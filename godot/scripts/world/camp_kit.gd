class_name CampKit
extends RefCounted
## Kamp parçaları (kaçak kampı, haydut kampı, kaçak sığınağı, mağara inleri, antrenman kuklası).
## Eskiden düz üçgen prizma çadır + turuncu koni ateş + yuvarlak küre kaya vardı ("kampa bile benzemiyor").
## Kaynak: Narutopedia Third Training Ground (kütük direkler), Otogakure / Kusagakure saklanma yerleri (düzensiz kaya yığını, karanlık ağız).

const ROPE := Color(0.72, 0.64, 0.46)
const POLE := Color(0.36, 0.26, 0.16)
const STONE := Color(0.46, 0.44, 0.41)


static func _p(b: MB, base: Transform3D, kind: String, pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, seg := 8) -> void:
	var bs := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	b.add_xf(kind, base * Transform3D(bs * Basis.from_scale(size), pos), col, seg)


## İki nokta arası ip / sırık (silindir)
static func _rod(b: MB, base: Transform3D, a: Vector3, c: Vector3, r: float, col: Color, seg := 5) -> void:
	_rodk(b, base, "cyl", a, c, r, col, seg)


## İki nokta arası primitif (cyl / cone: koninin ucu c'de)
static func _rodk(b: MB, base: Transform3D, kind: String, a: Vector3, c: Vector3, r: float, col: Color, seg := 5) -> void:
	var d := c - a
	var L := d.length()
	if L < 0.01:
		return
	var y := d / L
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var bs := Basis(x * r * 2.0, y * L, z * r * 2.0)
	b.add_xf(kind, base * Transform3D(bs, (a + c) * 0.5), col, seg)


## Çadır / sundurma çarpışma listesini ([dünya Transform3D, boyut] kutular) bir Builder gövdesine ekler
static func add_cols(b: Builder, cols: Array) -> void:
	for c in cols:
		if not is_instance_valid(b.body):
			return
		var t: Transform3D = c[0]
		var size: Vector3 = c[1]
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.transform = Transform3D(t.basis.orthonormalized(), t.origin)
		b.add_shape(cs)
		b.add_solid(t.origin, size.x * 0.5, size.z * 0.5, 0.0)


## ---------------------------------------------------------------- bez çadırlar
## Kaynak (refs/bandit_camp): sb_camp_pot (kanvas duvar çadırı: dikmeler arasında sarkan çatı, kapak bağlı açık kapı, karanlık iç,
## eteğe gerilmiş halat + kazık, tencere sehpası), sb_canopy_camp (mahya çadırları, halatlar), Sensordivision (iç iskelet),
## sb_official_camp (eşyaların üstüne gerilmiş derme bezler). Eskiden düz eğik kutu / prizma vardı ("çadırlar rezil").

static func _h(i: int, j: int, s: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(j) * 78.233 + float(s) * 37.719) * 43758.5453, 1.0)


## Bez yüzey: f(u, v) -> yerel nokta (u, v 0..1), nu x nv ızgara. İki yüzlü: dış yüz bez rengi (leke, kir, eskime),
## iç yüz koyu (çadırın içi karanlık görünür). ctr: dış yönü bulmak için yüzeyin "içindeki" yerel nokta.
## Toon gölgelendirici cull_back: dış yüz saat yönü (Godot ön yüz), iç yüz ters sırayla yazılır.
static func _cloth(b: MB, base: Transform3D, f: Callable, nu: int, nv: int, col: Color, ctr: Vector3, sd: int, mud := 0.32, inner_dk := 0.62) -> void:
	var P: Array = []
	for j in nv + 1:
		for i in nu + 1:
			P.append(f.call(float(i) / nu, float(j) / nv))
	var N: Array = []
	N.resize(P.size())
	var C: Array = []
	C.resize(P.size())
	var dirt := Color(0.3, 0.24, 0.16)
	for j in nv + 1:
		for i in nu + 1:
			var k := j * (nu + 1) + i
			var du: Vector3 = P[j * (nu + 1) + mini(i + 1, nu)] - P[j * (nu + 1) + maxi(i - 1, 0)]
			var dv: Vector3 = P[mini(j + 1, nv) * (nu + 1) + i] - P[maxi(j - 1, 0) * (nu + 1) + i]
			var n := du.cross(dv).normalized()
			if n.dot(P[k] - ctr) < 0.0:
				n = -n
			N[k] = n
			# renk: hafif doku gürültüsü + yağmur izi (sütun boyu koyu çizgi) + etekte çamur
			var p: Vector3 = P[k]
			var c := col.lerp(col.darkened(0.25), _h(i, j, sd) * 0.35)
			if _h(i, 0, sd + 7) > 0.78:
				c = c.darkened(0.1)
			if p.y < mud:
				c = c.lerp(dirt, (1.0 - p.y / mud) * 0.55)
			C[k] = c
	var nb := base.basis.inverse().transposed()
	for side in 2:
		var o := b.verts.size()
		for k in P.size():
			var n: Vector3 = N[k] if side == 0 else -N[k]
			b.verts.append(base * (P[k] + n * 0.006))
			b.normals.append((nb * n).normalized())
			b.colors.append(C[k] if side == 0 else (C[k] as Color).darkened(inner_dk))
			b.uvs.append(Vector2.ZERO)
		for j in nv:
			for i in nu:
				var a := o + j * (nu + 1) + i
				var q := [a, a + 1, a + nu + 2, a, a + nu + 2, a + nu + 1]
				for t in 2:
					var i0: int = q[t * 3]; var i1: int = q[t * 3 + 1]; var i2: int = q[t * 3 + 2]
					var cr := (b.verts[i1] - b.verts[i0]).cross(b.verts[i2] - b.verts[i0])
					if cr.dot(b.normals[i0]) > 0.0:
						b.idx.append_array([i0, i2, i1])
					else:
						b.idx.append_array([i0, i1, i2])


