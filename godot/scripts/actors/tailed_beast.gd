class_name TailedBeast
extends Fighter
## Kuyruklu canavar boss'u: dev model (BeastRig), çok aşamalı saldırılar, zayıf noktalar, mühürleme.
## Öldürülemez: canı %8'e inince diz çöker → 30 sn içinde [F] ile mühürlenmeli, yoksa toparlanır.

const PHASE2 := 0.66
const PHASE3 := 0.33
const SUBDUE := 0.08

var id = ""
var info := {}
var rig: BeastRig
var display_name = ""
var phase = 1
var aggro = false
var home := Vector3.ZERO
var atk = ""
var atk_t = 0.0
var atk_dur = 1.0
var atk_hit = false
var atk_cd = 3.0
var subdued = false
var subdued_t = 0.0
var seal_item := {}
var ball: Node3D = null
var roam_t = 0.0
var roam_goal := Vector3.ZERO
var num = 1
var cam_set = false
var jin_host: Node3D = null   # bir düşman jinchūriki'nin tam dönüşümüyse: bastırılınca form dağılır, jinchūriki geri gelir


func setup(beast_id: String) -> void:
	id = beast_id
	info = BeastModels.INFO.get(id, BeastModels.INFO["kurama"])
	num = int(info["num"])
	display_name = info["name"]
	team = "enemy"
	set_meta("faction", "beast")
	look = null
	element = info["element"]
	height = float(info["height"])
	radius = height * 0.24
	size = 1.0
	# efsanevi canavarlar: Güç 100 (Shukaku) .. 180 (Kurama); can ve güç seviyeyle
	level = 100 + (num - 1) * 10   # kullanıcı: bijūlar aşırı zayıftı -> en zayıfı (Shukaku) Güç 100, Kurama 180
	display_name = String(info["name"])   # seviye yazısı yok (ustalık sistemi)
	max_hp = 9000.0 + num * 4200.0 + (14000.0 if id == "kurama" else 0.0)
	hp = max_hp
	if id == "jubi":   # dokuzunun toplamı: Kurama'nın (Güç 180) çok üstünde
		level = 260
		max_hp = 150000.0
		hp = max_hp
	power = Stats.npc_power(level) * 1.2   # aynı Güç'teki ninjadan sert (eskiden Shukaku 4.7 < Güç 100 ninja 5.5)
	poise = 99.0


var level := 60
var atk_stage := 0
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO


func _build_body() -> void:
	# dev gövde: kapsül yerine model + tırmanılabilir parça çarpıştırıcıları
	rig = BeastModels.build(id, height)
	add_child(rig)


func _ready() -> void:
	add_to_group("fighters")
	add_to_group("tailed_beasts")
	collision_layer = 0
	collision_mask = 0
	_build_body()
	home = global_position
	roam_goal = home
	global_position.y = Game.ground_height(global_position.x, global_position.z)


func take_hit(inf: Dictionary) -> void:
	if dead:
		return
	var dmg: float = inf.get("dmg", 5.0) * Combat.element_mult(inf.get("element", ""), element)
	# zayıf nokta: saldıran bir mühür noktasına yakınsa (tırmanıp vurmak) x3
	var atk_node = inf.get("attacker")
	if atk_node is Node3D and is_instance_valid(atk_node):
		for w in rig.weak_points:
			if is_instance_valid(w) and atk_node.global_position.distance_to(w.global_position) < maxf(6.0, height * 0.12):
				dmg *= 3.0
				Combat.popup_text(w.global_position + Vector3.UP * 2.0, "ZAYIF NOKTA!", Color(1, 0.85, 0.3))
				BeastFX.weak_hit(w.global_position)
				break
	if subdued:
		dmg = 0.0
	hp = maxf(max_hp * SUBDUE, hp - dmg)
	if not aggro:
		_start_fight()
	Combat.damage_number(global_position + Vector3.UP * height * 0.6, dmg, Color(1, 0.7, 0.3))
	Hud.boss_bar(self)
	var sub_at: float = SUBDUE if jin_host != null else load("res://scripts/combat/fx/shodai_kubikazari_fx.gd").subdue_at(SUBDUE)   # İlk Hokage kolyesi
	if hp <= max_hp * sub_at + 0.01 and not subdued:
		if jin_host != null:
			EnemyJin.form_broken(self)   # jinchūriki dönüşümü: mühürleme yok, form dağılır
			return
		_subdue()


func is_dead() -> bool:
	return dead


## İsabet testi: gövde kapsülü + tırmanma kutuları + zayıf noktalar (başa/sırta çıkıp vurmak da sayılır)
func hit_test(point: Vector3, extra: float) -> bool:
	var base = global_position
	var r = height * 0.2
	var y = clampf(point.y, base.y + r, base.y + height * 0.6)
	if point.distance_to(Vector3(base.x, y, base.z)) <= r + extra:
		return true
	for mk in rig.colliders:
		if not is_instance_valid(mk):
			continue
		var sz: Vector3 = (mk.get_meta("size") as Vector3) * rig.design_scale() * 0.5 + Vector3.ONE * (extra + 1.0)
		var lp = mk.global_transform.orthonormalized().affine_inverse() * point
		if absf(lp.x) <= sz.x and absf(lp.y) <= sz.y and absf(lp.z) <= sz.z:
			return true
	for w in rig.weak_points:
		if is_instance_valid(w) and point.distance_to(w.global_position) < extra + 4.0:
			return true
	return false


