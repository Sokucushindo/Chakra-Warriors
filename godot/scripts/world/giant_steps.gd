class_name GiantSteps
extends RefCounted
## Dev adımı: devasa gövdeler (Gedō Mazō, bijū, büyük kuchiyoseler) yürürken her ayak basışında yer titrer, boğuk bir "güm"
## duyulur, ayağın biçiminde çukur iz kalır (kenarında kalkmış toprak parçaları) ve bastığı yerdeki yapılar yıkılır.
## Her şey gövdenin boyuna göre ölçeklenir: 6 m'lik hayvan hafif tıkırdar, 100 m'lik heykel ekranı sarsar.
## Çağıran: adım atan gövdenin kendi kodu (GedoWalker._step, BeastRig, Summon) — track() yol sayacıyla adımı kendisi bulur.

const MIN_SIZE := 5.0
const MAX_PRINTS := 40
const PRINT_LIFE := 40.0
static var _prints: Array = []
static var _mesh := {}
static var _acc := {}      # gövde kimliği -> [son konum, birikmiş yol, sıradaki ayak]


## Yol sayacı: gövde her kare çağırır; adım boyu kadar ilerleyince sıradaki ayağın yerine stomp atar.
## size = gövde boyu (m), half = ayaklar arası yarı açıklık (m), shape = "foot" (insansı) / "paw" (pençe) / "web" (kurbağa)
static func track(who: Node3D, size: float, yaw: float, half: float, shape := "paw", owner_f = null) -> void:
	if size < MIN_SIZE or not is_instance_valid(who):
		return
	var id := who.get_instance_id()
	var p: Vector3 = who.global_position
	var rec = _acc.get(id)
	if rec == null:
		if _acc.size() > 64:
			_acc.clear()
		_acc[id] = [p, 0.0, 1.0]
		return
	var d := Vector2(p.x - rec[0].x, p.z - rec[0].z).length()
	rec[0] = p
	if d > size * 2.0:   # ışınlanma: adım sayılmaz
		return
	rec[1] += d
	var stride := clampf(size * 0.32, 2.5, 30.0)
	if rec[1] < stride:
		return
	rec[1] = 0.0
	rec[2] = -float(rec[2])
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * half * float(rec[2])
	stomp(Game.jutsu_floor_at(p + side), size, yaw, shape, float(rec[2]) > 0.0, owner_f)


## Tek ayak basışı
static func stomp(at: Vector3, size: float, yaw: float, shape := "paw", right := true, owner_f = null) -> void:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or Game.world == null:
		return
	var d: float = at.distance_to(pl.global_position)
	var reach := size * 5.0 + 60.0
	if d > reach:
		return
	var k := 1.0 - d / reach
	var big := clampf(size / 60.0, 0.12, 1.4)
	Game.world.env.add_shake(big * k * 0.9)
	# güm: boy büyüdükçe daha kalın ve daha gür; uzaktan da duyulur (dev adımı konumdan bağımsız, mesafeyle kısılır)
	Sfx.play("boom", null, clampf(0.62 - size * 0.0022, 0.36, 0.62) * randf_range(0.94, 1.06), clampf(big * k * 0.32, 0.0, 0.3))   # kullanıcı: ses çok yüksekti
	if d < size * 3.0 + 40.0:
		Sfx.play("earth", at, randf_range(0.55, 0.7), clampf(big * 0.3, 0.06, 0.22))
	_print_at(at, size, yaw, shape, right)
	# bastığı yerdeki yapılar yıkılır
	WorldDamage.impact(at + Vector3.UP * 1.0, clampf(size * 0.14, 2.0, 16.0), {"dmg": size * 8.0, "kind": "heavy", "attacker": owner_f})