## Yere çakılı kazık + kazığa giden gergin halat (hafif sarkık)
static func _guy(b: MB, base: Transform3D, a: Vector3, stake: Vector3) -> void:
	var top := stake + Vector3(0, 0.16, 0)
	var mid := (a + top) * 0.5 - Vector3(0, 0.03 * a.distance_to(top), 0)
	_rod(b, base, a, mid, 0.011, ROPE, 4)
	_rod(b, base, mid, top, 0.011, ROPE, 4)
	var out := Vector3(stake.x - a.x, 0, stake.z - a.z).normalized()
	_rod(b, base, stake - Vector3(0, 0.08, 0), stake + Vector3(0, 0.22, 0) + out * 0.08, 0.03, POLE.lightened(0.1), 4)


## Kenarı yere çevrilmiş yama bez (çadır yüzüne dikilmiş başka renk parça): yüzeyin u0..u1, v0..v1 kısmı
static func _patch(b: MB, base: Transform3D, f: Callable, u0: float, u1: float, v0: float, v1: float, col: Color, ctr: Vector3, sd: int) -> void:
	var g := func(u: float, v: float) -> Vector3:
		var p: Vector3 = f.call(lerpf(u0, u1, u), lerpf(v0, v1, v))
		return p + (p - ctr).normalized() * 0.012
	_cloth(b, base, g, 2, 2, col, ctr, sd, 0.0)