func _start_fight() -> void:
	aggro = true
	Hud.boss_bar(self)
	Hud.banner(display_name, "Kuyruklu Canavar uyandı! Zayıf noktalara (altın mühürler) tırman ve vur.", info["chakra"])
	Sfx.play("roar", global_position, 0.6)
	_begin("roar", 1.8)
	if Game.player and not cam_set:
		cam_set = true
		Game.player.set_meta("beast_cam", Game.player.cam_dist)
		Game.player.cam_dist = maxf(Game.player.cam_dist, clampf(height * 0.12, 8.0, 16.0))
		Game.player.cam_range.y = maxf(Game.player.cam_range.y, 28.0)   # dev rakibi tekerle uzaktan izleyebil


func _end_fight() -> void:
	aggro = false
	Hud.boss_bar(null)
	if cam_set and Game.player and is_instance_valid(Game.player):
		Game.player.cam_dist = float(Game.player.get_meta("beast_cam", 5.5))
		if not Game.player.cam_giant:
			Game.player.cam_range = Vector2(2.2, 14.0)
	cam_set = false


## Mangekyō ile çağrılmış müttefik canavar: sahibinin düşmanlarına saldırır, süre bitince kaybolur
var ally_owner: Node3D = null
var ally_life := 0.0


## Kuchiyose komutları müttefik canavarda da geçer (J: Saldır -> Koru -> Bekle -> Takip, U: Bijūdama) — Summon.command_of
var hold_pos := Vector3.INF
var cmd_label: Label3D = null


func show_cmd() -> void:
	if cmd_label == null:
		cmd_label = Label3D.new()
		cmd_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cmd_label.font_size = 64
		cmd_label.pixel_size = 0.03
		cmd_label.outline_size = 14
		cmd_label.no_depth_test = true
		cmd_label.modulate = Color(1.0, 0.85, 0.5)
		add_child(cmd_label)
	cmd_label.position = Vector3(0, height * 1.05, 0)
	cmd_label.text = "[%s]" % Lang.t(Summon.CMD_NAMES[Summon.command_of(ally_owner)])
	cmd_label.visible = true
	var tw = cmd_label.create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): cmd_label.visible = false)


## Saldırılacak hedef: vahşi canavar oyuncuya; müttefik canavar sahibinin komutuna göre (varsayılan: en yakın düşman)
func _foe() -> Node3D:
	if ally_owner == null:
		return Game.player
	var cmd := Summon.command_of(ally_owner) if ally_owner is Player else "saldir"
	if cmd == "takip":
		return null   # saldırmaz, sahibinin peşinden gelir
	if cmd == "koru":
		return Combat.nearest_enemy(ally_owner, 18.0 + height * 0.3)   # yalnız sahibine yaklaşan
	if cmd == "bekle":
		if hold_pos == Vector3.INF:
			hold_pos = global_position
		for f in get_tree().get_nodes_in_group("fighters"):
			if f != self and Combat.hostile(self, f) and not f.is_dead() and f.global_position.distance_to(hold_pos) < 12.0 + height:
				return f
		return null
	if ally_owner is Player and ally_owner.combat:
		var lt = ally_owner.combat.lock_target
		if lt != null and is_instance_valid(lt) and not lt.is_dead() and Combat.hostile(self, lt):
			return lt   # kilitlediğin hedefe saldırır
	var best = null
	var bd = 160.0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or not Combat.hostile(self, f) or f.is_dead():
			continue
		var d = global_position.distance_to(f.global_position)
		if d < bd:
			bd = d
			best = f
	return best


func make_ally(owner_n: Node3D, life: float) -> void:
	ally_owner = owner_n
	ally_life = life
	team = owner_n.team
	set_meta("faction", "")
	aggro = true
	display_name = display_name.split(" — ")[0] + " (Sharingan'ın kontrolünde)"
	if rig:
		rig.set_sharingan(true)   # kanon: Sharingan'la yönetilen canavarın gözleri Sharingan olur


