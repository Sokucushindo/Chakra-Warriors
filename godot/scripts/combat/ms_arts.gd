class_name MsArts
extends RefCounted
## Mangekyō tarzlarının kendi teknikleri (Eyes.MS_STYLES): her biri ayrı hazırlık + bırakış + çarpma efekti.
## Susanoo teknikleri sahibinin GERÇEK Susanoo'sunu kullanır (Susanoo.of); Kamui girdabı; Itachi yanılsaması karga sürüsü.
## Jutsu.execute çağırır.

const COL := {"itachi": Color(1.0, 0.3, 0.25), "sasuke": Color(0.6, 0.35, 1.0), "madara": Color(0.25, 0.5, 1.0),
	"shisui": Color(0.3, 0.95, 0.5), "kakashi": Color(0.25, 0.95, 0.95)}

const IDS := ["totsuka_no_tsurugi", "yata_no_kagami", "magen_karasu_bunshin", "susanoo_kagutsuchi_no_yumiya",
	"enton_kagutsuchi_no_tsurugi", "susanoo_chidori", "susanoo", "susanoo_kobushi", "susanoo_kai", "yasaka_no_magatama", "enton_yasaka_no_magatama",
	"indora_no_ya", "susanoo_gokakyu", "susanoo_hozan", "susanoo_tsukumo", "kamui_shuriken", "kyoso_enbu",
	"zanzo_bunshin", "bunshun", "uchiha_ryu_higasa_no_mai", "susanoo_kaien", "kotoamatsukami_kobo", "kotoamatsukami_zanko", "kanseitai_susanoo_kishin",
	"saten", "sain", "muzan", "mekkyaku", "tenso",
	"raikiri_sosenko", "raikiri_issen", "raiju_hashiri_so", "susanoo_kamui_raikiri", "susanoo_dan", "susanoo_retsu", "susanoo_nito_no_mai",
	"totsuka_renzokugiri", "tsukuyomi_mode", "enton_honoikazuchi", "amaterasu_zanka"]   # yalnız kanon (uydurma tarz teknikleri silindi; Kamui/Shisui güçleri artık göz yeteneği)


static func handles(id: String) -> bool:
	return id in IDS


static func cast(c: Node3D, id: String, t: Node3D) -> void:
	Callable(MsArts, "m_" + id).call(c, t)


# ------------------------------------------------------------------ ortak yardımcılar
static func _scene() -> Node:
	return Jutsu.get_tree().current_scene


static func _tw() -> Tween:
	return Jutsu.create_tween()


static func _later(t: float, f: Callable) -> void:
	Jutsu.get_tree().create_timer(t).timeout.connect(f)


static func _chest(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * float(n.get("height") if n.get("height") != null else 1.8) * 0.55


static func _point(c: Node3D, t: Node3D, rng: float, fall := 14.0) -> Vector3:
	var tg = Jutsu._tg(c, t, rng)
	return _chest(tg) if tg else Jutsu._aim_ground(c, t, fall, rng) + Vector3.UP


static func _anim(c: Node3D, a: String, sp := 1.2) -> void:
	if c.get("model") and c.model:
		c.model.play(a, 0.05, sp, true)


static func _shake(a: float) -> void:
	if Game.world:
		Game.world.env.add_shake(a)


static func _tint(col: Color, dur: float) -> void:
	if Game.world:
		Game.world.env.set_tint(col)
		_later(dur, func(): if Game.world: Game.world.env.set_tint(Color(0, 0, 0, 0)))


static func _spiral(pos: Vector3, size: float, dur: float, normal := Vector3(0, 0, 1)) -> MeshInstance3D:
	return kamui_vortex(pos, size, dur)


## Kamui girdabı (anime): uzay merkeze doğru burkulur, ortası koyu boşluğa açılır; kameraya bakan, ekranı büken dörtgen
static func kamui_vortex(pos: Vector3, size: float, dur: float) -> MeshInstance3D:
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/vfx_kamui.gdshader")
	m.set_shader_parameter("strength", 0.0)
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 2.0
	var face = func():
		if is_instance_valid(mi) and Game.player and Game.player.cam:
			mi.look_at(Game.player.cam.global_position, Vector3.UP)
			mi.rotate_object_local(Vector3.UP, PI)
	face.call()
	var tw = mi.create_tween()
	tw.tween_method(func(k: float):
		m.set_shader_parameter("strength", k)
		face.call(), 0.0, 1.0, minf(0.35, dur * 0.4)).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(_k: float): face.call(), 0.0, 1.0, maxf(0.05, dur - 0.65))
	tw.tween_method(func(k: float):
		m.set_shader_parameter("strength", k)
		face.call(), 1.0, 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Itachi'nin kargası: sivri gagalı başı, kalın gövdesi, yelpaze kuyruğu ve parmak parmak tüylenen kanatları (Sharingan gözlü).
## Örgüler bir kez kurulur (sürüler yüzlerce karga çağırır).
static var _crow_body: ArrayMesh
static var _crow_wing: ArrayMesh
static func _crow() -> Node3D:
	if _crow_body == null:
		var ink = Color(0.04, 0.04, 0.06)
		var mb = MB.new()
		var pts = []
		var rr = []
		for k in 8:   # gövde: göğüs kalın, kuyruğa doğru incelir
			var z = lerpf(-0.16, 0.2, k / 7.0)
			pts.append(Vector3(0, -0.01 * sin(k / 7.0 * PI), z))
			var w = 0.085 * sin(lerpf(0.35, 2.9, k / 7.0)) + 0.012
			rr.append(Vector2(w, w * 0.9))
		Loft.tube(mb, pts, rr, ink, 8, 2)
		mb.add("sphere", Vector3(0, 0.05, -0.2), Vector3(0.11, 0.11, 0.12), ink, Vector3.ZERO, 8)   # baş
		mb.add("cone", Vector3(0, 0.04, -0.3), Vector3(0.035, 0.11, 0.03), Color(0.12, 0.12, 0.14), Vector3(-90, 0, 0), 5)   # gaga
		for sx in [-1.0, 1.0]:
			mb.add("sphere", Vector3(0.045 * sx, 0.075, -0.23), Vector3(0.026, 0.026, 0.02), Color(0.95, 0.05, 0.05), Vector3.ZERO, 5)   # Sharingan gözler
		for k in 5:   # yelpaze kuyruk
			var a = lerpf(-0.45, 0.45, k / 4.0)
			mb.add("box", Vector3(sin(a) * 0.06, -0.005, 0.27 + cos(a) * 0.05), Vector3(0.04, 0.008, 0.16), ink, Vector3(0, rad_to_deg(a), 0))
		_crow_body = mb.build(Props.toon())
		var wm = MB.new()   # sağ kanat (+X); sol kanat aynası
		wm.add("box", Vector3(0.12, 0, 0.0), Vector3(0.2, 0.018, 0.17), ink, Vector3(0, -8, 0))   # iç kanat (örtü tüyleri)
		for k in 5:   # dış kanat: parmak gibi ayrılan uç tüyler
			var a = lerpf(-22.0, 18.0, k / 4.0)
			var L = 0.2 + 0.04 * sin(k / 4.0 * PI)
			var dir = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
			wm.add("box", Vector3(0.22, 0, 0.02) + dir * L * 0.5, Vector3(L, 0.012, 0.045), ink, Vector3(0, -a, 0))
		_crow_wing = wm.build(Props.toon())
	var root = Node3D.new()
	var body = MeshInstance3D.new()
	body.mesh = _crow_body
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	for sx in [-1.0, 1.0]:
		var w = MeshInstance3D.new()
		w.mesh = _crow_wing
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.scale = Vector3(sx, 1, 1)
		w.position = Vector3(0.04 * sx, 0.02, -0.04)
		w.name = "W%d" % int(sx)
		root.add_child(w)
	return root


static func _flap(cr: Node3D, t: float) -> void:
	var a = sin(t * 26.0) * 0.8
	var l = cr.get_node_or_null("W-1"); var r = cr.get_node_or_null("W1")
	if l: l.rotation.z = -a
	if r: r.rotation.z = a


## Karga sürüsü: from'dan to'ya kıvrılarak uçar (n karga, süre); varınca on_arrive
static func _crows(from: Vector3, to: Vector3, n: int, dur: float, on_arrive := Callable()) -> void:
	var cs = []
	for i in n:
		var cr = _crow()
		_scene().add_child(cr)
		cr.global_position = from + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.6), randf_range(-0.6, 0.6))
		cr.scale = Vector3.ONE * randf_range(1.0, 1.5)
		cs.append([cr, cr.global_position, Vector3(randf_range(-4, 4), randf_range(1.5, 5.0), randf_range(-4, 4)), randf() * 0.25])
	var tw = _tw()
	tw.tween_method(func(x: float):
		for e in cs:
			var cr: Node3D = e[0]
			if not is_instance_valid(cr):
				continue
			var k = clampf((x - float(e[3])) / (1.0 - float(e[3])), 0.0, 1.0)
			var p0: Vector3 = e[1]
			var mid: Vector3 = (p0 + to) * 0.5 + e[2]
			var p = p0.lerp(mid, k).lerp(mid.lerp(to + e[2] * 0.15, k), k)
			if p.distance_to(cr.global_position) > 0.01:
				cr.look_at(p + (p - cr.global_position), Vector3.UP)
			cr.global_position = p
			_flap(cr, x * dur + float(e[3]) * 10.0), 0.0, 1.0, dur)
	tw.tween_callback(func():
		for e in cs:
			if is_instance_valid(e[0]):
				FX.smoke_puff(e[0].global_position, 0.25, 3)
				e[0].queue_free()
		if on_arrive.is_valid():
			on_arrive.call())


## Kara alev malzemeli geometri
static func _black_mesh(mb: MB) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mb.build(null)
	mi.material_override = Jutsu._black_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ================================================================== ITACHI
## Magen: Karasu Bunshin — beden karga sürüsüne dağılır, hedefin arkasında yeniden toplanır; hedef yanılsamada kalır
static func m_magen_karasu_bunshin(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 35.0)
	var from = c.global_position
	var dest: Vector3 = (tg.global_position + (tg.global_position - from).normalized() * 2.0) if tg else Jutsu._ground(from + Jutsu._aim_flat(c, t) * 14.0)
	dest = Jutsu._ground(dest)
	Sfx.play("genjutsu", from, 0.9)
	if c.get("model"):
		c.model.visible = false
	FX.smoke_puff(from + Vector3.UP, 0.8, 10)
	_crows(from + Vector3.UP, dest + Vector3.UP, 26, 0.7, func():
		if not is_instance_valid(c):
			return
		c.global_position = dest
		if c.has_method("reset_physics_interpolation"):
			c.reset_physics_interpolation()
		if c.get("model"):
			c.model.visible = true
		FX.smoke_puff(dest + Vector3.UP, 0.8, 10)
		if tg and is_instance_valid(tg) and not tg.is_dead():
			tg.apply_status("stun", 2.2)
			tg.take_hit(Jutsu._inf(c, "magen_karasu_bunshin", 1.0, {"knock": 6.0, "attacker": c, "dir": (tg.global_position - dest).normalized()}))
			VFX.shockwave(_chest(tg), Color(0.9, 0.05, 0.05), 3.0, 0.4, false))


