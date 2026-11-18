extends RefCounted
## Amagasa: model, açılıp kapanma, karşılama, gizli kılıç ve senbon düzeneği — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kanon (Umbrella / Senbon Shower / May Rain Blood River): kaburgalar yaylı, yüzlerce senbon taşır; şemsiye havaya atılıp döndürülür,
## düşen iğneler chakra ile hedefe yönetilir (Tora mührü). Shura'nınki alttan senbon atar ve sapında kılıç saklar.
## Zayıflık: kâğıt gövde ağır darbeyi tutamaz, yırtılıp kapanır; büyük jutsuyu da durdurmaz. Oyuncu ve düşman aynı kod.

const ID := "amagasa"
const STEP_COST := 0.01     # kaburgaları dolduran chakra (azami chakranın oranı)
const RAIN_COST := 0.07
const GUARD_T := 0.62       # açık şemsiyenin önden gelen darbeyi karşıladığı süre
const NEEDLE_COL := Color(0.78, 0.95, 0.9, 0.95)   # kaynakta soluk yeşil-beyaz çizgiler

static var _c := {}

const NEEDLE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying float along;
void vertex() {
	along = VERTEX.z + 0.5;   // 0 kuyruk, 1 uç
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * mix(0.12, 1.0, smoothstep(0.0, 0.6, along));
}
"""

const SWIRL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = smoothstep(0.0, 0.2, UV.x) * (1.0 - smoothstep(0.65, 1.0, UV.x));
	float w = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.06, 0.09, 0.2);
	ALPHA = e * smoothstep(0.1, 0.6, w) * fade_k * 0.9;
}
"""


# ------------------------------------------------------------------ model (CharacterModel.weapon_mesh buraya gelir)
## Silah uzayı: kabza 0, uç +Z. Kaynak (Umbrella.PNG): sığ koni, koyu zeytin kâğıt, kenardan taşan kaburgalar, dalgalı kenar,
## altta tekerlek göbeği ve sık destek telleri, kahverengi sap, ucunda beyaz sargı.
static func model(b: MB, id: String) -> void:
	var wood = Color(0.36, 0.27, 0.24)
	var wrap_c = Color(0.9, 0.88, 0.82)
	if id != "amagasa_govde":
		b.add("cyl", Vector3(0, 0, -0.03), Vector3(0.03, 0.54, 0.03), wood, Vector3(90, 0, 0), 8)
		for k in 5:
			b.add("cyl", Vector3(0, 0, -0.27 + k * 0.042), Vector3(0.034, 0.03, 0.034), wrap_c, Vector3(90, 0, 0), 8)
		b.add("cyl", Vector3(0, 0, -0.305), Vector3(0.036, 0.02, 0.036), Color(0.2, 0.15, 0.13), Vector3(90, 0, 0), 8)
	if id == "amagasa_kilic":
		var steel = Color(0.78, 0.81, 0.85)
		b.add("cyl", Vector3(0, 0, 0.245), Vector3(0.036, 0.018, 0.036), Color(0.2, 0.15, 0.13), Vector3(90, 0, 0), 8)
		b.add("box", Vector3(0, 0, 0.56), Vector3(0.026, 0.007, 0.62), steel)
		b.add("cone", Vector3(0, 0, 0.91), Vector3(0.018, 0.08, 0.005), steel, Vector3(90, 0, 0), 4)
		return
	b.add("cyl", Vector3(0, 0, 0.65), Vector3(0.024, 0.82, 0.024), wood, Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, 1.06), Vector3(0.05, 0.05, 0.07), Color(0.14, 0.13, 0.12), Vector3.ZERO, 8)
	match id:
		"amagasa_a":
			_canopy(b, 1.03, 0.68, 0.82, 0.62, 0.075)
		"amagasa_y":
			_canopy(b, 1.03, 0.47, 0.4, 0.42, 0.05)
		_:
			_canopy(b, 1.03, 0.3, 0.085, 0.31, 0.034)
			b.add("cyl", Vector3(0, 0, 0.52), Vector3(0.075, 0.024, 0.075), wrap_c.darkened(0.25), Vector3(90, 0, 0), 10)   # kapalı tutan bağ


