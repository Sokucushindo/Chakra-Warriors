extends RefCounted
## Nuno Maki (布, Narutopedia "Binding Cloth", hedef: res://scripts/combat/fx/nuno_maki_fx.gd). Kullanıcılar: Maki, Nonota (Suna).
## Kanon: dev kumaş rulosu serbestçe yönetilir. Nunoshibari: sarıp hareketi keser, üstüne mühür etiketi konur. Anime: Nunogakure ile kaçışı gizler,
## Protective Cloth Dome ile korur; ıslanırsa Shakuton gibi ısı tekniklerine dayanır.
## Mekanik (alet tuşu, sırtta rulo şart):
##   Normal: en yakın rakibe uçar, sarar, mühür etiketiyle bağlar.
##   Blok tuşu basılıyken: kumaş çevrende döner; 3 darbe tam durur (ağır darbe 2 sayar). Ateş kuru kumaşı yakar; ıslak (wet) kumaş ateşi de tutar. Büyük jutsu geçer.
##   Canın azken ve rakip yakınken: kumaş seni örter, geri süzülürsün, peşindekiler izini kaybeder.
## Yüzde indirim yok: darbe ya tam durur ya geçer. Görünen her şey bu dosyada. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const RANGE := 15.0
const BIND_T := 1.9
const MAX_H := 3.4
const GUARD_T := 3.5
const GUARD_N := 3
const ESCAPE_HP := 0.4
const ESCAPE_D := 8.5
const FIRE := ["katon", "shakuton", "yoton", "futton", "bakuton"]