func _physics_process(dt: float) -> void:
	if dead or Game.paused:
		return
	if ally_owner != null:
		ally_life -= dt
		if ally_life <= 0.0 or not is_instance_valid(ally_owner) or hp < max_hp * 0.15:
			dead = true
			BeastFX.vanish(global_position + Vector3.UP * height * 0.5, height, info["chakra"])
			Sfx.play("poof", global_position, 0.5)
			queue_free()
			return
	var pl = _foe()
	if pl == null:
		if ally_owner != null and is_instance_valid(ally_owner):
			if ally_owner is Player and Summon.command_of(ally_owner) == "bekle" and hold_pos != Vector3.INF:
				_walk_to(hold_pos, dt, 0.8)   # Bekle: yerinde durur
				return
			# hedef yok: sahibinin yanında bekle
			if global_position.distance_to(ally_owner.global_position) > height * 1.2:
				_walk_to(ally_owner.global_position, dt, 0.8)
			else:
				rig.move_speed = move_toward(rig.move_speed, 0.0, dt * 2.0)
		return
	for k in statuses.keys():
		statuses[k] -= dt
		if statuses[k] <= 0.0:
			statuses.erase(k)
	var to = pl.global_position - global_position
	to.y = 0
	var dist = to.length()
	if subdued:
		subdued_t -= dt
		if not seal_item.is_empty():
			seal_item["pos"] = pl.global_position if dist < height * 0.7 else global_position
		if subdued_t <= 0.0:
			_recover()
		return
	if not aggro:
		rig.aggro = false
		rig.run_target = 0.0
		# sakin dolaşma
		roam_t -= dt
		if roam_t <= 0.0:
			roam_t = randf_range(8.0, 16.0)
			roam_goal = home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * height * 1.5
		_walk_to(roam_goal, dt, 0.35)
		if dist < maxf(220.0, height * 2.5) and Engine.get_process_frames() % 20 == 0:
			_start_fight()
		return
	if dist > maxf(900.0, height * 10.0) and ally_owner == null:
		_end_fight()
		return
	rig.aggro = true
	rig.look_yaw = wrapf(atan2(-to.x, -to.z) - facing, -PI, PI)
	# yöne dön
	var want = atan2(-to.x, -to.z)
	facing = lerp_angle(facing, want, minf(1.0, dt * (0.6 if atk == "" else 0.2)))
	rig.rotation.y = facing
	# fazlar
	var hpf = hp / max_hp
	if ally_owner != null:
		hpf = 1.0   # müttefik: öfke fazları/afiş yok
	if phase == 1 and hpf < PHASE2:
		phase = 2
		Hud.banner(display_name, "ÖFKELENDİ — Kuyruklu Canavar Topu!", Color(1, 0.35, 0.25))
		_begin("roar", 1.6)
	elif phase == 2 and hpf < PHASE3:
		phase = 3
		Hud.banner(display_name, "ÇILGINLIK — chakra taşıyor!", Color(1, 0.2, 0.2))
		_begin("roar", 1.6)
	# saldırı yürüt
	if atk != "":
		atk_t += dt
		_run_attack(dt)
		if atk_t >= atk_dur:
			atk = ""
			atk_cd = randf_range(1.6, 3.2) / (1.0 + (phase - 1) * 0.35)
		return
	atk_cd -= dt
	if dist > height * 0.75:
		var far = dist > height * 1.6
		rig.run_target = 1.0 if far else 0.0
		_walk_to(pl.global_position, dt, 1.9 if far else 1.0)   # uzaktaysa koşar (dört ayaklı dörtnala kalkar)
	else:
		rig.run_target = 0.0
		rig.move_speed = move_toward(rig.move_speed, 0.0, dt * 2.0)
	if atk_cd <= 0.0:
		_choose(dist)


func _walk_to(p: Vector3, dt: float, mul: float) -> void:
	var d = p - global_position
	d.y = 0
	if d.length() < 3.0:
		rig.move_speed = move_toward(rig.move_speed, 0.0, dt * 2.0)
		return
	var spd = clampf(height * 0.09, 4.0, 14.0) * mul
	global_position += d.normalized() * spd * dt
	global_position.y = Game.ground_height(global_position.x, global_position.z)
	if not aggro:
		facing = lerp_angle(facing, atan2(-d.x, -d.z), minf(1.0, dt * 0.8))
		rig.rotation.y = facing
	rig.move_speed = move_toward(rig.move_speed, minf(mul, 1.0), dt * 2.0)


func _choose(dist: float) -> void:
	var opts = []
	if dist < height * 0.8:
		opts += ["stomp", "combo", "tail", "combo", "elem"]
	else:
		opts += ["elem", "elem", "elem", "roar"]
		if dist < height * 3.5:
			opts += ["leap", "leap"]   # aradaki mesafeyi bir sıçrayışta kapatır, iniş darbesi
	if ally_owner != null:   # çağrılan bijū öfke evresine hiç geçmez (canı müttefikte hep tam sayılır) — yine de kanondaki gibi Bijūdama atar
		opts += ["ball"]
	if phase >= 2:
		opts += ["ball", "elem"]
	if phase >= 3:
		opts += ["minions", "ball"]
	_begin(opts.pick_random(), 0.0)


