extends RefCounted
## Kurama — Dokuz Kuyruk, ELLE MODELLENMİŞ (deneme; BeastModels.KURAMA_EL ya da KURAMA_EL=1 ile açılır).
## Biçim notları beast_kurama.gd başındaki referans okumasıyla aynı (_tmp/ref/kurama):
##  - düz turuncu-kızıl cel, alt yüzler koyu; üst gövde iri, omuz kütleleri başın hizasından yüksek, baş omuzların arasında öne-aşağı
##  - uzun kaslı kollar (dirsekte sivri kürk), beş parmaklı uzun pençeli eller yere açık basar; ince bel, kambur sırt
##  - arka bacaklar tilki (diz önde, topuk geride yukarıda); baş uçurtma (yanakta geriye sivri tutamlar, ince sivri burun)
##  - siyah göz bandı kulağın dibine çıkar; kulak yassı yaprak, içi siyah; ağız yanağa kadar sırıtış; 9 kalın kuyruk yelpaze
## Yöntem (kıyafetlerdeki el modelleme): her parça tek parça kesintisiz yüzey, her köşe gerçek kemiğe ağırlıkla bağlı
## (beast_el.gd). Pivot düzeni / çarpıştırıcı / zayıf nokta / kuyruk ayarı eski modelle AYNI: animasyon ve oyun değişmez.
const BE = preload("res://scripts/actors/beast_el.gd")

const C := Color(0.95, 0.44, 0.1)
const CL := Color(1.0, 0.58, 0.22)
const LINE := Color(0.5, 0.17, 0.04)     # kas / kırışık çizgisi (anime ince koyu çizgi)
const BLK := Color(0.06, 0.035, 0.05)
const LIP := Color(0.1, 0.07, 0.08)
const MOUTH := Color(0.3, 0.05, 0.07)
const TONGUE := Color(0.62, 0.2, 0.22)
const FANG := Color(1.0, 0.98, 0.94)
const CLAW := Color(0.93, 0.91, 0.86)


static func _g(x: float, s: float) -> float:
	return exp(-x * x / (s * s))


## Kontrol noktalarının yaklaşık yay parametresi (eklem yerlerinin t değeri)
static func _tk(pts: Array) -> Array:
	var c := [0.0]
	for i in pts.size() - 1:
		c.append(float(c[i]) + (pts[i + 1] - pts[i]).length())
	var L: float = c[c.size() - 1]
	return c.map(func(x): return float(x) / L)


