extends RefCounted
## Sekka Kote (taşlaştırma eldiveni; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/sekka_kote_fx.gd). Kanon (Narutopedia "Petrification Gauntlet", Ishidate, Hilal Krallığı filmi):
## eldivendeki göz açılır, dokunulan beden kimyasalla taşa döner; ne kadar uzun tutulursa o kadar çok yer taşlaşır; taşlaşan yer kırılgandır, parçalanabilir. İkinci güç: taşları uzaktan kaldırır, küçültüp yağdırır.
## Görünüş refs/sekka_kote: mor eldiven, el sırtında dikey göz bebekli sarı göz; taşlaşan kolda pembe parlayan çatlaklar.
## Oyunda: dokunuşlar birikir (3'te beden taşlaşır: bağ + gri ten + kırılgan). Bitiriş kırılganı parçalar. Birikim 6 sn'de söner. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const ID := "sekka_kote"
const KEEP := 6.0
const STONE_T := 1.8
const BRITTLE_T := 3.5

const VEIN_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.95, 0.55, 0.9);
	ALPHA = smoothstep(0.2, 0.8, v) * fade_k;
}
"""


static func model(b: MB) -> void:
	var p = Color(0.3, 0.24, 0.42)
	var d = Color(0.18, 0.14, 0.26)
	LazyFx.g("Loft").tube(b, [Vector3(0, 0, -0.13), Vector3(0, 0, 0.02), Vector3(0, 0, 0.15), Vector3(0, 0, 0.27)], [0.058, 0.062, 0.072, 0.05], p, 12, 2)
	b.add("cyl", Vector3(0, 0, -0.12), Vector3(0.13, 0.03, 0.13), d, Vector3(90, 0, 0), 12)
	var c = Vector3(0.07, 0, 0.17)
	b.add("cyl", c, Vector3(0.1, 0.012, 0.1), d, Vector3(0, 0, 90), 14)
	b.add("cyl", c + Vector3(0.006, 0, 0), Vector3(0.08, 0.008, 0.08), Color(0.95, 0.72, 0.12), Vector3(0, 0, 90), 14)
	b.add("box", c + Vector3(0.012, 0, 0), Vector3(0.002, 0.012, 0.06), Color(0.04, 0.03, 0.03), Vector3(90, 0, 0))
	for k in 6:
		var a = k * TAU / 6.0
		b.add("box", c + Vector3(0.004, sin(a) * 0.058, cos(a) * 0.058), Vector3(0.006, 0.012, 0.02), Color(0.62, 0.58, 0.68), Vector3(-rad_to_deg(a), 0, 0))


## Göz kapağı: dokunuşta açılır
static func attach(node: Node3D) -> void:
	var m = MeshInstance3D.new()
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.086, 0.01, 0.086), Color(0.3, 0.24, 0.42), Vector3(0, 0, 90), 14)
	m.mesh = b.build(LazyFx.g("Props").toon())
	m.position = Vector3(0.083, 0, 0.17)
	node.add_child(m)
	node.set_meta("sk_lid", m)


static func _eye(who: Node3D, open: bool) -> void:
	var n = Yk.node_of(who, ID)
	if n == null or not n.has_meta("sk_lid"):
		return
	var l: Node3D = n.get_meta("sk_lid")
	if is_instance_valid(l):
		l.create_tween().tween_property(l, "scale", Vector3(1, 1, 0.02) if open else Vector3.ONE, 0.08)


static func _veins(t: Node3D) -> void:
	var c: Vector3 = U.chest(t)
	var m = Yk.mat("sekka_catlak", VEIN_SH)
	for b in ["LeftHand", "RightHand", "LeftFoot", "RightFoot", "Head"]:
		var e: Vector3 = U.bone_pos(t, b)
		var pts = []
		for k in 7:
			pts.append(c.lerp(e, k / 6.0) + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)))
		Yk.fade(Yk.strip(pts, 0.012, m, 0.0), 0.35, 0.3)


static func _stone_skin(t: Node3D, dur: float) -> void:
	var m = t.get("model")
	if m == null or not m is CharacterModel:
		return
	var r: Color = m._skin_ratio()
	var mats = []
	for sm in m.materials:
		if sm is ShaderMaterial:
			var v = sm.get_shader_parameter("tint")
			if v != null and v is Color and v == r:
				mats.append(sm)
				sm.set_shader_parameter("tint", Color(0.5, 0.48, 0.5))
	t.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(m):
			for sm in mats:
				sm.set_shader_parameter("tint", m._skin_ratio()))


static func petrify(t: Node3D, n_add: int) -> void:
	if not t.has_method("apply_status"):
		return
	var now = Game.now()
	var n = (int(t.get_meta("sk_n", 0)) if now < float(t.get_meta("sk_u", 0.0)) else 0) + n_add
	t.set_meta("sk_u", now + KEEP)
	_veins(t)
	if n >= 3:
		n = 0
		t.apply_status("bind", STONE_T)
		t.set_meta("sk_kirik", now + BRITTLE_T)
		_stone_skin(t, BRITTLE_T)
		Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Taşlaştı!", Color(0.8, 0.76, 0.8))
		Sfx.play("earth", t.global_position, 1.5, 0.7)
	else:
		t.apply_status("slow", 1.5 * n)
	t.set_meta("sk_n", n)


static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if i <= 2:
		_eye(who, true)
		Yk.after(who, 0.5, func():
			_eye(who, false))
		petrify(h, 2 if i == 2 else 1)


static func _rock() -> Mesh:
	return Yk.mesh("sekka_kaya", func():
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, Color(0.4, 0.38, 0.4), Vector3.ZERO, 2)
		return b.build(LazyFx.g("Props").toon()))


static func _fly(who: Node3D, from: Vector3, to: Vector3, s: float, delay: float, t: float, info: Dictionary, r: float) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _rock()
	Yk.root().add_child(mi)
	mi.global_position = from
	mi.scale = Vector3.ONE * s
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "global_position", to, t)
	tw.tween_callback(func():
		if is_instance_valid(who):
			Combat.hit_sphere(who, to, r, info)
		Sfx.play("earth", to, 1.3, 0.35)
		mi.queue_free())


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim: Vector3 = U.aim_at(who, tg)
	U.face(who, aim)
	var f = Yk.face(who)
	match i:
		3:
			var g: Vector3 = Yk.gp(who.global_position + f * 1.4)
			var up = g + Vector3.UP * 2.2
			var mi = MeshInstance3D.new()
			mi.mesh = _rock()
			Yk.root().add_child(mi)
			mi.global_position = g
			mi.scale = Vector3.ONE * 0.9
			var tw = mi.create_tween()
			tw.tween_property(mi, "global_position", up, 0.2)
			tw.tween_callback(mi.queue_free)
			_fly(who, up, aim, 0.9, 0.2, 0.22, {"dmg": dmg * 1.0, "knock": 8.0, "kind": "heavy", "hitstop": 0.05, "melee": false}, 1.6)
			Sfx.play("earth", g, 0.8, 0.8)
		4:
			for k in 9:
				var q = aim + Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2))
				_fly(who, q + Vector3.UP * 6.0, q - Vector3.UP * 0.4, randf_range(0.14, 0.26), k * 0.06, 0.26, {"dmg": dmg * 0.16, "knock": 0.8, "kind": "light", "hitstop": 0.0, "melee": false}, 0.9)
		5:
			var t = Combat.nearest_enemy(who, 3.4, f, 0.2)
			if t != null and Game.now() < float(t.get_meta("sk_kirik", 0.0)):
				t.set_meta("sk_kirik", 0.0)
				t.take_hit({"dmg": dmg * 2.2, "knock": 7.0, "kind": "heavy", "attacker": who, "dir": f, "hitstop": 0.1, "pierce_guard": true})
				Combat.popup_text(t.global_position + Vector3.UP * 2.4, "Parçalandı!", Color(0.95, 0.6, 0.85))
				Yk.shake(who, 0.4)