## Mahya (A / duvar) çadırı. base: zemindeki taban ortası, +z = ön (kapı). W genişlik, H mahya, L boy, hw yan duvar boyu (0 = A çadırı).
## Çatı bezi dikmeler arasında sarkar (catenary ~ sin), mahya hafif çöker, sol kapak yarı açık, sağ kapak toplanıp bağlanmış,
## iç karanlık; mahya sırığı, dikmeler, etek halatları + kazıklar; içte yer örtüsü, dürülü yataklar, bohça.
## cols verilirse çarpışma kutuları [dünya Transform3D, boyut] eklenir (iki çatı yüzü, arka duvar, kapalı kapak: içine girilebilir).
static func tent(b: MB, base: Transform3D, cloth: Color, W := 2.8, H := 2.0, L := 3.4, rng: RandomNumberGenerator = null, hw := 0.0, cols = null) -> void:
	var sd := int(absf(base.origin.x * 13.0 + base.origin.z * 7.0)) % 9973
	var hx := W * 0.5
	var spans := 2 if L > 4.2 else 1
	var sag := 0.07 + 0.02 * L / 3.4
	var ridge_y := func(v: float) -> float: return H - 0.045 * absf(sin(PI * v * spans))
	var span_s := func(v: float) -> float: return absf(sin(PI * v * spans))
	var ctr := Vector3(0, H * 0.4, 0)
	var nu := 6
	var nv := 8 * spans
	for sx: float in [-1.0, 1.0]:
		var roof := func(u: float, v: float) -> Vector3:
			var z := lerpf(-L * 0.5, L * 0.5, v)
			var R := Vector3(0, ridge_y.call(v), z)
			var E := Vector3(sx * hx, hw - 0.04 * span_s.call(v), z)
			var inw := Vector3(-sx * (H - hw), -hx, 0).normalized()   # bezin içe / aşağı yönü
			var s: float = sag * sin(PI * u) * (0.35 + 0.65 * span_s.call(v)) + 0.012 * sin(u * 9.0 + v * 5.0)
			return R.lerp(E, u) + inw * s
		_cloth(b, base, roof, nu, nv, cloth, ctr, sd + int(sx + 1))
		var pc := cloth.lerp(Color(0.62, 0.55, 0.4), 0.5) if (sd + int(sx)) % 2 == 0 else cloth.darkened(0.2)
		_patch(b, base, roof, 0.3, 0.55, 0.2 + 0.3 * float(sd % 3) / 3.0, 0.35 + 0.3 * float(sd % 3) / 3.0, pc, ctr, sd + 11)
		if hw > 0.05:
			var wall := func(u: float, v: float) -> Vector3:
				var z := lerpf(-L * 0.5, L * 0.5, v)
				var top := Vector3(sx * hx, hw - 0.04 * span_s.call(v), z)
				var bot := Vector3(sx * (hx + 0.08), 0.0, z)
				return top.lerp(bot, u) + Vector3(-sx * 0.035 * sin(PI * u) * span_s.call(v), 0, 0)
			_cloth(b, base, wall, 3, nv, cloth.darkened(0.06), ctr, sd + 5 + int(sx + 1))
			for k in spans + 1:   # yan duvar dikmeleri
				var z := lerpf(-L * 0.5, L * 0.5, float(k) / spans)
				_rod(b, base, Vector3(sx * hx, 0, z), Vector3(sx * hx, hw + 0.05, z), 0.03, POLE, 5)
		# saçak / etek halatları: her dikme hizasında dışarıdaki kazığa
		for k in spans + 1:
			var z := lerpf(-L * 0.5, L * 0.5, float(k) / spans) * 0.94
			var a := Vector3(sx * hx, maxf(hw, 0.12), z)
			_guy(b, base, a, Vector3(sx * (hx + 0.7 + hw * 0.6 + H * 0.25), 0, z * 1.05))
		if cols != null:
			var mid := Vector3(sx * hx * 0.5, (H + hw) * 0.5, 0)
			var sl := Vector2(hx, H - hw).length()
			var ang: float = atan2(H - hw, hx) * -sx
			cols.append([base * Transform3D(Basis(Vector3.BACK, ang), mid), Vector3(sl, 0.12, L)])
			if hw > 0.05:
				cols.append([base * Transform3D(Basis(), Vector3(sx * hx, hw * 0.5, 0)), Vector3(0.1, hw, L)])
	# arka duvar (beşgen: duvar + üçgen alın), içe hafif sarkık
	var gable_top := func(x: float) -> float: return hw + (H - hw) * (1.0 - absf(x) / hx)
	var back := func(u: float, v: float) -> Vector3:
		var x := lerpf(-hx, hx, u)
		return Vector3(x, v * gable_top.call(x), -L * 0.5 + 0.04 * sin(PI * v) * (1.0 - absf(x) / hx))
	_cloth(b, base, back, 6, 4, cloth.darkened(0.08), ctr, sd + 21)
	# ön: sol kapak yarı açık (alt köşesi geri çekik), sağ kapak toplanıp yan dikmeye bağlanmış
	var flap := func(u: float, v: float) -> Vector3:
		var xe := lerpf(-W * 0.16, 0.0, v)
		var x := lerpf(-hx, xe, u)
		return Vector3(x, v * gable_top.call(x) * (1.0 - 0.02 * u), L * 0.5 + 0.07 * sin(PI * u) * (0.3 + v))
	_cloth(b, base, flap, 4, 5, cloth.darkened(0.03), ctr, sd + 31)
	var fold := func(u: float, v: float) -> Vector3:   # toplanmış sağ kapak: rulo köşegeni ile çatı kenarı arasındaki üçgen bez
		var a := Vector3(hx - 0.05, 0.08, L * 0.5 + 0.03).lerp(Vector3(0.08, H - 0.1, L * 0.5 + 0.03), v)
		var c := Vector3(hx, hw, L * 0.5 + 0.02).lerp(Vector3(0.04, H - 0.04, L * 0.5 + 0.02), v)
		return a.lerp(c, u) + Vector3(0, 0, 0.04 * sin(PI * u) * (1.0 - v))
	_cloth(b, base, fold, 2, 5, cloth.lightened(0.04), ctr, sd + 41)
	_rod(b, base, Vector3(hx - 0.05, 0.08, L * 0.5 + 0.09), Vector3(0.1, H - 0.12, L * 0.5 + 0.09), 0.075, cloth.darkened(0.12), 6)   # rulo
	var tie := Vector3(hx, 0.08, L * 0.5 + 0.09).lerp(Vector3(0.1, H - 0.12, L * 0.5 + 0.09), 0.45)
	_p(b, base, "torus", tie, Vector3(0.2, 0.22, 0.2), ROPE, Vector3(0, 0, -rad_to_deg(atan2(H, hx)) + 90.0), 8)
	if cols != null:
		cols.append([base * Transform3D(Basis(), Vector3(0, (H + hw) * 0.4, -L * 0.5)), Vector3(W * 0.9, (H + hw) * 0.8, 0.1)])
		cols.append([base * Transform3D(Basis(), Vector3(-hx * 0.62, (H + hw) * 0.35, L * 0.5)), Vector3(hx * 0.7, (H + hw) * 0.7, 0.1)])
	# mahya sırığı (uçları dışarı taşar), ön / arka dikme, uç halatları
	_rod(b, base, Vector3(0, H + 0.02, -L * 0.5 - 0.22), Vector3(0, H + 0.02, L * 0.5 + 0.22), 0.04, POLE, 6)
	for k in spans + 1:
		var z := lerpf(-L * 0.5, L * 0.5, float(k) / spans)
		_rod(b, base, Vector3(0, 0, z), Vector3(0, ridge_y.call(float(k) / spans) + 0.12, z), 0.038, POLE, 6)
	for sz in [-1.0, 1.0]:
		_guy(b, base, Vector3(0, H, sz * (L * 0.5 + 0.18)), Vector3(0, 0, sz * (L * 0.5 + H * 0.75 + 0.3)))
	# zemin: çiğnenmiş taban izi, yer örtüsü, dürülü yataklar, bohça, testi
	_p(b, base, "box", Vector3(0, 0.025, -0.1), Vector3(W - 0.35, 0.025, L - 0.4), Color(0.36, 0.3, 0.22))
	var r1: float = rng.randf() if rng != null else _h(sd, 1, 3)
	var bed := [Color(0.46, 0.36, 0.48), Color(0.33, 0.4, 0.5), Color(0.5, 0.32, 0.26), Color(0.42, 0.44, 0.33)]
	_p(b, base, "cyl", Vector3(-hx * 0.45, 0.16, -0.25), Vector3(0.3, L * 0.5, 0.3), bed[int(r1 * 4.0) % 4], Vector3(90, 0, 0), 8)
	if W > 2.5:
		_p(b, base, "box", Vector3(hx * 0.4, 0.06, -0.3), Vector3(0.75, 0.08, L * 0.6), bed[(int(r1 * 4.0) + 1) % 4], Vector3(0, 4, 0))   # serili döşek
		_p(b, base, "cyl", Vector3(hx * 0.4, 0.13, -L * 0.3 + 0.05), Vector3(0.24, 0.6, 0.24), bed[(int(r1 * 4.0) + 2) % 4], Vector3(0, 0, 90), 7)
	_p(b, base, "sphere", Vector3(hx * 0.5, 0.2, -L * 0.42), Vector3(0.5, 0.38, 0.44), Color(0.58, 0.5, 0.36), Vector3.ZERO, 7)
	_p(b, base, "cyl", Vector3(-hx * 0.7, 0.16, L * 0.3), Vector3(0.2, 0.32, 0.2), Color(0.55, 0.38, 0.24), Vector3.ZERO, 7)


