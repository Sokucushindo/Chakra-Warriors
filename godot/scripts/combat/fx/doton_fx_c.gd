class_name DotonFXC
extends RefCounted
## Doton grubu C: on beş toprak tekniğinin görselleri — malzeme ve yapı taşları DotonLib'den (kaya / çamur / toz / zemin izi /
## çamur seli / yarık / beden kaplaması / kristal), her tekniğin şekli, hareketi ve sahnelenmesi burada ve birbirinden ayrı.
## Ortak efekt yardımcısı yok. Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, kopya mekaniği,
## yarık / çamur zemin bölgeleri) ana ağaçtaki işleyicilerden satır satır taşındı.
## Okunurluk: toz az ve kameraya yakınken söner (kütüphane), büyük yapılar kamerayla kişi arasına girmez, büyük kaya yüzleri
## gerçek boyutlu ağlarla (doku iri lekeye dönmez), çamur seli kabarık kesitli (hacimli).

const DL = preload("res://scripts/combat/fx/lib/doton_lib.gd")
const VX = preload("res://scripts/combat/vfx.gd")   # yalnız destan ölçeği sayısı (epic) okunur; görsel kullanılmaz
const ARMOR_GLOW := Color(0.5, 0.85, 1.0)

static var _cache := {}


# ================================================================== ortak oynanış izleri
## Eski zemin çatlağının oyun tarafı (birebir): büyük yarık üstünden geçeni yavaşlatır; boy destan ölçeğiyle büyür
static func _zone(pos: Vector3, size: float, dur := 6.0) -> void:
	var s = size * VX.epic
	if s >= 1.5:
		GroundFX.add(pos, "cracked", s * 0.6, clampf(dur, 3.0, 5.0))


## Eski "toprak çıkışı" patlamasının oyun tarafı (çatlak 2.2 * s)
static func _burst_zone(pos: Vector3, s: float) -> void:
	_zone(pos, 2.2 * s, 6.0)


# ================================================================== küçük yardımcılar
static func _prof(arr: Array) -> PackedVector2Array:
	var o = PackedVector2Array()
	for q in arr:
		o.append(q)
	return o


static func _cam(host: Node) -> Camera3D:
	if host == null or not host.is_inside_tree():
		return null
	return host.get_viewport().get_camera_3d()


## Sağ elli taban: X, Y = yukarı, Z = out (yatay)
static func _basis_out(out: Vector3) -> Basis:
	var z = DL.flat(out)
	var x = Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


## Kemiğe iliştirilmiş plakaları sök: her biri gerçek bir taş parçası olarak düşer, ek düğüm silinir
static func _shed(host: Node, ba: Node3D, col: Color) -> void:
	if ba == null or not is_instance_valid(ba):
		return
	if ba.is_inside_tree():
		for p in ba.find_children("*", "MeshInstance3D", true, false):
			var pm: MeshInstance3D = p
			if pm.material_override == DL.edge_glow_mat() or randf() < 0.45:
				continue
			var ck = DL.chunk(0.05 * randf_range(0.7, 1.3), 2, col.darkened(randf_range(0.0, 0.15)), {"ow": 0.01})
			DL.toss(host, ck, pm.global_position, Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.2), randf_range(-1.5, 1.5)), 0.8, 18.0, 0.5)
		DL.grit(host, ba.global_position, 8, col, {"spread": 120.0, "vmin": 0.4, "vmax": 1.8, "r": 0.12, "life": 0.6, "size": 0.03})
	ba.queue_free()


## Kişinin modeline zamanlı beden kaplaması: param a0 → a1 (t_in), bekle, a1 → a0 (t_out), kaldır
static func _skin_timed(c: Node3D, m: ShaderMaterial, param: String, a0: float, a1: float, t_in: float, dur: float, t_out: float) -> void:
	var mdl = c.get("model")
	if mdl == null or not is_instance_valid(mdl) or not (mdl as Node).is_inside_tree():
		return
	m.set_shader_parameter(param, a0)
	var list = DL.skin_apply(mdl, m)
	if list.is_empty():
		return
	var tw = (mdl as Node).create_tween()
	tw.tween_property(m, "shader_parameter/" + param, a1, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - t_in - t_out))
	tw.tween_property(m, "shader_parameter/" + param, a0, t_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): DL.skin_clear(list, m))


