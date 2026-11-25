extends RefCounted
## Elle modellenmiş setler, parti w: ss_buz_kimono, ss_buz_kimono2, ss_buhar_zirh, ss_hime_hakama, ss_orman_zirh, ss_orman_zirh_genc. Örnek: set_el.gd içindeki _shugonin.
## Kumaş yardımcıları parti e (P), q (Q), k (K), t (T); uzuv / zırh plakası parti l (L); sarmal kimono + geniş kol parti m (M).
## Burada: kabartma çizgili hakama paçası, yüzey üstü girdap, tırtıklı omuz kepi, sırt parşömeni, önlük plakaları ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const T = preload("res://scripts/actors/set_el_t.gd")

const DONE := ["ss_buz_kimono", "ss_buz_kimono2", "ss_buhar_zirh", "ss_hime_hakama", "ss_orman_zirh", "ss_orman_zirh_genc"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_buz_kimono": _haku(k, false)
		"ss_buz_kimono2": _haku(k, true)
		"ss_buhar_zirh": _han(k)
		"ss_hime_hakama": _hanabi(k)
		"ss_orman_zirh": _hashirama(k)
		"ss_orman_zirh_genc": _hashi_genc(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Uzuv yüzeyinde nokta (L uzvu: omuz eklemi gövdeyle gider): [konum, dış yön]
static func _lsp(l: Dictionary, s: float, a: float, lift: float) -> Array:
	var d: Vector3 = L._ld(l, s)
	var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri: Vector3 = (-d).cross(fw).normalized()
	var o: Vector3 = ri * sin(a) + fw * cos(a)
	return [L._lp(l, s) + o * (L._lr(l, s) + lift), o]


## İki kemik listesini karıştırır (t=0 a, t=1 b)
static func _mix(a: Array, b: Array, t: float) -> Array:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var d := {}
	for e in a:
		d[e[0]] = float(d.get(e[0], 0.0)) + float(e[1]) * (1.0 - t)
	for e in b:
		d[e[0]] = float(d.get(e[0], 0.0)) + float(e[1]) * t
	var o := []
	for key in d:
		o.append([key, d[key]])
	return o


## Bileğe inen geniş etek (andon hakama): dize kadar uyluğu tam izler; dizaltında kendi yanındaki baldıra geçer (kalkan bacağın baldırı
## önden delmez, kumaş tahta gibi ileri uzanmaz), iki bacak arasında geniş geçiş (ortadan bölünmez), uçta ağırlık biraz düşer
static func _long_hk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - k.K), 0.0, 1.0)
	var w: float = 0.98 * pow(t, 0.5) * lerpf(1.0, 0.88, smoothstep(k.K - 0.1, hem, p.y))
	var bk: float = smoothstep(0.03, -0.07, p.z)
	w = lerpf(w, 0.995, bk * smoothstep(k.K + 0.02, k.K - 0.12, p.y))   # arka diz altı: kalçada kalan pay baldırı kumaştan çıkarır
	var hw: float = lerpf(0.055, 0.11, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var ws: float = maxf(s, 1.0 - s)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	# arka: baldır dizin hemen altından izlenir (geri kalkan baldır arka eteği delmez); ön: yalnız aşağıda, az (diz önü uyluğa bağlı kalır, kumaş katlanıp delik açmaz)
	var kb_b: float = smoothstep(k.K + 0.07, k.K - 0.13, p.y) * 0.97
	var kb_f: float = smoothstep(k.K - 0.14, k.K - 0.42, p.y) * 0.4
	var kb: float = lerpf(kb_f, kb_b, bk) * smoothstep(0.0, 0.6, absf(2.0 * s - 1.0))
	return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]


## Diz altına inen sarmal yukata: iki kanat aynı noktada aynı ağırlık (bindirme ayrılmaz). Ön: uyluğu çabuk ve tam izler, iki bacak arasında geniş geçiş
## (öne çıkan uyluk kumaşı delip açığa çıkmaz); arka: ağırlık boy boyunca yavaş artar, diz altında baldırı izler (geri giden bacak arka eteği ezmez, delmez)
static func _yk_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.04, -0.07, p.z)
	var wf: float = 0.99 * pow(minf(1.0, t / 0.38), 0.38)
	var wb: float = lerpf(0.84 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), 0.93, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.12, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	# diz altı: arkada baldırı izler; önde yarı yarıya inen baldırı izler (kalkan dizin önünde kumaş dizin üstünden aşağı sarkar, diz kumaşı delip açığa çıkmaz)
	var kb: float = smoothstep(k.K + 0.05, k.K - 0.08, p.y) * lerpf(0.5, 0.85, bk) * smoothstep(0.0, 0.6, absf(2.0 * s - 1.0))
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Satır başına kemik listesi alan kabartma şerit (bol paçada her nokta altındaki kumaşın ağırlığını alır)
static func _ridge(k, pts: Array, outs: Array, skins: Array, hw: float, d: float, col: Color) -> void:
	var n: int = pts.size()
	var rows := []
	for i in n:
		var a: Vector3 = pts[maxi(0, i - 1)]
		var b: Vector3 = pts[mini(n - 1, i + 1)]
		var o: Vector3 = outs[i]
		var w: Vector3 = (b - a).normalized().cross(o).normalized() * hw
		var p: Vector3 = pts[i]
		rows.append([p + w - o * 0.002, p + w * 0.8 + o * d, p - w * 0.8 + o * d, p - w - o * 0.002])
	var t0: Vector3 = rows[0][1]
	var fn: Vector3 = -((rows[0][2] as Vector3) - t0).cross((rows[1][2] as Vector3) - t0)
	if fn.dot(outs[0]) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(_i, _j, _p): return col, func(_i, j, _p): return skins[j])


## Uzuv boyunca kabartma çizgi (s0..s1, a açısı). addf(s, a) altındaki kumaşın kabarması
static func _lstripe(k, l: Dictionary, s0: float, s1: float, a: float, addf: Callable, hw: float, col: Color, n := 10) -> void:
	var pts := []
	var ou := []
	var sk := []
	for j in n + 1:
		var s: float = lerpf(s0, s1, float(j) / n)
		var e: Array = _lsp(l, s, a, float(addf.call(s, a)) + 0.0008)
		pts.append(e[0])
		ou.append(e[1])
		sk.append(L._lskin(l, s))
	_ridge(k, pts, ou, sk, hw, 0.0014, col)


