extends RefCounted
## Tekkō (鉄甲; hedef: res://scripts/combat/fx/tekko_fx.gd). KANON ZAYIF: Narutopedia sayfası yalnız Vikipedi'ye yönlenir ve kullanıcı olarak Tenten'i
## yazar; Tenten'in silah görselinde (refs/tekko/Tentens_tools.png) bile seçilmiyor. Biçim gerçek Okinawa tekkōsu: avuçtaki demir çubuk, parmak
## eklemlerinin önünde çivili plaka, ikisini bağlayan üzengi kemer. Muşta Bıçağı'ndan farkı: kesmez, ezer.
## Mekanik: aynı hedefe art arda isabet "ezik" biriktirir; dördüncüde sersemletir. Silah uzayı (iki el aynı): +X parmak eklemleri, Z başparmak ekseni.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const IRON := Color(0.33, 0.34, 0.37)
const IRON_L := Color(0.56, 0.57, 0.6)
const STACK_T := 3.0
const STACK_N := 4

const STAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float t = pow(abs(cos(a * 2.5 + 0.5)), 16.0);
	float e = (0.1 + 0.85 * t) * sin(3.14159 * min(1.0, prog + 0.1));
	if (length(p) > e) discard;
	ALBEDO = vec3(1.0, 0.86, 0.6) * 1.8;
	ALPHA = 1.0 - prog;
}
"""


static func _seg(b: MB, p: Vector3, q: Vector3, w: float, col: Color) -> void:
	var y = q - p
	var yn = y.normalized()
	var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
	b.add_xf("cyl", Transform3D(Basis(xn * w, y * 1.08, xn.cross(yn) * w), (p + q) * 0.5), col, 6)


static func build(b: MB) -> void:
	b.add("cyl", Vector3.ZERO, Vector3(0.024, 0.108, 0.024), IRON, Vector3(90, 0, 0), 8)   # avuç çubuğu
	b.add("box", Vector3(0.062, 0, 0), Vector3(0.014, 0.038, 0.102), IRON_L)              # eklem plakası
	for z in [-0.034, 0.0, 0.034]:   # üç çivi
		b.add("cone", Vector3(0.082, 0, z), Vector3(0.018, 0.028, 0.018), IRON_L.lightened(0.15), Vector3(0, 0, -90), 5)
	for sz in [-1.0, 1.0]:   # üzengi kemer: çubuk ucundan plakaya, parmakların üstünden
		var a = Vector3(0, 0, sz * 0.05)
		var m = Vector3(0.028, 0.034, sz * 0.054)
		var c = Vector3(0.058, 0.012, sz * 0.05)
		_seg(b, a, m, 0.01, IRON)
		_seg(b, m, c, 0.01, IRON)


static func _sparks(p: Vector3, f: Vector3, n: int) -> void:
	var m = Kit.cached_mesh("tekko_kivilcim", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.008, 0.008, 0.05), Color(1.0, 0.76, 0.34))
		return b.build(Props.toon()))
	for k in n:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		var v = (f * randf_range(-0.4, 0.5) + Vector3(randf_range(-1, 1), randf_range(0.1, 1.1), randf_range(-1, 1))).normalized() * randf_range(2.5, 5.0)
		mi.look_at_from_position(p, p + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				mi.global_position = p + v * t + Vector3.DOWN * 7.0 * t * t, 0.0, 0.2, 0.2)
		tw.tween_callback(mi.queue_free)


static func _star(p: Vector3, size: float) -> void:
	var mi = Kit.quad(Kit.scene(), size, Kit.shader_mat("tekko_yildiz", STAR_SH))
	mi.global_position = p
	Kit.tween_param(mi, "prog", 0.0, 1.0, 0.14, true)


## KeyedCombos.on_target: isabet başına (oyuncu + düşman)
static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	var p = U.chest(h)
	var f: Vector3 = (who.global_position - h.global_position).normalized()
	_sparks(p + f * 0.25, f, 5 if i < 5 else 9)
	_star(p + f * 0.3, 0.9 if i < 5 else 1.6)
	var now = Game.now()
	var key = "tekko_%d" % who.get_instance_id()
	var n = (int(h.get_meta(key, 0)) if now - float(h.get_meta(key + "_t", -9.0)) < STACK_T else 0) + (2 if i == 5 else 1)
	h.set_meta(key + "_t", now)
	if n >= STACK_N and h.has_method("apply_status"):
		h.apply_status("stun", 0.75)
		Combat.popup_text(h.global_position + Vector3.UP * 2.2, "Ezildi!", Color(1.0, 0.82, 0.55))
		n = 0
	h.set_meta(key, n)
