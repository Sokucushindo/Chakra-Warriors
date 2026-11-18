extends RefCounted
## Fukumi-bi (ağızda saklanan köz; kanonda adsız; hedef: res://scripts/combat/fx/agiz_kozu_fx.gd). Kanon (Narutopedia "Concealed Mouth Ember", anime 105, Ibiki): ninja ağzında küçük köz saklar,
## ısırınca canlanır, yanıcı maddeye tükürüp tutuşturur. Ref refs/agiz_kozu: küçük parlak sarı-turuncu köz. Oyunda: el gerekmez, başka eylem sürerken de tükürülür; az hasar, yakar;
## Kibaku Fuda gibi aleve duyarlı şeyleri tutuşturur (ateş mermisi sayılır).

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")

const CD := 9.0

const GLOW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float m = pow(max(0.0, 1.0 - r), 2.0);
	if (m < 0.01) discard;
	ALBEDO = mix(vec3(1.0, 0.42, 0.06), vec3(1.0, 0.86, 0.34), m) * 2.0;
	ALPHA = m;
}
"""


static func _vis() -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = Kit.cached_mesh("koz", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.05, 0.036, 0.05), Color(1.0, 0.72, 0.16), Vector3.ZERO, 6)
		return b.build(Props.toon_color(Color(1.0, 0.72, 0.16), 0.8)))
	root.add_child(mi)
	Kit.quad(root, 0.42, Kit.shader_mat("koz_isik", GLOW_SH))
	return root


static func spit(who: Node3D, tg: Node3D) -> void:
	var from: Vector3 = Kit.eye(who) + who.face_dir() * 0.22
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var on_hit = func(pos: Vector3, t: Node3D) -> void:
		Sfx.play("fire", pos, 1.9, 0.3)
		if t != null and is_instance_valid(t) and t.has_method("apply_status"):
			t.apply_status("burn", 2.5)
	U.fire(who, from, U.solve(from, aim, 28.0, 4.0), {"g": 4.0, "r": 0.09, "life": 1.3, "vis": _vis(), "hit": on_hit,
		"info": {"dmg": 4.0 * Kit.tool_mult(who), "knock": 0.3, "kind": "light", "element": "katon", "hitstop": 0.0}})
	Sfx.play("click", from, 0.7, 0.35)   # ısırış


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, target: Node3D) -> Projectile:
	spit(who, target)
	return null


static func player_use(p: Node3D) -> void:
	if T.gate(p, "agiz_kozu", CD, false, 0.0, true):
		spit(p, U.target_of(p))