func _begin(a: String, dur: float) -> void:
	atk = a
	atk_t = 0.0
	atk_hit = false
	var d = dur
	match a:
		"stomp":
			d = 1.5; rig.play_action("stomp", d)
		"swipe":
			d = 1.2; rig.play_action(["swipe_l", "swipe_r"].pick_random(), d)
		"combo":
			d = 2.3; rig.play_action("swipe_l", 0.55)   # pençe → pençe → bitiriş (canavara göre)
			atk_stage = 0
		"leap":
			d = 1.5; rig.play_action("leap", d)
			leap_from = global_position
			var pl0 = _foe()
			var tgt = pl0.global_position if pl0 else global_position + face_dir() * height
			var dv = tgt - global_position
			dv.y = 0
			leap_to = global_position + dv.normalized() * maxf(dv.length() - height * 0.5, 0.0)
			Sfx.play("whoosh", global_position, 0.35)
		"tail":
			d = 2.0; rig.play_action("tail", d)
		"roar":
			d = maxf(d, 1.6); rig.play_action("roar", d)
		"elem":
			# teknik başta seçilir: hareketi ona göre (şaha kalkma / nefes / fırlatma / siper / kuyruk kamçısı), etkisi hareketin vuruş anında
			var pl0 = _foe()
			elem_key = BijuuArts.pick_key(id, (pl0.global_position - global_position).length(), clampf(height / 14.0, 2.0, 3.5)) if pl0 != null else ""
			if elem_key != "":
				var an: Array = BijuuArts.anim(elem_key)
				d = float(an[1]) + 0.3
				elem_rel = float(an[1]) * float(an[2]) / d
				rig.play_action(String(an[0]), float(an[1]))
			else:
				elem_rel = 0.5
				d = 1.6; rig.play_action("charge" if id in ["kokuo", "chomei", "isobu", "matatabi"] else "roar", d)
		"ball":
			d = 4.2; rig.play_action("bijudama", d)
			_ball_start()
		"minions":
			d = 1.6; rig.play_action("roar", d)
	atk_dur = d


## Kombo pençesi: canavara özgü iz (kum, mavi alev, lav...) önünde yelpaze
func _claw_hit(mul: float) -> void:
	var fwd = face_dir()
	var pt = global_position + fwd * height * 0.45 + Vector3.UP * height * 0.15
	BijuuArts.melee(self, id, pt, height * 0.28, _dmg(26.0) * mul, fwd)
	Sfx.play("whoosh", pt, 0.5)


## Canavarın gücü (power) hasara katılır: eskiden hesaplanıp hiç kullanılmıyordu — Güç 100-180 bijū, aynı güçteki ninjanın
## üçte biri kadar vuruyordu (çağrılan bijū zayıf şikâyeti). Ninja jutsusu taban x power; bijū tabanı ninjanınkinin ~2 katı -> x0.55
func _dmg(base: float) -> float:
	return base * (1.0 + num * 0.12) * (1.0 + (phase - 1) * 0.25) * maxf(1.0, power * 0.55)


func _run_attack(_dt: float) -> void:
	var k = atk_t / atk_dur
	var fwd = face_dir()
	match atk:
		"stomp":
			if k > 0.55 and not atk_hit:
				atk_hit = true
				var c = global_position
				Combat.hit_sphere(self, c + Vector3.UP * 2.0, height * 0.45, {"dmg": _dmg(28.0), "knock": 26.0, "launch": 9.0, "kind": "heavy", "element": "doton"})
				_shockwave(c, height * 0.9)
		"swipe":
			if k > 0.42 and not atk_hit:
				atk_hit = true
				var pt = global_position + fwd * height * 0.45 + Vector3.UP * height * 0.15
				BijuuArts.melee(self, id, pt, height * 0.28, _dmg(34.0), fwd)   # canavara özgü pençe: kum, mavi alev, lav, asit...
				Sfx.play("whoosh", pt, 0.5)
		"combo":
			# 0-0.55 sn sol pençe, 0.55-1.1 sağ pençe, 1.1-2.3 bitiriş: dört ayaklı ısırık + kuyruk savuruşu, dik canavar iki elle yere çakar
			var tt = atk_t
			if atk_stage == 0 and tt > 0.3:
				atk_stage = 1
				_claw_hit(0.9)
			elif atk_stage == 1 and tt > 0.55:
				atk_stage = 2
				rig.play_action("swipe_r", 0.55)
			elif atk_stage == 2 and tt > 0.85:
				atk_stage = 3
				_claw_hit(1.0)
			elif atk_stage == 3 and tt > 1.1:
				atk_stage = 4
				rig.play_action("bite" if rig.quadruped else "slam", 1.0)
			elif atk_stage == 4 and tt > (1.5 if rig.quadruped else 1.65):
				atk_stage = 5
				if rig.quadruped:
					var pt = rig.mouth_pos() + fwd * height * 0.15
					BijuuArts.melee(self, id, pt, height * 0.3, _dmg(40.0), fwd)
					Sfx.play("hit_heavy", pt, 0.6)
				else:
					var c2 = global_position + fwd * height * 0.4
					Combat.hit_sphere(self, c2 + Vector3.UP * 2.0, height * 0.5, {"dmg": _dmg(44.0), "knock": 30.0, "launch": 14.0, "kind": "heavy", "element": BijuuArts.MELEE.get(id, BijuuArts.MELEE["kurama"])[0]})
					BijuuArts.melee(self, id, c2 + Vector3.UP * height * 0.05, height * 0.35, _dmg(10.0), fwd)
					_shockwave(c2, height * 0.8)
			elif atk_stage == 5 and tt > 1.75 and rig.quadruped:
				atk_stage = 6
				rig.play_action("tail", 0.55)
				Combat.hit_sphere(self, global_position + Vector3.UP * height * 0.2, height * 0.7, {"dmg": _dmg(26.0), "knock": 38.0, "launch": 8.0, "kind": "heavy"})
				BeastFX.tail_sweep(global_position, info["chakra"], height * 1.4)
		"leap":
			# sıçrayış yayı: çömelme (0-0.22), uçuş (0.22-0.84), iniş darbesi
			var u = clampf((k - 0.22) / 0.62, 0.0, 1.0)
			var p = leap_from.lerp(leap_to, u)
			p.y = Game.ground_height(p.x, p.z)
			global_position = p
			if k >= 0.84 and not atk_hit:
				atk_hit = true
				rig.land_fx()
				Combat.hit_sphere(self, global_position + Vector3.UP * 2.0, height * 0.6, {"dmg": _dmg(36.0), "knock": 34.0, "launch": 12.0, "kind": "heavy", "element": "doton"})
				_crater(global_position, height * 0.3)
				Sfx.play("boom", global_position, 0.45)
		"tail":
			if k > 0.35 and not atk_hit:
				atk_hit = true
				Combat.hit_sphere(self, global_position + Vector3.UP * height * 0.2, height * 0.75, {"dmg": _dmg(30.0), "knock": 34.0, "launch": 8.0, "kind": "heavy"})
				BeastFX.tail_sweep(global_position, info["chakra"], height * 1.5)
				Sfx.play("whoosh", global_position, 0.35)
				if Game.world:
					Game.world.env.add_shake(0.8)
		"roar":
			if k > 0.25 and not atk_hit:
				atk_hit = true
				Sfx.play("roar", global_position, 0.55)
				Combat.hit_sphere(self, global_position + Vector3.UP * height * 0.4, height * 0.9, {"dmg": _dmg(10.0), "knock": 40.0, "launch": 10.0, "kind": "heavy"})
				BeastFX.roar(rig.mouth_pos(), info["chakra"], height * 1.2, fwd)
				if Game.world:
					Game.world.env.add_shake(1.2)
		"elem":
			if k > maxf(0.05, elem_rel) and not atk_hit:
				atk_hit = true
				_element_attack()
		"ball":
			_ball_tick(k)
		"minions":
			if k > 0.4 and not atk_hit:
				atk_hit = true
				_minions()


