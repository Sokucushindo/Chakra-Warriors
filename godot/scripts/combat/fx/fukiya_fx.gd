extends RefCounted
## Fukiya: model, iğneler, zehir görseli. Ortak efekt yok; atış SESSİZ ve izsizdir (kanonda suikast aracı).
## Kanon (Narutopedia "Blowpipe", "Injection Shot", "Injection Shot Sniper", "Dōshu Goetsu", "Kobuna", "The Terror! Enko Onikuma", "Aniki"):
## içi boş uzun tüp, ok / senbon üfler; usta tek atışta öldürür (Kabuto -> Sabiru, Shippūden 193). Ibiki ile Dōshu saniyeler içinde
## bayıltan iğneyle uyuşturur (Enko); Kobuna senbon atar; Aniki gülme zehirli ok üfler, Kakashi kolayca kaçar: görülen atıştan kaçılır.
## Zayıflık: hasar düşük, güç zehir ve fark edilmemekte; hedef sana bakıyorsa tek nefes öldürmez. Boru kırılabilir (Enko) oyunda yok.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const SPEED := 58.0
const GRAV := 0.8
const MUZZLE := 0.72
const POISON := 1.6     # iğne başına zehir süresi (sn)
const KILL_MUL := 3.4   # fark etmemiş hedefe Hitofuki

static var _c := {}


## Boru: üflenen uç z -0.205 (Kiseru ağızlığı ile aynı nokta), namlu z 0.72; ince koyu kızıl lake (Blowpipe.png), iki ucu koyu halka
static func build_pipe(b: MB) -> void:
	var red = Color(0.5, 0.12, 0.13)
	var dk = Color(0.2, 0.07, 0.08)
	b.add("cyl", Vector3(0, 0, 0.2575), Vector3(0.026, 0.925, 0.026), red, Vector3(90, 0, 0), 10)
	for z in [-0.2, 0.05, 0.42, 0.712]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.031, 0.016, 0.031), dk, Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, 0.721), Vector3(0.016, 0.003, 0.016), Color(0.03, 0.02, 0.02), Vector3(90, 0, 0), 8)   # namlu ağzı


## Üfleme iğnesi: ince çelik, dipte küçük lif topağı. Uç +Z, dip z=0
static func _needle(b: MB, tuft: Color) -> void:
	b.add("cyl", Vector3(0, 0, 0.09), Vector3(0.005, 0.18, 0.005), Color(0.78, 0.8, 0.85), Vector3(90, 0, 0), 4)
	b.add("cone", Vector3(0, 0, 0.012), Vector3(0.026, 0.035, 0.026), tuft, Vector3(90, 0, 0), 6)


## Uyku oku (Injection_Shot.png): gümüş şırınga gövde, süt rengi sıvı bölmesi, ince iğne, dipte kirli gri lif demeti
static func _syringe(b: MB) -> void:
	var steel = Color(0.72, 0.75, 0.78)
	var liq = Color(0.82, 0.84, 0.72)
	b.add("cyl", Vector3(0, 0, 0.09), Vector3(0.022, 0.09, 0.022), steel, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.15), Vector3(0.022, 0.04, 0.022), liq, Vector3(90, 0, 0), 8)
	for z in [0.045, 0.133]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.025, 0.005, 0.025), steel.darkened(0.3), Vector3(90, 0, 0), 8)
	b.add("cone", Vector3(0, 0, 0.18), Vector3(0.022, 0.02, 0.022), steel, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.225), Vector3(0.004, 0.08, 0.004), Color(0.3, 0.3, 0.33), Vector3(90, 0, 0), 4)
	var fib = Color(0.55, 0.53, 0.45)
	for k in 7:
		var a = k * TAU / 7.0
		var o = PackedVector2Array([Vector2(-0.006, 0.045), Vector2(0.006, 0.045), Vector2(0.012 + 0.006 * (k % 2), -0.03), Vector2(0.002, -0.012), Vector2(-0.012, -0.034)])
		b.add_slab(o, 0.002, fib, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.32), Vector3(0, 0.008, 0)))


static func _mesh(key: String, fn: Callable) -> Mesh:
	if not _c.has(key):
		var b = MB.new()
		fn.call(b)
		_c[key] = b.build(Props.toon())
	return _c[key]


