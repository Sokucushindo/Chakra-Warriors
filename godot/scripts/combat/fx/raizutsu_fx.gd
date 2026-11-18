extends RefCounted
## Raizutsu (雷筒; Narutopedia "Lightning Barrel", hedef: res://scripts/combat/fx/raizutsu_fx.gd). Kanon kullanıcılar: Kakashi, Sakura (anime). Ref: yeşil bambu boğumlu tüp.
## Kanon: tüp yere vurulunca tek şimşek atar; işaret fişeği gibi yeri belli eder, takım toplanır; yakındakini de çarpar.
## Mekanik (alet tuşu): tüp yere vurulur, gökyüzüne tek şimşek çıkar. 5 m içindeki rakipler çarpılır. Çevredeki yoldaşlar sana yönelir; BEDEL: uzaktaki düşmanlar da yerini öğrenir. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const SHOCK_R := 5.2
const DMG := 10.0
const STUN := 0.8
const ALLY_R := 70.0
const FOE_R := 50.0
const HEIGHT := 36.0

const BOLT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.3, 0.62, 1.0), vec3(0.95, 0.98, 1.0), smoothstep(0.35, 0.85, e));
	ALPHA = smoothstep(0.0, 0.45, e) * fade;
}
"""


static func _build_tube() -> Mesh:
	var b = MB.new()
	var g = Color(0.42, 0.62, 0.36)
	b.add("cyl", Vector3(0, 0.3, 0), Vector3(0.09, 0.62, 0.09), g, Vector3.ZERO, 10)
	for y in [0.12, 0.44]:
		b.add("cyl", Vector3(0, y, 0), Vector3(0.1, 0.018, 0.1), g.darkened(0.25), Vector3.ZERO, 10)
	b.add("cyl", Vector3(0, 0.612, 0), Vector3(0.06, 0.004, 0.06), Color(0.08, 0.1, 0.07), Vector3.ZERO, 10)
	return b.build(Props.toon())


## Kırık şimşek: iki dik düzlemde şerit
static func _bolt(root: Node3D, a: Vector3, b: Vector3, w: float, jag: float, life: float) -> void:
	var im = ImmediateMesh.new()
	var d = b - a
	var n = maxi(5, int(d.length() / 1.6))
	var pts: Array = []
	for i in n + 1:
		var u = float(i) / n
		var off = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * jag * sin(u * PI)
		pts.append(a + d * u + off)
	var f = d.normalized()
	var s1 = f.cross(Vector3.RIGHT if absf(f.x) < 0.9 else Vector3.UP).normalized()
	for s in [s1, s1.cross(f).normalized()]:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var k = 1.0 - float(i) / pts.size() * 0.55
			im.surface_set_uv(Vector2(i, 0))
			im.surface_add_vertex(pts[i] - s * w * k)
			im.surface_set_uv(Vector2(i, 1))
			im.surface_add_vertex(pts[i] + s * w * k)
		im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("raizutsu_bolt", BOLT_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 60.0
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	Kit.tween_param(mi, "fade", 1.0, 0.0, life, true)


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	var g = who.global_position + Vector3(f.x, 0, f.z).normalized() * 0.55
	g.y = Game.jutsu_floor(g.x, g.z)
	var s = {"t": 0.0, "fired": false}
	var box := {}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		var tube: Node3D = box["tube"]
		tube.position.y = -0.35 * (1.0 - clampf(t / 0.1, 0.0, 1.0))
		if t >= 0.14 and not bool(s["fired"]):
			s["fired"] = true
			if is_instance_valid(who):
				_fire(who, g, box["root"])
		return t > 1.0
	var root = Kit.ticker(g, fn)
	box["root"] = root
	var tube = MeshInstance3D.new()
	tube.mesh = Kit.cached_mesh("raizutsu_tube", Callable(_build_tube))
	root.add_child(tube)
	box["tube"] = tube
	Sfx.play("step_wood", g, 0.8, 0.8)
	return null


static func _fire(who: Node3D, g: Vector3, root: Node3D) -> void:
	var mouth = g + Vector3.UP * 0.62
	_bolt(root, mouth, mouth + Vector3.UP * HEIGHT, 0.2, 1.3, 0.55)
	_bolt(root, mouth + Vector3.UP * 12.0, mouth + Vector3(randf_range(-6, 6), 20.0, randf_range(-6, 6)), 0.08, 0.8, 0.35)
	Sfx.play("thunder", mouth, 1.25, 0.95)
	Sfx.play("zap", mouth, 0.9, 0.8)
	var mult = Kit.tool_mult(who)
	var hits = Combat.hit_sphere(who, g + Vector3.UP, SHOCK_R, {"dmg": DMG * mult, "knock": 2.0, "stun": STUN, "kind": "light", "element": "raiton", "hitstop": 0.05, "tool": "raizutsu"})
	for h in hits:
		_bolt(root, mouth, Kit.chest(h), 0.07, 0.45, 0.28)
	_signal(who, g, hits)


## İşaret: yoldaşlar gelir, düşmanlar yeri öğrenir (kanon: yerini belli eder)
static func _signal(who: Node3D, g: Vector3, hits: Array) -> void:
	var near_foe: Node3D = hits[0] if not hits.is_empty() else who.get("target") as Node3D
	var came = 0
	for f in Kit.fighters():
		if f == who or not (f is Enemy) or f.is_dead():
			continue
		var d = f.global_position.distance_to(g)
		if Combat.hostile(who, f):
			if d <= FOE_R and (f.target == null or not is_instance_valid(f.target)):
				f.target = who
		elif d <= ALLY_R and near_foe != null and is_instance_valid(near_foe) and Combat.hostile(f, near_foe):
			f.target = near_foe
			came += 1
	if who is Player:
		Combat.popup_text(g + Vector3.UP * 2.6, "İşaret verildi" if came == 0 else "%d yoldaş geliyor" % came, Color(0.7, 0.86, 1.0))
