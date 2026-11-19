extends RefCounted
## Elle modellenmiş setler, parti at: ss_ruzgar_genc, ss_silah_ustasi, ss_turuncu_maske, ss_su_zirh, ss_ay_cubbe, ss_antrenman. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{temari_outfit_young_ver, tenten_outfit, tobi_outfit, tobirama_outfit, toneri_outfit, training_clothes}/.
## Kumaş / uzuv yardımcıları parti e (P), i (I), j (J), k (K), l (L), m (M), q (Q), r (R), x (X), z (Z), aa (AA), ag (AG), aj (AJ) dosyalarından;
## burada: hakama paçası (bant kabartmalı), tasuki, Çin düğüm düğmesi, kürk yakalık, magatama dizisi ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const AB = preload("res://scripts/actors/set_el_ab.gd")
const AJ = preload("res://scripts/actors/set_el_aj.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")

const DONE := ["ss_antrenman", "ss_silah_ustasi", "ss_su_zirh", "ss_turuncu_maske", "ss_ay_cubbe", "ss_ruzgar_genc"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_antrenman": _keiko(k)
		"ss_silah_ustasi": _tenten(k)
		"ss_su_zirh": _tobirama(k)
		"ss_turuncu_maske": _tobi(k)
		"ss_ay_cubbe": _toneri(k)
		"ss_ruzgar_genc": _kaze_genc(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Hakama paçası: belden (top) iner, uyluğun altında geniş tüp; önde ve arkada pliler (gerçek kat), paçanın ucunda kabartma beyaz bant + ince çizgi.
## o: prof(s) ek yarıçap, s1 paça ucu, pl pli sayısı, amp, top (H üstü), col, band (Color), seg, n, pad
static func _hakama_leg(k, b: Dictionary, l: Dictionary, o: Dictionary) -> void:
	var sg: float = l["sg"]
	var kn: float = l["kn"]
	var hp: Vector3 = b["hp"]
	var wa: Vector3 = b["wa"]
	var H: float = k.H
	var s1: float = o["s1"]
	var top: float = H + float(o.get("top", 0.12))
	var prof: Callable = o["prof"]
	var pl: float = o.get("pl", 9.0)
	var amp: float = o.get("amp", 0.05)
	var col: Color = o["col"]
	var bc: Color = o["band"]
	var seg: int = o.get("seg", 54)
	var n: int = o.get("n", 34)
	var pad: float = o.get("pad", 0.016)
	var p0: Vector3 = l["p0"]
	var st := []
	for j in 6:
		st.append([lerpf(top, p0.y, float(j) / 6.0), 0.0, 0.0])
	for j in n + 1:
		st.append([0.0, s1 * float(j) / n, 0.0])
	st.append([0.0, s1, -0.005])
	for j in 3:
		st.append([0.0, s1 - 0.045 * float(j), -0.01])
	var ni: int = n + 7
	var b0: float = s1 - 0.052
	var b1: float = s1 - 0.012
	var l0: float = s1 - 0.078
	var l1: float = s1 - 0.066
	var bump := func(s: float) -> float:
		var e1: float = smoothstep(b0 - 0.004, b0 + 0.004, s) * (1.0 - smoothstep(b1 - 0.004, b1 + 0.002, s))
		var e2: float = smoothstep(l0 - 0.003, l0 + 0.002, s) * (1.0 - smoothstep(l1 - 0.002, l1 + 0.003, s))
		return 0.0028 * maxf(e1, e2)
	var white := func(s: float) -> bool: return (s > b0 and s < b1) or (s > l0 and s < l1)
	var rows := []
	var cc := []
	var sk := []
	var tx: float = hp.x * 0.56 + pad
	var cx0: float = sg * (hp.x * 0.44 + pad * 0.3)
	var zf: float = hp.y + pad
	var zb: float = absf(hp.z) + pad + 0.015
	var bo: Array = l["bo"]
	for ji in st.size():
		var e: Array = st[ji]
		var s: float = e[1]
		var top_row: bool = float(e[0]) != 0.0
		var base: Vector3 = L._lp(l, s) if not top_row else Vector3(p0.x, e[0], p0.z)
		var tl: float = smoothstep(0.0, 0.32, s) if not top_row else 0.0
		var R0: float = L._lr(l, s) + float(prof.call(s)) + float(e[2]) + (float(bump.call(s)) if ji <= ni and not top_row else 0.0)
		var wt: float = 1.0 - smoothstep(H - 0.04, top - 0.01, base.y) if top_row else 1.0
		var tx2: float = lerpf(wa.x * 0.56 + pad, tx, wt)
		var cx2: float = lerpf(sg * (wa.x * 0.44 + pad * 0.3), cx0, wt)
		var c3 := Vector3(lerpf(cx2, base.x, tl), base.y, lerpf(0.0, base.z, tl))
		var rx: float = lerpf(tx2, R0, tl)
		var rf: float = lerpf(lerpf(wa.y + pad, zf, wt), R0, tl)
		var rb: float = lerpf(lerpf(absf(wa.z) + pad, zb, wt), R0 * 1.06, tl)
		var ampv: float = amp * lerpf(0.25, 1.0, smoothstep(0.0, 0.5, s)) * (0.0 if top_row else 1.0) + (amp * 0.35 if top_row else 0.0)
		var ro := []
		var cr := []
		var sr := []
		var w: float = smoothstep(0.02, 0.26, s) if not top_row else 0.0
		var c: float = smoothstep(kn - 0.05, kn + 0.3, s) * float(o.get("cmax", 0.72))
		var wh: bool = not top_row and ji <= ni and bool(white.call(s))
		for i in seg:
			var a: float = TAU * i / seg - PI
			var inn: float = smoothstep(0.0, 0.6, -sg * sin(a)) * (1.0 - smoothstep(0.22, 0.55, s))
			var w2: float = w * (1.0 - 0.7 * inn)
			sr.append([["Hips", 1.0 - w2], [bo[0], w2 * (1.0 - c)], [bo[1], w2 * c]])
			var front: float = 0.35 + 0.65 * absf(cos(a))   # pliler önde ve arkada derin, yanda sığ
			var saw: float = fposmod(a * pl / TAU + 0.15, 1.0)
			var f: float = ampv * front * (smoothstep(0.0, 0.16, saw) - smoothstep(0.16, 1.0, saw) - 0.2)
			var q: Vector2 = SE.El.sup(a, rx, rf, -rb, 2.2)
			ro.append(c3 + Vector3(q.x * (1.0 + f), 0.0, q.y * (1.0 + f)))
			var c0: Color = bc if wh else col
			c0 = c0.darkened(clampf(-f / maxf(amp, 0.001) * 0.3, 0.0, 0.3)).lightened(clampf(f / maxf(amp, 0.001) * 0.08, 0.0, 0.08))
			cr.append(c0.darkened(0.42) if ji > ni else c0)
		rows.append(ro)
		cc.append(cr)
		sk.append(sr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(i, j, _p): return sk[j][i])


## Omuz çevresinden geçen kayış ilmeği (tasuki): ön omuz başından koltuk altına iner, arkadan çıkıp omuz üstünden döner.
## keys: üst giysi; x omzun üstünde geçtiği yer
static func _tasuki_loop(k, keys: Array, sg: float, x: float, y_low: float, hw: float, lift: float, col: Color, low: Color) -> void:
	var tsk := func(p): return M._arm_skin(k, p, absf(x) + 0.03)
	var ys: float = keys[0][0]
	while ys > keys[keys.size() - 1][0] and float(SE.El.key_at(keys, ys)[1]) <= absf(x) + 0.01:
		ys -= 0.004
	var pts := []
	var ou := []
	var n := 14
	for j in n + 1:   # önde koltuk altından omuz üstüne
		var t := float(j) / n
		var xx: float = lerpf(sg * (absf(x) + 0.03), x, smoothstep(0.0, 0.7, t))
		var e: Array = P._fp(keys, xx, lerpf(y_low, ys, t), true, lift)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.6, 1.0, t)).normalized())
	for j in range(n, -1, -1):   # arkada omuz üstünden aşağı
		var t := float(j) / n
		var xx: float = lerpf(sg * (absf(x) + 0.03), x, smoothstep(0.0, 0.7, t))
		var e: Array = P._fp(keys, xx, lerpf(y_low, ys, t), false, lift)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.6, 1.0, t)).normalized())
	k.strip(pts, ou, hw, 0.004, col, false, tsk)
	# alt kenar: kayış kolun altına girerken gölgede kalan koyu turuncu kat
	var lp := []
	var lo := []
	for j in 5:
		var t := float(j) / 4.0
		var e: Array = P._fp(keys, sg * (absf(x) + 0.03), lerpf(y_low, y_low + 0.05, t), true, lift + 0.0015)
		lp.append(e[0])
		lo.append(e[1])
	k.strip(lp, lo, hw * 0.92, 0.0045, low, false, tsk)


