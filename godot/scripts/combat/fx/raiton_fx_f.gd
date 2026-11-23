class_name RaitonFXF
extends RefCounted
## Raiton F grubu (son 10 teknik): görseller sıfırdan, malzeme / yapı taşı RaitonLib'den. Her tekniğin şekli, hareketi ve
## sahnelenmesi kendine özgü (A–E gruplarının kompozisyonları kullanılmaz). Oynanış (hasar çağrıları, durumlar, süreler,
## menzil, hücum / atılma davranışı) ana ağaçtaki PathJutsu / Jutsu / MsArts gövdelerinden satır satır taşındı.
## Dersler: çakmalar küçük mavi-beyaz; şimşek hep dişli (yumuşak şerit yok); parçalar okunur; hiçbir şey ekranı kaplamaz.

const KUROS := Color(0.4, 0.85, 1.0)        # Raiga'nın Kiba şimşeği
const KAKA := Color(0.75, 0.88, 1.0)        # Kakashi'nin Raikiri'si
const NUKITE := Color(0.65, 0.9, 1.0)       # Jigokuzuki
const VIOLET := Color(0.6, 0.3, 1.0)        # Inton Raiha
const VIOLET_L := Color(0.85, 0.7, 1.0)
const FIELD := Color(0.45, 0.85, 1.0)       # Bashōsen şimşek tarlası (kaynak: camgöbeği sütunlar)
const KAMUI_EDGE := Color(0.55, 0.85, 1.0)  # Kamui Raikiri: kara şimşeğin ince mavi konturu

static var _dm := {}


# ═════════════════════════════════════════ ortak küçük parçalar ═════════════════════════════════════════

static func _cam() -> Vector3:
	return RaitonLib.cam_pos()


## Düğümün yerel bir noktasını izleyen nokta (düğüm silinirse son konum)
static func _xf_fn(n: Node3D, local: Vector3) -> Callable:
	var w = weakref(n)
	var mem = {"p": n.global_transform * local if n.is_inside_tree() else Vector3.ZERO}
	return func() -> Vector3:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			mem["p"] = x.global_transform * local
		return mem["p"]


## Kara şimşek malzemesi (kenar + gövde rengi), paylaşılan
static func _dark(edge: Color, body: Color) -> ShaderMaterial:
	var key = edge.to_html() + body.to_html()
	if not _dm.has(key):
		_dm[key] = RaitonLib.mat("dark", {"edge_col": edge, "body_col": body})
	return _dm[key]


## Sabit çizgiler: verilen kırık çizgiler ömür boyunca sönerek kalır
static func _poly(lines: Array, m: Material, life: float, flat := false) -> void:
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		RaitonLib.draw(im, m, lines, pow(1.0 - age / life, 0.8), _cam(), flat)
		return true)


## Işık izi: verilen noktaları (Callable) rec sn kaydeder, son keep sn'lik yolu titreyen kırık çizgi olarak çizer
static func _streak(fns: Array, m: Material, w: float, rec: float, keep: float, jit := 0.07) -> void:
	var paths = []
	for f in fns:
		paths.append([])
	var stt = {"jt": 0.0, "off": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > rec + keep:
			return false
		for i in fns.size():
			var pa: Array = paths[i]
			if age <= rec:
				pa.append({"p": RaitonLib.pt(fns[i]), "t": age})
			while pa.size() > 0 and age - float(pa[0]["t"]) > keep:
				pa.pop_front()
		if age >= float(stt["jt"]):
			stt["jt"] = age + 0.04
			var off = []
			for k in 32:
				off.append(RaitonLib.rdir() * jit)
			stt["off"] = off
		var offs: Array = stt["off"]
		var polys = []
		for pa in paths:
			if pa.size() < 2:
				continue
			var line = []
			for i in pa.size():
				line.append(Vector3(pa[i]["p"]) + Vector3(offs[i % offs.size()]) * (1.0 - float(i) / pa.size()))
			polys.append({"p": line, "w": w, "a": 1.0, "k": 1})
		RaitonLib.draw(im, m, polys, 1.0, _cam())
		return true)


## Yerde kırık ağ çizgileri: merkezden dışa n çizgi (zemine yatık), life'ta söner
static func _ground_cracks(g: Vector3, n: int, r0: float, r1: float, col: Color, life: float) -> void:
	var lines = []
	for k in n:
		var a = TAU * (k + randf_range(-0.3, 0.3)) / n
		var dv = Vector3(cos(a), 0, sin(a))
		lines.append({"p": RaitonLib.ground_path(g + dv * r0 * 0.3, g + dv * randf_range(r0, r1), 0.3, 3), "w": 0.05, "a": 1.0, "k": 1})
	_poly(lines, RaitonLib.web_mat(col), life, true)


# ═════════════════════════════════════════ 1) Kurosuki: Ikazuchi no Kiba ═════════════════════════════════════════

## Raiga'nın iki Kiba kılıcı: ince çelik namlu, üst kenarında testere dişi "diş"ler, koyu sırt şeridi (silueti okunur),
## kınsız sap. Namlu boyunca dişli şimşek teli koşar, uçta çatırtı. Dönüş: kılıç uçlarını izleyen noktalar.
static func _kiba_swords(pj: PathJutsu, c: Node3D, dur: float) -> Array:
	var tips = []
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba == null:
			continue
		var steel = Color(0.8, 0.84, 0.9)
		var b = MB.new()
		b.add("box", Vector3(0, 0, 0.55), Vector3(0.026, 0.075, 0.95), steel)
		b.add("box", Vector3(0, -0.042, 0.55), Vector3(0.03, 0.014, 0.95), Color(0.2, 0.22, 0.28))
		for k in 5:
			b.add("prism", Vector3(0, 0.075, 0.2 + k * 0.18), Vector3(0.14, 0.09, 0.024), steel, Vector3(0, 90, 0), 4)
		b.add("box", Vector3(0, 0, 0.06), Vector3(0.05, 0.13, 0.035), Color(0.15, 0.15, 0.22))
		b.add("cyl", Vector3(0, 0, -0.08), Vector3(0.035, 0.22, 0.035), Color(0.12, 0.12, 0.2), Vector3(90, 0, 0), 6)
		var mi = MeshInstance3D.new()
		mi.mesh = b.build(Props.toon())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(mi)
		var base = _xf_fn(mi, Vector3(0, 0.03, 0.12))
		var tip = _xf_fn(mi, Vector3(0, 0.03, 1.05))
		RaitonLib.bolt(base, tip, KUROS, 0.035, dur, 1, 0.14, 0.05, 3)
		RaitonLib.crackle(tip, 0.25, dur, KUROS, 3, 0.025, 0.05, mi)
		tips.append(tip)
		pj.free_after(dur, ba)
	return tips


## Kara fırtına bulutu: yassı, koyu gri cel topaklar (opak, okunur); karnında kısa çakmalar ve yanıp sönen ışık
static func _storm_cloud(at: Vector3, r: float, dur: float) -> void:
	var root_n = Node3D.new()
	RaitonLib.root().add_child(root_n)
	root_n.global_position = at
	var b = MB.new()
	for k in 14:
		var a = randf() * TAU
		var rr = r * sqrt(randf())
		var s = randf_range(1.6, 3.0) * (1.0 - rr / r * 0.4)
		b.add("sphere", Vector3(cos(a) * rr, randf_range(-0.3, 0.5), sin(a) * rr), Vector3(s, s * 0.55, s),
			Color(0.13, 0.13, 0.17).lerp(Color(0.26, 0.26, 0.32), randf()), Vector3.ZERO, 10)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_n.add_child(mi)
	root_n.scale = Vector3.ONE * 0.2
	var tw = root_n.create_tween()
	tw.tween_property(root_n, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.7, 0.1))
	tw.tween_property(root_n, "scale", Vector3(1.3, 0.05, 1.3), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(root_n.queue_free)
	var stt = {"next": 0.0}
	var p = RaitonLib.Pulse.new()
	p.fn = func(node, _dt, age) -> bool:
		if age > dur - 0.4:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.08, 0.2)
			var q = node.global_position + RaitonLib.hdir() * r * randf_range(0.0, 0.8) - Vector3.UP * 0.4
			RaitonLib.bolt(q, q + RaitonLib.hdir() * randf_range(1.0, 2.5) - Vector3.UP * 0.3, KUROS, 0.05, 0.12, 1, 0.3)
			RaitonLib.light(q, KUROS, 2.0, 10.0, 0.12)
		return true
	root_n.add_child(p)


