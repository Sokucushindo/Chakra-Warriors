class_name ShinSusenju
extends Node3D
## Senpō Mokuton: Shin Sūsenju (kanon, Hashirama; ref _tmp/susenjuref + _tmp/vs/hm_*: Shippuden "Hashirama vs Madara").
## Lotus oturuşunda titanik tahta Buda: kalın cüppe kıvrımları, sol omuzdan inen örtü, göğüs önünde birleşik dua eden iki el;
## uzun maske yüz, kapalı gözler, uzun kulaklar, başın üstünde iki sıra küçük Buda başından taç ve topuz. Ardında dikey hale levhası;
## sırtından eş merkezli sıralar hâlinde yüzlerce kol tavus kuyruğu gibi açılır (bilek bandı, açık el).
## Chōjō Kebutsu: kollar heykelden KOPMAZ — kuyruktaki kökten hedefe kesintisiz uzayan dümdüz tahta kol, ucunda kapalı yumruk;
## vurur, geri çekilir, yeniden uzanır (ref 1:00-1:17: paralel kol demetleri yumruk yağdırır). Boy ~450 m. Tasarım boyu 10, ön -Z.

const H := 450.0
const S := H / 10.0
const WOOD := Color(0.56, 0.47, 0.36)
const WOOD2 := Color(0.5, 0.41, 0.31)
const DARK := Color(0.3, 0.24, 0.18)

var body: Node3D
var fan: MultiMeshInstance3D
var fan_xf: Array = []   # kuyruktaki her kolun tasarım dönüşümü
var arms: Array = []     # saldıran (uzayan) kollar
static var _arm_mesh: ArrayMesh
static var _shaft_mesh: ArrayMesh
static var _fist_mesh: ArrayMesh


static func spawn(parent: Node, at: Vector3, yaw: float) -> ShinSusenju:
	var s = ShinSusenju.new()
	parent.add_child(s)
	s.global_position = at
	s.rotation.y = yaw
	return s


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	_build_body()
	_build_fan()
	body.scale = Vector3.ONE * S


func _mi(b: MB) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	body.add_child(mi)
	return mi


# ------------------------------------------------------------------ kuyruk kolu (açık el)
## Tek kol (birim uzunluk, +Y): tahta lifli ön kol + bilek bandı + açık el (avuç önde -Z), dört parmak + başparmak
static func arm_mesh() -> ArrayMesh:
	if _arm_mesh != null:
		return _arm_mesh
	var b = MB.new()
	Loft.tube(b, [Vector3(0, 0, 0), Vector3(0, 0.4, 0), Vector3(0, 0.74, 0)], [0.07, 0.064, 0.056], WOOD, 8, 2)
	for k in 3:   # lif çizgileri
		var a = k * 2.1 + 0.4
		Loft.tube(b, [Vector3(cos(a) * 0.066, 0.06, sin(a) * 0.066), Vector3(cos(a + 0.15) * 0.062, 0.4, sin(a + 0.15) * 0.062), Vector3(cos(a) * 0.056, 0.7, sin(a) * 0.056)], [0.007, 0.007, 0.006], DARK, 4, 2)
	b.add("cyl", Vector3(0, 0.74, 0), Vector3(0.15, 0.045, 0.15), DARK, Vector3.ZERO, 10)   # bilek bandı (ref)
	Loft.blob(b, Vector3(0, 0.84, 0), Vector3(0, 1, 0), 0.2, [Vector2(0.075, 0.03), Vector2(0.1, 0.036), Vector2(0.098, 0.034), Vector2(0.085, 0.028)], WOOD, 10)
	for f in 4:
		var fx = lerpf(-0.07, 0.07, f / 3.0)
		var fl = [0.13, 0.16, 0.15, 0.115][f]
		Loft.tube(b, [Vector3(fx, 0.93, 0), Vector3(fx * 1.18, 0.93 + fl * 0.55, -0.006), Vector3(fx * 1.32, 0.93 + fl, -0.02)], [0.021, 0.018, 0.012], WOOD, 6, 2)
	Loft.tube(b, [Vector3(0.095, 0.82, 0), Vector3(0.15, 0.88, -0.012), Vector3(0.18, 0.95, -0.025)], [0.023, 0.019, 0.012], WOOD, 6, 2)
	_arm_mesh = b.build(Props.toon())
	return _arm_mesh


