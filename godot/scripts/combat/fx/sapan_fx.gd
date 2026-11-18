extends RefCounted
## Pachinko (sapan): model, gerçekten gerilen lastik + yaylanan kese, taşlar, biber topu.
## KANON ZAYIF: tek kullanıcı Tanishi (Genjutsu Ağacı Köyü, yalnız animedeki dolgu bölümleri). Narutopedia: babasının Biber Bombası'nı
## (Chilli Pepper Bomb, ref refs/sapan/Chilli_Pepper_Pill.png: parmak arasında turuncu-kızıl küçük top) sapanla uzaktaki müttefiklerine
## atar, üzerlerindeki genjutsuyu bozar. Sapanın kendisinin görseli wikide yok: çatal biçimi gerçek sapandan, KANON DEĞİL.
## "Pachinko" Japoncada sapan demek; Pachinko Technique (Naruto + Sasuke) çekilen chakra sıvısıyla heykel fırlatır: bitiriş bundan esinli.
## Zayıflık: en düşük hasar; taş zırhsızı bile zor iter. Gücü biber topunun genjutsu bozması ve göz yakması.
## Düzen yumi ile aynı: sağ eldeki silah MERMİ ("sapan"), sol eldeki ikinci silah ÇATAL ("sapan_catal"). Çatal uzayı: +Z yukarı, +X hedefe.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/sapan_anim.gd")

const SPEED := 40.0
const GRAV := 7.0
const GAS_R := 3.4      # biber bulutu: düşman gözü yanar
const KAI_R := 8.0      # müttefiklerin genjutsusu bozulur (kanon: uzaktaki müttefik)

const WOOD := Color(0.42, 0.28, 0.16)
const RUB := Color(0.24, 0.17, 0.14)
const LEATHER := Color(0.36, 0.22, 0.13)
const PEPPER := Color(0.78, 0.33, 0.1)    # Chilli_Pepper_Pill.png
const STONE := Color(0.5, 0.49, 0.46)

static var _c := {}


class Rig extends Node3D:
	const U2 = preload("res://scripts/combat/fx/uzak_nisan.gd")
	const TIP_Y := 0.058
	const TIP_Z := 0.145
	const REST := Vector3(-0.1, 0.0, 0.1)    # kesenin durduğu yer (çatal uzayı)

	var who: Node3D
	var fork: MeshInstance3D
	var bands: MultiMesh
	var pouch: MeshInstance3D
	var ball: MeshInstance3D
	var hooked := false
	var hook_in := -1.0
	var aim := Vector3.ZERO
	var p := Vector3.ZERO     # kese (dünya), yay-sönüm benzetimi
	var v := Vector3.ZERO
	var live := false
	var back_in := -1.0

	static func seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
		var y = b - a
		if y.length() < 0.0005:
			y = Vector3(0, 0, 0.0005)
		var yn = y.normalized()
		var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
		return Transform3D(Basis(xn * w, y * 1.02, xn.cross(yn) * w), (a + b) * 0.5)

	func setup(w: Node3D, n: MeshInstance3D, band_mesh: Mesh, pouch_mesh: Mesh, ball_mesh: Mesh) -> void:
		who = w
		fork = n
		name = "SapanRig"
		process_priority = 60
		bands = MultiMesh.new()
		bands.transform_format = MultiMesh.TRANSFORM_3D
		bands.mesh = band_mesh
		bands.instance_count = 2
		var mm = MultiMeshInstance3D.new()
		mm.multimesh = bands
		mm.custom_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
		add_child(mm)
		pouch = MeshInstance3D.new()
		pouch.mesh = pouch_mesh
		pouch.top_level = true
		add_child(pouch)
		ball = MeshInstance3D.new()
		ball.mesh = ball_mesh
		ball.visible = false
		pouch.add_child(ball)
		p = fork.to_global(REST)
		_draw_bands()

	func _draw_bands() -> void:
		var pl: Vector3 = fork.to_local(p)
		for k in 2:
			var tip = Vector3(0.0, TIP_Y * (1.0 if k == 0 else -1.0), TIP_Z)
			var stretch = tip.distance_to(pl)
			bands.set_instance_transform(k, seg_xf(tip, pl, clampf(0.016 - stretch * 0.012, 0.006, 0.016)))   # gerildikçe incelir
		var d: Vector3 = fork.to_global(Vector3(0, 0, 0.12)) - p
		var s = fork.global_transform.basis.get_scale().x
		if d.length() > 0.01:
			var dn = d.normalized()
			pouch.global_transform = Transform3D(Basis.looking_at(-dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT).scaled(Vector3.ONE * s), p)

	func engage(a: Vector3, t: float) -> void:
		aim = a
		hook_in = t
		live = true

	func _hook() -> void:
		hooked = true
		ball.visible = true
		back_in = -1.0
		var n = U2.weapon_node(who, "sapan")
		if n != null:
			n.visible = false

	func release() -> void:
		hook_in = -1.0
		if hooked:
			v = (fork.to_global(Vector3(0, 0, 0.12)) - p) * 34.0   # lastik keseyi çatala fırlatır
			back_in = 0.28
		hooked = false
		ball.visible = false
		live = true

	func _process(dt: float) -> void:
		if who == null or not is_instance_valid(who) or not is_instance_valid(fork):
			return
		var m = who.get("model")
		if m == null or m.overlay == null:
			return
		if not fork.is_visible_in_tree():
			return
		if p.distance_to(fork.global_position) > 1.6:   # kınlanınca / ışınlanınca kese geride kalmasın
			p = fork.to_global(REST)
			v = Vector3.ZERO
		var acting = m.drawn and m.overlay.key_t >= 0.0
		if hook_in >= 0.0:
			hook_in -= dt
			if hook_in < 0.0 and acting:
				_hook()
		if hooked and not acting:
			hooked = false
			ball.visible = false
			back_in = 0.1
		if back_in >= 0.0:
			back_in -= dt
			if back_in < 0.0 and not hooked:
				m._place_weapons()
		if acting and aim != Vector3.ZERO:
			var x = aim
			x.y = clampf(x.y, -0.5, 0.75)
			x = x.normalized()
			var z = (Vector3.UP - x * x.dot(Vector3.UP)).normalized()
			var g = fork.global_transform
			var s = g.basis.get_scale().x
			var q = g.basis.orthonormalized().get_rotation_quaternion().slerp(Basis(x, z.cross(x), z).get_rotation_quaternion(), minf(1.0, dt * 16.0))
			fork.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * s), g.origin)
		var rest: Vector3 = fork.to_global(REST)
		if hooked:
			p = U2.fingers(who, "Right")
			v = Vector3.ZERO
			_draw_bands()
		elif live or p.distance_to(rest) > 0.004:
			# yay-sönüm: kese çatalın içinden geçer, ileri geri sallanıp durur; sarkan parça
			var h = minf(dt, 0.033)
			v += ((rest - p) * 300.0 - v * 13.0 + Vector3.DOWN * 3.0) * h
			p += v * h
			_draw_bands()
			if v.length() < 0.05 and p.distance_to(rest) < 0.012:
				live = false


