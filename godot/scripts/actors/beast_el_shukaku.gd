extends RefCounted
## Shukaku — Bir Kuyruk, ELLE MODELLENMİŞ, EN BAŞTAN (iskelet noktaları + oranlar anime karelerinden yeniden ölçüldü).
## Kaynaklar _tmp/ref/shukaku (Shukaku.png ay önünde dik, Shukaku_Vs_Urashiki kambur dik, Shukaku_defending_Gaara çömelik,
## Shukaku_Struggling zincirli, Tailed_Beast_Ball ve Wind_Release yüz yakın). Ortak tasarım:
##  - kambur dik dev tanuki: alt gövde armut gibi geniş, göbek yere yakın; omuz kütlesi iri ve öne kambur; boyun yok
##  - baş gövdenin üst önünde BELİRGİN (gövde genişliğinin ~yarısı): yuvarlak tanuki başı, köşelerde iri sivri kulak (içi lacivert)
##  - yüz: sarı göz + dört köşeli yıldız bebek, çevresinde sivri uçlu siyah maske; kısa küt burun + küçük siyah burun ucu;
##    yüz genişliğinde ağız, kum renginde ZİKZAK dişler (beyaz değil), ayrı alt çene
##  - ön kol üst koldan kalın, dört kalın parmak, sivri uçlar kum renginde; bacaklar kısa tıknaz, üç parmaklı geniş ayak
##  - kuyruk: kökü gövdenin yarısı kalınlığında, gövde boyundan uzun, S biçiminde başın üstüne kalkar; üst üste binen sivri pullar
##  - desen: bütün gövdede lacivert, iki ucu sivri, alev gibi kıvrık fırça izleri
const BE = preload("res://scripts/actors/beast_el.gd")

const C := Color(0.8, 0.72, 0.58)
const CL := Color(0.86, 0.79, 0.66)
const MK := Color(0.12, 0.15, 0.42)
const DARK := Color(0.03, 0.03, 0.05)
const TOOTH := Color(0.95, 0.9, 0.78)   # kum rengi ama tenden açık: koyu ağız aralığında seçilir


static func _g(x: float, s: float) -> float:
	return exp(-x * x / (s * s))


