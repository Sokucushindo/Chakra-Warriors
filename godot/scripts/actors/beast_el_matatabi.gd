extends RefCounted
## Matatabi — İki Kuyruk, ELLE MODELLENMİŞ (Kurama ile aynı yöntem: iskelet + derili tek parça yüzey, beast_el.gd).
## Referans: _tmp/ref/matatabi (anime) + _tmp/ref/matatabi_storm (Storm 4 yan / ön kareler). Okunan yapı:
##  - mavi alevden YALIN büyük kedi, dört ayak üstünde; derin göğüs, ince bel, kalın but; bacaklar uzun, pençeler iri, beyaz tırnaklı
##  - boyun kalın, öne-yukarı; baş omuz hizasının üstünde, kama biçimli kaplan başı; geniş yanaklarda dışa savrulan alev tutamları
##  - burun köprüsünde V gibi birleşen siyah göz yamaları, içinde yuvarlak gözler (biri sarı, biri yeşil); geniş gri burun
##  - kocaman ağız: pembe dudak, sıra sivri dişler, köşeler yanağa kadar
##  - tüm gövdede KALIN siyah sarmal / virgül desenler; renk düz değil, açık-koyu mavi alev lekeleri; sırtta, dirsekte, topukta alev dilleri
##  - iki uzun kuyruk: gövdeden uzun, yassı-dalgalı, kenarlarında alev dilleri, uçta alev çatalı
## Pivot adları / sırası / kuyruk ayarı eski modeldeki gibi (animasyon ve oyun değişmez).
const BE = preload("res://scripts/actors/beast_el.gd")

const C := Color(0.16, 0.5, 0.98)
const HI := Color(0.45, 0.76, 1.0)
const DK := Color(0.02, 0.02, 0.07)
const FANG := Color(0.95, 0.97, 1.0)
const LIP := Color(0.92, 0.5, 0.6)
const MOUTH := Color(0.42, 0.1, 0.2)
const TONGUE := Color(0.86, 0.42, 0.52)
const NOSE := Color(0.42, 0.36, 0.5)
const CLAW := Color(0.88, 0.95, 1.0)


static func _g(x: float, s: float) -> float:
	return exp(-x * x / (s * s))


static func _tk(pts: Array) -> Array:
	var c := [0.0]
	for i in pts.size() - 1:
		c.append(float(c[i]) + (pts[i + 1] - pts[i]).length())
	var L: float = c[c.size() - 1]
	return c.map(func(x): return float(x) / L)


## Alev lekesi: açık / koyu mavi bulut (anime suluboya alev dokusu)
static func _mot(p: Vector3, k := 1.0) -> Color:
	var n := 0.5 + 0.5 * sin(p.x * 1.7 * k + p.z * 0.9 * k) * sin(p.y * 1.9 * k - p.z * 1.3 * k + 1.7)
	return C.lerp(HI, 0.55 * smoothstep(0.35, 0.9, n))


