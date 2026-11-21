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
	var d := c - a
	var L := d.length()
	if L < 0.01:
		return
	var y := d / L
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var bs := Basis(x * r * 2.0, y * L, z * r * 2.0)
	b.add_xf("cyl", base * Transform3D(bs, (a + c) * 0.5), col, seg)


## A çadırı: iki eğik bez yüzey, mahya sırığı, iki dikme, arka üçgen duvar, açık ön (bağlanmış kapak ruloları),
## yere gerilmiş halatlar ve kazıklar, içinde yer örtüsü ve dürülü yatak. base: zemindeki çadır ortası (z = çadır boyu).
static func tent(b: MB, base: Transform3D, cloth: Color, W := 2.8, H := 2.0, L := 3.4, rng: RandomNumberGenerator = null) -> void:
	var half := W * 0.5
	var slant := sqrt(half * half + H * H)
	var ang := rad_to_deg(atan2(H, half))
	var dk := cloth.darkened(0.18)
	for sx in [-1.0, 1.0]:
		# bez yüzey: üç parça; ortası hafif sarkık (gerilmiş bez)
		for k in 3:
			var z0 := -L * 0.5 + L * (k + 0.5) / 3.0
			var sag := 0.05 if k == 1 else 0.0
			_p(b, base, "box", Vector3(sx * half * 0.5 + sx * sag * 0.6, H * 0.5 - sag, z0), Vector3(slant, 0.04, L / 3.0 + 0.02), cloth if k != 1 else cloth.darkened(0.04), Vector3(0, 0, -sx * ang))
		# dikiş şeritleri ve alt etek
		for k in 2:
			var zs := -L * 0.5 + L * (k + 1) / 3.0
			_p(b, base, "box", Vector3(sx * half * 0.5, H * 0.5 + 0.025, zs), Vector3(slant, 0.02, 0.05), dk, Vector3(0, 0, -sx * ang))
		_p(b, base, "box", Vector3(sx * (half - 0.06), 0.12, 0), Vector3(0.05, 0.22, L + 0.04), dk, Vector3(0, 0, -sx * (90.0 - ang)))
		# yan halatlar: etek köşesinden dışarıdaki kazığa
		for sz in [-1.0, 1.0]:
			var a := Vector3(sx * half, 0.15, sz * L * 0.38)
			var st := Vector3(sx * (half + 0.9), 0.0, sz * L * 0.42)
			_rod(b, base, a, st + Vector3(0, 0.18, 0), 0.012, ROPE, 4)
			_p(b, base, "cyl", st + Vector3(0, 0.12, 0), Vector3(0.05, 0.3, 0.05), POLE, Vector3(0, 0, sx * 15.0), 4)
	# mahya sırığı, iki dikme, uçlardan yere halat
	_rod(b, base, Vector3(0, H + 0.03, -L * 0.5 - 0.25), Vector3(0, H + 0.03, L * 0.5 + 0.25), 0.045, POLE, 6)
	for sz in [-1.0, 1.0]:
		_rod(b, base, Vector3(0, 0, sz * L * 0.5), Vector3(0, H + 0.05, sz * L * 0.5), 0.04, POLE, 6)
		var st2 := Vector3(0, 0, sz * (L * 0.5 + 1.3))
		_rod(b, base, Vector3(0, H, sz * (L * 0.5 + 0.2)), st2 + Vector3(0, 0.18, 0), 0.014, ROPE, 4)
		_p(b, base, "cyl", st2 + Vector3(0, 0.12, 0), Vector3(0.06, 0.3, 0.06), POLE, Vector3(sz * 15.0, 0, 0), 4)
	# arka duvar (üçgen) + önde iki yana toplanmış kapak ruloları
	_p(b, base, "prism", Vector3(0, H * 0.5, -L * 0.5 + 0.02), Vector3(W - 0.05, H, 0.04), cloth.darkened(0.08))
	for sx in [-1.0, 1.0]:
		_rod(b, base, Vector3(sx * half * 0.92, 0.05, L * 0.5 + 0.04), Vector3(sx * 0.12, H - 0.1, L * 0.5 + 0.04), 0.09, cloth.lightened(0.05), 6)
		_p(b, base, "torus", Vector3(sx * half * 0.5, H * 0.5, L * 0.5 + 0.04), Vector3(0.24, 0.24, 0.24), ROPE, Vector3(0, 0, -sx * ang + 90.0), 8)
	# içi: yer örtüsü, dürülü yatak, bohça
	_p(b, base, "box", Vector3(0, 0.02, 0), Vector3(W - 0.3, 0.03, L - 0.2), Color(0.32, 0.27, 0.2))
	_p(b, base, "cyl", Vector3(-0.45, 0.17, -0.2), Vector3(0.32, L * 0.55, 0.32), Color(0.48, 0.38, 0.5) if rng == null or rng.randf() < 0.5 else Color(0.35, 0.42, 0.52), Vector3(90, 0, 0), 8)
	_p(b, base, "sphere", Vector3(0.5, 0.18, -L * 0.3), Vector3(0.5, 0.36, 0.45), Color(0.6, 0.52, 0.38), Vector3.ZERO, 7)


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
