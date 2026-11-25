class_name HokageMonument
extends RefCounted
## Hokage Kayası (Hokage Anıtı): uçurum yüzüne OYULMUŞ beş dev taş baş.
## Kaynak: refs/hokage_rock/HokageRock.png (anime geniş plan) + sb_hokage_rock_*.jpg. Referanstan çıkan özellikler:
##  - baş kayanın kendisinden çıkar: yanları kayaya doğru kıvrılır (silindir gibi gölgelenir), çevresinde koyu oyuk halkası,
##    kafanın etrafındaki kaya kabaca yontulmuş, dikey oluklu; boyun aşağıda kaya sütununa karışır
##  - yüz uzun oval, önü düz; derin göz çukuru içinde bebeksiz badem göz + kalın üst göz kapağı; ağır kaş çıkıntısı;
##    uzun düz burun (kanatlı, altı keskin gölge), kapalı küçük ağız, belirgin çene, elmacık
##  - saç iri kaya kütleleri: kalın yuvarlak tutamlar (karton diken değil), aralarında derin oluk; alın koruyucu bandı / başlık
## Oyunun kendi (kanon olmayan) Hokage'leri: her biri ayrı saç ve yüz (0 uzun ayrık saç, 1 dikenli + bant, 2 başlıklı yaşlı +
## keçi sakal, 3 geriye savrulan vahşi saç + yara izi, 4 kadın: yana taranmış kâkül, uzun saç).
## Yöntem: uçurum yüzeyinden dışarı doğru bir yükseklik alanı (derinlik fonksiyonu), yoğun ızgara (yüzde ~0.42 m),
## yumuşak normaller, oyuk = koyu köşe rengi; çarpışma aynı ızgaranın seyreltilmiş üçgen ağı (tırmanılabilir).

static var probes: Array = []   # test: her yüzün burun ucu (dünya) ve beklenen yüzey (çarpışma ışını karşılaştırması)


## _hokage_faces'in tam karşılığı: beş yüz + uçuruma çıkan merdiven + tepe seyir yeri ve etkileşimler
static func build(b: Builder, rock: Dictionary, cliff_n: float, v: Dictionary) -> void:
	var top = float(rock.get("top", float(v["base"]) + 165.0)) - b.origin.y
	var x0 = float(rock.get("x0", float(v["x"]) - 825.0)) - float(v["x"])
	var x1 = float(rock.get("x1", float(v["x"]) + 825.0)) - float(v["x"])
	var rc = Color(0.74, 0.58, 0.36)
	var cx = (x0 + x1) * 0.5
	var gap = carve(b, rock, cliff_n, v)
	BuildKonoha._cliff_stairs(b, -2.0 * gap - gap * 1.1, cliff_n, top, rc.darkened(0.2))
	var ln = cliff_n + 35.0
	b.box(Vector3(cx, BuildKonoha._gy(b, cx, ln) + 0.5, ln), Vector3(70, 1, 24), Color(0.55, 0.45, 0.35), 0, false)
	for k in 8:
		b.box(Vector3(cx - 34 + k * 9.7, BuildKonoha._gy(b, cx, ln) + 1.6, ln - 12), Vector3(0.3, 1.2, 0.3), Color(0.42, 0.3, 0.2), 0, false)
	BuildKonoha._act(b, cx, ln, 14, "lookout", "[F] Köyü seyret (kayıt)")
	BuildKonoha._act(b, cx + 30, ln, 4, "shrine", "[F] Kayadaki küçük sunakta dua et")


## Yalnız beş baş (test de bunu çağırır). Dönüş: yüzler arası mesafe
static func carve(b: Builder, rock: Dictionary, cliff_n: float, v: Dictionary) -> float:
	var top = float(rock.get("top", float(v["base"]) + 165.0)) - b.origin.y
	var rc = Color(0.74, 0.58, 0.36)   # terrain.gdshader'daki Hokage Kayası altın-toprak tonu
	var gap = 92.0
	var H = clampf(top * 0.42, 40.0, 78.0)   # baş (çene-tepe) yüksekliği
	var fy = top * 0.56
	var lift = [0.0, -0.06, 0.03, -0.04, 0.02]   # animedeki gibi başlar aynı hizada değil
	probes.clear()
	timing.clear()
	var t0 = Time.get_ticks_msec()
	for i in 5:
		var fx = (float(i) - 2.0) * gap
		_head(b, fx, fy + float(lift[i]) * H, cliff_n, H, rc.lightened(0.02 * float(i % 2)), i, NAN, top)
	print("Hokage Kayası yüzleri: %d ms (%s)" % [Time.get_ticks_msec() - t0, str(timing)])
	return gap


# ---------------------------------------------------------------- yardımcılar
static func _sm(x: float) -> float:
	return Sculpt._sm(x)


static func _vn(x: float, y: float, sd := 0) -> float:
	return Sculpt._vn(x, y, sd)