## Konik çadır (merkez dikme + kaburgalar): her kaburga arasında bez içe sarkar, bir dilimde açık kapı (üstü bez, altı karanlık
## ağız, iki yanda toplanmış kapaklar), tepeden çıkan sırık uçları, kaburga halatları. base: taban ortası, +z kapı.
static func cone_tent(b: MB, base: Transform3D, cloth: Color, R := 1.9, H := 2.9, cols = null) -> void:
	var sd := int(absf(base.origin.x * 11.0 + base.origin.z * 17.0)) % 9973
	var nr := 8
	var apex := Vector3(0, H, 0)
	var ctr := Vector3(0, H * 0.35, 0)
	for k in nr:
		var a0 := TAU * (k - 0.5) / nr + PI * 0.5   # 0. dilim +z (kapı)
		var a1 := TAU * (k + 0.5) / nr + PI * 0.5
		var door := k == 0
		var panel := func(u: float, v: float) -> Vector3:
			var a := lerpf(a0, a1, v)
			var g := Vector3(cos(a) * R, 0.0, sin(a) * R)
			var p := apex.lerp(g, u)
			var s := 0.11 * sin(PI * v) * sin(PI * u * 0.9)
			return p - Vector3(cos(a), 0, sin(a)) * s
		if door:
			# kapı dilimi: üst %45 bez; altı açık
			var upper := func(u: float, v: float) -> Vector3: return panel.call(u * 0.45, v)
			_cloth(b, base, upper, 3, 4, cloth.darkened(0.04), ctr, sd + k)
			for sv in [0.0, 1.0]:   # iki yana toplanmış kapak ruloları
				var top: Vector3 = panel.call(0.45, sv * 0.86 + 0.07)
				var bot: Vector3 = panel.call(1.0, sv * 0.7 + 0.15) + Vector3(0, 0.05, 0)
				_rod(b, base, top.lerp(bot, 0.15), bot, 0.05, cloth.darkened(0.12), 6)
		else:
			_cloth(b, base, panel, 5, 4, cloth if k % 3 else cloth.darkened(0.07), ctr, sd + k)
	for k in nr:   # kaburga sırıkları (tepeden dışarı taşar) + halatlar
		var a := TAU * (k + 0.5) / nr + PI * 0.5
		var g := Vector3(cos(a) * R, 0.0, sin(a) * R)
		var top := apex + (apex - g).normalized() * 0.45
		_rod(b, base, g, top, 0.028, POLE, 4)
		if k % 2 == 1:
			var at := apex.lerp(g, 0.62)
			_guy(b, base, at, Vector3(cos(a) * (R + 1.1), 0, sin(a) * (R + 1.1)))
	_rod(b, base, Vector3.ZERO, apex + Vector3(0, 0.1, 0), 0.045, POLE, 6)
	var pf := func(u: float, v: float) -> Vector3:
		var a := lerpf(TAU * 2.6 / nr, TAU * 3.2 / nr, v) + PI * 0.5
		return apex.lerp(Vector3(cos(a) * R, 0.0, sin(a) * R), lerpf(0.4, 0.7, u)) - Vector3(cos(a), 0, sin(a)) * 0.11 * sin(PI * (v * 0.6 + 0.2)) * 0.6
	_patch(b, base, pf, 0.0, 1.0, 0.0, 1.0, cloth.lerp(Color(0.6, 0.35, 0.25), 0.4), ctr, sd + 50)
	_p(b, base, "cyl", Vector3(0, 0.02, 0), Vector3(R * 1.7, 0.02, R * 1.7), Color(0.4, 0.3, 0.24), Vector3.ZERO, 10)   # hasır
	_p(b, base, "cyl", Vector3(-0.6, 0.15, -0.5), Vector3(0.28, 1.2, 0.28), Color(0.38, 0.4, 0.5), Vector3(90, 30, 0), 8)
	if cols != null:   # dilim başına eğik ince kutu (kapı dilimi yok: içine girilir)
		for k in range(1, nr):
			var a := TAU * k / nr + PI * 0.5
			var g := Vector3(cos(a) * R, 0.0, sin(a) * R)
			var mid := (apex + g) * 0.5
			var zx := (g - apex).normalized()
			var xx := Vector3(-sin(a), 0, cos(a))
			cols.append([base * Transform3D(Basis(xx, zx.cross(xx), zx), mid), Vector3(TAU * R / nr * 0.55, 0.1, apex.distance_to(g))])


