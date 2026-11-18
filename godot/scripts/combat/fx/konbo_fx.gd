extends RefCounted
## Kyodai Konbō: model, sarkan zincir, uçan / toprak altı baş — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kanon (Conch Shell Mace, refs/konbo): deniz kabuğu biçimli, dikenli, ortasında göz izi olan baş; sargılı sap; baş ile sap dibini bağlayan zincir.
## Anime: dikenler açılıp kanat olur ve uçar; toprak altında dikenlerini katlar; ayrıyken el işaretiyle yönetilir. Izumo'nun Mizuame Nabara'sıyla birlikte
## kullanılır: ayağı yapışmış rakip kaçamaz -> bağlı hedefe bu baş tam oturur (ek hasar + sersemletme). Oyuncu ve düşman aynı kod.

const ID := "konbo"
const HEAD_Z := 0.56
const FLY_COST := 0.03

static var _c := {}

const ROCK_SH := """shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""


## Zincir: iki düğüm arası sarkan halkalar (tek çizim). Sarkma yerçekimi yönünde, ucu hareket edince geride kalıp sallanır (ikincil hareket).
class Chain extends MultiMeshInstance3D:
	var a: Node3D
	var b: Node3D
	var pa := Vector3.ZERO
	var pb := Vector3.ZERO
	var slack := 0.22
	var mid := Vector3.ZERO
	var vel := Vector3.ZERO
	var ready_ok := false
	const N := 16

	func setup(link: Mesh, mat: Material) -> void:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link
		mm.instance_count = N
		multimesh = mm
		material_override = mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top_level = true
		custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)

	func _process(dt: float) -> void:
		if not is_instance_valid(a) or not is_instance_valid(b):
			queue_free()
			return
		if not a.is_visible_in_tree():
			visible = false
			return
		var A: Vector3 = a.global_transform * pa
		var cam = get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(A) > 1600.0:
			visible = false   # 40 m ötede halkalar görünmez: hesap da yok
			return
		visible = true
		global_transform = Transform3D.IDENTITY
		var B: Vector3 = b.global_transform * pb
		var L = A.distance_to(B)
		var stretch = maxf(1.4, (L / N) / 0.06)   # uzun atışta halkalar uzar, zincirde boşluk kalmaz
		var want = (A + B) * 0.5 + Vector3.DOWN * maxf(0.03, slack - L * 0.08)
		if not ready_ok:
			mid = want
			ready_ok = true
		var d = minf(dt, 0.033)
		vel += (want - mid) * 90.0 * d
		vel *= exp(-7.0 * d)
		mid += vel * d
		var prev = A
		for i in N:
			var u = (i + 0.5) / N
			var p = A.lerp(mid, u).lerp(mid.lerp(B, u), u)
			var dir = p - prev
			if dir.length() < 0.001:
				dir = Vector3.UP
			dir = dir.normalized()
			var x = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
			if i % 2 == 1:
				x = x.rotated(dir, PI * 0.5)
			# torus ekseni (Y) zincire dik: halka düzlemi zincir boyunca
			multimesh.set_instance_transform(i, Transform3D(Basis(dir * stretch, x, dir.cross(x)), p))
			prev = p


# ------------------------------------------------------------------ model
## Kabza 0, baş +Z. id: konbo (tam), konbo_sap (baş yok, baş uçarken elde kalan), konbo_bas / konbo_kanat / konbo_gomu (başın merkezi 0'da).
static func model(b: MB, id: String) -> void:
	if id == "konbo" or id == "konbo_sap":
		_haft(b)
	if id == "konbo":
		var h = MB.new()
		_head(h, "konbo_bas")
		b.add_mesh(h, Transform3D(Basis.IDENTITY, Vector3(0, 0, HEAD_Z)))
	elif id != "konbo_sap":
		_head(b, id)


static func _haft(b: MB) -> void:
	var cloth = Color(0.9, 0.85, 0.72)
	var shell = Color(0.55, 0.48, 0.62)
	Loft.tube(b, [Vector3(0, 0, -0.58), Vector3(0, 0, -0.1), Vector3(0, 0, 0.16), Vector3(0, 0, 0.3)], [0.042, 0.046, 0.058, 0.09], cloth, 10, 3)
	for k in 9:
		b.add("cyl", Vector3(0, 0, -0.54 + k * 0.088), Vector3(0.1, 0.008, 0.1), cloth.darkened(0.2), Vector3(90 + (k % 3) * 4.0, 0, 0), 10)   # sargı kıvrımları
	var t = MB.new()
	t.add("torus", Vector3.ZERO, Vector3(0.17, 0.17, 0.17), shell, Vector3(0, 0, 90), 12)   # sap dibindeki halka
	b.add_mesh(t, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.67)))


static func _spike(b: MB, p: Vector3, d: Vector3, L: float, w: float, col: Color) -> void:
	var y = d.normalized()
	var x = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	b.add_xf("cone", Transform3D(Basis(x * w, y * L, z * w), p + y * L * 0.42), col, 5)


static func _head(b: MB, id: String) -> void:
	var shell = Color(0.56, 0.49, 0.62)
	var dark = Color(0.44, 0.38, 0.5)
	var red = Color(0.62, 0.08, 0.14)
	var flat = id == "konbo_gomu"
	# deniz kabuğu gövdesi: arkası şişkin, öne doğru sivrilir; toprak altı biçimi daha uzun ve düzgün
	var zs = [-0.3, -0.16, 0.04, 0.2, 0.36] if not flat else [-0.34, -0.14, 0.1, 0.34, 0.56]
	var rs = [0.12, 0.3, 0.36, 0.25, 0.06] if not flat else [0.1, 0.26, 0.27, 0.16, 0.025]
	var pts = []
	for z in zs:
		pts.append(Vector3(0, 0, z))
	Loft.tube(b, pts, rs, shell, 14, 3)
	# ortadan geçen dikiş sırtı (kaynak: gövdeyi bölen kalın kıvrım)
	for k in 14:
		var a = TAU * k / 14.0
		b.add("box", Vector3(cos(a) * 0.335, sin(a) * 0.335, -0.1), Vector3(0.05, 0.05, 0.05), dark, Vector3(0, 0, rad_to_deg(a)))
	# göz: kırmızı yarık + sarı halka + siyah bebek
	var eye = Vector3(0.3, 0.0, 0.06)
	b.add("sphere", eye + Vector3(0.018, 0, 0.0), Vector3(0.05, 0.1, 0.27), red, Vector3(0, -12, 0), 10)
	b.add("sphere", eye + Vector3(0.05, 0, 0.0), Vector3(0.02, 0.078, 0.078), Color(0.9, 0.74, 0.2), Vector3.ZERO, 10)
	b.add("sphere", eye + Vector3(0.062, 0, 0.0), Vector3(0.012, 0.038, 0.038), Color(0.05, 0.04, 0.05), Vector3.ZERO, 8)
	if flat:
		for k in 5:   # katlanmış dikenler: gövdeye yatık kısa kertikler
			var a = PI * 0.5 + k * 0.5
			var z = -0.05 + k * 0.08
			_spike(b, Vector3(cos(a) * 0.22, sin(a) * 0.22, z), Vector3(cos(a) * 0.25, sin(a) * 0.25, 1.0), 0.14, 0.03, dark)
		return
	# zincir kulağı
	b.add("torus", Vector3(0, -0.34, -0.2), Vector3(0.09, 0.09, 0.09), dark, Vector3(90, 0, 0), 10)
	if id == "konbo_kanat":
		for sx in [-1.0, 1.0]:
			for k in 3:   # geriye süpürülmüş uzun kanat bıçakları (Conch_shell_aerial_form.png)
				var root = Vector3(sx * 0.26, 0.09 - k * 0.09, -0.06 - k * 0.05)
				var tip = Vector3(sx * (1.18 - k * 0.14), 0.16 - k * 0.1, -0.62 - k * 0.1)
				_blade(b, root, tip, 0.1 - k * 0.012, shell.darkened(k * 0.08))
		_spike(b, Vector3(0, 0, 0.34), Vector3(0, 0, 1), 0.3, 0.1, shell)
		for k in 5:
			var a = PI * 0.5 + (k - 2) * 0.36
			_spike(b, Vector3(cos(a) * 0.2, sin(a) * 0.26, -0.04), Vector3(cos(a) * 0.6, sin(a), -0.5), 0.28, 0.06, dark)
		return
	# ön yüzde iri dikenler, gövdede kısa yumrular (Kotetsu_Summoning_Shell.png)
	for k in 9:
		var a = TAU * k / 9.0 + 0.2
		_spike(b, Vector3(cos(a) * 0.24, sin(a) * 0.24, 0.2), Vector3(cos(a), sin(a), 0.55), 0.3 + (k % 3) * 0.05, 0.07, shell)
	for k in 7:
		var a = TAU * k / 7.0
		_spike(b, Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.34), Vector3(cos(a) * 0.5, sin(a) * 0.5, 1.0), 0.2, 0.05, dark)
	for k in 12:
		var a = k * 2.4
		var z = -0.2 + fmod(k * 0.37, 1.0) * 0.3
		_spike(b, Vector3(cos(a) * 0.3, sin(a) * 0.3, z), Vector3(cos(a), sin(a), 0.1), 0.09, 0.05, dark)


## Yassı uzun bıçak (iki yüzlü şerit, kök geniş, uç sivri)
static func _blade(b: MB, p: Vector3, q: Vector3, w: float, col: Color) -> void:
	var d = q - p
	var side = d.cross(Vector3.UP).normalized() * w
	var n = d.cross(side).normalized()
	var base = b.verts.size()
	var pts = [p - side, p + side, p.lerp(q, 0.6) + side * 0.8, q, p.lerp(q, 0.6) - side * 0.8]
	for s in [1.0, -1.0]:
		for v in pts:
			b.verts.append(v)
			b.normals.append(n * s)
			b.colors.append(col)
			b.uvs.append(Vector2.ZERO)
	for t in [[0, 1, 2], [0, 2, 4], [4, 2, 3]]:
		b.idx.append_array(PackedInt32Array([base + t[0], base + t[1], base + t[2]]))
		b.idx.append_array(PackedInt32Array([base + 5 + t[0], base + 5 + t[2], base + 5 + t[1]]))


# ------------------------------------------------------------------ zincir (CharacterModel silah kurulumu: elde ve uçarken)
static func _link() -> Mesh:
	if not _c.has("link"):
		var t = TorusMesh.new()
		t.inner_radius = 0.018
		t.outer_radius = 0.034
		t.rings = 8
		t.ring_segments = 5
		_c["link"] = t
	return _c["link"]


static func _chain_mat() -> Material:
	if not _c.has("cm"):
		_c["cm"] = Props.toon_color(Color(0.13, 0.12, 0.14), 0.3)
	return _c["cm"]


## Silah kurulurken: sap dibi halkasından başın kulağına sarkan zincir
static func attach_chain(node: Node3D) -> void:
	var c = Chain.new()
	c.setup(_link(), _chain_mat())
	c.a = node
	c.b = node
	c.pa = Vector3(0, -0.07, -0.72)
	c.pb = Vector3(0, -0.34, HEAD_Z - 0.2)
	c.slack = 0.34
	node.add_child(c)
	node.set_meta("konbo_chain", c)


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _node(who: Node3D) -> MeshInstance3D:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return null
	for w in m.weapons:
		if Gear.base_id(String(w["id"])) == ID and is_instance_valid(w["node"]) and w["node"] is MeshInstance3D:
			return w["node"]
	return null


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _foe(who: Node3D, r: float) -> Node3D:
	var best: Node3D = null
	var bd = r
	for x in who.get_tree().get_nodes_in_group("fighters"):
		if x == who or not Combat.hostile(who, x) or x.is_dead():
			continue
		var d = (x as Node3D).global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = x
	return best


static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


static func _gp(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.ground_height(p.x, p.z) + 0.03, p.z)


static func _aim_basis(d: Vector3) -> Basis:
	var z = d.normalized()
	var x = (Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).cross(z).normalized()
	return Basis(x, z.cross(x), z)


static func _stuck(t) -> bool:
	return t != null and is_instance_valid(t) and t.has_method("has_status") and t.has_status("bind")


## Başın isabeti: ayağı yapışmış / bağlı hedefe tam oturur (Mizuame Nabara uyumu)
static func _smash(who: Node3D, c: Vector3, r: float, dmg: float, tg, extra: Dictionary) -> void:
	var info = {"dmg": dmg, "kind": "heavy", "hitstop": 0.07, "melee": true}
	info.merge(extra, true)
	if _stuck(tg):
		info["dmg"] = dmg * 1.35
		info["stun"] = maxf(float(info.get("stun", 0.0)), 0.9)
		Combat.popup_text(c + Vector3.UP * 1.6, "Kaçamadı!", Color(1.0, 0.8, 0.5))
	Combat.hit_sphere(who, c, r, info)
	Sfx.play("hit_heavy_weapon", c, 0.72, 0.95)
	if who is Player and Game.world:
		Game.world.env.add_shake(0.35)


# ------------------------------------------------------------------ taş parçaları (kendi MultiMesh'i)
static func _rock_mesh() -> Mesh:
	if not _c.has("rock"):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.72, 0.86), Color.WHITE, Vector3(20, 40, 0), 4)
		_c["rock"] = b.build()
	return _c["rock"]


static func _rock_mat() -> ShaderMaterial:
	if not _c.has("rm"):
		var s = Shader.new()
		s.code = ROCK_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["rm"] = m
	return _c["rm"]


static func _rocks(p: Vector3, n: int, up: float, spread: float, size: float) -> void:
	var root = _root()
	if root == null:
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _rock_mesh()
	mm.instance_count = n
	var data = []
	for i in n:
		var a = randf() * TAU
		var v = Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0) * spread + Vector3.UP * randf_range(0.5, 1.0) * up
		var g = randf_range(0.26, 0.38)
		data.append([v, randf_range(0.5, 1.0) * size, randf() * TAU, randf_range(4.0, 9.0)])
		mm.set_instance_color(i, Color(g * 1.25, g, g * 0.82))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _rock_mat()
	mi.custom_aabb = AABB(p - Vector3.ONE * 8.0, Vector3.ONE * 16.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var T = 0.62
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		var fade = 1.0 - smoothstep(0.7 * T, T, t)
		for i in n:
			var e: Array = data[i]
			var q = p + (e[0] as Vector3) * t + Vector3.DOWN * 11.0 * t * t
			q.y = maxf(q.y, p.y)
			var br = Basis(Vector3(0.6, 0.7, 0.3).normalized(), float(e[2]) + float(e[3]) * t).scaled(Vector3.ONE * float(e[1]) * fade)
			mm.set_instance_transform(i, Transform3D(br, q)), 0.0, T, T)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ baş fırlatma
## mode: "throw" düz + zincirle dönüş, "wing" kanatlanıp tepeden dalış, "burrow" toprak altından çıkış
static func _launch(who: Node3D, mode: String, dmg: float) -> void:
	var root = _root()
	var n = _node(who)
	if root == null or n == null:
		return
	var tok = int(who.get_meta("konbo_tok", 0)) + 1   # hızlı kullanıcıda önceki baş dönmeden yenisi çıkarsa sapı eskisi geri getirmesin
	who.set_meta("konbo_tok", tok)
	var f = _face(who)
	var tg = _foe(who, 15.0)
	var start: Vector3 = n.global_transform * Vector3(0, 0, HEAD_Z)
	var far: Vector3 = who.global_position + f * 7.0 + Vector3.UP * 1.0
	var head = MeshInstance3D.new()
	head.mesh = CharacterModel.weapon_mesh({"throw": "konbo_bas", "wing": "konbo_kanat", "burrow": "konbo_gomu"}[mode])
	root.add_child(head)
	head.global_position = start
	n.mesh = CharacterModel.weapon_mesh("konbo_sap")
	var hanging = n.get_meta("konbo_chain", null)
	if is_instance_valid(hanging):
		hanging.visible = false
		hanging.set_process(false)
	var ch = Chain.new()
	ch.setup(_link(), _chain_mat())
	ch.a = n
	ch.b = head
	ch.pa = Vector3(0, -0.07, -0.72)
	ch.pb = Vector3(0, 0, -0.3)
	ch.slack = 0.3
	root.add_child(ch)
	var T = {"throw": 0.74, "wing": 1.12, "burrow": 1.0}[mode]
	var HIT = {"throw": 0.42, "wing": 0.62, "burrow": 0.56}[mode]
	var st = {"done": false, "tick": -1, "target": far}
	var track = func() -> Vector3:
		if tg != null and is_instance_valid(tg) and not tg.is_dead():
			st["target"] = (tg as Node3D).global_position + Vector3.UP * 1.0
		return st["target"]
	var mouth: Vector3 = _gp(who.global_position + f * 1.7)   # toprağa girdiği yer
	var finish = func():
		if is_instance_valid(head):
			head.queue_free()
		if is_instance_valid(ch):
			ch.queue_free()
		if is_instance_valid(n) and is_instance_valid(who) and int(who.get_meta("konbo_tok", 0)) == tok:
			n.mesh = CharacterModel.weapon_mesh(ID)
			if is_instance_valid(hanging):
				hanging.set_process(true)
				hanging.visible = true
	var tw = head.create_tween()
	var step = func(k: float) -> void:
		if not is_instance_valid(head) or not is_instance_valid(who):
			return
		var hand: Vector3 = n.global_transform * Vector3(0, 0, 0.3) if is_instance_valid(n) else who.global_position + Vector3.UP
		var to: Vector3 = track.call()
		var p: Vector3
		var look: Vector3 = to - head.global_position
		match mode:
			"throw":
				if k < HIT:
					var u = k / HIT
					p = start.lerp(to, 1.0 - (1.0 - u) * (1.0 - u))
				else:
					var u = (k - HIT) / (1.0 - HIT)
					p = (st["target"] as Vector3).lerp(hand, u * u)
					look = p - hand
			"wing":
				var apex = start.lerp(to, 0.55) + Vector3.UP * 5.2
				if k < 0.34:
					var u = k / 0.34
					p = start.lerp(apex, sin(u * PI * 0.5))
					look = apex - start
				elif k < HIT:
					var u = (k - 0.34) / (HIT - 0.34)
					p = apex.lerp(to, u * u)
				else:
					var u = (k - HIT) / (1.0 - HIT)
					p = (st["target"] as Vector3).lerp(hand, u * u)
					look = p - hand
			_:
				var to_g = _gp(to)
				if k < 0.14:
					p = start.lerp(mouth + Vector3.DOWN * 0.35, k / 0.14)
					look = Vector3.DOWN
				elif k < HIT:
					var u = (k - 0.14) / (HIT - 0.14)
					p = mouth.lerp(to_g, u) + Vector3.DOWN * 1.2
					head.visible = false
					look = to_g - mouth
					var tick = int(u * 8.0)
					if tick != int(st["tick"]):   # yerin altındaki baş üstünde toprak kabarır
						st["tick"] = tick
						_rocks(_gp(p), 4, 3.2, 0.9, 0.11)
				elif k < 0.78:
					var u = (k - HIT) / (0.78 - HIT)
					head.visible = true
					head.mesh = CharacterModel.weapon_mesh("konbo_bas")
					p = to_g + Vector3.UP * lerpf(-0.8, 2.4, sin(u * PI * 0.5))
					look = Vector3.UP
				else:
					var u = (k - 0.78) / 0.22
					p = (to_g + Vector3.UP * 2.4).lerp(hand, u * u)
					look = p - hand
		head.global_transform = Transform3D(_aim_basis(look if look.length() > 0.05 else f), p)
		if k >= HIT and not bool(st["done"]):
			st["done"] = true
			var c: Vector3 = st["target"]
			match mode:
				"throw":
					_smash(who, c, 1.5, dmg * 1.05, tg, {"knock": 8.0})
				"wing":
					_smash(who, c, 2.2, dmg * 1.3, tg, {"knock": 3.0, "stun": 0.4})
					_rocks(_gp(c), 10, 5.0, 3.0, 0.16)
				_:
					var gc = _gp(c)
					_smash(who, gc + Vector3.UP * 0.9, 2.3, dmg * 1.5, tg, {"knock": 1.5, "launch": 8.5})
					_rocks(gc, 18, 8.5, 3.6, 0.22)
	tw.tween_method(step, 0.0, 1.0, T)
	tw.tween_callback(finish)
	Sfx.play("swing_chain", start, 0.8, 0.9)


# ------------------------------------------------------------------ kombo bağları
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	match i:
		1:   # kendi ağırlığıyla yere iner
			var g = _gp(who.global_position + f * 1.7)
			_rocks(g, 8, 4.0, 2.2, 0.13)
			Sfx.play("hit_heavy_weapon", g, 0.68, 0.8)
			if who is Player and Game.world:
				Game.world.env.add_shake(0.3)
		3:
			_pay(who, FLY_COST)
			_launch(who, "throw", dmg)
		4:
			_pay(who, FLY_COST)
			_launch(who, "wing", dmg)
		5:
			var g = _gp(who.global_position + f * 1.7)
			_rocks(g, 12, 5.0, 2.6, 0.16)
			Sfx.play("earth", g, 0.8, 0.9)
			if who is Player and Game.world:
				Game.world.env.add_shake(0.45)
			_pay(who, FLY_COST)
			_launch(who, "burrow", dmg)