## Uzayan kolun gövdesi: birim boy (+Y 0..1), birim yarıçap; boyuna lif oluklarıyla — boyu ölçekle uzar, kalınlığı sabit kalır
static func shaft_mesh() -> ArrayMesh:
	if _shaft_mesh != null:
		return _shaft_mesh
	var b = MB.new()
	Loft.tube(b, [Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 1, 0)], [1.0, 0.97, 0.94], WOOD, 12, 2, false, false)
	for k in 6:
		var a = k * TAU / 6.0 + 0.3
		Loft.tube(b, [Vector3(cos(a) * 0.98, 0.0, sin(a) * 0.98), Vector3(cos(a + 0.05) * 0.95, 0.5, sin(a + 0.05) * 0.95), Vector3(cos(a) * 0.93, 1.0, sin(a) * 0.93)], [0.06, 0.06, 0.06], DARK, 4, 2, false, false)
	_shaft_mesh = b.build(Props.toon())
	return _shaft_mesh


## Kapalı yumruk (birim: yumruk boyu ~1, kol -Y'den gelir, yumruk +Y'ye vurur): bilek bandı, avuç kütlesi, dört boğum, başparmak
static func fist_mesh() -> ArrayMesh:
	if _fist_mesh != null:
		return _fist_mesh
	var b = MB.new()
	Loft.tube(b, [Vector3(0, -0.9, 0), Vector3(0, -0.35, 0)], [0.32, 0.3], WOOD, 12, 2)   # bilek
	b.add("cyl", Vector3(0, -0.4, 0), Vector3(0.78, 0.16, 0.78), DARK, Vector3.ZERO, 14)   # bilek bandı
	Loft.blob(b, Vector3(0, 0.05, 0), Vector3(0, 1, 0), 0.95, [Vector2(0.3, 0.26), Vector2(0.44, 0.36), Vector2(0.46, 0.38), Vector2(0.4, 0.34), Vector2(0.24, 0.2)], WOOD, 14)
	for f in 4:   # boğumlar: yumruğun önünde sıralı dört kıvrık parmak
		var fx = lerpf(-0.3, 0.3, f / 3.0)
		Loft.blob(b, Vector3(fx, 0.4, -0.14), Vector3(0, 0.3, -1).normalized(), 0.46, [Vector2(0.1, 0.1), Vector2(0.14, 0.14), Vector2(0.13, 0.13), Vector2(0.08, 0.08)], WOOD2, 8)
		Loft.tube(b, [Vector3(fx - 0.06, 0.52, -0.08), Vector3(fx + 0.06, 0.52, -0.08)], [0.012, 0.012], DARK, 4, 1)   # boğum çizgisi
	Loft.tube(b, [Vector3(0.42, 0.0, -0.05), Vector3(0.38, 0.2, -0.3), Vector3(0.12, 0.3, -0.4)], [0.13, 0.12, 0.09], WOOD2, 8, 2)   # başparmak
	_fist_mesh = b.build(Props.toon())
	return _fist_mesh