## Sundurma (yarım çadır): önde iki dikme + kiriş, bez kirişten arkaya yere iner (sarkık), yanları açık. base: ön orta, +z ön.
## Altına eşya konur. cols: üst bez eğik kutu + dikmeler
static func lean_to(b: MB, base: Transform3D, cloth: Color, W := 4.0, D := 3.0, Hf := 2.2, cols = null) -> void:
	var sd := int(absf(base.origin.x * 5.0 + base.origin.z * 3.0)) % 9973
	var Hb := 0.35
	var sheet := func(u: float, v: float) -> Vector3:
		var x := lerpf(-W * 0.5, W * 0.5, u)
		var f := Vector3(x, Hf - 0.05 * absf(sin(PI * u)), 0.05)
		var bk := Vector3(x, Hb, -D)
		var p := f.lerp(bk, v)
		return p - Vector3(0, 0.13 * sin(PI * v) * (0.4 + 0.6 * absf(sin(PI * u))), 0)
	_cloth(b, base, sheet, 8, 5, cloth, Vector3(0, -2.0, -D * 0.5), sd, 0.32, 0.3)
	_patch(b, base, sheet, 0.55, 0.8, 0.3, 0.6, cloth.lerp(Color(0.32, 0.36, 0.42), 0.6), Vector3(0, -2.0, -D * 0.5), sd + 3)
	_rod(b, base, Vector3(-W * 0.5 - 0.25, Hf + 0.04, 0.05), Vector3(W * 0.5 + 0.25, Hf + 0.04, 0.05), 0.05, POLE, 6)
	for sx in [-1.0, 1.0]:
		_rod(b, base, Vector3(sx * W * 0.5, 0, 0.05), Vector3(sx * W * 0.5, Hf + 0.12, 0.05), 0.055, POLE, 6)
		_guy(b, base, Vector3(sx * W * 0.5, Hf, 0.05), Vector3(sx * (W * 0.5 + 0.6), 0, 1.3))
		_guy(b, base, Vector3(sx * W * 0.5, Hb, -D), Vector3(sx * W * 0.5, 0, -D - 0.6))
	if cols != null:
		var mid := Vector3(0, (Hf + Hb) * 0.5, -D * 0.5)
		var ang := atan2(Hf - Hb, D)
		cols.append([base * Transform3D(Basis(Vector3.RIGHT, -ang), mid), Vector3(W, 0.1, Vector2(D, Hf - Hb).length())])


## İki direk arasında sarkık ip + asılı çamaşır / bez (ip yerel x boyunca). base: ilk direğin dibi. L ip boyu, h ip yüksekliği.
static func cloth_line(b: MB, base: Transform3D, L: float, h: float, cols_rng: RandomNumberGenerator) -> void:
	for sx in [0.0, 1.0]:
		_rod(b, base, Vector3(sx * L, 0, 0), Vector3(sx * L, h + 0.15, 0), 0.05, POLE, 5)
	var seg := 8
	var prev := Vector3(0, h, 0)
	var y_at := func(x: float) -> float: return h - 0.28 * sin(PI * x / L)
	for k in range(1, seg + 1):
		var x := L * k / seg
		var p := Vector3(x, y_at.call(x), 0)
		_rod(b, base, prev, p, 0.01, ROPE, 4)
		prev = p
	var x0 := 0.4
	var cs := [Color(0.78, 0.74, 0.62), Color(0.45, 0.32, 0.26), Color(0.36, 0.4, 0.48), Color(0.6, 0.22, 0.18), Color(0.3, 0.3, 0.28)]
	while x0 < L - 0.6:
		var w := cols_rng.randf_range(0.45, 0.9)
		var dl := cols_rng.randf_range(0.5, 0.95)
		var c: Color = cs[cols_rng.randi() % cs.size()]
		var xa := x0
		var hang := func(u: float, v: float) -> Vector3:
			var x := xa + u * w
			return Vector3(x, y_at.call(x) - v * dl + 0.03 * sin(PI * u) * v, 0.04 * sin(u * 6.0 + v * 3.0))
		_cloth(b, base, hang, 3, 3, c, Vector3(xa + w * 0.5, 0, -1.0), int(x0 * 100.0), -1.0, 0.15)
		_p(b, base, "box", Vector3(xa + 0.04, y_at.call(xa) + 0.03, 0), Vector3(0.03, 0.08, 0.05), POLE.lightened(0.2))
		x0 += w + cols_rng.randf_range(0.12, 0.45)


