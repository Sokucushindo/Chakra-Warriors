extends RefCounted
## Oni no Kote: model, dikenli zincir, zehirli pençe — kendi şekilleri ve gölgelendiricisi.
## Kaynak refs/oni_kote: çok parçalı gri kabuk, koyu oyuk, perçinler, kıvrık bıçaklar, parmak uçlarında pençe; zincir = delikli kalın halka + iki yana diken.
## Kanon: zincir hedefi bağlar ve parçalar; iki kardeş arasında gerilir; zincir etkisizleşince düzenek serbest bırakır, zehirli pençeyle saldırılır.
## Oyuncu ve düşman aynı kod. Yoldaş da aynı eldivenliyse zincir ikisinin arasında gerilir.

const Kit = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "oni_kote"
const CHAIN_R := 9.0
const REGROW := 10.0      # bırakılan zincirin yerine yenisinin sarılması
const BIND_T := 1.5
const POISON := 1.6
const POISON_BARE := 3.2  # zincirsiz kol: pençe asıl silah

const CLAW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float m = smoothstep(0.1, 0.45, v) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	ALBEDO = mix(vec3(0.24, 0.42, 0.2), vec3(0.86, 0.9, 0.82), smoothstep(0.55, 0.95, v));
	ALPHA = m * fade_k;
	if (ALPHA < 0.02) discard;
}
"""


# ------------------------------------------------------------------ model
## Ön kol ekseni +Z (bilek yönü); kabuk bileği örter, pençe elin önüne uzanır
static func model(b: MB) -> void:
	var steel = Color(0.72, 0.72, 0.78)
	var shade = Color(0.5, 0.5, 0.56)
	var dark = Color(0.09, 0.09, 0.11)
	var pts = [Vector3(0, 0, -0.13), Vector3(0, 0, -0.06), Vector3(0, 0, 0.05), Vector3(0, 0, 0.16), Vector3(0, 0, 0.23)]
	Loft.tube(b, pts, [0.07, 0.115, 0.135, 0.12, 0.085], shade, 16, 3)
	var petal := PackedVector2Array([Vector2(-0.05, -0.1), Vector2(0.05, -0.1), Vector2(0.065, 0.06), Vector2(0.0, 0.17), Vector2(-0.065, 0.06)])
	for k in 7:   # üst üste binen zırh plakaları + perçin
		var a = k * TAU / 7.0
		var n = Vector3(cos(a), sin(a), 0)
		var t = Vector3(-sin(a), cos(a), 0)
		var xf = Transform3D(Basis(n, t, Vector3.BACK).rotated(t, -0.12), n * 0.137 + Vector3(0, 0, 0.03))
		b.add_slab(petal, 0.008, steel if k % 2 == 0 else steel.darkened(0.08), xf, Callable(), shade.darkened(0.2))
		b.add("sphere", n * 0.147 + Vector3(0, 0, -0.03), Vector3.ONE * 0.016, dark, Vector3.ZERO, 5)
	b.add_xf("cyl", Transform3D(Basis(Vector3.UP * 0.075, Vector3.RIGHT * 0.012, Vector3.FORWARD * 0.075), Vector3(0.14, 0, 0.02)), dark, 12)   # yandaki yuvarlak oyuk
	var crescent := PackedVector2Array([Vector2(0.0, -0.08), Vector2(0.05, -0.05), Vector2(0.1, 0.03), Vector2(0.14, 0.15), Vector2(0.075, 0.06), Vector2(0.025, 0.02)])
	var thin = func(p: Vector2) -> float:
		return lerpf(0.02, 0.003, clampf(p.x / 0.14, 0.0, 1.0))
	for a in [0.8, 2.3, 3.9, 5.4]:   # kenardan fışkıran kıvrık bıçaklar
		var n = Vector3(cos(a), sin(a), 0)
		var t = Vector3(-sin(a), cos(a), 0)
		b.add_slab(crescent, 0.012, steel.lightened(0.1), Transform3D(Basis(-t, n, Vector3.BACK), n * 0.105 + Vector3(0, 0, 0.14)), thin, shade)
	var claw := PackedVector2Array([Vector2(-0.018, 0.0), Vector2(0.018, 0.0), Vector2(0.012, 0.09), Vector2(-0.018, 0.2), Vector2(-0.01, 0.09)])
	for k in 4:   # parmak uçlarında zehirli pençe
		var x = -0.054 + k * 0.036
		b.add("box", Vector3(x, 0.018, 0.25), Vector3(0.03, 0.03, 0.05), dark)
		b.add_slab(claw, 0.012, Color(0.4, 0.46, 0.38), Transform3D(Basis.IDENTITY, Vector3(x, 0.016, 0.27)))
	b.add("cyl", Vector3(0, -0.14, -0.05), Vector3(0.045, 0.03, 0.045), dark, Vector3.ZERO, 8)   # zincir çıkışı


static func _link() -> Mesh:
	return Kit.mesh("oni_halka", func():
		var b = MB.new()
		var g = Color(0.62, 0.62, 0.66)
		b.add("cyl", Vector3.ZERO, Vector3(0.1, 0.04, 0.1), g, Vector3.ZERO, 12)
		b.add("cyl", Vector3.ZERO, Vector3(0.05, 0.046, 0.05), Color(0.08, 0.08, 0.1), Vector3.ZERO, 10)
		for s in [-1.0, 1.0]:
			b.add("cone", Vector3(s * 0.098, 0, 0), Vector3(0.03, 0.11, 0.02), Color(0.78, 0.78, 0.82), Vector3(0, 0, -s * 90.0), 5)
		return b.build(Props.toon()))


## Kolluk takılınca: kabuktan sarkan kısa zincir (ikincil hareket); bırakılınca kalkar
static func attach(node: Node3D) -> void:
	var c = Kit.chain(node, _link(), func(): return node.global_transform * Vector3(0, -0.15, -0.05), func():
		return node.global_transform * Vector3(0, -0.15, -0.05) + Vector3.DOWN * 0.42 + node.global_transform.basis.z * -0.16, INF, 6, 0.1, 0.06)
	node.set_meta("oni_idle_chain", c)


# ------------------------------------------------------------------ durum
static func has_chain(who: Node3D) -> bool:
	return Game.now() >= float(who.get_meta("oni_free_until", 0.0))


static func _set_idle(who: Node3D, on: bool) -> void:
	var n = Kit.node_of(who, ID)
	if n == null:
		return
	if n.has_meta("oni_idle_chain"):
		var c = n.get_meta("oni_idle_chain")
		if is_instance_valid(c) and not on:
			c.life = 0.0
		if not on:
			n.remove_meta("oni_idle_chain")
	elif on:
		attach(n)


static func _claw_marks(who: Node3D, up: bool) -> void:
	var f = Kit.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var c: Vector3 = who.global_position + Vector3.UP * 1.15 + f * 0.9
	for k in 4:
		var off = (float(k) - 1.5) * 0.13
		var pts = []
		for j in 7:
			var u = j / 6.0 * 2.0 - 1.0
			var p: Vector3 = c + f * (0.25 * (1.0 - u * u))
			p += (Vector3.UP * u * 0.75 + s * off) if up else (s * u * 0.8 + Vector3.UP * (off - u * 0.18))
			pts.append(p)
		Kit.fade(Kit.strip(pts, 0.03, Kit.mat("oni_pence", CLAW_SH), 0.8), 0.05, 0.18)


## Zincir eli ile hedef arasında durur: dur sn
static func _line(who: Node3D, to_fn: Callable, dur: float) -> void:
	Kit.chain(Kit.root(), _link(), func(): return Kit.hand(who) if is_instance_valid(who) else Vector3.ZERO, to_fn, dur, 90, 0.1, 0.12)


static func _shoot(who: Node3D, dmg: float) -> void:
	var f = Kit.face(who)
	var a: Vector3 = Kit.hand(who)
	var tg = Combat.nearest_enemy(who, CHAIN_R, f, 0.6)
	var end: Vector3 = (tg.global_position + Vector3.UP) if tg != null else a + f * CHAIN_R * 0.85
	var born = Time.get_ticks_msec()
	_line(who, func():
		var k = pingpong((Time.get_ticks_msec() - born) / 240.0, 1.0)
		return a.lerp(end, clampf(k, 0.0, 1.0)), 0.46)
	Sfx.play("chain", a, 1.1, 0.8)
	for h in Combat.hit_zone(who, who.global_position, f, a.distance_to(end) + 0.5, 11.0, 2.4, {"dmg": dmg * 0.85, "knock": 1.5, "kind": "light", "bleed": 2.0, "hitstop": 0.03, "melee": false}):
		if h.has_method("apply_status"):
			h.apply_status("slow", 1.2)


static func _bind(h: Node3D, dur: float) -> void:
	if h.has_method("apply_status"):
		h.apply_status("bind", dur)   # fiziksel bağ: Nawanuke ile çözülebilir
	Kit.wrap(h, _link(), Kit.height_of(h) * 0.55, 13, dur)
	Sfx.play("chain", h.global_position, 0.9, 0.9)


static func _wrap(who: Node3D, dmg: float) -> void:
	var ally = Kit.partner(who, ID, 14.0)
	if ally != null:   # Oni Kyōdai: zincir iki kardeş arasında gerilir, aradaki herkesi sarar
		var a: Vector3 = Kit.hand(who)
		var b: Vector3 = Kit.hand(ally)
		var hits = Kit.foes_on_line(who, a, b, 1.4)
		Kit.chain(Kit.root(), _link(), func(): return Kit.hand(who) if is_instance_valid(who) else a, func(): return Kit.hand(ally) if is_instance_valid(ally) else b, 0.9, 150, 0.1, 0.05)
		for h in hits:
			h.take_hit({"dmg": dmg * 0.7, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "bleed": 3.0})
			_bind(h, BIND_T)
		if not hits.is_empty():
			Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Oni Kyōdai!", Color(0.8, 0.82, 0.86))
			who.set_meta("oni_bound", hits[0].get_instance_id())
			return
	var tg = Combat.nearest_enemy(who, CHAIN_R, Kit.face(who), 0.35)
	if tg == null:
		_shoot(who, dmg * 0.6)
		return
	_line(who, func(): return (tg.global_position + Vector3.UP) if is_instance_valid(tg) else Kit.hand(who), BIND_T)
	tg.take_hit({"dmg": dmg * 0.55, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "bleed": 2.0})
	_bind(tg, BIND_T)
	who.set_meta("oni_bound", tg.get_instance_id())


static func _rip(who: Node3D, dmg: float) -> void:
	var id = int(who.get_meta("oni_bound", 0))
	who.set_meta("oni_bound", 0)
	var h = instance_from_id(id) if id != 0 else null
	if not Kit.live(h):
		_claw_marks(who, false)
		return
	var v: Vector3 = who.global_position - h.global_position
	if h is CharacterBody3D and v.length() > 1.6:
		h.velocity = v.normalized() * minf(18.0, v.length() * 4.0) + Vector3.UP * 2.0
	for k in 3:   # dikenler etten geçerek çekilir
		Kit.after(who, 0.1 + k * 0.13, func():
			if Kit.live(h):
				h.take_hit({"dmg": dmg * 0.3, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "bleed": 3.0, "hitstop": 0.02})
				Sfx.play("chain", h.global_position, 1.3, 0.6))
	Kit.shake(who, 0.2)


## Düzenek zinciri bırakır: zincir yere düşer, kol serbest kalır, bir süre sonra yenisi sarılır
static func _release(who: Node3D) -> void:
	who.set_meta("oni_free_until", Game.now() + REGROW)
	_set_idle(who, false)
	Sfx.play("clink", who.global_position, 0.7, 0.9)
	var f = Kit.face(who)
	var g: Vector3 = Kit.gp(Kit.hand(who) - f * 0.8)
	var e: Vector3 = Kit.gp(g - f * 1.3)
	Kit.chain(Kit.root(), _link(), func(): return g, func(): return e, 4.0, 14, 0.1, 0.0)
	Kit.after(who, REGROW, func():
		if has_chain(who):
			_set_idle(who, true)
			Sfx.play("chain", who.global_position, 1.4, 0.4))


# ------------------------------------------------------------------ kombo bağları
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var chained = has_chain(who)
	match i:
		0:
			_claw_marks(who, false)
		1:
			_claw_marks(who, true)
		2:
			if chained:
				_shoot(who, dmg)
			else:
				_claw_marks(who, false)
		3:
			if chained:
				_wrap(who, dmg)
			else:
				_claw_marks(who, true)
		4:
			if chained:
				_rip(who, dmg)
			else:
				_claw_marks(who, false)
		5:
			if chained:
				_release(who)
			_claw_marks(who, false)
			Kit.shake(who, 0.3)


## Pençe teması zehir bırakır; zincirsiz kol daha çok
static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if not h.has_method("apply_status"):
		return
	var chained = has_chain(who)
	if chained and i in [2, 3, 4]:
		return   # zincir adımları kendi vuruşunda
	h.apply_status("burn", POISON if chained else POISON_BARE)
