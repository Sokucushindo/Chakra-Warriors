extends RefCounted
## Naitosōdo: model, uzayan ağız ve chakra kesiği (hedef: res://scripts/combat/fx/naitosodo_fx.gd). Kanon: Temujin'in Avrupa tipi kısa kılıcı; ağzı boğumlarından uzayıp tam boy geniş kılıç olur, enerji akıtılınca menzili büyür.
## Kanonda enerji Gelel taşından gelir; taş oyunda yok, kullanıcının chakrası harcanır (uyarlama). Ref: altın kanatlı siper, kırmızı taş, burgulu sap, topuz. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const ID := "naitosodo"
const COST := 0.12

const WAVE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float s = 0.5 + 0.5 * sin(UV.x * 26.0 + UV.y * 5.0 - TIME * 12.0);
	ALBEDO = mix(vec3(0.2, 0.72, 0.58), vec3(0.88, 1.0, 0.94), smoothstep(0.35, 0.95, e * (0.7 + 0.3 * s)));
	ALPHA = smoothstep(0.0, 0.5, e) * smoothstep(0.0, 0.1, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x)) * fade_k * 0.85;
}
"""


## Kabza 0, ağız +Z, keskin yüzler ±Y (kılıç gibi ince eksen X)
static func model(b: MB, id: String) -> void:
	var steel = Color(0.8, 0.82, 0.85)
	var dk = Color(0.58, 0.6, 0.65)
	var gold = Color(0.76, 0.68, 0.42)
	var L = 1.28 if id == "naitosodo_uzun" else 0.56
	b.add("box", Vector3(0, 0, 0.09 + L * 0.5), Vector3(0.018, 0.085, L), steel)
	b.add("box", Vector3(0.0105, 0, 0.09 + L * 0.5), Vector3(0.003, 0.018, L), dk)
	b.add("cone", Vector3(0, 0, 0.09 + L + 0.05), Vector3(0.018, 0.1, 0.085), steel, Vector3(90, 0, 0), 4)
	if id == "naitosodo_uzun":
		for k in 3:   # uzama boğumları
			b.add("box", Vector3(0, 0, 0.45 + k * 0.32), Vector3(0.021, 0.09, 0.006), dk.darkened(0.25))
	b.add("box", Vector3(0, 0, 0.05), Vector3(0.05, 0.1, 0.07), gold)
	for s in [-1.0, 1.0]:
		b.add("box", Vector3(0, 0.1 * s, 0.05), Vector3(0.03, 0.12, 0.05), gold, Vector3(-22 * s, 0, 0))
		b.add("box", Vector3(0, 0.165 * s, 0.09), Vector3(0.024, 0.05, 0.07), gold.darkened(0.12), Vector3(-40 * s, 0, 0))
	for s in [-1.0, 1.0]:
		b.add("sphere", Vector3(0.026 * s, 0, 0.05), Vector3(0.012, 0.05, 0.04), Color(0.76, 0.1, 0.1), Vector3.ZERO, 8)
	b.add("cyl", Vector3(0, 0, -0.08), Vector3(0.036, 0.18, 0.036), Color(0.3, 0.22, 0.15), Vector3(90, 0, 0), 8)
	for k in 4:
		b.add("cyl", Vector3(0, 0, -0.145 + k * 0.042), Vector3(0.042, 0.012, 0.042), Color(0.2, 0.14, 0.09), Vector3(82, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, -0.19), Vector3(0.05, 0.05, 0.05), gold, Vector3.ZERO, 8)


static func _form(who: Node3D, long_b: bool) -> void:
	var n = Yk.node_of(who, ID)
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("naitosodo_uzun" if long_b else ID)
		Sfx.play("clink", who.global_position + Vector3.UP * 1.2, 1.5 if long_b else 1.2, 0.45)


static func _set_len(who: Node3D, delay: float, long_b: bool) -> void:
	Yk.after(who, delay, _form.bind(who, long_b))


## Geniş chakra kesiği: art arda üç ince yay, sıra sıra vurur
static func _wave(who: Node3D, dmg: float) -> void:
	var f = Yk.face(who)
	var side = f.cross(Vector3.UP).normalized()
	var c = who.global_position + Vector3.UP * 1.15
	var done: Array = []
	var m = Yk.mat("naito_wave", WAVE_SH)
	for s in 3:
		var r = 4.0 + s * 1.5
		var pts = []
		for k in 21:
			var a = lerpf(-1.05, 1.05, k / 20.0)
			pts.append(c + (f * cos(a) + side * sin(a)) * r + Vector3.UP * (a * -0.55 + s * 0.14))
		Yk.fade(Yk.strip(pts, 0.34 - s * 0.05, m, 0.0), 0.08 + s * 0.04, 0.26)
	for k in 7:
		var a = lerpf(-1.0, 1.0, k / 6.0)
		for r in [3.2, 5.6]:
			var hits = Combat.hit_sphere(who, c + (f * cos(a) + side * sin(a)) * r, 1.5, {"dmg": dmg * 1.5, "knock": 9.0, "kind": "heavy", "hitstop": 0.08, "melee": true}, done)
			done.append_array(hits)
	Sfx.play("chakra", c, 0.8, 0.8)
	Sfx.play("swing_sword", c, 0.7, 1.0)
	Yk.shake(who, 0.4)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	if i == 0:
		_form(who, false)
	elif i == 2:
		_set_len(who, 0.2, true)
	elif i == 4:
		_set_len(who, 0.05, false)
	elif i == 5:
		_set_len(who, 0.25, true)
		_set_len(who, 1.2, false)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i == 4:
		Sfx.play("hit_heavy", who.global_position + Vector3.UP * 1.4, 1.3, 0.6)
	elif i == 5:
		if Yk.pay(who, COST):
			_wave(who, dmg)
		else:
			var f = Yk.face(who)
			Combat.hit_sphere(who, who.global_position + Vector3.UP * 1.1 + f * 1.9, 1.7, {"dmg": dmg * 1.1, "knock": 7.0, "kind": "heavy", "hitstop": 0.07, "melee": true})