static func build(r: BeastRig, root: Node3D) -> void:
	r.quadruped = true
	r.upright = false
	var HP := Vector3(0, 5.8, 3.0)
	r.hips = r._pivot(root, HP, "kalca_kok")
	r._collider(r.hips, Vector3(0, 0.3, 0.4), Vector3(3.6, 3.8, 5.6))
	var CH := Vector3(0, 6.0, -2.0)
	r.chest = r._pivot(r.hips, CH - HP, "gogus")
	r._collider(r.chest, Vector3(0, -0.2, -0.9), Vector3(4.2, 4.6, 5.0))
	var HD := Vector3(0, 7.25, -6.1)
	r.head = r._pivot(r.chest, HD - CH, "bas")
	var face := r._pivot(r.head, Vector3(0, 0.1, 0), "yuz")
	face.rotation.x = deg_to_rad(-8)
	r.jaw_close = -0.2   # anime: hırlar gibi açık ağız
	r.jaw = r._pivot(face, Vector3(0, -0.5, 0.25), "cene")
	r.jaw.rotation.y = PI
	r.mouth = r._pivot(face, Vector3(0, -0.75, -2.3), "agiz")
	r.head.scale = Vector3.ONE * 1.02
	r._collider(r.head, Vector3(0, 0.1, -0.5), Vector3(4.2, 3.4, 4.4))
	var LG := {}
	for sx: float in [-1.0, 1.0]:
		var S := Vector3(1.95 * sx, 6.4, -3.1)
		var E := Vector3(2.1 * sx, 3.75, -2.3)
		var W := Vector3(2.05 * sx, 1.05, -2.9)
		var sh := r._pivot(r.chest, S - CH, "kalca")
		var el := r._pivot(sh, E - S, "diz")
		var hd := r._pivot(el, W - E, "el")
		r.legs.append({"hip": sh, "kn": el, "side": sx, "front": true})
		var H := Vector3(1.75 * sx, 6.1, 3.6)
		var K := Vector3(2.0 * sx, 3.95, 2.3)
		var HK := Vector3(1.95 * sx, 2.15, 4.6)
		var A := Vector3(1.95 * sx, 1.0, 4.0)
		var hi_ := r._pivot(r.hips, H - HP, "kalca")
		var kn := r._pivot(hi_, K - H, "diz")
		var hk := r._pivot(kn, HK - K, "topuk")
		var ft := r._pivot(hk, A - HK, "ayak")
		r.legs.append({"hip": hi_, "kn": kn, "side": sx, "front": false})
		LG[sx] = {"S": S, "E": E, "W": W, "sh": sh, "el": el, "hd": hd, "H": H, "K": K, "HK": HK, "A": A, "hi": hi_, "kn": kn, "hk": hk, "ft": ft}
	# kuyruklar: eski modelle aynı pivotlar ve ayarlar (randf sırası dahil)
	var n := 10
	var length := 15.0
	var seg_len := length / n
	var tbase := r._pivot(r.hips, Vector3(0, 6.2, 4.7) - HP, "kuyruk_koku")
	r.tail_curl = -0.015
	var TL := []
	for ti in 2:
		var yaw := -13.0 if ti == 0 else 13.0
		var pitch := -10.0 - ti * 12.0
		var troot := r._pivot(tbase, Vector3.ZERO, "tail")
		troot.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
		var segs := []
		var parent: Node3D = troot
		for i in n:
			var piv := r._pivot(parent, Vector3(0, 0, seg_len) if i > 0 else Vector3.ZERO, "s%d" % i)
			segs.append(piv)
			parent = piv
		r.tails.append(segs)
		r.tail_cfg.append({"yaw": deg_to_rad(yaw), "pitch": deg_to_rad(pitch), "amp": 0.2, "phase": randf() * TAU, "style": "flame", "root": troot})
		TL.append([troot, segs, length, seg_len, ti])
	r._weak(r.head, Vector3(0, 1.8, 0.1))
	r._weak(r.chest, Vector3(0, 1.85, -0.5))
	r._weak(r.hips, Vector3(0, 2.3, 0.5))
	for sx: float in [-1.0, 1.0]:
		var g: Dictionary = LG[sx]
		for cd in [[g["sh"], g["S"], g["E"], 1.9], [g["el"], g["E"], g["W"], 1.3], [g["hi"], g["H"], g["K"], 2.2]]:
			var dv: Vector3 = (cd[2] as Vector3) - (cd[1] as Vector3)
			r._collider(cd[0], dv * 0.5, Vector3(float(cd[3]), dv.length() + 0.5, float(cd[3])))
			var mk: Node3D = r.colliders[r.colliders.size() - 1]
			mk.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))
	# ---------------- iskelet + köprü
	var be = BE.new()
	be.rig(r, root, [["omurga1", r.hips, r.chest, 0.33, Vector3(0, 6.2, 1.3)], ["omurga2", r.hips, r.chest, 0.67, Vector3(0, 6.1, -0.4)],
		["boyun", r.chest, r.head, 0.5, Vector3(0, 6.7, -4.9)]])
	be.shade = func(c: Color, nv: Vector3) -> Color: return c.lerp(Color(c.r * 0.6, c.g * 0.62, c.b * 0.78), smoothstep(0.3, 0.85, -nv.y) * 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2202
	_torso(be, r, LG, rng)
	for sx: float in [-1.0, 1.0]:
		_arm(be, r, LG[sx], sx, rng)
		_leg(be, r, LG[sx], sx, rng)
	for e in TL:
		_tail(be, e[0], e[1], e[2], e[3], e[4], rng)
	be.begin_head()   # baş ayrı ağ: Susanoo zırhı yüzü ince katmanla kaplar
	_head(be, r, face)
	be.finish(BeastKurama.mat())
	BeastModels._particles(r.hips, Vector3(2.0, 1.8, 3.4), [Color(0.4, 0.65, 1.0, 0.95), Color(0.02, 0.02, 0.15, 0.0)], 160, 2.0, Vector3(0, 7, 0), 1.0, true)
	BeastModels._particles(r.chest, Vector3(2.0, 2.2, 2.0), [Color(0.4, 0.65, 1.0, 0.95), Color(0.02, 0.02, 0.15, 0.0)], 90, 1.8, Vector3(0, 7, 0), 0.9, true)


## Siyah sarmal / virgül desen: (t0, a0) merkezli, s boyunda, sonunda kuyruğu olan kalın kıvrım (anime alev deseni)
static func _swirl(be, info: Dictionary, t0: float, a0: float, s: float, sk: Callable, turns := 1.35, rot := 0.0, flip := 1.0) -> void:
	var L: float = info["L"]
	var x := clampf(t0, 0.0, 1.0) * int(info["rings"])
	var rr: Vector2 = info["R"][mini(int(x), int(info["rings"]))]
	var Rm := maxf(0.3, (rr.x + rr.y) * 0.5)
	var path := []
	var th_max := turns * TAU
	var last := Vector2.ZERO
	var N := 26
	for i in N:
		var u := float(i) / (N - 1)
		var th := u * th_max
		var rad := s * (0.1 + 0.9 * u)
		last = Vector2(cos(th * flip + rot), sin(th * flip + rot)) * rad
		path.append(last)
	# kuyruk: son teğet yönünde, hafif kıvrılarak uzar
	var th2 := th_max
	var tan := Vector2(-sin(th2 * flip + rot), cos(th2 * flip + rot)) * flip
	for k in range(1, 5):
		var q := last + tan * s * 0.42 * k + last.normalized() * s * 0.06 * k * k
		path.append(q)
	var tp := []
	for q in path:
		tp.append(Vector2(t0 + q.x / L, a0 + q.y / Rm))
	be.band(info, tp, func(u): return s * 0.27 * (0.3 + 0.7 * smoothstep(0.0, 0.25, u)) * (1.0 - 0.9 * smoothstep(0.78, 1.0, u)), DK, sk, 0.03, 3)


## Alev dili: yüzeyden çıkan yassı sivri tutam (rengi açık / koyu mavi)
static func _flame_on(be, s: Array, dir: Vector3, ln: float, w: float, skf: Callable, col := C, xf := Transform3D.IDENTITY, t := 0.0) -> void:
	var p: Vector3 = s[0]
	var sw: Array = skf.call(t, 0.0, p)
	var nr: Vector3 = s[1]
	var d := dir.normalized()
	d = (d - nr * d.dot(nr) * 0.75 + nr * 0.12).normalized()   # yüzeye yatık, dışa hafif kalkık (diken gibi dik durmaz)
	be.tuft(p, nr, d, ln * 0.85, w * 1.9, col, sw, xf, 0.3, 0.38)


# ------------------------------------------------------------------ gövde + boyun: sağrıdan kafatasının içine tek tüp
static func _torso(be, r: BeastRig, LG: Dictionary, rng: RandomNumberGenerator) -> void:
	var tp := [Vector3(0, 6.0, 5.4), Vector3(0, 6.15, 5.0), Vector3(0, 6.3, 4.1), Vector3(0, 6.3, 3.0), Vector3(0, 6.15, 1.6), Vector3(0, 6.05, 0.2),
		Vector3(0, 5.95, -1.2), Vector3(0, 5.75, -2.4), Vector3(0, 5.95, -3.6), Vector3(0, 6.5, -4.7), Vector3(0, 6.95, -5.5), Vector3(0, 7.15, -6.0)]
	var tr := [Vector2(0.3, 0.3), Vector2(1.15, 1.2), Vector2(1.75, 1.85), Vector2(1.7, 1.8), Vector2(1.4, 1.5), Vector2(1.3, 1.45),
		Vector2(1.7, 2.0), Vector2(1.95, 2.25), Vector2(1.85, 2.0), Vector2(1.45, 1.5), Vector2(1.25, 1.25), Vector2(1.1, 1.05)]
	var tz := func(z: float) -> float: return clampf((5.4 - z) / 11.4, 0.0, 1.0)
	var anch := [[4.6, r.hips], [3.0, r.hips], [1.3, "omurga1"], [-0.4, "omurga2"], [-2.0, r.chest], [-3.8, r.chest], [-4.9, "boyun"], [-5.8, r.head]]
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var l: Array = BE.chain(p.z, anch)
		for sx: float in [-1.0, 1.0]:
			var g: Dictionary = LG[sx]
			var w := 0.5 * (1.0 - smoothstep(0.8, 2.4, p.distance_to(g["S"])))
			var w2 := 0.4 * (1.0 - smoothstep(1.0, 2.6, p.distance_to(g["H"])))
			for e in l:
				e[1] = float(e[1]) * (1.0 - w - w2)
			if w > 0.0:
				l.append([g["sh"], w])
			if w2 > 0.0:
				l.append([g["hi"], w2])
		return l
	var colf := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := absf(wrapf(a, -PI, PI))
		if aw > PI - 0.6 + 0.18 * sin(p.z * 3.1) + 0.08 * sin(p.z * 7.3):
			return DK   # karın / göğüs altı siyah, alev dişli kenar
		return _mot(p)
	var bump := func(t: float, a: float) -> float:
		var aw := wrapf(a, -PI, PI)
		var scap := 0.07 * _g(t - float(tz.call(-3.2)), 0.06) * _g(absf(aw) - 0.55, 0.25)
		var belly := -0.08 * _g(t - float(tz.call(0.6)), 0.1) * _g(absf(aw) - PI, 0.8)
		var ribs := 0.04 * _g(t - float(tz.call(-1.6)), 0.08) * _g(absf(aw) - 1.6, 0.4)
		return scap + belly + ribs
	var info: Dictionary = be.tube(tp, tr, colf, sk, 64, 30, Vector3.UP, false, true, bump)
	# siyah sarmallar: sırtta ve yanlarda dağınık, büyüklü küçüklü
	var spots := [[4.2, 0.9], [3.2, 1.6], [2.0, 0.6], [1.0, 1.4], [-0.2, 0.8], [-1.0, 1.7], [-2.2, 1.1], [-3.3, 0.6], [-4.0, 1.5], [4.0, 2.0], [0.4, 2.1], [-2.6, 2.2]]
	for sx: float in [-1.0, 1.0]:
		for sp in spots:
			var s := rng.randf_range(0.75, 1.1)
			_swirl(be, info, tz.call(float(sp[0]) + rng.randf_range(-0.3, 0.3)), sx * (float(sp[1]) + rng.randf_range(-0.1, 0.1)), s, sk, rng.randf_range(1.1, 1.5), rng.randf_range(0, TAU), sx)
	for z in [3.6, 0.6, -1.8]:
		_swirl(be, info, tz.call(z), 0.0, 0.8, sk, 1.2, rng.randf_range(0, TAU))
	# sırt çizgisi alev dilleri: geriye-yukarı savrulur
	for i in 8:
		var z := lerpf(4.8, -4.6, i / 7.0) + rng.randf_range(-0.3, 0.3)
		var t: float = tz.call(z)
		var s: Array = BE.at(info, t, (i % 2 - 0.5) * 0.35)
		_flame_on(be, s, Vector3((i % 2 - 0.5) * 0.4, 0.55, 1.0), rng.randf_range(1.1, 1.7), 0.5, sk, HI if i % 3 == 1 else C)
	# göğüs altı ve karın: aşağı-geri sarkan diller
	for i in 6:
		var z := lerpf(-3.8, 1.2, i / 5.0)
		var t: float = tz.call(z)
		for sx: float in [-1.0, 1.0]:
			var s: Array = BE.at(info, t, sx * (PI - 0.7))
			_flame_on(be, s, Vector3(0.3 * sx, -1.0, 0.6), rng.randf_range(0.8, 1.2), 0.4, sk, C)
	# sağrı yanları ve ense
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var s: Array = BE.at(info, tz.call(4.4 - k * 0.6), sx * (1.3 + k * 0.25))
			_flame_on(be, s, Vector3(0.4 * sx, 0.1, 1.0), 1.2 - k * 0.15, 0.45, sk, HI if k == 1 else C)
		for k in 3:
			var s2: Array = BE.at(info, tz.call(-4.9 + k * 0.4), sx * (0.7 + k * 0.3))
			_flame_on(be, s2, Vector3(0.5 * sx, 0.5, 1.0), 1.5 - k * 0.2, 0.5, sk, C if k != 1 else HI)


# ------------------------------------------------------------------ ön bacak: kürek -> pazı -> dirsek -> ön kol -> bilek -> pençe
static func _arm(be, r: BeastRig, g: Dictionary, sx: float, rng: RandomNumberGenerator) -> void:
	var S: Vector3 = g["S"]
	var E: Vector3 = g["E"]
	var W: Vector3 = g["W"]
	var pts := [S + Vector3(-0.7 * sx, 0.9, 0.35), S + Vector3(0.15 * sx, 0.1, 0.0), S.lerp(E, 0.5) + Vector3(0.15 * sx, 0, 0.2), E, E.lerp(W, 0.35) + Vector3(0.05 * sx, 0, -0.05),
		E.lerp(W, 0.75), W, W + Vector3(0, -0.42, -0.55), W + Vector3(0, -0.55, -1.05)]
	var rad := [Vector2(1.1, 1.2), Vector2(1.25, 1.35), Vector2(0.98, 1.08), Vector2(0.74, 0.8), Vector2(0.78, 0.8), Vector2(0.62, 0.62), Vector2(0.56, 0.55), Vector2(0.9, 0.48), Vector2(0.78, 0.4)]
	var tk := _tk(pts)
	var t1: float = tk[1]
	var tE: float = tk[3]
	var tW: float = tk[6]
	var sh: Node3D = g["sh"]
	var el: Node3D = g["el"]
	var hd: Node3D = g["hd"]
	var sk := func(t: float, _a: float, _p: Vector3) -> Array:
		if t < t1:
			var u := smoothstep(0.0, t1, t)
			return [[r.chest, 0.55 * (1.0 - u)], [sh, 1.0 - 0.55 * (1.0 - u)]]
		return BE.chain(t, [[t1, sh], [tE - 0.05, sh], [tE + 0.06, el], [tW, el], [tW + 0.06, hd]])
	var bump := func(t: float, a: float) -> float:
		return 0.07 * _g(t - lerpf(t1, tE, 0.4), 0.08) * maxf(0.0, cos(a - PI * 0.5 * sx - 0.5 * sx)) + 0.05 * _g(t - lerpf(tE, tW, 0.3), 0.07) * maxf(0.0, sin(a) * sx)
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, p): return _mot(p, 1.3), sk, 56, 24, Vector3.UP, false, true, bump)
	for k in 3:
		var t := lerpf(t1 + 0.04, tW - 0.08, k / 2.0)
		_swirl(be, info, t, BE.a_dir(info, t, Vector3(sx, 0.1, -0.3)), rng.randf_range(0.36, 0.44), sk, 1.2, rng.randf_range(0, TAU), sx)
	# dirsek arkasından geriye alev dilleri
	for k in 3:
		var t := tE - 0.03 + k * 0.06
		var s: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0.2 * sx, 0.1, 1.0)))
		_flame_on(be, s, Vector3(0.15 * sx, 0.35 - k * 0.15, 1.0), 1.3 - k * 0.25, 0.4, sk, HI if k == 1 else C, Transform3D.IDENTITY, t)
	_paw(be, W, sx, [[hd, 1.0]], 1.0)