# ================================================================== SASUKE
## Enton: Kagutsuchi no Tsurugi — elde kara alevden kılıç biçimlenir, ileri atılıp yay çizen kesik; kesik yanmaya devam eder
static func m_enton_kagutsuchi_no_tsurugi(c: Node3D, t: Node3D) -> void:
	var mb = MB.new()
	mb.add("box", Vector3(0, 0, -0.8), Vector3(0.12, 0.05, 1.6), Color.WHITE)
	mb.add("cone", Vector3(0, 0, -1.75), Vector3(0.12, 0.35, 0.05), Color.WHITE, Vector3(-90, 0, 0), 4)
	var sw = _black_mesh(mb)
	c.add_child(sw)
	sw.position = Vector3(0.35, 1.1, -0.5)
	sw.scale = Vector3(1, 1, 0.05)
	sw.create_tween().tween_property(sw, "scale", Vector3.ONE * 1.4, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play("genjutsu", c.global_position, 0.7)
	var inf = Jutsu._inf(c, "enton_kagutsuchi_no_tsurugi", 0.7, {"knock": 8.0, "kind": "heavy", "hitstop": 0.06, "element": "katon"})
	var hitl = []
	_later(0.25, func():
		if not is_instance_valid(c):
			return
		_anim(c, "slash_c", 1.3)
		Jutsu._dash(c, t, 0.32, 24.0, func(p: Vector3):
			for h in Combat.hit_sphere(c, p, 2.0, inf, hitl):
				hitl.append(h)
				Jutsu._ignite(h, 6.0)
			VFX.embers(p, Color(0.5, 0.1, 0.6), 2, 2.0, 0.5), func():
			if not is_instance_valid(c):
				return
			var arc = VFX._mi(VFX.asset("slash_arc"), Jutsu._black_mat())
			_scene().add_child(arc)
			arc.global_position = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 1.2
			arc.look_at(arc.global_position + c.face_dir(), Vector3.UP)
			arc.scale = Vector3.ONE * 3.5
			var tw = arc.create_tween()
			tw.tween_property(arc, "scale", Vector3.ONE * 4.5, 0.6)
			tw.tween_property(arc, "scale", Vector3.ONE * 0.1, 0.25)
			tw.tween_callback(arc.queue_free)
			VFX.black_smolder(Jutsu._ground(c.global_position + c.face_dir() * 2.0), 1.6, 5.0)
			if is_instance_valid(sw):
				sw.queue_free()))


# ================================================================== SUSANOO TEKNİKLERİ (gerçek Susanoo)
## Hepsi sahibinin GERÇEK Susanoo'sunu kullanır (Susanoo.of): oyuncunun V ile açtığı / özelleştirdiği, düşmanın kendi Susanoo'su.
## Susanoo yoksa teknik atılmaz. Kollar hedefe göre pozlanır (PoseOverlay), efektler Susanoo'nun elinden / ağzından çıkar,
## boyutlar Susanoo boyuyla (TIER_HEIGHT) ölçeklenir.

static func _pj() -> PathJutsu:
	return PathJutsu.get_pinst()


static func _alive(n: Node3D) -> bool:
	return n != null and is_instance_valid(n) and not n.is_dead()


## Sahibi (ve Susanoo'su) hedefe döner; yatay yön döner
static func _turn(c: Node3D, to: Vector3) -> Vector3:
	var d = to - c.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else c.face_dir()
	if "facing" in c:
		c.facing = atan2(-d.x, -d.z)
	return d


## Nişan: hedef varsa göğsü (her kare güncel), yoksa ileride yer
static func _aim_fn(c: Node3D, tg: Node3D, dist: float) -> Callable:
	var fb = Jutsu._ground(c.global_position + c.face_dir() * dist) + Vector3.UP
	var wr = weakref(tg) if tg else null   # serbest kalan hedefi lambda yakalamasın
	var last = {"p": _chest(tg) if tg else fb}
	return func() -> Vector3:
		var n = wr.get_ref() if wr else null
		if n != null and not n.is_dead():
			last["p"] = _chest(n)
		return last["p"]


## +Z ekseni dir'e bakan dönüş (looking_at -Z'yi çevirir); dikeye yakınsa yedek yukarı ekseni
static func _zbasis(dir: Vector3, up := Vector3.UP) -> Basis:
	var d = dir.normalized()
	var u = up if absf(d.dot(up.normalized())) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(-d, u)


## İnce silindir parçasını a->b arasına yerleştir (yay kirişi)
static func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var v = b - a
	var L = maxf(0.01, v.length())
	var y = v / L
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	mi.global_transform = Transform3D(Basis(x * r, y * L, z * r), (a + b) * 0.5)


static func _rod() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Susanoo'nun gövdesinden yükselen chakra halkası (teknik başlarken)
static func _sus_flare(sn: Susanoo, at: Vector3, s: float) -> void:
	VFX.gather(at, sn.color().lightened(0.3), s)
	VFX.star(at, sn.color().lightened(0.5), s * 1.6, 0.18)


# ------------------------------------------------------------------ Susanoo (çağırma)
static func m_susanoo(c: Node3D, t: Node3D) -> void:
	var had = c == Game.player and c.combat and c.combat.modes and c.combat.modes.eyes and c.combat.modes.eyes.susanoo
	var sn = Susanoo.of(c, "susanoo")
	if sn == null:
		return
	if had:
		Hud.msg("Susanoo zaten açık.", Color(0.8, 0.85, 1.0), 1.2)
		return
	var H = sn.h()
	VFX.shockwave(c.global_position + Vector3.UP * 0.3, sn.color(), 4.0 + H * 0.5, 0.5)
	VFX.embers(c.global_position + Vector3.UP * H * 0.3, sn.color().lightened(0.3), 30, 4.0 + H * 0.2, 1.2)
	_shake(0.3 + sn.tier * 0.15)


# ------------------------------------------------------------------ Totsuka no Tsurugi (Itachi)
## Kanon: Susanoo'nun sağ elindeki sake testisinden (kabza) akan ruhani sıvı kılıç; deldiği her şeyi testiye çeker,
## sonsuz sarhoş rüya dünyasına mühürler. Oyunda: saplama ağır hasar + sersemletme; zayıflamış (%40 altı, boss olmayan)
## hedef testiye çekilip mühürlenir. Oyuncuyu öldürmez (sersemletir).
static func _gourd(sn: Susanoo) -> MeshInstance3D:
	var mb = MB.new()
	mb.add("sphere", Vector3(0, 0, 0.0), Vector3(0.34, 0.34, 0.36), Color.WHITE, Vector3.ZERO, 16)
	mb.add("sphere", Vector3(0, 0, 0.27), Vector3(0.23, 0.23, 0.25), Color.WHITE, Vector3.ZERO, 14)
	mb.add("cyl", Vector3(0, 0, 0.42), Vector3(0.09, 0.12, 0.09), Color.WHITE, Vector3(90, 0, 0), 10)
	mb.add("torus", Vector3(0, 0, 0.15), Vector3(0.2, 0.2, 0.2), Color.WHITE, Vector3(90, 0, 0), 14)   # bel bağı
	mb.add("torus", Vector3(0, 0, 0.48), Vector3(0.1, 0.12, 0.1), Color.WHITE, Vector3(90, 0, 0), 10)   # ağız halkası
	return sn.chakra_mesh(mb, 1.3)


static var _blade_m: ArrayMesh
static func _blade_mesh() -> ArrayMesh:
	if _blade_m == null:
		var mb = MB.new()
		var pts = []
		var rr = []
		for k in 17:
			var z = k / 16.0
			pts.append(Vector3(sin(z * 11.0) * 0.025 * z, cos(z * 7.0) * 0.012 * z, z))
			var w = (0.06 + 0.06 * sin(z * PI * 0.9)) * (1.0 - pow(z, 4.0)) + 0.004
			rr.append(Vector2(w, w * 0.55))
		Loft.tube(mb, pts, rr, Color.WHITE, 10, 2, true, true, Callable(), Vector3.UP)
		_blade_m = mb.build(null)
	return _blade_m


static func m_totsuka_no_tsurugi(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "totsuka_no_tsurugi")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 10.0 + H * 1.3)
	var aim = _aim_fn(c, tg, H * 0.9)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.2)
	_anim(c, "cast_out", 0.8)
	sn.hide_weapons(2.9)
	var left_idle = Susanoo.arm(false, -side * 0.25 - Vector3.UP * 0.9 + d * 0.25, d * 0.7 - Vector3.UP * 0.5 - side * 0.2)
	# 1) testi omuz üstüne kalkar, kılıç ağzından göğe doğru akarak uzar
	sn.pose({"arms": Susanoo.arm(true, side * 0.55 + Vector3.UP * 0.5 - d * 0.15, Vector3.UP * 0.9 + d * 0.3, Vector3.UP * 0.5 + d * 0.85) + left_idle, "spine": -5.0}, 2.8)
	var gourd = _gourd(sn)
	_scene().add_child(gourd)
	var blade = Node3D.new()
	var outer = VFX._mi(_blade_mesh(), sn.flame_mat())
	var inner = VFX._mi(_blade_mesh(), VFX.mat_bolt(Color(1.0, 0.96, 0.9), 2.4))
	inner.scale = Vector3(0.38, 0.38, 1.0)
	blade.add_child(outer)
	blade.add_child(inner)
	_scene().add_child(blade)
	var st = {"len": 0.0, "mode": 0, "gs": 0.05, "w": S * 0.5}
	var o = {"sn": sn, "g": gourd, "b": blade}   # düğümler sözlükte: serbest kalınca lambda yakalaması hata vermesin
	var upd = func(_x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["g"]) and is_instance_valid(o["b"])):
			return
		var sn2: Susanoo = o["sn"]
		var gourd2: Node3D = o["g"]
		var blade2: Node3D = o["b"]
		var hp = sn2.hand(true)
		var dir: Vector3 = (Vector3.UP * 0.8 + d * 0.6).normalized() if st["mode"] == 0 else (aim.call() - hp).normalized()
		gourd2.global_transform = Transform3D(_zbasis(dir) * Basis.from_scale(Vector3.ONE * S * 0.75 * st["gs"]), hp - dir * S * 0.08)
		var mouth = gourd2.to_global(Vector3(0, 0, 0.5))
		blade2.global_transform = Transform3D(_zbasis(dir) * Basis.from_scale(Vector3(st["w"], st["w"], maxf(0.02, st["len"]))), mouth)
	var tw = blade.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, 3.0)
	tw.tween_method(func(x: float): st["gs"] = x, 0.05, 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(x: float): st["len"] = x, 0.0, H * 0.55, 0.45).set_delay(0.25).set_trans(Tween.TRANS_SINE)
	_sus_flare(sn, sn.hand(true), 1.4)
	Sfx.play("genjutsu", c.global_position, 0.6)
	_later(0.3, func(): Sfx.play("fire", c.global_position, 0.5, 0.6))
	# 2) saplama: kol hedefe uzanır, sıvı kılıç hedefe kadar akıp deler
	_later(0.8, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		st["mode"] = 1
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad) + left_idle, "spine": 12.0}, 2.0, true)
		var reach = sn.hand(true).distance_to(aim.call()) + H * 0.06
		var tw2 = blade.create_tween()
		tw2.tween_method(func(x: float): st["len"] = x, st["len"], reach, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Sfx.play("whoosh", c.global_position, 0.5, 0.9))
	_later(0.93, func():
		if not is_instance_valid(c):
			return
		var p: Vector3 = aim.call()
		VFX.star(p, col.lightened(0.5), 3.0 + H * 0.1, 0.2)
		VFX.shockwave(p, col, 3.0 + H * 0.15, 0.35, false, d)
		VFX.embers(p, col.lightened(0.3), 26, 7.0, 0.9)
		_shake(0.7)
		var inf = Jutsu._inf(c, "totsuka_no_tsurugi", 2.4, {"knock": 2.0, "kind": "heavy", "hitstop": 0.14, "dir": d})
		if c != Game.player and is_instance_valid(Game.player):
			# oyuncu Totsuka'yla mühürlenip ölmez: hasar mevcut canının yarısıyla sınırlı, sersemletme kalır
			inf["dmg"] = minf(float(inf.get("dmg", 0.0)), maxf(1.0, float(Game.player.hp) * 0.5))
		var hs = Combat.hit_sphere(c, p, 2.4 + H * 0.04, inf)
		for h in hs:
			if not _alive(h):
				continue
			h.apply_status("stun", 3.0)
			var sealable = h.has_method("die") and not (h is Player) and not h.has_meta("boss") and float(h.hp) <= float(h.max_hp) * 0.4
			if sealable:
				_totsuka_seal(c, sn, h, gourd, col)
			else:
				Combat.popup_text(_chest(h) + Vector3.UP, "Mühüre direniyor!", Color(1, 0.65, 0.55))
				# ruh testiye doğru çekiştirilir (iz), ama beden kopmaz
				_soul_wisps(h, gourd, col, 8))
	# 3) kılıç geri akar, testi kaybolur
	_later(2.2, func():
		if not is_instance_valid(blade):
			return
		var tw3 = blade.create_tween()
		tw3.set_parallel(true)
		tw3.tween_method(func(x: float): st["len"] = x, st["len"], 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		tw3.tween_method(func(x: float): st["gs"] = x, 1.0, 0.02, 0.35).set_delay(0.35)
		tw3.chain().tween_callback(func():
			blade.queue_free()
			if is_instance_valid(gourd):
				gourd.queue_free()))


## Ruh izleri: hedeften testinin ağzına akan Susanoo renginde sıvı-alev damlaları
static func _soul_wisps(h: Node3D, gourd: Node3D, col: Color, n: int) -> void:
	for k in n:
		_later(k * 0.07, func():
			if not (is_instance_valid(h) and is_instance_valid(gourd)):
				return
			var w = VFX._mi(VFX._sphere(0.5, 10, 6), VFX.mat_bolt(col.lightened(0.4), 1.8))
			_scene().add_child(w)
			var from = _chest(h) + Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
			w.global_position = from
			w.scale = Vector3.ONE * randf_range(0.3, 0.6)
			var tw = w.create_tween()
			var o = {"g": gourd, "w": w}
			tw.tween_method(func(x: float):
				if is_instance_valid(o["g"]) and is_instance_valid(o["w"]):
					var w2: Node3D = o["w"]
					var to = o["g"].to_global(Vector3(0, 0, 0.5))
					var mid = from.lerp(to, 0.5) + Vector3.UP * 2.0
					w2.global_position = from.lerp(mid, x).lerp(mid.lerp(to, x), x)
					w2.scale = Vector3.ONE * lerpf(0.5, 0.12, x), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(w.queue_free))


static func _totsuka_seal(c: Node3D, sn: Susanoo, h: Node3D, gourd: Node3D, col: Color) -> void:
	Combat.popup_text(_chest(h) + Vector3.UP, "Totsuka: mühürlendi", col.lightened(0.4))
	Sfx.play("genjutsu", h.global_position, 0.5)
	_soul_wisps(h, gourd, col, 18)
	var m = h.get("model")
	if m:
		var tw = m.create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "scale", m.scale * Vector3(0.05, 1.4, 0.05), 1.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_later(1.15, func():
		if not _alive(h):
			return
		h.die({"execute": true, "attacker": c, "dmg": 9999.0, "sealed": true})
		if is_instance_valid(h) and h.get("model"):
			h.model.visible = false
		if is_instance_valid(gourd):
			VFX.star(gourd.to_global(Vector3(0, 0, 0.5)), col.lightened(0.6), 2.0 + sn.h() * 0.05, 0.25))


# ------------------------------------------------------------------ Yata no Kagami (Itachi)
## Kanon: Susanoo'nun sol kolundaki ayna kalkan; niteliğini saldırıya göre değiştirip her saldırıyı etkisiz kılar.
## Oyunda: 6 sn boyunca gelen hasar %95 azalır (oyuncu ve düşman aynı); her darbe kalkanda dalgalanır ve önündekileri iter.
static func m_yata_no_kagami(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "yata_no_kagami")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var DUR = 6.0
	var d = c.face_dir()
	var side = d.cross(Vector3.UP).normalized()
	_anim(c, "block", 1.0)
	# sol kol kalkanı göğsün önünde tutar
	sn.pose({"arms": Susanoo.arm(false, -side * 0.55 + d * 0.65 - Vector3.UP * 0.35, side * 0.8 + d * 0.45 + Vector3.UP * 0.3), "spine": 6.0}, DUR)
	var shield = Node3D.new()
	var mb = MB.new()
	mb.add("torus", Vector3.ZERO, Vector3(1.0, 0.16, 1.0), Color.WHITE, Vector3(90, 0, 0), 28)
	mb.add("torus", Vector3.ZERO, Vector3(0.62, 0.06, 0.62), Color.WHITE, Vector3(90, 0, 0), 24)
	for k in 12:   # kenar boncukları (aynanın süslü çerçevesi)
		var a = TAU * k / 12.0
		mb.add("sphere", Vector3(cos(a), sin(a), 0) * 0.5, Vector3(0.08, 0.08, 0.08), Color.WHITE, Vector3.ZERO, 8)
	mb.add("sphere", Vector3(0, 0, 0.02), Vector3(0.12, 0.12, 0.06), Color.WHITE, Vector3.ZERO, 10)
	shield.add_child(sn.chakra_mesh(mb, 1.4))
	var face = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.49
	cm.bottom_radius = 0.49
	cm.height = 0.02
	cm.radial_segments = 32
	face.mesh = cm
	face.rotation = Vector3(PI * 0.5, 0, 0)
	var fm = StandardMaterial3D.new()
	fm.albedo_color = Color(col.lightened(0.55).r, col.lightened(0.55).g, col.lightened(0.55).b, 0.55)
	fm.metallic = 1.0
	fm.roughness = 0.06
	fm.emission_enabled = true
	fm.emission = col * 0.35
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = fm
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.add_child(face)
	_scene().add_child(shield)
	var st = {"s": 0.05}
	var o = {"sn": sn, "sh": shield, "c": c}
	var upd = func(_x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["sh"]) and is_instance_valid(o["c"])):
			return
		var fd = o["c"].face_dir()
		var at = o["sn"].bone_at("LeftLowerArm").lerp(o["sn"].bone_at("LeftHand"), 0.55) + fd * S * 0.12
		o["sh"].global_transform = Transform3D(_zbasis(fd) * Basis.from_scale(Vector3.ONE * S * 1.05 * st["s"]), at)
	var tw = shield.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, DUR + 0.4)
	tw.tween_method(func(x: float): st["s"] = x, 0.05, 1.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(x: float): st["s"] = x, 1.0, 0.02, 0.35).set_delay(DUR)
	tw.chain().tween_callback(shield.queue_free)
	VFX.star(shield.global_position, col.lightened(0.6), 2.0 + H * 0.08, 0.2)
	Sfx.play("chakra", c.global_position, 0.6)
	if c is Player:
		Buffs.add("yata", DUR, {"armor": 0.05, "_name": "Yata no Kagami", "_desc": "ayna kalkan: gelen hasar %95 azalır"})
	else:
		c.set_meta("yata_until", Time.get_ticks_msec() + int(DUR * 1000.0))
	var inf = Jutsu._inf(c, "yata_no_kagami", 0.3, {"knock": 20.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.04})
	var last = {"hp": float(c.hp)}
	Jutsu._ticks(int(DUR / 0.25), 0.25, func(i):
		if not (is_instance_valid(o["c"]) and is_instance_valid(o["sh"])):
			return
		var shield2: Node3D = o["sh"]
		var fd = c.face_dir()
		# darbe aldıysa ayna dalgalanır ve saldırganları geri savurur (niteliğini değiştirip yansıtır)
		if float(c.hp) < last["hp"] - 0.01 or i % 2 == 0:
			var struck = float(c.hp) < last["hp"] - 0.01
			var hs = Combat.hit_sphere(c, c.global_position + fd * H * 0.3 + Vector3.UP * H * 0.2, H * 0.22 + 2.0, inf)
			if struck or not hs.is_empty():
				VFX.shockwave(shield2.global_position + fd * S * 0.1, col.lightened(0.4), S * 1.4, 0.3, false, fd)
				VFX.star(shield2.global_position, Color(1, 1, 1), S * 0.5, 0.12)
		last["hp"] = float(c.hp))


# ------------------------------------------------------------------ Susanoo yayı: Enton: Susanoo Kagutsuchi (Sasuke) / Indora'nın Oku
## Sol el yayı hedefe uzatır, sağ el kirişi yanağa kadar çeker; ok kirişte biçimlenir (kara alev / şimşek), bırakınca kiriş titrer.
static func _bow_mesh(sn: Susanoo) -> MeshInstance3D:
	var mb = MB.new()
	var pts = []
	var rr = []
	for k in 15:
		var a = lerpf(-1.25, 1.25, k / 14.0)
		var tip = maxf(0.0, absf(a) - 1.0) * 4.0   # uçlar öne kıvrılır (recurve)
		pts.append(Vector3(0, sin(a) * 0.82, (1.0 - cos(a)) * 0.38 - tip * 0.1))
		var w = lerpf(0.045, 0.016, absf(a) / 1.25)
		rr.append(Vector2(w, w * 1.4))
	Loft.tube(mb, pts, rr, Color.WHITE, 8, 2, true, true, Callable(), Vector3.FORWARD)
	mb.add("sphere", Vector3(0, 0, 0.0), Vector3(0.09, 0.2, 0.1), Color.WHITE, Vector3.ZERO, 10)   # kabza
	for s in [-1.0, 1.0]:   # kanat süsleri
		mb.add("cone", Vector3(0, 0.45 * s, 0.1), Vector3(0.05, 0.22, 0.04), Color.WHITE, Vector3(90 + 30 * s, 0, 0), 6)
	return sn.chakra_mesh(mb, 1.5)


static func _bow_tips() -> Array:
	var a = 1.25
	var tip = (a - 1.0) * 4.0
	var z = (1.0 - cos(a)) * 0.38 - tip * 0.1
	return [Vector3(0, sin(a) * 0.82, z), Vector3(0, -sin(a) * 0.82, z)]


static func _sus_bow(c: Node3D, t: Node3D, jid: String, mode: String) -> void:
	var sn = Susanoo.of(c, jid)
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var indora = mode == "indora"
	var rng = (70.0 if indora else 45.0) + H * 1.5
	var tg = Jutsu._tg(c, t, rng)
	var aim = _aim_fn(c, tg, minf(rng, 25.0 + H))
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	var charge = 1.9 if indora else 1.0
	_pj().busy(c, charge + 0.3)
	_anim(c, "cast", 0.8)
	sn.hide_weapons(charge + 0.9)
	var ad = (aim.call() - sn.bone_at("LeftUpperArm")).normalized()
	var draw = Susanoo.arm(true, side * 0.55 - d * 0.8 + Vector3.UP * 0.12, -side * 0.85 + d * 0.3 + Vector3.UP * 0.3, -side * 0.6 + d * 0.7)
	sn.pose({"arms": Susanoo.arm(false, ad, ad, ad) + draw, "spine": -4.0}, charge + 0.8)
	var bow = _bow_mesh(sn)
	_scene().add_child(bow)
	var strings = [_rod(), _rod()]
	var smat = VFX.mat_bolt(col.lightened(0.6), 1.6)
	for s in strings:
		s.material_override = smat
		_scene().add_child(s)
	# ok: kara alev (Enton) ya da ak-mavi şimşek (Indora)
	var arrow = Node3D.new()
	var amb = MB.new()
	amb.add("cyl", Vector3(0, 0, 0.0), Vector3(0.05, 1.4, 0.05), Color.WHITE, Vector3(90, 0, 0), 8)
	amb.add("cone", Vector3(0, 0, -0.82), Vector3(0.16, 0.3, 0.06), Color.WHITE, Vector3(-90, 0, 0), 4)
	for s in [-1.0, 1.0]:
		amb.add("box", Vector3(0.06 * s, 0, 0.6), Vector3(0.12, 0.01, 0.22), Color.WHITE)
	var shaft = MeshInstance3D.new()
	shaft.mesh = amb.build(null)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.material_override = VFX.mat_bolt(Color(0.85, 0.92, 1.0), 2.6) if indora else Jutsu._black_mat()
	arrow.add_child(shaft)
	if indora:
		var arcs = Arcs.new()
		arcs.color = Color(0.7, 0.85, 1.0)
		arcs.radius = 0.5
		arcs.count = 8
		arcs.width = 0.04
		arrow.add_child(arcs)
	else:
		var fl = VFX.black_flames(0.35)
		fl.position = Vector3(0, 0, -0.3)
		fl.scale = Vector3(0.22, 0.22, 0.9)
		arrow.add_child(fl)
	_scene().add_child(arrow)
	var st = {"bs": 0.05, "as": 0.02, "drawn": true, "flying": false}
	var o = {"sn": sn, "bow": bow, "ar": arrow}
	var upd = func(_x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["bow"])):
			return
		var sn2: Susanoo = o["sn"]
		var bow2: Node3D = o["bow"]
		var arrow2 = o["ar"]
		var lh = sn2.hand(false)
		var a2: Vector3 = (aim.call() - lh).normalized()
		bow2.global_transform = Transform3D(_zbasis(-a2) * Basis.from_scale(Vector3.ONE * S * 1.35 * st["bs"]), lh)
		var tips = _bow_tips()
		var t0 = bow2.to_global(tips[0])
		var t1 = bow2.to_global(tips[1])
		var nock = sn2.hand(true) if st["drawn"] else bow2.to_global(Vector3(0, 0, (1.0 - cos(1.25)) * 0.38 - 0.1))
		var r = S * 0.012 * st["bs"]
		_seg(strings[0], t0, nock, r)
		_seg(strings[1], nock, t1, r)
		if is_instance_valid(arrow2) and not st["flying"]:
			var ad2 = (lh - nock).normalized() if st["drawn"] else a2
			arrow2.global_transform = Transform3D(_zbasis(-ad2) * Basis.from_scale(Vector3.ONE * S * 1.35 * st["as"]), nock + ad2 * S * 1.35 * st["as"] * 0.7)
	var tw = bow.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, charge + 1.2)
	tw.tween_method(func(x: float): st["bs"] = x, 0.05, 1.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(x: float): st["as"] = x, 0.02, 1.0, 0.4).set_delay(0.3)
	tw.tween_method(func(x: float): st["bs"] = x, 1.0, 0.02, 0.3).set_delay(charge + 0.85)
	tw.chain().tween_callback(func():
		bow.queue_free()
		for s in strings:
			if is_instance_valid(s):
				s.queue_free())
	_sus_flare(sn, sn.hand(false), 1.2)
	if indora:
		# Indora: gök kararır, her yandan şimşekler okun ucuna toplanır
		Sfx.play("thunder", c.global_position, 0.7)
		_tint(Color(0.06, 0.05, 0.16, 0.35), charge + 0.6)
		for k in 22:
			_later(0.3 + k * 0.07, func():
				if not is_instance_valid(arrow) or st["flying"]:
					return
				var tip = arrow.to_global(Vector3(0, 0, -0.9))
				var q = tip + Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(H * 0.3, H * 0.8)
				VFX.bolt(q, tip, Color(0.65, 0.85, 1.0), S * 0.02, 0.18, 2))
	else:
		Sfx.play("genjutsu", c.global_position, 0.6)
		_later(0.3, func(): if is_instance_valid(arrow): VFX.gather(arrow.global_position, Color(0.3, 0.05, 0.4), 1.4))
	# bırakış
	_later(charge, func():
		if not (is_instance_valid(c) and is_instance_valid(sn) and is_instance_valid(arrow)):
			if is_instance_valid(arrow):
				arrow.queue_free()
			return
		st["drawn"] = false
		st["flying"] = true
		sn.pose({"arms": Susanoo.arm(false, ad, ad, ad) + Susanoo.arm(true, side * 0.5 - d * 0.85 + Vector3.UP * 0.1, side * 0.3 - d * 0.9 + Vector3.UP * 0.25), "spine": -8.0}, 0.7, true)
		var from = arrow.global_position
		var to: Vector3 = aim.call()
		var dir = (to - from).normalized()
		var dist = from.distance_to(to)
		if not tg:
			to = from + dir * rng * 0.8
			dist = rng * 0.8
		Sfx.play("thunder" if indora else "whoosh", from, 0.6 if indora else 0.7)
		if indora:
			_fire_indora(c, sn, arrow, from, to, dir, dist)
		else:
			_fire_kagutsuchi(c, sn, arrow, from, to, dir, dist))