static func build(r: BeastRig, root: Node3D) -> void:
	r.quadruped = true
	r.upright = false
	# ---------------- pivotlar (eski modelle birebir aynı yer / ad / sıra)
	var HP := Vector3(0, 5.5, 5.2)
	r.hips = r._pivot(root, HP, "kalca_kok")
	r._collider(r.hips, Vector3(0, 0.2, -1.6), Vector3(3.6, 4.6, 7.8))
	var CH := Vector3(0, 7.6, -1.4)
	r.chest = r._pivot(r.hips, CH - HP, "gogus")
	r._collider(r.chest, Vector3(0, 0.5, -1.4), Vector3(6.4, 6.0, 5.6))
	var HD := Vector3(0, 5.3, -7.3)
	r.head = r._pivot(r.chest, HD - CH, "bas")
	var face := r._pivot(r.head, Vector3(0, 0.1, 0), "yuz")
	face.rotation.x = deg_to_rad(-6)
	face.scale = Vector3(1.0, 1.0, 0.8)
	r.jaw_close = 0.09
	r.jaw = r._pivot(face, Vector3(0, -1.08, 0.1), "cene")
	r.jaw.rotation.y = PI
	r.mouth = r._pivot(face, Vector3(0, -0.8, -3.6), "agiz")
	r.head.scale = Vector3.ONE * 1.25
	r._collider(r.head, Vector3(0, 0.2, -0.8), Vector3(4.3, 3.6, 5.4))   # baş 1.25 ölçekli: kutu boyu ölçeği almaz
	var LG := {}
	for sx: float in [-1.0, 1.0]:
		var S := Vector3(3.6 * sx, 8.5, -2.6)
		var E := Vector3(7.7 * sx, 7.5, -1.9)
		var W := Vector3(7.4 * sx, 1.1, -3.9)
		var sh := r._pivot(r.chest, S - CH, "kalca")
		var el := r._pivot(sh, E - S, "diz")
		var hd := r._pivot(el, W - E, "el")   # el kemiği (dirseğe bağlı, kendi animasyonu yok)
		r.legs.append({"hip": sh, "kn": el, "side": sx, "front": true})
		var H := Vector3(2.0 * sx, 5.6, 5.8)
		var K := Vector3(4.1 * sx, 3.7, 3.7)
		var HK := Vector3(3.7 * sx, 2.3, 6.9)
		var A := Vector3(3.7 * sx, 0.95, 5.5)
		var hi_ := r._pivot(r.hips, H - HP, "kalca")
		var kn := r._pivot(hi_, K - H, "diz")
		var hk := r._pivot(kn, HK - K, "topuk")
		var ft := r._pivot(hk, A - HK, "ayak")
		r.legs.append({"hip": hi_, "kn": kn, "side": sx, "front": false})
		LG[sx] = {"S": S, "E": E, "W": W, "sh": sh, "el": el, "hd": hd, "H": H, "K": K, "HK": HK, "A": A, "hi": hi_, "kn": kn, "hk": hk, "ft": ft}
	# kuyruklar: eski _tails ile aynı pivotlar ve ayarlar (randf sırası dahil)
	var nseg := 12
	var tbase := r._pivot(r.hips, Vector3(0, 5.9, 7.6) - HP, "kuyruk_koku")
	r.tail_curl = 0.0
	var TL := []
	for ti in 9:
		var yaw := lerpf(-78.0, 78.0, ti / 8.0)
		var pitch := -52.0 + absf(ti - 4.0) * 9.0 + 8.0 * (ti % 2)
		var length := 25.0 - absf(ti - 4.0) * 0.5 - 1.6 * (ti % 2)
		var seg_len := length / nseg
		var troot := r._pivot(tbase, Vector3((ti - 4.0) * 0.26, 0, 0), "tail")
		troot.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
		var segs := []
		var parent: Node3D = troot
		for i in nseg:
			var piv := r._pivot(parent, Vector3(0, 0, seg_len) if i > 0 else Vector3.ZERO, "s%d" % i)
			segs.append(piv)
			parent = piv
		r.tails.append(segs)
		r.tail_cfg.append({"yaw": deg_to_rad(yaw), "pitch": deg_to_rad(pitch), "amp": 0.12, "phase": randf() * TAU, "style": "fur", "root": troot, "s_amp": 0.42, "s_yaw": (ti - 4.0) * 0.04})
		TL.append([troot, segs, length, seg_len])
	# mühür noktaları yeni gövdenin yüzeyinde (eski yerler kalın gövdede derinin içinde kalıyordu)
	r._weak(r.head, Vector3(0, 1.75, -0.3))
	r._weak(r.chest, Vector3(0, 3.4, 0.6))
	r._weak(r.hips, Vector3(0, 2.45, 1.4))
	# kol ve uyluk çarpışması: iri uzuvlar içinden geçilmesin (kutu uzuvla döner)
	for sx: float in [-1.0, 1.0]:
		var g: Dictionary = LG[sx]
		for cd in [[g["sh"], g["S"], g["E"], 2.4], [g["el"], g["E"], g["W"], 1.7], [g["hi"], g["H"], g["K"], 2.6]]:
			var dv: Vector3 = (cd[2] as Vector3) - (cd[1] as Vector3)
			r._collider(cd[0], dv * 0.5, Vector3(float(cd[3]), dv.length() + 0.6, float(cd[3])))
			var mk: Node3D = r.colliders[r.colliders.size() - 1]
			mk.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))   # kutu uzvun yönünde (yatay üst kol üstünde durulur)
	# ---------------- iskelet + köprü (omurga ve boyun: iki pivot arası harman kemik)
	var be = BE.new()
	be.rig(r, root, [["omurga1", r.hips, r.chest, 0.33, Vector3(0, 6.1, 2.9)], ["omurga2", r.hips, r.chest, 0.67, Vector3(0, 6.8, 0.8)],
		["boyun", r.chest, r.head, 0.5, Vector3(0, 6.6, -5.3)]])
	be.shade = func(c: Color, n: Vector3) -> Color: return c.lerp(Color(c.r * 0.74, c.g * 0.57, c.b * 0.6), smoothstep(0.25, 0.8, -n.y) * 0.8)
	_torso(be, r, LG)
	for sx: float in [-1.0, 1.0]:
		_arm(be, r, LG[sx], sx)
		_leg(be, r, LG[sx], sx)
	_head(be, r, face)
	for e in TL:
		_tail(be, e[0], e[1], e[2], e[3])
	be.finish(BeastKurama.mat())


