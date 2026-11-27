extends RefCounted
## Kusari-fundo: model, eller arasında sarkan zincir, uçan ağırlık, karşılama ve bağlayıp atma — ortak efekt yok.
## Kaynak: Wikipedia "Kusari-fundo" (30-120 cm zincir, iki ucunda eş ağırlık), kanon: Izumo ve Kotetsu zincirle Kakuzu'yu sarıp hareketsiz bırakır.
## Oyun için zincir savururken ~3 m'ye uzar (görsel uyarlama). Yüzde indirim yok: Kusari Uke yakın dövüş darbesini tam yakalar ya da hiç.
## Oyuncu ve düşman aynı kod.

const ID := "kusari_fundo"
const REACH := 3.0
const UKE_T := 0.46
const BIND_T := 1.5
const MAX_H := 3.4

static var _c := {}


class Chain extends MultiMeshInstance3D:
	var a: Node3D
	var b: Node3D
	var slack := 0.32
	var mid := Vector3.ZERO
	var vel := Vector3.ZERO
	var init := false
	const N := 90       # en çok halka; görünen sayı zincir boyundan (halka aralığı PITCH)
	const PITCH := 0.048

	func setup(link: Mesh, mat: Material) -> void:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link
		mm.instance_count = N
		mm.visible_instance_count = 14
		multimesh = mm
		material_override = mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top_level = true
		custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)

	func _process(dt: float) -> void:
		if not is_instance_valid(a) or not is_instance_valid(b):
			visible = false
			return
		var A: Vector3 = a.global_position
		var cam = get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(A) > 1600.0:
			visible = false
			return
		visible = a.is_visible_in_tree() or b.is_visible_in_tree()
		# düğüm sol elin konumunda: custom_aabb (+-30 m) düğüme göre; eskiden dünya merkezindeydi -> haritada merkezden 30 m ötede
		# zincir görüş alanı dışı sayılıp hiç çizilmiyordu (saldırıda uçan ağırlığın zinciri görünmüyordu)
		global_transform = Transform3D(Basis.IDENTITY, A)
		var B: Vector3 = b.global_position
		var L = A.distance_to(B)
		var want = (A + B) * 0.5 + Vector3.DOWN * maxf(0.02, slack - L * 0.28)   # eller açılınca zincir gerilir
		if not init:
			mid = want
			init = true
		var d = minf(dt, 0.033)
		vel += (want - mid) * 110.0 * d
		vel *= exp(-8.0 * d)
		mid += vel * d
		# halka sayısı zincir boyuna göre (eskiden 14 halka 3 m'ye gerilip kesik kesik çizgi gibi görünüyordu)
		var arc = A.distance_to(mid) + mid.distance_to(B)
		var n = clampi(int(ceil(arc / PITCH)), 8, N)
		multimesh.visible_instance_count = n
		var stretch = clampf((arc / n) / 0.04, 1.2, 1.6)
		var prev = A
		for i in n:
			var u = (i + 0.5) / n
			var p = A.lerp(mid, u).lerp(mid.lerp(B, u), u)
			var dir = p - prev
			dir = dir.normalized() if dir.length() > 0.001 else Vector3.UP
			var x = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
			if i % 2 == 1:
				x = x.rotated(dir, PI * 0.5)
			multimesh.set_instance_transform(i, Transform3D(Basis(dir * stretch, x, dir.cross(x)), p - A))
			prev = p


# ------------------------------------------------------------------ model
## Avuçta duran sekizgen demir ağırlık (+Z uç), zincire bağlanan büyük ilk halka
static func model(b: MB) -> void:
	var iron = Color(0.24, 0.25, 0.28)
	var dark = Color(0.13, 0.13, 0.15)
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.058, 0.13, 0.058), iron, Vector3(90, 0, 0), 8)
	for z in [-0.03, 0.09]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.066, 0.016, 0.066), dark, Vector3(90, 0, 0), 8)
	b.add("torus", Vector3(0, 0, -0.06), Vector3(0.05, 0.05, 0.05), dark, Vector3(90, 0, 0), 8)


static func _link() -> Mesh:
	if not _c.has("mesh:link"):
		var t = TorusMesh.new()
		t.inner_radius = 0.014
		t.outer_radius = 0.026
		t.rings = 8
		t.ring_segments = 5
		_c["mesh:link"] = t
	return _c["mesh:link"]


## Silah kurulumunda (sol el eklenince): iki avuç arasına zincir
static func attach_chain(weapons: Array) -> void:
	var r = _w(weapons, "Right")
	var l = _w(weapons, "Left")
	if r.is_empty() or l.is_empty():
		return
	var c = Chain.new()
	if not _c.has("mat:chain"):
		_c["mat:chain"] = LazyFx.g("Props").toon_color(Color(0.17, 0.17, 0.2), 0.35)
	c.setup(_link(), _c["mat:chain"])
	c.a = l["node"]
	c.b = r["node"]
	(r["hand"] as Node3D).add_child(c)   # ağırlığın altına değil: ağırlık uçarken gizlenince zincir de kaybolurdu
	(r["node"] as Node3D).set_meta("kf_chain", c)