## Sandık (çivili kapaklı, demir köşeli)
static func crate(b: MB, base: Transform3D, s := 0.9, col := Color(0.52, 0.38, 0.22)) -> void:
	_p(b, base, "box", Vector3(0, s * 0.5, 0), Vector3(s, s, s), col)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_p(b, base, "box", Vector3(sx * s * 0.47, s * 0.5, sz * s * 0.47), Vector3(0.09, s + 0.01, 0.09), col.darkened(0.25))
	_p(b, base, "box", Vector3(0, s * 0.5, 0), Vector3(s + 0.02, 0.08, s + 0.02), col.darkened(0.15))
	_p(b, base, "box", Vector3(0, s + 0.005, 0), Vector3(s * 0.96, 0.02, 0.08), col.lightened(0.08), Vector3(0, 45, 0))


## Fıçı: şişkin gövde, iki çember, kapak
static func barrel(b: MB, base: Transform3D, h := 1.0, col := Color(0.48, 0.33, 0.2)) -> void:
	var r := h * 0.36
	for k in 3:
		var y := h * (k + 0.5) / 3.0
		var rr := r * (1.0 if k == 1 else 0.9)
		_p(b, base, "cyl", Vector3(0, y, 0), Vector3(rr * 2.0, h / 3.0 + 0.01, rr * 2.0), col.darkened(0.04 * k), Vector3.ZERO, 10)
	for y in [h * 0.2, h * 0.8]:
		_p(b, base, "cyl", Vector3(0, y, 0), Vector3(r * 2.0 * 0.97, 0.06, r * 2.0 * 0.97), Color(0.26, 0.25, 0.25), Vector3.ZERO, 10)
	_p(b, base, "cyl", Vector3(0, h, 0), Vector3(r * 1.75, 0.03, r * 1.75), col.darkened(0.2), Vector3.ZERO, 10)


## Çuval (bağlı ağızlı)
static func sack(b: MB, base: Transform3D, s := 1.0, col := Color(0.66, 0.58, 0.42)) -> void:
	_p(b, base, "sphere", Vector3(0, 0.3 * s, 0), Vector3(0.62, 0.62, 0.5) * s, col, Vector3.ZERO, 8)
	_p(b, base, "cone", Vector3(0, 0.66 * s, 0), Vector3(0.22, 0.2, 0.22) * s, col.darkened(0.1), Vector3.ZERO, 6)
	_p(b, base, "torus", Vector3(0, 0.58 * s, 0), Vector3(0.18, 0.15, 0.18) * s, ROPE, Vector3.ZERO, 8)


## Silah sehpası: iki A ayak + yatay kiriş, kirişe dayalı mızrak / naginata / kılıçlar
static func weapon_rack(b: MB, base: Transform3D, rng: RandomNumberGenerator) -> void:
	var wd := Color(0.4, 0.29, 0.18)
	for sx in [-1.0, 1.0]:
		_rod(b, base, Vector3(sx * 1.0, 0, -0.45), Vector3(sx * 1.0, 1.5, 0), 0.04, wd, 5)
		_rod(b, base, Vector3(sx * 1.0, 0, 0.45), Vector3(sx * 1.0, 1.5, 0), 0.04, wd, 5)
	_rod(b, base, Vector3(-1.15, 1.45, 0), Vector3(1.15, 1.45, 0), 0.045, wd.darkened(0.1), 6)
	_rod(b, base, Vector3(-1.0, 0.35, 0.2), Vector3(1.0, 0.35, 0.2), 0.03, wd, 5)
	var steel := Color(0.72, 0.74, 0.78)
	for k in 5:
		var x := -0.8 + k * 0.4 + rng.randf_range(-0.05, 0.05)
		var foot := Vector3(x, 0.0, 0.42 + rng.randf_range(-0.04, 0.06))
		var lean := Vector3(x + rng.randf_range(-0.08, 0.08), 1.48, 0.06)
		var dir := (lean - foot).normalized()
		match k % 3:
			0:   # mızrak
				var tip := foot + dir * 2.3
				_rod(b, base, foot, tip, 0.022, Color(0.45, 0.33, 0.2), 4)
				_rodk(b, base, "cone", tip, tip + dir * 0.3, 0.035, steel, 4)
			1:   # naginata (kavisli ağız)
				var tip2 := foot + dir * 2.0
				_rod(b, base, foot, tip2, 0.025, Color(0.22, 0.16, 0.12), 4)
				_rod(b, base, tip2, tip2 + dir * 0.45 + Vector3(0, 0, 0.06), 0.03, steel, 4)
			2:   # kılıç (kında)
				_rod(b, base, foot + Vector3(0, 0.05, 0), foot + dir * 1.0, 0.03, Color(0.15, 0.13, 0.12), 5)
				_rod(b, base, foot + dir * 1.0, foot + dir * 1.25, 0.022, Color(0.5, 0.3, 0.2), 4)
				_rod(b, base, foot + dir * 0.99, foot + dir * 1.01, 0.06, Color(0.55, 0.5, 0.3), 8)


