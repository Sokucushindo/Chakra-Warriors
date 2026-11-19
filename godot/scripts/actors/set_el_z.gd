extends RefCounted
## Elle modellenmiş setler, parti z: ss_gelinlik, ss_ates_pelerin, ss_mor_etek, ss_mor_genc, ss_mor_uzun, ss_murekkep. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), q (Q), r (R), t (T), v (V), y (Y) dosyalarından; burada boyundan bağlı (halter) kısa üst, Ino etek kesimi,
## parmaklı uzun eldiven, toplanan file paçalı pantolon ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const V = preload("res://scripts/actors/set_el_v.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")

const DONE := ["ss_ates_pelerin", "ss_mor_etek", "ss_mor_genc", "ss_mor_uzun", "ss_murekkep"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_gelinlik": _gelinlik(k)
		"ss_ates_pelerin": _ates(k)
		"ss_mor_etek": _mor_etek(k)
		"ss_mor_genc": _mor_genc(k)
		"ss_mor_uzun": _mor_uzun(k)
		"ss_murekkep": _murekkep(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
static func _male(k) -> bool:
	return str(k.m.look.get("gender", "m")) != "f"


## Uzuv boyunda y yüksekliğinin s değeri
static func _s_at(l: Dictionary, y: float) -> float:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	if y >= p1.y:
		return clampf(inverse_lerp(p0.y, p1.y, y), 0.0, 1.0) * kn
	return lerpf(kn, 1.0, clampf(inverse_lerp(p1.y, p2.y, y), 0.0, 1.0))


## Gövde kesiti: hang > 0 ise göğüs altında kumaş göğüsten düz iner (göğüs altına yapışmaz)
static func _mk(k, y: float, pad: float, hang: float, ch: Vector3) -> Array:
	var m: Vector3 = k.M(y, k.UA if y > k.H else 0.3)
	var zf: float = m.y
	if y < k.C - 0.03:
		zf = maxf(m.y, lerpf(m.y, ch.y * 0.97, hang))
	return [y, m.x + pad, zf + pad, m.z - pad]


## Boyundan y1'e gövde anahtarları
static func _tk(k, b: Dictionary, y1: float, pad: float, hang := 0.0) -> Array:
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [P._kp(nk, N + 0.02, pad * 0.5 + 0.006), [N - 0.045, ch.x * 0.74 + pad, ch.y * 0.84 + pad, ch.z * 0.88 - pad], P._kp(ch, C - 0.03, pad)]
	for y in [C - 0.1, H + 0.12, H + 0.04, H - 0.04]:
		if y > y1 + 0.015:
			keys.append(_mk(k, y, pad, hang, ch))
	keys.append(_mk(k, y1, pad, hang, ch))
	return keys


## Açık omuzlu ten gövde: omuz kesiti dar tutulur (omzu kolun kendi yuvarlak tüpü yapar; sivri omuz köşesi çıkmaz)
static func _skin_torso(k, b: Dictionary, y1: float) -> void:
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.015, 0.005), [N - 0.04, ch.x * 0.7, ch.y * 0.8, ch.z * 0.88], [C + 0.01, ch.x * 0.9, ch.y * 0.96, ch.z * 0.98], P._kp(ch, C - 0.03, 0.003)]
	for y in [C - 0.12, H + 0.12, H + 0.04]:
		if y > y1 + 0.02:
			keys.append(P._kp(k.M(y, k.UA), y, 0.003))
	keys.append(P._kp(k.M(y1, k.UA if y1 > H else 0.3), y1, 0.004))
	var skc: Color = Q._skc(k)
	SE.body_layer(k, keys, 40, 52, func(_i, _j, _p): return skc)


## Açık kol: omuz başında tüp incelir (boyun yanında sivri ten kanadı çıkmaz), bilekte elin içine kapanır
static func _arm_bare(k, ar: Dictionary, s0 := 0.0) -> void:
	var skc: Color = Q._skc(k)
	P._lt(k, ar, func(s, _a):
		var r: float = P._lr(ar, float(s))
		return 0.001 - r * 0.42 * (1.0 - smoothstep(0.0, 0.17, float(s))) - r * 0.9 * smoothstep(0.955, 0.99, float(s)), func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, s0, 0.99, 30, 16)


## Boyundan bağlı (halter) kolsuz üst: omuzlar açık, yaka kenarı boyundan koltuk altına iner. o: col, hem, cut (koltuk altı y), a0/a1 (kenar açıları),
## dip (önde sivri etek ucu), slit (önde yaka yırtmacı, anahtar deliği), pad, hang, ny, na. Döner: _cl sözlüğü + keys + ff
static func _halter(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var N: float = k.N
	var C: float = k.C
	var hem: float = o["hem"]
	var keys: Array = _tk(k, b, hem - float(o.get("dip", 0.0)) - 0.005, o.get("pad", 0.008), o.get("hang", 0.0))
	var col: Color = o["col"]
	var cut: float = o.get("cut", C - 0.03)
	var a0: float = o.get("a0", 0.42)
	var a1: float = o.get("a1", 1.05)
	var top_y: float = o.get("top", N + 0.006)
	var dip: float = o.get("dip", 0.0)
	var slit: float = o.get("slit", 0.0)
	var topf := func(a: float) -> float:
		var u: float = absf(a)
		var sd: float = smoothstep(a0, a1, u) * (1.0 - smoothstep(PI - a1, PI - a0, u))
		return lerpf(top_y, cut, sd)
	var hemf := func(a: float) -> float:
		return hem - dip * exp(-pow(a / 0.6, 2.0))
	var ff := func(a: float, y: float) -> float:
		return 0.007 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, hem, y) + 0.0025 * sin(a * 11.0 + y * 20.0)
	var o2 := {"keys": keys, "ny": o.get("ny", 26), "na": o.get("na", 104), "top": topf, "hem": hemf, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return col, "gain": 5.0, "th": 0.005, "inner": col.darkened(0.35), "skin": func(p): return Q._nsk(k, p)}
	var slit_v: float = o.get("slit_v", 0.3)
	var srng := func(v) -> Vector2:
		var gg: float = slit * (1.0 - smoothstep(0.0, slit_v, float(v))) + 0.0004
		return Vector2(gg, TAU - gg)
	if slit > 0.0:
		o2["rng"] = srng
	var g: Dictionary = P._cl(k, o2)
	g["keys"] = keys
	g["ff"] = ff
	return g


## Dik yaka: boynu saran bant. h: yükseklik, add: boyundan açıklık. Döner: _cl sözlüğü
static func _stand(k, b: Dictionary, h: float, add: float, col: Color, foldf := Callable()) -> Dictionary:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + h * q, add, add + 0.003), P._kp(nk, N + h * 0.4 * q, add + 0.004), P._kp(nk, N - 0.02, add + 0.012)]
	var nsk := func(p): return Q._nsk(k, p)
	var o := {"keys": ck, "ny": 8, "na": 56, "top": func(_a): return N + h * q, "hem": func(_a): return N - 0.014, "col": func(_a, _y, _v): return col, "gain": 5.0,
		"th": 0.005, "inner": col.darkened(0.3), "skin": nsk}
	if foldf.is_valid():
		o["fold"] = foldf
	var g: Dictionary = P._cl(k, o)
	P._cord(k, g["top"], 0.0032, col.lightened(0.04), true, nsk)
	return g


## Yüzey üstünde (açı, y) noktasında yerel düzlem eşlemesi
static func _mp_on(keys: Array, ff: Callable, a: float, y: float) -> Callable:
	return Q._local(keys, ff, a, y)