# ------------------------------------------------------------------ gövde
func _build_body() -> void:
	var b = MB.new()
	# lotus kaidesi: yassı yuvarlak taban + çevresinde kalın yaprak dilimleri
	b.add("cyl", Vector3(0, 0.18, 0.1), Vector3(6.2, 0.36, 4.8), DARK, Vector3.ZERO, 28)
	for k in 18:
		var a = k * TAU / 18.0
		var p = Vector3(cos(a) * 2.9, 0.42, sin(a) * 2.2 + 0.1)
		Loft.blob(b, p, Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4).normalized(), 0.75, [Vector2(0.1, 0.06), Vector2(0.42, 0.16), Vector2(0.36, 0.14), Vector2(0.05, 0.04)], WOOD2 if k % 2 == 0 else WOOD, 10)
	# bağdaş kurmuş bacaklar: cüppe altında iki kalın kütle, dizler yanlara taşar
	for s in [-1.0, 1.0]:
		Loft.tube(b, [Vector3(s * 2.25, 0.85, 0.1), Vector3(s * 1.3, 0.92, -0.75), Vector3(-s * 0.3, 0.85, -0.9)], [Vector2(0.62, 0.48), Vector2(0.56, 0.44), Vector2(0.46, 0.38)], WOOD, 14, 3)
		Loft.blob(b, Vector3(-s * 0.55, 0.95, -1.05), Vector3(s, 0.1, 0), 0.7, [Vector2(0.12, 0.1), Vector2(0.26, 0.2), Vector2(0.22, 0.18), Vector2(0.08, 0.06)], WOOD2, 8)   # tabanı yukarı ayak
	# gövde: geniş omuzlu dik beden, cüppe
	Loft.tube(b, [Vector3(0, 0.85, 0.25), Vector3(0, 2.0, 0.18), Vector3(0, 3.2, 0.12), Vector3(0, 4.15, 0.05), Vector3(0, 4.6, 0.02)],
		[Vector2(1.65, 1.1), Vector2(1.45, 1.0), Vector2(1.62, 1.05), Vector2(1.85, 1.0), Vector2(0.62, 0.52)], WOOD, 22, 4)
	# cüppe kıvrımları: gövdeden kucağa dökülen dikey oluklar
	for k in 9:
		var a = lerpf(-1.25, 1.25, k / 8.0)
		Loft.tube(b, [Vector3(sin(a) * 1.5, 3.6, 0.12 - cos(a) * 1.0), Vector3(sin(a) * 1.5, 2.2, 0.18 - cos(a) * 1.02), Vector3(sin(a) * 1.75, 1.0, 0.25 - cos(a) * 1.12)], [0.05, 0.06, 0.05], DARK, 4, 3)
	# sol omuzdan sağ kalçaya inen örtü bandı (ref 1:36)
	Loft.tube(b, [Vector3(1.5, 4.35, 0.0), Vector3(0.6, 3.6, -1.02), Vector3(-0.5, 2.6, -1.05), Vector3(-1.4, 1.6, -0.85)], [Vector2(0.42, 0.1), Vector2(0.45, 0.1), Vector2(0.42, 0.1), Vector2(0.36, 0.09)], WOOD2, 10, 4)
	for s in [-1.0, 1.0]:
		Loft.blob(b, Vector3(s * 1.85, 4.1, 0.02), Vector3(s * 0.4, -1, 0), 1.05, [Vector2(0.2, 0.2), Vector2(0.56, 0.5), Vector2(0.5, 0.45), Vector2(0.18, 0.18)], WOOD, 12)   # omuz
		# ana kollar: omuzdan inip göğsün önünde birleşen dua eden eller
		Loft.tube(b, [Vector3(s * 2.0, 3.95, 0.0), Vector3(s * 1.95, 3.0, -0.4), Vector3(s * 0.95, 2.75, -1.1), Vector3(s * 0.16, 3.15, -1.3)], [0.46, 0.42, 0.36, 0.3], WOOD, 12, 3)
		b.add("cyl", Vector3(s * 0.58, 2.88, -1.2), Vector3(0.66, 0.13, 0.66), DARK, Vector3(0, 0, s * 70), 12)
	Loft.blob(b, Vector3(0, 3.3, -1.33), Vector3(0, 1, -0.1), 1.2, [Vector2(0.3, 0.22), Vector2(0.38, 0.27), Vector2(0.32, 0.23), Vector2(0.13, 0.1)], WOOD, 12)   # birleşik avuçlar
	Loft.tube(b, [Vector3(0, 3.0, -1.5), Vector3(0, 3.85, -1.47)], [0.012, 0.012], DARK, 4, 1)   # avuç arası çizgi
	# boyun + uzun maske yüz (ref 1:49-1:51: uzun çene, düz burun, kapalı göz yayları)
	Loft.tube(b, [Vector3(0, 4.45, 0.0), Vector3(0, 4.9, -0.04)], [0.55, 0.5], WOOD, 12, 2)
	Loft.blob(b, Vector3(0, 5.25, -0.06), Vector3(0, 1, 0), 1.8, [Vector2(0.48, 0.5), Vector2(0.66, 0.66), Vector2(0.68, 0.68), Vector2(0.62, 0.62), Vector2(0.3, 0.3)], WOOD, 16)
	for s in [-1.0, 1.0]:
		Loft.blob(b, Vector3(s * 0.72, 5.15, 0.05), Vector3(0, -1, 0), 1.15, [Vector2(0.09, 0.06), Vector2(0.14, 0.08), Vector2(0.13, 0.07), Vector2(0.11, 0.05)], WOOD, 8)   # uzun kulak memesi
		Loft.tube(b, [Vector3(s * 0.12, 5.55, -0.66), Vector3(s * 0.28, 5.5, -0.67), Vector3(s * 0.44, 5.56, -0.6)], [0.03, 0.034, 0.022], DARK, 6, 2)   # kapalı göz
		Loft.tube(b, [Vector3(s * 0.1, 5.75, -0.66), Vector3(s * 0.3, 5.8, -0.64), Vector3(s * 0.48, 5.74, -0.56)], [0.025, 0.028, 0.02], DARK, 6, 2)   # kaş
	Loft.blob(b, Vector3(0, 5.32, -0.72), Vector3(0, -0.8, -0.55), 0.5, [Vector2(0.06, 0.05), Vector2(0.11, 0.09), Vector2(0.12, 0.09), Vector2(0.06, 0.04)], WOOD, 8)   # burun
	b.add("box", Vector3(0, 4.88, -0.66), Vector3(0.26, 0.035, 0.035), DARK)   # ağız
	b.add("sphere", Vector3(0, 5.92, -0.64), Vector3(0.09, 0.09, 0.05), DARK, Vector3.ZERO, 8)   # alın beni
	# taç: iki sıra küçük Buda başı + topuz (ref 1:51)
	for k in 7:
		var a = lerpf(-1.4, 1.4, k / 6.0)
		var hp = Vector3(sin(a) * 0.6, 6.25, -cos(a) * 0.52 + 0.06)
		Loft.blob(b, hp, Vector3.UP, 0.42, [Vector2(0.1, 0.1), Vector2(0.17, 0.17), Vector2(0.16, 0.16), Vector2(0.07, 0.07)], WOOD2, 10)
		b.add("sphere", hp + Vector3(0, 0.2, 0.0), Vector3(0.12, 0.1, 0.12), DARK, Vector3.ZERO, 6)
	for k in 4:
		var a = lerpf(-0.9, 0.9, k / 3.0)
		var hp = Vector3(sin(a) * 0.36, 6.62, -cos(a) * 0.3 + 0.08)
		Loft.blob(b, hp, Vector3.UP, 0.36, [Vector2(0.08, 0.08), Vector2(0.14, 0.14), Vector2(0.13, 0.13), Vector2(0.06, 0.06)], WOOD2, 10)
	Loft.blob(b, Vector3(0, 6.95, 0.06), Vector3.UP, 0.55, [Vector2(0.14, 0.14), Vector2(0.24, 0.24), Vector2(0.2, 0.2), Vector2(0.06, 0.06)], DARK, 10)   # topuz
	_mi(b)
	# hale: başın ardında halka + gövdenin ardında dikey oval levha (ref 1:40: kalın kenarlı dik levha)
	var hb = MB.new()
	hb.add("torus", Vector3(0, 5.6, 0.62), Vector3(2.6, 0.14, 2.6), DARK, Vector3(90, 0, 0), 36)
	hb.add("cyl", Vector3(0, 3.6, 1.05), Vector3(6.4, 0.28, 8.4), WOOD2, Vector3(90, 0, 0), 40)   # oval levha
	hb.add("torus", Vector3(0, 3.6, 0.9), Vector3(6.6, 0.35, 8.6), DARK, Vector3(90, 0, 0), 48)   # kalın kenar
	for k in 28:   # levhanın kabartma ışın çizgileri
		var a = k * TAU / 28.0
		hb.add("box", Vector3(cos(a) * 2.2, 3.6 + sin(a) * 2.9, 0.88), Vector3(0.06, 1.4, 0.05), DARK, Vector3(0, 0, rad_to_deg(a) - 90))
	_mi(hb)