# ------------------------------------------------------------------ gövde + boyun: sağrıdan kafatasının içine tek tüp
static func _torso(be, r: BeastRig, LG: Dictionary) -> void:
	var tp := [Vector3(0, 5.25, 8.6), Vector3(0, 5.4, 8.1), Vector3(0, 5.7, 7.1), Vector3(0, 5.9, 5.6), Vector3(0, 6.05, 4.0), Vector3(0, 6.3, 2.5), Vector3(0, 6.9, 1.0),
		Vector3(0, 7.7, -0.4), Vector3(0, 8.35, -2.0), Vector3(0, 7.95, -3.6), Vector3(0, 6.85, -4.9), Vector3(0, 6.05, -6.0), Vector3(0, 5.65, -6.8)]
	var tr := [Vector2(0.35, 0.35), Vector2(1.2, 1.25), Vector2(1.7, 1.65), Vector2(1.75, 1.7), Vector2(1.15, 1.25), Vector2(1.05, 1.3), Vector2(1.9, 1.75),
		Vector2(2.9, 2.2), Vector2(3.4, 2.35), Vector2(2.95, 2.15), Vector2(1.6, 1.45), Vector2(1.15, 1.1), Vector2(1.0, 0.95)]
	var tz := func(z: float) -> float: return clampf((8.6 - z) / 15.7, 0.0, 1.0)
	var anch := [[7.6, r.hips], [5.2, r.hips], [2.9, "omurga1"], [0.8, "omurga2"], [-1.4, r.chest], [-4.0, r.chest], [-5.3, "boyun"], [-6.4, r.head]]
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var l: Array = BE.chain(p.z, anch)
		for sx: float in [-1.0, 1.0]:   # omuz ve kalça kökünde gövde derisi uzvu biraz izler: eklemde yarık açılmaz
			var g: Dictionary = LG[sx]
			var w := 0.5 * (1.0 - smoothstep(1.0, 3.0, p.distance_to(g["S"])))
			var w2 := 0.4 * (1.0 - smoothstep(1.2, 3.0, p.distance_to(g["H"])))
			for e in l:
				e[1] = float(e[1]) * (1.0 - w - w2)
			if w > 0.0:
				l.append([g["sh"], w])
			if w2 > 0.0:
				l.append([g["hi"], w2])
		return l
	var t_sc: float = tz.call(-2.5)
	var t_bl: float = tz.call(2.2)
	var bump := func(t: float, a: float) -> float:
		var aw := wrapf(a, -PI, PI)
		var scap := 0.075 * _g(t - t_sc, 0.07) * _g(absf(aw) - 0.6, 0.25)      # kürek kemiği kabarıklığı
		var groove := -0.03 * _g(aw, 0.14) * smoothstep(0.15, 0.4, t) * (1.0 - smoothstep(0.6, 0.75, t))   # omurga oluğu
		var belly := -0.09 * _g(t - t_bl, 0.12) * _g(absf(aw) - PI, 0.7)      # içe çekik bel / karın
		var chestk := 0.05 * _g(t - tz.call(-3.4), 0.08) * _g(absf(aw) - 2.4, 0.45)   # göğüs kası
		return scap + groove + belly + chestk
	var info: Dictionary = be.tube(tp, tr, func(_t, _a, _p): return C, sk, 70, 32, Vector3.UP, false, true, bump)
	# kürek kemiği / göğüs kas çizgileri
	for sx: float in [-1.0, 1.0]:
		be.band(info, [Vector2(tz.call(-1.2), 0.42 * sx), Vector2(tz.call(-2.2), 0.72 * sx), Vector2(tz.call(-3.0), 0.55 * sx)],
			func(u): return 0.05 * sin(clampf(u, 0.05, 0.95) * PI) + 0.012, LINE, sk, 0.025)
		be.band(info, [Vector2(tz.call(-2.6), (PI - 0.35) * sx), Vector2(tz.call(-3.4), (PI - 0.8) * sx), Vector2(tz.call(-4.1), (PI - 1.15) * sx)],
			func(u): return 0.045 * sin(clampf(u, 0.05, 0.95) * PI) + 0.01, LINE, sk, 0.025)
	# kürk: omuz kütlesinde geriye sivri tutamlar, ense, göğüs yelesi, sağrı
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var z := lerpf(-2.8, -1.6, i / 1.0)
			var a := sx * (1.05 + 0.18 * (i % 2))
			var s: Array = BE.at(info, tz.call(z), a)
			_tuft_on(be, s, Vector3(0.25 * sx, 0.3, 1.0), 1.5 - 0.12 * i, 0.55, sk)
	for i in 3:
		var s: Array = BE.at(info, tz.call(-4.3 + (i % 2) * 0.35), PI + (i - 1) * 0.4)
		_tuft_on(be, s, Vector3((i - 1) * 0.3, -1.0, -0.35), 1.35 - absf(i - 1) * 0.15, 0.55, sk)
	for sx: float in [-1.0, 1.0]:
		var s: Array = BE.at(info, tz.call(7.5), sx * 1.6)
		_tuft_on(be, s, Vector3(0.3 * sx, -0.2, 1.0), 1.2, 0.5, sk)