## Yere vuruş: halka şok dalgası + krater izi
func _shockwave(c: Vector3, r: float) -> void:
	BeastFX.stomp(c, r * 0.5)
	_crater(c, r * 0.35)
	Sfx.play("boom", c, 0.5)
	if Game.world:
		Game.world.env.add_shake(1.5)


func _crater(c: Vector3, r: float) -> void:
	var dc = Decal.new()
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d = Vector2(x - 32, y - 32).length() / 32.0
			var a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.18, 0.13, 0.08, a * 0.85 * (0.7 + 0.3 * sin(d * 18.0))))
	dc.texture_albedo = ImageTexture.create_from_image(img)
	dc.size = Vector3(r * 2.0, 20.0, r * 2.0)
	get_tree().current_scene.add_child(dc)
	dc.global_position = c
	var tw = dc.create_tween()
	tw.tween_interval(40.0)
	tw.tween_property(dc, "modulate:a", 0.0, 6.0)
	tw.tween_callback(dc.queue_free)


## Canavara özel teknik (BijuuArts): Renkūdan, mercan, lav fışkırması, asit baloncukları, mürekkep, chakra kolu...
func _element_attack() -> void:
	var pl = _foe()
	if pl == null:
		return
	var dist = (pl.global_position - global_position).length()
	# teknik ölçeği: dev ama oyuncunun ekranını kaplamayacak kadar (alan teknikleri oyuncunun çevresine iner)
	var ts = clampf(height / 14.0, 2.0, 3.5)
	var key = elem_key if elem_key != "" else BijuuArts.pick_key(id, dist, ts)
	elem_key = ""
	if key != "":
		var td = BijuuArts.tech(id, key)
		BijuuArts.use(self, id, key, {"s": ts, "dmg": _dmg(30.0), "from": rig.mouth_pos(), "aim": pl.global_position + Vector3.UP, "tgt": pl, "col": info["chakra"]})
		Combat.popup_text(rig.mouth_pos() + Vector3.UP * 6.0, String(td.get("name", "")), info["chakra"].lightened(0.3))
		Sfx.play("roar", rig.mouth_pos(), 0.8, 0.5)
		return
	_element_attack_old()