const CLOTH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
instance uniform float prog = 1.0;
instance uniform float wet = 0.0;
void fragment() {
	if (UV.x > prog) discard;
	float e = abs(UV.y * 2.0 - 1.0);
	vec3 c = FRONT_FACING ? vec3(0.95, 0.92, 0.8) : vec3(0.74, 0.7, 0.58);
	c = mix(c, c * vec3(0.62, 0.68, 0.76), wet);
	ALBEDO = mix(c, vec3(0.08, 0.07, 0.06), smoothstep(0.93, 0.97, e));   // kaynaktaki siyah kenar çizgisi
}
"""


## Sırt eşyası modeli (back_items_ext "nuno_maki"): X boyunca yatan rulo, uçta sarmal, üstünde çapraz kat çizgileri (Binding_Cloth.png)
static func roll_mesh(b: MB) -> void:
	var cream = Color(0.95, 0.92, 0.8)
	var line = Color(0.2, 0.18, 0.15)
	b.add("cyl", Vector3.ZERO, Vector3(0.28, 0.66, 0.28), cream, Vector3(0, 0, 90), 16)
	for s in [-1.0, 1.0]:
		for k in 3:
			b.add("torus", Vector3(0.331 * s, 0, 0), Vector3(0.24 - k * 0.07, 0.008, 0.24 - k * 0.07), line, Vector3(0, 0, 90), 16)
	for k in 3:
		b.add("torus", Vector3(-0.2 + k * 0.2, 0, 0), Vector3(0.286, 0.012, 0.286), cream.darkened(0.25), Vector3(14, 0, 90), 16)
	b.add("box", Vector3(0.05, 0.135, 0.03), Vector3(0.1, 0.006, 0.07), Color(0.72, 0.1, 0.14))   # mühür etiketi


static func has_roll(who: Node3D) -> bool:
	var m = who.get("model") if who != null else null
	return m != null and m is CharacterModel and str(m.look.get("back_item", "")) == "nuno_maki"


# ------------------------------------------------------------------ kumaş geometrisi
static func _mat() -> ShaderMaterial:
	return Kit.shader_mat("nuno_cloth", CLOTH_SH)


## Birim sarmal bant: yarıçap 1, boy 1 (Y), UV.x bant boyunca
static func _helix(key: String, turns: float, band: float, r_fn: Callable) -> Mesh:
	return Kit.cached_mesh("nuno_" + key, func():
		var v = PackedVector3Array()
		var uv = PackedVector2Array()
		var idx = PackedInt32Array()
		var n = int(turns * 26.0)
		for i in n + 1:
			var u = float(i) / n
			var a = u * turns * TAU
			var y = u
			var r: float = r_fn.call(y)
			var d = Vector3(cos(a), 0, sin(a))
			v.append(d * r + Vector3.UP * (y - band * 0.5))
			v.append(d * r + Vector3.UP * (y + band * 0.5))
			uv.append(Vector2(u, 0))
			uv.append(Vector2(u, 1))
		for i in n:
			var q = i * 2
			idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m)


static func _mi(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat()
	mi.extra_cull_margin = 6.0
	parent.add_child(mi)
	return mi


## İki nokta arasında dalgalanan yassı kumaş şeridi (her kare yeniden)
static func _ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, w: float, t: float) -> void:
	im.clear_surfaces()
	var d = b - a
	var L = d.length()
	if L < 0.05:
		return
	var f = d / L
	var side = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
	var up = side.cross(f).normalized()
	var n = 18
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n + 1:
		var u = float(i) / n
		var wave = sin(u * 9.0 - t * 15.0) * 0.16 * sin(u * PI)
		var p = a + d * u + up * wave + side * cos(u * 6.0 - t * 11.0) * 0.08 * sin(u * PI)
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(p - side * w)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(p + side * w)
	im.surface_end()


static func _ribbon_mi(parent: Node3D) -> Array:
	var im = ImmediateMesh.new()
	var mi = _mi(parent, im)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY
	return [im, mi]


static func _back(who: Node3D) -> Vector3:
	return Kit.chest(who) + Vector3.UP * 0.1 - _face(who) * 0.3


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _foe(who: Node3D, r: float, preferred: Node3D) -> Node3D:
	if preferred != null and is_instance_valid(preferred) and not preferred.is_dead() and preferred.global_position.distance_to(who.global_position) <= r:
		return preferred
	var best: Node3D = null
	var bd = r
	for x in Kit.fighters():
		if x == who or not Combat.hostile(who, x) or x.is_dead():
			continue
		var d = (x as Node3D).global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = x
	return best


# ------------------------------------------------------------------ alet tuşu
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, target: Node3D) -> Projectile:
	var foe = _foe(who, RANGE, target)
	var guard = (who is Player and Input.is_action_pressed("guard")) or (who is Enemy and foe != null and foe.global_position.distance_to(who.global_position) < 3.0 and float(who.get("skill")) > 0.5)
	var hurt = float(who.get("hp")) < float(who.get("max_hp")) * ESCAPE_HP
	if guard:
		_guard(who)
	elif hurt and foe != null and foe.global_position.distance_to(who.global_position) < 9.0:
		_escape(who, foe)
	elif foe != null:
		_bind(who, foe)
	else:
		_guard(who)   # hedef yok: kumaş boşa gitmesin, çevrende döner
	Sfx.play("swing_fan", who.global_position + Vector3.UP, 0.75, 0.8)
	return null


# ------------------------------------------------------------------ Nunoshibari: uç, sar, etiketle
static func _bind(who: Node3D, t: Node3D) -> void:
	var s = {"t": 0.0, "stage": 0, "t0": 0.0}
	var FLY = 0.26
	var ht = Kit.height_of(t)
	var fits = ht <= MAX_H
	var r = (float(t.get("radius")) if t.get("radius") != null else 0.4) + 0.14
	var n := {}   # düğümler işlevden sonra kurulur: işlev sözlüğü yakalar
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or not is_instance_valid(t) or t.is_dead():
			return true
		var rb: Array = n["rb"]
		var wrap_m: MeshInstance3D = n["wrap"]
		var seal: MeshInstance3D = n["seal"]
		s["t"] += dt
		var k: float = s["t"]
		var c = Kit.chest(t)
		var from = _back(who)
		if int(s["stage"]) == 0:
			var u = clampf(k / FLY, 0.0, 1.0)
			_ribbon(rb[0], from, from.lerp(c, u), 0.17, k)
			if u >= 1.0:
				s["stage"] = 1
				s["t0"] = k
				if fits and t.has_method("apply_status"):
					t.apply_status("bind", BIND_T)
				t.take_hit({"dmg": 3.0, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "tool": "nuno_maki"})
				Sfx.play("swing_fan", c, 0.6, 0.8)
			return false
		var e = k - float(s["t0"])
		if not fits:
			return e > 0.3
		var hold = BIND_T
		var p = minf(e / 0.28, 1.0) * (1.0 - clampf((e - hold + 0.25) / 0.25, 0.0, 1.0))
		wrap_m.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(r, ht * 1.04, r)), t.global_position)
		wrap_m.set_instance_shader_parameter("prog", p)
		wrap_m.visible = true
		_ribbon(rb[0], from, from.lerp(c, clampf(1.0 - e / 0.28, 0.0, 1.0)), 0.17 * clampf(1.0 - e / 0.28, 0.02, 1.0), k)
		var fw = (who.global_position - t.global_position)
		fw.y = 0.0
		var nz = fw.normalized() if fw.length() > 0.05 else Vector3.BACK
		seal.visible = e > 0.26 and p > 0.1
		seal.global_transform = Transform3D(Basis(Vector3.UP.cross(nz).normalized(), Vector3.UP, nz), c + nz * (r + 0.03))
		return e >= hold
	var root = Kit.ticker(t.global_position, fn)
	n["rb"] = _ribbon_mi(root)
	var egg = func(y: float) -> float:
		return 0.52 + 0.55 * sqrt(maxf(0.0, 1.0 - pow(y * 2.0 - 1.0, 2.0)))   # yumurta biçimli koza (Cloth_binding_technique.png)
	var wrap_new = _mi(root, _helix("wrap", 9.0, 0.125, egg))
	wrap_new.visible = false
	n["wrap"] = wrap_new
	var seal_new = MeshInstance3D.new()
	n["seal"] = seal_new
	var make_seal = func() -> Mesh:
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.22, 0.28, 0.006), Color(0.72, 0.1, 0.14))
		for k in 3:
			b.add("box", Vector3(-0.05 + k * 0.05, 0.0, 0.005), Vector3(0.018, 0.2, 0.003), Color(0.08, 0.05, 0.05))
		return b.build(LazyFx.g("Props").toon())
	seal_new.mesh = Kit.cached_mesh("nuno_seal", make_seal)
	root.add_child(seal_new)
	seal_new.visible = false


# ------------------------------------------------------------------ koruyan kumaş
static func _guard(who: Node3D) -> void:
	var now = Game.now()
	var tok = int(who.get_meta("nuno_tok", 0)) + 1
	who.set_meta("nuno_tok", tok)
	who.set_meta("nuno_until", now + GUARD_T)
	who.set_meta("nuno_left", GUARD_N)
	var s = {"t": 0.0}
	var n := {}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or who.is_dead() or int(who.get_meta("nuno_tok", 0)) != tok:
			return true
		var mi: MeshInstance3D = n["mi"]
		s["t"] += dt
		var t: float = s["t"]
		var left = float(who.get_meta("nuno_until", 0.0)) - Game.now()
		if left <= 0.0:
			return true
		var w = 1.0 if who.has_method("has_status") and who.has_status("wet") else 0.0
		mi.set_instance_shader_parameter("wet", w)
		mi.set_instance_shader_parameter("prog", minf(t / 0.3, 1.0) * clampf(left / 0.25, 0.0, 1.0))
		mi.global_transform = Transform3D(Basis(Vector3.UP, t * 2.2).scaled(Vector3(1.0, Kit.height_of(who) * 1.1, 1.0)), who.global_position)
		return false
	var root = Kit.ticker(who.global_position, fn)
	# aralıklı iki buçuk tur: kubbe kabuğu değil, boşlukları görünen kumaş şerit (Hiding_in_Cloth.png)
	var bulge = func(y: float) -> float:
		return 1.25 + 0.3 * sin(y * PI)
	var band = _mi(root, _helix("guard", 2.6, 0.2, bulge))
	band.top_level = true
	band.set_instance_shader_parameter("prog", 0.0)
	n["mi"] = band


## Player/Enemy.take_hit çağırır. true: darbe tam durdu.
static func block(who: Node3D, info: Dictionary) -> bool:
	if not who.has_meta("nuno_until") or Game.now() > float(who.get_meta("nuno_until")):
		return false
	if info.get("sure", false) or int(info.get("tier", -1)) >= 3:
		return false
	var wet = who.has_method("has_status") and who.has_status("wet")
	if str(info.get("element", "")) in FIRE and not wet:
		who.set_meta("nuno_until", 0.0)   # kuru kumaş tutuşur: darbe geçer
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kumaş Yandı!", Color(1.0, 0.6, 0.3))
		Sfx.play("fire", who.global_position + Vector3.UP, 1.1, 0.8)
		return false
	var cost = 2 if str(info.get("kind", "light")) in ["heavy", "launch"] else 1
	var left = int(who.get_meta("nuno_left", 0)) - cost
	who.set_meta("nuno_left", left)
	if left <= 0:
		who.set_meta("nuno_until", 0.0)
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kumaş Yırtıldı!", Color(0.95, 0.85, 0.65))
	Sfx.play("hit_fan", who.global_position + Vector3.UP, 0.8, 0.8)
	return left >= 0


# ------------------------------------------------------------------ Nunogakure
static func _escape(who: Node3D, foe: Node3D) -> void:
	var at = who.global_position
	var away = at - foe.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else -_face(who)
	var dest = PlayerCombat.safe_dest(who, at, at + away * ESCAPE_D)
	var s = {"t": 0.0, "moved": false}
	var strips: Array = []
	var T = 0.75
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		if t >= T:
			return true
		if t >= 0.12 and not bool(s["moved"]) and is_instance_valid(who):
			s["moved"] = true
			who.global_position = dest
			for e in Kit.fighters():
				if e is Enemy and Combat.hostile(who, e) and e.target == who and e.global_position.distance_to(at) < 18.0:
					e.target = null   # kumaşın ardında izini kaybeder
		for i in strips.size():
			var a = TAU * i / strips.size() + t * 3.2
			var o = at + Vector3.UP * (0.3 + 0.32 * i)
			var r = 0.4 + 3.0 * minf(t / 0.2, 1.0)
			var q = o + Vector3(cos(a), 0.18, sin(a)) * r
			var q2 = o + Vector3(cos(a + 1.5), -0.1, sin(a + 1.5)) * r
			var fade = clampf((T - t) / 0.3, 0.0, 1.0)
			_ribbon(strips[i][0], q, q.lerp(q2, fade), 0.34 * fade, t + i)
		return false
	var root = Kit.ticker(at, fn)
	for i in 6:
		strips.append(_ribbon_mi(root))
	Combat.popup_text(at + Vector3.UP * 2.3, "Nunogakure!", Color(0.95, 0.92, 0.8))
