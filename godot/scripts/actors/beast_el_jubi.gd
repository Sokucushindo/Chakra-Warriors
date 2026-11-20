extends RefCounted
## Jūbi — On Kuyruk (ilk biçim), ELLE MODELLENMİŞ (BeastModels.JUBI_EL ile açılır). Kaynaklar: refs/jubi
## (Juubi NXB önden çömelik, Ten-Tails emerges yandan-önden, Juubi revived, Jubi vs Kurama&Gyuki). Ortak tasarım:
##  - arka bacak yok: gövdenin arkası yere oturan iri yuvarlak kese; önde aşağıda iki şişkin lob
##  - boyun yok: gövde öne-yukarı yükselir ve doğrudan başa döner; başın ön yüzü baştan sona DEV DİKEY AĞIZ
##    (koyu iç, çepeçevre uzun ince sivri dişler); ağzın üstünde TEK kırmızı Rinne-Sharingan göz; tepede diken demeti
##  - kollar KALIN ve kaslı: omuz kütlesi gövdenin yanından çıkar, dirsek yukarı-dışa, ön kol yere iner, uzun pençeli iri el
##  - on kuyruk: yassı levha DEĞİL, kalın yuvarlak (hafif yassı), sırttan yukarı-dışa yelpaze gibi açılır, uca doğru incelir ve kıvrılır
##  - düz gri-bej deri, seyrek çatlak / damar çizgileri (tahta lifi gibi sık çizgi yok)
## Yöntem Kurama ile aynı (beast_el.gd): tek parça derili yüzey; göz ve dişler baş eklemine bağlı ayrı parça.
const BE = preload("res://scripts/actors/beast_el.gd")

const C := Color(0.74, 0.66, 0.55)
const CD := Color(0.52, 0.45, 0.37)
const CL := Color(0.84, 0.78, 0.67)
const LINE := Color(0.3, 0.24, 0.2)
const MAW := Color(0.035, 0.008, 0.01)   # ağız içi neredeyse siyah (ışıksız malzemede açık renk parlak kırmızı görünüyordu)
const LIP := Color(0.45, 0.36, 0.3)
const CLAW := Color(0.86, 0.82, 0.72)


static func _g(x: float, s: float) -> float:
	return exp(-x * x / (s * s))


