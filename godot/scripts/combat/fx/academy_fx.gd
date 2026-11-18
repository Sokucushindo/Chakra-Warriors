class_name AcademyFX
extends RefCounted
## Akademi tekniklerinin KENDİ görselleri (KURAL 2026-11-16: hiçbir jutsu hazır efekte dayanmaz). Ortak FX / VFX yok;
## geometri MB ile, malzeme Godot'nun yerleşik malzemesiyle burada üretilir.
##  · poof: kanon "bofun" — klon / dönüşüm dumanı: yuvarlak, katmanlı cel bulut topakları şişer, dağılır
##  · feet_chakra: Ki / Gake Nobori — tabanlarda (ya da avuçlarda) nabız gibi atan ince mavi chakra zarı
##  · rope_snap: Nawanuke — kopan ip parçaları savrulup düşer
##  · tag_blast: Kawarimi kütüğündeki patlayıcı etiket — kâğıt tutuşur (kıvılcımlı kenar), katmanlı ateş topu, kara is lekesi


static func _mat(col: Color, unshaded := true, alpha := true) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _scene() -> Node:
	return Engine.get_main_loop().current_scene


static func _mi(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = at
	return mi


## Kanon klon / dönüşüm dumanı: 7-9 yuvarlak topak, iki tonlu (beyaz üst, gri-mavi alt), şişip yükselir ve erir
static func poof(at: Vector3, size := 1.0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var n = 7 + rng.randi() % 3
	for i in n:
		var b = MB.new()
		var r = rng.randf_range(0.35, 0.6) * size
		b.add("sphere", Vector3.ZERO, Vector3(r, r * 0.85, r), Color(1, 1, 1), Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, -r * 0.25, 0), Vector3(r * 0.92, r * 0.6, r * 0.92), Color(0.78, 0.82, 0.9), Vector3.ZERO, 10)
		var mat = _mat(Color(1, 1, 1, 0.95))
		mat.vertex_color_use_as_albedo = true
		var mi = _mi(b.build(mat), mat, at + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.5), rng.randf_range(-0.5, 0.5)) * size)
		mi.scale = Vector3.ONE * 0.3
		var drift = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.4, 1.0), rng.randf_range(-0.6, 0.6)) * size
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * rng.randf_range(1.1, 1.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", mi.global_position + drift, 0.7)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_delay(0.3)
		tw.chain().tween_callback(mi.queue_free)


## Ki / Gake Nobori: kemiklere iliştirilmiş ince chakra zarları (taban / avuç), mavi nabız
static func feet_chakra(c: Node3D, bones: Array, dur: float) -> void:
	var md = c.get("model")
	if md == null or md.get("skel") == null:
		return
	var sk: Skeleton3D = md.skel
	for bn in bones:
		var bi = sk.find_bone(String(bn))
		if bi < 0:
			continue
		var ba = BoneAttachment3D.new()
		ba.bone_name = String(bn)
		sk.add_child(ba)
		var b = MB.new()
		b.add("cyl", Vector3(0, -0.06, 0.04), Vector3(0.16, 0.012, 0.26), Color(0.55, 0.85, 1.0), Vector3.ZERO, 12)
		b.add("cyl", Vector3(0, -0.07, 0.04), Vector3(0.22, 0.008, 0.32), Color(0.3, 0.6, 1.0), Vector3.ZERO, 12)
		var mat = _mat(Color(0.6, 0.85, 1.0, 0.75))
		mat.vertex_color_use_as_albedo = true
		var mi = MeshInstance3D.new()
		mi.mesh = b.build(mat)
		mi.material_override = mat
		ba.add_child(mi)
		var tw = Game.safe_loops(mi.create_tween(), int(dur / 0.5))
		tw.tween_property(mat, "albedo_color:a", 0.3, 0.25)
		tw.tween_property(mat, "albedo_color:a", 0.8, 0.25)
		c.get_tree().create_timer(dur).timeout.connect(func():
			if is_instance_valid(ba):
				ba.queue_free())


## Nawanuke: 6-9 kısa ip parçası (bükümlü iki tel), savrulur, düşer, yerde bir süre kalıp söner
static func rope_snap(at: Vector3) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in 6 + rng.randi() % 4:
		var b = MB.new()
		var L = rng.randf_range(0.18, 0.4)
		b.add("cyl", Vector3(0.012, 0, 0), Vector3(0.022, L, 0.022), Color(0.72, 0.6, 0.4), Vector3(0, 0, 4), 5)
		b.add("cyl", Vector3(-0.012, 0, 0), Vector3(0.02, L, 0.02), Color(0.6, 0.48, 0.3), Vector3(0, 0, -4), 5)
		var mat = _mat(Color(1, 1, 1, 1), false, true)
		mat.vertex_color_use_as_albedo = true
		var mi = _mi(b.build(mat), mat, at + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.4), rng.randf_range(-0.3, 0.3)))
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var land = mi.global_position + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
		land.y = Game.ground_height(land.x, land.z) + 0.02
		var peak = (mi.global_position + land) * 0.5 + Vector3.UP * rng.randf_range(0.5, 1.0)
		var p0 = mi.global_position
		var tw = mi.create_tween()
		tw.tween_method(func(u: float):
			if is_instance_valid(mi):
				mi.global_position = p0.lerp(peak, u).lerp(peak.lerp(land, u), u)
				mi.rotation.x += 0.25, 0.0, 1.0, 0.55)
		tw.tween_property(mi, "rotation", Vector3(PI * 0.5, mi.rotation.y, 0), 0.05)
		tw.tween_interval(2.0)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
		tw.tween_callback(mi.queue_free)


