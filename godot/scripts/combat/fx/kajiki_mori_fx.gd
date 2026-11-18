extends RefCounted
## Kajiki Mori (marlin zıpkını; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/kajiki_mori_fx.gd). Kanon (Narutopedia "Marlin Harpoon", Isari / Araumi Funato, anime 233):
## uzun saplı, halatlı, marlin iskeleti başlı zıpkın; kaya ve çeliği deler. Uyanınca büyür, metal tam gövdeli marlin olur, balık gibi havada yüzer; değdiği chakrayı (Rasengan dahil) hızla yutar. Samehada'nın benzeri.
## Görünüş refs/kajiki_mori: kızıl sap, kemik baş, tek göz; uyanmış hâl: sıra sıra sırt yüzgeci, kızıl göz, dişler.
## Oyunda: her isabet chakra içer; 6 yudumda uyanır (14 sn). Uyanıkken daha çok içer, ağza gelen chakra mermilerini yutar, bitirişte elden çıkıp kendi yüzer. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const ID := "kajiki_mori"
const TIP := 1.75
const SIPS := 6
const AWAKE_T := 14.0
const SIP := 5.0
const SIP_AWAKE := 10.0
const THROW_R := 12.0

const SIP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float d = 0.5 + 0.5 * sin(UV.x * 26.0 + TIME * 24.0);
	ALBEDO = mix(vec3(0.2, 0.45, 1.0), vec3(0.8, 0.92, 1.0), d);
	ALPHA = smoothstep(0.2, 0.8, v) * d * fade_k;
}
"""


static func _pole(b: MB) -> void:
	var red = Color(0.52, 0.12, 0.16)
	b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.042, 1.74, 0.042), red, Vector3(90, 0, 0), 8)
	b.add("torus", Vector3(0, 0, -0.8), Vector3(0.07, 0.07, 0.07), Color(0.6, 0.6, 0.62), Vector3(0, 0, 90), 10)


## Kemik baş: uyumuş hâl (Isari's_Blade.png)
static func model(b: MB) -> void:
	_pole(b)
	var w = Color(0.9, 0.9, 0.87)
	var side = Color(0.62, 0.62, 0.6)
	var o := PackedVector2Array([Vector2(0.0, 0.92), Vector2(0.018, 1.2), Vector2(0.13, 1.28), Vector2(0.055, 1.36), Vector2(0.09, 1.46), Vector2(0.03, 1.5), Vector2(0.0, 1.95),
		Vector2(-0.035, 1.56), Vector2(0.0, 1.5), Vector2(-0.11, 1.5), Vector2(-0.05, 1.38), Vector2(-0.2, 1.3), Vector2(-0.03, 1.28), Vector2(-0.018, 1.1)])
	b.add_slab(o, 0.022, w, Transform3D.IDENTITY, Callable(), side)
	for k in 4:   # kaburga dikenleri
		var z = 0.98 + k * 0.075
		var h = 0.13 + k * 0.012
		for s in [-1.0, 1.0]:
			var r := PackedVector2Array([Vector2(0.0, z), Vector2(s * h, z - 0.05), Vector2(0.0, z + 0.03)])
			b.add_slab(r, 0.014, w, Transform3D.IDENTITY, Callable(), side)
	b.add("cyl", Vector3(0, 0.03, 1.42), Vector3(0.05, 0.03, 0.05), Color(0.08, 0.08, 0.09), Vector3(0, 0, 90), 10)
	b.add("cyl", Vector3(0, 0.03, 1.42), Vector3(0.026, 0.034, 0.026), w, Vector3(0, 0, 90), 8)


## Uyanmış: tam gövdeli metal marlin (Isari's_Weapon.png)
static func model_awake(b: MB) -> void:
	_pole(b)
	var m = Color(0.7, 0.68, 0.8)
	var d = Color(0.42, 0.41, 0.5)
	var body := PackedVector2Array([Vector2(0.03, 0.9), Vector2(0.15, 1.2), Vector2(0.19, 1.55), Vector2(0.12, 1.86), Vector2(0.03, 2.05), Vector2(0.0, 2.55), Vector2(-0.03, 2.05), Vector2(-0.03, 1.98), Vector2(-0.1, 1.86), Vector2(-0.17, 1.55), Vector2(-0.14, 1.2), Vector2(-0.03, 0.9)])
	var thick = func(p: Vector2) -> float:
		return lerpf(0.11, 0.015, clampf(absf(p.x) / 0.19, 0.0, 1.0))
	b.add_slab(body, 0.1, m, Transform3D.IDENTITY, thick, d)
	for k in 9:   # sırt yüzgeçleri
		var z = 0.98 + k * 0.085
		var h = 0.3 - absf(float(k) - 4.0) * 0.022
		var r := PackedVector2Array([Vector2(0.1, z - 0.05), Vector2(0.14 + h, z - 0.13), Vector2(0.12, z + 0.04)])
		b.add_slab(r, 0.02, m if k % 2 == 0 else d, Transform3D.IDENTITY, Callable(), d)
	for s in [-1.0, 1.0]:
		var f := PackedVector2Array([Vector2(-0.12, 1.5), Vector2(-0.42, 1.2), Vector2(-0.1, 1.62)])
		b.add_slab(f, 0.016, d, Transform3D(Basis(Vector3.BACK, s * 0.55), Vector3.ZERO), Callable(), d)
	for k in 6:   # dişler
		b.add("cone", Vector3(0, -0.05, 1.92 - k * 0.04), Vector3(0.012, 0.04, 0.012), Color(0.95, 0.95, 0.96), Vector3(180, 0, 0), 4)
	for s in [-1.0, 1.0]:
		b.add("sphere", Vector3(s * 0.05, 0.05, 1.8), Vector3.ONE * 0.05, Color(0.95, 0.12, 0.12), Vector3.ZERO, 8)


static func _rope() -> Mesh:
	return Yk.mesh("kajiki_halat", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.016, 0.08, 0.016), Color(0.72, 0.65, 0.48), Vector3(90, 0, 0), 5)
		return b.build(Props.toon()))


## Sap dibindeki halkadan sarkan halat
static func attach(node: Node3D) -> void:
	Yk.chain(node, _rope(), func(): return node.global_transform * Vector3(0, 0, -0.84), func():
		return node.global_transform * Vector3(0, 0, -0.84) + Vector3.DOWN * 0.5 + node.global_transform.basis.z * -0.12, INF, 9, 0.07, 0.1)


# ------------------------------------------------------------------ açlık
static func awake(who: Node3D) -> bool:
	return Game.now() < float(who.get_meta("kj_ayak", 0.0))


static func _swap(who: Node3D, on: bool) -> void:
	var n = Yk.node_of(who, ID)
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("kajiki_mori_o" if on else ID)


static func _wake(who: Node3D) -> void:
	who.set_meta("kj_ayak", Game.now() + AWAKE_T)
	who.set_meta("kj_n", 0)
	_swap(who, true)
	Sfx.play("roar", who.global_position, 1.6, 0.6)
	Combat.popup_text(who.global_position + Vector3.UP * 2.5, "Marlin uyandı!", Color(0.8, 0.82, 1.0))
	Yk.after(who, AWAKE_T + 0.05, func():
		if not awake(who):
			_swap(who, false))


static func _gain(who: Node3D, v: float) -> void:
	if who.get("chakra") != null:
		who.chakra = minf(float(who.max_chakra), float(who.chakra) + v)


static func _stream(a: Vector3, b: Vector3) -> void:
	var pts = []
	for k in 6:
		var u = k / 5.0
		pts.append(a.lerp(b, u) + Vector3.UP * sin(u * PI) * 0.2)
	Yk.fade(Yk.strip(pts, 0.05, Yk.mat("kajiki_chakra", SIP_SH), 0.4), 0.08, 0.16)


## İsabet: chakra içer
static func on_hit(who: Node3D, _i: int, h: Node3D) -> void:
	var take = SIP_AWAKE if awake(who) else SIP
	var got = 0.0
	if h.get("chakra") != null:
		got = minf(take, float(h.chakra))
		h.chakra = maxf(0.0, float(h.chakra) - take)
	if got <= 0.0:
		return
	_gain(who, got)
	_stream(h.global_position + Vector3.UP, who.global_position + Vector3.UP * 1.3)
	if not awake(who):
		var n = int(who.get_meta("kj_n", 0)) + 1
		who.set_meta("kj_n", n)
		if n >= SIPS:
			_wake(who)


## Uyanıkken ağız önündeki chakra mermilerini yutar (kanon: Rasengan bile)
static func _swallow(who: Node3D, at: Vector3) -> void:
	for p in who.get_tree().get_nodes_in_group("projectiles"):
		if p.dead or (p.info.get("element", "") in [null, ""]) or p.shooter == null or not is_instance_valid(p.shooter) or not Combat.hostile(who, p.shooter):
			continue
		if p.global_position.distance_to(at) < 2.6:
			_stream(p.global_position, at)
			_gain(who, 6.0)
			p.dead = true
			p.queue_free()
			Combat.popup_text(at + Vector3.UP, "Yuttu!", Color(0.7, 0.85, 1.0))


# ------------------------------------------------------------------ fırlatma / yüzme
static func _copy(who: Node3D) -> MeshInstance3D:
	var c = MeshInstance3D.new()
	c.mesh = CharacterModel.weapon_mesh("kajiki_mori_o" if awake(who) else ID)
	Yk.root().add_child(c)
	return c


static func _hide(who: Node3D, on: bool) -> void:
	var n = Yk.node_of(who, ID)
	if n != null:
		n.visible = not on


static func _throw(who: Node3D, dmg: float) -> void:
	var f = Yk.face(who)
	var a: Vector3 = Yk.hand(who)
	var tg = U.target_of(who)
	var end: Vector3 = U.chest(tg) if U.alive(tg) and a.distance_to(U.chest(tg)) < THROW_R else a + f * THROW_R
	var d = (end - a).normalized()
	var c = _copy(who)
	var b = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	_hide(who, true)
	var rope = Yk.chain(Yk.root(), _rope(), func(): return Yk.hand(who) if is_instance_valid(who) else a, func(): return (c.global_transform * Vector3(0, 0, -0.84)) if is_instance_valid(c) else a, 0.72, 120, 0.1, 0.25)
	var tip = TIP
	var tw = c.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(c):
			c.global_transform = Transform3D(b, a.lerp(end - d * tip, u)), 0.0, 1.0, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(who):
			for h in Combat.hit_sphere(who, end, 1.3, {"dmg": dmg, "knock": 1.0, "kind": "heavy", "hitstop": 0.06, "melee": false, "bleed": 2.0}):
				on_hit(who, 3, h)
				if h is CharacterBody3D:
					h.velocity = (who.global_position - h.global_position).normalized() * 13.0 + Vector3.UP * 2.0
			Sfx.play("hit_claw", end, 0.8, 0.8))
	tw.tween_interval(0.1)
	tw.tween_method(func(u: float):
		if is_instance_valid(c) and is_instance_valid(who):
			c.global_position = (end - d * tip).lerp(Yk.hand(who), u), 0.0, 1.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(who):
			_hide(who, false)
		if is_instance_valid(rope):
			rope.queue_free()
		c.queue_free())
	Sfx.play("whoosh", a, 0.8, 0.8)


## Uyanmış marlin elden çıkar, rakipten rakibe yüzer, döner
static func _swim(who: Node3D, dmg: float) -> void:
	var c = _copy(who)
	_hide(who, true)
	var s = {"t": 0.0, "p": Yk.hand(who), "v": Yk.face(who) * 16.0, "next": 0.0}
	var LIFE = 1.05
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or who.is_dead():
			c.queue_free()
			return true
		s["t"] += dt
		var t: float = s["t"]
		var p: Vector3 = s["p"]
		var v: Vector3 = s["v"]
		var goal: Vector3 = Yk.hand(who)
		if t < LIFE:
			var tg = Combat.nearest_enemy(who, 16.0)
			goal = U.chest(tg) if tg != null else who.global_position + Yk.face(who) * 8.0 + Vector3.UP * (1.3 + sin(t * 9.0))
		var want: Vector3 = (goal - p).normalized() * 19.0 + Vector3.UP * sin(t * 11.0) * 2.5
		v = v.lerp(want, minf(1.0, dt * 6.0))
		p += v * dt
		s["p"] = p
		s["v"] = v
		if v.length() > 0.1:
			var d = v.normalized()
			c.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT), p - d * TIP)
		if t >= float(s["next"]):
			s["next"] = t + 0.2
			_swallow(who, p)
			for h in Combat.hit_sphere(who, p, 1.3, {"dmg": dmg * 0.34, "knock": 3.0, "kind": "heavy", "hitstop": 0.03, "melee": false}):
				on_hit(who, 5, h)
		if t >= LIFE and p.distance_to(goal) < 1.4 or t > LIFE + 1.0:
			_hide(who, false)
			c.queue_free()
			return true
		return false
	load("res://scripts/combat/fx/alet_kit.gd").ticker(who.global_position, fn)
	Sfx.play("roar", who.global_position, 1.9, 0.5)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	var head: Vector3 = who.global_position + Vector3.UP * 1.3 + f * 2.2
	if awake(who):
		_swallow(who, head)
	match i:
		3:
			_throw(who, dmg)
		5:
			if awake(who):
				_swim(who, dmg)
			else:
				Combat.hit_zone(who, who.global_position, f, 3.8, 16.0, 2.2, {"dmg": dmg * 1.5, "knock": 11.0, "kind": "heavy", "hitstop": 0.07, "melee": true, "bleed": 3.0})
				Yk.shake(who, 0.3)