## Yüzey örneğine oturan tutam (ağırlığı yüzeyinki)
static func _tuft_on(be, s: Array, dir: Vector3, ln: float, w: float, skf: Callable, xf := Transform3D.IDENTITY, t := 0.0) -> void:
	var p: Vector3 = s[0]
	var sw: Array = skf.call(t, 0.0, p)
	be.tuft(p, s[1], dir + (s[1] as Vector3) * 0.35, ln, w, C, sw, xf, 0.62, 0.16)


# ------------------------------------------------------------------ ön kol: omuz kütlesi -> pazı -> dirsek -> ön kol -> bilek -> avuç, tek tüp
static func _arm(be, r: BeastRig, g: Dictionary, sx: float) -> void:
	var S: Vector3 = g["S"]
	var E: Vector3 = g["E"]
	var W: Vector3 = g["W"]
	var pts := [S + Vector3(-1.2 * sx, 0.3, 0.15), S + Vector3(0.15 * sx, 0.35, 0.1), S.lerp(E, 0.5) + Vector3(0.3 * sx, 0.05, -0.1), E, E.lerp(W, 0.33) + Vector3(0.15 * sx, 0, 0.15),
		E.lerp(W, 0.78), W, W + Vector3(0, -0.46, -0.65), W + Vector3(0, -0.6, -1.6)]
	var rad := [Vector2(1.25, 1.3), Vector2(1.45, 1.4), Vector2(0.95, 1.0), Vector2(0.72, 0.76), Vector2(0.88, 0.92), Vector2(0.68, 0.7), Vector2(0.55, 0.52), Vector2(1.35, 0.46), Vector2(1.2, 0.38)]
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
	var bump := func(t: float, a: float) -> float:   # pazı önde, ön kol kası dışta
		var f := 0.07 * _g(t - lerpf(t1, tE, 0.45), 0.08) * maxf(0.0, cos(a - PI * 0.5 * sx - 0.6 * sx))
		return f + 0.05 * _g(t - lerpf(tE, tW, 0.3), 0.07) * maxf(0.0, sin(a) * sx)
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, _p): return C, sk, 64, 26, Vector3.UP, false, true, bump)
	# pazı çizgisi
	var aout := BE.a_dir(info, lerpf(t1, tE, 0.5), Vector3(sx, 0.2, -0.6))
	be.band(info, [Vector2(lerpf(t1, tE, 0.25), aout), Vector2(lerpf(t1, tE, 0.55), aout - 0.25 * sx), Vector2(lerpf(t1, tE, 0.85), aout - 0.1 * sx)],
		func(u): return 0.045 * sin(clampf(u, 0.05, 0.95) * PI) + 0.01, LINE, sk, 0.025)
	# dirsek arkası: geriye-yukarı sivri kürk (anime: dirsekte tırtıklı tutam)
	for k in 3:
		var t := tE - 0.035 + k * 0.045
		var s: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0.35 * sx, 0.1, 1.0)))
		_tuft_on(be, s, Vector3(0.2 * sx, 0.45 - k * 0.15, 1.0), 1.9 - k * 0.35, 0.6, sk, Transform3D.IDENTITY, t)
	# omuz üstü kürk
	for k in 2:
		var t := lerpf(t1, tE, 0.08 + k * 0.2)
		var s: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0.5 * sx, 0.6, 0.6)))
		_tuft_on(be, s, Vector3(0.4 * sx, 0.1, 1.0), 1.3, 0.55, sk, Transform3D.IDENTITY, t)
	# parmaklar: avucun ön kenarından, boğumda kalkık, uçta yere iner; başparmak içte kısa
	var hsk := [[hd, 1.0]]
	for f in 5:
		var fa := lerpf(-1.0, 1.0, f / 4.0)
		var thumb := fa * sx < -0.9
		var s := 0.72 if thumb else (1.0 - absf(fa) * 0.08)
		s *= 1.45
		var b0 := W + Vector3(sin(fa) * 1.05, -0.48, -1.0 - cos(fa) * 0.35 + (0.45 if thumb else 0.0))
		var b1 := b0 + Vector3(sin(fa) * 0.55, 0.32, -0.95 * cos(fa) - 0.15) * s
		var b2 := b1 + Vector3(sin(fa) * 0.45, -0.5, -0.85) * s
		var b3 := b2 + Vector3(sin(fa) * 0.18, -0.36, -0.4) * s
		be.tube([b0, b1, b2, b3], [Vector2(0.3, 0.28) * s, Vector2(0.28, 0.26) * s, Vector2(0.23, 0.21) * s, Vector2(0.17, 0.15) * s],
			func(_t, _a, _p): return C, func(_t, _a, _p): return hsk, 14, 12, Vector3.UP, false, true)
		be.claw(b3 + Vector3(0, 0.02, -0.05), Vector3(sin(fa) * 0.25, -0.38, -1.0), 0.95 * s, 0.15 * s, CLAW, hsk)
	be.tube([W + Vector3(0, -0.72, -0.45), W + Vector3(0, -0.8, -1.1)], [Vector2(0.55, 0.14), Vector2(0.45, 0.12)], func(_t, _a, _p): return C.darkened(0.22), func(_t, _a, _p): return hsk, 6, 10, Vector3.UP, true, true)   # avuç yastığı
	for k in 2:
		var tw := tW - 0.03 - k * 0.04
		var sw2: Array = BE.at(info, tw, BE.a_dir(info, tw, Vector3(0.5 * sx, 0.1, 1.0)))
		_tuft_on(be, sw2, Vector3(0.35 * sx, -0.1, 1.0), 1.1 - k * 0.2, 0.48, sk, Transform3D.IDENTITY, tw)   # bilek kürkü