## Koni kâğıt: iki yüzlü üçgenler, dalgalı kenar; kaburgalar ve göbekten kaburgaya destek telleri
static func _canopy(b: MB, apex: float, rim: float, r: float, hub_z: float, hub_r: float) -> void:
	var paper = Color(0.35, 0.34, 0.22)
	var paper2 = Color(0.3, 0.29, 0.19)
	var inner = Color(0.2, 0.19, 0.13)
	var rib = Color(0.11, 0.1, 0.08)
	var n = 20
	var top = Vector3(0, 0, apex)
	var pt = func(a: float, q: float) -> Vector3:
		return Vector3(cos(a) * r * q, sin(a) * r * q, rim + (apex - rim) * (1.0 - q) * 0.25)
	for i in n:
		var a0 = TAU * i / n
		var a1 = TAU * (i + 1) / n
		var am = (a0 + a1) * 0.5
		var p0: Vector3 = pt.call(a0, 1.0)
		var p1: Vector3 = pt.call(a1, 1.0)
		var m: Vector3 = pt.call(am, 0.93)
		var c = paper if i % 2 == 0 else paper2
		_tri(b, top, p0, m, c, inner)
		_tri(b, top, m, p1, c, inner)
		_seg(b, top, p0 * Vector3(1.05, 1.05, 1.0), 0.008 + r * 0.004, rib)   # kaburga kenardan taşar
		if i % 2 == 0:
			var q: Vector3 = top.lerp(p0, 0.55)
			_seg(b, Vector3(0, 0, hub_z), q, 0.005 + r * 0.003, rib)        # destek teli
	b.add("cyl", Vector3(0, 0, hub_z), Vector3(hub_r, 0.05, hub_r), Color(0.3, 0.22, 0.2), Vector3(90, 0, 0), 12)


## Çift yüzlü üçgen: dışı col, içi col2
static func _tri(b: MB, p: Vector3, q: Vector3, r: Vector3, col: Color, col2: Color) -> void:
	var nr = (q - p).cross(r - p).normalized()
	var base = b.verts.size()
	for v in [p, q, r]:
		b.verts.append(v)
		b.normals.append(nr)
		b.colors.append(col2)
		b.uvs.append(Vector2.ZERO)
	for v in [p, q, r]:
		b.verts.append(v)
		b.normals.append(-nr)
		b.colors.append(col)
		b.uvs.append(Vector2.ZERO)
	b.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 3, base + 5, base + 4]))


static func _seg(b: MB, p: Vector3, q: Vector3, d: float, col: Color) -> void:
	var y = q - p
	var yn = y.normalized()
	var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
	var zn = xn.cross(yn)
	b.add_xf("cyl", Transform3D(Basis(xn * d, y, zn * d), (p + q) * 0.5), col, 5)


# ------------------------------------------------------------------ ortak küçükler
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


static func _h(who: Node3D) -> float:
	return float(who.get("height")) if who.get("height") != null else 1.8


static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


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


static func _after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


## Şemsiyenin biçimi: "" kapalı, "amagasa_y" yarım, "amagasa_a" açık, "amagasa_kilic" yalnız sap + gizli kılıç
static func _shape(who: Node3D, mesh_id: String) -> void:
	var n = _node(who)
	if n != null:
		n.mesh = CharacterModel.weapon_mesh(ID if mesh_id == "" else mesh_id)


## Açılış iki karede (yay fırlar), süre sonunda kapanır; yeni adım eskisinin kapanışını iptal eder
static func _open(who: Node3D, delay: float, hold: float) -> void:
	var tok = int(who.get_meta("kasa_tok", 0)) + 1
	who.set_meta("kasa_tok", tok)
	var live = func() -> bool:
		return int(who.get_meta("kasa_tok", 0)) == tok
	_after(who, delay, func():
		if live.call():
			_shape(who, "amagasa_y"))
	_after(who, delay + 0.05, func():
		if live.call():
			_shape(who, "amagasa_a")
			Sfx.play("swing_fan", who.global_position, 1.35, 0.55))
	_after(who, delay + hold, func():
		if live.call():
			_shape(who, "amagasa_y"))
	_after(who, delay + hold + 0.06, func():
		if live.call():
			_shape(who, ""))


