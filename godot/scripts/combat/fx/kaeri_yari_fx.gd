extends RefCounted
## Kaeri Yari: üç parçalı teleskopik model ve Jashin bağı — kendi şekli ve gölgelendiricisi.
## Kaynak refs/kaeri_yari/retractable_pike.png: kara, köşeli, iç içe üç boğum, sivri uç, üstünde kan izi.
## Kanon: kısa silindir bir anda tam boya uzar; Hidan ayinde kendine saplar, tırpansız kalınca dövüşte de kullanır; pelerininde en az iki tane saklar.
## TEK KAYNAK: Jashin tarzının elindeki mızrak (hand_spike) ve Kaeri Yari jutsusunun attığı mızrak (flying) da bu modeldir.
## Ayin KeyedCombos._jashin_draw / _jashin_self ile yürür; kan işareti tarzla aynı ("jashin_kan"). Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "kaeri_yari"
const KEYED_PATH := "res://scripts/combat/keyed_combos.gd"
const SEG2_IN := 0.38
const SEG3_IN := 0.85

const BLOOD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float rag = 0.5 + 0.5 * sin(UV.x * 31.0 + sin(UV.x * 7.0) * 2.0);
	float m = smoothstep(0.1 + 0.3 * rag * UV.x, 0.5, v);
	ALBEDO = mix(vec3(0.22, 0.02, 0.03), vec3(0.5, 0.05, 0.06), v);
	ALPHA = m * fade_k * (1.0 - UV.x * 0.5);
	if (ALPHA < 0.02) discard;
}
"""

const BLACK := Color(0.11, 0.11, 0.13)
const SHEEN := Color(0.2, 0.2, 0.23)


# ------------------------------------------------------------------ model
static func _seg(b: MB, z0: float, z1: float, r0: float, r1: float) -> void:
	Loft.tube(b, [Vector3(0, 0, z0), Vector3(0, 0, z1)], [r0, r1], BLACK, 8, 1)
	b.add("box", Vector3(r0 * 0.7, 0, (z0 + z1) * 0.5), Vector3(0.004, 0.006, (z1 - z0) * 0.86), SHEEN)


static func model_base(b: MB) -> void:
	Loft.tube(b, [Vector3(0, 0, -0.13), Vector3(0, 0, 0.08)], [0.03, 0.036], Color(0.07, 0.07, 0.08), 8, 1)
	_seg(b, 0.08, 0.5, 0.05, 0.04)
	b.add("cyl", Vector3(0, 0, 0.5), Vector3(0.09, 0.012, 0.09), SHEEN, Vector3(90, 0, 0), 8)


static func model_2(b: MB) -> void:
	_seg(b, 0.5, 0.95, 0.034, 0.025)
	b.add("cyl", Vector3(0, 0, 0.95), Vector3(0.058, 0.01, 0.058), SHEEN, Vector3(90, 0, 0), 8)


static func model_3(b: MB) -> void:
	Loft.tube(b, [Vector3(0, 0, 0.95), Vector3(0, 0, 1.46)], [0.021, 0.001], BLACK, 8, 1)


## Tam açık hâl (küçük resim, jutsu mermisi)
static func model(b: MB) -> void:
	model_base(b)
	model_2(b)
	model_3(b)


## Parçalı kurulum: eldeki silah ve Jashin tarzının mızrağı aynı (toplu başlar)
static func rig(node: MeshInstance3D) -> void:
	node.mesh = CharacterModel.weapon_mesh("kaeri_yari_kok")
	var s2 = MeshInstance3D.new()
	s2.mesh = CharacterModel.weapon_mesh("kaeri_yari_2")
	var s3 = MeshInstance3D.new()
	s3.mesh = CharacterModel.weapon_mesh("kaeri_yari_3")
	node.add_child(s2)
	node.add_child(s3)
	node.set_meta("ky_segs", [s2, s3])
	_set_k(node, 0.0)


static func attach(node: Node3D) -> void:
	if node is MeshInstance3D:
		rig(node)


static func _set_k(n: Node3D, k: float) -> void:
	var sg: Array = n.get_meta("ky_segs", [])
	if sg.size() < 2 or not is_instance_valid(sg[0]) or not is_instance_valid(sg[1]):
		return
	(sg[0] as Node3D).position.z = -(1.0 - k) * SEG2_IN
	(sg[1] as Node3D).position.z = -(1.0 - k) * SEG3_IN


static func _slide(n: Node3D, to: float, t: float) -> void:
	if n == null or not is_instance_valid(n) or not n.has_meta("ky_segs"):
		return
	var from = float(n.get_meta("ky_k", 0.0))
	n.set_meta("ky_k", to)
	n.create_tween().tween_method(func(k: float):
		if is_instance_valid(n):
			_set_k(n, k), from, to, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Jashin tarzının elindeki mızrak (KeyedCombos._jashin_spike buraya gelir)
static func hand_spike(who: Node3D, dur: float) -> void:
	var ba = PathJutsu.get_pinst().bone_attach(who, "RightHand")
	if ba == null:
		return
	var n = MeshInstance3D.new()
	rig(n)
	n.rotation.x = -PI * 0.5   # +Z (uç) kemiğin +Y yönüne
	n.position = Vector3(0, 0.02, 0.02)
	ba.add_child(n)
	_slide(n, 1.0, 0.1)
	who.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(ba):
			ba.queue_free())


## Kaeri Yari jutsusunun mermisi: uç uçuş yönüne (-Z)
static func flying() -> Node3D:
	var h = Node3D.new()
	var m = MeshInstance3D.new()
	m.mesh = CharacterModel.weapon_mesh(ID)
	m.rotation.y = PI
	m.position.z = 0.7
	h.add_child(m)
	return h


# ------------------------------------------------------------------ ayin
## Kanon: ayin Jashin inancı ister (oyuncu: Jashin yolunda Kaeri Yari'yi öğrenmiş; düşman: tekniği listesinde)
static func devout(who: Node3D) -> bool:
	if who is Player:
		return "jashin_kazik" in (Game.profile.get("learned", []) as Array)
	var a = who.get("arch")
	return a is Dictionary and "jashin_kazik" in (a.get("jutsu", []) as Array)


static func _blood(who: Node3D, f: Vector3, reach: float) -> void:
	var a: Vector3 = Kit.hand(who)
	var s = Vector3.UP.cross(f).normalized()
	var pts = []
	for k in 8:
		var u = k / 7.0
		pts.append(a + f * reach * u + s * sin(u * 5.0) * 0.07 + Vector3.DOWN * u * u * 0.12)
	Kit.fade(Kit.strip(pts, 0.05, Kit.mat("ky_kan", BLOOD_SH), 0.7), 0.06, 0.2)


static func _front(who: Node3D, dmg: float, mul: float, reach: float) -> void:
	var f = Kit.face(who)
	for h in Combat.hit_zone(who, who.global_position, f, reach, 22.0, 2.2, {"dmg": dmg * mul, "knock": 3.0, "kind": "heavy", "melee": true, "bleed": 2.5, "hitstop": 0.05}):
		h.set_meta("jashin_kan", Time.get_ticks_msec())
	_blood(who, f, reach * 0.8)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var n = Kit.node_of(who, ID)
	if i == 3:
		_slide(n, 0.0, 0.1)   # çember çizilirken toplu
		return
	_slide(n, 1.0, 0.08)
	Sfx.play("clink", who.global_position, 1.6, 0.4)
	who.set_meta("ky_t", Game.now() + 1.2)
	Kit.after(who, 1.3, func():
		if Game.now() >= float(who.get_meta("ky_t", 0.0)):
			_slide(Kit.node_of(who, ID), 0.0, 0.14))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var K = load(KEYED_PATH)
	var pious = devout(who)
	match i:
		0, 1, 2:
			_blood(who, Kit.face(who), 1.5)
			Sfx.play("throw_kunai", who.global_position, 0.8, 0.6)
		3:
			if pious:
				K._jashin_draw(who)
			else:
				Combat.popup_text(who.global_position + Vector3.UP * 2.4, "İnanç yok...", Color(0.7, 0.6, 0.6))
		4:
			if not (pious and K._jashin_self(who, dmg, 1.4, 0.03, "Bacağa!")):
				_front(who, dmg, 0.8, 2.6)
		5:
			if not (pious and K._jashin_self(who, dmg, 3.2, 0.06, "Jashin-sama!")):
				_front(who, dmg, 1.5, 3.2)
				Kit.shake(who, 0.3)


## Mızrağın aldığı kan tarzın ayininde de geçerli
static func on_hit(_who: Node3D, _i: int, h: Node3D) -> void:
	h.set_meta("jashin_kan", Time.get_ticks_msec())
