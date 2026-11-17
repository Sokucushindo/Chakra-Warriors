class_name RaitonFXA
extends RefCounted
## Raiton A grubu: 15 tekniğin görseli ve taşınmış oynanışı. Malzeme / yapı taşı RaitonLib'den; her tekniğin şekli,
## hareketi ve sahnelenmesi kendine özgü. Oynanış (hasar çağrıları, durumlar, süreler, menzil, mermi davranışı)
## PathJutsu'daki eski gövdelerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/raiton_lib.gd")   # sınıf adı sabit ifade sayılmıyor
const RAI := Color(0.65, 0.85, 1.0)
const EMAG := Color(0.55, 0.8, 1.0)
const GOLD := Color(1.0, 0.84, 0.32)
const YEL := Color(1.0, 0.95, 0.6)
const WHITE := Color(0.92, 0.96, 1.0)


# ═════════════════════════════════════════ Raijū Tsuiga ═════════════════════════════════════════

## Şimşek tazısı: ak-mavi plazmadan dört bacaklı köpek (kırmızı göz ve ağız), sivri yele, koşarken bacaklar dörtnala,
## arkasına akan şimşek saçakları, bastığı yerde küçük yanık; elden tazıya bir an şimşek bağı uzanır
static func _hound() -> Node3D:
	var root_n = Node3D.new()
	var body_m = L.solid_mat(Color(0.9, 0.96, 1.0), Color(0.55, 0.8, 1.0), Color(0.22, 0.48, 0.95))
	var ol = L.line_mat(Color(0.04, 0.1, 0.3), 0.045)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.1, 0.1), Vector3(1.0, 0.85, 1.9), Color.WHITE, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.2, -0.55), Vector3(1.05, 1.0, 1.0), Color.WHITE, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.55, -1.05), Vector3(0.7, 0.62, 0.8), Color.WHITE, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.42, -1.45), Vector3(0.36, 0.3, 0.55), Color.WHITE, Vector3.ZERO, 10)
	b.add("cone", Vector3(0.2, 0.95, -0.95), Vector3(0.16, 0.38, 0.12), Color.WHITE, Vector3(-15, 0, -18), 6)
	b.add("cone", Vector3(-0.2, 0.95, -0.95), Vector3(0.16, 0.38, 0.12), Color.WHITE, Vector3(-15, 0, 18), 6)
	# sivri şimşek yelesi: sırt boyunca geriye yatık dikenler
	for k in 6:
		var z = -0.7 + k * 0.3
		b.add("cone", Vector3(0, 0.55 - k * 0.03, z), Vector3(0.16, 0.42 - k * 0.03, 0.16), Color.WHITE, Vector3(55, 0, 0), 5)
	for sgn in [-1.0, 1.0]:
		b.add("cone", Vector3(0.45 * sgn, 0.05, -0.45), Vector3(0.12, 0.35, 0.12), Color.WHITE, Vector3(70, 0, 60 * sgn), 5)
		b.add("cone", Vector3(0.4 * sgn, 0.0, 0.5), Vector3(0.12, 0.3, 0.12), Color.WHITE, Vector3(80, 0, 55 * sgn), 5)
	var body = L.mi_of(b.build(body_m), body_m)
	body.material_overlay = ol
	root_n.add_child(body)
	# kırmızı gözler ve ağız (kaynaktaki gibi)
	var red = StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(0.95, 0.35, 0.4)
	var eb = MB.new()
	eb.add("sphere", Vector3(0.17, 0.62, -1.38), Vector3(0.11, 0.09, 0.06), Color.WHITE, Vector3.ZERO, 8)
	eb.add("sphere", Vector3(-0.17, 0.62, -1.38), Vector3(0.11, 0.09, 0.06), Color.WHITE, Vector3.ZERO, 8)
	eb.add("box", Vector3(0, 0.3, -1.62), Vector3(0.2, 0.05, 0.12), Color.WHITE, Vector3(-20, 0, 0))
	root_n.add_child(L.mi_of(eb.build(red), red))
	# bacaklar: omuz / kalça mafsalında dönen kapsüller
	var legs = []
	var lm = body_m
	var cm = CapsuleMesh.new()
	cm.radius = 0.12
	cm.height = 0.85
	for q in [[0.28, -0.6, 0.0], [-0.28, -0.6, PI], [0.26, 0.55, PI * 0.5], [-0.26, 0.55, PI * 1.5]]:
		var piv = Node3D.new()
		piv.position = Vector3(q[0], -0.05, q[1])
		var leg = L.mi_of(cm, lm)
		leg.material_overlay = ol
		leg.position = Vector3(0, -0.38, 0)
		piv.add_child(leg)
		root_n.add_child(piv)
		legs.append([piv, q[2]])
	# kuyruk
	var tail = Node3D.new()
	tail.position = Vector3(0, 0.35, 1.0)
	var tm = L.mi_of(cm, lm)
	tm.material_overlay = ol
	tm.position = Vector3(0, 0, 0.35)
	tm.rotation.x = PI * 0.5
	tm.scale = Vector3(0.8, 1.0, 0.8)
	tail.add_child(tm)
	root_n.add_child(tail)
	# dörtnala: bacaklar savrulur, gövde iner kalkar, kuyruk sallanır
	var p = RaitonLib.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(body):
			return false
		for lg in legs:
			var pv: Node3D = lg[0]
			pv.rotation.x = sin(age * 15.0 + float(lg[1])) * 0.8
		body.position.y = absf(sin(age * 15.0)) * 0.12
		tail.rotation.x = -0.6 + sin(age * 15.0) * 0.25
		tail.rotation.y = sin(age * 9.0) * 0.4
		return true
	root_n.add_child(p)
	root_n.scale = Vector3.ONE * 1.15
	return root_n


## Tazının arkasına akan şimşek saçakları (gövdeden geriye ve yukarı)
static func _streamers(pr: Node3D, col: Color, dur: float) -> void:
	var m = L.arc_mat(col)
	var w = weakref(pr)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var o: Vector3 = x.global_position
		var back: Vector3 = x.global_transform.basis.z.normalized()
		if age >= float(stt["next"]):
			stt["next"] = age + 0.045
			var out = []
			for k in 4:
				var s = o + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), 0) + back * randf_range(-0.3, 0.6)
				var e = s + back * randf_range(1.2, 2.6) + Vector3.UP * randf_range(0.2, 1.2) + L.perp(back) * 0.6
				L.fork(s, e, 0.22, 4, 1, out, 0.07, 1.0)
			stt["polys"] = out
		L.draw(im, m, stt["polys"], randf_range(0.7, 1.0), L.cam_pos())
		return true)


## Çarpma: dev dişli yıldız, yukarı ve dışa kubbe gibi açılan kalın dallar, zeminde geniş sürünen ark halkası, yanık
static func _hound_burst(p: Vector3) -> void:
	L.flash(p, 2.4, Color(0.4, 0.66, 1.0), 0.16, 12.0)
	L.light(p, Color(0.5, 0.72, 1.0), 4.0, 9.0, 0.2)
	for k in 10:
		var a = k * TAU / 10.0 + randf_range(-0.2, 0.2)
		var e = p + Vector3(cos(a) * 3.2, randf_range(0.6, 3.0), sin(a) * 3.2)
		L.bolt(p, e, RAI, 0.16, 0.35, 2, 0.2, 0.05)
	L.sparks(p, 40, RAI, 14.0, 0.45)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.scorch(g, 2.2, RAI, 6.0, 1.4)
		L.ground_arcs(g, 3.0, 1.2, RAI, 7)
	L.wet_shock(p, 1.4)