## Kamp ateşi: taş halka, çadır gibi çatılmış odunlar, kömür / köz yatağı, tencere sehpası (alevi fire_fx verir)
static func campfire(b: MB, base: Transform3D, pot := true) -> void:
	_p(b, base, "cyl", Vector3(0, 0.02, 0), Vector3(1.5, 0.04, 1.5), Color(0.12, 0.1, 0.09), Vector3.ZERO, 12)   # is lekesi
	for k in 10:
		var a := TAU * k / 10.0
		_p(b, base, "boulder", Vector3(cos(a) * 0.82, 0.1, sin(a) * 0.82), Vector3(0.36, 0.26, 0.3), STONE.darkened(0.05 * (k % 3)), Vector3(0, rad_to_deg(-a), 0), 20 + k)
	for k in 5:
		_p(b, base, "cyl", Vector3(0, 0.32, 0).rotated(Vector3.UP, TAU * k / 5.0) + Vector3(cos(TAU * k / 5.0), 0, sin(TAU * k / 5.0)) * 0.18, Vector3(0.09, 0.85, 0.09), Color(0.3, 0.2, 0.12), Vector3(32, -rad_to_deg(TAU * k / 5.0) + 90.0, 0), 5)
	for k in 7:   # közler
		var a := TAU * k / 7.0 + 0.3
		_p(b, base, "boulder", Vector3(cos(a) * 0.32, 0.05, sin(a) * 0.32), Vector3(0.16, 0.08, 0.14), Color(0.95, 0.35, 0.1) if k % 2 == 0 else Color(0.25, 0.12, 0.08), Vector3(0, k * 40.0, 0), 40 + k)
	if pot:
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			_rod(b, base, Vector3(cos(a) * 0.95, 0.0, sin(a) * 0.95), Vector3(0, 1.55, 0), 0.03, POLE, 5)
		_rod(b, base, Vector3(0, 1.55, 0), Vector3(0, 1.05, 0), 0.008, Color(0.2, 0.2, 0.2), 4)
		_p(b, base, "hemi", Vector3(0, 1.05, 0), Vector3(0.5, 0.5, 0.5), Color(0.18, 0.18, 0.2), Vector3(180, 0, 0), 10)
		_p(b, base, "torus", Vector3(0, 1.05, 0), Vector3(0.52, 0.5, 0.52), Color(0.25, 0.25, 0.27), Vector3.ZERO, 10)


## Gerçek alev (parçacık) + titreyen ışık: kamp ateşi / meşale
static func fire_fx(parent: Node, at: Vector3, s := 1.0) -> void:
	var fire = FX.burst(at + Vector3.UP * 0.25 * s, {"parent": parent, "amount": int(34 * s) + 8, "life": 0.65, "explosive": 0.0, "add": false, "cel": true, "hot": 0.8, "tex": FX.tex_soft, "size": 0.55 * s, "radius": 0.25 * s,
		"vmin": 0.6 * s, "vmax": 1.5 * s, "dir": Vector3.UP, "spread": 14.0, "gravity": Vector3(0, 1.5, 0),
		"colors": [Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.12, 0.7), Color(0.4, 0.15, 0.05, 0.0)]})
	if fire:
		# FX.burst kısa efekt sayar ve birkaç saniyede siler (eski sığınak ateşi bu yüzden hiç yanmıyordu): sürekli yanan kopya kalır
		var keep: GPUParticles3D = fire.duplicate(0)
		keep.one_shot = false
		parent.add_child(keep)
		keep.global_transform = fire.global_transform
		keep.emitting = true
		fire.queue_free()
	var fl = OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.3)
	fl.light_energy = 1.8 * s
	fl.omni_range = 8.0 * s
	parent.add_child(fl)
	fl.global_position = at + Vector3.UP * 0.8 * s


## Meşale: kazık, sarılı bez baş, demir halka (alev fire_fx ile)
static func torch(b: MB, base: Transform3D, p: Vector3, h := 2.2) -> void:
	_rod(b, base, p, p + Vector3(0, h, 0), 0.05, POLE, 6)
	_p(b, base, "cyl", p + Vector3(0, h + 0.12, 0), Vector3(0.16, 0.3, 0.16), Color(0.22, 0.17, 0.12), Vector3.ZERO, 7)
	_p(b, base, "torus", p + Vector3(0, h - 0.05, 0), Vector3(0.18, 0.2, 0.18), Color(0.25, 0.25, 0.27), Vector3.ZERO, 8)