static func build(r: BeastRig, root: Node3D) -> void:
	r.quadruped = false
	r.upright = true
	var HP := Vector3(0, 3.0, 1.0)
	r.hips = r._pivot(root, HP, "kalca_kok")
	r._collider(r.hips, Vector3(0, 0.6, -0.4), Vector3(9.0, 6.2, 8.0))
	var CH := Vector3(0, 6.6, -0.3)
	r.chest = r._pivot(r.hips, CH - HP, "gogus")
	r._collider(r.chest, Vector3(0, 0.6, -0.2), Vector3(9.2, 5.4, 7.0))
	var HD := Vector3(0, 8.7, -2.9)
	r.head = r._pivot(r.chest, HD - CH, "bas")
	r.head.scale = Vector3.ONE * 1.4   # iri baş (gövde genişliğinin ~yarısı)
	r._collider(r.head, Vector3(0, 0.2, -0.8), Vector3(7.0, 6.2, 6.4))   # kutu boyu pivot ölçeğini almaz
	r.jaw = r._pivot(r.head, Vector3(0, -1.35, 0.9), "cene")
	r.mouth = r._pivot(r.head, Vector3(0, -1.0, -1.8), "agiz")
	var LG := {}
	for sx: float in [-1.0, 1.0]:
		var S := Vector3(4.2 * sx, 7.4, -0.5)
		var E := Vector3(6.9 * sx, 4.8, -1.3)
		var W := Vector3(7.5 * sx, 1.9, -3.1)
		var sh := r._pivot(r.chest, S - CH, "omuz")
		var el := r._pivot(sh, E - S, "dirsek")
		r.arms.append({"sh": sh, "el": el, "side": sx})
		var H := Vector3(2.9 * sx, 2.2, 1.4)
		var K := Vector3(3.5 * sx, 1.3, -0.5)
		var A := Vector3(3.5 * sx, 0.55, -0.8)
		var hi := r._pivot(r.hips, H - HP, "kalca")
		var kn := r._pivot(hi, K - H, "diz")
		r.legs.append({"hip": hi, "kn": kn, "side": sx, "front": false, "slide": 1.0})
		LG[sx] = {"S": S, "E": E, "W": W, "sh": sh, "el": el, "H": H, "K": K, "A": A, "hi": hi, "kn": kn}
		for cd in [[sh, S, E, 3.6], [el, E, W, 3.6]]:   # uzuv yönünde dönük çarpışma kutusu
			var dv: Vector3 = (cd[2] as Vector3) - (cd[1] as Vector3)
			r._collider(cd[0], dv * 0.5, Vector3(float(cd[3]), dv.length() + 0.8, float(cd[3])))
			var mk: Node3D = r.colliders[r.colliders.size() - 1]
			mk.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))
	# kuyruk: kalın, sırttan arkaya-yukarı, S kavisle başın üstüne kalkar
	var n := 12
	var length := 22.0
	var seg_len := length / n
	var tbase := r._pivot(r.hips, Vector3(0, 2.6, 4.2) - HP, "kuyruk_koku")
	var troot := r._pivot(tbase, Vector3.ZERO, "tail")
	var pitch := -24.0
	troot.rotation = Vector3(deg_to_rad(pitch), 0, 0)
	r.tail_curl = -0.075   # uç başın arkasında kalır (kükrerken yüzü kapatıyordu)
	var segs := []
	var parent: Node3D = troot
	for i in n:
		var piv := r._pivot(parent, Vector3(0, 0, seg_len) if i > 0 else Vector3.ZERO, "s%d" % i)
		segs.append(piv)
		parent = piv
	r.tails.append(segs)
	r.tail_cfg.append({"yaw": 0.0, "pitch": deg_to_rad(pitch), "amp": 0.1, "phase": randf() * TAU, "style": "sand", "root": troot, "s_amp": 0.42, "s_yaw": 0.0})
	r._weak(r.head, Vector3(0, 2.6, 0.2))
	r._weak(r.chest, Vector3(0, 3.0, 1.2))
	r._weak(r.hips, Vector3(0, -0.8, -4.6))
	# ---------------- iskelet + köprü
	var be = BE.new()
	be.rig(r, root, [["bel", r.hips, r.chest, 0.5, Vector3(0, 4.8, 0.4)]])
	be.shade = func(c: Color, nrm: Vector3) -> Color: return c.lerp(Color(c.r * 0.76, c.g * 0.7, c.b * 0.68), smoothstep(0.2, 0.85, -nrm.y) * 0.7)
	_body(be, r, LG)
	for sx: float in [-1.0, 1.0]:
		_arm(be, r, LG[sx], sx)
		_leg(be, r, LG[sx], sx)
	_head(be, r, HD)
	_tail(be, troot, segs, length, seg_len)
	be.finish(BeastKurama.mat())
	BeastModels._particles(r.hips, Vector3(4.5, 4.0, 4.0), [Color(0.78, 0.7, 0.56, 0.8), Color(0.78, 0.7, 0.56, 0.0)], 60, 1.2, Vector3(0, -3, 0), 2.0)


## Lacivert alev fırça izi: yüzeyde iki ucu sivri, kıvrık şerit
static func _stroke(be, info: Dictionary, t0: float, a0: float, dt: float, da: float, w: float, skf: Callable, hook := 0.0) -> void:
	var path := []
	for k in 7:
		var u := k / 6.0
		path.append(Vector2(t0 + dt * u, a0 + da * u + hook * sin(u * PI) * 0.6 + 0.05 * sin(u * 9.0 + a0 * 3.0)))
	be.band(info, path, func(u): return w * pow(sin(clampf(u, 0.02, 0.98) * PI), 0.8) + 0.004, MK, skf, 0.028)


