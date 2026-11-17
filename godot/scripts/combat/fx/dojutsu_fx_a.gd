class_name DojutsuFXA
extends RefCounted
## Dōjutsu grubu A: Rinnegan yolları (Tendō, Chikushōdō, Shuradō, Ningendō, Gakidō emmesi, kara alıcılar, Chibaku Tensei,
## Gedō zincirleri, Amenotejikara) ve Sharingan / Mangekyō genjutsuları (Iatsu, Karga yanılsaması, Kazık yanılsaması,
## İzanagi, Kotoamatsukami). Malzeme ve yapı taşları DojutsuLib'den (kendi cel / kontur / hayalet / bükülme / disk shader'ları,
## kendi parçacık dokuları, gerçek göz konumunda parıltı); her tekniğin şekli, hareketi ve sahnelenmesi burada ve birbirinden
## ayrı. Ortak efekt yardımcısı yok. Oyunun gerçek sistemleri aynen kullanılır: çağrılar (Summon), Gedō heykeli (ağız / konum),
## Tendō dolumu, Gakidō emme kuralı, göz bedeli (Eyes), genjutsu tutma kuralı (Eyes.genjutsu_land).
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/dojutsu_lib.gd")


# ================================================================== küçük yardımcılar
static func _h(n: Node3D) -> float:
	return float(n.get("height")) if n != null and n.get("height") != null else 1.8


static func _mesh(b: MB, mat: Material) -> MeshInstance3D:
	return L.gi(b.build(null), mat)