## Sırttan eş merkezli sıralar hâlinde açılan yüzlerce kol (ref: tavus kuyruğu yelpazesi; dış sıralar daha uzun ve geride)
func _build_fan() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = arm_mesh()
	var rows = 15
	var xfs = []
	var pivot = Vector3(0, 3.4, 1.4)
	for r in rows:
		var n = 26 + r * 6
		var L = 2.4 + r * 0.42
		var rad0 = 2.6 + r * 0.38
		for k in n:
			var a = lerpf(-1.95, 1.95, (k + 0.5 * (r % 2)) / float(n))   # dikeyden açı: yelpaze yarım daireden biraz geniş
			var radial = Vector3(sin(a), cos(a), 0.0)
			var dir = (radial + Vector3(0, 0, 0.18 + r * 0.035)).normalized()
			var origin = pivot + radial * rad0 * Vector3(1.05, 0.95, 1.0) + Vector3(0, 0, 0.15 + r * 0.16)
			var yb = dir
			var xb = Vector3.BACK.cross(yb).normalized()
			if xb.length() < 0.1:
				xb = Vector3.RIGHT
			var zb = xb.cross(yb).normalized()
			xfs.append(Transform3D(Basis(xb * L * 1.15, yb * L, zb * L * 1.15), origin))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	fan_xf = xfs
	fan = MultiMeshInstance3D.new()
	fan.multimesh = mm
	body.add_child(fan)


