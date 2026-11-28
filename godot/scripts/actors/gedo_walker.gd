class_name GedoWalker
extends Node
## Gedō Mazō'nun yürüyen hâli (kanon: Dördüncü Büyük Savaş'ta heykel kambur yürür, elleriyle yeri ezer, kükremesiyle
## orduyu savurur; Obito / Madara kafasının üstünde durup onu yönetir).
## Çağırma tekniği heykeli çıkarıp çökerttikten sonra bu beyin devralır: düşmana yürür, çift el ezme ve kükreme yapar,
## adımları yeri sarsar. Çağıran yanına gelip [F] ile kafasına biner: W A S D yürütür, sol tık ezme, sağ tık kükreme, F iner.
## Görsel (yer yarığı, toz, taş) çağırma tekniğinin kendi efektleridir (DojutsuFXB).

const SPEED := 15.0       # m/sn (100 m'lik dev: ağır adımlar)
const TURN := 0.75        # rad/sn
const STRIDE := 30.0      # m / adım
const SMASH_CD := 4.5
const ROAR_CD := 12.0
const SWEEP_CD := 6.0
const STOMP_CD := 8.0
const DRAGON_CD := 11.0
const CHAIN_CD := 16.0
const RIDE_REACH := 75.0
const JID := "kuchiyose_gedo_mazo"

static var active: GedoWalker = null   # oyuncunun heykeli ([F] ile binilir)

var g: GedoMazo
var owner_f: Node3D
var pj
var fxb
var delay := 0.0
var phase := 0.0
var amp := 0.0
var act := ""
var act_t := 0.0
var act_step := 0
var smash_cd := 1.5
var roar_cd := 5.0
var sweep_cd := 2.5
var stomp_cd := 4.0
var dragon_cd := 3.0
var chain_cd := 6.0
var _act_gait := {}
var rider: Node3D = null
var _cam0: Array = []
var _want_act := ""
var _roar_hit: Array = []
var _last_cos := 1.0


static func attach(statue: GedoMazo, c: Node3D, pjn, wait: float) -> GedoWalker:
	var w := new()
	w.g = statue
	w.owner_f = c
	w.pj = pjn
	w.fxb = LazyFx.g("DojutsuFXB")
	w.delay = wait
	statue.add_child(w)
	if c is Player:
		active = w
	return w


## [F]: çağırdığın heykelin kafasına bin / in. Heykel yoksa ya da uzaktaysa false (F başka işe gider).
static func ride_toggle(pl) -> bool:
	if pl == null:
		return false
	var w := active
	if w == null or not is_instance_valid(w) or not is_instance_valid(w.g) or w.g.has_meta("leaving"):
		return false
	if w.rider != null:
		w.dismount()
		return true
	if w.delay > 0.0 or w.owner_f != pl:
		return false
	var d: Vector3 = pl.global_position - w.g.global_position
	d.y = 0.0
	if d.length() > RIDE_REACH:
		return false
	w.mount(pl)
	return true


## Binicinin tuşları (PlayerCombat yönlendirir)
static func ride_input(e: InputEvent) -> void:
	var w := active
	if w == null or not is_instance_valid(w) or w.rider == null:
		return
	if e.is_action_pressed("attack"):
		w._want_act = "smash"
	elif e.is_action_pressed("throw"):
		w._want_act = "roar"
	else:
		var si: int = Keys.slot_pressed(e)
		if si >= 0 and si < 4:
			w._want_act = ["sweep", "stomp", "dragon", "chain"][si]


func mount(pl: Node3D) -> void:
	rider = pl
	pl.set_meta("gedo_ride", true)
	_cam0 = [pl.cam_dist, pl.cam_lift, pl.cam_range, pl.cam_giant, pl.cam.far, pl.collision_mask]
	pl.collision_mask = 0
	pl.cam_range = Vector2(4.0, 260.0)   # tekerlekle en yakına gelince kafadaki karakterinin arkasından
	pl.cam_dist = 105.0
	pl.cam_lift = 6.0
	pl.cam_giant = true
	pl.cam.far = maxf(pl.cam.far, 6000.0)
	Hud.banner("GEDŌ MAZŌ", "Heykel senin emrinde  •  W A S D: yürüt  •  Sol tık: ezme  •  Sağ tık: kükreme  •  1: el süpürme  •  2: ayak darbesi  •  3: ruh ejderleri  •  4: zincirler  •  F: in", Color(0.8, 0.7, 1.0))