## Hakama paçası (parti l'nin geniş paçası): gerçek pli + pli sırtlarında kabartma çizgi. o: prof(s), s1, pl, amp, top, col, seg, n, cmax, pad, stripe (Color), sn (çizgi sayısı)
static func _hleg(k, b: Dictionary, l: Dictionary, o: Dictionary) -> void:
	var sg: float = l["sg"]
	var kn: float = l["kn"]
	var hp: Vector3 = b["hp"]
	var wa: Vector3 = b["wa"]
	var H: float = k.H
	var s1: float = o.get("s1", 1.0)
	var top: float = H + float(o.get("top", 0.1))
	var prof: Callable = o["prof"]
	var pl: float = o.get("pl", 9.0)
	var amp: float = o.get("amp", 0.05)
	var col: Color = o["col"]
	var seg: int = o.get("seg", 54)
	var n: int = o.get("n", 34)
	var pad: float = o.get("pad", 0.016)
	var cmax: float = o.get("cmax", 0.72)
	var p0: Vector3 = l["p0"]
	var st := []
	for j in 5:
		st.append([lerpf(top, p0.y, float(j) / 5.0), 0.0, 0.0])
	for j in n + 1:
		st.append([0.0, s1 * float(j) / n, 0.0])
	st.append([0.0, s1, -0.005])
	for j in 3:
		st.append([0.0, s1 - 0.05 * float(j), -0.01])
	var ni: int = n + 6
	var rows := []
	var cc := []
	var sk := []
	var cen := []
	var tx: float = hp.x * 0.56 + pad
	var cx0: float = sg * (hp.x * 0.44 + pad * 0.3)
	var zf: float = hp.y + pad
	var zb: float = absf(hp.z) + pad + 0.015
	var bo: Array = l["bo"]
	for ji in st.size():
		var e: Array = st[ji]
		var s: float = e[1]
		var base: Vector3 = L._lp(l, s) if float(e[0]) == 0.0 else Vector3(p0.x, e[0], p0.z)
		var tl: float = smoothstep(0.0, 0.32, s) if float(e[0]) == 0.0 else 0.0
		var R: float = L._lr(l, s) + float(prof.call(s)) + float(e[2])
		var wt: float = 1.0 - smoothstep(H - 0.04, top - 0.01, base.y) if float(e[0]) != 0.0 else 1.0
		var tx2: float = lerpf(wa.x * 0.56 + pad, tx, wt)
		var cx2: float = lerpf(sg * (wa.x * 0.44 + pad * 0.3), cx0, wt)
		var c3 := Vector3(lerpf(cx2, base.x, tl), base.y, lerpf(0.0, base.z, tl))
		var rx: float = lerpf(tx2, R, tl)
		var rf: float = lerpf(lerpf(wa.y + pad, zf, wt), R, tl)
		var rb: float = lerpf(lerpf(absf(wa.z) + pad, zb, wt), R * 1.06, tl)
		var ampv: float = amp * lerpf(0.3, 1.0, smoothstep(0.0, 0.5, s))
		var ro := []
		var cr := []
		var sr := []
		var w: float = smoothstep(0.02, 0.26, s) if float(e[0]) == 0.0 else 0.0
		var c: float = smoothstep(kn - 0.05, kn + 0.3, s) * cmax
		for i in seg:
			var a: float = TAU * i / seg - PI
			var inn: float = smoothstep(0.0, 0.6, -sg * sin(a)) * (1.0 - smoothstep(0.22, 0.55, s))
			var w2: float = w * (1.0 - 0.7 * inn)
			sr.append([["Hips", 1.0 - w2], [bo[0], w2 * (1.0 - c)], [bo[1], w2 * c]])
			var saw: float = fposmod(a * pl / TAU + 0.15, 1.0)
			var f: float = ampv * (smoothstep(0.0, 0.16, saw) - smoothstep(0.16, 1.0, saw) - 0.2)
			var q: Vector2 = SE.El.sup(a, rx, rf, -rb, 2.2)
			ro.append(c3 + Vector3(q.x * (1.0 + f), 0.0, q.y * (1.0 + f)))
			var c0: Color = col.darkened(clampf(-f / amp * 0.3, 0.0, 0.3)).lightened(clampf(f / amp * 0.08, 0.0, 0.08))
			cr.append(c0.darkened(0.42) if ji > ni - 1 else c0)
		rows.append(ro)
		cc.append(cr)
		sk.append(sr)
		cen.append(c3)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(i, j, _p): return sk[j][i])
	if not o.has("stripe"):
		return
	# pli sırtında ve yüzünde ince açık çizgiler (kabartma): her nokta paçanın kendi ağırlığını alır
	var sn: int = o.get("sn", 10)
	var scol: Color = o["stripe"]
	for m in sn:
		var i: int = int(round(float(m) / sn * seg + seg * 0.02)) % seg
		var pts := []
		var ou := []
		var ks := []
		for j in range(3, ni):
			var p: Vector3 = rows[j][i]
			var c4: Vector3 = cen[j]
			var oo := Vector3(p.x - c4.x, 0.0, p.z - c4.z).normalized()
			pts.append(p + oo * 0.0012)
			ou.append(oo)
			ks.append(sk[j][i])
		_ridge(k, pts, ou, ks, 0.0019, 0.0014, scol)


## Kimono yüzeyinde girdap (kabartma): kalın açık halka kolu + merkez nokta. mp: yüzey eşlemesi
static func _swirl(k, keys: Array, ff: Callable, a0: float, y0: float, r: float, rot: float, col: Color, skinf: Callable) -> void:
	var mp: Callable = Q._local(keys, ff, a0, y0)
	var out: Vector3 = Q._spt(keys, ff, a0, y0)[1]
	var lift := 0.0045
	var pts := []
	var ou := []
	var n := 18
	for i in n + 1:
		var t: float = float(i) / n
		var th: float = rot + t * TAU * 0.8
		var rr: float = r * lerpf(0.86, 0.6, t)
		var p: Vector3 = mp.call(cos(th) * rr, sin(th) * rr, lift)
		var p0: Vector3 = mp.call(cos(th) * rr, sin(th) * rr, lift - 0.01)
		pts.append(p)
		ou.append((p - p0).normalized())
	var rows := []
	for i in pts.size():
		var t: float = float(i) / n
		var hw: float = r * lerpf(0.2, 0.13, t)
		var a: Vector3 = pts[maxi(0, i - 1)]
		var b2: Vector3 = pts[mini(n, i + 1)]
		var o: Vector3 = ou[i]
		var w: Vector3 = (b2 - a).normalized().cross(o).normalized() * hw
		var p: Vector3 = pts[i]
		rows.append([p + w - o * 0.003, p + w * 0.8 + o * 0.0016, p - w * 0.8 + o * 0.0016, p - w - o * 0.003])
	Q._mesh(k, rows, false, func(_i, _j, _p): return col, func(_i, _j, p): return skinf.call(p), out)
	Q._disc(k, func(u, v, l): return mp.call(float(u) + r * 0.08, float(v) - r * 0.05, float(l)), out, r * 0.26, lift - 0.001, Callable(), func(_u, _v): return col, skinf, 3, 14)