# ------------------------------------------------------------------ Keiko-gi: Nenga (ref Shinobi Striker "Training Clothes"): geniş kısa kollu beyaz gi (sol kanat sağın üstüne, içte açık mavi yaka),
## omuzlardan geçip sırtta çaprazlanan sarı tasuki, yüksek belli geniş paçalı mavi hakama (önde ve arkada pliler, baldır ortasında beyaz paça bandı + ince çizgi),
## önde üç katlı himo düğümü ve çapraz bağlar, arkada koshi-ita; altı çıplak baldır (tabi / zōri ayak parçası)
static func _keiko(k) -> void:
	var wh := Color(0.957, 0.957, 0.965)
	var lb := Color(0.62, 0.78, 0.93)
	var bl := Color(0.11, 0.21, 0.565)
	var ye := Color(0.96, 0.78, 0.2)
	var og := Color(0.93, 0.56, 0.16)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	M._inner_v(k, b, wh.darkened(0.08))
	L._seat(k, b, bl.darkened(0.1))
	# hakama paçaları: belden baldır ortasına, geniş, pli
	var ht: float = H + 0.15
	for sd in ["Left", "Right"]:
		var le: Dictionary = L._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.31
		P._bare(k, P._limb(k, sd, true), skc, s1 - 0.07, 1.0)
		_hakama_leg(k, b, le, {"col": bl, "band": wh, "prof": func(s): return 0.016 + 0.05 * smoothstep(0.05, kn, float(s)) - 0.024 * smoothstep(kn + 0.05, s1, float(s)),
			"pl": 6.0, "amp": 0.05, "s1": s1, "top": 0.15, "seg": 56, "n": 34, "pad": 0.022, "cmax": 0.62})
	# hakamanın bel kısmı: önde ve arkada pli panel, iki paçanın üst ağzını örter (ortada gi görünmez)
	var hp: Vector3 = b["hp"]
	var uh: float = H - 0.13
	var uk := [P._kp(k.M(ht, k.UA), ht, 0.03), P._kp(wa, H + 0.06, 0.034), P._kp(hp, H - 0.04, 0.026), [uh, hp.x * 0.92, hp.y + 0.03, hp.z - 0.03]]
	var uf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((ht - y) / (ht - uh), 0.0, 1.0)
		return (0.03 * Q._tri(a * 12.0 + 0.4) * (0.4 + 0.6 * absf(cos(a))) + 0.006 * sin(a * 5.0)) * smoothstep(0.05, 0.4, t)
	P._cl(k, {"keys": uk, "ny": 18, "na": 120, "top": func(_a): return ht, "hem": func(_a): return uh, "fold": uf, "col": func(_a, _y, _v): return bl, "gain": 7.0, "th": 0.006,
		"inner": bl.darkened(0.4), "skin": func(p): return Q._csk(k, p, uh, 0.05)})
	# gi gövdesi: sol kanat sağın üstüne biner, hakamanın içine girer
	var hm0: float = H + 0.06
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.012), [hm0, wa.x + 0.008, wa.y + 0.008, wa.z - 0.008]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		var blouse: float = 0.02 * exp(-pow((y - (ht + 0.035)) / 0.03, 2.0)) * (0.6 + 0.4 * sin(a * 7.0 + 0.3))
		return 0.007 * sin(a * 6.0 + y * 11.0) * smoothstep(0.2, 0.5, up) + 0.01 * sin(a * 4.0 - y * 18.0) * (1.0 - smoothstep(0.3, 0.6, up)) + blouse
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hm0, "col": func(_a, _y, _v): return wh, "fold": fold, "band": wh.darkened(0.04), "band_w": 0.017, "juban": lb,
		"ny": 40, "na": 60, "gain": 4.0, "inner": wh.darkened(0.25)})
	# kollar: dirseğe inen geniş kısa kol (ağzı açık, astarlı), altı çıplak
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.3 if sd == "Left" else 2.7
		R._arm_skin(k, ar, 0.22)
		M._wide(k, ar, func(s: float) -> float: return 0.052 + 0.02 * smoothstep(0.05, 0.4, s), func(s: float) -> float: return 0.012 + 0.016 * smoothstep(0.15, 0.8, s / en),
			func(s: float, a: float) -> float: return 0.035 * sin(a * 3.0 + s * 9.0 + sv) + 0.02 * sin(a * 5.0 + sv), func(s: float, a: float, ins: bool) -> Color:
				if ins:
					return wh.darkened(0.3)
				return P._fs(wh, 0.012 * sin(a * 3.0 + s * 9.0 + sv), 7.0), en - 0.02, 0.0, 0.06, 26, 36)
	# tasuki: iki omuzda ilmek, sırtta çapraz
	for sg in [1.0, -1.0]:
		_tasuki_loop(k, keys, sg, sg * ch.x * 0.72, C - 0.09, 0.012, 0.009, ye, og)
		P._strap(k, keys, [Vector2(sg * ch.x * 0.72, N - 0.035), Vector2(0.0, C - 0.07), Vector2(-sg * ch.x * 0.86, C - 0.1)], false, 0.012, 0.009, 0.004, ye.darkened(0.03 * (1.0 + sg)), 12, tsk)
	# himo: hakamanın üst kenarında kalın mavi bağ, önde çaprazlanan kat bağlar ve üç katlı düğüm
	var bk2 := [P._kp(k.M(ht + 0.02, k.UA), ht + 0.02, 0.034), P._kp(wa, H + 0.08, 0.038)]
	L._sash(k, bk2, ht - 0.012, 0.018, 0.0, bl.darkened(0.08), 0.18, 1)
	for sg in [1.0, -1.0]:
		P._strap(k, bk2, [Vector2(0.0, ht - 0.006), Vector2(sg * wa.x * 0.55, ht - 0.026), Vector2(sg * wa.x * 0.98, ht - 0.03)], true, 0.011, 0.012, 0.004, bl.lightened(0.05), 8, tsk)
		P._strap(k, bk2, [Vector2(0.0, ht - 0.036), Vector2(sg * wa.x * 0.5, ht - 0.014), Vector2(sg * wa.x * 0.95, ht - 0.006)], true, 0.009, 0.0135, 0.004, bl.darkened(0.04), 8, tsk)
	var kq: Array = P._fp(bk2, 0.0, ht - 0.02, true, 0.026)
	var ko: Vector3 = kq[1]
	var kx: Vector3 = Vector3.UP.cross(ko).normalized()
	for i in 3:
		var c0: Vector3 = (kq[0] as Vector3) + Vector3(0, 0.026 - 0.026 * i, 0) + ko * 0.002 * float(1 - absi(i - 1))
		P._boxr(k, c0, kx * 0.019, Vector3(0, 0.011, 0), ko * 0.009, bl.lightened(0.04 if i == 1 else 0.0), k.torso_skin(c0.y), 0.35)
		P._boxr(k, c0 + ko * 0.009, kx * 0.006, Vector3(0, 0.0085, 0), ko * 0.003, bl.darkened(0.2), k.torso_skin(c0.y), 0.4)
	# arkada koshi-ita: sert yamuk levha
	var kb: Array = P._fp(bk2, 0.0, ht - 0.035, false, 0.012)
	var kbo: Vector3 = kb[1]
	P._boxr(k, kb[0], Vector3(0.085, 0, 0), Vector3(0, 0.05, 0), kbo * 0.007, bl.darkened(0.05), [["Hips", 0.5], ["Spine", 0.5]], 0.22)
	P._boxr(k, (kb[0] as Vector3) + kbo * 0.006 + Vector3(0, 0.03, 0), Vector3(0.06, 0, 0), Vector3(0, 0.004, 0), kbo * 0.003, bl.darkened(0.25), [["Hips", 0.5], ["Spine", 0.5]], 0.4)