## Kedi pençesi: yuvarlak avuç, dört şiş parmak, beyaz kıvrık tırnaklar
static func _paw(be, W: Vector3, sx: float, hsk: Array, sc: float) -> void:
	for f in 4:
		var fa := lerpf(-0.75, 0.75, f / 3.0)
		var fl := (1.0 - absf(fa) * 0.15) * sc
		var b0 := W + Vector3(sin(fa) * 0.62, -0.55, -0.75 - cos(fa) * 0.25)
		var b1 := b0 + Vector3(sin(fa) * 0.25, 0.12, -0.5) * fl
		var b2 := b1 + Vector3(sin(fa) * 0.12, -0.32, -0.35) * fl
		be.tube([b0, b1, b2], [Vector2(0.36, 0.32) * fl, Vector2(0.34, 0.3) * fl, Vector2(0.22, 0.2) * fl],
			func(_t, _a, p): return _mot(p, 1.6), func(_t, _a, _p): return hsk, 10, 12, Vector3.UP, false, true)
		be.claw(b2 + Vector3(0, 0.05, -0.05), Vector3(sin(fa) * 0.25, -0.45, -1.0), 0.75 * fl, 0.13 * fl, CLAW, hsk)
	be.tube([W + Vector3(0, -0.72, -0.35), W + Vector3(0, -0.78, -0.95)], [Vector2(0.6, 0.15), Vector2(0.5, 0.13)], func(_t, _a, _p): return DK, func(_t, _a, _p): return hsk, 6, 10, Vector3.UP, true, true)
	be.claw(W + Vector3(-0.55 * sx, -0.2, -0.25), Vector3(-0.4 * sx, -0.6, -0.7), 0.42, 0.1, CLAW, hsk)