## Patlayıcı etiket: kütüğe sarılı kâğıt (kırmızı kanji şeridi) 0.6 sn kıvılcımlı kenarla yanar, sonra katmanlı ateş topu
## (sarı-beyaz çekirdek, turuncu, koyu kızıl kenar) + yükselen kara is + yerde yanık leke. Görüneni burada; hasar çağıranda.
static func tag_blast(at: Vector3, fuse := 0.6) -> void:
	var tag = MB.new()
	tag.add("box", Vector3.ZERO, Vector3(0.12, 0.3, 0.01), Color(0.95, 0.92, 0.8))
	tag.add("box", Vector3(0, 0, 0.006), Vector3(0.04, 0.24, 0.004), Color(0.7, 0.08, 0.06))
	var tmat = _mat(Color(1, 1, 1, 1), false, false)
	tmat.vertex_color_use_as_albedo = true
	var tg = _mi(tag.build(tmat), tmat, at + Vector3.UP * 0.75)
	var ember = _mat(Color(1.0, 0.55, 0.1, 1.0))
	var eb = MB.new()
	eb.add("box", Vector3.ZERO, Vector3(0.13, 0.02, 0.012), Color(1, 1, 1))
	var edge = MeshInstance3D.new()
	edge.mesh = eb.build(ember)
	edge.material_override = ember
	tg.add_child(edge)
	edge.position = Vector3(0, -0.15, 0)
	var tw = edge.create_tween()
	tw.tween_property(edge, "position:y", 0.15, fuse)   # kenar yukarı doğru yanar
	tw.parallel().tween_property(tg, "scale:y", 0.15, fuse)
	tw.tween_callback(func():
		if is_instance_valid(tg):
			tg.queue_free()
		_fireball(at + Vector3.UP * 0.6))


static func _fireball(at: Vector3) -> void:
	var layers = [[0.5, Color(1.0, 0.97, 0.75), 0.18], [0.85, Color(1.0, 0.68, 0.18), 0.28], [1.25, Color(0.85, 0.25, 0.06), 0.4]]
	for L in layers:
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * float(L[0]), Color(1, 1, 1), Vector3.ZERO, 14)
		var m = _mat(Color(L[1].r, L[1].g, L[1].b, 0.95))
		var mi = _mi(b.build(m), m, at)
		mi.scale = Vector3.ONE * 0.2
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * 1.6, float(L[2])).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, float(L[2]) + 0.15)
		tw.tween_callback(mi.queue_free)
	# yükselen kara is topakları
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:
		var b = MB.new()
		var r = rng.randf_range(0.3, 0.55)
		b.add("sphere", Vector3.ZERO, Vector3(r, r * 0.8, r), Color(1, 1, 1), Vector3.ZERO, 8)
		var m = _mat(Color(0.12, 0.1, 0.1, 0.8))
		var mi = _mi(b.build(m), m, at + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, 0.6), rng.randf_range(-0.6, 0.6)))
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", mi.global_position + Vector3(0, rng.randf_range(1.2, 2.2), 0), 1.2)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 1.2)
		tw.tween_property(m, "albedo_color:a", 0.0, 1.2).set_delay(0.3)
		tw.chain().tween_callback(mi.queue_free)
	# yerde yanık leke
	var gp = Vector3(at.x, Game.ground_height(at.x, at.z) + 0.03, at.z)
	var sb = MB.new()
	sb.add("cyl", Vector3.ZERO, Vector3(2.4, 0.01, 2.0), Color(1, 1, 1), Vector3(0, rng.randf() * 360.0, 0), 14)
	var sm = _mat(Color(0.08, 0.06, 0.05, 0.75))
	var scorch = _mi(sb.build(sm), sm, gp)
	var st = scorch.create_tween()
	st.tween_interval(4.0)
	st.tween_property(sm, "albedo_color:a", 0.0, 1.5)
	st.tween_callback(scorch.queue_free)
