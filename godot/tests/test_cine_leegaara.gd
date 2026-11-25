extends "res://tests/shorts_kit.gd"
## Sinematik: Rock Lee vs Gaara (Chūnin ön eleme salonu, kanon sahneleri). Yatay 1920x1080, --write-movie.
## Kaynak: anime bölümü (_tmp/leegaara/sheet_*.jpg): karşılaşma → kum kalkanı tekmeyi durdurur → kum Lee'yi kovalar →
## ağırlıklar düşer → hız baskını, kum zırhı çatlar → Omote Renge → kapılar → Ura Renge → Sabaku Kyū → Lee bilinçsiz ayağa kalkar.
## SCENES=open,face,... ile tek sahne yeniden çekilir. Yazılar / letterbox kurguda (tools/shorts_make.py).

const SB = preload("res://scripts/combat/style_sabaku_anim.gd")
const OMORI = preload("res://scripts/combat/omori.gd")

var gaara: Enemy
var hold_g := true      # Gaara yerinde durur, kollar kavuşuk (kum dövüşür)
var guard_g := false    # kum kalkanı: Lee'nin vuruşları Gaara'ya geçmez
var O := Vector3.ZERO   # salon kökü (gökte)
const LEE_D := 7.0
const GAARA_D := 17.0


func landscape() -> bool:
	return true