## Tam eldiven: avuç kılıfı + her parmağa kemiğiyle giden kılıf (parmak ucu kapalı)
static func _glove_full(k, sd: String, col: Color) -> void:
	var m = k.m
	var hd: Vector3 = m._bp(sd + "Hand")
	var el: Vector3 = m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	var w := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var t := d.cross(w).normalized()
	var skin_h := [[sd + "Hand", 1.0]]
	var V0: PackedVector3Array = k.c["V"]
	var near := PackedVector3Array()
	for q: Vector3 in V0:
		if q.distance_to(hd) < 0.2:
			near.append(q)
	# avuç kılıfı: elin kendi köşelerinden ölçülür, parmak köküne kadar sarar
	var hs := [-0.03, -0.012, 0.004, 0.02, 0.034, 0.046, 0.054]
	var nb := 18
	var rad := []
	for h in hs:
		var ro := []
		ro.resize(nb)
		ro.fill(0.0)
		rad.append(ro)
	for q: Vector3 in near:
		var rel := q - hd
		var h0 := rel.dot(d)
		if h0 < -0.045 or h0 > 0.075:
			continue
		var x := rel.dot(w)
		var y := rel.dot(t)
		var r0 := sqrt(x * x + y * y)
		if r0 > 0.08:
			continue
		var bi: int = posmod(int(round((atan2(y, x) + PI) / TAU * nb)), nb)
		for j in hs.size():
			if absf(h0 - float(hs[j])) < 0.012:
				rad[j][bi] = maxf(rad[j][bi], r0)
	var rows := []
	for j in hs.size():
		var src: Array = rad[j]
		var ro := []
		for i in nb:
			var a := TAU * i / nb - PI
			var best: float = maxf(float(src[i]), maxf(float(src[(i + 1) % nb]), float(src[(i + nb - 1) % nb])) * 0.96)
			var e_max: float = 1.0 / sqrt(pow(cos(a) / 0.05, 2.0) + pow(sin(a) / 0.032, 2.0))
			var e_min: float = 1.0 / sqrt(pow(cos(a) / 0.03, 2.0) + pow(sin(a) / 0.018, 2.0))
			best = clampf(best, e_min, e_max)
			var rr: float = best + 0.0028
			ro.append(hd + d * float(hs[j]) + w * cos(a) * rr + t * sin(a) * rr)
		rows.append(ro)
	var sk_rows := []
	for j in hs.size():
		var hj: float = hs[j]
		sk_rows.append(skin_h if hj > -0.005 else [[sd + "Hand", 0.6], [sd + "LowerArm", 0.4]])
	k.grid(rows, true, func(i, j, _p): return col.darkened(0.12 * float((i + j) % 5 == 0)), func(_i, j, _p): return sk_rows[j])
	# parmaklar
	for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		var segs: Array = ["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]
		var pts := []
		var bones := []
		for sn in segs:
			var bn: String = sd + f + String(sn)
			if m.skel.find_bone(bn) < 0:
				pts = []
				break
			pts.append(m._bp(bn))
			bones.append(bn)
		if pts.size() < 3:
			continue
		var dl: Vector3 = (pts[2] as Vector3) - (pts[1] as Vector3)
		var tip: Vector3 = (pts[2] as Vector3) + dl.normalized() * clampf(dl.length() * 0.95, 0.014, 0.026)
		pts.append(tip)
		# yarıçap: o parmağın kendi köşelerinden
		var rs := []
		for si in 3:
			var a3: Vector3 = pts[si]
			var b3: Vector3 = pts[si + 1]
			var ab := b3 - a3
			var sum := 0.0
			var cnt := 0
			for q: Vector3 in near:
				var tt := (q - a3).dot(ab) / maxf(1e-6, ab.length_squared())
				if tt < 0.1 or tt > 0.9:
					continue
				var dd := (q - a3 - ab * tt).length()
				if dd < 0.014:
					sum += dd
					cnt += 1
			rs.append(clampf(sum / maxf(1, cnt) * 1.25, 0.0055, 0.011) if cnt > 0 else 0.008)
		var r0: float = rs[0]
		var r1: float = rs[1]
		var r2: float = rs[2]
		if f == "Thumb":
			pts[0] = (pts[0] as Vector3).lerp(pts[1], 0.35)
		var prof := [[0.0, r0 + 0.0024], [0.34, r1 + 0.0022], [0.68, r2 + 0.002], [0.9, r2 * 0.8 + 0.0016], [1.0, r2 * 0.25]]
		k.tube(pts, bones, prof, func(tt, _a, ins): return col.darkened(0.3) if ins else col.lightened(0.04 * float(tt > 0.85)), 10, 8, false)


## Uzun eldiven (kol tüpü s0'dan bileğe) + el
static func _long_glove(k, ar: Dictionary, s0: float, col: Color, sv: float) -> void:
	var en: float = ar["kn"]
	var gf := func(s: float, a: float) -> float:
		return 0.0032 + 0.0026 * smoothstep(s0 + 0.03, s0, s) + 0.003 * exp(-pow((s - en) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.0015 * P._lf(s, a, sv) * smoothstep(en + 0.04, 0.9, s)
	P._lt(k, ar, gf, func(s, a, ins):
		if ins:
			return col.darkened(0.3)
		return P._fs(col, float(gf.call(float(s), float(a))) - 0.0032, 18.0).lightened(0.05 * float(float(s) < s0 + 0.02)), s0, 0.995, 30, 18, 0.015)
	_glove_full(k, String(ar["sd"]), col)


## Toplanan bol pantolon, altında file ve ten, bilekte koyu bant
static func _baggy_net(k, le: Dictionary, col: Color, base: float, bag: float, tk: float, sv: float, nt: Color, band: Color) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var g: float = 1.0 - smoothstep(tk - 0.03, tk + 0.005, s)
		var cr: float = 0.009 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.012 * exp(-pow((s - tk + 0.045) / 0.045, 2.0)) * sin(a * 9.0 + sv)
		return ((0.006 + bag * 0.16) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + cr + ru) * g
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = (base + bag * smoothstep(0.0, 0.42, s) * (1.0 - 0.18 * smoothstep(0.55, tk, s))) * (1.0 - 0.42 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
		var g: float = smoothstep(tk - 0.06, tk + 0.008, s)
		return lerpf(v, 0.007, g) + float(fo.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		return P._fs(col, fo.call(s, a), 13.0), 0.0, tk + 0.012, 42, 24, 0.02)
	P._bare(k, le, Q._skc(k), tk - 0.04, 1.0)
	P._net_limb(k, le, tk - 0.005, 0.95, 0.0024, 12, 0.026, 0.0013, nt)
	P._lt(k, le, func(s, _a): return 0.0045 + 0.0015 * sin(clampf((float(s) - 0.935) / 0.05, 0.0, 1.0) * PI), func(_s, _a, ins): return band.darkened(0.3) if ins else band, 0.935, 0.99, 4, 18)
	return ad


## File dizlik / dirseklik: altta ten, ağ, iki ucunda çizgili kalın bant (gri + mor)
static func _net_pad(k, l: Dictionary, s0: float, s1: float, nt: Color, c_a: Color, c_b: Color, sv: float) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var bw: float = 0.026 / L
	var sheer: Color = nt.lerp(Q._skc(k), 0.55)
	P._lt(k, l, func(_s, _a): return 0.0022, func(s, a, ins): return sheer.darkened(0.3) if ins else sheer.darkened(0.08 * absf(sin(float(a) * 2.0 + sv))), s0 + bw * 0.5, s1 - bw * 0.5, 14, 18)
	P._net_limb(k, l, s0 + bw * 0.6, s1 - bw * 0.6, 0.0038, 12, 0.022, 0.0011, nt)
	for e in [[s0, s0 + bw], [s1 - bw, s1]]:
		var a0: float = e[0]
		var a1: float = e[1]
		P._lt(k, l, func(s, _a): return 0.0058 + 0.0014 * sin(clampf((float(s) - a0) / (a1 - a0), 0.0, 1.0) * PI), func(s, _a, ins):
			if ins:
				return c_a.darkened(0.3)
			var u: float = clampf((float(s) - a0) / (a1 - a0), 0.0, 1.0)
			return c_b if u > 0.36 and u < 0.64 else c_a, a0, a1, 5, 20)


## Yere inen gelinlik ağırlığı: ön yüz diz hizasına kadar uyluğu, diz altında kendi baldırını izler (öne kalkan diz eteği sert levha gibi kaldırmaz,
## kumaş baldırın önünde aşağı düşer); arka yüz boy boyunca yavaş artar, diz altında baldırı izler (geri savrulan topuk delmez)
static func _gsk(k, p: Vector3, hem: float, hw_top := 0.05, kb_back := 0.7, w_back := 0.95) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.2), 0.35)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), w_back, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.94, smoothstep(0.8, 1.0, t))
	var hw: float = lerpf(lerpf(hw_top, 0.1, smoothstep(0.1, 0.5, t)), 0.09, bk)   # üstte her yarı kendi uyluğunu izler (kalkan uyluk ortadan delmez)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * lerpf(1.0, kb_back, bk) * minf(1.0, absf(2.0 * s - 1.0) * lerpf(1.5, 1.0, bk))
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Yanları açık panel etek ağırlığı: her yarı kendi uyluğuna sıkı bağlı (uyluk paneli delmez), ortada dar geçiş
static func _psk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = pow(minf(1.0, t / 0.35), 0.5)
	var s: float = smoothstep(-0.045, 0.045, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ Kuro Hanayome (ref Shinobi Striker "Hinata Outfit: Bridal Ver."): boyundan bağlı kolsuz siyah-mor gelinlik: dik yaka + önde anahtar deliği,
## göğüs altında pli fırfır, geniş kemer, kemerin altında pli kısa kat (peplum), yere inen A kesim etek + altında koyu ikinci kat, önde kemerden sarkan açık tonlu pli şeritler, dirsek üstüne çıkan parmaklı eldiven
static func _gelinlik(k) -> void:
	var c0 := Color(0.15, 0.11, 0.17)
	var c1 := Color(0.175, 0.128, 0.215)
	var lo := Color(0.105, 0.08, 0.125)
	var rb := Color(0.33, 0.29, 0.38)
	var gl := Color(0.11, 0.09, 0.13)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var ch: Vector3 = b["ch"]
	var male: bool = _male(k)
	var tsk := func(p): return k.torso_skin(p.y)
	# ten: omuz, göğüs üstü (yaka yırtmacının arkası), kollar
	_skin_torso(k, b, C - 0.08)
	# altta koyu külotlu çorap (etek kalkınca bacak boş görünmez)
	K._seat(k, b, lo)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		P._lt(k, le, func(s, a): return 0.0028 + 0.0012 * sin(float(a) * 3.0 + float(s) * 20.0), func(_s, a, ins): return lo.darkened(0.3) if ins else lo.lightened(0.05 * maxf(0.0, cos(float(a)))), 0.0, 0.99, 24, 14)
		var ar: Dictionary = P._limb(k, sd, false)
		_arm_bare(k, ar)
		_long_glove(k, ar, 0.3, gl, 0.6 if sd == "Left" else 1.7)
	# korsaj: boyundan bağlı, omuzlar açık, önde anahtar deliği
	var bod: Dictionary = _halter(k, b, {"col": c0, "hem": H + 0.06, "cut": C - 0.035, "a0": 0.4, "a1": 1.0, "slit": 0.05, "slit_v": 0.22, "pad": 0.008, "hang": 0.35, "ny": 34})
	var nsk := func(p): return Q._nsk(k, p)
	P._cord(k, bod["top"], 0.0032, c0.lightened(0.05), true, nsk)
	var bk: Array = bod["keys"]
	var bff: Callable = bod["ff"]
	var sl: Array = Q._spt(bk, bff, 0.0, N - 0.045, 0.004)
	P._stud(k, sl[0], sl[1], 0.0045, c0.lightened(0.12), k.torso_skin(N - 0.045))
	# prenses dikişleri
	for sg in [1.0, -1.0]:
		Q._run(k, bk, bff, [Vector2(sg * 0.5, C - 0.01), Vector2(sg * 0.42, C - 0.08), Vector2(sg * 0.38, H + 0.07)], 0.0018, 0.003, 0.0011, c0.darkened(0.25), tsk, 8)
	# dik yaka: önde ince açıklık, düğme
	var cg: Dictionary = _stand(k, b, 0.055, 0.006, c0)
	var cb: Array = Q._spt([P._kp(b["nk"], N + 0.03, 0.012)], Callable(), 0.0, N + 0.03, 0.002)
	P._stud(k, cb[0], cb[1], 0.0038, c0.lightened(0.14), [["Neck", 0.5], ["UpperChest", 0.5]])
	# kemer
	var by: float = H + 0.085
	var wk := [P._kp(k.M(H + 0.13, k.UA), H + 0.13, 0.014), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.016)]
	V._belt(k, wk, by, 0.0, 0.021, 0.006, c0.lightened(0.03), 0.0, 96)
	# göğüs altı pli fırfır: üst kenarı dışa açılır
	var mb: Vector3 = k.M(C - 0.085, k.UA)
	var fy0: float = C - 0.07
	var fy1: float = by + 0.016
	var fk := [[fy0, mb.x + 0.034, maxf(mb.y, ch.y * 0.94) + 0.036, mb.z - 0.03], [lerpf(fy0, fy1, 0.5), mb.x + 0.02, maxf(mb.y, ch.y * 0.9) + 0.018, mb.z - 0.02], [fy1, wa.x + 0.016, wa.y + 0.016, wa.z - 0.016]]
	var fr: Dictionary = P._cl(k, {"keys": fk, "ny": 8, "na": 112, "top": func(_a): return fy0, "hem": func(_a): return fy1 - 0.004, "fold": func(a, _y, v): return Y._pleat(float(a), 15.0, 0.07) * (1.0 - 0.55 * float(v)) + 0.01 * (1.0 - float(v)),
		"col": func(_a, _y, _v): return c1, "gain": 6.0, "th": 0.004, "inner": c1.darkened(0.4), "skin": tsk})
	P._cord(k, fr["top"], 0.0026, c1.lightened(0.06), true, tsk)
	# etek: yere iner, A kesim; alt kat koyu
	var hem_l: float = F + 0.012
	var hem_m: float = hem_l + 0.055
	var sk := [P._kp(k.M(H + 0.075, 0.3), H + 0.075, 0.012), P._kp(hp, H - 0.04, 0.04), [KN + 0.12, hp.x + 0.075, hp.y + 0.075, hp.z - 0.085], [KN - 0.12, hp.x + 0.11, hp.y + 0.13, hp.z - 0.15], [hem_l, hp.x + 0.145, hp.y + 0.16, hp.z - 0.18]]
	var gsk := func(p): return _gsk(k, p, hem_l, 0.05, 0.45, 0.85)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem_l), 0.0, 1.0)
		var aw: float = absf(a)
		var fr2: float = 1.0 - 0.55 * exp(-pow(aw / 0.3, 2.0))   # önde şeritlerin altında düz
		return fr2 * pow(t, 0.8) * (0.034 * sin(a * 6.0 + 0.6) + 0.016 * sin(a * 11.0 + 1.9)) + 0.004 * sin(a * 18.0) * (1.0 - t)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# alt kat: etek ucunun altından taşan koyu bant
	var lk := []
	for e in sk:
		var yy: float = e[0]
		var gw: float = 0.006 * smoothstep(KN - 0.1, hem_l, yy)
		lk.append([yy, float(e[1]) - 0.008 + gw * 2.0, float(e[2]) - 0.008 + gw * 2.0, float(e[3]) + 0.008 - gw * 2.0])
	var lg: Dictionary = P._cl(k, {"keys": lk, "ny": 8, "na": 88, "top": func(_a): return KN - 0.12, "hem": func(_a): return hem_l, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return lo, "gain": 4.0, "th": 0.006, "inner": lo.darkened(0.3), "skin": gsk})
	var lh := []
	for p in lg["hem"]:
		lh.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, lh, 0.003, 0.0016, lo.lightened(0.06), true, gsk)
	var eg: Dictionary = P._cl(k, {"keys": sk, "ny": 34, "na": 84, "top": func(_a): return H + 0.075, "hem": func(_a): return hem_m, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return c1, "gain": 4.5, "th": 0.007, "inner": c1.darkened(0.35), "skin": gsk})
	var eh := []
	for p in eg["hem"]:
		eh.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, eh, 0.0035, 0.0018, c1.darkened(0.2), true, gsk)
	for sg in [1.0, -1.0]:
		Q._run(k, sk, ffw, [Vector2(sg * 1.57, H + 0.06), Vector2(sg * 1.57, hem_m + 0.02)], 0.0018, 0.002, 0.0011, c1.darkened(0.22), gsk, 14)
	# peplum: kemerin altında pli kısa kat
	var pk := [P._kp(k.M(H + 0.075, 0.3), H + 0.075, 0.024), [H - 0.06, hp.x + 0.07, hp.y + 0.07, hp.z - 0.07]]
	var pg: Dictionary = P._cl(k, {"keys": pk, "ny": 8, "na": 112, "top": func(_a): return by - 0.012, "hem": func(_a): return H - 0.06, "fold": func(a, _y, v): return Y._pleat(float(a), 16.0, 0.06) * (0.4 + 0.6 * float(v)),
		"col": func(_a, _y, _v): return c1.lightened(0.03), "gain": 6.0, "th": 0.005, "inner": c1.darkened(0.4), "skin": gsk})
	P._bd(k, K._yl(pg["hem"], 0.007), 0.0026, 0.0014, c1.darkened(0.15), true, gsk)
	# önde kemerden sarkan açık tonlu pli şeritler (ayrı kumaş, eteğin üstüne oturur)
	var rk := []
	for e in sk:
		rk.append([e[0], float(e[1]) + 0.01, float(e[2]) + 0.016, float(e[3]) - 0.01])
	var rw := func(v: float) -> float: return lerpf(0.24, 0.15, v)
	var rsk := func(p): return _gsk(k, Vector3(float(p.x) * 2.2, p.y, p.z), hem_l, 0.05, 0.45, 0.85)   # şerit kenarları kendi baldırını izler: öne çıkan baldır şeridi delmez
	var rrng := func(v) -> Vector2:
		var w2: float = rw.call(float(v))
		return Vector2(-w2, w2)
	var rfold := func(a, y, v) -> float:
		var w3: float = rw.call(float(v))
		var u: float = (float(a) + w3) / (2.0 * w3)
		return Y._pleat(u * PI, 5.0, 0.03) + float(ff.call(float(a), float(y))) * 0.6
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 42, "na": 30, "rng": rrng, "top": func(_a): return by - 0.01, "hem": func(a): return hem_m + 0.035 + 0.02 * absf(float(a)),
		"fold": rfold, "col": func(_a, _y, _v): return rb, "gain": 7.0, "th": 0.004, "inner": rb.darkened(0.4), "skin": rsk})
	for ed in [rg["ea"], rg["eb"]]:
		P._cord(k, ed, 0.0022, rb.darkened(0.2), false, rsk)
	P._cur_hem = hem_l