# ------------------------------------------------------------------ arka bacak: but -> uyluk -> diz -> baldır -> topuk -> pençe
static func _leg(be, r: BeastRig, g: Dictionary, sx: float, rng: RandomNumberGenerator) -> void:
	var H: Vector3 = g["H"]
	var K: Vector3 = g["K"]
	var HK: Vector3 = g["HK"]
	var A: Vector3 = g["A"]
	var pts := [H + Vector3(-0.8 * sx, 0.8, 0.3), H + Vector3(0.2 * sx, 0.1, 0.3), H.lerp(K, 0.5) + Vector3(0.15 * sx, 0, 0.35), K, K.lerp(HK, 0.45),
		HK, HK.lerp(A, 0.5), A, A + Vector3(0, -0.42, -0.5), A + Vector3(0, -0.55, -1.0)]
	var rad := [Vector2(1.25, 1.3), Vector2(1.6, 1.7), Vector2(1.2, 1.3), Vector2(0.72, 0.78), Vector2(0.6, 0.64), Vector2(0.45, 0.47), Vector2(0.42, 0.44), Vector2(0.52, 0.48), Vector2(0.85, 0.44), Vector2(0.74, 0.38)]
	var tk := _tk(pts)
	var t1: float = tk[1]
	var tK: float = tk[3]
	var tH: float = tk[5]
	var tA: float = tk[7]
	var hi_: Node3D = g["hi"]
	var kn: Node3D = g["kn"]
	var hk: Node3D = g["hk"]
	var ft: Node3D = g["ft"]
	var sk := func(t: float, _a: float, _p: Vector3) -> Array:
		if t < t1:
			var u := smoothstep(0.0, t1, t)
			return [[r.hips, 0.55 * (1.0 - u)], [hi_, 1.0 - 0.55 * (1.0 - u)]]
		return BE.chain(t, [[t1, hi_], [tK - 0.05, hi_], [tK + 0.05, kn], [tH - 0.03, kn], [tH + 0.03, hk], [tA - 0.03, hk], [tA + 0.04, ft]])
	var bump := func(t: float, a: float) -> float:
		return 0.08 * _g(t - lerpf(tK, tH, 0.35), 0.06) * maxf(0.0, -cos(a))
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, p): return _mot(p, 1.3), sk, 60, 24, Vector3.UP, false, true, bump)
	for k in 3:
		var t := lerpf(t1 * 0.8, lerpf(tK, tH, 0.4), k / 2.0)
		_swirl(be, info, t, BE.a_dir(info, t, Vector3(sx, 0.2, 0.1)), rng.randf_range(0.55, 0.65) * (1.0 - k * 0.3), sk, 1.25, rng.randf_range(0, TAU), sx)
	# but arkası ve topuk alev dilleri
	for k in 3:
		var t := lerpf(t1 * 0.7, lerpf(t1, tK, 0.6), k / 2.0)
		var s: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0.3 * sx, -0.1, 1.0)))
		_flame_on(be, s, Vector3(0.2 * sx, -0.2, 1.0), 1.4 - k * 0.2, 0.45, sk, HI if k == 1 else C, Transform3D.IDENTITY, t)
	for k in 2:
		var t := tH - 0.02 + k * 0.05
		var s2: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0, 0.3, 1.0)))
		_flame_on(be, s2, Vector3(0.1 * sx, 0.4, 1.0), 1.1 - k * 0.2, 0.38, sk, C, Transform3D.IDENTITY, t)
	_paw(be, A, sx, [[ft, 1.0]], 0.95)


