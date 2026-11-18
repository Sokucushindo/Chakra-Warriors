extends RefCounted
## Kurosawa (黒澤; hedef: res://scripts/combat/fx/kurosawa_fx.gd). Kanon (Narutopedia "Kurosawa", "Iai Beheading", "Mifune"; manga 516, 531):
## Mifune'nin ünlü kılıcı (meitō): uzun ince kavisli ağız, dikdörtgen tsuba, sargılı uzun kabza. Iaidō: bir anda çek, kes, hemen kına sok.
## Iaigiri Ibuse'nin dev başını yardı: büyük hedefe etkili. Mifune karşı koyuşlarıyla bilinir (Hanzō). Efsane: satılmaz, sahibi var.
## Ref refs/kurosawa/Kurosawa.png. Kesik: ince beyaz çizgi; kesik görünür, darbe kılıç kına girerken oturur.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/kurosawa_anim.gd")

const UKE_START := 0.1
const UKE_END := 0.62
const CHAKRA := 0.05       # bitiriş: ağza akan chakra
const BIG_H := 3.2         # bu boydan büyük hedef: Ibuse kuralı
const BIG_MUL := 1.6

const CUT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade_k = 1.0;
void fragment() {
	float x = UV.x;
	float w = 0.5 * sin(3.14159 * pow(x, 0.7)) * (0.35 + 0.65 * fade_k);
	float d = abs(UV.y - 0.5);
	if (d > w) discard;
	ALBEDO = mix(vec3(0.72, 0.84, 1.0), vec3(1.0), 1.0 - d / max(w, 0.001)) * 1.8;
	ALPHA = fade_k;
}
"""


static func build(b: MB) -> void:
	var steel = Color(0.86, 0.87, 0.89)
	var gold = Color(0.82, 0.68, 0.34)
	var teal = Color(0.16, 0.42, 0.46)
	CharacterModel._w_tsuka(b, -0.31, 0.06, 0.018, Color(0.8, 0.79, 0.75))
	CharacterModel._w_blade(b, 0.085, 1.04, 0.034, 0.14, steel)
	b.add("box", Vector3(0, 0, 0.072), Vector3(0.062, 0.088, 0.008), gold)      # dikdörtgen tsuba
	b.add("box", Vector3(0, 0, 0.072), Vector3(0.05, 0.076, 0.0095), teal)
	b.add("box", Vector3(0, 0, 0.072), Vector3(0.016, 0.03, 0.011), gold.darkened(0.25))
	b.add("cyl", Vector3(0, 0, -0.315), Vector3(0.04, 0.018, 0.04), gold, Vector3(90, 0, 0), 10)


static func _entry(who: Node3D) -> Dictionary:
	var m = who.get("model")
	if m == null or m.get("weapons") == null:
		return {}
	for w in m.weapons:
		if String(w["id"]) == "kurosawa" and is_instance_valid(w["node"]):
			return w
	return {}


## Kındaki kopya: kılıç elde gizliyken kabza kından görünür
static func _kin(w: Dictionary) -> MeshInstance3D:
	var h = w.get("sheath")
	if h == null or not is_instance_valid(h):
		return null
	var k = h.get_node_or_null("KuroKin")
	if k == null:
		k = MeshInstance3D.new()
		k.name = "KuroKin"
		k.mesh = CharacterModel.weapon_mesh("kurosawa")
		k.visible = false
		h.add_child(k)
	return k


static func _state(who: Node3D, in_saya: bool) -> void:
	var w = _entry(who)
	if w.is_empty() or not who.model.drawn:
		return
	(w["node"] as Node3D).visible = not in_saya
	var k = _kin(w)
	if k != null:
		k.visible = in_saya


static func _later(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(maxf(t, 0.01)).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


# ------------------------------------------------------------------ görsel
static func _arc(c: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, life := 0.24) -> void:
	var nax = a.cross(b).normalized()
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 28
	for i in n + 1:
		var k = float(i) / n
		var ang = lerpf(a0, a1, k)
		var dir = (a * cos(ang) + b * sin(ang)).normalized()
		var across = (dir * 0.5 + nax * 0.5).normalized() * w * 0.5
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(c + dir * r - across)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(c + dir * r + across)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("kuro_kesik", CUT_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	Kit.tween_param(mi, "fade_k", 1.0, 0.0, life, true)


static func _line(from: Vector3, to: Vector3, w: float, life: float) -> void:
	var d = to - from
	var f = d.normalized()
	var side = Vector3.UP.cross(f).normalized()
	for up in [Vector3.UP, side]:
		var mi = Kit.quad(Kit.scene(), 1.0, Kit.shader_mat("kuro_kesik", CUT_SH))
		var y: Vector3 = (up - f * f.dot(up)).normalized()
		mi.global_transform = Transform3D(Basis(f * d.length(), y * w, f.cross(y)), (from + to) * 0.5)
		Kit.tween_param(mi, "fade_k", 1.0, 0.0, life, true)


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position + Vector3.UP * 1.15]


static func _noto_click(who: Node3D) -> void:
	Sfx.play("clink", who.global_position + Vector3.UP, 1.75, 0.4)


# ------------------------------------------------------------------ karşı koyma
## Combat.speed_dodge başından çağrılır (oyuncu ve düşman): duruştayken önden gelen yakın darbe boşa gider, kılıç çıkar
static func parry(t: Node3D, info: Dictionary) -> bool:
	if Game.now() >= float(t.get_meta("kuro_uke", 0.0)) or not info.get("melee", false) or info.get("sure", false):
		return false
	var atk = info.get("attacker")
	if atk == null or not is_instance_valid(atk) or not (atk is Node3D) or not t.has_method("face_dir"):
		return false
	var to: Vector3 = atk.global_position - t.global_position
	to.y = 0.0
	if to.length() > 0.05 and t.face_dir().dot(to.normalized()) < 0.1:
		return false
	t.remove_meta("kuro_uke")
	U.face(t, atk.global_position)
	_state(t, false)
	var ax = _axes(t)
	_arc(ax[2], ax[0], ax[1], 1.7, -0.9, 0.9, 0.09)
	Sfx.play("clash", t.global_position + Vector3.UP, 1.35, 0.7)
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Karşılandı", Color(0.85, 0.92, 1.0))
	var w: Dictionary = Gear.weapon_of(t)
	var mul = Stats.melee_mult(Game.profile) if t is Player else float(t.get("power")) if t.get("power") != null else 1.0
	var dmg = float(w.get("hit", 6.0)) * mul * 1.7
	_later(t, 0.08, func():
		if U.alive(atk):
			Combat.hit_sphere(t, U.chest(atk), 1.1, {"dmg": dmg, "knock": 6.0, "stun": 0.6, "kind": "heavy", "hitstop": 0.08, "melee": true, "blade": true}))
	_later(t, 0.34, func():
		_state(t, true)
		_noto_click(t))
	return true


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var k = clampi(i, 0, 5)
	var tok = int(who.get_meta("kuro_tok", 0)) + 1
	who.set_meta("kuro_tok", tok)
	_state(who, true)
	var live = func() -> bool:
		return int(who.get_meta("kuro_tok", 0)) == tok
	_later(who, float(A.HIT[k]) - 0.05, func():
		if live.call():
			_state(who, false)
			Sfx.play("whoosh", who.global_position + Vector3.UP, 1.9, 0.4))
	_later(who, float(A.NOTO[k]), func():
		if live.call():
			_state(who, true)
			_noto_click(who))
	var ln = float(A.steps()[k]["len"])
	_later(who, ln + 0.12, func():   # kombo sürmediyse kılıç ele döner (bekleme duruşu)
		if live.call():
			_state(who, false)
			var w = _entry(who)
			if not w.is_empty():
				var kn = _kin(w)
				if kn != null:
					kn.visible = false)
	if k == 3:
		_later(who, UKE_START, func():
			who.set_meta("kuro_uke", Game.now() + UKE_END - UKE_START))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var ax = _axes(who)
	var f: Vector3 = ax[0]
	var s: Vector3 = ax[1]
	var c: Vector3 = ax[2]
	match i:
		0:
			_arc(c, f, s, 2.1, 1.1, -1.0, 0.1)
		1:
			_arc(c, (f + Vector3.UP * 0.5).normalized(), (s - Vector3.UP * 0.4).normalized(), 2.0, -1.0, 1.0, 0.1)
		2:
			_arc(c, (f - Vector3.UP * 0.3).normalized(), (Vector3.UP + s * 0.5).normalized(), 2.3, 1.2, -1.1, 0.12)
		3:   # karşılanacak darbe gelmediyse kısa kesik
			if who.has_meta("kuro_uke"):
				who.remove_meta("kuro_uke")
			_arc(c, f, s, 2.1, -1.0, 1.0, 0.1)
		4:
			_arc(c, f, s, 2.0, 1.0, -0.9, 0.09)
			_later(who, 0.14, func():
				var ax2 = _axes(who)
				_arc(ax2[2], (ax2[0] + Vector3.UP * 0.5).normalized(), (ax2[1] - Vector3.UP * 0.4).normalized(), 2.0, 1.0, -1.0, 0.1)
				Combat.hit_sphere(who, ax2[2] + ax2[0] * 1.4, 1.5, {"dmg": dmg * 0.7, "knock": 4.0, "kind": "light", "hitstop": 0.04, "melee": true, "blade": true}))
		5:
			_iaigiri(who, f, c, dmg)


## Tek uzak kesik: chakra ağza akar, çizgi önce görünür, darbe sonra oturur. Dev hedefe daha ağır.
static func _iaigiri(who: Node3D, f: Vector3, c: Vector3, dmg: float) -> void:
	var tg = U.target_of(who)
	if U.alive(tg):
		var v: Vector3 = tg.global_position - who.global_position
		v.y = 0.0
		if v.length() > 0.2 and v.normalized().dot(f) > 0.5:
			f = v.normalized()
			U.face(who, tg.global_position)
	var reach = 7.5 if U.pay(who, CHAKRA) else 3.6
	_line(c + f * 0.5, c + f * reach, 0.13, 0.42)
	if who is Player and Game.world:
		Game.world.env.add_shake(0.3)
	Sfx.play("swing_sword", c, 1.5, 0.8)
	var at: Vector3 = who.global_position
	_later(who, 0.2, func():
		for t in Kit.fighters():
			if t == who or t.is_dead() or not Combat.hostile(who, t):
				continue
			var p: Vector3 = t.global_position - at
			p.y = 0.0
			var along = p.dot(f)
			var r = float(t.get("radius")) if t.get("radius") != null else 0.4
			if along < 0.0 or along > reach + r or (p - f * along).length() > 1.0 + r:
				continue
			var big = Kit.height_of(t) >= BIG_H
			Combat.hit_sphere(who, U.chest(t), 0.6 + r, {"dmg": dmg * (BIG_MUL if big else 1.0) * 1.5, "knock": 12.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.1, "melee": true, "blade": true})
		Sfx.play("hit_sword", at + f * 2.0, 0.8, 0.8))
