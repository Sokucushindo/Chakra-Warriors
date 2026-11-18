extends RefCounted
## Kemuri Senkōdan (煙閃光弾; hedef: res://scripts/combat/fx/kemuri_senkodan_fx.gd). Kanon (Narutopedia "Smoke-Flash Bomb", Boruto manga 18): Katasuke'nin bilimsel aracı.
## Güçlü ses ve ışıkla duyuları kapatır; Mitsuki'nin keskin görme ve işitmesini bile engeller. Zayıflığı: geniş alan; haber verilmezse yoldaş da etkilenir.
## Oyunda: Hikaridama'dan farkı SES: bakmayanı da vurur, atan ve yoldaşı AYRICALIKSIZ etkilenir. Duvar arkası korur. Ref: sarı bantlı gri silindir, delikli baş.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const R := 13.0
const DAZE_MAX := 3.0
const DAZE_MIN := 1.0
const FUSE := 0.32

static var _tw: Tween

const BURST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 1.0 - smoothstep(0.02, 0.02 + 0.2 * (1.0 - prog), r);
	for (int i = 0; i < 4; i++) {
		float c = prog * 0.95 - float(i) * 0.1;
		if (c > 0.03) {
			float br = smoothstep(0.1, 0.5, 0.5 + 0.5 * sin(a * 13.0 + float(i) * 2.4));
			m = max(m, (1.0 - smoothstep(0.004, 0.012, abs(r - c))) * br);
		}
	}
	if (m < 0.02 || r > 1.0) discard;
	ALBEDO = vec3(1.0, 0.98, 0.86) * 2.4;
	ALPHA = m * (1.0 - prog);
}
"""

const SCREEN_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float ring = 0.5 + 0.5 * sin(length(p) * 70.0 - TIME * 26.0);
	ALBEDO = mix(vec3(1.0, 0.97, 0.84), vec3(1.0), ring * 0.4);
	ALPHA = clamp(k * k * 1.15 + ring * 0.2 * k, 0.0, 1.0);
}
"""


static func _body() -> Mesh:
	return Kit.cached_mesh("senkodan", func():
		var b = MB.new()
		var g = Color(0.42, 0.42, 0.44)
		var gd = Color(0.3, 0.3, 0.32)
		b.add("cyl", Vector3.ZERO, Vector3(0.11, 0.11, 0.11), Color(0.8, 0.74, 0.34), Vector3(90, 0, 0), 14)
		for z in [-0.066, 0.066]:
			b.add("cyl", Vector3(0, 0, z), Vector3(0.113, 0.026, 0.113), g, Vector3(90, 0, 0), 14)
		b.add("cyl", Vector3(0, 0, -0.082), Vector3(0.1, 0.008, 0.1), gd, Vector3(90, 0, 0), 14)
		b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.066, 0.044, 0.066), gd, Vector3(90, 0, 0), 12)
		for k in 6:
			var a = k * TAU / 6.0
			b.add("sphere", Vector3(cos(a) * 0.033, sin(a) * 0.033, 0.123), Vector3.ONE * 0.011, Color(0.06, 0.06, 0.07), Vector3.ZERO, 5)
		return b.build(Props.toon()))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "kemuri_senkodan", 24.0, 14.0, _body(), 1.0, Vector3(6, 3, 1))
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		_arm(pos + Vector3.UP * 0.2)
	return pr


static func _arm(at: Vector3) -> void:
	var s = {"t": 0.0}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		if float(s["t"]) >= FUSE:
			burst(at)
			return true
		return false
	var root = Kit.ticker(at, fn)
	var mi = MeshInstance3D.new()
	mi.mesh = _body()
	root.add_child(mi)
	Sfx.play("click", at, 1.9, 0.5)


static func burst(pos: Vector3) -> void:
	var root = Node3D.new()
	Kit.scene().add_child(root)
	root.global_position = pos
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.97, 0.86)
	l.omni_range = 26.0
	l.light_energy = 14.0
	root.add_child(l)
	var tw = root.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(root.queue_free)
	var q = Kit.quad(root, 26.0, Kit.shader_mat("senko_patlama", BURST_SH))
	Kit.tween_param(q, "prog", 0.0, 1.0, 0.34)
	Sfx.play("boom", pos, 2.4, 0.7)
	Sfx.play("alarm", pos, 2.2, 0.5)   # kulak çınlaması yerine geçici
	for f in Kit.fighters():   # dost düşman ayrımı YOK (kanon zayıflık)
		if f.is_dead() or not f.has_method("apply_status"):
			continue
		var e: Vector3 = Kit.eye(f)
		var d = e.distance_to(pos)
		if d > R:
			continue
		var ray = PhysicsRayQueryParameters3D.create(e, pos, 1)
		if not f.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_daze(f, lerpf(DAZE_MAX, DAZE_MIN, d / R))


static func _daze(f: Node3D, t: float) -> void:
	if f is Player:
		f.apply_status("stun", minf(0.8, t * 0.3))
		if f.combat != null:
			f.combat.lock_target = null
		if f == Game.player:
			_screen(t)
	else:
		if f.has_method("lose_target"):
			f.lose_target(t)
		f.apply_status("stun", t * 0.35)
		Combat.popup_text(f.global_position + Vector3.UP * (Kit.height_of(f) + 0.6), "Sersem!", Color(1, 1, 0.75))


static func _screen(t: float) -> void:
	var s = Kit.screen("senko", SCREEN_SH)
	var m: ShaderMaterial = s.material_override
	s.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var set_k = func(v: float) -> void:
		m.set_shader_parameter("k", v)
	var hide_s = func() -> void:
		s.visible = false
	set_k.call(1.0)
	_tw = s.create_tween()
	_tw.tween_interval(t * 0.25)
	_tw.tween_method(set_k, 1.0, 0.0, t * 0.75)
	_tw.tween_callback(hide_s)