## Çin düğüm düğmesi (pankou): kumaşa yatan yatay ip köprü, bir ucunda yuvarlak düğüm, öbür ucunda ilmek. c merkez, o dış yön, w yarı genişlik
static func _frog(k, c: Vector3, o: Vector3, w: float, col: Color, bones: Array) -> void:
	var x: Vector3 = Vector3.UP.cross(o).normalized()
	var y: Vector3 = o.cross(x).normalized()
	var sk := func(_p): return bones
	P._cord(k, [c - x * w + o * 0.002, c - x * w * 0.5 + o * 0.0035, c + o * 0.004, c + x * w * 0.5 + o * 0.0035, c + x * w + o * 0.002], 0.0026, col, false, sk, 0.0, 6)
	P._stud(k, c - x * (w + 0.0035) + o * 0.001, o, 0.0052, col.darkened(0.06), bones)
	var lp := []
	for i in 12:
		var t := TAU * i / 12.0
		lp.append(c + x * (w + 0.006 + 0.0055 * cos(t)) + y * 0.0042 * sin(t) + o * 0.003)
	P._cord(k, lp, 0.002, col, true, sk, 0.0, 5)


# ------------------------------------------------------------------ Buki Shōzoku (ref Shinobi Striker "Tenten Outfit"): beyaz Çin üstü (kırmızı biyeli dik yaka, yakadan sağa verev inip etek ucuna dikine inen
## kırmızı biyeli kapanış + dört düğüm düğme, kırmızı etek bandı, yanlarda leylak gölgeli kırışıklar), ön kol ortasında biten geniş kol + kıvrık kırmızı manşet, lacivert bilezik,
## şeftali pembesi bol pantolon (iç önde kırmızı dikiş biyesi, baldır ortasında toplanan kıvrık paça), altı çıplak baldır
static func _tenten(k) -> void:
	var wh := Color(0.957, 0.957, 0.949)
	var lv := Color(0.8, 0.78, 0.92)
	var rd := Color(0.78, 0.13, 0.12)
	var pk := Color(0.91, 0.63, 0.63)
	var nv := Color(0.16, 0.18, 0.36)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# pantolon: bol, baldır ortasında kıvrık paça; iç önde kırmızı biye
	K._seat(k, b, pk)
	I._seat(k, b, pk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 0.9 if sd == "Left" else 2.3
		var s1: float = kn + 0.25
		P._bare(k, le, skc, s1 - 0.06, 1.0)
		var ad: Callable = AJ._pleg(k, le, pk, s1, 0.02, 0.04, sv, 0.55, Callable(), pk.darkened(0.25))
		R._hem_roll(k, le, ad, s1, pk.darkened(0.05), 0.032, 0.0035)
		S._lstrip(k, le, 0.03, s1 - 0.034, func(_s): return -sg * 0.95, func(s, a): return float(ad.call(float(s), float(a))) + 0.0005, 0.0028, 0.0013, rd.darkened(0.1), 26)
	# üst: kalça üstüne iner
	var hem: float = H + 0.005
	var top: float = N + 0.008
	var jk: Array = AJ._jkeys(k, b, top, hem, 0.024, 0.032)
	var crease := func(a: float, y: float) -> float:   # yan kırışıklar: koltuk altından bele inen iki kat
		var aw: float = absf(a)
		var g: float = exp(-pow((aw - 1.42 + 0.08 * sin(y * 40.0)) / 0.07, 2.0)) * exp(-pow((y - (C - 0.1)) / 0.08, 2.0))
		return g
	var jf := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return -0.022 * float(crease.call(a, y)) + smoothstep(0.1, 0.4, absf(a)) * (t * (0.009 * sin(a * 6.0 + 0.6) + 0.004 * sin(a * 11.0 + 1.3)) + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 12.0))
	var jsk: Callable = AJ._jsk(k, hem)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 36, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(a, y, _v): return wh.lerp(lv, clampf(float(crease.call(float(a), float(y))) * 1.4, 0.0, 0.85)), "gain": 4.0, "th": 0.006, "inner": wh.darkened(0.3), "skin": jsk})
	var hm := []
	for p in jg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.011, 0))
	P._bd(k, hm, 0.011, 0.004, rd, true, jsk)
	var jff := func(a, y): return jf.call(float(a), float(y))
	# kapanış: yakadan sağa verev, sonra etek ucuna dikine; altında kanat kenarı basamağı
	var cp := [Vector2(-0.02, top - 0.004), Vector2(-0.2, N - 0.03), Vector2(-0.4, N - 0.075), Vector2(-0.43, C - 0.06), Vector2(-0.43, H + 0.08), Vector2(-0.43, hem + 0.02)]
	Q._run(k, jk, jff, cp, 0.0085, 0.0018, 0.0026, wh.darkened(0.03), jsk, 8)
	Q._run(k, jk, jff, cp, 0.0042, 0.0045, 0.0022, rd, jsk, 8)
	var fr := [[-0.09, N - 0.012], [-0.17, N - 0.026], [-0.25, N - 0.043], [-0.33, N - 0.061]]
	for e in fr:
		var sp: Array = Q._spt(jk, jff, float(e[0]), float(e[1]), 0.004)
		_frog(k, sp[0], sp[1], 0.013, rd, k.torso_skin(float(e[1])))
	for sg in [1.0, -1.0]:   # yan dikiş
		Q._run(k, jk, jff, [Vector2(sg * 1.58, C - 0.05), Vector2(sg * 1.57, hem + 0.02)], 0.0018, 0.0014, 0.001, wh.darkened(0.12), jsk, 8)
	# dik yaka: önde dar açıklık, kırmızı biyeli
	var cg: Dictionary = AJ._stand(k, nk, 0.05, 0.1, wh, wh.darkened(0.12), 0.026, 0.003)
	P._cord(k, cg["top"], 0.0036, rd, false, nsk)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0032, rd, false, nsk)
	# kollar: ön kol ortasına inen geniş kol, kıvrık kırmızı manşet, çıplak ön kol, lacivert bilezik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 1.7 if sd == "Left" else 0.6
		var s1 := 0.79
		R._arm_skin(k, ar, 0.62)
		var sf: Callable = AJ._sleeve(k, ar, wh, s1, sv, 0.02, 0.012, wh.darkened(0.25))
		I._cap(k, ar, wh, 0.02)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0035 + 0.0015 * sin(clampf((float(s) - s1 + 0.045) / 0.045, 0.0, 1.0) * PI), func(s, _a, ins):
			return rd.darkened(0.3) if ins else (rd.darkened(0.12) if float(s) < s1 - 0.038 else rd), s1 - 0.045, s1 + 0.002, 6, 24)
		I._cuff(k, ar, 0.875, 0.905, 0.0085, nv)
		Q._ring_on(k, ar, 0.89, func(_s, _a): return 0.0105, 0.0035, nv.lightened(0.15), 0.0012)