# ------------------------------------------------------------------ Hyōsetsu Kimono / Yukata (ref Shinobi Striker "Haku Outfit" ve "Haku Outfit First Encounter Vers."): sol kanat üstte kısa sarmal kimono
## Kimono: çizgili koyu dik yakalı tulum, beyaz yaka bandı kimono ucuna iner, dirsek üstünde biten kol + geniş beyaz kol ağzı, iki katlı kahve obi, çizgili diz altı hakama, beyaz tabi.
## Yukata: diz altına inen pembe kolsuz kimono, boyundan etek ucuna inen kırmızı bant, mor girdaplar, geniş beyaz obi, boyunda gerdanlık, çıplak kol ve baldır, beyaz tabi.
static func _haku(k, v2: bool) -> void:
	var b: Dictionary = P._base(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	var wt := Color(0.93, 0.92, 0.89)
	var kc: Color = Color(0.95, 0.87, 0.88) if v2 else Color(0.13, 0.19, 0.44)
	var band: Color = Color(0.82, 0.34, 0.36) if v2 else wt
	var obi: Color = Color(0.88, 0.89, 0.85) if v2 else Color(0.42, 0.27, 0.16)
	var jp := Color(0.21, 0.19, 0.18)
	var js: Color = jp.lightened(0.32)
	var hk := Color(0.22, 0.2, 0.19)
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	# iç: tulum (çizgili) ya da yaka altında ten
	if v2:
		M._inner_v(k, b, kc.darkened(0.06))
	else:
		var ik: Array = P._inner(k, b, func(_i, _j, _p): return jp, 0.006)
		for i in 9:
			var a: float = lerpf(-0.5, 0.5, float(i) / 8.0)
			Q._run(k, ik, Callable(), [Vector2(a, N + 0.03), Vector2(a, C - 0.15)], 0.0016, 0.0025, 0.0012, js, tsk, 4)
		# dik yaka: boynu saran çizgili tulum yakası, üst köşelerinde açık renk sekme
		var ck := [P._kp(nk, N + 0.085 * q, 0.012, 0.016), P._kp(nk, N + 0.03 * q, 0.016), P._kp(nk, N - 0.03, 0.03), P._kp(nk, N - 0.06, 0.046, 0.042)]
		var cf := func(a, y, _v): return 0.006 * sin(float(a) * 5.0 + float(y) * 20.0)
		P._cl(k, {"keys": ck, "ny": 9, "na": 48, "top": func(_a): return N + 0.08 * q, "hem": func(_a): return N - 0.055, "fold": cf,
			"col": func(_a, _y, _v): return jp, "skin": nsk, "th": 0.006})
		var cff := func(a, y): return cf.call(a, y, 0.0)
		for i in 16:
			var a: float = -PI + TAU * (float(i) + 0.5) / 16.0
			Q._run(k, ck, cff, [Vector2(a, N + 0.075 * q), Vector2(a, N - 0.045)], 0.0015, 0.0012, 0.0011, js, nsk, 3)
		for sg in [1.0, -1.0]:
			var e: Array = Q._spt(ck, cff, sg * 0.55, N + 0.065 * q, 0.004)
			P._boxr(k, e[0], Vector3(0.008, 0, 0).rotated(Vector3.UP, sg * 0.55), Vector3(0, 0.011, 0), (e[1] as Vector3) * 0.003, Color(0.82, 0.74, 0.62), [["Neck", 0.6], ["UpperChest", 0.4]], 0.3)
		L._seat(k, b, hk.darkened(0.2))
	# kollar
	for lk in ["Left", "Right"]:
		var ar: Dictionary = L._limb(k, lk, false)
		var le: Dictionary = L._limb(k, lk, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sj: float = ar["sj"]
		var sv: float = 1.2 if lk == "Left" else 2.6
		if v2:
			L._lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, 0.0, 0.985, 28, 16)
			# omuz kepi: kimononun omuzdan taşan kısa ağzı, içi lila
			var cap := func(s: float, a: float) -> float: return 0.014 + 0.01 * smoothstep(0.0, sj + 0.07, s) + 0.003 * sin(a * 3.0 + sv)
			L._lt(k, ar, cap, func(_s, a, ins): return Color(0.78, 0.66, 0.84) if ins else P._fs(kc, 0.003 * sin(float(a) * 3.0 + sv), 9.0), 0.0, sj + 0.075, 8, 22, 0.04)
		else:
			var jl := func(s: float, a: float) -> float:
				return 0.008 + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.006 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) - 0.004 * smoothstep(0.9, 0.98, s)
			L._lt(k, ar, jl, func(s, a, ins): return jp.darkened(0.3) if ins else P._fs(jp, float(jl.call(float(s), float(a))) - 0.008, 14.0), 0.0, 0.975, 34, 20)
			for i in 8:
				_lstripe(k, ar, 0.36, 0.95, -PI + TAU * (float(i) + 0.25) / 8.0, jl, 0.0015, js, 12)
			# kısa kimono kolu: dirsek üstünde biter, geniş beyaz ağız katlanır
			var s1: float = en - 0.1
			var sl := func(s: float, a: float) -> float:
				return 0.026 + 0.03 * smoothstep(0.0, 0.3, s) + 0.005 * P._lf(s, a, sv)
			L._lt(k, ar, sl, func(s, a, ins): return kc.darkened(0.3) if ins else P._fs(kc, 0.005 * P._lf(float(s), float(a), sv), 10.0), 0.0, s1 - 0.06, 24, 24, 0.05)
			var cu := func(s: float, a: float) -> float: return float(sl.call(s, a)) + 0.004 + 0.003 * sin(clampf((s - s1 + 0.075) / 0.075, 0.0, 1.0) * PI)
			L._lt(k, ar, cu, func(s, _a, ins): return wt.darkened(0.25) if ins else (wt.darkened(0.12) if float(s) > s1 - 0.01 else wt), s1 - 0.075, s1, 8, 24, 0.05)
			var ao: float = PI * 0.5 * float(ar["sg"]) - 0.3 * float(ar["sg"])
			var et: Array = _lsp(ar, s1 - 0.04, ao, float(cu.call(s1 - 0.04, ao)) + 0.003)
			P._boxr(k, et[0], (L._ld(ar, s1) as Vector3) * 0.012, (et[1] as Vector3).cross(L._ld(ar, s1)).normalized() * 0.008, (et[1] as Vector3) * 0.0025, Color(0.84, 0.78, 0.7), L._lskin(ar, s1 - 0.04), 0.3)
		# bacak: üstte tulum / şort, altta ten ve beyaz tabi
		L._lt(k, le, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, kn - 0.05, 0.99, 22, 16)
		if v2:
			L._lt(k, le, func(s, a): return 0.007 + 0.002 * P._lf(s, a, sv), func(_s, _a, ins): return kc.darkened(0.35) if ins else kc.darkened(0.05), 0.0, 0.22, 10, 18, 0.02)
		else:
			L._lt(k, le, func(s, a): return 0.01 + 0.003 * P._lf(s, a, sv), func(_s, _a, ins): return jp.darkened(0.35) if ins else jp, 0.0, kn + 0.06, 22, 18, 0.02)
		var so := func(s: float, _a: float) -> float: return 0.0045 + 0.003 * (1.0 - smoothstep(kn + 0.24, kn + 0.28, s))
		L._lt(k, le, so, func(s, a, ins): return wt.darkened(0.3) if ins else wt.darkened(0.06 if sin(float(a) * 4.0 + float(s) * 9.0) < -0.6 else 0.0), kn + 0.22, 0.99, 14, 18, 0.02)
		if not v2:
			# hakama paçası: diz altına iner, pli sırtlarında açık çizgi
			_hleg(k, b, le, {"col": hk, "stripe": hk.lightened(0.42), "sn": 12, "prof": func(s): return 0.012 + 0.045 * smoothstep(0.12, kn, s) + 0.012 * smoothstep(kn, kn + 0.18, s), "pl": 5.0, "amp": 0.03,
				"s1": kn + 0.17, "top": 0.0, "seg": 44, "n": 30, "cmax": 0.8, "pad": 0.01})
	# kimono gövdesi: sol kanat sağın üstüne biner; yaka bandı etek ucuna iner
	var hem: float = (KN - 0.055) if v2 else (H - 0.2)
	var keys: Array
	if v2:
		keys = [P._kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.042),
			[KN + 0.1, hp.x + 0.07, hp.y + 0.095, hp.z - 0.09], [hem, hp.x + 0.095, hp.y + 0.1, hp.z - 0.105]]   # diz önünde kumaş payı
	else:
		keys = [P._kp(nk, N + 0.0, 0.034), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.026), P._kp(hp, H - 0.04, 0.05), [hem, hp.x + 0.085, hp.y + 0.075, hp.z - 0.085]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		var blouse: float = 0.016 * exp(-pow((y - (H + 0.16)) / 0.035, 2.0))
		return t * (0.02 * sin(a * 5.0 + 0.4) + 0.01 * sin(a * 9.0 + 1.7)) + (1.0 - up) * 0.006 * sin(a * 7.0 + y * 10.0) * smoothstep(0.0, 0.1, up) + blouse
	var ysk := func(p): return _yk_skin(k, p, hem)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, v): return kc.darkened(0.1 * smoothstep(0.96, 1.0, float(v))), "fold": fold, "band": band, "band_w": 0.016 if v2 else 0.021,
		"ny": 64 if v2 else 44, "na": 60, "gain": 4.5, "inner": kc.darkened(0.3), "low": -0.95 if v2 else -0.5, "skin_fn": ysk if v2 else Callable()})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		P._bd(k, M._yl(g["hem"], 0.008), 0.0055, 0.002, kc.darkened(0.12), false, func(p): return _yk_skin(k, p, hem) if v2 else M._wrap_skin(k, p, hem, lf))
	var ff := func(a, y): return fold.call(float(a), float(y), 0.0)
	# obi: kalın katlı kuşak
	if v2:
		var ok := [P._kp(wa, H + 0.17, 0.038), P._kp(wa, H + 0.02, 0.05)]
		L._sash(k, ok, H + 0.1, 0.05, 0.0, obi, 0.08, 1)
		var bq: Array = P._sa(ok, PI, H + 0.1, 0.03)
		var c0: Vector3 = bq[0]
		var hip: Array = [["Hips", 0.4], ["Spine", 0.6]]
		P._boxr(k, c0 + Vector3(0, 0.004, -0.008), Vector3(0.085, 0, 0), Vector3(0, 0.052, 0), Vector3(0, 0, -0.022), obi.darkened(0.04), hip, 0.3)
		P._boxr(k, c0 + Vector3(0, 0.0, -0.028), Vector3(0.03, 0, 0), Vector3(0, 0.06, 0), Vector3(0, 0, -0.012), obi.lightened(0.03), hip, 0.3)
		# gerdanlık
		var cy: float = N + 0.035 * q
		var nm: Vector3 = k.M(cy, 0.09)
		var cp := []
		for i in 32:
			var a: float = TAU * i / 32.0 - PI
			var s2: Vector2 = SE.El.sup(a, nm.x + 0.006, nm.y + 0.006, nm.z - 0.006, 2.0)
			cp.append(Vector3(s2.x, cy, s2.y))
		P._cord(k, cp, 0.0075, Color(0.16, 0.13, 0.16), true, func(_p): return [["Neck", 1.0]], 0.0, 8)
		# girdaplar: ön ve arka, etek ucunda yarım kalanlar dahil kumaşa oturur
		var sw := Color(0.3, 0.16, 0.36)
		var spots := [[-0.85, N - 0.11], [0.9, N - 0.1], [-0.35, C - 0.07], [0.62, C - 0.14], [0.22, H - 0.03], [0.95, H - 0.04], [-0.6, H - 0.06], [-1.2, H - 0.1],
			[1.3, H - 0.16], [-0.85, H - 0.2], [0.42, H - 0.22], [-0.25, H - 0.32], [1.0, H - 0.34], [-1.0, H - 0.4], [0.2, hem + 0.06], [-0.6, hem + 0.05], [0.75, hem + 0.06],
			[PI - 0.3, N - 0.1], [-PI + 0.6, C - 0.08], [PI - 0.9, C - 0.16], [PI, H - 0.08], [PI - 0.6, H - 0.24], [-PI + 0.3, H - 0.3], [-PI + 1.0, H - 0.15], [PI - 1.4, H - 0.38], [PI - 0.15, hem + 0.06], [-PI + 0.8, hem + 0.06], [1.5, C - 0.05], [-1.55, C - 0.12]]
		for i in spots.size():
			var e: Array = spots[i]
			var a: float = e[0]
			var y: float = e[1]
			if y < H + 0.17 and y > H + 0.02:
				continue
			_swirl(k, keys, ff, a, y, 0.029, float(i) * 1.7, sw, ysk)
	else:
		var ok := [P._kp(wa, H + 0.15, 0.046), P._kp(wa, H + 0.0, 0.058)]
		L._sash(k, ok, H + 0.075, 0.046, 0.0, obi, 0.16, 2)
		P._cord(k, P._ring_pts(ok, H + 0.074, 0.008, 72), 0.004, obi.darkened(0.22), true, tsk, 0.0, 6)