## Diş darbesi: buluttan iki ayrı noktadan inen iki şimşek tek noktada birleşir (açık çene gibi);
## yerde küçük çakma, yukarı saçılan kıvılcım, yanık ve sürünen ark
static func _fang_strike(top: Vector3, p: Vector3) -> void:
	var side = RaitonLib.hdir()
	var g = RaitonLib.floor_at(p)
	RaitonLib.bolt(top + side * 1.6, g, KUROS, 0.22, 0.32, 3, 0.16, 0.05, 5)
	RaitonLib.bolt(top - side * 1.6, g, RaitonLib.PALE, 0.12, 0.26, 1, 0.2, 0.05, 4)
	RaitonLib.flash(g + Vector3.UP * 0.5, 1.1, KUROS, 0.12, 7.0)
	RaitonLib.sparks(g + Vector3.UP * 0.2, 14, KUROS, 9.0, 0.45, Vector3.UP, 0.8)
	RaitonLib.scorch(g, 1.2, KUROS, 4.0, 0.8)
	RaitonLib.ground_arcs(g, 1.4, 0.5, KUROS, 4, 0.04)
	RaitonLib.light(g + Vector3.UP, KUROS, 6.0, 14.0, 0.25)


static func kurosuki_ikazuchi_kiba(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tips = []
	if pj._held_or(c, "") != "kiba":
		tips = _kiba_swords(pj, c, 0.9)
	if tips.is_empty():
		tips = [RaitonLib.hand_fn(pj, c, true), RaitonLib.hand_fn(pj, c, false)]
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var top = at + Vector3.UP * 12.0
	# kılıçlar kalkar: iki namludan göğe dişli akım yükselir
	for tp in tips:
		RaitonLib.converge(tp, 0.6, 0.3, KUROS, 6, 0.02)
		var sky = func() -> Vector3:
			return RaitonLib.pt(tp) + Vector3.UP * 12.0
		RaitonLib.bolt(tp, sky, KUROS, 0.07, 0.4, 2, 0.14, 0.05, 5)
	_storm_cloud(top, 4.0, 2.0)
	for k in 5:
		pj.after(0.35 + k * 0.12, func():
			var p = at + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
			_fang_strike(top, p)
			RaitonLib.wet_shock(p + Vector3.UP * 0.4, 0.9)
			pj.hit(c, p + Vector3.UP, 2.0, pj.inf(c, "kurosuki_ikazuchi_kiba", 0.55, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.3})))
	Sfx.play("thunder", at, 1.0)


# ═════════════════════════════════════════ 2) Raigyaku Suihei ═════════════════════════════════════════

## Kol şimşekle kaplanır: dirsekten parmak uçlarına koşan, sürekli yeniden kırılan üç tel (kolun kendisi bıçak olur)
static func _arm_coat(pj: PathJutsu, c: Node3D, dur: float, col: Color) -> void:
	var hb = pj.bone_attach(c, "RightHand")
	var lb = pj.bone_attach(c, "RightLowerArm")
	if hb == null or lb == null:
		if hb:
			hb.queue_free()
		if lb:
			lb.queue_free()
		RaitonLib.crackle(RaitonLib.hand_fn(pj, c), 0.4, dur, col, 5, 0.03)
		return
	var h = _xf_fn(hb, Vector3(0, 0.12, 0))
	var e = RaitonLib.follow_fn(lb)
	RaitonLib.bolt(e, h, RaitonLib.PALE, 0.05, dur, 1, 0.22, 0.04, 3)
	RaitonLib.bolt(e, h, col, 0.04, dur, 1, 0.3, 0.05, 3)
	RaitonLib.bolt(e, h, col, 0.03, dur, 0, 0.35, 0.06, 3)
	RaitonLib.crackle(h, 0.32, dur, col, 4, 0.03, 0.05, hb)
	pj.free_after(dur, hb)
	pj.free_after(dur, lb)


## Yatay biçme cephesi: 160° yay hızla açılır ve dışa genişler; cephe testere dişi gibi sert kırık (yumuşak şerit değil),
## arkasında iki ince yankı yayı
static func _cleave_front(at: Vector3, d: Vector3, a0: float, a1: float, r0: float, r1: float, dur: float, col: Color) -> void:
	var m = RaitonLib.arc_mat(col)
	var stt = {"next": 0.0, "polys": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = age / dur
		var op = 1.0 - pow(1.0 - minf(f / 0.35, 1.0), 3.0)
		var r = lerpf(r0, r1, 1.0 - pow(1.0 - f, 2.0))
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var amax = lerpf(a0, a1, op)
			var polys = []
			for layer in 3:
				var rl = r * (1.0 - layer * 0.22)
				var n = 22 - layer * 5
				var line = []
				for i in n + 1:
					var a = deg_to_rad(lerpf(a0, amax, float(i) / n))
					var rr = rl * (1.0 + (0.07 if i % 2 == 0 else -0.07) * randf_range(0.5, 1.2))
					line.append(at + d.rotated(Vector3.UP, a) * rr + Vector3.UP * randf_range(-0.1, 0.1))
				polys.append({"p": line, "w": 0.09 - layer * 0.025, "a": 1.0 - layer * 0.3, "k": 0})
			stt["polys"] = polys
		RaitonLib.draw(im, m, stt["polys"], pow(1.0 - f, 0.6), _cam())
		return true)


static func raigyaku_suihei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	_arm_coat(pj, c, 0.6, RaitonLib.RAI)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_a", 1.6)
		var at = c.global_position + Vector3.UP * 1.3
		_cleave_front(at, d, -80.0, 80.0, 1.2, 4.8, 0.32, RaitonLib.RAI)
		for k in 5:
			var dir = d.rotated(Vector3.UP, deg_to_rad(lerpf(-70.0, 70.0, k / 4.0)))
			var e = at + dir * 4.5
			RaitonLib.zig_bolt(at + dir * 1.0, e, RaitonLib.PALE, 0.05, 0.22, 4, 0.25)
			RaitonLib.sparks(e, 5, RaitonLib.RAI, 6.0, 0.3, dir, 0.5)
		RaitonLib.dust_ring(pj.gp(c.global_position), 0.6, 3.2, 0.55)
		pj.shake(0.4)
		Combat.hit_zone(c, c.global_position, d, 5.0, 160.0, 2.0, pj.inf(c, "raigyaku_suihei", 1.8, {"knock": 14.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "dir": d})))
	Sfx.play("chidori", c.global_position, 1.0)


# ═════════════════════════════════════════ 3) Chidori Kōken ═════════════════════════════════════════