static func build(r: BeastRig, root: Node3D) -> void:
	r.quadruped = false
	r.upright = true
	# ---------------- pivotlar (rolleri eski modelle aynı: kalça / göğüs / baş / iki kol / on kuyruk)
	var HP := Vector3(0, 3.2, 3.4)
	r.hips = r._pivot(root, HP, "kalca_kok")
	r._collider(r.hips, Vector3(0, 0.6, 1.4), Vector3(12.0, 7.6, 11.0))
	var CH := Vector3(0, 5.6, 0.0)
	r.chest = r._pivot(r.hips, CH - HP, "gogus")
	r._collider(r.chest, Vector3(0, 1.0, -1.0), Vector3(11.0, 7.6, 7.0))
	var HD := Vector3(0, 8.0, -3.6)
	r.head = r._pivot(r.chest, HD - CH, "bas")
	r._collider(r.head, Vector3(0, 0.4, -1.6), Vector3(9.0, 9.0, 6.0))
	var AR := {}
	for sx: float in [-1.0, 1.0]:
		var S := Vector3(5.4 * sx, 7.6, -0.8)
		var E := Vector3(10.6 * sx, 8.6, -2.6)
		var W := Vector3(12.2 * sx, 1.3, -7.0)
		var sh := r._pivot(r.chest, S - CH, "omuz")
		var el := r._pivot(sh, E - S, "dirsek")
		r.arms.append({"sh": sh, "el": el, "side": sx})
		AR[sx] = {"S": S, "E": E, "W": W, "sh": sh, "el": el}
		for cd in [[sh, S, E, 3.4], [el, E, W, 2.6]]:   # uzuv yönünde dönük çarpışma kutusu
			var dv: Vector3 = (cd[2] as Vector3) - (cd[1] as Vector3)
			r._collider(cd[0], dv * 0.5, Vector3(float(cd[3]), dv.length() + 1.0, float(cd[3])))
			var mk: Node3D = r.colliders[r.colliders.size() - 1]
			mk.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))
	# kuyruklar: sırtın arkasında yelpaze, iki sıra (eski düzen)
	var n := 8
	var tbase := r._pivot(r.hips, Vector3(0, 5.2, 5.4) - HP, "kuyruk_koku")
	r.tail_curl = 0.0
	var TL := []
	for ti in 10:
		var u := ti / 9.0
		var phi := deg_to_rad(lerpf(-46.0, 46.0, u))
		var mid := 1.0 - absf(u - 0.5) * 2.0
		var length := 25.0 + mid * 8.0 + 3.0 * fposmod(ti * 0.61, 1.0)
		var seg_len := length / n
		var pitch := -70.0 + 10.0 * fposmod(ti * 0.37, 1.0) - (8.0 if ti % 2 == 0 else 0.0)
		var fan := r._pivot(tbase, Vector3(sin(phi) * 5.5, cos(phi) * 1.0, 0.8 if ti % 2 == 1 else 0.0), "yelpaze")
		fan.rotation.z = -phi
		var troot := r._pivot(fan, Vector3.ZERO, "tail")
		troot.rotation = Vector3(deg_to_rad(pitch), 0, 0)
		var segs := []
		var parent: Node3D = troot
		for i in n:
			var piv := r._pivot(parent, Vector3(0, 0, seg_len) if i > 0 else Vector3.ZERO, "s%d" % i)
			segs.append(piv)
			parent = piv
		r.tails.append(segs)
		var hook := (1.0 if phi >= 0.0 else -1.0) * (1.0 if ti % 3 != 1 else -1.0)
		r.tail_cfg.append({"yaw": 0.0, "pitch": deg_to_rad(pitch), "amp": 0.04, "phase": randf() * TAU, "style": "fur", "root": troot,
			"s_amp": 0.3 + 0.08 * fposmod(ti * 0.53, 1.0), "s_yaw": hook * (0.06 + 0.06 * fposmod(ti * 0.29, 1.0))})
		TL.append([troot, segs, length, seg_len, mid])
	r._weak(r.head, Vector3(0, 5.0, 0.4))   # başın tepe yüzeyinde (kutu tepesiyle aynı)
	r._weak(r.hips, Vector3(0, 4.1, 2.6))   # kese sırtının yüzeyinde
	# ---------------- iskelet + köprü
	var be = BE.new()
	be.rig(r, root, [["bel", r.hips, r.chest, 0.5, Vector3(0, 4.6, 1.6)]])
	be.shade = func(c: Color, nrm: Vector3) -> Color: return c.lerp(Color(c.r * 0.72, c.g * 0.66, c.b * 0.66), smoothstep(0.2, 0.85, -nrm.y) * 0.75)
	_body(be, r, HP, AR)
	for sx: float in [-1.0, 1.0]:
		_arm(be, r, AR[sx], sx)
	for e in TL:
		_tail(be, e[0], e[1], e[2], e[3], e[4])
	var mat: Material = BeastKurama.mat()   # düz cel deri (canavar malzemesinin çizik dokusu tahta lifi gibi duruyordu)
	be.finish(mat)
	_face(r, HD)


