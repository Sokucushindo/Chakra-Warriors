extends RefCounted
## Tōgarashi-dama (biber bombası; kanonda adı yok, ad bizim; hedef: res://scripts/combat/fx/togarashi_dama_fx.gd).
## Kanon (Narutopedia "Chilli Pepper Bomb", Shippūden 187): Genjutsu Ağacı Köyü halkının misket boyu turuncu topları;
## yayılan acı genjutsuyu kırar, insanların attığı genjutsuyu da. Sukune parmak aralarında ÜÇ tane tutar (refs/togarashi_dama).
## Mekanik: toz bulutundaki HERKES (atan, yoldaş, düşman) genjutsudan kurtulur ve bulut sürerken yenisi tutmaz.
## Bedel (kanonda geçmez, gerçek biberden çıkarım): içindeki öksürür, yavaşlar; hasar yok.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const R := 3.4
const LIFE := 5.5
const GUARD := 0.5       # her yoklamada korumayı bu kadar uzatır
const COUGH := 0.6       # yavaşlık yenilemesi
const GEN := ["fear", "kokuangyo", "stun"]   # Kai'nin çözdüğü durumlar (Player._input ile aynı liste)

static var _eye_k := 0.0
static var _eye_frame := -1

const DUST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, skip_vertex_transform;
instance uniform float grow = 0.0;
instance uniform float fade_k = 1.0;
varying float sd;
varying float wisp;
void vertex() {
	sd = COLOR.r;
	wisp = COLOR.b;
	float ang = TIME * (0.25 + sd * 0.5) + sd * 40.0;
	float cs = cos(ang);
	float sn = sin(ang);
	vec3 c = VERTEX * grow;
	c = vec3(c.x * cs - c.z * sn, c.y + 0.12 * sin(TIME * 1.3 + sd * 60.0), c.x * sn + c.z * cs);
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float sz = wisp > 0.5 ? 1.5 + COLOR.g * 1.6 : 0.04 + COLOR.g * 0.07;
	vec2 k = (UV - 0.5) * sz;
	float r = sd * 6.283 + TIME * (wisp > 0.5 ? 0.15 : 2.5);
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a;
	vec3 col;
	if (wisp > 0.5) {
		float y = p.y + 0.35 * sin(p.x * 3.0 + sd * 20.0 + TIME * 0.8);
		float w = 0.09 + 0.05 * sin(p.x * 5.0 + sd * 9.0);
		a = (1.0 - smoothstep(w * 0.4, w, abs(y))) * (1.0 - p.x * p.x) * 0.42;
		col = mix(vec3(0.86, 0.3, 0.1), vec3(0.95, 0.5, 0.18), sd);
	} else {
		float fa = atan(p.y, p.x);   // düzensiz biber kırıntısı
		float fr = 0.62 + 0.22 * sin(fa * 3.0 + sd * 30.0) + 0.12 * sin(fa * 7.0 + sd * 11.0);
		a = 1.0 - step(fr, length(p));
		col = sd < 0.4 ? vec3(0.82, 0.16, 0.07) : (sd < 0.8 ? vec3(0.95, 0.42, 0.1) : vec3(0.45, 0.1, 0.06));
	}
	ALBEDO = col;
	ALPHA = a * fade_k;
	if (ALPHA < 0.01 || -VERTEX.z < 0.4) discard;
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
	float t = TIME * 0.6;
	float w = 0.06 * sin(atan(p.y, p.x) * 7.0 + t) + 0.04 * sin(atan(p.y, p.x) * 13.0 - t * 1.4);
	float m = smoothstep(0.62, 1.25, length(p) + w);
	ALBEDO = mix(vec3(0.85, 0.22, 0.08), vec3(0.45, 0.06, 0.04), m);
	ALPHA = k * m * 0.8;
}
"""


static func _ball_mesh() -> Mesh:
	return Kit.cached_mesh("togarashi", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.15, Color(0.72, 0.31, 0.13), Vector3.ZERO, 10)
		return b.build(Props.toon()))


static func _dust_mesh() -> Mesh:
	return Kit.cached_mesh("togarashi_toz", func():
		var items := []
		for i in 190:
			var d = Vector3(randf_range(-1, 1), randf_range(-0.05, 0.75), randf_range(-1, 1))
			items.append([d.limit_length(1.0) * R, Color(randf(), randf(), 0.0, 1.0)])
		for i in 14:
			var a = randf() * TAU
			var rr = randf_range(0.2, 0.85) * R
			items.append([Vector3(cos(a) * rr, randf_range(0.5, 2.2), sin(a) * rr), Color(randf(), randf(), 1.0, 1.0)])
		return Kit.card_mesh(items))


## Üçlü atış kararı çağıranda (shuriken gibi); her top kendi bulutunu açar
static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "togarashi_dama", 34.0, 5.0, _ball_mesh(), 1.0, Vector3(4, 9, 0))
	pr.radius = 0.1
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		burst(pos)
	return pr


static func burst(pos: Vector3) -> void:
	var fl = Game.jutsu_floor(pos.x, pos.z)
	var base = Vector3(pos.x, fl if pos.y - fl < 3.0 else pos.y - 1.0, pos.z)
	var s = {"t": 0.0, "acc": 0.0, "mi": null, "pop": {}}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		var mi: MeshInstance3D = s["mi"]
		mi.set_instance_shader_parameter("grow", (1.0 - exp(-t * 4.0)) * (1.0 + t * 0.03))
		mi.set_instance_shader_parameter("fade_k", 1.0 - smoothstep(LIFE - 1.5, LIFE, t))
		s["acc"] += dt
		var cam_in = false
		if s["acc"] >= 0.2:
			s["acc"] = 0.0
			_breathe(base, s)
		var pl = Game.player
		if pl != null and is_instance_valid(pl) and pl.global_position.distance_to(base) < R and t < LIFE - 0.8:
			cam_in = true
		_eye_tick(dt, cam_in)
		return t >= LIFE
	var root = Kit.ticker(base, fn)
	s["mi"] = Kit.cards(root, _dust_mesh(), Kit.shader_mat("togarashi_toz", DUST_SH), Vector3(6, 5, 6))
	Sfx.play("poof", pos, 1.45, 0.7)


static func _breathe(base: Vector3, s: Dictionary) -> void:
	var until = Game.now() + GUARD
	for f in Kit.fighters():
		if f.is_dead() or not f.has_method("apply_status"):
			continue
		var fp: Vector3 = f.global_position
		if Vector2(fp.x - base.x, fp.z - base.z).length() > R or absf(fp.y - base.y) > 3.0:
			continue
		f.set_meta("togarashi_until", until)   # Fighter/Player.apply_status, genjutsu_land ve _genjutsu bunu okur
		f.apply_status("slow", COUGH)
		var st = f.get("statuses")
		var freed = false
		if st is Dictionary:
			for k in GEN:
				if st.has(k):
					st.erase(k)
					freed = true
		if freed:
			if f is Player and not (f.has_status("bind") or f.has_status("frozen")):
				f.input_locked = 0.0
			Combat.popup_text(fp + Vector3.UP * (Kit.height_of(f) + 0.4), "Genjutsu çözüldü!", Color(1.0, 0.55, 0.3))
		elif not s["pop"].has(f.get_instance_id()):
			s["pop"][f.get_instance_id()] = true
			Combat.popup_text(fp + Vector3.UP * (Kit.height_of(f) + 0.4), "Öksürük!", Color(0.95, 0.5, 0.3))


static func _eye_tick(dt: float, inside: bool) -> void:
	var fr = Engine.get_physics_frames()
	if fr == _eye_frame:
		if inside:
			_eye_k = minf(1.0, _eye_k + dt * 3.0)
		return
	_eye_frame = fr
	_eye_k = clampf(_eye_k + dt * (3.0 if inside else -2.0), 0.0, 1.0)
	var v = Kit.screen("togarashi", EYE_SH)
	v.visible = _eye_k > 0.01
	v.material_override.set_shader_parameter("k", _eye_k)