static func _fire_kagutsuchi(c: Node3D, sn: Susanoo, arrow: Node3D, from: Vector3, to: Vector3, dir: Vector3, dist: float) -> void:
	var H = sn.h()
	VFX.trail(arrow, H * 0.03, Color(0.45, 0.15, 0.55), Color(0.1, 0.02, 0.12), Color(0, 0, 0, 0), 24, 0.0)
	var dur = clampf(dist / 110.0, 0.1, 0.7)
	var tw = arrow.create_tween()
	tw.tween_property(arrow, "global_position", to, dur)
	tw.tween_callback(func():
		arrow.queue_free()
		if not is_instance_valid(c):
			return
		var inf = Jutsu._inf(c, "susanoo_kagutsuchi_no_yumiya", 1.8, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.08, "element": "katon"})
		for h in Combat.hit_sphere(c, to, 3.0 + H * 0.12, inf):
			Jutsu._ignite(h, 8.0)
		var g = Jutsu._ground(to)
		var fl = VFX.black_flames(2.0 + H * 0.05)
		_scene().add_child(fl)
		fl.global_position = g
		fl.scale = Vector3(1.0, 2.2, 1.0)
		_later(4.0, func(): if is_instance_valid(fl): fl.queue_free())
		VFX.shockwave(to, Color(0.22, 0.0, 0.3), 5.0 + H * 0.2, 0.5)
		VFX.black_smolder(g, 3.0 + H * 0.06, 7.0)
		VFX.embers(to, Color(0.6, 0.15, 0.7), 30, 8.0, 1.1)
		_shake(0.8))


static func _fire_indora(c: Node3D, sn: Susanoo, arrow: Node3D, from: Vector3, to: Vector3, dir: Vector3, dist: float) -> void:
	var H = sn.h()
	arrow.queue_free()
	# ışın: tüm yol boyunca kalın şimşek demeti + çatallar, sonda dev patlama
	for k in 3:
		VFX.bolt(from, to, Color(0.8, 0.9, 1.0), H * 0.025 * (1.0 - k * 0.3), 0.45, 4)
	var n = int(dist / 8.0)
	for k in n:
		var q = from + dir * (k * 8.0)
		_later(k * 0.012, func():
			VFX.bolt(q, q + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * H * 0.2, Color(0.6, 0.8, 1.0), H * 0.008, 0.3, 2))
	var inf = Jutsu._inf(c, "indora_no_ya", 4.0, {"knock": 30.0, "launch": 8.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.15, "dir": dir})
	var flat = Vector3(dir.x, 0, dir.z).normalized()
	Combat.hit_zone(c, Jutsu._ground(from), flat, dist + 6.0, 10.0, H * 0.6 + 6.0, inf)
	_later(0.1, func():
		if not is_instance_valid(c):
			return
		Combat.hit_sphere(c, to, 6.0 + H * 0.12, inf)
		_pj().impact_fx("raiton", Color(0.65, 0.85, 1.0), to, 2.0 + H * 0.06)
		VFX.cracks(Jutsu._ground(to), 10.0 + H * 0.2)
		VFX.shockwave(to, Color(0.7, 0.85, 1.0), 10.0 + H * 0.3, 0.6)
		VFX.star(to, Color(0.9, 0.95, 1.0), 8.0 + H * 0.2, 0.3)
		if c is Player:
			VFX.screen_lines(0.5, 1.5, Color(0.7, 0.85, 1.0))
		_shake(2.2))


static func m_susanoo_kagutsuchi_no_yumiya(c: Node3D, t: Node3D) -> void:
	_sus_bow(c, t, "susanoo_kagutsuchi_no_yumiya", "enton")


static func m_indora_no_ya(c: Node3D, t: Node3D) -> void:
	_sus_bow(c, t, "indora_no_ya", "indora")


# ------------------------------------------------------------------ Susanoo: Chidori
## Susanoo'nun sağ eli aşağıda dev Chidori'yi doldurur (yere sürten şimşekler, cıvıltı), sonra kol hedefe uzanır ve
## şimşek mızrak gibi elden fırlar.
static func m_susanoo_chidori(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_chidori")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color().lerp(Color(0.6, 0.75, 1.0), 0.5)
	var tg = Jutsu._tg(c, t, 16.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 10.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.1)
	_anim(c, "cast", 0.9)
	sn.hide_weapons(1.6)
	var lguard = Susanoo.arm(false, d * 0.55 - side * 0.35 - Vector3.UP * 0.55, d * 0.8 + side * 0.25 + Vector3.UP * 0.35)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.4 - Vector3.UP * 0.85 + side * 0.3, d * 0.35 - Vector3.UP * 0.9, d * 0.6 - Vector3.UP * 0.7) + lguard, "spine": 16.0}, 1.6)
	var ball = VFX.lightning_ball(S * 0.32, col)
	var arcs = Arcs.new()
	arcs.color = col.lightened(0.3)
	arcs.radius = S * 0.5
	arcs.count = 12
	arcs.width = S * 0.02
	ball.add_child(arcs)
	_scene().add_child(ball)
	var st = {"free": false}
	var tw = ball.create_tween()
	var o = {"sn": sn, "ball": ball}
	tw.tween_method(func(_x: float):
		if is_instance_valid(o["sn"]) and is_instance_valid(o["ball"]) and not st["free"]:
			o["ball"].global_position = o["sn"].hand(true), 0.0, 1.0, 1.0)
	ball.scale = Vector3.ONE * 0.1
	ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	Sfx.play("chidori", c.global_position, 0.6)
	for k in 12:   # yere sürten şimşek dilleri
		_later(0.1 + k * 0.065, func():
			if not is_instance_valid(ball) or st["free"]:
				return
			var hp = ball.global_position
			var g = Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * S * 0.6)
			VFX.bolt(hp, g, col.lightened(0.2), S * 0.03, 0.14, 2)
			if k % 4 == 0:
				FX.light(hp, col, 6.0, 8.0 + H * 0.6, 0.3))
	_later(0.9, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			if is_instance_valid(ball):
				ball.queue_free()
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad) + lguard, "spine": -6.0}, 0.7, true))
	_later(1.0, func():
		if not (is_instance_valid(c) and is_instance_valid(ball)):
			return
		st["free"] = true
		var from = ball.global_position
		var to: Vector3 = aim.call()
		for k in 3:
			VFX.bolt(from, to, col.lightened(0.4), S * (0.05 - k * 0.012), 0.3, 4)
		var tw2 = ball.create_tween()
		tw2.tween_property(ball, "global_position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.tween_callback(func():
			ball.queue_free()
			if not is_instance_valid(c):
				return
			var inf = Jutsu._inf(c, "susanoo_chidori", 2.2, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.1, "element": "raiton", "stun": 1.4, "dir": d})
			Combat.hit_sphere(c, to, 3.0 + H * 0.1, inf)
			for k in 8:
				VFX.bolt(to, to + Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized() * (4.0 + H * 0.3), col.lightened(0.3), S * 0.02, 0.3, 3)
			VFX.star(to, Color(0.85, 0.9, 1.0), 4.0 + H * 0.15, 0.2)
			VFX.shockwave(to, col, 5.0 + H * 0.25, 0.4, false, d)
			VFX.cracks(Jutsu._ground(to), 4.0 + H * 0.15)
			_shake(0.9)))


# ------------------------------------------------------------------ Yasaka no Magatama (Itachi) / Enton: Yasaka no Magatama (Sasuke)
## Susanoo'nun eli üç magatamayı bir halkada döndürür (Yasaka kolyesi), kolunu savurup fırlatır; magatamalar dönerek
## yay çizip hedefe iner. Enton türü: kara alevli magatamalar, değdiği yer kara alevle yanar.
static func _magatama_mesh() -> MB:
	var mb = MB.new()
	mb.add("sphere", Vector3(0.13, 0, 0), Vector3(0.24, 0.24, 0.16), Color.WHITE, Vector3.ZERO, 12)
	var pts = []
	var rr = []
	for k in 9:
		var a = -k / 8.0 * 2.3
		pts.append(Vector3(cos(a) * 0.13, sin(a) * 0.13, 0))
		var w = lerpf(0.1, 0.01, k / 8.0)
		rr.append(Vector2(w, w * 0.66))
	Loft.tube(mb, pts, rr, Color.WHITE, 8, 2, true, true, Callable(), Vector3.BACK)
	return mb


static func _sus_yasaka(c: Node3D, t: Node3D, jid: String, black: bool) -> void:
	var sn = Susanoo.of(c, jid)
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 36.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 18.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.0)
	_anim(c, "cast", 0.9)
	sn.hide_weapons(1.5)
	# kurulma: sağ kol yana-geriye açılır, avuç yukarıda, magatamalar avuçta döner
	sn.pose({"arms": Susanoo.arm(true, side * 0.75 + Vector3.UP * 0.35 - d * 0.35, Vector3.UP * 0.75 + d * 0.15 + side * 0.3, Vector3.UP * 0.6 - d * 0.3), "spine": -6.0}, 1.5)
	var holder = Node3D.new()
	_scene().add_child(holder)
	var ring_mb = MB.new()
	ring_mb.add("torus", Vector3.ZERO, Vector3(0.72, 0.04, 0.72), Color.WHITE, Vector3(90, 0, 0), 24)
	var ring = sn.chakra_mesh(ring_mb, 1.2)
	holder.add_child(ring)
	var mags = []
	for k in 3:
		var mi: MeshInstance3D
		if black:
			mi = _black_mesh(_magatama_mesh())
			var fl = VFX.black_flames(0.08)
			mi.add_child(fl)
			fl.position = Vector3(0.13, 0, 0)
		else:
			mi = sn.chakra_mesh(_magatama_mesh(), 1.8)
		var a = TAU * k / 3.0
		mi.position = Vector3(cos(a), sin(a), 0) * 0.36
		mi.rotation.z = a
		holder.add_child(mi)
		mags.append(mi)
	var st = {"s": 0.05, "spin": 0.0, "free": false}
	var tw = holder.create_tween()
	tw.set_parallel(true)
	var o = {"sn": sn, "h": holder}
	tw.tween_method(func(x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["h"])) or st["free"]:
			return
		st["spin"] = x * TAU * 6.0
		var hp = o["sn"].hand(true) + Vector3.UP * S * 0.25
		o["h"].global_transform = Transform3D(_zbasis(d) * Basis(Vector3.BACK, st["spin"]) * Basis.from_scale(Vector3.ONE * S * 0.6 * st["s"]), hp), 0.0, 1.0, 0.85)
	tw.tween_method(func(x: float): st["s"] = x, 0.05, 1.0, 0.3).set_trans(Tween.TRANS_BACK)
	_sus_flare(sn, sn.hand(true), 1.2)
	Sfx.play("genjutsu" if black else "chakra", c.global_position, 0.7)
	# savuruş: kol öne-aşağı iner
	_later(0.7, func():
		if is_instance_valid(sn):
			var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
			sn.pose({"arms": Susanoo.arm(true, (ad - side * 0.3).normalized(), (ad - side * 0.4 - Vector3.UP * 0.2).normalized()), "spine": 14.0}, 0.7, true))
	_later(0.82, func():
		st["free"] = true
		if not is_instance_valid(holder):
			return
		if not is_instance_valid(c):
			holder.queue_free()
			return
		ring.create_tween().tween_property(ring, "scale", Vector3.ONE * 1.8, 0.25)
		_later(0.25, func(): if is_instance_valid(holder): holder.queue_free())
		Sfx.play("whoosh", holder.global_position, 0.8)
		for k in 3:
			var mi: MeshInstance3D = mags[k]
			var from = mi.global_position
			mi.reparent(_scene())
			_later(k * 0.09, func(): _fly_magatama(c, sn, mi, from, aim, k, black, jid)))


static func _fly_magatama(c: Node3D, sn: Susanoo, mi: MeshInstance3D, from: Vector3, aim: Callable, k: int, black: bool, jid: String) -> void:
	if not is_instance_valid(mi):
		return
	var H = sn.h() if is_instance_valid(sn) else 16.0
	var col = sn.color() if is_instance_valid(sn) else Color(1, 0.3, 0.25)
	var to0: Vector3 = aim.call()
	var mid = (from + to0) * 0.5 + Vector3.UP * (2.0 + H * 0.12) + (to0 - from).cross(Vector3.UP).normalized() * (k - 1) * (3.0 + H * 0.15)
	var dur = clampf(from.distance_to(to0) / 55.0, 0.25, 1.1)
	if not black:
		VFX.trail(mi, H * 0.02, col.lightened(0.5), col, Color(col.r, col.g, col.b, 0), 18, 1.0)
	var sp = mi.global_basis
	var tw = mi.create_tween()
	var o = {"mi": mi}
	tw.tween_method(func(x: float):
		if is_instance_valid(o["mi"]):
			var to: Vector3 = aim.call()
			o["mi"].global_position = from.lerp(mid, x).lerp(mid.lerp(to, x), x)
			o["mi"].global_basis = sp * Basis(Vector3.BACK, x * TAU * 5.0), 0.0, 1.0, dur)
	tw.tween_callback(func():
		var p = mi.global_position
		mi.queue_free()
		if not is_instance_valid(c):
			return
		var inf = Jutsu._inf(c, jid, 0.55 if black else 0.6, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.06, "element": "katon" if black else ""})
		for h in Combat.hit_sphere(c, p, 2.4 + H * 0.06, inf):
			if black:
				Jutsu._ignite(h, 6.0)
		if black:
			var fl = VFX.black_flames(1.2 + H * 0.03)
			_scene().add_child(fl)
			fl.global_position = Jutsu._ground(p)
			_later(2.5, func(): if is_instance_valid(fl): fl.queue_free())
			VFX.black_smolder(Jutsu._ground(p), 1.6 + H * 0.04, 5.0)
			VFX.shockwave(p, Color(0.25, 0.0, 0.3), 3.0 + H * 0.12, 0.35)
		else:
			FX.impact(p, col, 1.0 + H * 0.05)
			VFX.shockwave(p, col.lightened(0.3), 3.0 + H * 0.12, 0.35)
			VFX.cracks(Jutsu._ground(p), 2.0 + H * 0.08)
		_shake(0.35))


static func m_yasaka_no_magatama(c: Node3D, t: Node3D) -> void:
	_sus_yasaka(c, t, "yasaka_no_magatama", false)


static func m_enton_yasaka_no_magatama(c: Node3D, t: Node3D) -> void:
	_sus_yasaka(c, t, "enton_yasaka_no_magatama", true)


# ------------------------------------------------------------------ Susanoo: Kobushi (yumruk)
static func m_susanoo_kobushi(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kobushi")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 6.0 + H * 1.1)
	var aim = _aim_fn(c, tg, 4.0 + H * 0.45)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 0.7)
	_anim(c, "cross", 1.0)
	# geri çekiş: yumruk omuzun arkasında, gövde burulur
	sn.pose({"arms": Susanoo.arm(true, -d * 0.7 + side * 0.55 - Vector3.UP * 0.25, d * 0.25 + Vector3.UP * 0.55 + side * 0.25, d * 0.6 + Vector3.UP * 0.4), "spine": -8.0}, 1.0)
	_later(0.38, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.6, true)
		Sfx.play("whoosh", c.global_position, 0.6, 0.7))
	_later(0.5, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		var fist = sn.hand(true)
		var to: Vector3 = aim.call()
		var p = fist.lerp(to, 0.4) if tg and fist.distance_to(to) < S * 0.9 + 3.0 else fist
		var inf = Jutsu._inf(c, "susanoo_kobushi", 2.4, {"knock": 24.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.12, "dir": d})
		Combat.hit_sphere(c, p, S * 0.45 + 2.0, inf)
		# yumruk basıncı: kolun ucundan ileri chakra şoku (kolun yetmediği mesafe)
		Combat.hit_zone(c, c.global_position, d, S * 1.2 + 6.0, 26.0, H * 0.8, inf)
		var front = fist + d * (S * 0.6 + 3.0)
		VFX.shockwave(front, col, S * 0.9 + 2.0, 0.3, false, d)
		VFX.shockwave(fist, col.lightened(0.3), S * 1.2 + 2.0, 0.3, false, d)
		VFX.star(fist, Color(1, 1, 1), S * 0.6 + 1.0, 0.12)
		var g = Jutsu._ground(p)
		if p.y - g.y < S * 0.8 + 2.0:
			VFX.cracks(g, S * 0.7 + 3.0)
			VFX.debris(g + Vector3.UP * 0.5, Color(0.5, 0.42, 0.32), 14, 8.0 + S, 0.4 + S * 0.05)
		Sfx.play("punch", p, 0.6)
		_shake(0.5 + sn.tier * 0.12))


# ------------------------------------------------------------------ Susanoo: Gōkakyū
## Susanoo nefes alıp geriye yaslanır, ağzında alev toplanır; öne eğilip dev ateş topunu üfler.
static func m_susanoo_gokakyu(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_gokakyu")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = _aim_fn(c, tg, 22.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.1)
	_anim(c, "cast", 0.9)
	# mühür eli: iki el göğüs önünde; nefes alırken gövde geriye
	var seal = Susanoo.arm(true, -Vector3.UP * 0.7 + d * 0.45 + side * 0.2, -side * 0.75 + Vector3.UP * 0.55 + d * 0.35) + Susanoo.arm(false, -Vector3.UP * 0.7 + d * 0.45 - side * 0.2, side * 0.75 + Vector3.UP * 0.55 + d * 0.35)
	sn.pose({"arms": seal, "spine": -16.0, "neck": -14.0}, 1.4)
	VFX.gather(sn.mouth(d), Color(1.0, 0.55, 0.15), 1.6)
	Sfx.play("fire", c.global_position, 0.5, 0.6)
	_later(0.65, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		sn.pose({"arms": seal, "spine": 18.0, "neck": 12.0}, 0.8, true)
		var from = sn.mouth(d)
		var to: Vector3 = aim.call()
		var ball = Node3D.new()
		ball.add_child(VFX.fireball(1.6 + S * 0.5))
		var inf = Jutsu._inf(c, "susanoo_gokakyu", 3.0, {"knock": 18.0, "launch": 8.0, "kind": "heavy", "element": "katon", "burn": 5.0})
		var pr = _pj().shot(c, from, (to - from).normalized(), 20.0 + S, ball, inf, tg, false, 3.0, func(p, _h):
			VFX.explosion(p, 2.0 + S * 0.3, Color(1.0, 0.5, 0.12))
			GroundFX.add(p, "burning", 5.0 + S * 0.5, 5.0, c)
			_shake(1.4))
		pr.radius = 1.5 + S * 0.35
		pr.homing_turn = 1.0
		ball.scale = Vector3.ONE * 0.2
		ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		Sfx.play("fire", from, 0.4))


# ------------------------------------------------------------------ Susanoo: Hōzan
## Susanoo'nun sol eli hedefi kavrayıp havaya kaldırır, sağ eldeki kılıç (yoksa chakra kılıcı) yukarıdan biçer.
static func m_susanoo_hozan(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_hozan")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg0 = Jutsu._tg(c, t, 8.0 + H * 1.0)
	if not _alive(tg0):
		if c == Game.player:
			Hud.msg("Hōzan: kavranacak hedef yok.", Color(0.85, 0.85, 0.85))
		return
	var d = _turn(c, tg0.global_position)
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.2)
	_anim(c, "cast_out", 0.9)
	var wr = weakref(tg0)
	var reach = func() -> Array:
		var ad = (_chest(wr.get_ref()) - sn.bone_at("LeftUpperArm")).normalized() if _alive(wr.get_ref()) else d
		return Susanoo.arm(false, ad, ad, ad)
	sn.pose({"arms": reach.call()}, 1.5)
	var st = {"held": false}
	var o = {"sn": sn}
	_later(0.35, func():
		if not (_alive(wr.get_ref()) and is_instance_valid(sn)):
			return
		st["held"] = true
		wr.get_ref().apply_status("bind", 1.2)
		Combat.popup_text(_chest(wr.get_ref()) + Vector3.UP, "Kavrandı!", col.lightened(0.4))
		# kavranan hedef ele çekilir, el yukarı kalkar
		var lift = Susanoo.arm(false, d * 0.6 - side * 0.3 + Vector3.UP * 0.3, d * 0.5 + Vector3.UP * 0.75)
		sn.pose({"arms": lift}, 1.2)
		var g0 = wr.get_ref().global_position
		var tw = wr.get_ref().create_tween()
		tw.tween_method(func(x: float):
			if _alive(wr.get_ref()) and is_instance_valid(o["sn"]) and st["held"]:
				var tt = wr.get_ref()
				var to = o["sn"].hand(false) - Vector3.UP * float(tt.get("height") if tt.get("height") != null else 1.8) * 0.5
				tt.global_position = g0.lerp(to, minf(1.0, x * 3.0))
				if "velocity" in tt:
					tt.velocity = Vector3.ZERO, 0.0, 1.0, 0.75))
	_later(0.55, func():
		if is_instance_valid(sn):
			sn.perform("slash_c", 0.9, 1.0))
	_later(1.05, func():
		st["held"] = false
		if not (is_instance_valid(c) and _alive(wr.get_ref())):
			return
		var p = _chest(wr.get_ref())
		_pj()._arc_cut(p, d, -70.0, 70.0, col.lightened(0.3), 2.0 + S * 0.35)
		_pj()._tai_impact(c, p, 1.0 + S * 0.15, false)
		var inf = Jutsu._inf(c, "susanoo_hozan", 3.0, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12, "dir": d})
		Combat.hit_sphere(c, p, float(wr.get_ref().radius) + 0.8 + S * 0.1, inf)
		_shake(0.9))