## Tırtıklı parlama (kamera yüzlü yıldız diski): açılır, kısa tutar, söner
static func _flash(pj: PathJutsu, p: Vector3, size: float, c_out: Color, c_in: Color, c_line: Color, life := 0.18, n := 8.0) -> void:
	var m = L.disc_mat(8, c_out, c_in, c_line, {"bill": true, "count": n, "prog": 0.0, "near_cut": 2.0})
	var d = L.disc(pj, p, size, m, false)
	var tw = d.create_tween()
	tw.tween_method(L.sp(m, "prog"), 0.2, 1.0, life * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(L.sp(m, "spin"), 0.0, 0.25, life)
	tw.tween_method(L.sp(m, "prog"), 1.0, 0.0, life * 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(d.queue_free)


static func _trail_mat() -> StandardMaterial3D:
	if L._cache.has("dj_trail"):
		return L._cache["dj_trail"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.5
	m.distance_fade_max_distance = 2.0
	L._cache["dj_trail"] = m
	return m


## Hareketli nesnenin ardında kamera yüzlü, uca incelen şerit (son ~10 konum)
static func _streak(pj: PathJutsu, target: Node3D, life: float, w: float, col: Color, n := 10) -> void:
	var im = ImmediateMesh.new()
	var mi = L.gi(im, _trail_mat())
	pj.get_tree().current_scene.add_child(mi)
	var pts: Array = []
	var wt = weakref(target)
	var tw = mi.create_tween()
	tw.tween_method(func(_u: float):
		if not is_instance_valid(mi):
			return
		var tn = wt.get_ref()
		if tn != null and is_instance_valid(tn) and tn.is_inside_tree():
			pts.push_front(tn.global_position)
		elif pts.size() > 0:
			pts.pop_back()
		while pts.size() > n:
			pts.pop_back()
		im.clear_surfaces()
		if pts.size() < 2:
			return
		var cam = mi.get_viewport().get_camera_3d()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var p: Vector3 = pts[i]
			var pa: Vector3 = pts[maxi(i - 1, 0)]
			var pb: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var d = pa - pb
			var vd = (cam.global_position - p) if cam else Vector3.UP
			var side = d.cross(vd)
			if side.length() > 0.0001:
				side = side.normalized()
			var k = float(i) / float(pts.size() - 1)
			var ww = w * (1.0 - k * 0.85)
			var cc = Color(col.r, col.g, col.b, col.a * (1.0 - k))
			im.surface_set_color(cc)
			im.surface_add_vertex(p + side * ww)
			im.surface_set_color(cc)
			im.surface_add_vertex(p - side * ww)
		im.surface_end(), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Düğümü bir hedefin üstünde tutar (dünya koordinatlı parçacık yayıcıları için)
static func _follow(n: Node3D, target: Node3D, off: Vector3, dur: float) -> void:
	var wt = weakref(target)
	var wn = weakref(n)
	n.create_tween().tween_method(func(_u: float):
		var tn = wt.get_ref()
		var nn = wn.get_ref()
		if tn != null and nn != null and is_instance_valid(tn) and is_instance_valid(nn):
			nn.global_position = tn.global_position + off, 0.0, 1.0, dur)


# ================================================================== Amenotejikara
## Amenotejikara (kanon, Sasuke'nin sol Rinnegan'ı): menzildeki hedefle yer anında değişir — duman yok. Göz parlar, iki noktada
## uzay içe çöken bir kıvrımla kapanır (arkadaki dünya bükülür), bedenin bıraktığı ince ışık yarığı söner, ardından tek bir
## dalga dışa yayılır. Bağlıyken kullanılırsa bağ rakibe geçer.
static func amenotejikara(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.3)
	if tt == null:
		if c is Player:
			Hud.msg("Amenotejikara: menzilde (22 m) yer değiştirecek hedef yok.", Color(0.75, 0.65, 0.95))
		return
	var a = c.global_position
	var b = tt.global_position
	L.eye_glint(pj, c, 1, 0.6, 0.42, -1)
	var seam_m = L.ghost("ameno_seam", Color(0.95, 0.92, 1.0), L.RIN, {"a_in": 0.85, "a_edge": 1.0, "glow": 0.6})
	for pair in [[a, _h(c)], [b, _h(tt)]]:
		var p: Vector3 = pair[0]
		var h: float = pair[1]
		var mid = p + Vector3.UP * h * 0.55
		L.ripple(pj, mid, h * 1.9, 0.2, true, L.RIN, 0.06, 0.75)
		pj.after(0.18, func():
			L.ripple(pj, mid, h * 1.5, 0.3, false, L.RIN.lightened(0.2), 0.025, 0.3))
		# bedenin kalıbı: bir an kalan dikey ışık yarığı, yatayda kapanır
		var cm = CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 1.0
		cm.radial_segments = 8
		var seam = L.gi(cm, seam_m)
		L.put(pj, seam, mid)
		seam.scale = Vector3(0.09, h * 1.1, 0.09)
		var stw = seam.create_tween()
		stw.tween_property(seam, "scale", Vector3(0.005, h * 1.25, 0.005), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		stw.tween_callback(seam.queue_free)
		L.gather(pj, mid, h * 0.6, 10, 0.2, [Color(0.85, 0.75, 1.0, 0.0), Color(0.85, 0.75, 1.0, 0.9), Color(1, 1, 1, 0)], "mote", true, 0.08)
	var was_bound = c.has_method("has_status") and c.has_status("bind")
	c.global_position = b
	tt.global_position = a
	if was_bound:   # kanon: bağdan kurtulup rakibi kendi yerine bırakır
		c.statuses.erase("bind")
		pj.st(tt, "bind", 2.0)
		Combat.popup_text(a + Vector3.UP * 2.6, "Yerine bağlandı!", Color(0.85, 0.75, 1.0))
	if c is Player:
		c.combat.face_to(tt)
	pj.after(0.08, func():
		if pj.live(c):
			pj._kick_pose(c, 0.25))
	Sfx.play("seal", b, 2.0, 0.6)


# ================================================================== Chikushōdō
## Pain'in çağrıları: sırtına saplı kara alıcı çubuklar + başın önünde Rinnegan halka deseni (çağıranın gözünü paylaşır)
static func _rin_mark(s: Node3D, h: float) -> void:
	var root: Node3D = s.parts.get("root") if s.get("parts") is Dictionary else s
	if root == null:
		return
	var mb = MB.new()
	for k in 6:
		var z = lerpf(-h * 0.25, h * 0.35, k / 5.0)
		var x = (k % 2 - 0.5) * h * 0.12
		mb.add("cyl", Vector3(x, h * 0.78 + (k % 3) * h * 0.03, z), Vector3(h * 0.025, h * 0.22, h * 0.025), L.INK, Vector3(randf_range(-25, 25), 0, randf_range(-25, 25)), 6)
		mb.add("sphere", Vector3(x, h * 0.89 + (k % 3) * h * 0.03, z), Vector3.ONE * h * 0.04, L.INK, Vector3.ZERO, 6)
	root.add_child(_mesh(mb, L.cel("rin_rod", Color.WHITE, {"ow": 0.02, "ocol": Color(0.02, 0.01, 0.03), "rim": L.RIN_DEEP, "rim_amt": 0.5})))
	var eye = Node3D.new()
	root.add_child(eye)
	eye.position = Vector3(0, h * 0.75, -h * 0.45)
	var dm = L.disc_mat(0, L.RIN, L.RIN_LINE, L.RIN_DEEP, {"count": 4.0, "speed": 0.15, "alpha": 0.9, "near_cut": 1.0})
	var qm = QuadMesh.new()
	qm.size = Vector2.ONE * h * 0.2
	var d = L.gi(qm, dm)
	eye.add_child(d)
	d.rotation.y = PI


## Chikushōdō (kanon): kan sunusu ve mühür olmadan dev hayvanlar çağrılır; hepsinin gözü Rinnegan, bedenleri kara alıcı
## çubuklarla delinmiş. Her doğuşta yere mürekkep çağırma yazısı ışınsal açılır, altında Rinnegan halkaları dalgalanır,
## ağır beden yere otururken toz halkası kalkar (duman bulutu yok). Gerçek müttefik (Summon), AI da aynı.
static func chikushodo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "cast_in", 1.4)
	L.eye_glint(pj, c, 1, 1.6, 0.34)
	var fd: Vector3 = c.face_dir()
	var specs = [
		{"contract": "köpek", "base": Contracts.DEFS["köpek"]["tiers"][2], "name": "Çok Başlı Dev Köpek (Rinnegan)", "h": 5.5, "hp": 900.0, "split": true,
			"sig": "Bölünen Sürü", "off": fd * 4.0 + fd.cross(Vector3.UP) * 3.0},
		{"contract": "şahin", "base": Contracts.DEFS["şahin"]["tiers"][2], "name": "Matkap Gagalı Dev Kuş (Rinnegan)", "h": 7.0, "hp": 1100.0, "split": false,
			"sig": "Matkap Gaga Dalışı", "off": fd * 3.0 - fd.cross(Vector3.UP) * 4.0 + Vector3.UP * 3.0},
	]
	var heavy = [["rin_rhino", "Dev Gergedan (Rinnegan)", "Boynuz Hücumu", 5.0], ["rin_ox", "Dev Öküz (Rinnegan)", "Boynuz Hücumu", 5.5], ["rin_panda", "Dev Panda (Rinnegan)", "Pençe Ezmesi", 5.0],
		["rin_centipede", "Dev Çıyan (Rinnegan)", "Yer Altından Saldırı", 3.0], ["rin_crab", "Dev Kabuklu (Rinnegan)", "Suiton: Haran Banshō", 4.0]].pick_random()
	specs.append({"contract": "köpek", "base": Contracts.DEFS["köpek"]["tiers"][2], "name": heavy[1], "h": heavy[3], "hp": 1300.0, "split": false,
		"sig": heavy[2], "off": -fd * 3.0 + fd.cross(Vector3.UP) * 5.0, "model": heavy[0]})
	# Dev Bukalemun (kanon): içine aldığı bedenleri görünmez kılar — can azsa çağırıcıyı saklar
	if float(c.get("hp")) < float(c.get("max_hp")) * 0.5:
		specs.append({"contract": "köpek", "base": Contracts.DEFS["köpek"]["tiers"][2], "name": "Dev Bukalemun (Rinnegan)", "h": 3.0, "hp": 600.0, "split": false,
			"sig": "", "off": -fd * 2.0, "model": "rin_chameleon", "hide": true})
	if c.has_meta("rin_dogs"):
		c.set_meta("rin_dogs", 1)
	for i in specs.size():
		var sp: Dictionary = specs[i]
		pj.after(0.15 + i * 0.45, func():
			if not pj.live(c):
				return
			var pos = pj.gp(c.global_position + sp["off"])
			var h = float(sp["h"])
			var g = pj.gp(pos)
			# mürekkep çağırma yazısı: merkezden ışınsal açılan kara çizgiler ve glif kesikleri
			var ink = L.disc(pj, g + Vector3.UP * 0.05, 3.0 + h * 0.9, L.disc_mat(3, L.INK, Color.BLACK, Color.BLACK, {"count": 14.0, "alpha": 0.95, "prog": 0.0, "spin": randf() * TAU}))
			L.disc_life(ink, 0.22, 1.5, 0.7)
			var rr = L.disc(pj, g + Vector3.UP * 0.07, h * 1.3, L.disc_mat(0, L.RIN, L.RIN_LINE, L.RIN_DEEP, {"count": 5.0, "speed": 1.6, "alpha": 0.55, "prog": 0.0}))
			L.disc_life(rr, 0.3, 0.5, 0.5)
			pj.after(0.12, func():
				L.burst(pj, g + Vector3.UP * 0.3, {"amount": 18, "life": 0.8, "ring": true, "radius": 0.6 + h * 0.3, "vmin": 2.0, "vmax": 5.0, "dir": Vector3.UP, "spread": 55.0,
					"gravity": Vector3(0, -5, 0), "radial": 4.0, "size": 0.45 + h * 0.1, "tex": "dust",
					"colors": [Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.0), Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.85), Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.0)]}))
			Sfx.play("poof", pos, 0.7)
			var d: Dictionary = (sp["base"] as Dictionary).duplicate(true)
			d["name"] = sp["name"]
			d["h"] = sp["h"]
			d["hp"] = sp["hp"]
			d["mount"] = false
			d["split"] = sp["split"]
			d["sig_name"] = sp["sig"]
			if sp["split"]:
				d["model"] = "rin_dog"
			if sp.has("model"):
				d["model"] = sp["model"]
				d["fly"] = false
				if sp.get("hide", false):
					d["role"] = "tank"
			d["lines"] = ["..."]
			var s = Summon.new()
			s.contract = sp["contract"]
			s.tier = 2
			s.def = d
			s.owner_f = c
			s.team = c.team
			pj.get_tree().current_scene.add_child(s)
			s.global_position = pos
			s.facing = c.get("facing") if c.get("facing") != null else 0.0
			s.life = 30.0
			if sp["split"]:
				c.set_meta("rin_dogs", 1)
			_rin_mark(s, h)
			if sp.get("hide", false):
				pj._chameleon_hide(c, s))
	Sfx.play("summon", c.global_position, 0.8)


# ================================================================== Shuradō
## Metal darbe: soluk çelik tırtıklı parlama + sıçrayan kıvılcımlar
static func _clank(pj: PathJutsu, p: Vector3) -> void:
	_flash(pj, p, 1.0, Color(0.8, 0.82, 0.88), Color(1, 1, 1), L.INK, 0.14, 7.0)
	L.burst(pj, p, {"amount": 9, "life": 0.4, "radius": 0.1, "vmin": 3.0, "vmax": 7.0, "gravity": Vector3(0, -14, 0), "size": 0.09, "add": true, "tex": "glint",
		"colors": [Color(1, 0.95, 0.75, 1), Color(1, 0.6, 0.2, 0.8), Color(1, 0.3, 0.1, 0)]})


## Shuradō (kanon, Asura Yolu): sırttan mekanik ek kollar fırlar, belde dönen testere kuşağı; ek kollar yakındakilere vurur.
## Kollar bedenden açılırken çelik kıymıkları ve kıvılcım saçılır; her vuruşta kollar ileri seğirtir, metal çarpma parlaması.
static func shurado(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var parts: Array = []
	var sk = Color(0.92, 0.76, 0.64)
	var ch = pj.bone_attach(c, "UpperChest")
	var arms: MeshInstance3D = null
	if ch:
		var b = MB.new()
		for i in 4:
			var sx = -1.0 if i % 2 == 0 else 1.0
			var y = 0.12 if i < 2 else -0.08
			var p0 = Vector3(sx * 0.12, y, 0.12)
			var p1 = Vector3(sx * 0.42, y + 0.05, 0.25)
			var p2 = Vector3(sx * 0.62, y - 0.2, 0.05)
			var p3 = Vector3(sx * 0.66, y - 0.42, -0.15)
			Loft.tube(b, [p0, p1, p2, p3], [0.05, 0.045, 0.04, 0.035], sk, 8, 3)
			b.add("cyl", p1.lerp(p2, 0.5), Vector3(0.07, 0.1, 0.07), Color(0.3, 0.3, 0.33), Vector3(0, 0, sx * 50), 8)   # mekanik bilezik
			Loft.blob(b, p3 + Vector3(0, -0.05, -0.03), Vector3(0, -1, -0.4), 0.15, [Vector2(0.04, 0.03), Vector2(0.05, 0.035), Vector2(0.04, 0.03)], sk, 8)
		arms = _mesh(b, L.cel("shura_skin", Color.WHITE, {"ow": 0.012, "ocol": Color(0.22, 0.12, 0.08)}))
		ch.add_child(arms)
		parts.append(arms)
		arms.scale = Vector3.ONE * 0.15
		arms.create_tween().tween_property(arms, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hips = pj.bone_attach(c, "Hips")
	var saw: Node3D = null
	if hips:
		saw = Node3D.new()
		hips.add_child(saw)
		var b2 = MB.new()
		for k in 14:   # katlanmış testere kuşağı: belin çevresinde dişli metal plakalar
			var a = k * TAU / 14.0
			var pp = Vector3(cos(a) * 0.24, 0.02, sin(a) * 0.2)
			b2.add("box", pp, Vector3(0.12, 0.08, 0.02), Color(0.78, 0.8, 0.85), Vector3(0, -rad_to_deg(a) + 90, 0))
			b2.add("cone", pp * 1.18, Vector3(0.03, 0.06, 0.02), Color(0.85, 0.87, 0.9), Vector3(0, -rad_to_deg(a), -90), 4)
		saw.add_child(_mesh(b2, L.cel("shura_steel", Color.WHITE, {"ow": 0.008, "ocol": Color(0.12, 0.12, 0.16), "rim": Color(1, 1, 1), "rim_amt": 0.5})))
		parts.append(saw)
		var stw = saw.create_tween().set_loops()
		stw.tween_property(saw, "rotation:y", TAU, 1.2).as_relative()
	var DUR = 20.0
	if c is Player:
		Buffs.add("shurado", DUR, {"melee": 1.35, "armor": 0.8, "speed": 1.15, "_name": "Shuradō", "_desc": "ek kollar ve testere kuşağı; ek kollar yakındakilere vurur"})
	elif c.has_method("add_buff"):
		c.add_buff("shurado", DUR, {"melee": 1.35, "armor": 0.8, "speed": 1.15})
	var wa = weakref(arms) if arms else null
	pj.every(DUR, 1.4, func(_i, _k):
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, c.global_position, 3.2).slice(0, 2):
			if not (is_instance_valid(e) and not e.is_dead()):
				continue
			e.take_hit(pj.inf(c, "shurado", 0.3, {"knock": 6.0, "kind": "light", "melee": true}))
			_clank(pj, e.global_position + Vector3.UP)
		var am = wa.get_ref() if wa else null
		if am != null and is_instance_valid(am):   # ek kollar ileri seğirtir
			var ptw = am.create_tween()
			ptw.tween_property(am, "scale", Vector3(1.1, 1.0, 1.35), 0.06)
			ptw.tween_property(am, "scale", Vector3.ONE, 0.18), func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	# açılış: sırttan çelik kıymıkları ve kıvılcımlar saçılır, ayak dibinde kısa toz halkası
	var back = c.global_position + Vector3.UP * 1.35 - c.face_dir() * 0.2
	L.burst(pj, back, {"amount": 16, "life": 0.5, "radius": 0.25, "vmin": 3.0, "vmax": 6.0, "gravity": Vector3(0, -12, 0), "size": 0.1, "add": true, "tex": "glint",
		"colors": [Color(1, 1, 1, 1), Color(0.85, 0.87, 0.95, 0.8), Color(0.6, 0.6, 0.7, 0)]})
	L.chips(pj, back, 6, 0.08, 4.0, Vector3.UP, 90.0, 0.7)
	L.burst(pj, c.global_position + Vector3.UP * 0.2, {"amount": 12, "life": 0.6, "ring": true, "radius": 0.6, "vmin": 1.0, "vmax": 2.0, "radial": 6.0, "dir": Vector3.UP, "spread": 30.0,
		"size": 0.5, "tex": "dust", "colors": [Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.0), Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.75), Color(L.DUST.r, L.DUST.g, L.DUST.b, 0.0)]})
	Sfx.play("blade", c.global_position, 0.8)


# ================================================================== Kuroki Jūshinki
## Kara alıcı çubuk: uzun, ince, kara; tepesi topuzlu (uzun eksen Z)
static func _rod(Lg := 1.6) -> MeshInstance3D:
	var b = MB.new()
	var k = Color(0.05, 0.045, 0.06)
	b.add("cyl", Vector3(0, 0, 0), Vector3(0.045, Lg, 0.045), k, Vector3(90, 0, 0), 6)
	b.add("sphere", Vector3(0, 0, -Lg * 0.5), Vector3(0.11, 0.11, 0.11), k, Vector3.ZERO, 6)
	b.add("cone", Vector3(0, 0, Lg * 0.5 + 0.06), Vector3(0.05, 0.14, 0.05), k, Vector3(90, 0, 0), 5)
	return _mesh(b, L.cel("rin_rod", Color.WHITE, {"ow": 0.02, "ocol": Color(0.02, 0.01, 0.03), "rim": L.RIN_DEEP, "rim_amt": 0.5}))


## Saplanan alıcı: hedefin bedeninde kalır, çakra akışı bozulur — jutsu yapamaz (sealed), yavaşlar. Bozulma: çubuğun çevresinde
## aralıklı lila halka titreşimi.
static func _pierce(pj: PathJutsu, c: Node3D, h: Node3D, dur: float) -> void:
	if not pj.live(h):
		return
	pj.st(h, "sealed", dur)
	pj.st(h, "slow", dur)
	var rod = _rod(0.9)
	h.add_child(rod)
	rod.position = Vector3(randf_range(-0.15, 0.15), randf_range(0.9, 1.4), randf_range(-0.1, 0.1))
	rod.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, 0)
	var tw = rod.create_tween()
	tw.tween_interval(dur)
	tw.tween_method(L.pfn(rod), 0.0, 1.0, 0.25)
	tw.tween_callback(rod.queue_free)
	var wr = weakref(rod)
	pj.every(dur, 0.55, func(_i, _k):
		var r = wr.get_ref()
		if r == null or not is_instance_valid(r) or not r.is_inside_tree():
			return
		var dm = L.disc_mat(0, L.RIN, L.RIN_LINE, L.RIN_DEEP, {"bill": true, "count": 3.0, "speed": 3.0, "alpha": 0.7, "prog": 0.0, "near_cut": 1.2})
		var d = L.disc(pj, r.global_position, 0.7, dm, false)
		L.disc_life(d, 0.12, 0.05, 0.18), Callable())
	Combat.popup_text(h.global_position + Vector3.UP * 2.4, "Çakrası bozuldu", Color(0.7, 0.6, 0.9))