func dismount() -> void:
	var pl := rider
	rider = null
	if pl == null or not is_instance_valid(pl):
		return
	pl.remove_meta("gedo_ride")
	if _cam0.size() >= 6:
		pl.collision_mask = _cam0[5]
	if _cam0.size() >= 5:
		pl.cam_dist = _cam0[0]
		pl.cam_lift = _cam0[1]
		pl.cam_range = _cam0[2]
		pl.cam_giant = _cam0[3]
		pl.cam.far = _cam0[4]
	if is_instance_valid(g):
		var fw := g.forward()
		pl.global_position = pj.gp(g.global_position + fw.cross(Vector3.UP) * 24.0 + fw * 8.0) + Vector3.UP * 0.3
	pl.velocity = Vector3.ZERO


func _exit_tree() -> void:
	if rider != null:
		dismount()
	if active == self:
		active = null


func _process(dt: float) -> void:
	if g == null or not is_instance_valid(g):
		return
	if g.has_meta("leaving"):
		if rider != null:
			dismount()
		g.gait = {}
		return
	if Game.paused:
		return
	if delay > 0.0:
		delay -= dt
		if delay <= 0.0:
			g.set_pose("walk", 1.2)
			g.open_mouth(0.15)
		return
	smash_cd -= dt
	roar_cd -= dt
	sweep_cd -= dt
	stomp_cd -= dt
	dragon_cd -= dt
	chain_cd -= dt
	var moving := false
	if act != "":
		_act_tick(dt)
	else:
		moving = _steer(dt)
	# yürüyüş: adım fazı yalnız ilerlerken döner; durunca uzuvlar yumuşakça poza iner
	amp = move_toward(amp, 1.0 if moving else 0.0, dt * 2.5)
	if moving:
		phase += SPEED * dt / STRIDE * PI
		var c0 := cos(phase)
		if (c0 < 0.0) != (_last_cos < 0.0):   # bacak en öne vardı: ayak yere iner
			_step(1.0 if sin(phase) > 0.0 else -1.0)
		_last_cos = c0
	var s := sin(phase) * amp
	var cs := cos(phase) * amp
	g.gait = {"lR": s * 0.5, "lL": -s * 0.5, "kR": -maxf(0.0, cs) * 0.6, "kL": -maxf(0.0, -cs) * 0.6,
		"aR": -s * 0.3, "aL": s * 0.3, "eR": -maxf(0.0, -s) * 0.25, "eL": -maxf(0.0, s) * 0.25,
		"hy": -absf(cs) * 0.1, "roll": s * 0.045}
	for k in _act_gait:   # teknik sırasında uzuv katmanı (süpüren kol, kalkan bacak)
		g.gait[k] = float(g.gait.get(k, 0.0)) + float(_act_gait[k])
	_ground_feet(dt)
	if rider != null:
		if not is_instance_valid(rider) or rider.is_dead():
			dismount()
		else:
			rider.global_position = g.head_top()
			if rider.model:
				rider.model.play("idle", 0.2)   # kafanın tepesinde ayakta durur (düşme / koşma animasyonu oynamasın)
			rider.velocity = Vector3.ZERO
			rider.facing = g.rotation.y   # heykelin baktığı yöne bakar (eskiden bindiği andaki yönünde kalıyor, ters duruyordu)
			rider.ride_cam_lift(6.0)
			rider.cam_giant = rider.cam_dist > 30.0
			rider.input_locked = maxf(rider.input_locked, 0.25)