# ------------------------------------------------------------------ Hi no Gaitō (ref Shinobi Striker "Hiruzen Outfit"): boğazlı siyah tulum (beli kemerin üstüne bollaşır), dirseğe inen bol kısa kol, perçinli gri omuzluklar,
## lacivert kemer, kolda file + koyu bilek bandı, sağ kolda bileği aşan perçinli gri kolluk, baldır ortasında toplanan bol pantolon + altında file ve bilekte koyu bant
static func _ates(k) -> void:
	var bk := Color(0.1, 0.1, 0.12)
	var gy := Color(0.66, 0.66, 0.72)
	var bl := Color(0.15, 0.17, 0.38)
	var nt := Color(0.3, 0.3, 0.36)
	var ag := Color(0.56, 0.57, 0.52)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# gövde: bol, belde kemerin üstüne bollaşır
	var keys: Array = _tk(k, b, H - 0.03, 0.016, 0.4)
	var bf := func(a: float, y: float) -> float:
		var bo: float = 0.045 * exp(-pow((y - (H + 0.11)) / 0.05, 2.0)) * (1.0 - smoothstep(H + 0.06, H + 0.04, y))
		return bo + (0.012 * sin(a * 7.0 + y * 14.0) + 0.006 * sin(a * 13.0 - y * 9.0)) * smoothstep(C - 0.05, H + 0.08, y) + 0.004 * sin(a * 4.0 - y * 20.0)
	P._cl(k, {"keys": keys, "ny": 40, "na": 96, "top": func(_a): return N + 0.006, "hem": func(_a): return H - 0.03, "fold": func(a, y, _v): return bf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 5.0, "th": 0.0, "skin": tsk})
	# boğazlı yaka
	var tf := func(a, _y, v): return 0.004 * sin(float(a) * 5.0 + float(v) * 3.0)
	_stand(k, b, 0.085, 0.008, bk.lightened(0.02), tf)
	# kemer
	var wk := [P._kp(k.M(H + 0.12, k.UA), H + 0.12, 0.03), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.03)]
	P._sash(k, wk, H + 0.055, 0.028, 0.008, bl, 0.12)
	V._belt(k, wk, H + 0.055, 0.0, 0.006, 0.019, bl.lightened(0.1), 0.0, 72)
	# kollar: bol kısa kol (dirsek), file, bilek bandı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.5 if sd == "Left" else 1.6
		var s1: float = en + 0.035
		_arm_bare(k, ar, en - 0.12)
		P._net_limb(k, ar, en - 0.05, 0.93, 0.0026, 11, 0.024, 0.0012, nt)
		P._lt(k, ar, func(s, _a): return 0.0048 + 0.0016 * sin(clampf((float(s) - 0.915) / 0.06, 0.0, 1.0) * PI), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.02), 0.915, 0.975, 4, 18)
		var sf := func(s: float, a: float) -> float:
			var g: float = smoothstep(s1 - 0.09, s1, s)
			return 0.02 + 0.016 * smoothstep(0.05, 0.3, s) - 0.012 * g - P._lr(ar, s) * 0.4 * (1.0 - smoothstep(0.0, 0.17, s)) + 0.006 * P._lf(s, a, sv) * (1.0 - g) + 0.007 * exp(-pow((s - s1 + 0.05) / 0.04, 2.0)) * sin(a * 7.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return bk.darkened(0.4) if ins else P._fs(bk.lightened(0.03), float(sf.call(float(s), float(a))) - 0.03, 12.0), 0.0, s1, 28, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, bk.darkened(0.3), s1 - 0.08, s1 - 0.003, 4, 22)
		# omuzluk: omzun üstünde kavisli plaka, kenar kalın, dışta perçin
		var au: float = V._outer(ar, 0.1, Vector3.UP)
		K._shell(k, ar, 0.02, 0.2, au - 1.05, au + 1.05, func(s, a): return float(sf.call(float(s), float(a))) + 0.006 + 0.004 * sin(clampf((float(s) - 0.02) / 0.18, 0.0, 1.0) * PI), 0.007, func(u, v, e):
			if e:
				return gy.darkened(0.3)
			return gy.darkened(0.16) if u < 0.06 or u > 0.94 or v > 0.9 else gy.lightened(0.04 * (1.0 - float(v))), 12, 18)
		for e2 in [[0.15, au + 0.55], [0.15, au - 0.55]]:
			var sp: float = e2[0]
			var ap: float = e2[1]
			var rv: Array = Q._ls(ar, sp, ap, float(sf.call(sp, ap)) + 0.0185)
			P._stud(k, rv[0], rv[1], 0.0048, gy.lightened(0.15), P._lskin(ar, sp))
		# sağ kolda uzun kolluk: ön kolun dışında, bileği aşar
		if sd == "Right":
			var ao: float = V._outer(ar, 0.78, Vector3.UP)
			var gs0: float = en + 0.06
			K._shell(k, ar, gs0, 0.995, ao - 0.62, ao + 0.62, func(s, _a): return 0.012 + 0.003 * smoothstep(gs0 + 0.05, gs0, float(s)), 0.007, func(u, v, e):
				if e:
					return ag.darkened(0.3)
				return ag.darkened(0.2) if u < 0.07 or u > 0.93 or v < 0.03 else ag.lightened(0.05 * float(absf(u - 0.5) < 0.12)), 18, 14)
			for sp2 in [gs0 + 0.06, 0.88]:
				k.wrap_turn(P._lp(ar, sp2), P._ld(ar, sp2), P._lr(ar, sp2) + 0.02, 0.008, 0.0, bk.lightened(0.04), P._lskin(ar, sp2))
			for i in 3:
				var sp3: float = lerpf(gs0 + 0.14, 0.8, float(i) / 2.0)
				var pe: Array = Q._ls(ar, sp3, ao, 0.0205)
				var dd: Vector3 = P._ld(ar, sp3)
				var po: Vector3 = pe[1]
				P._boxr(k, pe[0], po.cross(dd).normalized() * 0.008, dd * 0.016, po * 0.0025, ag.darkened(0.1), P._lskin(ar, sp3), 0.3)
			# uç: bileğin ötesinde elin yanına uzanan sivri plaka (ön kolla sert gider)
			var p2: Vector3 = ar["p2"]
			var d2: Vector3 = P._ld(ar, 0.99)
			var pe2: Array = Q._ls(ar, 0.99, ao, 0.0185)
			var po2: Vector3 = pe2[1]
			var c2: Vector3 = (pe2[0] as Vector3) + d2 * 0.03
			var rows := []
			for j in 5:
				var t := float(j) / 4.0
				var wv: float = 0.022 * (1.0 - t * 0.75)
				var ro := []
				for i in 5:
					var u := float(i) / 4.0 * 2.0 - 1.0
					ro.append(c2 + d2 * lerpf(-0.03, 0.028, t) + po2.cross(d2).normalized() * u * wv + po2 * 0.004 * (1.0 - u * u))
				rows.append(ro)
			Q._mesh(k, rows, false, func(_i, _j, _p): return ag, func(_i, _j, _p): return [[sd + "LowerArm", 1.0]], po2)
			var back_rows := []
			for ro in rows:
				var br := []
				for p in ro:
					br.append((p as Vector3) - po2 * 0.005)
				back_rows.append(br)
			Q._mesh(k, back_rows, false, func(_i, _j, _p): return ag.darkened(0.3), func(_i, _j, _p): return [[sd + "LowerArm", 1.0]], -po2)
	# pantolon: baldır ortasında toplanır, altı file
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		_baggy_net(k, le, bk, 0.016, 0.028, kn + (1.0 - kn) * 0.5, 0.9 if sd == "Left" else 2.1, nt, bk.lightened(0.02))