# ------------------------------------------------------------------ Susanoo: Tsukumo
## Susanoo iki elini kaldırır, ellerinin çevresinde onlarca chakra oku biçimlenir ve hedefe yağar.
static func m_susanoo_tsukumo(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_tsukumo")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 34.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 20.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.2)
	_anim(c, "cast", 0.9)
	sn.hide_weapons(1.8)
	sn.pose({"arms": Susanoo.arm(true, d * 0.55 + Vector3.UP * 0.55 + side * 0.45, d * 0.75 + Vector3.UP * 0.55) + Susanoo.arm(false, d * 0.55 + Vector3.UP * 0.55 - side * 0.45, d * 0.75 + Vector3.UP * 0.55), "spine": -6.0}, 1.8)
	var spears = []
	var smb = MB.new()
	smb.add("cyl", Vector3(0, 0, 0.0), Vector3(0.04, 1.0, 0.04), Color.WHITE, Vector3(90, 0, 0), 6)
	smb.add("cone", Vector3(0, 0, -0.62), Vector3(0.1, 0.25, 0.1), Color.WHITE, Vector3(-90, 0, 0), 6)
	for k in 16:
		_later(0.15 + k * 0.025, func():
			if not is_instance_valid(sn):
				return
			var u = (k / 15.0) * 2.0 - 1.0
			var base = sn.hand(true).lerp(sn.hand(false), 0.5) + side * u * S * 0.9 + Vector3.UP * (S * 0.25 + (1.0 - u * u) * S * 0.5)
			var sp = sn.chakra_mesh(smb, 1.6)
			_scene().add_child(sp)
			sp.global_transform = Transform3D(_zbasis(-(aim.call() - base).normalized()) * Basis.from_scale(Vector3.ONE * S * 0.45), base)
			sp.scale = Vector3.ONE * 0.05
			sp.create_tween().tween_property(sp, "scale", Vector3.ONE * S * 0.45, 0.2).set_trans(Tween.TRANS_BACK)
			spears.append(sp))
	Sfx.play("chakra", c.global_position, 0.8)
	_later(0.75, func():
		if is_instance_valid(sn):
			sn.pose({"arms": Susanoo.arm(true, d * 0.9 + side * 0.25, d) + Susanoo.arm(false, d * 0.9 - side * 0.25, d), "spine": 10.0}, 0.8, true))
	_later(0.8, func():
		for k in spears.size():
			var sp: MeshInstance3D = spears[k]
			_later(k * 0.035, func():
				if not is_instance_valid(sp):
					return
				if not is_instance_valid(c):
					sp.queue_free()
					return
				var from = sp.global_position
				var to: Vector3 = aim.call() + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * (1.0 + S * 0.1)
				var dir = (to - from).normalized()
				sp.global_transform = Transform3D(_zbasis(-dir) * Basis.from_scale(Vector3.ONE * S * 0.45), from)
				VFX.trail(sp, S * 0.05, col.lightened(0.5), col, Color(col.r, col.g, col.b, 0), 14, 1.0)
				var dur = clampf(from.distance_to(to) / 80.0, 0.12, 0.8)
				var tw = sp.create_tween()
				tw.tween_property(sp, "global_position", to, dur)
				tw.tween_callback(func():
					sp.queue_free()
					if is_instance_valid(c):
						Combat.hit_sphere(c, to, 1.6 + S * 0.08, Jutsu._inf(c, "susanoo_tsukumo", 0.3, {"knock": 3.0, "kind": "heavy"}))
						FX.impact(to, col, 0.6 + S * 0.05)))
		Sfx.play("whoosh", c.global_position, 1.3))


# ================================================================== KAMUI (Kakashi / Obito) — ortak boyut çekişi
## Kamui geçirgenliği görünümü: modelin tüm parçaları yarı saydam (0 = normal)
static func ghost(model: Node, amount: float) -> void:
	if model == null or not is_instance_valid(model):
		return
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = amount


## Hasar vermeden: konumun çevresindeki düşmanlar
static func _foes(c: Node3D, pos: Vector3, r: float) -> Array:
	var out = []
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and not f.is_dead() and f.global_position.distance_to(pos) <= r + float(f.get("radius") if f.get("radius") != null else 0.5):
			out.append(f)
	return out


## Kamui çekişi (kanon: deldiği / odakladığı şey anında Kamui boyutuna gider). Hasar verir; zayıflamış (boss olmayan, canı
## %35 altı) hedef bütünüyle boyuta çekilir, güçlü hedefin yalnız bir parçası kopar (ağır kanama). Oyuncu hedefse öldürmez.
static func kamui_warp(c: Node3D, h: Node3D, info: Dictionary, at: Vector3) -> void:
	if not _alive(h):
		return
	kamui_vortex(at, 1.6, 1.0)
	var inf = info.duplicate()
	if h == Game.player:
		inf["dmg"] = minf(float(inf.get("dmg", 0.0)), maxf(1.0, float(h.hp) * 0.5))
	h.take_hit(inf)
	if not _alive(h):
		return
	var weak = not (h is Player) and not h.has_meta("boss") and float(h.hp) <= float(h.max_hp) * 0.35 and h.has_method("die")
	if weak:
		Combat.popup_text(_chest(h) + Vector3.UP, "Kamui boyutuna çekildi", Color(0.7, 0.55, 0.9))
		h.apply_status("stun", 1.2)
		var m = h.get("model")
		if m:
			var tw = m.create_tween()
			tw.set_parallel(true)
			tw.tween_property(m, "scale", m.scale * 0.05, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_property(m, "rotation:y", m.rotation.y + TAU * 2.0, 0.9)
		if c == Game.player:
			Game.profile["kamui_store"] = int(Game.profile.get("kamui_store", 0)) + 1
		_later(0.95, func():
			if _alive(h):
				h.die({"execute": true, "attacker": c, "kamui": true, "dmg": 9999.0})
				if is_instance_valid(h) and h.get("model"):
					h.model.visible = false)
	else:
		Combat.popup_text(_chest(h) + Vector3.UP, "Bir parçası koptu", Color(0.8, 0.6, 0.95))
		h.apply_status("bleed", 5.0)


## Kamui Shuriken (kanon, Kakashi): Susanoo, Obito'nun Mangekyō'su biçiminde dev shuriken'ler oluşturur, Kamui ile doldurup
## fırlatır; dönerek gider, değdiğini keser ve anında boyuta çeker. GERÇEK Susanoo'nun elinden atılır.
static func _kamui_shuriken_mesh(sn: Susanoo) -> MeshInstance3D:
	var mb = MB.new()
	mb.add("cyl", Vector3.ZERO, Vector3(0.28, 0.05, 0.28), Color.WHITE, Vector3.ZERO, 16)
	for k in 3:   # Obito'nun Mangekyō deseni: merkezden kıvrılan üç kanat
		var pts = []
		var rr = []
		for j in 9:
			var u = j / 8.0
			var a = TAU * k / 3.0 + u * 1.9
			pts.append(Vector3(cos(a), 0, sin(a)) * lerpf(0.1, 0.62, u))
			var w = lerpf(0.13, 0.015, u)
			rr.append(Vector2(w, 0.025))
		Loft.tube(mb, pts, rr, Color.WHITE, 6, 2, true, true, Callable(), Vector3.UP)
	mb.add("torus", Vector3.ZERO, Vector3(1.0, 0.05, 1.0), Color.WHITE, Vector3.ZERO, 24)
	return sn.chakra_mesh(mb, 1.6)


static func m_kamui_shuriken(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "kamui_shuriken")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = _aim_fn(c, tg, 20.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.1)
	_anim(c, "throw", 1.0)
	sn.hide_weapons(1.6)
	for k in 3:
		var right = k != 1
		_later(k * 0.28, func():
			if not (is_instance_valid(c) and is_instance_valid(sn)):
				return
			var arm_side = side if right else -side
			sn.pose({"arms": Susanoo.arm(right, arm_side * 0.7 + Vector3.UP * 0.35 - d * 0.3, Vector3.UP * 0.6 + d * 0.5)}, 0.4, true)
			var sh = _kamui_shuriken_mesh(sn)
			_scene().add_child(sh)
			sh.global_position = sn.hand(right)
			sh.scale = Vector3.ONE * S * 0.9
			var vortex = kamui_vortex(sh.global_position, S * 0.5, 2.0)
			_later(0.22, func():
				if not (is_instance_valid(c) and is_instance_valid(sh) and is_instance_valid(sn)):
					if is_instance_valid(sh):
						sh.queue_free()
					return
				var ad = (aim.call() - sn.bone_at("RightUpperArm" if right else "LeftUpperArm")).normalized()
				sn.pose({"arms": Susanoo.arm(right, ad, ad)}, 0.4, true)
				var from = sh.global_position
				var to: Vector3 = aim.call() + side * (k - 1) * 2.0
				var dur = clampf(from.distance_to(to) / 60.0, 0.15, 0.9)
				var o = {"sh": sh, "v": vortex}
				var tw = sh.create_tween()
				tw.tween_method(func(x: float):
					if is_instance_valid(o["sh"]):
						var p = from.lerp(to, x) + side * sin(x * PI) * (k - 1) * S * 0.6
						o["sh"].global_position = p
						o["sh"].rotation.y = x * TAU * 6.0
						if is_instance_valid(o["v"]):
							o["v"].global_position = p, 0.0, 1.0, dur)
				tw.tween_callback(func():
					sh.queue_free()
					if not is_instance_valid(c):
						return
					var inf = Jutsu._inf(c, "kamui_shuriken", 0.7, {"knock": 6.0, "kind": "heavy", "hitstop": 0.1})
					for h in _foes(c, to, 2.0 + S * 0.15):
						kamui_warp(c, h, inf, _chest(h))
					kamui_vortex(to, 1.4 + S * 0.15, 0.9)
					_shake(0.4))
				Sfx.play("blade", from, 0.7)))


## Kyōsō Enbu (kanon, Madara): Susanoo'ya bürünmüş Madara chakra kılıcını shuriken gibi döndürerek fırlatır; yolundakileri biçer,
## hedefte döner durur, sonra Susanoo'nun eline geri gelir. GERÇEK Susanoo'nun kılıcı kullanılır.
static func m_kyoso_enbu(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "kyoso_enbu")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = _aim_fn(c, tg, 22.0 + H * 0.6)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.2)
	_anim(c, "slash_c", 1.0)
	sn.hide_weapons(2.6)
	# kurulma: kılıç omuz arkasına çekilir
	sn.pose({"arms": Susanoo.arm(true, side * 0.6 - d * 0.6 + Vector3.UP * 0.4, -side * 0.5 + Vector3.UP * 0.6 - d * 0.3)}, 0.6)
	var mb = MB.new()
	mb.add("box", Vector3(0, 0, -0.85), Vector3(0.05, 0.14, 1.7), Color.WHITE)
	mb.add("cone", Vector3(0, 0, -1.8), Vector3(0.05, 0.25, 0.14), Color.WHITE, Vector3(-90, 0, 0), 4)
	mb.add("box", Vector3(0, 0, 0.05), Vector3(0.3, 0.06, 0.06), Color.WHITE)
	mb.add("cyl", Vector3(0, 0, 0.3), Vector3(0.05, 0.45, 0.05), Color.WHITE, Vector3(90, 0, 0), 8)
	var sw = sn.chakra_mesh(mb, 1.7)
	_scene().add_child(sw)
	sw.global_position = sn.hand(true)
	sw.scale = Vector3.ONE * S * 1.2
	VFX.trail(sw, S * 0.15, col.lightened(0.5), col, Color(col.r, col.g, col.b, 0.0), 22, 1.0)
	_later(0.45, func():
		if not (is_instance_valid(c) and is_instance_valid(sw) and is_instance_valid(sn)):
			if is_instance_valid(sw):
				sw.queue_free()
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad)}, 0.5, true)
		var from = sw.global_position
		var to: Vector3 = aim.call()
		var dist = from.distance_to(to)
		var go = clampf(dist / 55.0, 0.2, 0.9)
		var hits = []
		var inf = Jutsu._inf(c, "kyoso_enbu", 0.6, {"knock": 10.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.05})
		var o = {"sw": sw}
		var tw = sw.create_tween()
		# git — hedefte dönerek biç — geri dön
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]):
				var p = from.lerp(to, x) + Vector3.UP * sin(x * PI) * S * 0.4
				o["sw"].global_position = p
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 5.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2)
				if is_instance_valid(c):
					for h in Combat.hit_sphere(c, p, 1.5 + S * 0.35, inf, hits):
						hits.append(h), 0.0, 1.0, go)
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]):
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 4.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2)
				if is_instance_valid(c) and int(x * 8.0) != int((x - 0.02) * 8.0):
					Combat.hit_sphere(c, to, 1.8 + S * 0.4, Jutsu._inf(c, "kyoso_enbu", 0.25, {"knock": 4.0, "kind": "heavy", "bleed": 2.0}))
					VFX.shockwave(to, col.lightened(0.3), 3.0 + S * 0.4, 0.2)
			, 0.0, 1.0, 0.6)
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]) and is_instance_valid(sn):
				o["sw"].global_position = to.lerp(sn.hand(true), x)
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 4.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2), 0.0, 1.0, go)
		tw.tween_callback(sw.queue_free)
		Sfx.play("blade", from, 0.6))


# ------------------------------------------------------------------ Susanoo: Kai (ref Narutopedia "Susanoo: Crush")
## Susanoo'nun eli rakibe uzanır, onu kavrar ve yumruğunun içinde ezer; sonra yere fırlatır
static func m_susanoo_kai(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kai")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 6.0 + H * 1.2)
	if tg == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var aim = _aim_fn(c, tg, 4.0 + H * 0.45)
	var d = _turn(c, aim.call())
	_pj().busy(c, 1.4)
	_anim(c, "push", 1.0)
	# uzan: el rakibe açık uzanır
	var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
	sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 10.0}, 0.9)
	Sfx.play("whoosh", c.global_position, 0.6, 0.7)
	_later(0.35, func():
		if not (is_instance_valid(c) and is_instance_valid(sn) and is_instance_valid(tg)) or tg.is_dead():
			return
		# kavra: hedef yumruğun içine alınır, havaya kaldırılır
		if tg.has_method("apply_status"):
			tg.apply_status("bind", 1.6)
		var hold = sn.hand(true)
		sn.pose({"arms": Susanoo.arm(true, (d + Vector3.UP * 0.6).normalized(), (d + Vector3.UP * 0.9).normalized(), Vector3.UP), "spine": 4.0}, 1.0)
		for k in 4:
			_later(0.15 + k * 0.25, func():
				if is_instance_valid(sn) and is_instance_valid(tg) and not tg.is_dead():
					tg.global_position = sn.hand(true) - Vector3.UP * 0.9
					if tg is CharacterBody3D:
						tg.velocity = Vector3.ZERO
					tg.take_hit(Jutsu._inf(c, "susanoo_kai", 0.45, {"knock": 0.0, "launch": 0.0, "kind": "crush", "pierce_guard": true}))
					VFX.shockwave(sn.hand(true), col.lightened(0.3), S * 0.5 + 1.2, 0.2, false)
					Sfx.play("hit_heavy", tg.global_position, 0.7, 0.6))
		Combat.popup_text(hold + Vector3.UP * 1.5, "Susanoo: Kai!", col.lightened(0.3)))
	# fırlat: el aşağı savrulur, hedef yere çarpar
	_later(1.4, func():
		if not (is_instance_valid(c) and is_instance_valid(sn) and is_instance_valid(tg)) or tg.is_dead():
			return
		sn.pose({"arms": Susanoo.arm(true, (d - Vector3.UP * 0.5).normalized(), d, d)}, 0.5, true)
		tg.take_hit(Jutsu._inf(c, "susanoo_kai", 1.2, {"knock": 18.0, "launch": -10.0, "kind": "heavy", "dir": d, "hitstop": 0.1}))
		var g = Jutsu._ground(tg.global_position)
		VFX.cracks(g, S * 0.6 + 3.0)
		VFX.debris(g + Vector3.UP * 0.4, Color(0.5, 0.42, 0.32), 12, 7.0, 0.35)
		_shake(0.6))


# ================================================================== SHISUI (Shunshin no Shisui)
const SHISUI := Color(0.3, 0.95, 0.5)


## Yeni tarz tekniklerinin hasar ölçeği (2026-11-15 ölçümü: aynı kademedeki eski Mangekyō teknikleriyle aynı toplam hasara çekildi;
## dengeyi buradan ayarla, vuruş paylarına dokunma)
const POW := {"zanzo_bunshin": 5.0, "bunshun": 5.0, "uchiha_ryu_higasa_no_mai": 5.0, "susanoo_kaien": 3.8, "kotoamatsukami_kobo": 4.2, "kanseitai_susanoo_kishin": 3.8, 
	"saten": 5.0, "sain": 5.0, "muzan": 4.5, "mekkyaku": 4.8, "tenso": 4.2, 
	"raikiri_sosenko": 4.4, "raikiri_issen": 4.4, "raiju_hashiri_so": 3.4, "susanoo_kamui_raikiri": 5.0, 
	"susanoo_dan": 4.0, "susanoo_retsu": 4.0, "susanoo_nito_no_mai": 3.3, "totsuka_renzokugiri": 3.0, "enton_honoikazuchi": 1.9, "amaterasu_zanka": 2.2}


static func _inf(c: Node3D, id: String, mul: float, extra := {}) -> Dictionary:
	return Jutsu._inf(c, id, mul * float(POW.get(id, 1.0)), extra)


static func _blink(c: Node3D, to: Vector3) -> void:
	c.global_position = to
	if "velocity" in c:
		c.velocity = Vector3.ZERO
	if c.has_method("reset_physics_interpolation"):
		c.reset_physics_interpolation()


