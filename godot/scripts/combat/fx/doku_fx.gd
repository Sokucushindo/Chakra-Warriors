extends RefCounted
## Doku: oyunun GERÇEK zehir durumu ("poison") ve silaha sürülen zehir (hedef: res://scripts/combat/fx/doku_fx.gd).
## Oyunda zehir durumu yoktu: jutsuların verdiği "poison" değeri hiçbir yerde okunmuyordu, silahlar yanma durumunu ödünç alıyordu.
## Kanon (Narutopedia "Poison"): toz, sıvı ya da gaz; bedeni zayıflatır, felç eder, öldürür; Tsunade'ninki chakra denetimini bozar;
## kunaiye sürülür ve etkisi gecikebilir (Sakura, manga 485-487); Hanzō kusarigamasına, Raidō kılıcına sürer. Ref refs/doku/Poison.png: mor leke.
## Etki: süre biriktikçe ağırlaşır. 5 sn üstü yavaşlatır, 10 sn üstü chakrayı keser. Oyuncu ve düşman aynı yoldan geçer.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")

const MAX_DUR := 14.0
const DPS := 3.0
const DPS_HEAVY := 5.0
const WEAK_AT := 5.0
const SEAL_AT := 10.0
const COAT_HITS := 6       # sürülen zehir kaç kesik dayanır
const COAT_TIME := 30.0
const COAT_DOSE := 2.2
const CUT_STYLES := ["blade", "dual", "sword", "sickle", "claw", "heavy", "chain"]
const PURPLE := Color(0.42, 0.22, 0.46)

const FILM_SH := """shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix, shadows_disabled;
uniform float z0 = 0.1;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * 0.0028;
}
void fragment() {
	float run = 0.5 + 0.5 * sin(lp.z * 34.0 + TIME * 1.6 + sin(lp.y * 90.0) * 1.5);
	float m = smoothstep(z0, z0 + 0.05, lp.z) * smoothstep(0.22, 0.55, run);
	if (m < 0.04) discard;
	ALBEDO = mix(vec3(0.3, 0.13, 0.34), vec3(0.56, 0.32, 0.6), run);
	ALPHA = m * 0.9;
}
"""

