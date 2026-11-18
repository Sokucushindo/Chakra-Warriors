extends RefCounted
## Tate: model, blok kuralı, karşı vuruş ve iple savurma — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kaynaklar: Gamaken (sırtta taşınan yuvarlak sakazuki kalkanı, savunur ve gürz gibi sallar), Renga Kokubō (kalkanı iki elle dayayıp alevi durdurur),
## Temujin'in kalkanı (kol üstünde; standart silahları geri çevirir), gerçek dünya: göbek (umbo) ile yumruk gibi karşılama.
## KURAL: alınan hasarı yüzde azaltan hiçbir şey yok. Önden gelen darbe ya TAM durur (dayanıklılık düşer) ya da geçer.
## Dayanıklılık biterse kalkan düşürülür: kısa sersemleme, bir süre blok yok. Oyuncu ve düşman aynı kod (Player/Enemy.take_hit).

const ID := "tate"
const BAR_MAX := 5.0
const BAR_REGEN := 0.55        # saniyede
const DOWN_T := 5.0            # kırılınca blok yok
const PERFECT_T := 0.18        # pencere başında karşılama: bedelsiz, saldıran sendeler

static var _c := {}

const SPARK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""


# ------------------------------------------------------------------ model
## Ön kol çerçevesi: +X kolun dış yüzü (kalkanın baktığı yön), YZ düzlemi kalkan yüzü. `ahsap_kalkan` sırt eşyasıyla aynı dil: ahşap gövde, demir kenar, demir göbek.
static func model(b: MB, id := "tate") -> void:
	var wood = Color(0.5, 0.36, 0.22)
	var wood2 = Color(0.43, 0.3, 0.18)
	var iron = Color(0.3, 0.31, 0.33)
	var r = 0.4   # toplam çap 0.85 altında kalsın: uzun silah bekleme eğimi kalkana uygulanmaz
	Loft.tube(b, [Vector3(0.03, 0, 0), Vector3(0.075, 0, 0), Vector3(0.115, 0, 0)], [r, r * 0.86, r * 0.42], wood, 24, 3, false, true, Callable(), Vector3.BACK)
	for k in 7:   # tahtalar: yüzeyde koyu ek yerleri
		var z = (k - 3) * 0.115
		var half = sqrt(maxf(0.0, r * r - z * z)) * 0.93
		var x = 0.082 + 0.02 * (1.0 - absf(z) / r)
		b.add("box", Vector3(x, 0, z), Vector3(0.006, half * 2.0, 0.009), wood2)
	b.add("torus", Vector3(0.04, 0, 0), Vector3(r * 2.06, 0.1, r * 2.06), iron, Vector3(0, 0, 90), 28)   # demir kenar
	b.add("sphere", Vector3(0.135, 0, 0), Vector3(0.09, 0.2, 0.2), iron, Vector3.ZERO, 12)                  # göbek
	b.add("cyl", Vector3(0.105, 0, 0), Vector3(0.27, 0.018, 0.27), iron.darkened(0.2), Vector3(0, 0, 90), 14)
	for k in 12:
		var a = TAU * k / 12.0
		b.add("sphere", Vector3(0.066, cos(a) * r * 0.9, sin(a) * r * 0.9), Vector3(0.022, 0.03, 0.03), iron, Vector3.ZERO, 5)   # perçinler
	for s in [-1.0, 1.0]:   # iç kayışlar (ön kolu saran)
		b.add("box", Vector3(0.012, 0, 0.09 * s), Vector3(0.012, 0.13, 0.03), Color(0.22, 0.15, 0.1))
	if id == "tate_kirik":   # dayanıklılık bitti: yüzeyde kırık yarıklar
		var dk = Color(0.08, 0.06, 0.05)
		for e in [[0.16, 0.05, 0.3, 30.0], [-0.12, 0.17, 0.24, -48.0], [0.03, -0.2, 0.2, 76.0]]:
			b.add("box", Vector3(0.112, e[0], e[1]), Vector3(0.01, e[2], 0.018), dk, Vector3(float(e[3]), 0, 0))


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


## {node, hand} (takılı değilse boş)
static func _gear(who: Node3D) -> Dictionary:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return {}
	for w in m.weapons:
		if Gear.base_id(String(w["id"])) in [ID, "tsurukame"] and is_instance_valid(w["node"]):
			return w
	return {}


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _h(who: Node3D) -> float:
	return float(who.get("height")) if who.get("height") != null else 1.8


static func _after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


static func _foe(who: Node3D, r: float) -> Node3D:
	var best: Node3D = null
	var bd = r
	for x in who.get_tree().get_nodes_in_group("fighters"):
		if x == who or not Combat.hostile(who, x) or x.is_dead():
			continue
		var d = (x as Node3D).global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = x
	return best


static func _set_mesh(w: Dictionary, id: String) -> void:
	var n = w["node"]
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh(id)


