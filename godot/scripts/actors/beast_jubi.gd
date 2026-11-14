class_name BeastJubi
extends RefCounted
## Jūbi — On Kuyruk (ilk biçim). Referans: refs/jubi (Juubi revived, Ten-Tails emerges, Juubi NXB, Jubi vs. Kurama&Gyuki)
## Okunan yapı:
##  - devasa, toprak-bej, çizgili (kabuk gibi çatlak / lif çizgili) deri; Kurama'nın yanında bile dağ gibi
##  - arka bacak yok: gövdenin arkası yere oturan şişkin bir kese / kabuk; gövde öne doğru alçalır
##  - iki uzun, ince, örümcek gibi kol: dirsekler yukarı-dışa kalkık, uzun pençeli parmaklar önde yere basar
##  - boyun yok: gövdenin önü baştan sona DEV AĞIZ — dikey oval, içi koyu, çepeçevre uzun ince sivri dişler
##  - ağzın üstünde TEK göz: kırmızı Rinne-Sharingan (iç içe halkalar + halkalarda dokuz tomoe)
##  - başın ve sırtın tepesinde deniz kabuğu gibi sivri diken demeti
##  - on kuyruk: sırttan yukarı-dışa dev bir çiçeğin yaprakları gibi açılan yassı, geniş, ucu sivri levhalar; boyuna çizgili

const C := Color(0.74, 0.65, 0.52)
const CD := Color(0.5, 0.42, 0.33)
const CL := Color(0.84, 0.77, 0.64)
const LINE := Color(0.24, 0.19, 0.15)
const MAW := Color(0.2, 0.07, 0.07)
const GUM := Color(0.45, 0.2, 0.18)
const TOOTH := Color(0.93, 0.88, 0.74)
const TV := Color(0.72, 0.66, 0.47)   # gölgesiz diş rengi (fildişi)
const EYE := Color(0.82, 0.1, 0.12)
const EYE_D := Color(0.1, 0.02, 0.03)


static func _col(_t: float, _a: float, d: Vector3) -> Color:
	return C.lerp(CD, clampf(-d.y * 1.1 - 0.1, 0.0, 1.0) * 0.85)


## Boyuna çatlak / lif çizgileri
static func _lines(mb: MB, sf: BeastSurf, n: int, a0: float, a1: float, t0: float, t1: float, w: float, seed_v: int) -> void:
	for i in n:
		var a = lerpf(a0, a1, (i + 0.5) / n)
		var ph = seed_v * 1.3 + i * 2.1
		var path = []
		for k in 9:
			var t = lerpf(t0, t1, k / 8.0)
			path.append(Vector2(t, a + 0.05 * sin(t * 7.0 + ph)))
		sf.ribbon(mb, path, func(u: float) -> float: return w * sin(clampf(u, 0.04, 0.96) * PI) + 0.01, LINE)


