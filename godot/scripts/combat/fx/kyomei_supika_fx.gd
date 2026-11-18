extends RefCounted
## Kyōmei Supīkā: kolçak modeli, ses dalgaları, titreşim birikimi (hedef: res://scripts/combat/fx/kyomei_supika_fx.gd).
## Kanon (Narutopedia "Resonating Echo Speaker", "Resonating Echo Drill", manga 40, 51-53, 87; Dosu Kinuta): sağ ön kolda delikli metal
## kolçak; kolun hareketinin sesini büyütür ya da emer. Chakra sesi yönlendirir. Ses engellenemez, iç kulağı vurur: denge gider, görüş
## bozulur, kusma. Kolçağa vurmak sesi büyütür. Kunai ve shuriken'i karşılar, çarpma titreşimi tekniğe katılır. Temasla engel parçalar.
## Vücuttaki su sesi iletir (Chōji'yi böyle yendi): ıslak hedefte daha güçlü. Oyunda Kyōmeisen jutsusu ayrı kalır.
## Ref refs/kyomei_supika: açık mor-gri kalın kabuk, yedi delik, çatlaklar, bilek bileziği, üstte iki küçük tutturma, elde bej plaka.
## Silah uzayı (ön kol çerçevesi): +Z bileğe, +X kolun dış yüzü.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const MAX_SES := 6
const SES_LIFE := 7.0
const CHAKRA := 0.06      # bitirişte sesi yönlendirme bedeli
const SHELL := Color(0.72, 0.68, 0.76)
const SHELL_D := Color(0.5, 0.46, 0.54)
const HOLE := Color(0.03, 0.03, 0.04)
const CRACK := Color(0.2, 0.18, 0.23)
const PLATE := Color(0.74, 0.7, 0.54)
const WAVE := Color(0.82, 0.76, 1.0)

## [z, açı (radyan)]: refteki delik dizilimi
const HOLES := [[-0.115, 0.55], [-0.095, -0.25], [-0.03, 0.42], [-0.035, -0.12], [0.02, -0.55], [-0.125, -0.95], [-0.05, -1.0]]

const WAVE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float seed_k = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float c = prog * 0.92 - float(i) * 0.13;
		if (c > 0.03) {
			float wob = 0.012 * sin(a * 9.0 + seed_k * 40.0 + float(i) * 2.0);
			float w = 0.01 + 0.012 * (1.0 - prog);
			float gaps = smoothstep(0.2, 0.42, 0.5 + 0.5 * sin(a * (3.0 + float(i)) + seed_k * 25.0 + float(i) * 1.7));
			m = max(m, (1.0 - smoothstep(w * 0.4, w, abs(r + wob - c))) * gaps);
		}
	}
	vec3 iri = 0.5 + 0.5 * cos(a * 2.0 + r * 9.0 + vec3(0.0, 2.1, 4.2));
	ALBEDO = mix(vec3(0.86, 0.8, 1.0), iri, 0.28) * 1.5;
	ALPHA = m * (1.0 - prog * prog) * (1.0 - smoothstep(0.96, 1.0, r));
}
"""

const DIZZY_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 sway = vec2(sin(TIME * 2.3 + uv.y * 5.0), cos(TIME * 1.9 + uv.x * 4.0)) * 0.012 * k;
	vec2 dbl = vec2(cos(TIME * 1.4), sin(TIME * 1.1)) * 0.016 * k;
	vec3 a = texture(scr, uv + sway + dbl).rgb;
	vec3 b = texture(scr, uv + sway - dbl).rgb;
	ALBEDO = (a + b) * 0.5;
	ALPHA = min(1.0, k * 3.0);
}
"""

static var _dizzy_tw: Tween = null


# ------------------------------------------------------------------ model
static func _radius(z: float) -> float:
	var pts = [[-0.175, 0.052], [-0.16, 0.078], [-0.125, 0.093], [-0.06, 0.091], [0.0, 0.08], [0.035, 0.07], [0.05, 0.062]]
	for k in pts.size() - 1:
		var p0: Array = pts[k]
		var p1: Array = pts[k + 1]
		if z <= float(p1[0]):
			return lerpf(float(p0[1]), float(p1[1]), smoothstep(float(p0[0]), float(p1[0]), z))
	return 0.062


