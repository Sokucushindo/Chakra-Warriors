class_name AkatsukiCave
extends RefCounted
## Akatsuki mağarası (kanon: Nehir Ülkesi'ndeki sığınak). Referans: refs/akatsuki (Five-Seal Barrier, Gedo_Mazo_Akatsuki_Rings,
## Magic Lantern Body, Nine Phantom Dragons, Statue_Sealed).
##  DIŞ  — kızıl-kahve kaya kütlesi, ağzı dev yuvarlak kayayla kapalı; kayanın üstünde "禁" etiketi, önünde kızıl torii.
##         Gofū Kekkai: kapıdaki etiketi kaldırmak için çevredeki dört etiket kısa süre içinde sökülmeli (kanon: aynı anda).
##  İÇ   — Interiors odası "akatsuki_cave": dev salon, beline kadar yere gömülü Gedō Mazō (tören pozu: prangalı eller önde,
##         parmaklar yukarı), parmak uçlarında yüzük kanjisi yeşil yanar; üyeler parmak uçlarında fener gölgesi olarak durur.
## Dış kısım oyuncu yaklaşınca kurulur (WorldAkatsuki.tick → sync), uzaklaşınca kalkar. Çarpışma görünen kayaların kendisinden.

const W := 110.0
const D := 130.0
const H := 66.0
const SINK := 45.0            # heykelin yere gömülü kısmı
const STATUE_D := 96.0
const ROCK := Color(0.33, 0.28, 0.32)
const ROCK_D := Color(0.19, 0.16, 0.2)
const EXT_ROCK := Color(0.52, 0.37, 0.34)
const RED := Color(0.7, 0.1, 0.1)
const TAG_R := 130.0          # dört dış etiketin kapıya uzaklığı
const TAG_WINDOW := 480.0     # dört etiket bu süre (sn) içinde sökülmeli

static var ext: Node3D
static var ext_at := Vector3.ZERO
static var statue: GedoMazo
static var shades: Array = []
static var torn := {}          # sökülen dış etiketler: sıra -> gerçek saat (sn)
static var broken := false     # Gofū Kekkai kırıldı (dış kurulum kalkana dek)
static var copies := {}        # etiket sırası -> o etiketin yarattığı oyuncu kopyası (Enemy)
static var dragons: Node3D


# ------------------------------------------------------------------ dış
static func sync() -> void:
	var on = WorldAkatsuki.exists() and Game.player != null and Game.world != null
	var at = WorldAkatsuki.cave_pos() if on else Vector3.ZERO
	var dist = Game.player.global_position.distance_to(at) if on else 1e9
	if is_instance_valid(ext) and (not on or dist > 2600.0 or ext_at.distance_to(at) > 1.0):
		drop()
	if on and not is_instance_valid(ext) and dist < 2000.0:
		_exterior(at)


static func drop() -> void:
	if is_instance_valid(ext):
		ext.queue_free()
	ext = null
	torn = {}
	broken = false
	for ck in copies.keys():
		if is_instance_valid(copies[ck]):
			copies[ck].queue_free()
	copies = {}
	for it in Interact.items.duplicate():
		if String(it.get("kind", "")) in ["aka_gate", "aka_tag"]:
			Interact.items.erase(it)


## Kapının önü (dünya): torii'nin altı
static func gate_pos() -> Vector3:
	var p = ext_at + Vector3(0, 0, 20.0)
	p.y = Game.ground_height(p.x, p.z)
	return p


static func _tag(b: Builder, c: Vector3, s: float) -> void:
	b.box(c, Vector3(4.4, 5.4, 0.16) * s, Color(0.93, 0.91, 0.84), 0.0, false)
	for k in 2:
		b.box(c + Vector3((k * 2 - 1) * 1.75 * s, 0, -0.06), Vector3(0.22, 4.6, 0.1) * s, RED, 0.0, false)
		b.box(c + Vector3(0, (k * 2 - 1) * 2.25 * s, -0.06), Vector3(3.7, 0.22, 0.1) * s, RED, 0.0, false)
	b.kanji(c + Vector3(0, 0, -0.14), "禁", 3.3 * s, RED, 0.0)