static func raiju_tsuiga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.6)
	L.hand_charge(pj, c, 0.4, RAI, 1.2)
	var hf = L.hand_fn(pj, c)
	L.converge(hf, 1.4, 0.2, RAI, 12)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var from = pj.gp(c.global_position + c.face_dir() * 1.0) + Vector3.UP * 0.7
		var hound = _hound()
		var dir = pj.aim_at(c, tt, from)
		dir.y = 0
		var pr = pj.shot(c, from, dir.normalized(), 24.0, hound, pj.inf(c, "raiton_raiju_tsuiga", 1.1, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8}), tt, false, 2.0, func(p, _h):
			_hound_burst(p))
		pr.homing_turn = 4.0
		pr.radius = 0.8
		L.flash(hf.call(), 1.4, RAI, 0.1, 7.0)
		L.bolt(hf, L.follow_fn(pr, Vector3.UP * 0.2), RAI, 0.14, 0.35, 3, 0.2, 0.04)
		L.crackle(L.follow_fn(pr, Vector3.UP * 0.2), 1.0, 2.0, RAI, 5, 0.04, 0.06, pr)
		_streamers(pr, RAI, 2.0)
		# patiler yerde küçük yanık + kısa ark bırakır
		pj.every(2.0, 0.14, func(_i, _k):
			if L.alive(pr):
				var g = L.floor_at(pr.global_position)
				if pr.global_position.y - g.y < 1.6:
					L.scorch(g + L.hdir() * 0.25, 0.35, RAI, 2.5, 0.5)
					L.bolt(g + Vector3.UP * 0.05, g + L.hdir() * 0.8 + Vector3.UP * 0.05, RAI, 0.03, 0.15, 0, 0.3, 0.05, 3), Callable()))
	Sfx.play("chidori", c.global_position, 1.2)


# ═════════════════════════════════════════ Ikazuchi Unagi ═════════════════════════════════════════

## Şimşek yılan balığı: elden hedefe kıvrılarak (yürüyen dalga) uzanan kalın altın-sarı akım + çevresinde kamçılanan
## ince şimşekler; ucu hedefin gövdesine sarmal halinde dolanır
static func _eel(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float) -> void:
	var hf = L.hand_fn(pj, c)
	var tf = L.follow_fn(tt, Vector3.UP * 1.0)
	var tb = L.follow_fn(tt)
	var m_main = L.arc_mat(GOLD)
	var m_thin = L.arc_mat(YEL)
	var cw = weakref(c)
	var tw = weakref(tt)
	var stt = {"next": 0.0, "whips": [], "coil": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var cx = cw.get_ref()
		var tx = tw.get_ref()
		if cx == null or tx == null or not is_instance_valid(cx) or not is_instance_valid(tx):
			return false
		var a: Vector3 = hf.call()
		var b: Vector3 = tf.call()
		var d = b - a
		var side = d.cross(Vector3.UP).normalized() if d.cross(Vector3.UP).length() > 0.01 else Vector3.RIGHT
		var up = side.cross(d).normalized()
		var reach = clampf(age / 0.18, 0.0, 1.0)
		var n = 28
		var path = []
		for i in n + 1:
			var f = float(i) / n * reach
			var env = sin(PI * f) * (0.35 + 0.15 * sin(age * 3.0))
			path.append(a + d * f + side * sin(f * PI * 3.0 - age * 11.0) * env + up * cos(f * PI * 2.0 - age * 8.0) * env * 0.5)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var whips = []
			for s in 3:
				var line = []
				for i in path.size():
					var p: Vector3 = path[i]
					line.append(p + L.rdir() * 0.18 * sin(PI * float(i) / path.size()))
				whips.append({"p": line, "w": 0.035, "a": randf_range(0.6, 1.0)})
			stt["whips"] = whips
			var coil = []
			if reach >= 1.0:
				var base: Vector3 = tb.call()
				var ph = age * 9.0
				for i in 40:
					var f = float(i) / 39.0
					var ang = ph + f * TAU * 3.0
					coil.append(base + Vector3(cos(ang) * 0.55, 0.15 + f * 1.7, sin(ang) * 0.55) + L.rdir() * 0.05)
				stt["coil"] = [{"p": coil, "w": 0.07, "a": 1.0, "k": 2}]
		var fade = clampf((dur - age) / 0.2, 0.0, 1.0)
		L.draw(im, m_main, [{"p": path, "w": 0.2, "a": 1.0, "k": 1}], fade, L.cam_pos())
		L.draw(im, m_thin, stt["whips"], fade, L.cam_pos())
		L.draw(im, m_main, stt["coil"], fade, L.cam_pos())
		return true)


static func ikazuchi_unagi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.9)
	pj.anim(c, "push", 1.3)
	L.hand_charge(pj, c, 2.0, GOLD, 1.1)
	if tt == null:
		return
	pj.st(tt, "bind", 2.0)
	_eel(pj, c, tt, 2.0)
	L.body_arcs(tt, 2.0, GOLD, 3, 0.035)
	pj.every(2.0, 0.4, func(_i, _k):
		if pj.live(tt):
			L.flash(tt.global_position + Vector3.UP, 1.5, GOLD, 0.12, 7.0)
			L.sparks(tt.global_position + Vector3.UP, 8, YEL, 6.0, 0.3)
			tt.take_hit(pj.inf(c, "raiton_ikazuchi_unagi", 0.25, {"knock": 0.0, "kind": "light", "element": "raiton"})), Callable())
	Sfx.play("thunder", tt.global_position, 1.5)


# ═════════════════════════════════════════ Raikyū ═════════════════════════════════════════

## Altın şimşek küresi (kaynak: beyaz öz, turuncu-altın kenar, çevresinde kılcal beyaz çatırtı); çarpınca küre
## yarılır: halka halinde kısa arklar + altın kıvılcım saçıntısı
static func _raikyu_pop(p: Vector3) -> void:
	L.flash(p, 3.0, GOLD, 0.18, 14.0)
	L.light(p, GOLD, 5.0, 9.0, 0.18)
	var ax = L.perp(Vector3.UP)
	var az = ax.cross(Vector3.UP)
	for k in 8:
		var a = k * TAU / 8.0
		var dir = (ax * cos(a) + az * sin(a) + Vector3.UP * randf_range(-0.4, 0.4)).normalized()
		L.bolt(p + dir * 0.4, p + dir * 1.7, YEL, 0.07, 0.25, 1, 0.3, 0.04, 3)
	L.sparks(p, 26, GOLD, 9.0, 0.4)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.scorch(g, 1.1, GOLD, 4.0, 0.8)
	L.wet_shock(p, 1.2)


static func raikyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var from = pj.hand_pos(c, true)
	for k in 5:
		L.bolt(from, from + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.6), randf_range(-0.6, 0.6)), YEL, 0.04, 0.25, 1, 0.3)
	var tt = pj.tg(c, t, 26.0)
	L.converge(from, 1.2, 0.2, GOLD, 10)
	L.flash(from, 0.8, GOLD, 0.2, 10.0)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var ball = Node3D.new()
		ball.add_child(L.orb(0.42, Color(1, 1, 0.92), Color(1.0, 0.82, 0.4), Color(1.0, 0.55, 0.15)))
		var info = {"knock": 8.0 * 1.2, "kind": "heavy", "element": "raiton", "hitstop": 0.05}
		info.merge({"stun": 0.6}, true)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, ball, pj.inf(c, "raikyu", 0.9, info), null, false, 1.6, func(p, _h):
			_raikyu_pop(p))
		pr.radius = 0.35 + 1.0 * 0.4
		L.crackle(L.follow_fn(pr), 0.7, 1.6, Color(1.0, 0.97, 0.85), 4, 0.025, 0.05, pr)
		L.trail(pr, GOLD, 0.2, 0.15, 0.1))
	Sfx.play("chidori", from, 1.4, 0.6)


# ═════════════════════════════════════════ Raigeki ═════════════════════════════════════════