## Uzvun omzunu saran kısa kep: alt kenarı açıya göre (tırtıklı yırtık kenar). s1f(a) -> alt kenar
static func _lcap(k, l: Dictionary, s1f: Callable, addf: Callable, col: Color, inner: Color, n := 8, seg := 30) -> void:
	var rows := []
	var ss := []
	var cc := []
	for side in 2:
		for j in n + 1:
			var v: float = float(j) / n if side == 0 else 1.0 - float(j) / n
			var ro := []
			var sr := []
			var cr := []
			for i in seg:
				var a: float = TAU * i / seg - PI
				var s: float = lerpf(0.0, float(s1f.call(a)), v)
				var ad: float = float(addf.call(s, a)) - (0.0045 if side == 1 else 0.0)
				ro.append(_lsp(l, s, a, ad)[0])
				sr.append(s)
				cr.append(inner if side == 1 else P._fs(col, 0.004 * sin(a * 7.0 + s * 20.0), 8.0).darkened(0.12 * smoothstep(0.85, 1.0, v)))
			rows.append(ro)
			ss.append(sr)
			cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(i, j, _p): return L._lskin(l, ss[j][i]))


# ------------------------------------------------------------------ Jōki Yoroi (ref Shinobi Striker "Han Outfit"): diz boyu kırmızı balıkçı yaka örgü tunik (yatay örgülü etek), üstünde omuzları yırtık
## kolsuz gri sarmal gi yelek + siyah yaka bandı, siyah ince kuşak, kahve boyun kayışı, kaburgalı kırmızı kollar, siyah eldiven, bol gri pantolon + koyu baldır sargısı
static func _han(k) -> void:
	var b: Dictionary = P._base(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var rd := Color(0.55, 0.12, 0.2)
	var gy := Color(0.45, 0.45, 0.48)
	var bk := Color(0.11, 0.11, 0.14)
	var br := Color(0.42, 0.29, 0.19)
	var pn := Color(0.4, 0.4, 0.43)
	var wr := Color(0.17, 0.17, 0.21)
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	# örgü kazak gövdesi: dikey kaburga (gerçek kabartma)
	var rib := func(a: float, f: float) -> float: return 0.5 + 0.5 * cos(a * f)
	var ik := [P._kp(nk, N + 0.06, 0.008, 0.01), P._kp(nk, N + 0.02, 0.016), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.01), P._kp(wa, H + 0.12, 0.01), P._kp(hp, H - 0.09, 0.012)]
	SE.body_layer(k, ik, 22, 96, func(_i, _j, p): return rd.darkened(0.28 * (1.0 - float(rib.call(atan2(p.x, p.z), 30.0)))), func(a, _y): return 0.016 * float(rib.call(a, 30.0)))
	# balıkçı yaka: boynu saran örgü, dibinde perçinli kahve kayış
	var ck := [P._kp(nk, N + 0.085 * q, 0.012, 0.016), P._kp(nk, N + 0.03 * q, 0.017), P._kp(nk, N - 0.03, 0.03), P._kp(nk, N - 0.06, 0.046, 0.042)]
	var cf := func(a, _y, _v): return 0.035 * float(rib.call(float(a), 20.0))
	P._cl(k, {"keys": ck, "ny": 9, "na": 80, "top": func(_a): return N + 0.08 * q, "hem": func(_a): return N - 0.055, "fold": cf,
		"col": func(_a, _y, _v): return rd, "gain": 5.0, "skin": nsk, "th": 0.006})
	var sy: float = N + 0.012
	var sp := []
	var so := []
	for i in 48:
		var a: float = TAU * i / 48.0 - PI
		var e: Array = Q._spt(ck, func(aa, yy): return cf.call(aa, yy, 0.0), a, sy, 0.004)
		sp.append(e[0])
		so.append(e[1])
	k.strip(sp, so, 0.012, 0.004, br, true, nsk)
	for a in [-0.5, -0.17, 0.17, 0.5]:
		var e2: Array = Q._spt(ck, func(aa, yy): return cf.call(aa, yy, 0.0), float(a), sy, 0.009)
		P._stud(k, e2[0], e2[1], 0.0045, Color(0.7, 0.68, 0.62), [["Neck", 0.5], ["UpperChest", 0.5]])
	# kollar: kaburgalı kırmızı kol, siyah eldiven; omuzda yeleğin yırtık kepi
	for lk in ["Left", "Right"]:
		var ar: Dictionary = L._limb(k, lk, false)
		var le: Dictionary = L._limb(k, lk, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sj: float = ar["sj"]
		var sv: float = 1.4 if lk == "Left" else 2.7
		var ra := func(s: float, a: float) -> float:
			return 0.012 + 0.004 * sin(clampf(s, 0.0, 1.0) * PI) + 0.009 * pow(absf(sin(s * PI * 15.0)), 0.6) * (1.0 - smoothstep(0.7, 0.76, s)) + 0.002 * sin(a * 3.0 + sv)
		L._lt(k, ar, ra, func(s, _a, ins): return rd.darkened(0.35) if ins else rd.darkened(0.3 * (1.0 - pow(absf(sin(float(s) * PI * 15.0)), 0.6))), 0.0, 0.78, 56, 20)
		var gl := func(s: float, _a: float) -> float: return 0.012 + 0.012 * smoothstep(0.78, 0.7, s) - 0.003 * smoothstep(0.9, 0.98, s)
		L._lt(k, ar, gl, func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.06 if sin(float(a) * 4.0 + float(s) * 12.0) > 0.7 else 0.0), 0.69, 0.985, 16, 20, 0.04)
		K._glove(k, lk, ar, bk, bk.lightened(0.12))
		var jag := func(a: float) -> float: return sj + 0.075 + 0.028 * Q._tri(a * 5.0 + sv) + 0.012 * sin(a * 11.0 + sv * 2.0)
		_lcap(k, ar, jag, func(s, a): return float(ra.call(s, a)) + 0.012 + 0.006 * smoothstep(0.0, sj + 0.05, s), gy, gy.darkened(0.35))
		# bol gri pantolon, dizaltında toplanır; koyu sargı + iki kahve kayış
		var tk: float = kn + 0.15
		Q._baggy(k, le, pn, wr, 0.012, 0.024, tk, sv)
		L._wraps(k, le, tk + 0.01, 0.935, 9, 0.009, 0.0125, wr, 0.008)
		for s in [tk + 0.045, 0.87]:
			k.wrap_turn(L._lp(le, s), L._ld(le, s), L._lr(le, s) + 0.017, 0.0085, 0.006, br, L._lskin(le, s))
	# kırmızı tunik eteği: yeleğin altından dize, yatay örgü, ön / yan panel dikişleri
	var hem2: float = KN + 0.01
	var sk := [P._kp(wa, H + 0.05, 0.02), [H - 0.04, hp.x + 0.034, hp.y + 0.034, hp.z - 0.05], [KN + 0.12, hp.x + 0.08, hp.y + 0.07, hp.z - 0.085], [hem2, hp.x + 0.09, hp.y + 0.075, hp.z - 0.09]]
	var sf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem2), 0.0, 1.0)
		var rr: float = 0.012 * pow(absf(sin((H - y) * PI / 0.021)), 0.7) * smoothstep(0.12, 0.3, t)
		return t * t * (0.02 * sin(a * 6.0 + 0.7) + 0.01 * sin(a * 11.0 + 2.0)) + rr
	var ssk := func(p): return _mix(M._wrap_skin(k, p, H - 0.12, true), M._wrap_skin(k, p, hem2, true), smoothstep(H - 0.1, H - 0.18, float(p.y)))
	P._cl(k, {"keys": sk, "ny": 62, "na": 60, "top": func(_a): return H + 0.05, "hem": func(_a): return hem2, "fold": func(a, y, _v): return sf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 9.0, "th": 0.006, "inner": rd.darkened(0.45), "skin": ssk})
	var sff := func(a, y): return sf.call(float(a), float(y))
	for a in [0.72, -0.72, 2.3, -2.3]:
		Q._run(k, sk, sff, [Vector2(float(a), H - 0.12), Vector2(float(a), hem2 + 0.006)], 0.003, 0.0035, 0.0018, rd.darkened(0.32), ssk, 10)
	# gri yelek: sarmal gi, sol kanat üstte, siyah yaka bandı yelek ucuna iner
	var hem: float = H - 0.12
	var keys := [P._kp(nk, N + 0.0, 0.036), [N - 0.055, ch.x * 1.02, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.04, 0.062), [hem, hp.x + 0.085, hp.y + 0.078, hp.z - 0.095]]
	var vf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.06 - y) / (H + 0.06 - hem), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return t * (0.016 * sin(a * 5.0 + 0.9) + 0.008 * sin(a * 9.0 + 0.3)) + (1.0 - up) * 0.01 * sin(a * 6.0 + y * 12.0) * smoothstep(0.0, 0.2, up) + up * 0.006 * sin(a * 4.0 - y * 20.0)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, v): return gy.darkened(0.1 * smoothstep(0.95, 1.0, float(v))), "fold": vf, "band": bk, "band_w": 0.022, "ny": 46, "na": 64, "gain": 5.0, "inner": gy.darkened(0.35), "low": -0.12})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		P._bd(k, M._yl(g["hem"], 0.007), 0.005, 0.002, gy.darkened(0.15), false, func(p): return M._wrap_skin(k, p, hem, lf))
	# siyah ince kuşak
	var ok := [P._kp(wa, H + 0.13, 0.05), P._kp(wa, H - 0.02, 0.062)]
	L._sash(k, ok, H + 0.05, 0.02, 0.0, bk, 0.22, 1)