## Kuroki Jūshinki (kanon, Pain / Obito / Madara): avucun içinden kara alıcılar uzar (referans: çubuk avuçtan büyür), dört çubuk
## art arda fırlatılır; ardında ince koyu-mor çakra şeridi. Saplandığı hedefin çakrası bozulur.
static func kuroki_jushinki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 26.0)
	pj.anim(c, "throw", 1.4)
	L.eye_glint(pj, c, 1, 0.9, 0.3)
	# tezahür: avuçtan çıkan çubuk (bir an elde uzar, sonra fırlatılır)
	var hb = pj.bone_attach(c, "RightHand")
	if hb:
		var show = _rod(1.0)
		hb.add_child(show)
		show.scale = Vector3(1, 1, 0.05)
		var stw = show.create_tween()
		stw.tween_property(show, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		stw.tween_interval(0.05)
		stw.tween_callback(hb.queue_free)
		L.burst(pj, pj.hand_pos(c, true), {"amount": 8, "life": 0.35, "radius": 0.1, "vmin": 0.3, "vmax": 1.0, "size": 0.12, "add": false,
			"colors": [Color(0.3, 0.22, 0.45, 0.0), Color(0.18, 0.12, 0.28, 0.8), Color(0.05, 0.03, 0.08, 0.0)]})
	for k in 4:
		pj.after(0.12 + k * 0.07, func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, true)
			var dir = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.04, 0.04))
			var pr = pj.shot(c, from, dir, 46.0, _rod(1.2), pj.inf(c, "kuroki_jushinki", 0.3, {"knock": 1.0, "launch": 0.0, "kind": "light", "weapon": true}), tt, false, 1.2, func(_p, h):
				if h and pj.live(h):
					_pierce(pj, c, h, 4.0))
			if pr:
				_streak(pj, pr, 1.2, 0.035, Color(0.32, 0.24, 0.48, 0.75), 8))
	Sfx.play("kunai", c.global_position, 1.2)


# ================================================================== Fūjutsu Kyūin
## Emilen jutsu: mermiden avuca akan soluk mavi çakra ipi, bariyerde parlama, avuçta toplanan kıvılcımlar
static func _absorb(pj: PathJutsu, c: Node3D, bub: MeshInstance3D, p: Vector3) -> void:
	var bm = L.ghost("kyuin_flow", Color(0.85, 0.95, 1.0), Color(0.45, 0.7, 1.0), {"pattern": 3.0, "a_in": 0.55, "a_edge": 0.9, "flow": 1.8, "glow": 0.4})
	var from_fn = func() -> Vector3:
		return p
	var to_fn = func() -> Vector3:
		return pj.hand_pos(c, true) if is_instance_valid(c) else p
	L.beam(pj, from_fn, to_fn, 0.09, 0.32, bm)
	L.ripple(pj, p, 1.6, 0.22, true, Color(0.7, 0.88, 1.0), 0.04, 0.6)
	L.gather(pj, pj.hand_pos(c, true), 0.5, 10, 0.25, [Color(0.75, 0.9, 1, 0), Color(0.8, 0.92, 1, 1), Color(1, 1, 1, 0)], "mote", true, 0.08)
	if is_instance_valid(bub):
		var tw = bub.create_tween()
		tw.tween_method(L.pfn(bub, "flare"), 1.0, 0.0, 0.35)


