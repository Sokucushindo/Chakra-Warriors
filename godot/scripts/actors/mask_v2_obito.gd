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
	if s == "shima_kamen":
		return _tobi(m, "shima")
	if s == "uzu_kamen":
		return _cap(m, s)
	if s in ["rinne_kamen", "rinne_kamen_ware"]:
		# 2026-11-27: kafayı saran kabuk oyunda "yumurta" gibi duruyordu; Rinne bir YÜZ maskesi (ref: önü kapatan kapsül plaka) —
		# beğenilen plaka sürümü (kapsül dış hat, ölçülen yanak / çene / kafa tepesi, halkalar, çerçeveli gözler)
		return _tobi(m, "rinne_ware" if s == "rinne_kamen_ware" else "rinne")
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


static func _tobi(m, kind := "tobi") -> bool:
	var hc: Vector3 = m._head_center()
	var ec: Vector3 = m.eye_center_model if m.face_mi else hc + Vector3(0, -0.03, 0.08)
	var er := ec + Vector3(-0.034, 0, 0)
	var el := ec + Vector3(0.034, 0, 0)
	var ei: Array = m.eye_iris_model
	if ei.size() == 2:
		var e0: Vector3 = ei[0]
		var e1: Vector3 = ei[1]
		er = e0 if e0.x < e1.x else e1
		el = e1 if e0.x < e1.x else e0
	var org := Vector3(hc.x, ec.y, hc.z)
	var key := "%sN5|%s|%.3f|%.3f|%.3f" % [kind, m._sk_key, er.x - org.x, er.y - org.y, el.x - org.x]
	var e = _cache.get(key)
	if e == null:
		e = _tobi_build(_head_pts(m, org), er - org, kind, el - org)
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		_cache[key] = e
	m._mesh_on("Head", e[0], Transform3D(Basis.IDENTITY, org))
	# saç: tepe ve ense açık (ref); yalnız maskenin önüne düşen perçem kesilir
	m.hair_mask_plane(Vector3(0, 0, 1), org + Vector3(0, 0, float(e[1])))
	return true


## Plaka dış hattı üssü: 2 = oval (Tobi / Shima), Rinne'de >2 = yanları dik kapsül (ref crops1 #3)
static var _pe := 2.0


## Çeneye doğru daralma (Rinne, ref: alt yarı yuvarlakça incelir; düz kapsül çenede kaba duruyordu): alt yarıda genişlik çarpanı
static var _taper := 0.0


static func _aw(a: float, y: float, b: float, yc: float) -> float:
	if _taper <= 0.0 or y >= yc:
		return a
	var u := clampf((yc - y) / b, 0.0, 1.0)
	return a * (1.0 - _taper * pow(u, 1.6))


static func _rho2(x: float, y: float, a: float, b: float, yc: float) -> float:
	return pow(absf(x / _aw(a, y, b, yc)), _pe) + pow(absf((y - yc) / b), _pe)


## Kabuk yüzeyi: oval içinde (ρ <= 1) z = ze + D·sqrt(1 - ρ²)
static func _tz(x: float, y: float, a: float, b: float, yc: float, ze: float, D: float) -> float:
	var r2 := _rho2(x, y, a, b, yc)
	var k := clampf((absf(x) / _aw(a, y, b, yc) - 0.62) / 0.38, 0.0, 1.0)   # yan kenarlar yanağa doğru geri kıvrılır (çapraz bakışta ten boşluğu kalmaz)
	return ze + D * sqrt(maxf(0.0, 1.0 - r2)) - 0.034 * k * k