## Mızrak: yumruktan ileri uzanan kalın, kenarı dişli beyaz-mavi şimşek kütlesi + çevresine sarılan ince şimşekler
static func _lance(a: Vector3, b: Vector3, col: Color, dur: float) -> void:
	var m = L.arc_mat(col)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			var out = []
			out.append({"p": L.jag(a, b, 0.05, 3), "w": 0.38, "a": 1.0})
			for k in 5:
				L.fork(a + L.perp(b - a) * 0.15, b + L.perp(b - a) * randf_range(0.2, 0.7), 0.22, 4, 1, out, 0.04, 0.9)
			stt["polys"] = out
		var grow = clampf(age / 0.05, 0.0, 1.0)
		var fade = pow(1.0 - age / dur, 0.6)
		L.draw(im, m, stt["polys"], fade * grow, L.cam_pos())
		return true)


static func raigeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	L.hand_charge(pj, c, 0.5, RAI, 1.3)
	var hf = L.hand_fn(pj, c)
	L.converge(hf, 1.6, 0.3, RAI, 14)
	pj.busy(c, 0.6)
	pj.after(0.15, func():
		pj._jump_at(c, tt, 0.0, 14.0 if tt else 3.0))
	pj.after(0.3, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var d = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.1 + d * 1.2
		L.flash(at, 3.4, RAI, 0.22, 11.0)
		_lance(at - d * 0.6, at + d * 3.4, RAI, 0.28)
		L.light(at, RAI, 7.0, 10.0, 0.2)
		L.sparks(at, 26, RAI, 12.0, 0.35, d, 0.8)
		var g = L.floor_at(at)
		if at.y - g.y < 2.5:
			L.scorch(g + d * 1.0, 1.4, RAI, 4.0, 0.9)
		L.wet_shock(at, 1.0)
		for e in pj.hit(c, at, 1.8, pj.inf(c, "raigeki", 1.3, {"knock": 8.0, "kind": "heavy", "element": "raiton"})):
			pj.st(e, "stun", 0.9)
			L.body_arcs(e, 0.9, RAI, 4)
		Sfx.play("thunder", at, 1.4))


# ═════════════════════════════════════════ Raisen ═════════════════════════════════════════

## Kendi şurikenimiz: dört eşkenar dörtgen bıçak + göbek (koyu çelik)
static func _shuriken(s: float) -> Node3D:
	var b = MB.new()
	var steel = Color(0.32, 0.34, 0.4)
	for k in 4:
		var a = k * 90.0
		var dv = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		b.add("box", dv * 0.24 * s, Vector3(0.2 * s, 0.025 * s, 0.2 * s), steel, Vector3(0, 45.0 - a, 0))
	b.add("cyl", Vector3.ZERO, Vector3(0.14 * s, 0.04 * s, 0.14 * s), Color(0.2, 0.2, 0.24), Vector3.ZERO, 10)
	var mi = L.mi_of(b.build(Props.toon()), null)
	var n = Node3D.new()
	n.add_child(mi)
	return n


## Şurikeni saran dönen şimşek çemberi (kaynak: Itachi'nin şimşekli şurikeni) + uçlardan fırlayan kısa arklar
static func _disc_ring(pr: Node3D, col: Color) -> void:
	var m = L.arc_mat(col)
	var w = weakref(pr)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree() or age > 2.0:
			return false
		var o: Vector3 = x.global_position
		var bx: Vector3 = x.global_transform.basis.x.normalized()
		var bz: Vector3 = x.global_transform.basis.z.normalized()
		if age >= float(stt["next"]):
			stt["next"] = age + 0.035
			var ring = []
			var ph = age * 30.0
			for i in 25:
				var a = ph + TAU * i / 24.0
				ring.append(o + (bx * cos(a) + bz * sin(a)) * 0.45 * randf_range(0.88, 1.12) + Vector3.UP * randf_range(-0.04, 0.04))
			var out = [{"p": ring, "w": 0.06, "a": 1.0, "k": 2}]
			for k in 2:
				var a2 = randf() * TAU
				var s = o + (bx * cos(a2) + bz * sin(a2)) * 0.45
				L.fork(s, s + (bx * cos(a2) + bz * sin(a2)) * randf_range(0.3, 0.6) + L.rdir() * 0.2, 0.3, 3, 0, out, 0.025, 0.8)
			stt["polys"] = out
		L.draw(im, m, stt["polys"], 1.0, L.cam_pos())
		return true)


static func _raisen_hit(p: Vector3) -> void:
	L.flash(p, 1.2, RAI, 0.1, 6.0)
	for k in 4:
		L.bolt(p, p + L.rdir() * 1.2, RAI, 0.04, 0.18, 1, 0.3, 0.04, 3)
	L.sparks(p, 12, RAI, 8.0, 0.3)
	L.wet_shock(p, 0.6)


static func raisen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 26.0)
	# elde şimşek yüklü shuriken belirir, fırlatma hareketinin bırakış anında elden çıkar (elle uyumlu)
	if c.get("model") and c.model.has_method("hold_temp"):
		c.model.hold_temp("el_shuriken", 0.32, "Right", 0.45)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(L.orb(0.1, Color(1, 1, 1), RAI, Color(0.4, 0.7, 1.0)))
		L.crackle(L.follow_fn(ba), 0.3, 0.32, RAI, 3, 0.02, 0.05, ba)
		pj.free_after(0.32, ba)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		L.flash(from, 0.9, RAI, 0.08, 8.0)
		for k in 4:
			pj.after(k * 0.05, func():
				var star = _shuriken(0.6)
				var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, (k - 1.5) * 0.05), 40.0, star, pj.inf(c, "raisen", 0.3, {"knock": 2.0, "kind": "light", "element": "raiton", "stun": 0.3}), tt, false, 1.2, func(p, _h):
					_raisen_hit(p))
				pr.spin = Vector3(0, 28, 0)
				_disc_ring(pr, RAI)
				L.trail(pr, RAI, 0.06, 0.12, 0.04)))
	Sfx.play("chidori", c.global_position, 1.6, 0.5)


# ═════════════════════════════════════════ Raigyaku Suihei Choppu ═════════════════════════════════════════

## Yatay el bıçağı: önde 150°lik yayı 0.1 sn'de süpüren, birkaç paralel dişli şimşek telinden hilal; kenar ucunda çakma,
## sonra zeminde öne açılan sürünen arklar, toz halkası, kırıntı (kaynak: Raikage'nin darbesinde yerden mavi sıçrama + toz)
static func _chop_arc(center: Vector3, d: Vector3, col: Color, dur: float) -> void:
	var m = L.arc_mat(col)
	var strands = []
	for s in 5:
		strands.append({"r": 1.5 + s * 0.12, "y": randf_range(-0.12, 0.12)})
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var sweep = clampf(age / 0.1, 0.0, 1.0)
		var a0 = deg_to_rad(-75.0)
		var a1 = lerpf(a0, deg_to_rad(75.0), sweep)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			var out = []
			for st in strands:
				var line = []
				var nseg = 22
				for i in nseg + 1:
					var a = lerpf(a0, a1, float(i) / nseg)
					var q = center + d.rotated(Vector3.UP, a) * float(st["r"]) + Vector3.UP * float(st["y"])
					line.append(q + L.rdir() * 0.07)
				out.append({"p": line, "w": 0.05 + 0.05 * randf(), "a": randf_range(0.6, 1.0), "k": 1})
			stt["polys"] = out
		L.draw(im, m, stt["polys"], pow(1.0 - age / dur, 0.5), L.cam_pos())
		return true)


