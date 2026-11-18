extends RefCounted
## Hikaridama (光玉, ışık bombası; hedef: res://scripts/combat/fx/hikaridama_fx.gd).
## Kanon (Narutopedia "Flash Bomb"): üstünde 光 yazan, sarılı küçük top; patlayınca kör edici ışık, oyalama aracı.
## Nara klanı sever: ışık gölgeleri bir an uzatır (Shadow Imitation Technique sayfası). Görünüş: refs/hikaridama
## (iple sarılı top + kara 光; patlama: merkezden fışkıran ışınlar, her şey beyaza boğulur).
## Mekanik: yalnız IŞIĞA BAKAN ve arada duvar / duman olmayan kör olur. Atan da yakındaysa ve bakıyorsa kör olur.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const KEMURI_PATH := "res://scripts/combat/fx/kemuridama_fx.gd"

const R := 16.0          # kör etme menzili
const SELF_R := 7.0      # atan ve yoldaşları bu mesafede kendi ışığına yakalanır
const POINT_BLANK := 2.5 # bu kadar yakında bakmasa da kör olur
const BLIND_MAX := 3.2
const BLIND_MIN := 1.2
const SHADOW_T := 6.0    # Nara gölgesi uzama süresi

static var _tw: Tween

const RAY_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = 0.5 + 0.5 * sin(a * 37.0 + 1.3 * sin(a * 7.0));
	s *= 0.5 + 0.5 * sin(a * 89.0 + 2.0);
	float reach = 0.25 + 0.75 * sqrt(clamp(prog * 3.0, 0.0, 1.0));
	float rays = smoothstep(0.2, 0.75, s) * (1.0 - smoothstep(reach * 0.25, reach, r));
	float core = 1.0 - smoothstep(0.02, 0.2, r);
	float f = 1.0 - smoothstep(0.35, 1.0, prog);
	ALBEDO = vec3(1.0, 0.97, 0.84) * 2.2;
	ALPHA = clamp(rays + core, 0.0, 1.0) * f;
	if (ALPHA < 0.004) discard;
}
"""

const WHITE_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
uniform vec2 center = vec2(0.5);
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = (SCREEN_UV - center) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = (0.5 + 0.5 * sin(a * 41.0 + 1.3 * sin(a * 7.0))) * (0.5 + 0.5 * sin(a * 97.0 + 2.0));
	float rays = smoothstep(0.08, 0.5, s) * (1.0 - smoothstep(0.2, 1.6, r));
	float core = 1.0 - smoothstep(0.1, 0.25 + 1.1 * k, r);
	float m = clamp(core + rays * k * 1.3 + k * k * 0.88, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0, 0.97, 0.82), vec3(1.0), m);
	ALPHA = m * min(1.0, k * 1.6);
}
"""


static func _ball_mesh() -> Mesh:
	return Kit.cached_mesh("hikaridama", func():
		var b = MB.new()
		var base = Color(0.76, 0.68, 0.42)
		var thread = Color(0.55, 0.46, 0.25)
		var ink = Color(0.05, 0.05, 0.05)
		var r = 0.15
		b.add("sphere", Vector3.ZERO, Vector3.ONE * (r * 2.0), base, Vector3.ZERO, 14)
		for i in 9:   # iple sarım: kutuptan kutba enlem halkaları (ref: üstte toplanan ip)
			var lat = lerpf(-1.25, 1.25, float(i) / 8.0)
			for j in 6:
				var yaw = float(j) / 6.0 * TAU
				var c = Vector3(cos(lat) * sin(yaw), sin(lat), cos(lat) * cos(yaw)).normalized()
				var t = Vector3.UP.cross(c).normalized()
				Kit.patch(b, c, t, 1.12, 0.035, r + 0.001, thread, 3, 1)
		for face in [Vector3.BACK, Vector3.FORWARD]:   # iki yüzde 光
			var f: Vector3 = face
			var strokes = [[Vector2(0, 0.42), Vector2(0, 0.08)], [Vector2(-0.36, 0.38), Vector2(-0.18, 0.18)], [Vector2(0.36, 0.38), Vector2(0.18, 0.18)],
				[Vector2(-0.56, 0.03), Vector2(0.56, 0.03)], [Vector2(-0.14, 0.0), Vector2(-0.4, -0.54)], [Vector2(0.14, 0.0), Vector2(0.14, -0.44)], [Vector2(0.14, -0.46), Vector2(0.5, -0.46)]]
			for st in strokes:
				Kit.stroke(b, f, Vector3.UP, st[0], st[1], 0.1, r + 0.003, ink)
		b.add("torus", Vector3(0, r + 0.012, 0), Vector3(0.04, 0.04, 0.04), thread, Vector3(90, 0, 0), 8)
		return b.build(Props.toon()))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "hikaridama", 32.0, 4.0, _ball_mesh(), 1.0, Vector3(5, 7, 0))
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		burst(who, pos + Vector3.UP * 0.5)
	return pr