## Sıçrama boyunca darbe almaz (oyuncu); art görüntüye vurulan darbe boşa gider
static func _flicker_guard(c: Node3D, dur: float) -> void:
	if c is Player and c.combat:
		c.combat.invuln = maxf(c.combat.invuln, dur)


## Yay biçimli şerit (kesik izi / alev dalgası): yerel +Z'ye bakan, XZ düzleminde; uçlara doğru incelir
static func _arc_mesh(r: float, span: float, w: float, n := 20) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_o = Vector3.ZERO
	var prev_i = Vector3.ZERO
	for i in n + 1:
		var t = i / float(n)
		var a = (t - 0.5) * span
		var ww = w * sin(PI * t)
		var o = Vector3(sin(a) * r, 0, cos(a) * r)
		var inn = Vector3(sin(a) * (r - ww), 0, cos(a) * (r - ww))
		if i > 0:
			var t0 = (i - 1) / float(n)
			for tri in [[prev_o, o, inn, Vector2(t0, 0), Vector2(t, 0), Vector2(t, 1)], [prev_o, inn, prev_i, Vector2(t0, 0), Vector2(t, 1), Vector2(t0, 1)],
					[prev_o, inn, o, Vector2(t0, 0), Vector2(t, 1), Vector2(t, 0)], [prev_o, prev_i, inn, Vector2(t0, 0), Vector2(t0, 1), Vector2(t, 1)]]:   # iki yüz (alev malzemesi arka yüzü çizmez)
				for k in 3:
					st.set_normal(Vector3.UP)
					st.set_uv(tri[3 + k])
					st.add_vertex(tri[k])
		prev_o = o
		prev_i = inn
	return st.commit()


## Kesik izi: at'ta, dir yönüne bakan, roll kadar yatırılmış yay; büyüyüp erir. fire: alev, değilse chakra parıltısı
static func _slash_arc(at: Vector3, dir: Vector3, r: float, roll: float, dur: float, fire: bool, col := SHISUI, thick := 0.42) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _arc_mesh(r, 2.3, r * thick)
	var m: ShaderMaterial
	if fire:
		m = VFX.mat_fire("fire", 4.0, 2.0, 0.25, 1.8, 0.1, Vector3(0, 0, -1), true)
	else:
		m = VFX.mat_fire("fire", 5.0, 3.0, 0.2, 2.0, 0.05, Vector3(0, 0, -1), true)
		m.set_shader_parameter("c_core", Color(1, 1, 1))
		m.set_shader_parameter("c_hot", col.lightened(0.6))
		m.set_shader_parameter("c_mid", col)
		m.set_shader_parameter("c_edge", col.darkened(0.3))
		m.set_shader_parameter("c_line", col.darkened(0.7))
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_transform = Transform3D(_zbasis(dir) * Basis(Vector3(0, 0, 1), roll), at)
	mi.scale = Vector3.ONE * 0.55
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.15, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("erode", x), 0.2, 1.05, dur)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Sahibinin gerçek Mangekyō desenini taşıyan disk (oyuncu: takılı gözün deseni; NPC: Shisui'nin dört kollu çarkı)
static func _ms_disc(c: Node3D, size: float, billboard: bool) -> MeshInstance3D:
	var d: Dictionary = Eyes.design_for(Game.profile, "sag_goz") if c == Game.player else {}
	if d.is_empty():
		d = {"style": 13, "blades": 4, "curve": 1.0, "thick": 0.55, "inner": 0.2, "spin": 0.6}
	var vv = Eyes.design_vecs(d)
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/ms_disc.gdshader")
	m.set_shader_parameter("ms_a", vv[0])
	m.set_shader_parameter("ms_b", vv[1])
	m.set_shader_parameter("col", vv[2])
	m.set_shader_parameter("billboard", billboard)
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Zanzō Bunshin (残像分身, anime 454): Shunshin'le hedefin çevresinde beş art görüntü bırakır; her art görüntü kendi yerinden
## tantō kesiği atar (kütlesi vardır), art görüntüye gelen saldırı boşa gider. Sonunda hedefin arkasında gerçek beden belirir.
static func m_zanzo_bunshin(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 26.0)
	var center: Vector3 = tg.global_position if tg else Jutsu._ground(c.global_position + c.face_dir() * 8.0)
	var base = atan2(c.global_position.x - center.x, c.global_position.z - center.z)
	_pj().busy(c, 1.25)
	_flicker_guard(c, 1.35)
	Sfx.play("whoosh", c.global_position, 1.8)
	var wr = weakref(tg) if tg else null
	for k in 5:
		_later(0.06 + k * 0.22, func():
			if not _alive(c):
				return
			var tgt = wr.get_ref() if wr else null
			var ctr: Vector3 = tgt.global_position if tgt != null and not tgt.is_dead() else center
			var a = base + (k + 1) * TAU * 2.0 / 5.0   # yıldız sırası: karşıdan karşıya sıçrar
			var at = Jutsu._ground(ctr + Vector3(sin(a), 0, cos(a)) * 2.4)
			FX.afterimage(c, 0.55, 0.25)
			_blink(c, at + Vector3.UP * 0.05)
			var d = _turn(c, ctr)
			_anim(c, "slash_a" if k % 2 == 0 else "slash_b", 2.2)
			FX.afterimage(c, 0.8, 1.1)   # burada kalan art görüntü
			_slash_arc(at + Vector3.UP * 1.15 + d * 0.5, d, 1.5, (0.6 if k % 2 == 0 else -0.6) + k * 0.25, 0.22, false)
			Sfx.play("slash", at, 1.3 + k * 0.05, 0.7)
			Combat.hit_sphere(c, ctr + Vector3.UP, 2.2, _inf(c, "zanzo_bunshin", 0.2, {"knock": 1.5, "kind": "light", "blade": true, "hitstop": 0.03, "dir": d})))
	_later(0.06 + 5 * 0.22, func():
		if not _alive(c):
			return
		var tgt = wr.get_ref() if wr else null
		var ctr: Vector3 = tgt.global_position if tgt != null and not tgt.is_dead() else center
		var back = Jutsu._ground(ctr - Vector3(sin(base), 0, cos(base)) * 2.0)
		FX.afterimage(c, 0.6, 0.6)
		_blink(c, back + Vector3.UP * 0.05)
		_turn(c, ctr)
		VFX.screen_lines(0.25, 0.7, SHISUI))


## Bunshun (分瞬, Storm Revolution): iki kage bunshin iki yandan hedefe atılıp çarpar, gerçek Shisui arkalarından tek kesikle bitirir
static func m_bunshun(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 24.0)
	var aim = _aim_fn(c, tg, 10.0)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.0)
	_anim(c, "cast", 1.6)
	Sfx.play("poof", c.global_position, 1.2)
	var look: Dictionary = c.model.look.duplicate() if c.get("model") and "look" in c.model else {}
	for sgn in [-1.0, 1.0]:
		var cl = ShadowClone.new()
		cl.team = c.team
		cl.look = look
		_scene().add_child(cl)
		var from = Jutsu._ground(c.global_position + side * sgn * 1.6)
		cl.global_position = from
		FX.smoke_puff(from + Vector3.UP, 0.7, 8)
		cl.set_physics_process(false)
		cl.set_process(false)
		if cl.get("model") and cl.model:
			cl.model.play("run", 0.05, 1.8, true)
		var wcl = weakref(cl)
		_later(0.12, func():
			var n = wcl.get_ref()
			if n == null:
				return
			var to: Vector3 = aim.call() + side * sgn * 0.9
			to = Jutsu._ground(to)
			var dd = to - n.global_position
			dd.y = 0.0
			if dd.length() > 0.2:
				n.rotation.y = atan2(-dd.x, -dd.z)
			var tw = n.create_tween()
			tw.tween_property(n, "global_position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				var m2 = wcl.get_ref()
				if m2 == null:
					return
				if _alive(c):
					Combat.hit_sphere(c, to + Vector3.UP, 1.9, _inf(c, "bunshun", 0.25, {"knock": 2.0, "kind": "heavy", "stun": 0.5, "hitstop": 0.04, "dir": d}))
				VFX.star(to + Vector3.UP * 1.1, Color(1, 1, 1), 1.4, 0.12)
				Sfx.play("punch", to, 1.1)
				FX.smoke_puff(to + Vector3.UP, 0.8, 10)
				m2.queue_free()))
	_later(0.5, func():
		if not _alive(c):
			return
		var to: Vector3 = aim.call()
		var stand = Jutsu._ground(to - d * 1.5)
		FX.afterimage(c, 0.7, 0.4)
		_blink(c, stand + Vector3.UP * 0.05)
		_anim(c, "slash_c", 2.0)
		_slash_arc(stand + Vector3.UP * 1.2 + d * 0.6, d, 2.0, 0.35, 0.28, false)
		Sfx.play("slash", stand, 1.0)
		Combat.hit_sphere(c, to, 2.4, _inf(c, "bunshun", 0.5, {"knock": 9.0, "kind": "heavy", "blade": true, "hitstop": 0.07, "dir": d}))
		VFX.screen_lines(0.2, 0.6, SHISUI))


## Uchiha Ryū: Higasa no Mai (うちは流・日暈の舞, Storm Revolution): tantō alevle kaplanır, tek hızlı savuruşla öne doğru
## genişleyen alev halesi (güneş halesi yayı) salınır; değdiğini yakar
static func m_uchiha_ryu_higasa_no_mai(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 24.0)
	var d = _turn(c, _aim_fn(c, tg, 12.0).call())
	_pj().busy(c, 0.85)
	_anim(c, "slash_a", 1.5)
	var hand = c.global_position + Vector3.UP * 1.2 + d * 0.5
	VFX.embers(hand, Color(1.0, 0.6, 0.15), 16, 5.0, 0.5)
	Sfx.play("fire", c.global_position, 1.3)
	_later(0.22, func():
		if not _alive(c):
			return
		var from = c.global_position + Vector3.UP * 1.1 + d * 1.0
		var mi = MeshInstance3D.new()
		mi.mesh = _arc_mesh(1.0, 2.6, 0.5, 28)
		var m = VFX.mat_fire("fire", 4.5, 2.2, 0.28, 1.9, 0.14, Vector3(0, 0, -1), true)
		m.render_priority = 1
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scene().add_child(mi)
		var bas = _zbasis(d) * Basis(Vector3(0, 0, 1), 0.18)
		mi.global_transform = Transform3D(bas, from)
		var inf = _inf(c, "uchiha_ryu_higasa_no_mai", 1.0, {"knock": 7.0, "kind": "heavy", "element": "katon", "burn": 4.0, "dir": d})
		var hit: Array = []
		var tw = _tw()
		tw.tween_method(func(x: float):
			if not is_instance_valid(mi):
				return
			var R = 1.6 + x * 5.5   # hale ilerledikçe açılır
			var pos = from + d * x * 20.0
			mi.global_transform = Transform3D(bas * Basis.from_scale(Vector3(R, 1.0, R * 0.55)), pos)
			m.set_shader_parameter("erode", 0.28 + maxf(0.0, x - 0.7) * 2.6)
			if _alive(c):
				for f in Combat.hit_sphere(c, pos + d * R * 0.5, R * 0.75, inf, hit):
					hit.append(f)
					VFX.embers(_chest(f), Color(1.0, 0.55, 0.12), 14, 7.0, 0.6), 0.0, 1.0, 0.55)
		tw.tween_callback(mi.queue_free)
		Sfx.play("whoosh", from, 0.8))


## Kotoamatsukami: Kōbō (別天神・光芒, Storm Revolution): hedef genjutsuya düşer; tepesinde dev bir Mangekyō belirir ve gözden
## inen ışık huzmeleri onu vurur. Genjutsu olduğu için göz göze gelmeyen / direnen hedefte tutmaz.
static func m_kotoamatsukami_kobo(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 30.0)
	_pj().busy(c, 0.9)
	_anim(c, "cast", 1.0)
	if tg == null:
		if c is Player:
			Hud.msg("Kotoamatsukami: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	_turn(c, tg.global_position)
	var gm = Eyes.genjutsu_land(c, tg, true)
	if gm <= 0.0:
		return
	var red = Color(0.95, 0.15, 0.2)
	VFX.star(Jutsu._mouth(c) + Vector3.UP * 0.12, red, 1.0, 0.25)
	Sfx.play("genjutsu", tg.global_position, 0.8)
	tg.apply_status("stun", 2.4 * gm)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var top = tg.global_position + Vector3.UP * (H + 9.0)
	# gökteki göz: sahibinin Mangekyō deseni, aşağı bakar
	var eye = _ms_disc(c, 9.0, false)
	_scene().add_child(eye)
	eye.global_position = top
	eye.rotation.x = PI * 0.5
	var em: ShaderMaterial = eye.material_override
	em.set_shader_parameter("fade", 0.0)
	eye.scale = Vector3.ONE * 0.2
	var et = eye.create_tween()
	et.set_parallel(true)
	et.tween_property(eye, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	et.tween_method(func(x: float): em.set_shader_parameter("fade", x), 0.0, 1.0, 0.25)
	if tg == Game.player and Game.world:
		Game.world.env.flash_tint(Color(0.85, 0.05, 0.05, 0.2), 1.6)
	var wr = weakref(tg)
	var inf = _inf(c, "kotoamatsukami_kobo", 0.2, {"knock": 0.5, "kind": "light", "hitstop": 0.02})
	for k in 5:
		_later(0.45 + k * 0.28, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not is_instance_valid(eye):
				return
			var off = Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * (1.6 if k < 4 else 0.0)
			var hitp: Vector3 = n.global_position + off
			var src: Vector3 = eye.global_position + off * 1.4
			var beam = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 0.55   # yukarıdan inerken daralan huzme
			cm.height = 1.0
			cm.radial_segments = 12
			cm.cap_top = false
			cm.cap_bottom = false
			beam.mesh = cm
			var bm = VFX.mat_fire("fire", 9.0, 1.2, 0.12, 2.4, 0.03, Vector3(0, -1, 0), true)   # akan ışık: beyaz çekirdek, altın kenar
			bm.set_shader_parameter("c_core", Color(1, 1, 1))
			bm.set_shader_parameter("c_hot", Color(1.0, 0.97, 0.85))
			bm.set_shader_parameter("c_mid", Color(1.0, 0.85, 0.5))
			bm.set_shader_parameter("c_edge", Color(1.0, 0.6, 0.25))
			bm.set_shader_parameter("c_line", Color(0.9, 0.35, 0.15))
			beam.material_override = bm
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_scene().add_child(beam)
			_seg(beam, src, hitp, 0.05)
			var wide = 0.4 if k < 4 else 1.1
			var bt = beam.create_tween()
			bt.tween_method(func(x: float):
				if is_instance_valid(beam):
					_seg(beam, src, hitp, 0.05 + x * wide), 0.0, 1.0, 0.1)
			bt.tween_interval(0.12)
			bt.tween_method(func(x: float):
				if is_instance_valid(beam):
					_seg(beam, src, hitp, 0.05 + x * wide), 1.0, 0.0, 0.14)
			bt.tween_callback(beam.queue_free)
			VFX.shockwave(hitp + Vector3.UP * 0.1, Color(1.0, 0.85, 0.6), 2.5 * wide + 1.0, 0.3)
			VFX.star(hitp + Vector3.UP, Color(1.0, 0.95, 0.8), 2.0 * wide + 1.0, 0.15)
			Sfx.play("chakra", hitp, 1.5, 0.6)
			if _alive(c):
				n.take_hit(inf.merged({"dir": Vector3.DOWN, "attacker": c}, true)))
	_later(2.1, func():
		if is_instance_valid(eye):
			var ft = eye.create_tween()
			ft.tween_method(func(x: float): em.set_shader_parameter("fade", x), 1.0, 0.0, 0.3)
			ft.tween_callback(eye.queue_free))


## Kotoamatsukami: Zankō (別天神・残光, Shinobi Striker): çevredeki bütün düşmanlara aynı anda uygulanır; hareketleri karışır,
## görüşleri kapanır (hedeflerini yitirirler). Hasar vermez.
static func m_kotoamatsukami_zanko(c: Node3D, _t: Node3D) -> void:
	_pj().busy(c, 0.7)
	_anim(c, "cast", 1.0)
	var red = Color(0.95, 0.15, 0.2)
	var eyep = Jutsu._mouth(c) + Vector3.UP * 0.12
	VFX.star(eyep, red, 1.6, 0.3)
	if c == Game.player:
		VFX.screen_lines(0.35, 0.8, red)
	Sfx.play("genjutsu", c.global_position, 1.1)
	var n = 0
	for f in Jutsu.get_tree().get_nodes_in_group("fighters"):
		if not is_instance_valid(f) or f.is_dead() or not Combat.hostile(c, f):
			continue
		if f.global_position.distance_to(c.global_position) > 28.0:
			continue
		var gm = Eyes.genjutsu_land(c, f, false)
		if gm <= 0.0:
			continue
		n += 1
		var dur = (3.0 if f.has_meta("boss") or f is TailedBeast else 6.0) * gm
		if f == Game.player:
			f.apply_status("kokuangyo", dur * 0.6)
		else:
			if f.has_method("lose_target"):
				f.lose_target(dur)
			f.apply_status("slow", dur)
		# art ışıltı: kurbanın gözünün önünde sahibinin Mangekyō'su yanar, etki sürdükçe başının üstünde soluk durur
		var H = float(f.get("height")) if f.get("height") != null else 1.8
		var mark = _ms_disc(c, 0.7, true)
		f.add_child(mark)
		mark.position = Vector3.UP * (H * 0.9)
		var mm: ShaderMaterial = mark.material_override
		var mt = mark.create_tween()
		mt.tween_method(func(x: float):
			mm.set_shader_parameter("fade", minf(1.0, x * 3.0))
			mark.scale = Vector3.ONE * (2.2 - 1.6 * minf(1.0, x * 2.0))
			mark.position = Vector3.UP * (H * 0.9 + x * (H * 0.25 + 0.25)), 0.0, 1.0, 0.6)
		mt.tween_method(func(x: float): mm.set_shader_parameter("fade", x), 1.0, 0.45, 0.4)
		mt.tween_interval(maxf(0.1, dur - 1.4))
		mt.tween_method(func(x: float): mm.set_shader_parameter("fade", x), 0.45, 0.0, 0.4)
		mt.tween_callback(mark.queue_free)
		Combat.popup_text(f.global_position + Vector3.UP * (H + 0.6), "Zankō", Color(1.0, 0.5, 0.5))
	if c is Player and n == 0:
		Hud.msg("Kotoamatsukami: Zankō — çevrede etkilenecek kimse yok.", Color(0.8, 0.8, 0.8))


## Susanoo'nun matkap mızrağı (Shisui'nin Susanoo'su): el hizasında, aim'e doğru
static func _sus_drill(sn: Susanoo, S: float, fire: bool) -> MeshInstance3D:
	var mb = MB.new()
	Susanoo._drill(mb, Vector3.ZERO, Vector3(0, 0, -1), 2.6, 0.34, Color.WHITE)
	var mi: MeshInstance3D
	if fire:
		mi = MeshInstance3D.new()
		mi.mesh = mb.build(null)
		mi.material_override = VFX.mat_fire("fire", 5.0, 2.4, 0.22, 1.9, 0.16, Vector3(0, 0, 1), true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mi = sn.chakra_mesh(mb, 1.5)
	_scene().add_child(mi)
	mi.scale = Vector3.ONE * S
	return mi


## Susanoo: Kaien (須佐能乎・廻炎, Storm 4): Susanoo'nun matkap mızrağı alev alır; dönerek hedefe saplanır, döndükçe deler ve yakar
static func m_susanoo_kaien(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kaien")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 16.0 + H * 1.5)
	var aim = _aim_fn(c, tg, 6.0 + H * 0.8)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.7)
	_anim(c, "cast", 0.9)
	sn.hide_weapons(2.0)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.5 + Vector3.UP * 0.3 + side * 0.5, d * 0.4 + Vector3.UP * 0.2), "spine": -14.0}, 0.5, true)   # geri çekiş
	var dr = _sus_drill(sn, S * 0.55, true)
	var L = 2.6 * S * 0.55   # matkabın boyu
	var st = {"spin": 0.0, "reach": 0.0}
	sn.follow_fx(dr, 1.75, func(): return sn.hand(true) + d * st["reach"] * S, func(): return aim.call() - dr.global_position)
	var spin_tw = _tw()
	spin_tw.tween_method(func(x: float):
		if is_instance_valid(dr):
			dr.rotate_object_local(Vector3(0, 0, 1), 0.55), 0.0, 1.0, 1.7)
	Sfx.play("fire", c.global_position, 0.8)
	_later(0.5, func():
		if not is_instance_valid(sn) or not _alive(c):
			return
		sn.pose({"arms": Susanoo.arm(true, d * 0.95 + Vector3.UP * 0.05, d), "spine": 16.0}, 1.1, true)   # saplama
		var rt = _tw()
		rt.tween_method(func(x: float): st["reach"] = x, 0.0, 0.5, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_shake(0.5))
	var inf = _inf(c, "susanoo_kaien", 0.14, {"knock": 0.6, "kind": "heavy", "element": "katon", "burn": 3.0, "hitstop": 0.02})
	for k in 7:
		_later(0.62 + k * 0.12, func():
			if not is_instance_valid(dr) or not _alive(c):
				return
			var ax: Vector3 = (aim.call() - dr.global_position).normalized()
			var tip: Vector3 = dr.global_position + ax * L
			var got: Array = []   # gövde boyunca: matkabın değdiği herkes (aynı vuruşta bir kez)
			for u in [0.35, 0.65, 0.95]:
				for f in Combat.hit_sphere(c, dr.global_position + ax * L * u, 1.2 + S * 0.3, inf.merged({"dir": d, "knock": 12.0 if k == 6 else 0.6}, true), got):
					got.append(f)
			VFX.embers(tip, Color(1.0, 0.6, 0.15), 12, 9.0, 0.5)
			if k % 2 == 0:
				VFX.shockwave(tip, Color(1.0, 0.55, 0.15), 2.0 + S, 0.2, false, -d)
				Sfx.play("fire", tip, 1.4, 0.5))
	_later(1.75, func():
		if is_instance_valid(dr):
			dr.queue_free())


## Kanseitai Susanoo: Kishin (完成体須佐能乎・鬼神, Shinobi Striker): Mükemmel Susanoo göğe sıçrar ve matkap kılıcını
## aşağı çevirip hedefin üstüne iner; indiği yer çöker
static func m_kanseitai_susanoo_kishin(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "kanseitai_susanoo_kishin")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var land: Vector3 = Jutsu._ground(tg.global_position if tg else c.global_position + c.face_dir() * (14.0 + H * 0.5))
	var d = _turn(c, land)
	var from = c.global_position
	_pj().busy(c, 2.1)
	_flicker_guard(c, 2.0)
	_anim(c, "jump", 1.0)
	sn.hide_weapons(2.3)
	sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.9 + d * 0.2, Vector3.UP) + Susanoo.arm(false, Vector3.UP * 0.9 + d * 0.2, Vector3.UP), "spine": -8.0}, 1.1, true)
	var dr = _sus_drill(sn, S * 1.25, false)
	sn.follow_fx(dr, 2.2, func(): return sn.hand(true).lerp(sn.hand(false), 0.5), func(): return Vector3.DOWN * 4.0 + d * 0.4, d)
	var apex = from.lerp(land, 0.55) + Vector3.UP * (10.0 + H * 0.9)
	VFX.shockwave(from + Vector3.UP * 0.2, sn.color(), 6.0 + S * 2.0, 0.4)
	Sfx.play("whoosh", from, 0.6)
	var tw = _tw()
	tw.tween_method(func(x: float):
		if _alive(c):
			_blink(c, from.lerp(apex, x)), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		if is_instance_valid(sn):
			sn.pose({"arms": Susanoo.arm(true, Vector3.DOWN * 0.8 + d * 0.3, Vector3.DOWN) + Susanoo.arm(false, Vector3.DOWN * 0.8 + d * 0.3, Vector3.DOWN), "spine": 22.0}, 1.0, true))
	tw.tween_method(func(x: float):
		if _alive(c):
			_blink(c, apex.lerp(land + Vector3.UP * 0.1, x))
			if is_instance_valid(dr):
				dr.rotate_object_local(Vector3(0, 0, 1), 0.7), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not _alive(c):
			return
		var R = 5.0 + S * 2.2
		Combat.hit_sphere(c, land + Vector3.UP, R, _inf(c, "kanseitai_susanoo_kishin", 1.0, {"knock": 16.0, "kind": "heavy", "hard_down": true, "hitstop": 0.1}))
		VFX.cracks(land, R * 1.6)
		VFX.shockwave(land + Vector3.UP * 0.2, sn.color(), R * 1.2, 0.5)
		VFX.debris(land + Vector3.UP * 0.5, Color(0.5, 0.42, 0.32), 26, 16.0, 0.9)
		_shake(1.6)
		Sfx.play("boom", land, 0.7))
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(dr):
			dr.queue_free())