# ------------------------------------------------------------------ Hime Hakama (ref Shinobi Striker "Hanabi Outfit"): iki tonlu turuncu kimono (çok geniş, uzun kollu; içi koyu turuncu), yakada turuncu-krem-turuncu
## şeritler, göğüs altından bileğe inen geniş kırmızı hakama, iki kat kırmızı bel bağı + önde soluk sarı kuşak ve fiyonk, arkada koshi-ita
static func _hanabi(k) -> void:
	var b: Dictionary = P._base(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var yo := Color(0.96, 0.69, 0.27)
	var og := Color(0.9, 0.46, 0.19)
	var cr := Color(0.98, 0.93, 0.76)
	var rd := Color(0.73, 0.17, 0.2)
	var bw := Color(0.97, 0.94, 0.8)
	var skc: Color = Q._skc(k)
	M._inner_v(k, b, cr)
	for lk in ["Left", "Right"]:
		var ar: Dictionary = L._limb(k, lk, false)
		var le: Dictionary = L._limb(k, lk, true)
		var en: float = ar["kn"]
		var sv: float = 1.1 if lk == "Left" else 2.9
		L._lt(k, le, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, 0.0, 0.99, 30, 16)
		L._lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, en * 0.6, 0.975, 16, 14)
		# çok geniş kol: bileğe iner, alt yanı torba gibi sarkar; içi koyu turuncu astar
		M._wide(k, ar, func(s: float) -> float: return 0.052 + 0.026 * smoothstep(0.05, 0.5, s), func(s: float) -> float: return 0.025 + 0.035 * smoothstep(0.3, 0.9, s),
			func(s: float, a: float) -> float: return 0.03 * sin(a * 3.0 + s * 6.0 + sv), func(s: float, a: float, ins: bool) -> Color:
				if ins:
					return og.darkened(0.12)
				return P._fs(yo, 0.012 * sin(a * 3.0 + s * 6.0 + sv), 7.0), 0.93, 0.3, L._lr(ar, 0.93) + 0.05, 30, 44)
	# kimono üstü: hakamanın içine girer
	var hm0: float = H - 0.02
	var keys := [P._kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 0.99, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.016), [hm0, wa.x + 0.02, wa.y + 0.02, wa.z - 0.02]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return 0.007 * sin(a * 6.0 + y * 11.0) * smoothstep(0.2, 0.5, up) + 0.012 * exp(-pow((y - (H + 0.2)) / 0.04, 2.0)) * sin(a * 9.0 + 0.4)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hm0, "col": func(_a, _y, _v): return yo, "fold": fold, "band": og, "band_w": 0.012, "juban": cr, "ny": 40, "na": 60, "gain": 5.0, "inner": og.darkened(0.2)})
	# yakada üçüncü şerit: kremin içinde ince turuncu
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		var ed: Array = g["ea"] if lf else g["eb"]
		var pts := []
		for p in ed:
			var pp: Vector3 = p
			if pp.y < C - 0.11:
				break
			pts.append(pp + Vector3(-0.024 if lf else 0.024, 0.0, -0.007))
		if pts.size() >= 2:
			P._bd(k, pts, 0.0055, 0.0025, og, false, func(p): return M._wrap_skin(k, p, hm0, lf), 0.1)
	# hakama: göğüs altından bileğe, geniş, önde ve arkada pliler
	var ht: float = H + 0.17
	var hm: Vector3 = k.M(ht, k.UA)
	var hemh: float = k.F + 0.1
	var hkeys := [[ht, hm.x + 0.03, hm.y + 0.032, hm.z - 0.03], [H + 0.06, wa.x + 0.036, wa.y + 0.036, wa.z - 0.036], [H - 0.04, hp.x + 0.045, hp.y + 0.045, hp.z - 0.05],
		[KN, hp.x + 0.09, hp.y + 0.11, hp.z - 0.095], [hemh, hp.x + 0.115, hp.y + 0.125, hp.z - 0.115]]
	var hf := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hemh), 0.0, 1.0)
		var pl: float = 0.016 * Q._tri(a * 10.0 + 0.6) * smoothstep(0.0, 0.25, t) * (0.6 + 0.4 * absf(cos(a)))
		return pl + t * t * (0.016 * sin(a * 5.0 + 1.1) + 0.008 * sin(a * 13.0 + 0.4))
	var hsk := func(p): return _long_hk(k, p, hemh)
	var hg: Dictionary = P._cl(k, {"keys": hkeys, "ny": 70, "na": 96, "top": func(_a): return ht, "hem": func(_a): return hemh, "fold": func(a, y, _v): return hf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.006, "inner": rd.darkened(0.4), "skin": hsk})
	P._bd(k, M._yl(hg["hem"], 0.009), 0.006, 0.002, rd.darkened(0.15), true, hsk)
	var hff := func(a, y): return hf.call(float(a), float(y))
	# iki kat kırmızı bel bağı + soluk sarı kuşak
	var bkeys := [[ht + 0.01, hm.x + 0.048, hm.y + 0.05, hm.z - 0.048], [H + 0.06, wa.x + 0.052, wa.y + 0.052, wa.z - 0.052]]
	L._sash(k, bkeys, ht - 0.012, 0.016, 0.0, rd.darkened(0.06), 0.14, 1)
	L._sash(k, bkeys, ht - 0.05, 0.014, 0.0, rd.darkened(0.12), 0.14, 1)
	var by: float = ht - 0.031
	L._sash(k, bkeys, by, 0.0085, 0.004, bw, 0.08, 1)
	# fiyonk: iki yassı ilmek, ortada düğüm, hakamanın üstüne yatan iki uç
	var kq: Array = P._sa(bkeys, 0.0, by, 0.016)
	var c0: Vector3 = kq[0]
	var hip: Array = [["Hips", 0.35], ["Spine", 0.65]]
	for sg in [1.0, -1.0]:
		var lp := []
		for i in 24:
			var th: float = TAU * float(i) / 24.0
			lp.append(c0 + Vector3(sg * (0.012 + 0.04 * (1.0 - cos(th))), 0.026 * sin(th) + 0.008 * (1.0 - cos(th)), 0.008 * (1.0 - cos(th)) * 0.3))
		P._tb(k, lp, func(_s, a): return 0.0075 * (0.35 + 0.65 * absf(sin(float(a)))), func(_s, a, _p): return bw.darkened(0.12) if cos(float(a)) < -0.3 else bw, func(_s, _p): return hip, 10, true)
	P._boxr(k, c0 + Vector3(0, 0, 0.004), Vector3(0.012, 0, 0), Vector3(0, 0.016, 0), Vector3(0, 0, 0.008), bw.darkened(0.05), hip, 0.4)
	for e in [[0.004, 0.026, 0.16], [-0.006, -0.02, 0.13]]:
		var tp := []
		var to := []
		for i in 9:
			var v: float = float(i) / 8.0
			var y: float = by - 0.012 - v * float(e[2])
			var x: float = float(e[0]) + float(e[1]) * v
			var sp: Array = Q._spt(hkeys, hff, asin(clampf(x / 0.12, -0.9, 0.9)), y, 0.008 + 0.004 * (1.0 - v))
			tp.append(sp[0])
			to.append(sp[1])
		k.strip(tp, to, 0.011, 0.003, bw.darkened(0.04), false, hsk)
	# arkada koshi-ita: hakamanın arka belinde sert levha
	var kb: Array = P._sa(bkeys, PI, ht - 0.05, 0.012)
	P._boxr(k, kb[0], Vector3(0.075, 0, 0), Vector3(0, 0.045, 0), Vector3(0, 0, -0.008), rd.darkened(0.08), [["Hips", 0.5], ["Spine", 0.5]], 0.25)