## Z ekseninde dönel yüzey. prof: [[z, r, renk], ...] (z artan). Yassı: y yönü 0.9
static func _lathe(b: MB, prof: Array, seg: int) -> void:
	var base = b.verts.size()
	for i in prof.size():
		var q: Array = prof[i]
		var q0: Array = prof[maxi(i - 1, 0)]
		var q1: Array = prof[mini(i + 1, prof.size() - 1)]
		var slope = (float(q1[1]) - float(q0[1])) / maxf(float(q1[0]) - float(q0[0]), 0.001)
		for j in seg + 1:
			var a = TAU * j / seg
			var d = Vector3(cos(a), sin(a) * 0.9, 0.0)
			b.verts.append(d * float(q[1]) + Vector3(0, 0, float(q[0])))
			b.normals.append((Vector3(cos(a), sin(a), 0.0) - Vector3(0, 0, slope)).normalized())
			b.colors.append(q[2])
			b.uvs.append(Vector2(float(j) / seg, float(i)))
	var rowlen = seg + 1
	for i in prof.size() - 1:
		for j in seg:
			var A = base + i * rowlen + j
			var B = A + 1
			var D = A + rowlen
			var C = D + 1
			b.idx.append_array([A, D, C, A, C, B])


static func _surf(z: float, a: float, lift := 0.0) -> Vector3:
	var r = _radius(z) + lift
	return Vector3(cos(a) * r, sin(a) * r * 0.9, z)


static func build_full(b: MB) -> void:
	var prof = []
	var n = 16
	for k in n + 1:
		var z = lerpf(-0.175, 0.05, float(k) / n)
		prof.append([z, _radius(z), SHELL])
	for q in [[0.052, 0.067, SHELL_D], [0.06, 0.066, SHELL], [0.085, 0.062, SHELL], [0.09, 0.054, SHELL_D]]:
		prof.append(q)
	_lathe(b, prof, 26)
	for h in HOLES:
		var z = float(h[0])
		var a = float(h[1])
		var p = _surf(z, a)
		var nr = Vector3(cos(a), sin(a), 0.0).normalized()
		var t1 = Vector3(0, 0, 1)
		var t2 = nr.cross(t1).normalized()
		b.add_xf("sphere", Transform3D(Basis(t2 * 0.03, nr * 0.006, t1 * 0.03), p), HOLE, 10)
		b.add_xf("torus", Transform3D(Basis(t2 * 0.036, nr * 0.05, t1 * 0.036), p), SHELL_D, 14)
	# çatlaklar (ref): deliklerden kenara giden ince kırık çizgiler
	var cracks = [[-0.03, 0.42, -0.035, -0.12], [-0.035, -0.12, -0.09, -0.42], [-0.09, -0.42, -0.14, -0.5], [0.0, 0.3, 0.035, 0.05], [0.035, 0.05, 0.05, -0.2]]
	for c in cracks:
		var p0 = _surf(float(c[0]), float(c[1]), 0.0012)
		var p1 = _surf(float(c[2]), float(c[3]), 0.0012)
		var y = p1 - p0
		var yn = y.normalized()
		var xn = yn.cross(Vector3.BACK).normalized()
		b.add_xf("box", Transform3D(Basis(xn * 0.0028, y, xn.cross(yn) * 0.0014), (p0 + p1) * 0.5), CRACK)
	# üst kenardaki iki küçük tutturma
	for z in [-0.11, -0.02]:
		var p = _surf(z, 1.35, 0.003)
		b.add("box", p, Vector3(0.012, 0.009, 0.036), SHELL_D, Vector3(0, 0, 77))


## Elin arkasındaki bej plaka (ref). Tutuş çerçevesinde: bilek +X, el sırtı +Y
static func build_plate(b: MB) -> void:
	b.add("box", Vector3(0.03, 0.042, 0.0), Vector3(0.075, 0.008, 0.072), PLATE)
	b.add("box", Vector3(0.03, 0.0465, 0.0), Vector3(0.058, 0.002, 0.056), PLATE.darkened(0.12))


# ------------------------------------------------------------------ görsel
static func _ring(p: Vector3, dir: Vector3, size: float, life: float, delay := 0.0) -> void:
	var make = func():
		var mi = Kit.quad(Kit.scene(), size, Kit.shader_mat("kyomei_dalga", WAVE_SH))
		var d = dir.normalized()
		mi.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT), p)
		mi.set_instance_shader_parameter("seed_k", randf())
		Kit.tween_param(mi, "prog", 0.0, 1.0, life, true)
	if delay <= 0.0:
		make.call()
	else:
		Kit.tree().create_timer(delay).timeout.connect(make)