static func _tobi_build(pts: PackedVector3Array, eye: Vector3, kind := "tobi", eye2 := Vector3.ZERO) -> Array:
	var rinne := kind.begins_with("rinne")
	var BASE := TOBI_BASE if kind == "tobi" else (RINNE_BASE if rinne else SHIMA_BASE)
	var INK := TOBI_INK if kind == "tobi" else (RINNE_INK if rinne else SHIMA_INK)
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
	var top := -9.0
	if rinne:
		# 2026-11-26 "yumurta gibi, küçült": yanak = yüzün önündeki en geniş yer (kulak değil), pay ince; üst kenar kafa tepesinde
		cheek = 0.0
		for q in pts:
			if absf(q.y) < 0.04 and q.z > 0.03:
				cheek = maxf(cheek, absf(q.x))
			if q.z > -0.02:
				top = maxf(top, q.y)
		a = cheek + 0.006
		y0 = chin - 0.004
		_pe = 2.6
		_taper = 0.24
	var y1 := y0 + a * 2.0 * (1.28 if kind == "tobi" else 1.36)   # Shima (ref o_2) biraz daha uzun
	# Rinne (ref crops1/crops2): halka merkezi gözlerin üstünde; dış halka gözlerden geçer; tepe noktası plakanın üst ucunda
	var rc := Vector2.ZERO
	var ring_r := 0.0
	if rinne:
		y1 = top + 0.006
		var dx := absf(eye2.x - eye.x) * 0.5
		var ey := (eye.y + eye2.y) * 0.5
		var f := 1.7   # halka merkezi gözlerin ne kadar üstünde: tepe noktası plakaya sığana dek küçülür
		while f > 0.9 and ey + dx * f + dx * sqrt(1.0 + f * f) * 1.2 > y1:
			f -= 0.05
		rc = Vector2((eye.x + eye2.x) * 0.5, ey + dx * f)
		ring_r = dx * sqrt(1.0 + f * f)
	var b := (y1 - y0) * 0.5
	var yc := (y0 + y1) * 0.5
	var front := nose + 0.008
	# kubbe derinliği D: ön sabitken kenara yakın yüz noktaları (yanak, alın, çene) kabuğun içinde kalsın diye D KÜÇÜLÜR
	# (front - D(1-s) >= q.z + pay); çok küçülürse (< 1.4 cm) D sabitlenip ön ileri alınır
	var D := 0.06
	for q in pts:
		var r2 := _rho2(q.x, q.y, a, b, yc)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		var s := sqrt(1.0 - r2)
		if s < 0.999:
			D = minf(D, (front - q.z - 0.005) / (1.0 - s))
	D = maxf(D, 0.014)
	for q in pts:
		var r2 := _rho2(q.x, q.y, a, b, yc)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		front = maxf(front, q.z + 0.005 + D * (1.0 - sqrt(1.0 - r2)))
	var ze := front - D
	var lift := 0.0   # kıvrık kenar yüzü delmesin: gerekirse bütün kabuk öne
	for q in pts:
		var r2 := _rho2(q.x, q.y, a, b, yc)
		if r2 >= 1.0 or q.z < 0.0:
			continue
		lift = maxf(lift, q.z + 0.005 - _tz(q.x, q.y, a, b, yc, ze, D))
	ze += lift
	var hole_r := 0.0105
	var hole_ar := 1.0
	var holes: Array = [Vector2(eye.x, eye.y)]
	var hole_z: Array = [eye.z]
	if rinne:
		hole_r = 0.0108
		hole_ar = 1.28   # göz biçimi yatık oval (ref), kara çerçeveli
		holes.append(Vector2(eye2.x, eye2.y))
		hole_z.append(eye2.z)
	var chunk := PackedVector2Array()   # çatlak sürüm: sol gözün çevresinden kopmuş parça (göz ve yanak açıkta)
	var cracks: Array = []
	if kind == "rinne_ware":
		var o := Vector2(eye2.x, eye2.y)
		chunk = PackedVector2Array([o + Vector2(-0.012, 0.012), o + Vector2(-0.004, -0.006), o + Vector2(-0.008, -0.024), o + Vector2(0.004, -0.04),
			o + Vector2(0.024, -0.05), o + Vector2(0.05, -0.036), o + Vector2(0.06, 0.004), o + Vector2(0.044, 0.026), o + Vector2(0.02, 0.03), o + Vector2(0.004, 0.022)])
		cracks = [[o + Vector2(-0.012, 0.012), o + Vector2(-0.024, 0.026), o + Vector2(-0.02, 0.044), o + Vector2(-0.034, 0.062), o + Vector2(-0.03, 0.08)],
			[o + Vector2(0.044, 0.026), o + Vector2(0.05, 0.05), o + Vector2(0.042, 0.072), o + Vector2(0.054, 0.1)],
			[o + Vector2(0.004, -0.04), o + Vector2(-0.012, -0.054), o + Vector2(-0.01, -0.072), o + Vector2(-0.03, -0.086)],
			[o + Vector2(0.024, -0.05), o + Vector2(0.03, -0.07), o + Vector2(0.022, -0.09)],
			[Vector2(eye.x, eye.y) + Vector2(0.012, 0.01), Vector2(eye.x, eye.y) + Vector2(0.022, 0.026), Vector2(eye.x, eye.y) + Vector2(0.018, 0.044)]]
	var in_hole := func(p: Vector2, k := 1.0) -> bool:
		for h in holes:
			var d: Vector2 = p - h
			if pow(d.x / (hole_r * hole_ar * k), 2) + pow(d.y / (hole_r * k), 2) < 1.0:
				return true
		return false
	var in_chunk := func(p: Vector2) -> bool:
		return not chunk.is_empty() and Geometry2D.is_point_in_polygon(p, chunk)
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
			var y := yc + b * rr * signf(sin(ang)) * pow(absf(sin(ang)), 2.0 / _pe)
			var x := _aw(a, y, b, yc) * rr * signf(cos(ang)) * pow(absf(cos(ang)), 2.0 / _pe)
			row.append(Vector3(x, y, _tz(x, y, a, b, yc, ze, D)))
		grid.append(row)
	var inner := BASE.darkened(0.6)
	var hx := Vector2(eye.x, eye.y)
	for ri in NR:
		for ai in NA:
			var a2 := (ai + 1) % NA
			var p00: Vector3 = grid[ri][ai]
			var p01: Vector3 = grid[ri][a2]
			var p10: Vector3 = grid[ri + 1][ai]
			var p11: Vector3 = grid[ri + 1][a2]
			var cen := (p00 + p01 + p10 + p11) * 0.25
			if in_hole.call(Vector2(cen.x, cen.y)) or in_chunk.call(Vector2(cen.x, cen.y)):
				continue
			if rinne and (in_hole.call(Vector2(p00.x, p00.y)) or in_hole.call(Vector2(p01.x, p01.y)) or in_hole.call(Vector2(p10.x, p10.y)) or in_hole.call(Vector2(p11.x, p11.y))):
				continue   # delik kenarında diş kalmasın (dış kenarı kara çerçeve örter)
			_tq(mb, p00, p01, p11, p10, BASE, Vector3(0, 0, 1))
			var o := Vector3(0, 0, -thick)
			_tq(mb, p00 + o, p10 + o, p11 + o, p01 + o, inner, Vector3(0, 0, -1))
	# dış kenar duvarı
	for ai in NA:
		var a2 := (ai + 1) % NA
		var q0: Vector3 = grid[NR][ai]
		var q1: Vector3 = grid[NR][a2]
		var o := Vector3(0, 0, -thick)
		_tq(mb, q0, q0 + o, q1 + o, q1, INK, Vector3(q0.x, q0.y - yc, 0))
	# --- 3) delik: gerçek açıklık + göze inen kara tünel
	for hi in holes.size():
		var hh: Vector2 = holes[hi]
		for k in 28:
			var t0 := TAU * k / 28.0
			var t1 := TAU * (k + 1) / 28.0
			var c0 := Vector3(cos(t0) * hole_ar, sin(t0), 0) * hole_r * (1.0 if rinne else 1.15)
			var c1 := Vector3(cos(t1) * hole_ar, sin(t1), 0) * hole_r * (1.0 if rinne else 1.15)
			var base := Vector3(hh.x, hh.y, 0)
			var f0 := base + c0
			f0.z = _tz(f0.x, f0.y, a, b, yc, ze, D) + 0.0005
			var f1 := base + c1
			f1.z = _tz(f1.x, f1.y, a, b, yc, ze, D) + 0.0005
			var bz: float = float(hole_z[hi]) + 0.003
			var b0 := base + c0 * 0.92
			b0.z = bz
			var b1 := base + c1 * 0.92
			b1.z = bz
			_tq(mb, f0, f1, b1, b0, Color(0.03, 0.02, 0.02), -c0)
	if rinne:
		_rinne_ink(mb, rc, ring_r, holes, hole_r, hole_ar, cracks, in_hole, in_chunk, a, b, yc, ze, D, INK, y1)
		mb.generate_normals()
		var meshr := mb.commit()
		meshr.surface_set_material(0, Props.toon())
		_pe = 2.0
		_taper = 0.0
		return [meshr, ze + 0.004]
	if kind == "shima":
		_shima_rings(mb, hx, hole_r, a, b, yc, ze, D, INK)
		mb.generate_normals()
		var meshs := mb.commit()
		meshs.surface_set_material(0, Props.toon())
		return [meshs, ze + 0.004]
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
		var r2 := _rho2(p2.x, p2.y, a, b, yc)
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
			_tq(mb, prev_l, l3, r3, prev_r, INK, Vector3(0, 0, 1))
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


# ====================================================================== Shima / Uzu / Rinne (2026-11-26, Tobi yöntemiyle)
## Ref crops1/crops2 (_tmp/obitoref): Shima = Tobi gibi yüz plakası (üstte saç açık), sarı; delik sağ gözde, çevresinde halkalar,
## öbür yana yayılan dalgalı yatay kara şeritler. Uzu = bütün kafayı saran kül-kahve kask; delikten dışa sarmallanan, üst üste binen
## beş kabarık kat. Rinne = önü ve tepeyi saran beyaz kabuk (ense saçı ve bağ açıkta); alında Rinnegan halkaları, iki göz deliği
## halkanın üstünde (virgül kuyruklu), altta yatay yay; çatlak sürümde sol gözden çatlaklar ve kopmuş yanak parçası.
const SHIMA_BASE := Color(0.95, 0.72, 0.18)
const SHIMA_INK := Color(0.2, 0.1, 0.03)
const UZU_BASE := Color(0.74, 0.69, 0.6)
const UZU_INK := Color(0.16, 0.13, 0.11)
const RINNE_BASE := Color(0.93, 0.92, 0.89)
const RINNE_INK := Color(0.06, 0.05, 0.06)


