extends RefCounted
## Hikō Tsubasa (kanatlı düzenek; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/hiko_tsubasa_fx.gd). Kanon (Narutopedia "Winged Mechanical Device", Gökyüzü ninjaları, film Bonds):
## kanatlara akan chakra uçurur; uzun kullanım chakrayı tüketir; kendi gücüyle KALKAMAZ (fırlatma düzeneği ister). Üstünden patlayıcı bırakılır. Görünüş refs/hiko_tsubasa: zeytin-altın dört kanat, ortada arma.
## Oyunda: alet tuşu havadayken açar (zıplayınca / sıçrayınca), oyunun uçuş sistemini kullanır; alçalıp yere değince ya da tuşla kapanır. Düşman: üstten geçip patlayıcı bırakır.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const SRC := "hiko_tsubasa"


static func _wing_mesh() -> Mesh:
	return Yk.mesh("hiko_kanat", func():
		var b = MB.new()
		var g = Color(0.68, 0.62, 0.26)
		var d = Color(0.42, 0.38, 0.14)
		var xf = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
		var big := PackedVector2Array([Vector2(0.08, 0.05), Vector2(0.7, 0.2), Vector2(1.5, 0.12), Vector2(0.75, -0.05), Vector2(0.1, -0.12)])
		var fin := PackedVector2Array([Vector2(0.05, 0.1), Vector2(0.12, 0.62), Vector2(0.3, 0.72), Vector2(0.24, 0.1)])
		for sx in [1.0, -1.0]:
			var m = Basis(Vector3.UP, 0.0 if sx > 0.0 else PI) * xf
			b.add_slab(big, 0.04, g, Transform3D(m, Vector3.ZERO), Callable(), d)
			b.add_slab(fin, 0.03, g, Transform3D(m, Vector3.ZERO), Callable(), d)
		b.add("cyl", Vector3.ZERO, Vector3(0.26, 0.05, 0.26), g, Vector3(90, 0, 0), 14)
		b.add("box", Vector3(0, 0, 0.03), Vector3(0.1, 0.02, 0.006), Color(0.2, 0.36, 0.72))
		b.add("box", Vector3(0.02, 0.03, 0.03), Vector3(0.02, 0.05, 0.006), Color(0.2, 0.36, 0.72))
		return b.build(Props.toon()))


static func _vis() -> Node3D:
	var root = Node3D.new()
	var m = MeshInstance3D.new()
	m.mesh = _wing_mesh()
	m.position = Vector3(0, 1.3, 0.2)
	root.add_child(m)
	return root


## Oyuncu (alet tuşu): havadaysa açar, uçuyorsa kapatır
static func player_use(p: Node3D) -> void:
	if p.flight_source() == SRC:
		p.stop_flight()
		return
	if bool(p.grounded):
		Hud.msg("Kanatlar yerden kaldıramaz: önce havalan, havadayken aç.", Color(1, 0.8, 0.5))
		return
	p.start_flight(SRC, {"speed": 25.0, "lift": 7.0, "drain": 4.5, "vis": _vis(), "name": "Hikō Tsubasa", "land_stop": true})
	Sfx.play("wind", p.global_position, 1.1, 0.7)


## Düşman: yükselir, hedefin üstünden geçer, patlayıcı bırakır
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, target: Node3D) -> Projectile:
	if who is Player:
		player_use(who)
		return null
	var tg = target if U.alive(target) else U.target_of(who)
	if not U.alive(tg):
		return null
	var v = _vis()
	who.add_child(v)
	var a: Vector3 = who.global_position
	var mid: Vector3 = tg.global_position
	var f = (mid - a)
	f.y = 0.0
	v.rotation.y = atan2(-f.x, -f.z)
	var e: Vector3 = mid + f.normalized() * 7.0
	e.y = Game.ground_height(e.x, e.z)
	var glide = func(u: float) -> void:
		if not is_instance_valid(who):
			return
		var p = a.lerp(e, u)
		p.y = lerpf(a.y, e.y, u) + sin(u * PI) * 8.0
		who.global_position = p
		if who is CharacterBody3D:
			who.velocity = Vector3.ZERO
	var tw = who.create_tween()
	tw.tween_method(glide, 0.0, 1.0, 1.7)
	tw.tween_callback(v.queue_free)
	for k in 3:
		Yk.after(who, 0.55 + k * 0.28, func():
			Projectile.tool(who, who.global_position + Vector3.UP * 0.9, Vector3.DOWN, "kibaku_dama", null))
	return null