# ------------------------------------------------------------------ Mizu Yoroi (ref Shinobi Striker "Tobirama Outfit"): dirsekte ve dizde biten lacivert tulum (boğazlı), mavi zırh: göğüslük + bel plakası,
## önde ve arkada üç sıra plakalı etek, omuzda iki kat mavi omuzluk, altında soluk mor kolluk + iki bağ; omuzlara yayılan beyaz kürk yakalık, dizden bileğe beyaz sargı + siyah bilek bandı
static func _tobirama(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var bl := Color(0.165, 0.29, 0.722)
	var bld: Color = bl.darkened(0.32)
	var lv := Color(0.722, 0.659, 0.847)
	var fu := Color(0.949, 0.949, 0.941)
	var wh := Color(0.92, 0.91, 0.88)
	var bk := Color(0.1, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	var ik: Array = P._inner(k, b, func(_i, j, _p): return nv.lightened(0.03) if j < 4 else nv, 0.008)
	X._neck(k, b, nv, 0.075, false, 0.0)
	K._seat(k, b, nv)
	I._seat(k, b, nv)
	# tulum paçası: dizin altında toplanır; altında beyaz sargı, bilekte siyah bant
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		Q._baggy(k, le, nv, wh.darkened(0.25), 0.016, 0.03, kn + 0.07, sv)
		I._shin(k, le, kn + 0.05, 11, wh)
		I._cuff(k, le, 0.935, 0.978, 0.017, bk)
	# kollar: dirsekte biten tulum kolu, çıplak ön kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.1
		R._arm_skin(k, ar, en - 0.04)
		var sf: Callable = I._sleeve(k, ar, nv, 0.012, en + 0.03, sv)
		# omuzluk: iki kat mavi plaka omzun dışından iner; altında soluk mor kolluk ve iki bağ
		var la: Dictionary = L._limb(k, sd, false)
		var sj: float = la["sj"]
		L._splint(k, la, sj + 0.13, en - 0.04, 0.0, 0.62, float(sf.call(0.3, 0.0)) + 0.011, 0.006, lv, lv.darkened(0.22), 8, 0.0)
		for s in [sj + 0.17, en - 0.08]:
			Q._ring_on(k, ar, s, func(s2, a): return float(sf.call(float(s2), float(a))) + 0.0015, 0.0085, lv.darkened(0.06), 0.003)
		L._sode(k, la, {"s0": -0.01, "n": 2, "ln": 0.07, "ov": 0.016, "W": 0.052, "R": L._lr(la, sj + 0.06) + 0.034, "curve": 2.6, "col": bl, "trim": bld, "lace": bld, "th": 0.009})
	# göğüslük: üst kenar göğsün üstünde düz, yanlarda koltuk altına iner
	var cy0: float = N - 0.055
	var ck := [P._kp(k.M(cy0 + 0.01, k.UA), cy0 + 0.01, 0.032), P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(k.M(H + 0.05, 0.3), H + 0.05, 0.036)]
	var ctop := func(a: float) -> float: return cy0 - 0.075 * exp(-pow((absf(a) - PI * 0.5) / 0.5, 2.0))
	var cf := func(a: float, y: float, _v: float) -> float: return 0.006 * cos(a * 2.0) * smoothstep(C + 0.04, C - 0.06, y) * 0.0 + 0.004 * exp(-pow(a / 0.25, 2.0)) * smoothstep(H + 0.1, C, y)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 22, "na": 100, "top": func(a): return ctop.call(float(a)), "hem": func(_a): return H + 0.1, "fold": cf,
		"col": func(_a, y, _v): return bl.darkened(0.08 * smoothstep(C - 0.05, H + 0.1, float(y))), "gain": 6.0, "th": 0.011, "inner": bld, "skin": tsk})
	P._cord(k, cg["top"], 0.0042, bl.lightened(0.08), true, tsk)
	# omuz kayışları: göğüslüğün üst köşesinden omuzdan sırta
	for x in [0.075, -0.075]:
		P._over(k, ik, x, cy0 - 0.004, cy0 - 0.004, 0.012, 0.012, 0.004, bld.lightened(0.1))
	# bel plakası: kalın halka, üstünde bağ düğümleri
	var bk2: Array = []
	for e in ck:
		bk2.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.012, float(e[3]) - 0.012])
	L._torso_plate(k, bk2, 0.0, PI * 0.995, H + 0.115, H + 0.06, 0.0, 0.011, bl.darkened(0.04), bld, 64, 3)
	for xa in [-0.85, -0.3, 0.3, 0.85]:
		var e: Array = Q._spt(bk2, Callable(), xa, H + 0.088, 0.013)
		P._stud(k, e[0], e[1], 0.0045, bld, tsk.call(e[0]))
	# önde ve arkada plakalı etek
	AG._kusazuri(k, hp, H + 0.075, 0.0, 0.55, 3, 0.1, 0.016, 0.07, 0.07, bl, bld, bld, 0.075)
	AG._kusazuri(k, hp, H + 0.075, PI, 0.6, 2, 0.1, 0.016, 0.07, 0.07, bl, bld, bld, 0.08)
	# kürk yakalık: boynun yanlarından omuzlara yayılan üç kat, önde açık (boğaz görünür)
	var fk := [P._kp(nk, N + 0.06, 0.02), P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.05, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.036)]
	for e in [[N + 0.05, 0.0, 0.03, 0.4, 0.62], [N + 0.012, 0.016, 0.04, 1.7, 0.5], [N - 0.03, 0.026, 0.046, 3.1, 0.42], [N - 0.06, 0.02, 0.034, 4.6, 0.7]]:
		var pts := []
		var a0: float = e[4]
		for i in 48:
			var a: float = lerpf(a0, TAU - a0, float(i) / 47.0)
			var aw: float = wrapf(a, -PI, PI)
			var y: float = float(e[0]) + 0.014 * exp(-pow((absf(aw) - 1.3) / 0.5, 2.0)) + 0.006 * sin(a * 9.0 + float(e[3]))
			pts.append(Q._spt(fk, Callable(), aw, y, float(e[1]) + float(e[2]) * 0.8)[0])
		_fur_open(k, pts, float(e[2]), fu.darkened(0.05 * float(float(e[3]) > 2.0)), nsk if float(e[0]) > N - 0.01 else tsk, float(e[3]))