## Fūjutsu Kyūin (kanon): bedeni her yönden saran saydam bariyer (referans: Gakidō'yu saran, dokuma ağ desenli soluk mavi küre;
## yutulan jutsu avuca akar) — ninjutsu emilir, fiziksel saldırı geçer. Emme kuralı Jutsu.preta_absorbs (oyuncu/düşman ortak).
static func fujutsu_kyuin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var DUR = 6.0
	if c is Player:
		Buffs.add("fujutsu_kyuin", DUR, {"_name": "Fūjutsu Kyūin", "_desc": "ninjutsu emilir (fiziksel saldırı emilmez; senjutsu taşlaştırır)"})
	else:
		c.set_meta("kyuin_until", Time.get_ticks_msec() / 1000.0 + DUR)
	L.eye_glint(pj, c, 1, 1.0, 0.3)
	# açılış: avuçlarda toplanan çakra, bariyer avuçtan şişerek bedeni sarar
	var hp = pj.hand_pos(c, true)
	L.gather(pj, hp, 1.3, 18, 0.3, [Color(0.75, 0.88, 1, 0), Color(0.75, 0.88, 1, 0.9), Color(1, 1, 1, 0)], "mote", true, 0.1)
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var bub = L.gi(sm, L.ghost("kyuin", Color(0.72, 0.86, 1.0), Color(0.55, 0.76, 1.0), {"a_in": 0.05, "a_edge": 0.55, "pattern": 1.0, "flow": 0.4, "glow": 0.25}))
	c.add_child(bub)
	bub.position = Vector3.UP * 1.0
	bub.scale = Vector3.ONE * 0.1
	bub.create_tween().tween_property(bub, "scale", Vector3(0.85, 1.15, 0.85), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.every(DUR, 0.08, func(_i, _k):
		if not is_instance_valid(bub) or bub.has_meta("off"):
			return
		if not pj.live(c) or not Jutsu.kyuin_on(c):
			bub.set_meta("off", true)
			L.dissolve(bub, 0.0, 0.25)
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			var pinf = p.get("info")
			var nin = pinf is Dictionary and pinf.has("tier") and not pinf.get("weapon", false)
			if nin and p.get("shooter") != c and p.global_position.distance_to(bub.global_position) < 1.9:
				_absorb(pj, c, bub, p.global_position)
				p.queue_free()
				pj.chakra_gain(c, 8.0), func():
		if is_instance_valid(bub) and not bub.has_meta("off"):
			bub.set_meta("off", true)
			L.dissolve(bub, 0.0, 0.3))
	Sfx.play("seal", c.global_position, 0.6)


# ================================================================== Chibaku Tensei
## Chibaku Tensei (kanon): eller çırpılır, avuçlar arasında doğan kara küre göğe fırlatılır (beyaz ışınlı koronalı kara güneş,
## referans), çevredeki her şeyi çekip dev uyduya gömer. Kara küre dünyayı içe büker; zemin çatlar, toz içe kıvrılarak yükselir,
## kayalar sarmal çizip kabuğa oturur. Gömülen yalnız canavar gücüyle kurtulabilir. Tendō 15 sn dolar.
static func chibaku_tensei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	if not Jutsu.tendo_gate(c):
		return
	Jutsu.tendo_spend(c, 15.0)
	pj.busy(c, 1.8)
	pj.anim(c, "cast_in", 1.2)
	var tt = pj.tg(c, t, 40.0)
	var ground = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 16.0)
	var at = ground + Vector3.UP * 32.0
	var halo = Color(0.95, 0.96, 1.0)   # referans: kara kürenin çevresinde beyaz hale (güneş tutulması gibi), mor değil
	if Game.world:
		Game.world.env.flash_tint(Color(0.05, 0.05, 0.06, 0.35), 9.5)
	L.eye_glint(pj, c, 1, 2.0, 0.45)
	# 1) çekirdek: kapkara küre + arkasında beyaz ışınlı korona (kamera yüzlü; küre önünü örter, kenarda hale kalır)
	var core = Node3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 32
	sm.rings = 16
	var bm = StandardMaterial3D.new()
	bm.albedo_color = Color(0.01, 0.01, 0.02)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.disable_fog = true
	core.add_child(L.gi(sm, bm))
	var qm = QuadMesh.new()
	qm.size = Vector2(3.0, 3.0)
	core.add_child(L.gi(qm, L.disc_mat(7, halo, Color.BLACK, Color.BLACK, {"bill": true, "count": 26.0, "alpha": 0.95, "near_cut": 0.0})))
	pj.get_tree().current_scene.add_child(core)
	core.global_position = pj.hand_pos(c, false)
	core.scale = Vector3.ONE * 0.6
	L.gather(pj, core.global_position, 2.2, 28, 0.5, [Color(0.12, 0.1, 0.16, 0.0), Color(0.06, 0.05, 0.1, 0.9), Color(0, 0, 0, 0)], "mote", false, 0.14)
	var tw = core.create_tween()
	tw.tween_property(core, "global_position", at, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(core, "scale", Vector3.ONE * 4.5, 0.7)
	tw.tween_callback(func():
		# kara güneş yerine oturur: kütleçekim nabzı dünyayı içe büker, beyaz parlama
		L.force_sphere(pj, at, 26.0, 5.0, 0.9, -0.06, halo, 3.0)
		L.ripple(pj, at, 18.0, 0.5, true, halo, 0.05, 0.3)
		L.light(pj, at, halo, 14.0, 60.0, 0.8)
		pj.shake(1.2)
		Sfx.play("thunder", at, 0.4))
	# 2) kütleçekim: zemin kopar, kayalar sarmal çizerek çekirdeğe yapışır; küre katman katman büyür
	var rocks: Array = []
	var shell := [4.0]
	pj.after(0.75, func():
		var ck = L.disc(pj, ground + Vector3.UP * 0.06, 70.0, L.disc_mat(4, Color(0.09, 0.07, 0.05), Color(0.26, 0.2, 0.15), Color.BLACK, {"count": 22.0, "alpha": 0.9, "prog": 0.0}))
		L.disc_life(ck, 2.4, 6.5, 1.5)
		for k in 6:   # yerden sökülen toz halkaları: içe kıvrılarak yükselir (itme değil, çekim)
			pj.after(k * 0.4, func():
				L.burst(pj, ground + Vector3.UP * 0.3, {"amount": 30, "life": 1.6, "ring": true, "radius": 30.0 - k * 3.0, "vmin": 3.0, "vmax": 7.0, "dir": Vector3.UP, "spread": 15.0,
					"radial": -5.0, "size": 2.6, "tex": "dust",
					"colors": [Color(0.62, 0.52, 0.4, 0.0), Color(0.6, 0.5, 0.38, 0.9), Color(0.55, 0.47, 0.36, 0.0)]})
				pj.shake(0.6))
		for k in 90:
			pj.after(randf() * 2.4, func():
				var a = randf() * TAU
				var r = randf_range(5.0, 44.0)
				var q = pj.gp(ground + Vector3(cos(a), 0, sin(a)) * r)
				var sz = randf_range(1.5, 5.0) * (1.25 if r > 22.0 else 1.0)
				var rk = L.rock(sz, (L.ROCK.pick_random() as Color).darkened(randf() * 0.15), k)
				pj.get_tree().current_scene.add_child(rk)
				rk.global_position = q - Vector3.UP * sz * 0.4
				rocks.append(rk)
				if sz > 3.2:
					var cd = L.disc(pj, q + Vector3.UP * 0.07, sz * 2.6, L.disc_mat(4, Color(0.1, 0.07, 0.05), Color(0.3, 0.22, 0.15), Color.BLACK, {"count": 9.0, "alpha": 0.85, "prog": 0.0}))
					L.disc_life(cd, 0.15, 3.0, 0.8)
				L.chips(pj, q + Vector3.UP * 0.5, 6, sz * 0.25, 8.0)
				# sarmal yörünge: yükselirken çekirdek etrafında döner, kabuğa oturur
				var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				var start = rk.global_position
				var spin = randf_range(1.5, 3.0) * (1.0 if randf() < 0.5 else -1.0)
				rk.create_tween().tween_method(func(u: float):
					if not is_instance_valid(rk):
						return
					var dest = at + dir * (shell[0] + sz * 0.35)
					var pth = start.lerp(dest, u * u)
					var off = (pth - at)
					off = off.rotated(Vector3.UP, spin * (1.0 - u) * 1.2)
					rk.global_position = at + off + Vector3.UP * sin(u * PI) * 3.0
					rk.rotation += Vector3(0.03, 0.05, 0.02), 0.0, 1.0, randf_range(1.0, 1.6)).set_trans(Tween.TRANS_SINE)
				shell[0] = minf(16.0, shell[0] + 0.17))
		# hedefler havaya çekilip kürenin içine gömülür
		for e in pj.enemies_near(c, ground, 24.0):
			if not (is_instance_valid(e) and not e.is_dead()):
				continue
			e.set_meta("chibaku_hold", true)
			var hold = 4.0 if (e.has_meta("boss") or e is TailedBeast) else 7.0
			pj.st(e, "bind", hold)
			pj.after(hold, func():
				if is_instance_valid(e):
					e.remove_meta("chibaku_hold"))
			if e is Player:
				pj.after(1.8, func():   # kanon: yalnız canavar gücü (Naruto'nun altı kuyruklu hali) uydudan kurtarır
					if is_instance_valid(e) and e.has_status("bind") and Buffs.has("beast"):
						e.statuses.erase("bind")
						e.remove_meta("chibaku_hold")
						L.chips(pj, e.global_position + Vector3.UP, 20, 0.8, 12.0, Vector3.UP, 180.0)
						Combat.popup_text(e.global_position + Vector3.UP * 2.6, "Canavar gücüyle kayaları parçaladı!", Color(1, 0.6, 0.3)))
			var etw = e.create_tween()
			etw.tween_property(e, "global_position", at + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pass)
	# 3) dev kaya ay: kabuk tamamlanınca yavaşça döner, içindekiler ezilir
	pj.after(3.6, func():
		# referans: düzgün küre yüzeyinde iç içe geçmiş yassı, köşeli taş plakalar (çatlak desenli ay), yumru yığın değil
		var mb = MB.new()
		mb.add("sphere", Vector3.ZERO, Vector3.ONE * 27.0, Color(0.2, 0.18, 0.16), Vector3.ZERO, 20)
		for q in 260:
			var dv = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var bs = randf_range(4.0, 7.0)
			var eu = Basis(Quaternion(Vector3.UP, dv)).get_euler() * (180.0 / PI)
			var tone: Color = Color(0.55, 0.52, 0.46).lerp(Color(0.42, 0.4, 0.36), randf())
			mb.add("boulder", dv * 13.3, Vector3(bs, bs * 0.32, bs * randf_range(0.7, 1.0)), tone, eu, q)
		for rk in rocks:   # çekilen kayalar ay yüzeyine gömülür (dışa taşmasın); çöküşte yeniden düşer
			if is_instance_valid(rk):
				rk.visible = false
		var moon = _mesh(mb, L.cel("chibaku_moon", Color.WHITE, {"ow": 0.22, "ocol": Color(0.1, 0.08, 0.07)}))
		pj.get_tree().current_scene.add_child(moon)
		moon.global_position = at
		moon.scale = Vector3.ONE * 0.6
		moon.create_tween().tween_property(moon, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
		moon.create_tween().tween_property(moon, "rotation:y", 0.6, 5.0)
		L.burst(pj, at, {"amount": 40, "life": 2.0, "size": 4.0, "radius": 12.0, "vmin": 2.0, "vmax": 6.0, "tex": "dust",
			"colors": [Color(0.55, 0.5, 0.45, 0.0), Color(0.55, 0.5, 0.45, 0.85), Color(0.5, 0.46, 0.42, 0.0)]})
		pj.shake(1.6)
		pj.every(5.0, 1.0, func(_i, _k):
			for e in pj.enemies_near(c, at, 22.0):
				if is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c, "chibaku_tensei", 0.5, {"knock": 0.0, "kind": "light"}))
			L.chips(pj, at + Vector3(randf_range(-8, 8), -10.0, randf_range(-8, 8)), 4, 0.8, 3.0, Vector3.DOWN, 30.0), Callable())
		# 4) çöküş: ay parçalanır, kayalar yağar
		pj.after(5.2, func():
			L.light(pj, at, Color(0.7, 0.6, 0.5), 8.0, 50.0, 0.6)
			for rk in rocks:
				if not is_instance_valid(rk):
					continue
				rk.visible = true
				var fall = pj.gp(rk.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
				var rtw = rk.create_tween()
				rtw.tween_interval(randf() * 0.4)
				rtw.tween_property(rk, "global_position", fall, randf_range(0.7, 1.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				rtw.tween_callback(func():
					L.chips(pj, fall + Vector3.UP * 0.5, 5, 0.6, 7.0)
					L.burst(pj, fall + Vector3.UP, {"amount": 8, "life": 1.2, "size": 2.2, "radius": 1.5, "vmin": 1.0, "vmax": 4.0, "tex": "dust",
						"colors": [Color(0.6, 0.52, 0.42, 0.0), Color(0.6, 0.52, 0.42, 0.8), Color(0.6, 0.52, 0.42, 0.0)]}))
				rtw.tween_interval(4.0)
				rtw.tween_property(rk, "scale", Vector3.ONE * 0.05, 0.6)
				rtw.tween_callback(rk.queue_free)
			if is_instance_valid(moon):
				var mtw = moon.create_tween()
				mtw.tween_property(moon, "scale", Vector3.ONE * 0.05, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				mtw.tween_callback(moon.queue_free)
			for e in pj.enemies_near(c, at, 20.0):
				if is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c, "chibaku_tensei", 1.4, {"knock": 6.0, "launch": 2.0, "kind": "heavy"}))
			pj.shake(1.8)
			Sfx.play("boom", ground, 0.6)))
	tw.tween_interval(8.5)
	tw.tween_property(core, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(core.queue_free)
	Sfx.play("earth", c.global_position, 0.4)


# ================================================================== Sharingan genjutsuları
## Iatsu Sharingan (kanon): tek bir BAKIŞ — kurbana kabus genjutsusu çöker, ezici baskı onu dizlerinin üstüne düşürür.
## Görünüş (referans: kara damarlı kızıl karanlıkta kurbanın üstünde asılı dev Sharingan): kullanıcının gözü parlar, bakış
## yönünde üç kızıl kıvrım kurbana doğru çöker, kurbanın tepesinde dev üç tomoeli göz belirir, altında damarlı kızıl zemin;
## baskı kara-kızıl lekeleri kurbanın üstüne bastırır. Tek hedef, göz teması şart.
static func iatsu_sharingan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.eye_glint(pj, c, 0, 2.5, 0.5)
	var tt = pj.tg(c, t, 18.0)
	if tt == null:
		return
	pj.busy(c, 0.6)
	var gm = pj._gen_power(c) * Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var dur = 2.6 * gm
	pj.st(tt, "stun", dur)
	pj.st(tt, "fear", dur + 1.5)
	var from = L.eye_world(c)
	var to = tt.global_position + Vector3.UP * 1.4
	for k in 3:
		pj.after(k * 0.08, func():
			L.ripple(pj, from.lerp(to, 0.35 + k * 0.3), 2.0 + k * 1.2, 0.3, true, Color(0.8, 0.04, 0.05), 0.045, 0.85))
	pj.after(0.2, func():
		if not pj.live(tt):
			return
		if tt.get("model"):
			tt.model.play("crouch", 0.05, 1.0)
		var h = _h(tt)
		var em = L.disc_mat(5, Color(0.62, 0.04, 0.05), Color(0.08, 0.0, 0.01), Color(0.25, 0.0, 0.02), {"bill": true, "speed": 0.5, "alpha": 0.0, "near_cut": 4.0})
		var eye = L.disc(pj, tt.global_position + Vector3.UP * (h + 2.4), clampf(h * 2.2, 3.5, 12.0), em, false)
		var etw = eye.create_tween()
		etw.tween_method(L.sp(em, "alpha"), 0.0, 0.92, 0.2)
		etw.parallel().tween_property(eye, "global_position", tt.global_position + Vector3.UP * (h + 1.6), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		etw.tween_interval(maxf(0.1, dur - 0.6))
		etw.tween_method(L.sp(em, "alpha"), 0.92, 0.0, 0.3)
		etw.tween_callback(eye.queue_free)
		L.burst(pj, tt.global_position + Vector3.UP * h * 1.25, {"amount": 18, "life": 0.6, "size": 0.9 * h / 1.8, "radius": 0.6, "vmin": 2.0, "vmax": 4.0, "dir": Vector3.DOWN, "spread": 40.0,
			"tex": "mote", "colors": [Color(0.3, 0.0, 0.03, 0.0), Color(0.14, 0.0, 0.02, 0.9), Color(0.03, 0.0, 0.01, 0.0)]})
		L.tint_layer(pj, tt, dur, Color(0.7, 0.0, 0.03))
		pj.shake(0.35))
	pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, "iatsu_sharingan", 0.5, {"knock": 0.0}))
	if Game.world and c is Player:
		Game.world.env.flash_tint(Color(0.6, 0.0, 0.0, 0.14), 0.6)
	Sfx.play("genjutsu", tt.global_position, 0.7)


## Magen: Shinkarasu (kanon, Itachi): göz teması GEREKMEZ — kullanıcıdan bir karga seli boşalır, kurbanı sarıp yutar ve onu
## savunmasız bırakır. Kargalar tırtıklı kara siluetler (referans), kurbanın altında pembe-kızıl girdap döner; sonunda kargalar
## dağılıp kara tüylere dönüşür.
static func magen_shinkarasu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.eye_glint(pj, c, 0, 2.0, 0.4)
	var tt = pj.tg(c, t, 26.0)
	if tt == null:
		return
	pj.busy(c, 0.5)
	pj.anim(c, "cast_out", 1.2)
	var gm = pj._gen_power(c) * Eyes.genjutsu_land(c, tt, false)
	var crows = []
	var N = 34
	for k in N:
		pj.after(k * 0.025, func():
			if not (is_instance_valid(c) and pj.live(tt)):
				return
			var cr = L.crow()
			pj.get_tree().current_scene.add_child(cr)
			var from = c.global_position + Vector3.UP * 1.3 + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.4), randf_range(-0.4, 0.4))
			cr.global_position = from
			cr.scale = Vector3.ONE * randf_range(0.8, 1.2) * 1.6
			crows.append({"n": cr, "a": randf() * TAU, "r": randf_range(0.5, 1.6), "y": randf_range(0.3, 2.3), "w": randf_range(3.0, 6.0) * (1.0 if randf() < 0.5 else -1.0), "t": 0.0, "from": from}))
	var dur = 3.2
	pj.every(dur, 1.0 / 30.0, func(i, _k):
		var cen = tt.global_position if pj.live(tt) else c.global_position
		for cr in crows:
			var b = cr["n"]
			if not is_instance_valid(b):
				continue
			cr["t"] += 1.0 / 30.0
			cr["a"] += cr["w"] / 30.0
			var orbit = cen + Vector3(cos(cr["a"]) * cr["r"], cr["y"], sin(cr["a"]) * cr["r"])
			var prev = b.global_position
			var k = clampf(cr["t"] / 0.35, 0.0, 1.0)   # önce sel hâlinde hedefe akar, sonra etrafında döner
			b.global_position = (cr["from"] as Vector3).lerp(orbit, k * k * (3.0 - 2.0 * k)) if k < 1.0 else prev.lerp(orbit, 0.35)
			var dv = b.global_position - prev
			if dv.length() > 0.01 and absf(dv.normalized().y) < 0.97:   # büyük dünya koordinatında küçük fark kaybolmasın: birim yön
				b.look_at(b.global_position + dv.normalized() * 3.0, Vector3.UP)
			L.flap(b, cr["t"] * 2.2)
		if i == 12 and gm > 0.0 and pj.live(tt):
			# karga seli kurbanı yuttu: savunmasız
			pj.st(tt, "stun", 2.4 * gm)
			pj.st(tt, "fear", 3.0 * gm)
			if tt.has_method("lose_target"):
				tt.lose_target(3.0 * gm)
			L.tint_layer(pj, tt, 2.4 * gm, Color(0.3, 0.05, 0.08), 1)
		if i % 10 == 5 and gm > 0.0 and pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, "magen_shinkarasu", 0.1, {"knock": 0.0}))
	, func():
		var sum = Vector3.ZERO
		var cnt = 0
		for cr in crows:
			var b = cr["n"]
			if is_instance_valid(b):
				sum += b.global_position
				cnt += 1
				L.dissolve(b, 0.0, 0.25)
		if cnt > 0:
			L.feathers(pj, sum / cnt, mini(70, cnt * 3), 1.4))
	Sfx.play("genjutsu", tt.global_position, 1.2)