static func build(r: BeastRig, root: Node3D) -> void:
	r.quadruped = false
	r.upright = true
	var HP = Vector3(0, 3.0, 3.2)
	r.hips = r._pivot(root, HP, "kalca_kok")
	# --- arka kütle: yere oturan geniş tümsek + önde iki şişkin göğüs lobu
	var mb = MB.new()
	var bs = BeastSurf.tube(mb, [Vector3(0, 1.5, 9.0) - HP, Vector3(0, 2.8, 6.0) - HP, Vector3(0, 3.4, 2.5) - HP, Vector3(0, 3.6, -0.5) - HP],
		[Vector2(2.5, 1.8), Vector2(5.5, 3.2), Vector2(6.2, 3.9), Vector2(5.6, 3.8)], C, 32, 6, _col, Vector3.UP)
	_lines(mb, bs, 22, -PI, PI, 0.06, 0.96, 0.05, 3)
	for sx in [-1.0, 1.0]:
		mb.add("sphere", Vector3(2.1 * sx, 1.7, -2.2) - HP, Vector3(7.4, 4.6, 6.4), C, Vector3.ZERO, 16)
	r._mesh(r.hips, mb)
	r._collider(r.hips, Vector3(0, 0.2, 1.6), Vector3(11.5, 7.0, 11.0))
	# --- gövde: öne-yukarı yükselen kalın boyun
	var CH = Vector3(0, 4.6, 0.6)
	r.chest = r._pivot(r.hips, CH - HP, "gogus")
	var mc = MB.new()
	var cs = BeastSurf.tube(mc, [Vector3(0, 3.4, 0.8) - CH, Vector3(0, 5.6, -1.4) - CH, Vector3(0, 7.2, -3.2) - CH, Vector3(0, 7.7, -4.4) - CH],
		[Vector2(5.2, 3.9), Vector2(4.5, 3.8), Vector2(3.8, 3.7), Vector2(3.6, 3.6)], C, 36, 7, _col, Vector3.UP)
	_lines(mc, cs, 26, -PI, PI, 0.04, 0.96, 0.055, 7)
	for sx in [-1.0, 1.0]:
		mc.add("sphere", Vector3(3.3 * sx, 6.0, -1.0) - CH, Vector3(6.4, 5.4, 6.0), C, Vector3(0, 0, 18.0 * sx), 16)
	r._mesh(r.chest, mc)
	r._collider(r.chest, Vector3(0, 1.2, -1.6), Vector3(9.6, 7.6, 7.0))
	# --- baş: boynun ucu = çepeçevre dişli dikey oval ağız; üstünde tek gözlü alın
	var HD = Vector3(0, 7.7, -4.4)
	r.head = r._pivot(r.chest, HD - CH, "bas")
	r.head.rotation.x = deg_to_rad(-10.0)   # ağız öne ve hafif aşağı bakar (yerden bakan görür)
	var mh = MB.new()
	Loft.tube(mh, [Vector3(0, 0, 2.0), Vector3(0, 0.1, 0.2), Vector3(0, 0, -1.6), Vector3(0, -0.1, -2.8)],
		[Vector2(3.6, 3.6), Vector2(3.5, 3.8), Vector2(3.1, 3.7), Vector2(2.7, 3.35)], C, 30, 5, true, false, _col)
	var RC = Vector3(0, -0.1, -2.8)
	var RA = 2.6
	var RB = 3.25
	# dudak halkası
	var lip = []
	var lipr = []
	for k in 33:
		var a = TAU * k / 32.0
		lip.append(RC + Vector3(cos(a) * RA, sin(a) * RB, 0))
		lipr.append(0.42)
	Loft.tube(mh, lip, lipr, C.lerp(CD, 0.45), 8, 1, false, false)
	# ağız boşluğu: koyu, halkanın hemen gerisinde
	mh.add("sphere", RC + Vector3(0, 0, 1.2), Vector3(RA * 2.0, RB * 2.0, 2.6), MAW, Vector3.ZERO, 18)
	mh.add("sphere", RC + Vector3(0, -1.6, 0.9), Vector3(2.6, 1.6, 2.4), GUM, Vector3.ZERO, 10)   # dil
	# dişler: halkanın her yanından içe doğru uzun, ince, sivri; arkada ikinci kısa sıra
	# alın: ağzın üstündeki yumru (göz burada)
	mh.add("sphere", Vector3(0, 3.5, -1.3), Vector3(5.0, 3.2, 4.0), C, Vector3.ZERO, 16)
	# diken demeti: başın arkasından ve boyun sırtından yukarı-geriye
	var spikes = [[Vector3(0, 4.6, -0.6), Vector3(0, 1, 0.2), 5.0, 0.7], [Vector3(-1.1, 4.3, 0.0), Vector3(-0.3, 1, 0.3), 4.0, 0.55], [Vector3(1.1, 4.3, 0.0), Vector3(0.3, 1, 0.3), 3.8, 0.55],
		[Vector3(0, 3.9, 1.2), Vector3(0, 1, 0.5), 4.4, 0.65], [Vector3(-2.0, 3.6, 0.2), Vector3(-0.6, 1, 0.3), 3.0, 0.45], [Vector3(2.0, 3.6, 0.2), Vector3(0.6, 1, 0.3), 3.1, 0.45],
		[Vector3(-0.9, 3.6, 2.0), Vector3(-0.2, 1, 0.6), 3.2, 0.5], [Vector3(0.9, 3.6, 2.0), Vector3(0.2, 1, 0.6), 3.0, 0.5], [Vector3(0, 3.3, 2.9), Vector3(0, 1, 0.8), 3.4, 0.55],
		[Vector3(-2.6, 2.7, 1.2), Vector3(-0.9, 1, 0.4), 2.2, 0.38], [Vector3(2.6, 2.7, 1.2), Vector3(0.9, 1, 0.4), 2.3, 0.38]]
	for s in spikes:
		var d: Vector3 = (s[1] as Vector3).normalized()
		var p0: Vector3 = s[0]
		Loft.tube(mh, [p0 - d * 0.8, p0 + d * float(s[2]) * 0.7 + Vector3(0, 0, 0.2), p0 + d * float(s[2]) * 1.6 + Vector3(0, 0, 0.8)], [float(s[3]), float(s[3]) * 0.6, 0.03], [C, CL, CL], 9, 4)
	r._mesh(r.head, mh)
	r._collider(r.head, Vector3(0, 0.8, -0.6), Vector3(7.4, 8.6, 6.0))
	# tek göz: kırmızı Rinne-Sharingan — alnın önünde, öne bakar
	var EP = Vector3(0, 3.5, -3.12)
	var me = MB.new()
	# dişler: halkanın her yanından içe doğru; üstte ve altta uzun kavisli, yanlarda kısa; arkada ikinci sıra
	for i in 26:
		var a = TAU * (i + 0.5) / 26.0
		var o = Vector3(cos(a) * RA * 0.94, sin(a) * RB * 0.94, 0)
		var inw = -Vector3(cos(a), sin(a), 0)
		var ln = (0.7 + 1.25 * pow(absf(sin(a)), 1.6)) * (0.8 + 0.4 * fposmod(i * 0.37, 1.0))
		var side = Vector3(-sin(a), cos(a), 0) * (0.1 if i % 2 == 0 else -0.08)
		Loft.tube(me, [RC + o - inw * 0.3 + Vector3(0, 0, 0.1), RC + o + inw * ln * 0.5 + Vector3(0, 0, -0.5) + side, RC + o + inw * ln + Vector3(0, 0, -0.15) + side * 0.4], [0.21, 0.14, 0.015], [TV.darkened(0.45), TV.darkened(0.15), TV], 7, 4)
	for i in 16:
		var a = TAU * (i + 0.2) / 16.0
		var o = Vector3(cos(a) * RA * 0.8, sin(a) * RB * 0.8, 0.5)
		var inw = -Vector3(cos(a), sin(a), 0)
		var ln = 0.7 + 0.8 * absf(sin(a))
		Loft.tube(me, [RC + o - inw * 0.2, RC + o + inw * ln * 0.5 + Vector3(0, 0, -0.15), RC + o + inw * ln], [0.15, 0.1, 0.015], TV.darkened(0.55), 6, 3)
	me.add("sphere", EP, Vector3(3.3, 1.9, 0.5), Color(0.03, 0.01, 0.01), Vector3.ZERO, 18)             # koyu badem göz çukuru
	me.add("sphere", EP + Vector3(0, 0, -0.14), Vector3(1.7, 1.4, 0.42), EYE, Vector3.ZERO, 18)
	for ring in 3:
		var rr = 0.26 + ring * 0.2
		var pts = []
		var rads = []
		for k in 25:
			var a = TAU * k / 24.0
			pts.append(EP + Vector3(cos(a) * rr, sin(a) * rr * 0.8, -0.365 + rr * rr * 0.16))
			rads.append(0.035)
		Loft.tube(me, pts, rads, EYE_D, 4, 1, false, false)
		for k in 3:
			var a2 = TAU * k / 3.0 + ring * 0.7
			me.add("sphere", EP + Vector3(cos(a2) * rr, sin(a2) * rr * 0.8, -0.38 + rr * rr * 0.16), Vector3(0.15, 0.15, 0.08), EYE_D, Vector3.ZERO, 6)
	me.add("sphere", EP + Vector3(0, 0, -0.36), Vector3(0.2, 0.2, 0.08), EYE_D, Vector3.ZERO, 8)
	var emi = MeshInstance3D.new()
	emi.mesh = me.build(null)
	var em = StandardMaterial3D.new()
	em.vertex_color_use_as_albedo = true
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emi.material_override = em
	r.head.add_child(emi)
	r.mouth = r._pivot(r.head, RC + Vector3(0, 0, -0.6), "agiz")
	# --- kollar: geniş omuz, dirsek dışa-yukarı, pençeli el yanda-önde yere basar
	for sx in [-1.0, 1.0]:
		var S = Vector3(4.6 * sx, 6.2, -1.4)
		var E = Vector3(9.6 * sx, 9.2, -2.6)
		var Wr = Vector3(12.4 * sx, 1.3, -7.4)
		var sh = r._pivot(r.chest, S - CH, "omuz")
		var m1 = MB.new()
		m1.add("sphere", Vector3.ZERO, Vector3(4.4, 4.0, 4.2), C, Vector3.ZERO, 14)
		var s1 = BeastSurf.tube(m1, [Vector3.ZERO, (E - S) * 0.5 + Vector3(0, 0.5, 0), E - S], [2.1, 1.5, 1.05], C, 18, 6, _col)
		_lines(m1, s1, 9, -PI, PI, 0.08, 0.94, 0.045, 21)
		r._mesh(sh, m1)
		var el = r._pivot(sh, E - S, "dirsek")
		var m2 = MB.new()
		m2.add("sphere", Vector3.ZERO, Vector3(2.3, 2.3, 2.3), C, Vector3.ZERO, 12)   # dirsek yumrusu
		var s2 = BeastSurf.tube(m2, [Vector3.ZERO, (Wr - E) * 0.5 + Vector3(0.5 * sx, 0, -0.3), Wr - E], [0.95, 1.0, 0.75], C, 18, 6, _col)
		_lines(m2, s2, 8, -PI, PI, 0.08, 0.94, 0.04, 23)
		var hand = Wr - E + Vector3(0.3 * sx, -0.5, -0.5)
		m2.add("sphere", hand, Vector3(3.0, 1.3, 3.0), C, Vector3.ZERO, 12)
		for f in 5:
			var fa = lerpf(-1.1, 1.1, f / 4.0) + 0.35 * sx
			var f0 = hand + Vector3(sin(fa) * 1.0, 0.1, -cos(fa) * 1.0)
			var f1 = hand + Vector3(sin(fa) * 2.5, 0.7, -cos(fa) * 2.5)
			var f2 = hand + Vector3(sin(fa) * 3.8, -0.5, -cos(fa) * 3.7)
			Loft.tube(m2, [f0, f1, f2], [0.44, 0.38, 0.26], C, 8, 3, true, true, _col)
			Loft.tube(m2, [f2 + Vector3(0, 0.05, 0), f2 + Vector3(sin(fa) * 0.6, -0.1, -cos(fa) * 0.6), f2 + Vector3(sin(fa) * 1.1, -0.6, -cos(fa) * 1.0)], [0.26, 0.16, 0.02], CL, 6, 3)
		r._mesh(el, m2)
		r.arms.append({"sh": sh, "el": el, "side": sx})
	_tails(r, Vector3(0, 5.0, 5.0) - HP)
	r._weak(r.head, Vector3(0, 0.0, -1.2))
	r._weak(r.hips, Vector3(0, 3.6, 3.4))


