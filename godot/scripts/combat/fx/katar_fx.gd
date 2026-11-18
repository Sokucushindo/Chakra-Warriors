extends RefCounted
## Katāru: model, delme izi, kanama ve gövdeden geçiş — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kaynak (gerçek dünya, Wikipedia "Katar (dagger)"): iki paralel kol + çapraz tutamaklı H kabza; ağız kolun doğrultusunda, temel saldırı yumruk gibi düz itiş,
## bütün kilo arkasında; Tamil adı "kalkan yaran". Narutopedia yalnız kullanıcıları listeler (görsel/teknik yok): kanon biçim iddia edilmez. Oyuncu ve düşman aynı kod.

const ID := "katar"
const REACH_TIP := 1.55    # delme izinin gövdeden uzaklığı

static var _c := {}

const STREAK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying float along;
void vertex() {
	along = VERTEX.z + 0.5;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * smoothstep(0.0, 0.8, along);
}
"""


# ------------------------------------------------------------------ model
## Yumruk çerçevesi (pençe ile aynı): +X parmak eklemlerinden ileri (ön kol doğrultusu), +Y el sırtı, Z yumruk boyunca.
## H kabza: Z boyunca avuçta iki çapraz tutamak, X boyunca iki yan kol; ağız üçgen, orta sırtlı, yassı yüzü Y'ye bakar.
static func model(b: MB) -> void:
	var steel = Color(0.74, 0.76, 0.8)
	var ridge = Color(0.92, 0.93, 0.95)
	var brass = Color(0.62, 0.48, 0.24)
	var dark = Color(0.2, 0.17, 0.15)
	for s in [-1.0, 1.0]:
		b.add("box", Vector3(-0.015, 0.0, 0.056 * s), Vector3(0.22, 0.016, 0.014), brass)   # yan kollar (bileğe uzanır)
		b.add("sphere", Vector3(-0.125, 0.0, 0.056 * s), Vector3(0.022, 0.022, 0.022), brass, Vector3.ZERO, 6)
	for x in [-0.018, 0.022]:
		b.add("cyl", Vector3(x, 0, 0), Vector3(0.022, 0.112, 0.022), dark, Vector3(90, 0, 0), 6)   # avuçtaki tutamaklar
	b.add("box", Vector3(0.096, 0, 0), Vector3(0.022, 0.024, 0.128), brass)   # ağız kökü
	var o = PackedVector2Array([Vector2(0.105, -0.046), Vector2(0.27, -0.03), Vector2(0.44, 0.0), Vector2(0.27, 0.03), Vector2(0.105, 0.046)])
	# profil (y,z) -> burada (x,z): slab yassı ekseni X olduğundan Y ekseni etrafında çevrilir
	var flip = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	b.add_slab(o, 0.012, steel, Transform3D(flip, Vector3.ZERO))
	b.add("box", Vector3(0.25, 0, 0), Vector3(0.3, 0.015, 0.006), ridge)   # orta sırt


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


## list: [from, yön, boy, renk]; kısa ömürlü ince çizgiler
static func _streaks(list: Array, life: float) -> void:
	var root = _root()
	if root == null or list.is_empty():
		return
	if not _c.has("mesh"):
		var b = BoxMesh.new()
		b.size = Vector3(0.02, 0.008, 1.0)
		_c["mesh"] = b
		var s = Shader.new()
		s.code = STREAK_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["mat"] = m
	var n = list.size()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _c["mesh"]
	mm.instance_count = n
	var c0: Vector3 = list[0][0]
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), list[i][0]))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _c["mat"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(c0 - Vector3.ONE * 8.0, Vector3.ONE * 16.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		for i in n:
			var e: Array = list[i]
			var d: Vector3 = (e[1] as Vector3).normalized()
			var x = (Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).cross(d).normalized()
			var L: float = float(e[2]) * minf(t * 4.0, 1.0)
			var c: Color = e[3]
			mm.set_instance_transform(i, Transform3D(Basis(x, d.cross(x), d * L), (e[0] as Vector3) + d * (L * 0.5 + float(e[2]) * t * 0.6)))
			mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * (1.0 - t))), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Delme izi: yumruk hizasından ileri ince keskin çizgi + yanlarda iki kısa çizgi
static func _thrust(who: Node3D, side_off: float, d: Vector3, y: float, reach := REACH_TIP) -> void:
	var f = _face(who)
	var side = Vector3.UP.cross(f).normalized()
	var p = who.global_position + Vector3.UP * y + side * side_off + f * 0.45
	var white = Color(0.93, 0.95, 1.0, 0.95)
	var pale = Color(0.72, 0.78, 0.86, 0.6)
	_streaks([[p, d, reach, white], [p + side * 0.05, d, reach * 0.7, pale], [p - side * 0.05 + Vector3.UP * 0.03, d, reach * 0.62, pale]], 0.16)
	Sfx.play("swing_blade", p, randf_range(1.35, 1.55), 0.45)


## Yalnız ağzın ucunun değdiği yerde: küçük kanatan delme (ek hasar az; asıl darbe yumruk vuruşu)
static func _pierce(who: Node3D, p: Vector3, dmg: float, bleed: float) -> Array:
	return Combat.hit_sphere(who, p, 0.65, {"dmg": dmg * 0.14, "knock": 0.0, "kind": "light", "bleed": bleed, "hitstop": 0.0, "melee": true})


## Tōshi: iki kol kilitli, gövde rakibin içinden geçer; yol üstünde herkes bir kez delinir
static func _run_through(who: Node3D, dmg: float) -> void:
	var f = _face(who)
	var side = Vector3.UP.cross(f).normalized()
	var D = 4.6
	var T = 0.15
	var from = who.global_position
	var done: Array = []
	var last = {"k": 0.0}
	var tw = who.create_tween()
	tw.tween_method(func(k: float):
		var dk = k - float(last["k"])
		last["k"] = k
		var p: Vector3 = who.global_position
		who.global_position = PlayerCombat.safe_dest(who, p, p + f * D * dk)
		var hits = Combat.hit_sphere(who, who.global_position + Vector3.UP * 1.05 + f * 0.5, 1.05, {"dmg": dmg * 1.55, "knock": 2.0, "stun": 0.45, "kind": "heavy", "bleed": 3.0, "hitstop": 0.09, "melee": true}, done)
		done.append_array(hits)
		for h in hits:
			if h.has_method("apply_status"):
				h.apply_status("armor_broken", 5.0)   # "kalkan yaran": delinen zırh bir süre işe yaramaz
			Sfx.play("hit_blade", h.global_position + Vector3.UP, 0.8, 0.9), 0.0, 1.0, T)
	var list = []
	for k in 9:   # geçiş çizgileri: gövde boyunca ince hız izleri
		var o = side * randf_range(-0.42, 0.42) + Vector3.UP * randf_range(0.25, 1.65)
		list.append([from + o + f * randf_range(0.0, 1.5), f, randf_range(2.4, 4.4), Color(0.9, 0.93, 1.0, 0.8)])
	_streaks(list, 0.24)
	Sfx.play("whoosh", from, 1.55, 0.8)


# ------------------------------------------------------------------ kombo bağları
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	var side = Vector3.UP.cross(f).normalized()
	var c = who.global_position + Vector3.UP * 1.15 + f * 1.45
	match i:
		0:
			_thrust(who, -0.2, f, 1.25)
			_pierce(who, c, dmg, 1.5)
		1:
			_thrust(who, 0.2, f, 1.25)
			_pierce(who, c, dmg, 1.5)
		2:
			_thrust(who, -0.22, (f + side * 0.16).normalized(), 1.0, 1.25)
			_thrust(who, 0.22, (f - side * 0.16).normalized(), 1.0, 1.25)
			_pierce(who, c + Vector3.DOWN * 0.15, dmg * 1.4, 2.5)
		4:
			_thrust(who, -0.1, (f * 0.42 + Vector3.UP).normalized(), 0.8, 1.7)
			_pierce(who, who.global_position + Vector3.UP * 1.4 + f * 1.1, dmg, 2.0)
		5:
			_run_through(who, dmg)