# ================================================================== OBITO (Kamui: geçirgenlik, ışınlanma, bilek zincirleri)
static var _iron_mat: StandardMaterial3D
static func _iron() -> StandardMaterial3D:
	if _iron_mat == null:
		_iron_mat = StandardMaterial3D.new()
		_iron_mat.albedo_color = Color(0.2, 0.2, 0.23)
		_iron_mat.metallic = 0.8
		_iron_mat.roughness = 0.35
	return _iron_mat


## Demir zincir a -> b (Obito'nun bilek zinciri); life sn sonra kalkar
static func _chain(a: Vector3, b: Vector3, life: float, sag := 0.25, grow := 0.1) -> Node3D:
	var h = Node3D.new()
	_scene().add_child(h)
	Jutsu._chain_line(h, a, b, sag, grow, _iron())
	_later(life, func():
		if is_instance_valid(h):
			h.queue_free())
	return h


## Hedefin gövdesine dolanan zincir halkası
static func _chain_wrap(tg: Node3D, life: float) -> void:
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var r = 0.42 * H / 1.8
	for row in 2:
		var y = tg.global_position + Vector3.UP * H * (0.5 + row * 0.16)
		for k in 6:
			var a0 = k * TAU / 6.0
			var a1 = (k + 1) * TAU / 6.0
			_chain(y + Vector3(cos(a0), 0, sin(a0)) * r, y + Vector3(cos(a1), 0, sin(a1)) * r, life, 0.0, 0.05)


## Kamui ile ışınlan: çıkış ve varış noktasında küçük girdap
static func _kamui_tp(c: Node3D, to: Vector3) -> void:
	kamui_vortex(c.global_position + Vector3.UP * 1.1, 0.8, 0.45)
	_blink(c, to)
	kamui_vortex(to + Vector3.UP * 1.1, 0.8, 0.45)
	Sfx.play("th_teleport", to, 1.3, 0.6)


## Hedefi a -> b taşı (fırlatma / yere çakma); yay yüksekliği arc. Taşınırken bağlıdır.
static func _carry(tg: Node3D, to: Vector3, dur: float, arc := 0.0) -> void:
	if not _alive(tg):
		return
	var from = tg.global_position
	tg.apply_status("bind", dur + 0.15)
	var wr = weakref(tg)
	var tw = _tw()
	tw.tween_method(func(x: float):
		var n = wr.get_ref()
		if n == null or n.is_dead():
			return
		n.global_position = from.lerp(to, x) + Vector3.UP * sin(x * PI) * arc
		if n is CharacterBody3D:
			n.velocity = Vector3.ZERO, 0.0, 1.0, dur)


## Kamui geçirgenliği (teknik boyunca): yarı saydam görünür, darbe almaz
static func _phase(c: Node3D, dur: float) -> void:
	_flicker_guard(c, dur)
	ghost(c.get("model"), 0.55)
	var wr = weakref(c)
	_later(dur, func():
		var n = wr.get_ref()
		if n != null:
			ghost(n.get("model"), 0.0))


## Saten (鎖天, Storm): Obito geçirgen hâlde rakibin içinden geçer; bileklerindeki zincir rakibe dolanır. Zincirle havaya
## fırlatır, Kamui ile tepesine ışınlanıp yumrukla yere çakar. (Kanon: maskeli adamın Minato'ya karşı zinciri.)
static func m_saten(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 14.0)
	if tg == null:
		if c is Player:
			Hud.msg("Saten: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = _turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var big = H > 4.0   # dev hedef havaya kaldırılamaz: zincir dolanır, tepeden yumruk iner
	_pj().busy(c, 1.7)
	_phase(c, 0.45)
	_anim(c, "dash", 1.4)
	var from = c.global_position
	var past = Jutsu._ground(tg.global_position + d * (2.4 + H * 0.2))
	var tw = _tw()
	tw.tween_method(func(x: float):
		if _alive(c):
			_blink(c, from.lerp(past, x)), 0.0, 1.0, 0.3)
	kamui_vortex(_chest(tg), 0.7, 0.5)
	Sfx.play("whoosh", from, 1.4)
	var wr = weakref(tg)
	_later(0.32, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		_turn(c, n.global_position)
		_anim(c, "cast_out", 1.5)
		_chain_wrap(n, 0.5)
		_chain(c.global_position + Vector3.UP * 1.1, _chest(n), 0.5)
		n.apply_status("bind", 0.6)
		n.take_hit(_inf(c, "saten", 0.25, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
		Sfx.play("chain", n.global_position, 1.0))
	_later(0.8, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		_anim(c, "slash_c", 1.6)   # zinciri yukarı savurur
		if not big:
			_carry(n, n.global_position + Vector3.UP * 6.5, 0.32)
		_later(0.12, func():
			var m = wr.get_ref()
			if m != null and _alive(c):
				_chain(c.global_position + Vector3.UP * 1.3, _chest(m), 0.3, 0.1, 0.05))
		Sfx.play("swing_chain", c.global_position, 1.0))
	_later(1.25, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		var top = n.global_position + Vector3.UP * (H + 0.6)
		_kamui_tp(c, top)
		_anim(c, "cross", 1.6)
		var g = Jutsu._ground(n.global_position)
		if not big:
			_carry(n, g, 0.14)
		_later(0.15, func():
			var m = wr.get_ref()
			if not _alive(c):
				return
			if m != null and not m.is_dead():
				m.take_hit(_inf(c, "saten", 0.75, {"knock": 4.0, "launch": -12.0, "kind": "heavy", "hard_down": true, "hitstop": 0.09, "dir": Vector3.DOWN}))
			VFX.cracks(g, 3.5)
			VFX.debris(g + Vector3.UP * 0.3, Color(0.5, 0.42, 0.32), 12, 8.0, 0.4)
			_shake(0.6)
			Sfx.play("hit_heavy", g, 0.8)
			_blink(c, Jutsu._ground(g - d * 1.6) + Vector3.UP * 0.05)))


## Sain (鎖引, Storm): bilek zinciri uzaktaki rakibe dolanır; Obito onu zincirle iki kez yere savurur, sonra Kamui ile arkasına
## ve üstüne ışınlanıp dönen tekmeyle indirir
static func m_sain(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 18.0)
	if tg == null:
		if c is Player:
			Hud.msg("Sain: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = _turn(c, tg.global_position)
	var side = d.cross(Vector3.UP).normalized()
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var big = H > 4.0
	_pj().busy(c, 2.0)
	_anim(c, "throw", 1.5)
	var hand = func() -> Vector3: return c.global_position + Vector3.UP * 1.3 + d * 0.4
	_chain(hand.call(), _chest(tg), 0.42, 0.3, 0.14)
	Sfx.play("swing_chain", c.global_position, 1.1)
	var wr = weakref(tg)
	var base = tg.global_position
	_later(0.18, func():
		var n = wr.get_ref()
		if n != null and not n.is_dead():
			_chain_wrap(n, 0.25)
			n.apply_status("bind", 1.6)
			Sfx.play("chain", n.global_position, 1.1))
	for k in 2:
		_later(0.42 + k * 0.5, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not _alive(c):
				return
			_turn(c, n.global_position)
			_anim(c, "slash_a" if k == 0 else "slash_b", 1.3)
			var to = Jutsu._ground(base + side * (3.2 if k == 0 else -3.2) - d * 1.0)
			if not big:
				_carry(n, to, 0.34, 3.4)
			_chain(hand.call(), n.global_position + Vector3.UP * (H * 0.5 + 2.2), 0.3, 0.2, 0.06)
			Sfx.play("swing_chain", c.global_position, 0.9 + k * 0.15)
			_later(0.35, func():
				var m = wr.get_ref()
				if m == null or m.is_dead() or not _alive(c):
					return
				m.take_hit(_inf(c, "sain", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "hitstop": 0.06, "pierce_guard": true, "dir": Vector3.DOWN}))
				m.apply_status("bind", 0.6)
				VFX.cracks(m.global_position, 2.6)
				VFX.debris(m.global_position + Vector3.UP * 0.3, Color(0.5, 0.42, 0.32), 8, 7.0, 0.35)
				_chain(hand.call(), _chest(m), 0.12, 0.15, 0.02)
				_shake(0.4)
				Sfx.play("hit_chain", m.global_position, 0.9)))
	_later(1.5, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		var bd = n.global_position - c.global_position
		bd.y = 0.0
		bd = bd.normalized() if bd.length() > 0.2 else d
		_kamui_tp(c, n.global_position + bd * 1.0 + Vector3.UP * (H + 1.2))
		_turn(c, n.global_position)
		_anim(c, "fin_c", 1.8)
		var g = Jutsu._ground(n.global_position)
		var tw = _tw()
		var p0 = c.global_position
		tw.tween_method(func(x: float):
			if _alive(c):
				_blink(c, p0.lerp(g - bd * 0.2 + Vector3.UP * (H * 0.8), x))
				if c.get("model"):
					c.model.rotation.y += 0.9, 0.0, 1.0, 0.16)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not _alive(c):
				return
			if c.get("model"):
				c.model.rotation.y = 0.0
			if m != null and not m.is_dead():
				m.take_hit(_inf(c, "sain", 0.4, {"knock": 9.0, "launch": -8.0, "kind": "heavy", "hard_down": true, "hitstop": 0.08, "dir": -bd}))
				VFX.star(_chest(m), Color(1, 1, 1), 2.0, 0.14)
			Sfx.play("hit_heavy", g, 1.0)
			_blink(c, Jutsu._ground(g + bd * 1.4) + Vector3.UP * 0.05)))


## Muzan (無惨, Storm): Obito Kamui ile kaybolur, rakibin tam tepesinde belirir ve üstüne çöküp kunaiyi saplar. Uzaktan başlar.
static func m_muzan(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 45.0)
	if tg == null:
		if c is Player:
			Hud.msg("Muzan: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	_turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	_pj().busy(c, 0.95)
	_flicker_guard(c, 0.7)
	_anim(c, "cast", 2.0)
	kamui_vortex(c.global_position + Vector3.UP * 1.1, 1.0, 0.5)
	Sfx.play("th_teleport", c.global_position, 1.1, 0.7)
	ghost(c.get("model"), 1.0)   # girdaba çekilir: görünmez
	var wr = weakref(tg)
	_later(0.3, func():
		if not _alive(c):
			return
		ghost(c.get("model"), 0.0)
		var n = wr.get_ref()
		if n == null or n.is_dead():
			return
		var top = n.global_position + Vector3.UP * (H + 6.0)
		kamui_vortex(top + Vector3.UP * 1.0, 1.1, 0.5)
		_blink(c, top)
		_anim(c, "fall", 1.0)
		var tw = _tw()
		tw.tween_interval(0.12)
		tw.tween_method(func(x: float):
			var m = wr.get_ref()
			if _alive(c) and m != null:
				_blink(c, top.lerp(m.global_position + Vector3.UP * (H * 0.75), x)), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not _alive(c) or m == null or m.is_dead():
				return
			_anim(c, "slash_c", 2.0)
			var g = Jutsu._ground(m.global_position)
			m.take_hit(_inf(c, "muzan", 1.0, {"knock": 3.0, "launch": -10.0, "kind": "heavy", "blade": true, "bleed": 4.0, "hard_down": true, "hitstop": 0.1, "dir": Vector3.DOWN}))
			VFX.star(_chest(m) + Vector3.UP * 0.4, Color(1, 1, 1), 2.4, 0.14)
			VFX.cracks(g, 2.4)
			_shake(0.5)
			Sfx.play("hit_blade", g, 0.9)
			var back = m.global_position - c.global_position
			back.y = 0.0
			_blink(c, Jutsu._ground(g - (back.normalized() if back.length() > 0.1 else c.face_dir()) * 1.4) + Vector3.UP * 0.05)))


## Mekkyaku (滅却, Storm): Obito yumruk ve tekme yağdırır; her darbenin arasında geçirgenleşir, rakibin karşılığı içinden geçer
static func m_mekkyaku(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 9.0)
	if tg == null:
		if c is Player:
			Hud.msg("Mekkyaku: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d0 = _turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var reach = 1.3 + H * 0.15
	_pj().busy(c, 1.75)
	_flicker_guard(c, 1.7)
	var wr = weakref(tg)
	var base = atan2(-d0.x, -d0.z)
	var angs = [0.0, 2.2, -1.9, 3.14, 1.1, -0.4]   # hedefin çevresinde: ön, sol arka, sağ arka, arka, sol, ön
	var anims = ["jab", "cross", "hook", "jab", "hook", "cross"]
	for k in 6:
		_later(0.05 + k * 0.27, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not _alive(c):
				ghost(c.get("model") if is_instance_valid(c) else null, 0.0)
				return
			var a = base + angs[k]
			var at = Jutsu._ground(n.global_position + Vector3(sin(a), 0, cos(a)) * reach)
			if k > 0:
				kamui_vortex(c.global_position + Vector3.UP * 1.1, 0.55, 0.35)
			_blink(c, at + Vector3.UP * 0.05)
			var d = _turn(c, n.global_position)
			ghost(c.get("model"), 0.0)   # vururken katı
			_anim(c, anims[k], 2.0)
			var last = k == 5
			n.take_hit(_inf(c, "mekkyaku", 0.3 if last else 0.14, {"knock": 11.0 if last else 0.3, "launch": 3.0 if last else 0.0, "kind": "heavy" if last else "light",
				"stun": 0.0 if last else 0.35, "hitstop": 0.07 if last else 0.03, "dir": d}))
			VFX.star(_chest(n), Color(1, 1, 1), 1.6 if last else 1.0, 0.1)
			Sfx.play("punch", n.global_position, 1.0 + k * 0.05, 0.8)
			if last:
				_shake(0.4)
			else:
				_later(0.13, func():
					if _alive(c):
						ghost(c.get("model"), 0.6)))   # darbe arası geçirgen
	_later(1.75, func():
		if is_instance_valid(c):
			ghost(c.get("model"), 0.0))


## Tensō (転葬, Storm): rakip Kamui boyutuna çekilir; Obito çevreye kibaku fuda saçar ve rakibi patlayan mühürlerin tam
## ortasına geri bırakır. Dev hedef boyuta sığmaz: yalnız mühürler patlar.
static func m_tenso(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 12.0)
	if tg == null:
		if c is Player:
			Hud.msg("Tensō: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = _turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var fits = H <= 4.0 and not (tg is TailedBeast)
	_pj().busy(c, 1.5)
	_anim(c, "cast", 1.2)
	var P = Jutsu._ground(tg.global_position)
	var wr = weakref(tg)
	var mdl = tg.get("model")
	var s0: Vector3 = mdl.scale if mdl != null and is_instance_valid(mdl) else Vector3.ONE
	kamui_vortex(_chest(tg), 1.5, 0.75)
	Sfx.play("th_teleport", P, 0.8)
	if fits:
		tg.apply_status("bind", 1.5)
		if mdl != null and is_instance_valid(mdl):
			var tw = mdl.create_tween()
			tw.set_parallel(true)
			tw.tween_property(mdl, "scale", s0 * 0.04, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_property(mdl, "rotation:y", mdl.rotation.y + TAU * 2.0, 0.5)
			tw.chain().tween_callback(func(): mdl.visible = false)
	# mühürler: rakibin durduğu yerin çevresine halka
	_later(0.35, func():
		if not _alive(c):
			return
		_anim(c, "throw", 1.6)
		var from = c.global_position + Vector3.UP * 1.3 + d * 0.4
		for k in 7:
			var a = k * TAU / 6.0
			var to = P + (Vector3(cos(a), 0, sin(a)) * 1.5 if k < 6 else Vector3.ZERO) + Vector3.UP * 0.03
			load("res://scripts/combat/keyed_combos.gd")._fly_tag(c, from, to, 0.4 + k * 0.02, 0.0)
		Sfx.play("throw", c.global_position, 1.2))
	_later(1.0, func():
		var n = wr.get_ref()
		if n == null or not fits:
			return
		if mdl != null and is_instance_valid(mdl):
			mdl.visible = true
			mdl.scale = s0
		if n.is_dead():
			return
		n.global_position = P
		kamui_vortex(P + Vector3.UP * 1.1, 1.2, 0.4))
	_later(1.14, func():
		if not _alive(c):
			return
		VFX.explosion(P + Vector3.UP * 0.6, 1.5)
		Combat.hit_sphere(c, P + Vector3.UP * 0.8, 4.2, _inf(c, "tenso", 1.0, {"knock": 13.0, "launch": 6.0, "kind": "heavy", "burn": 3.0, "hitstop": 0.08}))
		_shake(1.0)
		Sfx.play("boom", P, 1.0))


# ================================================================== KAKASHI (Raikiri + Kamui)
const RAI := Color(0.6, 0.82, 1.0)


## Elde şimşek kütlesi (Raikiri): kemiğe bağlı, dur sn
static func _hand_orb(c: Node3D, right: bool, dur: float, size := 0.45) -> void:
	var ba = _pj().bone_attach(c, "RightHand" if right else "LeftHand")
	if ba == null:
		return
	ba.add_child(VFX.lightning_ball(size, RAI))
	var a = Arcs.new()
	a.color = RAI
	a.radius = 0.9
	a.count = 6
	a.width = 0.03
	ba.add_child(a)
	_pj().free_after(dur, ba)


## Önü açık mesafe (duvara / kayaya kadar): atılışlar yapının içine girmesin
static func _free_dist(from: Vector3, d: Vector3, maxd: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(from, from + d * maxd, 1)
	var r = _scene().get_world_3d().direct_space_state.intersect_ray(q)
	return maxf(0.0, from.distance_to(r["position"]) - 0.8) if not r.is_empty() else maxd


static func _dash_to(c: Node3D, to: Vector3, dur: float) -> void:
	var from = c.global_position
	var tw = _tw()
	tw.tween_method(func(x: float):
		if _alive(c):
			_blink(c, from.lerp(to, x)), 0.0, 1.0, dur)


static func _rai_burst(at: Vector3, n: int, r: float) -> void:
	for k in n:
		VFX.bolt(at, at + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() * r, RAI.lightened(0.3), 0.06, 0.22, 2)
	VFX.star(at, Color(0.9, 0.95, 1.0), r * 0.9, 0.14)


## Raikiri: Sōsenkō (雷切・双穿光, Storm): iki elde birer Raikiri; hedefe koşar, birini saplar, hemen ardından ötekini
static func m_raikiri_sosenko(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 22.0)
	var aim = _aim_fn(c, tg, 8.0)
	var d = _turn(c, aim.call())
	_pj().busy(c, 1.25)
	_anim(c, "cast", 1.4)
	_hand_orb(c, true, 1.0)
	_hand_orb(c, false, 1.3)
	Sfx.play("chidori", c.global_position, 1.1)
	for k in 5:
		_later(0.05 + k * 0.06, func():
			if _alive(c):
				for r in [true, false]:
					var hp = _pj().hand_pos(c, r)
					VFX.bolt(hp, Jutsu._ground(hp + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))), RAI, 0.05, 0.12, 2))
	_later(0.36, func():
		if not _alive(c):
			return
		var to: Vector3 = aim.call()
		to.y = c.global_position.y
		var dd = to - c.global_position
		var L = minf(maxf(0.0, dd.length() - 1.4), _free_dist(c.global_position + Vector3.UP, d, 22.0))
		_anim(c, "dash", 1.6)
		FX.afterimage(c, 0.5, 0.3)
		_dash_to(c, Jutsu._ground(c.global_position + d * L) + Vector3.UP * 0.05, 0.2))
	for k in 2:
		_later(0.6 + k * 0.3, func():
			if not _alive(c):
				return
			var dn = _turn(c, aim.call())
			_anim(c, "cross" if k == 0 else "jab", 1.8)
			var at = c.global_position + Vector3.UP * 1.1 + dn * 1.3
			var last = k == 1
			Combat.hit_sphere(c, at, 2.0, _inf(c, "raikiri_sosenko", 0.6 if last else 0.4, {"knock": 15.0 if last else 0.5, "launch": 3.0 if last else 0.0, "kind": "heavy",
				"element": "raiton", "stun": 0.4 if last else 0.6, "hitstop": 0.1 if last else 0.06, "pierce_guard": true, "dir": dn}))
			_rai_burst(at, 6 if last else 4, 3.0 if last else 2.0)
			if last:
				VFX.cracks(Jutsu._ground(at), 3.0)
				_shake(0.6)
			Sfx.play("zap", at, 1.0 + k * 0.2))


## Raikiri Issen (雷切一閃, Storm): Raikiri ile göz açıp kapayana dek rakibe varır, onu kavrayıp şimşekle yerde uzun uzun
## sürükler ve sonunda fırlatır
static func m_raikiri_issen(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 26.0)
	if tg == null:
		if c is Player:
			Hud.msg("Raikiri Issen: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = _turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var big = H > 4.0
	_pj().busy(c, 1.7)
	_flicker_guard(c, 0.5)
	_anim(c, "cast", 1.6)
	_hand_orb(c, true, 1.6, 0.5)
	Sfx.play("chidori", c.global_position, 1.3)
	var wr = weakref(tg)
	_later(0.3, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		d = _turn(c, n.global_position)
		var gap = c.global_position.distance_to(n.global_position)
		FX.afterimage(c, 0.6, 0.35)
		_anim(c, "dash", 2.0)
		_dash_to(c, Jutsu._ground(c.global_position + d * maxf(0.0, gap - 1.2 - H * 0.2)) + Vector3.UP * 0.05, 0.1)
		if c == Game.player:
			VFX.screen_lines(0.2, 0.8, RAI))
	_later(0.42, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not _alive(c):
			return
		n.take_hit(_inf(c, "raikiri_issen", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "element": "raiton", "hitstop": 0.08, "pierce_guard": true, "dir": d}))
		_rai_burst(_chest(n), 4, 2.0)
		if big or n.is_dead():
			return
		# sürükleme: önündeki açık mesafe kadar (en fazla 13 m)
		var L = minf(13.0, _free_dist(c.global_position + Vector3.UP, d, 14.0))
		var p0 = c.global_position
		n.apply_status("bind", 1.0)
		var st = {"k": 0}
		var tw = _tw()
		tw.tween_method(func(x: float):
			var m = wr.get_ref()
			if not _alive(c) or m == null or m.is_dead():
				return
			var cp = Jutsu._ground(p0 + d * L * x)
			_blink(c, cp + Vector3.UP * 0.05)
			m.global_position = Jutsu._ground(cp + d * 1.1)
			if m is CharacterBody3D:
				m.velocity = Vector3.ZERO
			var step = int(x * 12.0)
			if step != st["k"]:
				st["k"] = step
				var hp = _pj().hand_pos(c, true)
				VFX.bolt(hp, Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))), RAI, 0.06, 0.15, 2)
				VFX.debris(m.global_position + Vector3.UP * 0.2, Color(0.5, 0.42, 0.32), 4, 5.0, 0.25)
				if step % 3 == 0:
					VFX.cracks(m.global_position, 1.8)
					m.take_hit(_inf(c, "raikiri_issen", 0.1, {"knock": 0.0, "launch": 0.0, "kind": "light", "element": "raiton", "pierce_guard": true}))
					m.apply_status("bind", 0.5), 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not _alive(c) or m == null or m.is_dead():
				return
			_anim(c, "push", 1.8)
			m.take_hit(_inf(c, "raikiri_issen", 0.4, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.8, "hitstop": 0.1, "dir": d}))
			_rai_burst(_chest(m), 8, 3.5)
			_shake(0.7)
			Sfx.play("zap", m.global_position, 0.8)))


## Raijū Hashiri no Jutsu: Sō (雷獣走りの術・双, Storm): iki şimşek tazısı iki yana açılıp koşar, hedefe yanlardan saldırır
static func m_raiju_hashiri_so(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 34.0)
	var aim = _aim_fn(c, tg, 14.0)
	var d = _turn(c, aim.call())
	_pj().busy(c, 0.8)
	_anim(c, "cast", 1.2)
	_hand_orb(c, true, 0.5)
	_hand_orb(c, false, 0.5)
	Sfx.play("chidori", c.global_position, 1.2)
	_later(0.3, func():
		if not _alive(c):
			return
		_anim(c, "cast_out", 1.4)
		for sgn in [-1.0, 1.0]:
			var head = Node3D.new()
			var hound = RantonArt.hound(1.9)
			hound.position.y = -0.8
			head.add_child(hound)
			var dir = d.rotated(Vector3.UP, sgn * 0.75)   # önce yana açılır, sonra hedefe kıvrılır
			var from = Jutsu._ground(c.global_position + dir * 1.2) + Vector3.UP * 0.9
			var pr = _pj().shot(c, from, dir, 26.0, head, _inf(c, "raiju_hashiri_so", 0.5, {"knock": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.9}), tg, false, 2.2, func(p, _h):
				_pj().impact_fx("raiton", RAI, p, 1.3))
			pr.homing_turn = 5.5
			pr.radius = 0.7
			var wpr = weakref(pr)   # isabetle silinen mermiyi lambda yakalamasın
			_pj().every(2.2, 0.05, func(_i, _k):
				var q = wpr.get_ref()
				if q != null:
					var p0 = q.global_position + q.global_basis.z * randf_range(-1.0, 1.0)
					VFX.bolt(p0, p0 + Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)), RAI.lightened(0.2), 0.06, 0.09, 2), Callable()))