## Vurulanın başı çevresinde dönen iki yatay dalga (iç kulak)
static func _ears(t: Node3D, dur: float) -> void:
	if not is_instance_valid(t):
		return
	var s = {"t": 0.0, "root": null}
	var quads = []
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var tt: float = s["t"]
		if not is_instance_valid(t) or tt > dur:
			return true
		var r: Node3D = s["root"]
		r.global_position = Kit.eye(t) + Vector3.UP * 0.12
		for k in quads.size():
			var q: MeshInstance3D = quads[k]
			q.rotation = Vector3(-PI * 0.5 + sin(tt * 5.0 + k) * 0.35, tt * (5.0 + k), 0.0)
			q.set_instance_shader_parameter("prog", fmod(tt * 1.5 + k * 0.5, 1.0))
		return false
	var root = Kit.ticker(Kit.eye(t), fn)
	s["root"] = root
	for k in 2:
		var q = Kit.quad(root, 0.75 + k * 0.2, Kit.shader_mat("kyomei_dalga", WAVE_SH))
		q.set_instance_shader_parameter("seed_k", randf())
		quads.append(q)


static func _dizzy_screen(k: float, dur: float) -> void:
	var s = Kit.screen("kyomei", DIZZY_SH)
	var m: ShaderMaterial = s.material_override
	s.visible = true
	if _dizzy_tw != null and _dizzy_tw.is_valid():
		_dizzy_tw.kill()
	_dizzy_tw = s.create_tween()
	var set_k = func(v: float) -> void:
		m.set_shader_parameter("k", v)
	_dizzy_tw.tween_method(set_k, k, 0.0, dur)
	_dizzy_tw.tween_callback(func(): s.visible = false)


# ------------------------------------------------------------------ titreşim birikimi
static func ses(who: Node3D) -> int:
	if Game.now() - float(who.get_meta("kyo_t", -99.0)) > SES_LIFE:
		return 0
	return int(who.get_meta("kyo_ses", 0))


static func _add(who: Node3D, n: int) -> void:
	who.set_meta("kyo_ses", mini(MAX_SES, ses(who) + n))
	who.set_meta("kyo_t", Game.now())
	if who is Player:
		Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Yankı %d" % ses(who), WAVE)


static func _vent(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, "kyomei_supika")
	return n.to_global(Vector3(0.09, 0, -0.06)) if n != null else who.global_position + Vector3.UP * 1.25 + who.face_dir() * 0.4


# ------------------------------------------------------------------ ses vuruşu
## İç kulağa etki: kalkan ve kaçış durdurmaz. s: şiddet
static func deafen(t: Node3D, s: float) -> void:
	if not is_instance_valid(t) or not t.has_method("apply_status"):
		return
	t.apply_status("slow", 1.6 + s * 2.0)
	if s >= 0.5:
		t.apply_status("stun", 0.35 + s * 0.8)
		Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Denge bozuldu!", WAVE)
	_ears(t, 0.8 + s)
	if t is Player and t == Game.player:
		_dizzy_screen(clampf(0.35 + s * 0.55, 0.0, 1.0), 1.0 + s * 1.5)


## origin'den f yönünde, R menzil ve cos_min genişlik içinde: ses duvardan da geçer
static func sound(who: Node3D, origin: Vector3, f: Vector3, R: float, cos_min: float, dmg: float, s: float) -> int:
	var n = 0
	for t in Kit.fighters():
		if t == who or not Combat.hostile(who, t) or t.is_dead():
			continue
		var v: Vector3 = Kit.chest(t) - origin
		var d = v.length()
		if d > R + 0.4 or (d > 0.8 and v.normalized().dot(f) < cos_min):
			continue
		_hit_one(who, t, dmg, s, f)
		n += 1
	return n


static func _hit_one(who: Node3D, t: Node3D, dmg: float, s: float, f: Vector3) -> void:
	var wet = t.has_method("has_status") and t.has_status("wet")
	t.take_hit({"dmg": dmg * (1.35 if wet else 1.0), "knock": 1.0, "kind": "light", "hitstop": 0.02, "sure": true, "melee": false, "attacker": who, "dir": Vector3(f.x, 0, f.z).normalized()})
	U.credit(who, t)
	deafen(t, s * (1.3 if wet else 1.0))


static func _aim_dir(who: Node3D, tg: Node3D) -> Vector3:
	var p = U.aim_at(who, tg)
	U.face(who, p)
	var d: Vector3 = p - (who.global_position + Vector3.UP * 1.3)
	d.y = clampf(d.y, -d.length() * 0.4, d.length() * 0.4)
	return d.normalized() if d.length() > 0.05 else who.face_dir()