# ------------------------------------------------------------------ modeller
static func _seg(b: MB, p: Vector3, q: Vector3, w: float, col: Color) -> void:
	b.add_xf("cyl", Rig.seg_xf(p, q, w), col, 6)


## Çatal: tek dal parçası, sap sargılı (gerçek sapan; kanon görseli yok)
static func build_fork(b: MB) -> void:
	_seg(b, Vector3(0, 0, -0.11), Vector3(0, 0, 0.035), 0.03, WOOD)
	for z in [-0.08, -0.05, -0.02]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.034, 0.012, 0.034), LEATHER, Vector3(90, 0, 0), 8)
	for sy in [-1.0, 1.0]:
		var m = Vector3(0, sy * 0.046, 0.075)
		var t = Vector3(0, sy * Rig.TIP_Y, Rig.TIP_Z)
		_seg(b, Vector3(0, 0, 0.03), m, 0.024, WOOD)
		_seg(b, m, t, 0.02, WOOD)
		b.add("cyl", t + Vector3(0, 0, -0.012), Vector3(0.024, 0.012, 0.024), RUB, Vector3(90, 0, 0), 8)


## Dururken: lastik + kese gevşek
static func build_full(b: MB) -> void:
	build_fork(b)
	for sy in [-1.0, 1.0]:
		_seg(b, Vector3(0, sy * Rig.TIP_Y, Rig.TIP_Z), Rig.REST, 0.014, RUB)
	b.add_mesh(_pouch_mb(), Transform3D(Basis(Vector3.UP, -PI * 0.5), Rig.REST))


static func _pouch_mb() -> MB:
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.05, 0.012, 0.04), LEATHER)
	return b


## Sağ elde tutulan mermi (parmak arasında)
static func build_shot(b: MB) -> void:
	b.add("sphere", Vector3(0, 0, 0.02), Vector3(0.036, 0.036, 0.036), PEPPER, Vector3.ZERO, 10)


static func _mesh(key: String, fn: Callable) -> Mesh:
	if not _c.has(key):
		var b = MB.new()
		fn.call(b)
		_c[key] = b.build(Props.toon())
	return _c[key]


static func _stone_mesh() -> Mesh:
	return _mesh("stone", func(b: MB): b.add("boulder", Vector3.ZERO, Vector3(0.05, 0.042, 0.05), STONE, Vector3.ZERO, 3))