## Kaynak (Sasuke): kılıçtan uzayan uzun, kalın, dişli beyaz-camgöbeği şimşek bıçağı. Kabzadan kılıç doğrultusunda (el +Y)
## 0.3 → 3.5 m uzar; beyaz öz + dallı camgöbeği dış tel, sürekli yeniden kırılır.
static func _koken_blade(ba: Node3D, dur: float) -> void:
	var bw = weakref(ba)
	var mc = RaitonLib.arc_mat(RaitonLib.CYAN)
	var mw = RaitonLib.arc_mat(RaitonLib.PALE)
	var stt = {"next": 0.0, "out": [], "core": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var b = bw.get_ref()
		if age > dur or b == null or not is_instance_valid(b) or not b.is_inside_tree():
			return false
		var L = lerpf(0.3, 3.5, 1.0 - pow(1.0 - minf(age / 0.3, 1.0), 2.0))
		var xf: Transform3D = b.global_transform
		var a = xf * Vector3(0, 0.08, 0)
		var e = a + xf.basis.y.normalized() * L
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var out = []
			RaitonLib.fork(a, e, 0.09, 4, 2, out, 0.1, 1.0)
			stt["out"] = out
			stt["core"] = [{"p": RaitonLib.jag(a, e, 0.05, 3), "w": 0.035, "a": 1.0, "k": 3}]
		var fade = clampf((dur - age) / 0.15, 0.0, 1.0)
		RaitonLib.draw(im, mc, stt["out"], fade, _cam())
		RaitonLib.draw(im, mw, stt["core"], fade, _cam())
		return true)


## Savuruş: 3.5–4 m'lik şimşek bıçağı 120° yayı süpürür; geçtiği açılarda kısa ömürlü dişli yankılar kalır,
## uç yere değdiği hatta ince yanık ağı bırakır
static func _koken_sweep(pj: PathJutsu, at: Vector3, d: Vector3, a0: float, a1: float, L: float) -> void:
	var mc = RaitonLib.arc_mat(RaitonLib.CYAN)
	var mw = RaitonLib.arc_mat(RaitonLib.PALE)
	var stt = {"next": 0.0, "blade": [], "core": [], "echo": []}
	var swing = 0.12
	var life = 0.34
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var f = clampf(age / swing, 0.0, 1.0)
		var e = 1.0 - pow(1.0 - f, 2.5)
		var dir = d.rotated(Vector3.UP, deg_to_rad(lerpf(a0, a1, e)))
		var a = at + dir * 0.6
		var b = at + dir * L - Vector3.UP * (0.25 * sin(PI * e))
		if age >= float(stt["next"]):
			stt["next"] = age + 0.035
			var out = []
			RaitonLib.fork(a, b, 0.08, 4, 2, out, 0.11, 1.0)
			stt["blade"] = out
			stt["core"] = [{"p": RaitonLib.jag(a, b, 0.04, 3), "w": 0.04, "a": 1.0, "k": 3}]
			if f < 1.0:
				(stt["echo"] as Array).append({"p": RaitonLib.jag(a, b, 0.12, 3), "w": 0.06, "t": age})
		var polys = []
		for ec in stt["echo"]:
			var k = 1.0 - (age - float(ec["t"])) / 0.18
			if k > 0.0:
				polys.append({"p": ec["p"], "w": ec["w"], "a": k * 0.6, "k": 3})
		polys.append_array(stt["blade"])
		var fade = clampf((life - age) / 0.12, 0.0, 1.0)
		RaitonLib.draw(im, mc, polys, fade, _cam())
		RaitonLib.draw(im, mw, stt["core"], fade, _cam())
		return true)
	pj.after(swing, func():
		var tip = at + d.rotated(Vector3.UP, deg_to_rad(a1)) * L
		RaitonLib.sparks(tip, 12, RaitonLib.RAI, 8.0, 0.35, d.rotated(Vector3.UP, deg_to_rad(a1 + 90.0)), 0.6)
		RaitonLib.flash(tip, 0.7, RaitonLib.RAI, 0.08, 7.0)
		var scar = []
		for i in 8:
			var p0 = at + d.rotated(Vector3.UP, deg_to_rad(lerpf(a0, a1, i / 8.0))) * L
			var p1 = at + d.rotated(Vector3.UP, deg_to_rad(lerpf(a0, a1, (i + 1) / 8.0))) * L
			var seg = RaitonLib.ground_path(p0, p1, 0.2, 2)
			if not scar.is_empty():
				seg.pop_front()
			scar.append_array(seg)
		_poly([{"p": scar, "w": 0.06, "a": 1.0, "k": 2}], RaitonLib.web_mat(RaitonLib.RAI), 1.4, true))


static func chidori_koken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		_koken_blade(ba, 0.8)
		RaitonLib.crackle(RaitonLib.follow_fn(ba), 0.3, 0.8, RaitonLib.RAI, 4, 0.03, 0.04, ba)
		pj.free_after(0.8, ba)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 1.5)
		var at = c.global_position + Vector3.UP * 1.2
		_koken_sweep(pj, at, d, -60.0, 60.0, 4.0)
		Combat.hit_zone(c, c.global_position, d, 4.5, 120.0, 2.0, pj.inf(c, "chidori_koken", 1.8, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8, "dir": d})))
	Sfx.play("chidori", c.global_position, 1.1)


# ═════════════════════════════════════════ 4) Kamui Raikiri ═════════════════════════════════════════

## Kaynak (Kakashi, Susanoo'lu Kamui): eli ve önkolu saran kalın, opak SİYAH dişli şimşek dikenleri, ince mavi konturlu;
## hepsi parmakların önünde tek sivri uçta birleşir. Elin önünde Kamui girdabı (koyu sarmal çizgiler içe çekilir).
static func _kamui_hand(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		RaitonLib.crackle(RaitonLib.hand_fn(pj, c), 0.4, dur, KAMUI_EDGE, 5, 0.04)
		return
	var dm = _dark(KAMUI_EDGE, Color(0.02, 0.02, 0.05))
	var bw = weakref(ba)
	var stt = {"next": 0.0, "polys": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var b = bw.get_ref()
		if age > dur or b == null or not is_instance_valid(b) or not b.is_inside_tree():
			return false
		var xf = Transform3D(b.global_transform.basis.orthonormalized(), b.global_transform.origin)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var out = []
			var tip = Vector3(0, 0.85, 0)
			for k in 7:
				var a = TAU * k / 7.0 + randf_range(-0.3, 0.3)
				var r = randf_range(0.1, 0.24)
				var s = Vector3(cos(a) * r, randf_range(-0.35, 0.05), sin(a) * r)
				out.append({"p": RaitonLib.jag(tip, s, 0.2, 3), "w": randf_range(0.035, 0.06), "a": 1.0})
			stt["polys"] = out
		var polys = []
		for pl in stt["polys"]:
			var wp = []
			for q in pl["p"]:
				wp.append(xf * Vector3(q))
			polys.append({"p": wp, "w": pl["w"], "a": pl["a"], "k": 1})
		RaitonLib.draw(im, dm, polys, clampf((dur - age) / 0.12, 0.0, 1.0), _cam())
		return true)
	_kamui_spiral(_xf_fn(ba, Vector3(0, 0.15, 0.15)), 0.35, dur)
	pj.free_after(dur + 0.05, ba)


## Kamui girdabı: kameraya dönük üç kollu koyu sarmal; kollar dönerek merkeze çekilir (kenarları dişli titrer)
static func _kamui_spiral(center, r: float, dur: float) -> void:
	var dm = _dark(Color(0.6, 0.75, 0.95), Color(0.03, 0.03, 0.06))
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var c0 = RaitonLib.pt(center)
		var v = (_cam() - c0).normalized()
		var bx = v.cross(Vector3.UP)
		bx = bx.normalized() if bx.length_squared() > 0.0001 else Vector3.RIGHT
		var by = bx.cross(v).normalized()
		var f = age / dur
		var polys = []
		for j in 3:
			var line = []
			for i in 15:
				var q = float(i) / 14.0
				var rad = r * (1.0 - q) * (1.0 - 0.35 * f)
				var ang = j * TAU / 3.0 + q * 5.0 + age * 9.0
				line.append(c0 + (bx * cos(ang) + by * sin(ang)) * rad + RaitonLib.rdir() * r * 0.03)
			polys.append({"p": line, "w": r * 0.07, "a": 1.0, "k": 1})
		RaitonLib.draw(im, dm, polys, clampf((dur - age) / 0.15, 0.0, 1.0) * minf(age / 0.08, 1.0), _cam())
		return true)