static func _exterior(at: Vector3) -> void:
	ext_at = at
	var b = Builder.new(Game.world, at.x, -at.z, at.y, "AkatsukiMagara")
	b.landscape = false
	ext = b.root
	var g = func(x: float, n: float) -> float: return Game.ground_height(at.x + x, at.z - n) - at.y
	var rng = RandomNumberGenerator.new()
	rng.seed = 7707
	# kaya kütlesi: önde alçalan, arkada yükselen iki sıra sarp kaya (ağız n = 0'da, güneye bakar)
	for row in 3:
		for i in 9:
			var x = (-72.0 + i * 18.0) * (1.0 - row * 0.14) + rng.randf_range(-5.0, 5.0)
			if row == 0 and absf(x) < 13.0:
				x = 16.0 * signf(x + 0.01)
			var n = 26.0 + row * 30.0 + rng.randf_range(0.0, 8.0) + absf(x) * 0.1
			var h = (rng.randf_range(46.0, 60.0) + row * 26.0) * (1.0 - absf(x) / 150.0)
			b.crag(Vector3(x, g.call(x, n) - 5.0, n), rng.randf_range(40.0, 54.0), h, EXT_ROCK.darkened(rng.randf() * 0.16 + row * 0.06), i + row * 5, true, rng.randf() * 360.0)
	b.crag(Vector3(0, g.call(0.0, 30.0) + 16.0, 30.0), 56.0, 46.0, EXT_ROCK.darkened(0.08), 3, true, 40.0)   # ağzın üstündeki alın
	# ağız: düzensiz taş kemer + içini dolduran dev yuvarlak kaya
	var g0: float = g.call(0.0, 4.0)
	PathLairs.rock_arch(b, 0.0, g0, 5.0, 27.0, 14.5, EXT_ROCK.darkened(0.12))
	b.boulder(Vector3(0, g0 + 9.0, 9.0), Vector3(24.0, 22.0, 13.0), EXT_ROCK.lightened(0.05), 5, true, 0.0)
	_tag(b, Vector3(0, g0 + 9.5, 2.2), 1.0)
	PathLairs.shimenawa(b, Vector3(-11.5, g0 + 16.5, 3.0), Vector3(11.5, g0 + 16.5, 3.0), 2.4)
	# kızıl torii
	var gt: float = g.call(0.0, -20.0)
	for s in [-1.0, 1.0]:
		b.cyl(Vector3(s * 7.0, gt + 6.5, -20.0), 1.3, 14.0, RED, true, 12)
		b.box(Vector3(s * 7.0, gt + 0.5, -20.0), Vector3(2.0, 1.0, 2.0), Color(0.2, 0.19, 0.2))
	b.box(Vector3(0, gt + 13.8, -20.0), Vector3(20.0, 1.1, 1.5), RED, 0.0, false)
	b.box(Vector3(0, gt + 14.7, -20.0), Vector3(21.5, 0.6, 2.0), Color(0.16, 0.14, 0.15), 0.0, false)
	b.box(Vector3(0, gt + 10.6, -20.0), Vector3(16.5, 0.8, 0.9), RED, 0.0, false)
	b.box(Vector3(0, gt + 12.2, -20.0), Vector3(1.6, 2.2, 0.5), Color(0.16, 0.14, 0.15), 0.0, false)
	b.interact(Vector3(0, g0 + 1.0, -1.5), 6.0, "aka_gate", "[F] Mühürlü kaya")
	# Gofū Kekkai'nin dört dış etiketi: çevredeki kayaların üstünde
	for k in 4:
		var a = PI + (k + 0.5) * PI / 4.0   # ağzın önündeki yarım çember
		var x = cos(a) * TAG_R
		var n = sin(a) * TAG_R - 20.0
		var gy: float = g.call(x, n)
		b.boulder(Vector3(x, gy + 2.2, n), Vector3(7.0, 6.5, 6.0), EXT_ROCK.darkened(0.1), k + 9, true, k * 50.0)
		_tag(b, Vector3(x, gy + 3.0, n - 3.2), 0.42)
		b.interact(Vector3(x, gy + 0.8, n - 4.6), 8.5, "aka_tag", "[F] Etiketi sök (禁)", {"idx": k})
	b.finish()


