extends RefCounted
## Sōha Kote (çift bıçaklı kolluk; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/soha_kote_fx.gd). Kanon (Narutopedia "Double Bladed Bracers", Shippūden 398):
## iki keskin ağızlı metal kolluk; yakın dövüşte kesilir, savunurken de vurana zarar verir. Görünüş refs/soha_kote: açık gri, kol boyunca uzanan iki ağız, parlama.
## Oyunda: blok tutarken yakın dövüşle vuran kesilir (hasar indirimi yok; blok kuralı aynen). 3. adımdaki Uke Nagashi anında bu kesik iki kat ve vuranı sendeletir. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "soha_kote"
const BACK_K := 0.32
const PARRY_K := 0.75
const PARRY_T := 0.55
const GAP := 0.25

const CUT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	if (v < 0.35 + 0.45 * abs(UV.x * 2.0 - 1.0)) discard;
	ALBEDO = vec3(0.93, 0.95, 0.98);
	ALPHA = fade_k;
}
"""


## Ön kol ekseni +Z, kolun dışı +X
static func model(b: MB) -> void:
	var plate = Color(0.78, 0.79, 0.81)
	var dark = Color(0.3, 0.3, 0.32)
	LazyFx.g("Loft").tube(b, [Vector3(0, 0, -0.13), Vector3(0, 0, 0.0), Vector3(0, 0, 0.12)], [0.062, 0.066, 0.052], plate, 14, 2)
	for z in [-0.12, 0.11]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.138 if z < 0.0 else 0.112, 0.016, 0.138 if z < 0.0 else 0.112), dark, Vector3(90, 0, 0), 14)
	var o := PackedVector2Array([Vector2(0.0, -0.15), Vector2(0.03, -0.1), Vector2(0.06, 0.03), Vector2(0.05, 0.15), Vector2(0.0, 0.25)])
	var thin = func(p: Vector2) -> float:
		return lerpf(0.016, 0.002, clampf(p.x / 0.06, 0.0, 1.0))
	for a in [-0.5, 0.5]:   # kolun dış yüzünde iki ağız
		var n = Vector3(cos(a), sin(a), 0)
		var t = Vector3(-sin(a), cos(a), 0)
		b.add_slab(o, 0.012, Color(0.9, 0.91, 0.94), Transform3D(Basis(-t, n, Vector3.BACK), n * 0.058), thin, dark)


## Sol kolda ağızlar yine dışa baksın
static func attach(node: Node3D, side: String) -> void:
	if side == "Left":
		node.rotation.z = PI


static func _guarding(who: Node3D) -> bool:
	if Game.now() < float(who.get_meta("soha_uke", 0.0)):
		return true   # Uke Nagashi adımı
	if who is Player:
		return who.combat != null and str(who.combat.action) == "guard"
	return bool(who.get("guarding"))


static func _worn(who: Node3D) -> bool:
	return Yk.node_of(who, ID) != null


static func _cut(c: Vector3, f: Vector3, s: Vector3, r: float) -> void:
	var pts = []
	for k in 7:
		var u = k / 6.0 * 2.0 - 1.0
		pts.append(c + f * (r * (1.0 - u * u * 0.5)) + s * u * r * 0.8 + Vector3.UP * u * 0.2)
	Yk.fade(Yk.strip(pts, 0.06, Yk.mat("soha_kesik", CUT_SH), 0.0), 0.03, 0.11)


## take_hit başı (Player ve Enemy): korunurken önden gelen yakın dövüş darbesi vurana döner. Darbenin kendisine dokunmaz.
static func on_guarded(who: Node3D, info: Dictionary) -> void:
	if not info.get("melee", false) or not _guarding(who) or not _worn(who):
		return
	var a = info.get("attacker")
	if a == null or not is_instance_valid(a) or a == who or not Combat.hostile(who, a) or a.is_dead():
		return
	var v: Vector3 = a.global_position - who.global_position
	v.y = 0.0
	if v.length() > 3.6 or Yk.face(who).dot(v.normalized()) < 0.1 or Game.now() < float(who.get_meta("soha_cd", 0.0)):
		return
	who.set_meta("soha_cd", Game.now() + GAP)
	var parry = Game.now() < float(who.get_meta("soha_uke", 0.0))
	var d = maxf(3.0, float(info.get("dmg", 5.0)) * (PARRY_K if parry else BACK_K))
	var hit = {"dmg": d, "knock": 3.0 if parry else 1.0, "kind": "light", "attacker": who, "dir": v.normalized(), "hitstop": 0.03, "melee": false, "bleed": 2.0}
	if parry:
		hit["stun"] = 0.45
	a.take_hit(hit)
	var s = Vector3.UP.cross(v.normalized()).normalized()
	_cut(who.global_position + Vector3.UP * 1.25, v.normalized(), s, 0.8)
	Sfx.play("clink", who.global_position + Vector3.UP * 1.2, 1.5 if parry else 1.25, 0.7)


static func start(who: Node3D, i: int) -> void:
	if i == 2 and who != null and is_instance_valid(who):
		who.set_meta("soha_uke", Game.now() + PARRY_T)


static func strike(who: Node3D, i: int, _dmg: float) -> void:
	var f = Yk.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var c: Vector3 = who.global_position + Vector3.UP * 1.25
	match i:
		0:
			_cut(c, f, s, 1.1)
		1:
			_cut(c, f, -s, 1.1)
		3:
			_cut(c, f, s + Vector3.UP * 0.4, 1.2)
			_cut(c, f, -s + Vector3.UP * 0.4, 1.2)
		4:
			_cut(c, f, Vector3.UP, 1.1)
		5:
			_cut(c, f, s, 1.5)
			_cut(c + Vector3.UP * 0.12, f, -s, 1.5)
			Sfx.play("swing_sword", c, 1.1, 0.7)