## Kuyruktaki rastgele bir kolun kökü (dünya): saldıran kol buradan uzar
func random_root_world() -> Vector3:
	var xf: Transform3D = fan_xf[randi() % fan_xf.size()]
	return body.global_transform * (xf * Vector3(0, 0.3, 0))


func random_hand_world() -> Vector3:
	var xf: Transform3D = fan_xf[randi() % fan_xf.size()]
	return body.global_transform * (xf * Vector3(0, 0.95, 0))


# ------------------------------------------------------------------ Chōjō Kebutsu: heykele bağlı uzayan yumruk kolları
## Kuyruktaki bir kökten uzayacak kol açar (başta boyu sıfır). r kol kalınlığı (m), fs yumruk boyu (m).
func new_arm(r: float, fs: float) -> Dictionary:
	var shaft = MeshInstance3D.new()
	shaft.mesh = shaft_mesh()
	var fist = MeshInstance3D.new()
	fist.mesh = fist_mesh()
	add_child(shaft)
	add_child(fist)
	shaft.top_level = true
	fist.top_level = true
	var root = random_root_world()
	var a = {"shaft": shaft, "fist": fist, "root": root, "r": r, "fs": fs, "tip": root}
	arms.append(a)
	_pose_arm(a, root)
	return a


## Kolu kökten tip noktasına uzatır: gövde kökten tipe dümdüz, yumruk tipte hedefe bakar
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
	var fs: float = a["fs"]
	(a["shaft"] as Node3D).global_transform = Transform3D(Basis(x * r, y * maxf(L - fs * 0.6, 0.01), z * r), root)
	(a["fist"] as Node3D).global_transform = Transform3D(Basis(x * fs, y * fs, z * fs), tip - y * fs * 0.45)
	(a["shaft"] as Node3D).visible = L > 1.0
	(a["fist"] as Node3D).visible = L > 1.0


## Kolu şimdiki ucundan goal'a uzatır (dur sn), vurunca on_hit(goal), hold sn bekler, geri çeker (back sn; köke kadar değil)
func punch(a: Dictionary, goal: Vector3, dur: float, hold: float, back: float, on_hit: Callable) -> void:
	var root: Vector3 = a["root"]
	var from: Vector3 = a["tip"]
	var mid = root.lerp(goal, 0.3)
	var tw = create_tween()
	tw.tween_method(func(t: float): _pose_arm(a, from.lerp(goal, t)), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_hit.bind(goal))
	tw.tween_interval(hold)
	tw.tween_method(func(t: float): _pose_arm(a, goal.lerp(mid, t)), 0.0, 1.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Kolu tamamen köküne geri sarar ve siler
func retract(a: Dictionary, back: float) -> void:
	var root: Vector3 = a["root"]
	var from: Vector3 = a["tip"]
	var tw = create_tween()
	tw.tween_method(func(t: float): _pose_arm(a, from.lerp(root, t)), 0.0, 1.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_drop_arm.bind(a))


func _drop_arm(a: Dictionary) -> void:
	for k in ["shaft", "fist"]:
		if is_instance_valid(a[k]):
			(a[k] as Node).queue_free()
	arms.erase(a)
