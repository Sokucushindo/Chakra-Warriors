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


## Kamui girdabı (anime ref: refs/kamui_anime): uzay odak noktasına doğru sarmal burkulur — arkasındaki görüntü (beden dahil)
## merkeze akar, ince mürekkep çizgileri içe döner, ortası küçük kara nokta. Kameraya bakan, ekranı büken dörtgen (kabuk yok).
## o: "follow" Node3D (pos onun yerel ofseti olur, izler), "pull" (+ içe yutma / - dışa çıkış), "twist", "core", "ink", "spin",
## "back" (kameradan uzağa itme, m)
static func kamui_vortex(pos: Vector3, size: float, dur: float, o := {}) -> MeshInstance3D:
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/vfx_kamui.gdshader")
	m.set_shader_parameter("strength", 0.0)
	var pull = float(o.get("pull", 0.35))
	m.set_shader_parameter("pull", pull)
	m.set_shader_parameter("twist", float(o.get("twist", 1.0)))
	m.set_shader_parameter("core", float(o.get("core", 0.07)))
	m.set_shader_parameter("ink", float(o.get("ink", 1.0)))
	m.set_shader_parameter("spin", float(o.get("spin", 1.0 if pull >= 0.0 else -1.0)))
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	_scene().add_child(mi)
	var fol = o.get("follow") as Node3D
	mi.global_position = (fol.global_position + pos) if fol and is_instance_valid(fol) else pos
	mi.scale = Vector3.ONE * size * 2.0
	var back = float(o.get("back", minf(0.7, size * 0.4)))   # bedenin arkasına: beden önünde burgaca akar (ekran dokusu bedeni görmez)
	var face = func():
		if not is_instance_valid(mi):
			return
		var base: Vector3 = (fol.global_position + pos) if fol and is_instance_valid(fol) else pos
		var cam = mi.get_viewport().get_camera_3d() if mi.is_inside_tree() else null
		if cam and cam.global_position.distance_squared_to(base) > 0.0001:
			mi.global_position = base + (base - cam.global_position).normalized() * back
			mi.look_at(cam.global_position, Vector3.UP)
			mi.rotate_object_local(Vector3.UP, PI)
		else:
			mi.global_position = base
	face.call()
	var t_in = minf(0.45, dur * 0.45)   # açılış (anime: uzay yavaşça burkulmaya başlar)
	var tw = mi.create_tween()
	tw.tween_method(func(k: float):
		m.set_shader_parameter("strength", k)
		face.call(), 0.0, 1.0, t_in).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(_k: float): face.call(), 0.0, 1.0, maxf(0.05, dur - t_in - 0.3))
	tw.tween_method(func(k: float):
		m.set_shader_parameter("strength", k)
		mi.scale = Vector3.ONE * size * 2.0 * (0.3 + 0.7 * k)   # çöküş: burgaç kara noktaya kapanır
		face.call(), 1.0, 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Bedenin boyu (yoksa 1.8): Kamui burgacı hedef boyuna göre büyür
static func _hh(n: Node) -> float:
	return float(n.get("height")) if n and n.get("height") != null else 1.8


## Kamui geçirgenliği (anime ref d_phase): darbe bedenin içinden geçerken yalnız geçtiği yerde küçük, kısa bir uzay
## burkulması olur (beden dönmez, sürekli girdap yok). Sık darbede 0.15 sn'de bir.
static func kamui_ripple(n: Node3D, at := Vector3.INF) -> void:
	if n == null or not is_instance_valid(n):
		return
	var now = Game.now()
	if now < float(n.get_meta("kamui_rip_t", 0.0)):
		return
	n.set_meta("kamui_rip_t", now + 0.15)
	var hh = float(n.get("height")) if n.get("height") != null else 1.8
	var p = at if at != Vector3.INF else n.global_position + Vector3.UP * hh * randf_range(0.45, 0.8)
	kamui_vortex(p - n.global_position, 0.42, 0.42, {"follow": n, "pull": 0.15, "twist": 0.7, "core": 0.0, "ink": 0.7})


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
	DojutsuFXD.magen_karasu_bunshin(_pj(), c, t)


# ================================================================== SASUKE
## Enton: Kagutsuchi no Tsurugi — elde kara alevden kılıç biçimlenir, ileri atılıp yay çizen kesik; kesik yanmaya devam eder
static func m_enton_kagutsuchi_no_tsurugi(c: Node3D, t: Node3D) -> void:
	KatonFXF.enton_kagutsuchi_no_tsurugi(null, c, t)


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
	DojutsuFXB.susanoo(_pj(), c, t)


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
	DojutsuFXD.totsuka_no_tsurugi(_pj(), c, t)


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
	DojutsuFXD.yata_no_kagami(_pj(), c, t)


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
		KatonLib.embers(Game.world, to, 30, 0.4, KatonLib.PAL_BLACK, {"vmin": 8.0 * 0.4, "vmax": 8.0, "life": 1.1})
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
	RaitonFXF.susanoo_chidori(MsArts._pj(), c, t)


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
	DojutsuFXB.susanoo_kobushi(_pj(), c, t)


# ------------------------------------------------------------------ Susanoo: Gōkakyū
## Susanoo nefes alıp geriye yaslanır, ağzında alev toplanır; öne eğilip dev ateş topunu üfler.
static func m_susanoo_gokakyu(c: Node3D, t: Node3D) -> void:
	KatonFXF.susanoo_gokakyu(null, c, t)


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
	NinjutsuFXG.susanoo_tsukumo(_pj(), c, t)


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
## %35 altı) hedef bütünüyle boyuta çekilir (orada tutsak kalır: world/kamui_space.gd), güçlü hedefin yalnız bir parçası kopar
## (ağır kanama). Oyuncu hedefse öldürmez: zayıflamışsa o da boyuta çekilir (aynı kural), çıkışı arar.
static func kamui_warp(c: Node3D, h: Node3D, info: Dictionary, at: Vector3) -> void:
	if not _alive(h):
		return
	var inf = info.duplicate()
	if h == Game.player:
		inf["dmg"] = minf(float(inf.get("dmg", 0.0)), maxf(1.0, float(h.hp) * 0.5))
	# zayıflamış (ya da bu darbeyle düşecek) hedef darbe yemez: bütünüyle boyuta akar (hasarla ölüp yerde ceset kalmasın)
	var weak = not (h is Player) and not h.has_meta("boss") and float(h.hp) - float(inf.get("dmg", 0.0)) <= float(h.max_hp) * 0.35 and h.has_method("die")
	if not weak:
		h.take_hit(inf)
		if not _alive(h):
			return
	if h == Game.player and float(h.hp) <= float(h.max_hp) * 0.35 and pull_player(c):
		return
	if weak:
		h.apply_status("stun", 1.2)
		if c == Game.player:
			Game.profile["kamui_store"] = int(Game.profile.get("kamui_store", 0)) + 1
		# anime (Kakashi): odak noktasındaki uzay sarmal burkulur, beden oraya akıp kaybolur; ceset / düşüş karesi yok
		KS.swallow(c, h, at, 0.9, func():
			Combat.popup_text(at + Vector3.UP, "Kamui boyutuna çekildi", Color(0.7, 0.55, 0.9))
			h.die({"execute": true, "attacker": c, "kamui": true, "dmg": 9999.0})
			if is_instance_valid(h) and h.is_dead():
				KS.capture(c, h))   # boyutta tutsak kalır
	else:
		Combat.popup_text(_chest(h) + Vector3.UP, "Bir parçası koptu", Color(0.8, 0.6, 0.95))
		h.apply_status("bleed", 5.0)
		kamui_vortex(at, _hh(h) * 1.4, 1.0, {"pull": 0.5})
		KS.twist_into(h, at, 0.7, false, 0.3)   # güçlü hedef: odaktaki parça burkulup kopar, beden geri yaylanır


const KS = preload("res://scripts/world/kamui_space.gd")


## Oyuncu düşman Kamui'siyle boyuta çekilir (NPC'lerle aynı kural; yeni çıkmışsa / kapalı yerdeyse / saldırandan güçlüyse olmaz)
static func pull_player(c: Node3D) -> bool:
	var pl = Game.player
	if pl == null or c == pl or not is_instance_valid(c) or KS.player_inside() or KS._blocked() != "":
		return false
	if Game.now() < float(pl.get_meta("kamui_pull_immune", 0.0)) or Combat.power_of(pl) > Combat.power_of(c) * 1.5:   # çekme kuralı her iki yönde aynı
		return false
	Combat.popup_text(_chest(pl) + Vector3.UP, "Kamui boyutuna çekildin", Color(0.7, 0.55, 0.9))
	KS.node().enter_player("pulled")
	return true


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
	DojutsuFXB.kyoso_enbu(_pj(), c, t)


# ------------------------------------------------------------------ Susanoo: Kai (ref Narutopedia "Susanoo: Crush")
## Susanoo'nun eli rakibe uzanır, onu kavrar ve yumruğunun içinde ezer; sonra yere fırlatır
static func m_susanoo_kai(c: Node3D, t: Node3D) -> void:
	DojutsuFXD.susanoo_kai(_pj(), c, t)


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
	DojutsuFXC.zanzo_bunshin(MsArts._pj(), c, t)


## Bunshun (分瞬, Storm Revolution): iki kage bunshin iki yandan hedefe atılıp çarpar, gerçek Shisui arkalarından tek kesikle bitirir
static func m_bunshun(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.bunshun(MsArts._pj(), c, t)


## Uchiha Ryū: Higasa no Mai (うちは流・日暈の舞, Storm Revolution): tantō alevle kaplanır, tek hızlı savuruşla öne doğru
## genişleyen alev halesi (güneş halesi yayı) salınır; değdiğini yakar
static func m_uchiha_ryu_higasa_no_mai(c: Node3D, t: Node3D) -> void:
	KatonFXC.uchiha_ryu_higasa_no_mai(_pj(), c, t)


## Kotoamatsukami: Kōbō (別天神・光芒, Storm Revolution): hedef genjutsuya düşer; tepesinde dev bir Mangekyō belirir ve gözden
## inen ışık huzmeleri onu vurur. Genjutsu olduğu için göz göze gelmeyen / direnen hedefte tutmaz.
static func m_kotoamatsukami_kobo(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.kotoamatsukami_kobo(MsArts._pj(), c, t)


## Kotoamatsukami: Zankō (別天神・残光, Shinobi Striker): çevredeki bütün düşmanlara aynı anda uygulanır; hareketleri karışır,
## görüşleri kapanır (hedeflerini yitirirler). Hasar vermez.
static func m_kotoamatsukami_zanko(c: Node3D, _t: Node3D) -> void:
	DojutsuFXC.kotoamatsukami_zanko(MsArts._pj(), c, _t)


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
	KatonFXC.susanoo_kaien(_pj(), c, t)


## Kanseitai Susanoo: Kishin (完成体須佐能乎・鬼神, Shinobi Striker): Mükemmel Susanoo göğe sıçrar ve matkap kılıcını
## aşağı çevirip hedefin üstüne iner; indiği yer çöker
static func m_kanseitai_susanoo_kishin(c: Node3D, t: Node3D) -> void:
	DojutsuFXD.kanseitai_susanoo_kishin(_pj(), c, t)


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
	Sfx.play("kamui_in", c.global_position, 0.9)
	_blink(c, to)
	kamui_vortex(to + Vector3.UP * 1.1, 0.8, 0.45)
	Sfx.play("kamui_out", to, 0.9)


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
	DojutsuFXC.saten(MsArts._pj(), c, t)


## Sain (鎖引, Storm): bilek zinciri uzaktaki rakibe dolanır; Obito onu zincirle iki kez yere savurur, sonra Kamui ile arkasına
## ve üstüne ışınlanıp dönen tekmeyle indirir
static func m_sain(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.sain(MsArts._pj(), c, t)


## Muzan (無惨, Storm): Obito Kamui ile kaybolur, rakibin tam tepesinde belirir ve üstüne çöküp kunaiyi saplar. Uzaktan başlar.
static func m_muzan(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.muzan(MsArts._pj(), c, t)


## Mekkyaku (滅却, Storm): Obito yumruk ve tekme yağdırır; her darbenin arasında geçirgenleşir, rakibin karşılığı içinden geçer
static func m_mekkyaku(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.mekkyaku(MsArts._pj(), c, t)


## Tensō (転葬, Storm): rakip Kamui boyutuna çekilir; Obito çevreye kibaku fuda saçar ve rakibi patlayan mühürlerin tam
## ortasına geri bırakır. Dev hedef boyuta sığmaz: yalnız mühürler patlar.
static func m_tenso(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.tenso(MsArts._pj(), c, t)


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
	RaitonFXE.raikiri_sosenko(_pj(), c, t)


## Raikiri Issen (雷切一閃, Storm): Raikiri ile göz açıp kapayana dek rakibe varır, onu kavrayıp şimşekle yerde uzun uzun
## sürükler ve sonunda fırlatır
static func m_raikiri_issen(c: Node3D, t: Node3D) -> void:
	RaitonFXE.raikiri_issen(_pj(), c, t)


## Raijū Hashiri no Jutsu: Sō (雷獣走りの術・双, Storm): iki şimşek tazısı iki yana açılıp koşar, hedefe yanlardan saldırır
static func m_raiju_hashiri_so(c: Node3D, t: Node3D) -> void:
	RaitonFXE.raiju_hashiri_so(_pj(), c, t)


## Susanoo: Kamui Raikiri (須佐能乎・神威雷切, Storm): Susanoo'nun yumruğunda Raikiri toplanır, çevresinde Kamui girdabı döner;
## yumruk saplandığı yeri hem deler hem boyuta çeker
static func m_susanoo_kamui_raikiri(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.susanoo_kamui_raikiri(MsArts._pj(), c, t)


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
	DojutsuFXC.susanoo_dan(MsArts._pj(), c, t)


## Susanoo: Retsu (須佐能乎・裂, Storm): Susanoo kılıcı alttan savrulup rakibi havaya kaldırır; düşerken iki kılıç çapraz iner
static func m_susanoo_retsu(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.susanoo_retsu(MsArts._pj(), c, t)


## Susanoo: Nitō no Mai (須佐能乎・二刀の舞, Storm): Susanoo iki kılıcını sırayla savurur; her savuruş uzağa giden bir chakra
## dalgası bırakır
static func m_susanoo_nito_no_mai(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.susanoo_nito_no_mai(MsArts._pj(), c, t)


# ================================================================== ITACHI
## Totsuka no Tsurugi: Renzokugiri (十拳剣・連続斬り, Storm): Totsuka kılıcıyla iki yatay kesik, bir saplama; Itachi ateş
## topuyla bitirir
static func m_totsuka_renzokugiri(c: Node3D, t: Node3D) -> void:
	DojutsuFXC.totsuka_renzokugiri(MsArts._pj(), c, t)


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
	DojutsuFXC.tsukuyomi_mode(MsArts._pj(), c, _t)


# ================================================================== SASUKE (Enton)
## Enton: Honoikazuchi (炎遁・火雷, anime): Amaterasu bedeni sarar, sonra dikenlere dönüşüp çevredeki herkesi deler
static func m_enton_honoikazuchi(c: Node3D, _t: Node3D) -> void:
	KatonFXC.enton_honoikazuchi(_pj(), c, _t)


## Amaterasu: Zanka (天照・残火, Storm): Susanoo'nun eli dev bir kara alev küresi tutar; küreden kopan küçük küreler çevreye
## saçılır ve bir süre tuzak olarak bekler, değene patlayıp Amaterasu bulaştırır
static func m_amaterasu_zanka(c: Node3D, t: Node3D) -> void:
	KatonFXC.amaterasu_zanka(_pj(), c, t)
