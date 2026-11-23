class_name Kanzeon
extends Node3D
## Kanzeon Renge-Ō (kanon, Tobi/Zetsu Yamato'yu araç ederek; ref refs/fx/kanzeon_renge_o + _tmp/vs/kz_*: "Tobi vs Third Hokage").
## AYAKTA dev tahta heykel (Shin Sūsenju'dan küçük): yere doğru sütun gibi açılan uzun cüppe (dikey kıvrımlar, kuşak, omuzdan
## çapraz örtü), göğsün önünde dua eden eller; ardında dikey oval hale çerçevesi ve onu tüy gibi saran dört sıra açık el (yelpaze);
## yanlara uzanan dört uzun kol (bileğinde bant, açık avuç). Başın üstünde topuzlu, maske yüzlü BEŞ büyük baş (ref kz 0:29):
## Issai Kaiku'da her biri bir doğa püskürtür. Saldıran kollar heykelden KOPMAZ: kökten hedefe uzayıp açık avuçla yere çarpar.
## Boy ~160 m. Tasarım boyu 10, ön -Z.

const H := 160.0
const S := H / 10.0
const WOOD := Color(0.52, 0.41, 0.33)
const WOOD2 := Color(0.46, 0.36, 0.29)
const DARK := Color(0.3, 0.23, 0.18)

var body: Node3D
var heads: Array = []    # beş büyük başın ağız noktaları (tasarım)
var roots: Array = []    # saldıran kolların kök noktaları (tasarım): hale tüyleri + uzun kolların omuzları
var arms: Array = []
static var _plume_mesh: ArrayMesh
static var _shaft_mesh: ArrayMesh
static var _palm_mesh: ArrayMesh


static func spawn(parent: Node, at: Vector3, yaw: float) -> Kanzeon:
	var k = Kanzeon.new()
	parent.add_child(k)
	k.global_position = at
	k.rotation.y = yaw
	return k


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	_build()
	body.scale = Vector3.ONE * S


## Açık el (birim, +Y parmak yönü, avuç +Z'ye bakar): kısa bilek + bant, geniş avuç, açık parmaklar, yana açık başparmak
static func _hand(b: MB, xf: Transform3D, col: Color, wrist := 0.35) -> void:
	var pts := func(arr: Array) -> Array:
		var o = []
		for p in arr:
			o.append(xf * p)
		return o
	var sc: float = xf.basis.get_scale().x
	Loft.tube(b, pts.call([Vector3(0, -wrist, 0), Vector3(0, -0.05, 0)]), [0.15 * sc, 0.14 * sc], col, 10, 2)
	var bp: Vector3 = xf * Vector3(0, -0.08, 0)
	b.add_xf("cyl", Transform3D(xf.basis * Basis.from_scale(Vector3(0.36, 0.07, 0.36)), bp), DARK, 12)
	Loft.blob(b, xf * Vector3(0, 0.14, 0), (xf.basis * Vector3.UP).normalized(), 0.34 * sc, [Vector2(0.17, 0.06) * sc, Vector2(0.22, 0.075) * sc, Vector2(0.21, 0.07) * sc, Vector2(0.18, 0.06) * sc], col, 10, Callable(), (xf.basis * Vector3.BACK).normalized())
	for f in 4:
		var fx = lerpf(-0.15, 0.15, f / 3.0)
		var fl = [0.26, 0.31, 0.29, 0.23][f]
		Loft.tube(b, pts.call([Vector3(fx, 0.3, 0), Vector3(fx * 1.25, 0.3 + fl * 0.55, 0.015), Vector3(fx * 1.45, 0.3 + fl, 0.04)]), [0.045 * sc, 0.04 * sc, 0.028 * sc], col, 6, 2)
	Loft.tube(b, pts.call([Vector3(0.2, 0.08, 0), Vector3(0.33, 0.18, 0.03), Vector3(0.4, 0.3, 0.06)]), [0.05 * sc, 0.042 * sc, 0.03 * sc], col, 6, 2)