# ------------------------------------------------------------------ senbon: tek MultiMesh, her iğne kendi yolunda
static func _needle_mesh() -> Mesh:
	if not _c.has("mesh"):
		var m = BoxMesh.new()
		m.size = Vector3(0.016, 0.016, 1.0)
		_c["mesh"] = m
	return _c["mesh"]


static func _needle_mat() -> ShaderMaterial:
	if not _c.has("mat"):
		var s = Shader.new()
		s.code = NEEDLE_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["mat"] = m
	return _c["mat"]


static func _look(z: Vector3, sc: Vector3) -> Basis:
	var zn = z.normalized()
	var x = (Vector3.UP if absf(zn.y) < 0.95 else Vector3.RIGHT).cross(zn).normalized()
	return Basis(x * sc.x, zn.cross(x) * sc.y, zn * sc.z)


## list: [{a, b, t0, fly}] — iğne t0'da a'dan çıkar, fly sn'de b'ye varır, stick sn saplı kalıp söner
static func _needles(list: Array, length: float, stick: float) -> void:
	var root = _root()
	if root == null or list.is_empty():
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _needle_mesh()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), list[i]["a"]))   # ilk karede dünya merkezinde görünmesin
	var box = AABB((list[0]["a"] as Vector3), Vector3.ZERO)
	var total = 0.0
	for e in list:
		box = box.expand(e["a"]).expand(e["b"])
		total = maxf(total, float(e["t0"]) + float(e["fly"]))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _needle_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = box.grow(2.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var end = total + stick
	var tw = mi.create_tween()
	tw.tween_method(func(now: float):
		if not is_instance_valid(mi):
			return
		for i in list.size():
			var e: Dictionary = list[i]
			var u = (now - float(e["t0"])) / float(e["fly"])
			if u < 0.0:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), e["a"]))
				continue
			var a: Vector3 = e["a"]
			var b: Vector3 = e["b"]
			var d = b - a
			var fly = u < 1.0
			var sc = Vector3(1, 1, length if fly else 0.34)   # uçarken uzun ışık çizgisi, saplanınca kısa iğne
			mm.set_instance_transform(i, Transform3D(_look(d, sc), a.lerp(b, minf(u, 1.0))))
			var al = 1.0 if fly else clampf(1.0 - (now - float(e["t0"]) - float(e["fly"])) / maxf(stick, 0.01), 0.0, 1.0)
			mm.set_instance_color(i, Color(NEEDLE_COL.r, NEEDLE_COL.g, NEEDLE_COL.b, NEEDLE_COL.a * al)), 0.0, end, end)
	tw.tween_callback(mi.queue_free)


## Dönen şemsiyenin çevresinde koyu sarmal çizgiler (Senbon_Shower.PNG); dolu halka değil, kopuk ince yaylar
static func _swirl_mesh() -> ArrayMesh:
	if _c.has("swirl"):
		return _c["swirl"]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var rng = RandomNumberGenerator.new()
	rng.seed = 4411
	for s in 26:
		var a0 = rng.randf() * TAU
		var r0 = rng.randf_range(0.95, 2.7)
		var L = rng.randf_range(0.28, 0.6)
		var base = v.size()
		for k in 7:
			var u = k / 6.0
			var a = a0 + u * L
			var r = r0 + u * 0.32   # dışa açılan sarmal
			var w = 0.012 + 0.012 * r0
			var dir = Vector3(cos(a), sin(a), 0)
			v.append(dir * (r - w))
			v.append(dir * (r + w))
			uv.append(Vector2(u, 0))
			uv.append(Vector2(u, 1))
		for k in 6:
			var q = base + k * 2
			idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_c["swirl"] = m
	return m


static func _swirl_mat() -> ShaderMaterial:
	if not _c.has("swirl_m"):
		var s = Shader.new()
		s.code = SWIRL_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["swirl_m"] = m
	return _c["swirl_m"]