## Ayak biçimi dokusu (zemine yansıtılan çıkartma için): koyu çukur tabanı, kenara doğru yumuşar. Biçim başına bir kez çizilir.
static func _shape_tex(shape: String) -> ImageTexture:
	if _mesh.has(shape):
		return _mesh[shape]
	var blobs: Array = []   # [merkez x, merkez z, yarıçap x, yarıçap z, dönüş] (birim kare içinde, parmaklar -z)
	match shape:
		"foot":   # insansı taban: uzun taban + topuk + beş parmak
			blobs.append([0.0, -0.05, 0.3, 0.46, 0.0])
			blobs.append([0.0, 0.42, 0.24, 0.26, 0.0])
			for i in 5:
				blobs.append([-0.28 + i * 0.14, -0.66 + absf(i - 1.5) * 0.05, 0.075, 0.11, 0.0])
		"web":   # kurbağa: geniş taban + yelpaze gibi açılan dört uzun parmak
			blobs.append([0.0, 0.22, 0.3, 0.34, 0.0])
			for i in 4:
				var a := -0.75 + i * 0.5
				blobs.append([sin(a) * 0.48, -cos(a) * 0.48, 0.09, 0.36, a])
		_:   # pençe: yuvarlak yastık + dört parmak yastığı + tırnak çentikleri
			blobs.append([0.0, 0.2, 0.34, 0.3, 0.0])
			for i in 4:
				var a2 := -0.6 + i * 0.4
				blobs.append([sin(a2) * 0.5, -cos(a2) * 0.4, 0.12, 0.17, a2])
				blobs.append([sin(a2) * 0.74, -cos(a2) * 0.68, 0.035, 0.1, a2])
	var N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var px := (x + 0.5) / N * 2.0 - 1.0
			var pz := (y + 0.5) / N * 2.0 - 1.0
			var best := 9.0
			for bl in blobs:
				var dx: float = px - float(bl[0])
				var dz: float = pz - float(bl[1])
				var ca := cos(float(bl[4]))
				var sa := sin(float(bl[4]))
				var lx := (dx * ca + dz * sa) / float(bl[2])
				var lz := (-dx * sa + dz * ca) / float(bl[3])
				best = minf(best, sqrt(lx * lx + lz * lz))
			var al := clampf((1.0 - best) / 0.22, 0.0, 1.0)
			# taban koyu, kenarın hemen içinde en koyu halka (çukurun gölgeli duvarı)
			var wall := clampf(1.0 - absf(best - 0.82) / 0.18, 0.0, 1.0)
			var v := 0.07 - wall * 0.04
			img.set_pixel(x, y, Color(v, v * 0.78, v * 0.55, al * (0.8 + wall * 0.2)))
	_mesh[shape] = ImageTexture.create_from_image(img)
	return _mesh[shape]


static func _rim_mesh() -> ArrayMesh:
	if not _mesh.has("_rim"):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, Color(0.42, 0.34, 0.25), Vector3.ZERO, 4)
		_mesh["_rim"] = b.build(Props.toon())
	return _mesh["_rim"]


## Çukur iz: ayak biçiminde koyu taban (zemine gömülü görünür) + kenarında kalkmış toprak parçaları; bir süre kalıp solar
static func _print_at(at: Vector3, size: float, yaw: float, shape: String, right: bool) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var fl := clampf(size * 0.115, 0.8, 13.0)   # ayak boyu (m)
	var root := Node3D.new()
	tree.current_scene.add_child(root)
	root.global_position = at
	root.rotation.y = yaw
	var dc := Decal.new()   # zemine yansır: engebeli arazide gömülmez, havada kalmaz
	dc.texture_albedo = _shape_tex(shape)
	dc.size = Vector3(fl * 1.25 * 2.0, 8.0 + fl, fl * 1.25 * 2.0) * 0.8
	dc.scale = Vector3(-1.0 if not right else 1.0, 1.0, 1.0)
	dc.upper_fade = 0.0
	dc.lower_fade = 0.0
	dc.normal_fade = 0.2
	dc.distance_fade_enabled = true
	dc.distance_fade_begin = 500.0
	dc.distance_fade_length = 120.0
	root.add_child(dc)
	var n := clampi(int(6 + size * 0.12), 6, 16)
	var rocks: Array = []
	for i in n:
		var a := TAU * i / float(n) + randf_range(-0.2, 0.2)
		var r := MeshInstance3D.new()
		r.mesh = _rim_mesh()
		var s := fl * randf_range(0.07, 0.15)
		r.scale = Vector3(s * randf_range(1.0, 1.6), s * 0.6, s)
		r.position = Vector3(cos(a) * fl * 0.52, s * 0.15, sin(a) * fl * 0.85 - fl * 0.08)
		r.position.y += Game.jutsu_floor_at(root.global_position + Basis(Vector3.UP, yaw) * r.position).y - at.y
		r.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(r)
		rocks.append(r)
		var p1: Vector3 = r.position
		r.position = p1 - Vector3.UP * s
		var tr := r.create_tween()
		tr.tween_property(r, "position", p1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prints.append(root)
	while _prints.size() > MAX_PRINTS:
		var old = _prints.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := root.create_tween()
	tw.tween_interval(PRINT_LIFE * 0.7)
	tw.tween_property(dc, "albedo_mix", 0.0, PRINT_LIFE * 0.3)
	for r in rocks:
		tw.parallel().tween_property(r, "scale", Vector3.ONE * 0.01, PRINT_LIFE * 0.3)
	tw.tween_callback(root.queue_free)