static func _big_stone_mesh() -> Mesh:
	return _mesh("stone_big", func(b: MB): b.add("boulder", Vector3.ZERO, Vector3(0.2, 0.17, 0.2), STONE.darkened(0.1), Vector3.ZERO, 5))


static func _pepper_mesh() -> Mesh:
	return _mesh("pepper", func(b: MB): b.add("sphere", Vector3.ZERO, Vector3(0.05, 0.05, 0.05), PEPPER, Vector3.ZERO, 10))


static func rig_of(who: Node3D) -> Rig:
	var n = U.weapon_node(who, "sapan_catal")
	if n == null or not (n is MeshInstance3D):
		return null
	var r = n.get_node_or_null("SapanRig")
	if r != null:
		return r
	var rig = Rig.new()
	n.add_child(rig)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("sapan_catal_k")
	var bm = _mesh("band", func(b: MB): b.add("cyl", Vector3.ZERO, Vector3.ONE, RUB, Vector3.ZERO, 5))
	var pm = _mesh("pouch", func(b: MB): b.add_mesh(_pouch_mb()))
	rig.setup(who, n, bm, pm, _pepper_mesh())
	return rig


static func _vis(mesh: Mesh, spin_ok := true) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if spin_ok:
		var sp = Vector3(randf_range(-16, 16), randf_range(-16, 16), randf_range(-16, 16))
		var tw = Game.safe_loops(mi.create_tween())
		tw.tween_method(func(k: float):
			if is_instance_valid(mi):
				mi.rotation = sp * k, 0.0, 2.0, 2.0)
	return root


## Taş kırıntıları / biber tozu taneleri: ayrı ayrı uçan küçük parçalar (duman bulutu değil)
static func _specks(p: Vector3, n: int, mesh: Mesh, spd: float, rise: float, grav: float, life: float) -> void:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree) or (ml as SceneTree).current_scene == null:
		return
	for k in n:
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(ml as SceneTree).current_scene.add_child(mi)
		mi.global_position = p
		var a = randf() * TAU
		var r = sqrt(randf())
		var vel = Vector3(cos(a) * r, randf_range(0.1, 1.0) * rise, sin(a) * r) * spd * randf_range(0.5, 1.0)
		var l = life * randf_range(0.65, 1.0)
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				var dr = (1.0 - exp(-t * 3.0)) / 3.0   # hava frenler: tanecik yavaşlar, süzülür
				mi.global_position = p + vel * dr + Vector3.DOWN * grav * t * t
				mi.scale = Vector3.ONE * (1.0 - smoothstep(0.6, 1.0, t / l)), 0.0, l, l)
		tw.tween_callback(mi.queue_free)


static func _chips(p: Vector3, n := 5) -> void:
	_specks(p, n, _mesh("chip", func(b: MB): b.add("box", Vector3.ZERO, Vector3(0.018, 0.014, 0.02), STONE)), 3.0, 0.9, 5.0, 0.32)


static func _pebble(who: Node3D, from: Vector3, vel: Vector3, dmg: float, o := {}) -> Projectile:
	var cb: Callable = o.get("hit", Callable())
	var land = func(pos: Vector3, tgt: Node3D) -> void:
		_chips(pos, int(o.get("chips", 5)))
		Sfx.play("hit_claw" if tgt != null else "clink", pos, randf_range(0.8, 1.0), 0.45)
		if cb.is_valid():
			cb.call(pos, tgt)
	return U.fire(who, from, vel, {"g": float(o.get("g", GRAV)), "r": float(o.get("r", 0.1)), "life": float(o.get("life", 2.2)), "hit": land,
		"vis": _vis(o.get("mesh", _stone_mesh())),
		"info": {"dmg": dmg, "knock": float(o.get("knock", 1.5)), "kind": str(o.get("kind", "light")), "hitstop": 0.02, "launch": float(o.get("launch", 0.0))}})


## Mizukiri: yere çarpınca sekip hedefe yönelir (kalan sekme kadar)
static func _skip(who: Node3D, from: Vector3, tg: Node3D, fall: Vector3, dmg: float, hops: int) -> void:
	var on = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt != null or hops <= 0 or not is_instance_valid(who):
			return
		if pos.y - Game.ground_height(pos.x, pos.z) > 0.7:
			return   # havada söndü ya da duvara çarptı: sekmez
		var nxt = pos + Vector3.UP * 0.12
		var aim: Vector3 = U.chest(tg) if U.alive(tg) else nxt + Vector3(fall.x, 0.0, fall.z).normalized() * 5.0
		var rest = aim - nxt
		var low = nxt + rest * (0.55 if hops > 1 else 1.0)
		if hops > 1:
			low.y = Game.ground_height(low.x, low.z)
		var nv = U.solve(nxt, low, SPEED * 0.8, GRAV)
		_skip(who, nxt, tg, nv, dmg * 1.15, hops - 1)
	_pebble(who, from, fall, dmg, {"hit": on, "chips": 3})


