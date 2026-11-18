extends RefCounted
## Mushū no Dokugiri (無臭の毒霧; hedef: res://scripts/combat/fx/mushu_dokugiri_fx.gd). Kanon (Narutopedia "Odourless Poison Mist", Hilal Krallığı filmi): patlayıcı etiketle saçılan kokusuz toz;
## solunca beş duyu bozulur, tepkiler yavaşlar, kullananlar kolayca kaçar ve vurur. Görünüş refs/mushu_dokugiri: etiketin sarı patlaması; toz neredeyse görünmez.
## Oyunda: 8 sn, 5,5 m. İçindeki düşman yavaşlar, tepkisi düşer (kaçış ve okuma becerisi yarıya iner). Atan etkilenmez. Oyuncuysa ekran kenarı dalgalanır. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const R := 5.5
const LIFE := 8.0

static var _veil := 0.0
static var _fr := -1

const MOTE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, skip_vertex_transform;
instance uniform float fade_k = 1.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	vec3 c = VERTEX + vec3(sin(TIME * 0.5 + sd * 40.0), 0.5 * sin(TIME * 0.7 + sd * 70.0), cos(TIME * 0.4 + sd * 90.0)) * 0.5;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * 0.035;
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	ALBEDO = vec3(0.86, 0.8, 0.92);
	ALPHA = 0.35 * fade_k;
}
"""

const POP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = (0.55 + 0.14 * sin(a * 7.0) + 0.08 * sin(a * 13.0)) * sqrt(min(1.0, prog * 3.0));
	float r = length(p);
	if (r > e || r < e * smoothstep(0.45, 1.0, prog)) discard;
	ALBEDO = r < e * 0.6 ? vec3(0.8, 0.55, 0.12) : vec3(0.42, 0.24, 0.5);
}
"""

const VEIL_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	float w = 0.08 * sin(p.y * 6.0 + TIME * 1.7) + 0.06 * sin(p.x * 7.0 - TIME * 1.3);
	float m = smoothstep(0.7, 1.35, length(p) + w);
	ALBEDO = vec3(0.3, 0.2, 0.36);
	ALPHA = k * m * 0.65;
}
"""


static func _body() -> Mesh:
	return Yk.mesh("mushu_tomar", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.09, 0.2, 0.09), Color(0.85, 0.81, 0.68), Vector3(90, 0, 0), 8)
		b.add("cyl", Vector3.ZERO, Vector3(0.096, 0.03, 0.096), Color(0.4, 0.2, 0.5), Vector3(90, 0, 0), 8)
		return b.build(Props.toon()))


static func _motes() -> Mesh:
	return Yk.mesh("mushu_toz", func():
		var items := []
		for i in 120:
			var d = Vector3(randf_range(-1, 1), randf_range(0.0, 0.5), randf_range(-1, 1)).limit_length(1.0)
			items.append([d * R, Color(randf(), 0.0, 0.0, 1.0)])
		return Kit.card_mesh(items))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "mushu_dokugiri", 30.0, 6.0, _body(), 1.0, Vector3(6, 4, 0))
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		burst(who, pos)
	return pr


static func _numb(f: Node3D) -> void:
	if f is Player:
		Buffs.add("mushu_dokugiri", 0.8, {"speed": 0.72, "_desc": "duyular bulanık, tepkiler yavaş"})
	elif f.has_method("add_buff"):
		f.add_buff("mushu_dokugiri", 0.8, {"speed": 0.72})
		if f.get("skill") != null and not f.has_meta("mushu_sk"):
			f.set_meta("mushu_sk", float(f.skill))
			f.skill = float(f.skill) * 0.5
		f.set_meta("mushu_u", Game.now() + 0.8)
		Yk.after(f, 0.9, func():
			if f.has_meta("mushu_sk") and Game.now() >= float(f.get_meta("mushu_u", 0.0)):
				f.skill = float(f.get_meta("mushu_sk"))
				f.remove_meta("mushu_sk"))


static func burst(who: Node3D, pos: Vector3) -> void:
	var fl = Game.jutsu_floor(pos.x, pos.z)
	var c = Vector3(pos.x, fl + 0.4 if pos.y - fl < 3.0 else pos.y, pos.z)
	var s = {"t": 0.0, "acc": 0.0, "mi": null}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		(s["mi"] as GeometryInstance3D).set_instance_shader_parameter("fade_k", 1.0 - smoothstep(LIFE - 1.5, LIFE, t))
		s["acc"] += dt
		var inside = false
		if float(s["acc"]) >= 0.3:
			s["acc"] = 0.0
			if is_instance_valid(who):
				for f in Kit.fighters():
					if Combat.hostile(who, f) and not f.is_dead() and f.global_position.distance_to(c) < R:
						_numb(f)
		var pl = Game.player
		if pl != null and is_instance_valid(pl) and is_instance_valid(who) and Combat.hostile(who, pl) and pl.global_position.distance_to(c) < R and t < LIFE - 0.6:
			inside = true
		_veil_tick(dt, inside)
		return t >= LIFE
	var root = Kit.ticker(c, fn)
	s["mi"] = Kit.cards(root, _motes(), Yk.mat("mushu_zerre", MOTE_SH), Vector3.ONE * (R + 2.0))
	var pop = Kit.quad(root, 4.5, Yk.mat("mushu_patlama", POP_SH))
	pop.position = Vector3.UP * 0.6
	Kit.tween_param(pop, "prog", 0.0, 1.0, 0.3, true)
	Sfx.play("boom", c, 1.6, 0.55)


static func _veil_tick(dt: float, inside: bool) -> void:
	var f = Engine.get_physics_frames()
	if f != _fr:   # birden çok bulut varken sönüm karede bir kez
		_fr = f
		_veil -= dt * 2.0
	if inside:
		_veil += dt * 4.0
	_veil = clampf(_veil, 0.0, 1.0)
	var v = Kit.screen("mushu", VEIL_SH)
	v.visible = _veil > 0.01
	v.material_override.set_shader_parameter("k", _veil)