## Ahşap kıymıkları + demir kıvılcım çizgileri (blok anı)
static func _splinters(p: Vector3, d: Vector3, n: int) -> void:
	var root = _root()
	if root == null:
		return
	if not _c.has("chip"):
		var b = BoxMesh.new()
		b.size = Vector3(0.03, 0.012, 0.12)
		_c["chip"] = b
		var s = Shader.new()
		s.code = SPARK_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["chipm"] = m
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _c["chip"]
	mm.instance_count = n
	var data = []
	for i in n:
		var v = (d + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * 0.75).normalized() * randf_range(2.5, 6.0)
		var col = Color(1.0, 0.82, 0.5) if i % 3 == 0 else Color(0.58, 0.42, 0.26)
		data.append([v, randf() * TAU, randf_range(6.0, 14.0), col])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _c["chipm"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(p - Vector3.ONE * 5.0, Vector3.ONE * 10.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var T = 0.42
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		for i in n:
			var e: Array = data[i]
			var q = p + (e[0] as Vector3) * t + Vector3.DOWN * 9.0 * t * t
			mm.set_instance_transform(i, Transform3D(Basis(Vector3(0.5, 0.7, 0.2).normalized(), float(e[1]) + float(e[2]) * t), q))
			var c: Color = e[3]
			mm.set_instance_color(i, Color(c.r, c.g, c.b, 1.0 - t / T)), 0.0, T, T)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ blok
static func _bar(who: Node3D) -> float:
	var now = Game.now()
	var gw = _gear(who)
	var mx = 8.0 if not gw.is_empty() and Gear.base_id(String(gw["id"])) == "tsurukame" else BAR_MAX   # Tsurukame: Jidanda'ya dayanan kabuk
	var v = minf(mx, float(who.get_meta("tate_bar", mx)) + (now - float(who.get_meta("tate_bar_t", now))) * BAR_REGEN)
	who.set_meta("tate_bar", v)
	who.set_meta("tate_bar_t", now)
	return v


static func _holding(who: Node3D) -> bool:
	if who is Player:
		return who.combat != null and str(who.combat.get("action")) == "guard"
	return bool(who.get("guarding"))


## Darbe karşılandı mı? true: darbe tamamen durdu. false: kalkan yok, açı tutmuyor, jutsu çok büyük ya da kalkan düştü -> tam geçer.
static func block(who: Node3D, info: Dictionary) -> bool:
	var w = _gear(who)
	if w.is_empty():
		return false
	var n: Node3D = w["node"]
	var now = Game.now()
	var win = now <= float(who.get_meta("tate_win", 0.0))
	if not win and not _holding(who):
		return false
	if not n.visible or n.get_parent() != w["hand"] or now < float(who.get_meta("tate_down", 0.0)):
		return false
	var tier = int(info.get("tier", -1))
	if info.get("sure", false) or tier >= 4:   # oyuncunun normal bloğuyla aynı eşik: en büyük jutsular durmaz
		return false
	var f = _face(who)
	var atk = info.get("attacker")
	var to: Vector3 = (atk.global_position - who.global_position) if atk is Node3D and is_instance_valid(atk) else -Vector3(info.get("dir", Vector3.ZERO))
	to.y = 0.0
	if to.length() < 0.05 or to.normalized().dot(f) < 0.2:
		return false
	var c = who.global_position + Vector3.UP * _h(who) * 0.62 + f * 0.55
	var perfect = win and now - float(who.get_meta("tate_win0", -9.0)) <= PERFECT_T and tier < 0
	var cost = 0.0 if perfect else (2.0 if str(info.get("kind", "light")) in ["heavy", "launch"] else 1.0) + maxf(0.0, float(tier) + 1.0)
	var bar = _bar(who) - cost
	if bar < 0.0:
		who.set_meta("tate_bar", 0.0)
		who.set_meta("tate_down", now + DOWN_T)
		_set_mesh(w, Gear.base_id(String(w["id"])) + "_kirik")
		_after(who, DOWN_T, func():
			var w2 = _gear(who)
			if not w2.is_empty():
				_set_mesh(w2, Gear.base_id(String(w2["id"]))))
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kalkan Düştü!", Color(1.0, 0.6, 0.35))
		Sfx.play("hit_heavy", c, 0.7, 0.9)
		_splinters(c, to.normalized(), 18)
		if who.has_method("apply_status"):
			who.apply_status("stun", 0.7)
		return false
	who.set_meta("tate_bar", bar)
	Sfx.play("block", c, 1.35 if perfect else randf_range(0.82, 0.96), 0.9)
	_splinters(c, to.normalized(), 7 if not perfect else 4)
	if who is CharacterBody3D:
		who.velocity += -to.normalized() * (0.8 if perfect else 2.0 + maxi(tier, 0) * 1.2)
	if bool(info.get("melee", false)) and atk is Node3D and is_instance_valid(atk) and perfect:
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Kusursuz Blok!", Color(0.85, 0.95, 1.0))
		if atk.has_method("stagger"):
			atk.stagger(0.7)
		elif atk.has_method("apply_status"):
			atk.apply_status("stun", 0.45)
	if now <= float(who.get_meta("tate_counter", 0.0)):
		who.set_meta("tate_counter", 0.0)
		_after(who, 0.06, func():
			_counter(who))
	return true


static func _window(who: Node3D, delay: float, dur: float) -> void:
	_after(who, delay, func():
		who.set_meta("tate_win0", Game.now())
		who.set_meta("tate_win", Game.now() + dur))


## Mamori Kaeshi: karşılayan kalkan aynı anda öne çarpar
static func _counter(who: Node3D) -> void:
	var f = _face(who)
	var c = who.global_position + Vector3.UP * 1.1 + f * 1.25
	var dmg = float(who.get_meta("tate_dmg", 10.0))
	Combat.hit_sphere(who, c, 1.25, {"dmg": dmg * 1.45, "knock": 8.0, "stun": 0.75, "kind": "heavy", "hitstop": 0.09, "melee": true})
	Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Karşı Vuruş!", Color(1.0, 0.85, 0.5))
	Sfx.play("hit_heavy_weapon", c, 1.05, 0.9)
	_splinters(c, f, 6)


# ------------------------------------------------------------------ yürüyerek itiş
static func _drive(who: Node3D, dist: float, dur: float) -> void:
	var last = {"k": 0.0}
	var tw = who.create_tween()
	tw.tween_method(func(k: float):
		var dk = k - float(last["k"])
		last["k"] = k
		var p: Vector3 = who.global_position
		who.global_position = PlayerCombat.safe_dest(who, p, p + _face(who) * dist * dk), 0.0, 1.0, dur)


# ------------------------------------------------------------------ Furi Tate: kalkan ipiyle savrulur
static func flail(who: Node3D, dmg: float) -> void:
	var root = _root()
	var w = _gear(who)
	if root == null or w.is_empty():
		return
	var n: Node3D = w["node"]
	var hand: Node3D = w["hand"]
	n.visible = false
	var disc = MeshInstance3D.new()
	disc.mesh = CharacterModel.weapon_mesh(ID)
	root.add_child(disc)
	var rope = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.016
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	rope.mesh = cm
	rope.material_override = Props.toon_color(Color(0.66, 0.56, 0.38), 0.2)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rope)
	var f0 = _face(who)
	var tg = _foe(who, 9.0)
	var T = 0.86
	var done: Array = []
	var st = {"tick": -1, "slam": false}
	var a0 = atan2(f0.x, f0.z) - PI * 0.5   # sol yandan başlar
	var tw = disc.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(disc) or not is_instance_valid(who):
			return
		var c = who.global_position + Vector3.UP * 1.15
		var f = _face(who)
		var p: Vector3
		var u = k / 0.68
		if k < 0.68:   # çevrede bir tur + çeyrek
			var a = a0 - u * TAU * 1.25
			p = c + Vector3(sin(a), 0.04 * sin(u * 9.0), cos(a)) * lerpf(1.2, 3.0, minf(u * 2.0, 1.0))
		elif k < 0.82:   # öne çarpış
			var tp = (tg.global_position + Vector3.UP * 1.0) if tg != null and is_instance_valid(tg) else c + f * 3.4
			p = disc.global_position.lerp(tp, 0.5)
		else:
			var v = (k - 0.82) / 0.18
			p = disc.global_position.lerp(hand.global_position, v)
		var out = (p - c)
		out.y = 0.0
		var nz = out.normalized() if out.length() > 0.05 else f
		disc.global_transform = Transform3D(Basis(Vector3.UP.cross(nz).normalized(), Vector3.UP, Vector3.UP.cross(nz).normalized().cross(Vector3.UP)).rotated(nz, PI * 0.5), p)
		var h0: Vector3 = hand.global_position
		var d = p - h0
		var L = maxf(d.length(), 0.05)
		var y = d / L
		var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		rope.global_transform = Transform3D(Basis(x, y * L, x.cross(y)), (h0 + p) * 0.5)
		var tick = int(k * T / 0.07)
		if tick != int(st["tick"]) and k < 0.66:
			st["tick"] = tick
			done.append_array(Combat.hit_sphere(who, p, 1.05, {"dmg": dmg * 0.5, "knock": 4.0, "kind": "light", "hitstop": 0.04, "melee": true}, done))
		if k >= 0.76 and not bool(st["slam"]):
			st["slam"] = true
			Combat.hit_sphere(who, p, 1.5, {"dmg": dmg * 1.15, "knock": 11.0, "kind": "heavy", "hitstop": 0.09, "melee": true})
			Sfx.play("hit_heavy_weapon", p, 0.82, 1.0)
			_splinters(p, f, 8), 0.0, 1.0, T)
	tw.tween_callback(func():
		if is_instance_valid(disc):
			disc.queue_free()
		if is_instance_valid(rope):
			rope.queue_free()
		if is_instance_valid(n):
			n.visible = true)
	Sfx.play("swing_chain", who.global_position, 0.72, 0.9)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	match i:
		0:
			_window(who, 0.03, 0.26)
		2:
			_window(who, 0.08, 0.6)
			_after(who, 0.1, func():
				_drive(who, 2.3, 0.5))
		3:
			_window(who, 0.08, 0.62)
			who.set_meta("tate_counter", Game.now() + 0.7)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	who.set_meta("tate_dmg", dmg)
	if i == 5:
		flail(who, dmg)
