extends RefCounted
## Yuki Ita (kar kayağı; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/yuki_ita_fx.gd). Kanon (Narutopedia "Snowboard", Mizore Fuyukuma, Kar Ülkesi filmi): karda hızlı ve kolay gidiş; ormanda bile rahat döner.
## Görünüş refs/yuki_ita: kızıl çerçeve, mor iç, iki yuvarlak delik, altında ip. Oyunda: yalnız karlı bölgede, alet tuşuyla binilir/inilir; karın dışında kendiliğinden biter. Düşman: karda kısa süre hızlanır.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const SRC := "yuki_ita"
const SNOW := [8, 15]

const SPRAY_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	if (v < 0.2 + 0.5 * UV.x) discard;
	ALBEDO = vec3(0.93, 0.96, 1.0);
	ALPHA = fade_k;
}
"""


static func on_snow(p: Vector3) -> bool:
	return Game.biome_at(p.x, p.z) in SNOW


static func _board() -> Mesh:
	return Yk.mesh("yuki_ita", func():
		var b = MB.new()
		var red = Color(0.56, 0.16, 0.26)
		var pur = Color(0.27, 0.19, 0.36)
		var xf = Transform3D(Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), Vector3.ZERO)
		var o := PackedVector2Array([Vector2(-0.14, -0.7), Vector2(0.14, -0.7), Vector2(0.17, -0.45), Vector2(0.11, 0.0), Vector2(0.17, 0.45), Vector2(0.14, 0.7), Vector2(-0.14, 0.7), Vector2(-0.17, 0.45), Vector2(-0.11, 0.0), Vector2(-0.17, -0.45)])
		var ins := PackedVector2Array([Vector2(-0.1, -0.62), Vector2(0.1, -0.62), Vector2(0.13, -0.45), Vector2(0.07, 0.0), Vector2(0.13, 0.45), Vector2(0.1, 0.62), Vector2(-0.1, 0.62), Vector2(-0.13, 0.45), Vector2(-0.07, 0.0), Vector2(-0.13, -0.45)])
		b.add_slab(o, 0.03, red, xf, Callable(), red.darkened(0.3))
		b.add_slab(ins, 0.034, pur, xf)
		for z in [-0.42, 0.42]:
			b.add("cyl", Vector3(0, 0.002, z), Vector3(0.17, 0.036, 0.17), red, Vector3.ZERO, 14)
			b.add("cyl", Vector3(0, 0.003, z), Vector3(0.12, 0.038, 0.12), Color(0.8, 0.86, 0.92), Vector3.ZERO, 14)
			b.add("box", Vector3(0, 0.024, z), Vector3(0.012, 0.012, 0.11), Color(0.6, 0.6, 0.63))
		return b.build(Props.toon()))


static func _vis() -> Node3D:
	var root = Node3D.new()
	var m = MeshInstance3D.new()
	m.mesh = _board()
	m.position = Vector3(0, 0.03, 0)
	root.add_child(m)
	return root


static func player_use(p: Node3D) -> void:
	if p.flight_source() == SRC:
		p.stop_flight()
		return
	if not on_snow(p.global_position):
		Hud.msg("Yuki Ita yalnız karda kayar.", Color(0.8, 0.9, 1.0))
		return
	p.start_flight(SRC, {"speed": 23.0, "lift": 0.0, "drain": 0.0, "vis": _vis(), "name": "Yuki Ita", "hug": true})
	var s = {"acc": 0.0}
	Kit.ticker(p.global_position, func(dt: float) -> bool:
		if not is_instance_valid(p) or p.flight_source() != SRC:
			return true
		if not on_snow(p.global_position):
			p.stop_flight()
			Hud.msg("Kar bitti.", Color(0.8, 0.9, 1.0))
			return true
		s["acc"] += dt
		if float(s["acc"]) >= 0.1 and Vector2(p.velocity.x, p.velocity.z).length() > 4.0:
			s["acc"] = 0.0
			_spray(p)
		return false)


static func _spray(w: Node3D) -> void:
	var f = Yk.face(w)
	var a: Vector3 = w.global_position - f * 0.6 + Vector3.UP * 0.05
	var s = Vector3.UP.cross(f).normalized() * randf_range(-0.8, 0.8)
	Yk.fade(Yk.strip([a, a - f * 0.5 + Vector3.UP * 0.3 + s * 0.4, a - f * 1.1 + Vector3.UP * 0.2 + s], 0.08, Yk.mat("yuki_kar", SPRAY_SH), 0.6), 0.05, 0.2)


## Düşman: karda hızlanır
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	if who is Player:
		player_use(who)
		return null
	if not on_snow(who.global_position) or not who.has_method("add_buff"):
		return null
	who.add_buff("yuki_ita", 8.0, {"speed": 1.5})
	var v = _vis()
	who.add_child(v)
	v.rotation.y = float(who.get("facing")) if who.get("facing") != null else 0.0
	who.get_tree().create_timer(8.0).timeout.connect(v.queue_free)
	return null