# ------------------------------------------------------------------ Ino etek kesimi (üç mor setin ortak kalıbı): belde bantlı A kesim etek. o: y0, hem, flare, amp, col, gap (önde açıklık, yoksa kapalı),
## step (bindirme kenarının açısı, yoksa yok), skin(p). Döner: keys, ff, g
static func _iskirt(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var H: float = k.H
	var y0: float = o["y0"]
	var hem: float = o["hem"]
	var hp: Vector3 = b["hp"]
	var wm: Vector3 = k.M(y0, 0.3)
	var fl: float = o.get("flare", 0.06)
	var amp: float = o.get("amp", 0.025)
	var col: Color = o["col"]
	var ea: float = o.get("ease", 0.0)   # önde uyluk payı: öne kalkan uyluk kumaşı delmez
	var keys := [[y0, wm.x + 0.012, wm.y + 0.012, wm.z - 0.012], [H - 0.04, hp.x + 0.03, hp.y + 0.03 + ea, hp.z - 0.032]]
	if hem < k.K + 0.04:
		keys.append([k.K + 0.08, hp.x + 0.03 + fl * 0.6, hp.y + 0.03 + fl * 0.55 + ea, hp.z - 0.032 - fl * 0.55])
	keys.append([hem, hp.x + 0.03 + fl, hp.y + 0.03 + fl * 0.85 + ea, hp.z - 0.032 - fl * 0.9])
	var ins: float = o.get("inset", 0.0)   # iç kat: dış kumaşın altında kalır
	if ins > 0.0:
		for e in keys:
			e[1] = float(e[1]) - ins
			e[2] = float(e[2]) - ins
			e[3] = float(e[3]) + ins
	var se: float = o.get("step", 99.0)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var f: float = t * (amp * sin(a * 7.0 + 0.6) + amp * 0.4 * sin(a * 12.0 + 1.9)) + 0.004 * sin(a * 16.0) * (1.0 - t)
		if se < 9.0:
			f += 0.012 * smoothstep(se - 0.006, se + 0.006, a) * (1.0 - smoothstep(1.6, 2.4, a))
		return f
	var sk: Callable = o["skin"]
	var co := {"keys": keys, "ny": o.get("ny", 30), "na": o.get("na", 120), "top": func(_a): return y0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(a, y, v): return o["colf"].call(float(a), float(y), float(v)) if o.has("colf") else col, "gain": 6.0, "th": 0.006, "inner": col.darkened(0.38), "skin": sk}
	if o.has("gap"):
		co["rng"] = o["gap"]
	var g: Dictionary = P._cl(k, co)
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.003, 0.0016, col.darkened(0.18), o.has("gap") == false, sk)
	# bel bandı
	var bk := [[y0 + 0.02, wm.x + 0.02, wm.y + 0.02, wm.z - 0.02], [y0 - 0.04, wm.x + 0.024, wm.y + 0.024, wm.z - 0.024]]
	if o.get("belt", true):
		V._belt(k, bk, y0 - 0.012, 0.0, 0.0135, 0.004, col.darkened(0.06), 0.0, 96)
	return {"keys": keys, "ff": ff, "g": g, "bk": bk}