func _element_attack_old() -> void:
	var pl = _foe()
	if pl == null:
		return
	var from = rig.mouth_pos()
	var aim = (pl.global_position + Vector3.UP - from).normalized()
	var ch: Color = info["chakra"]
	match id:
		"shukaku":  # rüzgar: sıkıştırılmış hava mermisi + kum saçması
			for i in 3:
				_proj(from, (aim + Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08))).normalized(), 60.0, height * 0.06, "fuuton", Color(0.9, 0.8, 0.55), _dmg(26.0))
		"matatabi":  # mavi kedi alevi topları
			for i in 4:
				_proj(from, (aim + Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.05), 0)).normalized(), 48.0, height * 0.07, "katon", Color(0.3, 0.45, 1.0), _dmg(24.0))
		"isobu":  # su kütlesi mermisi + mercan tuzağı
			_proj(from, aim, 50.0, height * 0.1, "suiton", Color(0.4, 0.7, 1.0), _dmg(34.0))
			pl.apply_status("slow", 3.0)
		"son_goku":  # lav bombaları (yay çizerek)
			for i in 6:
				var tgt = pl.global_position + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
				var pr = _proj(from, Vector3.ZERO, 0.0, height * 0.045, "yoton", Color(1.0, 0.4, 0.05), _dmg(22.0))
				var t = 1.6 + randf() * 0.6
				pr.gravity = 20.0
				pr.vel = (tgt - from) / t + Vector3.UP * 20.0 * t * 0.5
		"kokuo":  # buharla güçlenmiş boynuz hücumu
			var d = (pl.global_position - global_position)
			d.y = 0
			var dist = d.length()
			var tw = create_tween()
			var end = global_position + d.normalized() * minf(dist + 10.0, height * 2.0)
			end.y = Game.ground_height(end.x, end.z)
			tw.tween_property(self, "global_position", end, 0.6)
			tw.tween_callback(func():
				Combat.hit_zone(self, global_position, face_dir(), height * 0.9, 50.0, height, {"dmg": _dmg(40.0), "knock": 40.0, "launch": 10.0, "kind": "heavy", "element": "futton"})
				BeastFX.steam(global_position + Vector3.UP * height * 0.3, height))
		"saiken":  # aşındırıcı sümük alanı
			_field(pl.global_position, height * 0.25, Color(0.75, 0.95, 0.85), 7.0, _dmg(6.0), "suiton")
		"chomei":  # pul tozu: görüşü bulandırır + hücum
			_field(pl.global_position, height * 0.3, Color(0.9, 1.0, 0.6), 5.0, _dmg(5.0), "fuuton")
			if Game.world:
				Game.world.env.flash_tint(Color(0.85, 1.0, 0.5, 0.25), 3.0)
		"gyuki":  # mürekkep püskürtme (görüş kararır) + dokunaç
			_field(pl.global_position, height * 0.2, Color(0.05, 0.03, 0.08), 6.0, _dmg(8.0), "suiton")
			if Game.world:
				Game.world.env.flash_tint(Color(0, 0, 0, 0.55), 2.5)
			Combat.hit_zone(self, global_position, face_dir(), height * 0.9, 55.0, height, {"dmg": _dmg(30.0), "knock": 20.0, "kind": "heavy"})
		_:  # kurama: art arda küçük canavar topları
			for i in 3:
				get_tree().create_timer(i * 0.3).timeout.connect(func():
					if dead or Game.player == null: return
					var a2 = (Game.player.global_position + Vector3.UP - rig.mouth_pos()).normalized()
					var b = TailedBeasts.fire_ball(self, rig.mouth_pos(), a2, height * 0.035, ch, _dmg(30.0), 70.0)
					b.homing = Game.player
					b.homing_turn = 0.4)
	Sfx.play("roar", from, 0.8, 0.5)


func _proj(from: Vector3, dir: Vector3, spd: float, r: float, el: String, col: Color, dmg: float) -> Projectile:
	var pr = Projectile.new()
	pr.shooter = self
	pr.vel = dir * spd
	pr.radius = maxf(1.0, r)
	pr.life = 4.0
	pr.info = {"dmg": dmg, "element": el, "knock": 18.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.06}
	if el == "yoton":   # Son Gokū lav kayası: enerji küresi/ateş patlaması değil
		pr.add_child(BeastFX.lava_ball(maxf(1.5, r * 2.0)))
	else:
		pr.add_child(BeastFX.shot_ball(maxf(1.5, r * 2.0), col, el))
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		if el == "yoton":
			BeastFX.lava_hit(pos, maxf(1.5, r * 0.8))
		else:
			BeastFX.shot_hit(pos, maxf(1.0, r * 0.6), col, el)
		Combat.hit_sphere(self, pos, maxf(4.0, r * 2.5), {"dmg": dmg * 0.5, "element": el, "knock": 14.0, "kind": "heavy"}, pr.hit_list)
	get_tree().current_scene.add_child(pr)
	pr.global_position = from
	return pr


## Hasar veren zemin alanı (sümük, toz, mürekkep)
func _field(c: Vector3, r: float, col: Color, dur: float, dps: float, el: String) -> void:
	var n = Node3D.new()
	get_tree().current_scene.add_child(n)
	n.global_position = c
	BeastFX.field(c, r, col, dur, id)
	var t = {"v": 0.0}
	var tm = Timer.new()
	tm.wait_time = 0.5
	tm.autostart = true
	n.add_child(tm)
	tm.timeout.connect(func():
		t["v"] += 0.5
		if is_instance_valid(self):
			Combat.hit_sphere(self, c + Vector3.UP, r, {"dmg": dps * 0.5, "element": el, "knock": 0.0, "kind": "light"})
		if t["v"] >= dur:
			n.queue_free())


# ------------------------------------------------------------------ Kuyruklu Canavar Topu
var elem_key := ""        # bu element saldırısında kullanılacak teknik (hareket ona göre seçilir)
var elem_rel := 0.5       # tekniğin çıktığı an (saldırı süresine oranla)


