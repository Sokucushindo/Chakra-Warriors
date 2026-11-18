extends RefCounted
## Ryūjin (龍刃; hedef: res://scripts/combat/fx/ryujin_fx.gd). Kaynak YALNIZ OYUN (Narutopedia "Dragon Blade", Dragon Blade Chronicles): ortasına takılan beş küreyle beş temel doğayı kullandırır,
## kesip chakra emer, sahibine bağlı kalmak ister; tam denetim çok yüksek chakra ister. Görünüş refs/ryujin: mavi-çelik kunai ağzı, sarı zikzak, halka, pullu yeşil sap, turuncu örgü püskül.
## Oyunda: her adım sıradaki doğa; chakrası düşük kullanıcı daha çok öder. Bitişte bıçak fırlar, beş doğa patlar, kendiliğinden döner. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const ID := "ryujin"
const EL := ["katon", "fuuton", "raiton", "doton", "suiton"]
const COL := [Color(0.95, 0.25, 0.15), Color(0.3, 0.9, 0.4), Color(1.0, 0.86, 0.2), Color(0.95, 0.5, 0.15), Color(0.2, 0.55, 1.0)]
const RICH := 300.0

const ARC_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
instance uniform vec3 tone = vec3(1.0);
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(tone, vec3(1.0), smoothstep(0.65, 1.0, v)) * 1.4;
	ALPHA = smoothstep(0.1, 0.7, v) * (1.0 - UV.x * 0.5) * fade_k;
}
"""


static func model(b: MB) -> void:
	var steel = Color(0.56, 0.68, 0.76)
	var pale = Color(0.86, 0.93, 0.96)
	var gold = Color(0.9, 0.72, 0.2)
	var teal = Color(0.16, 0.52, 0.5)
	var o := PackedVector2Array([Vector2(-0.075, 0.13), Vector2(0.075, 0.13), Vector2(0.095, 0.2), Vector2(0.0, 1.0), Vector2(-0.095, 0.2)])
	var thin = func(p: Vector2) -> float:
		return lerpf(0.032, 0.004, clampf(absf(p.x) / 0.095, 0.0, 1.0))
	b.add_slab(o, 0.03, steel, Transform3D.IDENTITY, thin, pale)
	for k in 5:   # sarı zikzak
		var z = 0.2 + k * 0.1
		var s = 1.0 if k % 2 == 0 else -1.0
		b.add("box", Vector3(0, s * 0.012, z + 0.05), Vector3(0.034, 0.012, 0.13), gold, Vector3(s * 24.0, 0, 0))
	b.add("torus", Vector3(0, 0, 0.07), Vector3(0.16, 0.16, 0.16), steel.darkened(0.15), Vector3(0, 0, 90), 16)
	b.add("cyl", Vector3(0, 0, -0.12), Vector3(0.05, 0.26, 0.05), teal, Vector3(90, 0, 0), 8)
	for k in 7:
		b.add("cyl", Vector3(0, 0, -0.23 + k * 0.036), Vector3(0.056, 0.006, 0.056), teal.darkened(0.3), Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, 0, -0.28), Vector3(0.07, 0.07, 0.05), steel, Vector3(0, 0, 45))


static func _orb_mesh(col: Color) -> Mesh:
	return Yk.mesh("ryujin_kure_%s" % col.to_html(), func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.07, col, Vector3.ZERO, 10)
		return b.build(Props.toon()))


## Halkanın ortasında sıradaki doğanın küresi
static func attach(node: Node3D) -> void:
	var m = MeshInstance3D.new()
	m.mesh = _orb_mesh(COL[0])
	m.position = Vector3(0, 0, 0.07)
	node.add_child(m)
	node.set_meta("ry_k", m)


static func _set_orb(who: Node3D, i: int) -> void:
	var n = Yk.node_of(who, ID)
	if n != null and n.has_meta("ry_k") and is_instance_valid(n.get_meta("ry_k")):
		n.get_meta("ry_k").mesh = _orb_mesh(COL[i])


static func _pay(who: Node3D) -> bool:
	var a = who.get("arch")
	var jin = (who is Player and TailedBeasts.player_jinchuriki() != "") or (a is Dictionary and a.has("beast"))
	if jin:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	return Yk.pay(who, 0.012 if mx >= RICH else 0.04)


static func _arc(c: Vector3, f: Vector3, s: Vector3, r: float, i: int) -> void:
	var pts = []
	for k in 9:
		var u = k / 8.0 * 2.0 - 1.0
		pts.append(c + f * r * (1.0 - u * u * 0.55) + s * u * r * 0.9 + Vector3.UP * u * 0.25)
	var mi = Yk.strip(pts, 0.14, Yk.mat("ryujin_yay", ARC_SH), 0.2)
	var col: Color = COL[i]
	mi.set_instance_shader_parameter("tone", Vector3(col.r, col.g, col.b))
	Yk.fade(mi, 0.05, 0.16)


static func _wave(who: Node3D, i: int, dmg: float, at: Vector3, f: Vector3, reach: float) -> void:
	_arc(at, f, Vector3.UP.cross(f).normalized(), reach * 0.55, i)
	Combat.hit_sphere(who, at + f * reach * 0.5, reach * 0.55, {"dmg": dmg, "knock": 3.0, "kind": "light", "element": EL[i], "hitstop": 0.02, "melee": false})


static func _throw(who: Node3D, dmg: float) -> void:
	var n = Yk.node_of(who, ID)
	var a: Vector3 = Yk.hand(who)
	var tg = U.target_of(who)
	var end: Vector3 = U.aim_at(who, tg)
	if a.distance_to(end) > 10.0:
		end = a + (end - a).normalized() * 10.0
	var d = (end - a).normalized()
	var c = MeshInstance3D.new()
	c.mesh = CharacterModel.weapon_mesh(ID)
	Yk.root().add_child(c)
	if n != null:
		n.visible = false
	var b = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	var tw = c.create_tween()
	var go = func(u: float) -> void:
		if is_instance_valid(c):
			c.global_transform = Transform3D(b, a.lerp(end, u))
	var back = func(u: float) -> void:
		if is_instance_valid(c) and is_instance_valid(who):
			c.global_position = end.lerp(Yk.hand(who), u)   # sahibine döner
	tw.tween_method(go, 0.0, 1.0, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(who):
			for k in 5:
				var dir = Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 5.0)
				_wave(who, k, dmg * 0.34, end, dir, 2.4)
			Sfx.play("boom", end, 1.5, 0.6))
	tw.tween_interval(0.14)
	tw.tween_method(back, 0.0, 1.0, 0.24)
	tw.tween_callback(func():
		if n != null and is_instance_valid(n):
			n.visible = true
		c.queue_free())


static func start(who: Node3D, i: int) -> void:
	if who != null and is_instance_valid(who):
		_set_orb(who, i % 5)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	if i == 5:
		_throw(who, dmg)
		return
	if _pay(who):
		_wave(who, i, dmg * 0.32, who.global_position + Vector3.UP * 1.2 + f * 0.7, f, 3.0)
		Sfx.play("whoosh", who.global_position, 1.2, 0.4)


static func on_hit(who: Node3D, _i: int, h: Node3D) -> void:
	if h.get("chakra") != null and who.get("chakra") != null:
		var t = minf(3.0, float(h.chakra))
		h.chakra = float(h.chakra) - t
		who.chakra = minf(float(who.max_chakra), float(who.chakra) + t)
