extends RefCounted
## Obito / Tobi maskeleri (kaynak: Narutopedia, _tmp/obitoref: o_1 / p_9 Tobi, o_2 / o_6 Kiri-Ame dönemi, p_6 Maskeli Adam,
## o_3 / p_1 savaş maskesi, p_1 / o_4 çatlayan savaş maskesi). MaskV2 çağırır.
## Hepsi başı saran kabuk (kanon: maskenin kenarında boşluk yok). Kabuk gerçek kafanın (yüz + kafatası) üstünden 3 mm payla geçer;
## Tobi'de tepe ve ense saçı açıkta (ref o_1), diğerlerinde saç tamamen kabuğun altında.
## Kabuk yüze göre kurulur: göz delikleri GERÇEK delik (oyuncunun gözü, Sharingan / Rinnegan dahil, delikten görünür),
## oluklar / halkalar kabuğa oyulmuş kabartma (boya değil), delik ve kırık kenarlarında kalınlık duvarı.
##  - spiral_maske (Tobi): turuncu yumurta kabuk, sağ gözde tek delik, delikten dışa açılan tek kollu sarmal oluk (~9 tur)
##  - shima_kamen (Kiri / Ame dönemi): sarı uzun kabuk, sağ gözde delik; deliğin çevresinde halkalar, öbür yana dalgalı yatay şeritler
##  - uzu_kamen (Kyūbi gecesi Maskeli Adam): başın önünü saran kül-kahve kabuk, delikten çıkan beş geniş kat (üst üste binen yaprak)
##  - rinne_kamen (savaş): beyaz kabuk, alın ortasında Rinnegan halkaları, iki göz deliği halkanın üstünde, deliklerde virgül kuyruğu
##  - rinne_kamen_ware: aynı maske, sol gözden yayılan çatlaklar ve kopmuş yanak parçası (sol göz ve yanak açıkta)

const STYLES := ["spiral_maske", "shima_kamen", "uzu_kamen", "rinne_kamen", "rinne_kamen_ware"]
const CACHE_MAX := 40
static var _cache := {}


static func has(s) -> bool:
	return s in STYLES