## Kürk rulosu (açık uçlu): tutam tutam kabarır, iki ucu incelip kapanır (önde boş halka görünmez)
static func _fur_open(k, pts: Array, R: float, col: Color, skinf: Callable, sd := 0.0) -> void:
	var nf := func(s: float, a: float) -> float:
		return 0.5 + 0.5 * sin(s * float(pts.size()) * 1.57 + a * 2.0 + 1.7 * sin(s * 41.0 + sd) + sd)
	P._tb(k, pts, func(s: float, a: float) -> float: return R * (0.72 + 0.46 * float(nf.call(s, a))) * pow(clampf(sin(clampf(s, 0.0, 1.0) * PI) * 3.0, 0.02, 1.0), 0.6), func(s: float, a: float, _p: Vector3) -> Color:
		var n: float = nf.call(s, a)
		return col.darkened(0.3 * (1.0 - n)).lightened(0.08 * n * n), func(_s: float, p: Vector3) -> Array: return skinf.call(p), 12, false)


# ------------------------------------------------------------------ Uzumaki Kamen (ref Shinobi Striker "Tobi Outfit"): mor uzun kollu iç üstüne dirsekte biten lacivert savaş ceketi (kalçaya iner, önde kanat kenarı),
## omzun dışından inen iki kat koyu omuz plakası, belde geniş koyu mor kuşak, kalçanın iki yanında sarkan koyu plaka dizisi, çeneye sarılı kalın koyu yeşil atkı
## (arkadan sırta yatıp sol baldırın arkasına inen uç), gri tam eldiven, baldır ortasında toplanan lacivert bol pantolon + beyaz bacak sargısı
static func _tobi(k) -> void:
	var nv := Color(0.141, 0.141, 0.235)
	var pu := Color(0.227, 0.165, 0.314)
	var ob := Color(0.29, 0.165, 0.314)
	var sc := Color(0.118, 0.29, 0.267)
	var gy := Color(0.416, 0.416, 0.439)
	var wh := Color(0.9, 0.89, 0.86)
	var pl := Color(0.13, 0.13, 0.19)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	P._inner(k, b, func(_i, j, _p): return pu.lightened(0.04) if j < 4 else pu, 0.006)
	K._seat(k, b, nv)
	I._seat(k, b, nv)
	# pantolon: bol, baldır ortasında toplanır; altında beyaz sargı
	var pads := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.2
		var tk: float = kn + 0.2
		pads[sd] = Q._baggy(k, le, nv, wh.darkened(0.25), 0.018, 0.034, tk, sv)
		I._shin(k, le, tk - 0.02, 9, wh)
	# ceket: kalçaya iner; sol kanat sağın üstüne biner (kenar sağ göğüsten etek ucuna)
	var hem: float = H - 0.075
	var top: float = N + 0.006
	var jk: Array = AJ._jkeys(k, b, top, hem, 0.03, 0.045)
	var jf := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.05, 0.3, absf(a + 0.3)) * (t * (0.014 * sin(a * 6.0 + 0.3) + 0.007 * sin(a * 11.0 + 1.5)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 13.0))
	var jsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)) if float(p.y) > H - 0.005 else Q._csk(k, p, hem, 0.07)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 40, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.007, "inner": nv.darkened(0.35), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	var hm := []
	for p in jg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._cord(k, hm, 0.0032, nv.darkened(0.12), true, jsk)
	Q._run(k, jk, jff, [Vector2(-0.3, top - 0.01), Vector2(-0.32, C - 0.05), Vector2(-0.33, hem + 0.004)], 0.007, 0.004, 0.0035, nv.lightened(0.04), jsk, 14)
	for sg in [1.0, -1.0]:
		Q._run(k, jk, jff, [Vector2(sg * 1.58, C - 0.05), Vector2(sg * 1.57, hem + 0.02)], 0.002, 0.0015, 0.0011, nv.darkened(0.2), jsk, 8)
	# geniş koyu mor kuşak: iki kat
	var ok := [P._kp(k.M(H + 0.11, k.UA), H + 0.11, 0.044), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.05)]
	L._sash(k, ok, H + 0.055, 0.042, 0.0, ob, 0.16, 2)
	# kalçanın iki yanında koyu plaka dizisi (kuşaktan sarkar)
	for sg in [1.0, -1.0]:
		L._tasset(k, b, {"y0": H + 0.025, "ac": sg * 1.45, "aw": 0.34, "n": 3, "h": 0.085, "ov": 0.016, "flare": 0.14, "add": 0.06, "col": pl, "trim": pl.lightened(0.12), "lace": ob.darkened(0.2), "th": 0.008})
	# kollar: mor iç kol bileğe, ceket kolu dirsekte, gri eldiven; omzun dışında iki kat koyu plaka
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		P._lt(k, ar, func(s, a): return 0.007 + 0.003 * sin(float(a) * 3.0 + float(s) * 30.0 + sv) * smoothstep(0.75, 0.85, float(s)), func(_s, _a, ins): return pu.darkened(0.3) if ins else pu, en - 0.1, 0.9, 16, 18)
		var sf: Callable = I._sleeve(k, ar, nv, 0.017, en + 0.02, sv, 0.0, 0.008)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.darkened(0.1), en - 0.012, en + 0.021, 3, 20)
		P._lt(k, ar, func(s, _a): return 0.0105 + 0.002 * smoothstep(0.86, 0.9, float(s)), func(_s, _a, ins): return gy.darkened(0.3) if ins else gy, 0.84, 0.985, 8, 18)
		Z._glove_full(k, sd, gy)
		var la: Dictionary = L._limb(k, sd, false)
		L._sode(k, la, {"s0": -0.015, "n": 2, "ln": 0.08, "ov": 0.018, "W": 0.05, "R": L._lr(la, float(la["sj"]) + 0.06) + 0.04, "curve": 2.2, "col": pl, "trim": pl.lightened(0.1), "lace": ob.darkened(0.2), "th": 0.009})
	# atkı: boynu saran kalın kat kat bez, çeneye çıkar; omuzlara yayılır
	var hq: float = Q._hq(k)
	var sk := [[N + 0.07 * hq, nk.x + 0.03, nk.y + 0.036, nk.z - 0.03], [N + 0.03 * hq, nk.x + 0.044, nk.y + 0.05, nk.z - 0.04], [N - 0.02, nk.x + 0.07, nk.y + 0.07, nk.z - 0.06], [N - 0.06, ch.x * 0.88, ch.y * 0.98 + 0.03, ch.z * 1.0 - 0.03]]
	var sf2 := func(a: float, y: float, v: float) -> float:
		return 0.06 * sin(float(v) * PI * 3.0 + cos(a) * 0.8 + 0.5) * smoothstep(0.0, 0.15, float(v)) * (1.0 - 0.6 * float(v)) + 0.01 * sin(a * 7.0 + y * 20.0)
	var sg0: Dictionary = P._cl(k, {"keys": sk, "ny": 20, "na": 64, "top": func(a): return N + hq * (0.07 - 0.012 * cos(float(a))), "hem": func(a): return N - 0.06 + 0.015 * cos(float(a)), "fold": sf2,
		"col": func(_a, _y, _v): return sc, "gain": 6.0, "th": 0.008, "inner": sc.darkened(0.3), "skin": nsk})
	P._cord(k, sg0["top"], 0.009, sc.lightened(0.03), true, nsk, 0.0, 8)
	P._cord(k, AA._yl(sg0["hem"], 0.004), 0.008, sc.darkened(0.05), true, tsk, 0.0, 8)
	# atkının ucu: ensede düğümden sırta yatar, sol kalçanın arkasından baldıra iner
	var xb: float = 0.06
	P._strap(k, jk, [Vector2(xb * 0.4, N - 0.06), Vector2(xb, C - 0.05), Vector2(xb * 1.2, H + 0.02), Vector2(xb * 1.25, hem + 0.012)], false, 0.03, 0.012, 0.005, sc.darkened(0.04), 12, jsk)