static func raigyaku_suihei_choppu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	var d = pj._face(c, tt)
	L.hand_charge(pj, c, 0.5, RAI, 1.4)
	pj.busy(c, 0.6)
	pj.after(0.12, func():
		pj._jump_at(c, tt, 0.0, 10.0 if tt else 3.0))
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_b", 1.8)
		var at = c.global_position + Vector3.UP * 1.2
		_chop_arc(at + d * 0.3, d, RAI, 0.32)
		var tip = at + d * 0.3 + d.rotated(Vector3.UP, deg_to_rad(75.0)) * 1.7
		pj.after(0.1, func():
			L.flash(tip, 1.6, RAI, 0.12, 7.0)
			L.sparks(tip, 14, RAI, 10.0, 0.3, d.rotated(Vector3.UP, deg_to_rad(165.0)), 0.5))
		var g = L.floor_at(c.global_position + d * 1.8)
		L.ground_arcs(g, 2.6, 0.6, RAI, 6)
		L.dust_ring(g, 0.6, 3.8, 0.7)
		L.debris(g, 8, 6.0, Color(0.42, 0.38, 0.33), d * 0.6)
		L.light(at + d, RAI, 5.0, 8.0, 0.2)
		Combat.hit_zone(c, c.global_position, d, 3.2, 75.0, 2.0, pj.inf(c, "raigyaku_suihei_choppu", 1.3, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
		pj.shake(0.4)
		Sfx.play("thunder", c.global_position, 1.7, 0.6))


# ═════════════════════════════════════════ Kaminarimon: Denkō Ken ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Yumrukta büyüyen yük; vuruşta yumruğun önünde dar koni halinde öne fırlayan 6 kalın
## şimşek + yumruk eksenine dik açılan çatırtılı ark çemberi (geometrik kabuk değil, şimşek telleri) + az dişli iri çakma
static func _knuckle_ring(at: Vector3, d: Vector3, col: Color, dur: float) -> void:
	var m = L.arc_mat(col)
	var ax = L.perp(d)
	var az = d.cross(ax).normalized()
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = age / dur
		var r = lerpf(0.4, 2.3, 1.0 - pow(1.0 - f, 2.5))
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			var out = []
			for s in 2:
				var ring = []
				var off = d * (0.3 * s + f * 1.2)
				for i in 33:
					var a = TAU * i / 32.0
					ring.append(at + off + (ax * cos(a) + az * sin(a)) * r * (1.0 - s * 0.25) * randf_range(0.9, 1.1))
				out.append({"p": ring, "w": 0.05, "a": 1.0 - s * 0.35, "k": 2})
			stt["polys"] = out
		L.draw(im, m, stt["polys"], 1.0 - f, L.cam_pos())
		return true)


static func denko_ken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 0.6)
	L.hand_charge(pj, c, 0.6, EMAG, 1.6)
	L.converge(L.hand_fn(pj, c), 1.2, 0.25, EMAG, 10)
	pj._jump_at(c, tt, 0.3, 8.0)
	pj.after(0.25, func():
		if pj.live(c):
			var d = c.face_dir()
			var at = c.global_position + Vector3.UP * 1.1 + d * 1.2
			L.flash(at, 2.8, EMAG, 0.16, 5.0)
			L.light(at, EMAG, 6.0, 9.0, 0.2)
			for k in 6:
				var dv = (d + L.perp(d) * randf_range(0.1, 0.6)).normalized()
				L.bolt(at, at + dv * randf_range(2.4, 3.4), EMAG, 0.11, 0.3, 2, 0.16, 0.04)
			_knuckle_ring(at, d, EMAG, 0.25)
			L.sparks(at, 18, EMAG, 10.0, 0.3, d, 0.6)
			L.wet_shock(at, 1.4)
			for e in pj.hit(c, at, 2.2, pj.inf(c, "kaminarimon_denko_ken", 1.4, {"knock": 12.0, "kind": "heavy", "element": "raiton", "stun": 0.8})):
				L.body_arcs(e, 0.8, EMAG, 5))
	Sfx.play("chidori", c.global_position, 1.3)


# ═════════════════════════════════════════ Kaminarimon: Raijin no Tate ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Önde dönen altı plazma düğümü; komşu düğümler arasında çatırdayan şimşek çemberi,
## ara ara merkezden çapraz atlayan teller; mermiyi yakınca düğümden mermiye şimşek atlar, mermi çakmayla söner
static func _shield_web(ring: Node3D, orbs: Array, col: Color) -> void:
	var m = L.arc_mat(col)
	var rw = weakref(ring)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var r = rw.get_ref()
		if r == null or not is_instance_valid(r) or not r.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var out = []
			var ps = []
			for o in orbs:
				if is_instance_valid(o):
					ps.append(o.global_position)
			for i in ps.size():
				if randf() < 0.85:
					L.fork(ps[i], ps[(i + 1) % ps.size()], 0.25, 3, 0, out, 0.04, 1.0)
			if ps.size() >= 4 and randf() < 0.45:
				var i0 = randi() % ps.size()
				L.fork(ps[i0], ps[(i0 + 3) % ps.size()], 0.2, 4, 1, out, 0.03, 0.7)
			stt["polys"] = out
		L.draw(im, m, stt["polys"], randf_range(0.7, 1.0), L.cam_pos())
		return true)


static func raijin_tate(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var ring = Node3D.new()
	c.add_child(ring)
	ring.position = Vector3(0, 1.2, 1.3)
	var orbs = []
	for k in 6:
		var a = k * TAU / 6.0
		var o = L.orb(0.16, Color(1, 1, 1), EMAG, Color(0.3, 0.6, 1.0))
		ring.add_child(o)
		o.position = Vector3(cos(a), sin(a), 0) * 1.0
		orbs.append(o)
	var tw = ring.create_tween()
	tw.tween_property(ring, "rotation:z", TAU * 6.0, 5.0)
	tw.tween_callback(ring.queue_free)
	_shield_web(ring, orbs, EMAG)
	L.flash(ring.global_position, 2.0, EMAG, 0.15, 6.0)
	pj.every(5.0, 0.06, func(_i, _k):
		if not (pj.live(c) and is_instance_valid(ring)):
			return
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr.get("shooter") != c and pr.global_position.distance_to(ring.global_position) < 2.0:
				var near = ring.global_position
				var best = 99.0
				for o in orbs:
					if is_instance_valid(o) and o.global_position.distance_to(pr.global_position) < best:
						best = o.global_position.distance_to(pr.global_position)
						near = o.global_position
				L.bolt(near, pr.global_position, EMAG, 0.1, 0.15, 1)
				L.flash(pr.global_position, 1.0, EMAG, 0.1, 6.0)
				L.sparks(pr.global_position, 8, EMAG, 6.0, 0.25)
				pr.queue_free(), Callable())
	Sfx.play("chidori", c.global_position, 1.5)


# ═════════════════════════════════════════ Raigen Raikōchū ═════════════════════════════════════════

## Göz kamaştıran ışık sütunu: gökten atanın üstüne inen sarı-beyaz dikey şimşek demeti, dev çakma, dışa 6 şimşek;
## oyuncu ekranında manga zikzaklı beyaz patlama; etkilenenlerin başı çevresinde 2.5 sn sahte zikzak şimşekler çakar
static func _phantom(e: Node3D, dur: float) -> void:
	var m = L.arc_mat(YEL)
	var ew = weakref(e)
	var hgt = float(e.get("height")) if e.get("height") != null else 1.8
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = ew.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.1, 0.22)
			var out = []
			var head: Vector3 = x.global_position + Vector3.UP * hgt * 0.92
			for k in randi_range(0, 2):
				var s = head + L.rdir() * 0.9 + Vector3.UP * 0.3
				out.append({"p": L.zigzag(s, s + L.rdir() * 0.8 + Vector3.DOWN * 0.3, 4, 0.18), "w": 0.05, "a": 1.0, "k": 2})
			stt["polys"] = out
		L.draw(im, m, stt["polys"], 1.0, L.cam_pos())
		return true)