## Dış etiketlerden biri sökülmek istendi. Kanon (Gofū Kekkai): etikete dokunanın karşısına bariyerin yarattığı KENDİ KOPYASI
## çıkar: o anki canı, chakrası, gücü ve teknikleriyle. Kopya yenilince etiket sökülmüş sayılır; dördü TAG_WINDOW içinde
## sökülürse kapıdaki mühür düşer (üyeler için gerek yok). Kopyadan uzaklaşılırsa kopya dağılır, etiket yerinde kalır.
static func tear(it: Dictionary) -> void:
	var k = int(it.get("idx", 0))
	if broken:
		Hud.msg("Bariyer zaten düştü; kaya kapı açık.", Color(0.9, 0.8, 0.6))
		return
	_expire()
	if torn.has(k):
		Hud.msg("Bu etiket zaten söküldü (%d/4)." % torn.size(), Color(0.9, 0.8, 0.6))
		return
	if is_instance_valid(copies.get(k)):
		Hud.msg("Önce etiketten çıkan kopyanı yen.", Color(1, 0.7, 0.5))
		return
	Sfx.play("seal", Game.player.global_position, 0.7)
	var tag_at: Vector3 = it.get("pos", Game.player.global_position)
	copies[k] = _spawn_copy(tag_at, k)
	Hud.banner("GOFŪ KEKKAI", "Etikete dokundun: bariyer senin kopyanı yarattı. Onu yenmeden etiket sökülmez.", Color(0.9, 0.55, 0.4))


static func _expire() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	for q in torn.keys():   # süresi geçen etiketler yeniden yapışır
		if now - float(torn[q]) > TAG_WINDOW:
			torn.erase(q)


## Kopya yenildi: etiket söküldü
static func _copy_down(k: int) -> void:
	copies.erase(k)
	if broken:
		return
	_expire()
	torn[k] = Time.get_ticks_msec() / 1000.0
	if torn.size() >= 4:
		broken = true
		Game.world.env.add_shake(0.5)
		Hud.banner("GOFŪ KEKKAI DÜŞTÜ", "Dört etiket birlikte söküldü. Kaya kapıdaki mühür artık tutmuyor.", Color(0.9, 0.75, 0.4))
	else:
		Hud.msg("Etiket söküldü (%d/4). Hepsi %d saniye içinde sökülmezse sökülenler yeniden yapışır." % [torn.size(), int(TAG_WINDOW)], Color(0.9, 0.8, 0.6))


## Oyuncunun kopyası: aynı görünüş, aynı Güç, yuvalardaki teknikler, o anki can ve chakra oranı
static func _spawn_copy(tag_at: Vector3, k: int) -> Enemy:
	var pr: Dictionary = Game.profile
	var pl = Game.player
	var lv = int(pr.get("level", 1))
	var a = Enemy.archetype("rogue", 0)
	a["respawn"] = false
	a["name"] = "%s (Kekkai kopyası)" % String(pr.get("name", ""))
	a["element"] = String((pr.get("elements", ["katon"]) as Array)[0])
	Stats.npc_ninja(a, lv)
	a["xp"] = 0
	a["ryo"] = 0
	a["aggr"] = 1.0
	a["look"] = pl._look_with_age().duplicate(true)
	var js: Array = []
	for j in pr.get("slots", []):
		if String(j) != "" and Data.jutsu.has(j) and not (Data.jutsu[j] as Dictionary).has("virtual") and not j in js:
			js.append(j)
	if not js.is_empty():
		a["jutsu"] = js.slice(0, 6)
		a.erase("auto_jutsu")
	var clan = String(pr.get("clan", "none"))
	if clan != "none" and clan != "":
		a["clan"] = clan
	var e = Enemy.new()
	e.setup(a)
	pl.get_tree().current_scene.add_child(e)
	var dir: Vector3 = pl.global_position - tag_at
	dir.y = 0.0
	var at: Vector3 = tag_at + (dir.normalized() if dir.length() > 0.1 else Vector3.BACK) * 2.5
	at.y = Game.ground_height(at.x, at.z)
	e.global_position = at
	e.home = at
	e.hp = maxf(e.max_hp * clampf(pl.hp / maxf(1.0, pl.max_hp), 0.3, 1.0), 1.0)   # kanon: yaratıldığı andaki hâlin
	e.chakra = e.max_chakra * clampf(pl.chakra / maxf(1.0, pl.max_chakra), 0.3, 1.0)
	e.set_meta("no_loot", true)
	if a.has("clan"):
		ClanWorld.after_spawn_enemy(e, clan, lv, 0)
	e.target = pl
	FX.aura(e, Color(0.75, 0.2, 0.2), 1.2)
	var w = CopyWatch.new()
	w.k = k
	w.tag_at = tag_at
	w.foe = e
	pl.get_tree().current_scene.add_child(w)
	return e


