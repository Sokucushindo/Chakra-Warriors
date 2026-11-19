extends RefCounted
## Omori (根性 yazılı bacak ağırlıkları; kanon: Rock Lee — refs/lee_weights). Bej levhalar tozluğun altında incikte taşınır: giyiliyken
## yavaşlatır, çıkarılınca beden birden hafifler. Levhalar yere düşünce küçük bir çukur açar ve orada kalır.
## Geri takmak için yanlarına dönülür; bir süre sonra yerdekiler kaybolur, o zaman yedekler takılabilir.
## Oyuncu: Gōken Shōzoku giyiliyken [P]. Düşman: ağırlıklı tozluk giyen ninja sıkışınca aynı işlemi yapar.

const S = preload("res://scripts/combat/samehada_anim.gd")
const KEYED = preload("res://scripts/combat/keyed_combos.gd")

const WORN_SPEED := 0.75     # giyiliyken hız (Progress._weights_tick ile aynı)
const FREE_SPEED := 1.3      # çıkarılınca hız
const POSE_LEN := 0.8
const DROP_AT := 0.38
const DROP_LIFE := 90.0
const REACH := 5.0
const NPC_HP := 0.7          # düşman canı bu oranın altına inince çıkarır
const NPC_RANGE := 14.0

static var _c := {}
static var _drops := {}      # kişi kimliği -> [düğümler]