static func raigen_raikochu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var _tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.6)
	var o = c.global_position
	L.flash(o + Vector3.UP * 1.5, 6.5, YEL, 0.35, 14.0)
	L.light(o + Vector3.UP * 2.0, YEL, 10.0, 18.0, 0.45)
	for k in 7:
		var q = o + L.hdir() * randf_range(0.2, 0.9)
		L.bolt(q + Vector3.UP * 14.0, q + Vector3.UP * 0.1, YEL, 0.14, 0.45, 2, 0.12, 0.05, 5)
	L.scorch(L.floor_at(o), 1.8, YEL, 4.0, 1.0)
	if c is Player:
		L.screen_flash(Color(1, 0.98, 0.85), 0.5)
	for k in 6:
		var a = k * TAU / 6.0
		var e = o + Vector3(cos(a) * 6.0, 1.5 + randf_range(-1, 2), sin(a) * 6.0)
		L.zig_bolt(o + Vector3.UP * 1.5 + (e - o - Vector3.UP * 1.5).normalized() * 0.6, e, YEL, 0.07, 0.3, 7, 0.45, 0.05)
	for e in pj.enemies_near(c, c.global_position, 12.0):
		pj.st(e, "stun", 2.5)
		if e.has_method("lose_target"):
			e.lose_target(2.5)
		_phantom(e, 2.5)
	Sfx.play("thunder", c.global_position, 1.5)


# ═════════════════════════════════════════ Jinraisen ═════════════════════════════════════════

## Şimşek oku: tip 0.06 sn'de 26 m koşar (ucu keskin ok başı + küçük çakma), beyaz öz + mavi-beyaz kılıf + çevresinde
## burulan üç ince tel; tutar, söner, yolda kısa iyon arkları kalır
static func _arrow_beam(a: Vector3, b: Vector3, d: Vector3) -> void:
	var m_core = L.arc_mat(WHITE)
	var m_glow = L.arc_mat(RAI)
	var side = L.perp(d)
	var stt = {"next": 0.0, "core": [], "wrap": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.5:
			return false
		var reach = clampf(age / 0.06, 0.0, 1.0)
		var tip = a.lerp(b, reach)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			stt["core"] = [{"p": L.jag(a, tip, 0.012, 5), "w": 0.1, "a": 1.0}, {"p": L.jag(a, tip, 0.03, 4), "w": 0.3, "a": 0.6}]
			var wrap = []
			for k in 3:
				var line = []
				var nseg = 40
				for i in nseg + 1:
					var f = float(i) / nseg
					var ang = f * 26.0 + k * TAU / 3.0 + age * 30.0
					var q = a.lerp(tip, f) + (side * cos(ang) + d.cross(side) * sin(ang)) * 0.22 * sin(PI * f)
					line.append(q + L.rdir() * 0.04)
				wrap.append({"p": line, "w": 0.03, "a": 0.9})
			# ok başı: uçtan geriye iki keskin çizgi
			wrap.append({"p": [tip - d * 0.7 + side * 0.35, tip, tip - d * 0.7 - side * 0.35], "w": 0.07, "a": 1.0, "k": 2})
			stt["wrap"] = wrap
		var fade = 1.0 if age < 0.14 else clampf(1.0 - (age - 0.14) / 0.36, 0.0, 1.0)
		L.draw(im, m_glow, stt["core"], fade, L.cam_pos())
		L.draw(im, m_core, stt["wrap"], fade, L.cam_pos())
		return true)
	# kalan iyon arkları
	for k in 6:
		var f = randf_range(0.1, 0.95)
		var p = a.lerp(b, f)
		L.bolt(p, p + L.rdir() * 0.7, RAI, 0.025, 0.6, 0, 0.35, 0.08, 3)


static func jinraisen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 30.0)
	var from = pj.hand_pos(c, true)
	L.converge(from, 1.0, 0.15, WHITE, 10)
	L.crackle(from, 0.35, 0.15, WHITE, 3, 0.025)
	pj.after(0.15, func():
		if not pj.live(c):
			return
		var ad = pj.aim_at(c, tt, from)
		var end = from + ad * 26.0
		_arrow_beam(from, end, ad)
		L.flash(from, 1.8, WHITE, 0.12, 9.0)
		L.light(from, WHITE, 6.0, 10.0, 0.15)
		Combat.hit_zone(c, c.global_position, pj.aim_at(c, tt, from), 26.0, 5.0, 2.5, pj.inf(c, "raiton_jinraisen", 1.3, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
		if tt:
			var ip = tt.global_position + Vector3.UP
			L.flash(ip, 2.2, RAI, 0.14, 8.0)
			L.sparks(ip, 20, WHITE, 12.0, 0.35, ad, 0.5)
			for k in 4:
				L.bolt(ip, ip + (ad + L.rdir() * 0.6).normalized() * randf_range(1.5, 2.5), RAI, 0.06, 0.25, 1, 0.25, 0.04)
			L.wet_shock(ip, 1.0)
		Sfx.play("thunder", from, 1.8, 0.6))


# ═════════════════════════════════════════ Raitoningu Sutorēto ═════════════════════════════════════════

## Şimşek düz yumruk (taijutsu ağırlıklı): koşuda hız çizgileri ve ayak altında yanık kayma izi; vuruşta öne fışkıran
## düz basınç çizgileri, yumruk eksenine dik iki hava sıkışma halkası, yerde toz halkası + kırıntı; ışık küçük
static func _air_rings(at: Vector3, d: Vector3, dur: float) -> void:
	var m = L.arc_mat(L.PALE)
	var ax = L.perp(d)
	var az = d.cross(ax).normalized()
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = age / dur
		var polys = []
		for s in 2:
			var r = lerpf(0.3, 1.6 - s * 0.4, 1.0 - pow(1.0 - f, 2.0))
			var ring = []
			for i in 29:
				var a = TAU * i / 28.0
				ring.append(at + d * (0.6 + s * 0.9 + f * 1.5) + (ax * cos(a) + az * sin(a)) * r)
			polys.append({"p": ring, "w": 0.035, "a": 0.8 - s * 0.3, "k": 2})
		for k in 8:
			var q = at + (ax * randf_range(-0.6, 0.6) + az * randf_range(-0.6, 0.6))
			polys.append({"p": [q, q + d * randf_range(1.5, 3.0)], "w": 0.02, "a": randf_range(0.4, 0.9), "k": 1})
		L.draw(im, m, polys, 1.0 - f, L.cam_pos())
		return true)


static func raitoningu_sutoreto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	L.hand_charge(pj, c, 0.5, RAI, 1.0)
	var d = pj._jump_at(c, tt, 0.0, 20.0 if tt else 5.0)
	pj.busy(c, 0.5)
	L.speed_lines(c, d, 0.22, Color(0.7, 0.85, 1.0))
	pj.every(0.18, 0.045, func(_i, _k):
		if pj.live(c):
			L.scorch(L.floor_at(c.global_position), 0.3, RAI, 2.0, 0.3), Callable())
	pj.after(0.18, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 2.0)
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.3
		_air_rings(at, d, 0.22)
		L.flash(at, 1.3, RAI, 0.08, 6.0)
		L.sparks(at, 10, RAI, 9.0, 0.25, d, 0.4)
		var g = L.floor_at(at)
		if at.y - g.y < 2.5:
			L.dust_ring(g, 0.4, 2.6, 0.5)
			L.debris(g, 5, 5.0, Color(0.42, 0.38, 0.33), d)
		L.wet_shock(at, 1.0)
		for e in pj.hit(c, at, 1.8, pj.inf(c, "raitoningu_sutoreto", 1.5, {"knock": 18.0, "kind": "heavy", "element": "raiton", "stun": 0.5})):
			L.body_arcs(e, 0.5, RAI, 3)
		pj.shake(0.25)
		Sfx.play("thunder", at, 1.6, 0.6))


# ═════════════════════════════════════════ Hebi Ikazuchi ═════════════════════════════════════════