static func _vis(mesh: Mesh) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation.y = PI
	mi.position = Vector3(0, 0, 0.1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


static func _dart_mesh() -> Mesh:
	return _mesh("dart", func(b: MB): _needle(b, Color(0.42, 0.62, 0.3)))


static func _sleep_mesh() -> Mesh:
	return _mesh("sleep", func(b: MB): _syringe(b))


## Yaradan süzülen koyu yeşil zehir damlaları (yalnız bu silahın)
static func _drips(t: Node3D, n: int) -> void:
	if not is_instance_valid(t):
		return
	var m = _mesh("drop", func(b: MB): b.add("sphere", Vector3.ZERO, Vector3(0.022, 0.034, 0.022), Color(0.26, 0.42, 0.16), Vector3.ZERO, 6))
	var base = U.chest(t)
	for k in n:
		t.get_tree().create_timer(k * 0.16).timeout.connect(func():
			if not is_instance_valid(t):
				return
			var mi = MeshInstance3D.new()
			mi.mesh = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			t.get_tree().current_scene.add_child(mi)
			var p: Vector3 = base + Vector3(randf_range(-0.16, 0.16), randf_range(-0.2, 0.2), randf_range(-0.16, 0.16))
			mi.global_position = p
			var tw = mi.create_tween()
			tw.tween_method(func(v: float):
				if is_instance_valid(mi):
					mi.global_position = p + Vector3.DOWN * 3.6 * v * v, 0.0, 0.5, 0.5)
			tw.tween_callback(mi.queue_free))


static func _poison(t: Node3D, dur: float) -> void:
	if t != null and is_instance_valid(t) and t.has_method("apply_status"):
		load("res://scripts/combat/fx/doku_fx.gd").add(t, dur)
		_drips(t, 3)


static func _muzzle(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, "fukiya")
	return n.to_global(Vector3(0, 0, MUZZLE)) if n != null else who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.7


## Düşman seni görmüyor mu? (hedefi yok ya da sana sırtı dönük). Oyuncu hedefse yalnız sırtı dönükse.
static func unaware(who: Node3D, t: Node3D) -> bool:
	if not U.alive(t):
		return false
	if not (t is Player) and t.get("target") == null:
		return true
	var to = who.global_position - t.global_position
	to.y = 0.0
	return to.length() > 0.1 and t.face_dir().dot(to.normalized()) < -0.25


static func _dart(who: Node3D, aim: Vector3, dmg: float, on_hit: Callable, mesh: Mesh = null, stray := 0.0) -> void:
	var from = _muzzle(who)
	var to = aim + Vector3(randf_range(-stray, stray), randf_range(-stray, stray), randf_range(-stray, stray))
	var dm = mesh if mesh != null else _dart_mesh()
	var cb = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt != null and is_instance_valid(tgt):
			Sfx.play("hit_claw", pos, 1.7, 0.3)
			var mi = MeshInstance3D.new()
			mi.mesh = dm
			U.pin(mi, tgt, pos - (to - from).normalized() * 0.1, to - from, 2.0)
			if on_hit.is_valid():
				on_hit.call(tgt)
	U.fire(who, from, U.solve(from, to, SPEED, GRAV), {"g": GRAV, "r": 0.1, "life": 1.8, "stick": true, "vis": _vis(dm), "hit": cb,
		"info": {"dmg": dmg, "knock": 0.4, "kind": "light", "hitstop": 0.0}})


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 3 and who is CharacterBody3D:   # Hiki-fuki: geriye kayarak mesafe açar
		var f: Vector3 = who.face_dir()
		who.velocity.x = -f.x * 8.5
		who.velocity.z = -f.z * 8.5
		who.velocity.y = 3.0


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	Sfx.play("whoosh", _muzzle(who), 2.6, 0.12)   # yalnız kısa nefes: uzaktan duyulmaz
	match i:
		0, 1, 3:
			_dart(who, aim, dmg * 0.5, func(t: Node3D): _poison(t, POISON))
		2:   # Nemuri-ya: birkaç an yürür, sonra bayıltır (Injection Shot: "saniyeler içinde")
			var sleep_hit = func(t: Node3D) -> void:
				if t.has_method("apply_status"):
					t.apply_status("slow", 1.0)
				Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyuşuyor...", Color(0.8, 0.85, 0.7))
				t.get_tree().create_timer(0.8).timeout.connect(func():
					if U.alive(t) and t.has_method("apply_status"):
						t.apply_status("stun", 2.0)
						Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyudu!", Color(0.8, 0.85, 0.7)))
			_dart(who, aim, dmg * 0.3, sleep_hit, _sleep_mesh())
		4:   # Sanren: bir nefeste üç iğne, biraz dağılır
			for k in 3:
				who.get_tree().create_timer(k * 0.1).timeout.connect(func():
					if is_instance_valid(who):
						_dart(who, U.aim_at(who, tg), dmg * 0.34, func(t: Node3D): _poison(t, POISON * 0.6), null, 0.12))
		5:   # Hitofuki: fark etmemiş hedefe öldürücü iğne; görüldüyse sıradan bir iğne kadar kalır
			var sure = unaware(who, tg)
			var kill_hit = func(t: Node3D) -> void:
				_poison(t, POISON * 2.0)
				if sure:
					Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Tek nefes!", Color(0.7, 0.9, 0.55))
			_dart(who, aim, dmg * (KILL_MUL if sure else 0.9), kill_hit)