# ------------------------------------------------------------------ arka bacak: but -> uyluk -> diz -> baldır -> topuk -> ayak, tek tüp
static func _leg(be, r: BeastRig, g: Dictionary, sx: float) -> void:
	var H: Vector3 = g["H"]
	var K: Vector3 = g["K"]
	var HK: Vector3 = g["HK"]
	var A: Vector3 = g["A"]
	var pts := [H + Vector3(-1.0 * sx, 0.75, 0.3), H + Vector3(0.2 * sx, 0.15, 0.35), H.lerp(K, 0.5) + Vector3(0.2 * sx, 0, 0.45), K, K.lerp(HK, 0.42) + Vector3(0, -0.05, 0),
		HK, HK.lerp(A, 0.5), A, A + Vector3(0, -0.42, -0.55), A + Vector3(0, -0.52, -1.25)]
	var rad := [Vector2(1.3, 1.3), Vector2(1.7, 1.8), Vector2(1.2, 1.28), Vector2(0.68, 0.72), Vector2(0.6, 0.64), Vector2(0.4, 0.42), Vector2(0.37, 0.39), Vector2(0.45, 0.42), Vector2(0.78, 0.34), Vector2(0.68, 0.3)]
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
	var bump := func(t: float, a: float) -> float:   # baldır kası arkada
		return 0.08 * _g(t - lerpf(tK, tH, 0.35), 0.06) * maxf(0.0, -cos(a))
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, _p): return C, sk, 70, 26, Vector3.UP, false, true, bump)
	var aout := BE.a_dir(info, lerpf(t1, tK, 0.4), Vector3(sx, 0.1, 0.3))
	be.band(info, [Vector2(lerpf(0.0, t1, 0.8), aout + 0.2 * sx), Vector2(lerpf(t1, tK, 0.4), aout), Vector2(lerpf(t1, tK, 0.8), aout - 0.2 * sx)],
		func(u): return 0.05 * sin(clampf(u, 0.05, 0.95) * PI) + 0.012, LINE, sk, 0.025)
	# but arkası ve topuk: geriye sivri kürk
	for k in 3:
		var t := lerpf(t1 * 0.7, lerpf(t1, tK, 0.6), k / 2.0)
		var s: Array = BE.at(info, t, BE.a_dir(info, t, Vector3(0.3 * sx, -0.2, 1.0)))
		_tuft_on(be, s, Vector3(0.25 * sx, -0.35, 1.0), 1.5 - k * 0.2, 0.55, sk, Transform3D.IDENTITY, t)
	var s2: Array = BE.at(info, tH, BE.a_dir(info, tH, Vector3(0, 0.3, 1.0)))
	_tuft_on(be, s2, Vector3(0.1 * sx, 0.5, 1.0), 1.25, 0.45, sk, Transform3D.IDENTITY, tH)
	var fsk := [[ft, 1.0]]
	for f in 4:
		var fa := lerpf(-0.6, 0.6, f / 3.0)
		var fl := 1.0 - absf(fa) * 0.18   # orta parmaklar uzun
		var b0 := A + Vector3(sin(fa) * 0.66, -0.52, -0.8 - cos(fa) * 0.2)
		var b1 := b0 + Vector3(sin(fa) * 0.32, 0.26, -0.62) * fl
		var b2 := b1 + Vector3(sin(fa) * 0.24, -0.2, -0.55) * fl
		var b3 := b2 + Vector3(sin(fa) * 0.12, -0.34, -0.36) * fl
		be.tube([b0, b1, b2, b3], [Vector2(0.36, 0.33), Vector2(0.34, 0.31), Vector2(0.28, 0.25), Vector2(0.2, 0.17)], func(_t, _a, _p): return C, func(_t, _a, _p): return fsk, 14, 12, Vector3.UP, false, true)
		be.tube([b0 + Vector3(0, -0.22, 0.05), b1.lerp(b2, 0.5) + Vector3(0, -0.24, 0)], [Vector2(0.24, 0.12), Vector2(0.2, 0.1)], func(_t, _a, _p): return C.darkened(0.22), func(_t, _a, _p): return fsk, 6, 8, Vector3.UP, true, true)   # parmak yastığı
		be.claw(b3 + Vector3(0, 0.02, -0.04), Vector3(sin(fa) * 0.2, -0.5, -1.0), 0.95 * fl, 0.18, CLAW, fsk)
	be.tube([A + Vector3(0, -0.62, -0.35), A + Vector3(0, -0.66, -0.75)], [Vector2(0.62, 0.16), Vector2(0.5, 0.14)], func(_t, _a, _p): return C.darkened(0.22), func(_t, _a, _p): return fsk, 6, 10, Vector3.UP, true, true)   # taban yastığı
	be.claw(A + Vector3(-0.55 * sx, -0.15, -0.2), Vector3(-0.5 * sx, -0.6, -0.6), 0.5, 0.12, CLAW, fsk)   # iç tırnak (bilek üstünde)
	var sa: Array = BE.at(info, tA - 0.02, BE.a_dir(info, tA - 0.02, Vector3(0.4 * sx, 0.2, 1.0)))
	_tuft_on(be, sa, Vector3(0.3 * sx, -0.2, 1.0), 0.9, 0.42, sk, Transform3D.IDENTITY, tA - 0.02)


