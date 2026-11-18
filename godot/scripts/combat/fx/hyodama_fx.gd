extends RefCounted
## Hyōdama (氷玉; Narutopedia "Ice Bomb", kanon film: Fubuki Kakuyoku; hedef: res://scripts/combat/fx/hyodama_fx.gd). Mavi kristal küre kunaiye iple bağlanır, atılır; patlayınca toprağı kaldıracak güçte buz dikenleri fışkırır.
## Mekanik (alet): çarpınca yerden halka hâlinde buz dikeni; içindekiler havaya kalkar, kısa süre donar. Dikenler bir süre durup erir. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const R := 3.4
const DMG := 18.0
const FREEZE := 1.1
const SPIKES := 26
const LIFE := 2.4

const ICE_SH := """shader_type spatial;
render_mode unshaded, cull_back;
varying float h;
void vertex() {
	h = VERTEX.y + 0.5;
}
void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 c = mix(vec3(0.3, 0.62, 0.85), vec3(0.82, 0.96, 1.0), clamp(h * 0.8 + rim * 0.7, 0.0, 1.0));
	ALBEDO = c;
}
"""


static func _build_kunai() -> Mesh:
	var b = MB.new()
	var m = Color(0.2, 0.21, 0.25)
	b.add("cone", Vector3(0, 0, 0.14), Vector3(0.09, 0.22, 0.03), m, Vector3(90, 0, 0), 4)
	b.add("cyl", Vector3(0, 0, -0.03), Vector3(0.024, 0.14, 0.024), Color(0.62, 0.62, 0.6), Vector3(90, 0, 0), 6)
	b.add("torus", Vector3(0, 0, -0.12), Vector3(0.075, 0.075, 0.075), m, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.24), Vector3(0.006, 0.18, 0.006), Color(0.48, 0.46, 0.36), Vector3(90, 0, 0), 4)
	b.add("sphere", Vector3(0, 0, -0.37), Vector3.ONE * 0.12, Color(0.18, 0.6, 0.8), Vector3.ZERO, 10)
	b.add("torus", Vector3(0, 0, -0.37), Vector3(0.125, 0.04, 0.125), Color(0.5, 0.46, 0.34), Vector3(0, 0, 0), 12)
	return b.build(Props.toon())


static func _build_spike() -> Mesh:
	var c = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 5
	c.rings = 1
	return c


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "hyodama", 40.0, 6.0, Kit.cached_mesh("hyo_kunai", Callable(_build_kunai)), 4.0 * Kit.tool_mult(who))
	(pr.get_child(0) as Node3D).rotation.y = PI
	var boom = func(pos: Vector3, _t: Node3D) -> void:
		if is_instance_valid(who):
			erupt(who, pos)
	pr.on_hit = boom
	return pr


static func erupt(who: Node3D, at: Vector3) -> void:
	var g = Vector3(at.x, Game.jutsu_floor(at.x, at.z), at.z)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Kit.cached_mesh("hyo_spike", Callable(_build_spike))
	mm.instance_count = SPIKES
	var data = []
	for i in SPIKES:
		var a = randf() * TAU
		var r = sqrt(randf()) * R
		var p = Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = Game.jutsu_floor(g.x + p.x, g.z + p.z) - g.y
		var out = Vector3(cos(a), 2.4, sin(a)).normalized()
		var x = out.cross(Vector3.FORWARD if absf(out.z) < 0.9 else Vector3.RIGHT).normalized()
		data.append([p, Basis(x, out, x.cross(out)), randf_range(1.5, 3.4) * (1.15 - r / R * 0.55), randf_range(0.28, 0.5), r / R * 0.12])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var s = {"t": 0.0, "hit": false}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		if t >= LIFE:
			return true
		var melt = 1.0 - smoothstep(LIFE - 0.6, LIFE, t)
		for i in SPIKES:
			var e: Array = data[i]
			var g2 = clampf((t - float(e[4])) / 0.1, 0.0, 1.0) * melt
			var b: Basis = e[1]
			var L = float(e[2]) * g2
			var w = float(e[3]) * (0.4 + 0.6 * g2)
			mm.set_instance_transform(i, Transform3D(Basis(b.x * w, b.y * L, b.z * w), (e[0] as Vector3) + b.y * L * 0.5))
		if t >= 0.06 and not bool(s["hit"]) and is_instance_valid(who):
			s["hit"] = true
			var hits = Combat.hit_sphere(who, g + Vector3.UP, R, {"dmg": DMG * Kit.tool_mult(who), "knock": 1.0, "launch": 7.0, "kind": "heavy", "element": "hyoton", "hitstop": 0.06, "tool": "hyodama"})
			for h in hits:
				if h.has_method("apply_status"):
					h.apply_status("frozen", FREEZE)
		return false
	var root = Kit.ticker(g, fn)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Kit.shader_mat("hyo_ice", ICE_SH)
	mi.custom_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
	root.add_child(mi)
	Sfx.play("th_ice", g, 0.9, 0.9)
