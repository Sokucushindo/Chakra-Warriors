class_name TrainingDummy
extends Node3D
## Antrenman kuklası: hasar alır, sallanır, devrilir ve geri kalkar.

var team = "dummy"
var radius = 0.45
var height = 1.9
var hp = 120.0
var max_hp = 120.0
var dead = false
var vis: Node3D


func _ready() -> void:
	add_to_group("fighters")
	# arazi yüksekliği; yükseltilmiş zeminde (teras, avlu döşemesi) verilen yükseklik korunur
	var g = Game.ground_height(global_position.x, global_position.z)
	if not has_meta("exam_target") or global_position.y < g:
		global_position.y = g
	vis = Node3D.new()
	add_child(vis)
	# Kaynak (Narutopedia Third Training Ground + makiwara): kalın kütük direk, iple bağlı saman sargılar,
	# omuz hizasında iple bağlanmış kol kütüğü, yıpranmış başlık sargısı, vuruş izleri. Eskiden kutu kol + küre kafa + kırmızı kareydi.
	var b = MB.new()
	var I = Transform3D.IDENTITY
	var bark = Color(0.4, 0.29, 0.19)
	var straw = Color(0.78, 0.66, 0.4)
	var rope = Color(0.6, 0.48, 0.3)
	b.add("cyl", Vector3(0, 0.95, 0), Vector3(0.36, 1.9, 0.36), bark, Vector3.ZERO, 9)   # direk
	b.add("cyl", Vector3(0, 1.905, 0), Vector3(0.33, 0.012, 0.33), Color(0.72, 0.58, 0.4), Vector3.ZERO, 9)   # kesik tepe halkası
	b.add("cyl", Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), bark.darkened(0.25), Vector3.ZERO, 9)   # yere gömülü dip
	for k in 5:   # yer yer kabuk kalıntısı
		b.add("box", Vector3(0, 0.3 + k * 0.33, 0).rotated(Vector3.UP, k * 1.3) + Vector3(0.17, 0, 0).rotated(Vector3.UP, k * 1.3), Vector3(0.04, 0.22, 0.09), bark.darkened(0.2), Vector3(0, -rad_to_deg(k * 1.3), 0))
	# gövde sargısı: saman demeti, alt / üst kenarı kabarık, üç sıra ip
	b.add("sphere", Vector3(0, 1.12, 0), Vector3(0.66, 0.86, 0.6), straw, Vector3.ZERO, 14)   # kabarık saman demeti
	for k in 3:   # demetten taşan saman uçları (alt etek)
		b.add("cone", Vector3(0, 0.72, 0).rotated(Vector3.UP, 0.0), Vector3(0.6 - k * 0.04, 0.16, 0.56 - k * 0.04), straw.darkened(0.06 * k), Vector3(180, k * 25, 0), 12)
	for y in [0.88, 1.12, 1.36]:
		var w = 0.6 * sqrt(maxf(0.05, 1.0 - pow((y - 1.12) / 0.43, 2.0))) + 0.02
		b.add("torus", Vector3(0, y, 0), Vector3(w, 0.45, w * 0.92), rope, Vector3.ZERO, 14)
	# kol kütüğü: gövdenin üstünden geçen yatay kütük, çapraz ip bağı
	CampKit._rod(b, I, Vector3(-0.72, 1.58, 0.0), Vector3(0.72, 1.6, 0.0), 0.075, bark.lightened(0.05), 7)
	for sx in [-1.0, 1.0]:
		CampKit._rod(b, I, Vector3(sx * 0.2, 1.48, 0.2), Vector3(-sx * 0.2, 1.7, 0.2), 0.02, rope, 4)
		CampKit._rod(b, I, Vector3(sx * 0.2, 1.48, -0.2), Vector3(-sx * 0.2, 1.7, -0.2), 0.02, rope, 4)
		b.add("cyl", Vector3(sx * 0.6, 1.59, 0), Vector3(0.2, 0.16, 0.2), straw.darkened(0.05), Vector3(0, 0, 90), 8)   # kol ucu saman topu
		b.add("torus", Vector3(sx * 0.6, 1.59, 0), Vector3(0.22, 0.4, 0.22), rope, Vector3(0, 0, 90), 8)
	# baş: direğin tepesine sarılmış bez + ip, alında çizik izleri
	b.add("sphere", Vector3(0, 1.86, 0), Vector3(0.42, 0.4, 0.4), straw.darkened(0.04), Vector3.ZERO, 10)   # saman baş
	b.add("cone", Vector3(0, 2.1, 0), Vector3(0.18, 0.16, 0.18), straw.darkened(0.1), Vector3.ZERO, 8)   # tepede bağlanmış saman ucu
	b.add("torus", Vector3(0, 2.03, 0), Vector3(0.14, 0.4, 0.14), rope, Vector3.ZERO, 8)
	b.add("torus", Vector3(0, 1.7, 0), Vector3(0.3, 0.45, 0.3), rope, Vector3.ZERO, 10)   # boyun bağı
	# vuruş izleri: gövdede kesik çentikler, saplanmış bir kunai
	for k in 3:
		b.add("box", Vector3(-0.08 + k * 0.08, 1.05 + k * 0.1, 0.29), Vector3(0.16, 0.018, 0.02), Color(0.35, 0.27, 0.15), Vector3(0, 0, 25 - k * 20))
	b.add("box", Vector3(0.14, 1.25, 0.33), Vector3(0.03, 0.03, 0.16), Color(0.25, 0.25, 0.28), Vector3(-15, 10, 0))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	vis.add_child(mi)
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var sh = CylinderShape3D.new()
	sh.radius = 0.33
	sh.height = 1.9
	cs.shape = sh
	cs.position.y = 0.95
	sb.add_child(cs)
	add_child(sb)