# ------------------------------------------------------------------ gövde: armut alt gövde -> göbek -> kambur omuz kütlesi -> sırt tepesi, tek dik tüp
static func _body(be, r: BeastRig, LG: Dictionary) -> void:
	var tp := [Vector3(0, 0.6, 1.4), Vector3(0, 1.4, 1.2), Vector3(0, 3.0, 0.8), Vector3(0, 4.8, 0.4), Vector3(0, 6.4, -0.1), Vector3(0, 7.8, -0.5),
		Vector3(0, 8.9, -0.6), Vector3(0, 9.6, -0.4)]
	var tr := [Vector2(1.8, 1.6), Vector2(3.6, 3.0), Vector2(4.6, 4.1), Vector2(4.3, 3.9), Vector2(4.6, 3.7), Vector2(4.2, 3.4), Vector2(3.0, 2.6), Vector2(0.8, 0.8)]
	var ty := func(y: float) -> float: return clampf((y - 0.6) / 9.0, 0.0, 1.0)
	var anch := [[1.4, r.hips], [3.4, r.hips], [4.8, "bel"], [6.2, r.chest], [9.6, r.chest]]
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var l: Array = BE.chain(p.y, anch)
		for sx: float in [-1.0, 1.0]:
			var g: Dictionary = LG[sx]
			var w := 0.45 * (1.0 - smoothstep(1.5, 3.6, p.distance_to(g["S"])))
			var w2 := 0.35 * (1.0 - smoothstep(1.2, 3.0, p.distance_to(g["H"])))
			for e in l:
				e[1] = float(e[1]) * (1.0 - w - w2)
			if w > 0.0:
				l.append([g["sh"], w])
			if w2 > 0.0:
				l.append([g["hi"], w2])
		return l
	var bump := func(t: float, a: float) -> float:   # a=0 ön (-z), PI arka
		var aw := wrapf(a, -PI, PI)
		var belly := 0.05 * _g(t - ty.call(2.8), 0.12) * _g(aw, 0.9)                        # göbek öne şişkin
		var hump := 0.07 * _g(t - ty.call(7.6), 0.1) * _g(absf(aw) - PI, 0.9)              # sırt kamburu
		var pec := 0.05 * _g(t - ty.call(6.2), 0.07) * _g(absf(aw) - 0.6, 0.35)            # göğüs
		return belly + hump + pec
	var info: Dictionary = be.tube(tp, tr, func(_t, _a, _p): return C, sk, 70, 44, Vector3.FORWARD, true, true, bump)
	var lsk := func(_t, _a, p): return sk.call(0.0, 0.0, p)
	seed(7)
	for i in 78:   # alev fırça izleri (referansta bütün gövdede sık): gövdenin her yanında, kıvrık, bazısı kancalı
		var t0 := randf_range(0.12, 0.82)
		var a0 := randf_range(-PI, PI)
		_stroke(be, info, t0, a0, randf_range(0.08, 0.16) * (1.0 if randf() < 0.5 else -1.0), randf_range(-0.4, 0.4), randf_range(0.11, 0.2), lsk, randf_range(-0.45, 0.45))


# ------------------------------------------------------------------ kol: omuz kütlesi -> üst kol -> dirsek -> KALIN ön kol -> el, tek tüp + 4 kalın parmak
static func _arm(be, r: BeastRig, g: Dictionary, sx: float) -> void:
	var S: Vector3 = g["S"]
	var E: Vector3 = g["E"]
	var W: Vector3 = g["W"]
	var pts := [S + Vector3(-1.6 * sx, 0.3, 0.2), S + Vector3(0.2 * sx, 0.4, 0.0), S.lerp(E, 0.5) + Vector3(0.3 * sx, 0.2, 0), E, E.lerp(W, 0.45) + Vector3(0.25 * sx, 0, 0),
		W, W + Vector3(0.2 * sx, -0.6, -0.7)]
	var rad := [Vector2(2.3, 2.3), Vector2(2.4, 2.3), Vector2(1.9, 1.9), Vector2(1.75, 1.8), Vector2(2.2, 2.2), Vector2(1.7, 1.6), Vector2(1.9, 1.1)]
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
	var info: Dictionary = be.tube(pts, rad, func(_t, _a, _p): return C, sk, 50, 30, Vector3.UP, false, true)
	seed(11 + int(sx))
	for i in 16:
		_stroke(be, info, randf_range(0.1, 0.85), randf_range(-PI, PI), randf_range(0.09, 0.15), randf_range(-0.35, 0.35), randf_range(0.11, 0.17), sk, randf_range(-0.4, 0.4))
	# el: 4 kalın parmak, uçları kum renginde sivri (ayrı beyaz pençe yok)
	var hsk := [[el, 1.0]]
	var hand: Vector3 = W + Vector3(0.2 * sx, -0.9, -1.0)
	for f in 4:
		var fa := lerpf(-0.75, 0.75, f / 3.0) + 0.2 * sx
		var b0 := hand + Vector3(sin(fa) * 0.9, 0.1, -cos(fa) * 0.7)
		var b1 := hand + Vector3(sin(fa) * 1.6, 0.25, -cos(fa) * 1.5)
		var b2 := hand + Vector3(sin(fa) * 2.1, -0.35, -cos(fa) * 2.1)
		var b3 := hand + Vector3(sin(fa) * 2.35, -0.85, -cos(fa) * 2.4)
		be.tube([b0, b1, b2, b3], [Vector2(0.62, 0.55), Vector2(0.58, 0.52), Vector2(0.42, 0.38), Vector2(0.05, 0.05)], func(_t, _a, _p): return C, func(_t, _a, _p): return hsk, 14, 12, Vector3.UP, false, true)


