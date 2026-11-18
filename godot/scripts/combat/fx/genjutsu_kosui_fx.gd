extends RefCounted
## Genjutsu Yaburi no Kōsui (幻術破りの香水; hedef: res://scripts/combat/fx/genjutsu_kosui_fx.gd). Kanon (Narutopedia "Genjutsu Nullifying Perfume", yalnız OYUN: Storm 4): Suna'nın koku duyusunu uyararak sözlü
## genjutsuyu bozan panzehri; Çöl Orkidesi ve Alev Otu; uzak savaşçılara verilir, Temari rüzgârıyla yayar. Görsel kaynağı YOK; şişe ve tanecikler bizim yorumumuz.
## Oyunda: sıkılır, 9 sn boyunca çevrede yoldaşların genjutsusu sürekli çözülür. Rüzgâr doğası ya da Temari yelpazesi menzili büyütür.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const LIFE := 9.0
const R := 7.0
const R_WIND := 12.0
const CD := 35.0
const GEN := ["fear", "kokuangyo", "sleep"]   # düz sersemleme genjutsu değil, çözülmez

const MOTE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, skip_vertex_transform;
instance uniform float age = 0.0;
instance uniform float span = 7.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float t = fract(age * (0.05 + COLOR.g * 0.08) + sd);
	vec3 c = VERTEX * span;
	c.x += sin(age * 0.7 + sd * 40.0) * 0.5;
	c.z += cos(age * 0.6 + sd * 30.0) * 0.5;
	c.y = 0.15 + t * 3.0;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float r = sd * 6.283 + age * 1.4;
	vec2 k = (UV - 0.5) * vec2(0.07, 0.13) * sin(t * 3.14159);
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (abs(p.x) > 1.0 - p.y * p.y) discard;
	ALBEDO = mix(vec3(0.93, 0.68, 0.86), vec3(0.98, 0.9, 0.7), sd);
	ALPHA = 0.85;
}
"""


static func build(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.05, 0.07, 0.05), Color(0.82, 0.64, 0.78), Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, 0.076), Vector3(0.018, 0.024, 0.018), Color(0.74, 0.62, 0.34), Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, 0.098), Vector3.ONE * 0.026, Color(0.62, 0.34, 0.5), Vector3.ZERO, 8)


static func _windy(who: Node3D) -> bool:
	if U.weapon_node(who, "temari_ogi") != null:
		return true
	if who is Player:
		return "fuuton" in (Game.profile.get("elements", []) as Array)
	return str(who.get("element")) == "fuuton"


static func _motes() -> Mesh:
	return Kit.cached_mesh("kosui_tane", func():
		var items := []
		for i in 70:
			var a = randf() * TAU
			var r = sqrt(randf())
			items.append([Vector3(cos(a) * r, 0.0, sin(a) * r), Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


static func use(who: Node3D) -> void:
	T.pose(who, "genjutsu_kosui", {"LeftUpperArm": Vector3(0.2, 0.1, 0.97), "LeftLowerArm": Vector3(-0.1, 0.55, 0.83)}, 0.5)
	Sfx.play("wind", who.global_position + Vector3.UP, 1.9, 0.3)
	var R_now = R_WIND if _windy(who) else R
	var s = {"t": 0.0, "scan": 0.0, "mi": null}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		(s["mi"] as GeometryInstance3D).set_instance_shader_parameter("age", float(s["t"]) + 20.0)
		if float(s["t"]) >= LIFE or not is_instance_valid(who):
			return true
		s["scan"] = float(s["scan"]) - dt
		if float(s["scan"]) <= 0.0:
			s["scan"] = 0.2
			for f in Kit.fighters():
				if f.is_dead() or f.get("statuses") == null or Combat.hostile(who, f) or f.global_position.distance_to(s["c"]) > R_now:
					continue
				var had = false
				for g in GEN:
					if f.statuses.has(g):
						f.statuses.erase(g)
						had = true
				if had:
					if f is Player:
						f.input_locked = 0.0
					Combat.popup_text(f.global_position + Vector3.UP * 2.2, "Koku uyandırdı", Color(0.95, 0.75, 0.9))
		return false
	var at: Vector3 = who.global_position
	s["c"] = at
	var root = Kit.ticker(at, fn)
	var mi = Kit.cards(root, _motes(), Kit.shader_mat("kosui_tane", MOTE_SH), Vector3(R_WIND + 1.0, 5.0, R_WIND + 1.0))
	mi.set_instance_shader_parameter("span", R_now)
	s["mi"] = mi


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	use(who)
	return null


static func player_use(p: Node3D) -> void:
	if T.gate(p, "genjutsu_kosui", CD, false, 0.5):
		use(p)