## Yılan başı: yassı kama kafa (arkası geniş çene mafsalı, öne daralan üst çene), aşağı açılıp kapanan alt çene, uzun üst
## dişler + küçük alt dişler, koyu ağız içi, kaş çıkıntıları ve koyu gözler; koyu turuncu dış çizgi. Baş her karede gidiş
## yönüne döner
static func _snake_head(col: Color) -> Node3D:
	var root_n = Node3D.new()
	var inner = Node3D.new()
	inner.scale = Vector3.ONE * 1.2
	root_n.add_child(inner)
	var m = L.solid_mat(Color(1, 1, 0.88), col, Color(0.95, 0.58, 0.1))
	var ol = L.line_mat(Color(0.35, 0.15, 0.02), 0.03)
	var wc = Color.WHITE
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.02, 0.15), Vector3(0.62, 0.26, 0.55), wc, Vector3.ZERO, 14)
	b.add("cone", Vector3(0, 0.06, -0.3), Vector3(0.6, 0.85, 0.2), wc, Vector3(-80, 0, 0), 10)
	b.add("box", Vector3(0.17, 0.16, -0.1), Vector3(0.14, 0.06, 0.32), wc, Vector3(0, -12, 0))
	b.add("box", Vector3(-0.17, 0.16, -0.1), Vector3(0.14, 0.06, 0.32), wc, Vector3(0, 12, 0))
	var skull = L.mi_of(b.build(m), m)
	skull.material_overlay = ol
	inner.add_child(skull)
	# alt çene: mafsaldan aşağı açılır
	var jaw = Node3D.new()
	jaw.position = Vector3(0, -0.05, 0.15)
	inner.add_child(jaw)
	var jb = MB.new()
	jb.add("cone", Vector3(0, -0.03, -0.42), Vector3(0.5, 0.8, 0.12), wc, Vector3(-95, 0, 0), 10)
	var jm = L.mi_of(jb.build(m), m)
	jm.material_overlay = ol
	jaw.add_child(jm)
	# ağız içi, gözler, dişler (düz renk)
	var dark = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.35, 0.08, 0.04)
	var mb = MB.new()
	mb.add("sphere", Vector3(0, -0.04, -0.12), Vector3(0.4, 0.1, 0.55), wc, Vector3.ZERO, 10)
	inner.add_child(L.mi_of(mb.build(dark), dark))
	var eye = StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color(0.06, 0.03, 0.02)
	var eb = MB.new()
	for sgn in [-1.0, 1.0]:
		eb.add("sphere", Vector3(0.22 * sgn, 0.13, -0.02), Vector3(0.09, 0.07, 0.12), wc, Vector3.ZERO, 8)
	inner.add_child(L.mi_of(eb.build(eye), eye))
	var fang = StandardMaterial3D.new()
	fang.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fang.albedo_color = Color(1, 1, 1)
	var fb = MB.new()
	for sgn in [-1.0, 1.0]:
		fb.add("cone", Vector3(0.12 * sgn, -0.08, -0.5), Vector3(0.05, 0.22, 0.05), wc, Vector3(180, 0, 0), 5)
	inner.add_child(L.mi_of(fb.build(fang), fang))
	var lf = MB.new()
	for sgn in [-1.0, 1.0]:
		lf.add("cone", Vector3(0.1 * sgn, 0.06, -0.55), Vector3(0.035, 0.12, 0.035), wc, Vector3.ZERO, 5)
	jaw.add_child(L.mi_of(lf.build(fang), fang))
	var p = RaitonLib.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(jaw):
			return false
		jaw.rotation.x = -(0.3 + 0.2 * absf(sin(age * 9.0)))
		var par = root_n.get_parent()
		if par != null and par.get("vel") != null:
			var v: Vector3 = par.get("vel")
			if v.length() > 0.1:
				root_n.look_at(root_n.global_position + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
		return true
	root_n.add_child(p)
	return root_n


## Yılan gövdesi: merminin geçtiği yol üzerinde, baştan kuyruğa doğru büyüyen yılan kıvrımı (yürüyen dalga), kuyruğa
## doğru incelen opak cel gövde (kenarı birkaç karede bir kırılan, çatırdayan), ince parıltı, gövdeden kopan kısa
## şimşek dalları; mermi bitince kuyruk son noktaya çekilir
static func _snake_body(pr: Node3D, col: Color) -> void:
	var m_body = L.arc_mat(col)
	var m_halo = L.arc_mat(Color(1.0, 0.8, 0.3))
	var m_band = L.band_mat(Color(1, 1, 0.9), Color(1.0, 0.82, 0.3), Color(0.45, 0.2, 0.03))
	var w = weakref(pr)
	var stt = {"next": 0.0, "arcs": [], "gone": -1.0, "pts": [], "jit": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var pts: Array = stt["pts"]
		var x = w.get_ref()
		var live = x != null and is_instance_valid(x) and x.is_inside_tree()
		if live:
			var p: Vector3 = x.global_position
			if pts.is_empty() or Vector3(pts[pts.size() - 1]).distance_to(p) > 0.15:
				pts.append(p)
		elif float(stt["gone"]) < 0.0:
			stt["gone"] = age
		# gövde boyu ~6 m
		var total = 0.0
		var i0 = pts.size() - 1
		while i0 > 0 and total < 6.0:
			total += Vector3(pts[i0]).distance_to(pts[i0 - 1])
			i0 -= 1
		if i0 > 0:
			pts = pts.slice(i0)
		if not live:
			var g = age - float(stt["gone"])
			if g > 0.3 or pts.size() < 2:
				return false
			var drop = int(ceil(pts.size() * g / 0.3))
			if drop > 0 and drop < pts.size():
				pts = pts.slice(drop)
		stt["pts"] = pts
		var n = pts.size()
		if n < 2:
			return true
		# kıvrım: baştan uzaklığa göre yanal yürüyen dalga (başta sıfır, gövdede büyür)
		var disp = []
		var sides = []
		var dh = 0.0
		for k in n:
			var i = n - 1 - k
			if k > 0:
				dh += Vector3(pts[i]).distance_to(pts[i + 1])
			var tn: Vector3 = Vector3(pts[mini(i + 1, n - 1)]) - Vector3(pts[maxi(i - 1, 0)])
			var sd = tn.cross(Vector3.UP)
			sd = sd.normalized() if sd.length() > 0.001 else Vector3.RIGHT
			var amp = 0.38 * clampf(dh / 1.2, 0.0, 1.0)
			disp.push_front(Vector3(pts[i]) + sd * sin(dh * 1.8 - age * 13.0) * amp)
			sides.push_front(sd)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var jl = []
			for i in 48:
				jl.append(L.rdir() * 0.05)
			stt["jit"] = jl
			# gövdeden kopan kısa şimşek dalları + gövde boyunca bir kesik tel
			var arcs = []
			for q in 3:
				var i = randi() % maxi(n - 3, 1)
				var s0: Vector3 = disp[i]
				var sg = 1.0 if randf() < 0.5 else -1.0
				var dv = (Vector3(sides[i]) * sg + Vector3.UP * randf_range(-0.2, 0.8) + L.rdir() * 0.3).normalized()
				L.fork(s0, s0 + dv * randf_range(0.5, 1.3), 0.3, 3, 1, arcs, 0.03, 1.0)
			var line = []
			for i in n:
				line.append(Vector3(disp[i]) + L.rdir() * 0.16 * (float(i) / n))
			arcs.append({"p": line, "w": 0.025, "a": 0.8, "k": 1})
			stt["arcs"] = arcs
		var jit: Array = stt["jit"]
		var body = []
		for i in n:
			body.append(Vector3(disp[i]) + Vector3(jit[i % jit.size()]) * (float(i) / n))
		L.draw(im, m_halo, [{"p": body, "w": 0.32, "a": 0.25, "k": 1}], 1.0, L.cam_pos())
		L.draw(im, m_band, [{"p": body, "w": 0.2, "a": 1.0, "k": 1}], 1.0, L.cam_pos())
		L.draw(im, m_body, stt["arcs"], 1.0, L.cam_pos())
		return true)


## Isırık: önce çevresinde daralan şimşek sarmalı, sonra çakma, dallar, sarı yanık
static func _snake_bite(p: Vector3, col: Color) -> void:
	var m = L.arc_mat(col)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.2:
			return false
		var f = age / 0.2
		var line = []
		for i in 49:
			var u = float(i) / 48.0
			var a = u * TAU * 3.0 + age * 25.0
			var r = lerpf(1.6, 0.2, f) * (1.0 - u * 0.3)
			line.append(p + Vector3(cos(a) * r, (u - 0.5) * 1.6 * (1.0 - f), sin(a) * r) + L.rdir() * 0.05)
		L.draw(im, m, [{"p": line, "w": 0.07, "a": 1.0, "k": 2}], 1.0, L.cam_pos())
		return true)
	L.flash(p, 2.0, Color(1.0, 0.72, 0.2), 0.14, 10.0)
	L.light(p, Color(1.0, 0.85, 0.5), 4.0, 9.0, 0.2)
	for k in 7:
		L.bolt(p, p + L.rdir() * randf_range(2.0, 3.0), col, 0.12, 0.3, 2)
	L.sparks(p, 28, col, 12.0, 0.4)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.scorch(g, 1.8, col, 5.0, 1.2)
	L.wet_shock(p, 1.4)


