extends RefCounted
## Okarina (hedef: res://scripts/combat/fx/okarina_fx.gd). Kanon (Narutopedia "Ocarina", ANİME 213, Menma): kişinin gücünü ve hızını artırır, genjutsudan çıkarır.
## Ref refs/okarina/Ocarina.png: bej damla gövde, ortada ek çizgisi, sekiz delik, gri ağızlık. Oyunda: kısa ezgi; çevredeki yoldaşlar ve çalan güçlenir, genjutsudan çıkar.
## Çalarken korumasızsın. Oyuncu ve düşman aynı.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")

const R := 12.0
const PLAY := 0.95
const BUFF_T := 14.0
const CD := 40.0
const GEN := ["fear", "kokuangyo", "stun"]   # Kai ile aynı durumlar
const CLAY := Color(0.72, 0.6, 0.44)

const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float wave = 0.02 * sin(a * 8.0 + prog * 9.0);
	float m = 1.0 - smoothstep(0.004, 0.016, abs(r + wave - prog * 0.95));
	m *= smoothstep(0.15, 0.55, 0.5 + 0.5 * sin(a * 5.0 - prog * 6.0));
	if (m < 0.02) discard;
	ALBEDO = vec3(1.0, 0.9, 0.62) * 1.5;
	ALPHA = m * (1.0 - prog);
}
"""


## Uç +Z ağızlık, Y üst yüz
static func build(b: MB) -> void:
	b.add("sphere", Vector3(0, 0, -0.012), Vector3(0.075, 0.042, 0.135), CLAY, Vector3.ZERO, 12)
	b.add("cone", Vector3(0, 0, 0.066), Vector3(0.05, 0.075, 0.028), CLAY, Vector3(90, 0, 0), 8)
	b.add("cone", Vector3(0, 0, 0.098), Vector3(0.022, 0.024, 0.012), Color(0.52, 0.45, 0.48), Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, 0.0, -0.012), Vector3(0.078, 0.004, 0.002), CLAY.darkened(0.3))
	var holes = [[-0.024, 0.03], [0.024, 0.03], [-0.03, 0.002], [0.03, 0.002], [-0.028, -0.03], [0.028, -0.03], [-0.016, -0.055], [0.016, -0.055]]
	for h in holes:
		b.add("sphere", Vector3(h[0], 0.0195, h[1]), Vector3(0.012, 0.004, 0.009), Color(0.08, 0.06, 0.05), Vector3.ZERO, 6)


static func _note() -> Mesh:
	return Kit.cached_mesh("okarina_nota", func():
		var b = MB.new()
		var c = Color(1.0, 0.86, 0.5)
		b.add("sphere", Vector3(0, -0.05, 0), Vector3(0.05, 0.036, 0.012), c, Vector3.ZERO, 6)
		b.add("box", Vector3(0.022, 0.01, 0), Vector3(0.007, 0.12, 0.006), c)
		b.add("box", Vector3(0.042, 0.062, 0), Vector3(0.042, 0.012, 0.006), c, Vector3(0, 0, -24))
		return b.build(Props.toon_color(c, 0.4)))


static func _pose(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null:
		return
	var W = S.LEG_WIDE
	var r = {"RightUpperArm": Vector3(-0.25, -0.65, 0.72), "RightLowerArm": Vector3(0.55, 0.72, 0.42)}
	var l = {"LeftUpperArm": Vector3(0.25, -0.65, 0.72), "LeftLowerArm": Vector3(-0.55, 0.72, 0.42)}
	var r0 = {"RightUpperArm": Vector3(-0.25, -0.9, 0.3), "RightLowerArm": Vector3(0.1, -0.4, 0.9)}
	var l0 = {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(-0.1, -0.4, 0.9)}
	var fw = Vector3(0, 0, 1)
	m.overlay.play_keys({"len": PLAY + 0.2, "hit": PLAY, "keys": [
		S._k(0.0, 0.36, 0.0, 2.0, fw, S._a(r0, l0), W), S._k(0.18, 0.34, 0.0, -3.0, fw, S._a(r, l), W),
		S._k(PLAY, 0.34, 0.0, -5.0, fw, S._a(r, l), W), S._k(PLAY + 0.2, 0.36, 0.0, 2.0, fw, S._a(r0, l0), W)]}, 1.0)
	if m.has_method("hold_temp"):
		m.hold_temp("okarina", PLAY + 0.05, "Left", 1.0, 0.0, false, true)
	who.get_tree().create_timer(PLAY + 0.18).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())


static func _notes(who: Node3D) -> void:
	for k in 7:
		who.get_tree().create_timer(k * 0.13).timeout.connect(func():
			if not is_instance_valid(who):
				return
			var mi = MeshInstance3D.new()
			mi.mesh = _note()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Kit.scene().add_child(mi)
			var p: Vector3 = Kit.eye(who) + who.face_dir() * 0.25
			var side = randf_range(-0.5, 0.5)
			var fly = func(v: float) -> void:
				if is_instance_valid(mi):
					mi.global_position = p + Vector3(side * v + sin(v * 7.0) * 0.08, v * 1.1, side * 0.4 * v)
					mi.scale = Vector3.ONE * (1.0 - smoothstep(0.65, 1.0, v))
			var tw = mi.create_tween()
			tw.tween_method(fly, 0.0, 1.0, 0.8)
			tw.tween_callback(mi.queue_free)
			Sfx.play("genjutsu", p, 1.7 + [0.0, 0.2, 0.35, 0.2, 0.5, 0.35, 0.6][k], 0.16))


static func _bless(f: Node3D) -> void:
	var mods = {"melee": 1.2, "speed": 1.15}
	if f is Player:
		Buffs.add("okarina", BUFF_T, mods)
	elif f.has_method("add_buff"):
		f.add_buff("okarina", BUFF_T, mods)
	var had = false
	for s in GEN:
		if f.statuses.has(s):
			f.statuses.erase(s)
			had = true
	if had and f is Player:
		f.input_locked = 0.0
	Combat.popup_text(f.global_position + Vector3.UP * 2.2, "Genjutsu çözüldü" if had else "Ezgi", Color(1.0, 0.88, 0.58))


static func use(who: Node3D) -> void:
	_pose(who)
	_notes(who)
	who.get_tree().create_timer(PLAY).timeout.connect(func():
		if not is_instance_valid(who) or who.is_dead():
			return
		var q = Kit.quad(Kit.scene(), R * 2.0, Kit.shader_mat("okarina_halka", RING_SH))
		q.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), who.global_position + Vector3.UP * 0.2)
		Kit.tween_param(q, "prog", 0.0, 1.0, 0.7, true)
		for f in Kit.fighters():
			if f.is_dead() or f.get("statuses") == null or Combat.hostile(who, f):
				continue
			if f.global_position.distance_to(who.global_position) <= R:
				_bless(f))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	use(who)
	return null


static func player_use(p: Node3D) -> void:
	var c = p.combat
	if c.action != "" and c.action != "guard":
		return
	var nm = str(Data.items.get("okarina", {"name": "Okarina"})["name"])
	if not c.tool_owned("okarina"):
		Hud.msg("%s sende yok — pazardan bir kez al, sonra sınırsız." % nm, Color(1, 0.6, 0.5))
		return
	if float(c.tool_cd.get("okarina", 0.0)) > 0.0:
		Hud.msg("%s hazır değil: %d sn" % [nm, ceili(float(c.tool_cd["okarina"]))], Color(1, 0.75, 0.5))
		return
	c.tool_cd["okarina"] = CD
	c.action = "throw"
	c.t = 0.35 - PLAY   # eylem ezgi boyunca sürer
	use(p)
