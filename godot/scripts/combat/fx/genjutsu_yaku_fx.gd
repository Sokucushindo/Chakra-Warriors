extends RefCounted
## Genjutsu Yaku (幻術薬; hedef: res://scripts/combat/fx/genjutsu_yaku_fx.gd). Kanon (Narutopedia "Genjutsu Pill", Shippūden 318, Orochimaru): yutulunca bedeni felç eden genjutsu kurar, zihni de etkiler.
## Ref refs/genjutsu_yaku/Genjutsu_Pills.png: altın kapaklı cam şişe, soluk yeşil-krem hapler. Oyunda hedefe YUTTURMAK gerekir: 2.4 m içindeki, blok tutmayan rakibin ağzına tıkılır.
## Felç + hedef kaybı; güçlü hedefte oyunun sersemletme kırpması işler. Boşa gidince bekleme başlamaz.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")

const REACH := 2.4
const STUN := 3.2
const CD := 45.0
const PILL := Color(0.78, 0.78, 0.6)

const SWIRL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 0.5 + 0.5 * sin(a * 3.0 + r * 16.0 - TIME * 7.0);
	if (m < 0.82 || r > 0.95) discard;
	ALBEDO = vec3(0.62, 0.72, 0.42);
	ALPHA = (1.0 - r) * sin(prog * 3.14159);
}
"""


static func build(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.05, 0.08, 0.05), Color(0.84, 0.88, 0.86), Vector3(90, 0, 0), 10)
	for k in 9:
		var a = k * 2.399
		var r = 0.006 + k * 0.0022
		b.add("sphere", Vector3(cos(a) * r, sin(a) * r, -0.03 + k * 0.007), Vector3(0.018, 0.015, 0.018), PILL, Vector3.ZERO, 6)
	b.add("cyl", Vector3(0, 0, 0.048), Vector3(0.054, 0.018, 0.054), Color(0.74, 0.6, 0.28), Vector3(90, 0, 0), 12)


static func _victim(who: Node3D) -> Node3D:
	var best: Node3D = null
	var bd = REACH
	var fd: Vector3 = who.face_dir()
	for f in Kit.fighters():
		if f == who or f.is_dead() or not Combat.hostile(who, f) or f.get("guarding") == true:
			continue
		if f is Player and f.combat != null and f.combat.action == "guard":
			continue
		var v: Vector3 = f.global_position - who.global_position
		v.y = 0.0
		if v.length() < bd and (v.length() < 0.6 or v.normalized().dot(fd) > 0.2):
			bd = v.length()
			best = f
	return best


static func feed(who: Node3D, t: Node3D) -> void:
	U.face(who, t.global_position)
	T.pose(who, "genjutsu_yaku", {"LeftUpperArm": Vector3(0.1, 0.1, 0.99), "LeftLowerArm": Vector3(-0.1, 0.25, 0.96)}, 0.5)
	who.get_tree().create_timer(0.2).timeout.connect(func():
		if not U.alive(t):
			return
		var mul = Eyes.genjutsu_land(who, t, false)   # oyunun genjutsu kapısı: Sharingan direnci, Kyō Tenchi-ten, Tōgarashi
		if mul <= 0.0:
			return
		t.apply_status("stun", STUN * mul)
		if t.has_method("lose_target"):
			t.lose_target(STUN * mul)
		elif t is Player and t.combat != null:
			t.combat.lock_target = null
		Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Beden tutuldu!", Color(0.75, 0.85, 0.55))
		Sfx.play("genjutsu", t.global_position + Vector3.UP, 0.8, 0.6)
		var q = Kit.quad(Kit.scene(), 1.3, Kit.shader_mat("yaku_girdap", SWIRL_SH))
		q.global_position = Kit.eye(t) + Vector3.UP * 0.1
		Kit.tween_param(q, "prog", 0.0, 1.0, 1.4, true))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	var t = _victim(who)
	if t != null:
		feed(who, t)
	return null


static func player_use(p: Node3D) -> void:
	var t = _victim(p)
	if t == null:
		Hud.msg("Yutturmak için rakibin dibinde olmalısın.", Color(1, 0.75, 0.5))
		return
	if T.gate(p, "genjutsu_yaku", CD, false, 0.5):
		feed(p, t)
