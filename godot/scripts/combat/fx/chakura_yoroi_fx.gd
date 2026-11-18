extends RefCounted
## Chakura no Yoroi (チャクラの鎧; kanon film: Nadare, Fubuki, Mizore, Dotō; hedef: res://scripts/combat/fx/chakura_yoroi_fx.gd). Kristal, görünmez bariyer üretir: ninjutsu, genjutsu ve atılan aletler durur; taijutsu durmaz.
## Kural: yüzde indirim yok. Darbe ya bariyerde TAM durur (kristal yorulur) ya da geçer. Yakın dövüş hep geçer. Raiton saldırısı bariyeri deler ve kristali çatlatır (kanon: Raikiri, Chidori). Kristal biterse 12 sn bariyer yok.
## Kanon istikrarsızlık: kristali çatlayan zırh, yakındaki başka zırhın kristaline değince ikisi de patlar. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const BACK_ID := "chakura_yoroi"
const BAR := 6.0
const REGEN := 0.3
const DOWN_T := 12.0
const NEAR := 4.5

const RIP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.25, 0.65, 0.85), vec3(0.9, 1.0, 1.0), e);
	ALPHA = smoothstep(0.0, 0.7, e) * sin(UV.x * 3.14159) * fade_k;
}
"""


## Göğüs düzeneği (BackItemsExt, yerel +Z ön): yin-yang kristal yuvası, gövdeye giden koyu lacivert borular (ref Chakra_Armour.png)
static func chest_model(mb: MB) -> void:
	var grey = Color(0.58, 0.59, 0.63)
	var blue = Color(0.13, 0.28, 0.42)
	var white = Color(0.93, 0.95, 0.94)
	var teal = Color(0.15, 0.55, 0.65)
	mb.add("cyl", Vector3.ZERO, Vector3(0.17, 0.035, 0.17), grey, Vector3(90, 0, 0), 18)
	mb.add("cyl", Vector3(0, 0, 0.02), Vector3(0.125, 0.012, 0.125), white, Vector3(90, 0, 0), 18)
	mb.add("halfcyl", Vector3(0, 0, 0.027), Vector3(0.122, 0.006, 0.122), teal, Vector3(90, 0, 0), 14)
	mb.add("cyl", Vector3(0.03, 0, 0.032), Vector3(0.06, 0.004, 0.06), teal, Vector3(90, 0, 0), 12)
	mb.add("cyl", Vector3(-0.03, 0, 0.032), Vector3(0.06, 0.004, 0.06), white, Vector3(90, 0, 0), 12)
	for s in [-1.0, 1.0]:
		mb.add("box", Vector3(0.12 * s, 0.1, -0.015), Vector3(0.02, 0.2, 0.012), blue, Vector3(0, 0, -38 * s))
		mb.add("box", Vector3(0.1 * s, -0.11, -0.015), Vector3(0.02, 0.18, 0.012), blue, Vector3(0, 0, 32 * s))


static func worn(who: Node3D) -> bool:
	var m = who.get("model")
	return m != null and m.get("look") is Dictionary and str(m.look.get("back_item", "")) == BACK_ID


static func _bar(who: Node3D) -> float:
	var now = Game.now()
	var v = minf(BAR, float(who.get_meta("cy_bar", BAR)) + (now - float(who.get_meta("cy_t", now))) * REGEN)
	who.set_meta("cy_bar", v)
	who.set_meta("cy_t", now)
	return v


static func up(who: Node3D) -> bool:
	return worn(who) and Game.now() >= float(who.get_meta("cy_down", 0.0))


## Combat.cc_dur: genjutsu tutmaz
static func stops_genjutsu(n: Node) -> bool:
	return n is Node3D and up(n)


static func _ripple(c: Vector3, to: Vector3) -> void:
	var d = to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var x = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var y = x.cross(d)
	var m = Yk.mat("cy_rip", RIP_SH)
	for s in 3:
		var pts = []
		var r = 0.45 + s * 0.22
		var a0 = randf() * TAU
		for k in 11:
			var a = a0 + k / 10.0 * 2.0
			pts.append(c + (x * cos(a) + y * sin(a)) * r)
		Yk.fade(Yk.strip(pts, 0.035, m, 0.0), 0.03 * s, 0.2)


static func _crack(who: Node3D, c: Vector3) -> void:
	who.set_meta("cy_bar", 0.0)
	who.set_meta("cy_down", Game.now() + DOWN_T)
	Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kristal Çatladı!", Color(1.0, 0.65, 0.4))
	Sfx.play("clash", c, 0.6, 1.0)
	for f in who.get_tree().get_nodes_in_group("fighters"):
		if f != who and f is Node3D and f.has_method("is_dead") and not f.is_dead() and worn(f) and f.global_position.distance_to(who.global_position) <= NEAR:
			_overload(who, f)
			break


## Kanon: iki zırhın kristali birbirine değince patlar
static func _overload(a: Node3D, b: Node3D) -> void:
	for t in [a, b]:
		t.take_hit({"dmg": float(t.get("max_hp")) * 0.3 if t.get("max_hp") != null else 40.0, "knock": 9.0, "kind": "heavy", "sure": true, "hitstop": 0.1, "dir": ((t as Node3D).global_position - (a.global_position + b.global_position) * 0.5).normalized()})
	Combat.popup_text((a.global_position + b.global_position) * 0.5 + Vector3.UP * 2.4, "Kristaller Patladı!", Color(1.0, 0.55, 0.3))
	Sfx.play("boom", a.global_position, 0.8, 1.0)


## Player/Enemy.take_hit: true = bariyerde tam durdu
static func block(who: Node3D, info: Dictionary) -> bool:
	if not up(who) or info.get("sure", false):
		return false
	var thrown = info.has("tool")
	if bool(info.get("melee", false)) and not thrown:
		return false   # kanon: taijutsuya karşı korumaz
	var tier = int(info.get("tier", -1))
	var c = who.global_position + Vector3.UP * 1.2
	var dir = Vector3(info.get("dir", Vector3.ZERO))
	var bar = _bar(who)
	if str(info.get("element", "")) == "raiton" and tier >= 1:
		who.set_meta("cy_bar", bar - 3.0)
		if bar - 3.0 <= 0.0:
			_crack(who, c)
		Sfx.play("zap", c, 0.8, 0.7)
		return false
	if tier >= 5:
		_crack(who, c)
		return false
	var cost = 1.0 + maxf(0.0, float(tier))
	if bar - cost < 0.0:
		_crack(who, c)
		return false
	who.set_meta("cy_bar", bar - cost)
	_ripple(c - dir * 0.55, dir)
	Sfx.play("block", c, 1.5, 0.45)
	return true