func is_dead() -> bool:
	return dead


func face_dir() -> Vector3:
	return -global_transform.basis.z


func take_hit(info: Dictionary) -> void:
	if dead:
		return
	if has_meta("drill_throw") and not info.has("tool"):
		Combat.popup_text(global_position + Vector3.UP * 1.2, "Yalnız atış! [R]", Color(1, 0.8, 0.4))
		return
	if has_meta("throw_only"):
		# atış hedefi: yalnız kunai/shuriken; tek isabet yeter
		if not info.has("tool"):
			Combat.popup_text(global_position + Vector3.UP * 2.2, "Yalnız atış! [R]", Color(1, 0.8, 0.4))
			return
		info = info.duplicate()
		info["dmg"] = hp + 1.0
	var dmg: float = info.get("dmg", 5.0)
	hp -= dmg
	Combat.damage_number(global_position + Vector3.UP * 2.3, dmg, Color(1, 0.9, 0.3) if info.get("kind", "") != "heavy" else Color(1, 0.55, 0.2))
	var d: Vector3 = info.get("dir", Vector3.FORWARD)
	var axis = Vector3.UP.cross(d).normalized()
	if axis.length() < 0.1:
		axis = Vector3.RIGHT
	vis.transform.basis = Basis(axis, 0.35 if info.get("kind", "") != "heavy" else 0.6)
	var tw = vis.create_tween()
	tw.tween_property(vis, "transform:basis", Basis.IDENTITY, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Progress.on_dummy_hit(self, dmg)
	if hp <= 0.0:
		dead = true
		var tw2 = vis.create_tween()
		tw2.tween_property(vis, "transform:basis", Basis(axis, PI * 0.47), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(4.0)
		tw2.tween_callback(func():
			hp = max_hp
			dead = false
			vis.transform.basis = Basis.IDENTITY
			FX.smoke_puff(global_position + Vector3.UP, 0.7, 8))
		Progress.on_dummy_broken(self)


func apply_status(_n: String, _d: float) -> void:
	pass