# ------------------------------------------------------------------ Murasaki Kunoichi (ref Shinobi Striker "Ino Outfit"): boyundan bağlı kolsuz mor kısa üst (koyu dik yaka, önde düğmeli pat), açık karın,
## düşük belli mor etek (bel bandı + düğme, önde yırtmaç: altında gri-mavi iç panel), koyu gri şort, sağ uylukta beyaz sargı, gri-mor çizgili file dirseklik ve dizlik
static func _mor_etek(k) -> void:
	var pu := Color(0.416, 0.165, 0.604)
	var pd := Color(0.26, 0.1, 0.4)
	var gp := Color(0.44, 0.5, 0.66)
	var gs := Color(0.24, 0.24, 0.29)
	var nt := Color(0.36, 0.37, 0.44)
	var sg_c := Color(0.62, 0.62, 0.68)
	var wh := Color(0.93, 0.92, 0.9)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var tsk := func(p): return k.torso_skin(p.y)
	_skin_torso(k, b, H - 0.02)
	# üst
	var top: Dictionary = _halter(k, b, {"col": pu, "hem": C - 0.11, "cut": C - 0.03, "a0": 0.42, "a1": 1.02, "pad": 0.009, "hang": 0.75})
	var tk: Array = top["keys"]
	var tff: Callable = top["ff"]
	var nsk := func(p): return Q._nsk(k, p)
	P._cord(k, top["top"], 0.003, pu.darkened(0.12), true, nsk)
	P._bd(k, K._yl(top["hem"], 0.007), 0.0028, 0.0014, pu.darkened(0.18), true, tsk)
	# önde pat + düğmeler
	Q._run(k, tk, tff, [Vector2(0.0, N - 0.005), Vector2(0.0, C - 0.105)], 0.011, 0.002, 0.0022, pu.lightened(0.03), tsk, 10)
	Q._run(k, tk, tff, [Vector2(0.075, N - 0.01), Vector2(0.075, C - 0.105)], 0.0014, 0.0034, 0.001, pu.darkened(0.3), tsk, 10)
	for i in 5:
		var y: float = lerpf(N - 0.03, C - 0.09, float(i) / 4.0)
		var e: Array = Q._spt(tk, tff, 0.0, y, 0.0042)
		P._stud(k, e[0], e[1], 0.0044, pd, k.torso_skin(y))
	# arkada orta dikiş
	Q._run(k, tk, tff, [Vector2(PI - 0.001, N - 0.0), Vector2(PI - 0.001, C - 0.105)], 0.0016, 0.0025, 0.001, pu.darkened(0.25), tsk, 10)
	_stand(k, b, 0.05, 0.006, pd)
	# kollar: ten + file dirseklik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		_arm_bare(k, ar)
		_net_pad(k, ar, en - 0.17, en + 0.17, nt, sg_c, pu, 0.4 if sd == "Left" else 1.3)
	# şort + bacaklar
	var sk0: Array = R._seat_keys(k, b)
	var sk := [P._kp(k.M(H + 0.03, 0.3), H + 0.03, 0.008), sk0[2], sk0[3]]   # şort beli etek bandının altında kalır
	R._seat(k, sk, func(_i, _j, _p): return gs)
	var hem: float = H - 0.26
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var s1: float = kn * 0.3
		var ad: Callable = R._short_leg(k, le, gs, s1, 0.012, 0.01, sv)
		R._hem_roll(k, le, ad, s1, gs.lightened(0.05), 0.026, 0.002)
		P._bare(k, le, skc, s1 - 0.06, 1.0)
		_net_pad(k, le, kn - 0.14, kn + 0.12, nt, sg_c, pu, sv)
		if sd == "Right":
			var hs: float = _s_at(le, hem) + 0.02
			for i in 3:
				var s: float = hs + float(i) * 0.03
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + 0.004, 0.014, 0.008 * (1.0 if i % 2 == 0 else -1.0), wh.darkened(0.05 * float(i % 2)), P._lskin(le, s))
	# etek: düşük bel, önde yırtmaç; altında gri-mavi iç panel
	var y0: float = H + 0.045
	var esk := func(p): return Y._msk(k, p, hem)
	var gap := func(v) -> Vector2:
		var gg: float = lerpf(0.035, 0.1, smoothstep(0.08, 1.0, float(v)))
		return Vector2(gg, TAU - gg)
	var ip: Dictionary = _iskirt(k, b, {"y0": y0, "hem": hem + 0.004, "flare": 0.035, "amp": 0.0, "col": gp, "skin": esk, "gap": func(_v): return Vector2(-0.36, 0.36), "ny": 16, "na": 28, "belt": false, "inset": 0.005})
	var ek: Dictionary = _iskirt(k, b, {"y0": y0, "hem": hem, "flare": 0.05, "amp": 0.018, "col": pu, "skin": esk, "gap": gap, "ny": 28, "na": 110})
	var g: Dictionary = ek["g"]
	for ed in [g["ea"], g["eb"]]:
		P._cord(k, ed, 0.0028, pu.darkened(0.15), false, esk)
	# bel bandında düğme (yırtmacın solunda)
	var bb: Array = Q._spt(ek["bk"], Callable(), 0.12, y0 - 0.012, 0.009)
	P._stud(k, bb[0], bb[1], 0.0055, pd, [["Hips", 1.0]])
	P._cur_hem = hem


