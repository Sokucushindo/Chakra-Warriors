extends RefCounted
## Makibishi (まきびし, hedef: res://scripts/combat/fx/makibishi_fx.gd).
## Kanon (Narutopedia, One Decade One Hundred Ninja s.165): yürüyenin ayağını yaralayıp takipçiyi caydıran küçük sivri parçalar.
## Görünüş refs/makibishi/makibishi2.png: koyu gri, kıvrık boynuzlu, altı iki yana açılan yüzgeç biçimi.
## Mekanik: torba yere çarpınca dikenler TEK TEK saçılır; koşarak basan ayağına batar, batan diken harcanır.
## Duran ya da havadan geçen etkilenmez (ayağa batar). Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const FIELD_R := 3.2
const SPIKES := 30
const STEP_R := 0.55    # ayağın dikene değdiği mesafe
const DMG := 5.0
const LIMP := 2.5       # topallama (yavaşlık) süresi
const HIT_GAP := 0.45   # aynı kişiye iki batış arası
const FLY_T := 0.38     # saçılma uçuşu


static func _spike_mesh() -> Mesh:
	return Kit.cached_mesh("makibishi", func():
		var b = MB.new()
		var o := PackedVector2Array([Vector2(0.0, -0.10), Vector2(0.055, -0.045), Vector2(0.12, -0.01), Vector2(0.205, 0.06),
			Vector2(0.10, 0.045), Vector2(0.05, 0.055), Vector2(0.0, 0.11), Vector2(0.018, 0.0)])
		var thick = func(p: Vector2) -> float:
			return lerpf(0.036, 0.006, clampf(p.x / 0.2, 0.0, 1.0))
		var c = Color(0.31, 0.32, 0.36)
		var side = Color(0.17, 0.17, 0.2)
		b.add_slab(o, 0.03, c, Transform3D.IDENTITY, thick, side)
		b.add_slab(o, 0.03, c, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), thick, side)
		return b.build(Props.toon()))


static func _pouch_mesh() -> Mesh:
	return Kit.cached_mesh("makibishi_pouch", func():
		var b = MB.new()
		var cloth = Color(0.33, 0.29, 0.24)
		b.add("sphere", Vector3.ZERO, Vector3(0.26, 0.22, 0.26), cloth, Vector3.ZERO, 10)
		b.add("cyl", Vector3(0, 0.13, 0), Vector3(0.07, 0.06, 0.07), cloth.darkened(0.2), Vector3.ZERO, 6)
		b.add("torus", Vector3(0, 0.12, 0), Vector3(0.09, 0.09, 0.09), Color(0.62, 0.55, 0.4), Vector3.ZERO, 8)
		return b.build(Props.toon()))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "makibishi", 22.0, 14.0, _pouch_mesh(), 2.0, Vector3(6, 3, 0))
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		scatter(who, pos, 8.0)
	return pr


## Projectile.caltrops da buraya gelir (düşmanın kaçarken ayağının dibine saçması dahil)
static func scatter(who: Node3D, at: Vector3, dur: float) -> void:
	at.y = Game.jutsu_floor_at(at).y
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _spike_mesh()
	mm.instance_count = SPIKES
	var spikes := []
	for i in SPIKES:
		var a = randf() * TAU
		var r = sqrt(randf()) * (FIELD_R - 0.2)
		var x = cos(a) * r
		var z = sin(a) * r
		spikes.append({"p": Vector3(x, Game.jutsu_floor_at(Vector3(at.x + x, at.y, at.z + z)).y - at.y + 0.01, z),
			"b": Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(-0.3, 0.3)),
			"hop": randf_range(0.6, 1.5), "ax": Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized(), "live": true})
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	var s = {"t": 0.0, "acc": 0.0, "cd": {}, "pop": {}}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who):
			return true
		s["t"] += dt
		var t: float = s["t"]
		if t <= FLY_T + dt:
			var k = clampf(t / FLY_T, 0.0, 1.0)
			for i in SPIKES:
				var sp = spikes[i]
				if sp["live"]:
					var p: Vector3 = (sp["p"] as Vector3) * k + Vector3.UP * sin(k * PI) * float(sp["hop"])
					var ax: Vector3 = sp["ax"]
					var rest: Basis = sp["b"]
					mm.set_instance_transform(i, Transform3D(Basis(ax, (1.0 - k) * 11.0) * rest, p))
		elif t > dur - 0.6:
			var k = clampf((t - (dur - 0.6)) / 0.6, 0.0, 1.0)
			for i in SPIKES:
				var sp = spikes[i]
				if sp["live"]:
					var rest: Basis = sp["b"]
					mm.set_instance_transform(i, Transform3D(rest, (sp["p"] as Vector3) - Vector3.UP * k * 0.25))
		if t >= dur:
			return true
		s["acc"] += dt
		if s["acc"] >= 0.08 and t > FLY_T:
			s["acc"] = 0.0
			if _step_check(who, at, spikes, mm, s):
				return true
		return false
	var root = Kit.ticker(at, fn)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-5, -4, -5), Vector3(10, 8, 10))
	root.add_child(mi)
	Sfx.play("clink", at, 1.5, 0.7)


## true: basılmamış diken kalmadı
static func _step_check(who: Node3D, at: Vector3, spikes: Array, mm: MultiMesh, s: Dictionary) -> bool:
	var t: float = s["t"]
	for f in Kit.fighters():
		if not Combat.hostile(who, f) or f.is_dead():
			continue
		var fp: Vector3 = f.global_position
		if Vector2(fp.x - at.x, fp.z - at.z).length() > FIELD_R + 1.0 or absf(fp.y - at.y) > 1.6:
			continue
		if f.get("grounded") == false:
			continue   # havadan geçen basmaz
		var v = f.get("velocity")
		if v is Vector3 and Vector2(v.x, v.z).length() < 0.8:
			continue   # duran ayak batmaz
		var id = f.get_instance_id()
		if t < float(s["cd"].get(id, 0.0)):
			continue
		var fr = f.get("radius")
		var reach = STEP_R + (float(fr) * 0.5 if fr != null else 0.2)
		var lp: Vector3 = fp - at
		for i in spikes.size():
			var sp = spikes[i]
			if not sp["live"]:
				continue
			var q: Vector3 = sp["p"]
			if Vector2(q.x - lp.x, q.z - lp.z).length() > reach:
				continue
			sp["live"] = false
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), q))
			s["cd"][id] = t + HIT_GAP
			if f.has_method("apply_status"):
				f.apply_status("slow", LIMP)
			f.take_hit({"dmg": DMG, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "tool": "makibishi"})
			Sfx.play("clink", fp, 1.9, 0.5)
			if t >= float(s["pop"].get(id, 0.0)):
				s["pop"][id] = t + 2.0
				Combat.popup_text(fp + Vector3.UP * (Kit.height_of(f) + 0.3), "Ayağına battı!", Color(0.85, 0.85, 0.9))
			break
	for sp in spikes:
		if sp["live"]:
			return false
	return true