# ------------------------------------------------------------------ gövde: arka kese -> bel -> göğüs -> baş, tek tüp; önde iki lob
static func _body(be, r: BeastRig, HP: Vector3, AR: Dictionary) -> void:
	var tp := [Vector3(0, 1.2, 9.6), Vector3(0, 2.4, 8.4), Vector3(0, 3.4, 6.2), Vector3(0, 4.0, 3.6), Vector3(0, 4.6, 1.6), Vector3(0, 5.8, -0.2),
		Vector3(0, 7.2, -1.6), Vector3(0, 8.3, -2.8), Vector3(0, 8.6, -4.0), Vector3(0, 8.1, -5.0)]
	var tr := [Vector2(1.2, 1.0), Vector2(4.4, 2.6), Vector2(6.4, 3.8), Vector2(6.8, 4.3), Vector2(6.0, 4.4), Vector2(6.0, 4.6),
		Vector2(5.6, 4.6), Vector2(4.9, 4.6), Vector2(4.6, 4.4), Vector2(4.2, 4.2)]
	var tz := func(z: float) -> float: return clampf((9.6 - z) / 14.6, 0.0, 1.0)
	var anch := [[6.0, r.hips], [3.0, r.hips], [1.6, "bel"], [-0.2, r.chest], [-1.8, r.chest], [-3.2, r.head]]
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var l: Array = BE.chain(p.z, anch)
		for sx: float in [-1.0, 1.0]:   # omuz kökünde gövde derisi kolu biraz izler: yarık açılmaz
			var g: Dictionary = AR[sx]
			var w := 0.45 * (1.0 - smoothstep(1.5, 4.0, p.distance_to(g["S"])))
			if w > 0.0:
				for e in l:
					e[1] = float(e[1]) * (1.0 - w)
				l.append([g["sh"], w])
		return l
	var bump := func(t: float, a: float) -> float:
		var aw := wrapf(a, -PI, PI)
		var pec := 0.06 * _g(t - tz.call(-0.6), 0.07) * _g(absf(aw) - 2.5, 0.4)          # göğüs kası
		var spine := -0.035 * _g(aw, 0.18) * smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.7, 0.85, t))   # sırt oluğu
		var hump := 0.05 * _g(t - tz.call(4.2), 0.1) * _g(aw, 0.9)                      # kese sırtı kabarık
		return pec + spine + hump
	var colf := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := wrapf(a, -PI, PI)
		return C.lerp(CL, 0.25 * _g(absf(aw) - PI, 0.8) * smoothstep(-1.0, -4.0, p.z))   # göğüs önü hafif açık
	var info: Dictionary = be.tube(tp, tr, colf, sk, 80, 40, Vector3.UP, false, true, bump)
	# çatlak / damar çizgileri: seyrek, uzun, hafif kıvrık
	var lsk := func(_t, _a, p): return sk.call(0.0, 0.0, p)
	for q in [[0.15, 0.55, -0.4], [0.2, 0.62, 0.5], [0.1, 0.5, 1.4], [0.18, 0.6, -1.3], [0.3, 0.75, 2.2], [0.3, 0.72, -2.1], [0.05, 0.4, 0.05], [0.4, 0.85, 2.8], [0.42, 0.85, -2.8]]:
		var path := []
		for k in 7:
			var t: float = lerpf(float(q[0]), float(q[1]), k / 6.0)
			path.append(Vector2(t, float(q[2]) + 0.07 * sin(k * 1.7 + float(q[2]) * 3.0)))
		be.band(info, path, func(u): return 0.05 * sin(clampf(u, 0.05, 0.95) * PI) + 0.01, LINE, lsk, 0.03)
	# önde aşağıda iki şişkin lob (gövdeden yere sarkan)
	for sx: float in [-1.0, 1.0]:
		var lp := [Vector3(1.6 * sx, 4.4, 0.6), Vector3(2.3 * sx, 3.0, -1.0), Vector3(2.4 * sx, 1.8, -1.6), Vector3(2.2 * sx, 0.9, -1.4)]
		var lr := [Vector2(2.4, 2.4), Vector2(3.2, 3.0), Vector2(2.8, 2.4), Vector2(0.8, 0.6)]
		var lsk2 := func(_t, _a, p: Vector3) -> Array: return [[r.hips, 0.6], ["bel", 0.4]] if p.y < 3.6 else [["bel", 0.6], [r.chest, 0.4]]
		be.tube(lp, lr, func(_t, _a, _p): return C, lsk2, 24, 24, Vector3.FORWARD, false, true)
	# tepe dikenleri: başın arkasından ve sırttan yukarı-geriye
	var hsk := func(_t, _a, _p): return [[r.head, 1.0]]
	var csk := func(_t, _a, _p): return [[r.chest, 1.0]]
	var spikes := [[Vector3(0, 12.4, -3.4), Vector3(0, 1, 0.25), 4.6, 0.75, hsk], [Vector3(-1.4, 12.1, -2.8), Vector3(-0.35, 1, 0.3), 3.8, 0.6, hsk],
		[Vector3(1.4, 12.1, -2.8), Vector3(0.35, 1, 0.3), 3.6, 0.6, hsk], [Vector3(0, 11.9, -1.8), Vector3(0, 1, 0.55), 4.2, 0.7, hsk],
		[Vector3(-2.6, 11.4, -2.2), Vector3(-0.7, 1, 0.3), 2.8, 0.5, hsk], [Vector3(2.6, 11.4, -2.2), Vector3(0.7, 1, 0.3), 2.9, 0.5, hsk],
		[Vector3(-1.0, 11.6, -0.6), Vector3(-0.2, 1, 0.7), 3.2, 0.55, csk], [Vector3(1.0, 11.6, -0.6), Vector3(0.2, 1, 0.7), 3.0, 0.55, csk],
		[Vector3(0, 11.0, 0.6), Vector3(0, 1, 0.9), 3.4, 0.6, csk], [Vector3(-3.4, 10.4, -1.0), Vector3(-1.0, 1, 0.4), 2.2, 0.4, csk],
		[Vector3(3.4, 10.4, -1.0), Vector3(1.0, 1, 0.4), 2.3, 0.4, csk]]
	for s in spikes:
		var d: Vector3 = (s[1] as Vector3).normalized()
		var p0: Vector3 = s[0]
		var ln: float = s[2]
		be.tube([p0 - d * 1.2, p0 + d * ln * 0.45 + Vector3(0, 0, 0.3), p0 + d * ln + Vector3(0, 0, 0.9)], [Vector2(s[3], s[3]), Vector2(float(s[3]) * 0.55, float(s[3]) * 0.55), Vector2(0.03, 0.03)],
			func(t, _a, _p): return C.lerp(CL, float(t) * 0.6), s[4], 10, 10, Vector3.FORWARD, false, true)