## Kol üstünde omuzluk (sode): kolun dış-üst yönünde sıra sıra plaka, kolla sert gider (koşuda kanat gibi açılmaz). up: dış yönün yukarı payı
static func _sode_w(k, l: Dictionary, s0: float, s1: float, n: int, W: float, R: float, curve: float, up: float, col: Color, trim: Color, lace: Color, th := 0.008) -> Array:
	var sd: String = l["sd"]
	var sg: float = l["sg"]
	var ovec: Vector3 = Vector3(sg, up, 0.0).normalized()
	var fr := func(s: float) -> Array:
		var d: Vector3 = L._ld(l, s)
		var oo: Vector3 = (ovec - d * d.dot(ovec)).normalized()
		return [L._lp(l, s), oo, d.cross(oo).normalized()]
	var bo := [["UpperChest", 0.12], [sd + "UpperArm", 0.88]]
	var ds: float = (s1 - s0) / n
	for i in n:
		var st: float = s0 + i * ds * 0.86
		var en: float = st + ds
		var ra: float = R + 0.004 * i
		var pf := func(u: float, v: float) -> Vector3:
			var f: Array = fr.call(lerpf(st, en, v))
			var x: float = (2.0 * u - 1.0) * W
			return (f[0] as Vector3) + (f[1] as Vector3) * (ra + lerpf(-0.002, 0.007, v) - curve * x * x) + (f[2] as Vector3) * x
		var nf := func(u: float, v: float) -> Vector3:
			var f: Array = fr.call(lerpf(st, en, v))
			var x: float = (2.0 * u - 1.0) * W
			return ((f[1] as Vector3) + (f[2] as Vector3) * (2.0 * curve * x)).normalized()
		var last: bool = i == n - 1
		L._shell(k, pf, nf, 14, 5, th, func(_u, v, e):
			if last and v > 0.86:
				return trim
			return col.darkened(0.22) if e else col.darkened(0.06 * v), func(_u, _v, _p): return bo)
		if not last:
			for ux in [0.25, 0.75]:
				var a: Vector3 = pf.call(ux, 0.8) + (nf.call(ux, 0.8) as Vector3) * (th + 0.002)
				var c: Vector3 = pf.call(ux, 1.0) + (nf.call(ux, 1.0) as Vector3) * (th + 0.0045)
				L._cord(k, [a, c], 0.003, lace, func(_p): return bo, 5)
	var fm: Array = fr.call(s0 + (s1 - s0) * 0.35)
	return [(fm[0] as Vector3) + (fm[1] as Vector3) * (R + th + 0.004), fm[1], fm[2], bo]


## Gövde üstünde kısa yatay bağcık yuvası (koyu kabartma)
static func _slot(k, keys: Array, a: float, y: float, lift: float, w: float, col: Color, skinf: Callable) -> void:
	var r: float = float(SE.El.key_at(keys, y)[1])
	var pts := []
	var ou := []
	for t in 3:
		var e: Array = L._sa(keys, a + (float(t) - 1.0) * w / maxf(0.06, r), y, lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, 0.0026, 0.0018, col, false, skinf)