const CRATER_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float a = atan(q.y, q.x);
	float r = length(q) + 0.07 * sin(a * 7.0) + 0.04 * sin(a * 17.0 + 1.3);
	float pit = 1.0 - smoothstep(0.58, 0.68, r);
	float rim = smoothstep(0.56, 0.68, r) * (1.0 - smoothstep(0.72, 0.9, r));
	float crack = smoothstep(0.93, 1.0, abs(sin(a * 5.0 + 0.6))) * smoothstep(0.5, 0.65, r) * (1.0 - smoothstep(0.8, 0.98, r));
	ALBEDO = mix(vec3(0.42, 0.35, 0.27), vec3(0.11, 0.09, 0.07), max(pit, crack));
	ALPHA = clamp(pit * 0.85 + rim * 0.45 + crack * 0.8, 0.0, 1.0) * fade_k;
	if (ALPHA < 0.01) discard;
}
"""


static func _is_player(who: Node3D) -> bool:
	return who is Player


## Kişi ağırlık kuşanıyor mu (çıkarmış olsa da)
static func has_set(who: Node3D) -> bool:
	if _is_player(who):
		var gs: Dictionary = Gear.equipped(Game.profile, "set")
		return not gs.is_empty() and bool(Gear.item(String(gs["id"])).get("agirlik", false))
	var lk = who.get("look")
	if not (lk is Dictionary):
		return false
	return lk.get("leg_warmers") is Color or bool(Gear.item(str(lk.get("set_id", ""))).get("agirlik", false))   # elle modellenmiş Gōken: tozluk kıyafetin içinde


static func is_off(who: Node3D) -> bool:
	if _is_player(who):
		return bool(Game.profile.get("omori_off", false))
	return bool(who.get_meta("omori_off", false))


static func _set_off(who: Node3D, on: bool) -> void:
	if _is_player(who):
		Game.profile["omori_off"] = on
	else:
		who.set_meta("omori_off", on)


## İki adımlı eğilme: eller inciğe iner, levhalar çözülür, doğrulur
static func _pose() -> Dictionary:
	var arms = {"RightUpperArm": Vector3(-0.32, -0.8, 0.5), "RightLowerArm": Vector3(0.06, -0.86, 0.5),
		"LeftUpperArm": Vector3(0.32, -0.8, 0.5), "LeftLowerArm": Vector3(-0.06, -0.86, 0.5)}
	# çömelme: dizler öne, eller inciğe iner
	var sq = {"RightUpperLeg": Vector3(-0.2, -0.3, 0.93), "RightLowerLeg": Vector3(-0.05, -0.93, -0.36), "RightFoot": Vector3(-0.05, -0.3, 0.95),
		"LeftUpperLeg": Vector3(0.2, -0.3, 0.93), "LeftLowerLeg": Vector3(0.05, -0.93, -0.36), "LeftFoot": Vector3(0.05, -0.3, 0.95)}
	var rest = {"RightUpperArm": Vector3(-0.15, -0.97, 0.1), "RightLowerArm": Vector3(-0.05, -0.95, 0.25),
		"LeftUpperArm": Vector3(0.15, -0.97, 0.1), "LeftLowerArm": Vector3(0.05, -0.95, 0.25)}
	var d = Vector3(0, -1, 0.2)
	var w = S.LEG_WIDE
	return {"len": POSE_LEN, "hit": DROP_AT, "two": false, "keys": [
		S._k(0.0, 0.3, 0, 4, d, rest, w),
		S._k(0.26, 0.86, 0, 64, d, arms, sq),
		S._k(0.46, 0.88, 0, 66, d, arms, sq),
		S._k(POSE_LEN, 0.3, 0, 4, d, rest, w),
	]}


static func _play_pose(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or not (m is CharacterModel) or m.overlay == null:
		return
	m.overlay.play_keys(_pose(), 1.0)
	who.get_tree().create_timer(POSE_LEN).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())


static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


## 根 ve 性: birim karede kısa dikdörtgen vuruşlar [x0, y0, x1, y1]
const GLYPH_KON := [[0.22, 0.05, 0.22, 0.95], [0.02, 0.3, 0.42, 0.3], [0.2, 0.42, 0.02, 0.72], [0.24, 0.42, 0.42, 0.62],
	[0.55, 0.08, 0.55, 0.92], [0.55, 0.08, 0.92, 0.08], [0.92, 0.08, 0.92, 0.5], [0.55, 0.28, 0.92, 0.28], [0.55, 0.5, 0.92, 0.5], [0.62, 0.58, 0.98, 0.95]]
const GLYPH_SHO := [[0.2, 0.05, 0.2, 0.95], [0.04, 0.3, 0.08, 0.5], [0.36, 0.28, 0.32, 0.45],
	[0.5, 0.15, 0.45, 0.32], [0.48, 0.3, 0.96, 0.3], [0.72, 0.05, 0.72, 0.9], [0.52, 0.58, 0.92, 0.58], [0.44, 0.9, 0.98, 0.9]]


static func _stroke(b: MB, g: Vector2, sz: float, s: Array, ink: Color) -> void:
	var a = g + Vector2(float(s[0]), -float(s[1])) * sz
	var c = g + Vector2(float(s[2]), -float(s[3])) * sz
	var mid = (a + c) * 0.5
	var L = maxf(a.distance_to(c), 0.004)
	var ang = rad_to_deg(atan2(c.y - a.y, c.x - a.x))
	b.add("box", Vector3(mid.x, 0.0225, -mid.y), Vector3(L + 0.003, 0.002, 0.0042), ink, Vector3(0, ang, 0))


## Levha: yerel XZ yüzeyi, +Y yüz (yere yatık düşer)
static func _plate_mesh() -> ArrayMesh:
	if _c.has("mesh:plate"):
		return _c["mesh:plate"]
	var b = MB.new()
	var cream = Color(0.85, 0.83, 0.72)
	var line = Color(0.42, 0.4, 0.34)
	var ink = Color(0.07, 0.07, 0.07)
	b.add("box", Vector3.ZERO, Vector3(0.2, 0.04, 0.28), cream)
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * 0.078, 0.021, -0.122), Vector3(0.018, 0.006, 0.018), Color(0.45, 0.45, 0.5), Vector3.ZERO, 8)
	for r in 3:
		var z = -0.07 + r * 0.075
		b.add("box", Vector3(0, 0.0205, z), Vector3(0.176, 0.001, 0.064), line)
		b.add("box", Vector3(0, 0.0212, z), Vector3(0.17, 0.001, 0.058), cream)
		var sz = 0.046
		var o = Vector2(-0.062, -z + sz * 0.5)
		for s in GLYPH_KON:
			_stroke(b, o, sz, s, ink)
		for s in GLYPH_SHO:
			_stroke(b, o + Vector2(0.074, 0.0), sz, s, ink)
	var m = b.build(Props.toon())
	_c["mesh:plate"] = m
	return m


static func _crater_mat() -> ShaderMaterial:
	if not _c.has("mat:crater"):
		var s = Shader.new()
		s.code = CRATER_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["mat:crater"] = m
	return _c["mat:crater"]


static func _clear_drops(who: Node3D) -> void:
	var id = who.get_instance_id()
	for n in _drops.get(id, []):
		if is_instance_valid(n):
			n.queue_free()
	_drops.erase(id)


static func _land(p: Vector3, who: Node3D, loud: float) -> Node3D:
	var root = _root()
	if root == null:
		return null
	if not _c.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		q.orientation = PlaneMesh.FACE_Y
		_c["mesh:quad"] = q
	var mi = MeshInstance3D.new()
	mi.mesh = _c["mesh:quad"]
	mi.material_override = _crater_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = p + Vector3.UP * 0.018
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * 0.58
	root.get_tree().create_timer(DROP_LIFE).timeout.connect(mi.queue_free)
	Sfx.play("boom", p, 0.62, loud)
	Dangle.blast(p, 2.5, 2.0, 0.2)
	if is_instance_valid(who):
		KEYED._shake(who, 0.22)
	return mi


static func _drop_one(who: Node3D, bone: String, sx: float, idx: int) -> void:
	var m = who.get("model")
	var root = _root()
	if root == null or m == null or not (m is CharacterModel) or m.skel == null:
		return
	var b = m.skel.find_bone(bone)
	var from: Vector3 = who.global_position + Vector3.UP * 0.3
	if b >= 0:
		from = m.skel.global_transform * m.skel.get_bone_global_pose(b).origin + Vector3.UP * 0.12
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else Vector3.FORWARD
	var side = Vector3.UP.cross(f).normalized()
	var ground = who.global_position + side * sx * 0.3 + f * 0.18
	ground.y = who.global_position.y + 0.04
	var mi = MeshInstance3D.new()
	mi.mesh = _plate_mesh()
	root.add_child(mi)
	mi.global_position = from
	mi.rotation = Vector3(PI * 0.5, randf_range(-0.3, 0.3), 0)
	var id = who.get_instance_id()
	if not _drops.has(id):
		_drops[id] = []
	_drops[id].append(mi)
	mi.add_to_group("omori_drop")
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", ground, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "rotation", Vector3(0.0, randf() * TAU, 0.05 * sx), 0.2)
	tw.chain().tween_callback(func():
		var cr = _land(ground, who, 0.8 if idx == 0 else 0.6)
		if cr != null and _drops.has(id):
			_drops[id].append(cr))
	var tree = who.get_tree()
	tree.create_timer(DROP_LIFE).timeout.connect(func():
		if is_instance_valid(mi):
			mi.queue_free())


## Çıkar: eğilir, levhalar düşer, beden hafifler
static func release(who: Node3D) -> void:
	if not has_set(who) or is_off(who):
		return
	_set_off(who, true)
	_clear_drops(who)
	_play_pose(who)
	if _is_player(who):
		who.input_locked = maxf(float(who.input_locked), POSE_LEN)
	var tree = who.get_tree()
	tree.create_timer(DROP_AT).timeout.connect(func():
		if not is_instance_valid(who):
			return
		_drop_one(who, "LeftFoot", 1.0, 0)
		_drop_one(who, "RightFoot", -1.0, 1)
		if _is_player(who):
			Hud.msg("Omori çıktı: beden hafifledi", Color(0.75, 1.0, 0.65), 2.5)
		else:
			var a = who.get("arch")
			if a is Dictionary:
				a["speed"] = float(a.get("speed", 8.5)) / WORN_SPEED * FREE_SPEED)


## Geri tak: yerdeki levhaların yanında (ya da kaybolmuşlarsa yedekle)
static func wear(who: Node3D) -> void:
	var live: Array = (_drops.get(who.get_instance_id(), []) as Array).filter(func(n): return is_instance_valid(n) and n.is_in_group("omori_drop"))
	for n in live:
		if (n as Node3D).global_position.distance_to(who.global_position) > REACH:
			if _is_player(who):
				Hud.msg("Ağırlıklar uzakta kaldı", Color(1, 0.8, 0.5), 2.0)
			return
	_set_off(who, false)
	_clear_drops(who)
	_play_pose(who)
	if _is_player(who):
		who.input_locked = maxf(float(who.input_locked), POSE_LEN)
		Hud.msg("Omori takıldı", Color(0.9, 0.85, 0.7), 2.0)


## Oyuncu tuşu
static func toggle(p: Node3D) -> void:
	if not has_set(p):
		Hud.msg("Ağırlıklı kıyafet giymiyorsun", Color(1, 0.8, 0.5), 2.0)
		return
	if is_off(p):
		wear(p)
	else:
		release(p)


## Düşman: ağırlıklı doğar (yavaş); sıkışınca çıkarır
static func npc_ready(e: Node3D) -> void:
	if not has_set(e):
		return
	e.arch = (e.arch as Dictionary).duplicate()
	e.arch["speed"] = float(e.arch.get("speed", 8.5)) * WORN_SPEED
	e.set_meta("omori_npc", true)


static func npc_tick(e: Node3D) -> void:
	if not e.has_meta("omori_npc") or is_off(e):
		return
	var t = e.get("target")
	if t == null or not is_instance_valid(t) or float(e.hp) > float(e.max_hp) * NPC_HP:
		return
	if e.global_position.distance_to(t.global_position) < NPC_RANGE and String(e.state) != "attack":
		release(e)