# ------------------------------------------------------------------ bacak: kısa tıknaz uyluk -> diz -> bilek -> 3 parmaklı geniş ayak
static func _leg(be, r: BeastRig, g: Dictionary, sx: float) -> void:
	var H: Vector3 = g["H"]
	var K: Vector3 = g["K"]
	var A: Vector3 = g["A"]
	var pts := [H + Vector3(-0.6 * sx, 0.6, 0.4), H, K, A, A + Vector3(0, -0.2, -0.9)]
	var rad := [Vector2(2.0, 2.0), Vector2(2.2, 2.1), Vector2(1.6, 1.6), Vector2(1.3, 1.2), Vector2(1.6, 0.6)]
	var hi: Node3D = g["hi"]
	var kn: Node3D = g["kn"]
	var sk := func(t: float, _a: float, _p: Vector3) -> Array:
		if t < 0.25:
			var u := smoothstep(0.0, 0.25, t)
			return [[r.hips, 0.5 * (1.0 - u)], [hi, 1.0 - 0.5 * (1.0 - u)]]
		return BE.chain(t, [[0.4, hi], [0.6, kn]])
	be.tube(pts, rad, func(_t, _a, _p): return C, sk, 30, 24, Vector3.UP, false, true)
	var fsk := [[kn, 1.0]]
	var foot: Vector3 = A + Vector3(0, -0.25, -0.9)
	for f in 3:
		var fa := lerpf(-0.55, 0.55, f / 2.0) + 0.12 * sx
		var b0 := foot + Vector3(sin(fa) * 0.6, 0.05, -cos(fa) * 0.4)
		var b1 := foot + Vector3(sin(fa) * 1.1, 0.1, -cos(fa) * 1.1)
		var b2 := foot + Vector3(sin(fa) * 1.35, -0.25, -cos(fa) * 1.6)
		be.tube([b0, b1, b2], [Vector2(0.5, 0.42), Vector2(0.44, 0.38), Vector2(0.04, 0.04)], func(_t, _a, _p): return C, func(_t, _a, _p): return fsk, 10, 10, Vector3.UP, false, true)


