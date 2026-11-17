class_name KatonFXF
extends RefCounted
## Katon F: Arayış Topu teknikleri (Bōchō Gudōdama, Gudō Jiu Hikari, Zangetsu), Enton Kagutsuchi no Tsurugi, Susanoo Gōkakyū.
## Arayış Topu ve kara alev MADDESİ KatonFXC'nin malzemesidir (aynı madde = aynı malzeme); şekil, hareket ve sahneleme
## her teknikte burada sıfırdan. Hazır / ortak görsel yok.

static var _cache := {}

## Genişleyen ak ışıma küresi (Arayış Topunun "ışıması"): kenara doğru söner, içi beyaz-sarı, kenarı ince gri kontur
const GLARE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform float hot = 1.0;
void fragment() {
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	vec3 core = vec3(1.0, 1.0, 0.94);
	vec3 rim = vec3(0.62, 0.64, 0.7);
	vec3 col = mix(rim, core, smoothstep(0.08, 0.35, f));
	col = mix(col, vec3(0.15, 0.15, 0.18), step(f, 0.06));
	ALBEDO = col;
	float a = mix(0.25, 1.0, smoothstep(0.0, 0.5, f)) * hot;
	float nearf = smoothstep(1.5, 6.0, -VERTEX.z);
	ALPHA = clamp(a * fade * nearf, 0.0, 1.0);
}
"""

## Yere yatık tırtıklı silme dalgası (zeminde grileşen halka); prog 0..1 yarıçap, fade
const SCAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.2;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float edge = prog * (0.92 + 0.08 * sin(a * 13.0 + seed * 5.0) + 0.04 * sin(a * 31.0 + seed));
	float band = smoothstep(edge - 0.16, edge - 0.04, r) * (1.0 - smoothstep(edge - 0.02, edge, r));
	float inner = (1.0 - smoothstep(edge - 0.35, edge - 0.15, r)) * 0.35 * step(r, edge);
	vec3 col = mix(vec3(0.72, 0.73, 0.76), vec3(0.05, 0.05, 0.06), step(0.5, band));
	ALBEDO = col;
	ALPHA = clamp(max(band, inner) * fade, 0.0, 1.0);
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _sph() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sph"] = s
	return _cache["sph"]


static func _tree(pj) -> SceneTree:
	return pj.get_tree()


static func _host(pj) -> Node:
	return pj.get_tree().current_scene


## Ak ışıma küresi: r0'dan r1'e büyür, söner
static func _glare(host: Node, p: Vector3, r0: float, r1: float, life: float) -> MeshInstance3D:
	var mi = KatonLib.gi(_sph(), _mat("glare", GLARE_SHADER))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("hot", 1.0)
	KatonLib.put(host, mi, p)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life * 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Zeminde dışa koşan silme dalgası (gri halka, tırtıklı)
static func _scar(host: Node, p: Vector3, r: float, life: float) -> void:
	var mi = KatonLib.gi(KatonLib._plane(), _mat("scar", SCAR_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("prog", 0.15)
	mi.set_instance_shader_parameter("fade", 1.0)
	KatonLib.put(host, mi, KatonLib.floor_at(p) + Vector3.UP * 0.06)
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_method(KatonLib.pf(mi, "prog"), 0.15, 1.0, life * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(mi, "fade"), 1.0, 0.0, life * 0.5)
	tw.tween_callback(mi.queue_free)


## Işıma anında kopan ince ak ışınlar (kısa, dümdüz, dışa koşan çubuklar)
static func _rays(host: Node, p: Vector3, n: int, len_: float, life: float) -> void:
	if not _cache.has("ray"):
		var b = MB.new()
		b.add("box", Vector3(0, 0, -0.5), Vector3(0.05, 0.05, 1.0), Color(1, 1, 0.94))
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache["ray"] = b.build(m)
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		var mi = KatonLib.gi(_cache["ray"], null)
		KatonLib.put(host, mi, p)
		KatonLib.look(mi, d)
		mi.scale = Vector3(1, 1, 0.1)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1, 1, len_ * randf_range(0.6, 1.0)), life * 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(0.05, 0.05, len_), life * 0.65)
		tw.tween_callback(mi.queue_free)


# ================================================================== Bōchō Gudōdama
## Elde ufak Arayış Topu belirir, hedefe süzülür; orada sıvı gibi dalgalanarak dev bir küreye şişer (her şeyi yutar),
## yüzeyinden dışa ak ışınlar çakar, zeminde gri silme dalgası koşar; sonra ağır ağır büzülüp yok olur.
static func bocho_gudodama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var host = _host(pj)
	var tt = pj.tg(c, t, 30.0)
	var at = (tt.global_position + Vector3.UP if tt else c.global_position + pj.fwd(c, t) * 14.0 + Vector3.UP)
	var ball = KatonFXC._tsb_ball(1.0)
	host.add_child(ball)
	ball.global_position = pj.hand_pos(c, true)
	ball.scale = Vector3.ONE * 0.4
	var tw = ball.create_tween()
	tw.tween_property(ball, "global_position", at, 0.4).set_trans(Tween.TRANS_SINE)
	# şişme: hızlı başlayıp yavaşlayan, iki kez "nefes alan" büyüme
	tw.tween_property(ball, "scale", Vector3.ONE * 5.5, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "scale", Vector3.ONE * 7.5, 0.28)   # vuruş yarıçapı 7.5 ile aynı; daha büyüğü kamerayı yutar.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_rays(host, at, 14, 11.0, 0.45)
		_scar(host, at, 16.0, 1.4)
		KatonFXC._erase_flakes(host, at + Vector3.UP * 2.0, 26, 10.0, Vector3.UP * 0.4)
		pj.hit(c, at, 7.5, pj.inf(c, "bocho_gudodama", 3.0, {"knock": 20.0, "kind": "heavy", "hitstop": 0.12}))
		pj.shake(1.4))
	tw.tween_interval(0.6)
	tw.tween_property(ball, "scale", Vector3.ONE * 0.05, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(ball.queue_free)
	Sfx.play("boom", at, 0.4)


# ================================================================== Gudō Jiu Hikari
## Omuz üstünde topu tutar; fırlattığı top hedefte önce siyah iken içten ağarıp ak ışıma küresine döner (yer yarılır,
## gri pullar), ışıma söndükçe ufak kara top yeniden belirip sahibine geri uçar.
static func gudo_jiu_hikari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var host = _host(pj)
	var tt = pj.tg(c, t, 32.0)
	var bb = KatonFXC._tsb_ball(0.32)
	c.add_child(bb)
	bb.position = Vector3(0, 1.8, 0.6)
	Sfx.play("chakra", c.global_position, 0.5)
	pj.after(0.35, func():
		if not pj.live(c) or not is_instance_valid(bb):
			return
		var from = bb.global_position
		bb.queue_free()
		var proj = Node3D.new()
		proj.add_child(KatonFXC._tsb_ball(0.45))
		pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, proj, pj.inf(c, "gudo_jiu_hikari", 0.4, {"knock": 4.0, "kind": "heavy"}), tt, false, 1.4, func(p, _h):
			# kara top durur, titreyerek şişer; içinden ak ışıma doğar
			var hold = KatonFXC._tsb_ball(0.45)
			KatonLib.put(host, hold, p)
			var tw = hold.create_tween()
			tw.tween_property(hold, "scale", Vector3.ONE * 1.6, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_glare(host, p, 1.2, 7.0, 0.55)
				_rays(host, p, 10, 7.0, 0.35)
				_scar(host, p, 9.0, 1.0)
				KatonFXC._erase_flakes(host, p, 18, 6.0)
				KatonLib.light(host, p, Color(1, 1, 0.92), 8.0, 20.0, 0.4)
				GroundFX.add(KatonLib.floor_at(p) + Vector3.UP * 0.1, "cracked", 3.0, 5.0)
				pj.hit(c, p, 7.0, pj.inf(c, "gudo_jiu_hikari", 2.2, {"knock": 20.0, "launch": 6.0, "kind": "heavy", "pierce_guard": true, "hitstop": 0.1}))
				pj.shake(0.9)
				Sfx.play("boom", p, 0.7)
				if is_instance_valid(hold):
					hold.queue_free()
				# top sahibine geri döner: ışımanın içinden küçük kara top
				var back = KatonFXC._tsb_ball(0.3)
				KatonLib.put(host, back, p)
				var tw2 = back.create_tween()
				tw2.tween_interval(0.25)
				tw2.tween_method(func(u: float):
					if is_instance_valid(back) and pj.live(c):
						back.global_position = p.lerp(c.global_position + Vector3.UP * 1.8, u) + Vector3.UP * sin(u * PI) * 1.5, 0.0, 1.0, 0.5)
				tw2.tween_callback(back.queue_free))))


# ================================================================== Zangetsu
## Atılıp çapraz vurur; vuruşla rakibin göğsüne küçük kara top yapışır, nabız gibi atarak büyür, en büyük anında
## ak ışımayla patlar: dışa ışınlar, gri silme halkası, pullar.
static func zangetsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.2)
	if tt == null:
		return
	var host = _host(pj)
	pj._jump_at(c, tt, 0.0, 12.0)
	pj.anim(c, "cross", 1.3)
	pj.after(0.25, func():
		if not pj.live(c) or not pj.live(tt):
			return
		tt.take_hit(pj.inf(c, "zangetsu", 0.5, {"knock": 2.0, "kind": "heavy"}))
		# vuruş izi: çapraz iki ince gri silme çizgisi (kesik değil, maddenin silindiği yer)
		var chest = tt.global_position + Vector3.UP * 1.2
		for _s in 2:
			_rays(host, chest, 2, 1.4, 0.3)
		KatonFXC._erase_flakes(host, chest, 6, 1.0)
		var ball = KatonFXC._tsb_ball(0.18)
		var ba = pj.bone_attach(tt, "Chest")
		if ba:
			ba.add_child(ball)
			ball.position = Vector3(0, 0, 0.25)
		else:
			tt.add_child(ball)
			ball.position = Vector3(0, 1.2, 0.3)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Arayış topu yerleşti!", Color(0.85, 0.85, 0.95))
		# nabız: büyü-küçül-büyü (her atımda ufak pul kopar)
		var tw = ball.create_tween()
		for k in 3:
			var big = 0.6 + k * 0.6
			tw.tween_property(ball, "scale", Vector3.ONE * big * 1.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(ball, "scale", Vector3.ONE * big, 0.12)
		tw.tween_property(ball, "scale", Vector3.ONE * 2.6, 0.0)
		tw.tween_callback(func():
			var p = ball.global_position
			ball.queue_free()
			if ba:
				ba.queue_free()
			_glare(host, p, 0.8, 6.0, 0.5)
			_rays(host, p, 12, 6.0, 0.35)
			_scar(host, p, 8.0, 0.9)
			KatonFXC._erase_flakes(host, p, 16, 5.0)
			KatonLib.light(host, p, Color(1, 1, 0.92), 7.0, 18.0, 0.35)
			pj.hit(c, p, 6.0, pj.inf(c, "zangetsu", 2.0, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "pierce_guard": true, "hitstop": 0.1}))
			pj.shake(0.8)
			Sfx.play("boom", p, 0.8)))


# ================================================================== Enton: Kagutsuchi no Tsurugi
## Avuçtan kara alev kılıcı uzar (alevden şekillenmiş dalgalı ağız + uçta kanca dil); atılışta arkasında kara alev
## dilleri bırakır; savuruşta önde yarım ay biçiminde kara alev yelpazesi açılır, yere düşen alev kara kor olup yanar.
static func enton_kagutsuchi_no_tsurugi(_pj_unused, c: Node3D, t: Node3D) -> void:
	var host = Jutsu.get_tree().current_scene
	var sw = Node3D.new()
	c.add_child(sw)
	sw.position = Vector3(0.35, 1.1, -0.5)
	# kılıç gövdesi: kara alev kütlesi çubuğu (ileri -Z) + boyunca dalgalı diller + uçta kanca dil
	for k in 6:
		var z = -0.25 - k * 0.3
		var m = KatonFXC._black_mass_mi(0.12 - k * 0.012, 0.35)
		m.position = Vector3(0, 0, z)
		m.scale = Vector3(0.12 - k * 0.012, 0.12 - k * 0.012, 0.22)
		sw.add_child(m)
		var tg = KatonFXC._black_tongue_mi(0.45 - k * 0.04, 0.2, Vector3(0, 1.0, 0.25).normalized(), 1.0)
		tg.position = Vector3(0, 0.05, z)
		sw.add_child(tg)
	var tip = KatonFXC._black_tongue_mi(0.7, 0.25, Vector3(0, 0.3, -1.0).normalized(), 1.1)
	tip.position = Vector3(0, 0.05, -2.0)
	sw.add_child(tip)
	sw.scale = Vector3(1, 1, 0.05)
	sw.create_tween().tween_property(sw, "scale", Vector3.ONE * 1.4, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play("genjutsu", c.global_position, 0.7)
	var inf = Jutsu._inf(c, "enton_kagutsuchi_no_tsurugi", 0.7, {"knock": 8.0, "kind": "heavy", "hitstop": 0.06, "element": "katon"})
	var hitl = []
	var step = [0]
	Jutsu.get_tree().create_timer(0.25).timeout.connect(func():
		if not is_instance_valid(c):
			return
		if c.get("model") and c.model:
			c.model.play("slash_c", 0.05, 1.3, true)
		Jutsu._dash(c, t, 0.32, 24.0, func(p: Vector3):
			for h in Combat.hit_sphere(c, p, 2.0, inf, hitl):
				hitl.append(h)
				Jutsu._ignite(h, 6.0)
			step[0] += 1
			if step[0] % 2 == 0:
				KatonFXC._black_tongue(host, p - Vector3.UP * 0.6, 1.0, 0.5, 0.5, Vector3(0, 1, 0.2).normalized()), func():
			if not is_instance_valid(c):
				return
			# savuruş: önde yarım ay kara alev yelpazesi (9 dil yay boyunca, dışa yatık)
			var d: Vector3 = c.face_dir()
			var sd = d.cross(Vector3.UP).normalized()
			var o = c.global_position + Vector3.UP * 1.1 + d * 1.2
			for k in 9:
				var u = (k / 8.0) * 2.0 - 1.0
				var ax = (d * cos(u * 1.1) + sd * sin(u * 1.1) + Vector3.UP * 0.25).normalized()
				KatonFXC._black_tongue(host, o + sd * u * 1.6, randf_range(2.2, 3.0), 0.8, 0.7, ax, ax * 1.2)
			# yere düşen kara korlar: alçak, yavaş sönen diller
			var g = KatonLib.floor_at(c.global_position + d * 2.0)
			for k in 6:
				var a = randf() * TAU
				KatonFXC._black_tongue(host, g + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.6), randf_range(0.5, 0.9), 0.5, randf_range(2.5, 4.5))
			if is_instance_valid(sw):
				var tw = sw.create_tween()
				tw.tween_property(sw, "scale", Vector3(0.2, 0.2, 0.05), 0.2)
				tw.tween_callback(sw.queue_free)))


# ================================================================== Susanoo: Gōkakyū
## Susanoo'nun ağzında ateş toplanır (sarmal kor akışı + kabaran kütle), dev ateş topu Susanoo ölçeğinde yuvarlanarak
## uçar (güneş yüzeyi + taç diller), çarpınca yassı dev alev çiçeği, yanan zemin.
static func susanoo_gokakyu(_pj_unused, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_gokakyu")
	if sn == null:
		return
	var host = Jutsu.get_tree().current_scene
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = MsArts._aim_fn(c, tg, 22.0 + H * 0.6)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	MsArts._pj().busy(c, 1.1)
	MsArts._anim(c, "cast", 0.9)
	var seal = Susanoo.arm(true, -Vector3.UP * 0.7 + d * 0.45 + side * 0.2, -side * 0.75 + Vector3.UP * 0.55 + d * 0.35) + Susanoo.arm(false, -Vector3.UP * 0.7 + d * 0.45 - side * 0.2, side * 0.75 + Vector3.UP * 0.55 + d * 0.35)
	sn.pose({"arms": seal, "spine": -16.0, "neck": -14.0}, 1.4)
	# toplanma: ağız önünde sarmal kor akışı ve küçük kabaran kütle
	var mouth0 = sn.mouth(d)
	KatonLib.spiral_in(host, mouth0, 0.0, 0.6, 12, 1.2 + S * 0.4)
	KatonLib.mass(host, mouth0 + d * 0.4 * S, 0.2 * S, 0.7 * S, 0.65, Vector3.ZERO, 0.0, 1.1)
	Sfx.play("fire", c.global_position, 0.5, 0.6)
	MsArts._later(0.65, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		sn.pose({"arms": seal, "spine": 18.0, "neck": 12.0}, 0.8, true)
		var from = sn.mouth(d)
		var to: Vector3 = aim.call()
		var R = 1.6 + S * 0.5
		var ball = Node3D.new()
		ball.add_child(KatonLib.sun_mi(R, 0.0, 1.05, 1.4))
		for k in 10:
			var a = k * TAU / 10.0
			var ax = Vector3(cos(a), sin(a) * 0.6 + 0.3, sin(a)).normalized()
			var tgm = KatonLib.tongue_mi(R * 0.9, R * 0.55, ax, 0.0, 5, 0.0, 1.0)
			tgm.position = ax * R * 0.75
			ball.add_child(tgm)
		var inf = Jutsu._inf(c, "susanoo_gokakyu", 3.0, {"knock": 18.0, "launch": 8.0, "kind": "heavy", "element": "katon", "burn": 5.0})
		var pr = MsArts._pj().shot(c, from, (to - from).normalized(), 20.0 + S, ball, inf, tg, false, 3.0, func(p, _h):
			# yassı dev alev çiçeği: yere yatık halka diller + basık kütleler + kavruk iz
			for k in 12:
				var a = k * TAU / 12.0
				var ax = Vector3(cos(a), 0.45, sin(a)).normalized()
				KatonLib.tongue(host, p, randf_range(2.5, 3.6) * (1.0 + S * 0.2), 1.6, 0.7, ax, ax * 2.0)
			KatonLib.mass(host, p, 0.6, 2.4 + S * 0.4, 0.8, Vector3.UP * 1.5, 0.0, 1.2, 1.0, 0.6)
			KatonLib.scorch(host, KatonLib.floor_at(p) + Vector3.UP * 0.05, 4.0 + S * 0.5, 6.0)
			KatonLib.light(host, p, Color(1.0, 0.6, 0.2), 8.0, 24.0, 0.5)
			KatonFXC._blast_marks(p, 2.0 + S * 0.3)
			GroundFX.add(p, "burning", 5.0 + S * 0.5, 5.0, c)
			MsArts._shake(1.4))
		pr.radius = 1.5 + S * 0.35
		pr.homing_turn = 1.0
		ball.scale = Vector3.ONE * 0.2
		ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		Sfx.play("fire", from, 0.4))