## Anime Bijūdama: top ağzın önünde başı kadar büyür, canavar yutar, fırlatır
func _ball_start() -> void:
	Combat.popup_text(rig.mouth_pos() + Vector3.UP * 4.0, "Bijūdama!", Color(0.8, 0.5, 1.0))
	BijudamaFX.charge(rig.mouth, height * 0.34, 4.2 * 0.86)


func _ball_tick(k: float) -> void:
	if k > 0.86 and not atk_hit:
		atk_hit = true
		var pl = _foe()
		if pl == null:
			return
		var from = BijudamaFX.muzzle(rig.mouth, height * 0.34 * 0.4)
		var aim = (pl.global_position + Vector3.UP - from).normalized()
		TailedBeasts.fire_ball(self, from, aim, height * 0.17, info["chakra"], _dmg(110.0), 75.0)


func _minions() -> void:
	for i in 2 + phase:
		var e = Enemy.new()
		var a = Enemy.archetype("rogue", i)
		a["name"] = "%s Chakra Klonu" % display_name.split(" — ")[0]
		a["hp"] = 160.0 + num * 30.0
		a["power"] = 2.0
		a["xp"] = 60
		a["ryo"] = 0
		a["respawn"] = false
		a["element"] = element
		e.setup(a)
		get_tree().current_scene.add_child(e)
		var p = global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * height * 0.6
		p.y = Game.ground_height(p.x, p.z)
		e.global_position = p
		e.home = p
		BeastFX.minion(p + Vector3.UP, info["chakra"])


# ------------------------------------------------------------------ boyun eğme / mühürleme
func _subdue() -> void:
	subdued = true
	subdued_t = 30.0 * (1.0 + Stats.skill(Game.profile, "fuin")) * load("res://scripts/combat/fx/shodai_kubikazari_fx.gd").hold_mult()
	atk = ""
	if ball and is_instance_valid(ball):
		ball.queue_free()
	rig.play_action("kneel", 999.0)
	rig.move_speed = 0.0
	Hud.banner("%s DİZ ÇÖKTÜ" % display_name.split(" — ")[0].to_upper(), "30 saniye içinde yanına git ve [F] ile mühürle!", Color(1, 0.85, 0.4))
	seal_item = {"pos": global_position, "radius": height * 0.75, "kind": "beast_seal", "label": "Mühürle: %s" % display_name.split(" — ")[0], "beast": self}
	Interact.add(seal_item)


func _recover() -> void:
	subdued = false
	Interact.items.erase(seal_item)
	seal_item = {}
	hp = max_hp * 0.35
	phase = 3
	rig.play_action("roar", 1.8)
	Hud.banner(display_name, "Mühürlenmeden toparlandı!", Color(1, 0.3, 0.2))
	Hud.boss_bar(self)


