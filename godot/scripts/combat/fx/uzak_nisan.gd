extends RefCounted
## Uzak menzil silahlarının (yumi, arbalet, fukiya, sapan) ORTAK ve GÖRSELSİZ yardımcıları: nişan, kemik konumu, gerçek mermi kurulumu.
## Görsel üretmez; her silahın okunu / efektini kendi dosyası yapar. Mermi oyunun kendi Projectile sınıfıdır (kapsül + dünya çarpışması,
## yana sekince güdüm kopması, saplanma hazır gelir). Oyuncu ve düşman aynı yoldan geçer:
##   oyuncu: kilitli hedef -> nişangâhtaki düşman (Jutsu.soft_target) -> nişangâhın gösterdiği nokta
##   düşman: kendi hedefi -> baktığı yön


static func alive(t) -> bool:
	return t != null and is_instance_valid(t) and t is Node3D and t.has_method("is_dead") and not t.is_dead()


static func target_of(who: Node3D) -> Node3D:
	if who is Player:
		var c = who.combat
		if c != null and alive(c.lock_target):
			return c.lock_target
		return Jutsu.soft_target(who)
	var t = who.get("target")
	if alive(t) and Combat.hostile(who, t):
		return t
	return null


static func chest(t: Node3D) -> Vector3:
	var h = t.get("height")
	return t.global_position + Vector3.UP * (float(h) if h != null else 1.8) * 0.55


## Nişan noktası (dünya)
static func aim_at(who: Node3D, tg: Node3D) -> Vector3:
	if alive(tg):
		return chest(tg)
	if who is Player:
		return who.aim_point()
	return who.global_position + who.face_dir() * 18.0 + Vector3.UP * 1.35


## Gövdeyi nişan noktasına çevirir (oyuncu ve düşman: ikisinde de "facing")
static func face(who: Node3D, p: Vector3) -> void:
	var v = p - who.global_position
	v.y = 0.0
	if v.length() > 0.05 and who.get("facing") != null:
		who.facing = atan2(-v.x, -v.z)


static func bone_pos(who: Node3D, bone: String) -> Vector3:
	var m = who.get("model")
	if m == null or m.skel == null:
		return who.global_position + Vector3.UP * 1.35
	var i = m.skel.find_bone(bone)
	if i < 0:
		return who.global_position + Vector3.UP * 1.35
	return m.skel.global_transform * m.skel.get_bone_global_pose(i).origin


## İpi tutan parmakların konumu (orta parmak kökü; yoksa el kemiği)
static func fingers(who: Node3D, side: String) -> Vector3:
	var m = who.get("model")
	if m != null and m.skel != null and m.skel.find_bone(side + "MiddleProximal") >= 0:
		return bone_pos(who, side + "MiddleProximal")
	return bone_pos(who, side + "Hand")


static func weapon_node(who: Node3D, id: String) -> Node3D:
	var m = who.get("model")
	if m == null or m.get("weapons") == null:
		return null
	for w in m.weapons:
		if String(w["id"]) == id and is_instance_valid(w["node"]):
			return w["node"]
	return null


## Düz atış hızı: yerçekimi telafisiyle noktaya varır
static func solve(from: Vector3, to: Vector3, speed: float, g: float) -> Vector3:
	var d = to - from
	var t = d.length() / maxf(speed, 1.0)
	return d / maxf(t, 0.01) + Vector3.UP * 0.5 * g * t


## Yüksek yay: T saniyede noktaya düşer
static func lob(from: Vector3, to: Vector3, T: float, g: float) -> Vector3:
	return (to - from) / T + Vector3.UP * 0.5 * g * T


## Chakra öder; yetmezse false (kullanıcı silahı saf haliyle kullanır)
static func pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


## İsabet kaydı: oyuncunun atış ustalığı ve görev sayacı (Projectile.tool'un beslediği aynı beceri)
static func credit(who: Node3D, tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not is_instance_valid(who):
		return
	if who is Player:
		Progress.on_hit_landed(tgt)
		LazyFx.g("Mastery").gain(Game.profile, "shurikenjutsu", 0.02)


## Gerçek mermi. o: g, r, life, stick, pierce, info, hit (func(pos, tgt)), tick (func(proj, dt)), vis (Node3D, -Z uçuş yönü)
static func fire(who: Node3D, from: Vector3, vel: Vector3, o: Dictionary) -> Projectile:
	var pr = Projectile.new()
	pr.shooter = who
	pr.vel = vel
	pr.gravity = float(o.get("g", 0.0))
	pr.radius = float(o.get("r", 0.14))
	pr.life = float(o.get("life", 2.5))
	pr.stick = bool(o.get("stick", false))
	pr.pierce = bool(o.get("pierce", false))
	pr.info = (o.get("info", {}) as Dictionary).duplicate()
	pr.info["melee"] = false
	var cb: Callable = o.get("hit", Callable())
	pr.on_hit = func(pos: Vector3, tgt: Node3D) -> void:
		credit(who, tgt)
		if cb.is_valid():
			cb.call(pos, tgt)
	var tick: Callable = o.get("tick", Callable())
	if tick.is_valid():
		pr.on_tick = tick
	var vis = o.get("vis")
	if vis != null:
		pr.add_child(vis)
	who.get_tree().current_scene.add_child(pr)
	pr.global_position = from
	if vel.length() > 0.1:
		var vn = vel.normalized()
		pr.look_at(from + vn, Vector3.UP if absf(vn.y) < 0.98 else Vector3.RIGHT)
	return pr


## Hedefe saplanan görsel (+Z ucu gövdeye girer); hedef başına en çok 5 tane, life sn sonra silinir
static func pin(mi: Node3D, tgt: Node3D, pos: Vector3, dir: Vector3, life: float) -> void:
	if not is_instance_valid(tgt) or int(tgt.get_meta("uzak_sapli", 0)) >= 5 or dir.length() < 0.01:
		mi.free()
		return
	tgt.set_meta("uzak_sapli", int(tgt.get_meta("uzak_sapli", 0)) + 1)
	tgt.add_child(mi)
	var dn = dir.normalized()
	mi.global_transform = Transform3D(Basis.looking_at(-dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT), pos)
	tgt.get_tree().create_timer(life).timeout.connect(func():
		if is_instance_valid(mi):
			mi.queue_free()
		if is_instance_valid(tgt):
			tgt.set_meta("uzak_sapli", maxi(0, int(tgt.get_meta("uzak_sapli", 1)) - 1)))