func scenes() -> Array:
	return ["open", "face", "shield", "chase", "weights", "blitz", "omote", "gates", "ura", "kyu", "stand", "balcony", "omote2", "ura2"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 60
	pr["clan"] = "none"
	pl.apply_profile_stats()
	var L: Dictionary = pr["look"]
	L["hair_style"] = "s9"
	L["hair"] = Color(0.04, 0.04, 0.05)
	L["eye"] = Color(0.05, 0.05, 0.05)
	L["skin"] = Color(0.95, 0.78, 0.63)
	if pr.has("equip"):
		pr["equip"].erase("kafa")
	Gear.grant(pr, "set_goken", "set")
	if not pr.has("paths") or not (pr["paths"] is Dictionary):
		pr["paths"] = {}
	pr["paths"]["kapi"] = {"s": 4, "q": ""}
	pr["fight_style"] = "kapi"
	Game.profile["omori_off"] = false
	Game.settings["blood"] = false   # kan lekesi yok (sinematik, kanlı değil)
	for s in ["sag_goz", "sol_goz"]:
		if pr.has("equip"):
			pr["equip"].erase(s)
	Gear.apply_look(pr)
	pl.rebuild_model()


func H(x: float, y: float, d: float) -> Vector3:
	return O + Vector3(x, y, -d)


func _process(dt: float) -> void:
	super._process(dt)
	if gaara and is_instance_valid(gaara):
		if guard_g:
			gaara.sub_inv = 0.5
		if hold_g:
			gaara.target = null
			gaara.think_t = 0.5
			if String(gaara.state) in ["idle", "chase", "recover", "attack", "guard", "leap", "charge"]:
				gaara.state = "idle"
				gaara.state_t = 0.0
				gaara.wander_to = gaara.global_position
				gaara.velocity = Vector3.ZERO
			var v = pl.global_position - gaara.global_position
			v.y = 0
			if v.length() > 0.3:
				gaara.facing = atan2(-v.x, -v.z)


# ------------------------------------------------------------------ kurulum
func _gaara_look() -> Dictionary:
	var L = CharacterModel.default_look()
	L.merge({"gender": "m", "age": "adult", "hair_style": "s3", "hair": Color(0.62, 0.12, 0.08), "skin": Color(0.98, 0.86, 0.76),
		"eye": Color(0.45, 0.75, 0.62), "face_paint": "fp12", "band": null, "village": "suna"}, true)
	var W = Outfits.wear_set(L, "ss_kum_cocuk")
	W["back_item"] = "kabak"
	W["backc"] = Color(0.78, 0.6, 0.42)
	W["hair_style"] = "s3"
	W["hair"] = Color(0.62, 0.12, 0.08)
	W["keep_hair"] = true
	W["npc"] = true
	return W


func _hall() -> void:
	if Interiors.inst == null:
		print("SHOTCHK hall YOK")
		return
	if Interiors.inst.inside != "chunin_hall":
		var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
		field.y = Game.ground_height(field.x, field.z)
		await _goto(field, 2.0)
		Interiors.inst.enter({"pos": field, "out": field, "room": "chunin_hall", "kind": "enter"})
		await _w(4.5)
		_closeui()
	O = Interiors.inst.origin
	if gaara == null or not is_instance_valid(gaara):
		var a = Enemy.archetype("suna", 0)
		a["look"] = _gaara_look()
		a.merge({"clan": "sabaku", "no_world": true, "jutsu": [], "respawn": false, "name": "Gaara", "level": 40, "skill": 0.1, "guard": 0.0, "sub": 0.0, "tools": false}, true)
		gaara = Enemy.new()
		gaara.setup(a)
		get_tree().current_scene.add_child(gaara)
		gaara.global_position = H(0, 0.05, GAARA_D)
		gaara.home = gaara.global_position
		foes.append(gaara)
		await _w(1.0)
	gaara.max_hp = 1e7
	gaara.hp = 1e7
	gaara.dodge_cd = 999.0
	if gaara.hp_bar:
		gaara.hp_bar.layers = 0
	gaara.skill = 0.1


func _place(lee_d := LEE_D, gaara_d := GAARA_D) -> void:
	await _hall()
	_god()
	hold_g = true
	guard_g = false
	gaara.set_physics_process(true)
	gaara.global_position = H(0, 0.05, gaara_d)
	gaara.velocity = Vector3.ZERO
	gaara.home = gaara.global_position
	pl.global_position = H(0, 0.1, lee_d)
	pl.velocity = Vector3.ZERO
	pl.yaw = 0.0   # -z (heykele, Gaara'ya) bakar
	pl.combat.lock_target = gaara
	pl.combat.face_to(gaara)
	await _w(0.3)
	_fold()


## Gaara'nın kavuşuk kolları (Sabaku tarzının duruşu)
func _fold() -> void:
	if not is_instance_valid(gaara) or gaara.model == null or gaara.model.overlay == null:
		return
	var k0 = SB._t(0.0, 0.04, 0, 0, SB.R_FOLD, SB.L_FOLD, {})
	var k1 = k0.duplicate()
	k1["t"] = 999.0
	gaara.model.overlay.play_keys({"len": 999.0, "hit": 999.0, "two": false, "keys": [k0, k1]}, 1.0)


func _gaara_step(i: int) -> void:
	if is_instance_valid(gaara) and gaara.model and gaara.model.overlay:
		gaara.model.overlay.play_keys(SB.steps()[i], 1.0)


func _gcast(id: String, tgt: Node3D) -> void:
	print("CASTCHK %s gaara" % id)
	Jutsu.execute(gaara, id, tgt)


func _gp() -> Vector3:
	return gaara.global_position if is_instance_valid(gaara) else H(0, 0, GAARA_D)


## Kum kalkanı (kanon: Gaara'nın kendiliğinden kalkan kumu) — Sabaku efektinin kendi kum malzemesiyle, çekim için
func _sand_shield(dur: float) -> Node3D:
	var g = _gp()
	var to_l = pl.global_position - g
	to_l.y = 0
	to_l = to_l.normalized()
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = g + to_l * 1.05
	root.look_at(root.global_position + to_l, Vector3.UP)
	var n := 0
	for row in 3:
		for col in 5:
			var u = (col - 2) / 2.0
			var ball = SabakuFXA.sand(SabakuFXA._ball(0.3, 300 + n), {"near0": 0.3, "near1": 0.9}, true)
			root.add_child(ball)
			ball.position = Vector3(u * 0.62, 0.35 + row * 0.62 - absf(u) * 0.12 * row, u * u * 0.45)
			ball.scale = Vector3(0.42, 0.4, 0.26) * (1.0 - row * 0.12)
			n += 1
	root.scale = Vector3(1, 0.05, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SabakuFXA.grains(root, root.global_position + Vector3.UP * 0.2, {"ring": 1.0, "n": 70, "life": 0.7, "dir": Vector3.UP, "spread": 25.0, "v0": 2.5, "v1": 5.5, "g": Vector3(0, -6.0, 0)})
	SabakuFXA.grains(root, Vector3.UP * 1.4, {"parent": root, "stream": true, "dur": dur, "box": Vector3(1.3, 0.2, 0.2), "n": 50, "life": 0.9,
		"dir": Vector3.DOWN, "spread": 10.0, "v0": 0.2, "v1": 1.0, "g": Vector3(0, -8.0, 0), "s0": 0.03, "s1": 0.06})
	SabakuFXA.crumble(root, root, dur, 0.45)
	get_tree().create_timer(dur + 0.6).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())
	Sfx.play("earth", root.global_position, 1.2)
	return root


## Lee'nin geri takla kaçışı (oyuncunun kaçış hareketiyle aynı alanlar)
func _lee_flip(d: Vector3, spd := 13.0) -> void:
	d.y = 0
	d = d.normalized()
	pl.velocity = d * spd + Vector3.UP * 6.0
	pl.dash_t = 0.3
	pl.evade_t = 0.46
	pl.flip_axis = Vector3.UP.cross(d).normalized()
	var fwd = Basis(Vector3.UP, pl.facing) * Vector3.FORWARD
	pl.flip_sgn = 1.0 if fwd.cross(d).y < 0.0 else -1.0
	pl.flip_kind = "tuck"
	pl.flip_t = 0.001
	pl.model.play("air", 0.05)
	pl.model.overlay.set_pose("leap", 0.0)
	FX.speed_lines(pl.global_position + Vector3.UP, d)
	Sfx.play("whoosh", pl.global_position, 1.45, 0.6)


func _slowmo(k: float, real_dur: float) -> void:
	Engine.time_scale = k
	await get_tree().create_timer(real_dur * k).timeout
	Engine.time_scale = 1.0


## Takip kamerası: iki dövüşçünün ortası
func _mid() -> Vector3:
	return (pl.global_position + _gp()) * 0.5 + Vector3.UP * 1.1


func _watch2(cut: String, dur: float) -> void:
	_watch(cut, func(): return _gp() + Vector3.UP if is_instance_valid(gaara) else null, dur)
	_watch(cut + "_lee", func(): return pl.global_position + Vector3.UP, dur)


# ------------------------------------------------------------------ 1) açılış: salon, heykel, iki rakip
func s_open() -> void:
	await _place()
	await _w(1.0)
	var hc = H(0, 9.0, 30.0)
	_cut("open", "a")
	_watch2("open", 5.5)
	await _move(H(7, 11.0, 2.5), H(-2.0, 1.9, 3.2), hc, H(0, 1.3, GAARA_D), 5.5)
	_cut("open", "b")


# ------------------------------------------------------------------ 2) yüz yüze
func s_face() -> void:
	await _place()
	await _w(0.6)
	var g = _gp()
	_cut("face_g", "a")
	_watch("face_g", func(): return _gp() + Vector3.UP * 1.5, 2.6)
	cam.fov = 34.0
	await _move(g + Vector3(1.2, 1.35, 3.6), g + Vector3(0.7, 1.45, 2.6), g + Vector3(0, 1.4, 0), g + Vector3(0, 1.45, 0), 2.6)
	cam.fov = 52.0
	_cut("face_g", "b")
	var p = pl.global_position
	_cut("face_l", "a")
	_watch("face_l", func(): return pl.global_position + Vector3.UP * 1.5, 2.6)
	await _move(p + Vector3(-0.9, 0.5, -2.6), p + Vector3(-0.45, 0.7, -1.75), p + Vector3(0, 1.45, 0), p + Vector3(0, 1.55, 0), 2.6)
	_cut("face_l", "b")


# ------------------------------------------------------------------ 3) tekme kuma çarpar (kum kalkanı)
func s_shield() -> void:
	await _place(GAARA_D - 9.0)
	guard_g = true
	var g = _gp()
	var sd = Vector3.RIGHT
	_cut("shield", "a")
	_watch2("shield", 3.6)
	var cam_t := 0.0
	# Lee atılır; kalkan son anda yerden yükselir
	pl._ninja_dash()
	var sh_made := false
	var t := 0.0
	while t < 3.6:
		_god()
		var d = g - pl.global_position
		d.y = 0
		if not sh_made and d.length() < 4.5:
			sh_made = true
			_sand_shield(2.4)
		if d.length() < 2.3:
			pl.combat.face_to(gaara)
			pl.combat.attack()
		var m = _mid()
		cam.fov = 44.0
		cam.global_position = m + sd * 4.6 + Vector3.UP * 0.1 + Vector3(0, 0, -0.6 - t * 0.3)
		cam.look_at(m + Vector3.DOWN * 0.2)
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("shield", "b")
	cam.fov = 52.0
	guard_g = false


# ------------------------------------------------------------------ 4) kum Lee'yi kovalar, Lee taklayla kaçar
func s_chase() -> void:
	await _place(GAARA_D - 9.0)
	var g = _gp()
	_cut("chase", "a")
	_watch2("chase", 3.6)
	_gcast("suna_shuriken", pl)
	var t := 0.0
	var flipped := false
	while t < 3.6:
		_god()
		if not flipped and t > 1.05:
			flipped = true
			_lee_flip(Vector3(1.0, 0, 0.6))
		var l = pl.global_position
		cam.global_position = g + Vector3(-1.3, 2.0, -2.6) + Vector3(0, 0, t * 0.2)
		cam.look_at(l.lerp(g, 0.3) + Vector3.UP * 0.9)
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("chase", "b")
	_fold()


# ------------------------------------------------------------------ 5) ağırlıklar
func s_weights() -> void:
	Game.profile["omori_off"] = false
	await _place(LEE_D)
	OMORI.wear(pl)
	await _w(0.6)
	var p = pl.global_position
	_cut("weights", "a")
	_watch("weights", func(): return pl.global_position + Vector3.UP * 0.4, 1.6)
	OMORI.release(pl)
	await _move(Vector3(1.4, 0.5, -1.6), Vector3(1.0, 0.35, -1.2), Vector3(0, 0.6, 0), Vector3(0, 0.25, 0), 1.6, pl)
	_cut("weights", "b")
	_cut("weights2", "a")
	_watch("weights2", func(): return p + Vector3.UP * 0.3, 2.2)
	await _move(p + Vector3(-3.2, 1.0, -1.6), p + Vector3(-2.6, 1.5, -2.4), p + Vector3(0, 0.3, 0), p + Vector3(0, 1.0, 0), 2.2)
	_cut("weights2", "b")


# ------------------------------------------------------------------ 6) hız baskını: kum zırhı, tekme yüze
func s_blitz() -> void:
	await _place(GAARA_D - 10.0)
	var g = _gp()
	_cut("blitz", "a")
	_watch2("blitz", 4.0)
	pl._ninja_dash()
	var t := 0.0
	var slow := false
	while t < 4.0:
		_god()
		var d = _gp() - pl.global_position
		d.y = 0
		if d.length() < 2.4:
			pl.combat.face_to(gaara)
			pl.combat.attack()
			if not slow:
				slow = true
				_slowmo(0.35, 0.9)
		var m = _mid()
		var k = clampf(t / 4.0, 0.0, 1.0)
		cam.global_position = m + Vector3(-3.6 + k * 1.0, -0.1 + k * 0.3, -1.2 - k * 1.2)
		cam.look_at(m)
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	_cut("blitz", "b")


# ------------------------------------------------------------------ 7) Omote Renge
func s_omote() -> void:
	await _place(GAARA_D - 5.5)
	hold_g = false
	gaara.state = "idle"
	var g = _gp()
	_cut("omote", "a")
	_watch2("omote", 5.0)
	_cast("omote_renge", gaara)
	var t := 0.0
	while t < 5.0:
		_god()
		var m = _mid()
		var hy = maxf(m.y, _gp().y + 1.0)
		cam.fov = lerpf(46.0, 30.0, clampf((m.y - O.y - 1.5) / 6.0, 0.0, 1.0))
		cam.global_position = H(4.5, 2.6 + t * 0.3, GAARA_D + 9.0)
		cam.look_at(Vector3(m.x, lerpf(m.y, hy, 0.5), m.z))
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("omote", "b")
	cam.fov = 52.0
	hold_g = true


# ------------------------------------------------------------------ 8) kapılar
func s_gates() -> void:
	await _place(LEE_D + 1.0)
	var p = pl.global_position
	_cut("gates", "a")
	_watch("gates", func(): return pl.global_position + Vector3.UP, 4.2)
	_cast("hachimon", null)
	var t := 0.0
	while t < 4.2:
		_god()
		var a = -PI * 0.42 + t / 4.2 * PI * 0.84
		var r = lerpf(3.4, 2.6, t / 4.2)
		cam.global_position = p + Vector3(sin(a) * r, 0.45 + t * 0.1, -cos(a) * r)
		cam.look_at(p + Vector3.UP * 1.25)
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("gates", "b")


# ------------------------------------------------------------------ 9) Ura Renge
func s_ura() -> void:
	await _place(GAARA_D - 5.5)
	_cast("hachimon", null)
	await _w(1.2)
	hold_g = false
	var g = _gp()
	_cut("ura", "a")
	_watch2("ura", 5.0)
	_cast("ura_renge", gaara)
	var t := 0.0
	while t < 5.0:
		_god()
		var m = _mid()
		cam.global_position = H(-6.5, 1.8 + t * 0.25, GAARA_D + 5.0)
		cam.look_at(Vector3(m.x, clampf(m.y + 0.8, O.y + 1.0, O.y + 6.0), m.z))
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("ura", "b")
	hold_g = true


# ------------------------------------------------------------------ 10) Sabaku Kyū (kesme: kum kapanır, el yumruğa)
func s_kyu() -> void:
	await _w(7.0)   # kapıların yeşil aurası sönsün (Ura Renge sonrası Lee tükenmiş)
	await _place(GAARA_D - 8.0)
	var p = pl.global_position
	var g = _gp()
	_cut("kyu", "a")
	_watch("kyu", func(): return pl.global_position + Vector3.UP, 2.6)
	_gaara_step(3)
	_gcast("sabaku_kyu", pl)
	await _move(p + Vector3(3.2, 0.9, -2.6), p + Vector3(2.2, 1.3, -1.8), p + Vector3(0, 0.9, 0), p + Vector3(0, 1.2, 0), 2.6)
	_cut("kyu", "b")
	_cut("kyu_hand", "a")
	_watch("kyu_hand", func(): return _gp() + Vector3.UP * 1.3, 1.8)
	_gaara_step(5)
	cam.fov = 36.0
	await _move(g + Vector3(-2.0, 1.2, 2.6), g + Vector3(-1.5, 1.3, 2.0), g + Vector3(0, 1.3, 0.3), g + Vector3(0, 1.35, 0.3), 1.8)
	cam.fov = 52.0
	_cut("kyu_hand", "b")
	_fold()
	# Lee yığılır: gerçek yere düşüş animasyonu (oyunun ölüm/yere seriliş klibi), canı tam — sahne için yalnız poz
	pl.set_physics_process(false)
	pl.velocity = Vector3.ZERO
	pl.model.play("death", 0.15)
	var lp = pl.global_position
	SabakuFXA.grains(pl, lp + Vector3.UP * 1.6, {"box": Vector3(0.5, 0.3, 0.9), "n": 120, "life": 1.6, "dir": Vector3.DOWN, "spread": 25.0,
		"v0": 0.2, "v1": 1.0, "g": Vector3(0, -4.0, 0), "s0": 0.03, "s1": 0.06})
	SabakuFXA.ground(pl, lp, 1.3, 0, 6.0, {"grow_t": 0.6})
	var gg = _gp()
	var side = Vector3.RIGHT
	_cut("down", "a")
	_watch("down", func(): return pl.global_position + Vector3.UP * 0.3, 6.0)
	# Gaara'nın yanından (heykel arkada kalır) yerdeki Lee'ye: Gaara önde, Lee orta planda, arkada giriş duvarı
	var c0 = gg + Vector3(1.3, 1.75, -2.4)
	var c1 = gg + Vector3(0.95, 1.6, -1.5)
	cam.fov = 34.0
	await _move(c0, c1, lp.lerp(gg, 0.3) + Vector3.UP * 0.5, lp + Vector3.UP * 0.25, 6.0)
	cam.fov = 52.0
	_cut("down", "b")
	pl.set_physics_process(true)


# ------------------------------------------------------------------ 11) Lee ayakta (bitiş)
func s_stand() -> void:
	await _place(GAARA_D - 8.0)
	await _w(0.5)
	var p = pl.global_position
	_cut("stand", "a")
	_watch2("stand", 5.5)
	await _move(p + Vector3(-1.0, 0.5, -4.2), p + Vector3(-0.5, 1.2, -2.4), p + Vector3(0, 1.3, 0), p + Vector3(0, 1.45, 0), 5.5)
	_cut("stand", "b")


# ------------------------------------------------------------------ uzun kurgu: balkondan bakış + yavaş çekim tekrarlar
func s_balcony() -> void:
	await _place(GAARA_D - 9.0)
	guard_g = true
	_cut("balcony", "a")
	_watch2("balcony", 4.0)
	pl._ninja_dash()
	var made := false
	var t := 0.0
	while t < 4.0:
		_god()
		var d = _gp() - pl.global_position
		d.y = 0
		if not made and d.length() < 4.5:
			made = true
			_sand_shield(2.6)
		if d.length() < 2.3:
			pl.combat.face_to(gaara)
			pl.combat.attack()
		var m = _mid()
		cam.fov = 26.0
		cam.global_position = H(-13.2, 7.9, 9.0 + t * 0.5)
		cam.look_at(m)
		await get_tree().process_frame
		t += get_process_delta_time()
	_cut("balcony", "b")
	cam.fov = 52.0
	guard_g = false


func s_omote2() -> void:
	await _place(GAARA_D - 5.5)
	hold_g = false
	var g = _gp()
	Engine.time_scale = 0.55
	_cut("omote2", "a")
	_watch2("omote2", 5.0 * 0.55)
	_cast("omote_renge", gaara)
	var t := 0.0
	while t < 5.0 * 0.55:
		_god()
		var m = _mid()
		cam.fov = lerpf(48.0, 32.0, clampf((m.y - O.y - 1.5) / 6.0, 0.0, 1.0))
		cam.global_position = H(-6.0, 1.2, GAARA_D + 6.0)
		cam.look_at(Vector3(m.x, m.y + 0.4, m.z))
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	_cut("omote2", "b")
	cam.fov = 52.0
	hold_g = true


func s_ura2() -> void:
	await _w(6.0)
	await _place(GAARA_D - 5.5)
	_cast("hachimon", null)
	await _w(1.2)
	hold_g = false
	var g = _gp()
	Engine.time_scale = 0.55
	_cut("ura2", "a")
	_watch2("ura2", 5.0 * 0.55)
	_cast("ura_renge", gaara)
	var t := 0.0
	while t < 5.0 * 0.55:
		_god()
		var m = _mid()
		cam.global_position = Vector3(g.x + 6.5, O.y + 0.6, g.z - 2.0)
		cam.look_at(Vector3(m.x, clampf(m.y + 0.6, O.y + 1.0, O.y + 7.0), m.z))
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	_cut("ura2", "b")
	hold_g = true