# ------------------------------------------------------------------ baş (yüz pivotunun yerel uzayında, ileri -Z)
static func _head(be, r: BeastRig, face: Node3D) -> void:
	var F: Transform3D = be.rs(face)
	var fsk := [[face, 1.0]]
	var sk := func(_t, _a, _p): return fsk
	var hp := [Vector3(0, 0.25, 1.35), Vector3(0, 0.45, 0.95), Vector3(0, 0.55, 0.25), Vector3(0, 0.42, -0.55), Vector3(0, 0.18, -1.25), Vector3(0, -0.02, -1.8),
		Vector3(0, -0.1, -2.25), Vector3(0, -0.14, -2.5), Vector3(0, -0.15, -2.6)]
	var hr := [Vector2(0.5, 0.45), Vector2(1.2, 1.0), Vector2(1.55, 1.18), Vector2(1.45, 1.05), Vector2(1.08, 0.8), Vector2(0.88, 0.62), Vector2(0.72, 0.5), Vector2(0.4, 0.32), Vector2(0.05, 0.05)]
	var tz := func(z: float) -> float: return clampf((1.35 - z) / 3.95, 0.0, 1.0)
	var lipA := func(z: float) -> float: return lerpf(1.3, 0.55, clampf(inverse_lerp(0.1, -2.35, z), 0.0, 1.0))
	var colf := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := wrapf(a, -PI, PI)
		if p.z < 0.05 and p.z > -2.35 and absf(aw) > PI - float(lipA.call(p.z)) + 0.06:
			return MOUTH
		return _mot(p, 2.0)
	var bump := func(t: float, a: float) -> float:   # kaş kemeri + yanak şişkinliği
		var aw := wrapf(a, -PI, PI)
		return 0.06 * _g(t - float(tz.call(-0.75)), 0.05) * _g(absf(aw) - 0.6, 0.25) + 0.06 * _g(t - float(tz.call(-0.3)), 0.12) * _g(absf(aw) - 1.7, 0.4)
	var hi: Dictionary = be.tube(hp, hr, colf, sk, 48, 34, Vector3.UP, true, true, bump, F)
	# geniş gri-mor burun + dudağa inen çizgi
	be.tube([Vector3(0, -0.02, -2.3), Vector3(0, 0.0, -2.52), Vector3(0, -0.08, -2.72)], [Vector2(0.05, 0.04), Vector2(0.3, 0.16), Vector2(0.05, 0.04)],
		func(_t, _a, _p): return NOSE, sk, 10, 18, Vector3.UP, true, true, Callable(), F)
	be.band(hi, [Vector2(tz.call(-2.45), PI), Vector2(tz.call(-2.35), PI)], func(_u): return 0.03, DK, sk, 0.02)
	# alın: yukarı-geriye çıkan siyah alev darbeleri (ortada uzun, yanlarda kısa)
	for k in 7:
		var fa := (k - 3.0) * 0.25
		var z0 := -1.2 + absf(k - 3.0) * 0.1
		var ln := 1.0 - absf(k - 3.0) * 0.12
		be.band(hi, [Vector2(tz.call(z0), fa), Vector2(tz.call(z0 + ln * 0.5), fa + 0.05 * (k - 3.0)), Vector2(tz.call(z0 + ln), fa + 0.11 * (k - 3.0))],
			func(u): return 0.13 * pow(sin(clampf(u, 0.03, 0.97) * PI), 0.8) * (1.3 - u * 0.6) + 0.01, DK, sk, 0.03)
	for k in 2:   # burun köprüsü kırışıkları
		var z := -1.75 - k * 0.15
		be.band(hi, [Vector2(tz.call(z + 0.03), -0.45), Vector2(tz.call(z), 0.0), Vector2(tz.call(z + 0.03), 0.45)], func(u): return 0.03 * sin(clampf(u, 0.05, 0.95) * PI) + 0.008, DK, sk, 0.02)
	for sx: float in [-1.0, 1.0]:
		# siyah göz yaması: dış üst köşeden gözün üstünden geçip burun köprüsünde ortada birleşir
		be.band(hi, [Vector2(tz.call(-0.35), 1.35 * sx), Vector2(tz.call(-0.75), 1.1 * sx), Vector2(tz.call(-1.15), 0.72 * sx), Vector2(tz.call(-1.45), 0.36 * sx), Vector2(tz.call(-1.6), 0.0)],
			func(u): return 0.36 * pow(sin(clampf(u * 0.85 + 0.05, 0.0, 1.0) * PI), 0.7) + 0.03, DK, sk, 0.035)
		# göz: yuvarlak, düz renk; sağ sarı, sol yeşil
		var ed: Array = BE.at(hi, tz.call(-1.05), 0.82 * sx, 0.04)
		var nrm := ((ed[1] as Vector3) + Vector3(0, 0, -1.3)).normalized()
		var eb := Basis.looking_at(nrm, Vector3.UP)
		var iris := Color(1.0, 0.86, 0.3) if sx > 0 else Color(0.1, 0.72, 0.6)
		BeastModels._anime_eye(r, face, (ed[0] as Vector3) + nrm * 0.1, Vector3(0.32, 0.3, 0.07), iris, iris, iris, eb.get_euler() * 180.0 / PI, "none")
		# yanak bıyık çizgileri
		for k in 3:
			var wa := sx * (1.45 + k * 0.22)
			be.band(hi, [Vector2(tz.call(-1.6 + k * 0.05), wa - 0.1 * sx), Vector2(tz.call(-1.25 + k * 0.05), wa + 0.02 * sx), Vector2(tz.call(-0.85 + k * 0.05), wa + 0.12 * sx)],
				func(u): return 0.1 * sin(clampf(u, 0.03, 0.97) * PI) * (1.3 - u * 0.6) + 0.008, DK, sk, 0.025)
		# üst dudak (pembe) + diş sırası
		var lp := []
		for i in 7:
			var z := lerpf(0.05, -2.35, i / 6.0)
			lp.append(Vector2(tz.call(z), PI - sx * float(lipA.call(z))))
		be.band(hi, lp, func(u): return 0.1 * (1.0 - 0.35 * u), LIP, sk, 0.04)
		for i in range(1, 10):
			var z := lerpf(-0.1, -2.25, i / 9.5)
			var canine := i == 7
			var s: Array = BE.at(hi, tz.call(z), PI - sx * (float(lipA.call(z)) - 0.1))
			be.claw((s[0] as Vector3) + Vector3(0, 0.04, 0), Vector3(-0.06 * sx, -1.0, 0.05), 0.62 if canine else 0.26 + 0.06 * (i % 2), 0.12 if canine else 0.075, FANG, fsk, F, Vector3(0, 0, 1), 6)
		# uzun sivri kulak: dışa-geriye yatık, içi siyah
		var e0 := Vector3(0.85 * sx, 0.95, 0.35)
		var e1 := Vector3(2.3 * sx, 2.55, 1.9)
		var em := e0.lerp(e1, 0.45) + Vector3(0.15 * sx, 0.2, -0.1)
		var ew := Vector3(sx, -0.6, -0.2).normalized()
		var en := (e1 - e0).normalized().cross(ew).normalized()
		if en.z > 0.0:
			en = -en
		var ecol := func(t: float, a: float, _p: Vector3) -> Color:
			return DK if cos(a) > 0.6 and t > 0.18 and t < 0.88 else C
		be.tube([e0, e0.lerp(em, 0.5), em, em.lerp(e1, 0.55), e1], [Vector2(0.5, 0.22), Vector2(0.54, 0.18), Vector2(0.42, 0.14), Vector2(0.3, 0.1), Vector2(0.02, 0.02)],
			ecol, sk, 30, 22, en, false, true, Callable(), F)
		# yanakta dışa-geriye savrulan büyük alev tutamları (yüzü yanlara genişletir)
		for k in 6:
			var z := 0.35 - k * 0.2
			var s: Array = BE.at(hi, tz.call(z), sx * (PI * 0.5 + 0.1 + k * 0.16))
			_flame_on(be, s, Vector3(1.0 * sx, 0.2 - k * 0.16, 0.75), (2.0 - k * 0.15) * (1.0 if k % 2 == 0 else 0.8), 0.48, sk, HI if k % 2 == 1 else C, F)
	# tepe alevleri: kafanın üstünden geriye-yukarı yalayan diller
	for k in 5:
		var s: Array = BE.at(hi, tz.call(0.6 - k * 0.25), (k % 2 - 0.5) * 0.5)
		_flame_on(be, s, Vector3((k % 2 - 0.5) * 0.4, 0.25, 1.0), 1.1 - k * 0.08, 0.38, sk, HI if k % 2 == 0 else C, F)
	# alt çene: ağız içi pembe dil, kenarda pembe dudak ve dişler, altı siyah
	var jsk := [[r.jaw, 1.0]]
	var jk := func(_t, _a, _p): return jsk
	var jp := [Vector3(0, -0.6, 0.3), Vector3(0, -0.66, -0.6), Vector3(0, -0.62, -1.45), Vector3(0, -0.56, -2.0), Vector3(0, -0.5, -2.3), Vector3(0, -0.48, -2.42)]
	var jr := [Vector2(1.2, 0.34), Vector2(1.0, 0.34), Vector2(0.72, 0.28), Vector2(0.48, 0.2), Vector2(0.26, 0.13), Vector2(0.04, 0.04)]
	var jcol := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := wrapf(a, -PI, PI)
		if absf(aw) < 0.85 and p.z < 0.1:
			return TONGUE if absf(aw) < 0.45 and p.z < -0.4 and p.z > -1.9 else MOUTH
		return DK if absf(aw) > 2.2 else _mot(p, 2.0)
	var ji: Dictionary = be.tube(jp, jr, jcol, jk, 26, 24, Vector3.UP, true, true, Callable(), F)
	var jtz := func(z: float) -> float: return clampf((0.3 - z) / 2.72, 0.0, 1.0)
	for sx: float in [-1.0, 1.0]:
		var lp2 := []
		for i in 7:
			lp2.append(Vector2(jtz.call(lerpf(0.1, -2.3, i / 6.0)), 0.95 * sx))
		be.band(ji, lp2, func(u): return 0.09 * (1.0 - 0.35 * u), LIP, jk, 0.035)
		for i in range(1, 9):
			var z := lerpf(-0.1, -2.2, (i + 0.5) / 9.0)
			var canine := i == 6
			var s: Array = BE.at(ji, jtz.call(z), 0.82 * sx)
			be.claw((s[0] as Vector3) - Vector3(0, 0.03, 0), Vector3(-0.06 * sx, 1.0, 0.0), 0.5 if canine else 0.24, 0.1 if canine else 0.07, FANG, jsk, F, Vector3(0, 0, 1), 6)
		var sc: Array = BE.at(ji, jtz.call(-0.6), sx * 2.3)
		_flame_on(be, sc, Vector3(0.4 * sx, -0.7, 0.8), 1.2, 0.36, jk, C, F)