static func _w(weapons: Array, side: String) -> Dictionary:
	for w in weapons:
		if LazyFx.g("Gear").base_id(String(w["id"])) == ID and String(w["side"]) == side and is_instance_valid(w["node"]):
			return w
	return {}


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _weapons(who: Node3D) -> Array:
	var m = who.get("model")
	return m.weapons if m != null and m is CharacterModel else []


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _foe(who: Node3D, r: float) -> Node3D:
	var best: Node3D = null
	var bd = r
	for x in who.get_tree().get_nodes_in_group("fighters"):
		if x == who or not Combat.hostile(who, x) or x.is_dead():
			continue
		var d = (x as Node3D).global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = x
	return best


static func _after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


static func _h(n: Node3D) -> float:
	return float(n.get("height")) if n.get("height") != null else 1.8


# ------------------------------------------------------------------ uçan ağırlık
## side elindeki ağırlık çıkar; zincir öbür elden ona uzar. path(k, el) -> konum, tick(k, konum) isteğe bağlı
static func _fly(who: Node3D, side: String, T: float, path: Callable, tick := Callable()) -> void:
	var root = _root()
	var ws = _weapons(who)
	var w = _w(ws, side)
	var other = _w(ws, "Left" if side == "Right" else "Right")
	var rw = _w(ws, "Right")
	if root == null or w.is_empty() or other.is_empty() or rw.is_empty():
		return
	var n: Node3D = w["node"]
	var ch = (rw["node"] as Node3D).get_meta("kf_chain", null)
	if not is_instance_valid(ch):
		return
	var tok = int(who.get_meta("kf_tok", 0)) + 1
	who.set_meta("kf_tok", tok)
	var fly = MeshInstance3D.new()
	fly.mesh = CharacterModel.weapon_mesh(ID)
	root.add_child(fly)
	fly.global_transform = n.global_transform
	n.visible = false
	ch.a = other["node"]
	ch.b = fly
	var tw = fly.create_tween()
	var step = func(k: float) -> void:
		if not is_instance_valid(fly) or not is_instance_valid(who) or not is_instance_valid(n):
			return
		var p: Vector3 = path.call(k, n.global_position)
		var d: Vector3 = p - fly.global_position
		fly.global_position = p
		if d.length() > 0.01:
			fly.look_at(p + d, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
		if tick.is_valid():
			tick.call(k, p)
	var done = func() -> void:
		if is_instance_valid(fly):
			fly.queue_free()
		if is_instance_valid(n):
			n.visible = true
		if is_instance_valid(ch) and is_instance_valid(who) and int(who.get_meta("kf_tok", 0)) == tok:
			var l = _w(_weapons(who), "Left")
			var r = _w(_weapons(who), "Right")
			if not l.is_empty() and not r.is_empty():
				ch.a = l["node"]
				ch.b = r["node"]
	tw.tween_method(step, 0.0, 1.0, T)
	tw.tween_callback(done)


## Düz çakış: ağırlık gider, zincirle döner
static func _flick(who: Node3D, side: String, T := 0.32) -> void:
	var f = _face(who)
	var tg = _foe(who, REACH + 1.5)
	var path = func(k: float, hand: Vector3) -> Vector3:
		var far: Vector3 = hand + f * REACH
		if tg != null and is_instance_valid(tg):
			far = tg.global_position + Vector3.UP * _h(tg) * 0.6
		return hand.lerp(far, sin(k * PI))
	_fly(who, side, T, path)
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 1.4, 0.7)


## Baş üstünde çevirme
static func _whirl(who: Node3D, T: float) -> void:
	var a0 = randf() * TAU
	var path = func(k: float, hand: Vector3) -> Vector3:
		var a = a0 + k * TAU * 3.0
		var r = REACH * 0.9 * sin(minf(k * 5.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.86, 1.0, k))
		return hand + Vector3(cos(a), 0.12, sin(a)) * r
	_fly(who, "Right", T, path)
	Sfx.play("swing_chain", who.global_position + Vector3.UP * 2.0, 1.1, 0.8)


# ------------------------------------------------------------------ Karami: dolanıp bağlar
static func _wrap(who: Node3D, dmg: float) -> void:
	var f = _face(who)
	var tg = _foe(who, 7.5)
	var st = {"done": false}
	var T = 0.68
	var path = func(k: float, hand: Vector3) -> Vector3:
		var c: Vector3 = hand + f * 4.5
		var live = tg != null and is_instance_valid(tg) and not tg.is_dead()
		if live:
			c = tg.global_position + Vector3.UP * _h(tg) * 0.55
		if k < 0.3:
			return hand.lerp(c, k / 0.3)
		if k < 0.72 and live:
			var u = (k - 0.3) / 0.42
			var a = u * TAU * 2.0
			var r = (float(tg.get("radius")) if tg.get("radius") != null else 0.4) + 0.2
			return c + Vector3(cos(a) * r, (u - 0.5) * 0.7, sin(a) * r)
		return c.lerp(hand, clampf((k - 0.72) / 0.28, 0.0, 1.0))
	var tick = func(k: float, _p: Vector3) -> void:
		if k < 0.34 or bool(st["done"]) or tg == null or not is_instance_valid(tg) or tg.is_dead():
			return
		st["done"] = true
		tg.take_hit({"dmg": dmg * 0.7, "knock": 0.0, "kind": "light", "hitstop": 0.05, "melee": true, "attacker": who, "dir": f})
		if _h(tg) <= MAX_H and tg.has_method("apply_status"):
			tg.apply_status("bind", BIND_T)
			who.set_meta("kf_bound", tg.get_instance_id())
			who.set_meta("kf_bound_t", Game.now() + BIND_T + 0.4)
			Combat.popup_text(tg.global_position + Vector3.UP * (_h(tg) + 0.3), "Zincirlendi!", Color(0.8, 0.84, 0.92))
		Sfx.play("hit_chain", tg.global_position + Vector3.UP, 1.0, 0.85)
	_fly(who, "Right", T, path, tick)


