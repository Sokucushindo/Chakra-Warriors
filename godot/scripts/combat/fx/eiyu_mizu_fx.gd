extends RefCounted
## Eiyū no Mizu (英雄の水; hedef: res://scripts/combat/fx/eiyu_mizu_fx.gd). Kanon (Narutopedia "Hero Water"; OVA 1, Takigakure; Hisen, Shibuki, Suien): yüz yılda bir dev ağacın
## verdiği sıvı. İçene kısa süre en az on kat chakra verir; Suien bununla kunaileri savuran chakra kalkanı yaptı. Bedeli ÖMÜR: Shibuki'nin babası bu yüzden öldü.
## Oyunda: tek kullanımlık, satılmaz; Taki'nin "Kahraman Suyu" görevinden gelir. 16 sn chakra hiç bitmez, jutsu ve vuruş güçlenir, küçük mermiler savrulur. Sonunda chakra sıfır,
## ağırlaşma; oyuncunun ömrü 6 yıl kısalır (düşmanda azami can düşer). Ref refs/eiyu_mizu/The_Heroes_Water.PNG: ikiz küreli cam kabak, ip, mantar tıpa.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")

const DUR := 16.0
const LIFE_COST := 6.0
const CRASH := 5.0
const AURA_R := 1.5

const STREAM_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade_k = 1.0;
void fragment() {
	float x = fract(UV.x * 3.0 - TIME * 1.7);
	float w = 0.5 * smoothstep(0.0, 0.25, x) * (1.0 - smoothstep(0.45, 1.0, x));
	if (abs(UV.y - 0.5) > w) discard;
	ALBEDO = mix(vec3(0.55, 0.85, 1.0), vec3(1.0), x) * 1.6;
	ALPHA = fade_k * 0.9;
}
"""


## Tıpa +Z
static func build(b: MB) -> void:
	var glass = Color(0.72, 0.76, 0.9)
	var liq = Color(0.4, 0.42, 0.34)
	b.add("sphere", Vector3(0, 0, -0.055), Vector3.ONE * 0.1, glass, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0, 0.05), Vector3.ONE * 0.085, glass, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, -0.006, -0.055), Vector3.ONE * 0.088, liq, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, -0.005, 0.05), Vector3.ONE * 0.074, liq, Vector3.ZERO, 10)
	for z in [-0.006, 0.0, 0.006]:
		b.add("torus", Vector3(0, 0, z), Vector3(0.05, 0.05, 0.05), Color(0.62, 0.54, 0.34), Vector3(90, 0, 0), 12)
	b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.024, 0.024, 0.024), Color(0.66, 0.54, 0.38), Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, -0.05, 0.002), Vector3(0.005, 0.07, 0.005), Color(0.62, 0.54, 0.34))


static func _pose(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null:
		return
	var W = S.LEG_WIDE
	var r = {"RightUpperArm": Vector3(-0.25, -0.9, 0.3), "RightLowerArm": Vector3(0.1, -0.4, 0.9)}
	var l0 = {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(-0.1, -0.4, 0.9)}
	var l1 = {"LeftUpperArm": Vector3(0.28, -0.55, 0.78), "LeftLowerArm": Vector3(-0.5, 0.82, 0.25)}
	var fw = Vector3(0, 0, 1)
	m.overlay.play_keys({"len": 0.75, "hit": 0.4, "keys": [S._k(0.0, 0.36, 0.0, 2.0, fw, S._a(r, l0), W), S._k(0.25, 0.34, 0.0, -10.0, fw, S._a(r, l1), W),
		S._k(0.52, 0.34, 0.0, -14.0, fw, S._a(r, l1), W), S._k(0.75, 0.4, 0.0, 6.0, fw, S._a(r, l0), W)]}, 1.0)
	if m.has_method("hold_temp"):
		m.hold_temp("eiyu_mizu", 0.55, "Left", 1.0, 0.0, false, true)
	who.get_tree().create_timer(0.72).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())


static func _spiral(root: Node3D) -> MeshInstance3D:
	var mesh = Kit.cached_mesh("eiyu_sarmal", func():
		var im = ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 61:
			var k = i / 60.0
			var a = k * TAU * 2.5
			var p = Vector3(cos(a) * 0.62, k * 2.0, sin(a) * 0.62)
			im.surface_set_uv(Vector2(k, 0.0))
			im.surface_add_vertex(p + Vector3.UP * -0.035)
			im.surface_set_uv(Vector2(k, 1.0))
			im.surface_add_vertex(p + Vector3.UP * 0.035)
		im.surface_end()
		return im)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kit.shader_mat("eiyu_akim", STREAM_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func use(who: Node3D) -> void:
	_pose(who)
	Sfx.play("water", who.global_position + Vector3.UP, 1.2, 0.5)
	var mods = {"jutsu": 1.55, "melee": 1.3, "speed": 1.12}
	who.get_tree().create_timer(0.42).timeout.connect(func():
		if not is_instance_valid(who):
			return
		if who is Player:
			Buffs.add("eiyu_mizu", DUR, mods)
		elif who.has_method("add_buff"):
			who.add_buff("eiyu_mizu", DUR, mods)
		Sfx.play("charge", who.global_position, 0.8, 0.7)
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kahraman Suyu", Color(0.7, 0.9, 1.0))
		_run(who))


static func _run(who: Node3D) -> void:
	var st = {"t": 0.0, "root": null, "mi": null}
	var fn = func(dt: float) -> bool:
		st["t"] += dt
		if not is_instance_valid(who) or who.is_dead():
			return true
		var r: Node3D = st["root"]
		r.global_position = who.global_position
		r.rotate_y(dt * 3.2)
		if who.get("chakra") != null and who.get("max_chakra") != null:
			who.chakra = float(who.max_chakra)   # kanon: on kat chakra; süre boyunca tükenmez
		var c: Vector3 = who.global_position + Vector3.UP * 1.1
		for pr in Kit.tree().get_nodes_in_group("projectiles"):   # Suien: chakra akışı kunaileri savurur
			if is_instance_valid(pr) and not pr.dead and pr.shooter != null and is_instance_valid(pr.shooter) and Combat.hostile(who, pr.shooter) and float(pr.radius) < 0.3 and (pr.info.get("element", "") in [null, ""]) and pr.global_position.distance_to(c) < AURA_R:
				pr.vel = (pr.global_position - c).normalized() * pr.vel.length() * 0.7 + Vector3.UP * 3.0
				pr.hit_list.append(who)
		if float(st["t"]) >= DUR:
			_crash(who)
			return true
		return false
	var root = Kit.ticker(who.global_position, fn)
	st["root"] = root
	st["mi"] = _spiral(root)


## Bedel
static func _crash(who: Node3D) -> void:
	if who.get("chakra") != null:
		who.chakra = 0.0
	if who.has_method("apply_status"):
		who.apply_status("slow", CRASH)
	Sfx.play("heartbeat", who.global_position, 0.8, 0.8)
	if who is Player:
		Aging.lifespan()   # kayıt yoksa üretir
		Game.profile["life"] = float(Game.profile["life"]) - LIFE_COST
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Ömrün kısaldı", Color(0.85, 0.75, 0.9))
	elif who.get("max_hp") != null:
		who.max_hp = float(who.max_hp) * 0.7
		who.hp = minf(float(who.hp), float(who.max_hp))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	who.set_meta("eiyu_ictim", true)
	use(who)
	return null


static func player_use(p: Node3D) -> void:
	var c = p.combat
	if c.action != "" and c.action != "guard":
		return
	var inv: Dictionary = Game.profile["inventory"]
	if int(inv.get("eiyu_mizu", 0)) <= 0:
		Hud.msg("Kahraman Suyu kalmadı.", Color(1, 0.6, 0.5))
		return
	if Buffs.has("eiyu_mizu"):
		return
	inv["eiyu_mizu"] = int(inv["eiyu_mizu"]) - 1
	c.action = "throw"
	c.t = -0.35
	use(p)