static func hebi_ikazuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 28.0)
	var from = pj.hand_pos(c, true)
	L.converge(from, 1.4, 0.2, YEL, 12)
	L.crackle(from, 0.5, 0.2, YEL, 4, 0.03)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var head = _snake_head(YEL)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 22.0, head, pj.inf(c, "raiton_hebi_ikazuchi", 1.4, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8}), tt, false, 2.4, func(p, _h):
			_snake_bite(p, YEL))
		pr.homing_turn = 5.0
		var age = {"t": 0.0}
		pr.on_tick = func(p: Projectile, dt: float) -> void:
			age["t"] += dt
			p.vel = p.vel.rotated(Vector3.UP, sin(age["t"] * 14.0) * 0.08)
		_snake_body(pr, YEL)
		L.crackle(L.follow_fn(pr), 0.7, 2.4, YEL, 3, 0.03, 0.06, pr))
	Sfx.play("chidori", from, 1.2)


# ═════════════════════════════════════════ Raiton: Hiraishin ═════════════════════════════════════════

## Şimşek çubuğu: koyu çelik öz + akkor kılıf, sivri uç; boyunca ileri koşan tel arkları
static func _rod(col: Color) -> Node3D:
	var root_n = Node3D.new()
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.25, 0.3, 0.4)
	steel.metallic = 0.7
	steel.roughness = 0.35
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.06, 1.5, 0.06), Color.WHITE, Vector3(90, 0, 0), 8)
	b.add("cone", Vector3(0, 0, -0.85), Vector3(0.1, 0.25, 0.1), Color.WHITE, Vector3(-90, 0, 0), 8)
	root_n.add_child(L.mi_of(b.build(steel), steel))
	var sheath = L.plasma_mat(Color(1, 1, 1), col, Color(0.4, 0.7, 1.0), 0.75)
	var s = MB.new()
	s.add("cyl", Vector3.ZERO, Vector3(0.16, 1.6, 0.16), Color.WHITE, Vector3(90, 0, 0), 10)
	root_n.add_child(L.mi_of(s.build(sheath), sheath))
	return root_n


## Saplanan çubuk: hedefin gövdesinde (ya da çarpma noktasında) 1.5 sn kalır; tepesinden çevreye ve yere şimşek fışkırır,
## yere değen uçlar küçük yanık bırakır
static func _rod_strike(pj: PathJutsu, p: Vector3, h: Node3D, d: Vector3) -> void:
	var planted = _rod(RAI)
	if h and pj.live(h):
		h.add_child(planted)
		planted.position = Vector3(0, 1.1, 0)
	else:
		L.root().add_child(planted)
		planted.global_position = p
	if d.length() > 0.01:
		planted.look_at(planted.global_position + d, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	pj.free_after(1.5, planted)
	pj.every(1.5, 0.08, func(_i, _k):
		var q = h.global_position + Vector3.UP if h and pj.live(h) else p
		var e = q + Vector3(randf_range(-2.5, 2.5), randf_range(-1, 2.5), randf_range(-2.5, 2.5))
		L.bolt(q, e, RAI, 0.1, 0.12, 2)
		if randf() < 0.25:
			var g = L.floor_at(q + L.hdir() * randf_range(1.0, 2.5))
			L.bolt(q, g, RAI, 0.08, 0.14, 1)
			L.scorch(g, 0.4, RAI, 2.5, 0.4), Callable())
	if h and pj.live(h):
		pj.st(h, "stun", 1.5)
		L.body_arcs(h, 1.5, RAI, 4)
	L.flash(p, 2.4, RAI, 0.16, 8.0)
	L.light(p, RAI, 6.0, 10.0, 0.2)
	L.sparks(p, 18, RAI, 10.0, 0.35, -d, 0.8)
	L.wet_shock(p, 1.0)


static func hiraishin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 24.0)
	var from = pj.hand_pos(c, true)
	# kaynak: kalkık koldan yukarı / yana dallanan şimşekler
	for k in 3:
		L.bolt(from, from + Vector3(randf_range(-1.2, 1.2), randf_range(0.8, 1.8), randf_range(-1.2, 1.2)), RAI, 0.06, 0.25, 2)
	L.flash(from, 1.1, RAI, 0.1, 6.0)
	var rod = _rod(RAI)
	var ad = pj.aim_at(c, tt, from)
	var pr = pj.shot(c, from, ad, 44.0, rod, pj.inf(c, "raiton_hiraishin", 1.0, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.6}), null, false, 1.0, func(p, h):
		_rod_strike(pj, p, h, ad))
	L.trail(pr, RAI, 0.07, 0.14, 0.03)
	L.crackle(L.follow_fn(pr), 0.6, 1.0, RAI, 3, 0.025, 0.05, pr)
	Sfx.play("thunder", from, 1.5, 0.5)


# ═════════════════════════════════════════ Amigumo ═════════════════════════════════════════

## Şimşek örümcek ağı (kaynak: yerde ince mavi ışınsal teller + kesik kesik eş merkezli yaylar): avuçlardan dışa
## 0.35 sn'de yayılır, zeminin şekline oturur, teller boyunca dışa akım nabızları koşar; 8 sn sonra içe çekilerek söner
static func _web_field(at: Vector3, R: float, hold: float, col: Color) -> void:
	var m = L.web_mat(col)
	var m_hot = L.arc_mat(Color(0.45, 0.75, 1.0))
	var lines = []
	var spokes = 14
	for k in spokes:
		var a = TAU * k / spokes + randf_range(-0.12, 0.12)
		var s0 = Vector3(at.x + cos(a) * 0.5, 0, at.z + sin(a) * 0.5)
		var s1 = Vector3(at.x + cos(a) * R, 0, at.z + sin(a) * R)
		var line = []
		for q in L.jag(s0, s1, 0.035, 5, true):
			var qv: Vector3 = q
			line.append({"r": Vector2(qv.x - at.x, qv.z - at.z).length(), "p": qv})
		lines.append(line)
	for j in 5:
		var rr = R * (0.18 + j * 0.2)
		var start = randf() * TAU
		var nparts = randi_range(3, 5)
		for q in nparts:
			var a0 = start + TAU * q / nparts
			var a1 = a0 + TAU / nparts * randf_range(0.55, 0.85)
			var line = []
			var nseg = maxi(6, int((a1 - a0) * rr / 0.3))
			for i in nseg + 1:
				var aa = lerpf(a0, a1, float(i) / nseg)
				# dişli yay: her noktada içe / dışa sert kırılım
				var r2 = rr * (1.0 + sin(aa * 5.0 + j) * 0.04) + (0.12 if i % 2 == 0 else -0.12) * randf_range(0.3, 1.0)
				line.append({"r": r2, "p": Vector3(at.x + cos(aa) * r2, 0, at.z + sin(aa) * r2)})
			lines.append(line)
	for line in lines:
		for s in line:
			var p: Vector3 = s["p"]
			s["p"] = Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.05, p.z)
	var total = 0.35 + hold + 0.3
	var stt = {"next": 0.0, "jit": [], "surge": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > total:
			return false
		var lim = R + 1.0
		if age < 0.35:
			lim = R * age / 0.35
		elif age > 0.35 + hold:
			lim = R * (1.0 - (age - 0.35 - hold) / 0.3)
		# titreşim: birkaç karede bir tüm teller hafifçe yeniden kırılır; ayrıca 2-3 tel boyunca parlak akım dalgası
		if age >= float(stt["next"]):
			stt["next"] = age + 0.07
			var jl = []
			for i in 64:
				var h = L.hdir() * randf_range(0.0, 0.07)
				jl.append(h)
			stt["jit"] = jl
			var surge = []
			for q in 3:
				var line: Array = lines[randi() % lines.size()]
				if line.size() < 4:
					continue
				var i0 = randi() % (line.size() - 3)
				var seg = []
				for i in range(i0, mini(i0 + 5, line.size())):
					if float(line[i]["r"]) <= lim:
						seg.append(Vector3(line[i]["p"]) + Vector3.UP * randf_range(0.02, 0.2) + L.hdir() * 0.08)
				if seg.size() >= 2:
					surge.append({"p": seg, "w": 0.09, "a": 1.0})
			stt["surge"] = surge
		var jit: Array = stt["jit"]
		var polys = []
		var li = 0
		for line in lines:
			li += 1
			var cut = []
			var ii = 0
			for s in line:
				ii += 1
				if float(s["r"]) <= lim:
					cut.append(Vector3(s["p"]) + Vector3(jit[(li * 7 + ii) % jit.size()]))
				elif cut.size() >= 2:
					break
			if cut.size() >= 2:
				polys.append({"p": cut, "w": 0.1, "a": 1.0, "k": 2})
		var flick = 0.8 + 0.2 * randf()
		L.draw(im, m, polys, flick, L.cam_pos(), true)
		L.draw(im, m_hot, stt["surge"], 1.0, L.cam_pos())
		return true)