# ------------------------------------------------------------------ Tsuki Koromo (ref Shinobi Striker "Toneri Outfit"): dizin altına inen soluk zeytin beyazı cübbe (göğüs derin V açık, altında sol kanat sağın üstüne,
## koyu yüksek dik yaka, bileğe inen geniş kol), belde siyah kuşak; sağ omzun üstünden sol kalçaya verev inip önde dize sarkan haki örtü (üst kenarı kalın kıvrık rulo,
## sırtta verev bant), boyunda koyu magatama dizisi, siyah parmaksız eldiven, beyaz pantolon (diz çizmesi ayak parçası)
static func _toneri(k) -> void:
	var wh := Color(0.894, 0.886, 0.8)
	var kh := Color(0.722, 0.706, 0.541)
	var pn := Color(0.949, 0.941, 0.918)
	var dk := Color(0.13, 0.16, 0.17)
	var mg := Color(0.36, 0.3, 0.42)
	var bk := Color(0.1, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	M._inner_v(k, b, wh.darkened(0.12))
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, pn, 0.012, 0.02, 1.0, 1.4 if sd == "Left" else 2.6)
	# cübbe: göğüs V açık, altında bindirme; dizin altına iner
	var hem: float = KN - 0.07
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.04), [H - 0.04, hp.x + 0.055, hp.y + 0.075, hp.z - 0.065],
		[KN + 0.05, hp.x + 0.09, hp.y + 0.11, hp.z - 0.11], [hem, hp.x + 0.11, hp.y + 0.11, hp.z - 0.14]]
	var vt := func(y: float) -> float: return smoothstep(C - 0.16, N - 0.01, y)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var fe: float = 1.0 - 0.8 * exp(-pow((a + 0.4) / 0.12, 2.0))
		return fe * (pow(t, 0.9) * ((0.026 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y))
	var csk := func(p): return AB._lsk(k, p, hem, 0.04)
	var r: Dictionary = AG._robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": func(y): return lerpf(0.3, -0.4, float(vt.call(float(y)))), "ao": func(y): return lerpf(-0.4, 0.4, float(vt.call(float(y)))), "ff": ff,
		"col": func(_a, _y): return wh, "lin": wh.darkened(0.22), "skin": csk, "th": 0.008, "ny": 56, "na": 104, "olift": 0.008, "gain": 4.5})
	AG._edge(k, r["eb"], 0.0036, 0.002, wh.darkened(0.1), csk, 0.003)
	AG._edge(k, r["ea"].slice(0, 22), 0.0036, 0.002, wh.darkened(0.1), csk, -0.003)
	AG._edge(k, AA._yl(r["hem"], 0.01), 0.0032, 0.0016, wh.darkened(0.12), csk)
	for sg in [1.0, -1.0]:   # yan dikişler
		Q._run(k, keys, ff, [Vector2(sg * 1.6, C - 0.05), Vector2(sg * 1.58, H), Vector2(sg * 1.56, hem + 0.016)], 0.0022, 0.0014, 0.0011, wh.darkened(0.14), csk, 12)
	# siyah kuşak
	var ok: Array = []
	for e in keys.slice(2, 5):
		ok.append([e[0], float(e[1]) + 0.008, float(e[2]) + 0.008, float(e[3]) - 0.008])
	P._sash(k, ok, H + 0.075, 0.024, 0.004, bk, 0.12)
	# koyu yüksek dik yaka: önü geniş açık
	var cg: Dictionary = AJ._stand(k, nk, 0.1, 0.62, dk, dk.lightened(0.08), 0.032, 0.022)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.003, dk.lightened(0.06), false, nsk)
	# kollar: bileğe inen geniş kol, siyah parmaksız eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 2.0 if sd == "Left" else 0.8
		R._arm_skin(k, ar, 0.55)
		AA._hang_sleeve(k, ar, wh, wh.darkened(0.2), 0.02, 0.026, 0.014, 0.865, sv)
		I._cap(k, ar, wh, 0.02)
		AG._glove(k, sd, ar, bk)
	# haki örtü: sağ omuzdan sol kalçaya verev üst kenar, önde dizin üstüne sarkar
	var dkeys: Array = []
	for e in keys:
		dkeys.append([e[0], float(e[1]) + 0.014, float(e[2]) + 0.016, float(e[3]) - 0.014])
	var dtop := func(a: float) -> float:
		if a < -0.35:
			return N - 0.03 - 0.035 * smoothstep(-0.7, -1.3, a)
		return lerpf(N - 0.03, H + 0.06, smoothstep(-0.35, 1.1, a))
	var dhem: float = KN + 0.0
	var df := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - dhem), 0.0, 1.0)
		var dg: float = 0.012 * sin((a * 0.16 - (y - H)) * 34.0) * smoothstep(H - 0.05, H + 0.15, y)   # verev çekme kırışıkları
		return t * (0.024 * sin(a * 5.0 + 0.7) + 0.011 * sin(a * 9.0 + 1.3)) + dg
	var dsk := func(p): return AB._lsk(k, p, hem, 0.04)
	var dg2: Dictionary = P._cl(k, {"keys": dkeys, "ny": 40, "na": 70, "rng": func(_v): return Vector2(-1.32, 1.38), "top": func(a): return dtop.call(float(a)),
		"hem": func(a): return dhem + 0.02 * sin(float(a) * 2.0 + 0.4), "fold": df, "col": func(_a, _y, _v): return kh, "gain": 5.0, "th": 0.007, "inner": kh.darkened(0.3), "skin": dsk})
	P._cord(k, dg2["top"], 0.0095, kh.darkened(0.04), false, dsk, 0.0, 8)
	P._bd(k, AA._yl(dg2["hem"], 0.008), 0.004, 0.0016, kh.darkened(0.12), false, dsk)
	# omuzdan sırta geçen bant + sırtta verev iniş
	P._over(k, dkeys, -0.085, N - 0.04, N - 0.04, 0.03, 0.004, 0.006, kh.darkened(0.03))
	P._strap(k, dkeys, [Vector2(-0.085, N - 0.04), Vector2(-0.02, C - 0.06), Vector2(0.08, H + 0.12), Vector2(0.13, H + 0.06)], false, 0.03, 0.004, 0.006, kh.darkened(0.05), 12, tsk)
	# magatama dizisi: boyun kökünde ipe dizili koyu taneler
	var mk := [P._kp(nk, N + 0.012, 0.004, 0.006), [N - 0.06, ch.x * 0.84, ch.y * 0.82 + 0.004, ch.z * 0.9]]
	var mpts := []
	for i in 25:
		var a: float = lerpf(-0.5, 1.1, float(i) / 24.0)
		mpts.append(Q._spt(mk, Callable(), a, N - 0.012 - 0.022 * cos(a * 1.2), 0.004)[0])
	P._cord(k, mpts, 0.0018, bk, false, nsk)
	for i in 6:
		var a: float = lerpf(-0.3, 0.95, float(i) / 5.0)
		var y: float = N - 0.016 - 0.022 * cos(a * 1.2)
		var mp: Callable = Q._local(mk, Callable(), a, y)
		Q._tomoe(k, mp, Q._spt(mk, Callable(), a, y)[1], 0.0075, -PI * 0.5 + a * 0.4, 0.007, mg, nsk, mg.darkened(0.45))


