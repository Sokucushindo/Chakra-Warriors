extends RefCounted
## Bōenkyō (Narutopedia "Eye Scope", hedef: res://scripts/combat/fx/boenkyo_fx.gd). Kanon kullanıcı: Deidara; saçın altında gözde taşınan dürbün.
## Kanon işlev: uzaktaki hedefi görür, aradaki mesafeyi ölçer. Yüz eşyası + alet tuşu: 9 sn dürbün açılır, görüş daralır, görüşteki rakiplerin üstünde
## mesafe yazar, nişangâha en yakın olan 140 m'ye kadar kilitlenir (uzak silah, alet ve jutsu o hedefi alır). Hasar vermez. Oyuncu ve düşman aynı araç.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const DUR := 9.0
const RANGE := 140.0
const FOV := 26.0
const STYLE := "boenkyo"


## Baş modeli (ref Deidara's_Scope.png): gri kutu, altın plaka, büyük yeşil + küçük kırmızı mercek, şakağa giden kol. Yerel +Z yüzün önü.
static func head(b: MB) -> void:
	var grey = Color(0.47, 0.47, 0.53)
	var dark = Color(0.27, 0.28, 0.34)
	var gold = Color(0.84, 0.68, 0.43)
	b.add("box", Vector3.ZERO, Vector3(0.09, 0.052, 0.04), grey, Vector3(0, 0, 18))
	b.add("box", Vector3(0.012, 0.0, -0.028), Vector3(0.096, 0.058, 0.018), dark, Vector3(0, 0, 18))
	b.add("box", Vector3(-0.002, 0.0, 0.0212), Vector3(0.05, 0.012, 0.002), gold, Vector3(0, 0, 18))
	b.add("cyl", Vector3(-0.022, -0.007, 0.022), Vector3(0.036, 0.003, 0.036), gold, Vector3(90, 0, 0), 14)
	b.add("cyl", Vector3(0.024, 0.008, 0.022), Vector3(0.026, 0.003, 0.026), gold, Vector3(90, 0, 0), 12)
	b.add("cyl", Vector3(-0.022, -0.007, 0.0245), Vector3(0.028, 0.003, 0.028), Color(0.12, 0.42, 0.42), Vector3(90, 0, 0), 14)
	b.add("cyl", Vector3(0.024, 0.008, 0.0245), Vector3(0.018, 0.003, 0.018), Color(0.55, 0.13, 0.15), Vector3(90, 0, 0), 12)
	b.add("box", Vector3(0.062, 0.012, -0.085), Vector3(0.008, 0.016, 0.14), dark, Vector3(0, 12, 0))


static func has_scope(who: Node3D) -> bool:
	var m = who.get("model") if who != null else null
	return m != null and m is CharacterModel and str(m.look.get("face_style", "")) == STYLE


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	Sfx.play("click", who.global_position + Vector3.UP * 1.6, 1.4, 0.6)
	if who is Player:
		_player_view(who)
	else:
		_enemy_spot(who)
	return null


static func _enemy_spot(e: Node3D) -> void:
	var best: Node3D = null
	var bd = 0.0
	for f in Kit.fighters():
		if f == e or not Combat.hostile(e, f) or f.is_dead():
			continue
		var d = e.global_position.distance_to(f.global_position)
		if d <= 90.0 and d > bd:
			bd = d
			best = f
	if best != null:
		e.target = best   # gözcü: en uzaktaki rakibi hedef alır


static func _in_view(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var s = cam.unproject_position(p)
	var r = cam.get_viewport().get_visible_rect()
	return r.has_point(s)


static func _player_view(p: Node3D) -> void:
	var cam: Camera3D = p.cam
	if cam == null:
		return
	var tok = int(p.get_meta("boenkyo_tok", 0)) + 1
	p.set_meta("boenkyo_tok", tok)
	var base = float(Game.settings.get("fov", 70.0))
	var s = {"t": 0.0, "label": 0.0}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(p) or not is_instance_valid(cam):
			return true
		if int(p.get_meta("boenkyo_tok", 0)) != tok:
			return true
		s["t"] += dt
		var t: float = s["t"]
		var done = t >= DUR or p.is_dead() or not has_scope(p)
		var k = minf(t / 0.2, 1.0) * clampf((DUR - t) / 0.2, 0.0, 1.0)
		cam.fov = base if done else lerpf(base, FOV, k)
		if done:
			return true
		s["label"] -= dt
		if float(s["label"]) <= 0.0:
			s["label"] = 0.9
			_scan(p, cam)
		return false
	Kit.ticker(p.global_position, fn)


static func _scan(p: Node3D, cam: Camera3D) -> void:
	var best: Node3D = null
	var bs = INF
	var centre = cam.get_viewport().get_visible_rect().size * 0.5
	for f in Kit.fighters():
		if f == p or not Combat.hostile(p, f) or f.is_dead():
			continue
		var d = p.global_position.distance_to(f.global_position)
		var head_p = U.chest(f) + Vector3.UP * 0.8
		if d > RANGE or not _in_view(cam, head_p):
			continue
		Combat.popup_text(head_p + Vector3.UP * 0.5, "%d m" % int(round(d)), Color(0.7, 0.95, 0.9))
		var sd = cam.unproject_position(head_p).distance_to(centre)
		if sd < bs:
			bs = sd
			best = f
	if best != null and p.combat != null:
		p.combat.lock_target = best