## Yön ve hedef: binici varsa onun tuşları, yoksa en yakın düşman (yoksa çağıranın peşi). true = bu kare yürüdü
func _steer(dt: float) -> bool:
	var want := Vector3.ZERO
	var fw := g.forward()
	if rider != null:
		var v := Input.get_vector("left", "right", "back", "forward")
		if v.length() > 0.2:
			var yaw: float = rider.cam_pivot.global_rotation.y
			want = (Basis(Vector3.UP, yaw) * Vector3(v.x, 0, -v.y)).normalized()
		if _want_act != "":
			var left := _cd_of(_want_act)
			if left <= 0.0:
				_start(_want_act)
			else:
				Hud.msg(LazyFx.g("Lang").t("Heykel henüz toparlanmadı (%.1f sn)") % maxf(left, 0.1), Color(0.8, 0.7, 1.0), 1.2)
		_want_act = ""
		if act != "":
			return false
	else:
		if owner_f == null or not is_instance_valid(owner_f):
			return false
		var best: Node3D = null
		var bd := 1e9
		for f in pj.enemies_near(owner_f, g.global_position, 260.0):
			var dd: float = f.global_position.distance_to(g.global_position)
			if dd < bd:
				bd = dd
				best = f
		if best != null:
			var to: Vector3 = best.global_position - g.global_position
			to.y = 0.0
			var facing: bool = to.length() < 1.0 or fw.dot(to.normalized()) > 0.92
			if to.length() < 62.0 and facing and smash_cd <= 0.0:
				_start("smash")
				return false
			if to.length() < 30.0 and stomp_cd <= 0.0:   # dibindekini ayağıyla ezer
				_start("stomp")
				return false
			if to.length() < 58.0 and fw.dot(to.normalized()) > 0.1 and sweep_cd <= 0.0:   # yanındakini eliyle süpürür
				_start("sweep")
				return false
			if to.length() < 125.0 and fw.dot(to.normalized()) > 0.8 and roar_cd <= 0.0:
				_start("roar")
				return false
			if to.length() > 34.0 or not facing:
				want = to.normalized()
			if to.length() <= 34.0 and not facing:
				_turn(want, dt)   # dibindeki hedefe yerinde döner
				return false
		else:
			var to2: Vector3 = owner_f.global_position - g.global_position
			to2.y = 0.0
			if to2.length() > 90.0:
				want = to2.normalized()
	if want == Vector3.ZERO:
		return false
	_turn(want, dt)
	fw = g.forward()
	if fw.dot(want) < 0.5:
		return false   # önce döner
	g.global_position += fw * SPEED * dt   # yükseklik _ground_feet'te: ayak tabanları zemine oturtulur
	return true


## Heykeli ayak tabanlarından yere oturtur: en alçak taban noktası tam zeminde durur (eskiden gövde merkezinin altındaki
## zemine göre konuyordu: adım atarken ve eğimde ayak toprağın içinde kalıyordu)
func _ground_feet(dt: float) -> void:
	var low := 1e9
	for q in g.sole_points():
		low = minf(low, (q as Vector3).y - pj.gp(q).y)
	if low > 1e8:
		return
	low = clampf(low, -12.0, 12.0)
	# gömülmüşse hemen çıkar, havadaysa yumuşakça iner
	g.global_position.y -= low * (minf(1.0, dt * 14.0) if low < 0.0 else minf(1.0, dt * 6.0))


func _turn(want: Vector3, dt: float) -> void:
	var ty := atan2(-want.x, -want.z)
	var dy := wrapf(ty - g.rotation.y, -PI, PI)
	g.rotation.y += clampf(dy, -TURN * dt, TURN * dt)