# ------------------------------------------------------------------ Murasaki Nagasukāto (ref Shinobi Striker "Ino Outfit 2"): boyundan bağlı kolsuz mor kısa üst (sivri gömlek yakası, önde orta dikiş,
## göğüs altında bant, önde sivri inen etek ucu), açık karın, baldır ortasına inen kruvaze mor sargı etek (bel bandı, sağ önde bindirme kenarı)
static func _mor_uzun(k) -> void:
	var pu := Color(0.353, 0.165, 0.541)
	var pl := Color(0.62, 0.52, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	_skin_torso(k, b, H - 0.02)
	for sd in ["Left", "Right"]:
		_arm_bare(k, P._limb(k, sd, false))
		P._bare(k, P._limb(k, sd, true), Q._skc(k), 0.0, 1.0)
	K._seat(k, b, pu.darkened(0.3))
	# üst: önde sivri uç
	var top: Dictionary = _halter(k, b, {"col": pu, "hem": C - 0.1, "dip": 0.035, "cut": C - 0.03, "a0": 0.36, "a1": 1.0, "pad": 0.009, "hang": 0.8})
	var tk: Array = top["keys"]
	var tff: Callable = top["ff"]
	P._cord(k, top["top"], 0.003, pl, true, nsk)
	P._cord(k, K._yl(top["hem"], 0.004), 0.0028, pl, true, tsk)
	Q._run(k, tk, tff, [Vector2(0.0, N - 0.0), Vector2(0.0, C - 0.12)], 0.0022, 0.003, 0.0016, pl, tsk, 12)
	# göğüs altı bant: koyu şerit + açık biyeler
	var yb: float = C - 0.065
	var ring := []
	for i in 96:
		ring.append(Q._spt(tk, tff, TAU * i / 96.0 - PI, yb, 0.0035)[0])
	P._bd(k, ring, 0.009, 0.0026, pu.darkened(0.2), true, tsk)
	for dy in [0.009, -0.009]:
		var r2 := []
		for i in 96:
			r2.append(Q._spt(tk, tff, TAU * i / 96.0 - PI, yb + dy, 0.006)[0])
		P._cord(k, r2, 0.0018, pl, true, tsk)
	# sivri gömlek yakası: dik bant + öne kıvrılan iki sivri kanat
	_stand(k, b, 0.045, 0.006, pu)
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + 0.04 * q, 0.012, 0.016), P._kp(nk, N + 0.0, 0.026), P._kp(nk, N - 0.04, 0.05)]
	var cf := func(a: float) -> float:
		var tipz: float = exp(-pow((absf(a) - 0.36) / 0.2, 2.0))
		return N - 0.012 - 0.05 * tipz * smoothstep(0.08, 0.2, absf(a))
	var cl: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 64, "rng": func(_v): return Vector2(0.07, TAU - 0.07), "top": func(_a): return N + 0.036 * q, "hem": cf,
		"col": func(_a, _y, _v): return pu, "gain": 5.0, "th": 0.004, "inner": pu.darkened(0.3), "skin": nsk})
	P._cord(k, cl["hem"], 0.0024, pl, false, nsk)
	for ed in [cl["ea"], cl["eb"]]:
		P._cord(k, ed, 0.0022, pl, false, nsk)
	# uzun kruvaze etek: sağ önde bindirme
	var hem: float = lerpf(KN, F, 0.42)
	var y0: float = H + 0.05
	var esk := func(p): return _gsk(k, p, hem, 0.11)
	var se := -0.32
	var ek: Dictionary = _iskirt(k, b, {"y0": y0, "hem": hem, "flare": 0.05, "ease": 0.055, "amp": 0.018, "col": pu, "skin": esk, "step": se, "ny": 40, "na": 132})
	var keys: Array = ek["keys"]
	var ff: Callable = ek["ff"]
	# alt kanat: üst kanadın altına giren iç kat, sağ uyluğu izler (adımda bindirme açılınca altından ten değil kumaş görünür)
	var usk := func(p): return _gsk(k, Vector3(minf(float(p.x), -0.1), p.y, p.z), hem, 0.11)
	var uk := []
	for e in keys:
		uk.append([e[0], float(e[1]) - 0.003, float(e[2]) - 0.004, float(e[3]) + 0.003])
	P._cl(k, {"keys": uk, "ny": 30, "na": 30, "rng": func(_v): return Vector2(se - 0.1, se + 0.95), "top": func(_a): return y0 - 0.01, "hem": func(_a): return hem + 0.006,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)) - 0.012 * smoothstep(se - 0.006, se + 0.006, float(a)), "col": func(_a, _y, _v): return pu.darkened(0.12), "gain": 6.0, "th": 0.004, "inner": pu.darkened(0.4), "skin": usk})
	# bindirme kenarı: belden etek ucuna hafif verev, kenar dönüşü + biye
	var ctrl := [Vector2(se + 0.012, y0 - 0.02), Vector2(se + 0.02, (y0 + hem) * 0.5), Vector2(se + 0.028, hem + 0.012)]
	Q._run(k, keys, ff, ctrl, 0.0034, 0.0015, 0.0022, pu.lightened(0.04), esk, 14)
	Q._run(k, keys, ff, [Vector2(se + 0.003, y0 - 0.02), Vector2(se + 0.006, hem + 0.012)], 0.0016, 0.003, 0.0012, pl, esk, 14)
	P._cur_hem = hem