static func kamui_raikiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.1)
	_kamui_hand(pj, c, 0.9)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		if c is Player:
			c.combat.invuln = maxf(c.combat.invuln, 0.35)   # geçirgen yaklaşma
		var m = c.get("model")
		MsArts.ghost(m, 0.5)
		pj.after(0.3, func(): MsArts.ghost(m, 0.0))
		var d = pj.fwd(c, tt)
		var dest = pj.gp(tt.global_position - d * 1.1) if pj.live(tt) else pj.gp(c.global_position + d * 8.0)
		pj._face(c, tt)
		pj.anim(c, "dash", 1.6)
		var from = c.global_position
		_streak([RaitonLib.hand_fn(pj, c)], _dark(KAMUI_EDGE, Color(0.02, 0.02, 0.05)), 0.09, 0.34, 0.2, 0.1)
		var dash = c.create_tween()
		dash.tween_method(func(x: float):
			if pj.live(c):
				var q = from.lerp(dest, x)
				q.y = maxf(q.y, Game.jutsu_floor_at(q).y)
				c.global_position = q
				if "velocity" in c:
					c.velocity = Vector3.ZERO, 0.0, 1.0, 0.16)
		pj.after(0.18, func():
			if not pj.live(c):
				return
			pj.anim(c, "jab", 2.0)
			var at = c.global_position + Vector3.UP * 1.1 + d * 1.2
			RaitonLib.wet_shock(at, 1.6)
			var dm = _dark(KAMUI_EDGE, Color(0.02, 0.02, 0.05))
			# delip geçen kara diken + çevreye saçılan kara dallar
			RaitonLib.bolt_m(at - d * 0.4, at + d * 6.0, dm, 0.14, 0.32, 1, 0.08, 0.05, 4)
			for k in 7:
				var dd = (d * 0.9 + RaitonLib.rdir()).normalized()
				RaitonLib.bolt_m(at, at + dd * randf_range(1.5, 3.2), dm, 0.07, 0.26, 1, 0.22, 0.05, 3)
			RaitonLib.flash(at, 1.0, RaitonLib.PALE, 0.1, 8.0)
			RaitonLib.light(at, KAMUI_EDGE, 6.0, 12.0, 0.25)
			var kinf = pj.inf(c, "kamui_raikiri", 3.0, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.8, "hitstop": 0.12})
			var hs = pj.enemies_near(c, at, 2.4)
			for h in hs:
				MsArts.kamui_warp(c, h, kinf, at)
			if hs.is_empty():
				_kamui_spiral(at, 1.2, 0.5)
			pj.shake(0.6)))
	Sfx.play("chidori", c.global_position, 1.0)


# ═════════════════════════════════════════ 5) Raikiri ═════════════════════════════════════════

## Kaynak (Kakashi, klasik): avuçta kör edici küçük beyaz öz; çevresinden her yöne UZUN, ince, dallı şimşek kolları
## (örümcek bacağı gibi) kesik kesik fırlar — Chidori'nin sık cıvıltısından farklı: az ama uzun, uzağa uzanan teller.
static func _raikiri_hand(c: Node3D) -> Node3D:
	var hand: Node3D = Node3D.new()
	Jutsu._palm(c, hand)
	hand.add_child(RaitonLib.orb(0.12, Color(1, 1, 1), RaitonLib.PALE, KAKA))
	RaitonLib.crackle(RaitonLib.follow_fn(hand), 0.3, 30.0, RaitonLib.PALE, 5, 0.03, 0.03, hand)
	_raikiri_legs(hand)
	var l = OmniLight3D.new()
	l.light_color = KAKA
	l.light_energy = 2.6
	l.omni_range = 7.0
	l.shadow_enabled = false
	hand.add_child(l)
	Sfx.play("chidori", c.global_position)
	return hand


static func _raikiri_legs(hand: Node3D) -> void:
	var stt = {"next": 0.0}
	var p = RaitonLib.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(hand) or not hand.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.06, 0.11)
			var o = hand.global_position
			var away = o - _cam()
			for k in randi_range(2, 3):
				var dv = RaitonLib.rdir()
				if dv.dot(away) < 0.0:
					dv = -dv   # kameraya doğru uzanmasın (ekranı kaplamaz)
				dv.y = absf(dv.y) * 0.7 + 0.1
				RaitonLib.bolt(o, o + dv.normalized() * randf_range(2.0, 4.0), KAKA, 0.03, 0.1, 2, 0.17, 0.1, 5)
		return true
	hand.add_child(p)


## Hücumda: avucun önünde ileri uzanan kısa, düz kesici ağız (beyaz öz) + geriye savrulan üç tel. Elle birlikte taşınır
## (yerel ofsetler her kare elin konumuna eklenir: hızda geride kalmaz)
static func _raikiri_lance(hand: Node3D, state: Dictionary) -> void:
	var hw = weakref(hand)
	var mc = RaitonLib.arc_mat(KAKA)
	var mw = RaitonLib.arc_mat(RaitonLib.PALE)
	var stt = {"next": 0.0, "edge": [], "back": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var h = hw.get_ref()
		if bool(state["done"]) or age > 1.0 or h == null or not is_instance_valid(h) or not h.is_inside_tree():
			return false
		var d: Vector3 = state.get("d", Vector3.FORWARD)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.035
			stt["edge"] = [{"p": RaitonLib.jag(Vector3.ZERO, d * 1.5, 0.05, 3), "w": 0.05, "a": 1.0, "k": 3}]
			var back = []
			for k in 3:
				back.append({"p": RaitonLib.jag(Vector3.ZERO, -d * randf_range(2.0, 3.4) + RaitonLib.rdir() * 0.5, 0.2, 3), "w": 0.05, "a": 0.9, "k": 0})
			stt["back"] = back
		var hp: Vector3 = h.global_position
		var e = []
		for pl in stt["edge"]:
			var wp = []
			for q in pl["p"]:
				wp.append(hp + Vector3(q))
			e.append({"p": wp, "w": pl["w"], "a": pl["a"], "k": pl["k"]})
		var bk = []
		for pl in stt["back"]:
			var wp = []
			for q in pl["p"]:
				wp.append(hp + Vector3(q))
			bk.append({"p": wp, "w": pl["w"], "a": pl["a"], "k": pl["k"]})
		RaitonLib.draw(im, mc, bk, 1.0, _cam())
		RaitonLib.draw(im, mw, e, 1.0, _cam())
		return true)