# ------------------------------------------------------------------ kol: omuz kütlesi -> kalın üst kol -> dirsek -> ön kol -> bilek -> el, tek tüp + parmaklar
static func _arm(be, r: BeastRig, g: Dictionary, sx: float) -> void:
	var S: Vector3 = g["S"]
	var E: Vector3 = g["E"]
	var W: Vector3 = g["W"]
	var pts := [S + Vector3(-1.8 * sx, -0.2, 0.3), S + Vector3(0.3 * sx, 0.4, 0.0), S.lerp(E, 0.5) + Vector3(0, 0.9, 0), E, E.lerp(W, 0.35) + Vector3(0.3 * sx, 0, 0.2),
		E.lerp(W, 0.8), W, W + Vector3(0.4 * sx, -0.6, -0.8)]
	var rad := [Vector2(2.6, 2.6), Vector2(3.0, 2.8), Vector2(2.2, 2.3), Vector2(1.6, 1.7), Vector2(1.9, 1.9), Vector2(1.35, 1.35), Vector2(1.1, 1.0), Vector2(2.0, 0.8)]
	var tk := [0.0]
	for i in pts.size() - 1:
		tk.append(float(tk[i]) + ((pts[i + 1] as Vector3) - (pts[i] as Vector3)).length())
	var L: float = tk[tk.size() - 1]
	var t1: float = float(tk[1]) / L
	var tE: float = float(tk[3]) / L
	var sh: Node3D = g["sh"]
	var el: Node3D = g["el"]
	var sk := func(t: float, _a: float, _p: Vector3) -> Array:
		if t < t1:
			var u := smoothstep(0.0, t1, t)
			return [[r.chest, 0.55 * (1.0 - u)], [sh, 1.0 - 0.55 * (1.0 - u)]]
		return BE.chain(t, [[t1, sh], [tE - 0.05, sh], [tE + 0.06, el]])
	var bump := func(t: float, a: float) -> float:   # pazı önde, ön kol kası dışta
		return 0.08 * _g(t - lerpf(t1, tE, 0.45), 0.08) * maxf(0.0, cos(a - PI * 0.5 * sx)) + 0.05 * _g(t - lerpf(tE, 1.0, 0.3), 0.07) * maxf(0.0, sin(a) * sx)
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, _p): return C, sk, 64, 28, Vector3.UP, false, true, bump)
	var lsk := func(_t, _a, _p): return [[el, 1.0]]
	be.band(info, [Vector2(lerpf(tE, 1.0, 0.1), 0.6 * sx), Vector2(lerpf(tE, 1.0, 0.5), 0.8 * sx), Vector2(lerpf(tE, 1.0, 0.85), 0.7 * sx)],
		func(u): return 0.06 * sin(clampf(u, 0.05, 0.95) * PI) + 0.012, LINE, lsk, 0.03)
	# el: geniş avuç, beş uzun boğumlu parmak, uzun pençe
	var hsk := [[el, 1.0]]
	var hand: Vector3 = W + Vector3(0.4 * sx, -0.7, -1.0)
	for f in 5:
		var fa := lerpf(-1.05, 1.05, f / 4.0) + 0.35 * sx
		var b0 := hand + Vector3(sin(fa) * 1.0, 0.0, -cos(fa) * 0.9)
		var b1 := hand + Vector3(sin(fa) * 2.4, 0.7, -cos(fa) * 2.3)
		var b2 := hand + Vector3(sin(fa) * 3.6, -0.3, -cos(fa) * 3.5)
		var b3 := hand + Vector3(sin(fa) * 4.2, -0.75, -cos(fa) * 4.0)
		be.tube([b0, b1, b2, b3], [Vector2(0.5, 0.45), Vector2(0.46, 0.42), Vector2(0.38, 0.34), Vector2(0.28, 0.24)], func(_t, _a, _p): return C, func(_t, _a, _p): return hsk, 14, 12, Vector3.UP, false, true)
		be.claw(b3 + Vector3(0, 0.02, 0), Vector3(sin(fa) * 0.4, -0.5, -cos(fa) * 0.9), 1.5, 0.26, CLAW, hsk)