## Sürekli düşen damla / tane yayıcı (parent'a bağlı, dünya uzayında iz)
static func _drips(parent: Node3D, amount: int, mesh: Mesh, mat: Material, o := {}) -> GPUParticles3D:
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.DOWN)
	pm.spread = float(o.get("spread", 25.0))
	pm.initial_velocity_min = float(o.get("vmin", 0.3))
	pm.initial_velocity_max = float(o.get("vmax", 1.5))
	pm.gravity = Vector3(0, -float(o.get("g", 14.0)), 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(o.get("r", 0.5))
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ps = GPUParticles3D.new()
	ps.process_material = pm
	ps.amount = maxi(1, amount)
	ps.lifetime = float(o.get("life", 0.7))
	ps.local_coords = false
	ps.draw_pass_1 = mesh
	ps.material_override = mat
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	parent.add_child(ps)
	ps.position = o.get("off", Vector3.ZERO)
	ps.emitting = true
	return ps


static func _eye_mat() -> StandardMaterial3D:
	if not _cache.has("eye"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.78, 0.3)
		_cache["eye"] = m
	return _cache["eye"]


static func _eye_mesh() -> SphereMesh:
	if not _cache.has("eye_mesh"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 5
		_cache["eye_mesh"] = s
	return _cache["eye_mesh"]


static func _star_quad() -> QuadMesh:
	if not _cache.has("star_q"):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache["star_q"] = q
	return _cache["star_q"]


## Kemik ekinin altına metre ölçekli kök: iskeletin / modelin küresel ölçeği (içe aktarılan rig 0.01 ya da 100 olabilir)
## sökülür, çocukların boyu ve konumu gerçek metre olur
static func _bone_root(ba: Node3D) -> Node3D:
	var root = Node3D.new()
	ba.add_child(root)
	var p = ba.get_parent()
	if p is Node3D:
		var sc = (p as Node3D).global_basis.get_scale()
		var k = (sc.x + sc.y + sc.z) / 3.0
		if k > 0.0001:
			root.scale = Vector3.ONE / k
	return root


## Kemiğin Y ekseni çevresine halka halinde taş plakalar (kemiğe iliştirilir): n plaka, r yarıçap, y0..y1 boy aralığı (metre)
static func _plate_ring(ba: Node3D, n: int, r: float, y0: float, y1: float, sz: Vector3, col: Color, glow: bool, delay0: float) -> void:
	var root = _bone_root(ba)
	var rows = 2 if y1 - y0 > 0.08 else 1
	for row in rows:
		var y = lerpf(y0, y1, float(row) / maxf(1.0, float(rows - 1)))
		for i in n:
			var a = TAU * (i + 0.5 * row + randf_range(-0.12, 0.12)) / n
			var out = Vector3(cos(a), 0.0, sin(a))
			var mesh = DL.chunk_mesh(2, i + row * 3)
			var pl = DL.rock(mesh, col.darkened(randf_range(0.0, 0.14)), {"ow": 0.012})
			root.add_child(pl)
			pl.position = out * r + Vector3.UP * y
			var s = sz * randf_range(0.85, 1.15)
			pl.basis = Basis.looking_at(out, Vector3.UP).scaled(Vector3.ONE)
			pl.scale = Vector3.ONE * 0.01
			if glow:
				var gl = DL.gi(mesh, DL.edge_glow_mat())
				gl.set_instance_shader_parameter("gcol", DL.v3(ARMOR_GLOW))
				gl.set_instance_shader_parameter("gpow", 0.85)
				pl.add_child(gl)
			var tw = pl.create_tween()
			tw.tween_interval(delay0 + row * 0.06 + i * 0.015)
			tw.tween_property(pl, "scale", s, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================== 1) Iwa Bunshin no Jutsu (Ōnoki)
## Kopya, yerden kalkan iki yarım taş kozanın içinde belirir; kozalar katman şeritli kaya, yanlara açılıp kırılarak toprağa
## geri gömülür. Kopyanın bedeni (referans) önce baştan aşağı taştır; plakalar hücre hücre dökülür, bedende çokgen taş yarıkları
## kalır. Vurulunca kopya yontulmuş taş parçalarına ayrılıp saçılır, yerde çatlak kalır (duman yok).
static func _cocoon(pj: PathJutsu, at: Vector3, face: Vector3, tone: Color) -> void:
	var side = DL.side_of(face)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for s in [-1.0, 1.0]:
		var ol = PackedVector2Array()
		for i in 7:
			var a = PI * float(i) / 6.0
			ol.append(Vector2(cos(a) * 0.56 * rng.randf_range(0.92, 1.08), sin(a) * 0.46 * rng.randf_range(0.85, 1.1)))
		var mesh = DL.prism_mesh(ol, 0.0, 2.15, 0.1, 0.12, rng.randi())
		var half = DL.rock(mesh, tone.darkened(rng.randf_range(0.0, 0.1)), {"ow": 0.03, "strata": 3.2, "shadow": true})
		DL.put(pj, half, at - Vector3.UP * 2.3)
		var b0 = Basis(face * s, Vector3.UP, side * s)
		half.global_basis = b0
		var hw = weakref(half)
		var tw = half.create_tween()
		tw.tween_property(half, "global_position", at, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.22)
		tw.set_parallel(true)
		tw.tween_method(func(k: float) -> void:
			var x = hw.get_ref()
			if x != null and is_instance_valid(x):
				x.global_basis = b0.rotated((face * s).normalized(), 0.55 * k), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(half, "global_position", at + side * s * 0.45, 0.22)
		tw.set_parallel(false)
		tw.tween_callback(func():
			var x = hw.get_ref()
			if x == null or not is_instance_valid(x):
				return
			for k in 4:
				var ck = DL.chunk(rng.randf_range(0.14, 0.24), 2, tone.darkened(randf_range(0.0, 0.15)), {"ow": 0.025})
				DL.toss(pj, ck, x.global_position + Vector3.UP * randf_range(0.6, 1.9) + side * s * 0.4, side * s * randf_range(1.5, 3.0) + Vector3.UP * randf_range(1.0, 3.0), 0.9)
			DL.grit(pj, x.global_position + Vector3.UP * 1.0, 12, tone, {"dir": side * s + Vector3.UP * 0.3, "spread": 60.0, "vmin": 1.0, "vmax": 3.5, "r": 0.6, "life": 0.8, "size": 0.05}))
		tw.tween_property(half, "global_position", at + side * s * 0.45 - Vector3.UP * 2.4, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(half.queue_free)


static func _stone_clone(pj: PathJutsu, d: Node3D, tone: Color) -> void:
	var cm = d.get("model")
	if cm == null or not is_instance_valid(cm) or not (cm as Node).is_inside_tree():
		return
	var m = DL.skin_mat(2, tone, 6.0)
	m.set_shader_parameter("fill", 1.0)
	DL.skin_apply(cm, m)
	var tw = (cm as Node).create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(m, "shader_parameter/fill", 0.0, 0.8)
	var dw = weakref(d)
	pj.every(0.8, 0.13, func(_i, _k):
		var x = dw.get_ref()
		if x == null or not is_instance_valid(x):
			return
		var a = randf() * TAU
		var p0 = x.global_position + Vector3(cos(a) * 0.25, randf_range(0.4, 1.6), sin(a) * 0.25)
		var fl = DL.chunk(randf_range(0.05, 0.09), 2, tone, {"ow": 0.012})
		DL.toss(pj, fl, p0, Vector3(cos(a), 0.6, sin(a)) * randf_range(1.0, 2.2), 0.7, 18.0, 0.4))


static func _stone_shatter(pj: PathJutsu, pos: Vector3, tone: Color) -> void:
	var g = DL.floor_at(pos)
	for i in 10:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / 10.0
		var y = randf_range(0.2, 1.7)
		var ck = DL.chunk(randf_range(0.1, 0.2) * (1.2 - y * 0.25), 2, tone.darkened(randf_range(0.0, 0.18)), {"ow": 0.025})
		DL.toss(pj, ck, g + Vector3(cos(a) * 0.2, y, sin(a) * 0.2), Vector3(cos(a), 0.0, sin(a)) * randf_range(1.5, 4.0) + Vector3.UP * randf_range(0.5, 3.0), 1.1)
	DL.grit(pj, g + Vector3.UP * 0.9, 22, tone, {"spread": 120.0, "vmin": 1.5, "vmax": 5.0, "r": 0.4, "life": 0.9, "size": 0.05})
	DL.crack(pj, g, 1.6, 3.0, 0.2)


static func iwa_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tone = Color(0.6, 0.58, 0.54)
	for sx in [-1.0, 1.0]:
		var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 2.5 * sx)
		_burst_zone(at, 1.3)
		_cocoon(pj, at, DL.flat(c.face_dir()), tone)
		DL.crack(pj, at, 1.5, 2.6, 0.15)
		DL.grit(pj, at + Vector3.UP * 0.1, 10, DL.pal(at)["body"], {"spread": 70.0, "vmin": 1.5, "vmax": 4.0, "r": 0.7, "life": 0.7, "size": 0.05})
		var d = pj.decoy(c, at, 12.0, func(pos):
			_stone_shatter(pj, pos, tone)
			_burst_zone(pos, 1.4))
		if d:
			d.set("max_hp", 4.0)
			d.set_meta("no_smoke", true)   # kanon: taş kopya taşa dağılır, duman yok
			_stone_clone(pj, d, tone)
	Sfx.play("earth", c.global_position, 1.1)


# ================================================================== 2) Kakōgan (Taş Parlaklığı)
## Referans: parmak ucunda kızıl, yüzlü, beyaz çizgili kristal; çevresinde dört kollu beyaz parıltı yıldızları. Kristal büyür,
## döner, söner. Sonra iki yumruğun üstünü koyu granit plakalar sarar (içinde kızıl kristal kırıntıları); süre bitince dökülür.
static func _fingertip_crystal(pj: PathJutsu, c: Node3D) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var holder = Node3D.new()
	_bone_root(ba).add_child(holder)
	holder.position = Vector3(0, 0.2, 0)
	var cr = DL.gi(DL.crystal_mesh(randi() % 3), DL.crystal_mat())
	cr.set_instance_shader_parameter("ccol", Vector3(0.92, 0.22, 0.16))
	holder.add_child(cr)
	cr.position = Vector3(0, -0.05, 0)
	cr.scale = Vector3.ONE * 0.005
	var tw = cr.create_tween()
	tw.tween_property(cr, "scale", Vector3.ONE * 0.11, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.65)
	tw.tween_property(cr, "scale", Vector3.ONE * 0.005, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var sp = cr.create_tween()
	sp.tween_property(cr, "rotation:y", TAU * 0.6, 1.1)
	for i in 4:
		var st = DL.gi(_star_quad(), DL.star_mat())
		holder.add_child(st)
		st.position = Vector3(randf_range(-0.07, 0.07), randf_range(0.0, 0.14), randf_range(-0.07, 0.07))
		st.scale = Vector3.ONE * randf_range(0.09, 0.16)
		st.set_instance_shader_parameter("glow", 0.0)
		var sw = st.create_tween()
		sw.tween_interval(0.15 + i * 0.12)
		sw.tween_method(DL.pf(st, "glow"), 0.0, 1.0, 0.1)
		sw.tween_method(DL.pf(st, "glow"), 1.0, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sw.tween_method(DL.pf(st, "glow"), 0.0, 0.8, 0.08)
		sw.tween_method(DL.pf(st, "glow"), 0.8, 0.0, 0.25)
	pj.free_after(1.2, ba)


static func _granite_fist(ba: Node3D) -> void:
	var gran = Color(0.36, 0.33, 0.36)
	_plate_ring(ba, 6, 0.08, 0.03, 0.11, Vector3(0.11, 0.12, 0.08), gran, false, 0.3)
	var mroot = _bone_root(ba)
	var cap = DL.rock(DL.chunk_mesh(2, 4), gran.darkened(0.08), {"ow": 0.01})
	mroot.add_child(cap)
	cap.position = Vector3(0, 0.15, 0.0)
	cap.scale = Vector3.ONE * 0.01
	cap.create_tween().tween_property(cap, "scale", Vector3(0.16, 0.11, 0.14), 0.16).set_delay(0.45).set_trans(Tween.TRANS_BACK)
	for k in 2:
		var fl = DL.gi(DL.crystal_mesh(k), DL.crystal_mat())
		fl.set_instance_shader_parameter("ccol", Vector3(0.85, 0.18, 0.14))
		mroot.add_child(fl)
		fl.position = Vector3((k - 0.5) * 0.08, 0.14, 0.08)
		fl.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		fl.scale = Vector3.ONE * 0.01
		fl.create_tween().tween_property(fl, "scale", Vector3.ONE * 0.04, 0.15).set_delay(0.55)


static func kakogan(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_fingertip_crystal(pj, c)
	var parts = []
	for right in [true, false]:
		var gb = pj.bone_attach(c, "RightHand" if right else "LeftHand")
		if gb == null:
			continue
		_granite_fist(gb)
		parts.append(weakref(gb))
	pj.after(15.0, func():
		for w in parts:
			var x = w.get_ref()
			if x != null:
				_shed(pj, x, Color(0.36, 0.33, 0.36)))
	# oynanış (klan işleyicisinden birebir)
	if c is Player:
		Buffs.add("kakogan", 15.0, {"melee": 1.3})
	Sfx.play("earth", c.global_position, 1.3)


# ================================================================== 3) Doryūdan (Toprak Ejderi Mermisi) — jutsu.gd j_ işleyicisi
## Referans: kişinin yanındaki zeminden ıslak koyu kahve, uzun burunlu bir çamur ejderi kıvrılarak yükselir (kaş çıkıntısı,
## sarı göz, geriye yatık sırt dikenleri, aşağı sarkan çamur dişler); çenesi her tükürüşte açılır, ağzından ıslak çamur topları
## (arkasında damlayan çamur) fırlar; çarpınca çamur sıçrar, yerde göl kalır. Boyun her karede kafaya göre eğri boyunca dizilir,
## gövdeden çamur damlar; iş bitince kafa toprağa geri dalar. (Ejder kişinin 2.4 m yanında, biraz arkasında; kafası omuzun üstünde, kamera görüşünün içinde.)
static func _dragon_head(head: Node3D, mud: Color) -> Node3D:
	var root = Node3D.new()
	head.add_child(root)
	var dark = mud.darkened(0.25)
	var parts = [
		[Vector3(0, 0.15, 0.25), Vector3(0.95, 0.78, 1.15), mud],    # kafatası
		[Vector3(0, 0.05, -0.85), Vector3(0.58, 0.4, 0.95), mud],    # burun / üst çene
		[Vector3(0, 0.55, -0.15), Vector3(0.8, 0.22, 0.55), dark],   # kaş çıkıntısı
		[Vector3(0, 0.22, -1.6), Vector3(0.36, 0.26, 0.32), dark],   # burun ucu
	]
	for p in parts:
		var b = DL.mud_blob(1.0, p[2])
		root.add_child(b)
		b.position = p[0]
		b.rotation = Vector3.ZERO
		b.scale = p[1]
	for s in [-1.0, 1.0]:
		var e = DL.gi(_eye_mesh(), _eye_mat())
		root.add_child(e)
		e.position = Vector3(0.48 * s, 0.38, -0.35)
		e.scale = Vector3(0.12, 0.2, 0.3)
		for k in 3:   # geriye yatık sırt / kulak dikenleri
			var sp = DL.gi(DL.chunk_mesh(1, k + (2 if s > 0 else 0)), DL.mud_mat(0.02))
			sp.set_instance_shader_parameter("mcol", DL.v3(dark))
			root.add_child(sp)
			sp.position = Vector3(0.35 * s * (1.0 - k * 0.3), 0.6 - k * 0.1, 0.5 + k * 0.35)
			sp.rotation = Vector3(1.9 + k * 0.15, 0.0, -0.35 * s)
			sp.scale = Vector3.ONE * (0.28 - k * 0.05)
		for k in 2:   # sarkan çamur dişler
			var tooth = DL.gi(DL.chunk_mesh(1, k + 1), DL.mud_mat(0.015))
			tooth.set_instance_shader_parameter("mcol", DL.v3(mud.lightened(0.15)))
			root.add_child(tooth)
			tooth.position = Vector3(0.22 * s, -0.22, -1.15 + k * 0.4)
			tooth.rotation = Vector3(PI, 0, 0)
			tooth.scale = Vector3.ONE * 0.13
	var jaw = Node3D.new()
	root.add_child(jaw)
	jaw.position = Vector3(0, -0.18, -0.15)
	var jm = DL.mud_blob(1.0, mud.darkened(0.08))
	jaw.add_child(jm)
	jm.position = Vector3(0, -0.12, -0.7)
	jm.rotation = Vector3.ZERO
	jm.scale = Vector3(0.48, 0.2, 0.9)
	_drips(root, 10, DL.chunk_mesh(3, 1, 0.07), DL.mud_mat(0.0), {"r": 0.6, "life": 0.6, "off": Vector3(0, -0.2, -0.4)})
	return jaw


static func _mud_splat(host: Node, pos: Vector3, mud: Color) -> void:
	var g = DL.floor_at(pos)
	for i in 6:
		var a = randf() * TAU
		var b = DL.mud_blob(randf_range(0.12, 0.22), mud.darkened(randf_range(0.0, 0.15)), 0.02)
		DL.toss(host, b, pos + Vector3.UP * 0.2, Vector3(cos(a) * randf_range(2.0, 4.5), randf_range(2.0, 4.5), sin(a) * randf_range(2.0, 4.5)), 0.9, 18.0, 0.6)
	if pos.y - g.y < 1.5:
		DL.puddle(host, g, 1.3, 3.0)
	DL.grit(host, pos, 12, mud, {"spread": 90.0, "vmin": 2.0, "vmax": 5.0, "r": 0.3, "life": 0.6, "size": 0.05})


static func _spit(js, c: Node3D, head: Node3D, jaw: Node3D, dd: Vector3, mud: Color) -> void:
	if is_instance_valid(jaw) and jaw.is_inside_tree():
		var jt = jaw.create_tween()
		jt.tween_property(jaw, "rotation:x", -0.6, 0.07)
		jt.tween_property(jaw, "rotation:x", 0.0, 0.16).set_delay(0.05)
	var mouth = head.global_position + dd * 1.2
	DL.grit(js, mouth, 10, mud, {"dir": dd, "spread": 22.0, "vmin": 4.0, "vmax": 9.0, "g": 14.0, "r": 0.25, "life": 0.5, "size": 0.05})
	# mermi (eski motor mermisiyle birebir oynanış: yarıçap, ömür, hız, bilgi, yerçekimi)
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = dd * 26.0
	pr.radius = maxf(0.25, 0.9 * 0.6)
	pr.life = 2.6
	pr.info = js._inf(c, "doton_doryudan", 0.35)
	var ball = DL.mud_blob(0.5, mud, 0.03)
	pr.add_child(ball)
	_drips(pr, 14, DL.chunk_mesh(3, 2, 0.08), DL.mud_mat(0.0), {"r": 0.3, "life": 0.5, "vmin": 0.2, "vmax": 0.8})
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		_mud_splat(js, pos, mud)
	js.get_tree().current_scene.add_child(pr)
	pr.global_position = head.global_position + dd * 1.5
	pr.gravity = 4.0


static func doryudan(js, c: Node3D, t: Node3D) -> void:
	var fd: Vector3 = js._aim_flat(c, t)
	var side = fd.cross(Vector3.UP)
	var base: Vector3 = js._ground(c.global_position - fd * 1.0 + side * 2.4)
	var mud = Color(0.42, 0.3, 0.19)
	var pl = DL.pal(base)
	var head = Node3D.new()
	js.get_tree().current_scene.add_child(head)
	head.global_position = base - Vector3.UP * 3.0
	var jaw = _dragon_head(head, mud)
	# boyun: kafaya göre her karede eğri boyunca dizilen çamur halkaları
	var rig = Node3D.new()
	js.get_tree().current_scene.add_child(rig)
	var segs = []
	var n = 12
	for i in n:
		var u = float(i) / float(n - 1)
		var seg = DL.mud_blob(1.0, mud.darkened(0.06 * (1.0 - u)))
		rig.add_child(seg)
		var r = lerpf(1.25, 0.85, u)
		seg.scale = Vector3(r, r * 0.9, r * 1.25)
		if i % 2 == 1:
			var sp = DL.gi(DL.chunk_mesh(1, i % 6), DL.mud_mat(0.02))
			sp.set_instance_shader_parameter("mcol", DL.v3(mud.darkened(0.25)))
			seg.add_child(sp)
			sp.position = Vector3(0, 0.75, 0.1)
			sp.rotation = Vector3(0.7, 0, 0)
			sp.scale = Vector3.ONE * 0.32
		if i % 4 == 2:
			_drips(seg, 8, DL.chunk_mesh(3, 3, 0.07), DL.mud_mat(0.0), {"r": 0.7, "life": 0.7})
		segs.append(seg)
	var hw = weakref(head)
	var upd = func(_k: float) -> void:
		var h = hw.get_ref()
		if h == null or not is_instance_valid(h):
			for s in segs:
				if is_instance_valid(s):
					s.visible = false
			return
		var hp: Vector3 = h.global_position
		var back: Vector3 = h.global_basis.z.normalized()
		var p0 = base - Vector3.UP * 2.0
		var p1 = base + Vector3.UP * 2.6
		var p2 = hp + back * 1.8 - Vector3.UP * 1.0
		var p3 = hp + back * 0.9
		var cam = _cam(rig)
		var cp = cam.global_position if cam else Vector3(1e9, 1e9, 1e9)
		var fy = base.y - 0.6
		for i in segs.size():
			var seg: Node3D = segs[i]
			var u = float(i) / float(segs.size() - 1)
			var p = p0.bezier_interpolate(p1, p2, p3, u)
			var pn = p0.bezier_interpolate(p1, p2, p3, minf(u + 0.04, 1.0))
			seg.global_position = p
			var tn = pn - p
			if u < 0.99 and tn.length() > 0.001:
				var f = tn.normalized()
				var r = lerpf(1.25, 0.85, u)
				seg.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT) * Basis.from_scale(Vector3(r, r * 0.9, r * 1.25))
			seg.visible = p.y > fy and cp.distance_to(p) > 2.5
	var rt = rig.create_tween()
	rt.tween_method(upd, 0.0, 1.0, 3.2)
	rt.tween_callback(rig.queue_free)
	# zemin: yarılan çukur, çamur gölü, fırlayan topaklar, az toz
	_zone(base, 6.0)
	DL.pit(js, base, 2.4, 3.2)
	DL.puddle(js, base, 2.8, 3.4)
	DL.crack(js, base, 4.0, 3.6)
	DL.burst_chunks(js, base, 8, 0.3, 7.0, pl["body"], 1.2)
	DL.grit(js, base + Vector3.UP * 0.2, 24, pl["body"], {"spread": 55.0, "vmin": 5.0, "vmax": 11.0, "r": 1.0, "life": 1.0, "size": 0.06})
	DL.dust_ring(js, base, 1.2, 3.2, 5, 1.6, 0.9, pl["dust"])
	Sfx.play("earth", base)
	var top = base + Vector3.UP * 4.2 + fd * 1.2
	var tw = head.create_tween()
	tw.tween_method(func(k: float):
		var p = (base - Vector3.UP * 3.0).lerp(top, k) + fd.cross(Vector3.UP) * sin(k * PI) * 0.8
		head.global_position = p
		var aim = (t.global_position if t and is_instance_valid(t) else c.global_position + fd * 15.0) - p
		if aim.length() > 0.1:
			head.look_at(p + aim, Vector3.UP), 0.0, 1.0, 0.7).set_ease(Tween.EASE_OUT)
	for i in 5:
		tw.tween_callback(func():
			var aimp = (t.global_position + Vector3.UP if t and is_instance_valid(t) else c.global_position + fd * 18.0)
			var dd = (aimp - head.global_position).normalized()
			_spit(js, c, head, jaw, dd, mud))
		tw.tween_interval(0.25)
	tw.tween_property(head, "global_position:y", base.y - 5.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(head.queue_free)


# ================================================================== 4) Doryū Taiga (Toprak Akış Nehri)
## Referans: zemin sıvılaşıp koyu kahve, kabarık çamur nehrine döner; kenarlardan çamur sıçrar. Kişinin önünden başlayan geniş,
## hacimli (kabarık kesitli) çamur seli ileri akar; önünde yuvarlanan çamur topakları ve sürüklenen kayalardan bir kabarık cephe
## var, iki yakadan çamur fırlar; geçtiği yerde zemin yarılır. Sonra sel kuruyup kırılarak söner.
static func _river(pj: PathJutsu, from: Vector3, d: Vector3) -> void:
	var side = DL.side_of(d)
	var pts = PackedVector3Array()
	var ws = PackedFloat32Array()
	var hs = PackedFloat32Array()
	var L = 23.0
	var steps = 30
	for i in steps + 1:
		var u = float(i) / float(steps)
		var p = from + d * (1.2 + u * L) + side * sin(u * 5.0) * 0.35
		pts.append(DL.floor_at(p))
		ws.append(lerpf(3.4, 4.8, u) * (0.92 + 0.12 * sin(u * 17.0)))
		hs.append(lerpf(0.4, 0.62, u) * (0.85 + 0.2 * sin(u * 23.0 + 1.0)))
	var mi = DL.gi(DL.strip_mesh(pts, ws, side, 0.05, hs), DL.flow_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("base", Vector3(0.44, 0.31, 0.19))
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	DL.put(pj, mi, Vector3.ZERO)
	var tw = mi.create_tween()
	tw.tween_method(DL.pf(mi, "head"), 0.0, L + 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_method(DL.pf(mi, "fade"), 0.0, 1.05, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	# cephe: yuvarlanan çamur topakları + sürüklenen kayalar
	var front = Node3D.new()
	DL.put(pj, front, pts[0])
	var pl = DL.pal(from)
	for i in 7:
		var b: MeshInstance3D
		if i < 5:
			b = DL.mud_blob(randf_range(0.45, 0.75), Color(0.42, 0.3, 0.19).darkened(randf_range(0.0, 0.15)))
		else:
			b = DL.chunk(randf_range(0.3, 0.45), 0, pl["stone"], {"ow": 0.025})
		front.add_child(b)
		b.position = side * lerpf(-1.5, 1.5, float(i % 5) / 4.0) + Vector3.UP * randf_range(0.2, 0.55) - d * (0.0 if i < 5 else 0.9)
		var rt = b.create_tween().set_loops(3)
		rt.tween_property(b, "rotation", side * PI, 0.45).as_relative()
	var fw = weakref(front)
	var ft = front.create_tween()
	ft.tween_method(func(u: float) -> void:
		var x = fw.get_ref()
		if x == null or not is_instance_valid(x):
			return
		var idx = clampi(int(u * steps), 0, steps)
		x.global_position = pts[idx] + Vector3.UP * hs[idx] * 0.4, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ft.tween_property(front, "scale", Vector3(1.0, 0.1, 1.0), 0.4)
	ft.tween_callback(front.queue_free)


static func _bank_splash(pj: PathJutsu, q: Vector3, d: Vector3) -> void:
	var side = DL.side_of(d)
	var mud = Color(0.42, 0.3, 0.19)
	for s in [-1.0, 1.0]:
		var b = DL.mud_blob(randf_range(0.14, 0.24), mud, 0.02)
		DL.toss(pj, b, q + side * s * 1.9 + Vector3.UP * 0.4, side * s * randf_range(2.0, 3.5) + d * 2.0 + Vector3.UP * randf_range(2.5, 4.0), 0.8, 18.0, 0.5)
	DL.grit(pj, q + Vector3.UP * 0.4, 8, mud, {"dir": (d + Vector3.UP).normalized(), "spread": 50.0, "vmin": 2.0, "vmax": 5.0, "r": 1.2, "life": 0.6, "size": 0.05})


static func doryu_taiga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.anim(c, "crouch", 1.3)
	var d = pj.fwd(c, t)
	var fl = DL.flat(d)
	_river(pj, c.global_position, fl)
	DL.ripple(pj, c.global_position + fl * 1.2, 3.0, 0.8)
	pj.every(1.6, 0.2, func(_i, k):
		var q = pj.gp(c.global_position + d * (3.0 + k * 18.0))
		_zone(q, 2.0, 6.0)
		if k < 0.95:
			_bank_splash(pj, q, fl)
		for e in pj.hit(c, q + Vector3.UP * 0.5, 3.0, pj.inf(c, "doton_doryu_taiga", 0.25, {"knock": 10.0, "kind": "light", "element": "doton", "dir": d})):
			pj.st(e, "slow", 3.0), Callable())
	pj.shake(0.5)
	Sfx.play("earth", c.global_position, 0.6)


# ================================================================== 5) Dotō Kōka no Jutsu (Sertleşme)
## Referans: beden açık gri-mavi, köşeli taş plakalara döner (koyu yarık çizgileri, aydınlık pahlar), çevrede kabarık toz.
## Kaplama kişinin GERÇEK bedenine ayaktan başa doğru yayılır (kabuk yok); ayak dibinde zemin çatlar, yerden taş pulları
## sıçrayıp bedene yapışır, ayak çevresinde birkaç levha kalkıp iner, az toz. 12 sn sonra kaplama baştan ayağa geri çekilir.
static func koka_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	var pl = DL.pal(g)
	var tone = Color(0.66, 0.7, 0.75)
	_zone(g, 3.0)
	var m = DL.skin_mat(0, tone, 7.0)
	_skin_timed(c, m, "spread", -0.15, 2.4, 0.55, 12.0, 0.6)
	DL.crack(pj, g, 1.8, 3.0, 0.2, 0.0, 8.0)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:   # ayak çevresinde kalkan levhalar
		var a = TAU * (i + rng.randf_range(-0.2, 0.2)) / 6.0
		var out = Vector3(cos(a), 0, sin(a))
		var mesh = DL.prism_mesh(DL.jag_rect(0.42, 0.22, 1, 0.04, rng), -0.3, 0.32, 0.18, 0.05, rng.randi())
		var sl = DL.rock(mesh, tone.darkened(rng.randf_range(0.05, 0.2)), {"ow": 0.02})
		var p = DL.floor_at(g + out * 0.85)
		sl.basis = _basis_out(out).rotated(DL.side_of(out), -0.35)   # sahne kökünde yerel = küresel; rise kendisi ekler
		DL.rise(pj, sl, p, 0.6, 0.12, 0.9, 0.35, i * 0.03)
	for i in 7:   # yerden sıçrayıp bedene yapışan taş pulları
		var a = randf() * TAU
		var p0 = DL.floor_at(g + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 1.8)) + Vector3.UP * 0.05
		var fl = DL.chunk(randf_range(0.06, 0.1), 2, tone, {"ow": 0.012})
		DL.put(pj, fl, p0)
		var tgt = c.global_position + Vector3(cos(a) * 0.2, randf_range(0.3, 1.5), sin(a) * 0.2)
		var fw = weakref(fl)
		var tw = fl.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_method(func(u: float) -> void:
			var x = fw.get_ref()
			if x != null and is_instance_valid(x):
				x.global_position = p0.lerp(tgt, u) + Vector3.UP * sin(u * PI) * 0.6, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(fl.queue_free)
	DL.dust_ring(pj, g, 0.6, 2.2, 4, 1.3, 1.0, pl["dust"])
	# oynanış (klan işleyicisinden birebir)
	if c is Player:
		Buffs.add("koka", 12.0, {"armor": 0.68, "speed": 0.8})
		c.combat.set("poise_t", 12.0)
	_zone(c.global_position, 2.5)
	Sfx.play("earth", c.global_position, 1.0)


# ================================================================== 6) Ganchūsō (Kaya Sütun Mızrakları)
## Referans: koyu arduvaz gri, uzun sivri kaya mızrakları kümeler halinde fışkırır. Kişiden hedefe sıra sıra (her adımda bir ana
## mızrak + yanlara yatık iki küçük kardeş) gerçek boyutlu yüzlü ağlar yerden saplanır; dibinde çukur, yukarı fışkıran çakıl;
## isabette hedefte kırılan kıymıklar. Sonra mızraklar toprağa geri çekilir.
static func _spike_cluster(pj: PathJutsu, q: Vector3, h: float, d: Vector3, tone: Color, k: int) -> void:
	var side = DL.side_of(d)
	var specs = [[0.0, h, 0.36, 0.0]]
	for s in [-1.0, 1.0]:
		specs.append([s, h * randf_range(0.45, 0.62), 0.22, s])
	for sp in specs:
		var hh: float = sp[1]
		var mesh = DL.spike_mesh(snappedf(hh, 0.1), sp[2], 5, (k * 3 + int(sp[0] + 1.0)) % 9)
		var spike = DL.rock(mesh, tone.darkened(randf_range(0.0, 0.12)), {"ow": 0.03, "strata": 1.6})
		var p = q + side * float(sp[3]) * 0.55 - d * absf(float(sp[3])) * 0.2
		DL.put(pj, spike, p - Vector3.UP * hh * 1.05)
		var tilt = Vector3(deg_to_rad(randf_range(-15, 15)), randf() * TAU, deg_to_rad(randf_range(-15, 15)))
		if float(sp[3]) != 0.0:
			tilt = Vector3(0, randf() * TAU, 0)
		spike.rotation = tilt
		if float(sp[3]) != 0.0:
			spike.global_basis = Basis(d, deg_to_rad(28.0) * float(sp[3])) * spike.global_basis
		var tw = spike.create_tween()
		tw.tween_property(spike, "global_position", p, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.4)
		tw.tween_property(spike, "global_position", p - Vector3.UP * hh * 1.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(spike.queue_free)
	DL.pit(pj, q, 0.95, 1.9, 0.08)
	var pl = DL.pal(q)
	DL.grit(pj, q + Vector3.UP * 0.1, 10, pl["body"], {"spread": 35.0, "vmin": 4.0, "vmax": 9.0, "r": 0.4, "life": 0.7, "size": 0.05})
	DL.burst_chunks(pj, q, 3, 0.12, 4.5, pl["body"], 1.2, 2, 0.8)


static func ganchuso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var d = pj.fwd(c, tt)
	var dist = c.global_position.distance_to(tt.global_position) if tt else 14.0
	var tone = Color(0.4, 0.42, 0.47)
	for k in 10:
		pj.after(0.12 + k * 0.05, func():
			var q = pj.gp(c.global_position + d * (2.0 + (dist - 1.0) * k / 9.0) + d.cross(Vector3.UP) * randf_range(-0.6, 0.6))
			var h = 2.0 + k * 0.2
			_spike_cluster(pj, q, h, DL.flat(d), tone, k)
			_burst_zone(q, 0.6)
			var hs = pj.hit(c, q + Vector3.UP, 1.4, pj.inf(c, "doton_ganchuso", 0.35, {"knock": 4.0, "launch": 8.0, "kind": "heavy", "element": "doton", "bleed": 2.0}))
			for e in hs:
				if is_instance_valid(e):
					DL.burst_chunks(pj, e.global_position + Vector3.UP, 4, 0.07, 5.0, tone, 1.0, 1, 0.6))
	Sfx.play("earth", c.global_position, 0.9)


# ================================================================== 7) Doton Kage Bunshin (Toprak Klonu)
## Referans: kopya ıslak toprak / çamurdan bir beden; dağılırken çamur her yana sıçrar. Yerden kıvrımlı bir toprak sütunu
## (tepesi o zeminin örtüsü) insan boyunda kabarır, kendi ağırlığıyla yayvanlaşıp çöker; içinden kopya çıkar, bedenini kaplayan
## kuru toprak sıvası baştan ayağa süzülüp akar. Vurulunca kopya toprak yığınına çöker, çamur sıçrar (duman yok).
static func _soil_column(pj: PathJutsu, at: Vector3) -> void:
	var pl = DL.pal(at)
	var prof = _prof([Vector2(0.62, -0.1), Vector2(0.6, 0.3), Vector2(0.5, 1.2), Vector2(0.42, 1.75), Vector2(0.24, 2.0), Vector2(0.0, 2.08)])
	var mesh = DL.lathe_mesh(prof, 14, 5.0, 0.14, 0.03, randi() % 4)
	var col = DL.rock(mesh, pl["body"], {"ow": 0.03, "top": pl["top"], "top_y": 1.95, "strata": 3.5})
	DL.put(pj, col, at - Vector3.UP * 2.2)
	var tw = col.create_tween()
	tw.tween_property(col, "global_position", at, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.06)
	tw.set_parallel(true)
	tw.tween_property(col, "scale", Vector3(1.6, 0.06, 1.6), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		for i in 6:
			var a = randf() * TAU
			var ck = DL.chunk(randf_range(0.1, 0.18), 0, pl["body"], {"ow": 0.02})
			DL.toss(pj, ck, at + Vector3(cos(a) * 0.5, randf_range(0.8, 1.8), sin(a) * 0.5), Vector3(cos(a), 0.3, sin(a)) * randf_range(1.0, 2.5), 0.8)
		DL.grit(pj, at + Vector3.UP * 1.2, 16, pl["body"], {"dir": Vector3.DOWN, "spread": 80.0, "vmin": 0.5, "vmax": 2.0, "r": 0.6, "life": 0.8, "size": 0.05})).set_delay(0.0)
	tw.set_parallel(false)
	tw.tween_callback(col.queue_free)


static func _soil_heap(pj: PathJutsu, pos: Vector3) -> void:
	var g = DL.floor_at(pos)
	var pl = DL.pal(g)
	var prof = _prof([Vector2(0.95, -0.05), Vector2(0.75, 0.28), Vector2(0.4, 0.58), Vector2(0.0, 0.68)])
	var heap = DL.rock(DL.lathe_mesh(prof, 12, 4.0, 0.2, 0.05, randi() % 4), pl["body"].darkened(0.1), {"ow": 0.025, "strata": 4.0})
	DL.put(pj, heap, g)
	heap.scale = Vector3(0.55, 2.4, 0.55)
	var tw = heap.create_tween()
	tw.tween_property(heap, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.4)
	tw.tween_property(heap, "global_position", g - Vector3.UP * 0.75, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(heap.queue_free)
	var mud = pl["mud"]
	for i in 7:   # yanlara savrulan yassı çamur sıçrantıları (referans)
		var a = TAU * (i + randf_range(-0.3, 0.3)) / 7.0
		var b = DL.mud_blob(1.0, mud, 0.02)
		b.scale = Vector3(randf_range(0.18, 0.3), 0.08, randf_range(0.18, 0.3))
		DL.toss(pj, b, g + Vector3.UP * randf_range(0.6, 1.4), Vector3(cos(a) * randf_range(2.0, 4.0), randf_range(1.0, 2.5), sin(a) * randf_range(2.0, 4.0)), 1.0, 18.0, 1.0)
	DL.grit(pj, g + Vector3.UP * 0.8, 18, pl["body"], {"spread": 110.0, "vmin": 1.0, "vmax": 4.0, "r": 0.4, "life": 0.8, "size": 0.05})


static func kage_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 2.5)
	_burst_zone(at, 1.3)
	_soil_column(pj, at)
	DL.crack(pj, at, 1.3, 2.4, 0.15)
	var soil: Color = DL.pal(at)["body"]
	pj.after(0.3, func():
		if pj.live(c):
			var d = pj.decoy(c, at, 12.0, func(pos):
				_burst_zone(pos, 1.6)
				_soil_heap(pj, pos))
			if d:
				d.set("max_hp", 3.0)
				d.set_meta("no_smoke", true)   # toprak kopya toprağa çöker, duman yok
				var cm = d.get("model")
				if cm and is_instance_valid(cm) and (cm as Node).is_inside_tree():
					var m = DL.skin_mat(3, soil, 8.0)
					m.set_shader_parameter("drain", 2.3)
					var list = DL.skin_apply(cm, m)
					var tw = (cm as Node).create_tween()
					tw.tween_interval(0.15)
					tw.tween_property(m, "shader_parameter/drain", -0.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw.tween_callback(func(): DL.skin_clear(list, m))
					DL.grit(pj, at + Vector3.UP * 1.0, 14, soil, {"dir": Vector3.DOWN, "spread": 70.0, "vmin": 0.3, "vmax": 1.2, "r": 0.4, "life": 0.9, "size": 0.04}))
	Sfx.play("earth", at, 1.1)


# ================================================================== 8) Iwao Golem Ken (Golem Yumruğu)
## Sağ yumruk, katman şeritli kahve kayadan iri bir golem yumruğuna büyür (çekirdek blok + boğum sırası + başparmak); zeminden
## çakıllar ele akar. Atılıp vurunca: yumruğun önünde çökük krater, çevresinde halka halinde dışa yatık kalkan levhalar, ışınsal
## yarık, savrulan kaya, yer dalgası, az toz.
static func _golem_fist(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var tone: Color = pl["stone"].lerp(Color(0.5, 0.42, 0.33), 0.55)
	var core = DL.rock(DL.chunk_mesh(2, 1, 0.16), tone, {"ow": 0.01, "strata": 14.0})
	core.position = Vector3(0, 0.12, 0)
	root.add_child(core)
	for i in 4:
		var kn = DL.rock(DL.chunk_mesh(2, i + 2, 0.06), tone.darkened(randf_range(0.04, 0.16)), {"ow": 0.008})
		kn.position = Vector3(-0.1 + i * 0.066, 0.24, 0.05)
		kn.rotation = Vector3(randf() * 0.5, randf() * TAU, randf() * 0.5)
		root.add_child(kn)
	var th = DL.rock(DL.chunk_mesh(2, 5, 0.07), tone.darkened(0.1), {"ow": 0.008})
	th.position = Vector3(0.13, 0.12, 0.08)
	root.add_child(th)
	return root


static func _golem_impact(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var g = DL.floor_at(at)
	var pl = DL.pal(g)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	DL.pit(pj, g, 2.2, 2.6, 0.12)
	DL.crack(pj, g, 4.5, 3.4, 0.18, 0.0, 10.0)
	DL.ripple(pj, g, 5.0, 0.8)
	for i in 8:
		var a = TAU * (i + rng.randf_range(-0.2, 0.2)) / 8.0
		var out = Vector3(cos(a), 0, sin(a))
		var mesh = DL.prism_mesh(DL.jag_rect(1.1, 0.8, 2, 0.08, rng), -0.18, 0.18, 0.2, 0.05, rng.randi())
		var sl = DL.rock(mesh, pl["body"].darkened(rng.randf_range(0.0, 0.12)), {"ow": 0.03, "top": pl["top"], "top_y": 0.15, "strata": 3.0})
		var p = DL.floor_at(g + out * 2.0) + Vector3.UP * 0.15
		sl.basis = _basis_out(out).rotated(DL.side_of(out), deg_to_rad(rng.randf_range(30.0, 48.0)))
		DL.rise(pj, sl, p, 0.7, 0.1, 1.1, 0.5)
	DL.burst_chunks(pj, g, 12, 0.28, 8.0, pl["body"], 1.0)
	DL.grit(pj, g + Vector3.UP * 0.2, 28, pl["body"], {"dir": (Vector3.UP + d * 0.5).normalized(), "spread": 70.0, "vmin": 4.0, "vmax": 10.0, "r": 1.0, "life": 0.9, "size": 0.06})
	DL.dust_ring(pj, g, 1.5, 4.0, 6, 2.0, 1.1, pl["dust"])


static func iwao_golem_ken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 8.0)
	var pl = DL.pal(c.global_position)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var fist = _golem_fist(pl)
		_bone_root(ba).add_child(fist)
		fist.position = Vector3(0, 0.1, 0)
		fist.scale = Vector3.ONE * 0.1
		var tw = fist.create_tween()
		tw.tween_property(fist, "scale", Vector3.ONE * 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var hp = pj.hand_pos(c, true)
		for i in 5:
			var a = randf() * TAU
			var p0 = DL.floor_at(c.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 1.5)) + Vector3.UP * 0.05
			var pb = DL.chunk(randf_range(0.05, 0.09), 0, pl["body"], {"ow": 0.01})
			DL.put(pj, pb, p0)
			var pw = weakref(pb)
			var pt = pb.create_tween()
			pt.tween_method(func(u: float) -> void:
				var x = pw.get_ref()
				if x != null and is_instance_valid(x):
					x.global_position = p0.lerp(hp, u) + Vector3.UP * sin(u * PI) * 0.4, 0.0, 1.0, 0.2 + i * 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			pt.tween_callback(pb.queue_free)
		pj.free_after(0.8, ba)
	var d = pj._jump_at(c, tt, 0.6, 8.0)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP * 0.8 + d * 1.4
		_golem_impact(pj, at, d)
		_zone(pj.gp(at), 8.0)
		pj.hit(c, at, 3.0, pj.inf(c, "iwao_golem_ken", 2.4, {"knock": 20.0, "launch": 6.0, "kind": "heavy", "element": "doton", "hitstop": 0.12}))
		pj.shake(0.9))
	Sfx.play("earth", c.global_position, 0.6)


# ================================================================== 9) Doton Chiwari (Toprak Yarığı)
## Referans: zemin bir çizgi boyunca yarılır, iki yakadaki büyük kaya levhalar yarığa doğru kalkıp eğilir, aralarından toz
## kabarır, küçük bloklar fırlar. Kişinin önünden 12 m'lik koyu, derin, girintili bir yarık açılır; her adımda iki yanda üstü
## çimenli kalın levhalar iç kenarları kalkarak yatar; az toz yalnız uzak tarafta. Sonra levhalar oturur, yarık kapanır.
static func _rift(pj: PathJutsu, from: Vector3, d: Vector3) -> void:
	var side = DL.side_of(d)
	var pts = PackedVector3Array()
	var ws = PackedFloat32Array()
	var steps = 26
	var ph = randf() * TAU
	for i in steps + 1:
		var u = float(i) / float(steps)
		pts.append(DL.floor_at(from + d * (1.2 + u * 12.4) + side * sin(u * 6.0 + ph) * 0.25))
		ws.append(2.6)
	var mi = DL.gi(DL.strip_mesh(pts, ws, side, 0.06), DL.rift_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("soil", DL.v3(DL.pal(from)["body"]))
	mi.set_instance_shader_parameter("open", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	DL.put(pj, mi, Vector3.ZERO)
	var tw = mi.create_tween()
	tw.tween_method(DL.pf(mi, "open"), 0.0, 13.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_method(DL.pf(mi, "fade"), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func _heave(pj: PathJutsu, q: Vector3, d: Vector3) -> void:
	var pl = DL.pal(q)
	var side = DL.side_of(d)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for s in [-1.0, 1.0]:
		var mesh = DL.prism_mesh(DL.jag_rect(1.9, 1.15, 2, 0.08, rng), -0.28, 0.24, 0.16, 0.05, rng.randi())
		var sl = DL.rock(mesh, pl["body"].darkened(rng.randf_range(0.0, 0.1)), {"ow": 0.035, "top": pl["top"], "top_y": 0.2, "strata": 3.0, "shadow": true})
		var cen = DL.floor_at(q + side * s * 1.05)
		DL.put(pj, sl, cen - Vector3.UP * 0.5)
		var b0 = Basis(d * s, Vector3.UP, side * s)
		var ang = deg_to_rad(rng.randf_range(24.0, 40.0))
		var sw = weakref(sl)
		var set_t = func(k: float) -> void:
			var x = sw.get_ref()
			if x != null and is_instance_valid(x):
				x.global_basis = b0.rotated((d * s).normalized(), ang * k)
				x.global_position = cen + Vector3.UP * (0.32 * k - 0.5 * (1.0 - k))
		set_t.call(0.0)
		var tw = sl.create_tween()
		tw.tween_method(set_t, 0.0, 1.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.9)
		tw.tween_method(set_t, 1.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(sl.queue_free)
		var ck = DL.chunk(rng.randf_range(0.12, 0.2), 2, pl["body"], {"ow": 0.025})
		DL.toss(pj, ck, cen + Vector3.UP * 0.3, side * s * rng.randf_range(1.0, 2.5) + Vector3.UP * rng.randf_range(3.0, 5.0), 1.0)
	DL.grit(pj, q + Vector3.UP * 0.1, 12, pl["body"], {"spread": 30.0, "vmin": 3.0, "vmax": 7.0, "r": 0.5, "life": 0.8, "size": 0.05})
	DL.dust(pj, q + Vector3.UP * 0.7 + side * randf_range(-0.4, 0.4), 1.6, 1.1, Vector3.UP * 0.8, pl["dust"])


static func chiwari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		_rift(pj, c.global_position, DL.flat(d))
		for k in 6:
			var q = pj.gp(c.global_position + d * (2.0 + k * 2.0))
			pj.after(k * 0.05, func():
				_zone(q, 3.0, 5.0)
				_heave(pj, q, DL.flat(d))
				for e in pj.enemies_near(c, q, 2.0):
					if pj.live(e) and e.has_method("apply_status"):
						e.apply_status("bind", 1.5)
						pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "doton_chiwari", 0.5, {"knock": 0.0, "kind": "heavy", "element": "doton"})))
		pj.shake(0.7))
	Sfx.play("earth", c.global_position, 0.7)


# ================================================================== 10) Doton Dohā (Toprak Dalgası)
## Zemin bir su dalgası gibi kıvrılır: kişinin önünden 6 m genişlikte, sırtı çimenli, ön yüzü kıvrık dudaklı bir toprak dalgası
## yükselip 18 m ileri yuvarlanır; tepesinden öne çamur topakları savrulur, geçtiği yer dalgalanır ve çamur bölgesi kalır; sonunda
## dalga kendi üstüne çöküp topaklara dağılır.
static func _wave_mesh(w: float, sd: int) -> ArrayMesh:
	var key = "wave_%.1f_%d" % [w, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	# profil (z ileri, y yukarı): arka yamaç → tepe → öne sarkan dudak → kıvrımın altı → ön yüz
	var prof = [Vector2(-2.6, -0.3), Vector2(-1.7, 0.5), Vector2(-0.9, 1.25), Vector2(-0.25, 1.85), Vector2(0.35, 2.05),
		Vector2(0.85, 1.8), Vector2(1.0, 1.4), Vector2(0.75, 1.08), Vector2(0.45, 1.0), Vector2(0.55, 0.55), Vector2(0.85, 0.05), Vector2(1.05, -0.3)]
	var np = prof.size()
	var nx = 13
	var v = PackedVector3Array()
	for i in nx:
		var u = float(i) / float(nx - 1)
		var x = (u - 0.5) * w
		var hf = maxf(0.06, pow(maxf(0.0, 1.0 - pow(2.0 * u - 1.0, 2.0)), 0.45)) * rng.randf_range(0.88, 1.08)
		for j in np:
			var p: Vector2 = prof[j]
			var jy = rng.randf_range(-0.05, 0.05) if j > 0 and j < np - 1 else 0.0
			v.append(Vector3(x + rng.randf_range(-0.06, 0.06), p.y * hf + jy, p.x * lerpf(0.55, 1.0, hf)))
	var tris = PackedInt32Array()
	var wants = []
	for i in nx - 1:
		for j in np - 1:
			var a = i * np + j
			var b = i * np + j + 1
			var cc = (i + 1) * np + j + 1
			var dd = (i + 1) * np + j
			var tz = prof[j + 1].x - prof[j].x
			var ty = prof[j + 1].y - prof[j].y
			var wv = Vector3(0, tz, -ty)
			tris.append_array([a, b, cc, a, cc, dd])
			wants.append(wv)
			wants.append(wv)
	var ti = {"k": 0}
	var m = DL.facet(v, tris, func(_cp: Vector3) -> Vector3:
		var wv: Vector3 = wants[ti["k"]]
		ti["k"] += 1
		return wv)
	_cache[key] = m
	return m


static func _earth_wave(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var pl = DL.pal(c.global_position)
	var wave = DL.rock(_wave_mesh(6.0, randi() % 3), pl["body"], {"ow": 0.04, "top": pl["top"], "top_y": 1.45, "strata": 2.4, "shadow": true})
	var p0 = c.global_position
	DL.put(pj, wave, pj.gp(p0 + d * 2.0) - Vector3.UP * 0.2)
	var side = DL.side_of(d)
	wave.global_basis = Basis(-side, Vector3.UP, d)
	wave.scale = Vector3(1.0, 0.15, 1.0)
	var ww = weakref(wave)
	var tw = wave.create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float) -> void:
		var x = ww.get_ref()
		if x != null and is_instance_valid(x):
			x.global_position = DL.floor_at(p0 + d * (2.0 + k * 18.0)) - Vector3.UP * 0.2, 0.0, 1.0, 1.0)
	tw.set_parallel(false)
	tw.tween_callback(func():
		var x = ww.get_ref()
		if x == null or not is_instance_valid(x):
			return
		var g = DL.floor_at(x.global_position)
		for i in 9:
			var b = DL.chunk(randf_range(0.15, 0.3), 0, pl["body"].darkened(randf_range(0.0, 0.15)), {"ow": 0.025})
			DL.toss(pj, b, g + side * randf_range(-2.6, 2.6) + Vector3.UP * randf_range(0.8, 1.8), d * randf_range(2.0, 5.0) + Vector3.UP * randf_range(1.0, 3.0), 1.0)
		DL.dust_ring(pj, g + d * 0.6, 1.0, 3.0, 4, 1.6, 1.0, pl["dust"]))
	tw.tween_property(wave, "scale", Vector3(1.15, 0.05, 1.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(wave.queue_free)


static func doha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var mud = Color(0.38, 0.28, 0.18)
	_earth_wave(pj, c, DL.flat(d))
	pj.every(1.0, 0.07, func(i, k):
		var q = pj.gp(c.global_position + d * (2.0 + k * 18.0))
		var side = d.cross(Vector3.UP).normalized()
		if i % 2 == 0:
			var b = DL.mud_blob(randf_range(0.14, 0.24), mud, 0.02)
			DL.toss(pj, b, q + d * 0.8 + side * randf_range(-2.2, 2.2) + Vector3.UP * 2.0, d * randf_range(4.0, 7.0) + Vector3.UP * randf_range(1.5, 3.0), 0.8, 18.0, 0.5)
		if i % 3 == 0:
			GroundFX.add(q, "mud", 2.4, 4.0, c)
			DL.ripple(pj, q - d * 1.0, 2.8, 1.1)
		for e in pj.enemies_near(c, q, 2.8):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "doton_doha", 0.2, {"knock": 8.0, "kind": "light", "element": "doton", "dir": d})), Callable())
	Sfx.play("earth", c.global_position, 0.8)


# ================================================================== 11) Doton Gansetsukon (Kaya Eklem Sopası)
## Elde boğum boğum taş omurlardan (aralarında yuvarlak eklem topuzları) ve sivri uçtan bir sopa sırayla örülür; iki savuruşta
## sopanın yayı boyunca kırık taş kıymıkları teğet savrulur, isabette hedefte kıymık patlar; sonra sopa elde ufalanır.
static func _joint_club(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var tone: Color = pl["stone"].lerp(Color(0.52, 0.42, 0.32), 0.6)
	for k in 5:
		var seg = DL.rock(DL.chunk_mesh(2, k, 0.2), tone.darkened(k * 0.04), {"ow": 0.012, "strata": 10.0})
		root.add_child(seg)
		seg.position = Vector3(0, 0.25 + k * 0.45, 0)
		seg.rotation = Vector3(randf_range(-0.1, 0.1), k * 0.5, randf_range(-0.1, 0.1))
		seg.set_meta("full", Vector3(1.0 - k * 0.08, 2.1, 1.0 - k * 0.08))
		seg.scale = Vector3.ONE * 0.01
		if k < 4:
			var jt = DL.rock(DL.chunk_mesh(0, k, 0.085), tone.darkened(0.2), {"ow": 0.01})
			root.add_child(jt)
			jt.position = Vector3(0, 0.47 + k * 0.45, 0)
			jt.set_meta("full", Vector3.ONE)
			jt.scale = Vector3.ONE * 0.01
	var tip = DL.rock(DL.spike_mesh(0.55, 0.13, 5, 3), tone.lightened(0.05), {"ow": 0.012})
	root.add_child(tip)
	tip.position = Vector3(0, 2.38, 0)
	tip.set_meta("full", Vector3.ONE)
	tip.scale = Vector3.ONE * 0.01
	return root


static func _club_sweep(pj: PathJutsu, c: Node3D, at: Vector3, k: int, tone: Color) -> void:
	var f = DL.flat(c.face_dir())
	var side = DL.side_of(f)
	var dirs = 1.0 if k == 0 else -1.0
	for i in 7:
		var u = (float(i) / 6.0 - 0.5) * 2.0 * dirs
		var a = u * 1.05
		var rad = f * cos(a) + side * sin(a)
		var tang = (side * cos(a) - f * sin(a)) * -dirs
		var p = c.global_position + Vector3.UP * 1.1 + rad * randf_range(1.5, 2.1)
		var sh = DL.chunk(randf_range(0.05, 0.09), 1, tone, {"ow": 0.012})
		DL.toss(pj, sh, p, tang * randf_range(4.0, 7.0) + rad * 2.0 + Vector3.UP * randf_range(1.0, 2.5), 0.7, 18.0, 0.4)
	DL.grit(pj, at, 12, tone, {"dir": (f + Vector3.UP * 0.2).normalized(), "spread": 60.0, "vmin": 2.0, "vmax": 5.0, "r": 0.5, "life": 0.6, "size": 0.04})


static func gansetsukon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var _tt = pj.tg(c, t, 6.0)
	pj.busy(c, 0.8)
	var pl = DL.pal(c.global_position)
	var tone: Color = pl["stone"].lerp(Color(0.52, 0.42, 0.32), 0.6)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var club = _joint_club(pl)
		_bone_root(ba).add_child(club)
		club.rotation_degrees = Vector3(-90, 0, 0)
		var i = 0
		for part in club.get_children():
			var full: Vector3 = part.get_meta("full", Vector3.ONE)
			part.create_tween().tween_property(part, "scale", full, 0.08).set_delay(0.02 + i * 0.022).set_trans(Tween.TRANS_BACK)
			i += 1
		var bw = weakref(ba)
		pj.after(0.76, func():
			var x = bw.get_ref()
			if x != null and is_instance_valid(x) and x.is_inside_tree():
				for part in club.get_children():
					if randf() < 0.6:
						var ck = DL.chunk(randf_range(0.05, 0.09), 2, tone, {"ow": 0.01})
						DL.toss(pj, ck, (part as Node3D).global_position, Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5)), 0.7, 18.0, 0.4))
		pj.free_after(0.8, ba)
	for k in 2:
		pj.after(0.2 + k * 0.25, func():
			if not pj.live(c):
				return
			pj.anim(c, "slash_a" if k == 0 else "slash_b", 1.6)
			var at = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 2.2
			_club_sweep(pj, c, at, k, tone)
			var hs = pj.hit(c, at, 2.4, pj.inf(c, "doton_gansetsukon", 0.9, {"knock": 8.0, "kind": "heavy", "element": "doton"}))
			for e in hs:
				if is_instance_valid(e):
					DL.burst_chunks(pj, e.global_position + Vector3.UP * 1.1, 5, 0.07, 4.5, tone, 0.8, 1, 0.6))
	Sfx.play("earth", c.global_position, 1.2)


# ================================================================== 12) Doton Dochū Baku (Yeraltı Patlaması)
## Referans: yerden dev bir toprak fıskiyesi yukarı yelpaze gibi fışkırır, içinde çakıllar. Önce hedefin altında zemin kabarıp
## titrer, dalgalanır, çakıllar hoplar; sonra yassı, sivri toprak dilleri yelpaze halinde 6-8 m yukarı fırlar, tepeden topaklar
## dört yana yağar, dibinde krater ve yarık kalır, az toz.
static func _rumble(pj: PathJutsu, at: Vector3) -> Node3D:
	var pl = DL.pal(at)
	DL.ripple(pj, at, 2.6, 0.6)
	var prof = _prof([Vector2(1.5, -0.1), Vector2(1.1, 0.2), Vector2(0.55, 0.38), Vector2(0.0, 0.44)])
	var mound = DL.rock(DL.lathe_mesh(prof, 12, 3.0, 0.12, 0.03, randi() % 4), pl["body"], {"ow": 0.025, "top": pl["top"], "top_y": 0.1, "strata": 4.0})
	DL.put(pj, mound, at - Vector3.UP * 0.45)
	var mw = weakref(mound)
	var tw = mound.create_tween()
	tw.tween_method(func(u: float) -> void:
		var x = mw.get_ref()
		if x != null and is_instance_valid(x):
			x.global_position = at + Vector3(randf_range(-0.05, 0.05), -0.45 * (1.0 - u), randf_range(-0.05, 0.05)), 0.0, 1.0, 0.5)
	return mound


static func _geyser(pj: PathJutsu, at: Vector3) -> void:
	var pl = DL.pal(at)
	var tone: Color = pl["body"].lightened(0.05)
	for i in 7:
		var a = TAU * (i + randf_range(-0.2, 0.2)) / 7.0
		var out = Vector3(cos(a), 0, sin(a))
		var h = randf_range(5.5, 7.5)
		var fin = DL.rock(DL.spike_mesh(snappedf(h, 0.5), 0.9, 4, i % 5), tone.darkened(randf_range(0.0, 0.14)), {"ow": 0.035, "strata": 1.4})
		var p = at + out * 0.5
		DL.put(pj, fin, p - Vector3.UP * h)
		var fb = _basis_out(out)
		fin.global_basis = Basis(fb.x, fb.y, fb.z * 0.32).rotated(DL.side_of(out), -deg_to_rad(randf_range(8.0, 32.0)))   # yassı dil
		var tw = fin.create_tween()
		tw.tween_interval(i * 0.02)
		tw.tween_property(fin, "global_position", p, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(fin, "global_position", p - Vector3.UP * h * 1.05, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(fin.queue_free)
	pj.after(0.45, func():   # tepeden yağan topaklar
		for i in 14:
			var a = randf() * TAU
			var ck = DL.chunk(randf_range(0.14, 0.3), randi() % 3, tone.darkened(randf_range(0.0, 0.2)), {"ow": 0.025})
			DL.toss(pj, ck, at + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.5) + Vector3.UP * randf_range(3.0, 7.0), Vector3(cos(a), 0.0, sin(a)) * randf_range(1.5, 4.0) + Vector3.UP * randf_range(0.0, 2.0), 1.4))
	DL.burst_chunks(pj, at, 10, 0.3, 12.0, tone, 2.0, -1, 1.4)
	DL.grit(pj, at + Vector3.UP * 0.3, 36, tone, {"spread": 22.0, "vmin": 8.0, "vmax": 16.0, "r": 0.9, "life": 1.3, "size": 0.07})
	DL.pit(pj, at, 2.2, 3.5, 0.15)
	DL.crack(pj, at, 3.6, 3.8, 0.2)
	DL.dust_ring(pj, at, 1.4, 3.6, 6, 1.8, 1.1, pl["dust"])


static func dochubaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var body: Color = DL.pal(at)["body"]
	var mound = _rumble(pj, at)
	var mw = weakref(mound)
	var hop = func(_i, _k):
		DL.grit(pj, at + Vector3.UP * 0.2, 3, body, {"spread": 60.0, "vmin": 1.5, "vmax": 3.0, "r": 1.2, "life": 0.5, "size": 0.05})
	var erupt = func():
		var x = mw.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free()
		_geyser(pj, at)
		_zone(at, 5.0)
		pj.hit(c, at + Vector3.UP, 3.5, pj.inf(c, "doton_dochubaku", 1.5, {"knock": 4.0, "launch": 12.0, "kind": "heavy", "element": "doton"}))
		pj.shake(0.8)
	pj.every(0.5, 0.08, hop, erupt)
	Sfx.play("earth", at, 0.8)


# ================================================================== 13) Doton Chidōkaku (Toprak Hareket Çekirdeği)
## Kişinin altındaki zemin katman şeritli, tepesi çimenli kalın bir kaya sütun (mesa) olarak fırlar, onu sıçrama yayı boyunca taşır;
## tabanında halka halinde dışa yatık kıymıklar kalkar, zemin ışınsal yarılır, kaya savrulur; yükselirken sütun kenarından
## parçalar düşer; sonra sütun toprağa geri çekilir.
static func _mesa(pj: PathJutsu, at: Vector3) -> void:
	var pl = DL.pal(at)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var ol = DL.jag_circle(1.5, 9, 0.16, rng)
	var mesh = DL.prism_mesh(ol, -5.5, 0.0, 0.03, 0.12, rng.randi())
	var mesa = DL.rock(mesh, pl["body"].lerp(pl["stone"], 0.3), {"ow": 0.045, "top": pl["top"], "top_y": 0.0, "strata": 1.6, "shadow": true})
	DL.put(pj, mesa, at)
	mesa.rotation.y = rng.randf() * TAU
	# sütunun tepesi kişinin sıçrama yayını ayağının altında izler (18 m/sn, yerçekimi 36: tepe ~4.5 m, 0.5 sn): kişi sütunun
	# içine gömülmez; inişte sütun da onunla toprağa çekilir (çarpışması yok, eskisi gibi)
	var mw = weakref(mesa)
	var tw = mesa.create_tween()
	tw.tween_method(func(tm: float) -> void:
		var x = mw.get_ref()
		if x != null and is_instance_valid(x):
			x.global_position = at + Vector3.UP * (maxf(18.0 * tm - 18.0 * tm * tm, 0.0) - 0.15), 0.0, 0.5, 0.5)
	tw.tween_callback(func():   # tepe kenarından düşen parçalar
		for i in 6:
			var a = rng.randf() * TAU
			var ck = DL.chunk(rng.randf_range(0.15, 0.3), 2, pl["body"].darkened(rng.randf_range(0.0, 0.15)), {"ow": 0.025})
			DL.toss(pj, ck, at + Vector3(cos(a), 0, sin(a)) * 1.6 + Vector3.UP * rng.randf_range(2.5, 4.3), Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 2.5), 1.4))
	tw.tween_interval(0.12)
	tw.tween_method(func(tm: float) -> void:
		var x = mw.get_ref()
		if x != null and is_instance_valid(x):
			x.global_position = at + Vector3.UP * (maxf(18.0 * tm - 18.0 * tm * tm, 0.0) - 0.15 - (tm - 0.5) * 1.2), 0.5, 1.05, 0.55)
	tw.tween_property(mesa, "global_position", at - Vector3.UP * 0.6, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mesa.queue_free)
	for i in 10:
		var a = TAU * (i + rng.randf_range(-0.25, 0.25)) / 10.0
		var out = Vector3(cos(a), 0, sin(a))
		var p = DL.floor_at(at + out * rng.randf_range(1.9, 2.4))
		var sh = DL.rock(DL.chunk_mesh(1, i % 6, snappedf(rng.randf_range(0.28, 0.42), 0.05)), pl["body"].darkened(rng.randf_range(0.0, 0.15)), {"ow": 0.025, "top": pl["top"], "top_y": 0.5})
		sh.basis = _basis_out(out).rotated(DL.side_of(out), -deg_to_rad(rng.randf_range(20.0, 45.0)))
		DL.rise(pj, sh, p, 1.0, 0.12, 2.6, 0.5, 0.03 * i)
	DL.crack(pj, at, 3.4, 3.8, 0.25, 0.0, 9.0)
	DL.burst_chunks(pj, at, 10, 0.25, 7.0, pl["body"], 0.9)
	DL.grit(pj, at + Vector3.UP * 0.2, 24, pl["body"], {"spread": 80.0, "vmin": 3.0, "vmax": 8.0, "r": 1.6, "life": 0.9, "size": 0.06})
	DL.dust_ring(pj, at, 1.8, 4.2, 6, 1.8, 1.0, pl["dust"])


static func chidokaku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var at = pj.gp(c.global_position)
	_zone(at, 6.0, 5.0)
	_mesa(pj, at)
	c.set("velocity", Vector3.UP * 18.0)
	pj.after(0.2, func():
		for e in pj.enemies_near(c, at, 6.0):
			if pj.live(e) and e.global_position.distance_to(at) > 1.6:
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "doton_chidokaku", 1.0, {"knock": 9.0, "launch": 4.0, "kind": "heavy", "element": "doton"})))
	pj.shake(0.8)
	Sfx.play("earth", at, 0.6)


# ================================================================== 14) Domu (Kakuzu / Jirōbō sertleşmesi)
## Kişinin GERÇEK teni göğüsten dışa doğru kömür karası, sert bir taşa döner: ince açık yarık ağı, sert parlama şeritleri, koyu
## kenar (kabuk / kutu yok). Ayak dibinde zemin sarmal çatlar, bedenden koyu taneler dökülür. 8 sn sonra kararma göğse çekilir.
static func domu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var g = pj.gp(c.global_position)
	_zone(g, 3.0)
	var m = DL.skin_mat(1, Color(0.17, 0.155, 0.15), 9.0)
	_skin_timed(c, m, "spread", 0.0, 1.7, 0.6, 8.0, 0.5)
	DL.crack(pj, g, 1.4, 2.6, 0.35, 1.4, 6.0)
	DL.grit(pj, c.global_position + Vector3.UP * 1.2, 16, Color(0.2, 0.18, 0.17), {"dir": Vector3.DOWN, "spread": 70.0, "vmin": 0.3, "vmax": 1.5, "r": 0.4, "life": 0.8, "size": 0.035})
	if c is Player:
		Buffs.add("domu", 8.0, {"armor": 0.85, "melee": 1.4, "speed": 0.85, "_name": "Domu", "_desc": "taş ten: fiziksel hasar neredeyse sıfır"})
	Sfx.play("earth", c.global_position, 1.2)


# ================================================================== 15) Iwa no Yoroi (Kaya Zırhı)
## Referans: kol ve yumruğu saran açık gri-mavi, köşeli yüzlü kaya; kenarları mavi chakra ışığıyla parlar. Yerden çakıllar
## bedene akar, kemiklere bağlı (bedenle hareket eden) yüzlü plakalar halka halinde dizilir: yumruk, ön kol, üst kol, göğüs,
## baldır; her plakanın kenarında mavi parıltı. 12 sn sonra plakalar gerçek taş parçaları olarak dökülür.
const _ARMOR := [
	["RightHand", 5, 0.085, 0.03, 0.11, Vector3(0.12, 0.13, 0.085)],
	["LeftHand", 5, 0.085, 0.03, 0.11, Vector3(0.12, 0.13, 0.085)],
	["RightLowerArm", 6, 0.09, 0.05, 0.2, Vector3(0.12, 0.15, 0.08)],
	["LeftLowerArm", 6, 0.09, 0.05, 0.2, Vector3(0.12, 0.15, 0.08)],
	["RightUpperArm", 5, 0.1, 0.04, 0.18, Vector3(0.13, 0.15, 0.08)],
	["LeftUpperArm", 5, 0.1, 0.04, 0.18, Vector3(0.13, 0.15, 0.08)],
	["Chest", 8, 0.19, 0.0, 0.1, Vector3(0.16, 0.16, 0.08)],
	["UpperChest", 8, 0.2, 0.0, 0.12, Vector3(0.17, 0.16, 0.08)],
	["RightLowerLeg", 5, 0.1, 0.08, 0.26, Vector3(0.13, 0.16, 0.08)],
	["LeftLowerLeg", 5, 0.1, 0.08, 0.26, Vector3(0.13, 0.16, 0.08)],
]


static func iwa_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var g = pj.gp(c.global_position)
	var pl = DL.pal(g)
	var tone = Color(0.7, 0.76, 0.82)
	_zone(g, 2.5)
	var parts = []
	var bi = 0
	for spec in _ARMOR:
		var ba = pj.bone_attach(c, spec[0])
		if ba == null:
			continue
		_plate_ring(ba, spec[1], spec[2], spec[3], spec[4], spec[5], tone, true, 0.18 + bi * 0.03)
		parts.append(weakref(ba))
		bi += 1
	for i in 9:   # yerden bedene akan çakıllar
		var a = randf() * TAU
		var p0 = DL.floor_at(g + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 1.8)) + Vector3.UP * 0.05
		var pb = DL.chunk(randf_range(0.05, 0.09), 2, tone, {"ow": 0.01})
		DL.put(pj, pb, p0)
		var tgt = c.global_position + Vector3(cos(a) * 0.25, randf_range(0.4, 1.5), sin(a) * 0.25)
		var pw = weakref(pb)
		var tw = pb.create_tween()
		tw.tween_interval(i * 0.025)
		tw.tween_method(func(u: float) -> void:
			var x = pw.get_ref()
			if x != null and is_instance_valid(x):
				x.global_position = p0.lerp(tgt, u) + Vector3.UP * sin(u * PI) * 0.5, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(pb.queue_free)
	DL.crack(pj, g, 1.5, 2.8, 0.2)
	DL.grit(pj, g + Vector3.UP * 0.1, 16, pl["body"], {"spread": 60.0, "vmin": 1.0, "vmax": 3.0, "r": 0.9, "life": 0.7, "size": 0.05})
	pj.after(12.0, func():
		for w in parts:
			var x = w.get_ref()
			if x != null:
				_shed(pj, x, tone))
	if c is Player:
		Buffs.add("iwa_no_yoroi", 12.0, {"armor": 0.62, "speed": 0.75})
	Sfx.play("earth", c.global_position, 0.9)