## Ayak yere iner: toz halkası, sarsıntı, altındakini ezer
func _step(side: float) -> void:
	var fp: Vector3 = pj.gp(g.foot_pos(side))
	var host = fxb._host(pj)
	for k in 7:
		var ang := TAU * k / 7.0 + randf() * 0.4
		var dv := Vector3(cos(ang), 0, sin(ang))
		fxb._billow(host, fp + dv * 5.0 + Vector3.UP * 1.0, randf_range(4.5, 7.0), 1.3, dv * 6.0 + Vector3.UP * 1.2)
	fxb._chunks(host, fp + Vector3.UP * 0.8, fp.y, 6, 9.0, 0.7, fxb.EARTH, 1.2)
	LazyFx.g("GiantSteps").stomp(fp, 100.0, g.rotation.y, "foot", side > 0.0, owner_f)   # yer titrer, güm sesi, ayak biçimli çukur, altındaki yapı yıkılır
	if pj.live(owner_f):
		pj.hit(owner_f, fp + Vector3.UP * 1.5, 11.0, pj.inf(owner_f, JID, 0.5, {"knock": 12.0, "launch": 4.0, "kind": "heavy"}))


func _cd_of(kind: String) -> float:
	match kind:
		"smash": return smash_cd
		"roar": return roar_cd
		"sweep": return sweep_cd
		"stomp": return stomp_cd
		"dragon": return dragon_cd
		"chain": return chain_cd
	return 0.0


func _start(kind: String) -> void:
	act = kind
	act_t = 0.0
	act_step = 0
	_roar_hit = []
	_act_gait = {}
	if kind == "sweep":
		sweep_cd = SWEEP_CD
		g.set_pose("sweep", 0.5)
		g.open_mouth(0.4)
	elif kind == "stomp":
		stomp_cd = STOMP_CD
		g.open_mouth(0.4)
	elif kind == "dragon":
		dragon_cd = DRAGON_CD
		g.set_pose("roar", 0.5)
		g.open_mouth(1.0)
	elif kind == "chain":
		chain_cd = CHAIN_CD
		g.set_pose("roar", 0.5)
	elif kind == "smash":
		smash_cd = SMASH_CD
		g.set_pose("rear", 0.6)
		g.open_mouth(0.5)
	else:
		roar_cd = ROAR_CD
		g.set_pose("roar", 0.5)
		g.open_mouth(0.3)