## Kopyayı izler: yenilince etiketi söker; oyuncu uzaklaşırsa (ya da dış kurulum kalkarsa) kopya dağılır
class CopyWatch extends Node:
	var k := 0
	var tag_at := Vector3.ZERO
	var foe: Enemy
	func _process(_dt: float) -> void:
		if not is_instance_valid(foe) or foe.dead or foe.hp <= 0.0 or foe.is_queued_for_deletion():
			AkatsukiCave._copy_down(k)
			queue_free()
			return
		var pl = Game.player
		if pl == null or not is_instance_valid(AkatsukiCave.ext) or AkatsukiCave.broken or pl.global_position.distance_to(tag_at) > 75.0 or pl.hp <= 0.0:
			FX.aura(foe, Color(0.75, 0.2, 0.2), 0.6)
			foe.queue_free()
			AkatsukiCave.copies.erase(k)
			if pl != null and not AkatsukiCave.broken and is_instance_valid(AkatsukiCave.ext):
				Hud.msg("Kopyadan uzaklaştın: kopya dağıldı, etiket yerinde kaldı.", Color(0.9, 0.8, 0.6))
			queue_free()


# ------------------------------------------------------------------ iç
static func _mat(col: Color, alpha := 1.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Gentōshin (fener gölgesi): pelerinli koyu siluet; liderin gözleri Rinnegan
static func _shade(parent: Node3D, at: Vector3, face: Vector3, idx: int, lead: bool, seed: int) -> Node3D:
	var n = Node3D.new()
	parent.add_child(n)
	n.global_position = at
	n.rotation.y = atan2(face.x, face.z)
	var mb = MB.new()
	Loft.tube(mb, [Vector3(0, 0, 0), Vector3(0, 0.75, 0), Vector3(0, 1.38, 0), Vector3(0, 1.56, 0), Vector3(0, 1.66, 0)],
		[Vector2(0.44, 0.34), Vector2(0.38, 0.3), Vector2(0.3, 0.24), Vector2(0.27, 0.23), Vector2(0.29, 0.25)], Color(1, 1, 1), 10, 3, true, false)
	mb.add("sphere", Vector3(0, 1.7, 0), Vector3(0.3, 0.33, 0.31), Color(1, 1, 1), Vector3.ZERO, 8)
	var r = RandomNumberGenerator.new()
	r.seed = seed
	var spikes = r.randi_range(0, 9)   # saç: kimi düz, kimi diken diken (kişiye göre sabit)
	for k in spikes:
		var a = TAU * k / maxf(1.0, spikes) + r.randf() * 0.4
		var d = Vector3(cos(a) * 0.8, 0.75 + r.randf() * 0.5, sin(a) * 0.8).normalized()
		Loft.tube(mb, [Vector3(0, 1.74, 0) + d * 0.08, Vector3(0, 1.74, 0) + d * (0.3 + r.randf() * 0.14)], [0.085, 0.01], Color(1, 1, 1), 5, 1, false, true)
	if spikes < 3:
		Loft.tube(mb, [Vector3(0, 1.84, 0.02), Vector3(0, 1.5, -0.17), Vector3(0, 1.0 + r.randf() * 0.3, -0.2)], [Vector2(0.17, 0.1), Vector2(0.16, 0.06), Vector2(0.05, 0.03)], Color(1, 1, 1), 6, 2, true, true)
	var mi = MeshInstance3D.new()
	mi.mesh = mb.build(null)
	var m = _mat(Color(0.035, 0.03, 0.06), 0.9)
	mi.material_override = m
	n.add_child(mi)
	var eb = MB.new()
	for s in [-1.0, 1.0]:
		if lead:
			eb.add("sphere", Vector3(s * 0.065, 1.72, 0.145), Vector3(0.075, 0.05, 0.02), Color(0.78, 0.72, 0.92), Vector3.ZERO, 8)
		else:
			eb.add("sphere", Vector3(s * 0.06, 1.72, 0.145), Vector3(0.05, 0.022, 0.02), Color(0.92, 0.92, 0.95), Vector3.ZERO, 6)
	var ei = MeshInstance3D.new()
	ei.mesh = eb.build(null)
	var em = _mat(Color(1, 1, 1))
	em.vertex_color_use_as_albedo = true
	ei.material_override = em
	n.add_child(ei)
	if lead:   # Rinnegan halkaları
		var rb = MB.new()
		for s in [-1.0, 1.0]:
			for q in 2:
				rb.add("torus", Vector3(s * 0.065, 1.72, 0.157), Vector3(0.018 + q * 0.016, 0.012 + q * 0.011, 0.004), Color(1, 1, 1), Vector3(90, 0, 0), 8)
		var ri = MeshInstance3D.new()
		ri.mesh = rb.build(null)
		ri.material_override = _mat(Color(0.2, 0.14, 0.35))
		n.add_child(ri)
	# gölge titrer (uzaktan yansıtılan görüntü)
	var tw = n.create_tween().set_loops()
	tw.tween_property(m, "albedo_color:a", 0.72, 0.5 + r.randf() * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.92, 0.4 + r.randf() * 0.5)
	n.set_meta("slot", idx)
	return n


## Interiors._build("akatsuki_cave") çağırır
static func interior(I: Interiors) -> void:
	var rng = I.rng
	shades = []
	dragons = null
	# ---- kabuk: zemin, duvarlar, tavan (çarpışmalı); üstü kaya yumrularıyla kaplı
	I.bx(0, -3.0, D * 0.5, W + 8.0, 6.0, D + 8.0, Color(0.2, 0.18, 0.2), true)
	for i in 90:
		I.bx(rng.randf_range(-W * 0.46, W * 0.46), 0.004, rng.randf_range(2.0, D - 2.0), rng.randf_range(3.0, 9.0), 0.008, rng.randf_range(3.0, 9.0),
			Color(0.2, 0.18, 0.2).lightened(rng.randf_range(-0.04, 0.05)), false, Vector3(0, rng.randf_range(0, 90), 0))
	I.bx(-W * 0.5 - 1.0, H * 0.5, D * 0.5, 2.0, H, D + 4.0, ROCK, true)
	I.bx(W * 0.5 + 1.0, H * 0.5, D * 0.5, 2.0, H, D + 4.0, ROCK, true)
	I.bx(0, H * 0.5, D + 1.0, W + 4.0, H, 2.0, ROCK, true)
	I.bx(0, H * 0.5, -1.2, W + 4.0, H, 2.0, ROCK, true)
	I.bx(0, H + 1.0, D * 0.5, W + 4.0, 2.0, D + 4.0, ROCK_D, true)
	for i in 260:   # yan duvarlar
		var side = -1.0 if i % 2 == 0 else 1.0
		var s = rng.randf_range(7.0, 14.0)
		I.sp(side * (W * 0.5 + s * 0.5 - rng.randf_range(1.5, 4.5)), rng.randf_range(0.5, H), rng.randf_range(0.0, D), Vector3(s, s * rng.randf_range(0.8, 1.5), s), ROCK.darkened(rng.randf() * 0.35), 7)
	for i in 150:   # arka ve ön duvar
		var s2 = rng.randf_range(7.0, 14.0)
		var back = i % 3 != 0
		I.sp(rng.randf_range(-W * 0.5, W * 0.5), rng.randf_range(0.5 if back else 9.0, H), (D + s2 * 0.5 - rng.randf_range(1.5, 4.0)) if back else (-s2 * 0.5 + rng.randf_range(1.0, 2.5)),
			Vector3.ONE * s2, ROCK.darkened(rng.randf() * 0.35), 7)
	for i in 110:   # tavan kubbesi + sarkıtlar
		I.sp(rng.randf_range(-W * 0.5, W * 0.5), H - rng.randf_range(0.0, 3.0), rng.randf_range(0.0, D), Vector3(rng.randf_range(9.0, 18.0), 6.0, rng.randf_range(9.0, 18.0)), ROCK_D.darkened(rng.randf() * 0.25), 7)
	for i in 70:
		var tx = rng.randf_range(-W * 0.46, W * 0.46)
		var tz = rng.randf_range(6.0, D - 4.0)
		var tl = rng.randf_range(4.0, 13.0)
		I.sp(tx, H - 1.5 - tl * 0.5, tz, Vector3(rng.randf_range(1.2, 2.6), tl, rng.randf_range(1.2, 2.6)), ROCK.darkened(0.2), 5)
	for i in 46:   # yerde kaya döküntüsü (heykelin önü ve giriş yolu açık)
		var rx = rng.randf_range(-W * 0.46, W * 0.46)
		var rz = rng.randf_range(8.0, D - 4.0)
		if absf(rx) < 20.0 and rz < STATUE_D - 6.0:
			continue
		var rs = rng.randf_range(2.0, 5.5)
		I.sp(rx, rs * 0.2, rz, Vector3(rs, rs * 0.8, rs), ROCK.darkened(rng.randf() * 0.3), 6)
		var cs = CollisionShape3D.new()
		var sh = SphereShape3D.new()
		sh.radius = rs * 0.42
		cs.shape = sh
		cs.position = I.L(rx, rs * 0.2, rz)
		I.body.add_child(cs)
	# ---- giriş: kaya kapının iç yüzü
	I.sp(0, 9.0, -5.0, Vector3(24.0, 22.0, 13.0), Color(0.3, 0.24, 0.24), 10)
	I.act(0, 3.2, 3.0, "exit", "[F] Dışarı çık")
	# ---- Gedō Mazō: beline kadar gömülü, yüzü girişe dönük; tören pozu
	var sealed = WorldAkatsuki.sealed_n()
	var g = GedoMazo.spawn(I.room, I.L(0, -SINK, STATUE_D), PI, clampi(sealed, 0, 9))
	statue = g
	g.set_pose("ritual", 0.0)
	for l in g.legs:
		(l["hip"] as Node3D).visible = false
	# heykelin gövdesi katı (görünen gövde kadar): üst üste silindirler
	for k in 3:
		var cs2 = CollisionShape3D.new()
		var cy2 = CylinderShape3D.new()
		cy2.radius = [15.0, 17.0, 13.0][k]
		cy2.height = 12.0
		cs2.shape = cy2
		cs2.position = I.L(0, 6.0 + k * 12.0, STATUE_D + 1.0)
		I.body.add_child(cs2)
	for i in 30:   # heykelin yerden çıktığı yerde kırık kaya halkası
		var a = TAU * i / 30.0
		var rr = 19.0 + rng.randf_range(-2.0, 3.0)
		var s3 = rng.randf_range(3.0, 6.5)
		I.sp(cos(a) * rr, s3 * 0.15, STATUE_D + sin(a) * rr * 0.8, Vector3(s3, s3 * rng.randf_range(0.6, 1.2), s3), ROCK_D.lightened(rng.randf() * 0.1), 6)
	# ---- ışık: loş mor salon, heykelin önünde soluk tepe ışığı, girişte gün ışığı sızıntısı
	I.lamp(0, 30.0, STATUE_D - 34.0, Color(0.62, 0.55, 0.85), 2.6, 95.0)
	I.lamp(-34.0, 12.0, 40.0, Color(0.5, 0.42, 0.7), 1.3, 60.0)
	I.lamp(34.0, 12.0, 40.0, Color(0.5, 0.42, 0.7), 1.3, 60.0)
	I.lamp(0, 5.0, 6.0, Color(0.95, 0.85, 0.7), 1.1, 30.0)
	# ---- parmak uçları: yüzük kanjileri + üyelerin gölgeleri (kurulumdan bir kare sonra: pivotlar yerleşsin)
	_dress.call_deferred(I)


static func _dress(I: Interiors) -> void:
	await I.get_tree().process_frame
	if not is_instance_valid(statue) or not is_instance_valid(I.room):
		return
	var tips = statue.finger_tips()
	var sl: Array = WorldAkatsuki.D()["slots"]
	var sealing = not WorldAkatsuki.sealing().is_empty()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Microsoft YaHei"])
	font.font_weight = 800
	var gm = MB.new()
	var any = false
	for i in mini(10, tips.size()):
		var id = String(sl[i]) if i < sl.size() else ""
		if id == "":
			continue   # sahipsiz yüzük: parmak karanlık
		any = true
		var tp: Vector3 = tips[RING_FINGER[i]]
		gm.add("sphere", tp + Vector3(0, 0.2, 0), Vector3(1.15, 0.7, 1.15), Color(0.35, 1.0, 0.45), Vector3.ZERO, 10)
		var lb = Label3D.new()
		lb.text = WorldAkatsuki.KANJI[i]
		lb.font = font
		lb.font_size = 96
		lb.pixel_size = 0.95 / 96.0
		lb.modulate = Color(0.75, 1.0, 0.78)
		lb.outline_size = 8
		lb.outline_modulate = Color(0.05, 0.4, 0.12)
		lb.shaded = false
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = false
		I.room.add_child(lb)
		lb.global_position = tp + Vector3(0, -0.5, 0.75)
		# üye: tören sürerken herkes, yoksa yalnız lider gölgesi (oyuncunun parmağı boş: oyuncu yerde durur)
		if id != "player" and (sealing or i == 0):
			var p = WorldPeople.get_p(id)
			if not p.is_empty():
				shades.append(_shade(I.room, tp + Vector3(0, 0.55, 0), Vector3(0, 0, 1), i, i == 0, hash(id)))
	if any:
		var gi = MeshInstance3D.new()
		gi.mesh = gm.build(null)
		var m = _mat(Color(1, 1, 1), 0.55)
		m.vertex_color_use_as_albedo = true
		gi.material_override = m
		I.room.add_child(gi)
		for s in [-1.0, 1.0]:
			var l = OmniLight3D.new()
			l.light_color = Color(0.3, 1.0, 0.45)
			l.light_energy = 2.2
			l.omni_range = 26.0
			I.room.add_child(l)
			l.global_position = (tips[2] if s < 0 else tips[7]) + Vector3(0, 3.0, 4.0)
	if sealing:
		seal_fx(I)
	WorldAkatsuki.inside_built(I)


## Tören başlarken eksik üyelerin gölgeleri de parmak uçlarına gelir, ejderler çıkar
static func gather(I: Interiors) -> void:
	if not is_instance_valid(statue) or not is_instance_valid(I.room):
		return
	var tips = statue.finger_tips()
	var sl: Array = WorldAkatsuki.D()["slots"]
	var have = shades.filter(func(s): return is_instance_valid(s)).map(func(s): return int(s.get_meta("slot", -1)))
	for i in mini(10, sl.size()):
		var id = String(sl[i])
		if id == "" or id == "player" or i in have or WorldPeople.get_p(id).is_empty():
			continue
		shades.append(_shade(I.room, (tips[RING_FINGER[i]] as Vector3) + Vector3(0, 0.55, 0), Vector3(0, 0, 1), i, i == 0, hash(id)))
	seal_fx(I)


## Yüzük sırası → parmak (finger_tips sırası: bir elin beş parmağı, sonra öbür el). Kanon: sağ el başparmak 零, işaret 青,
## orta 白, yüzük 朱, serçe 玄; sol el serçe 空, yüzük 南, orta 北, işaret 三, başparmak 玉.
const RING_FINGER := [5, 6, 7, 8, 9, 0, 1, 2, 3, 4]


## Genryū Kyū Fūjin: heykelin ağzından çıkan dokuz mavi ejder, yerdeki tutsağın chakrasını çeker
static func seal_fx(I: Interiors) -> void:
	if is_instance_valid(dragons) or not is_instance_valid(statue):
		return
	statue.open_mouth(1.0)
	dragons = Node3D.new()
	I.room.add_child(dragons)
	var from = statue.mouth_pos()
	var to = I.L(0, 2.0, STATUE_D - 44.0)
	var mb = MB.new()
	var lite = MB.new()
	for k in 9:
		var a = TAU * k / 9.0
		var side = Vector3(cos(a), sin(a) * 0.55, 0.0)
		var pts = []
		var rad = []
		var cols = []
		for i in 31:
			var t = i / 30.0
			var c = from.lerp(to, t) + Vector3(0, sin(t * PI) * 12.0, 0)
			var spread = pow(sin(t * PI), 0.7) * (24.0 + 7.0 * sin(k * 1.7)) + 0.4
			var wob = sin(t * PI) * 3.2   # yılan gibi kıvrılır
			pts.append(c + side * spread + Vector3(sin(t * 13.0 + k * 1.3) * wob, cos(t * 11.0 + k * 2.1) * wob, 0))
			rad.append(lerpf(0.55, 1.15, sin(t * PI)) * (1.0 if i < 29 else 0.6))
			cols.append(Color(0.05, 0.22, 0.85).lerp(Color(0.35, 0.7, 1.0), 0.5 + 0.5 * sin(i * 1.9 + k)))   # açık-koyu chakra dalgaları
		Loft.tube(mb, pts, rad, cols, 8, 2, true, true)
		# ejder başı: uzun çene + iki boynuz (uç tutsağa bakar)
		var hd: Vector3 = (pts[30] - pts[28]).normalized()
		var hp: Vector3 = pts[30]
		Loft.tube(mb, [hp - hd * 0.5, hp + hd * 1.6, hp + hd * 4.2], [Vector2(2.5, 2.0), Vector2(2.2, 1.5), Vector2(0.7, 0.5)], Color(0.1, 0.32, 0.95), 8, 2, true, true)
		var upv = (Vector3.UP - hd * hd.y).normalized()
		for s in [-1.0, 1.0]:
			var sv = hd.cross(Vector3.UP).normalized() * s
			Loft.tube(mb, [hp + upv * 1.3 + sv * 1.0, hp - hd * 3.2 + upv * 3.6 + sv * 1.7], [0.5, 0.05], Color(0.1, 0.32, 0.95), 5, 1, false, true)
			lite.add("sphere", hp + hd * 2.0 + upv * 1.0 + sv * 1.15, Vector3(0.7, 0.42, 0.7), Color(0.92, 0.98, 1.0), Vector3.ZERO, 6)
	lite.add("sphere", to, Vector3(7.0, 5.0, 7.0), Color(0.85, 0.95, 1.0), Vector3.ZERO, 12)
	var mi = MeshInstance3D.new()
	mi.mesh = mb.build(null)
	var m = _mat(Color(1, 1, 1), 0.82)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	mi.material_override = m
	dragons.add_child(mi)
	var li = MeshInstance3D.new()
	li.mesh = lite.build(null)
	var lm = _mat(Color(1, 1, 1), 0.8)
	lm.vertex_color_use_as_albedo = true
	li.material_override = lm
	dragons.add_child(li)
	var l = OmniLight3D.new()
	l.light_color = Color(0.4, 0.65, 1.0)
	l.light_energy = 4.0
	l.omni_range = 80.0
	dragons.add_child(l)
	l.global_position = from.lerp(to, 0.5) + Vector3(0, 6.0, 0)
	var tw = dragons.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 5.5, 0.35)
	tw.parallel().tween_property(m, "albedo_color:a", 0.9, 0.35)
	tw.tween_property(l, "light_energy", 3.2, 0.45)
	tw.parallel().tween_property(m, "albedo_color:a", 0.72, 0.45)


static func seal_fx_off() -> void:
	if is_instance_valid(dragons):
		dragons.queue_free()
	dragons = null
	if is_instance_valid(statue):
		statue.open_mouth(0.0)
	for s in shades:
		if is_instance_valid(s) and int(s.get_meta("slot", 0)) != 0:
			s.queue_free()