## Hibiki-uke: yakına gelen kunai / shuriken / iğne / ok kolçakta durur, titreşim olur (patlayıcı araçlar durmaz)
static func _catch(who: Node3D, dur: float) -> void:
	var s = {"t": 0.0}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		if not is_instance_valid(who) or float(s["t"]) > dur:
			return true
		var c: Vector3 = _vent(who)
		for pr in Kit.tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(pr) or pr.dead or pr.shooter == null or not is_instance_valid(pr.shooter):
				continue
			if not Combat.hostile(who, pr.shooter) or (not pr.info.get("element", "") in [null, ""]) or float(pr.radius) > 0.3:
				continue
			if str(pr.info.get("tool", "")) in ["kibaku_dama", "bakusaidama", "kibaku_fuda", "smoke", "hikaridama", "togarashi_dama", "makibishi"]:
				continue
			if pr.global_position.distance_to(c) < 1.5:
				pr.dead = true
				pr.queue_free()
				_add(who, 1)
				Sfx.play("clink", c, 0.7, 0.7)
				_ring(c, (pr.global_position - c).normalized() if pr.global_position.distance_to(c) > 0.05 else who.face_dir(), 1.5, 0.3)
		return false
	Kit.ticker(who.global_position, fn)


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 4:
		_catch(who, 0.68)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var f = _aim_dir(who, tg)
	var o = _vent(who)
	match i:
		0, 1:   # savuruş sesi: yumruk değmese de yakındakine ulaşır
			_ring(o + f * 0.4, f, 2.2, 0.26)
			_ring(o + f * 1.1, f, 3.2, 0.3, 0.04)
			sound(who, o, f, 3.4, 0.62, dmg * 0.32, 0.2)
			_add(who, 1)
			Sfx.play("genjutsu", o, 1.9, 0.22)
		2:   # Uchinarashi: kolçağa vurmak sesi büyütür: çevreye yayılır, iki kat birikir
			for k in 3:
				_ring(o, Vector3.UP, 4.0 + k * 1.6, 0.34, k * 0.05)
				_ring(o, f, 2.6 + k, 0.3, k * 0.05)
			sound(who, o, f, 3.6, -1.0, dmg * 0.55, 0.55)
			_add(who, 2)
			Sfx.play("clash", o, 0.62, 0.55)
			Sfx.play("genjutsu", o, 1.45, 0.35)
		3:   # Kyōmei-zuki: düz çizgide delen ses
			for k in 5:
				_ring(o + f * (0.5 + k * 1.05), f, 1.3 + k * 0.5, 0.26, k * 0.035)
			sound(who, o, f, 6.0, 0.86, dmg * 0.6, 0.7)
			_add(who, 1)
			Sfx.play("genjutsu", o, 1.7, 0.35)
		4:   # biriken titreşimden kısa bir itiş
			var c = ses(who)
			_ring(o + f * 0.5, f, 2.6 + c * 0.35, 0.3)
			sound(who, o, f, 3.0 + c * 0.25, 0.7, dmg * (0.3 + c * 0.06), 0.3)
		5:   # Kyōmei-hanachi: biriken ses chakrayla yönlenir; chakra yoksa kısa ve dağınık
			var c = ses(who)
			who.set_meta("kyo_ses", 0)
			var guided = U.pay(who, CHAKRA)
			var R = (9.0 + c * 1.2) if guided else 4.0
			var goal: Vector3 = o + f * R
			if guided and U.alive(tg) and o.distance_to(U.chest(tg)) <= R:
				goal = U.chest(tg)
			var path: Vector3 = goal - o
			var dn: Vector3 = path.normalized() if path.length() > 0.05 else f
			for k in 9:
				var u = float(k + 1) / 9.0
				_ring(o + path * u, dn, 1.2 + u * (2.0 + c * 0.25), 0.3, u * 0.22)
			Sfx.play("genjutsu", o, 1.15, 0.7)
			var pw = dmg * (0.9 + c * 0.22)
			var sev = 0.75 + c * 0.14
			Kit.tree().create_timer(0.22).timeout.connect(func():
				if not is_instance_valid(who):
					return
				if guided and U.alive(tg) and goal.distance_to(U.chest(tg)) < 3.0:
					_hit_one(who, tg, pw, sev, dn)   # chakra hedefi bulur
				else:
					sound(who, o, dn, R, 0.9, pw * 0.8, sev * 0.7))
			if who is Player and Game.world:
				Game.world.env.add_shake(0.3)