## Shima: deliğin çevresinde halkalar; uzak yana doğru yassılaşıp dalgalı yatay şeritlere dönen eş-uzaklık çizgileri (kabartma şerit)
static func _shima_rings(mb: SurfaceTool, hx: Vector2, hole_r: float, a: float, b: float, yc: float, ze: float, D: float, ink: Color) -> void:
	var far_s := -signf(hx.x) if absf(hx.x) > 0.001 else 1.0   # deliğin karşı yanı
	var f := func(p: Vector2) -> float:
		var d := p - hx
		var t := clampf(d.x * far_s / (a * 1.5), 0.0, 1.0)
		var kx := lerpf(1.0, 0.12, t * t * (3.0 - 2.0 * t))   # güçlü yassılma: göz çevresinde 2 kapalı halka, ötesi kenara uzanan şerit (ok ucu gibi kapanmaz)
		return sqrt(pow(d.x * kx, 2) + d.y * d.y)
	var spacing := 0.0175
	for li in 10:
		var L := hole_r * 1.75 + li * spacing
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var have := false
		var N := 260
		var pts2: Array = []
		if li < 2:   # göz çevresindeki kapalı halkalar (tam daire; yassılma onları "C" gibi açıyordu)
			for k in N + 1:
				var th := TAU * k / N
				pts2.append(hx + Vector2(cos(th), sin(th)) * L)
		else:
			# ref: göz yanında yarım daire, iki kolu karşı kenara kadar uzanan dalgalı yatay şerit (ışınla örnekleme kenarda nokta
			# kaçırıp şeritleri yarıda bırakıyordu): üst kol kenardan göze, gözün arkasında yarım daire, alt kol gözden kenara
			var wav := func(x: float) -> float:
				return 0.0028 * sin(x * 70.0 + li * 1.7) * clampf(float(li - 1) / 2.0, 0.0, 1.0)
			var reach := a * 2.2
			var M := 90
			var upper: Array = []
			var lower: Array = []
			for k in M + 1:
				var dx := reach * float(k) / M
				var t := clampf(dx / (a * 1.5), 0.0, 1.0)
				var kx := lerpf(1.0, 0.12, t * t * (3.0 - 2.0 * t))
				var q := L * L - pow(dx * kx, 2)
				if q < 0.0:
					break
				var dy := sqrt(q)
				var x := hx.x + far_s * dx
				upper.append(Vector2(x, hx.y + dy + wav.call(x)))
				lower.append(Vector2(x, hx.y - dy + wav.call(x)))
			upper.reverse()
			pts2.append_array(upper)
			for k in range(1, 40):
				var th := PI * 0.5 + PI * float(k) / 40.0   # gözün arka yanı (uzak tarafın tersi)
				pts2.append(hx + Vector2(far_s * cos(th), sin(th)) * L)
			pts2.append_array(lower)
		# 2026-11-27 "yarım kalmış çizgiler": şerit plakanın dış hattına kadar uzanır (0.975'te, kenar kıvrımından önce bitiyordu);
		# plaka içinde kalan parçalar ayrı ayrı çizilir, kenarda kalan kısa kırıntılar (< 7 nokta) atılır
		var segs: Array = []
		var cur: Array = []
		var N2 := pts2.size()
		var start := 0
		for k in N2:   # halka kapalı: dışarıda kalan bir noktadan başla ki içerideki parça ikiye bölünmesin
			if _rho2((pts2[k] as Vector2).x, (pts2[k] as Vector2).y, a, b, yc) > 0.997:
				start = k
				break
		for kk in N2 + 1:
			var p3: Vector2 = pts2[(start + kk) % N2]
			if _rho2(p3.x, p3.y, a, b, yc) > 0.997:
				if cur.size() >= 12:
					segs.append(cur)
				cur = []
			else:
				cur.append(p3)
		if cur.size() >= 12:
			segs.append(cur)
		pts2 = []
		for sg in segs:
			var rim := 0.0   # kenara yapışık parça (dış halkanın plaka kenarını takip eden kesik dikey çizgisi) atılır
			for q in sg:
				rim += _rho2((q as Vector2).x, (q as Vector2).y, a, b, yc)
			if rim / sg.size() > 0.86:
				continue
			pts2.append_array(sg)
			pts2.append(Vector2.INF)   # parça sonu
		for k in pts2.size():
			var p2: Vector2 = pts2[k]
			if p2 == Vector2.INF:
				have = false
				continue
			var q2: Vector2 = pts2[mini(k + 1, pts2.size() - 1)]
			if q2 == Vector2.INF:
				q2 = p2 + (p2 - (pts2[maxi(k - 1, 0)] as Vector2))
			var tg := (q2 - p2).normalized() if q2 != p2 else Vector2.RIGHT
			var nrm := Vector2(tg.y, -tg.x)
			var w := 0.0033
			var pl := p2 + nrm * w
			var pr := p2 - nrm * w
			var l3 := Vector3(pl.x, pl.y, _tz(pl.x, pl.y, a, b, yc, ze, D) + 0.0007)
			var r3 := Vector3(pr.x, pr.y, _tz(pr.x, pr.y, a, b, yc, ze, D) + 0.0007)
			if have:
				_tq(mb, prev_l, l3, r3, prev_r, ink, Vector3(0, 0, 1))
			prev_l = l3
			prev_r = r3
			have = true


## Plaka üstüne kabartma mürekkep şerit (nokta dizisi, uçta incelme isteğe bağlı); delik / kopuk parça / plaka dışı atlanır
static func _pstrip(mb: SurfaceTool, cpts: Array, w0: float, w1: float, a: float, b: float, yc: float, ze: float, D: float, ink: Color, skip: Callable, zf := Callable()) -> void:
	var n := cpts.size()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var have := false
	for k in n:
		var p2: Vector2 = cpts[k]
		if (not zf.is_valid() and _rho2(p2.x, p2.y, a, b, yc) > 0.965) or skip.call(p2):
			have = false
			continue
		var q0: Vector2 = cpts[maxi(k - 1, 0)]
		var q1: Vector2 = cpts[mini(k + 1, n - 1)]
		var tg := (q1 - q0).normalized() if q1 != q0 else Vector2.RIGHT
		var nrm := Vector2(tg.y, -tg.x)
		var w := lerpf(w0, w1, float(k) / maxf(1.0, n - 1.0))
		var pl := p2 + nrm * w
		var pr := p2 - nrm * w
		var l3 := Vector3(pl.x, pl.y, (float(zf.call(pl)) if zf.is_valid() else _tz(pl.x, pl.y, a, b, yc, ze, D)) + 0.0007)
		var r3 := Vector3(pr.x, pr.y, (float(zf.call(pr)) if zf.is_valid() else _tz(pr.x, pr.y, a, b, yc, ze, D)) + 0.0007)
		if have:
			_tq(mb, prev_l, l3, r3, prev_r, ink, Vector3(0, 0, 1))
		prev_l = l3
		prev_r = r3
		have = true