## Magen: Kasegui no Jutsu (kanon): önce Genjutsu: Sharingan (GÖZ TEMASI) — yanılsamada kurbanın bedenine yukarıdan dev kara
## kazıklar çakılır, hareket özgürlüğü elinden alınır; acı gerçektir. Kazıklar kara, kenarı kızıl (yanılsama); her çakılışta
## kızıl tırtıklı parlama ve yerde mürekkep lekesi; bitince kazıklar piksel piksel dağılır.
static func magen_kasegui_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.eye_glint(pj, c, 0, 2.0, 0.45)
	var tt = pj.tg(c, t, 22.0)
	if tt == null:
		return
	pj.busy(c, 0.5)
	var gm = pj._gen_power(c) * Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var dur = 3.5 * gm
	pj.st(tt, "bind", dur)
	L.tint_layer(pj, tt, dur, Color(0.5, 0.0, 0.03))
	var cen = tt.global_position
	var mat = L.cel("kasegui", Color(0.07, 0.02, 0.03), {"vcol": false, "ow": 0.035, "ocol": Color(0.78, 0.03, 0.06), "rim": Color(0.62, 0.02, 0.05), "rim_amt": 0.8})
	var stakes = []
	for k in 6:
		pj.after(0.12 + k * 0.11, func():
			if not pj.live(tt):
				return
			var a = k * TAU / 6.0 + randf_range(-0.3, 0.3)
			var tilt = randf_range(0.35, 0.65)
			var dir = Vector3(cos(a) * sin(tilt), -cos(tilt), sin(a) * sin(tilt)).normalized()   # yukarıdan, eğik çakılır
			var through = tt.global_position + Vector3.UP * randf_range(0.6, 1.5)
			var b = MB.new()
			b.add("cone", Vector3(0, 0, -1.6), Vector3(0.22, 1.0, 0.22), Color.WHITE, Vector3(-90, 0, 0), 6)
			b.add("cyl", Vector3(0, 0, 0.6), Vector3(0.26, 3.4, 0.26), Color.WHITE, Vector3(90, 0, 0), 6)
			b.add("cyl", Vector3(0, 0, 2.35), Vector3(0.36, 0.14, 0.36), Color.WHITE, Vector3(90, 0, 0), 8)   # çakılan baş
			var mi = _mesh(b, mat)
			pj.get_tree().current_scene.add_child(mi)
			var start = through - dir * 5.0
			mi.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD), start)
			var end = through + dir * 0.9
			var tw = mi.create_tween()
			tw.tween_property(mi, "global_position", end, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_flash(pj, through, 1.3, Color(0.85, 0.06, 0.08), Color(1.0, 0.75, 0.7), Color(0.1, 0.0, 0.01), 0.14, 6.0)
				L.burst(pj, through, {"amount": 10, "life": 0.5, "size": 0.14, "vmin": 2.0, "vmax": 5.0, "gravity": Vector3(0, -6, 0),
					"colors": [Color(0.7, 0.02, 0.04, 1), Color(0.3, 0.0, 0.02, 0)]})
				var sp = L.disc(pj, pj.gp(through) + Vector3.UP * 0.05, randf_range(0.9, 1.4), L.disc_mat(9, Color(0.18, 0.0, 0.02), Color.BLACK, Color.BLACK, {"alpha": 0.85, "prog": 0.0}))
				L.disc_life(sp, 0.08, maxf(0.2, dur - 0.5), 0.5)
				pj.shake(0.12)
				Sfx.play("kunai", through, 0.6))
			stakes.append(mi))
	# işkence: acı gerçek — süre boyunca tik hasarı, kurban kıvranır
	pj.every(dur, 0.5, func(i, _k):
		if pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, "magen_kasegui_no_jutsu", 0.12, {"knock": 0.0, "kind": "light"}))
			if i % 2 == 0 and tt.get("model"):
				tt.model.play("hit", 0.05, 0.8, true), func():
		for mi in stakes:
			if is_instance_valid(mi):
				L.dissolve(mi, 0.0, 0.35))
	if Game.world and tt == Game.player:
		Game.world.env.flash_tint(Color(0.35, 0.0, 0.05, 0.3), 1.2)
	Sfx.play("genjutsu", cen, 0.8)


# ================================================================== Mazō no Kusari
## Zincir: iri oval halkalar (sırayla 90° dönük, birbirine geçer), her halkanın sırtında diken; uçta ejder başı. sc: ölçek
static func _chain(parent: Node3D, a: Vector3, b: Vector3, sc: float, mat: Material, grow: float, dragon_head := true) -> void:
	var link_len = 0.3 * sc
	var step = 0.2 * sc
	var Ln = a.distance_to(b)
	var n = maxi(2, int(Ln / step))
	var tm = TorusMesh.new()
	tm.inner_radius = 0.055 * sc
	tm.outer_radius = 0.1 * sc
	tm.rings = 10
	tm.ring_segments = 6
	var spk = CylinderMesh.new()
	spk.top_radius = 0.0
	spk.bottom_radius = 0.03 * sc
	spk.height = 0.12 * sc
	spk.radial_segments = 5
	var sag = Ln * 0.06
	for j in n + 1:
		var u = float(j) / n
		var p = a.lerp(b, u) + Vector3.DOWN * sin(u * PI) * sag
		var u2 = minf(1.0, u + 0.01)
		var d = (a.lerp(b, u2) + Vector3.DOWN * sin(u2 * PI) * sag) - p
		if d.length() < 0.0001:
			d = b - a
		d = d.normalized()
		var n1 = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
		var axis = n1 if j % 2 == 0 else d.cross(n1).normalized()
		var xb = axis.cross(d).normalized()
		var link = L.gi(tm, mat)
		parent.add_child(link)
		var basis = Basis(xb, axis, d) * Basis.from_scale(Vector3(1.0, 1.0, link_len / (0.2 * sc)))
		if j % 2 == 1:   # referans: halkanın sırtında yukarı bakan diken
			var spm = L.gi(spk, mat)
			link.add_child(spm)
			spm.position = Vector3(0, 0.12 * sc, 0) if absf(axis.y) < 0.5 else Vector3(0.12 * sc, 0, 0)
			spm.rotation = Vector3.ZERO if absf(axis.y) < 0.5 else Vector3(0, 0, -PI * 0.5)
		link.global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * 0.01), p)
		var tw = link.create_tween()
		tw.tween_interval(maxf(0.001, u * grow))
		tw.tween_method(func(x: float):
			if is_instance_valid(link):
				link.global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * x), p), 0.01, 1.0, 0.05 if grow > 0.0 else 0.01)
	if not dragon_head:   # Obito'nun alıcı zincirleri: düz uç
		return
	# ejder başı (uç; Madara'nın heykel zincirleri): yassı, uzun burunlu, zikzak çeneli, pembe göz
	var hb = MB.new()
	var W = Color(0.9, 0.88, 0.98)
	Loft.tube(hb, [Vector3(0, 0, 0.5), Vector3(0, 0.06, 0.0), Vector3(0, 0.03, -0.75), Vector3(0, -0.04, -1.2)], [Vector2(0.32, 0.22), Vector2(0.34, 0.24), Vector2(0.2, 0.12), Vector2(0.05, 0.04)], W, 10, 3)
	for sx in [-1.0, 1.0]:
		hb.add("box", Vector3(sx * 0.22, 0.15, -0.35), Vector3(0.16, 0.03, 0.04), Color(0.95, 0.5, 0.8), Vector3(0, sx * 15, 0))
		for q in 5:
			hb.add("cone", Vector3(sx * (0.18 - q * 0.025), -0.12, -0.3 - q * 0.17), Vector3(0.05, 0.1, 0.04), Color(0.25, 0.2, 0.35), Vector3(0, 0, 0), 4)
		for q in 3:   # geriye savrulan yele dişleri
			hb.add("cone", Vector3(sx * 0.12, 0.2, 0.25 + q * 0.18), Vector3(0.07, 0.25, 0.06), W, Vector3(-60, 0, sx * 20), 4)
	var head = _mesh(hb, L.cel("mazo_head", Color.WHITE, {"glow": 0.15, "ow": 0.02, "ocol": Color(0.32, 0.22, 0.55)}))
	parent.add_child(head)
	var dir = (b - a).normalized()
	head.global_position = b
	head.look_at(b + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)   # burun (-Z) hedefe
	head.scale = Vector3.ONE * 0.01
	var htw = head.create_tween()
	htw.tween_interval(maxf(0.001, grow))
	htw.tween_property(head, "scale", Vector3.ONE * sc * 0.55, 0.08)


## Boyna dolanan zincir tasması (kanon: zincirler boyunları tasma gibi sarar)
static func _collar(tt: Node3D, sc: float, mat: Material) -> void:
	var col = Node3D.new()
	tt.add_child(col)
	var h = 1.45 if not (tt is TailedBeast) else float(tt.height) * 0.6
	col.position = Vector3.UP * h
	var big = tt is TailedBeast
	var r = (float(tt.height) * 0.12 if big else 0.2)
	var tm = TorusMesh.new()
	tm.inner_radius = 0.035 * (sc if big else 1.0)
	tm.outer_radius = 0.06 * (sc if big else 1.0)
	tm.rings = 8
	tm.ring_segments = 6
	var n = 12
	for k in n:
		var ang = TAU * k / n
		var l = L.gi(tm, mat)
		col.add_child(l)
		l.position = Vector3(cos(ang), 0, sin(ang)) * r
		l.rotation = Vector3(PI * 0.5 if k % 2 == 0 else 0.0, -ang, 0)
	var tw = col.create_tween()
	tw.tween_interval(3.6)
	tw.tween_method(L.pfn(col), 0.0, 1.0, 0.3)
	tw.tween_callback(col.queue_free)