# ------------------------------------------------------------------ kuyruk: kalın yuvarlak (hafif yassı), uca doğru incelen tek tüp
static func _tail(be, troot: Node3D, segs: Array, length: float, seg_len: float, mid: float) -> void:
	var X: Transform3D = be.rs(troot)
	var r0 := 1.5 + 0.35 * mid
	var rf := func(k: float) -> float:
		return lerpf(r0 * 0.8, r0 * 1.15, sin(minf(1.0, k * 2.5) * PI * 0.5)) * (1.0 - pow(maxf(0.0, (k - 0.35) / 0.65), 1.3) * 0.97)
	var pts := []
	var rad := []
	for i in 16:
		var k := float(i) / 15.0
		var z := lerpf(-1.0, length, k)
		pts.append(Vector3(0, 0, z))
		var rr: float = rf.call(clampf(z / length, 0.0, 1.0))
		rad.append(Vector2(rr * 1.06, rr * 0.9))   # neredeyse yuvarlak, çok hafif yassı
	var nseg := segs.size()
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var f := clampf(p.z / seg_len - 0.5, 0.0, nseg - 1.0)
		var i0 := mini(int(f), nseg - 1)
		var i1 := mini(i0 + 1, nseg - 1)
		var w := f - i0
		return [[segs[i0], 1.0 - w], [segs[i1], w]]
	var col := func(_t: float, a: float, p: Vector3) -> Color:
		return C.lerp(CL, 0.3 * _g(wrapf(a, -PI, PI), 0.6)).lerp(CD, 0.25 * clampf(p.z / length, 0.0, 1.0))
	var bump := func(t: float, a: float) -> float:   # boyuna hafif sırtlar (kök / damar)
		return 0.03 * sin(a * 4.0 + t * 9.0) * smoothstep(0.05, 0.2, t) * (1.0 - smoothstep(0.8, 0.95, t))
	var info: Dictionary = be.tube(pts, rad, col, sk, 60, 20, Vector3.UP, false, true, bump, X)
	for a0 in [0.0, PI * 0.5, -PI * 0.5]:   # boyuna damar çizgisi
		var path := []
		for k in 6:
			path.append(Vector2(lerpf(0.06, 0.8, k / 5.0), a0 + 0.08 * sin(k * 1.3)))
		be.band(info, path, func(u): return 0.07 * (1.0 - u * 0.7) + 0.01, LINE, sk, 0.03)