static func _bound(who: Node3D) -> Node3D:
	if Game.now() > float(who.get_meta("kf_bound_t", 0.0)):
		return null
	var o = instance_from_id(int(who.get_meta("kf_bound", 0)))
	return o if o != null and is_instance_valid(o) and o is Node3D and not o.is_dead() else null


# ------------------------------------------------------------------ Shime Nage
static func _throw_over(who: Node3D, h: Node3D, dmg: float) -> void:
	var f = _face(who)
	var from = h.global_position
	var to = who.global_position - f * 2.6
	to.y = Game.ground_height(to.x, to.z) + 0.05
	var T = 0.42
	who.set_meta("kf_bound_t", 0.0)
	if h.has_method("apply_status"):
		h.apply_status("bind", T + 0.1)
	var tw = h.create_tween()
	var arc = func(k: float) -> void:
		if is_instance_valid(h):
			h.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 3.0
			if h is CharacterBody3D:
				h.velocity = Vector3.ZERO
	var land = func() -> void:
		if not is_instance_valid(h) or not is_instance_valid(who):
			return
		h.global_position = PlayerCombat.safe_dest(h, to + Vector3.UP * 0.1, to)
		h.take_hit({"dmg": dmg * 1.7, "knock": 2.0, "kind": "heavy", "stun": 0.5, "hitstop": 0.1, "melee": true, "attacker": who, "dir": -f})
		Sfx.play("hit_heavy", to, 0.8, 1.0)
		if who is Player and Game.world:
			Game.world.env.add_shake(0.55)
	tw.tween_method(arc, 0.0, 1.0, T)
	tw.tween_callback(land)
	Sfx.play("hit_chain", from + Vector3.UP, 0.7, 0.9)


# ------------------------------------------------------------------ Kusari Uke (Player/Enemy.take_hit)
## Gergin zincir önden gelen yakın dövüş darbesini tam yakalar; ağır darbe ve jutsu geçer
static func parry(who: Node3D, info: Dictionary) -> bool:
	if not who.has_meta("kf_uke") or Game.now() > float(who.get_meta("kf_uke")):
		return false
	if not bool(info.get("melee", false)) or info.get("sure", false) or int(info.get("tier", -1)) >= 0:
		return false
	if str(info.get("kind", "light")) in ["heavy", "launch"]:
		return false
	var atk = info.get("attacker")
	if not (atk is Node3D) or not is_instance_valid(atk):
		return false
	var to: Vector3 = atk.global_position - who.global_position
	to.y = 0.0
	if to.length() < 0.05 or to.normalized().dot(_face(who)) < 0.3:
		return false
	who.remove_meta("kf_uke")
	Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Zincirle Yakalandı!", Color(0.85, 0.9, 0.98))
	Sfx.play("hit_chain", who.global_position + Vector3.UP * 1.3, 1.3, 0.9)
	if atk.has_method("stagger"):
		atk.stagger(0.6)
	elif atk.has_method("apply_status"):
		atk.apply_status("stun", 0.45)
	return true


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	if i == 0:
		_after(who, 0.12, _flick.bind(who, "Right", 0.32))
	elif i == 1:
		_after(who, 0.13, _flick.bind(who, "Left", 0.32))
	elif i == 2:
		_after(who, 0.08, _uke.bind(who))
	elif i == 3:
		_after(who, 0.12, _whirl.bind(who, 0.74))


static func _uke(who: Node3D) -> void:
	who.set_meta("kf_uke", Game.now() + UKE_T)
	Sfx.play("clink", who.global_position + Vector3.UP * 1.4, 0.9, 0.5)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i == 4:
		_wrap(who, dmg)
	elif i == 5:
		var h = _bound(who)
		if h != null and h.global_position.distance_to(who.global_position) < 9.0:
			_throw_over(who, h, dmg)
		else:
			_flick(who, "Right", 0.3)
			_after(who, 0.33, _flick.bind(who, "Left", 0.26))
			var c = who.global_position + Vector3.UP * 1.1 + _face(who) * 2.3
			Combat.hit_sphere(who, c, 1.7, {"dmg": dmg * 1.15, "knock": 9.0, "kind": "heavy", "hitstop": 0.08, "melee": true})