## Hale tüyü: kısa ön kol + açık el (birim boy ~1)
static func plume_mesh() -> ArrayMesh:
	if _plume_mesh != null:
		return _plume_mesh
	var b = MB.new()
	Loft.tube(b, [Vector3(0, 0, 0), Vector3(0, 0.3, 0)], [0.1, 0.09], WOOD, 8, 2)
	_hand(b, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.75), Vector3(0, 0.55, 0)), WOOD, 0.3)
	_plume_mesh = b.build(Props.toon())
	return _plume_mesh


static func shaft_mesh() -> ArrayMesh:
	if _shaft_mesh != null:
		return _shaft_mesh
	var b = MB.new()
	Loft.tube(b, [Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 1, 0)], [1.0, 0.96, 0.92], WOOD, 12, 2, false, false)
	for k in 4:   # oyma çizgileri (ref: kol boyunca kıvrım çizgileri)
		var a = k * TAU / 4.0 + 0.7
		Loft.tube(b, [Vector3(cos(a) * 0.97, 0.0, sin(a) * 0.97), Vector3(cos(a + 0.2) * 0.94, 0.5, sin(a + 0.2) * 0.94), Vector3(cos(a) * 0.91, 1.0, sin(a) * 0.91)], [0.05, 0.05, 0.05], DARK, 4, 2, false, false)
	_shaft_mesh = b.build(Props.toon())
	return _shaft_mesh


## Çarpan kolun ucu: bant + geniş açık avuç (birim boy ~1; +Y parmak yönü, avuç +Z)
static func palm_mesh() -> ArrayMesh:
	if _palm_mesh != null:
		return _palm_mesh
	var b = MB.new()
	_hand(b, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.4), Vector3(0, 0.1, 0)), WOOD, 0.4)
	_palm_mesh = b.build(Props.toon())
	return _palm_mesh