## Kaya tepe + mağara ağzı. Ağız +z yönüne bakar, (0,0,0) ağzın önündeki zemin. Döner: çarpışma için kaya küreleri [merkez, yarıçap].
static func cave_mouth(b: MB, rng: RandomNumberGenerator, rock: Color, lab: bool) -> Array:
	var I := Transform3D.IDENTITY
	var cols: Array = []
	var moss := Color(0.3, 0.42, 0.22)
	# ana tepe: üst üste binmiş iri pürüzlü kayalar (tek küre değil)
	var masses := [[Vector3(0, 3.2, -8.5), Vector3(15.0, 9.5, 11.0)], [Vector3(-6.5, 2.0, -6.0), Vector3(8.5, 6.5, 8.0)], [Vector3(6.8, 2.2, -6.5), Vector3(9.0, 7.0, 8.5)],
		[Vector3(-2.5, 6.0, -10.0), Vector3(9.0, 6.0, 8.0)], [Vector3(3.5, 5.0, -11.5), Vector3(8.0, 6.5, 7.0)]]
	for i in masses.size():
		var c: Vector3 = masses[i][0]
		var s: Vector3 = masses[i][1]
		b.add("boulder", c, s, rock.darkened(rng.randf() * 0.18), Vector3(0, rng.randf() * 360.0, 0), 60 + i)
		cols.append([c, minf(s.x, minf(s.y, s.z)) * 0.48])
		b.add("boulder", c + Vector3(rng.randf_range(-1, 1), s.y * 0.42, rng.randf_range(-1, 1)), Vector3(s.x * 0.6, s.y * 0.18, s.z * 0.6), moss.darkened(rng.randf() * 0.15), Vector3(0, rng.randf() * 360.0, 0), 70 + i)   # tepe yosunu / çimi
	# ağzı çevreleyen kaya kemer: iki yan sütun + üstte devrik alın taşı
	for sx in [-1.0, 1.0]:
		b.add("crag", Vector3(sx * 3.0, 2.0, -1.6), Vector3(2.6, 4.2, 2.4), rock.darkened(0.1 + rng.randf() * 0.08), Vector3(0, rng.randf() * 360.0, sx * -6.0), 80 + int(sx + 1))
		b.add("boulder", Vector3(sx * 4.6, 0.7, -0.6), Vector3(2.2, 1.6, 2.0), rock.darkened(0.05), Vector3(0, rng.randf() * 360.0, 0), 84 + int(sx + 1))
	b.add("boulder", Vector3(0, 4.5, -1.8), Vector3(7.6, 2.4, 3.0), rock.darkened(0.12), Vector3(0, 0, 4.0), 90)
	b.add("boulder", Vector3(0.6, 5.6, -2.4), Vector3(4.0, 1.0, 2.2), moss, Vector3(0, 20, 0), 91)
	# karanlık geçit: içe doğru kararan tünel (ağız oyuk görünür, düz siyah leke değil)
	for k in 4:
		var t := float(k) / 3.0
		b.add("hemi", Vector3(0, 0.0, -1.4 - k * 1.1), Vector3(4.4 - k * 0.5, 7.2 - k * 0.9, 1.4), Color(0.1, 0.08, 0.07).lerp(Color(0.01, 0.01, 0.01), t), Vector3.ZERO, 14)
	for k in 5:   # ayak yolu: çiğnenmiş toprak lekeleri (düz paspas değil)
		b.add("cyl", Vector3(rng.randf_range(-0.8, 0.8), 0.01, 0.4 - k * 0.6), Vector3(rng.randf_range(1.4, 2.2), 0.03, rng.randf_range(1.0, 1.6)), Color(0.33, 0.28, 0.2).darkened(k * 0.06), Vector3(0, rng.randf() * 180.0, 0), 9)
	# ağız iskelesi: iki ahşap dikme + kiriş (kaçakların taşıdığı destek)
	var wood := Color(0.38, 0.27, 0.17)
	for sx in [-1.0, 1.0]:
		_rod(b, I, Vector3(sx * 1.75, 0, -1.2), Vector3(sx * 1.6, 3.1, -1.2), 0.14, wood, 6)
	_p(b, I, "box", Vector3(0, 3.15, -1.2), Vector3(4.2, 0.3, 0.32), wood.darkened(0.1))
	# önde dağınık taşlar
	for k in 7:
		var a := rng.randf_range(-1.2, 1.2)
		var r := rng.randf_range(4.5, 8.0)
		var p := Vector3(sin(a) * r, 0.2, -1.0 + cos(a) * r * 0.5)
		if absf(p.x) < 2.6:
			p.x = 2.6 * (1.0 if p.x >= 0 else -1.0) + p.x
		b.add("boulder", p, Vector3.ONE * rng.randf_range(0.5, 1.3), rock.darkened(rng.randf() * 0.2), Vector3(0, rng.randf() * 360.0, 0), 100 + k)
	for sx in [-1.0, 1.0]:
		torch(b, I, Vector3(sx * 2.6, 0, 0.6))
	if lab:
		for k in 3:   # yerde sürüklenme izleri, kırık kafes
			b.add("box", Vector3(-1.5 + k * 1.5, 0.05, 2.5 + k), Vector3(0.25, 0.04, 2.0), Color(0.3, 0.2, 0.18))
		b.add("box", Vector3(4.5, 0.8, 2.0), Vector3(1.6, 1.6, 1.6), Color(0.3, 0.28, 0.26))
	return cols
