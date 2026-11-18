extends RefCounted
## Koshō Mimikazari (biber küpe; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/kosho_mimikazari_fx.gd). Kanon (Narutopedia "Pepper Balloon Earrings", Koyuki Kazahana, Kar Ülkesi filmi):
## yuvarlak küpelerin içi biber spreyi; sıkınca karşıdakinin yüzüne fışkırır, kaçma fırsatı verir. Görünüş refs/kosho_mimikazari: kırmızı kabak biçimli küpe, parmaklar arasında.
## Oyunda: 3,4 m koni, bakan yüze; hedef kör olur, kullanan geri sıçrar. Hasar yok. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const REACH := 3.4
const BLIND := 2.6

static var _tw: Tween

const JET_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = 0.5 + 0.5 * sin(UV.x * 30.0 - TIME * 30.0);
	ALBEDO = mix(vec3(0.72, 0.1, 0.08), vec3(0.98, 0.42, 0.28), w);
	ALPHA = smoothstep(0.1 + 0.3 * UV.x, 0.6, v) * fade_k * 0.8;
	if (ALPHA < 0.02) discard;
}
"""

const EYE_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	float m = smoothstep(0.1, 1.0, length(p * vec2(0.8, 1.2)) + 0.08 * sin(p.x * 9.0 + TIME));
	ALBEDO = mix(vec3(0.9, 0.3, 0.2), vec3(0.42, 0.04, 0.04), m);
	ALPHA = k * (0.55 + 0.42 * m);
}
"""


static func _ear() -> Mesh:
	return Yk.mesh("kosho_kupe", func():
		var b = MB.new()
		var r = Color(0.82, 0.16, 0.14)
		b.add("sphere", Vector3(0, -0.018, 0), Vector3.ONE * 0.034, r, Vector3.ZERO, 8)
		b.add("sphere", Vector3(0, 0.008, 0), Vector3.ONE * 0.022, r, Vector3.ZERO, 8)
		b.add("cone", Vector3(0, 0.027, 0), Vector3(0.012, 0.02, 0.012), r, Vector3.ZERO, 6)
		b.add("sphere", Vector3(0.008, -0.014, 0.014), Vector3.ONE * 0.008, Color(1, 0.72, 0.6), Vector3.ZERO, 5)
		return b.build(Props.toon()))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, target: Node3D) -> Projectile:
	var tg = target if U.alive(target) else U.target_of(who)
	if U.alive(tg):
		U.face(who, U.chest(tg))
	var f = Yk.face(who)
	var h = Yk.height_of(who)
	var s = Vector3.UP.cross(f).normalized()
	var from: Vector3 = who.global_position + Vector3.UP * h * 0.9 + f * 0.14 - s * 0.1
	var e = MeshInstance3D.new()
	e.mesh = _ear()
	Yk.root().add_child(e)
	e.global_position = from
	var tw = e.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(e.queue_free)
	var m = Yk.mat("kosho_jet", JET_SH)
	for k in 5:
		var d = f.rotated(Vector3.UP, deg_to_rad((k - 2) * 8.0))
		var pts = []
		for j in 6:
			var u = j / 5.0
			pts.append(from + d * REACH * u + Vector3.UP * sin(u * 8.0 + k) * 0.05)
		Yk.fade(Yk.strip(pts, 0.05, m, -2.2), 0.1, 0.22)
	Sfx.play("wind", from, 1.8, 0.45)
	for t in Kit.fighters():
		if not Combat.hostile(who, t) or t.is_dead():
			continue
		var v: Vector3 = t.global_position - who.global_position
		v.y = 0.0
		if v.length() > REACH + 0.4 or f.dot(v.normalized()) < 0.72:
			continue
		if t.has_method("face_dir") and t.face_dir().dot(-v.normalized()) < -0.1:
			continue   # arkası dönükse yüzüne gelmez
		_blind(t)
	if who is CharacterBody3D:
		who.velocity.x = -f.x * 8.0
		who.velocity.z = -f.z * 8.0
		who.velocity.y = 4.0
	return null


static func _blind(t: Node3D) -> void:
	Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Gözler yanıyor!", Color(1.0, 0.45, 0.35))
	if t is Player:
		t.apply_status("stun", 0.5)
		if t.combat != null:
			t.combat.lock_target = null
		var v = Kit.screen("kosho", EYE_SH)
		var mt: ShaderMaterial = v.material_override
		mt.set_shader_parameter("k", 1.0)
		v.visible = true
		if _tw != null and _tw.is_valid():
			_tw.kill()
		var dim = func(x: float) -> void:
			mt.set_shader_parameter("k", x)
		_tw = v.create_tween()
		_tw.tween_interval(0.7)
		_tw.tween_method(dim, 1.0, 0.0, BLIND - 0.7)
		_tw.tween_callback(func():
			if is_instance_valid(v):
				v.visible = false)
	else:
		if t.has_method("lose_target"):
			t.lose_target(BLIND)
		t.apply_status("stun", 0.6)