func _build() -> void:
	var b = MB.new()
	# uzun cüppe: yerde geniş etekten yukarı daralan sütun (ref: aşağı doğru açılan dev etek, dikey kıvrımlar)
	Loft.tube(b, [Vector3(0, -0.4, 0.0), Vector3(0, 0.0, 0.0), Vector3(0, 1.5, 0.0), Vector3(0, 3.5, 0.0), Vector3(0, 5.5, 0.0), Vector3(0, 6.5, 0.0)],
		[Vector2(1.9, 1.5), Vector2(1.85, 1.45), Vector2(1.35, 1.05), Vector2(0.98, 0.76), Vector2(0.86, 0.66), Vector2(0.95, 0.7)], WOOD, 24, 4, true, false)
	for k in 13:
		var a = lerpf(-1.35, 1.35, k / 12.0)
		Loft.tube(b, [Vector3(sin(a) * 1.85, -0.3, -cos(a) * 1.45), Vector3(sin(a) * 1.32, 1.6, -cos(a) * 1.02), Vector3(sin(a) * 0.95, 3.6, -cos(a) * 0.74), Vector3(sin(a) * 0.85, 5.4, -cos(a) * 0.66)], [0.035, 0.03, 0.025, 0.02], DARK, 5, 3)
	b.add("torus", Vector3(0, 5.55, 0.0), Vector3(1.75, 0.12, 1.36), DARK, Vector3.ZERO, 28)   # kuşak
	Loft.tube(b, [Vector3(0.0, 5.5, -0.7), Vector3(0.1, 5.1, -0.74), Vector3(0.05, 4.6, -0.76)], [0.1, 0.09, 0.06], WOOD2, 6, 3)   # kuşak düğümü sarkıtı
	# omuzdan çapraz inen örtü (ref)
	Loft.tube(b, [Vector3(0.9, 7.45, -0.1), Vector3(0.35, 6.9, -0.72), Vector3(-0.4, 6.1, -0.78), Vector3(-0.85, 5.55, -0.6)], [Vector2(0.24, 0.06), Vector2(0.26, 0.06), Vector2(0.24, 0.06), Vector2(0.2, 0.05)], WOOD2, 8, 4)
	# göğüs-omuz
	Loft.tube(b, [Vector3(0, 6.3, 0.0), Vector3(0, 7.3, 0.0), Vector3(0, 7.7, 0.0)], [Vector2(1.08, 0.7), Vector2(1.12, 0.7), Vector2(0.45, 0.4)], WOOD, 18, 3)
	for s in [-1.0, 1.0]:
		Loft.blob(b, Vector3(s * 1.08, 7.3, 0.0), Vector3(s * 0.4, -1, 0), 0.6, [Vector2(0.12, 0.12), Vector2(0.3, 0.28), Vector2(0.27, 0.25), Vector2(0.1, 0.1)], WOOD, 10)
		# dua eden eller: kollar göğüs önünde, avuçlar dik birleşik (ref)
		Loft.tube(b, [Vector3(s * 1.1, 7.25, 0.0), Vector3(s * 1.15, 6.65, -0.35), Vector3(s * 0.7, 6.6, -0.82), Vector3(s * 0.14, 6.9, -0.98)], [0.27, 0.24, 0.2, 0.15], WOOD, 10, 3)
		b.add("cyl", Vector3(s * 0.42, 6.72, -0.92), Vector3(0.36, 0.07, 0.36), DARK, Vector3(0, 0, s * 70), 12)
	Loft.blob(b, Vector3(0, 7.15, -1.02), Vector3(0, 1, -0.08), 0.75, [Vector2(0.16, 0.12), Vector2(0.2, 0.15), Vector2(0.17, 0.12), Vector2(0.07, 0.05)], WOOD, 10)
	# ana baş: sakin yüz, kapalı gözler, uzun kulak
	Loft.tube(b, [Vector3(0, 7.6, 0.0), Vector3(0, 7.95, -0.03)], [0.3, 0.28], WOOD, 12, 2)
	Loft.blob(b, Vector3(0, 8.15, -0.04), Vector3(0, 1, 0), 1.05, [Vector2(0.36, 0.38), Vector2(0.48, 0.5), Vector2(0.46, 0.48), Vector2(0.24, 0.24)], WOOD, 14)
	for s in [-1.0, 1.0]:
		Loft.tube(b, [Vector3(s * 0.08, 8.25, -0.48), Vector3(s * 0.2, 8.22, -0.49), Vector3(s * 0.31, 8.26, -0.44)], [0.022, 0.026, 0.016], DARK, 5, 2)
		Loft.blob(b, Vector3(s * 0.5, 8.1, 0.0), Vector3(0, -1, 0), 0.62, [Vector2(0.06, 0.04), Vector2(0.09, 0.05), Vector2(0.08, 0.05), Vector2(0.06, 0.03)], WOOD, 6)
	b.add("box", Vector3(0, 7.86, -0.47), Vector3(0.15, 0.022, 0.022), DARK)
	# taç: beş büyük maske yüzlü baş — topuzlu, kapalı/oyuk gözlü (ref kz 0:29), ana başın üstünde yarım çember
	heads.clear()
	for k in 5:
		var a = lerpf(-1.1, 1.1, k / 4.0)
		var hp = Vector3(sin(a) * 0.62, 8.95 + (0.12 if k == 2 else 0.0), -cos(a) * 0.42 + 0.08)
		var fdir = Vector3(sin(a), 0.0, -cos(a)).normalized()
		Loft.blob(b, hp, Vector3.UP, 0.68, [Vector2(0.16, 0.16), Vector2(0.24, 0.24), Vector2(0.25, 0.25), Vector2(0.2, 0.2), Vector2(0.08, 0.08)], WOOD2 if k % 2 == 0 else WOOD, 12)
		var side = fdir.cross(Vector3.UP).normalized()
		for s in [-1.0, 1.0]:   # oyuk göz
			b.add("sphere", hp + fdir * 0.22 + side * s * 0.09 + Vector3(0, 0.07, 0), Vector3(0.07, 0.04, 0.03), DARK, Vector3.ZERO, 6)
		b.add("box", hp + fdir * 0.235 + Vector3(0, -0.12, 0), Vector3(0.12, 0.025, 0.02), DARK, Vector3(0, rad_to_deg(a), 0))   # ağız
		b.add("torus", hp + Vector3(0, 0.22, 0), Vector3(0.36, 0.05, 0.36), DARK, Vector3.ZERO, 14)   # saç bandı
		Loft.blob(b, hp + Vector3(0, 0.4, 0.02), Vector3.UP, 0.24, [Vector2(0.07, 0.07), Vector2(0.12, 0.12), Vector2(0.1, 0.1), Vector2(0.04, 0.04)], DARK, 8)   # topuz
		heads.append(hp + fdir * 0.3 + Vector3(0, -0.1, 0))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	body.add_child(mi)
	# hale: gövdeyi çevreleyen dikey oval çerçeve (ref: ince kenarlı, içinde kabartma çizgiler)
	var hb = MB.new()
	var hc = Vector3(0, 6.4, 0.55)
	hb.add("torus", hc, Vector3(4.6, 0.16, 6.6), DARK, Vector3(90, 0, 0), 48)
	hb.add("torus", hc + Vector3(0, 0.0, 0.05), Vector3(4.3, 0.08, 6.3), WOOD2, Vector3(90, 0, 0), 48)
	hb.add("cyl", hc + Vector3(0, 0, 0.12), Vector3(4.3, 0.06, 6.3), WOOD.darkened(0.12), Vector3(90, 0, 0), 40)
	for k in 10:   # çerçeve içi dikey kabartma çizgileri
		var x = lerpf(-1.8, 1.8, k / 9.0)
		var hh = 3.1 * sqrt(maxf(0.0, 1.0 - pow(x / 2.15, 2.0)))
		hb.add("box", hc + Vector3(x, 0, 0.06), Vector3(0.03, hh * 2.0, 0.03), DARK)
	var hmi = MeshInstance3D.new()
	hmi.mesh = hb.build(Props.toon())
	body.add_child(hmi)
	# hale tüyleri: çerçeveyi dışından saran dört sıra açık el, alttan yukarı her sıra biraz dışta / geride (ref: kat kat yaprak)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plume_mesh()
	var xfs = []
	roots.clear()
	for r in 4:
		var n = 34 + r * 6
		for k in n:
			var a = (k + 0.5 * (r % 2)) / float(n) * TAU
			var ell = Vector3(cos(a) * 2.35, sin(a) * 3.35, 0.0)
			if ell.y < -2.6:   # cüppenin ardına giren alt uç boş
				continue
			var dv = Vector3(cos(a) / 2.35, sin(a) / 3.35, 0.0).normalized()
			var o = hc + ell * (1.0 + r * 0.1) + Vector3(0, 0, 0.18 + r * 0.12)
			var L = 0.9 + r * 0.12 + 0.08 * sin(k * 1.7 + r)
			var yb = (dv + Vector3(0, 0, 0.1 + r * 0.05)).normalized()
			var xb = Vector3.BACK.cross(yb).normalized()
			var zb = xb.cross(yb).normalized()
			xfs.append(Transform3D(Basis(xb * L, yb * L, zb * L), o))
			if k % 3 == 0:
				roots.append(o)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var fan = MultiMeshInstance3D.new()
	fan.multimesh = mm
	body.add_child(fan)
	# yanlara uzanan dört uzun kol (ref: omuzdan açılıp uçta açık avuç; bilekte bant)
	var lb = MB.new()
	for s in [-1.0, 1.0]:
		for h in 2:
			var o = Vector3(s * 1.0, 7.15 - h * 0.7, 0.2)
			var mid = o + Vector3(s * 2.4, 0.5 - h * 0.9, -0.3)
			var tip = o + Vector3(s * 4.9, 0.2 - h * 2.0, -0.9)
			Loft.tube(lb, [o, mid, tip], [0.2, 0.17, 0.14], WOOD, 10, 4)
			var dv = (tip - mid).normalized()
			var zb = (Vector3.DOWN - dv * dv.dot(Vector3.DOWN)).normalized()
			var xb = dv.cross(zb).normalized()
			_hand(lb, Transform3D(Basis(xb, dv, zb).scaled(Vector3.ONE * 0.95), tip + dv * 0.2), WOOD, 0.3)
			roots.append(o + Vector3(s * 0.3, 0, 0))
	var lmi = MeshInstance3D.new()
	lmi.mesh = lb.build(Props.toon())
	body.add_child(lmi)