# ------------------------------------------------------------------ baş (yüz pivotunun yerel uzayında kurulur, ileri -Z)
static func _head(be, r: BeastRig, face: Node3D) -> void:
	var F: Transform3D = be.rs(face)
	var fsk := [[face, 1.0]]
	var sk := func(_t, _a, _p): return fsk
	var hp := [Vector3(0, 0.3, 1.45), Vector3(0, 0.45, 1.0), Vector3(0, 0.5, 0.2), Vector3(0, 0.42, -0.6), Vector3(0, 0.25, -1.2), Vector3(0, 0.05, -1.75), Vector3(0, -0.05, -2.4),
		Vector3(0, -0.14, -3.0), Vector3(0, -0.18, -3.42), Vector3(0, -0.2, -3.6)]
	var hr := [Vector2(0.5, 0.45), Vector2(1.08, 0.98), Vector2(1.35, 1.15), Vector2(1.22, 1.06), Vector2(0.88, 0.86), Vector2(0.58, 0.64), Vector2(0.45, 0.52), Vector2(0.36, 0.42), Vector2(0.22, 0.26), Vector2(0.05, 0.05)]
	var tz := func(z: float) -> float: return clampf((1.45 - z) / 5.06, 0.0, 1.0)
	var lipA := func(z: float) -> float: return lerpf(1.15, 0.45, clampf(inverse_lerp(-0.1, -3.35, z), 0.0, 1.0))
	var colf := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := wrapf(a, -PI, PI)
		if p.z < -0.05 and p.z > -3.35 and absf(aw) > PI - float(lipA.call(p.z)) + 0.06:
			return MOUTH   # ağız tavanı (çene açılınca görünür)
		return C
	var bump := func(t: float, a: float) -> float:   # kaş kemeri (öfkeli bakış) + alın ortası çukur
		var aw := wrapf(a, -PI, PI)
		return 0.07 * _g(t - tz.call(-1.0), 0.05) * _g(absf(aw) - 0.62, 0.22) - 0.03 * _g(aw, 0.18) * _g(t - tz.call(-0.6), 0.1)
	var hi: Dictionary = be.tube(hp, hr, colf, sk, 52, 36, Vector3.UP, true, true, bump, F)
	# burun: ucun üstüne oturan yuvarlak siyah burun (keskin kenar)
	be.tube([Vector3(0, -0.08, -3.1), Vector3(0, -0.05, -3.4), Vector3(0, -0.12, -3.68)], [Vector2(0.06, 0.05), Vector2(0.4, 0.3), Vector2(0.05, 0.05)],
		func(_t, _a, _p): return BLK, sk, 12, 18, Vector3.UP, true, true, Callable(), F)
	# alın ortası çizgisi, burun sırtı kırışıkları (hırlama)
	be.band(hi, [Vector2(tz.call(-1.5), 0.0), Vector2(tz.call(-0.95), 0.0), Vector2(tz.call(-0.45), 0.0)], func(u): return 0.03 * sin(clampf(u, 0.05, 0.95) * PI) + 0.008, LINE, sk, 0.022)
	for k in 3:
		var z := -1.72 - k * 0.17
		be.band(hi, [Vector2(tz.call(z + 0.03), -0.6), Vector2(tz.call(z), 0.0), Vector2(tz.call(z + 0.03), 0.6)], func(u): return 0.024 * sin(clampf(u, 0.05, 0.95) * PI) + 0.006, LINE, sk, 0.02)
	for sx: float in [-1.0, 1.0]:
		# siyah bant: burun yanında ince başlar, gözü sarar, kaşın üstünden kulağın dibine çıkar
		be.band(hi, [Vector2(tz.call(-2.15), 0.72 * sx), Vector2(tz.call(-1.65), 0.95 * sx), Vector2(tz.call(-1.15), 1.06 * sx), Vector2(tz.call(-0.75), 0.86 * sx), Vector2(tz.call(-0.45), 0.52 * sx), Vector2(tz.call(-0.3), 0.33 * sx)],
			func(u): return lerpf(0.06, 0.46, smoothstep(0.0, 0.42, u)) * (1.0 - 0.4 * smoothstep(0.7, 1.0, u)), BLK, sk, 0.035)
		# göz: beyaz, küçük kızıl iris + yarık bebek; dış köşe yukarı çekik
		var ed: Array = BE.at(hi, tz.call(-1.15), 0.98 * sx, 0.04)
		var nrm := ((ed[1] as Vector3) * 0.5 + Vector3(0, 0.1, -1.0)).normalized()
		var eb := Basis.looking_at(nrm, Vector3.UP) * Basis(Vector3.BACK, deg_to_rad(30 * sx))
		var er := eb.get_euler() * 180.0 / PI
		var ep: Vector3 = (ed[0] as Vector3) + nrm * 0.03
		BeastModels._anime_eye(r, face, ep, Vector3(0.74, 0.27, 0.1), Color(0.96, 0.94, 0.9), Color(0.96, 0.94, 0.9), BLK, er, "none")
		BeastModels._anime_eye(r, face, ep + nrm * 0.03, Vector3(0.34, 0.26, 0.1), Color(0.78, 0.05, 0.04), Color(0.95, 0.1, 0.06), BLK, er, "slit")
		# üst dudak: kalın koyu çizgi, ağız köşesi yanağa kadar; içinde sıra sivri dişler
		var lp := []
		for i in 7:
			var z := lerpf(-0.05, -3.38, i / 6.0)
			lp.append(Vector2(tz.call(z), PI - sx * float(lipA.call(z))))
		be.band(hi, lp, func(u): return 0.1 * (1.0 - 0.4 * u), LIP, sk, 0.04)
		for i in range(1, 11):
			var z := lerpf(-0.25, -3.2, i / 10.5)
			var canine := i == 8
			var s: Array = BE.at(hi, tz.call(z), PI - sx * (float(lipA.call(z)) - 0.1))
			be.claw((s[0] as Vector3) + Vector3(0, 0.04, 0), Vector3(-0.08 * sx, -1.0, 0.05), 0.45 if canine else 0.24, 0.1 if canine else 0.07, FANG, fsk, F, Vector3(0, 0, 1), 6)
		# kulak: kaştan çıkar, başın ~2.5 katı, yassı yaprak; ön yüzü siyah (turuncu kenar), hafif çukur
		var e0 := Vector3(0.5 * sx, 0.95, -0.25)
		var e1 := Vector3(4.3 * sx, 5.7, 3.1)
		var em := e0.lerp(e1, 0.4) + Vector3(0.3 * sx, 0.25, -0.2)
		var ew := Vector3(sx, -0.75, -0.1).normalized()
		var en := (e1 - e0).normalized().cross(ew).normalized()
		if en.z > 0.0:
			en = -en
		var ep_ := [e0, e0.lerp(em, 0.45), em, em.lerp(e1, 0.55), e1.lerp(em, 0.08), e1]
		be.tube(ep_, [Vector2(0.52, 0.34), Vector2(0.76, 0.27), Vector2(0.68, 0.2), Vector2(0.43, 0.13), Vector2(0.1, 0.05), Vector2(0.02, 0.02)],
			func(_t, _a, _p): return C, sk, 34, 18, en, false, true, Callable(), F)
		# kulak içi: ön yüze gömülü ince siyah yaprak (keskin kenar; köşe rengi bulanık geçiş yapıyordu)
		var ip := []
		for q in [0.12, 0.3, 0.5, 0.7, 0.86, 0.97]:
			var qi := float(q) * 5.0
			var k0 := mini(int(qi), 4)
			var ery: float = [0.34, 0.27, 0.2, 0.13, 0.05, 0.02][k0] * (1.0 - (qi - k0)) + [0.34, 0.27, 0.2, 0.13, 0.05, 0.02][k0 + 1] * (qi - k0)
			ip.append((ep_[k0] as Vector3).lerp(ep_[k0 + 1], qi - k0) + en * ery * 0.78)
		be.tube(ip, [Vector2(0.3, 0.08), Vector2(0.55, 0.09), Vector2(0.5, 0.08), Vector2(0.32, 0.06), Vector2(0.12, 0.03), Vector2(0.02, 0.02)],
			func(_t, _a, _p): return BLK, sk, 30, 14, en, true, true, Callable(), F)
		# yanak kürkü: çene köşesinde geriye-dışa sivri tırtıklı tutamlar (önden uçurtma silueti)
		for k in 5:
			var z := 0.55 - k * 0.22
			var s: Array = BE.at(hi, tz.call(z), sx * (PI * 0.5 + 0.15 + k * 0.17))
			_tuft_on(be, s, Vector3(1.0 * sx, -0.18 - k * 0.12, 0.5), (2.5 - k * 0.2) * (1.0 if k % 2 == 0 else 0.8), 0.5, sk, F)
		# kafa arkası (ense) tutamı
		var sb: Array = BE.at(hi, tz.call(1.05), sx * 0.7)
		_tuft_on(be, sb, Vector3(0.3 * sx, 0.3, 1.0), 1.2, 0.45, sk, F)
	# alt çene: kalın, öne incelen; üstü ağız içi (dil), kenarında alt dudak ve zikzak dişler
	var jsk := [[r.jaw, 1.0]]
	var jk := func(_t, _a, _p): return jsk
	var jp := [Vector3(0, -1.17, 0.2), Vector3(0, -1.32, -0.9), Vector3(0, -1.32, -2.0), Vector3(0, -1.24, -2.85), Vector3(0, -1.16, -3.3), Vector3(0, -1.12, -3.45)]
	var jr := [Vector2(1.05, 0.34), Vector2(0.78, 0.34), Vector2(0.5, 0.28), Vector2(0.33, 0.21), Vector2(0.18, 0.13), Vector2(0.04, 0.04)]
	var jcol := func(_t: float, a: float, p: Vector3) -> Color:
		var aw := wrapf(a, -PI, PI)
		if absf(aw) < 0.85 and p.z < 0.05:
			return TONGUE if absf(aw) < 0.45 and p.z < -0.5 and p.z > -2.6 else MOUTH
		return C
	var ji: Dictionary = be.tube(jp, jr, jcol, jk, 30, 26, Vector3.UP, true, true, Callable(), F)
	var jtz := func(z: float) -> float: return clampf((0.2 - z) / 3.68, 0.0, 1.0)
	for sx: float in [-1.0, 1.0]:
		var lp2 := []
		for i in 7:
			lp2.append(Vector2(jtz.call(lerpf(0.05, -3.3, i / 6.0)), 0.95 * sx))
		be.band(ji, lp2, func(u): return 0.09 * (1.0 - 0.4 * u), LIP, jk, 0.035)
		for i in range(1, 11):
			var z := lerpf(-0.25, -3.2, (i + 0.5) / 10.5)
			var canine := i == 8
			var s: Array = BE.at(ji, jtz.call(z), 0.82 * sx)
			be.claw((s[0] as Vector3) - Vector3(0, 0.03, 0), Vector3(-0.08 * sx, 1.0, 0.0), 0.36 if canine else 0.22, 0.09 if canine else 0.065, FANG, jsk, F, Vector3(0, 0, 1), 6)
		var sc: Array = BE.at(ji, jtz.call(-0.5), sx * 2.2)
		_tuft_on(be, sc, Vector3(0.35 * sx, -0.45, 1.0), 1.4, 0.45, jk, F)