# ------------------------------------------------------------------ gizli düzenekler
## 4. adım: kaburga uçlarından öne iğne salvosu (hedefe döner), yol üstünde her rakibe bir kez
static func volley(who: Node3D, dmg: float) -> void:
	var f = _face(who)
	var side = Vector3.UP.cross(f).normalized()
	var c = who.global_position + Vector3.UP * _h(who) * 0.82 + f * 0.55
	var aim = c + f * 9.0
	var tg = _foe(who, 11.0)
	if tg != null:
		aim = tg.global_position + Vector3.UP * 1.0
	var d = (aim - c).normalized()
	var list = []
	for i in 18:
		var a = TAU * i / 18.0
		var off = side * cos(a) * 0.62 + Vector3.UP * sin(a) * 0.62
		var hit_p = c + d * 10.0 + off * 1.6 + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		list.append({"a": c + off, "b": hit_p, "t0": randf() * 0.1, "fly": 0.24})
	_needles(list, 1.5, 0.05)
	Sfx.play("throw", c, 1.7, 0.7)
	var hit_done: Array = []
	for k in 4:
		_after(who, 0.05 + k * 0.05, func():
			var q = c + d * (2.2 + k * 2.2)
			hit_done.append_array(Combat.hit_sphere(who, q, 1.35, {"dmg": dmg * 0.85, "knock": 1.5, "kind": "light", "bleed": 1.5, "hitstop": 0.02}, hit_done)))


## 5. adım: gövde sol ele, sap + kılıç sağ elde kalır
static func draw_sword(who: Node3D, dur: float) -> void:
	var m = who.get("model")
	if m == null or not (m is CharacterModel) or m.skel == null or m.skel.find_bone("LeftHand") < 0:
		return
	who.set_meta("kasa_tok", int(who.get_meta("kasa_tok", 0)) + 1)
	_shape(who, "amagasa_kilic")
	var ba: BoneAttachment3D = m._attach("LeftHand", m._grip_xf("Left"))
	var body = MeshInstance3D.new()
	body.mesh = CharacterModel.weapon_mesh("amagasa_govde")
	body.position = Vector3(0, 0, -0.24)
	ba.get_child(0).add_child(body)
	Sfx.play("blade", who.global_position, 1.25, 0.7)
	_after(who, dur, func():
		_shape(who, "")
		Sfx.play("clink", who.global_position, 1.3, 0.35))
	who.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(ba):
			ba.queue_free())


## 6. adım: şemsiye elden fırlar, başın üstünde döner; iğneler hedefe yönetilerek iner, sonra ele süzülür
static func shower(who: Node3D, dmg: float) -> void:
	var root = _root()
	var n = _node(who)
	if root == null or n == null:
		return
	var f = _face(who)
	var tg = _foe(who, 16.0)
	var st = {"c": tg.global_position if tg != null else who.global_position + f * 6.0}
	var strong = _pay(who, RAIN_COST)   # chakrası yetmezse iğneler dağınık ve az
	n.visible = false
	var top: Vector3 = (st["c"] as Vector3).lerp(who.global_position, 0.25) + Vector3.UP * 8.0
	var from = n.global_position
	var copy = MeshInstance3D.new()
	copy.mesh = CharacterModel.weapon_mesh("amagasa_a")
	root.add_child(copy)
	copy.global_position = from
	var ring = MeshInstance3D.new()
	ring.mesh = _swirl_mesh()
	ring.material_override = _swirl_mat()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copy.add_child(ring)
	ring.position = Vector3(0, 0, 0.45)
	ring.visible = false
	var UP_B = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)   # sap aşağı, tepe göğe
	var T = 1.24
	var tw = copy.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(copy):
			return
		var spin = Basis(Vector3.UP, t * 26.0) * UP_B
		var p: Vector3
		if t < 0.26:
			var k = t / 0.26
			p = from.lerp(top, 1.0 - (1.0 - k) * (1.0 - k))
		elif t < 1.02:
			p = top + Vector3.UP * sin(t * 5.0) * 0.08
			ring.visible = true
		else:
			ring.visible = false
			var k = (t - 1.02) / (T - 1.02)
			var hand = n.global_position if is_instance_valid(n) else top
			p = top.lerp(hand, k * k)
			copy.mesh = CharacterModel.weapon_mesh("amagasa_y" if k < 0.5 else ID)
		copy.global_transform = Transform3D(spin, p), 0.0, T, T)
	tw.tween_callback(func():
		if is_instance_valid(copy):
			copy.queue_free()
		if is_instance_valid(n):
			n.visible = true
			n.mesh = CharacterModel.weapon_mesh(ID))
	# iğneler dalga dalga: her dalga hedefin O ANKİ yerine yönelir (chakra ile yönetilir)
	var waves = 5
	var per = 9 if strong else 4
	for w in waves:
		_after(who, 0.3 + w * 0.15, func():
			if tg != null and is_instance_valid(tg) and not tg.is_dead():
				st["c"] = (st["c"] as Vector3).lerp(tg.global_position, 0.7)
			var c: Vector3 = st["c"]
			var list = []
			for i in per:
				var a = randf() * TAU
				var o = top + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 0.95)
				var q = c + Vector3(randf_range(-2.6, 2.6), 0, randf_range(-2.6, 2.6))
				q.y = Game.ground_height(q.x, q.z) + 0.1
				list.append({"a": o, "b": q, "t0": randf() * 0.12, "fly": 0.26})
			_needles(list, 2.1, 0.5)
			Combat.hit_sphere(who, c + Vector3.UP * 0.9, 2.9 if strong else 2.2, {"dmg": dmg * (0.26 if strong else 0.12), "knock": 0.2, "kind": "light", "bleed": 1.0, "hitstop": 0.01}))
	Sfx.play("whoosh", top, 1.7, 0.7)


