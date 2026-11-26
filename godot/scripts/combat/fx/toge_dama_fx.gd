extends RefCounted
## Toge-dama (diken bombası; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/toge_dama_fx.gd). Kanon (Narutopedia "Spike Bomb", "Spike Rain", Shippūden 307):
## ortasında barut olan küçük diken topu; atılınca patlar, dikenleri her yöne fırlatır. Birkaçı birden atılıp geniş alan kaplanır. Görünüş refs/toge_dama: kahverengi, sık piramit dikenli top.
## Oyunda: üçlü atış, HAVADA patlar (rakibe değince hemen). Her diken gerçek uçan parça; siperin ardına geçen ya da kaçan vurulmaz. Bakusaidama'dan farkı: etiket patlaması yok, hasar yalnız dikenlerden.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const SPIKES := 42
const FUSE := 0.72
const SPEED := 15.0
const DMG := 3.2
const MAX_HITS := 4       # bir toptan bir kişiye en çok
const LIFE := 1.3

const POP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = (0.3 + 0.55 * abs(sin(a * 6.0 + 0.7)) * abs(sin(a * 11.0))) * sin(min(prog * 3.0, 1.0) * 1.57);
	if (length(p) > e) discard;
	ALBEDO = mix(vec3(1.0, 0.82, 0.42), vec3(0.8, 0.32, 0.1), prog) * 1.5;
	ALPHA = 1.0 - prog;
}
"""


static func _fib(i: int, n: int) -> Vector3:
	var y = 1.0 - (float(i) + 0.5) / n * 2.0
	var r = sqrt(maxf(0.0, 1.0 - y * y))
	var a = float(i) * 2.399963
	return Vector3(cos(a) * r, y, sin(a) * r)


static func _ball() -> Mesh:
	return Yk.mesh("toge_top", func():
		var b = MB.new()
		var c = Color(0.36, 0.23, 0.17)
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.17, c.darkened(0.3), Vector3.ZERO, 8)
		for i in 64:
			var d = _fib(i, 64)
			var x = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var col = c if i % 3 else c.lightened(0.14)
			b.add_xf("cone", Transform3D(Basis(x * 0.05, d * 0.065, x.cross(d) * 0.05), d * 0.1), col, 4)
		return b.build(Props.toon()))


static func _spike() -> Mesh:
	return Yk.mesh("toge_diken", func():
		var b = MB.new()
		b.add("cone", Vector3(0, 0, 0.03), Vector3(0.04, 0.09, 0.04), Color(0.36, 0.23, 0.17), Vector3(90, 0, 0), 4)
		return b.build(Props.toon()))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "toge_dama", 25.0, 8.0, _ball(), 1.0, Vector3(7, 9, 4))
	pr.life = FUSE
	var mult = Kit.tool_mult(who)
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		burst(who, pos + Vector3.UP * 0.15, mult)
	return pr


static func burst(who: Node3D, at: Vector3, mult: float) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _spike()
	mm.instance_count = SPIKES
	var sp := []
	for i in SPIKES:
		var d = _fib(i, SPIKES)
		sp.append({"p": at, "v": d * SPEED * randf_range(0.8, 1.15) + Vector3.UP * 1.0, "on": true, "fly": true})
	var hits := {}
	var s = {"t": 0.0}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		# adaylar karede bir kez: düşman, ayakta ve diken bulutuna erişebilir (eskiden her diken her karede herkesi tarıyordu:
		# köyde ~130 kişi x diken sayısı -> 2 sn boyunca kare başı 20-60 ms). Sonuç aynı: elenenler zaten değemezdi.
		var fs: Array = []
		if is_instance_valid(who):
			var reach = SPEED * 1.2 * (s["t"] + 0.1) + 6.0
			for f in Kit.fighters():
				var fh = f.get("height")
				if fh != null and not f.has_method("hit_test") and f.global_position.distance_to(at) > reach + float(fh):
					continue
				if Combat.hostile(who, f) and not f.is_dead():
					fs.append(f)
		for i in SPIKES:
			var e: Dictionary = sp[i]
			if not e["on"]:
				continue
			if e["fly"]:
				var v: Vector3 = e["v"]
				v.y -= 16.0 * dt
				e["v"] = v
				var p: Vector3 = (e["p"] as Vector3) + v * dt
				if p.y <= Game.jutsu_floor_at(p).y:
					p.y = Game.jutsu_floor_at(p).y + 0.02
					e["fly"] = false
				e["p"] = p
				if is_instance_valid(who):
					for f in fs:
						if is_instance_valid(f) and not f.is_dead() and Combat.capsule_hit(p, f, 0.1):
							e["on"] = false
							var id = f.get_instance_id()
							if int(hits.get(id, 0)) < MAX_HITS:
								hits[id] = int(hits.get(id, 0)) + 1
								f.take_hit({"dmg": DMG * mult, "knock": 0.6, "kind": "light", "attacker": who, "dir": v.normalized(), "hitstop": 0.0, "bleed": 1.0, "tool": "toge_dama"})
							break
			var vd: Vector3 = e["v"]
			var z = vd.normalized() if vd.length() > 0.01 and e["fly"] else Vector3.DOWN
			var x = z.cross(Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT).normalized()
			var sc = 0.0 if not e["on"] else clampf((LIFE - float(s["t"])) * 5.0, 0.0, 1.0)
			mm.set_instance_transform(i, Transform3D(Basis(x * sc, z.cross(x) * sc, z * sc), e["p"]))
		return float(s["t"]) >= LIFE
	var root = Kit.ticker(Vector3.ZERO, fn)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(at - Vector3.ONE * 30.0, Vector3.ONE * 60.0)
	root.add_child(mi)
	var pop = Kit.quad(root, 2.2, Yk.mat("toge_patlama", POP_SH))
	pop.global_position = at
	Kit.tween_param(pop, "prog", 0.0, 1.0, 0.16, true)
	Sfx.play("boom", at, 1.8, 0.5)
	Sfx.play("clink", at, 1.3, 0.6)