# ------------------------------------------------------------------ baş: yuvarlak tanuki başı, kulaklar, maske, gözler, burun, zikzak dişli ağız + ayrı çene
## Baş pivotunun YEREL uzayında kurulur (pivot 1.4 ölçekli: göz, kulak, diş, çene birlikte büyür)
static func _head(be, r: BeastRig, HD: Vector3) -> void:
	var F: Transform3D = be.rs(r.head)
	var hsk := [[r.head, 1.0]]
	var sk := func(_t, _a, _p): return hsk
	var hp := [Vector3(0, 0.2, 2.1), Vector3(0, 0.4, 1.3), Vector3(0, 0.3, 0.1), Vector3(0, -0.1, -1.0), Vector3(0, -0.6, -1.7), Vector3(0, -0.8, -2.1)]
	var hr := [Vector2(1.6, 1.6), Vector2(2.6, 2.2), Vector2(2.8, 2.2), Vector2(2.4, 1.9), Vector2(1.3, 1.1), Vector2(0.3, 0.3)]
	var tz := func(z: float) -> float: return clampf((2.1 - z) / 4.2, 0.0, 1.0)
	var colf := func(_t: float, a: float, p: Vector3) -> Color:   # ağız tavanı (alt yüz)
		var aw := wrapf(a, -PI, PI)
		return DARK if absf(aw) > 2.3 and p.z < 0.3 and p.z > -1.8 else C
	var hi: Dictionary = be.tube(hp, hr, colf, sk, 40, 34, Vector3.UP, true, true, Callable(), F)
	be.tube([Vector3(0, -0.5, -1.8), Vector3(0, -0.45, -2.1), Vector3(0, -0.55, -2.3)], [Vector2(0.05, 0.05), Vector2(0.45, 0.32), Vector2(0.05, 0.05)], func(_t, _a, _p): return DARK, sk, 10, 14, Vector3.UP, true, true, Callable(), F)   # burun
	for sx: float in [-1.0, 1.0]:
		# siyah göz maskesi: gözü sarar, dış köşede sivri uç yanağa iner
		be.band(hi, [Vector2(tz.call(-1.45), 0.3 * sx), Vector2(tz.call(-1.25), 0.55 * sx), Vector2(tz.call(-1.0), 0.85 * sx), Vector2(tz.call(-0.6), 1.15 * sx), Vector2(tz.call(-0.2), 1.45 * sx)],
			func(u): return lerpf(0.06, 0.5, smoothstep(0.0, 0.45, u)) * (1.0 - 0.85 * smoothstep(0.65, 1.0, u)), DARK, sk, 0.035)
		var ed: Array = BE.at(hi, tz.call(-1.05), 0.8 * sx, 0.05)   # başın burna daraldığı, yüzeyin öne döndüğü yer
		var nrm := ((ed[1] as Vector3) * 0.6 + Vector3(0, 0.05, -1.0)).normalized()
		var eb := Basis.looking_at(nrm, Vector3.UP) * Basis(Vector3.BACK, deg_to_rad(-24 * sx))
		BeastModels._anime_eye(r, r.head, (ed[0] as Vector3) + nrm * 0.03, Vector3(0.6, 0.48, 0.1), Color(0.95, 0.78, 0.12), Color(1.0, 0.86, 0.18), Color(0.02, 0.02, 0.02), eb.get_euler() * 180.0 / PI, "star")
		# kulak: üst köşede dışa-yukarı sivri üçgen, yassı; ön yüzü lacivert
		var e0 := Vector3(1.6 * sx, 1.7, 1.3)
		var e1 := Vector3(2.9 * sx, 3.3, 1.5)
		var en := Vector3(0, 0.15, -1.0).normalized()
		var ecol := func(t: float, a: float, _p: Vector3) -> Color: return MK if cos(a) > 0.35 and t > 0.12 and t < 0.9 else C
		be.tube([e0 + Vector3(-0.3 * sx, -0.5, 0), e0, e0.lerp(e1, 0.55) + Vector3(0.1 * sx, 0, 0), e1], [Vector2(1.0, 0.4), Vector2(1.05, 0.35), Vector2(0.6, 0.22), Vector2(0.03, 0.03)], ecol, sk, 20, 18, en, false, true, Callable(), F)
		# üst diş sırası: ağız kenarında açık renk zikzak üçgenler (koyu ağız aralığının önünde görünür)
		for i in 9:
			var z := lerpf(0.1, -1.7, i / 8.0)
			var s: Array = BE.at(hi, tz.call(z), sx * (PI - 0.55 - i * 0.06), 0.0)
			be.claw((s[0] as Vector3) + Vector3(0, 0.05, 0), Vector3(0, -1.0, -0.12), 0.7 if i % 2 == 0 else 0.48, 0.22, TOOTH, hsk, F, Vector3(0, 0, 1), 4)
		_stroke(be, hi, tz.call(1.3), 1.6 * sx, 0.14, 0.25 * sx, 0.12, sk, 0.25)
		_stroke(be, hi, tz.call(1.7), 0.5 * sx, 0.12, 0.3 * sx, 0.1, sk, -0.25)
	# alt çene: geniş, öne incelen; üstü koyu ağız içi, kenarında yukarı bakan zikzak dişler
	var jsk := [[r.jaw, 1.0]]
	var jk := func(_t, _a, _p): return jsk
	var jp := [Vector3(0, -1.45, 1.0), Vector3(0, -1.6, 0.0), Vector3(0, -1.55, -1.0), Vector3(0, -1.4, -1.6)]
	var jr := [Vector2(2.2, 0.55), Vector2(2.1, 0.6), Vector2(1.6, 0.5), Vector2(0.5, 0.25)]
	var jcol := func(_t: float, a: float, _p: Vector3) -> Color: return DARK if absf(wrapf(a, -PI, PI)) < 0.9 else C
	var ji: Dictionary = be.tube(jp, jr, jcol, jk, 24, 26, Vector3.UP, true, true, Callable(), F)
	var jtz := func(z: float) -> float: return clampf((1.0 - z) / 2.6, 0.0, 1.0)
	for sx: float in [-1.0, 1.0]:
		for i in 8:
			var z := lerpf(0.5, -1.4, i / 7.0)
			var s: Array = BE.at(ji, jtz.call(z), 0.95 * sx, 0.0)
			be.claw((s[0] as Vector3) - Vector3(0, 0.03, 0), Vector3(0, 1.0, -0.05), 0.56 if i % 2 == 0 else 0.38, 0.2, TOOTH, jsk, F, Vector3(0, 0, 1), 4)