## İsabet — "şimşeği kesen": hedefin içinden ileri delip geçen dar telli şimşek + hedefin üstünden çapraz inen keskin,
## düz beyaz kesik çizgisi; küçük çakma, öne saçılan kıvılcım, yerde yanık ve kırıntı
static func _raikiri_cut(pj: PathJutsu, pt: Vector3, d: Vector3, col: Color) -> void:
	for k in 4:
		var dd = (d * 2.0 + RaitonLib.rdir() * 0.5).normalized()
		RaitonLib.bolt(pt, pt + dd * randf_range(4.0, 7.0), col, 0.12, 0.28, 2, 0.15)
	var side = d.cross(Vector3.UP).normalized()
	var cut_dir = (side * cos(0.5) + Vector3.UP * sin(0.5)).normalized()
	var a = pt - cut_dir * 1.4
	var b = pt + cut_dir * 1.4
	_poly([{"p": [a, b], "w": 0.05, "a": 1.0, "k": 3}, {"p": RaitonLib.zigzag(a, b, 5, 0.12), "w": 0.03, "a": 0.8, "k": 3}], RaitonLib.arc_mat(RaitonLib.PALE), 0.3)
	RaitonLib.flash(pt, 1.4, KAKA, 0.12, 11.0)
	RaitonLib.sparks(pt, 28, RaitonLib.PALE, 14.0, 0.45, d, 0.5)
	var g = RaitonLib.floor_at(pt)
	RaitonLib.scorch(g, 2.0, KAKA, 6.0, 1.0)
	RaitonLib.debris(g, 8, 10.0, Color(0.5, 0.42, 0.32), d)
	RaitonLib.light(pt, col, 10.0, 18.0, 0.4)
	pj.shake(1.0)


## Elde hücum (Jutsu._hand_dash'in oynanışı birebir: hazırlık, koşu pozu, her kare hedefe yön, 1 m küre isabeti, 0.6 sn sınır)
static func _raikiri_dash(pj: PathJutsu, c: Node3D, t: Node3D, hand: Node3D, charge: float, speed: float, info: Dictionary, col: Color) -> void:
	var tid: int = t.get_instance_id() if is_instance_valid(t) else 0   # silinen hedefi yakalamasın
	var tw = c.create_tween()
	tw.tween_interval(charge)
	var state = {"t": 0.0, "done": false}
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
				state["done"] = true
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
			state["d"] = d
			c.velocity = d * speed
			if c is Player:
				c.combat.action = "cast"
				c.combat.t = -10.0
			if c.get("model"):
				if not state.has("ran"):
					state["ran"] = true
					Jutsu._pose_chidori_run(c)
				c.model.play("run", 0.08, 1.9)
			if not state.has("lance") and is_instance_valid(hand):
				state["lance"] = true
				_raikiri_lance(hand, state)
			var pt = c.global_position + Vector3.UP * 1.1 + d * 1.0
			var hits = Combat.hit_sphere(c, pt, 1.0, info)
			if not hits.is_empty() or state["t"] > 0.6:
				state["done"] = true
				Jutsu._palm_release(c)
				if is_instance_valid(c) and c.get("model") and c.model.get("overlay"):
					c.model.overlay.set_pose("cast", 0.0)
				if c is Player:
					c.combat.action = ""
				c.velocity = Vector3.ZERO
				if not hits.is_empty():
					_raikiri_cut(pj, pt, d, col)
					Sfx.play("boom", pt, 1.2)
				var h = hand
				if is_instance_valid(h):
					var tw2 = h.create_tween()
					tw2.tween_property(h, "scale", Vector3.ONE * 0.01, 0.2)
					tw2.tween_callback(h.queue_free)
				timer.queue_free())
		timer.start())


static func raikiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c) * Jutsu._elem_bonus(c, "raiton")
	# kanon: Sharingan olmadan güvenle kullanılamaz (tünel görüşü). Sharingan yoksa: hasar düşük ve karşı darbeye açık
	var has_sh = false
	if c is Player and c.combat and c.combat.modes and c.combat.modes.get("eyes"):
		var ey = c.combat.modes.eyes
		has_sh = ey.active and (ey._kind("sag") in [1, 4, 5] or ey._kind("sol") in [1, 4, 5])
	elif c.has_meta("eyes"):
		has_sh = int(c.get_meta("eyes").get("kind", 0)) in [1, 4, 5]
	if not has_sh:
		m *= 0.75
		if c is Player:
			Hud.msg("Sharingan olmadan Raikiri: tünel görüşü — karşı saldırıya açıksın!", Color(1, 0.7, 0.4), 2.0)
			Buffs.add("tunel_gorus", 2.5, {"armor": 1.4, "_name": "Tünel Görüşü"})
	var hand = _raikiri_hand(c)
	hand.scale = Vector3.ONE * 1.25
	Jutsu._pose_chidori_charge(c)
	_raikiri_dash(pj, c, t, hand, 0.5, 36.0, {"dmg": 40.0 * m, "element": "raiton", "knock": 16.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.14, "stun": 1.2}, KAKA)
	# hazırlıkta ayak dibinde sürünen arklar; hücuma çıkarken dağlanmış iz kalır
	if pj.live(c):
		RaitonLib.ground_arcs(pj.gp(c.global_position), 1.1, 0.5, KAKA, 5, 0.04)
	pj.after(0.5, func():
		if pj.live(c):
			RaitonLib.scorch(pj.gp(c.global_position), 1.6, KAKA, 5.0, 0.8))


# ═════════════════════════════════════════ 6) Raikiri: Sōraishin ═════════════════════════════════════════

## Raikiri ikiye bölünür: iki elde birer küçük beyaz plazma + çatırtı + ışık
static func _twin_raikiri(pj: PathJutsu, c: Node3D, dur: float, size := 0.4) -> void:
	for bn in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, bn)
		if ba == null:
			continue
		ba.add_child(RaitonLib.orb(size * 0.3, Color(1, 1, 1), KAKA, RaitonLib.PALE))
		RaitonLib.crackle(RaitonLib.follow_fn(ba), size * 1.0, dur, KAKA, 5, 0.03, 0.04, ba)
		var l = OmniLight3D.new()
		l.light_color = KAKA
		l.light_energy = 1.6
		l.omni_range = 4.0
		l.shadow_enabled = false
		ba.add_child(l)
		if not c is ShadowClone:   # klonun eki klonla birlikte silinir
			pj.free_after(dur, ba)


## Topraktan çıkış / dalış: dışa açılan toz halkası + kırıntı
static func _earth_burst(g: Vector3, s: float) -> void:
	RaitonLib.dust_ring(g, 0.3, 2.2 * s, 0.6)
	RaitonLib.debris(g, int(7 * s), 7.0 * s, Color(0.5, 0.42, 0.32))