# ------------------------------------------------------------------ kuyruk: kökten uca tek yassı tüp, kenarlarında alev dilleri, uçta çatal
static func _tail(be, troot: Node3D, segs: Array, length: float, seg_len: float, ti: int, rng: RandomNumberGenerator) -> void:
	var X: Transform3D = be.rs(troot)
	var rf := func(k: float) -> float:
		return lerpf(0.85, 1.45, sin(minf(1.0, k * 2.4) * PI * 0.5)) * (1.0 - pow(maxf(0.0, (k - 0.3) / 0.7), 1.8) * 0.85)
	var pts := []
	var rad := []
	for i in 16:
		var k := float(i) / 15.0
		var z := lerpf(-0.8, length, k)
		pts.append(Vector3(0.18 * sin(k * 7.0 + ti), 0, z))
		var rr: float = rf.call(clampf(z / length, 0.0, 1.0))
		rad.append(Vector2(rr * 0.7, rr))
	var n := segs.size()
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var f := clampf(p.z / seg_len - 0.5, 0.0, n - 1.0)
		var i0 := mini(int(f), n - 1)
		var i1 := mini(i0 + 1, n - 1)
		var w := f - i0
		return [[segs[i0], 1.0 - w], [segs[i1], w]]
	var col := func(_t: float, _a: float, p: Vector3) -> Color: return _mot(p * 0.9 + Vector3(ti * 3.0, 0, 0), 1.2).lerp(HI, clampf(p.z / length, 0.0, 1.0) * 0.3)
	var bump := func(t: float, a: float) -> float:
		return 0.05 * sin(a * 4.0 + t * 19.0 + ti) * smoothstep(0.05, 0.2, t) * (1.0 - smoothstep(0.8, 0.95, t))
	var info: Dictionary = be.tube(pts, rad, col, sk, 60, 18, Vector3.UP, false, true, bump, X)
	# yan yüzlerde siyah sarmallar
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var t := 0.12 + k * 0.19 + rng.randf_range(-0.03, 0.03)
			_swirl(be, info, t, side * PI * 0.5, rng.randf_range(0.65, 0.8) * (1.0 - t * 0.4), sk, 1.2, rng.randf_range(0, TAU), side)
	# üst ve alt kenardan geriye savrulan alev dilleri
	var xs := func(t: float, a: float, p: Vector3) -> Array: return sk.call(t, a, X.affine_inverse() * p)
	for i in 9:
		var t := 0.08 + i * 0.1 + rng.randf_range(-0.025, 0.025)
		for e in 2:
			if e == 1 and i % 2 == 0:
				continue
			var a := 0.0 if e == 0 else PI
			var s: Array = BE.at(info, t, a + rng.randf_range(-0.2, 0.2))
			var nr: Vector3 = s[1]
			var ln: float = float(info["R"][mini(int(t * 60), 60)].y) * rng.randf_range(1.1, 1.8)
			_flame_on(be, [X * (s[0] as Vector3), X.basis * nr], X.basis * (Vector3(0, 0, 1) + nr * 0.35), ln * 1.25, 0.68 * (1.0 - t * 0.4), xs, HI if i % 3 == 1 else C, Transform3D.IDENTITY, t)
	# uç alev çatalı
	for f in 3:
		var nr2 := Vector3(cos(f * 2.1 + ti) * 0.7, sin(f * 2.1 + ti), 0)
		var tip := Vector3(0, 0, length - 0.6)
		_flame_on(be, [X * tip, X.basis * nr2.normalized()], X.basis * (Vector3(0, 0, 1) + nr2 * 0.45), 2.3, 0.55, xs, HI if f == 0 else C, Transform3D.IDENTITY, 0.95)