func head_world(i: int) -> Vector3:
	return body.global_transform * (heads[i] as Vector3)


func random_root_world() -> Vector3:
	return body.global_transform * (roots[randi() % roots.size()] as Vector3)


# ------------------------------------------------------------------ heykele bağlı uzayan açık avuç kolları
func new_arm(r: float, ps: float) -> Dictionary:
	var shaft = MeshInstance3D.new()
	shaft.mesh = shaft_mesh()
	var palm = MeshInstance3D.new()
	palm.mesh = palm_mesh()
	add_child(shaft)
	add_child(palm)
	shaft.top_level = true
	palm.top_level = true
	var root = random_root_world()
	var a = {"shaft": shaft, "palm": palm, "root": root, "r": r, "ps": ps, "tip": root}
	arms.append(a)
	_pose_arm(a, root)
	return a


## Kol kökten tipe dümdüz; avuç kolun ucunda, yüzü yere dönük (yukarıdan inen tokat)
func _pose_arm(a: Dictionary, tip: Vector3) -> void:
	if not is_instance_valid(a["shaft"]):
		return
	a["tip"] = tip
	var root: Vector3 = a["root"]
	var d = tip - root
	var L = maxf(d.length(), 0.01)
	var y = d / L
	var x = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z = x.cross(y).normalized()
	var r: float = a["r"]
	var ps: float = a["ps"]
	(a["shaft"] as Node3D).global_transform = Transform3D(Basis(x * r, y * maxf(L - ps * 0.5, 0.01), z * r), root)
	var pz = (Vector3.DOWN - y * y.dot(Vector3.DOWN))
	pz = pz.normalized() if pz.length() > 0.05 else z
	var px = y.cross(pz).normalized()
	(a["palm"] as Node3D).global_transform = Transform3D(Basis(px * ps, y * ps, pz * ps), tip - y * ps * 0.7)
	(a["shaft"] as Node3D).visible = L > 1.0
	(a["palm"] as Node3D).visible = L > 1.0


func slap(a: Dictionary, goal: Vector3, dur: float, hold: float, back: float, on_hit: Callable) -> void:
	var root: Vector3 = a["root"]
	var from: Vector3 = a["tip"]
	var mid = root.lerp(goal, 0.35)
	var tw = create_tween()
	tw.tween_method(func(t: float): _pose_arm(a, from.lerp(goal, t)), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_hit.bind(goal))
	tw.tween_interval(hold)
	tw.tween_method(func(t: float): _pose_arm(a, goal.lerp(mid, t)), 0.0, 1.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func retract(a: Dictionary, back: float) -> void:
	var root: Vector3 = a["root"]
	var from: Vector3 = a["tip"]
	var tw = create_tween()
	tw.tween_method(func(t: float): _pose_arm(a, from.lerp(root, t)), 0.0, 1.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_drop_arm.bind(a))


func _drop_arm(a: Dictionary) -> void:
	for k in ["shaft", "palm"]:
		if is_instance_valid(a[k]):
			(a[k] as Node).queue_free()
	arms.erase(a)