## Kaynak: göğe dikilen düz şimşek omurgası ve onu sağdan sola kesen keskin, düz parçalı zikzak ışık izi.
## Havadaki her vuruş zincire bir köşe ekler; son darbede zincirin tamamı + dikey omurga birlikte yanar.
static func raikiri_soraishin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Raikiri: Sōraishin: hedef yok", Color(0.8, 0.9, 1.0))
		return
	pj.busy(c, 2.5)
	var id = "raikiri_soraishin"
	var cw = weakref(c)
	var tw = weakref(tt)
	var d = pj._face(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	var chain = {"pts": []}
	# 1) toprağa dalar, hedefin dibinden çıkar: çeneye yumruk
	_earth_burst(pj.gp(c.global_position), 0.8)
	c.global_position = pj.gp(tt.global_position - d * 1.1)
	_earth_burst(pj.gp(c.global_position), 1.4)
	Sfx.play("earth", c.global_position, 1.2)
	pj.anim(c, "hook", 2.0)
	tt.take_hit(pj.inf(c, id, 0.3, {"knock": 0.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.06, "stun": 2.4, "melee": true}))
	# 2) geri sıçrar: iki elin arasında Raikiri, ikiye bölünür
	var back = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = -d * 15.0 + Vector3.UP * 4.0
		pj.anim(cc, "seal", 1.6)
		_twin_raikiri(pj, cc, 2.1)
		var hr = RaitonLib.hand_fn(pj, cc, true)
		var hl = RaitonLib.hand_fn(pj, cc, false)
		RaitonLib.zig_bolt(hr, hl, RaitonLib.PALE, 0.05, 0.3, 4, 0.12)   # tek kütle iki ele yarılır
		RaitonLib.flash((pj.hand_pos(cc, true) + pj.hand_pos(cc, false)) * 0.5, 0.8, KAKA, 0.1, 9.0)
		Sfx.play("chidori", cc.global_position, 1.1)
	pj.after(0.22, back)
	# 3) dalış: iki ışık izi; ilk Raikiri havaya atar
	var dive = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var dd = pj._jump_at(cc, x, 0.0, 40.0)
		pj.anim(cc, "cross", 2.0)
		_streak([RaitonLib.hand_fn(pj, cc, true), RaitonLib.hand_fn(pj, cc, false)], RaitonLib.arc_mat(KAKA), 0.07, 0.32, 0.22, 0.06)
		var s3 = {"hit": false}
		var run = func(_i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2) or s3["hit"]:
				return
			if c2.global_position.distance_to(x2.global_position) < 2.0:
				s3["hit"] = true
				if c2 is CharacterBody3D:
					c2.velocity = Vector3.ZERO
				var o = x2.global_position + Vector3.UP * 1.1
				x2.take_hit(pj.inf(c2, id, 0.7, {"knock": 0.0, "launch": 13.0, "kind": "heavy", "element": "raiton", "hitstop": 0.1, "stun": 2.0, "melee": true}))
				RaitonLib.flash(o, 1.2, KAKA, 0.1, 9.0)
				RaitonLib.sparks(o, 16, RaitonLib.PALE, 10.0, 0.4, Vector3.UP, 0.6)
				(chain["pts"] as Array).append(o)
				Sfx.play("thunder", o, 1.4)
		pj.every(0.32, 1.0 / 60.0, run, Callable())
	pj.after(0.72, dive)
	# 4) havada zikzak: bir sağdan bir soldan — her geçiş düz, sert bir ışık çizgisi
	var prev = {"p": Vector3.ZERO}
	var lm = RaitonLib.arc_mat(KAKA)
	for k in 4:
		var zig = func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x):
				return
			if "velocity" in x:
				x.velocity = Vector3.UP * 5.0
			var sgn = 1.0 if k % 2 == 0 else -1.0
			var np = x.global_position + side * sgn * 1.3 + Vector3.UP * 0.3
			var from: Vector3 = prev["p"] if k > 0 else cc.global_position + Vector3.UP * 1.1
			cc.global_position = np
			if cc is CharacterBody3D:
				cc.velocity = Vector3.UP * 2.0
			pj._face(cc, x)
			prev["p"] = np + Vector3.UP * 1.1
			var to = np + Vector3.UP * 1.1
			_poly([{"p": [from, to], "w": 0.08, "a": 1.0, "k": 2}, {"p": [from + RaitonLib.rdir() * 0.06, to + RaitonLib.rdir() * 0.06], "w": 0.03, "a": 0.7, "k": 2}], lm, 0.4)
			(chain["pts"] as Array).append(to)
			pj.anim(cc, "cross" if k % 2 == 0 else "hook", 2.4)
			x.take_hit(pj.inf(cc, id, 0.2, {"knock": 0.0, "launch": 3.0, "kind": "light", "element": "raiton", "hitstop": 0.04, "melee": true}))
			RaitonLib.flash(x.global_position + Vector3.UP * 1.1, 0.7, KAKA, 0.08, 7.0)
			Sfx.play("chidori", np, 1.6, 0.4)
		pj.after(1.12 + k * 0.17, zig)
	# 5) tepeden ikinci Raikiri: yere çakar — zincirin tamamı ve dikey omurga yanar
	var slam = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		cc.global_position = x.global_position + Vector3.UP * 1.7 - d * 0.3
		if cc is CharacterBody3D:
			cc.velocity = Vector3.DOWN * 18.0
		pj.anim(cc, "cross", 1.8)
		var g = pj.gp(x.global_position)
		x.take_hit(pj.inf(cc, id, 1.0, {"knock": 0.0, "launch": -24.0, "kind": "heavy", "element": "raiton", "hitstop": 0.16, "stun": 1.0, "melee": true, "attacker": cc}))
		var pts: Array = chain["pts"]
		var top = g + Vector3.UP * 3.5
		for q in pts:
			top.y = maxf(top.y, Vector3(q).y + 1.0)
		if pts.size() >= 2:
			_poly([{"p": pts.duplicate(), "w": 0.07, "a": 1.0, "k": 2}], lm, 0.7)
		RaitonLib.bolt(top, g, RaitonLib.PALE, 0.16, 0.4, 1, 0.05, 0.05, 4)
		RaitonLib.bolt(top, g, KAKA, 0.08, 0.35, 0, 0.09, 0.05, 4)
		RaitonLib.flash(g + Vector3.UP * 0.5, 1.6, KAKA, 0.14, 12.0)
		RaitonLib.scorch(g, 2.4, KAKA, 6.0, 1.2)
		_ground_cracks(g, 6, 1.5, 3.5, KAKA, 1.0)
		_earth_burst(g, 1.2)
		pj.shake(0.9)
		Sfx.play("thunder", g, 1.0)
	pj.after(1.12 + 4 * 0.17 + 0.14, slam)


# ═════════════════════════════════════════ 7) Jigokuzuki: Ippon Nukite ═════════════════════════════════════════

## Tek parmak ucunda iğne: el ucunun önünde çok ince, neredeyse düz uzun şimşek mızrağı (beyaz öz + ince camgöbeği hâle),
## arkasında ince iz; isabete dek elle taşınır
static func _needle(pj: PathJutsu, c: Node3D, d: Vector3, state: Dictionary, dur: float) -> void:
	var cw = weakref(c)
	var mc = RaitonLib.arc_mat(NUKITE)
	var mw = RaitonLib.arc_mat(RaitonLib.PALE)
	var stt = {"next": 0.0, "halo": [], "core": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur or bool(state["hit"]) or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			stt["halo"] = [{"p": RaitonLib.jag(-d * 1.4, d * 0.9, 0.04, 3), "w": 0.07, "a": 0.8, "k": 1}]
			stt["core"] = [{"p": RaitonLib.jag(-d * 0.3, d * 1.1, 0.015, 2), "w": 0.025, "a": 1.0, "k": 3}]
		var hp = pj.live_hand(x)
		var polys = []
		for grp in [stt["halo"], stt["core"]]:
			var out = []
			for pl in grp:
				var wp = []
				for q in pl["p"]:
					wp.append(hp + Vector3(q))
				out.append({"p": wp, "w": pl["w"], "a": pl["a"], "k": pl["k"]})
			polys.append(out)
		RaitonLib.draw(im, mc, polys[0], 1.0, _cam())
		RaitonLib.draw(im, mw, polys[1], 1.0, _cam())
		return true)


## Delip geçen tek mızrak: hedefin içinden arkaya 7 m dümdüz ince şimşek, dar koni kıvılcım arkadan fışkırır, iki küçük çakma
static func _pierce_through(o: Vector3, d: Vector3) -> void:
	RaitonLib.bolt(o - d * 0.5, o + d * 7.0, NUKITE, 0.11, 0.3, 0, 0.03, 0.04, 4)
	RaitonLib.bolt(o - d * 0.5, o + d * 7.5, RaitonLib.PALE, 0.04, 0.25, 0, 0.02, 0.04, 4)
	RaitonLib.flash(o, 0.9, NUKITE, 0.1, 6.0)
	RaitonLib.flash(o + d * 1.0, 0.6, RaitonLib.PALE, 0.08, 5.0)
	RaitonLib.sparks(o + d * 0.6, 18, RaitonLib.PALE, 15.0, 0.35, d, 0.25)
	RaitonLib.light(o, NUKITE, 8.0, 12.0, 0.3)