## Rinne deseni (ref crops1 #3, crops2 #1): ortak merkezli üç halka (iç halkanın ortası dolu nokta, dış halka gözlerden geçer;
## plaka dışına taşan kısmı görünmez), tepede dolu nokta, ağız hizasında geniş yay, gözlerin dış-altından kıvrılan virgül kuyrukları
static func _rinne_ink(mb: SurfaceTool, rc: Vector2, r3: float, holes: Array, hole_r: float, hole_ar: float, cracks: Array,
		in_hole: Callable, in_chunk: Callable, a: float, b: float, yc: float, ze: float, D: float, ink: Color, ytop: float, zf := Callable()) -> void:
	var skip := func(p: Vector2) -> bool:
		return in_hole.call(p, 1.18) or in_chunk.call(p)
	var circ := func(c: Vector2, r: float, t0: float, t1: float, n: int) -> Array:
		var out: Array = []
		for k in n + 1:
			var t := lerpf(t0, t1, float(k) / n)
			out.append(c + Vector2(cos(t), sin(t)) * r)
		return out
	# göz deliği kara çerçevesi (k 1.0 -> 1.42 dolu halka)
	for h in holes:
		var hp: Vector2 = h
		var ring: Array = []
		for k in 49:
			var t := TAU * k / 48.0
			ring.append(hp + Vector2(cos(t) * hole_ar, sin(t)) * hole_r * 1.2)
		_pstrip(mb, ring, hole_r * 0.22, hole_r * 0.22, a, b, yc, ze, D, ink, in_chunk, zf)
	var w := 0.0019
	_pstrip(mb, circ.call(rc, r3 * 0.27, 0.0, TAU, 72), w, w, a, b, yc, ze, D, ink, skip, zf)
	_pstrip(mb, circ.call(rc, r3 * 0.55, 0.0, TAU, 120), w, w, a, b, yc, ze, D, ink, skip, zf)
	_pstrip(mb, circ.call(rc, r3, 0.0, TAU, 200), w, w, a, b, yc, ze, D, ink, skip, zf)
	_pstrip(mb, circ.call(rc, r3 * 1.75, deg_to_rad(232.0), deg_to_rad(308.0), 120), w, w, a, b, yc, ze, D, ink, skip, zf)
	# dolu noktalar: iç içe halkalarla doldur
	for dot in [[rc, r3 * 0.075], [Vector2(rc.x, minf(rc.y + r3 * 1.18, ytop - r3 * 0.15)), r3 * 0.1]]:
		var c: Vector2 = dot[0]
		var rr: float = dot[1]
		var k := rr
		while k > 0.0005:
			_pstrip(mb, circ.call(c, k, 0.0, TAU, 28), 0.0012, 0.0012, a, b, yc, ze, D, ink, skip, zf)
			k -= 0.0018
		_pstrip(mb, [c + Vector2(-0.0012, 0), c + Vector2(0.0012, 0)], 0.0012, 0.0012, a, b, yc, ze, D, ink, skip, zf)
	# virgül kuyrukları: deliğin dış-alt kenarından aşağı ve içe kıvrılır, uca doğru incelir
	for h in holes:
		var hp: Vector2 = h
		var side := signf(hp.x - rc.x)
		var tail: Array = []
		for k in 18:
			var t := float(k) / 17.0
			var ang := deg_to_rad(270.0 + side * (25.0 + t * 70.0))   # alttan başlar, dışa ve yukarı doğru değil aşağı sarkarak kıvrılır
			var rad := hole_r * (1.45 + t * 0.6)
			tail.append(hp + Vector2(cos(ang) * hole_ar, sin(ang)) * rad + Vector2(side * t * 0.002, -t * t * 0.009))
		_pstrip(mb, tail, 0.0028, 0.0004, a, b, yc, ze, D, ink, in_chunk, zf)
	for cr in cracks:
		var pts: Array = []
		for k in (cr as Array).size() - 1:
			for j in 6:
				pts.append((cr[k] as Vector2).lerp(cr[k + 1], j / 6.0))
		pts.append(cr[-1])
		_pstrip(mb, pts, 0.0012, 0.0005, a, b, yc, ze, D, ink, in_chunk, zf)


## Kafa kabuğu (Uzu kask, Rinne ön+tepe): ölçülen yüz/kafa noktalarının hepsini içinde bırakan elipsoit; ön kutuplu ızgara
static func _cap(m, s: String) -> bool:
	var hc: Vector3 = m._head_center()
	var ec: Vector3 = m.eye_center_model if m.face_mi else hc + Vector3(0, -0.03, 0.08)
	var er := ec + Vector3(-0.034, 0, 0)
	var el := ec + Vector3(0.034, 0, 0)
	var ei: Array = m.eye_iris_model
	if ei.size() == 2:
		var e0: Vector3 = ei[0]
		var e1: Vector3 = ei[1]
		er = e0 if e0.x < e1.x else e1
		el = e1 if e0.x < e1.x else e0
	var org := Vector3(hc.x, ec.y, hc.z)
	var key := "cap7|%s|%s|%.3f|%.3f|%.3f" % [s, m._sk_key, er.x - org.x, er.y - org.y, el.x - org.x]
	var e = _cache.get(key)
	if e == null:
		e = _cap_build(_head_pts(m, org), er - org, el - org, s)
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		_cache[key] = e
	m._mesh_on("Head", e[0], Transform3D(Basis.IDENTITY, org))
	if s == "uzu_kamen":
		var clumps = CharacterModel._hair_cache.values()
		for mi in m.skel.find_children("*", "MeshInstance3D", true, false):
			if mi.name in ["VHair", "HairDangle"] or (mi.mesh != null and mi.mesh in clumps):
				mi.visible = false
	else:
		# Rinne: önü ve tepeyi örter, ense saçı açık (ref o_4): kabuğun önüne / üstüne taşan saç kesilir
		var c3: Vector3 = e[1]
		m.hair_mask_plane(Vector3(0, 0.45, 1).normalized(), org + c3 + Vector3(0, 0, -0.015))
	return true