# ------------------------------------------------------------------ karşılama (Player.take_hit + Enemy.take_hit)
## Açık şemsiye önden gelen darbeyi karşılar: true = darbe boşa gitti. Ağır darbe kâğıdı yırtar, geçer; büyük jutsu durmaz.
static func parry(who: Node3D, info: Dictionary) -> bool:
	if not who.has_meta("kasa_guard") or Game.now() > float(who.get_meta("kasa_guard")):
		return false
	if info.get("sure", false) or int(info.get("tier", -1)) >= 3:
		return false
	var f = _face(who)
	var atk = info.get("attacker")
	var to: Vector3 = (atk.global_position - who.global_position) if atk is Node3D and is_instance_valid(atk) else -Vector3(info.get("dir", Vector3.ZERO))
	to.y = 0.0
	if to.length() < 0.05 or to.normalized().dot(f) < 0.25:
		return false
	who.remove_meta("kasa_guard")
	var c = who.global_position + Vector3.UP * _h(who) * 0.62 + f * 1.05
	if str(info.get("kind", "light")) in ["heavy", "launch"]:
		who.set_meta("kasa_tok", int(who.get_meta("kasa_tok", 0)) + 1)
		_shape(who, "")
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kasa Yırtıldı!", Color(1.0, 0.7, 0.4))
		Sfx.play("hit_fan", c, 0.7, 0.8)
		return false
	Sfx.play("block", c, 1.25, 0.8)
	Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Karşılandı!", Color(0.75, 0.95, 0.9))
	# kaburgalar titrer: kenardan dışa kısa iğne parıltıları
	var side = Vector3.UP.cross(f).normalized()
	var list = []
	for i in 10:
		var a = TAU * i / 10.0
		var d = side * cos(a) + Vector3.UP * sin(a)
		list.append({"a": c + d * 0.72, "b": c + d * 1.25 + f * 0.25, "t0": 0.0, "fly": 0.1})
	_needles(list, 0.32, 0.0)
	if bool(info.get("melee", false)) and atk is Node3D and is_instance_valid(atk):
		if atk.has_method("stagger"):
			atk.stagger(0.55)
		elif atk.has_method("apply_status"):
			atk.apply_status("stun", 0.4)
	return true


# ------------------------------------------------------------------ kombo bağları (KeyedCombos)
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	match i:
		0:
			who.set_meta("kasa_tok", int(who.get_meta("kasa_tok", 0)) + 1)
			_shape(who, "")
		1:
			_open(who, 0.12, 0.6)
			_after(who, 0.12, func():
				who.set_meta("kasa_guard", Game.now() + GUARD_T))
		2:
			_open(who, 0.04, 0.82)
		3:
			_open(who, 0.12, 0.42)
		4:
			who.set_meta("kasa_tok", int(who.get_meta("kasa_tok", 0)) + 1)
			_shape(who, "")
			_after(who, 0.24, func():
				draw_sword(who, 0.6))
		5:
			_open(who, 0.18, 0.2)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	match i:
		3:
			_pay(who, STEP_COST)
			volley(who, dmg)
		5:
			shower(who, dmg)
