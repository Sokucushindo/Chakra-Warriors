extends RefCounted
## Sasumata: model, kıskaç mekaniği ve çatal patlaması — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kaynak: Gamaken_vs_Rhino.png / Gamaken.png (çift kollu koyu demir çatal, her yanı diken), Exploding_Sasumata_Attack_1.png (uçta beyaz yıldız patlama).
## Kanon: "in the anime he can also cause explosions with his sasumata". Tutma mekaniği gerçek silahtan (Edo zaptiyesinin adam yakalayan sırığı):
## rakip çatalda uzakta tutulur, itilir, yere / duvara kıstırılır. Dev gövdeyi çatal almaz: hasar geçer, tutma olmaz.
## Oyuncu ve düşman aynı kod.

const ID := "sasumata"
const HOLD_D := 2.05         # tutulanın gövde merkezinden uzaklığı (çatal ağzı)
const MAX_H := 3.4           # bundan uzun gövde çatala sığmaz
const BLAST_COST := 0.08

static var _c := {}

const STAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float ray(vec2 p, float a, float w) {
	float c = cos(a), s = sin(a);
	vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	return (1.0 - smoothstep(0.0, w * (1.0 - abs(q.x)) + 0.001, abs(q.y))) * (1.0 - smoothstep(0.55, 1.0, abs(q.x)));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float grow = 0.35 + 0.65 * sqrt(prog);
	p /= grow;
	float m = ray(p, 0.62, 0.075) + ray(p, 2.3, 0.05) * 0.8 + ray(p, 1.32, 0.022) * 0.7;
	float fade = 1.0 - smoothstep(0.35, 1.0, prog);
	ALBEDO = mix(vec3(0.72, 0.8, 1.0), vec3(1.0), clamp(m, 0.0, 1.0));
	ALPHA = clamp(m * fade * 1.4, 0.0, 1.0);
	if (ALPHA < 0.01) discard;
}
"""

const SPARK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, çatal +Z, çatal kolları x-z düzleminde. Sap: demir, kavrama yeri sargılı; kollar dışa açılıp uçta içe kıvrılır, her yanı konik diken.
static func model(b: MB) -> void:
	var iron = Color(0.24, 0.25, 0.31)
	var dk = Color(0.15, 0.15, 0.2)
	var grip = Color(0.2, 0.15, 0.13)
	b.add("cyl", Vector3(0, 0, 0.36), Vector3(0.042, 2.0, 0.042), iron, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.05), Vector3(0.05, 0.9, 0.05), grip, Vector3(90, 0, 0), 8)
	for k in 6:
		b.add("cyl", Vector3(0, 0, -0.42 + k * 0.15), Vector3(0.054, 0.018, 0.054), dk, Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, -0.65), Vector3(0.075, 0.075, 0.09), dk, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, 0, 1.34), Vector3(0.1, 0.075, 0.12), iron, Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		var pts = [Vector3(0, 0, 1.32), Vector3(0.1 * sx, 0, 1.43), Vector3(0.215 * sx, 0, 1.58), Vector3(0.225 * sx, 0, 1.76), Vector3(0.15 * sx, 0, 1.9)]
		Loft.tube(b, pts, [0.044, 0.04, 0.034, 0.026, 0.012], iron, 7, 3)
		for j in 4:   # kol dikenleri: dış ve iç yüz
			var u = (j + 0.6) / 4.0
			var p = _curve(pts, u)
			_spike(b, p, Vector3(sx, 0, 0.25), 0.082, dk)
			if j % 2 == 0:
				_spike(b, p, Vector3(0, 1, 0.1), 0.06, dk)
				_spike(b, p, Vector3(0, -1, 0.1), 0.06, dk)
			else:
				_spike(b, p, Vector3(-sx, 0, 0.3), 0.05, dk)
	for k in 5:   # sapın üst yarısında sarmal dikenler
		var a = k * 2.4
		_spike(b, Vector3(cos(a) * 0.02, sin(a) * 0.02, 0.62 + k * 0.14), Vector3(cos(a), sin(a), 0.15), 0.07, dk)


static func _curve(pts: Array, u: float) -> Vector3:
	var f = u * (pts.size() - 1)
	var i = mini(int(f), pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


static func _spike(b: MB, p: Vector3, d: Vector3, L: float, col: Color) -> void:
	var y = d.normalized()
	var x = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	b.add_xf("cone", Transform3D(Basis(x * L * 0.5, y * L, z * L * 0.5), p + y * L * 0.45), col, 5)


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


static func _after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


static func _fits(h: Node3D) -> bool:
	return h is CharacterBody3D and (float(h.get("height")) if h.get("height") != null else 1.8) <= MAX_H


static func _held(who: Node3D) -> Node3D:
	var id = int(who.get_meta("sas_held", 0))
	if id == 0:
		return null
	var o = instance_from_id(id)
	if o == null or not is_instance_valid(o) or not (o is Node3D) or o.is_dead():
		return null
	return o


static func release(who: Node3D) -> void:
	who.set_meta("sas_held", 0)
	who.set_meta("sas_tok", int(who.get_meta("sas_tok", 0)) + 1)


# ------------------------------------------------------------------ kıskaç
## Rakibi çatal ağzında tut: bağlanır, kullanıcının önünde kalır; süre dolunca ya da yeni emirle bırakılır
static func grip(who: Node3D, h: Node3D, dur: float) -> void:
	if not _fits(h) or h.is_dead():
		return
	if h.has_method("apply_status"):
		h.apply_status("bind", dur)
	who.set_meta("sas_held", h.get_instance_id())
	var tok = int(who.get_meta("sas_tok", 0)) + 1
	who.set_meta("sas_tok", tok)
	Sfx.play("clink", h.global_position + Vector3.UP, 0.75, 0.7)
	var last = {"k": 0.0}
	var tw = who.create_tween()
	tw.tween_method(func(k: float):
		var dt = (k - float(last["k"])) * dur
		last["k"] = k
		if int(who.get_meta("sas_tok", 0)) != tok or not is_instance_valid(h) or h.is_dead():
			return
		var hp: Vector3 = h.global_position
		var to = who.global_position + _face(who) * HOLD_D
		to.y = hp.y
		h.global_position = PlayerCombat.safe_dest(h, hp, hp.move_toward(to, 16.0 * dt))
		(h as CharacterBody3D).velocity = Vector3.ZERO, 0.0, 1.0, dur)
	tw.tween_callback(func():
		if int(who.get_meta("sas_tok", 0)) == tok:
			who.set_meta("sas_held", 0))


## Kullanıcıyı ileri yürüt (tutulan çatalın önünde taşınır); duvar güvenli
static func _drive(who: Node3D, dist: float, dur: float) -> void:
	var last = {"k": 0.0}
	var tw = who.create_tween()
	tw.tween_method(func(k: float):
		var dk = k - float(last["k"])
		last["k"] = k
		var p: Vector3 = who.global_position
		var f = _face(who)
		var block = _held(who)
		if block != null and _wall_ahead(who, block, f, 0.8):
			return   # rakip duvara dayandı: itiş durur
		who.global_position = PlayerCombat.safe_dest(who, p, p + f * dist * dk), 0.0, 1.0, dur)


static func _wall_ahead(who: Node3D, h: Node3D, f: Vector3, d: float) -> bool:
	var a = h.global_position + Vector3.UP
	var q = PhysicsRayQueryParameters3D.create(a, a + f * d, 1, [who.get_rid(), h.get_rid()])
	return not who.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ patlama
static func _mat(key: String, code: String) -> ShaderMaterial:
	key = "mat:" + key
	if not _c.has(key):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[key] = m
	return _c[key]


## Çatal ucunda beyaz yıldız + geri fışkıran demir kıvılcım çizgileri
static func blast_fx(p: Vector3, f: Vector3) -> void:
	var root = _root()
	if root == null:
		return
	if not _c.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(5.2, 5.2)   # gölgelendirici kameraya çevirirken ölçeği atar: boy mesh'te
		_c["quad"] = q
	var st = MeshInstance3D.new()
	st.mesh = _c["quad"]
	st.material_override = _mat("star", STAR_SH)
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st.extra_cull_margin = 6.0
	root.add_child(st)
	st.global_position = p
	var tw = st.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(st):
			st.set_instance_shader_parameter("prog", v), 0.0, 1.0, 0.3)
	tw.tween_callback(st.queue_free)
	if not _c.has("spark"):
		var b = BoxMesh.new()
		b.size = Vector3(0.022, 0.022, 1.0)
		_c["spark"] = b
	var n = 16
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _c["spark"]
	mm.instance_count = n
	var dirs = []
	for i in n:
		var d = (f * randf_range(-0.2, 1.0) + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1))).normalized()
		dirs.append([d, randf_range(5.0, 12.0)])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("sparkm", SPARK_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(p - Vector3.ONE * 6.0, Vector3.ONE * 12.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var t2 = mi.create_tween()
	t2.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		for i in n:
			var d: Vector3 = dirs[i][0]
			var sp: float = dirs[i][1]
			var pos = p + d * sp * t + Vector3.DOWN * 7.0 * t * t
			var v = (d * sp + Vector3.DOWN * 14.0 * t).normalized()
			var x = (Vector3.UP if absf(v.y) < 0.95 else Vector3.RIGHT).cross(v).normalized()
			var L = 0.5 * (1.0 - t / 0.34)
			mm.set_instance_transform(i, Transform3D(Basis(x, v.cross(x), v * L), pos))
			mm.set_instance_color(i, Color(1.0, 0.82, 0.55, 1.0 - t / 0.34)), 0.0, 0.34, 0.34)
	t2.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var h = _held(who)
	if i == 1:
		if h != null:
			grip(who, h, 0.75)   # önceki adımda çatala alınan, itiş boyunca çatalda kalır
		_after(who, 0.1, func():
			_drive(who, 2.5, 0.46))
	elif i == 5:
		if h != null:
			grip(who, h, 0.8)    # yere çivilenen, patlamaya kadar çatalda
		_after(who, 0.58, func():
			_drive(who, 0.7, 0.1))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	match i:
		1:
			var h = _held(who)
			if h != null and _wall_ahead(who, h, f, 1.0):   # duvara kıstırıldı: kanonik zaptiye kullanımı
				if h.has_method("apply_status"):
					h.apply_status("stun", 1.1)
				Combat.hit_sphere(who, h.global_position + Vector3.UP, 0.9, {"dmg": dmg * 0.55, "knock": 0.0, "kind": "heavy", "hitstop": 0.06, "melee": true})
				Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Kıstırıldı!", Color(1.0, 0.8, 0.45))
				Sfx.play("hit_heavy_weapon", h.global_position, 0.8, 0.9)
		5:
			var h = _held(who)
			var at = (h.global_position + Vector3.UP) if h != null else who.global_position + Vector3.UP * 1.1 + f * 2.5
			release(who)
			if not _pay(who, BLAST_COST):
				return   # chakra yok: yalnız düz itiş
			blast_fx(at, -f)
			Sfx.play("boom", at, 1.25, 0.85)
			if who is Player and Game.world:
				Game.world.env.add_shake(0.5)
			Combat.hit_sphere(who, at, 2.1, {"dmg": dmg * (1.05 if h != null else 0.75), "knock": 13.0, "launch": 3.5, "kind": "heavy", "hitstop": 0.08})


## İsabet eden hedefe adımın kıskaç etkisi
static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if h == null or not is_instance_valid(h) or h.is_dead():
		return
	var f = _face(who)
	match i:
		0:
			grip(who, h, 0.95)
		1:
			grip(who, h, 0.7)
		2:
			release(who)
			if h is CharacterBody3D:   # bilek çatalda: kullanıcıya doğru yere çekilir
				h.velocity = -f * 5.0 + Vector3.DOWN * 2.0
		3:
			release(who)
		4:
			if _fits(h):
				var p = who.global_position + f * HOLD_D
				p.y = Game.ground_height(p.x, p.z) + 0.05
				h.global_position = PlayerCombat.safe_dest(h, h.global_position, p)
				(h as CharacterBody3D).velocity = Vector3.ZERO
				grip(who, h, 1.0)
				if h.has_method("apply_status"):
					h.apply_status("stun", 0.8)