const VEIN_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float e = 0.62 - 0.14 * k + 0.025 * sin(a * 9.0 + TIME * 0.7) + 0.018 * sin(a * 23.0 - TIME * 0.5);
	float pulse = 0.82 + 0.18 * sin(TIME * 3.4);
	ALBEDO = vec3(0.2, 0.07, 0.24);
	ALPHA = smoothstep(e, e + 0.3, r) * 0.62 * k * pulse;
}
"""


static func left(t: Node) -> float:
	var st = t.get("statuses")
	return float(st.get("poison", 0.0)) if st != null else 0.0


## Tek giriş noktası: tüm zehir kaynakları buradan
static func add(t: Node3D, d: float) -> void:
	if t == null or not is_instance_valid(t) or d <= 0.0 or not t.has_method("apply_status") or t.get("statuses") == null:
		return
	if t.has_method("is_dead") and t.is_dead():
		return
	if Game.now() < float(t.get_meta("doku_bagisik", 0.0)):
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Panzehir", Color(0.8, 0.9, 0.55))
		return
	t.apply_status("poison", minf(left(t) + d, MAX_DUR))
	_watch(t)


## Her kare (Fighter.tick_status / Player._tick_status)
static func tick(f: Node, dt: float) -> void:
	var l = left(f)
	var dps = DPS_HEAVY if l > WEAK_AT else DPS
	if f is Player:
		dps *= clampf(1.0 - Stats.skill(Game.profile, "poison_resist"), 0.2, 1.0)
	f.hp -= dps * dt
	var now = Game.now()
	if l > WEAK_AT and now >= float(f.get_meta("doku_nb", 0.0)):
		f.set_meta("doku_nb", now + 0.25)
		f.apply_status("slow", 0.4)
		if l > SEAL_AT:
			f.apply_status("sealed", 0.4)   # kanon: chakra denetimi bozulur


## Panzehir: durumu siler, kısa süre korur
static func cure(t: Node3D, protect: float) -> bool:
	if t == null or not is_instance_valid(t) or t.get("statuses") == null:
		return false
	var had = t.statuses.has("poison")
	t.statuses.erase("poison")
	if protect > 0.0:
		t.set_meta("doku_bagisik", Game.now() + protect)
	return had


static func _drop_mesh() -> Mesh:
	return Kit.cached_mesh("doku_damla", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.024, 0.04, 0.024), PURPLE, Vector3.ZERO, 6)
		return b.build(Props.toon()))


static func _drop(p: Vector3) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _drop_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_position = p
	var tw = mi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.global_position = p + Vector3.DOWN * 4.2 * v * v, 0.0, 0.46, 0.46)
	tw.tween_callback(mi.queue_free)


## Zehir sürdükçe damlalar; oyuncuda ekran kenarı morarır
static func _watch(t: Node3D) -> void:
	if t.has_meta("doku_izle"):
		return
	t.set_meta("doku_izle", true)
	var st = {"d": 0.0}
	var is_pl = t is Player and t == Game.player
	var fn = func(dt: float) -> bool:
		var ok = is_instance_valid(t) and not t.is_dead() and left(t) > 0.0
		if is_pl:
			var s = Kit.screen("doku", VEIN_SH)
			s.visible = ok
			if ok:
				(s.material_override as ShaderMaterial).set_shader_parameter("k", clampf(left(t) / SEAL_AT, 0.25, 1.0))
		if not ok:
			if is_instance_valid(t):
				t.remove_meta("doku_izle")
			return true
		st["d"] = float(st["d"]) - dt
		if float(st["d"]) <= 0.0:
			st["d"] = 0.34
			_drop(Kit.chest(t) + Vector3(randf_range(-0.17, 0.17), randf_range(-0.25, 0.2), randf_range(-0.17, 0.17)))
		return false
	Kit.ticker(t.global_position, fn)


# ------------------------------------------------------------------ silaha sürme
static func can_coat(who: Node3D) -> bool:
	var w: Dictionary = Gear.weapon_of(who)
	var m = who.get("model")
	return str(w.get("style", "fist")) in CUT_STYLES and not w.get("ranged", false) and m != null and not (m.weapons as Array).is_empty()


static func coated(who: Node3D) -> bool:
	return int(who.get_meta("doku_n", 0)) > 0 and Game.now() < float(who.get_meta("doku_son", 0.0))


## Vial modeli (elde): koyu şişe, mantar tıpa. Uç +Z
static func build_vial(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.036, 0.06, 0.036), Color(0.2, 0.12, 0.24), Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, 0.068), Vector3(0.016, 0.018, 0.016), Color(0.26, 0.17, 0.3), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.083), Vector3(0.013, 0.014, 0.013), Color(0.62, 0.48, 0.3), Vector3(90, 0, 0), 8)


static func _pour_pose(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null:
		return
	var W = S.LEG_WIDE
	var r = {"RightUpperArm": Vector3(-0.3, -0.75, 0.6), "RightLowerArm": Vector3(0.55, 0.2, 0.8)}
	var l0 = {"LeftUpperArm": Vector3(0.3, -0.85, 0.42), "LeftLowerArm": Vector3(0.0, -0.3, 0.95)}
	var l1 = {"LeftUpperArm": Vector3(0.2, -0.45, 0.87), "LeftLowerArm": Vector3(-0.72, 0.42, 0.55)}
	var fw = Vector3(0.6, 0.15, 0.78).normalized()
	m.overlay.play_keys({"len": 0.6, "hit": 0.3, "keys": [
		S._k(0.0, 0.36, 0.0, 2.0, fw, S._a(r, l0), W),
		S._k(0.2, 0.4, 8.0, 8.0, fw, S._a(r, l1), W),
		S._k(0.46, 0.4, 8.0, 8.0, fw, S._a(r, l1), W),
		S._k(0.6, 0.36, 0.0, 2.0, fw, S._a(r, l0), W),
	]}, 1.0)
	if m.has_method("hold_temp"):
		m.hold_temp("doku_sise", 0.55, "Left", 1.0, 0.0, false, true)
	who.get_tree().create_timer(0.56).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())


static func coat(who: Node3D) -> void:
	who.set_meta("doku_n", COAT_HITS)
	who.set_meta("doku_son", Game.now() + COAT_TIME)
	_pour_pose(who)
	Sfx.play("water", who.global_position + Vector3.UP, 1.7, 0.3)
	var n: Node3D = who.model.weapons[0]["node"]
	var kp: Array = CharacterModel.weapon_kp(String(who.model.weapons[0]["id"]), n)
	var z0 = float(kp[1])
	var z1 = float(kp[2])
	var film: MeshInstance3D = null
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and n.get_node_or_null("DokuFilm") == null:
		film = MeshInstance3D.new()
		film.name = "DokuFilm"
		film.mesh = (n as MeshInstance3D).mesh
		var mat = Kit.shader_mat("doku_film", FILM_SH).duplicate() as ShaderMaterial
		mat.set_shader_parameter("z0", z0)
		film.material_override = mat
		film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(film)
	var st = {"d": 0.3}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or not is_instance_valid(n) or not coated(who):
			if is_instance_valid(film):
				film.queue_free()
			return true
		st["d"] = float(st["d"]) - dt
		if float(st["d"]) <= 0.0 and n.is_visible_in_tree():
			st["d"] = randf_range(0.28, 0.55)
			_drop(n.to_global(Vector3(0, 0, randf_range(z0, z1))))
		return false
	Kit.ticker(who.global_position, fn)


## Combat.hit_sphere içinden: yakın dövüş kesiği hedefe zehir taşır. Blok tutan kesilmez.
static func on_melee(a: Node3D, f: Node3D) -> void:
	if not coated(a):
		a.remove_meta("doku_n")
		return
	if f.get("guarding") == true:
		return
	add(f, COAT_DOSE)
	var left_n = int(a.get_meta("doku_n", 0)) - 1
	if left_n <= 0:
		a.remove_meta("doku_n")
	else:
		a.set_meta("doku_n", left_n)


## Düşman aleti (Projectile.tool -> ALET_FX). Mermi yok.
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	if can_coat(who) and not coated(who):
		coat(who)
	return null


## Oyuncunun alet tuşu
static func player_use(p: Node3D) -> void:
	var c = p.combat
	if c.action != "" and c.action != "guard":
		return
	var nm = str(Data.items.get("doku", {"name": "Doku"})["name"])
	if not c.tool_owned("doku"):
		Hud.msg("%s sende yok — pazardan bir kez al, sonra sınırsız." % nm, Color(1, 0.6, 0.5))
		return
	if float(c.tool_cd.get("doku", 0.0)) > 0.0:
		Hud.msg("%s hazır değil: %d sn" % [nm, ceili(float(c.tool_cd["doku"]))], Color(1, 0.75, 0.5))
		return
	c._quick_draw()
	if not can_coat(p):
		Hud.msg("Zehir yalnız kesici yakın dövüş silahına sürülür.", Color(1, 0.75, 0.5))
		return
	c.tool_cd["doku"] = PlayerCombat.TOOL_CD / (1.0 + Mastery.get_v(Game.profile, "shurikenjutsu") / 50.0)
	c.action = "throw"
	c.t = -0.2   # "throw" eylemi 0.35'te biter: sürme pozu 0.55 sn sürer
	coat(p)
