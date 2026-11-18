extends RefCounted
## Kunai-tō: model, halkadaki zincir ve ağırlık — kendi şekilleri ve gölgelendiricisi.
## Kaynak refs/kunai_to/kunai_blades.png: koyu kavisli ağız, açık renk tek kenar, sapa yakın küçük delik, beyaz sargılı sap, büyük koyu halka, ince zincir.
## Kanon (Narutopedia "Kunai Blade"): kılıç gibi kullanılır; Kotetsu ve Izumo silahlarını ağırlıklı zincirle birleştirip rakibi hareketsiz bırakır.
## Yalnız kullanan ağırlığı kendi savurur (kanon dışı yardımcı kullanım); ortak bağ için yanında aynı silahlı yoldaş gerekir. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "kunai_to"
const RING := Vector3(0, 0, -0.34)
const CAST_R := 8.0
const LEG_BIND := 0.9
const PAIR_BIND := 2.0

const THREAD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float dash = step(0.35, fract(UV.x * 9.0 - TIME * 7.0));
	ALBEDO = vec3(0.86, 0.88, 0.92);
	ALPHA = smoothstep(0.2, 0.7, v) * dash * fade_k * (1.0 - UV.x * 0.6);
	if (ALPHA < 0.02) discard;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, uç +Z (~1.05 m), kesici kenar +Y; halka -Z ucunda
static func model(b: MB) -> void:
	var body = Color(0.3, 0.3, 0.33)
	var steel = Color(0.8, 0.81, 0.84)
	var wrap = Color(0.88, 0.87, 0.84)
	var dark = Color(0.2, 0.2, 0.23)
	var o := PackedVector2Array([Vector2(-0.055, 0.04), Vector2(-0.085, 0.2), Vector2(-0.09, 0.45), Vector2(-0.07, 0.72), Vector2(-0.02, 0.93), Vector2(0.04, 1.05),
		Vector2(0.045, 0.86), Vector2(0.075, 0.62), Vector2(0.095, 0.38), Vector2(0.085, 0.16), Vector2(0.05, 0.04)])
	b.add_slab(MB.hole(o, Vector2(-0.02, 0.14), 0.018), 0.016, body, Transform3D.IDENTITY, Callable(), dark)
	var e := PackedVector2Array([Vector2(0.085, 0.16), Vector2(0.095, 0.38), Vector2(0.075, 0.62), Vector2(0.045, 0.86), Vector2(0.04, 1.05),
		Vector2(0.012, 0.9), Vector2(0.03, 0.62), Vector2(0.045, 0.38), Vector2(0.04, 0.16)])
	b.add_slab(e, 0.018, steel)
	b.add("cyl", Vector3(0, 0, -0.1), Vector3(0.042, 0.3, 0.042), wrap, Vector3(90, 0, 0), 8)
	for k in 6:   # çapraz sargı
		b.add("box", Vector3(0, 0, -0.22 + k * 0.05), Vector3(0.05, 0.05, 0.01), wrap.darkened(0.22), Vector3(0, 0, 45.0 * (1 - 2 * (k % 2))))
	b.add("torus", RING, Vector3(0.17, 0.17, 0.17), dark, Vector3(0, 0, 90), 14)


static func _link() -> Mesh:
	return Kit.mesh("kunai_halka", func():
		var b = MB.new()
		b.add("torus", Vector3.ZERO, Vector3(0.05, 0.05, 0.085), Color(0.24, 0.24, 0.27), Vector3.ZERO, 8)
		return b.build(Props.toon()))


static func _weight() -> Mesh:
	return Kit.mesh("kunai_agirlik", func():
		var b = MB.new()
		var c = Color(0.18, 0.18, 0.2)
		b.add("cyl", Vector3.ZERO, Vector3(0.08, 0.11, 0.08), c, Vector3.ZERO, 8)
		b.add("cone", Vector3(0, -0.09, 0), Vector3(0.08, 0.07, 0.08), c, Vector3(180, 0, 0), 8)
		return b.build(Props.toon()))


## Eldeki silah: halkadan sarkan kısa zincir + ağırlık (ikincil hareket)
static func attach(node: Node3D) -> void:
	var c = Kit.chain(node, _link(), func(): return node.global_transform * RING, func():
		return node.global_transform * RING + Vector3.DOWN * 0.3, INF, 6, 0.07, 0.05, true, _weight())
	node.set_meta("kunai_chain", c)


# ------------------------------------------------------------------ zincir işleri
static func _ring_pos(who: Node3D) -> Vector3:
	var n = Kit.node_of(who, ID)
	return n.global_transform * RING if n != null else Kit.hand(who)