static func burst(who: Node3D, pos: Vector3) -> void:
	var root = Node3D.new()
	Kit.scene().add_child(root)
	root.global_position = pos
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.98, 0.9)
	l.omni_range = 34.0
	l.light_energy = 16.0
	root.add_child(l)
	var tw = root.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(root.queue_free)
	var rays = Kit.quad(root, 24.0, Kit.shader_mat("hikari_isin", RAY_SH))
	Kit.tween_param(rays, "prog", 0.0, 1.0, 0.42)
	Sfx.play("boom", pos, 2.1, 0.5)
	Game.set_meta("hikari_kage_until", Game.now() + SHADOW_T)   # Jutsu.shadow_k bunu okur: gölge tekniklerinin menzili uzar
	if is_instance_valid(who) and Kit.clan_of(who) == "nara":
		Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Gölge uzadı!", Color(0.7, 0.68, 0.9))
	var kemuri = load(KEMURI_PATH)
	for f in Kit.fighters():
		if f.is_dead() or not f.has_method("apply_status"):
			continue
		var e: Vector3 = Kit.eye(f)
		var d = e.distance_to(pos)
		if d > R:
			continue
		var enemy_of_thrower = is_instance_valid(who) and Combat.hostile(who, f)
		if not enemy_of_thrower and d > SELF_R:
			continue
		if not _looks_at(f, e, pos, d):
			continue
		var q = PhysicsRayQueryParameters3D.create(e, pos, 1)
		if not f.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		if kemuri.blocked(e, pos):
			continue
		_blind(f, lerpf(BLIND_MAX, BLIND_MIN, d / R), pos)


static func _looks_at(f: Node3D, e: Vector3, pos: Vector3, d: float) -> bool:
	if d < POINT_BLANK:
		return true
	var look: Vector3
	if f is Player and f.cam != null:
		look = -f.cam.global_transform.basis.z
	elif f.has_method("face_dir"):
		look = f.face_dir()
	else:
		return false
	return look.dot((pos - e).normalized()) > 0.15


## Düşman: hedefini kaybeder + kısa sersemleme. Oyuncu: ekran beyaza boğulur + kilit düşer + aynı sersemleme (üst sınırlı).
static func _blind(f: Node3D, t: float, pos: Vector3) -> void:
	if f is Player:
		f.apply_status("stun", minf(0.7, t * 0.3))
		if f.combat != null:
			f.combat.lock_target = null
		_white(f, t, pos)
	elif f.has_method("lose_target"):
		f.lose_target(t)
		f.apply_status("stun", t * 0.35)
		Combat.popup_text(f.global_position + Vector3.UP * (Kit.height_of(f) + 0.6), "KÖR!", Color(1, 1, 0.7))


static func _white(pl: Node3D, t: float, pos: Vector3) -> void:
	var s = Kit.screen("hikari", WHITE_SH)
	var m: ShaderMaterial = s.material_override
	var c = Vector2(0.5, 0.45)
	if pl.cam != null and not pl.cam.is_position_behind(pos):
		var vs: Vector2 = pl.cam.get_viewport().get_visible_rect().size
		c = pl.cam.unproject_position(pos) / vs
	m.set_shader_parameter("center", c)
	m.set_shader_parameter("k", 1.0)
	s.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = s.create_tween()
	_tw.tween_interval(t * 0.35)
	_tw.tween_method(func(v: float): m.set_shader_parameter("k", v), 1.0, 0.0, t * 0.65)
	_tw.tween_callback(func():
		if is_instance_valid(s):
			s.visible = false)