## On kuyruk: sırtın arkasında yelpaze gibi (önden bakınca tavus kuyruğu) açılan geniş, yassı, ucu kıvrık sivri yapraklar
static func _tails(r: BeastRig, base_pos: Vector3) -> void:
	var n = 8
	var base = r._pivot(r.hips, base_pos, "kuyruk_koku")
	r.tail_curl = 0.0
	for ti in 10:
		var u = ti / 9.0
		var phi = deg_to_rad(lerpf(-44.0, 44.0, u))
		var mid = 1.0 - absf(u - 0.5) * 2.0   # 0 kenar, 1 orta
		var length = 27.0 + mid * 9.0 + 4.0 * fposmod(ti * 0.61, 1.0)
		var seg_len = length / n
		var pitch = -72.0 + 10.0 * fposmod(ti * 0.37, 1.0) - (8.0 if ti % 2 == 0 else 0.0)   # çift olanlar öne, tekler arkaya: iki sıra
		var fan = r._pivot(base, Vector3(sin(phi) * 6.5, cos(phi) * 1.2, 0.8 if ti % 2 == 1 else 0.0), "yelpaze")
		fan.rotation.z = -phi
		var troot = r._pivot(fan, Vector3.ZERO, "tail")
		troot.rotation = Vector3(deg_to_rad(pitch), 0, 0)
		var segs = []
		var parent = troot
		for i in n:
			var k0 = float(i) / n
			var k1 = float(i + 1) / n
			var w0 = _blade(k0)
			var w1 = _blade(k1)
			var piv = r._pivot(parent, Vector3(0, 0, seg_len) if i > 0 else Vector3.ZERO, "s%d" % i)
			var mb = MB.new()
			var th0 = w0 * 0.14 + 0.12
			var th1 = w1 * 0.14 + 0.05
			Loft.tube(mb, [Vector3(0, 0, -seg_len * 0.2), Vector3(0, 0, seg_len * 0.5), Vector3(0, 0, seg_len * 1.12)],
				[Vector2(w0, th0), Vector2((w0 + w1) * 0.5, (th0 + th1) * 0.5), Vector2(w1, th1)], C.lerp(CD, 0.25), 12, 3, i == 0, true)
			for sy in [-1.0, 1.0]:
				# açık renk orta şerit + koyu damar çizgileri (iki yüzde)
				Loft.tube(mb, [Vector3(0, sy * th0 * 0.72, 0), Vector3(0, sy * th1 * 0.72, seg_len * 1.05)], [Vector2(w0 * 0.5, th0 * 0.42), Vector2(w1 * 0.5, th1 * 0.42)], CL, 8, 1, false, false)
				for q in [-0.62, 0.0, 0.62]:
					Loft.tube(mb, [Vector3(q * w0, sy * (th0 * (1.12 - absf(q) * 0.5)), 0), Vector3(q * w1, sy * (th1 * (1.12 - absf(q) * 0.5)), seg_len * 1.05)], [0.05, 0.04], LINE, 4, 1)
			r._mesh(piv, mb)
			segs.append(piv)
			parent = piv
		r.tails.append(segs)
		var hook = (1.0 if phi >= 0.0 else -1.0) * (1.0 if ti % 3 != 1 else -1.0)
		r.tail_cfg.append({"yaw": 0.0, "pitch": deg_to_rad(pitch), "amp": 0.035, "phase": randf() * TAU, "style": "fur", "root": troot, "s_amp": 0.07 + 0.03 * fposmod(ti * 0.53, 1.0), "s_yaw": hook * (0.05 + 0.06 * fposmod(ti * 0.29, 1.0))})


## Yaprak yarı genişliği: kökte dar, üçte birde en geniş, uca doğru sivrilir
static func _blade(k: float) -> float:
	return maxf(0.05, lerpf(2.2, 6.2, sin(minf(1.0, k * 2.4) * PI * 0.5)) * (1.0 - pow(k, 1.5)))