static func jigokuzuki_ippon_nukite(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.2)
	var d = pj._face(c, tt)
	Sfx.play("chidori", c.global_position, 1.2)
	# tüm chakra tek noktaya: çevreden ele çekilen kıvılcımlar, parmak ucunda gittikçe sıkışan iğne çakması
	RaitonLib.converge(RaitonLib.hand_fn(pj, c), 1.2, 0.6, NUKITE, 14, 0.022)
	var charge = func(i, k):
		if not pj.live(c):
			return
		var hp = pj.hand_pos(c)
		if i % 2 == 0:
			RaitonLib.light(hp, NUKITE, 2.0 + 4.0 * k, 4.0, 0.1)
		if i % 4 == 0:
			RaitonLib.flash(hp, 0.15 + 0.3 * k, RaitonLib.PALE, 0.06, 4.0)
	var thrust = func():
		if not pj.live(c):
			return
		var dd = pj._jump_at(c, tt, 0.0, 30.0)
		pj.anim(c, "cross", 2.2)
		var state = {"hit": false}
		_needle(pj, c, dd, state, 0.35)
		var fly = func(_i, _k):
			if state["hit"] or not pj.live(c):
				return
			var hs = pj.hit(c, c.global_position + Vector3.UP * 1.2 + dd * 1.0, 1.3, pj.inf(c, "jigokuzuki_ippon_nukite", 4.2, {"knock": 14.0, "kind": "heavy", "element": "raiton", "melee": true, "armor_break": 0.5, "unblockable": true, "hitstop": 0.16, "attacker": c}))
			if hs.size() > 0:
				state["hit"] = true
				var o: Vector3 = hs[0].global_position + Vector3.UP * 1.1
				_pierce_through(o, dd)
				if "velocity" in c:
					c.velocity = Vector3.ZERO
				pj.shake(0.8)
				Sfx.play("thunder", o, 1.3)
		pj.every(0.35, 1.0 / 60.0, fly, Callable())
	pj.every(0.6, 1.0 / 30.0, charge, thrust)


# ═════════════════════════════════════════ 8) Bashōsen: Rai no Maki ═════════════════════════════════════════

## Bashōsen (kuşanılan silah modeli) elde açılır; sırttaki gizlenir, chakra emilir (eski yelpaze yardımcısının oynanışı birebir).
## Savuruşta yelpaze tüylerinin kenarında kısa şimşek çatırtısı.
static func _fan(pj: PathJutsu, c: Node3D) -> Node3D:
	var root_n = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = CharacterModel.weapon_mesh("bashosen")
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_n.add_child(mi)
	pj.after(0.2, func():
		if is_instance_valid(root_n) and root_n.is_inside_tree():
			RaitonLib.crackle(RaitonLib.follow_fn(root_n, Vector3.UP * 0.6), 0.6, 0.6, FIELD, 6, 0.03, 0.04, root_n)
			RaitonLib.sparks(root_n.global_position + Vector3.UP * 0.8, 14, RaitonLib.PALE, 5.0, 0.4))
	var md = c.get("model")
	var hidden = []
	if md and "weapons" in md:
		for w in md.weapons:
			if String(w.get("id", "")) == "bashosen" and is_instance_valid(w["node"]) and w["node"].visible:
				w["node"].visible = false
				hidden.append(w["node"])
	pj.after(1.9, func():
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root_n)
		root_n.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root_n, pj.hand_pos(c, true))
	root_n.scale = Vector3.ONE * 0.05
	var tw = root_n.create_tween()
	tw.tween_property(root_n, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(root_n, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root_n):
			root_n.queue_free())
	if c is Player:
		c.chakra = maxf(0.0, c.chakra - c.max_chakra * 0.15)
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Bashōsen chakranı emiyor!", Color(0.95, 0.85, 0.5))
	pj.busy(c, 1.1)
	pj.anim(c, "slash_a", 1.0)
	return root_n


## Kaynak (Rai no Maki): yerden fışkıran dikey camgöbeği şimşek sütunları, dibinde yere yayılan dişli şimşek lekeleri.
static func _surge(g: Vector3) -> void:
	var h = randf_range(7.0, 11.0)
	for k in 3:
		var top = g + Vector3.UP * h * randf_range(0.7, 1.0) + RaitonLib.hdir() * randf_range(0.3, 1.2)
		RaitonLib.bolt(g + RaitonLib.hdir() * 0.3, top, FIELD if k > 0 else RaitonLib.PALE, 0.2 - k * 0.05, 0.25, 2, 0.12, 0.04, 5)
	RaitonLib.flash(g + Vector3.UP * 0.4, 0.9, FIELD, 0.1, 7.0)
	RaitonLib.sparks(g + Vector3.UP * 0.2, 8, FIELD, 7.0, 0.35, Vector3.UP, 0.5)
	_ground_cracks(g, 5, 1.4, 2.8, FIELD, 0.4)


## Tarla sınırı: zemine yapışık, dişli, kesik kesik yanan şimşek çemberi + içinde sürünen arklar
static func _field_rim(center: Vector3, r: float, dur: float, col: Color) -> void:
	var m = RaitonLib.web_mat(col)
	var stt = {"next": 0.0, "polys": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.12
			var out = []
			var n = 18
			for i in n:
				if randf() < 0.25:
					continue
				var a0 = TAU * i / n
				var a1 = TAU * (i + 1) / n
				out.append({"p": RaitonLib.ground_path(center + Vector3(cos(a0), 0, sin(a0)) * r, center + Vector3(cos(a1), 0, sin(a1)) * r, 0.15, 2), "w": 0.07, "a": randf_range(0.5, 1.0), "k": 0})
			stt["polys"] = out
		var grow = minf(age / 0.3, 1.0)
		RaitonLib.draw(im, m, stt["polys"], grow * clampf((dur - age) / 0.4, 0.0, 1.0), _cam(), true)
		return true)
	RaitonLib.ground_arcs(center, r * 0.9, dur, col, 8, 0.05, 0.09)


static func bashosen_rai_no_maki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	_fan(pj, c)
	var center = pj.gp(c.global_position + d * 16.0)
	pj.after(0.35, func():
		_field_rim(center, 13.0, 4.4, FIELD)
		Sfx.play("thunder", center, 0.7)
		pj.every(4.0, 0.35, func(i, _k):
			for k in 5:
				var p = center + d * randf_range(-11, 11) + side * randf_range(-11, 11)
				var g = pj.gp(p)
				var near = pj.enemies_near(c, center, 13.0)
				if k < 2 and not near.is_empty():
					g = near[(i + k) % near.size()].global_position
				_surge(RaitonLib.floor_at(g))
				for e in pj.enemies_near(c, g, 2.4):
					if not pj.live(e):
						continue
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, "bashosen_rai_no_maki", 0.35, {"element": "raiton", "knock": 2.0, "kind": "light", "hitstop": 0.04}))
					pj.st(e, "stun", 0.6)
			if i % 2 == 0:
				pj.shake(0.25), Callable()))


# ═════════════════════════════════════════ 9) Susanoo: Chidori ═════════════════════════════════════════

