extends RefCounted
## Fūin Fuda (封印札; hedef: res://scripts/combat/fx/fuin_fuda_fx.gd). Kanon (Narutopedia "Sealing Tag", Naruto 556-558): rakibe ya da nesneye konur; etiket sağlam kaldıkça
## hedef ÇAĞRILAMAZ. Mühür yazısı bedene yayılır, arka tarafta düğümlenir. Kunaiye bağlanıp uzaktan atılır, etiketler birleşince güçlenir; mühür bitmeden sökülebilir,
## bitince çıkarması çok zordur. Görünüş refs/fuin_fuda: kızıl etiket, her yöne yayılan kara yazı şeritleri.
## Oyunda: düşen hedefte yazı yayılır (2,6 sn; bağlıysa yarısı). Yer değiştirme (Kawarimi) mührü bitmeden düşürür. Bitince: çağrılmış yaratık mühürlenip gider;
## ninja süre boyunca hiçbir Kuchiyose yapamaz. 3 etiket birleşirse hedef düğümlenir (kısa bağ + chakra kapanır). Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const SEAL_T := 2.6
const STEP_DOWN := 0.8    # her ek etiket mührü hızlandırır
const LOCK_T := 14.0
const LOCK_ADD := 4.0
const LINES := 10

const SCRIPT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade_k = 1.0;
float h(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	if (UV.x > prog) discard;
	float c = floor(UV.x * 46.0);
	float fx = fract(UV.x * 46.0);
	float y = UV.y;
	float a = step(abs(y - (0.25 + 0.5 * h(c))), 0.13) + step(abs(fx - h(c + 3.0)), 0.16) * step(0.15, y) * step(y, 0.85);
	if (a < 0.5 || fx > 0.84) discard;
	ALBEDO = vec3(0.04, 0.03, 0.04);
	ALPHA = fade_k;
}
"""


static func _tag(b: MB, xf: Transform3D) -> void:
	var t = MB.new()
	var red = Color(0.78, 0.13, 0.2)
	var ink = Color(0.1, 0.03, 0.05)
	t.add("box", Vector3.ZERO, Vector3(0.09, 0.2, 0.003), red)
	t.add("box", Vector3(0, 0.0, 0.0025), Vector3(0.016, 0.15, 0.001), ink)
	for k in 7:
		var y = -0.075 + k * 0.025
		t.add("box", Vector3(0.022 * (1 - 2 * (k % 2)), y, 0.0025), Vector3(0.024, 0.006, 0.001), ink, Vector3(0, 0, 18.0 * (1 - 2 * (k % 3 % 2))))
	b.add_mesh(t, xf)


static func _tag_mesh() -> Mesh:
	return Yk.mesh("fuin_etiket", func():
		var b = MB.new()
		_tag(b, Transform3D.IDENTITY)
		return b.build(Props.toon()))


static func _thrown() -> Mesh:
	return Yk.mesh("fuin_kunai", func():
		var b = MB.new()
		var k = MB.new()
		CharacterModel._kunai_mesh(k)
		b.add_mesh(k, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
		_tag(b, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.02, 0.1)))
		return b.build(Props.toon()))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "fuin_fuda", 42.0, 3.0, _thrown(), 2.0)
	pr.on_hit = func(_pos: Vector3, tg: Node3D) -> void:
		if tg != null and is_instance_valid(tg):
			stick(who, tg)
	return pr


## Yazı şeritleri: etiketten çıkar, gövdeyi iki yandan dolaşır, arkada buluşur
static func _lines(root: Node3D, a0: float, r: float, h: float, n: int) -> Array:
	var out := []
	var yc = h * 0.58
	for i in n:
		var sgn = 1.0 if i % 2 == 0 else -1.0
		var dy = (float(i / 2) / maxf(1.0, float(n / 2) - 1.0) - 0.5) * h * 0.95
		var im = ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var seg = 22
		for k in seg + 1:
			var u = float(k) / seg
			var a = a0 + sgn * u * PI
			var y = yc + sin(u * PI) * dy
			var rad = Vector3(sin(a), 0, cos(a))
			var p = rad * (r * (1.0 + 0.06 * sin(u * PI))) + Vector3.UP * y
			var side = Vector3.UP * 0.028
			im.surface_set_uv(Vector2(u, 0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(u, 1))
			im.surface_add_vertex(p + side)
		im.surface_end()
		var mi = MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = Yk.mat("fuin_yazi", SCRIPT_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = h
		root.add_child(mi)
		out.append(mi)
	return out


static func _add_paper(s: Dictionary) -> void:
	var t: Node3D = s["t"]
	var a = float(s["a0"]) + (int(s["n"]) - 1) * 0.5
	var r = float(s["r"])
	var mi = MeshInstance3D.new()
	mi.mesh = _tag_mesh()
	(s["root"] as Node3D).add_child(mi)
	mi.position = Vector3(sin(a), 0, cos(a)) * (r + 0.02) + Vector3.UP * Yk.height_of(t) * (0.58 + (int(s["n"]) - 1) * 0.08)
	mi.rotation.y = a


static func stick(who: Node3D, t: Node3D) -> void:
	Sfx.play("th_paper", t.global_position, 1.1, 0.8)
	var s = t.get_meta("fuin_s", null)
	if s is Dictionary and is_instance_valid(s.get("root")):
		s["n"] = int(s["n"]) + 1
		s["need"] = maxf(0.6, float(s["need"]) - STEP_DOWN)
		_add_paper(s)
		if bool(s["done"]):
			t.set_meta("fuin_until", float(t.get_meta("fuin_until", 0.0)) + LOCK_ADD)
			s["end"] = float(s["end"]) + LOCK_ADD
			_knot_check(s)
		return
	var fr = t.get("radius")
	var r = float(fr) if fr != null else 0.38
	var v: Vector3 = who.global_position - t.global_position
	var root = Node3D.new()
	t.add_child(root)
	var bound = t.has_method("has_status") and t.has_status("bind")
	s = {"t": t, "who": who, "root": root, "n": 1, "k": 0.0, "need": SEAL_T * (0.5 if bound else 1.0), "done": false, "end": 0.0, "r": r, "a0": atan2(v.x, v.z), "p": t.global_position, "knotted": false}
	s["lines"] = _lines(root, float(s["a0"]), r * 1.04, Yk.height_of(t), LINES)
	t.set_meta("fuin_s", s)
	_add_paper(s)
	Kit.ticker(t.global_position, func(dt: float) -> bool:
		return _tick(s, dt))


static func _prog(s: Dictionary, p: String, v: float) -> void:
	for l in s["lines"]:
		if is_instance_valid(l):
			l.set_instance_shader_parameter(p, v)


static func _clear(s: Dictionary) -> void:
	var t = s["t"]
	if is_instance_valid(t):
		t.remove_meta("fuin_s")
	if is_instance_valid(s["root"]):
		s["root"].queue_free()


static func _tick(s: Dictionary, dt: float) -> bool:
	var t = s["t"]
	if not is_instance_valid(t) or t.is_dead() or not is_instance_valid(s["root"]):
		if is_instance_valid(s["root"]):
			s["root"].queue_free()
		return true
	if not bool(s["done"]):
		if (t.global_position - (s["p"] as Vector3)).length() > 4.5:   # kanon: bitmeden sökülebilir (yer değiştirme etiketi geride bırakır)
			Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Etiket düştü", Color(0.85, 0.8, 0.75))
			_clear(s)
			return true
		s["p"] = t.global_position
		s["k"] = float(s["k"]) + dt
		var u = clampf(float(s["k"]) / float(s["need"]), 0.0, 1.0)
		_prog(s, "prog", u)
		if u >= 1.0:
			s["done"] = true
			return _complete(s)
		return false
	var left = float(s["end"]) - Game.now()
	if left < 1.0:
		_prog(s, "fade_k", clampf(left, 0.0, 1.0))
	if left <= 0.0:
		_clear(s)
		return true
	return false


## true: işi bitti
static func _complete(s: Dictionary) -> bool:
	var t = s["t"]
	Sfx.play("seal", t.global_position, 0.85, 0.9)
	Combat.popup_text(t.global_position + Vector3.UP * (Yk.height_of(t) + 0.5), "Mühürlendi!", Color(0.85, 0.2, 0.28))
	if t is Summon:
		_clear(s)
		t.dismiss()
		return true
	if t is ClanConstruct:
		_clear(s)
		t.vanish()
		return true
	var dur = LOCK_T + LOCK_ADD * (int(s["n"]) - 1)
	s["end"] = Game.now() + dur
	t.set_meta("fuin_until", Game.now() + dur)   # PlayerCombat ve Enemy Kuchiyose'yi buradan keser
	_knot_check(s)
	return false


## Etiketler birleşti: yazı arkada düğümlenir
static func _knot_check(s: Dictionary) -> void:
	if bool(s["knotted"]) or int(s["n"]) < 3:
		return
	s["knotted"] = true
	var t = s["t"]
	if t.has_method("apply_status"):
		t.apply_status("bind", 2.0)
		t.apply_status("sealed", 4.0)
	var a = float(s["a0"]) + PI
	var b = MB.new()
	b.add("torus", Vector3.ZERO, Vector3(0.14, 0.14, 0.14), Color(0.05, 0.04, 0.05), Vector3(90, 0, 0), 10)
	b.add("box", Vector3.ZERO, Vector3(0.16, 0.03, 0.01), Color(0.05, 0.04, 0.05), Vector3(0, 0, 40))
	b.add("box", Vector3.ZERO, Vector3(0.16, 0.03, 0.01), Color(0.05, 0.04, 0.05), Vector3(0, 0, -40))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	(s["root"] as Node3D).add_child(mi)
	mi.position = Vector3(sin(a), 0, cos(a)) * (float(s["r"]) + 0.04) + Vector3.UP * Yk.height_of(t) * 0.58
	mi.rotation.y = a


## Yapay zekâ: hedef çağrılmış bir yaratıksa ya da yakınında çağrısı dolaşıyorsa
static func ai_wants(e: Node3D) -> bool:
	var tg = e.target
	if tg is Summon or tg is ClanConstruct:
		return true
	for f in Kit.fighters():
		if f is Summon and f.get("owner_f") == tg and not f.is_dead():
			return true
	return false