## Sırt eşyası yöntemi (BackV2._loop): kafa + yüz ağının yatay kesit halkaları (6 mm arayla, 48 yön, en dış nokta, boş yön
## komşudan doldurulur, yatay + dikey yumuşatma çıkıntıyı içeride bırakır). Halka yığını -> C'den küresel yarıçap tablosu
## (kabuğun ızgarası bununla kurulur; çıkan yüzey kafayı sarar, elipsoit / tahmin yok).
static func _ring_table(pts: PackedVector3Array, C: Vector3, KA: int, KB: int) -> PackedFloat32Array:
	var ymin := INF
	var ymax := -INF
	for q in pts:
		ymin = minf(ymin, q.y)
		ymax = maxf(ymax, q.y)
	var DY := 0.006
	var NY := int((ymax - ymin) / DY) + 1
	var NBn := 48
	var Rr := PackedFloat32Array()
	Rr.resize(NY * NBn)
	Rr.fill(0.0)
	for q in pts:
		var iy := clampi(int((q.y - ymin) / DY), 0, NY - 1)
		var dx := q.x - C.x
		var dz := q.z - C.z
		var b := int(fposmod(atan2(dx, dz) / TAU, 1.0) * NBn) % NBn
		Rr[iy * NBn + b] = maxf(Rr[iy * NBn + b], sqrt(dx * dx + dz * dz))
	var have := []
	for iy in NY:
		var src := Rr.slice(iy * NBn, (iy + 1) * NBn)
		var known := 0
		for b in NBn:
			if src[b] > 0.0:
				known += 1
		have.append(known >= 3)
		if known < 3:
			for b in NBn:
				Rr[iy * NBn + b] = 0.0
			continue
		for b in NBn:
			if src[b] > 0.0:
				continue
			var a1 := 1
			while src[posmod(b - a1, NBn)] <= 0.0:
				a1 += 1
			var b1 := 1
			while src[posmod(b + b1, NBn)] <= 0.0:
				b1 += 1
			Rr[iy * NBn + b] = lerpf(src[posmod(b - a1, NBn)], src[posmod(b + b1, NBn)], float(a1) / (a1 + b1))
	# 2026-11-26 "tümör gibi şişmiş": en dışı koruyan yumuşatma kulağı yanağa / çeneye yayıyordu. Şimdi: ortanca süzgeç (kulak,
	# burun gibi dar sivrilikleri atar, yanağın / alnın gerçek çizgisi kalır) + düz ortalama
	var med := func(vals: Array) -> float:
		vals.sort()
		return vals[vals.size() / 2]
	var hm := Rr.duplicate()
	for iy in NY:
		for b in NBn:
			if Rr[iy * NBn + b] <= 0.0:
				continue
			var w: Array = []
			for db in range(-3, 4):
				w.append(Rr[iy * NBn + posmod(b + db, NBn)])
			hm[iy * NBn + b] = med.call(w)
	Rr = hm
	var vm := Rr.duplicate()
	for iy in range(1, NY - 1):
		for b in NBn:
			var va: float = Rr[(iy - 1) * NBn + b]
			var vb: float = Rr[(iy + 1) * NBn + b]
			var v0: float = Rr[iy * NBn + b]
			if v0 <= 0.0 or va <= 0.0 or vb <= 0.0:
				continue
			vm[iy * NBn + b] = med.call([va, v0, vb])
	Rr = vm
	for it in 2:
		var sm := Rr.duplicate()
		for iy in NY:
			for b in NBn:
				var v0: float = Rr[iy * NBn + b]
				if v0 <= 0.0:
					continue
				var acc := v0 * 2.0
				var n := 2.0
				for dd in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
					var jy: int = iy + int(dd[0])
					if jy < 0 or jy >= NY:
						continue
					var vv: float = Rr[jy * NBn + posmod(b + int(dd[1]), NBn)]
					if vv > 0.0:
						acc += vv
						n += 1.0
				sm[iy * NBn + b] = acc / n
		Rr = sm
	var ring_r := func(y: float, ang: float) -> float:   # o yükseklikte, o yöndeki halka yarıçapı (0 = halka yok)
		var fy := (y - ymin) / DY - 0.5
		if fy < 0.0 or fy > NY - 1.0:
			return 0.0
		var i0 := int(floorf(fy))
		var i1 := mini(i0 + 1, NY - 1)
		var t := fy - i0
		var fb := fposmod(ang / TAU, 1.0) * NBn - 0.5
		var b0 := posmod(int(floorf(fb)), NBn)
		var b1 := (b0 + 1) % NBn
		var tb := fb - floorf(fb)
		var r0 := lerpf(Rr[i0 * NBn + b0], Rr[i0 * NBn + b1], tb)
		var r1 := lerpf(Rr[i1 * NBn + b0], Rr[i1 * NBn + b1], tb)
		if r0 <= 0.0 or r1 <= 0.0:
			return maxf(r0, r1) * (1.0 - absf(t - (0.0 if r0 > 0.0 else 1.0)))
		return lerpf(r0, r1, t)
	var out := PackedFloat32Array()
	out.resize(KA * KB)
	for ia in KA:
		for ib in KB:
			var al := (ia + 0.5) / KA * PI
			var be := (ib + 0.5) / KB * TAU
			var d := Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))
			var t := 0.02
			var last_in := 0.02
			while t < 0.26:
				var p := C + d * t
				var hd := Vector2(p.x - C.x, p.z - C.z).length()
				if hd <= float(ring_r.call(p.y, atan2(p.x - C.x, p.z - C.z))):
					last_in = t
				t += 0.0015
			out[ia * KB + ib] = last_in
	return out


const CAP_KA := 36
const CAP_KB := 72


