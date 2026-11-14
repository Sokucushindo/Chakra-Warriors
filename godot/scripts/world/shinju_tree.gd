class_name ShinjuTree
extends Node3D
## Shinju — Tanrı Ağacı (On Kuyruk'un son biçimi). Referans: refs/jubi/Ten-Tails__Ten-Tails_tree.png, God_Tree__Artificial_God_Tree.png
## Okunan yapı: halat gibi burulmuş dört kalın lif gövde, yukarı doğru incelir; dipten on dev kök yere yayılır (on kuyruk);
## tepede yeşil çanak yapraklar üstünde kapalı mor tomurcuk. Tepesinde Mugen Tsukuyomi'nin ayı: yaklaştıkça kızarır.
## Çarpışma görselin kendi şeklinden: gövde üst üste silindirler, kökler boyunca küreler (üstünde yürünür / tırmanılır).

const H := 720.0
const BARK := Color(0.31, 0.26, 0.2)
const BARK_D := Color(0.17, 0.14, 0.11)
const SEPAL := Color(0.3, 0.42, 0.2)
const BUD := Color(0.6, 0.36, 0.8)
const BUD_D := Color(0.36, 0.18, 0.55)

var moon: MeshInstance3D
var moon_mat: StandardMaterial3D
var ring_mat: StandardMaterial3D
var body: StaticBody3D


static func spawn(parent: Node, at: Vector3) -> ShinjuTree:
	var t = ShinjuTree.new()
	parent.add_child(t)
	t.global_position = at
	t._build()
	return t


static func _trunk_r(u: float) -> float:
	return lerpf(54.0, 13.0, pow(u, 0.7)) * (1.0 + 0.9 * maxf(0.0, 1.0 - u / 0.07))