# ------------------------------------------------------------------ yüz: dev dikey ağız (koyu iç, dudak halkası, uzun sivri dişler), tek Rinne-Sharingan göz
static func _face(r: BeastRig, HD: Vector3) -> void:
	# baş pivotunun yerel uzayı (döndürülmemiş): ağız başın ön yüzünde, aşağıya kadar iner
	var RC := Vector3(0, -1.2, -1.5)   # yüzün (kapalı ön uç, dünya z -5.0) hemen önünde, alt yarıda; göz üstte kalır
	var RA := 2.9
	var RB := 3.7
	var mh := MB.new()
	var lip := []
	var lipr := []
	for k in 33:
		var a := TAU * k / 32.0
		lip.append(RC + Vector3(cos(a) * RA, sin(a) * RB, 0))
		lipr.append(0.6)
	Loft.tube(mh, lip, lipr, LIP, 8, 1, false, false)
	mh.add("sphere", RC + Vector3(0, 0, 0.25), Vector3(RA * 2.0, RB * 2.0, 0.35), MAW, Vector3.ZERO, 20)   # ağız boşluğu (yüze yapışık koyu iç)
	mh.add("sphere", RC + Vector3(0, -1.9, 0.05), Vector3(2.4, 1.1, 0.4), Color(0.2, 0.06, 0.06), Vector3.ZERO, 10)   # dil
	for i in 28:   # dişler: halkadan içe, üst-altta uzun kavisli, yanlarda kısa
		var a := TAU * (i + 0.5) / 28.0
		var o := Vector3(cos(a) * RA * 0.94, sin(a) * RB * 0.94, 0)
		var inw := -Vector3(cos(a), sin(a), 0)
		var ln := (1.0 + 1.6 * pow(absf(sin(a)), 1.4)) * (0.8 + 0.4 * fposmod(i * 0.37, 1.0))
		var side := Vector3(-sin(a), cos(a), 0) * (0.1 if i % 2 == 0 else -0.08)
		Loft.tube(mh, [RC + o - inw * 0.3 + Vector3(0, 0, 0.1), RC + o + inw * ln * 0.5 + Vector3(0, 0, -0.5) + side, RC + o + inw * ln + Vector3(0, 0, -0.15) + side * 0.4],
			[0.23, 0.15, 0.015], [BeastJubi.TV.darkened(0.4), BeastJubi.TV.darkened(0.12), BeastJubi.TV], 7, 4)
	for i in 18:
		var a := TAU * (i + 0.2) / 18.0
		var o := Vector3(cos(a) * RA * 0.78, sin(a) * RB * 0.78, 0.6)
		var inw := -Vector3(cos(a), sin(a), 0)
		var ln := 0.8 + 0.9 * absf(sin(a))
		Loft.tube(mh, [RC + o - inw * 0.2, RC + o + inw * ln * 0.5 + Vector3(0, 0, -0.15), RC + o + inw * ln], [0.16, 0.1, 0.015], BeastJubi.TV.darkened(0.5), 6, 3)
	# göz: ağzın üstünde, alnın ön yüzünde
	var EP := Vector3(0, 3.35, -1.55)
	mh.add("sphere", EP, Vector3(3.4, 2.0, 0.6), Color(0.03, 0.01, 0.01), Vector3.ZERO, 18)
	mh.add("sphere", EP + Vector3(0, 0, -0.16), Vector3(1.8, 1.5, 0.45), BeastJubi.EYE, Vector3.ZERO, 18)
	for ring in 3:
		var rr := 0.27 + ring * 0.21
		var pts := []
		var rads := []
		for k in 25:
			var a := TAU * k / 24.0
			pts.append(EP + Vector3(cos(a) * rr, sin(a) * rr * 0.8, -0.39 + rr * rr * 0.16))
			rads.append(0.037)
		Loft.tube(mh, pts, rads, BeastJubi.EYE_D, 4, 1, false, false)
		for k in 3:
			var a2 := TAU * k / 3.0 + ring * 0.7
			mh.add("sphere", EP + Vector3(cos(a2) * rr, sin(a2) * rr * 0.8, -0.41 + rr * rr * 0.16), Vector3(0.16, 0.16, 0.08), BeastJubi.EYE_D, Vector3.ZERO, 6)
	mh.add("sphere", EP + Vector3(0, 0, -0.39), Vector3(0.22, 0.22, 0.08), BeastJubi.EYE_D, Vector3.ZERO, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = mh.build(null)
	var em := StandardMaterial3D.new()
	em.vertex_color_use_as_albedo = true
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = em
	r.head.add_child(mi)
	r.mouth = r._pivot(r.head, RC + Vector3(0, 0, -0.6), "agiz")