# ------------------------------------------------------------------ Murasaki Kodomo (ref Shinobi Striker "Ino Outfit (Young Ver.)"): bol boğazlı kolsuz mor kısa üst (göğüste kapaklı cep + 山 damgası),
## karında beyaz sargı, Konoha plakalı mavi kemer, yanları açık ön-arka panelli mor etek, altında beyaz sargılı şort, sağ uylukta koyu kılıf, mor biyeli bol beyaz kolluk
static func _mor_genc(k) -> void:
	var pu := Color(0.36, 0.22, 0.56)
	var pd := Color(0.26, 0.16, 0.42)
	var wh := Color(0.93, 0.93, 0.95)
	var bl := Color(0.2, 0.26, 0.58)
	var mt := Color(0.74, 0.75, 0.78)
	var nv := Color(0.14, 0.16, 0.3)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# kollar: ten + bol beyaz kolluk
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.2
		_arm_bare(k, ar)
		var s0 := 0.3
		var wf := func(s: float, a: float) -> float:
			return 0.014 + 0.012 * smoothstep(s0, 0.75, s) - 0.008 * smoothstep(0.88, 0.95, s) + 0.005 * P._lf(s, a, sv) * smoothstep(s0 + 0.04, s0 + 0.12, s) * smoothstep(0.95, 0.88, s) + 0.007 * exp(-pow((s - en) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, ar, wf, func(s, a, ins): return wh.darkened(0.35) if ins else P._fs(wh, float(wf.call(float(s), float(a))) - 0.02, 9.0), s0, 0.975, 30, 20, 0.02)
		for e in [[s0, s0 + 0.04], [0.935, 0.978]]:
			var b0: float = e[0]
			var b1: float = e[1]
			P._lt(k, ar, func(s, a): return float(wf.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return pd.darkened(0.3) if ins else pu, b0, b1, 3, 20)
	# üst: bol, kolsuz, karın üstünde biter
	var hem: float = H + 0.165
	var keys: Array = _tk(k, b, hem, 0.018, 0.6)
	var ff := func(a: float, y: float) -> float:
		return 0.01 * sin(a * 5.0 + 0.4) * smoothstep(C - 0.02, hem, y) + 0.004 * sin(a * 9.0 + y * 17.0) * smoothstep(N - 0.05, C - 0.04, y)
	var tg: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 96, "top": func(_a): return N + 0.004, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return pu, "gain": 6.0, "th": 0.006, "inner": pu.darkened(0.4), "skin": tsk})
	P._bd(k, K._yl(tg["hem"], 0.008), 0.003, 0.0016, pu.darkened(0.18), true, tsk)
	# bol boğaz: boynu saran iki kat rulo
	var q: float = Q._hq(k)
	var ck := [[N + 0.075 * q, nk.x + 0.032, nk.y + 0.032, nk.z - 0.036], [N + 0.035 * q, nk.x + 0.044, nk.y + 0.046, nk.z - 0.046], [N - 0.03, nk.x + 0.05, nk.y + 0.06, nk.z - 0.05]]
	var cw: Dictionary = P._cl(k, {"keys": ck, "ny": 14, "na": 64, "top": func(_a): return N + 0.075 * q, "hem": func(_a): return N - 0.03,
		"fold": func(a, _y, v): return 0.06 * sin(float(v) * PI * 2.0) * (1.0 - 0.4 * float(v)) + 0.012 * sin(float(a) * 6.0 + 0.4) * float(v), "col": func(_a, _y, _v): return pd, "gain": 4.0, "th": 0.006, "inner": pd.darkened(0.35), "skin": nsk})
	P._cord(k, cw["top"], 0.0045, pd.lightened(0.05), true, nsk)
	# göğüste kapaklı cep (sivri kapak) + sağ göğüste 山 damgası
	var mp: Callable = _mp_on(keys, ff, -0.22, C + 0.005)
	var rows := []
	for j in 6:
		var v := float(j) / 5.0
		var ro := []
		for i in 11:
			var u := float(i) / 10.0 * 2.0 - 1.0
			var yv: float = lerpf(0.0, -0.032 - 0.016 * (1.0 - absf(u)), v)
			var e2: float = minf(1.0 - absf(u), minf(v, 1.0 - v) * 2.0)
			ro.append(mp.call(u * 0.06, yv, 0.003 + 0.004 * smoothstep(0.0, 0.25, e2)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(i, j, _p): return pu.darkened(0.25) if i == 0 or i == 10 or j == 5 else pu.lightened(0.04), func(_i, _j, p): return k.torso_skin(p.y), Q._spt(keys, ff, -0.22, C)[1])
	var ms: Callable = _mp_on(keys, ff, 0.42, C - 0.01)
	for st in [[Vector2(-0.012, 0.01), Vector2(-0.012, -0.008), Vector2(0.012, -0.008), Vector2(0.012, 0.01)], [Vector2(0.0, 0.014), Vector2(0.0, -0.008)]]:
		R._lstrip(k, ms, st, 0.0018, 0.004, 0.0013, pd, tsk)
	# karında beyaz sargı: tur tur
	var wy0: float = hem + 0.02
	var wy1: float = H + 0.075
	var wk := [_mk(k, wy0 + 0.02, 0.006, 0.0, b["ch"]), _mk(k, wy1 - 0.02, 0.006, 0.0, b["ch"])]
	SE.body_layer(k, wk, 6, 48, func(_i, _j, _p): return wh.darkened(0.2))
	for i in 5:
		var y: float = lerpf(wy0 - 0.008, wy1 + 0.008, float(i) / 4.0)
		V._belt(k, wk, y, 0.005 * (1.0 if i % 2 == 0 else -1.0), 0.0115, 0.004, wh.darkened(0.04 * float(i % 3)), 0.6 * float(i), 64)
	# beyaz sargılı şort: kalça + uyluk turları
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return wh.darkened(0.06))
	var sh_s := 0.36
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.0 if sd == "Left" else 2.4
		P._lt(k, le, func(s, _a): return 0.009 - 0.005 * smoothstep(sh_s - 0.12, sh_s, float(s)), func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.12), 0.0, sh_s, 16, 22)
		for i in 9:
			var s: float = lerpf(0.03, sh_s - 0.02, float(i) / 8.0)
			k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + 0.009 - 0.005 * smoothstep(sh_s - 0.12, sh_s, s), 0.014, 0.008 * sin(float(i) * 1.7 + sv), wh.darkened(0.05 * float(i % 3)), P._lskin(le, s))
		P._bare(k, le, Q._skc(k), sh_s - 0.04, 1.0)
		if sd == "Right":
			J._holster(k, le, func(s, _a): return 0.016 - 0.006 * smoothstep(sh_s - 0.12, sh_s, float(s)), nv.lightened(0.04), nv)
	# etek: yanları açık ön ve arka panel, diz üstü
	var ehem: float = KN + 0.07
	var hp: Vector3 = b["hp"]
	var ey0: float = H + 0.075
	var wm: Vector3 = k.M(ey0, 0.3)
	var ekeys := [[ey0, wm.x + 0.016, wm.y + 0.016, wm.z - 0.016], [H - 0.04, hp.x + 0.056, hp.y + 0.056, hp.z - 0.052], [ehem, hp.x + 0.076, hp.y + 0.07, hp.z - 0.066]]
	var esk := func(p): return _psk(k, p, ehem)
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - ehem), 0.0, 1.0)
		return t * (0.012 * sin(a * 6.0 + 0.6) + 0.006 * sin(a * 11.0 + 1.3))
	for ctr in [0.0, PI]:
		var hw: float = 1.08 if ctr == 0.0 else 1.12
		var bsk := func(p): return T._ksk(k, p, ehem)   # arka panel: geniş geçiş (geri giden uyluk kalçayı açığa çıkarmaz)
		var psk: Callable = esk if ctr == 0.0 else bsk
		var pg: Dictionary = P._cl(k, {"keys": ekeys, "ny": 26, "na": 50, "rng": func(_v): return Vector2(ctr - hw, ctr + hw), "top": func(_a): return ey0, "hem": func(_a): return ehem,
			"fold": func(a, y, _v): return ef.call(float(a), float(y)), "col": func(_a, _y, _v): return pu, "gain": 6.0, "th": 0.006, "inner": pu.darkened(0.4), "skin": psk})
		for ed in [pg["ea"], pg["eb"]]:
			P._cord(k, ed, 0.003, pu.darkened(0.16), false, psk)
		P._bd(k, K._yl(pg["hem"], 0.009), 0.003, 0.0016, pu.darkened(0.18), false, psk)
	# mavi kemer + Konoha plakası
	var bkey := [[ey0 + 0.02, wm.x + 0.024, wm.y + 0.024, wm.z - 0.024], [ey0 - 0.04, wm.x + 0.028, wm.y + 0.028, wm.z - 0.028]]
	var by: float = ey0 - 0.01
	V._belt(k, bkey, by, 0.0, 0.017, 0.005, bl, 0.0, 96)
	var pe: Array = Q._spt(bkey, Callable(), 0.0, by, 0.013)
	var po: Vector3 = pe[1]
	var hb := [["Hips", 0.5], ["Spine", 0.5]]
	P._boxr(k, pe[0], Vector3(0.05, 0, 0), Vector3(0, 0.02, 0), po * 0.006, mt, hb, 0.3)
	var rgt: Vector3 = Vector3.UP.cross(po).normalized()
	V._m_leaf(k, V._plane((pe[0] as Vector3) + po * 0.006, rgt, Vector3.UP, po), 0.014, 0.0016, 0.0, mt.darkened(0.35), func(_p): return hb)
	for sg in [1.0, -1.0]:
		P._stud(k, (pe[0] as Vector3) + rgt * sg * 0.04 + po * 0.006, po, 0.0026, mt.darkened(0.2), hb)
	P._cur_hem = ehem