## Mühürleme tamamlandı (TailedBeasts çağırır): girdap efektiyle kaybolur
func sealed_away(into: Node3D) -> void:
	dead = true
	Interact.items.erase(seal_item)
	_end_fight()
	var tgt = into.global_position + Vector3.UP if into else global_position
	BeastFX.sealed(global_position + Vector3.UP * height * 0.5, height, info["chakra"], tgt)
	var tw = create_tween()
	tw.tween_property(rig, "scale", Vector3.ONE * 0.01, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## İçine mühürleme: canavarın ruhu emilir — beden yarı saydam parlayan bir ruha döner, göğsünden mühürleyenin karnına sarmal
## bir chakra akıntısı akar, canavar kendi ekseninde dönerek, uzayıp küçülerek akıntıyla içine çekilir; karındaki mühür
## sarmalı parlar, son anda içine girerken sarsıntı. (Sahne efektleri burada, sıfırdan.)
func absorbed_into(into: Node3D) -> void:
	dead = true
	Interact.items.erase(seal_item)
	_end_fight()
	set_physics_process(false)
	var col: Color = info["chakra"]
	var pl = into
	if pl and pl.get("model") and pl.model.overlay:
		pl.model.overlay.set_pose("seal", 1.0)   # el mührü
	if pl is Player:
		pl.input_locked = maxf(pl.input_locked, 5.2)
		pl.velocity = Vector3.ZERO
	# 1) beden ruha döner: her parçaya kenarı parlayan yarı saydam chakra katmanı
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 col : source_color;
uniform float k = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float flow = 0.5 + 0.5 * sin(TIME * 9.0 + (VERTEX.y + VERTEX.x) * 0.6);
	ALBEDO = col.rgb * (0.9 + rim * 3.0) * (0.8 + flow * 0.4);
	ALPHA = clamp(k * (0.55 + rim), 0.0, 1.0);
}"""
	gm.shader = sh
	gm.set_shader_parameter("col", col)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = gm
	var tk = create_tween()
	tk.tween_method(func(x: float): gm.set_shader_parameter("k", x), 0.0, 1.0, 0.9)
	# karındaki mühür sarmalı (tek parça: chakra renginde noktalar sarmal üzerinde)
	var mark: MeshInstance3D = null
	if pl and is_instance_valid(pl):
		var mb := MB.new()
		for i in 34:
			var u = float(i) / 33.0
			var a = u * TAU * 2.2
			var rr = 0.03 + u * 0.15
			mb.add("sphere", Vector3(cos(a) * rr, sin(a) * rr, 0.0), Vector3.ONE * (0.022 + u * 0.012), col.lightened(0.3), Vector3.ZERO, 6)
		mark = MeshInstance3D.new()
		mark.mesh = mb.build(null)
		var mm := StandardMaterial3D.new()
		mm.vertex_color_use_as_albedo = true
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = Color(1, 1, 1, 0.0)
		mark.material_override = mm
		pl.add_child(mark)
		var fd: Vector3 = pl.face_dir() if pl.has_method("face_dir") else Vector3.FORWARD
		var belly: Vector3 = pl.global_position + Vector3.UP * 0.95 * float(pl.model.age_scale if pl.get("model") else 1.0)
		mark.global_position = Vector3(pl.global_position.x, belly.y, pl.global_position.z) + fd * 0.2   # karnın ortası, gövdenin önü
		mark.look_at(mark.global_position + fd, Vector3.UP)
		var tm = mark.create_tween()
		tm.tween_property(mm, "albedo_color:a", 1.0, 0.6)
		tm.parallel().tween_property(mark, "rotation:z", TAU * 2.0, 4.6)
	# 2) sarmal ruh akıntısı: göğüsten karna, eğri boyunca dönen parlak taneler (canavar küçüldükçe çıkış noktası da gelir)
	var src := func() -> Vector3: return rig.global_position + Vector3.UP * height * 0.5 * rig.scale.y
	var dst := func() -> Vector3: return (mark.global_position if is_instance_valid(mark) else (pl.global_position + Vector3.UP if is_instance_valid(pl) else global_position))
	var root = get_tree().current_scene
	for i in 240:
		get_tree().create_timer(0.3 + i * 0.014, false).timeout.connect(func():
			if not is_instance_valid(root):
				return
			var o := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r0 = clampf(height * 0.016, 0.2, 1.1) * randf_range(0.6, 1.2)
			sm.radius = r0
			sm.height = r0 * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			o.mesh = sm
			var om := StandardMaterial3D.new()
			om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			om.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			om.albedo_color = col.lightened(randf_range(0.0, 0.25)) * 1.15   # parlak ama canavarın chakra renginde
			o.material_override = om
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(o)
			var ph = randf() * TAU
			var spin = randf_range(2.0, 3.5)
			var dur = randf_range(0.7, 1.0)
			var tw2 = o.create_tween()
			tw2.tween_method(func(t: float):
				if not is_instance_valid(o):
					return
				var a0: Vector3 = src.call() if is_instance_valid(rig) else dst.call()
				var b0: Vector3 = dst.call()
				var mid = a0.lerp(b0, 0.5) + Vector3.UP * a0.distance_to(b0) * 0.18
				var p = a0.lerp(mid, t).lerp(mid.lerp(b0, t), t)   # ikinci derece eğri
				var ax = (b0 - a0).normalized()
				var sd = ax.cross(Vector3.UP).normalized()
				var up2 = sd.cross(ax).normalized()
				var rad = a0.distance_to(b0) * 0.08 * (1.0 - t) + 0.05
				var ang = ph + t * TAU * spin
				o.global_position = p + (sd * cos(ang) + up2 * sin(ang)) * rad
				o.scale = Vector3.ONE * maxf(0.06, 1.0 - t * 0.94), 0.0, 1.0, dur)   # karna vardıkça incelir (mühre akar).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw2.tween_callback(o.queue_free))
	# 3) beden akıntıyla çekilir: döner, uzar, küçülür, karna girer
	var start: Vector3 = rig.global_position
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_method(func(t: float):
		if not is_instance_valid(rig):
			return
		var d: Vector3 = dst.call()
		rig.global_position = start.lerp(d - Vector3.UP * height * 0.5 * (1.0 - t) * 0.02, t * t)
		var s = lerpf(1.0, 0.006, pow(t, 0.7))
		rig.scale = Vector3(s * (1.0 - t * 0.45), s * (1.0 + t * 0.8), s * (1.0 - t * 0.45))
		rig.rotation.y += 0.08 + t * 0.35, 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if Game.world:
			Game.world.env.add_shake(1.0)
		Sfx.play("seal", global_position, 0.6, 0.9)
		if is_instance_valid(pl) and pl.get("model"):
			pl.model.play("hit", 0.05, 0.8, true)   # içine giren güçle sarsılır
			pl.model.overlay.set_pose("seal", 0.0)
		if is_instance_valid(mark):
			var tf = mark.create_tween()
			tf.tween_property(mark, "scale", Vector3.ONE * 1.8, 0.25)
			tf.tween_property(mark.material_override, "albedo_color:a", 0.0, 0.8)
			tf.tween_callback(mark.queue_free))
	tw.tween_interval(0.3)
	tw.tween_callback(queue_free)


func die(_inf: Dictionary) -> void:
	pass


func _exit_tree() -> void:
	if not seal_item.is_empty():
		Interact.items.erase(seal_item)
	if aggro:
		_end_fight()