## GERÇEK Susanoo (Susanoo.of): dev sağ el yere yakın, avucunda Susanoo renginde plazma çekirdek; teller dev önkola
## sarılarak tırmanır, yeri yalar; kol hedefe uzanınca dev dallı mızrak gibi fırlar.
static func _arm_climb(sn, ball: Node3D, col: Color, S: float, dur: float) -> void:
	var stt = {"next": 0.0}
	var sw = weakref(sn)
	var p = RaitonLib.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		var s = sw.get_ref()
		if age > dur or s == null or not is_instance_valid(s) or not is_instance_valid(ball) or not ball.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.07, 0.13)
			var o = ball.global_position
			var arm: Vector3 = s.bone_at("RightLowerArm")
			RaitonLib.bolt(o, arm + RaitonLib.rdir() * S * 0.25, col, S * 0.025, 0.12, 2, 0.22, 0.06, 4)
		return true
	ball.add_child(p)


static func susanoo_chidori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_chidori")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color().lerp(Color(0.6, 0.75, 1.0), 0.5)
	var tg = Jutsu._tg(c, t, 16.0 + H * 1.2)
	var aim = MsArts._aim_fn(c, tg, 10.0 + H * 0.6)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.1)
	MsArts._anim(c, "cast", 0.9)
	sn.hide_weapons(1.6)
	var lguard = Susanoo.arm(false, d * 0.55 - side * 0.35 - Vector3.UP * 0.55, d * 0.8 + side * 0.25 + Vector3.UP * 0.35)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.4 - Vector3.UP * 0.85 + side * 0.3, d * 0.35 - Vector3.UP * 0.9, d * 0.6 - Vector3.UP * 0.7) + lguard, "spine": 16.0}, 1.6)
	var ball = Node3D.new()
	ball.add_child(RaitonLib.orb(S * 0.24, Color(1, 1, 1), col.lightened(0.35), col))
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 8.0 + H * 0.6
	l.shadow_enabled = false
	ball.add_child(l)
	MsArts._scene().add_child(ball)
	ball.global_position = sn.hand(true)
	RaitonLib.crackle(RaitonLib.follow_fn(ball), S * 0.55, 3.0, col.lightened(0.3), 10, S * 0.02, 0.04, ball)
	_arm_climb(sn, ball, col.lightened(0.2), S, 1.0)
	var fr = {"free": false}
	var tw = ball.create_tween()
	var o = {"sn": sn, "ball": ball}
	tw.tween_method(func(_x: float):
		if is_instance_valid(o["sn"]) and is_instance_valid(o["ball"]) and not fr["free"]:
			o["ball"].global_position = o["sn"].hand(true), 0.0, 1.0, 1.0)
	ball.scale = Vector3.ONE * 0.1
	ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	Sfx.play("chidori", c.global_position, 0.6)
	for k in 12:   # yere sürten şimşek dilleri
		MsArts._later(0.1 + k * 0.065, func():
			if not is_instance_valid(ball) or fr["free"]:
				return
			var hp = ball.global_position
			var g = Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * S * 0.6)
			RaitonLib.bolt(hp, g, col.lightened(0.2), S * 0.03, 0.14, 2, 0.2)
			if k % 4 == 0:
				RaitonLib.light(hp, col, 6.0, 8.0 + H * 0.6, 0.3)
				RaitonLib.sparks(g, 6, col.lightened(0.3), 4.0 + S * 2.0, 0.3, Vector3.UP, 0.7))
	MsArts._later(0.9, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			if is_instance_valid(ball):
				ball.queue_free()
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad) + lguard, "spine": -6.0}, 0.7, true))
	MsArts._later(1.0, func():
		if not (is_instance_valid(c) and is_instance_valid(ball)):
			return
		fr["free"] = true
		var from = ball.global_position
		var to: Vector3 = aim.call()
		RaitonLib.bolt(from, to, col.lightened(0.4), S * 0.05, 0.3, 3, 0.12, 0.05, 5)
		RaitonLib.bolt(from, to, RaitonLib.PALE, S * 0.018, 0.26, 0, 0.08, 0.05, 5)
		var tw2 = ball.create_tween()
		tw2.tween_property(ball, "global_position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.tween_callback(func():
			ball.queue_free()
			if not is_instance_valid(c):
				return
			var inf = Jutsu._inf(c, "susanoo_chidori", 2.2, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.1, "element": "raiton", "stun": 1.4, "dir": d})
			Combat.hit_sphere(c, to, 3.0 + H * 0.1, inf)
			for k in 8:
				RaitonLib.bolt(to, to + Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized() * (4.0 + H * 0.3), col.lightened(0.3), S * 0.02, 0.3, 2, 0.2)
			RaitonLib.flash(to, 1.6 + H * 0.05, col.lightened(0.4), 0.14, 11.0)
			RaitonLib.sparks(to, 30, col.lightened(0.4), 10.0 + H * 0.4, 0.5)
			var gg = Jutsu._ground(to)
			RaitonLib.dust_ring(gg, 1.0, 5.0 + H * 0.25, 0.6)
			RaitonLib.scorch(gg, 4.0 + H * 0.15, col, 6.0, 1.2)
			RaitonLib.light(to, col, 10.0, 16.0 + H, 0.4)
			MsArts._shake(0.9)))


# ═════════════════════════════════════════ 10) Senpō: Inton Raiha ═════════════════════════════════════════

## İki parmak ucunda karanlık mor çekirdek ve çatırtı
static func _two_finger(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		RaitonLib.crackle(RaitonLib.hand_fn(pj, c), 0.25, dur, VIOLET_L, 4, 0.025)
		return
	var tip = Node3D.new()
	ba.add_child(tip)
	tip.position = Vector3(0, 0.14, 0.02)
	tip.add_child(RaitonLib.orb(0.06, Color(0.95, 0.88, 1.0), VIOLET, Color(0.25, 0.08, 0.45)))
	RaitonLib.crackle(RaitonLib.follow_fn(tip), 0.22, dur, VIOLET_L, 4, 0.025, 0.05, tip)
	pj.free_after(dur, ba)


## Karanlık mor şimşek fırtınası: parmaklardan öne yelpaze gibi yayılan kalın, opak koyu mor gövdeli (açık mor konturlu)
## dallı şimşekler; uçlarından yere inen ince mor teller; sonunda önde kaya parçalayan yanık ve kırıntı
static func senpo_inton_raiha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d = pj.fwd(c, t)
	_two_finger(pj, c, 0.6)
	var dm = _dark(VIOLET_L, Color(0.13, 0.03, 0.24))
	pj.every(0.8, 0.08, func(_i, _k):
		if not pj.live(c):
			return
		var o = pj.hand_pos(c)
		for i in 2:
			var b = pj.gp(c.global_position + d.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(6.0, 18.0)) + Vector3.UP * randf_range(0.2, 2.0)
			RaitonLib.bolt_m(o, b, dm, 0.13, 0.22, 3, 0.2, 0.05, 5)
			RaitonLib.bolt(o, b, VIOLET, 0.035, 0.18, 1, 0.22)
			var gq = b + Vector3(randf_range(-2, 2), -b.y + pj.gp(b).y, randf_range(-2, 2))
			RaitonLib.bolt(b, gq, VIOLET_L, 0.05, 0.15, 1, 0.25)
			if randf() < 0.4:
				RaitonLib.sparks(gq, 4, VIOLET_L, 4.0, 0.3, Vector3.UP, 0.8))
	pj.after(0.25, func():
		Combat.hit_zone(c, c.global_position, d, 18.0, 35.0, 3.0, pj.inf(c, "senpo_inton_raiha", 1.6, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 1.0}))
		var g = pj.gp(c.global_position + d * 10.0)
		RaitonLib.scorch(g, 3.0, VIOLET, 6.0, 1.2)
		_ground_cracks(g, 7, 2.0, 4.0, VIOLET, 1.2)
		RaitonLib.debris(g, 10, 8.0, Color(0.4, 0.37, 0.35), d))
	Sfx.play("lightning", c.global_position, 0.8)