# ------------------------------------------------------------------ Sumi Shōzoku (ref Shinobi Striker "Inojin Outfit"): gri iç gömlek (belde görünür), dik yakalı fermuarlı kısa lacivert-mor ceket (kısa kollar,
## omuzlardan geçen kırmızı kayışlar + göğüste metal halka), file uzun kollar, lacivert-mor pantolon, sağ uylukta iki beyaz bantlı kılıf
static func _murekkep(k) -> void:
	var jk := Color(0.19, 0.17, 0.33)
	var gy := Color(0.47, 0.45, 0.54)
	var rd := Color(0.62, 0.16, 0.2)
	var mt := Color(0.72, 0.72, 0.75)
	var nt := Color(0.3, 0.3, 0.34)
	var wh := Color(0.92, 0.92, 0.94)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# gri iç gömlek: belde pantolonun üstüne biner
	var ik: Array = _tk(k, b, H + 0.02, 0.01, 0.2)
	var igf := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + y * 21.0) * smoothstep(C - 0.05, H + 0.06, y) + 0.008 * exp(-pow((y - (H + 0.045)) / 0.03, 2.0))
	P._cl(k, {"keys": ik, "ny": 30, "na": 80, "top": func(_a): return N + 0.01, "hem": func(_a): return H + 0.02, "fold": func(a, y, _v): return igf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.005, "inner": gy.darkened(0.35), "skin": tsk})
	# pantolon
	K._seat(k, b, jk)
	var wbk := [P._kp(k.M(H + 0.05, 0.3), H + 0.05, 0.012), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.014)]
	V._belt(k, wbk, H + 0.022, 0.0, 0.014, 0.004, jk.darkened(0.08), 0.0, 72)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.9 if sd == "Left" else 2.0
		var pa: Callable = K._pant(k, le, jk, 0.018, 0.016, 0.99, sv)
		if sd == "Right":
			J._holster(k, le, pa, wh, jk.darkened(0.35))
	# kollar: file uzun kol (altta ten), bilekte koyu bant
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		_arm_bare(k, ar, 0.3)
		P._lt(k, ar, func(_s, _a): return 0.0018, func(_s, a, ins): return nt.darkened(0.3) if ins else Q._skc(k).lerp(nt, 0.35).darkened(0.06 * absf(sin(float(a) * 2.0))), 0.32, 0.93, 18, 16)
		P._net_limb(k, ar, 0.32, 0.93, 0.0034, 13, 0.02, 0.001, nt)
		P._lt(k, ar, func(s, _a): return 0.0045 + 0.0012 * sin(clampf((float(s) - 0.925) / 0.055, 0.0, 1.0) * PI), func(_s, _a, ins): return jk.darkened(0.3) if ins else jk.darkened(0.2), 0.925, 0.98, 4, 18)
	# kısa ceket: göğüs altında biter, önü fermuarlı
	var hem: float = C - 0.13
	var keys: Array = _tk(k, b, hem, 0.024, 0.5)
	var ff := func(a: float, y: float) -> float:
		return 0.008 * sin(a * 5.0 + 0.3 + y * 6.0) * smoothstep(C, hem, y) + 0.004 * sin(a * 9.0 - y * 15.0)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 26, "na": 96, "top": func(_a): return N + 0.004, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return jk, "gain": 6.0, "th": 0.007, "inner": jk.darkened(0.35), "skin": tsk})
	P._bd(k, K._yl(jg["hem"], 0.011), 0.0055, 0.0022, jk.lightened(0.04), true, tsk)
	# fermuar: dişli şerit + çekme
	var zp := []
	var zo := []
	for i in 40:
		var y: float = lerpf(N + 0.05 * Q._hq(k), hem + 0.004, float(i) / 39.0)
		var e: Array = Q._spt(keys, ff, 0.0, minf(y, N), 0.0035) if y <= N else [Vector3(0, y, float(b["nk"].y) + 0.017), Vector3(0, 0, 1)]
		zp.append(e[0])
		zo.append(e[1])
	k.strip(zp, zo, 0.0035, 0.0018, mt.darkened(0.25), false, nsk)
	var zt: Array = Q._spt(keys, ff, 0.0, C + 0.03, 0.007)
	P._boxr(k, zt[0], Vector3(0.0045, 0, 0), Vector3(0, 0.011, 0), (zt[1] as Vector3) * 0.003, mt, k.torso_skin(C + 0.03), 0.3)
	# dik yaka
	_stand(k, b, 0.05, 0.01, jk)
	# kısa kollar + manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.4 if sd == "Left" else 1.5
		var s1 := 0.4
		var sf := func(s: float, a: float) -> float:
			return 0.022 + 0.01 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) + 0.006 * exp(-pow((s - 0.1) / 0.1, 2.0)) - P._lr(ar, s) * 0.4 * (1.0 - smoothstep(0.0, 0.17, s))   # omuz başında incelir: sivri omuz köşesi yok
		P._lt(k, ar, sf, func(s, a, ins): return jk.darkened(0.4) if ins else P._fs(jk, float(sf.call(float(s), float(a))) - 0.028, 12.0), 0.0, s1 - 0.04, 22, 22, 0.0)
		var cf := func(s: float, a: float) -> float: return float(sf.call(s, a)) + 0.0035
		P._lt(k, ar, cf, func(_s, _a, ins): return jk.darkened(0.4) if ins else jk.lightened(0.04), s1 - 0.045, s1, 4, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.006, jk.darkened(0.3), s1 - 0.1, s1 - 0.004, 5, 22)
	# kırmızı kayışlar: arkadan omzu aşar, göğüste metal halkada biter
	var ch: Vector3 = b["ch"]
	for sg in [1.0, -1.0]:
		var x: float = sg * ch.x * 0.5
		P._over(k, keys, x, C + 0.02, hem + 0.012, 0.0115, 0.006, 0.004, rd)
		var e: Array = P._fp(keys, x, C + 0.012, true, 0.012)
		var c: Vector3 = e[0]
		var o: Vector3 = e[1]
		var rr := []
		for i in 18:
			var th := TAU * i / 18.0
			rr.append(c + Vector3(cos(th) * 0.011, sin(th) * 0.008 - 0.012, 0.0) + o * 0.002)
		P._cord(k, rr, 0.0024, mt, true, tsk)
		P._boxr(k, c + Vector3(0, -0.026, 0) + o * 0.001, Vector3(0.0105, 0, 0), Vector3(0, 0.008, 0), o * 0.003, rd.darkened(0.1), k.torso_skin(c.y), 0.3)
	P._cur_hem = H - 0.1