## Mazō no Kusari (kanon): Gedō Mazō'nun ağzından fışkıran ejder başlı zincirler hedeflerin boynuna dolanır, onları heykele
## sürükler; kuyruklu canavar gücü bastırılır. Heykel yoksa çağıranın elinden düz uçlu kısa zincir. Ağızda beyaz-lila tırtıklı
## ışık patlaması (referans: zincirler beyaz-mor ışıktan fışkırır); halkalar beyaz-lila, mor konturlu.
static func mazo_no_kusari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var statue: Node3D = null
	for g in pj.get_tree().get_nodes_in_group("gedo_mazo"):
		if is_instance_valid(g) and g.get_meta("owner_f", null) == c and not g.has_meta("leaving"):
			statue = g
	var targets: Array = []
	if statue:
		targets = pj.enemies_near(c, c.global_position, 85.0)
		targets.sort_custom(func(x, y): return x.global_position.distance_to(c.global_position) < y.global_position.distance_to(c.global_position))
		targets = targets.slice(0, 9)
		statue.open_mouth(1.0)
		var mp = statue.mouth_pos()
		_flash(pj, mp, 14.0, Color(0.82, 0.72, 1.0), Color(1, 1, 1), Color(0.32, 0.22, 0.55), 0.5, 9.0)
		L.burst(pj, mp, {"amount": 26, "life": 0.6, "size": 1.2, "radius": 2.0, "vmin": 4.0, "vmax": 12.0, "dir": statue.global_transform.basis.z * -1.0, "spread": 70.0, "add": true,
			"colors": [Color(0.95, 0.9, 1, 0.9), Color(0.6, 0.45, 1, 0)]})
		L.light(pj, mp, Color(0.85, 0.75, 1.0), 6.0, 30.0, 0.6)
	else:
		var tt = pj.tg(c, t, 26.0)
		if tt:
			targets = [tt]
	if targets.is_empty():
		if c is Player:
			Hud.msg("Mazō no Kusari: menzilde hedef yok.", Color(0.8, 0.75, 1.0))
		return
	L.eye_glint(pj, c, 1, 1.2, 0.3)
	var sc = 7.0 if statue else 1.4
	var mat = L.cel("mazo_%d" % int(sc), Color(0.93, 0.91, 1.0), {"vcol": false, "glow": 0.2, "ow": 0.012 * sc, "ocol": Color(0.32, 0.22, 0.55), "rim": Color(1, 1, 1), "rim_amt": 0.4})
	if statue == null:   # elden çıkış: avuçta küçük lila parlama
		_flash(pj, pj.hand_pos(c, true), 0.9, Color(0.82, 0.72, 1.0), Color(1, 1, 1), Color(0.32, 0.22, 0.55), 0.2, 7.0)
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	for i in targets.size():
		var tt: Node3D = targets[i]
		var from: Vector3 = (statue.mouth_pos() if statue else pj.hand_pos(c, true))
		var neck = tt.global_position + Vector3.UP * (1.45 if not (tt is TailedBeast) else float(tt.height) * 0.6)
		pj.after(0.05 + i * 0.08, func():
			if not (pj.live(tt) and pj.live(c)):
				return
			var Ln = from.distance_to(neck)
			var grow = clampf(Ln / 60.0, 0.25, 0.8)
			var cn = Node3D.new()
			root.add_child(cn)
			_chain(cn, from, neck, sc, mat, grow, statue != null)
			pj.after(grow + 0.05, func():
				if not (pj.live(tt) and pj.live(c)):
					return
				_collar(tt, sc, mat)
				_flash(pj, tt.global_position + Vector3.UP * (1.45 if not (tt is TailedBeast) else float(tt.height) * 0.6), 1.2 if not (tt is TailedBeast) else 6.0,
					Color(0.82, 0.72, 1.0), Color(1, 1, 1), Color(0.32, 0.22, 0.55), 0.16, 6.0)
				var boss = tt.has_meta("boss") or tt is TailedBeast
				var beast = tt is TailedBeast or String(tt.get_meta("faction", "")) == "beast" or (tt is Player and TailedBeasts.player_jinchuriki() != "") or tt.has_meta("jinchuriki")
				var hold = (1.6 if boss else 3.2) * (1.0 if statue else 0.8)
				pj.st(tt, "bind", hold)
				if beast:
					pj.st(tt, "sealed", hold + 3.0)   # lanet mührü: kuyruklu canavar gücü bastırılır
					Combat.popup_text(tt.global_position + Vector3.UP * 3.0, "Canavar gücü bastırıldı", Color(0.8, 0.7, 1.0))
				tt.take_hit(pj.inf(c, "mazo_no_kusari", 0.9, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
				# heykele (ya da kullanıcıya) sürüklenir
				if not boss and not (tt is TailedBeast):
					var dest = pj.gp((statue.global_position + statue.global_transform.basis * Vector3(0, 0, -26.0)) if statue else c.global_position + c.face_dir() * 2.5)
					var dd = dest - tt.global_position
					dd.y = 0.0
					var pull = minf(dd.length(), 12.0 if statue else 6.0)
					if pull > 0.5:
						var tw = tt.create_tween()
						tw.tween_property(tt, "global_position", pj.gp(tt.global_position + dd.normalized() * pull), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						tw.tween_callback(func():   # zincir gergin kalır: yeni konuma yeniden kurulur
							if is_instance_valid(cn) and pj.live(tt):
								for ch in cn.get_children():
									ch.queue_free()
								var src: Vector3 = (statue.mouth_pos() if is_instance_valid(statue) else pj.hand_pos(c, true)) if pj.live(c) else from
								_chain(cn, src, tt.global_position + Vector3.UP * 1.45, sc, mat, 0.0, statue != null))))
	pj.after(4.0, func():
		if is_instance_valid(root):
			var tw = root.create_tween()
			tw.tween_method(L.pfn(root), 0.0, 1.0, 0.3)
			tw.tween_callback(root.queue_free)
		if is_instance_valid(statue):
			statue.open_mouth(0.6))
	Sfx.play("chain", c.global_position, 0.8)


# ================================================================== Tendō (Chō Shinra Tensei)
## Krater kenarında dışa devrilmiş toprak levhaları: yerden fırlar, bir süre kalır, sonra gömülür
static func _rim_slabs(pj: PathJutsu, g: Vector3, r: float) -> void:
	var n = 30
	for k in n:
		var ang = TAU * k / n + randf_range(-0.05, 0.05)
		var dv = Vector3(cos(ang), 0, sin(ang))
		var p = pj.gp(g + dv * r * randf_range(0.42, 0.55))
		var s = r * randf_range(0.05, 0.09)
		var rk = L.rock(s, (L.ROCK.pick_random() as Color).darkened(0.1), k)
		pj.get_tree().current_scene.add_child(rk)
		rk.global_position = p - Vector3.UP * s
		var up = (dv * 0.7 + Vector3.UP).normalized()
		rk.global_transform.basis = Basis(Quaternion(Vector3.UP, up)) * Basis.from_scale(Vector3(1.2, 0.45, 0.8))
		var tw = rk.create_tween()
		tw.tween_interval(r * 0.012)
		tw.tween_property(rk, "global_position", p + Vector3.UP * s * 0.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(10.0)
		tw.tween_property(rk, "global_position", p - Vector3.UP * s * 1.2, 1.5)
		tw.tween_callback(rk.queue_free)


## Shinra Tensei çekirdeği (mekanik jutsu.gd shinra_core'dan aynen; görünüş bu dosyada): görünmez kuvvet dünyayı büken dev bir
## küre olarak yayılır, zemin dışa kazınır (ışınsal krater + devrilen toprak levhaları), toz perdeleri ve kaya parçaları dışa
## savrulur. Düşmanlar savrulur, ninjutsu mermileri geri çevrilir, kara alevler savrulur, ağaç / ev yıkılır.
static func _shinra(pj: PathJutsu, c: Node3D, center: Vector3, r: float, power: float) -> void:
	var g = Vector3(center.x, Game.jutsu_floor(center.x, center.z), center.z)
	L.force_sphere(pj, center, 0.5, r, 0.7 + r * 0.01, 0.07, Color(0.85, 0.97, 0.9), 0.0)
	pj.after(0.12, func():
		L.force_sphere(pj, center, 0.5, r * 0.7, 0.6 + r * 0.01, 0.04, Color(0.85, 0.97, 0.9), 2.0))
	var cr = L.disc(pj, g + Vector3.UP * 0.06, r * 2.2, L.disc_mat(4, Color(0.11, 0.08, 0.06), Color(0.36, 0.25, 0.16), Color.BLACK, {"count": 28.0, "alpha": 0.92, "prog": 0.0}))
	L.disc_life(cr, 0.5, 12.0, 3.0)
	L.burst(pj, g + Vector3.UP * 0.4, {"amount": 64, "life": 1.1, "ring": true, "radius": maxf(1.0, r * 0.08), "vmin": 2.0, "vmax": 5.0, "dir": Vector3.UP, "spread": 30.0,
		"radial": r * 2.0, "damp": 2.0, "size": 1.0 + r * 0.06, "tex": "dust",
		"colors": [Color(0.66, 0.58, 0.48, 0.0), Color(0.66, 0.58, 0.48, 0.9), Color(0.6, 0.53, 0.44, 0.0)]})
	L.chips(pj, g + Vector3.UP * 0.6, int(20 + r * 0.6), 0.4 + r * 0.01, r * 0.9, Vector3.UP, 80.0, 1.4)
	L.light(pj, center, Color(0.92, 1.0, 0.95), 10.0, r * 1.2, 0.5)
	Sfx.play("boom", center, clampf(0.7 - r * 0.004, 0.35, 0.7))
	if Game.world:
		Game.world.env.add_shake(clampf(0.6 + r * 0.04, 0.6, 2.4))
	WorldDamage.impact(g, r * 0.8, {"dmg": 40.0 * power, "knock": 30.0, "kind": "heavy"})
	if r >= 20.0:
		_rim_slabs(pj, g, r)
	for pr in pj.get_tree().get_nodes_in_group("projectiles"):
		if pr.shooter != c and not pr.dead and pr.global_position.distance_to(center) < r + 2.0:
			pr.apply_clash(false, 0.0)
	if center.distance_to(c.global_position + Vector3.UP) < r:
		for spt in Amaterasu.spots.duplicate():
			if spt["target"] == c:
				Amaterasu._drop(spt, 2.0)
				Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Kara alevler savruldu", Color(0.8, 0.9, 0.85))
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and not f.is_dead() and f.global_position.distance_to(center) < r + f.radius:
			var dd = f.global_position - center
			dd.y = 0
			if dd.length() < 0.1:
				dd = f.global_position - c.global_position
				dd.y = 0
			var heavy = f is TailedBeast or f.has_meta("boss")
			var k = (0.4 if heavy else 1.0) * power
			f.take_hit(pj.inf(c, "shinra_tensei", 1.1 * power, {"knock": 30.0 * k, "launch": 7.0 * k, "kind": "heavy", "dir": dd.normalized(), "attacker": c}))


## Chō Shinra Tensei (kanon, Pain'in Konoha saldırısı): Tendō göğe yükselir, chakrasını uzun süre toplar ve bütün alanı yerle
## bir eden dev itmeyi bırakır. Kuvvet görünmezdir (referans: yağmur ve kayalar itilir, kuvvetin kendisi görünmez): yükselirken
## yer tozları ona doğru emilir, kuvvet bedeninin çevresinde içe çöken kıvrımlarla sıkışır, sonra dünyayı büken dev küre
## yayılır. Bedeli: uzun Tendō dolumu (25 sn) ve ömür (canın %8'i); ardından bitkin düşer.
static func tendo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	if not Jutsu.tendo_gate(c):
		return
	Jutsu.tendo_spend(c, 25.0)
	pj.busy(c, 2.6)
	if c is Player:
		c.input_locked = 2.4
	var base = c.global_position
	var sky = base + Vector3.UP * 16.0
	var tw = c.create_tween()
	tw.tween_property(c, "global_position", sky, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	L.eye_glint(pj, c, 1, 2.6, 0.4)
	L.gather(pj, sky + Vector3.UP, 7.0, 40, 1.1, [Color(0.85, 0.97, 0.9, 0.0), Color(0.9, 1.0, 0.95, 0.7), Color(1, 1, 1, 0)], "mote", true, 0.16)
	L.burst(pj, base + Vector3.UP * 0.2, {"amount": 20, "life": 1.0, "ring": true, "radius": 3.0, "vmin": 2.0, "vmax": 5.0, "dir": Vector3.UP, "spread": 20.0, "radial": -2.0,
		"size": 1.0, "tex": "dust", "colors": [Color(0.66, 0.58, 0.48, 0.0), Color(0.66, 0.58, 0.48, 0.8), Color(0.6, 0.53, 0.44, 0.0)]})
	pj.after(1.1, func():
		if pj.live(c):
			Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Shinra Tensei...", Color(0.85, 0.97, 0.9))
			for k in 3:
				pj.after(k * 0.25, func():
					if pj.live(c):
						L.ripple(pj, c.global_position + Vector3.UP, 7.0, 0.35, true, Color(0.85, 0.97, 0.9), 0.04, 0.35))
			L.force_sphere(pj, c.global_position + Vector3.UP, 3.0, 0.6, 0.9, -0.05, Color(0.85, 0.97, 0.9), 0.0))
	pj.after(2.0, func():
		if not pj.live(c):
			return
		_shinra(pj, c, pj.gp(c.global_position) + Vector3.UP * 2.0, 42.0, 2.0)
		if Game.world:
			Game.world.env.screen_flash(0.3)
		c.hp = maxf(1.0, c.hp - c.max_hp * 0.08)
		Combat.popup_text(c.global_position + Vector3.UP * 3.0, "Ömür bedeli", Color(0.75, 0.4, 0.45))
		if c is Player:
			Buffs.add("tendo_bitkin", 8.0, {"speed": 0.8, "_name": "Bitkin", "_desc": "Chō Shinra Tensei: chakra ve beden tükendi"}))
	Sfx.play("wind", c.global_position, 0.5)


# ================================================================== Kaiwan no Hiya
static func _fist() -> Node3D:
	var b = MB.new()
	var sk = Color(0.92, 0.76, 0.64)
	Loft.blob(b, Vector3(0, 0, -0.06), Vector3(0, 0, -1), 0.26, [Vector2(0.07, 0.06), Vector2(0.09, 0.075), Vector2(0.085, 0.07), Vector2(0.06, 0.05)], sk, 10)
	for k in 4:
		b.add("sphere", Vector3(lerpf(-0.06, 0.06, k / 3.0), 0.03, -0.17), Vector3(0.045, 0.05, 0.05), sk, Vector3.ZERO, 6)
	b.add("cyl", Vector3(0, 0, 0.06), Vector3(0.14, 0.04, 0.14), Color(0.35, 0.35, 0.4), Vector3(90, 0, 0), 10)   # bilek yarığı
	var mi = _mesh(b, L.cel("shura_skin", Color.WHITE, {"ow": 0.012, "ocol": Color(0.22, 0.12, 0.08)}))
	mi.scale = Vector3.ONE * 1.6
	var root = Node3D.new()
	root.add_child(mi)
	return root


## Bilek yarığından fışkıran itki alevi: mermiyi izleyen dünya koordinatlı kıvılcım akışı (sarı → turuncu → koyu kızıl)
static func _exhaust(pj: PathJutsu, pr: Node3D, dur: float) -> void:
	var ps = L.burst(pj, pr.global_position, {"amount": 40, "life": 0.3, "loop": dur, "radius": 0.06, "vmin": 0.2, "vmax": 1.0, "size": 0.32, "add": true,
		"colors": [Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.15, 0.8), Color(0.4, 0.08, 0.02, 0)]})
	_follow(ps, pr, Vector3.ZERO, dur)


## Kaiwan no Hiya (kanon, Shuradō: "Şaşırtıcı Yeteneğin Alevli Oku"): ön kol bilekten kopar, alev itkili bir füze gibi fırlar;
## çarpınca tırtıklı sarı-turuncu patlama (referans: yumruğun çevresinde sivri ışınlı sarı parlama ve hız çizgileri), kaya
## parçaları; yumruk mıknatıs gibi bileğe geri döner.
static func kaiwan_no_hiya(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 34.0)
	pj.anim(c, "cross", 1.2)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var dir = pj.aim_at(c, tt, from)
		pj._asura_hand(c, true)
		_flash(pj, from, 1.6, Color(1.0, 0.72, 0.25), Color(1.0, 0.97, 0.75), Color(0.35, 0.12, 0.04), 0.16, 9.0)
		L.burst(pj, from, {"amount": 14, "life": 0.35, "size": 0.2, "radius": 0.15, "vmin": 4.0, "vmax": 9.0, "dir": -dir, "spread": 40.0, "add": true, "tex": "glint",
			"colors": [Color(1, 0.95, 0.6, 1), Color(1, 0.45, 0.1, 0.8), Color(0.3, 0.1, 0.05, 0)]})
		var fist = _fist()
		var pr = pj.shot(c, from, dir, 42.0, fist, pj.inf(c, "kaiwan_no_hiya", 2.0, {"knock": 20.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.08}), tt, false, 1.0, func(pp, _h):
			_flash(pj, pp, 4.2, Color(1.0, 0.7, 0.25), Color(1.0, 0.98, 0.8), Color(0.4, 0.14, 0.04), 0.3, 11.0)
			L.burst(pj, pp, {"amount": 22, "life": 0.45, "size": 0.16, "radius": 0.3, "vmin": 8.0, "vmax": 16.0, "add": true, "tex": "glint",
				"colors": [Color(1, 1, 0.85, 1), Color(1, 0.6, 0.2, 0.7), Color(0.5, 0.15, 0.05, 0)]})
			L.chips(pj, pp, 14, 0.4, 8.0)
			L.light(pj, pp, Color(1.0, 0.7, 0.3), 6.0, 12.0, 0.35)
			pj.shake(0.6)
			# geri dönüş: bilekteki çakra eli mıknatıs gibi çeker
			var back = _fist()
			pj.get_tree().current_scene.add_child(back)
			back.global_position = pp
			var btw = back.create_tween()
			btw.tween_method(func(u: float):
				if is_instance_valid(back) and pj.live(c):
					back.global_position = pp.lerp(pj.hand_pos(c, true), u * u)
					back.look_at(pj.hand_pos(c, true) + Vector3(0.001, 0, 0), Vector3.UP), 0.0, 1.0, 0.35)
			btw.tween_callback(func():
				back.queue_free()
				if pj.live(c):
					pj._asura_hand(c, false)))
		if pr:
			_exhaust(pj, pr, 1.0)
		else:
			pj._asura_hand(c, false)
		pj.after(1.6, func():   # güvence: el her durumda geri gelir
			if pj.live(c):
				pj._asura_hand(c, false)))
	Sfx.play("boom", c.global_position, 1.3)


# ================================================================== Ningendō
## Ruh silueti: yarı saydam beyaz, kenarı lila parlayan insan biçimi; tülü yukarı akar (referans: başın tepesinden çekilen ruh)
static func _soul() -> Node3D:
	var b = MB.new()
	var W = Color(0.92, 0.94, 1.0)
	b.add("sphere", Vector3(0, 1.62, 0), Vector3(0.36, 0.42, 0.36), W, Vector3.ZERO, 10)
	Loft.tube(b, [Vector3(0, 1.4, 0), Vector3(0, 1.0, 0.03), Vector3(0, 0.75, 0)], [Vector2(0.2, 0.13), Vector2(0.17, 0.12), Vector2(0.15, 0.11)], W, 8, 2)
	for sx in [-1.0, 1.0]:
		Loft.tube(b, [Vector3(sx * 0.2, 1.35, 0), Vector3(sx * 0.45, 1.05, -0.1), Vector3(sx * 0.6, 1.25, -0.3)], [0.06, 0.05, 0.035], W, 6, 2)
		Loft.tube(b, [Vector3(sx * 0.1, 0.75, 0), Vector3(sx * 0.2, 0.4, 0.1), Vector3(sx * 0.15, 0.0, 0.25)], [0.08, 0.06, 0.04], W, 6, 2)
	var mi = _mesh(b, L.ghost("soul", L.SOUL, L.SOUL_EDGE, {"pattern": 2.0, "a_in": 0.35, "a_edge": 0.95, "flow": 0.9, "glow": 0.35}))
	var n = Node3D.new()
	n.add_child(mi)
	return n


## Ningendō (kanon): el kurbanın başına konur, zihni okunur, ruhu bedenden sökülür. Avuçta mor tutuş ışığı; ruh başın
## tepesinden yukarı-geri sıyrılırken beden ile arasında gerilen mor ışık şeridi; sökülen ruh beyaz-lila tüllere dağılır.
## Canavar gücü direnir; güçlüler yarı sökülür.
static func ningendo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	if tt == null:
		if c is Player:
			Hud.msg("Ningendō: eli başına koymak için hedefe yakın olmalısın.", Color(0.75, 0.85, 1.0))
		return
	pj.busy(c, 1.8)
	var dv = pj._face(c, tt)
	var tw0 = c.create_tween()
	tw0.tween_property(c, "global_position", pj.gp(tt.global_position - dv * 0.9), 0.2).set_trans(Tween.TRANS_QUAD)
	L.eye_glint(pj, c, 1, 2.0, 0.3)
	pj.after(0.25, func():
		if not (pj.live(c) and pj.live(tt)) or c.global_position.distance_to(tt.global_position) > 2.5:
			return
		pj.anim(c, "interact", 1.0)
		tt.set_meta("gaki_hold", true)
		pj.st(tt, "bind", 1.6)
		if c is Player:
			c.input_locked = 1.5
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Zihni okunuyor...", Color(0.8, 0.88, 1.0))
		var resist = (tt is Player and Buffs.has("beast")) or tt.has_meta("jinchuriki")
		var boss = tt is Player or tt.has_meta("boss") or tt is TailedBeast
		# avuçta mor tutuş ışığı (el kemiğine iliştirili)
		var hb = pj.bone_attach(c, "RightHand")
		if hb:
			var sm = SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			var orb = L.gi(sm, L.ghost("ningen_palm", Color(0.95, 0.92, 1.0), L.SOUL_EDGE, {"a_in": 0.25, "a_edge": 0.9, "glow": 0.5}))
			hb.add_child(orb)
			L.kill(pj, 1.6, hb)
		var ghost = _soul()
		pj.get_tree().current_scene.add_child(ghost)
		ghost.global_position = tt.global_position
		ghost.rotation.y = tt.rotation.y
		ghost.scale = Vector3.ONE * 0.98
		var away = -dv
		var wt = weakref(tt)
		var wg = weakref(ghost)
		var head0 = tt.global_position + Vector3.UP * 1.6
		var from_fn = func() -> Vector3:
			var n = wt.get_ref()
			return (n.global_position + Vector3.UP * 1.6) if n != null and is_instance_valid(n) else head0
		var to_fn = func() -> Vector3:
			var g = wg.get_ref()
			return (g.global_position + Vector3.UP * 1.6) if g != null and is_instance_valid(g) else head0
		L.beam(pj, from_fn, to_fn, 0.14, 1.45, L.ghost("ningen_band", Color(0.95, 0.92, 1.0), Color(0.62, 0.42, 1.0), {"pattern": 3.0, "a_in": 0.35, "a_edge": 0.75, "flow": 1.2, "glow": 0.3}))
		var tw = ghost.create_tween()
		tw.tween_interval(0.6)
		# el geri çekilirken ruh bedenden sıyrılır (başından itibaren öne-yukarı uzar)
		tw.tween_property(ghost, "global_position", tt.global_position + away * (0.5 if resist else 1.4) + Vector3.UP * 0.25, 0.8).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(ghost, "rotation:x", -0.35, 0.8)
		tw.parallel().tween_property(ghost, "scale", Vector3(0.95, 1.12, 0.95), 0.8)
		tw.tween_callback(func():
			if is_instance_valid(tt):
				tt.remove_meta("gaki_hold")
			if not (pj.live(c) and pj.live(tt)):
				return
			if resist:
				Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Canavar gücüyle direndi!", Color(1, 0.6, 0.3))
				tt.take_hit(pj.inf(c, "ningendo", 1.2, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
			elif boss:
				pj.st(tt, "stun", 2.0)
				if tt is Player:
					tt.chakra = maxf(0.0, tt.chakra * 0.4)
				tt.take_hit(pj.inf(c, "ningendo", 0.0, {"dmg": float(tt.max_hp) * (0.22 if tt is Player else 0.1), "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
				Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Ruhu yarı söküldü", Color(0.8, 0.88, 1.0))
			else:
				tt.take_hit(pj.inf(c, "ningendo", 0.0, {"dmg": float(tt.max_hp) * 4.0, "no_blood": true, "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
				Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Ruhu söküldü", Color(0.8, 0.88, 1.0))
			L.burst(pj, ghost.global_position + Vector3.UP, {"amount": 22, "life": 0.9, "size": 0.35, "radius": 0.5, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 60.0, "add": true,
				"colors": [Color(0.95, 0.95, 1, 0.9), Color(0.65, 0.5, 1, 0.6), Color(0.5, 0.4, 1, 0)]}))
		tw.tween_property(ghost, "scale", Vector3.ONE * 0.05, 0.4)
		tw.tween_callback(ghost.queue_free))
	Sfx.play("genjutsu", c.global_position, 0.8)


# ================================================================== İzanagi
## İzanagi (kanon, Danzō / Obito): kullanıcı İzanagi'yi ÖNCEDEN açar; süre boyunca başına gelen kötü her şey — yara, ölüm —
## yanılsamaya döner (gerçeği yeniden yazar). Süre bitince kullanılan Sharingan gözü kalıcı olarak ışığını kaybeder.
## Görünüş: sağ göz kızıl parlar; ayağının altında bedenle yürüyen soluk, yavaş dönen üç tomoe deseni (gerçeğin yeniden
## yazıldığı alan) ve aralıklı kızıl uzay kıvrımları; bitişte göz griye dönüp kapanır, desen hızla dönüp söner, gri kıvrım.
static func izanagi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var start_hp = float(c.get("hp")) if c.get("hp") != null else 0.0
	var dur = PathJutsu.IZANAGI_DUR
	c.set_meta("izanagi_hp", start_hp)
	c.set_meta("izanagi_until", Time.get_ticks_msec() + int(dur * 1000.0))
	if c is Player:
		Buffs.add("izanagi", dur, {"_name": "İzanagi", "_desc": "%d sn: ölüm dahil başına gelen her şey yanılsama; sonunda bir Sharingan gözün kararır" % int(dur)})
		Hud.msg("İzanagi: gerçekle yanılsama yer değiştirdi (%d sn). Bedeli bir göz." % int(dur), Color(1, 0.45, 0.45), 5.0)
	else:
		Combat.popup_text(c.global_position + Vector3.UP * 2.6, "İzanagi!", Color(0.9, 0.15, 0.2))
	L.eye_glint(pj, c, 0, dur, 0.45, 1)
	var h = _h(c)
	L.ripple(pj, c.global_position + Vector3.UP * h * 0.55, h * 2.4, 0.35, false, Color(0.9, 0.15, 0.2), 0.04, 0.6)
	var sm = L.disc_mat(5, Color(0.7, 0.05, 0.08), Color(0.12, 0.0, 0.02), Color(0.3, 0.0, 0.03), {"alpha": 0.0, "speed": 0.4, "near_cut": 1.0})
	var qm = QuadMesh.new()
	qm.size = Vector2(3.2, 3.2)
	qm.orientation = PlaneMesh.FACE_Y
	var seal = L.gi(qm, sm)
	c.add_child(seal)
	seal.position = Vector3.UP * 0.06
	var stw = seal.create_tween()
	stw.tween_method(L.sp(sm, "alpha"), 0.0, 0.38, 0.3)
	var wc = weakref(c)
	pj.every(dur, 2.5, func(_i, _k):
		var n = wc.get_ref()
		if n != null and is_instance_valid(n) and not n.is_dead():
			L.ripple(pj, n.global_position + Vector3.UP * h * 0.55, h * 1.6, 0.4, true, Color(0.85, 0.1, 0.15), 0.025, 0.3), Callable())
	pj.after(dur, func():
		if not is_instance_valid(c):
			return
		c.remove_meta("izanagi_hp")
		c.remove_meta("izanagi_until")
		var now = float(c.get("hp"))
		if now < start_hp and now > 0.0:
			pj.heal(c, start_hp - now)   # süre içindeki yaralar da yanılsamaydı
		L.eye_glint(pj, c, 3, 0.8, 0.5, 1)
		L.ripple(pj, c.global_position + Vector3.UP * h * 0.55, h * 3.2, 0.45, false, Color(0.7, 0.7, 0.72), 0.04, 0.5)
		if is_instance_valid(seal):
			var etw = seal.create_tween()
			etw.tween_method(L.sp(sm, "speed"), 0.4, 6.0, 0.5)
			etw.parallel().tween_method(L.sp(sm, "alpha"), 0.38, 0.0, 0.5)
			etw.tween_callback(seal.queue_free)
		# bedel: Sharingan gözü kararır
		if c is Player:
			if c.combat and c.combat.modes and c.combat.modes.eyes:
				c.combat.modes.eyes.izanagi_cost()
		elif c.has_meta("eyes"):
			c.set_meta("eyes", {"kind": 0, "lvl": 0})
			Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Gözü karardı", Color(0.7, 0.2, 0.25)))
	Sfx.play("genjutsu", c.global_position, 0.8)


# ================================================================== Kotoamatsukami
## Kotoamatsukami (kanon, Shisui'nin Mangekyō'su): hedef farkına varmadan iradesi yeniden yazılır. Görünüş: kullanıcının
## sağ gözünde dört kanatlı Mangekyō parlar, gözden hedefin alnına ince kızıl-beyaz akış süzülür, hedefin yüzünün önünde
## dönen Mangekyō belirip içine gömülür; iradesi çevrilen hedefin başında küçük dönen Mangekyō işareti kalır.
static func kotoamatsukami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var red = Color(0.95, 0.15, 0.2)
	var eye = L.eye_world(c)
	var tt = pj.tg(c, t, 22.0)
	if not (c is Player):
		# düşman: oyuncunun yanındaki müttefiki çevirir
		for f in pj.get_tree().get_nodes_in_group("fighters"):
			if f != Game.player and f.get("team") == "player" and pj.live(f) and f.global_position.distance_to(c.global_position) < 22.0:
				tt = f
				break
	if tt == null:
		if c is Player:
			Hud.msg("Kotoamatsukami: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	L.eye_glint(pj, c, 2, 1.0, 0.5, 1)
	var to = tt.global_position + Vector3.UP * 1.6
	var bm = L.ghost("koto_beam", Color(1.0, 0.8, 0.8), red, {"pattern": 3.0, "a_in": 0.6, "a_edge": 0.9, "flow": 2.0, "glow": 0.5})
	var wc = weakref(c)
	var wt = weakref(tt)
	var from_fn = func() -> Vector3:
		var n = wc.get_ref()
		return L.eye_world(n) if n != null and is_instance_valid(n) else eye
	var to_fn = func() -> Vector3:
		var n = wt.get_ref()
		return (n.global_position + Vector3.UP * 1.6) if n != null and is_instance_valid(n) else to
	L.beam(pj, from_fn, to_fn, 0.025, 0.35, bm)
	pj.after(0.2, func():
		if not pj.live(tt):
			return
		var at = tt.global_position + Vector3.UP * 1.6
		var fm = L.disc_mat(6, Color(0.85, 0.06, 0.08), Color(0.06, 0.0, 0.01), Color(0.95, 0.2, 0.2), {"bill": true, "speed": 4.0, "prog": 0.0, "near_cut": 2.0})
		var face = L.disc(pj, at + (eye - at).normalized() * 0.4, 0.9, fm, false)
		var ftw = face.create_tween()
		ftw.tween_method(L.sp(fm, "prog"), 0.0, 1.0, 0.1)
		ftw.tween_interval(0.25)
		ftw.tween_property(face, "global_position", at, 0.2).set_ease(Tween.EASE_IN)
		ftw.parallel().tween_property(face, "scale", Vector3.ONE * 0.1, 0.2).set_ease(Tween.EASE_IN)
		ftw.tween_callback(face.queue_free)
		L.ripple(pj, at, 1.8, 0.3, true, red, 0.03, 0.5)
		Sfx.play("genjutsu", tt.global_position, 1.4, 0.4)
		if tt == Game.player:
			pj.st(tt, "stun", 1.6)
			if Game.world:
				Game.world.env.flash_tint(Color(0.85, 0.05, 0.05, 0.2), 0.8)
			return
		if tt.has_meta("boss") or not ("team" in tt):
			pj.st(tt, "stun", 6.0)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "İradesi sarsıldı", red.lightened(0.3))
			return
		# irade değişti: yeni tarafının dostu olur, eski dostlarına saldırır; süre bitince eski hâline döner
		var old_team = String(tt.team)
		tt.team = c.team
		tt.set("target", null)
		tt.set_meta("koto_mark", true)
		var mark = Node3D.new()
		var mq = QuadMesh.new()
		mq.size = Vector2.ONE * 0.36
		mark.add_child(L.gi(mq, L.disc_mat(6, Color(0.85, 0.06, 0.08), Color(0.06, 0.0, 0.01), Color(0.95, 0.2, 0.2), {"bill": true, "speed": 3.0, "alpha": 0.95, "near_cut": 1.0})))
		tt.add_child(mark)
		ClanJutsu.fit_body(tt, mark)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		mark.position = Vector3.UP * (float(tt.get("height")) + 0.5 if tt.get("height") != null else 2.3)
		var dur = 45.0 * gm
		pj.after(dur, func():
			if is_instance_valid(mark):
				mark.queue_free()
			if pj.live(tt) and tt.has_meta("koto_mark"):
				tt.remove_meta("koto_mark")
				tt.team = old_team
				tt.set("target", null)))