func _act_tick(dt: float) -> void:
	act_t += dt
	var host = fxb._host(pj)
	var fw := g.forward()
	if act == "sweep":
		# tek el süpürme: sağ kol yana açılıp geri çekilir (0.6 sn), sonra yere sürtünerek karşıya savrulur (0.4 sn)
		var k0 := clampf(act_t / 0.6, 0.0, 1.0)
		var k1 := clampf((act_t - 0.6) / 0.4, 0.0, 1.0)
		k1 = k1 * k1 * (3.0 - 2.0 * k1)
		var back := clampf((act_t - 1.5) / 0.7, 0.0, 1.0)
		var sw := lerpf(k0 * 1.0, -0.75, k1) * (1.0 - back)
		_act_gait = {"aR": (0.75 + 0.2 * k1) * (1.0 - back), "zR": sw * 1.1, "eR": 0.3 * k0 * (1.0 - back), "twist": -sw * 0.55, "aL": -0.5 * k0 * (1.0 - back)}
		if act_step == 0 and act_t >= 0.6:
			act_step = 1
			g.open_mouth(1.0)
			Sfx.play("earth", g.global_position + fw * 30.0, 0.5, 0.8)
		if act_step == 1 and act_t < 1.0 and int(act_t * 30.0) % 2 == 0:   # elin geçtiği yay boyunca toprak kalkar
			var ang := lerpf(-1.25, 1.25, k1)
			var dv := (Basis(Vector3.UP, ang) * fw).normalized()
			var q: Vector3 = pj.gp(g.global_position + dv * 44.0)
			fxb._billow(host, q + Vector3.UP * 1.5, randf_range(6.0, 9.0), 1.3, dv * 8.0 + Vector3.UP * 3.0)
			fxb._chunks(host, q + Vector3.UP * 1.0, q.y, 5, 18.0, 1.0, fxb.EARTH, 1.5)
			pj.shake(0.7)
		if act_step == 1 and act_t >= 0.85:
			act_step = 2
			if pj.live(owner_f):
				var side := fw.cross(Vector3.UP).normalized()
				for f in pj.enemies_near(owner_f, g.global_position + fw * 20.0, 52.0):
					var to: Vector3 = f.global_position - g.global_position
					to.y = 0.0
					if to.length() > 3.0 and fw.dot(to.normalized()) < -0.05:
						continue
					f.take_hit(pj.inf(owner_f, JID, 1.3, {"knock": 38.0, "launch": 6.0, "kind": "heavy", "dir": (-side + fw * 0.3).normalized(), "attacker": owner_f}))
		elif act_step == 2 and act_t >= 1.5:
			act_step = 3
			g.set_pose("walk", 0.8)
			g.open_mouth(0.15)
		elif act_t >= 2.3:
			_act_gait = {}
			act = ""
	elif act == "stomp":
		# ayak darbesi: sağ bacak dizden kalkar (0.7 sn), yere çakılır; darbe halkası çevredekileri sersemletir, yarıklar açılır
		var up := clampf(act_t / 0.7, 0.0, 1.0)
		var dn := clampf((act_t - 0.7) / 0.18, 0.0, 1.0)
		var lift := up * (1.0 - dn)
		_act_gait = {"lR": lift * 1.0, "kR": -lift * 1.2, "roll": -lift * 0.08, "aL": lift * 0.4, "aR": lift * 0.4}
		if act_step == 0 and act_t >= 0.9:
			act_step = 1
			_act_gait = {}
			var fp: Vector3 = pj.gp(g.foot_pos(1.0))
			g.shake = 0.8
			pj.shake(2.2)
			Sfx.play("earth", fp, 0.7, 0.5)
			for k in 5:   # ayaktan ışınsal yarıklar
				var ang2 := TAU * k / 5.0 + randf_range(-0.3, 0.3)
				var dv2 := Vector3(cos(ang2), 0, sin(ang2))
				fxb._fissure(host, pj.gp(fp + dv2 * 20.0), 16.0, 5.0)
			for k in 20:
				var ang3 := TAU * k / 20.0
				var dv3 := Vector3(cos(ang3), 0, sin(ang3))
				fxb._billow(host, fp + dv3 * 8.0 + Vector3.UP * 1.2, randf_range(6.0, 9.0), 1.6, dv3 * 16.0 + Vector3.UP * 1.5)
			fxb._chunks(host, fp + Vector3.UP * 1.0, fp.y, 22, 20.0, 1.3, fxb.EARTH, 2.0)
			if pj.live(owner_f):
				for f in pj.enemies_near(owner_f, fp, 42.0):
					var to3: Vector3 = f.global_position - fp
					to3.y = 0.0
					f.take_hit(pj.inf(owner_f, JID, 1.0 if to3.length() > 14.0 else 1.9, {"knock": 20.0, "launch": 11.0, "kind": "heavy", "dir": (to3.normalized() if to3.length() > 0.1 else fw), "attacker": owner_f}))
					pj.st(f, "stun", 1.2)
		elif act_t >= 1.7:
			act = ""
	elif act == "dragon":
		# ruh ejderleri (kanon: heykelin ağzından çıkan ejderler dokunduğunun yaşam gücünü söker): en yakın üç düşmana birer ejder
		if act_step == 0 and act_t >= 0.5:
			act_step = 1
			g.shake = 0.5
			Sfx.play("roar", g.mouth_pos(), 0.4, 0.8)
			if pj.live(owner_f):
				var foes: Array = pj.enemies_near(owner_f, g.global_position, 150.0)
				foes.sort_custom(func(x, y): return x.global_position.distance_to(g.global_position) < y.global_position.distance_to(g.global_position))
				for k in mini(3, foes.size()):
					fxb._gm_dragon(pj, owner_f, g, foes[k])
				if foes.is_empty() and rider != null:
					Hud.msg(LazyFx.g("Lang").t("Ejderlerin sökeceği bir ruh yok."), Color(0.8, 0.7, 1.0), 1.5)
					dragon_cd = 1.0
		elif act_t >= 1.6:
			g.set_pose("walk", 0.8)
			g.open_mouth(0.15)
			act = ""
	elif act == "chain":
		if act_step == 0 and act_t >= 0.4:
			act_step = 1
			if pj.live(owner_f):
				LazyFx.g("DojutsuFXA").mazo_no_kusari(pj, owner_f, null)
		elif act_t >= 1.5:
			g.set_pose("walk", 0.8)
			g.open_mouth(0.15)
			act = ""
	elif act == "smash":
		if act_step == 0 and act_t >= 0.7:   # iki el birden iner
			act_step = 1
			g.set_pose("crouch", 0.3)
			g.open_mouth(1.0)
		elif act_step == 1 and act_t >= 1.0:
			act_step = 2
			var front: Vector3 = pj.gp(g.global_position + fw * 34.0)
			g.shake = 0.5
			pj.shake(1.8)
			fxb._fissure(host, front, 22.0, 7.0)
			for k in 16:
				var ang := TAU * k / 16.0
				var dv := Vector3(cos(ang), 0, sin(ang))
				fxb._billow(host, front + dv * 6.0 + Vector3.UP * 1.0, randf_range(5.0, 7.5), 1.4, dv * 9.0 + Vector3.UP * 1.5)
			fxb._chunks(host, front + Vector3.UP * 1.0, front.y, 18, 16.0, 1.1, fxb.EARTH, 1.8)
			Sfx.play("earth", front, 0.6, 0.6)
			if pj.live(owner_f):
				pj.hit(owner_f, front + Vector3.UP * 2.0, 26.0, pj.inf(owner_f, JID, 1.6, {"knock": 26.0, "launch": 8.0, "kind": "heavy"}))
		elif act_step == 2 and act_t >= 1.7:
			act_step = 3
			g.set_pose("walk", 0.8)
			g.open_mouth(0.15)
		elif act_t >= 2.5:
			act = ""
	else:   # kükreme: ağızdan çıkan basınç önündeki her şeyi savurur; dalga yerde toz kaldırarak ilerler
		if act_step == 0 and act_t >= 0.5:
			act_step = 1
			g.open_mouth(1.0)
			g.shake = 1.2
			pj.shake(1.4)
			Sfx.play("roar", g.mouth_pos(), 0.5, 0.55)
		if act_step == 1:
			var r := (act_t - 0.5) * 95.0
			if r <= 125.0:
				var base: Vector3 = g.global_position + fw * 12.0
				for k in 4:   # dalga cephesi: yay boyunca toz
					var a2 := randf_range(-0.7, 0.7)
					var dv2 := (Basis(Vector3.UP, a2) * fw).normalized()
					var q: Vector3 = pj.gp(base + dv2 * r)
					fxb._billow(host, q + Vector3.UP * 1.2, randf_range(5.0, 8.0), 1.1, dv2 * 22.0 + Vector3.UP * 2.0, Color(0.78, 0.74, 0.7))
				if int(act_t * 20.0) % 3 == 0:
					var dv3 := (Basis(Vector3.UP, randf_range(-0.6, 0.6)) * fw).normalized()
					var q3: Vector3 = pj.gp(base + dv3 * r)
					fxb._chunks(host, q3 + Vector3.UP * 0.8, q3.y, 3, 14.0, 0.6, fxb.EARTH, 1.0)
				if pj.live(owner_f):
					for f in pj.enemies_near(owner_f, base, r):
						if f in _roar_hit:
							continue
						var to: Vector3 = f.global_position - base
						to.y = 0.0
						if to.length() > 2.0 and fw.dot(to.normalized()) < 0.72:
							continue
						_roar_hit.append(f)
						f.take_hit(pj.inf(owner_f, JID, 0.7, {"knock": 34.0, "launch": 7.0, "kind": "heavy", "dir": (to.normalized() if to.length() > 0.1 else fw), "attacker": owner_f}))
						pj.st(f, "stun", 0.8)
			else:
				act_step = 2
				g.set_pose("walk", 0.8)
				g.open_mouth(0.15)
		elif act_step == 2 and act_t >= 2.7:
			act = ""