## Yontu heykeli: (u, v) baş birimi (H) -> uçurum yüzeyinden dışarı derinlik (H birimi)
class Sculpt:
	static func _sm(x: float) -> float:
		var t = clampf(x, 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

	static var _fn: FastNoiseLite
	## [0, 1] düzgün gürültü (yerel FastNoiseLite: betik içi karma gürültüden ~20 kat hızlı)
	static func _vn(x: float, y: float, sd := 0) -> float:
		if _fn == null:
			_fn = FastNoiseLite.new()
			_fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			_fn.fractal_type = FastNoiseLite.FRACTAL_NONE
			_fn.frequency = 1.0
		return _fn.get_noise_2d(x + sd * 31.7, y - sd * 17.3) * 0.5 + 0.5

	var seed := 0
	var D := 0.30            # yüz önünün kayadan çıkıntısı
	var jaw := 0.29
	var chin_w := 0.11
	var brow := 0.03
	var brow_w := 0.02
	var brow_tilt := 0.1
	var eye_tilt := 0.0
	var eye_h := 0.028
	var cheek := 0.02
	var nose_h := 0.07
	var nose_tip := -0.15
	var mouth_w := 0.07
	var frown := 0.5
	var lip := 1.0
	var age := 0.0
	var ears := false
	var band := false
	var scar := false
	var hl_c := 0.3          # saç çizgisi (orta)
	var hl_side := 0.0       # yanlarda saç çizgisinin inişi
	var cap_rx := 0.37
	var cap_top := 0.58
	var cap_d := 0.33
	var cap_groove := 1.0
	var part := Vector2(0.0, 0.5)   # saç oluklarının çıktığı nokta (ayrım / tepe)
	var hood := 9.0          # < 9: başlık yanları yüzün kenarından bu v'ye kadar iner (yanaklık)
	var locks: Array = []    # [pts PackedVector2Array, Rect2, r0, r1, d0, d1, yuvarlaklık, oluk sayısı]

	## kalın yuvarlak saç tutamı: a -> c (kontrol) -> e ikinci derece eğri; r yarıçap, d taban derinliği (kökten uca)
	func lock(a: Vector2, c: Vector2, e: Vector2, r0: float, r1: float, d0: float, d1: float, rnd := 0.8, grooves := 3.0) -> void:
		var pts := PackedVector2Array()
		var N = 10
		for k in N + 1:
			var t = float(k) / N
			pts.append(a * (1.0 - t) * (1.0 - t) + c * 2.0 * t * (1.0 - t) + e * t * t)
		var rect = Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			rect = rect.expand(p)
		rect = rect.grow(maxf(r0, r1) + 0.01)
		locks.append([pts, rect, r0, r1, d0, d1, rnd, grooves])

	func head_rx(v: float) -> float:
		if v >= 0.05:
			var q = (v - 0.05) / 0.52
			return 0.0 if q >= 1.0 else 0.338 * sqrt(1.0 - q * q)
		if v >= -0.16:
			return lerpf(0.338, jaw, _sm((0.05 - v) / 0.21))
		var k = clampf((-0.16 - v) / 0.33, 0.0, 1.0)
		return lerpf(jaw, chin_w, pow(k, 1.3))

	## başın çıplak hacmi (özelliksiz): önü düz, yanları kayaya kıvrılan oval
	func head_base(u: float, v: float) -> float:
		var rx = head_rx(v)
		if rx <= 0.002:
			return -1.0
		var s = absf(u) / rx
		if s >= 1.0:
			return -1.0
		var front = sqrt(1.0 - pow(s, 2.4))
		var vr = 1.0
		if v < -0.40:
			var k = (-0.40 - v) / 0.09
			if k >= 1.0:
				return -1.0
			vr = sqrt(1.0 - k * k)
		return D * front * vr - 0.035 * _sm((v - 0.12) / 0.4)

	func face(u: float, v: float) -> float:
		var t = head_base(u, v)
		if t < 0.0:
			return -1.0
		var s = absf(u) / maxf(head_rx(v), 0.01)
		var wf = _sm((0.85 - s) / 0.3)
		if wf > 0.0 and v < 0.32:
			t += wf * features(u, v)
		return t

	func features(u: float, v: float) -> float:
		var au = absf(u)
		var f = 0.0
		var ey = 0.02
		# göz çukuru
		var sx = (au - 0.118) / 0.094
		var sy = (v - ey) / 0.06
		var dd = sx * sx + sy * sy
		if dd < 1.0:
			f -= 0.036 * _sm(1.0 - dd)
		# bebeksiz badem göz + kalın üst kapak
		var lx = (au - 0.118) / 0.066
		if absf(lx) < 1.0:
			var w2 = 1.0 - lx * lx
			var hh = eye_h * pow(w2, 0.55)
			var ly = v - ey - eye_tilt * (au - 0.118)
			if absf(ly) < hh:
				f += 0.03 * sqrt(w2) * sqrt(1.0 - pow(ly / hh, 2.0))
			f += 0.015 * w2 * exp(-pow((ly - hh) / 0.009, 2.0))
			f += 0.006 * w2 * exp(-pow((ly + hh) / 0.007, 2.0))
		# ağır kaş çıkıntısı (kaşlar: dış uç eğimi brow_tilt; kadında ince kaş)
		var bx = au - 0.118
		if absf(bx) < 0.14:
			var yb = ey + 0.068 + brow_tilt * bx - 1.0 * bx * bx
			f += brow * exp(-pow((v - yb) / brow_w, 2.0)) * _sm((0.14 - absf(bx)) / 0.05) * _sm((au - 0.008) / 0.03)
		f += 0.5 * brow * exp(-pow((v - ey - 0.062) / 0.03, 2.0) - pow(u / 0.035, 2.0))   # kaş arası köprü
		if frown > 0.5:
			f -= 0.006 * frown * exp(-pow((au - 0.022) / 0.007, 2.0) - pow((v - ey - 0.05) / 0.03, 2.0))   # kaş çatma çizgileri
		# elmacık + altındaki çöküklük
		f += cheek * exp(-pow((au - 0.19) / 0.06, 2.0) - pow((v + 0.06) / 0.045, 2.0))
		f -= 0.016 * exp(-pow((au - 0.17) / 0.05, 2.0) - pow((v + 0.22) / 0.08, 2.0))
		if age > 0.0:
			f -= 0.007 * age * exp(-pow((au - 0.12) / 0.05, 2.0) - pow((v - ey + 0.052) / 0.008, 2.0))   # göz altı torbası
			for wy in [0.2, 0.245]:   # alın kırışıkları
				f -= 0.005 * age * exp(-pow((v - wy - 0.01 * cos(u * 9.0)) / 0.006, 2.0)) * _sm((0.2 - au) / 0.05)
		# burun: kaşların arasından başlayan, aşağı doğru genişleyip yükselen kama; altı keskin gölge
		var vt = ey + 0.035
		var vn = nose_tip
		if v < vt and v > vn - 0.035 and au < 0.09:
			if v >= vn:
				var k = (vt - v) / (vt - vn)
				var w = 0.016 + 0.03 * k
				var h = 0.008 + nose_h * pow(k, 1.4)
				if au < w:
					f += h * pow(1.0 - pow(au / w, 2.0), 0.7)
			else:
				var k2 = (vn - v) / 0.035
				var w3 = 0.046
				if au < w3:
					f += (0.008 + nose_h) * pow(1.0 - pow(au / w3, 2.0), 0.7) * sqrt(maxf(0.0, 1.0 - k2 * k2))
		f += 0.028 * exp(-pow((au - 0.043) / 0.02, 2.0) - pow((v - vn - 0.006) / 0.018, 2.0))   # burun kanatları
		f -= 0.014 * exp(-pow((au - 0.02) / 0.009, 2.0) - pow((v - vn + 0.014) / 0.007, 2.0))   # burun delikleri
		# ağız: kapalı, küçük; köşeler frown ile aşağı
		var mv = vn - 0.105
		var ym = mv - frown * 0.012 * pow(u / mouth_w, 2.0)
		var mwin = clampf((mouth_w * 1.15 - au) / (mouth_w * 0.3), 0.0, 1.0)
		f -= 0.022 * exp(-pow((v - ym) / 0.008, 2.0)) * mwin
		f += 0.012 * lip * exp(-pow(u / (mouth_w * 0.85), 2.0) - pow((v - ym - 0.017) / 0.012, 2.0))
		f += 0.016 * lip * exp(-pow(u / (mouth_w * 0.75), 2.0) - pow((v - ym + 0.022) / 0.014, 2.0))
		f -= 0.010 * exp(-pow(u / 0.05, 2.0) - pow((v - ym + 0.052) / 0.01, 2.0))   # alt dudak altı oluğu
		f += 0.012 * exp(-pow(u / 0.11, 2.0) - pow((v - mv) / 0.07, 2.0))   # ağız çıkıntısı
		f += 0.026 * exp(-pow(u / 0.075, 2.0) - pow((v + 0.40) / 0.045, 2.0))   # çene
		if age > 0.0:   # burun kanadından ağız köşesine yaş çizgisi
			var d = _seg_d(Vector2(au, v), Vector2(0.062, vn + 0.005), Vector2(mouth_w + 0.025, ym - 0.035))
			f -= 0.01 * age * exp(-pow(d / 0.008, 2.0))
		if scar and u < 0.0:   # sol gözün üstünden inen yara izi
			var d2 = _seg_d(Vector2(u, v), Vector2(-0.2, 0.15), Vector2(-0.065, -0.11))
			f -= 0.012 * exp(-pow(d2 / 0.007, 2.0))
		return f

	func _seg_d(p: Vector2, a: Vector2, c: Vector2) -> float:
		var ab = c - a
		var t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		return p.distance_to(a + ab * t)

	func hair(u: float, v: float) -> float:
		var best = -1.0
		# başın üstünü kaplayan saç / başlık kütlesi; alt kenarı saç çizgisinde keskin biter
		var hl = hl_c - hl_side * pow(minf(absf(u) / 0.33, 1.3), 2.0)
		var inhood = v > hood and absf(u) > head_rx(v) * 0.9
		if inhood:
			hl = minf(hl, v - 0.03)
		if v > hl - 0.02:
			var q = pow(u / cap_rx, 2.0)
			if v > 0.05:
				q += pow((v - 0.05) / (cap_top - 0.05), 2.0)
			if q < 1.0:
				var c = cap_d * sqrt(1.0 - pow(sqrt(q), 2.2)) * _sm((v - hl + 0.02) / 0.02)
				if inhood:
					c *= _sm((v - hood) / 0.12)
				if cap_groove > 0.0:   # ayrımdan / tepeden ışınsal tutam olukları
					var ang = atan2(u - part.x, part.y - v + 0.25)
					c += 0.013 * cap_groove * (absf(sin(ang * 8.0)) - 0.6) * _sm(c / 0.1)
				best = c
		var capc = best
		# alın koruyucu bant + plaka (başın eğrisini izler) + kazınmış yaprak sarmalı
		if band and v < hl_c and v > hl_c - 0.075:
			var hb = head_base(u, v)
			if hb > 0.0:
				var bv = hb + 0.02
				if absf(u) < 0.11 and v < hl_c - 0.008 and v > hl_c - 0.067:
					var pe = minf(minf(0.11 - absf(u), v - (hl_c - 0.067)), (hl_c - 0.008) - v)
					bv += 0.014 * _sm(pe / 0.008)
					var pc = Vector2(u, v - (hl_c - 0.0375))
					var r = pc.length()
					var th = atan2(pc.y, pc.x) + PI
					var sr = 0.006 + 0.018 * th / TAU   # sarmal
					if absf(r - sr) < 0.0035 or (pc.x > 0.0 and pc.x < 0.03 and absf(pc.y + pc.x * 0.6 - 0.0) < 0.003):
						bv -= 0.006
				best = maxf(best, bv)
		# tutamlar
		var p = Vector2(u, v)
		for L in locks:
			var rect: Rect2 = L[1]
			if not rect.has_point(p):
				continue
			var pts: PackedVector2Array = L[0]
			var bd = 1e9
			var bt = 0.0
			var bs = 0.0
			var n = pts.size() - 1
			for k in n:
				var a = pts[k]
				var ab = pts[k + 1] - a
				var t = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
				var q2 = a + ab * t
				var d = p.distance_to(q2)
				if d < bd:
					bd = d
					bt = (float(k) + t) / n
					bs = signf(ab.x * (p.y - a.y) - ab.y * (p.x - a.x))
			var r = lerpf(float(L[2]), float(L[3]), pow(bt, 1.5)) * (0.45 + 0.55 * _sm(bt / 0.25))   # kök incelir: kütleden çıkar
			if bd >= r:
				continue
			var x = bd / r
			var cs = sqrt(1.0 - x * x)
			var val = lerpf(float(L[4]), float(L[5]), bt) - 0.03 * (1.0 - _sm(bt / 0.25)) + r * float(L[6]) * cs
			var gr = float(L[7])
			if gr > 0.0:   # tutamın içinde boyuna telli oluklar
				val += 0.005 * cos(PI * gr * x * bs) * cs * (1.0 - 0.5 * bt)
			if capc > 0.0:   # kök saç kütlesinin yüzeyinden çıkar (boncuk gibi top uç kalmaz)
				val = lerpf(capc, val, _sm(bt / 0.3))
			best = maxf(best, val)
		return best

	## kaya: başı taşıyan düzensiz kaya kütlesi (dikdörtgen arka plaka YOK): kenarı açıya göre gürültülü bir halka, dışa doğru
	## uçurum yüzeyine sıfıra iner (uçurumun içine dalar); çene altında aşağı doğru genişleyip kayaya gömülen boyun kütlesi
	func rock(u: float, v: float, uw: float, vb: float, vt: float) -> float:
		var dv = v - 0.04
		var r = sqrt(pow(u / 0.5, 2.0) + pow(dv / 0.62, 2.0))
		var th = atan2(u, dv)
		var cx = cos(th); var sy = sin(th)
		var R = 0.98 + 0.55 * (_vn(cx * 1.3, sy * 1.3, seed) - 0.5) + 0.22 * (_vn(cx * 3.6, sy * 3.6, seed + 1) - 0.5)
		var mound = 0.07 * _sm((R * 1.08 - r) / 0.42)
		var w = 0.24 + 0.12 * clampf((-0.45 - v) / 0.5, 0.0, 1.0)
		var m2 = 0.12 * exp(-pow(u / w, 2.0)) * _sm((-0.40 - v) / 0.15) * _sm((v + 1.0 + 0.2 * (_vn(u * 4.0, 3.0, seed + 2) - 0.5)) / 0.35)
		var pres = clampf(maxf(mound / 0.07, m2 / 0.12), 0.0, 1.0)
		if pres <= 0.0:
			return 0.0
		var st = 0.035 * (_vn(u * 6.0, v * 1.1, seed + 3) - 0.5) + 0.025 * (1.0 - absf(2.0 * _vn(u * 13.0, v * 2.0, seed + 5) - 1.0)) \
			+ 0.01 * (_vn(u * 31.0, v * 5.0, seed + 7) - 0.5)
		var win = _sm((uw - absf(u)) / 0.05) * _sm((v - vb) / 0.05) * _sm((vt - v) / 0.05)
		return maxf(0.0, (mound + m2 + st * pres - 0.012) * win)

	func neck(u: float, v: float) -> float:
		if v > -0.25:
			return -1.0
		var s = absf(u) / 0.19
		if s >= 1.0:
			return -1.0
		return 0.19 * sqrt(1.0 - s * s) * _sm((v + 0.95) / 0.35) + 0.006 * (_vn(u * 20.0, v * 3.0, 13) - 0.5)

	func depth(u: float, v: float, uw: float, vb: float, vt: float) -> float:
		var d = rock(u, v, uw, vb, vt)
		d = maxf(d, neck(u, v))
		d = maxf(d, face(u, v))
		if ears:
			var ex = (absf(u) - 0.335) / 0.045
			var ey2 = (v + 0.0) / 0.085
			var q = ex * ex + ey2 * ey2
			if q < 1.0:
				d = maxf(d, 0.12 * sqrt(1.0 - q) - 0.01 * exp(-q * 3.0))
		d = maxf(d, hair(u, v))
		return d + 0.004 * (_vn(u * 40.0, v * 40.0, 17) - 0.5)   # taş yüzey pürüzü


## Her Hokage'nin yüz ve saç tarifi (oyunun kendi Hokage'leri)
static func _sculpt(style: int) -> Sculpt:
	var s = Sculpt.new()
	match style:
		0:   # Birinci: ortadan ayrılmış uzun düz saç omuzlara iner; sert, yaşlıca yüz
			s.jaw = 0.30; s.chin_w = 0.12; s.brow = 0.032; s.brow_tilt = 0.12; s.eye_tilt = 0.05
			s.nose_h = 0.072; s.nose_tip = -0.15; s.mouth_w = 0.075; s.frown = 0.8; s.age = 0.5
			s.hl_c = 0.36; s.hl_side = 0.22; s.cap_d = 0.335; s.part = Vector2(0.0, 0.56)
			for sd in [-1.0, 1.0]:
				for k in 4:
					var kf = float(k)
					s.lock(Vector2(sd * (0.04 + 0.07 * kf), 0.53 - 0.05 * kf), Vector2(sd * (0.41 + 0.02 * kf), 0.34 - 0.07 * kf),
						Vector2(sd * (0.37 + 0.045 * kf + 0.02 * sin(kf * 1.7)), -0.45 - 0.08 * kf + 0.05 * sin(kf * 2.3)),
						0.078, 0.035, 0.345, 0.21 - 0.015 * kf)
				s.lock(Vector2(sd * 0.38, 0.3), Vector2(sd * 0.54, 0.0), Vector2(sd * 0.52, -0.75), 0.085, 0.045, 0.22, 0.12, 0.7, 2.0)
		1:   # İkinci: alın bandının üstünde yukarı-dışa açılan iri dikenli saç, yanlarda yüzü çerçeveleyen kâküller; genç
			s.jaw = 0.285; s.chin_w = 0.1; s.brow = 0.022; s.brow_tilt = 0.05; s.eye_tilt = 0.0
			s.nose_h = 0.062; s.nose_tip = -0.14; s.mouth_w = 0.065; s.frown = 0.2
			s.band = true; s.hl_c = 0.27; s.cap_d = 0.32; s.cap_rx = 0.4; s.cap_top = 0.7; s.part = Vector2(0.0, 0.3)
			var o = Vector2(0.0, 0.3)
			var angs = [-68.0, -40.0, -13.0, 13.0, 40.0, 68.0]
			for k in angs.size():
				var a = deg_to_rad(float(angs[k]))
				var dv = Vector2(sin(a), cos(a))
				var ln = 0.45 + 0.05 * cos(float(k) * 2.1) - 0.08 * absf(sin(a))
				var curl = Vector2(dv.y, -dv.x) * 0.02 * signf(sin(a) + 0.001)
				s.lock(o + dv * 0.14, o + dv * ln * 0.6 - curl, o + dv * ln, 0.115, 0.012, 0.32, 0.16)
			for sd in [-1.0, 1.0]:
				s.lock(Vector2(sd * 0.22, 0.25), Vector2(sd * 0.37, 0.1), Vector2(sd * 0.32, -0.2), 0.065, 0.01, 0.34, 0.29)
				s.lock(Vector2(sd * 0.3, 0.24), Vector2(sd * 0.43, 0.12), Vector2(sd * 0.44, -0.08), 0.065, 0.01, 0.31, 0.2)
		2:   # Üçüncü: alın plakalı başlık, yanaklıkları yüzün kenarından çeneye iner; keçi sakal ve bıyık; yaşlı, yumuşak bakış
			s.jaw = 0.29; s.chin_w = 0.11; s.brow = 0.026; s.brow_tilt = -0.08; s.eye_tilt = -0.03
			s.nose_h = 0.07; s.nose_tip = -0.15; s.mouth_w = 0.07; s.frown = -0.2; s.age = 1.0
			s.band = true; s.hl_c = 0.27; s.cap_d = 0.335; s.cap_rx = 0.39; s.cap_top = 0.58; s.cap_groove = 0.0; s.hood = -0.3
			for sd in [-1.0, 1.0]:
				s.lock(Vector2(sd * 0.02, -0.18), Vector2(sd * 0.07, -0.19), Vector2(sd * 0.115, -0.25), 0.022, 0.008, 0.33, 0.31, 0.8, 2.0)   # bıyık
			s.lock(Vector2(0.0, -0.3), Vector2(0.0, -0.45), Vector2(0.0, -0.62), 0.055, 0.01, 0.315, 0.24, 0.8, 4.0)   # keçi sakal
			for sd in [-1.0, 1.0]:
				s.lock(Vector2(sd * 0.035, -0.31), Vector2(sd * 0.045, -0.45), Vector2(sd * 0.02, -0.58), 0.035, 0.008, 0.31, 0.24, 0.8, 2.0)
		3:   # Dördüncü: bandın üstünden geriye-yukarı savrulan vahşi tutamlar, yanlarda dışa sivrilen saç; sert, yara izli
			s.jaw = 0.315; s.chin_w = 0.14; s.brow = 0.036; s.brow_tilt = 0.22; s.eye_tilt = 0.1
			s.nose_h = 0.075; s.nose_tip = -0.15; s.mouth_w = 0.08; s.frown = 1.4; s.age = 0.3; s.scar = true; s.cheek = 0.026
			s.band = true; s.hl_c = 0.27; s.cap_d = 0.33; s.cap_rx = 0.4; s.cap_top = 0.72; s.part = Vector2(0.0, 0.25)
			for k in 7:
				var u0 = -0.3 + 0.1 * float(k)
				var sg = signf(u0) if absf(u0) > 0.01 else 0.0
				s.lock(Vector2(u0, 0.36), Vector2(u0 * 1.3, 0.52), Vector2(u0 * 1.8 + sg * 0.07, 0.6 + 0.07 * cos(u0 * 5.0)), 0.095, 0.012, 0.335, 0.17)
			for sd in [-1.0, 1.0]:
				s.lock(Vector2(sd * 0.33, 0.25), Vector2(sd * 0.45, 0.2), Vector2(sd * 0.55, 0.06), 0.075, 0.01, 0.3, 0.13)
				s.lock(Vector2(sd * 0.32, 0.16), Vector2(sd * 0.42, 0.06), Vector2(sd * 0.5, -0.12), 0.07, 0.01, 0.29, 0.13)
		4:   # Beşinci (kadın): yana taranmış kâkül, yüzü çerçeveleyen uzun tutamlar, arkada uzun saç
			s.jaw = 0.265; s.chin_w = 0.08; s.brow = 0.016; s.brow_w = 0.011; s.brow_tilt = 0.04; s.eye_tilt = 0.06; s.eye_h = 0.033
			s.nose_h = 0.05; s.nose_tip = -0.125; s.mouth_w = 0.058; s.frown = 0.0; s.lip = 1.4; s.cheek = 0.016
			s.hl_c = 0.27; s.hl_side = 0.15; s.cap_d = 0.325; s.cap_rx = 0.36; s.cap_top = 0.56; s.part = Vector2(0.1, 0.52)
			s.lock(Vector2(0.1, 0.5), Vector2(-0.1, 0.38), Vector2(-0.3, 0.16), 0.085, 0.015, 0.345, 0.315)
			s.lock(Vector2(0.08, 0.45), Vector2(-0.02, 0.33), Vector2(-0.13, 0.2), 0.07, 0.012, 0.345, 0.32)
			s.lock(Vector2(0.12, 0.5), Vector2(0.26, 0.42), Vector2(0.3, 0.19), 0.08, 0.015, 0.345, 0.31)
			for sd in [-1.0, 1.0]:
				s.lock(Vector2(sd * 0.27, 0.32), Vector2(sd * 0.38, 0.0), Vector2(sd * 0.33, -0.7), 0.075, 0.035, 0.33, 0.22)
				s.lock(Vector2(sd * 0.33, 0.36), Vector2(sd * 0.47, 0.0), Vector2(sd * 0.42, -0.8), 0.08, 0.04, 0.3, 0.19)
				s.lock(Vector2(sd * 0.38, 0.38), Vector2(sd * 0.56, 0.0), Vector2(sd * 0.52, -0.88), 0.085, 0.045, 0.25, 0.14, 0.7, 2.0)
	return s


## Değişken adımlı eksen: [ca, cb] arası ince, dışı kaba
static func _axis(a: float, b: float, ca: float, cb: float, fine: float, coarse: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var t = a
	while t < b - 0.01:
		out.append(t)
		t += fine if (t >= ca and t <= cb) else coarse
	out.append(b)
	return out


## uçurum yüzeyi (BuildKonoha._cliff_surface ile aynı tarama, daha çok ikili adım: 0.5 m hata kabartmada yatay basamak yapıyordu)
static func _cliff_n(b: Builder, x: float, cliff_n: float, y: float) -> float:
	var nn = cliff_n - 140.0
	while nn < cliff_n + 220.0:
		if BuildKonoha._gy(b, x, nn + 8.0) > y:
			var lo = nn
			var hi = nn + 8.0
			for k in 9:
				var mid = (lo + hi) * 0.5
				if BuildKonoha._gy(b, x, mid) > y:
					hi = mid
				else:
					lo = mid
			return (lo + hi) * 0.5
		nn += 8.0
	return cliff_n


## 1B kutu bulanıklığı (önek toplamı, O(1)/nokta): dizi src (NX*NY), yön 0 = satır boyunca, 1 = sütun boyunca
static func _box(src: PackedFloat32Array, NX: int, NY: int, rad: int, axis: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(NX * NY)
	var L = NX if axis == 0 else NY
	var M = NY if axis == 0 else NX
	var st = 1 if axis == 0 else NX
	var ost = NX if axis == 0 else 1
	var pre := PackedFloat32Array()
	pre.resize(L + 1)
	for m in M:
		var base = m * ost
		var acc = 0.0
		pre[0] = 0.0
		for k in L:
			acc += src[base + k * st]
			pre[k + 1] = acc
		for k in L:
			var k0 = maxi(k - rad, 0)
			var k1 = mini(k + rad + 1, L)
			out[base + k * st] = (pre[k1] - pre[k0]) / float(k1 - k0)
	return out


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + t * (3.0 * (p1 - p2) + p3 - p0)))


static var timing := {}
## surf_const: NAN değilse uçurum taranmaz, düz yüzey kullanılır (hız ölçümü)
static func _head(b: Builder, fx: float, fy: float, cliff_n: float, H: float, col: Color, style: int, surf_const := NAN, top_y := 1e6) -> void:
	var t0 = Time.get_ticks_usec()
	var sc = _sculpt(style)
	sc.seed = 40 + style * 9
	var UW = 0.78; var VB = -1.2
	var VT = minf(0.92, (top_y - 16.0 - fy) / H)   # uçurum ağzının kıvrımına taşmasın (orada yüzey dik değil)
	var W = UW * 2.0 * H
	var CX = 13; var CY = 22
	var surf := PackedFloat32Array()
	surf.resize(CX * CY)
	for jy in CY:
		for ix in CX:
			surf[jy * CX + ix] = surf_const if not is_nan(surf_const) else _cliff_n(b, fx - W * 0.5 + W * ix / float(CX - 1), cliff_n, fy + H * (VB + (VT - VB) * jy / float(CY - 1)))
	# arazi uçurumu basamaklı: örnekleri dikeyde yumuşat (1-2-1, iki kez), yoksa kabartmada yatay ışık bantları çıkıyor
	for _p in 2:
		var sm2 := surf.duplicate()
		for jy in range(1, CY - 1):
			for ix in CX:
				sm2[jy * CX + ix] = (surf[(jy - 1) * CX + ix] + 2.0 * surf[jy * CX + ix] + surf[(jy + 1) * CX + ix]) * 0.25
		surf = sm2
	var t1 = Time.get_ticks_usec()
	# ince ızgara yalnız heykelin olduğu yerde; dış kaya kütlesi kaba
	var xs = _axis(-UW, UW, -0.6, 0.6, 0.6 / H, 1.6 / H)
	var ys = _axis(VB, VT, -0.74, 0.8, 0.6 / H, 1.6 / H)
	var NX = xs.size(); var NY = ys.size()
	var N = NX * NY
	var dep := PackedFloat32Array()
	dep.resize(N)
	for jy in NY:
		var v = ys[jy]
		for ix in NX:
			dep[jy * NX + ix] = sc.depth(xs[ix], v, UW, VB, VT)
	var t2 = Time.get_ticks_usec()
	# hafif yumuşatma (ızgara basamağı kırılmasın) + geniş bulanık derinlik (oyuk koyu / çıkıntı açık renk için)
	dep = _box(_box(dep, NX, NY, 1, 0), NX, NY, 1, 1)
	var blur = _box(_box(dep, NX, NY, 5, 0), NX, NY, 5, 1)
	blur = _box(_box(blur, NX, NY, 4, 0), NX, NY, 4, 1)
	var verts := PackedVector3Array()
	verts.resize(N)
	# yüzey: örnek ızgarasında Catmull-Rom (eğimi sürekli: doğrusal aradeğerin kırıkları ışıkta bant yapıyordu)
	var colv := PackedFloat32Array()   # önce her örnek sütununda satır boyunca dikey aradeğer
	colv.resize(NY * CX)
	for jy in NY:
		var fv = clampf((ys[jy] - VB) / (VT - VB) * (CY - 1), 0.0, CY - 1.001)
		var j0 = int(fv); var cj = fv - j0
		for ix in CX:
			colv[jy * CX + ix] = _cr(surf[maxi(j0 - 1, 0) * CX + ix], surf[j0 * CX + ix], surf[(j0 + 1) * CX + ix], surf[mini(j0 + 2, CY - 1) * CX + ix], cj)
	for jy in NY:
		var y = fy + ys[jy] * H
		for ix in NX:
			var x = fx + xs[ix] * H
			var fu = clampf((xs[ix] + UW) / (2.0 * UW) * (CX - 1), 0.0, CX - 1.001)
			var i0 = int(fu); var ci = fu - i0
			var rb = jy * CX
			var sn = _cr(colv[rb + maxi(i0 - 1, 0)], colv[rb + i0], colv[rb + i0 + 1], colv[rb + mini(i0 + 2, CX - 1)], ci)
			# kaya kütlesinin dışı uçurumun içinde (kenar 3 m içeri dalar): birleşim çizgisi kütlenin düzensiz kenarını izler
			var d0 = dep[jy * NX + ix]
			verts[jy * NX + ix] = b.w(Vector3(x, y, sn - d0 * H + 0.6 + 2.5 * (1.0 - _sm(d0 / 0.025))))
	var norms := PackedVector3Array()
	norms.resize(N)
	var cols := PackedColorArray()
	cols.resize(N)
	for jy in NY:
		var ju = mini(jy + 1, NY - 1) * NX; var jd = maxi(jy - 1, 0) * NX
		for ix in NX:
			var k = jy * NX + ix
			var nn = (verts[jy * NX + mini(ix + 1, NX - 1)] - verts[jy * NX + maxi(ix - 1, 0)]).cross(verts[ju + ix] - verts[jd + ix])
			norms[k] = nn.normalized() if nn.length_squared() > 1e-10 else Vector3(0, 0, 1)
			var diff = blur[k] - dep[k]
			var wx = verts[k]
			var tone = 0.9 + 0.2 * Sculpt._vn(wx.x * 0.05, wx.y * 0.012, 21)
			tone *= lerpf(1.04, 0.8, _sm((Sculpt._vn(wx.x * 0.09, wx.y * 0.01, 23) - 0.6) / 0.25))   # dikey akıntı izleri
			cols[k] = Color(col.r * tone, col.g * tone, col.b * tone).darkened(clampf(diff * 7.0, 0.0, 0.42)).lightened(clampf(-diff * 2.5, 0.0, 0.08))
	var idx := PackedInt32Array()
	idx.resize((NX - 1) * (NY - 1) * 6)
	var q = 0
	for jy in NY - 1:
		for ix in NX - 1:
			var i00 = jy * NX + ix
			var i01 = i00 + NX
			idx[q] = i00; idx[q + 1] = i01 + 1; idx[q + 2] = i00 + 1   # ön yüz köye bakar
			idx[q + 3] = i00; idx[q + 4] = i01; idx[q + 5] = i01 + 1
			q += 6
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi = MeshInstance3D.new()
	mi.name = "HokageMonument%d" % style
	mi.mesh = mesh
	mi.material_override = Props.toon()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	b.root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var t3 = Time.get_ticks_usec()
	# test ölçümü: burun ucu
	var nj = 0
	while nj < NY - 1 and ys[nj] < sc.nose_tip:
		nj += 1
	var ni = 0
	while ni < NX - 1 and xs[ni] < 0.0:
		ni += 1
	probes.append(verts[nj * NX + ni])
	# çarpışma: aynı yüzeyin seyreltilmiş üçgen ağı (~1.8 m; yüze, saça basılır, tırmanılır). Kütlenin tamamen uçurum
	# içinde kalan dış hücreleri atlanır (arazi zaten çarpışır)
	if is_instance_valid(b.body) and is_nan(surf_const):
		var cjs: Array = []
		var k2 = 0
		while k2 < NY - 1:
			cjs.append(k2)
			k2 += 3
		cjs.append(NY - 1)
		var cis: Array = []
		k2 = 0
		while k2 < NX - 1:
			cis.append(k2)
			k2 += 3
		cis.append(NX - 1)
		var faces := PackedVector3Array()
		for a in cjs.size() - 1:
			for c in cis.size() - 1:
				var j0b: int = cjs[a]; var j1b: int = cjs[a + 1]; var i0b: int = cis[c]; var i1b: int = cis[c + 1]
				if dep[j0b * NX + i0b] <= 0.0 and dep[j0b * NX + i1b] <= 0.0 and dep[j1b * NX + i0b] <= 0.0 and dep[j1b * NX + i1b] <= 0.0:
					continue
				var p00 = verts[j0b * NX + i0b]; var p10 = verts[j0b * NX + i1b]
				var p01 = verts[j1b * NX + i0b]; var p11 = verts[j1b * NX + i1b]
				faces.append_array(PackedVector3Array([p00, p11, p10, p00, p01, p11]))
		var tri = ConcavePolygonShape3D.new()
		tri.set_faces(faces)
		var cs = CollisionShape3D.new()
		cs.shape = tri
		b.add_shape(cs)
	var t4 = Time.get_ticks_usec()
	for kk in ["surf", "depth", "mesh", "coll"]:
		if not timing.has(kk):
			timing[kk] = 0.0
	timing["surf"] += (t1 - t0) / 1000.0; timing["depth"] += (t2 - t1) / 1000.0
	timing["mesh"] += (t3 - t2) / 1000.0; timing["coll"] += (t4 - t3) / 1000.0
	timing["verts"] = int(timing.get("verts", 0)) + N