# ------------------------------------------------------------------ Kaze Kodomo (ref Shinobi Striker "Temari Outfit Young Ver."): uyluk ortasına inen soluk pembe kruvaze tunik elbise (geniş kayık yaka: omuz ve boyun
## file, önde sağa kaçık kapanış kenarı + dört beyaz düğme sekmesi, eğik kıvrık etek ucu, yanlarda leylak gölgeli kırışıklar), ön kol ortasına kıvrılmış uzun kollar (sol ön kolda beyaz sargı),
## kızıl kuşak + sağ önde etek ucuna inen kuşak ucu, soluk pembe kısa şort, sol uylukta ve sağ baldırda file + koyu bant
static func _kaze_genc(k) -> void:
	var pk := Color(0.91, 0.831, 0.863)
	var lv := Color(0.74, 0.6, 0.76)
	var rd := Color(0.44, 0.14, 0.21)
	var nt := Color(0.36, 0.22, 0.28)
	var wh := Color(0.95, 0.95, 0.94)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	# ten + omuzda file (kayık yakadan boyna)
	Z._skin_torso(k, b, C - 0.06)
	var sk_k := [P._kp(b["nk"], N + 0.03, 0.004, 0.006), P._kp(b["nk"], N + 0.0, 0.007), [N - 0.045, ch.x * 0.74, ch.y * 0.82, ch.z * 0.9], [N - 0.075, ch.x * 0.86, ch.y * 0.9, ch.z * 0.95]]
	P._net_patch(k, sk_k, func(_a, _y): return true, -PI, PI, N - 0.075, N + 0.028, 0.017, 0.0013, 0.0022, nt)
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return pk.darkened(0.04))
	# bacaklar: kısa şort, ten; sol uylukta file, sağ baldırda file
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.6 if sd == "Left" else 1.7
		var s1: float = kn * 0.24
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var ad: Callable = R._short_leg(k, le, pk.darkened(0.04), s1, 0.01, 0.006, sv)
		R._hem_roll(k, le, ad, s1, pk.darkened(0.08), 0.018, 0.002)
		if sd == "Left":
			P._net_limb(k, le, s1 + 0.02, kn - 0.05, 0.0028, 8, 0.028, 0.0011, nt)
			Q._ring_on(k, le, kn - 0.05, func(_s, _a): return 0.003, 0.0085, nt.darkened(0.2), 0.0025)
		else:
			P._net_limb(k, le, kn + 0.07, 0.985, 0.0028, 8, 0.028, 0.0011, nt)
			Q._ring_on(k, le, kn + 0.075, func(_s, _a): return 0.003, 0.0085, nt.darkened(0.2), 0.0025)
	# elbise: kayık yaka, eğik etek ucu
	var hem0: float = H - 0.2
	var keys := [P._kp(k.M(N - 0.03, k.UA), N - 0.03, 0.026), [N - 0.06, ch.x * 1.02, ch.y * 0.96 + 0.012, ch.z * 1.04 - 0.012], P._kp(ch, C - 0.03, 0.026), P._kp(b["wa"], H + 0.12, 0.034),
		[H - 0.04, hp.x + 0.034, hp.y + 0.036, hp.z - 0.04], [hem0 - 0.04, hp.x + 0.06, hp.y + 0.06, hp.z - 0.066]]
	var topf := func(a: float) -> float:
		var aw: float = absf(a)
		return N - 0.05 + 0.03 * smoothstep(0.6, 1.4, aw) * (1.0 - smoothstep(1.8, 2.6, aw)) + 0.01 * smoothstep(2.4, 3.1, aw)
	var hemf := func(a: float) -> float: return hem0 + 0.028 * sin(a) + 0.005 * sin(a * 3.0 + 0.6)
	var crease := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return exp(-pow((aw - 1.0 + 0.06 * sin(y * 50.0)) / 0.09, 2.0)) * exp(-pow((y - (C - 0.06)) / 0.05, 2.0)) + 0.8 * exp(-pow((aw - 1.25) / 0.1, 2.0)) * exp(-pow((y - (H - 0.08)) / 0.04, 2.0))
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem0), 0.0, 1.0)
		return -0.02 * float(crease.call(a, y)) + t * (0.012 * sin(a * 5.0 + 0.4) + 0.006 * sin(a * 11.0 + 1.6)) + (1.0 - t) * 0.004 * sin(a * 6.0 + y * 13.0)
	var esk := func(p): return X._xsk(k, p, hem0 - 0.03)
	var eg: Dictionary = P._cl(k, {"keys": keys, "ny": 44, "na": 96, "top": func(a): return topf.call(float(a)), "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(a, y, _v): return pk.lerp(lv, clampf(float(crease.call(float(a), float(y))) * 1.2, 0.0, 0.8)), "gain": 4.0, "th": 0.007, "inner": pk.darkened(0.3), "skin": esk})
	var eff := func(a, y): return ef.call(float(a), float(y))
	# yaka kenarı: kalın kıvrık bant; etek ucu kıvrık
	P._cord(k, AA._yl(eg["top"], -0.004), 0.0065, pk.lightened(0.03), true, tsk, 0.0, 8)
	P._cord(k, AA._yl(eg["hem"], 0.007), 0.0075, pk.darkened(0.03), true, esk, 0.0, 8)
	# kanat kenarı: sağa kaçık, yakadan etek ucuna; dört beyaz sekme
	var ex: float = -0.32
	var cp := [Vector2(ex + 0.05, float(topf.call(ex)) - 0.004), Vector2(ex, C - 0.02), Vector2(ex - 0.01, H), Vector2(ex - 0.01, float(hemf.call(ex - 0.01)) + 0.012)]
	Q._run(k, keys, eff, cp, 0.009, 0.0016, 0.003, pk.darkened(0.02), esk, 14)
	Q._run(k, keys, eff, cp, 0.0012, 0.0046, 0.0008, pk.darkened(0.45), esk, 14)
	for yy in [C - 0.02, H + 0.12, H - 0.06, hem0 + 0.04]:
		var sp: Array = Q._spt(keys, eff, ex - 0.02, yy, 0.0045)
		var o: Vector3 = sp[1]
		P._boxr(k, sp[0], Vector3.UP.cross(o).normalized() * 0.0085, Vector3(0, 0.006, 0), o * 0.0025, wh, esk.call(sp[0]), 0.35)
	for sg in [1.0, -1.0]:   # yan dikiş
		Q._run(k, keys, eff, [Vector2(sg * 1.58, C - 0.05), Vector2(sg * 1.57, hem0 + 0.04)], 0.0018, 0.0014, 0.001, pk.darkened(0.14), esk, 10)
	# kızıl kuşak + sağ önde inen uç
	var by: float = H + 0.075
	var ok := [P._kp(k.M(by + 0.05, k.UA), by + 0.05, 0.04), P._kp(k.M(by - 0.05, 0.3), by - 0.05, 0.044)]
	L._sash(k, ok, by, 0.03, 0.0, rd, 0.16, 2)
	var tp := []
	var to := []
	for i in 17:
		var v: float = float(i) / 16.0
		var y: float = by - 0.01 - v * (by - hem0 - 0.0)
		var a: float = lerpf(-0.95, -1.12, v)
		var sp: Array = Q._spt(keys, eff, a, y, 0.009 + 0.004 * v)
		tp.append(sp[0])
		to.append(sp[1])
	k.strip(tp, to, 0.016, 0.004, rd.darkened(0.05), false, esk)
	var kn0: Array = Q._spt(keys, eff, -0.92, by - 0.004, 0.034)
	P._boxr(k, kn0[0], Vector3.UP.cross(kn0[1]).normalized() * 0.017, Vector3(0, 0.017, 0), (kn0[1] as Vector3) * 0.008, rd.lightened(0.04), tsk.call(kn0[0]), 0.45)
	# kollar: uzun kol ön kol ortasına kıvrılmış, kalın rulo; sol ön kolda beyaz sargı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 1.6 if sd == "Left" else 0.5
		var s1 := 0.7
		R._arm_skin(k, ar, 0.55)
		var sf: Callable = AJ._sleeve(k, ar, pk, s1, sv, 0.02, 0.014, pk.darkened(0.25))
		I._cap(k, ar, pk, 0.02)
		X._roll(k, ar, s1 - 0.075, s1 + 0.004, func(s, a): return float(sf.call(float(s), float(a))), 0.011, pk.lightened(0.02), sv)
		if sd == "Left":
			P._lt(k, ar, func(s, _a): return 0.006 - 0.002 * smoothstep(0.9, 0.96, float(s)), func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.05), s1 - 0.02, 0.955, 12, 18)
			P._wraps(k, ar, s1 + 0.02, 0.945, 8, 0.0075, 0.012, wh, 0.006)