## Ağırlık halkadan hedefe uçar ve döner
static func _cast(who: Node3D, end: Vector3, dur: float) -> void:
	var a: Vector3 = _ring_pos(who)
	var born = Time.get_ticks_msec()
	Kit.chain(Kit.root(), _link(), func(): return _ring_pos(who) if is_instance_valid(who) else a, func():
		var k = pingpong((Time.get_ticks_msec() - born) / (dur * 500.0), 1.0)
		return a.lerp(end, clampf(k, 0.0, 1.0)), dur, 110, 0.07, 0.1, true, _weight())
	Sfx.play("chain", a, 1.25, 0.7)


static func _throw_weight(who: Node3D, dmg: float) -> void:
	var f = Kit.face(who)
	var tg = Combat.nearest_enemy(who, CAST_R, f, 0.6)
	var end: Vector3 = (tg.global_position + Vector3.UP) if tg != null else who.global_position + Vector3.UP * 1.2 + f * CAST_R * 0.85
	_cast(who, end, 0.44)
	Combat.hit_zone(who, who.global_position, f, who.global_position.distance_to(end) + 0.5, 9.0, 2.4, {"dmg": dmg * 0.8, "knock": 2.0, "kind": "light", "stun": 0.25, "hitstop": 0.03, "melee": false})


static func _leg_wrap(who: Node3D, dmg: float) -> void:
	var f = Kit.face(who)
	var tg = Combat.nearest_enemy(who, CAST_R, f, 0.45)
	if tg == null:
		_throw_weight(who, dmg * 0.6)
		return
	var low = func(): return (tg.global_position + Vector3.UP * 0.25) if is_instance_valid(tg) else who.global_position
	Kit.chain(Kit.root(), _link(), func(): return _ring_pos(who) if is_instance_valid(who) else Vector3.ZERO, low, LEG_BIND, 110, 0.07, 0.14, true)
	if tg.has_method("apply_status"):
		tg.apply_status("bind", LEG_BIND)
	Kit.wrap(tg, _link(), 0.25, 18, LEG_BIND)
	tg.take_hit({"dmg": dmg * 0.4, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO})
	who.set_meta("kunai_bound", tg.get_instance_id())
	Sfx.play("chain", tg.global_position, 0.95, 0.9)


static func _pull(who: Node3D) -> void:
	var id = int(who.get_meta("kunai_bound", 0))
	who.set_meta("kunai_bound", 0)
	var h = instance_from_id(id) if id != 0 else null
	if Kit.live(h) and h is CharacterBody3D:
		var v: Vector3 = who.global_position - h.global_position
		if v.length() > 1.5:
			h.velocity = v.normalized() * minf(16.0, v.length() * 3.6) + Vector3.UP * 1.5


## Ortak bağ: iki kunai-tō arasında gerilen zincir ileri süpürülür, üstünden geçtiği herkes sarılır
static func _pair_sweep(who: Node3D, ally: Node3D, dmg: float) -> bool:
	var a: Vector3 = _ring_pos(who)
	var b: Vector3 = _ring_pos(ally)
	var hits = Kit.foes_on_line(who, a, b, 1.6)
	var thread = [a, a.lerp(b, 0.5) + Vector3.DOWN * 0.04, b]
	Kit.fade(Kit.strip(thread, 0.03, Kit.mat("kunai_iz", THREAD_SH), 0.0), 0.08, 0.2)
	Kit.chain(Kit.root(), _link(), func(): return _ring_pos(who) if is_instance_valid(who) else a, func(): return _ring_pos(ally) if is_instance_valid(ally) else b, 0.8, 200, 0.07, 0.05, true)
	for h in hits:
		h.take_hit({"dmg": dmg * 1.1, "knock": 0.0, "kind": "heavy", "attacker": who, "dir": Vector3.ZERO, "hitstop": 0.05})
		if h.has_method("apply_status"):
			h.apply_status("bind", PAIR_BIND)
		Kit.wrap(h, _link(), Kit.height_of(h) * 0.5, 20, PAIR_BIND)
	if hits.is_empty():
		return false
	Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Renkei!", Color(0.82, 0.86, 0.92))
	return true


# ------------------------------------------------------------------ kombo bağları
static func strike(who: Node3D, i: int, dmg: float) -> void:
	match i:
		2:
			_throw_weight(who, dmg)
		3:
			_leg_wrap(who, dmg)
		4:
			_pull(who)
		5:
			var ally = Kit.partner(who, ID, 12.0)
			if ally != null:
				_pair_sweep(who, ally, dmg)