## Tōgarashi-dama: tane tane kızıl toz saçılır. Müttefikin (ve atanın) genjutsusu bozulur, düşmanın gözü yanar.
static func pepper_burst(who: Node3D, p: Vector3, dmg: float) -> void:
	var red = _mesh("dust", func(b: MB): b.add("sphere", Vector3.ZERO, Vector3(0.028, 0.028, 0.028), Color(0.82, 0.22, 0.08), Vector3.ZERO, 5))
	var org = _mesh("dust2", func(b: MB): b.add("sphere", Vector3.ZERO, Vector3(0.02, 0.02, 0.02), Color(0.92, 0.52, 0.14), Vector3.ZERO, 5))
	_specks(p, 34, red, 7.5, 0.7, 0.5, 1.5)
	_specks(p, 22, org, 5.0, 1.0, 0.35, 1.8)
	Sfx.play("clink", p, 1.5, 0.3)
	if not is_instance_valid(who):
		return
	for f in who.get_tree().get_nodes_in_group("fighters"):
		if not is_instance_valid(f) or f.is_dead() or f.get("statuses") == null:
			continue
		var d = f.global_position.distance_to(p)
		if Combat.hostile(who, f):
			if d < GAS_R:
				f.apply_status("slow", 2.5)
				if f.has_method("lose_target"):
					f.lose_target(1.8)   # gözü yanan düşman hedefini kaybeder
				f.take_hit({"dmg": dmg * 0.3, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "melee": false})
				Combat.popup_text(f.global_position + Vector3.UP * 2.2, "Gözü yandı!", Color(1.0, 0.55, 0.25))
		elif d < KAI_R:
			var had = false
			for s in ["fear", "kokuangyo", "stun"]:   # oyuncunun Kai'si ile aynı durumlar
				if f.statuses.has(s):
					f.statuses.erase(s)
					had = true
			if had:
				if f is Player:
					f.input_locked = 0.0
				Combat.popup_text(f.global_position + Vector3.UP * 2.2, "Genjutsu bozuldu!", Color(1.0, 0.75, 0.4))


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var p = U.aim_at(who, U.target_of(who))
	U.face(who, p)
	var rig = rig_of(who)
	if rig != null:
		rig.ball.mesh = _pepper_mesh() if i == 4 else (_big_stone_mesh() if i == 5 else _stone_mesh())   # kesedeki mermi adımın mermisi
		rig.engage((p - U.bone_pos(who, "LeftHand")).normalized(), float(A.HOOK[clampi(i, 0, 5)]))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var n = U.weapon_node(who, "sapan_catal")
	var from: Vector3 = n.to_global(Vector3(0.05, 0.0, 0.12)) if n != null else who.global_position + Vector3.UP * 1.4 + who.face_dir() * 0.6
	var rig = rig_of(who)
	if rig != null:
		rig.release()
	Sfx.play("whoosh", from, 1.5, 0.3)
	match i:
		0, 1:
			_pebble(who, from, U.solve(from, aim, SPEED, GRAV), dmg * 0.8)
		2:   # Futatsu: kesede iki taş, hafif ayrılır
			var side = Vector3.UP.cross((aim - from).normalized()).normalized()
			for sg in [-1.0, 1.0]:
				_pebble(who, from, U.solve(from, aim + side * sg * 0.55, SPEED, GRAV), dmg * 0.55)
		3:   # Mizukiri: önce yere, iki sekmeyle hedefe (sekmede güçlenir, kalkan arkasına alttan girer)
			var mid = from.lerp(aim, 0.45)
			mid.y = Game.ground_height(mid.x, mid.z)
			_skip(who, from, tg, U.solve(from, mid, SPEED, GRAV), dmg * 0.6, 2)
		4:   # Tōgarashi-dama: yüksek yay, çarptığı yerde patlar (kanon)
			var at = func(pos: Vector3, _t: Node3D) -> void:
				pepper_burst(who, pos + Vector3.UP * 0.4, dmg)
			_pebble(who, from, U.lob(from, aim, 0.85, GRAV), dmg * 0.2, {"mesh": _pepper_mesh(), "hit": at, "chips": 0, "r": 0.14})
		5:   # Ō-tsubute: lastik sonuna kadar; ağır taş yere serer. Chakra lastiği güçlendirir (Pachinko no Jutsu esinli)
			var hard = U.pay(who, 0.04)
			_pebble(who, from, U.solve(from, aim, SPEED * 1.35, GRAV), dmg * (1.9 if hard else 1.3), {"mesh": _big_stone_mesh(), "r": 0.2, "knock": 13.0 if hard else 7.0,
				"launch": 3.0 if hard else 0.0, "kind": "heavy", "chips": 9})
			if who is Player and Game.world:
				Game.world.env.add_shake(0.2)