class Mk:
	var st := ""
	var sc := 1.0
	var full := true    # bütün başı saran kabuk (alt kenar çene / çene hattı / ense); false: yüzü ve yanları saran yumurta (Tobi)
	var A := 0.16       # yumurta yarı eni (harita: yay uzunluğu)
	var BT := 0.118
	var BB := 0.128
	var EGG := 0.0
	var SQ := 2.0
	var er := Vector2(-0.034, 0.0)
	var el := Vector2(0.034, 0.0)
	var holes := []
	var chunk := PackedVector2Array()
	var cracks := []
	var rc := Vector2.ZERO
	var R2 := 0.06
	var base := Color(0.96, 0.53, 0.12)
	var ink := Color(0.22, 0.09, 0.03)
	var rim := Color(0.1, 0.05, 0.03)
	# kafa zarfı (küresel): C merkez, env[j * NT + i] yarıçap
	const NT := 120
	const NP := 64
	const P0 := -1.35
	const P1 := 1.5708
	var C := Vector3.ZERO
	var env := PackedFloat32Array()
	var Rw := 0.1
	var phe := 0.0
	var yb := Vector3(-0.128, -0.112, -0.085)   # alt kenar yüksekliği: ön (çene altı), yan (çene hattı), ense

	func _init(s: String, k: float) -> void:
		st = s
		sc = k

	## göz delikleri harita koordinatında belli olunca desen / delik / kırık yerleşir
	func setup(r: Vector2, l: Vector2) -> void:
		er = r
		el = l
		var hr := 0.0105 * sc
		match st:
			"spiral_maske":
				full = false; A = 0.215 * sc; BT = 0.118 * sc; BB = 0.128 * sc; EGG = 0.0; SQ = 2.6
				holes = [[er, hr, hr]]
			"shima_kamen":
				A = 0.16 * sc
				base = Color(0.95, 0.73, 0.2); ink = Color(0.1, 0.07, 0.05); rim = Color(0.08, 0.06, 0.04)
				holes = [[er, hr, hr]]
			"uzu_kamen":
				A = 0.16 * sc
				base = Color(0.6, 0.45, 0.38); ink = Color(0.2, 0.13, 0.11); rim = Color(0.08, 0.06, 0.06)
				holes = [[er, hr * 1.05, hr * 1.05]]
			"rinne_kamen", "rinne_kamen_ware":
				A = 0.16 * sc
				base = Color(0.93, 0.92, 0.89); ink = Color(0.07, 0.06, 0.07); rim = Color(0.05, 0.05, 0.06)
				holes = [[er, hr * 1.12, hr * 0.92], [el, hr * 1.12, hr * 0.92]]
				rc = Vector2((er.x + el.x) * 0.5, (er.y + el.y) * 0.5 + 0.048 * sc)
				R2 = er.distance_to(rc)
				if st == "rinne_kamen_ware":
					var o := el
					var s2 := sc
					var V := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s2
					chunk = PackedVector2Array([V.call(0.0095, -0.004), V.call(0.017, -0.019), V.call(0.013, -0.033), V.call(0.026, -0.05), V.call(0.022, -0.068),
						V.call(0.05, -0.076), V.call(0.1, -0.062), V.call(0.1, 0.014), V.call(0.046, 0.017), V.call(0.031, 0.007), V.call(0.014, 0.009)])
					cracks = [
						[V.call(0.022, -0.068), V.call(0.018, -0.084), V.call(0.03, -0.1), V.call(0.024, -0.122), V.call(0.034, -0.15)],
						[V.call(0.026, -0.05), V.call(0.012, -0.056), V.call(0.004, -0.072), V.call(-0.01, -0.078)],
						[V.call(0.014, 0.009), V.call(0.008, 0.022), V.call(0.014, 0.034), V.call(0.002, 0.046), V.call(0.006, 0.06)],
						[V.call(0.046, 0.017), V.call(0.05, 0.034), V.call(0.042, 0.05), V.call(0.054, 0.07)],
						[er + Vector2(-0.01, -0.006) * sc, er + Vector2(-0.02, -0.014) * sc, er + Vector2(-0.024, -0.03) * sc, er + Vector2(-0.036, -0.04) * sc],
						[er + Vector2(0.004, 0.011) * sc, er + Vector2(0.0, 0.024) * sc, er + Vector2(-0.012, 0.03) * sc],
					]

	func f_out(p: Vector2) -> float:
		var ax := A * (1.0 + EGG * clampf(p.y / BT, -1.0, 1.0))
		var by := BT if p.y > 0.0 else BB
		var k := pow(pow(absf(p.x) / ax, SQ) + pow(absf(p.y) / by, SQ), 1.0 / SQ)
		return (1.0 - k) * minf(ax, by)

	func f_hole(p: Vector2, h: Array) -> float:
		var c: Vector2 = h[0]
		var q := Vector2((p.x - c.x) / float(h[1]), (p.y - c.y) / float(h[2]))
		return (q.length() - 1.0) * minf(float(h[1]), float(h[2]))

	func f_chunk(p: Vector2) -> float:
		var d := 1e9
		var n := chunk.size()
		for i in n:
			d = minf(d, _seg_d(p, chunk[i], chunk[(i + 1) % n]))
		return -d if Geometry2D.is_point_in_polygon(p, chunk) else d

	static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-10), 0.0, 1.0)
		return p.distance_to(a + ab * t)

	static func _poly_d(p: Vector2, pts: Array) -> float:
		var d := 1e9
		for i in pts.size() - 1:
			d = minf(d, _seg_d(p, pts[i], pts[i + 1]))
		return d


	# ---------------------------------------------------------------- kafa zarfı
	func dir(t: float, p: float) -> Vector3:
		return Vector3(cos(p) * sin(t), sin(p), cos(p) * cos(t))

	func rad(t: float, p: float) -> float:
		var ft := fposmod((t + PI) / TAU * NT, float(NT))
		var fp := clampf((p - P0) / (P1 - P0) * (NP - 1), 0.0, NP - 1.001)
		var i := int(ft)
		var j := int(fp)
		var i2 := (i + 1) % NT
		var a := ft - i
		var b := fp - j
		return lerpf(lerpf(env[j * NT + i], env[j * NT + i2], a), lerpf(env[(j + 1) * NT + i], env[(j + 1) * NT + i2], a), b)

	func bpos(t: float, p: float) -> Vector3:
		return C + dir(t, p) * rad(t, p)

	## Desen haritası: x = kabuk yüzeyinde ön ortadan yatay yay uzunluğu, y = model yüksekliği (önde yüze izdüşümle aynı ölçek)
	func chart(t: float, p: float) -> Vector2:
		var ft := clampf((t + PI) / TAU * NT, 0.0, NT - 1.001)
		var fp := clampf((p - P0) / (P1 - P0) * (NP - 1), 0.0, NP - 1.001)
		var i := int(ft)
		var j := int(fp)
		var a := ft - i
		var b := fp - j
		var s := lerpf(lerpf(arcs[j * NT + i], arcs[j * NT + i + 1], a), lerpf(arcs[(j + 1) * NT + i], arcs[(j + 1) * NT + i + 1], a), b)
		return Vector2(s, bpos(t, p).y)

	var arcs := PackedFloat32Array()
	var eyes3 := []   # göz merkezleri (yerel): delik tünelinin dibi
	func _arcs() -> void:
		arcs.resize(NT * NP)
		var h := NT / 2
		for j in NP:
			var p := P0 + j * (P1 - P0) / (NP - 1)
			arcs[j * NT + h] = 0.0
			for i in range(h + 1, NT):
				arcs[j * NT + i] = arcs[j * NT + i - 1] + bpos(-PI + i * TAU / NT, p).distance_to(bpos(-PI + (i - 1) * TAU / NT, p))
			for i in range(h - 1, -1, -1):
				arcs[j * NT + i] = arcs[j * NT + i + 1] - bpos(-PI + i * TAU / NT, p).distance_to(bpos(-PI + (i + 1) * TAU / NT, p))

	## Gerçek kafa (yüz mesh'i + gövde kabuğunun boyun üstü) köşelerinden yarıçap haritası; üstünden eğrilik yarıçapı R olan
	## örtü geçer (burun / kaş geniş yumuşak kabarıklık, göz çukuru köprülenir), 3 mm pay; saç hesaba girmez (kabuğun altında kalır)
	func fit_head(m, org: Vector3, eyes: Array) -> void:
		# merkez göz hizasında, kafatası ortasında: yüz yönleri yataya yakın (yukarıdan bakan merkez yüzü eğik görüp kabuğu gözün 4-5 cm önüne itiyordu)
		C = Vector3(0.0, 0.0, (m.skull_c as Vector3).z - org.z)
		var hf := PackedFloat32Array()
		hf.resize(NT * NP)
		hf.fill(-1.0)
		var add := func(q: Vector3) -> void:
			var d := q - C
			var r := d.length()
			if r < 0.02:
				return
			var t := atan2(d.x, d.z)
			var p := asin(clampf(d.y / r, -1.0, 1.0))
			var i := int((t + PI) / TAU * NT) % NT
			var j := int(roundf((p - P0) / (P1 - P0) * (NP - 1)))
			if j >= 0 and j < NP:
				hf[j * NT + i] = maxf(hf[j * NT + i], r)
		if not m._face_src.is_empty():
			var fm: Mesh = m._face_src[0]
			var fx: Transform3D = m._face_src[1]
			for si in fm.get_surface_count():
				for v in (MeshArr.get_arrays(fm, si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					add.call(fx * v - org)
		if m.body_mesh != null and m.body_mesh.mesh != null:
			var ny: float = m._bp("Neck").y + 0.035
			for v in (m._body_vs() as PackedVector3Array):
				if v.y > ny:
					add.call(v - org)
		# Pürüzsüz sert kabuk (anime maskeleri düz yumurta / kask): kafa köşelerinin üstüne gerilmiş "lastik örtü".
		# Boş yönler komşudan dolar; sonra çok kez yumuşatılıp her seferinde yüzün dışına itilir: burun / kaş / yanak / kulak
		# ayrıntısı kaybolur, kabuk yalnız en dıştaki noktalara (burun ucu, kulak, tepe) değen geniş bir kabuğa döner.
		var clear := 0.0065 * sc   # gövde gölgelendiricisinin dış çizgi kabuğu (birkaç mm şişer) de içeride kalsın
		var need := PackedFloat32Array()
		need.resize(NT * NP)
		for k in NT * NP:
			need[k] = (hf[k] + clear) if hf[k] > 0.0 else -1.0
		env = need.duplicate()
		for j in range(NP - 2, -1, -1):
			for i in NT:
				if env[j * NT + i] <= 0.0:
					env[j * NT + i] = env[(j + 1) * NT + i] if env[(j + 1) * NT + i] > 0.0 else 0.08 * sc
		for j in range(1, NP):
			for i in NT:
				if env[j * NT + i] <= 0.0:
					env[j * NT + i] = env[(j - 1) * NT + i]
		for it in 110:
			var o := env.duplicate()
			for j in NP:
				var j0 := maxi(j - 1, 0)
				var j1 := mini(j + 1, NP - 1)
				for i in NT:
					var k := j * NT + i
					o[k] = (env[j * NT + (i + NT - 1) % NT] + env[j * NT + (i + 1) % NT] + env[j0 * NT + i] + env[j1 * NT + i] + env[k] * 2.0) / 6.0
			env = o
			if it < 104:
				for k in NT * NP:
					env[k] = maxf(env[k], need[k])
		var lift := 0.0
		for k in NT * NP:
			lift = maxf(lift, need[k] - clear * 0.5 - env[k])
		for k in NT * NP:
			env[k] += maxf(lift, 0.0)
		# tepe kutbu: son satır tek yarıçap
		var top := 0.0
		for i in NT:
			top = maxf(top, env[(NP - 1) * NT + i])   # en büyüğü: ortalama tepeyi kafa derisinin içine çekiyordu
		for i in NT:
			env[(NP - 1) * NT + i] = top
		_arcs()

	## Gözün tam önündeki kabuk noktası (önden bakınca delik irisin üstünde): (t, p)
	func eye_tp(e: Vector3) -> Vector2:
		var best := Vector2.ZERO
		var bd := 1e9
		for pass_i in 2:
			var c := best
			var st2 := 0.02 if pass_i == 0 else 0.002
			var n := 40 if pass_i == 0 else 12
			for a in range(-n, n + 1):
				for b in range(-n, n + 1):
					var t := (0.0 if pass_i == 0 else c.x) + a * st2
					var p := (0.0 if pass_i == 0 else c.y) + b * st2
					var q := bpos(t, p)
					if q.z < e.z:
						continue
					var d := Vector2(q.x - e.x, q.y - e.y).length_squared()
					if d < bd:
						bd = d
						best = Vector2(t, p)
		return best

	# ---------------------------------------------------------------- parametre uzayı (u: -1..1 azimut, ön sık; v: 0..1 yükselim)
	func tu(u: float) -> float:
		return PI * (0.42 * u + 0.58 * u * u * u)

	func pv(v: float) -> float:
		return lerpf(P0 + 0.04, P1, v + 0.11 * sin(TAU * v))   # göz hizası sık

	func yedge(t: float) -> float:
		var a := absf(t) / PI
		return lerpf(yb.x, yb.y, smoothstep(0.0, 0.5, a)) if a < 0.5 else lerpf(yb.y, yb.z, smoothstep(0.5, 1.0, a))

	func fq(uv: Vector2) -> float:
		var t := tu(uv.x)
		var p := pv(uv.y)
		var q := chart(t, p)
		var v := (bpos(t, p).y - yedge(t)) if full else f_out(q)
		if cos(t) > 0.0:
			for h in holes:
				v = minf(v, f_hole(q, h))
			if not chunk.is_empty():
				v = minf(v, f_chunk(q))
		return v

	func which(uv: Vector2) -> int:
		var t := tu(uv.x)
		var p := pv(uv.y)
		var q := chart(t, p)
		var best := absf((bpos(t, p).y - yedge(t)) if full else f_out(q))
		var w := 0
		for h in holes:
			var v := absf(f_hole(q, h))
			if v < best:
				best = v
				w = 1
		if not chunk.is_empty() and absf(f_chunk(q)) < best:
			w = 2
		return w

	func project(uv: Vector2) -> Vector2:
		var e := 0.0004
		for _i in 10:
			var v := fq(uv)
			if absf(v) < 0.00002:
				break
			var g := Vector2(fq(uv + Vector2(e, 0)) - fq(uv - Vector2(e, 0)), fq(uv + Vector2(0, e)) - fq(uv - Vector2(0, e))) / (2.0 * e)
			var gg := g.length_squared()
			if gg < 1e-10:
				break
			uv -= g * (v / gg)
			uv = Vector2(clampf(uv.x, -1.0, 1.0), clampf(uv.y, 0.0, 1.0))
		return uv

	func fpos(uv: Vector2) -> Vector3:
		var t := tu(uv.x)
		var p := pv(uv.y)
		var d := dir(t, p)
		return C + d * (rad(t, p) + detail(chart(t, p)).x)

	var _wide := 1.0   # yanlarda ızgara seyrek: oluk kenarı yumuşar (tırtıklı / hareli görünmesin)
	func _gv(d: float, w: float) -> float:
		return 1.0 - smoothstep(w * 0.5 - 0.0006 * sc * _wide, w * 0.5 + 0.0012 * sc * _wide, d)

	## (yükseklik farkı, mürekkep oranı)
	func detail(p: Vector2) -> Vector2:
		var dz := 0.0
		var ik := 0.0
		_wide = 1.0 + 2.5 * smoothstep(0.07 * sc, 0.16 * sc, absf(p.x))
		match st:
			"spiral_maske":
				# tek kollu Arşimet sarmalı: delik kenarından başlar, ~9 turda kenara ulaşır (ref o_1, p_9)
				var q := p - er
				var r := q.length()
				var P := 0.0165 * sc
				var rh := 0.0105 * sc
				var ph := (r - rh) / P - atan2(q.y, q.x) / TAU
				var d := absf(ph - roundf(ph)) * P
				var g := _gv(d, 0.0028 * sc) * smoothstep(rh, rh + 0.002 * sc, r)
				var fr := ph - floorf(ph)
				dz = -0.0013 * sc * g + 0.0006 * sc * sin(PI * fr)
				ik = g
				# delik ağzı: koyu dudak
				var lip := 1.0 - smoothstep(rh + 0.0012 * sc, rh + 0.0024 * sc, r)
				ik = maxf(ik, lip)
				dz -= 0.0008 * sc * lip
			"shima_kamen":
				# deliğin çevresinde halkalar, öbür yana doğru açılıp dalgalı yatay şeritlere döner (ref o_2)
				var q := p - er
				var dxp := maxf(0.0, q.x)
				var qx := 1.0 / (1.0 + pow(dxp / (0.024 * sc), 2.0))
				var F := sqrt(pow(q.x * qx, 2.0) + q.y * q.y)
				F += 0.0034 * sc * sin(p.x / sc * 62.0 + 0.6) * smoothstep(0.0, 0.03 * sc, dxp)
				var Pst := 0.031 * sc
				var ph := (F - 0.0105 * sc) / Pst
				var fr := ph - floorf(ph)
				# koyu şerit: periyodun %42'si; uçlara (kenara) doğru incelir
				var taper := 1.0 - 0.35 * smoothstep(0.5, 1.0, absf(p.x) / A)
				var half := 0.21 * taper
				var dd := absf(fr - 0.62) * Pst
				var g := 1.0 - smoothstep(half * Pst - 0.0008 * sc * _wide, half * Pst + 0.0012 * sc * _wide, dd)
				g *= smoothstep(0.0105 * sc, 0.0125 * sc, q.length())
				dz = -0.0011 * sc * g
				ik = g
				var lip := 1.0 - smoothstep(0.0115 * sc, 0.0128 * sc, q.length())
				ik = maxf(ik, lip)
			"uzu_kamen":
				# beş geniş kat: delikten dışa logaritmik sarmal, her kat bir sonrakinin üstüne biner (ref p_6)
				var q := p - er
				var r := maxf(q.length(), 0.001)
				var rh := 0.011 * sc
				var ph := 5.0 * atan2(q.y, q.x) / TAU + 1.5 * log(r / rh)
				var fr := ph - floorf(ph)
				var w := smoothstep(rh, rh + 0.007 * sc, r)
				var step := smoothstep(0.0, 0.07, fr) * (1.0 - smoothstep(0.93, 1.0, fr))
				dz = 0.005 * sc * fr * step * w
				ik = (1.0 - smoothstep(0.04, 0.1, fr)) * w
				var lip := 1.0 - smoothstep(rh + 0.0014 * sc, rh + 0.0026 * sc, r)
				ik = maxf(ik, lip)
			"rinne_kamen", "rinne_kamen_ware":
				# alın ortasında nokta + üç Rinnegan halkası (ikincisi iki gözden geçer), tepede yarım disk (ref o_3, p_1)
				var r := p.distance_to(rc)
				var w := 0.0032 * sc
				var g := maxf(_gv(absf(r - R2 * 0.3), w), maxf(_gv(absf(r - R2), w), _gv(absf(r - R2 * 1.78), w)))
				# halkalar yüzün önünde kalır (ref o_3 / p_1): tepeye ve enseye taşmaz
				g *= (1.0 - smoothstep(0.12 * sc, 0.14 * sc, absf(p.x))) * (1.0 - smoothstep(rc.y + R2 + 0.012 * sc, rc.y + R2 + 0.024 * sc, p.y))
				g = maxf(g, 1.0 - smoothstep(0.0048 * sc, 0.0056 * sc, r))
				g = maxf(g, 1.0 - smoothstep(0.0085 * sc, 0.0095 * sc, p.distance_to(rc + Vector2(0, R2 + 0.003 * sc))))
				# göz çevresi koyu oyuk + dışa-aşağı kıvrılan virgül kuyruğu
				for e: Vector2 in [er, el]:
					var sx := signf(e.x - rc.x)
					var de: Vector2 = (p - e) / Vector2(1.12, 0.92)
					var c := 1.0 - smoothstep(0.0134 * sc, 0.0146 * sc, de.length())
					var tail := []
					for i in 7:
						var t := i / 6.0
						var a := lerpf(-0.35, -1.75, t)
						tail.append(e + Vector2(sx * cos(a) * (0.0125 + 0.006 * t), sin(a) * (0.0115 + 0.009 * t)) * sc)
					var dt := _poly_d(p, tail)
					var tw := 0.0042 * sc
					c = maxf(c, 1.0 - smoothstep(tw * 0.5, tw * 0.5 + 0.0006 * sc, dt))
					g = maxf(g, c)
				dz = -0.0011 * sc * g
				ik = g
				for cr in cracks:
					var cd := _poly_d(p, cr)
					var cg := _gv(cd, 0.0013 * sc)
					dz -= 0.0014 * sc * cg
					ik = maxf(ik, cg * 0.85)
		# ense düz: desen kulak arkasında söner (kabuğun arka dikişinde desen kopukluğu görünmesin)
		var fb := 1.0 - smoothstep(0.17 * sc, 0.21 * sc, absf(p.x))
		return Vector2(dz * fb, ik * fb)

	func _wind(mb: MB, a: int, b: int, c: int, out: Vector3) -> void:
		var pa: Vector3 = mb.verts[a]
		if (mb.verts[b] - pa).cross(mb.verts[c] - pa).dot(out) > 0.0:
			var t := b
			b = c
			c = t
		mb.idx.append(a)
		mb.idx.append(b)
		mb.idx.append(c)

	func _quad(mb: MB, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, c0: Color, c1: Color) -> void:
		var ia := _add(mb, a, out, c0)
		var ib := _add(mb, b, out, c0)
		var ic := _add(mb, c, out, c1)
		var id := _add(mb, d, out, c1)
		_wind(mb, ia, ib, ic, out)
		_wind(mb, ia, ic, id, out)

	func _add(mb: MB, p: Vector3, n: Vector3, c: Color) -> int:
		mb.verts.append(p)
		mb.normals.append(n)
		mb.colors.append(c)
		mb.uvs.append(Vector2.ZERO)
		return mb.verts.size() - 1

	func build_mesh() -> ArrayMesh:
		var nu := 180
		var nv := 124
		var N := nu * nv
		var UV := PackedVector2Array()
		UV.resize(N)
		var ins := PackedByteArray()
		ins.resize(N)
		for j in nv:
			for i in nu:
				var uv := Vector2(-1.0 + 2.0 * i / (nu - 1), float(j) / (nv - 1))
				UV[j * nu + i] = uv
				ins[j * nu + i] = 1 if fq(uv) >= 0.0 else 0
		var mb := MB.new()
		var vid := PackedInt32Array()
		vid.resize(N)
		vid.fill(-1)
		var vuv := PackedVector2Array()
		var seam := PackedByteArray()
		var vq := PackedVector2Array()
		var du := 0.0015
		for j in nv:
			for i in nu:
				var k := j * nu + i
				var uv: Vector2 = UV[k]
				var proj := false
				if ins[k] == 0:
					var near := false
					for dj in [-1, 0, 1]:
						for di in [-1, 0, 1]:
							var ii: int = i + di
							var jj: int = j + dj
							if ii >= 0 and jj >= 0 and ii < nu and jj < nv and ins[jj * nu + ii] == 1:
								near = true
					if not near:
						continue
					uv = project(uv)
					proj = true
				var P := fpos(uv)
				var n := (fpos(uv + Vector2(du, 0)) - fpos(uv - Vector2(du, 0))).cross(fpos(uv + Vector2(0, du)) - fpos(uv - Vector2(0, du)))
				if n.length_squared() < 1e-16:
					n = P - C
				n = n.normalized()
				if n.dot(P - C) < 0.0:
					n = -n
				var t := tu(uv.x)
				var ik := detail(chart(t, pv(uv.y))).y
				vid[k] = _add(mb, P, n, base.lerp(ink, clampf(ik, 0.0, 1.0)))
				vq.append(chart(t, pv(uv.y)))
				vuv.append(uv)
				seam.append(1 if not proj and (i == 0 or i == nu - 1 or j == nv - 1) else 0)
		var edges := {}
		for j in nv - 1:
			for i in nu - 1:
				var k := j * nu + i
				for t in [[k, k + 1, k + nu + 1], [k, k + nu + 1, k + nu]]:
					if ins[t[0]] + ins[t[1]] + ins[t[2]] == 0:
						continue
					var a := vid[t[0]]
					var b := vid[t[1]]
					var c := vid[t[2]]
					if a < 0 or b < 0 or c < 0:
						continue
					var pa: Vector3 = mb.verts[a]
					var pb: Vector3 = mb.verts[b]
					var pc: Vector3 = mb.verts[c]
					if (pb - pa).cross(pc - pa).length_squared() < 1e-24:
						continue
					_wind(mb, a, b, c, (pa + pb + pc) / 3.0 - C)
					for q in [[a, b, c], [b, c, a], [c, a, b]]:
						var key := Vector2i(mini(q[0], q[1]), maxi(q[0], q[1]))
						if edges.has(key):
							edges[key][0] += 1
						else:
							edges[key] = [1, q[2]]
		# iç yüz (2.5 mm): delikten / kırıktan / alt kenardan bakınca kabuğun içi koyu görünür
		var nf := mb.verts.size()
		var nidx := mb.idx.size()
		var th := 0.0025 * sc
		var inner := base.darkened(0.6)
		var bmap := PackedInt32Array()
		bmap.resize(nf)
		bmap.fill(-1)
		# yalnız ön yarı (delik / kırık / alt kenardan görünen yer); ense tarafının içi görünmez
		for v in nf:
			var qv: Vector2 = vq[v] if v < vq.size() else Vector2(9, 9)
			var nearh := false
			for h in holes:
				nearh = nearh or qv.distance_to(h[0]) < 0.032 * sc
			if nearh or (not chunk.is_empty() and f_chunk(qv) < 0.025 * sc) or ((mb.verts[v] as Vector3).y < yedge(0.0) + 0.03 * sc if full else f_out(qv) < 0.02 * sc):
				bmap[v] = _add(mb, mb.verts[v] - mb.normals[v] * th, -mb.normals[v], inner)
		for t in range(0, nidx, 3):
			var a := bmap[mb.idx[t]]
			var b := bmap[mb.idx[t + 1]]
			var c := bmap[mb.idx[t + 2]]
			if a >= 0 and b >= 0 and c >= 0:
				mb.idx.append(a)
				mb.idx.append(c)
				mb.idx.append(b)
		# kenar duvarları: kabuk kalınlığı; dış kenarda başa doğru kıvrılan kısa iki yüzlü etek
		for key in edges:
			var ed: Array = edges[key]
			if ed[0] != 1:
				continue
			if seam[key.x] == 1 and seam[key.y] == 1:
				continue
			var pa: Vector3 = mb.verts[key.x]
			var pb: Vector3 = mb.verts[key.y]
			var mid := (pa + pb) * 0.5
			var nr: Vector3 = (mb.normals[key.x] + mb.normals[key.y]).normalized()
			var out: Vector3 = mid - (mb.verts[ed[1]] as Vector3)
			out = (out - nr * out.dot(nr)).normalized()
			var w := which((vuv[key.x] + vuv[key.y]) * 0.5)
			var cc: Color = base.darkened(0.3) if w == 0 else (rim if w == 1 else base.darkened(0.22))
			var TA: Vector3 = -(mb.normals[key.x] as Vector3) * th
			var TB: Vector3 = -(mb.normals[key.y] as Vector3) * th
			if w == 1 and not eyes3.is_empty():
				# göz deliği: kabuktan göze uzanan ince kara tünel (kabuk göze çukurlaşmaz; delik dibinde göz görünür)
				var ez := 0.0
				var bd := 1e9
				for e3: Vector3 in eyes3:
					var dd := Vector2(e3.x - mid.x, e3.y - mid.y).length()
					if dd < bd:
						bd = dd
						ez = e3.z
				var za := minf(pa.z - 0.002 * sc, ez + 0.0045 * sc)
				var zb := minf(pb.z - 0.002 * sc, ez + 0.0045 * sc)
				_quad(mb, pa, pb, Vector3(pb.x, pb.y, zb), Vector3(pa.x, pa.y, za), out, rim, rim.darkened(0.5))
			else:
				_quad(mb, pa, pb, pb + TB, pa + TA, out, cc, cc.darkened(0.2))
			if w == 0:
				var bk := (C - mid).normalized() * 0.012 * sc
				_quad(mb, pa + TA, pb + TB, pb + TB + bk, pa + TA + bk, out, base.darkened(0.35), base.darkened(0.5))
				_quad(mb, pa + TA, pb + TB, pb + TB + bk, pa + TA + bk, -out, inner, inner)
		return mb.build(Props.toon())


static func build(m, s, _fg: Color) -> bool:
	if not s in STYLES:
		return false
	if s == "spiral_maske":
		return _tobi(m)
	var hc: Vector3 = m._head_center()
	var ab: AABB = m.head_ab
	var hw := clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2
	var sc := clampf(hw / 0.19, 0.85, 1.15)
	var ec: Vector3 = m.eye_center_model if m.face_mi else hc + Vector3(0, -0.03, 0.08)
	var er := ec + Vector3(-0.034, 0, 0)
	var el := ec + Vector3(0.034, 0, 0)
	var ei: Array = m.eye_iris_model
	if ei.size() == 2:
		var e0: Vector3 = ei[0]
		var e1: Vector3 = ei[1]
		er = e0 if e0.x < e1.x else e1
		el = e1 if e0.x < e1.x else e0
	var org := Vector3(hc.x, (er.y + el.y) * 0.5, hc.z)
	var key := "%s|%s|%.3f|%.3f|%.3f|%.3f" % [m._sk_key, s, sc, er.x - org.x, er.y - org.y, el.x - org.x]
	var e = _cache.get(key)
	if e == null:
		var k := Mk.new(String(s), sc)
		k.fit_head(m, org, [er - org, el - org])
		k.eyes3 = [er - org, el - org]
		if OS.has_environment("MASKDBG"):
			var worst := 0.0
			var wp := Vector3.ZERO
			var cnt := 0
			var vs: Array = []
			if not m._face_src.is_empty():
				var fm2: Mesh = m._face_src[0]
				for si in fm2.get_surface_count():
					for v in (MeshArr.get_arrays(fm2, si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
						vs.append((m._face_src[1] as Transform3D) * v - org)
			var ny2: float = m._bp("Neck").y + 0.035
			for v in (m._body_vs() as PackedVector3Array):
				if v.y > ny2:
					vs.append(v - org)
			for q in vs:
				var d3: Vector3 = q - k.C
				var r3 := d3.length()
				var ex := r3 - k.rad(atan2(d3.x, d3.z), asin(clampf(d3.y / r3, -1.0, 1.0)))
				if ex > 0.0:
					cnt += 1
					if ex > worst:
						worst = ex
						wp = q
			if m.face_mi:
				var fmx: Mesh = m.face_mi.mesh
				for si in fmx.get_surface_count():
					var hi := 0
					for v in (MeshArr.get_arrays(fmx, si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
						if ((m._face_xf as Transform3D) * v).y > org.y + 0.06:
							hi += 1
					var mt = m.face_mi.get_surface_override_material(si)
					print("OBITO YUZ yuzey %d ad %s üstte %d malzeme %s %s" % [si, fmx.surface_get_name(si), hi, str(mt), (str(mt.transparency) + " prio " + str(mt.render_priority) + " depth " + str(mt.depth_draw_mode) + " nodepth " + str(mt.no_depth_test)) if mt is BaseMaterial3D else ""])
			print("OBITO DELME %d köşe dışarıda, en çok %.4f @ %s (C %s)" % [cnt, worst, str(wp), str(k.C)])
		var tr := k.eye_tp(er - org)
		var tl := k.eye_tp(el - org)
		k.phe = (tr.y + tl.y) * 0.5
		if OS.has_environment("MASKDBG"):
			for e3 in [er - org, el - org]:
				var d3: Vector3 = e3 - k.C
				var te := atan2(d3.x, d3.z)
				var pe := asin(d3.y / d3.length())
				print("OBITO GOZ r_goz %.4f kabuk %.4f  tp %s  goz %s kabuk_on %s" % [d3.length(), k.rad(te, pe), str(Vector2(te, pe)), str(e3), str(k.bpos(tr.x, tr.y))])
		k.Rw = k.rad(0.0, k.phe)
		k.setup(k.chart(tr.x, tr.y), k.chart(tl.x, tl.y))
		var rf := k.rad(0.0, 0.0)
		var rb := k.rad(PI, 0.0)
		var rs := (k.rad(PI * 0.5, 0.0) + k.rad(-PI * 0.5, 0.0)) * 0.5
		e = [k.build_mesh(), k.full, k.C, rf, rb, rs, k.BB, k.BT]
		if OS.has_environment("MASKDBG"):
			print("OBITO MASKE %s: %d köşe, kafa yarıçapı ön %.3f arka %.3f yan %.3f" % [s, (e[0] as ArrayMesh).surface_get_array_len(0), rf, rb, rs])
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		_cache[key] = e
	m._mesh_on("Head", e[0], Transform3D(Basis.IDENTITY, org))
	if e[1]:
		# başı tamamen saran kabuk: saç kabuğun içinden taşmasın (kask / kapüşonla aynı yol)
		var clumps = CharacterModel._hair_cache.values()
		for mi in m.skel.find_children("*", "MeshInstance3D", true, false):
			if mi.name in ["VHair", "HairDangle"] or (mi.mesh != null and mi.mesh in clumps):
				mi.visible = false
	else:
		# Tobi: tepe ve ense saçı açıkta (ref o_1); maske boyunca kafa yüzeyinin dışına taşan saç kesilir
		var c3: Vector3 = org + (e[2] as Vector3)
		var rf: float = e[3]
		var rb: float = e[4]
		m.hair_mask_slab(org.y - float(e[6]) - 0.01, org.y + float(e[7]) - 0.006, Vector2(c3.x, c3.z + (rf - rb) * 0.5), float(e[5]) - 0.002, (rf + rb) * 0.5 - 0.002)
	return true


const MeshArr = preload("res://scripts/core/mesh_arr.gd")


# ====================================================================== Tobi no Kamen (baştan, sırt eşyası yöntemi)
## Ref o_1 / p_9. Ölçülmüş yüze oturan elle kurulmuş parçalar (back_v2 gibi):
##  1) kabuk: oval kubbe plaka (en = yanaklar + pay, boy = çene altı .. alnın üstü, oran ~1.28), önü burnun 8 mm önünde,
##     kenarları yanaklara kıvrılır; tek kenar derinliği ayarıyla bütün yüz kabuğun içinde kalır (yüzü İZLEMEZ, pürüzsüz)
##  2) sarmal: kabuğa oturan ayrı koyu kabartma şerit (~9 tur, deliğe doğru sıklaşır) — boya değil
##  3) delik: gözün tam önünde gerçek açıklık + göze inen kara tünel (göz delikten görünür)
const TOBI_BASE := Color(0.95, 0.5, 0.1)
const TOBI_INK := Color(0.2, 0.08, 0.03)

static func _head_pts(m, org: Vector3) -> PackedVector3Array:
	var vs := PackedVector3Array()
	if not m._face_src.is_empty():
		var fm2: Mesh = m._face_src[0]
		for si in fm2.get_surface_count():
			for v in (MeshArr.get_arrays(fm2, si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				vs.append((m._face_src[1] as Transform3D) * v - org)
	var ny2: float = m._bp("Neck").y + 0.035
	for v in (m._body_vs() as PackedVector3Array):
		if v.y > ny2:
			vs.append(v - org)
	return vs


static func _tobi(m) -> bool:
	var hc: Vector3 = m._head_center()
	var ec: Vector3 = m.eye_center_model if m.face_mi else hc + Vector3(0, -0.03, 0.08)
	var er := ec + Vector3(-0.034, 0, 0)
	var ei: Array = m.eye_iris_model
	if ei.size() == 2:
		var e0: Vector3 = ei[0]
		var e1: Vector3 = ei[1]
		er = e0 if e0.x < e1.x else e1
	var org := Vector3(hc.x, ec.y, hc.z)
	var key := "tobiN3|%s|%.3f|%.3f" % [m._sk_key, er.x - org.x, er.y - org.y]
	var e = _cache.get(key)
	if e == null:
		e = _tobi_build(_head_pts(m, org), er - org)
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		_cache[key] = e
	m._mesh_on("Head", e[0], Transform3D(Basis.IDENTITY, org))
	# saç: tepe ve ense açık (ref); yalnız maskenin önüne düşen perçem kesilir
	m.hair_mask_plane(Vector3(0, 0, 1), org + Vector3(0, 0, float(e[1])))
	return true


## Kabuk yüzeyi: oval içinde (ρ <= 1) z = ze + D·sqrt(1 - ρ²)
static func _tz(x: float, y: float, a: float, b: float, yc: float, ze: float, D: float) -> float:
	var r2 := pow(x / a, 2) + pow((y - yc) / b, 2)
	var k := clampf((absf(x) / a - 0.62) / 0.38, 0.0, 1.0)   # yan kenarlar yanağa doğru geri kıvrılır (çapraz bakışta ten boşluğu kalmaz)
	return ze + D * sqrt(maxf(0.0, 1.0 - r2)) - 0.034 * k * k


static func _tobi_build(pts: PackedVector3Array, eye: Vector3) -> Array:
	# --- yüz ölçüsü
	var chin := 9.0
	var cheek := 0.0
	var nose := -9.0
	for q in pts:
		if q.z > 0.04 and absf(q.x) < 0.03:
			chin = minf(chin, q.y)
		if absf(q.y) < 0.04 and q.z > 0.0:
			cheek = maxf(cheek, absf(q.x))
		if absf(q.x) < 0.03 and absf(q.y) < 0.06:
			nose = maxf(nose, q.z)
	var a := cheek + 0.017
	var y0 := chin - 0.006
	var y1 := y0 + a * 2.0 * 1.28
	var b := (y1 - y0) * 0.5
	var yc := (y0 + y1) * 0.5
	var front := nose + 0.008
	# kubbe derinliği D: ön sabitken kenara yakın yüz noktaları (yanak, alın, çene) kabuğun içinde kalsın diye D KÜÇÜLÜR
	# (front - D(1-s) >= q.z + pay); çok küçülürse (< 1.4 cm) D sabitlenip ön ileri alınır
	var D := 0.06
	for q in pts:
		var r2 := pow(q.x / a, 2) + pow((q.y - yc) / b, 2)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		var s := sqrt(1.0 - r2)
		if s < 0.999:
			D = minf(D, (front - q.z - 0.005) / (1.0 - s))
	D = maxf(D, 0.014)
	for q in pts:
		var r2 := pow(q.x / a, 2) + pow((q.y - yc) / b, 2)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		front = maxf(front, q.z + 0.005 + D * (1.0 - sqrt(1.0 - r2)))
	var ze := front - D
	var lift := 0.0   # kıvrık kenar yüzü delmesin: gerekirse bütün kabuk öne
	for q in pts:
		var r2 := pow(q.x / a, 2) + pow((q.y - yc) / b, 2)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		lift = maxf(lift, q.z + 0.005 - _tz(q.x, q.y, a, b, yc, ze, D))
	ze += lift
	var hole_r := 0.0105
	var mb := SurfaceTool.new()
	mb.begin(Mesh.PRIMITIVE_TRIANGLES)
	# --- 1) kabuk: oval ızgara (kutupsal, kenarda sık), dış + iç yüz + kenar duvarı; delik hücreleri boş
	var NR := 46
	var NA := 120
	var thick := 0.0035
	var grid := []
	for ri in NR + 1:
		var row := []
		var rr := float(ri) / NR
		for ai in NA:
			var ang := TAU * ai / NA
			var x := a * rr * cos(ang)
			var y := yc + b * rr * sin(ang)
			row.append(Vector3(x, y, _tz(x, y, a, b, yc, ze, D)))
		grid.append(row)
	var inner := TOBI_BASE.darkened(0.6)
	var hx := Vector2(eye.x, eye.y)
	for ri in NR:
		for ai in NA:
			var a2 := (ai + 1) % NA
			var p00: Vector3 = grid[ri][ai]
			var p01: Vector3 = grid[ri][a2]
			var p10: Vector3 = grid[ri + 1][ai]
			var p11: Vector3 = grid[ri + 1][a2]
			var cen := (p00 + p01 + p10 + p11) * 0.25
			if Vector2(cen.x, cen.y).distance_to(hx) < hole_r:
				continue
			_tq(mb, p00, p01, p11, p10, TOBI_BASE, Vector3(0, 0, 1))
			var o := Vector3(0, 0, -thick)
			_tq(mb, p00 + o, p10 + o, p11 + o, p01 + o, inner, Vector3(0, 0, -1))
	# dış kenar duvarı
	for ai in NA:
		var a2 := (ai + 1) % NA
		var q0: Vector3 = grid[NR][ai]
		var q1: Vector3 = grid[NR][a2]
		var o := Vector3(0, 0, -thick)
		_tq(mb, q0, q0 + o, q1 + o, q1, TOBI_INK, Vector3(q0.x, q0.y - yc, 0))
	# --- 3) delik: gerçek açıklık + göze inen kara tünel
	var hz := _tz(hx.x, hx.y, a, b, yc, ze, D)
	for k in 28:
		var t0 := TAU * k / 28.0
		var t1 := TAU * (k + 1) / 28.0
		var c0 := Vector3(cos(t0), sin(t0), 0) * hole_r * 1.15
		var c1 := Vector3(cos(t1), sin(t1), 0) * hole_r * 1.15
		var base := Vector3(hx.x, hx.y, 0)
		var f0 := base + c0
		f0.z = _tz(f0.x, f0.y, a, b, yc, ze, D) + 0.0005
		var f1 := base + c1
		f1.z = _tz(f1.x, f1.y, a, b, yc, ze, D) + 0.0005
		var bz := eye.z + 0.003
		var b0 := base + c0 * 0.92
		b0.z = bz
		var b1 := base + c1 * 0.92
		b1.z = bz
		_tq(mb, f0, f1, b1, b0, Color(0.03, 0.02, 0.02), -c0)
	# --- 2) sarmal kabartma şerit (deliğin çevresinden dışa, ~9 tur, içte sık)
	var turns := 9.0
	var rmax := maxf(a, b) * 1.25
	var steps := 1400
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var have_prev := false
	for k in steps + 1:
		var t := float(k) / steps
		var ang := -TAU * turns * t
		var r := hole_r * 1.25 + (rmax - hole_r * 1.25) * pow(t, 1.18)   # içte sık
		var p2 := hx + Vector2(cos(ang), sin(ang)) * r
		var r2 := pow(p2.x / a, 2) + pow((p2.y - yc) / b, 2)
		if r2 > 0.985:
			have_prev = false
			continue
		var w := lerpf(0.0034, 0.0022, t) * 0.5
		var tg := Vector2(-sin(ang), cos(ang))
		var nrm := Vector2(tg.y, -tg.x)
		var pl := p2 + nrm * w
		var pr := p2 - nrm * w
		var l3 := Vector3(pl.x, pl.y, _tz(pl.x, pl.y, a, b, yc, ze, D) + 0.0007)
		var r3 := Vector3(pr.x, pr.y, _tz(pr.x, pr.y, a, b, yc, ze, D) + 0.0007)
		if have_prev:
			_tq(mb, prev_l, l3, r3, prev_r, TOBI_INK, Vector3(0, 0, 1))
		prev_l = l3
		prev_r = r3
		have_prev = true
	mb.generate_normals()
	var mesh := mb.commit()
	mesh.surface_set_material(0, Props.toon())
	return [mesh, ze + 0.004]


## Dörtgen: n yönüne bakan yüz (Godot ön yüz saat yönü)
static func _tq(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, n: Vector3) -> void:
	var fn := (p1 - p0).cross(p2 - p0)
	if fn.dot(n) > 0.0:   # saat yönünün tersi -> çevir
		var t := p1
		p1 = p3
		p3 = t
	st.set_color(col)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)


static func _tri_c(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, c0: Color, c1: Color, c2: Color, ctr: Vector3, flip := false, any := false, uv := []) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	var outw := ((p0 + p1 + p2) / 3.0 - ctr)
	var face_out := n.dot(outw) < 0.0   # Godot: saat yönü ön yüz
	if any:
		face_out = true
	var want_out := not flip
	if not any and face_out != want_out:
		var t := p1
		p1 = p2
		p2 = t
		var tc := c1
		c1 = c2
		c2 = tc
		if uv.size() == 3:
			uv = [uv[0], uv[2], uv[1]]
	var u0: Vector2 = uv[0] if uv.size() == 3 else Vector2(0.002, 0.002)   # dokunun köşesi düz beyaz: köşe rengi geçer
	var u1: Vector2 = uv[1] if uv.size() == 3 else Vector2(0.002, 0.002)
	var u2: Vector2 = uv[2] if uv.size() == 3 else Vector2(0.002, 0.002)
	st.set_color(c0); st.set_uv(u0); st.add_vertex(p0)
	st.set_color(c1); st.set_uv(u1); st.add_vertex(p1)
	st.set_color(c2); st.set_uv(u2); st.add_vertex(p2)