## Susanoo: Kamui Raikiri (須佐能乎・神威雷切, Storm): Susanoo'nun yumruğunda Raikiri toplanır, çevresinde Kamui girdabı döner;
## yumruk saplandığı yeri hem deler hem boyuta çeker
static func m_susanoo_kamui_raikiri(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kamui_raikiri")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 12.0 + H * 1.3)
	var aim = _aim_fn(c, tg, 6.0 + H * 0.7)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.5)
	_anim(c, "cast", 0.9)
	sn.hide_weapons(1.9)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.5 + side * 0.4 - Vector3.UP * 0.3, d * 0.3 - Vector3.UP * 0.6), "spine": -12.0}, 1.0, true)
	var ball = VFX.lightning_ball(S * 0.34, RAI)
	var arcs = Arcs.new()
	arcs.color = RAI.lightened(0.3)
	arcs.radius = S * 0.55
	arcs.count = 12
	arcs.width = S * 0.02
	ball.add_child(arcs)
	_scene().add_child(ball)
	sn.follow_fx(ball, 1.5, func(): return sn.hand(true))
	var vx = kamui_vortex(sn.hand(true), S * 0.75, 1.5)
	sn.follow_fx(vx, 1.5, func(): return sn.hand(true))
	Sfx.play("chidori", c.global_position, 0.6)
	for k in 10:
		_later(0.1 + k * 0.07, func():
			if is_instance_valid(ball):
				var hp = ball.global_position
				VFX.bolt(hp, Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * S * 0.6), RAI, S * 0.03, 0.14, 2))
	_later(0.85, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.7, true)
		_shake(0.5))
	_later(1.0, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		var fist = sn.hand(true)
		var at = fist + (aim.call() - fist).limit_length(S * 0.8)
		var inf = _inf(c, "susanoo_kamui_raikiri", 1.0, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.1, "dir": d})
		for h in _foes(c, at, 2.2 + H * 0.14):
			kamui_warp(c, h, inf, _chest(h))
		_rai_burst(at, 8, 3.0 + H * 0.25)
		VFX.cracks(Jutsu._ground(at), 3.0 + H * 0.15)
		_shake(0.9)
		Sfx.play("zap", at, 0.7))
	_later(1.5, func():
		if is_instance_valid(ball):
			ball.queue_free())


# ================================================================== MADARA (Susanoo kılıçları)
## Susanoo'nun chakra kılıcı (namlu -Z'ye bakar); dur sn boyunca verilen elde durur, look_fn yönüne bakar
static func _sus_sword(sn: Susanoo, S: float, right: bool, dur: float, look_fn: Callable) -> MeshInstance3D:
	var mb = MB.new()
	mb.add("box", Vector3(0, 0, -1.25), Vector3(0.05, 0.16, 2.5), Color.WHITE)
	mb.add("cone", Vector3(0, 0, -2.62), Vector3(0.05, 0.25, 0.16), Color.WHITE, Vector3(-90, 0, 0), 4)
	mb.add("box", Vector3(0, 0, 0.05), Vector3(0.34, 0.07, 0.07), Color.WHITE)
	mb.add("cyl", Vector3(0, 0, 0.3), Vector3(0.05, 0.45, 0.05), Color.WHITE, Vector3(90, 0, 0), 8)
	var sw = sn.chakra_mesh(mb, 1.7)
	_scene().add_child(sw)
	sw.scale = Vector3.ONE * S
	sn.follow_fx(sw, dur, func(): return sn.hand(right), look_fn)
	_later(dur, func():
		if is_instance_valid(sw):
			sw.queue_free())
	return sw


## Susanoo: Dan (須佐能乎・断, Storm): dirsek darbesiyle açar, Susanoo kılıcıyla ardı ardına biçer ve tepeden inen tek bir
## kesikle yeri yarar
static func m_susanoo_dan(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_dan")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 8.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 4.0 + H * 0.5)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 2.0)
	_anim(c, "hook", 1.6)
	sn.hide_weapons(2.3)
	Combat.hit_sphere(c, c.global_position + Vector3.UP + d * 1.2, 1.6, _inf(c, "susanoo_dan", 0.08, {"knock": 2.0, "kind": "light", "stun": 0.4, "dir": d}))
	var look = {"d": d}
	_sus_sword(sn, S * 0.5, true, 2.1, func(): return look["d"])
	var reach = 2.0 + S * 0.9
	for k in 3:
		_later(0.3 + k * 0.3, func():
			if not (is_instance_valid(sn) and _alive(c)):
				return
			var sg = 1.0 if k % 2 == 0 else -1.0
			sn.pose({"arms": Susanoo.arm(true, d * 0.7 - side * sg * 0.7, d * 0.5 - side * sg * 0.85), "spine": 8.0, "twist": -sg * 24.0}, 0.5, true)
			look["d"] = (d - side * sg * 0.9).normalized()
			_anim(c, "slash_a" if k % 2 == 0 else "slash_b", 1.5)
			var at: Vector3 = c.global_position + d * reach + Vector3.UP * (1.0 + H * 0.12)
			_slash_arc(at - d * reach * 0.5, d, reach * 0.9, sg * 0.25, 0.24, false, col, 0.16)
			Combat.hit_sphere(c, at, 1.6 + S * 0.7, _inf(c, "susanoo_dan", 0.16, {"knock": 1.0, "kind": "heavy", "blade": true, "bleed": 1.5, "hitstop": 0.04, "dir": d}))
			Sfx.play("swing_sword", c.global_position, 0.7))
	_later(1.25, func():
		if is_instance_valid(sn) and _alive(c):
			look["d"] = (Vector3.UP + d * 0.2).normalized()
			sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.95 + d * 0.2, Vector3.UP), "spine": -14.0}, 0.5, true))   # kılıç tepede bekler
	_later(1.6, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		look["d"] = (d - Vector3.UP * 0.5).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.85 - Vector3.UP * 0.5, d * 0.8 - Vector3.UP * 0.6), "spine": 24.0}, 0.6, true)
		_anim(c, "slash_c", 1.4)
		var g0 = Jutsu._ground(c.global_position + d * 1.5)
		var Lr = reach * 1.8
		_slash_arc(c.global_position + d * reach * 0.4 + Vector3.UP * (1.5 + H * 0.2), d, reach * 1.2, PI * 0.5, 0.3, false, col, 0.16)
		var got: Array = []
		var inf = _inf(c, "susanoo_dan", 0.5, {"knock": 14.0, "launch": 2.0, "kind": "heavy", "blade": true, "bleed": 3.0, "hard_down": true, "hitstop": 0.1, "dir": d})
		for u in 4:   # yarık: kesiğin indiği hat boyunca
			var p = Jutsu._ground(g0 + d * Lr * (u + 0.5) / 4.0)
			VFX.cracks(p, 2.0 + S * 0.5)
			VFX.debris(p + Vector3.UP * 0.3, Color(0.5, 0.42, 0.32), 6, 9.0, 0.4)
			for f in Combat.hit_sphere(c, p + Vector3.UP, 1.4 + S * 0.6, inf, got):
				got.append(f)
		_shake(1.0)
		Sfx.play("hit_heavy", g0, 0.7))