func _build() -> void:
	body = StaticBody3D.new()
	add_child(body)
	var mb = MB.new()
	# --- gövde: dört lif, halat gibi burulur
	for k in 4:
		var pts = []
		var rad = []
		for i in 49:
			var u = i / 48.0
			var R = _trunk_r(u)
			var a = k * TAU / 4.0 + u * TAU * 5.5
			pts.append(Vector3(cos(a) * R * 0.6, u * H - 6.0, sin(a) * R * 0.6))
			rad.append(R * 0.64)
		Loft.tube(mb, pts, rad, BARK.lerp(BARK_D, 0.45 * (k % 2)), 10, 2, true, true)
	for i in 8:
		var u = (i + 0.5) / 8.0
		var cs = CollisionShape3D.new()
		var cy = CylinderShape3D.new()
		cy.radius = _trunk_r(u) * 1.2
		cy.height = H / 8.0
		cs.shape = cy
		cs.position = Vector3(0, u * H, 0)
		body.add_child(cs)
	# --- on kök: dipten çıkar, yere yaslanarak uzaklaşır, incelir
	var gp = global_position
	for k in 10:
		var a = k * TAU / 10.0 + 0.35 * sin(k * 2.3)
		var L = 300.0 + 220.0 * fposmod(k * 0.618, 1.0)
		var dir = Vector3(cos(a), 0, sin(a))
		var side = Vector3(-dir.z, 0, dir.x)
		var pts = []
		var rad = []
		for i in 13:
			var t = i / 12.0
			var p = dir * (30.0 + t * L) + side * sin(t * 5.0 + k) * 26.0 * t
			var r = lerpf(42.0, 3.0, pow(t, 0.8))
			var gy = Game.ground_height(gp.x + p.x, gp.z + p.z) - gp.y
			p.y = lerpf(70.0, gy + r * 0.3, minf(1.0, t * 4.0))
			pts.append(p)
			rad.append(r)
			var cs = CollisionShape3D.new()
			var sp = SphereShape3D.new()
			sp.radius = r
			cs.shape = sp
			cs.position = p
			body.add_child(cs)
			if i > 0:
				var cs2 = CollisionShape3D.new()
				var sp2 = SphereShape3D.new()
				sp2.radius = (r + float(rad[i - 1])) * 0.5
				cs2.shape = sp2
				cs2.position = (p + pts[i - 1]) * 0.5
				body.add_child(cs2)
		Loft.tube(mb, pts, rad, BARK.lerp(BARK_D, 0.3 + 0.3 * (k % 2)), 10, 3, true, true)
		# köke sarılı ince lif (burgu izi)
		var lp = []
		var lr = []
		for i in 25:
			var t = i / 24.0
			var idx = mini(11, int(t * 12.0))
			var f = t * 12.0 - idx
			var c: Vector3 = (pts[idx] as Vector3).lerp(pts[idx + 1], f)
			var r = lerpf(float(rad[idx]), float(rad[idx + 1]), f)
			var w = t * 14.0 + k
			lp.append(c + (side * cos(w) + Vector3.UP * sin(w)) * r * 0.92)
			lr.append(r * 0.22 + 0.3)
		Loft.tube(mb, lp, lr, BARK_D, 6, 1, true, true)
	var mi = MeshInstance3D.new()
	mi.mesh = mb.build(Props.toon())
	mi.extra_cull_margin = 200.0
	add_child(mi)
	# --- tepe: yeşil çanak yapraklar + kapalı mor tomurcuk (gölgesiz: gece de seçilir)
	var mt = MB.new()
	for k in 7:
		var a = k * TAU / 7.0
		var d = Vector3(cos(a), 0, sin(a))
		Loft.tube(mt, [Vector3(0, H - 4.0, 0), d * 34.0 + Vector3(0, H + 12.0, 0), d * 70.0 + Vector3(0, H + 4.0, 0), d * 98.0 + Vector3(0, H - 26.0, 0)],
			[Vector2(6.0, 5.0), Vector2(20.0, 3.5), Vector2(15.0, 2.5), Vector2(1.0, 0.6)], [SEPAL.darkened(0.3), SEPAL, SEPAL, SEPAL.lightened(0.15)], 8, 4, true, true, Callable(), d)
	mt.add("sphere", Vector3(0, H + 44.0, 0), Vector3(50.0, 96.0, 50.0), BUD_D, Vector3.ZERO, 14)
	for j in 3:
		var n = 6 - j
		var ring_r = [25.0, 17.0, 9.0][j]
		for k in n:
			var a = k * TAU / n + j * 0.5
			var d = Vector3(cos(a), 0, sin(a))
			mt.add("sphere", d * ring_r + Vector3(0, H + 24.0 + j * 24.0, 0), Vector3(30.0 - j * 5.0, 58.0 - j * 6.0, 14.0), BUD.lerp(BUD_D, 0.25 * ((k + j) % 2)),
				Vector3(-14.0 - j * 4.0, -rad_to_deg(a) + 90.0, 0), 10)
	var ti = MeshInstance3D.new()
	ti.mesh = mt.build(null)
	var tm = StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ti.material_override = tm
	add_child(ti)
	# --- ay: Mugen Tsukuyomi yaklaştıkça kızarır, üstünde Rinne-Sharingan halkaları belirir
	moon = MeshInstance3D.new()
	var mm = MB.new()
	mm.add("sphere", Vector3.ZERO, Vector3(2.0, 2.0, 2.0), Color(1, 1, 1), Vector3.ZERO, 24)
	var mr = MB.new()
	for ring in 3:
		var rr = 0.3 + ring * 0.24
		var pts = []
		var rads = []
		for k in 37:
			var a = TAU * k / 36.0
			pts.append(Vector3(cos(a) * rr, sin(a) * rr, -sqrt(maxf(0.0, 1.0 - rr * rr)) - 0.012))
			rads.append(0.022)
		Loft.tube(mr, pts, rads, Color(1, 1, 1), 4, 1, false, false)
		for k in 3:
			var a2 = TAU * k / 3.0 + ring * 0.7
			mr.add("sphere", Vector3(cos(a2) * rr, sin(a2) * rr, -sqrt(maxf(0.0, 1.0 - rr * rr)) - 0.01), Vector3(0.12, 0.12, 0.06), Color(1, 1, 1), Vector3.ZERO, 6)
	mr.add("sphere", Vector3(0, 0, -1.0), Vector3(0.16, 0.16, 0.06), Color(1, 1, 1), Vector3.ZERO, 8)
	moon.mesh = mm.build(null)
	moon_mat = StandardMaterial3D.new()
	moon_mat.vertex_color_use_as_albedo = true
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.disable_fog = true
	moon.material_override = moon_mat
	moon.scale = Vector3.ONE * 190.0
	add_child(moon)
	var ri = MeshInstance3D.new()
	ri.mesh = mr.build(null)
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.disable_fog = true
	ri.material_override = ring_mat
	moon.add_child(ri)
	moon.position = Vector3(380.0, H + 620.0, 700.0)
	set_moon(0.0)


## k: 0 (ağaç yeni dikildi, solgun ay) .. 1 (Mugen Tsukuyomi: kan kırmızı)
func set_moon(k: float) -> void:
	if moon_mat:
		k = clampf(k, 0.0, 1.0)
		var c = Color(1.0, 0.95, 0.86).lerp(Color(0.95, 0.12, 0.1), k)
		moon_mat.albedo_color = c
		ring_mat.albedo_color = c.lerp(Color(0.22, 0.02, 0.03), smoothstep(0.15, 0.7, k))   # halkalar ay kızardıkça belirir


func _process(_dt: float) -> void:
	# ayın halkalı yüzü hep bakana döner
	var cam = get_viewport().get_camera_3d()
	if cam and moon:
		moon.look_at(cam.global_position, Vector3.UP)


## Ağaç kurur: yere çöker ve kaybolur
func wither() -> void:
	body.queue_free()
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), 6.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(moon, "scale", Vector3.ONE * 0.01, 3.0)
	tw.tween_callback(queue_free)