static func _cap_build(pts: PackedVector3Array, er: Vector3, el: Vector3, s: String, head_rad := PackedFloat32Array(), head_c := Vector3.ZERO) -> Array:
	var uzu := s == "uzu_kamen"
	var BASE := UZU_BASE if uzu else RINNE_BASE
	var INK := UZU_INK if uzu else RINNE_INK
	# --- kafayı izleyen kabuk (2026-11-26 "yumurta gibi kocaman" düzeltmesi): her yönde yarıçap = o yöndeki en dış kafa / yüz
	# noktası (açısal kova), komşu kovalarla yumuşatılır (burun / kaş tümsek yapmaz), üstüne ince pay. Elipsoit en uzak noktaya göre
	# şişip kafadan çok büyük çıkıyordu.
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for q in pts:
		mn = Vector3(minf(mn.x, q.x), minf(mn.y, q.y), minf(mn.z, q.z))
		mx = Vector3(maxf(mx.x, q.x), maxf(mx.y, q.y), maxf(mx.z, q.z))
	var C := (mn + mx) * 0.5
	C.y = lerpf(C.y, mx.y, 0.12 if uzu else 0.1)
	if not uzu:
		C.z = lerpf(C.z, mn.z, 0.08)
	var KA := 36   # kutup açısı kovası (0..PI, ön kutup +z)
	var KB := 72   # boylam kovası
	var raw := PackedFloat32Array()
	raw.resize(KA * KB)
	for q in pts:
		var d := q - C
		var L := d.length()
		if L < 0.001:
			continue
		var al0 := acos(clampf(d.z / L, -1.0, 1.0))
		var be0 := atan2(d.y, d.x)
		var ia := clampi(int(al0 / PI * KA), 0, KA - 1)
		var ib := int(posmod(be0, TAU) / TAU * KB) % KB
		raw[ia * KB + ib] = maxf(raw[ia * KB + ib], L)
	# boş kova: komşulardan doldur (geniş maks); sonra yumuşat (ortalama) ama ham değerin altına inme
	var fill := raw.duplicate()
	for it in 6:
		var nxt := fill.duplicate()
		for ia in KA:
			for ib in KB:
				if fill[ia * KB + ib] > 0.0:
					continue
				var mxv := 0.0
				for da in [-1, 0, 1]:
					var ja: int = clampi(ia + da, 0, KA - 1)
					for db in [-1, 0, 1]:
						mxv = maxf(mxv, fill[ja * KB + (ib + db + KB) % KB])
				nxt[ia * KB + ib] = mxv
		fill = nxt
	var cone := 2   # ±2 kova (~10°) içindeki en dış nokta: burun çevresi yuvarlanır
	var rad := PackedFloat32Array()
	rad.resize(KA * KB)
	for ia in KA:
		for ib in KB:
			var mxv := 0.0
			for da in range(-cone, cone + 1):
				var ja: int = clampi(ia + da, 0, KA - 1)
				for db in range(-cone, cone + 1):
					mxv = maxf(mxv, fill[ja * KB + (ib + db + KB) % KB])
			rad[ia * KB + ib] = mxv
	for it in (9 if uzu else 3):   # yumuşatma
		var sm := rad.duplicate()
		for ia in KA:
			for ib in KB:
				var acc := 0.0
				var n := 0
				for da in [-1, 0, 1]:
					var ja: int = clampi(ia + da, 0, KA - 1)
					for db in [-1, 0, 1]:
						acc += rad[ja * KB + (ib + db + KB) % KB]
						n += 1
				sm[ia * KB + ib] = maxf(acc / n, fill[ia * KB + ib])
		rad = sm
	# 2026-11-26 "sırt eşyası nasılsa öyle": kabuk ölçülen yatay kesit halkalarından (BackV2._loop yöntemi) -> küresel tablo
	var real_head := true
	head_rad = _ring_table(pts, C, KA, KB)
	if real_head:
		var dil := head_rad.duplicate()
		for ia in KA:
			for ib in KB:
				var mxv := 0.0
				for da in [-1, 0, 1]:
					var ja: int = clampi(ia + da, 0, KA - 1)
					for db in [-1, 0, 1]:
						mxv = maxf(mxv, head_rad[ja * KB + (ib + db + KB) % KB])
				dil[ia * KB + ib] = mxv
		# düz yüzey (ortanca süzgeçli halkalar) AMA hiçbir yönde o yönün gerçek en dış noktasının (raw) altına inmez; kural yalnız
		# o yönde (komşuya yayılmaz): kulak / burun yerinde küçük kabarıklık, yanakta şiş yok; yüz kabuktan taşmaz
		rad = head_rad.duplicate()
		for ii in rad.size():
			rad[ii] = maxf(rad[ii], raw[ii])
		for it in 2:
			var sm2 := rad.duplicate()
			for ia in KA:
				for ib in KB:
					var acc := 0.0
					for da in [-1, 0, 1]:
						var ja: int = clampi(ia + da, 0, KA - 1)
						for db in [-1, 0, 1]:
							acc += rad[ja * KB + (ib + db + KB) % KB]
					sm2[ia * KB + ib] = maxf(acc / 9.0, raw[ia * KB + ib])
			rad = sm2
	var pad := 0.012 if uzu else 0.011   # yüz katmanları (ağız, kaş, çizgiler) öne kaydırılarak çizilir: daha yakın kabuğu deliyorlardı
	# Uzu (kullanıcı beğendi, 2026-11-26): eski elipsoit kabuk birebir korunur
	var ER := Vector3.ZERO
	if true:   # Uzu + Rinne: pürüzsüz elipsoit kabuk (Rinne'de gerçek yüzey birleştirmesi yanak / çenede inişli çıkışlı hat yapıyordu)
		# Uzu (ref: düz yumurta kubbe; ilk sürüm beğenildi, yalnız büyüktü): elipsoit, kulak / burun atılmış halka ölçüsüne
		# (ortanca süzgeçli tablo) oturur, %97 yönü kapsar; gerçek-yüzey birleştirmesi yok (yumru yapıyordu)
		ER = (mx - mn) * 0.5
		ER.y = maxf(ER.y, 0.1)
		var Fs2: Array = []
		for ia in KA:
			for ib in KB:
				var al := (ia + 0.5) / KA * PI
				var be := (ib + 0.5) / KB * TAU
				var dv := Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))
				if (dv.normalized()).dot(Vector3(0, -0.95, -0.3).normalized()) > cos(deg_to_rad(40.0)):
					continue   # boyun yönü
				var q := dv * float(head_rad[ia * KB + ib])
				Fs2.append(pow(q.x / ER.x, 2) + pow(q.y / ER.y, 2) + pow(q.z / ER.z, 2))
		Fs2.sort()
		var F2: float = Fs2[int(Fs2.size() * 0.97)] if Fs2.size() > 0 else 1.0
		ER = ER * sqrt(maxf(F2, 0.01)) + (Vector3(0.007, 0.007, 0.007) if uzu else Vector3(0.008, 0.008, 0.01))
	if false:
		C = (mn + mx) * 0.5
		C.y = lerpf(C.y, mx.y, 0.12)
		ER = (mx - mn) * 0.5
		ER.y = maxf(ER.y, 0.1)
		# 2026-11-26 "kafaya fazla büyük": elipsoit en uzak noktaya (kulak, burun) göre değil %80'lik noktaya göre; dışarı taşan
		# yerleri (kulak) yumuşatılmış kafa yüzeyi örter -> kabuk kafayı sarar, şişkin top olmaz
		var Fs: Array = []
		for q in pts:
			var d := (q - C)
			Fs.append(pow(d.x / ER.x, 2) + pow(d.y / ER.y, 2) + pow(d.z / ER.z, 2))
		Fs.sort()
		var F: float = Fs[int(Fs.size() * 0.8)] if Fs.size() > 0 else 1.0
		ER = ER * sqrt(maxf(F, 0.01)) + Vector3(0.004, 0.004, 0.004)
	var rfun := func(al: float, be: float) -> float:   # çift doğrusal örnek
		var dve := Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))
		var ell := 1.0 / sqrt(pow(dve.x / ER.x, 2) + pow(dve.y / ER.y, 2) + pow(dve.z / ER.z, 2))
		if uzu:
			return ell
		if true:
			var nk := smoothstep(0.84, 0.97, dve.dot(Vector3(0, -0.45, 0.89).normalized()))
			return ell + 0.014 * nk   # burun ucu
		var fa := clampf(al / PI * KA - 0.5, 0.0, KA - 1.001)
		var fb := posmod(be, TAU) / TAU * KB - 0.5
		var ia := int(floor(fa))
		var ib := int(floor(fb))
		var ta := fa - ia
		var tb := fb - ib
		var b0 := (ib + KB) % KB
		var b1 := (ib + 1 + KB) % KB
		var ia1 := mini(ia + 1, KA - 1)
		var v := lerpf(lerpf(rad[ia * KB + b0], rad[ia * KB + b1], tb), lerpf(rad[ia1 * KB + b0], rad[ia1 * KB + b1], tb), ta)
		var dv2 := Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))
		var nose_k := smoothstep(0.84, 0.97, dv2.dot(Vector3(0, -0.45, 0.89).normalized()))   # burun ucu: kabuk orada biraz kabarır
		return v + pad + 0.012 * nose_k
	var dir_of := func(al: float, be: float) -> Vector3:
		return Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))
	var P := func(al: float, be: float) -> Vector3:
		return C + (dir_of.call(al, be) as Vector3) * float(rfun.call(al, be))
	var R := Vector3.ONE * float(rfun.call(0.0, 0.0))   # (ön yarıçap; eski kodla uyum)
	var amax := func(be: float) -> float:
		var sb := sin(be)
		if uzu:
			return PI   # kask: her yön kapalı (ref p_6); boyun deliği aşağıda ayrıca açılır
		return deg_to_rad(92.0 + 26.0 * maxf(0.0, sb) - 8.0 * maxf(0.0, -sb))   # ön + tepe, ense açık
	# göz deliklerinin ön yüzeydeki yeri (xy izdüşümü)
	var holes: Array = [Vector2(er.x, er.y)] if uzu else [Vector2(er.x, er.y), Vector2(el.x, el.y)]
	var hole_r := 0.0105 if uzu else 0.0108
	var hole_ar := 1.0 if uzu else 1.28   # Rinne delikleri yatık oval (kara çerçeveli)
	var chunk := PackedVector2Array()
	var cracks: Array = []
	if s == "rinne_kamen_ware":
		var o := Vector2(el.x, el.y)
		chunk = PackedVector2Array([o + Vector2(-0.012, 0.012), o + Vector2(-0.004, -0.006), o + Vector2(-0.008, -0.024), o + Vector2(0.004, -0.04),
			o + Vector2(0.024, -0.05), o + Vector2(0.05, -0.036), o + Vector2(0.06, 0.004), o + Vector2(0.044, 0.026), o + Vector2(0.02, 0.03), o + Vector2(0.004, 0.022)])
		cracks = [[o + Vector2(-0.012, 0.012), o + Vector2(-0.024, 0.026), o + Vector2(-0.02, 0.044), o + Vector2(-0.034, 0.062), o + Vector2(-0.03, 0.08)],
			[o + Vector2(0.044, 0.026), o + Vector2(0.05, 0.05), o + Vector2(0.042, 0.072), o + Vector2(0.054, 0.1)],
			[o + Vector2(0.004, -0.04), o + Vector2(-0.012, -0.054), o + Vector2(-0.01, -0.072), o + Vector2(-0.03, -0.086)],
			[o + Vector2(0.024, -0.05), o + Vector2(0.03, -0.07), o + Vector2(0.022, -0.09)],
			[Vector2(er.x, er.y) + Vector2(0.012, 0.01), Vector2(er.x, er.y) + Vector2(0.022, 0.026), Vector2(er.x, er.y) + Vector2(0.018, 0.044)]]
	var in_poly := func(p: Vector2) -> bool:
		if chunk.is_empty():
			return false
		return Geometry2D.is_point_in_polygon(p, chunk)
	var in_hole := func(p: Vector2) -> bool:
		for h in holes:
			var d: Vector2 = p - h
			if pow(d.x / (hole_r * hole_ar), 2) + pow(d.y / hole_r, 2) < 1.0:
				return true
		return false
	# Uzu katları: delik yönü ekseninde açısal sarmal; kat içinde rampa, kat sonunda basamak (üst üste binen yapraklar)
	var hdir: Vector3 = (Vector3(er.x, er.y, C.z + R.z) - C).normalized()
	var ax1 := hdir.cross(Vector3.UP).normalized()
	var ax2 := ax1.cross(hdir).normalized()
	var fold := func(p: Vector3) -> Array:   # [yükseklik, basamağa yakınlık 0..1]
		var v := (p - C).normalized()
		var dl: float = acos(clampf(v.dot(hdir), -1.0, 1.0))
		var gm: float = atan2(v.dot(ax2), v.dot(ax1))
		var u: float = gm / TAU * 6.0 + dl * 1.5   # altı kat, delikten uzaklaştıkça kıvrılır
		var fr: float = u - floor(u)
		var hgt: float = 0.02 * pow(fr, 0.6) * clampf((dl - 0.1) / 0.3, 0.0, 1.0)   # kat rampası; sonunda bir sonrakinin altına basamakla iner (ilk, beğenilen sürüm)
		return [hgt, fr]
	var NA := 220 if uzu else 150
	var NB := 130 if uzu else 96
	var thick := 0.0035
	var V := []   # [ai][bi] -> [konum, renk]
	for ai in NB + 1:
		var row := []
		for bi in NA:
			var be := TAU * bi / NA
			var al: float = float(amax.call(be)) * float(ai) / NB
			var p: Vector3 = P.call(al, be)
			var col := BASE
			if uzu:
				var fd: Array = fold.call(p)
				var nrm := (p - C).normalized()
				p += nrm * float(fd[0])
			row.append([p, col])
		V.append(row)
	var mb := SurfaceTool.new()
	mb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := BASE.darkened(0.55)
	for ai in NB:
		for bi in NA:
			var b2 := (bi + 1) % NA
			var p00: Vector3 = V[ai][bi][0]
			var p01: Vector3 = V[ai][b2][0]
			var p10: Vector3 = V[ai + 1][bi][0]
			var p11: Vector3 = V[ai + 1][b2][0]
			var cen := (p00 + p01 + p10 + p11) * 0.25
			var c2 := Vector2(cen.x, cen.y)
			if cen.z > C.z and (in_hole.call(c2) or in_poly.call(c2)):
				continue
			if cen.z > C.z and (in_hole.call(Vector2(p00.x, p00.y)) or in_hole.call(Vector2(p01.x, p01.y)) or in_hole.call(Vector2(p10.x, p10.y)) or in_hole.call(Vector2(p11.x, p11.y))):
				continue   # deliğe değen kare atılır; dış kenarın basamağını yuvarlak kara çerçeve örter
			if uzu and (cen - C).normalized().dot(Vector3(0, -0.95, -0.3).normalized()) > cos(deg_to_rad(32.0)):
				continue   # boyun deliği
			var out := (cen - C).normalized()
			var col: Color = V[ai][bi][1]
			_tq(mb, p00, p01, p11, p10, col, out)
			var o := -out * thick
			_tq(mb, p00 + o, p10 + o, p11 + o, p01 + o, inner, -out)
	# kenar duvarı (kabuk ağzı)
	for bi in NA:
		var b2 := (bi + 1) % NA
		var q0: Vector3 = V[NB][bi][0]
		var q1: Vector3 = V[NB][b2][0]
		var out := ((q0 + q1) * 0.5 - C).normalized()
		_tq(mb, q0, q0 - out * thick, q1 - out * thick, q1, INK, (q0 - C) - out * 0.0)
	# göz delikleri: göze inen kara tünel
	var front_z := func(p2: Vector2) -> float:   # önden izdüşüm: (x, y) noktasının kabuk üstündeki z'si (yinelemeli)
		var z := C.z + float(rfun.call(0.0, 0.0))
		for it in 6:
			var d := Vector3(p2.x, p2.y, z) - C
			var L := d.length()
			var al := acos(clampf(d.z / maxf(L, 0.0001), -1.0, 1.0))
			var be := atan2(d.y, d.x)
			var r: float = rfun.call(al, be)
			var dxy := Vector2(p2.x - C.x, p2.y - C.y).length()
			z = C.z + sqrt(maxf(0.0001, r * r - dxy * dxy))
		return z
	var eyes3 := [er] if uzu else [er, el]
	for hi in holes.size():
		var h: Vector2 = holes[hi]
		var ez: float = (eyes3[hi] as Vector3).z + 0.003
		for k in 28:
			var t0 := TAU * k / 28.0
			var t1 := TAU * (k + 1) / 28.0
			var c0 := Vector2(cos(t0) * hole_ar, sin(t0)) * hole_r * 0.97   # tünel deliğin İÇİNDEN başlar (kabuğun üstüne taşmaz)
			var c1 := Vector2(cos(t1) * hole_ar, sin(t1)) * hole_r * 0.97
			var f0 := Vector3(h.x + c0.x, h.y + c0.y, front_z.call(h + c0) + 0.0005)
			var f1 := Vector3(h.x + c1.x, h.y + c1.y, front_z.call(h + c1) + 0.0005)
			var b0 := Vector3(h.x + c0.x * 1.45, h.y + c0.y * 1.45, ez)   # göze doğru genişler: göz delikten görünür
			var b1 := Vector3(h.x + c1.x * 1.45, h.y + c1.y * 1.45, ez)
			_tq(mb, f0, f1, b1, b0, Color(0.03, 0.02, 0.02), -Vector3(c0.x, c0.y, 0))
	if uzu:   # yuvarlak delik ağzı: kabuk (katlar dahil) üstünde kara halka, 0.97 -> 1.4 delik yarıçapı
		for h in holes:
			var hp: Vector2 = h
			var N := 48
			var prev_i := Vector3.ZERO
			var prev_o := Vector3.ZERO
			for k in N + 1:
				var t := TAU * k / N
				var dv := Vector2(cos(t) * hole_ar, sin(t))
				var pts2: Array = []
				for kk in [0.97, 1.4]:
					var q2: Vector2 = hp + dv * hole_r * kk
					var p3 := Vector3(q2.x, q2.y, front_z.call(q2))
					var nr := (p3 - C).normalized()
					p3 += nr * (float((fold.call(p3) as Array)[0]) + 0.0009)
					pts2.append(p3)
				if k > 0:
					_tq(mb, prev_i, pts2[0], pts2[1], prev_o, Color(0.03, 0.02, 0.02), (pts2[0] - C).normalized())
				prev_i = pts2[0]
				prev_o = pts2[1]
	if uzu:
		var on_cap := func(v: Vector3) -> Array:   # yön -> [elipsoit noktası, normal, kabuğun içinde mi]
			var al := acos(clampf(v.z, -1.0, 1.0))
			var be := atan2(v.y, v.x)
			var q: Vector3 = C + v * float(rfun.call(al, be))
			var inside: bool = al <= float(amax.call(be)) - 0.02
			return [q, (q - C).normalized(), inside]
		for n in 6:
			var prev_a := Vector3.ZERO
			var prev_b := Vector3.ZERO
			var have := false
			for k in 241:
				var dl: float = lerpf(0.16, 2.9, float(k) / 240.0)
				var gm: float = (float(n) - dl * 1.5) * TAU / 6.0
				var v: Vector3 = (hdir * cos(dl) + (ax1 * cos(gm) + ax2 * sin(gm)) * sin(dl)).normalized()
				var cp: Array = on_cap.call(v)
				if not bool(cp[2]):
					have = false
					continue
				var q: Vector3 = cp[0]
				var nr: Vector3 = cp[1]
				var hh: float = 0.02 * clampf((dl - 0.1) / 0.3, 0.0, 1.0) + 0.0008
				var dl2: float = dl + 0.012
				var gm2: float = (float(n) - dl2 * 1.5) * TAU / 6.0
				var v2: Vector3 = (hdir * cos(dl2) + (ax1 * cos(gm2) + ax2 * sin(gm2)) * sin(dl2)).normalized()
				var tg: Vector3 = ((on_cap.call(v2)[0] as Vector3) - q).normalized()
				var side: Vector3 = nr.cross(tg).normalized() * 0.0016
				# çizgi gerçek kat yüzeyine oturur: basamağın iki yanındaki kat yüksekliğinin büyüğü (sabit 2 cm havada kalıyordu)

				var pa: Vector3 = q + nr * hh + side
				var pb: Vector3 = q + nr * hh - side
				if have:
					_tq(mb, prev_a, pa, pb, prev_b, INK, nr)
				prev_a = pa
				prev_b = pb
				have = true
	# --- Rinne deseni: beğenilen plakadaki desen (_rinne_ink) kabuk yüzeyine çizilir (önden izdüşüm z = front_z)
	if not uzu:
		var dx := absf(el.x - er.x) * 0.5
		var ey := (er.y + el.y) * 0.5
		var ytop: float = mx.y + pad
		var f := 1.7
		while f > 0.9 and ey + dx * f + dx * sqrt(1.0 + f * f) * 1.2 > ytop:
			f -= 0.05
		var rc := Vector2((er.x + el.x) * 0.5, ey + dx * f)
		var ring_r := dx * sqrt(1.0 + f * f)
		var in_hole_k := func(p: Vector2, k := 1.0) -> bool:
			for h in holes:
				var d: Vector2 = p - h
				if pow(d.x / (hole_r * hole_ar * k), 2) + pow(d.y / (hole_r * k), 2) < 1.0:
					return true
			return false
		var zf := func(p: Vector2) -> float:
			return front_z.call(p)
		_rinne_ink(mb, rc, ring_r, holes, hole_r, hole_ar, cracks, in_hole_k, in_poly, 1.0, 1.0, 0.0, 0.0, 0.0, INK, ytop, zf)
	mb.generate_normals()
	var mesh := mb.commit()
	mesh.surface_set_material(0, Props.toon())
	return [mesh, C]