## Susanoo: Retsu (須佐能乎・裂, Storm): Susanoo kılıcı alttan savrulup rakibi havaya kaldırır; düşerken iki kılıç çapraz iner
static func m_susanoo_retsu(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_retsu")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 8.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 4.0 + H * 0.5)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	var reach = 2.0 + S * 0.9
	_pj().busy(c, 1.5)
	_anim(c, "slash_b", 1.2)
	sn.hide_weapons(1.9)
	var look = {"r": (d - Vector3.UP * 0.6).normalized(), "l": (d - Vector3.UP * 0.6).normalized()}
	_sus_sword(sn, S * 0.5, true, 1.6, func(): return look["r"])
	sn.pose({"arms": Susanoo.arm(true, d * 0.4 - Vector3.UP * 0.85, d * 0.7 - Vector3.UP * 0.6), "spine": 18.0}, 0.4, true)
	var at: Vector3 = c.global_position + d * reach + Vector3.UP
	var up_h = 5.0 + H * 0.35
	_later(0.3, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		look["r"] = (d + Vector3.UP * 0.8).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.6 + Vector3.UP * 0.7, d * 0.4 + Vector3.UP * 0.9), "spine": -10.0}, 0.5, true)
		_slash_arc(at + Vector3.UP * H * 0.1, d, reach * 0.9, -PI * 0.5, 0.26, false, col, 0.16)
		Sfx.play("swing_sword", c.global_position, 0.7)
		for f in Combat.hit_sphere(c, at, 1.8 + S * 0.7, _inf(c, "susanoo_retsu", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "blade": true, "hitstop": 0.06, "pierce_guard": true, "dir": Vector3.UP})):
			var fh = float(f.get("height")) if f.get("height") != null else 1.8
			if fh <= 4.0 and _alive(f):
				_carry(f, f.global_position + Vector3.UP * up_h, 0.4))
	_later(0.55, func():
		if is_instance_valid(sn) and _alive(c):
			_sus_sword(sn, S * 0.5, false, 1.0, func(): return look["l"])
			look["r"] = (Vector3.UP + side * 0.5).normalized()
			look["l"] = (Vector3.UP - side * 0.5).normalized()
			sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.8 + side * 0.5 + d * 0.2, Vector3.UP + side * 0.3) + Susanoo.arm(false, Vector3.UP * 0.8 - side * 0.5 + d * 0.2, Vector3.UP - side * 0.3), "spine": -8.0}, 0.5, true))
	_later(0.95, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		look["r"] = (d - side * 0.7 - Vector3.UP * 0.3).normalized()
		look["l"] = (d + side * 0.7 - Vector3.UP * 0.3).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.8 - side * 0.5 - Vector3.UP * 0.2, d * 0.7 - side * 0.7) + Susanoo.arm(false, d * 0.8 + side * 0.5 - Vector3.UP * 0.2, d * 0.7 + side * 0.7), "spine": 20.0}, 0.6, true)
		_anim(c, "slash_c", 1.5)
		var xp = at + Vector3.UP * up_h
		for rl in [0.8, -0.8]:
			_slash_arc(xp - d * reach * 0.4, d, reach, rl, 0.3, false, col, 0.16)
		Combat.hit_sphere(c, xp, 2.4 + S * 0.8, _inf(c, "susanoo_retsu", 0.7, {"knock": 18.0, "launch": 2.0, "kind": "heavy", "blade": true, "bleed": 3.0, "hitstop": 0.1, "dir": d}))
		Combat.hit_sphere(c, at, 1.8 + S * 0.6, _inf(c, "susanoo_retsu", 0.7, {"knock": 18.0, "kind": "heavy", "blade": true, "bleed": 3.0, "dir": d}))   # kaldırılamayan dev hedef yerde
		VFX.star(xp, col.lightened(0.5), 3.0 + S * 0.5, 0.16)
		_shake(0.8)
		Sfx.play("hit_sword", xp, 0.8))


## Susanoo: Nitō no Mai (須佐能乎・二刀の舞, Storm): Susanoo iki kılıcını sırayla savurur; her savuruş uzağa giden bir chakra
## dalgası bırakır
static func m_susanoo_nito_no_mai(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_nito_no_mai")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = _aim_fn(c, tg, 20.0 + H * 0.5)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	_pj().busy(c, 1.7)
	_anim(c, "slash_a", 1.0)
	sn.hide_weapons(2.1)
	var look = {"r": (d + side).normalized(), "l": (d - side).normalized()}
	_sus_sword(sn, S * 0.5, true, 1.9, func(): return look["r"])
	_sus_sword(sn, S * 0.5, false, 1.9, func(): return look["l"])
	var inf = _inf(c, "susanoo_nito_no_mai", 0.3, {"knock": 6.0, "kind": "heavy", "blade": true, "bleed": 2.0, "dir": d})
	for k in 4:
		_later(0.25 + k * 0.33, func():
			if not (is_instance_valid(sn) and _alive(c)):
				return
			var right = k % 2 == 0
			var sg = 1.0 if right else -1.0
			var dn: Vector3 = (aim.call() - c.global_position)
			dn.y = 0.0
			dn = dn.normalized() if dn.length() > 0.5 else d
			look["r" if right else "l"] = (dn - side * sg * 0.8).normalized()
			sn.pose({"arms": Susanoo.arm(right, dn * 0.8 - side * sg * 0.6, dn * 0.6 - side * sg * 0.8), "spine": 10.0, "twist": -sg * 22.0}, 0.45, true)
			_anim(c, "slash_a" if right else "slash_b", 1.5)
			Sfx.play("swing_sword", c.global_position, 0.6 + k * 0.08)
			var from = c.global_position + Vector3.UP * (1.2 + H * 0.3) + dn * (1.5 + S * 0.6)
			var mi = MeshInstance3D.new()
			mi.mesh = _arc_mesh(1.0, 2.4, 0.4, 24)
			var m = VFX.mat_fire("fire", 6.0, 2.6, 0.2, 2.0, 0.05, Vector3(0, 0, -1), true)
			m.set_shader_parameter("c_core", Color(1, 1, 1))
			m.set_shader_parameter("c_hot", col.lightened(0.6))
			m.set_shader_parameter("c_mid", col)
			m.set_shader_parameter("c_edge", col.darkened(0.3))
			m.set_shader_parameter("c_line", col.darkened(0.7))
			m.render_priority = 1
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_scene().add_child(mi)
			var R = 2.0 + S * 0.9
			var bas = _zbasis(dn) * Basis(Vector3(0, 0, 1), sg * 0.7) * Basis.from_scale(Vector3(R, 1.0, R * 0.5))
			var dist = 34.0 + H * 0.6
			var got: Array = []
			var tw = _tw()
			tw.tween_method(func(x: float):
				if not is_instance_valid(mi):
					return
				var pos = from + dn * x * dist - Vector3.UP * x * H * 0.25
				mi.global_transform = Transform3D(bas, pos)
				m.set_shader_parameter("erode", 0.2 + maxf(0.0, x - 0.75) * 3.2)
				if _alive(c):
					for f in Combat.hit_sphere(c, pos + dn * R * 0.4, R * 0.7, inf, got):
						got.append(f)
						VFX.star(_chest(f), col.lightened(0.5), 1.6 + S * 0.2, 0.12), 0.0, 1.0, 0.5)
			tw.tween_callback(mi.queue_free))


# ================================================================== ITACHI
## Totsuka no Tsurugi: Renzokugiri (十拳剣・連続斬り, Storm): Totsuka kılıcıyla iki yatay kesik, bir saplama; Itachi ateş
## topuyla bitirir
static func m_totsuka_renzokugiri(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "totsuka_renzokugiri")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 9.0 + H * 1.2)
	var aim = _aim_fn(c, tg, 4.0 + H * 0.5)
	var d = _turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	var reach = 2.0 + S * 0.9
	_pj().busy(c, 2.0)
	_anim(c, "slash_a", 1.0)
	sn.hide_weapons(2.0)
	var look = {"d": (d + side).normalized()}
	var blade = Node3D.new()
	var outer = VFX._mi(_blade_mesh(), sn.flame_mat())
	var inner = VFX._mi(_blade_mesh(), VFX.mat_bolt(Color(1.0, 0.96, 0.9), 2.4))
	inner.scale = Vector3(0.38, 0.38, 1.0)
	blade.add_child(outer)
	blade.add_child(inner)
	var holder = Node3D.new()   # _blade_mesh +Z'ye uzar; follow_fx -Z'yi yöne çevirir
	holder.add_child(blade)
	blade.rotation.y = PI
	_scene().add_child(holder)
	holder.scale = Vector3.ONE * S * 0.45
	sn.follow_fx(holder, 1.5, func(): return sn.hand(true), func(): return look["d"])
	_later(1.5, func():
		if is_instance_valid(holder):
			holder.queue_free())
	for k in 2:
		_later(0.25 + k * 0.35, func():
			if not (is_instance_valid(sn) and _alive(c)):
				return
			var sg = 1.0 if k == 0 else -1.0
			look["d"] = (d - side * sg * 0.9).normalized()
			sn.pose({"arms": Susanoo.arm(true, d * 0.7 - side * sg * 0.7, d * 0.5 - side * sg * 0.85), "spine": 8.0, "twist": -sg * 24.0}, 0.5, true)
			_anim(c, "slash_a" if k == 0 else "slash_b", 1.4)
			var at: Vector3 = c.global_position + d * reach + Vector3.UP * (1.0 + H * 0.12)
			_slash_arc(at - d * reach * 0.5, d, reach * 0.9, 0.0, 0.24, false, col, 0.16)
			Combat.hit_sphere(c, at, 1.6 + S * 0.7, _inf(c, "totsuka_renzokugiri", 0.2, {"knock": 1.0, "kind": "heavy", "blade": true, "stun": 0.4, "hitstop": 0.05, "dir": d}))
			Sfx.play("swing_sword", c.global_position, 0.75))
	_later(1.0, func():
		if not (is_instance_valid(sn) and _alive(c)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		look["d"] = ad
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.5, true)
		var at: Vector3 = aim.call()
		Combat.hit_sphere(c, at, 1.6 + S * 0.6, _inf(c, "totsuka_renzokugiri", 0.3, {"knock": 2.0, "kind": "heavy", "blade": true, "stun": 0.8, "hitstop": 0.08, "pierce_guard": true, "dir": d}))
		VFX.star(at, col.lightened(0.5), 2.0 + S * 0.4, 0.14)
		Sfx.play("hit_sword", at, 0.8))
	_later(1.45, func():
		if not _alive(c):
			return
		_anim(c, "cast_out", 1.4)
		var from = Jutsu._mouth(c) + d * 0.5
		var ball = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 20
		sm.rings = 10
		ball.mesh = sm
		ball.material_override = VFX.mat_fire("fire", 3.0, 2.2, 0.3, 1.7, 0.2, Vector3(0, 0, 1), true)
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball.scale = Vector3.ONE * 0.3
		ball.create_tween().tween_property(ball, "scale", Vector3.ONE * 1.5, 0.25)
		var dir: Vector3 = (aim.call() - from).normalized()
		var pr = _pj().shot(c, from, dir, 24.0, ball, _inf(c, "totsuka_renzokugiri", 0.5, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "element": "katon", "burn": 4.0}), tg, false, 1.8, func(p, _h):
			VFX.explosion(p, 1.0))
		pr.radius = 1.3
		Sfx.play("fire", from, 0.9))


## Zemine oturan disk örgüsü (eğimde toprağın altında kalmasın): merkez c, yarıçap R; UV düzlemsel
static func _ground_disc(center: Vector3, R: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = 10
	var segs = 36
	var pt = func(i: int, k: int) -> Array:
		var r = R * i / float(rings)
		var a = k * TAU / segs
		var x = cos(a) * r
		var z = sin(a) * r
		var y = Game.ground_height(center.x + x, center.z + z) - center.y + 0.14
		return [Vector3(x, y, z), Vector2(x / R * 0.5 + 0.5, z / R * 0.5 + 0.5)]
	for i in rings:
		for k in segs:
			var q = [pt.call(i, k), pt.call(i + 1, k), pt.call(i + 1, k + 1), pt.call(i, k + 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(q[idx][1])
				st.add_vertex(q[idx][0])
	return st.commit()


## Tsukuyomi Mōdo (月読モード, Ultimate Ninja): Tsukuyomi bir alana yayılır; içindeki rakipler görünmez bir engele takılmış gibi
## ağırlaşır (bedenleri değil zihinleri tutulur). Açık kaldıkça kullanıcının canı ve chakrası erir.
static func m_tsukuyomi_mode(c: Node3D, _t: Node3D) -> void:
	var R = 14.0
	var dur = 8.0
	_pj().busy(c, 0.6)
	_anim(c, "cast", 1.0)
	VFX.star(Jutsu._mouth(c) + Vector3.UP * 0.12, Color(0.95, 0.15, 0.2), 1.4, 0.3)
	Sfx.play("genjutsu", c.global_position, 0.6)
	if c == Game.player:
		VFX.screen_lines(0.5, 1.0, Color(0.9, 0.1, 0.12))
		_tint(Color(0.55, 0.0, 0.06, 0.14), dur)
	# yerde dönen dev Mangekyō: alanın sınırı
	var ctr = Jutsu._ground(c.global_position)   # alan kurulduğu yerde kalır (bariyer)
	var disc = _ms_disc(c, R * 2.0, false)
	disc.mesh = _ground_disc(ctr, R)
	_scene().add_child(disc)
	disc.global_position = ctr
	var dm: ShaderMaterial = disc.material_override
	dm.set_shader_parameter("fade", 0.0)
	dm.set_shader_parameter("glow", 1.0)
	var seen = {}
	var st = {"tick": -1.0}
	var wr = weakref(c)
	var tw = disc.create_tween()
	tw.tween_method(func(x: float):
		var n = wr.get_ref()
		if n == null or n.is_dead():
			dm.set_shader_parameter("fade", 0.0)
			return
		var el = x * dur
		dm.set_shader_parameter("fade", 0.65 * minf(1.0, el * 3.0) * minf(1.0, (dur - el) * 2.0))
		if el - st["tick"] < 0.5:
			return
		st["tick"] = el
		# bedel: can ve chakra erir
		if "chakra" in n:
			n.chakra = maxf(0.0, float(n.chakra) - 3.0)
		n.hp = maxf(1.0, float(n.hp) - float(n.max_hp) * 0.006)
		for f in _foes(n, ctr, R):
			var id = f.get_instance_id()
			if not seen.has(id):
				seen[id] = Eyes.genjutsu_land(n, f, false)
				if float(seen[id]) > 0.0:
					Combat.popup_text(_chest(f) + Vector3.UP, "Tsukuyomi", Color(1.0, 0.4, 0.45))
			if float(seen[id]) > 0.0:
				f.apply_status("slow", 0.8), 0.0, 1.0, dur)
	tw.tween_callback(disc.queue_free)


# ================================================================== SASUKE (Enton)
## Enton: Honoikazuchi (炎遁・火雷, anime): Amaterasu bedeni sarar, sonra dikenlere dönüşüp çevredeki herkesi deler
static func m_enton_honoikazuchi(c: Node3D, _t: Node3D) -> void:
	_pj().busy(c, 1.1)
	_anim(c, "cast", 1.1)
	Amaterasu.focus_flash(c)
	var wrap = VFX.black_flames(1.5)
	c.add_child(wrap)
	wrap.position = Vector3(0, 0.1, 0)
	_later(1.0, func():
		if is_instance_valid(wrap):
			wrap.queue_free())
	Sfx.play("fire", c.global_position, 0.6)
	_later(0.38, func():
		if not _alive(c):
			return
		_anim(c, "cast_out", 1.5)
		var ctr = c.global_position + Vector3.UP * 0.9
		var R = 5.2
		for k in 12:
			var a = k * TAU / 12.0 + randf_range(-0.12, 0.12)
			var dir = (Vector3(sin(a), 0, cos(a)) + Vector3.UP * randf_range(0.05, 0.45)).normalized()
			var len = R * randf_range(0.8, 1.1)
			var sp = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.34
			cm.height = 1.0
			cm.radial_segments = 5
			cm.rings = 6
			sp.mesh = cm
			sp.material_override = Jutsu._black_mat()
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_scene().add_child(sp)
			var y = dir
			var x = y.cross(Vector3.UP).normalized()
			var z = x.cross(y)
			var place = func(l: float, w: float):
				if is_instance_valid(sp):
					sp.global_transform = Transform3D(Basis(x * w, y * l, z * w), ctr + dir * (0.3 + l * 0.5))
			place.call(0.05, 1.0)
			var tw = sp.create_tween()
			tw.tween_method(func(v: float): place.call(v * len, 1.0), 0.05, 1.0, 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.45)
			tw.tween_method(func(v: float): place.call(len, v), 1.0, 0.02, 0.25)
			tw.tween_callback(sp.queue_free)
		var small = _inf(c, "enton_honoikazuchi", 0.08, {"knock": 0.0, "launch": 0.0, "kind": "light", "hitstop": 0.0, "element": "katon"})
		for f in Combat.hit_sphere(c, ctr, R, _inf(c, "enton_honoikazuchi", 1.0, {"knock": 10.0, "launch": 2.0, "kind": "heavy", "element": "katon", "bleed": 3.0, "hitstop": 0.09, "pierce_guard": true})):
			if _alive(f):
				Amaterasu.ignite(c, f, f.global_position, 6.0, small)
		_shake(0.7)
		Sfx.play("hit_blade", ctr, 0.7))


## Amaterasu: Zanka (天照・残火, Storm): Susanoo'nun eli dev bir kara alev küresi tutar; küreden kopan küçük küreler çevreye
## saçılır ve bir süre tuzak olarak bekler, değene patlayıp Amaterasu bulaştırır
static func m_amaterasu_zanka(c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "amaterasu_zanka")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 30.0 + H)
	var aim = _aim_fn(c, tg, 12.0 + H * 0.4)
	var d = _turn(c, aim.call())
	_pj().busy(c, 1.2)
	_anim(c, "cast", 1.0)
	sn.hide_weapons(1.6)
	var ad = (d + Vector3.UP * 0.25).normalized()
	sn.pose({"arms": Susanoo.arm(true, ad, ad, Vector3.UP), "spine": 6.0}, 1.4, true)
	Amaterasu.focus_flash(c)
	var orb_mesh = func(r: float) -> MeshInstance3D:
		var mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		mi.material_override = Jutsu._black_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
	var big: MeshInstance3D = orb_mesh.call(S * 0.3)
	_scene().add_child(big)
	big.scale = Vector3.ONE * 0.1
	big.create_tween().tween_property(big, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	sn.follow_fx(big, 1.3, func(): return sn.hand(true) + Vector3.UP * S * 0.35)
	_later(1.3, func():
		if is_instance_valid(big):
			big.queue_free())
	Sfx.play("fire", c.global_position, 0.5)
	var boom = _inf(c, "amaterasu_zanka", 0.3, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "element": "katon", "hitstop": 0.05})
	var small = _inf(c, "amaterasu_zanka", 0.06, {"knock": 0.0, "launch": 0.0, "kind": "light", "hitstop": 0.0, "element": "katon"})
	for k in 5:
		_later(0.45 + k * 0.14, func():
			if not (_alive(c) and is_instance_valid(big)):
				return
			var ctr: Vector3 = aim.call()
			var a = k * TAU / 4.0 + 0.4
			var spot = Jutsu._ground(ctr + (Vector3(sin(a), 0, cos(a)) * 3.2 if k > 0 else Vector3.ZERO)) + Vector3.UP * 0.9
			var from = big.global_position
			var orb: MeshInstance3D = orb_mesh.call(0.5)
			_scene().add_child(orb)
			orb.global_position = from
			var stt = {"live": true, "t": 0.0}
			var pop = func():
				if not stt["live"] or not is_instance_valid(orb):
					return
				stt["live"] = false
				var p = orb.global_position
				orb.queue_free()
				VFX.puffs(p, {"amount": 22, "life": 0.6, "size": 1.2, "vmin": 2, "vmax": 6, "glow": 1.0, "outline_col": Color(0.4, 0.05, 0.45),
					"colors": [Color(0.12, 0.02, 0.15, 1), Color(0.05, 0.0, 0.08, 1), Color(0.02, 0.0, 0.03, 0)]})
				Sfx.play("fire", p, 1.2, 0.7)
				if _alive(c):
					for f in Combat.hit_sphere(c, p, 3.0, boom):
						if _alive(f):
							Amaterasu.ignite(c, f, f.global_position, 6.0, small)
			var tw = orb.create_tween()
			tw.tween_method(func(x: float):
				if is_instance_valid(orb):
					orb.global_position = from.lerp(spot, x) + Vector3.UP * sin(x * PI) * 3.0, 0.0, 1.0, 0.45)
			# tuzak: 8 sn bekler, yaklaşana patlar
			tw.tween_method(func(x: float):
				if not stt["live"] or not is_instance_valid(orb):
					return
				orb.global_position = spot + Vector3.UP * sin(x * 40.0) * 0.12
				if x * 8.0 - stt["t"] >= 0.15 and is_instance_valid(c):
					stt["t"] = x * 8.0
					if not _foes(c, spot, 1.7).is_empty():
						pop.call(), 0.0, 1.0, 8.0)
			tw.tween_callback(func():
				if stt["live"] and is_instance_valid(orb):
					stt["live"] = false
					orb.queue_free()))