# ------------------------------------------------------------------ Mori Yoroi (ref Shinobi Striker "Hashirama Outfit"): boğazlıklı lacivert tulum (paçası baldırda biter), kızıl göğüslük + omuz askıları,
## kolun dışında sarkan kızıl omuzluk + omuz arkasında dik levha, kızıl kolluk, yanlarda kalçalık, beyaz baldır sargısı + lacivert bilek bandı, sırtta iki yana taşan dev parşömen
static func _hashirama(k) -> void:
	var b: Dictionary = P._base(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var nv := Color(0.12, 0.15, 0.3)
	var cm := Color(0.58, 0.1, 0.13)
	var cd := Color(0.33, 0.05, 0.07)
	var wh := Color(0.92, 0.92, 0.9)
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	var ik: Array = P._inner(k, b, func(_i, j, _p): return nv.lightened(0.03) if j % 7 == 3 else nv, 0.006)
	K._seat(k, b, nv.darkened(0.05))
	var ck := [P._kp(nk, N + 0.08 * q, 0.012, 0.016), P._kp(nk, N + 0.03 * q, 0.017), P._kp(nk, N - 0.03, 0.03), P._kp(nk, N - 0.06, 0.046, 0.042)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 9, "na": 48, "top": func(_a): return N + 0.075 * q, "hem": func(_a): return N - 0.055, "fold": func(a, y, _v): return 0.012 * sin(float(a) * 4.0 + float(y) * 60.0),
		"col": func(_a, _y, _v): return nv, "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.0045, nv.lightened(0.06), true, nsk)
	for lk in ["Left", "Right"]:
		var ar: Dictionary = L._limb(k, lk, false)
		var le: Dictionary = L._limb(k, lk, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sj: float = ar["sj"]
		var sg: float = ar["sg"]
		var sv: float = 1.3 if lk == "Left" else 2.4
		var sl := func(s: float, a: float) -> float:
			return 0.009 + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		L._lt(k, ar, sl, func(s, a, ins): return nv.darkened(0.3) if ins else P._fs(nv, float(sl.call(float(s), float(a))) - 0.009, 14.0), 0.0, 0.985, 34, 20)
		# kızıl kolluk: dirsekte geniş ağız, iki uçta koyu kenar, üstünde sırt levhası
		var g0: float = en + 0.05
		var ga := func(s: float, _a: float) -> float: return 0.02 + 0.012 * (1.0 - smoothstep(g0, g0 + 0.14, s)) - 0.004 * smoothstep(0.85, 0.94, s)
		L._lt(k, ar, ga, func(s, _a, ins): return cd if ins else (cd.lightened(0.05) if float(s) < g0 + 0.015 or float(s) > 0.915 else cm), g0, 0.93, 16, 24, 0.04)
		L._splint(k, ar, g0 + 0.06, 0.9, 0.0, 0.42, 0.03, 0.006, cm.lightened(0.06), cd, 6, 0.25)
		# omuzluk: kolun dışında sarkan üç plaka
		_sode_w(k, ar, sj - 0.01, en - 0.1, 3, 0.052, 0.072, 2.4, 0.35, cm, cd, cd.darkened(0.3), 0.009)
		# omuz arkasında dik levha
		var bc := Vector3(sg * ch.x * 0.62, N + 0.035, ch.z * 0.35)
		P._boxr(k, bc, Vector3(0.019, 0, 0), Vector3(sg * 0.01, 0.075, -0.006), Vector3(0, 0, 0.008), cm.darkened(0.04), [["UpperChest", 1.0]], 0.18)
		P._boxr(k, bc + Vector3(0, 0.0, 0.0085), Vector3(0.011, 0, 0), Vector3(sg * 0.009, 0.066, -0.005), Vector3(0, 0, 0.002), cd, [["UpperChest", 1.0]], 0.2)
		# baldırda biten paça, beyaz sargı, lacivert bilek bandı
		var tk: float = kn + 0.2
		Q._baggy(k, le, nv, wh.darkened(0.12), 0.014, 0.024, tk, sv)
		L._wraps(k, le, tk - 0.015, 0.895, 11, 0.009, 0.0125, wh, 0.009)
		L._lt(k, le, func(s, _a): return 0.017 + 0.002 * sin(clampf((s - 0.9) / 0.075, 0.0, 1.0) * PI), func(_s, a, ins): return nv.darkened(0.3) if ins else nv.darkened(0.08 if sin(float(a) * 5.0) < -0.5 else 0.0), 0.9, 0.975, 6, 20)
	# göğüslük: ön ve arka levha, altında koyu bel şeridi, omuz askıları
	var dk: Array = L._tk(k, b, 0.024, H + 0.0, 0.0, 0.0)
	var top: float = N - 0.095
	L._torso_plate(k, dk, 0.0, 1.22, top, H + 0.075, 0.004, 0.012, cm, cd, 30, 12)
	L._torso_plate(k, dk, PI, 1.22, top, H + 0.075, 0.004, 0.012, cm.darkened(0.04), cd, 30, 12)
	for ac in [0.0, PI]:
		L._torso_plate(k, dk, ac, 1.26, H + 0.095, H + 0.055, 0.016, 0.009, cd.lightened(0.08), cd, 30, 3)
	for sg in [1.0, -1.0]:
		L._over(k, ik.slice(1), sg * 0.58, top + 0.004, sg * (PI - 0.58), top + 0.004, 0.012, 0.016, 0.006, cm.darkened(0.12))
	# kalçalık: iki yanda dörder plaka
	for sg in [1.0, -1.0]:
		L._tasset(k, b, {"y0": H + 0.05, "ac": sg * (PI * 0.5 + 0.08), "aw": 0.3, "n": 4, "h": 0.085, "ov": 0.014, "flare": 0.12, "add": 0.034, "col": cm, "trim": cd, "lace": cd.darkened(0.3), "th": 0.008})
	# sırtta dev parşömen: kanondaki kâğıt + lila kat + koyu topuz; koşuda kollar içinden geçmesin diye sırta çapraz, uçları omuz / kalça genişliğinde kalır
	var R := 0.088
	var Lh := 0.27
	var ax := Vector3(-0.47, 0.883, 0.0).normalized()   # alt uç sol kalçada, üst uç sağ kürek kemiğinde
	var e1 := Vector3(-ax.y, ax.x, 0.0)
	var e2 := Vector3(0.0, 0.0, 1.0)
	var yc: float = C - 0.14
	var bz := 9.0
	for i in 9:
		var yy: float = yc + ax.y * lerpf(-Lh, Lh, float(i) / 8.0)
		bz = minf(bz, float(SE.El.key_at(dk, minf(yy, N - 0.1))[3]))
	var c0 := Vector3(0.0, yc, bz - 0.006 - R)
	var sb: Array = k.torso_skin(yc)
	var lav := Color(0.72, 0.7, 0.86)
	var paper := Color(0.95, 0.95, 0.97)
	var rp := func(x: float, th: float, r: float) -> Vector3: return c0 + ax * x + (e1 * sin(th) + e2 * cos(th)) * r
	var rows := []
	for j in 29:
		var x: float = lerpf(-Lh, Lh, float(j) / 28.0)
		var ro := []
		for i in 30:
			ro.append(rp.call(x, TAU * i / 30.0, R))
		rows.append(ro)
	Q._mesh(k, rows, true, func(i, j, _p):
		var x: float = lerpf(-Lh, Lh, float(j) / 28.0)
		return paper.darkened(0.08) if absf(x) > Lh - 0.012 else paper.darkened(0.04 * float(i % 2)), func(_i, _j, _p): return sb, e2)
	for sx in [1.0, -1.0]:
		# uç kapağı + topuz
		var cap := []
		for jj in 3:
			var ro := []
			for i in 30:
				ro.append(rp.call(sx * (Lh + 0.002), TAU * i / 30.0, R * [1.0, 0.55, 0.05][jj]))
			cap.append(ro)
		Q._mesh(k, cap, true, func(_i, _j, _p): return paper.darkened(0.14), func(_i, _j, _p): return sb, ax * sx)
		P._tb(k, [c0 + ax * sx * (Lh - 0.004), c0 + ax * sx * (Lh + 0.026), c0 + ax * sx * (Lh + 0.036)], func(s, _a): return 0.026 * (1.0 - 0.75 * smoothstep(0.6, 1.0, float(s))), func(_s, a, _p): return Color(0.1, 0.1, 0.12).lightened(0.08 if cos(float(a)) > 0.5 else 0.0), func(_s, _p): return sb, 14)
		# altın çizgiler: uçta kâğıdın dışa bakan yüzünde
		for i in 6:
			var th: float = PI + lerpf(-1.2, 1.2, float(i) / 5.0)
			var o: Vector3 = e1 * sin(th) + e2 * cos(th)
			P._boxr(k, c0 + ax * sx * (Lh - 0.05) + o * (R + 0.002), ax * 0.014, (e1 * cos(th) - e2 * sin(th)) * 0.0032, o * 0.0022, Color(0.78, 0.63, 0.28), sb, 0.4)
	# lila kat: kâğıdın dış katı, yırtık kenarlı
	var lr := []
	for i in 31:
		var th: float = lerpf(-PI * 0.95, PI * 0.95, float(i) / 30.0)
		var xb: float = Lh * 0.56 + 0.02 * Q._tri(th * 4.0 + 0.5) + 0.01 * sin(th * 11.0)
		var ro := []
		for j in 17:
			ro.append(rp.call(lerpf(-xb, xb, float(j) / 16.0), th + PI, R + 0.003))
		lr.append(ro)
	var lo: Vector3 = (lr[1][0] as Vector3) - c0
	Q._mesh(k, lr, false, func(_i, j, _p): return lav.darkened(0.06 * float(j % 2)), func(_i, _j, _p): return sb, (lo - ax * ax.dot(lo)).normalized())


# ------------------------------------------------------------------ Mori Yoroi Wakate (ref Shinobi Striker "Hashirama Outfit: Young Ver."): lacivert kimono (file iç yaka), zeytin yeşili göğüslük + dize inen plakalı önlük,
## tepesinde Senju arması olan omuzluk + omuz kemerleri, bej burgu ip kuşak, sol kalçada kahve kese, file önkol + baldır, lacivert bant
static func _hashi_genc(k) -> void:
	var b: Dictionary = P._base(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var nv := Color(0.12, 0.13, 0.23)
	var ol := Color(0.45, 0.5, 0.45)
	var od := Color(0.27, 0.3, 0.28)
	var pd := Color(0.33, 0.36, 0.35)
	var rp := Color(0.86, 0.8, 0.62)
	var bg := Color(0.44, 0.29, 0.2)
	var nt := Color(0.36, 0.2, 0.18)
	var skc: Color = Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var ik: Array = P._inner(k, b, func(_i, _j, p): return skc if p.y > C - 0.02 else nv.darkened(0.3), 0.004, -99.0, 72)   # 72 sıra: boyun ve yaka ağzı katı görünür (V yaka)
	P._net_patch(k, ik, func(a, y): return absf(float(a)) < 0.62, -0.62, 0.62, C - 0.03, N + 0.05, 0.013, 0.0011, 0.0025, nt)
	K._seat(k, b, nv.darkened(0.08))
	for lk in ["Left", "Right"]:
		var ar: Dictionary = L._limb(k, lk, false)
		var le: Dictionary = L._limb(k, lk, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sj: float = ar["sj"]
		var sg: float = ar["sg"]
		var sv: float = 0.9 if lk == "Left" else 2.2
		# önkol: ten + file, lacivert bilek bandı; kimono kolu önkolun ortasında biter
		L._lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, en, 0.985, 18, 16)
		P._net_limb(k, ar, en + 0.1, 0.9, 0.003, 8, 0.014, 0.0011, nt)
		L._lt(k, ar, func(s, _a): return 0.008 + 0.002 * sin(clampf((s - 0.9) / 0.075, 0.0, 1.0) * PI), func(_s, _a, ins): return nv.darkened(0.3) if ins else nv, 0.9, 0.975, 6, 18)
		var s1: float = en + 0.2
		var sl := func(s: float, a: float) -> float:
			return 0.014 + 0.012 * smoothstep(0.1, 0.5, s) + 0.005 * P._lf(s, a, sv) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		L._lt(k, ar, sl, func(s, a, ins): return nv.darkened(0.35) if ins else P._fs(nv, 0.005 * P._lf(float(s), float(a), sv), 12.0), 0.0, s1, 34, 22, 0.05)
		# baldır: file + ten, lacivert bilek bandı; pantolon dizaltında büzülür
		L._lt(k, le, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, kn, 0.99, 18, 16)
		P._net_limb(k, le, kn + 0.12, 0.92, 0.003, 9, 0.014, 0.0011, nt)
		L._lt(k, le, func(s, _a): return 0.012 + 0.002 * sin(clampf((s - 0.915) / 0.07, 0.0, 1.0) * PI), func(_s, a, ins): return nv.darkened(0.3) if ins else nv.darkened(0.08 if sin(float(a) * 5.0) < -0.5 else 0.0), 0.915, 0.985, 6, 20)
		var tk: float = kn + 0.14
		var pa: Callable = K._pant(k, le, nv, 0.014, 0.022, tk, sv)
		L._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.003 + 0.002 * sin(clampf((s - tk + 0.04) / 0.04, 0.0, 1.0) * PI), func(_s, _a, ins): return nv.darkened(0.35) if ins else nv.lightened(0.04), tk - 0.04, tk + 0.002, 5, 20)
		# omuzluk: omuz tepesinde koyu plakalar, üstte Senju arması
		var cr: Array = _sode_w(k, ar, sj - 0.03, sj + 0.2, 2, 0.06, 0.066, 3.0, 1.1, pd, od, od.darkened(0.3), 0.009)
		var cc: Vector3 = cr[0]
		var co: Vector3 = cr[1]
		P._fan(k, cc, co, cr[2], 0.022, Callable(), func(u, v):
			var r2: float = Vector2(float(u), float(v)).length()
			return od.darkened(0.2) if r2 > 0.78 or (r2 < 0.5 and absf(float(u)) < 0.12) else pd.lightened(0.1), cr[3], 4, 24)
		k.strip([cc + co * 0.003 - (cr[2] as Vector3) * 0.012, cc + co * 0.003 + (cr[2] as Vector3) * 0.012], [co, co], 0.0028, 0.002, od.darkened(0.25), false, func(_p): return cr[3])
	# kimono: sol kanat üstte, kalçaya iner
	var hem: float = H - 0.12
	var keys := [P._kp(nk, N + 0.01, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.046), [hem, hp.x + 0.06, hp.y + 0.055, hp.z - 0.065]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * 0.016 * sin(a * 6.0 + 0.3) + 0.007 * sin(a * 5.0 + y * 12.0) * smoothstep(H + 0.3, H + 0.05, y)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, _v): return nv, "fold": fold, "band": nv.lightened(0.07), "band_w": 0.015, "ny": 40, "na": 60, "gain": 5.0, "inner": nv.darkened(0.3), "low": -0.3})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		P._bd(k, M._yl(g["hem"], 0.007), 0.005, 0.002, nv.darkened(0.2), false, func(p): return M._wrap_skin(k, p, hem, lf))
	# göğüslük: ön ve arka levha, bağcık yuvaları, omuz kemerleri
	var dk: Array = L._tk(k, b, 0.04, H + 0.0, 0.0, 0.0)
	var top: float = N - 0.085
	L._torso_plate(k, dk, 0.0, 1.2, top, H + 0.07, 0.004, 0.012, ol, od, 30, 12)
	L._torso_plate(k, dk, PI, 1.2, top, H + 0.07, 0.004, 0.012, ol.darkened(0.04), od, 30, 12)
	for e in [[-0.2, top - 0.022], [0.2, top - 0.022], [-0.55, C - 0.05], [0.55, C - 0.05], [-0.55, C - 0.12], [0.55, C - 0.12], [-0.3, H + 0.11], [0.3, H + 0.11]]:
		_slot(k, dk, float(e[0]), float(e[1]), 0.018, 0.016, od.darkened(0.3), tsk)
	for sg in [1.0, -1.0]:
		var fp: Vector3 = L._sa(dk, sg * 0.5, top + 0.002, 0.012)[0]
		var bp: Vector3 = L._sa(dk, sg * (PI - 0.5), top + 0.002, 0.012)[0]
		var ap := Vector3(sg * ch.x * 0.62, N + 0.075, (fp.z + bp.z) * 0.5)
		var arc := []
		for i in 17:
			var t: float = float(i) / 16.0
			arc.append(fp * (1.0 - t) * (1.0 - t) + ap * 2.0 * t * (1.0 - t) + bp * t * t)
		P._tb(k, arc, func(_s, _a): return 0.0055, func(_s, a, _p): return od.darkened(0.15) if cos(float(a)) < -0.3 else od, func(_s, _p): return [["UpperChest", 1.0]], 8)
	# önlük: belden dize üç sıra plaka (iki bacağın ortalamasını izler), bağcık yuvaları
	var ak := [[H + 0.07, hp.x + 0.05, hp.y + 0.062, hp.z - 0.05], [KN + 0.05, hp.x + 0.08, hp.y + 0.105, hp.z - 0.08], [KN - 0.04, hp.x + 0.085, hp.y + 0.125, hp.z - 0.085]]
	var ah: float = KN - 0.035
	var ask := func(p: Vector3) -> Array:
		var t: float = clampf((H + 0.07 - p.y) / (H + 0.07 - ah), 0.0, 1.0)
		var w: float = 0.74 * pow(minf(1.0, t / 0.3), 0.6)
		var s2: float = 1.0 if p.x > 0.0 else 0.0
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s2], ["RightUpperLeg", w * (1.0 - s2)]]
	var nr := 3
	var rh: float = (H + 0.07 - ah) / nr
	for sg in [1.0, -1.0]:   # iki yarım önlük: her biri kendi uyluğunu izler, ortada sol yarım sağın üstüne biner
		var ac: float = sg * 0.33
		var ov: float = 0.004 if sg > 0.0 else 0.0
		for r in nr:
			var y0: float = H + 0.07 - r * rh + (0.012 if r > 0 else 0.0)
			var y1: float = H + 0.07 - (r + 1) * rh
			var last: bool = r == nr - 1
			L._shell(k, func(u: float, v: float) -> Vector3: return L._sa(ak, ac + 0.37 * (2.0 * u - 1.0), lerpf(y0, y1, v), 0.003 * r + ov)[0],
				func(u: float, v: float) -> Vector3: return L._sa(ak, ac + 0.37 * (2.0 * u - 1.0), lerpf(y0, y1, v))[1], 14, 8, 0.011, func(_u, v, e):
					if last and v > 0.9:
						return od
					return od.darkened(0.1) if e else ol.darkened(0.05 * v), func(_u, _v, p): return ask.call(Vector3(sg * 0.05, p.y, p.z)))
			for yy in [0.3, 0.7]:
				_slot(k, ak, ac, lerpf(y0, y1, float(yy)), 0.003 * r + 0.0125 + ov, 0.012, od.darkened(0.3), func(p): return ask.call(Vector3(sg * 0.05, p.y, p.z)))
	# bej burgu ip kuşak, sağ yanda düğüm ve iki kısa uç
	var rk := [[H + 0.12, wa.x + 0.07, wa.y + 0.065, wa.z - 0.065], [H + 0.02, wa.x + 0.08, wa.y + 0.075, wa.z - 0.075]]
	var ry: float = H + 0.075
	T._twist(k, P._ring_pts(rk, ry, 0.0, 72), true, 0.012, 16.0, rp, tsk)
	var kq: Array = L._sa(rk, -1.25, ry, 0.012)
	var kc: Vector3 = kq[0]
	P._boxr(k, kc, Vector3(0, 0, 0.02), Vector3(0, 0.017, 0), (kq[1] as Vector3) * 0.014, rp.darkened(0.06), [["Hips", 1.0]], 0.5)
	for dx in [0.012, -0.014]:
		var tl := []
		for i in 7:
			var t: float = float(i) / 6.0
			tl.append(kc + (kq[1] as Vector3) * 0.006 + Vector3(-0.004 * t, -0.012 - 0.09 * t, float(dx) + 0.01 * t * signf(float(dx))))
		T._twist(k, tl, false, 0.0085, 3.0, rp, func(p): return T._ksk(k, p, H - 0.3), 0.3)
	# sol kalçada kahve kese
	var bq: Array = L._sa(ak, PI - 0.75, H - 0.03, 0.03)
	var bo := [["Hips", 1.0]]
	P._boxr(k, bq[0], Vector3(0.045, 0, 0).rotated(Vector3.UP, -0.75 + PI), Vector3(0, 0.05, 0), (bq[1] as Vector3) * 0.024, bg, bo, 0.4)
	P._boxr(k, (bq[0] as Vector3) + Vector3(0, 0.036, 0) + (bq[1] as Vector3) * 0.006, Vector3(0.048, 0, 0).rotated(Vector3.UP, -0.75 + PI), Vector3(0, 0.017, 0), (bq[1] as Vector3) * 0.022, bg.lightened(0.06), bo, 0.4)