# ------------------------------------------------------------------ kuyruk: kalın, pullu (üst üste binen sivri pul sırtları), lacivert izli
static func _tail(be, troot: Node3D, segs: Array, length: float, seg_len: float) -> void:
	var X: Transform3D = be.rs(troot)
	var rf := func(k: float) -> float:
		return lerpf(2.3, 2.6, sin(minf(1.0, k * 3.0) * PI * 0.5)) * (1.0 - pow(maxf(0.0, (k - 0.25) / 0.75), 1.5) * 0.96)
	var pts := []
	var rad := []
	for i in 18:
		var k := float(i) / 17.0
		var z := lerpf(-1.5, length, k)
		pts.append(Vector3(0, 0, z))
		var rr: float = rf.call(clampf(z / length, 0.0, 1.0))
		rad.append(Vector2(rr, rr * 0.92))
	var nseg := segs.size()
	var sk := func(_t: float, _a: float, p: Vector3) -> Array:
		var f := clampf(p.z / seg_len - 0.5, 0.0, nseg - 1.0)
		var i0 := mini(int(f), nseg - 1)
		var i1 := mini(i0 + 1, nseg - 1)
		var w := f - i0
		return [[segs[i0], 1.0 - w], [segs[i1], w]]
	# pul: üst üste binen sivri yaprak pullar (sıralar şaşırtmalı); pul kökü gömük, ucu kabarık, kenarı koyu
	var leaf := func(t: float, a: float) -> Vector2:   # (kabarıklık 0..1, kenar 0..1)
		var rows := 26.0
		var cols := 10.0
		var rr := t * rows
		var row := floorf(rr)
		var ph := rr - row
		var cp := fposmod(a / TAU * cols + (0.5 if int(row) % 2 == 1 else 0.0), 1.0)
		var wdt := 1.0 - pow(absf(2.0 * cp - 1.0), 2.0)
		var h := smoothstep(0.0, 0.9, ph) * wdt
		return Vector2(h, maxf(1.0 - smoothstep(0.0, 0.18, wdt), 1.0 - smoothstep(0.0, 0.12, ph)))
	var bump := func(t: float, a: float) -> float:
		return 0.055 * float(leaf.call(t, a).x) * smoothstep(0.03, 0.1, t) * (1.0 - smoothstep(0.9, 1.0, t))
	var colf := func(t: float, a: float, _p: Vector3) -> Color:
		var lf: Vector2 = leaf.call(t, a)
		return C.lerp(CL, 0.18 * lf.x).darkened(0.28 * lf.y)
	var info: Dictionary = be.tube(pts, rad, colf, sk, 132, 36, Vector3.UP, false, true, bump, X)
	seed(23)
	for i in 56:   # her pulda lacivert iz
		_stroke(be, info, randf_range(0.06, 0.88), randf_range(-PI, PI), 0.035, randf_range(-0.15, 0.15), 0.08, sk, randf_range(-0.2, 0.2))