static func amigumo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var at = pj.gp(c.global_position)
	_web_field(at, 8.0, 8.0, RAI)
	L.flash(at + Vector3.UP * 0.3, 1.6, RAI, 0.15, 8.0)
	L.ground_arcs(at, 1.2, 0.5, RAI, 5)
	pj.every(8.4, 0.3, func(_i, _k):
		if randf() < 0.6:
			var q = at + Vector3(randf_range(-7, 7), 0.1, randf_range(-7, 7))
			var g = L.floor_at(q)
			L.bolt(g + Vector3.UP * 0.05, L.floor_at(q + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))) + Vector3.UP * 0.4, RAI, 0.05, 0.15, 1, 0.3)
		for e in pj.enemies_near(c, at, 8.0):
			if randf() < 0.3:
				pj.st(e, "stun", 0.6)
				L.bolt(pj.gp(e.global_position) + Vector3.UP * 0.1, e.global_position + Vector3.UP * 1.6, RAI, 0.1, 0.2, 2)
				L.body_arcs(e, 0.6, RAI, 3)
				e.take_hit(pj.inf(c, "raiton_amigumo", 0.12, {"knock": 0.0, "kind": "light", "element": "raiton"})), Callable())
	Sfx.play("thunder", at, 1.2)


# ═════════════════════════════════════════ Kaminari Shibari ═════════════════════════════════════════

## Şimşek bağı (kaynak: direkler arasında gerilen saydam mavi elektrik perdesi): hedefin çevresine dört direk düşüp
## saplanır, aralarında saydam elektrik perdeleri açılır, direklerden hedefe bağlayan şimşek zincirleri; süre sonunda söner
static func _cage(pj: PathJutsu, tt: Node3D, dur: float, col: Color) -> void:
	var base = pj.gp(tt.global_position)
	var posts = []
	var stake_b = MB.new()
	stake_b.add("cyl", Vector3(0, 1.3, 0), Vector3(0.12, 2.6, 0.12), Color(0.58, 0.58, 0.62), Vector3.ZERO, 8)
	stake_b.add("cyl", Vector3(0, 1.55, 0), Vector3(0.15, 0.35, 0.15), Color(0.9, 0.72, 0.2), Vector3.ZERO, 8)
	stake_b.add("cyl", Vector3(0, 0.4, 0), Vector3(0.15, 0.2, 0.15), Color(0.9, 0.72, 0.2), Vector3.ZERO, 8)
	var stake_mesh = stake_b.build(Props.toon())
	var a0 = randf() * TAU
	for k in 4:
		var a = a0 + k * TAU / 4.0
		var q = L.floor_at(base + Vector3(cos(a), 0, sin(a)) * 1.4)
		var mi = L.mi_of(stake_mesh, null)
		L.root().add_child(mi)
		mi.global_position = q + Vector3.UP * 3.0
		mi.rotation = Vector3(randf_range(-0.08, 0.08), randf() * TAU, randf_range(-0.08, 0.08))
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", q - Vector3.UP * 0.2, 0.12).set_ease(Tween.EASE_IN)
		tw.tween_interval(dur)
		tw.tween_property(mi, "global_position", q - Vector3.UP * 2.8, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
		posts.append(q)
	pj.after(0.12, func():
		for q in posts:
			L.flash(q + Vector3.UP * 0.2, 0.8, col, 0.1, 6.0)
			L.debris(q, 3, 3.0)
		# perdeler
		for k in 4:
			var A: Vector3 = posts[k]
			var B: Vector3 = posts[(k + 1) % 4]
			var sm = L.mat("sheet", {"glow": col, "power": 0.0})
			var qm = QuadMesh.new()
			qm.size = Vector2(A.distance_to(B), 2.3)
			var sh = L.mi_of(qm, sm)
			L.root().add_child(sh)
			var mid = (A + B) * 0.5 + Vector3.UP * 1.25
			sh.global_position = mid
			var nrm = (B - A).cross(Vector3.UP)
			if nrm.length() > 0.01:
				sh.look_at(mid + nrm.normalized(), Vector3.UP)
			var tw = sh.create_tween()
			tw.tween_property(sm, "shader_parameter/power", 1.0, 0.12)
			tw.tween_interval(maxf(dur - 0.25, 0.1))
			tw.tween_property(sm, "shader_parameter/power", 0.0, 0.3)
			tw.tween_callback(sh.queue_free))
	# direklerden hedefe bağlayan zincir şimşekleri + direk tepeleri arasında çatırtı
	var m = L.arc_mat(col)
	var tf = L.follow_fn(tt, Vector3.UP * 1.0)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur + 0.12:
			return false
		if age < 0.12:
			return true
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var out = []
			var tp: Vector3 = tf.call()
			for k in 4:
				var top: Vector3 = posts[k] + Vector3.UP * randf_range(1.2, 2.3)
				if randf() < 0.8:
					L.fork(top, tp + L.rdir() * 0.25, 0.18, 4, 1, out, 0.045, 1.0)
				if randf() < 0.5:
					L.fork(Vector3(posts[k]) + Vector3.UP * 2.3, Vector3(posts[(k + 1) % 4]) + Vector3.UP * 2.3, 0.15, 3, 0, out, 0.03, 0.8)
			stt["polys"] = out
		L.draw(im, m, stt["polys"], clampf((dur + 0.12 - age) / 0.2, 0.0, 1.0), L.cam_pos())
		return true)


static func kaminari_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	L.bolt(pj.hand_pos(c, true), tt.global_position + Vector3.UP, RAI, 0.2, 0.3, 3)
	pj.st(tt, "bind", 3.0)
	_cage(pj, tt, 3.0, RAI)
	L.body_arcs(tt, 3.0, RAI, 3, 0.03)
	pj.every(3.0, 0.5, func(_i, _k):
		if pj.live(tt):
			L.flash(tt.global_position + Vector3.UP * 1.1, 0.9, RAI, 0.08, 6.0)
			tt.take_hit(pj.inf(c, "raiton_kaminari_shibari", 0.2, {"knock": 0.0, "kind": "light", "element": "raiton"})), Callable())
	Sfx.play("thunder", tt.global_position, 1.3)