# ------------------------------------------------------------------ kuyruk: kökten uca tek tüp, 12 boğum kemiğine yumuşak geçişli
static func _tail(be, troot: Node3D, segs: Array, length: float, seg_len: float) -> void:
	var X: Transform3D = be.rs(troot)
	var rf := func(k: float) -> float:
		return lerpf(1.0, 1.6, sin(minf(1.0, k * 3.0) * PI * 0.5)) * (1.0 - pow(maxf(0.0, (k - 0.55) / 0.45), 1.6) * 0.97)
	var pts := []
	var rad := []
	for i in 16:
		var k := float(i) / 15.0
		pts.append(Vector3(0, 0, lerpf(-0.8, length, k)))
		var rr: float = rf.call(clampf(lerpf(-0.8, length, k) / length, 0.0, 1.0))
		rad.append(Vector2(rr, rr * 0.86))
	var n := segs.size()
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var f := clampf(p.z / seg_len - 0.5, 0.0, n - 1.0)
		var i0 := mini(int(f), n - 1)
		var i1 := mini(i0 + 1, n - 1)
		var w := f - i0
		return [[segs[i0], 1.0 - w], [segs[i1], w]]
	var col := func(_t: float, _a: float, p: Vector3) -> Color: return C.lerp(CL, clampf(p.z / length, 0.0, 1.0) * 0.35)
	var bump := func(t: float, a: float) -> float:   # hafif kürk dalgası (düz boru gibi durmasın)
		return 0.035 * sin(a * 5.0 + t * 23.0) * smoothstep(0.05, 0.2, t) * (1.0 - smoothstep(0.8, 0.95, t))
	be.tube(pts, rad, col, sk, 66, 18, Vector3.UP, false, true, bump, X)
