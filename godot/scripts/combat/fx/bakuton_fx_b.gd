class_name BakutonFXB
extends RefCounted
## Bakuton grubu B: Iwa patlama dövüşü (Dai Jiraiken, Shōgeki, Bōgyo), Bakuha klanı mayın / avuç / zincir patlamaları ve
## Deidara'nın kil sanatı yan teknikleri (kil kuşlar, kil bebekler, intihar klonu, C2 mayın ejderi, C2 dalış, kil ikame).
## Malzeme ve yapı taşları BakutonLib'den; her tekniğin patlama şekli, hareketi ve sahnelenmesi burada ve birbirinden ayrı.
## Ortak efekt yardımcısı yok. Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, zemin yarığı /
## yanık bölgeleri, ses, sarsıntı) ana ağaçtaki işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/bakuton_lib.gd")

static var _cache := {}


# ================================================================== eski ortak yardımcıların OYUN tarafı (görselsiz)
## Yarık zemin: üstünden geçen yavaşlar (eski çatlak izinin oyun tarafı; boy >= 1.5)
static func _crack_zone(g: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(g, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


## Eski kil patlamasının oyun tarafı: zemine yakınsa yarık bölge, sarsıntı, ses
static func _blast_side(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var g = L.floor_at(pos)
	if pos.y - g.y < 3.5 * s:
		_crack_zone(g, 4.5 * s, 8.0)
	pj.shake(0.6 * s)
	Sfx.play("boom", pos)


## Eski Bakuton isabetinin oyun tarafı (kil patlaması 1.1*s + yakın zemin yarığı + sarsıntı)
static func _impact_side(pj: PathJutsu, at: Vector3, s: float) -> void:
	_blast_side(pj, at, 1.1 * s)
	var g = L.floor_at(at)
	if at.y - g.y < 2.5:
		_crack_zone(g, 2.5 * s, 6.0)
	pj.shake(0.25 + 0.25 * s)


## Eski ateş patlamasının oyun tarafı: zemine yakınsa yanan zemin, sarsıntı, ses
static func _explosion_side(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var g = L.floor_at(pos)
	if pos.y - g.y < 3.0 * s:
		GroundFX.add(g + Vector3.UP * 0.12, "burning", 1.2 * s + 0.8, 4.0)
	pj.shake(0.7 * s)
	Sfx.play("boom", pos)


## Yakın dövüş vuruşu (eski mhit'in oyun tarafı): isabet + sarsıntı (+ ağır vuruşta yarık zemin). Görsel tekniğin kendisinde.
static func _mhit(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary, exclude: Array = []) -> Array:
	var hs = pj.hit(c, pos, r, info, exclude)
	if not hs.is_empty():
		var heavy = String(info.get("kind", "")) == "heavy"
		var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
		var ms = s if heavy else s * 0.7
		if heavy and s > 1.3:
			_crack_zone(pj.gp(hs[0].global_position + Vector3.UP), 3.0 * ms)
		pj.shake(0.2 + 0.3 * ms)
	return hs


# ================================================================== Bakuton Dai Jiraiken
## Havaya sıçrayış: iki yumrukta beyaz-sarı çekirdek kabarır, yumruklardan kıvılcım damlar; dalışta dikey hız çizgileri.
## Yere çarpış: alçak geniş parlama, yuvarlak kabaran top, merkezde kenarları kalkan kaya plakaları (zemin kabarır, sonra
## geri çöker), ışınsal yarıklı kurum. Ardından üç şerit boyunca toprağın altından yarı gömülü toplar sırayla fışkırır —
## her biri kaya parçası kusar, arkasında küçük yanık izi bırakır.
static func bakuton_dai_jiraiken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.3)
	var d = pj._face(c, tt)
	var dist: float = clampf(c.global_position.distance_to(tt.global_position) - 4.0, 0.0, 8.0) if tt else 2.0
	if "velocity" in c:
		c.velocity = d * dist * 2.0 + Vector3.UP * 10.0
	_twin_fists(pj, c, 0.66)
	var dive = func():
		if pj.live(c) and "velocity" in c:
			c.velocity = d * 3.0 + Vector3.DOWN * 30.0
			pj.anim(c, "hook", 1.6)
			for k in 3:
				var off = Vector3(randf_range(-0.5, 0.5), 1.6 + k * 0.6, randf_range(-0.5, 0.5))
				L.flash(pj, c.global_position + off, 1.6, 0.18, {"spikes": 2.0, "stretch": Vector2(0.08, 2.2), "near": 3.0})
	pj.after(0.5, dive)
	var blast = func():
		if not pj.live(c):
			return
		var o = pj.gp(c.global_position + d * 1.2)
		var done = []
		_quake_center(pj, o, d)
		_impact_side(pj, o + Vector3.UP * 0.4, 2.0)
		done.append_array(_mhit(pj, c, o + Vector3.UP * 0.8, 3.4, pj.inf(c, "bakuton_dai_jiraiken", 2.6, {"knock": 22.0, "launch": 6.0, "kind": "heavy", "element": "bakuton", "hitstop": 0.14})))
		pj.shake(1.2)
		Sfx.play("boom", o, 0.6)
		for lane in 3:
			var ld = d.rotated(Vector3.UP, (lane - 1) * 0.42)
			for k in 4:
				var pop = func():
					if not pj.live(c):
						return
					var p = pj.gp(o + ld * (3.5 + k * 3.0)) + Vector3.UP * 0.6
					_buried_burst(pj, p, ld, 1.1 + k * 0.2)
					_impact_side(pj, p, 1.1 + k * 0.2)
					done.append_array(_mhit(pj, c, p, 2.7, pj.inf(c, "bakuton_dai_jiraiken", 2.2, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "element": "bakuton"}), done))
					if k % 2 == 0:
						Sfx.play("boom", p, 0.9, 0.7)
				pj.after(0.08 + k * 0.08, pop)
	pj.after(0.66, blast)


## İki yumrukta kabaran çekirdek + yumruklardan damlayan kıvılcım (kemik yoksa elde kısa çakmalar)
static func _twin_fists(pj: PathJutsu, c: Node3D, t: float) -> void:
	var has_bone = false
	for side in ["RightHand", "LeftHand"]:
		var ba = L.bone(c, side)
		if ba == null:
			continue
		has_bone = true
		var orb = L.orb_mi(0.08, 0.35, 7.0)
		ba.add_child(orb)
		var tw = orb.create_tween()
		tw.tween_property(orb, "scale", Vector3.ONE * 0.6, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		L.kill(pj, t + 0.04, ba)
	pj.every(t, 0.09, func(_i, _k):
		if not is_instance_valid(c):
			return
		for r in [true, false]:
			L.sparks(pj, pj.hand_pos(c, r), 3 if has_bone else 6, 0.06, {"dir": Vector3.DOWN, "spread": 40.0, "vmin": 0.6, "vmax": 2.0, "g": Vector3(0, -6, 0), "life": 0.35, "size": 0.07}))


## Merkez çarpma: alçak parlama, yuvarlak top, kenarı kalkan kaya plakaları, kurum
static func _quake_center(pj: PathJutsu, o: Vector3, _d: Vector3) -> void:
	L.flash(pj, o + Vector3.UP * 0.5, 7.0, 0.32, {"spikes": 12.0, "stretch": Vector2(1.5, 0.7), "near": 8.0})
	_fb(pj, o + Vector3.UP * 0.8, 0.7, 3.4, 1.5, {"near": 8.0, "rise": 1.2})
	L.light(pj, o + Vector3.UP * 1.5, Color(1.0, 0.86, 0.6), 7.0, 18.0, 0.6)
	L.soot(pj, o, 4.2, 9.0, {"heat": 0.9, "cracks": 1.0})
	# kalkan kaya plakaları: halka boyunca dışa eğilip yükselir, sonra çöker
	for k in 9:
		var a = k * TAU / 9.0 + randf() * 0.3
		var rd = Vector3(cos(a), 0, sin(a))
		var slab = L.stone(randf_range(0.8, 1.2), 2.0, k % 3 == 0)
		slab.scale = Vector3(1.0, 0.35, 1.3)
		var p0 = L.floor_at(o + rd * randf_range(2.0, 2.6)) - Vector3.UP * 0.35
		L.put(pj, slab, p0)
		slab.rotation.y = -a
		var tw = slab.create_tween()
		tw.tween_property(slab, "global_position", p0 + Vector3.UP * 0.55 + rd * 0.3, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(slab, "rotation:z", 0.6 * (1.0 if k % 2 == 0 else -1.0), 0.12)
		tw.parallel().tween_property(slab, "rotation:x", -0.5, 0.12)
		tw.tween_interval(1.4)
		tw.tween_property(slab, "global_position", p0 - Vector3.UP * 0.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(slab.queue_free)
	L.shrapnel(pj, o + Vector3.UP * 0.4, 10, 9.0, 0.22, {"col": L.STONE, "up": 1.0, "life": 1.3})
	L.ring(pj, o + Vector3.UP * 0.12, 1.0, 8.0, 0.5, Vector3.UP, {"w": 0.3, "near": 7.0})


## Şerit patlaması: zeminin altından fışkıran yarı gömülü top, kusulan kaya, küçük yanık
static func _buried_burst(pj: PathJutsu, p: Vector3, ld: Vector3, s: float) -> void:
	var g = L.floor_at(p)
	L.flash(pj, g + Vector3.UP * 0.3, 2.2 * s, 0.2, {"spikes": 5.0, "warm": 0.6, "stretch": Vector2(1.6, 0.6), "near": 6.0})
	_fb(pj, g - Vector3.UP * 0.2 * s, 0.4 * s, 1.5 * s, 1.0 + 0.1 * s, {"near": 7.0, "rise": 1.4, "squash": Vector3(1.0, 0.8, 1.0)})
	L.shrapnel(pj, g + Vector3.UP * 0.2, 5, 7.0 * s, 0.16 * s, {"col": L.STONE, "up": 1.4, "dir": ld + Vector3.UP, "bias": 0.3, "life": 1.0})
	L.soot(pj, g, 1.2 * s, 5.0, {"heat": 0.5})


# ================================================================== Kibaku Nendo
## Avuç ağzı kili çiğner (anime: dudakların arasından kabarık beyaz kil topağı çıkar); üç kil kuş sırayla esneyerek doğar,
## uçarken içleri ışıldar. Çarpınca kanat açıklığında yatay, yassı kabaran top, kuşun kil tüyleri gibi süzülen pullar.
static func kibaku_nendo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.palm_mouth(pj, c, true, 0.6, 0.06)
	var dir = Jutsu._aim(c, t)
	for i in 3:
		pj.get_tree().create_timer(i * 0.18).timeout.connect(func():
			if not is_instance_valid(c):
				return
			var dd = (dir + Vector3(randf_range(-0.3, 0.3), 0.25, randf_range(-0.3, 0.3))).normalized()
			var pr = Projectile.new()
			pr.shooter = c
			pr.vel = dd * 18.0
			pr.radius = 0.8
			pr.life = 3.0
			pr.homing = t
			pr.homing_turn = 2.5
			pr.info = Jutsu._inf(c, "kibaku_nendo", 0.4, {"element": "bakuton"})
			var bird = L.bird(1.1, 1.2)
			pr.add_child(bird)
			pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
				_wing_burst(pj, pos, pr.vel)
				_blast_side(pj, pos, 1.0)
				Combat.hit_sphere(c, pos, 4.0, Jutsu._inf(c, "kibaku_nendo", 0.6, {"element": "bakuton"}), pr.hit_list)
			pj.get_tree().current_scene.add_child(pr)
			pr.global_position = Jutsu._hand(c) + Vector3.UP * 0.5
			L.pop_in(bird, 0.22, 1.0)
			L.shrapnel(pj, pr.global_position, 3, 2.0, 0.04, {"up": 0.8, "life": 0.6})
			pj.get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(bird):
					L.fuse(bird, 1.2, 0.45)))


## Kuş patlaması: kanat açıklığında yassı top + süzülen kil tüyleri + birkaç kıvılcım
static func _wing_burst(pj: PathJutsu, pos: Vector3, vel: Vector3) -> void:
	var side = Vector3(vel.x, 0, vel.z).normalized().cross(Vector3.UP)
	if side.length() < 0.5:
		side = Vector3.RIGHT
	L.flash(pj, pos, 2.4, 0.22, {"spikes": 5.0, "warm": 0.4, "stretch": Vector2(1.7, 0.7), "near": 5.0})
	_fb(pj, pos, 0.3, 1.5, 0.9, {"near": 6.0, "rise": 0.9, "dir": side, "squash": Vector3(0.75, 0.7, 1.8)})
	L.flakes(pj, pos, 26, 0.5, {"col0": L.CLAY, "col1": L.CLAY_SHADE, "vmin": 2.0, "vmax": 5.5, "g": Vector3(0, -1.6, 0), "damp": 2.5, "life": 1.9, "size": 0.22, "spin": 300.0, "spread": 120.0})
	L.sparks(pj, pos, 10, 0.3, {"vmin": 4.0, "vmax": 9.0, "life": 0.4})
	L.light(pj, pos, Color(1.0, 0.88, 0.62), 4.0, 8.0, 0.35)


# ================================================================== Jibaku Bunshin
## Yer değiştirirken bedenden kil kabuk kırıntıları dökülür; kopya kalır. Kopya vurulunca (anime: kucaklayıp kör edici beyaz
## ışıkla patlar) içinden ışınsal hız çizgili beyaz çakma, beyaz-camgöbeği kabaran kubbe, geç kalan koyu gri topaklar,
## zemin halkası ve kurum.
static func jibaku_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var at = c.global_position
	L.shrapnel(pj, at + Vector3.UP * 1.1, 9, 3.0, 0.1, {"up": 0.3, "life": 0.8})
	L.flakes(pj, at + Vector3.UP * 1.0, 14, 0.45, {"col0": L.CLAY, "col1": L.CLAY_SHADE, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -3.0, 0), "life": 0.9, "size": 0.12})
	c.global_position = pj.gp(at - c.face_dir() * 5.0)
	pj.decoy(c, at, 8.0, func(pos):
		_clone_flash(pj, pos + Vector3.UP)
		_blast_side(pj, pos + Vector3.UP, 2.0)
		pj.hit(c, pos + Vector3.UP, 5.0, pj.inf(c, "jibaku_bunshin", 1.8, {"knock": 18.0, "launch": 7.0, "kind": "heavy", "element": "bakuton"}))
		pj.shake(0.9))
	Sfx.play("poof", at, 1.0)


## Işınsal hız çizgili kör edici çakma (kameraya dönük dörtgen): beyaz çekirdek, dışa uzanan beyaz ışık şeritleri ve aralarında
## ince koyu gri hız çizgileri (anime kör edici patlama karesi). Kendi shader'ı.
const RAYS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float near = 7.0;
instance uniform float grow = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float rh(float x) {
	return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453);
}

float rn(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(rh(i), rh(i + 1.0), f);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x) / 6.2831853 + 0.5;
	float s1 = rn(a * 46.0);
	float s2 = rn(a * 131.0 + 7.0);
	float reach = 0.35 + 0.6 * s1 * (0.6 + 0.4 * grow);
	float core = 0.24 + 0.1 * s2;
	vec3 col = vec3(1.0);
	float al = 0.0;
	if (r < core) {
		al = 1.0;
	} else if (r < reach) {
		al = (1.0 - smoothstep(reach * 0.6, reach, r)) * (0.55 + 0.45 * s2);
		col = mix(vec3(1.0, 1.0, 0.97), vec3(0.86, 0.95, 1.0), smoothstep(core, reach, r));
	}
	// ince koyu hız çizgileri: beyaz şeritlerin arasında, dış halkada
	float ln = step(0.86, s2) * step(s1, 0.45) * smoothstep(0.45, 0.6, r) * (1.0 - smoothstep(0.85, 1.0, r));
	if (ln > 0.0 && al < 0.5) {
		col = vec3(0.28, 0.29, 0.33);
		al = max(al, ln * 0.85);
	}
	float vis = smoothstep(near * 0.5, near, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2)) * 1.6;
	ALPHA = al * fade * vis;
}
"""


static func _rays_mat() -> ShaderMaterial:
	if _cache.has("rays"):
		return _cache["rays"]
	var sh = Shader.new()
	sh.code = RAYS_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["rays"] = m
	return m


static func _clone_flash(pj: PathJutsu, p: Vector3) -> void:
	var q = QuadMesh.new()
	q.size = Vector2.ONE
	var mi = L.gi(q, _rays_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", 7.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	L.put(pj, mi, p)
	mi.scale = Vector3.ONE * 3.0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 11.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(L.pf(mi, "grow"), 0.0, 1.0, 0.3)
	tw.tween_method(L.pf(mi, "fade"), 1.0, 0.0, 0.3).set_delay(0.2)
	tw.chain().tween_callback(mi.queue_free)
	_fb(pj, p, 0.8, 3.8, 1.2, {"pal": L.PAL_WHITE, "near": 8.0, "rise": 0.6, "cool": 0.9})
	L.light(pj, p, Color(0.92, 0.97, 1.0), 9.0, 22.0, 0.5)
	pj.get_tree().create_timer(0.3).timeout.connect(func():
		for k in 3:
			var a = k * TAU / 3.0 + randf()
			var off = Vector3(cos(a), randf_range(-0.2, 0.3), sin(a)) * 2.4
			_pf(pj, p + off, 1.0, 1.6, off.normalized() * 1.2 + Vector3.UP * 0.6, {"gray": 0.9, "near": 6.0}))
	var g = L.floor_at(p)
	if p.y - g.y < 3.0:
		L.ring(pj, g + Vector3.UP * 0.1, 0.8, 7.5, 0.5, Vector3.UP, {"w": 0.2, "near": 7.0})
		L.soot(pj, g, 3.0, 8.0, {"heat": 0.4})
	L.shrapnel(pj, p, 8, 10.0, 0.14, {"up": 0.4})


# ================================================================== Bakuton Shōgeki
## Gari'nin yer patlaması (anime): yumrukta toplanan kıvılcımlar; vuruşta zemine yapışık yassı turuncu-sarı kubbe, kubbenin
## önünden yatay olarak geçen keskin beyaz şerit (kenardan görülen ince şok halkası) ve havaya kalkan koyu kaya kütleleri.
static func bakuton_shogeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 0.0, 14.0 if tt else 3.0)
	pj.busy(c, 0.6)
	L.converge(pj, pj.hand_pos(c, true), 0.22, 8, 0.7, {"warm": 0.5, "core": 0.35})
	pj.after(0.22, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.3
		_ground_dome(pj, at, c.face_dir())
		_impact_side(pj, at, 1.3)
		pj.hit(c, at, 2.6, pj.inf(c, "bakuton_shogeki", 1.6, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "bakuton"}))
		Sfx.play("boom", at, 1.0))


static func _ground_dome(pj: PathJutsu, at: Vector3, fd: Vector3) -> void:
	var g = L.floor_at(at + fd * 0.6)
	L.flash(pj, at, 3.0, 0.2, {"spikes": 7.0, "warm": 0.7, "near": 5.0})
	_fb(pj, g, 0.5, 2.7, 0.95, {"near": 7.0, "rise": 0.25, "squash": Vector3(1.5, 0.72, 1.5), "heat": 1.0, "cool": 0.8})
	pj.get_tree().create_timer(0.04).timeout.connect(func():
		L.ring(pj, g + Vector3.UP * 0.75, 0.6, 7.5, 0.38, Vector3.UP, {"w": 0.07, "near": 5.0}))
	for k in 6:
		var a = randf() * TAU
		var dv = (Vector3(cos(a), 0, sin(a)) * 0.5 + fd * 0.7).normalized() * randf_range(3.0, 6.0) + Vector3.UP * randf_range(6.0, 9.0)
		L.toss(pj, L.stone(randf_range(0.3, 0.5), 1.5, false), g + Vector3.UP * 0.3, dv, randf_range(0.9, 1.3))
	L.shrapnel(pj, g + Vector3.UP * 0.2, 8, 6.0, 0.12, {"col": L.STONE.darkened(0.3), "up": 1.2, "life": 0.9})
	L.soot(pj, g, 2.2, 6.0, {"heat": 0.7})
	L.light(pj, g + Vector3.UP, Color(1.0, 0.7, 0.35), 5.0, 10.0, 0.4)


# ================================================================== Ningyō Kibaku Nendo
## Sol avuç ağzı kili çiğner; yanında üç kil bebek (anime: öne düşük iri fasulye baş, kara nokta gözler, topuz kollar,
## şişkin baldırlı ince bacaklar) esneyerek doğar ve hoplaya hoplaya koşar. Varınca: yuvarlak kabaran top, kopan kol / bacak /
## baş parçaları savrulur, ayak hizasında küçük halka.
static func ningyo_kibaku_nendo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 24.0)
	for k in 3:
		pj.after(0.2 + k * 0.15, func():
			if not pj.live(c):
				return
			var from = pj.gp(c.global_position + c.face_dir() * 1.0 + c.face_dir().cross(Vector3.UP) * (k - 1) * 0.8) + Vector3.UP * 0.4
			var dir = pj.aim_at(c, tt, from)
			dir.y = 0
			var rig = Node3D.new()
			var doll = L.runner_doll(1.3, 1.4)
			doll.position = Vector3.UP * -0.4
			rig.add_child(doll)
			L.run_cycle(doll, 0.3)
			L.pop_in(doll, 0.2, 1.0)
			var pr = pj.shot(c, from, dir.normalized(), 14.0, rig, pj.inf(c, "ningyo_kibaku_nendo", 0.9, {"knock": 12.0, "launch": 5.0, "kind": "heavy", "element": "bakuton"}), tt, false, 2.5, func(p, _h):
				_doll_pop(pj, p)
				_blast_side(pj, p, 1.3))
			pr.homing_turn = 4.0
			var age = {"t": 0.0}
			pr.on_tick = func(p: Projectile, dt: float) -> void:
				age["t"] += dt
				p.get_child(0).position.y = absf(sin(age["t"] * 12.0)) * 0.5
			L.shrapnel(pj, from - Vector3.UP * 0.3, 4, 2.5, 0.06, {"up": 0.6, "life": 0.6}))
	L.palm_mouth(pj, c, false, 0.6, 0.06)
	Sfx.play("poof", c.global_position, 1.3)


## Kil bebeğin patlaması: yuvarlak top + savrulan uzuvlar + ayak hizasında halka
static func _doll_pop(pj: PathJutsu, p: Vector3) -> void:
	L.flash(pj, p, 2.6, 0.22, {"spikes": 6.0, "near": 5.0})
	_fb(pj, p, 0.4, 1.8, 1.0, {"near": 6.0, "rise": 1.0})
	for k in 5:
		var b = MB.new()
		if k == 0:
			b.add("sphere", Vector3.ZERO, Vector3(0.3, 0.17, 0.26), L.CLAY, Vector3(-18, 0, 0), 10)
			for sx in [-1.0, 1.0]:
				b.add("sphere", Vector3(sx * 0.075, 0.03, -0.12), Vector3(0.03, 0.035, 0.02), L.EYE, Vector3.ZERO, 6)
		else:
			Loft.tube(b, [Vector3(0, 0, -0.16), Vector3(0, 0, 0.0), Vector3(0, 0, 0.16)], [Vector2(0.035, 0.035), Vector2(0.07, 0.07), Vector2(0.02, 0.02)], L.CLAY, 8, 2, true, true)
		var piece = Node3D.new()
		piece.add_child(L.clay_mi(b, 1.0))
		var a = k * TAU / 5.0 + randf() * 0.5
		L.toss(pj, piece, p + Vector3.UP * 0.2, Vector3(cos(a) * randf_range(3.0, 5.0), randf_range(5.0, 8.0), sin(a) * randf_range(3.0, 5.0)), randf_range(0.9, 1.2))
	var g = L.floor_at(p)
	if p.y - g.y < 2.0:
		L.ring(pj, g + Vector3.UP * 0.12, 0.4, 3.2, 0.45, Vector3.UP, {"w": 0.25, "near": 5.0})
		L.soot(pj, g, 1.4, 5.0, {"heat": 0.4})
	L.light(pj, p, Color(1.0, 0.85, 0.6), 4.0, 9.0, 0.4)


# ================================================================== Bakuha Jirai
## Ağızda patlayıcı chakra kıvılcımları toplanır; altı kil topak yay çizerek öne tükürülür, yere basılınca yassılaşıp yarı gömülür
## ve kurulu kaldıkça içten yavaşça nabız gibi ışıldar. Üstüne basılınca: yerden dikey dar sütun halinde fışkıran top, dikine
## uzun çakma, tam yukarı savrulan kil kırıntıları, küçük zemin halkası.
static func bakuha_jirai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.converge(pj, pj._mouth_pos(c), 0.35, 6, 0.6, {"warm": 0.2, "core": 0.3})
	var d = pj.fwd(c, t)
	for k in 6:
		var p = pj.gp(c.global_position + d.rotated(Vector3.UP, (k - 2.5) * 0.35) * (6.0 + (k % 2) * 3.0))
		var mine = L.lump(0.5, 1.2)
		var p0 = c.global_position + Vector3.UP
		L.put(pj, mine, p0)
		var p1 = p + Vector3.UP * 0.12
		var tw = mine.create_tween()
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(mine):
				mine.global_position = p0.lerp(p1, u) + Vector3.UP * sin(u * PI) * 1.4, 0.0, 1.0, 0.35)
		tw.tween_property(mine, "scale", Vector3(1.25, 0.45, 1.25), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if is_instance_valid(mine):
				var pulse = mine.create_tween().set_loops()
				pulse.tween_method(func(v: float) -> void:
					L.sp(mine, "glow", v), 0.0, 0.3, 0.7).set_trans(Tween.TRANS_SINE)
				pulse.tween_method(func(v: float) -> void:
					L.sp(mine, "glow", v), 0.3, 0.0, 0.7).set_trans(Tween.TRANS_SINE))
		var armed = {"on": true}
		pj.after(0.4, func():
			pj.every(15.0, 0.1, func(_i, _k):
				if not armed["on"] or not is_instance_valid(mine):
					return
				if not pj.enemies_near(c, p, 1.6).is_empty():
					armed["on"] = false
					mine.queue_free()
					_jet_column(pj, p)
					_blast_side(pj, p + Vector3.UP * 0.5, 1.3)
					pj.hit(c, p + Vector3.UP, 3.0, pj.inf(c, "bakuha_jirai", 0.8, {"knock": 12.0, "launch": 7.0, "kind": "heavy", "element": "bakuton"}))
					pj.shake(0.5), func():
				if is_instance_valid(mine):
					mine.queue_free()))
	Sfx.play("poof", c.global_position, 1.3)


static func _jet_column(pj: PathJutsu, p: Vector3) -> void:
	var g = L.floor_at(p)
	L.flash(pj, g + Vector3.UP * 0.9, 2.8, 0.22, {"spikes": 4.0, "stretch": Vector2(0.55, 1.9), "near": 5.0})
	_fb(pj, g + Vector3.UP * 0.6, 0.3, 1.4, 1.0, {"near": 6.0, "rise": 2.6, "squash": Vector3(0.55, 1.65, 0.55), "grow": 0.25})
	L.shrapnel(pj, g + Vector3.UP * 0.2, 8, 9.0, 0.08, {"dir": Vector3.UP, "bias": 0.85, "life": 1.1})
	L.ring(pj, g + Vector3.UP * 0.1, 0.3, 2.6, 0.4, Vector3.UP, {"w": 0.3, "near": 5.0})
	L.soot(pj, g, 1.3, 6.0, {"heat": 0.8})


# ================================================================== Bakuha Kibaku Te
## Sağ avuç ağzı kili çiğner; avuç hedefe dayanınca bedene yapışkan kil topağı kalır — nabız gibi atar, iki saniyede içten
## kızarıp çatlar. "Katsu!": bedenin içinden dışa doğru çatlaklardan fışkıran altı dar alev dili, merkezde top, bel hizasında
## yatay halka; ardından artçı çıtırtı kıvılcımları.
static func bakuha_kibaku_te(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt10 = pj.tg(c, t, 10.0)
	L.palm_mouth(pj, c, true, 0.8, 0.05)
	var tt = pj.tg(c, t, 5.0)
	pj.anim(c, "cross", 1.6)
	if tt != null:
		var blob = L.lump(0.5, 0.6)
		pj.attach(tt, blob, 2.0, Vector3(0, tt.height * 0.55, -tt.radius), 2)
		var tw = blob.create_tween().set_loops()
		tw.tween_property(blob, "scale", Vector3.ONE * 0.65, 0.2)
		tw.tween_property(blob, "scale", Vector3.ONE * 0.45, 0.2)
		L.fuse(blob, 2.0, 0.9)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "...", Color(1, 0.85, 0.4))
		pj.after(2.0, func():
			var p = tt.global_position + Vector3.UP if is_instance_valid(tt) else c.global_position
			_inner_burst(pj, p)
			_blast_side(pj, p, 1.8)
			pj.hit(c, p, 3.0, pj.inf(c, "bakuha_kibaku_te", 2.2, {"knock": 16.0, "launch": 8.0, "kind": "heavy", "element": "bakuton", "hitstop": 0.12}))
			Combat.popup_text(p + Vector3.UP * 1.4, "Katsu!", Color(1, 0.9, 0.5))
			pj.shake(0.8))
	if tt10:
		pj.after(2.0, func():
			if pj.live(tt10):
				var q = tt10.global_position + Vector3.UP
				_crackle(pj, q)
				_blast_side(pj, q, 1.2))


static func _inner_burst(pj: PathJutsu, p: Vector3) -> void:
	L.flash(pj, p, 3.2, 0.24, {"spikes": 14.0, "near": 5.0})
	_fb(pj, p, 0.3, 1.3, 0.9, {"near": 6.0, "rise": 0.8})
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.9), randf_range(-1, 1)).normalized()
		_fb(pj, p + dv * 0.4, 0.2, 1.1, 0.7, {"near": 5.0, "rise": 0.4, "dir": dv, "squash": Vector3(0.45, 0.45, 1.9), "vel": dv * 3.0, "grow": 0.25})
	L.ring(pj, p, 0.5, 4.0, 0.4, Vector3.UP, {"w": 0.12, "near": 5.0})
	L.shrapnel(pj, p, 6, 7.0, 0.07, {"up": 0.4})
	L.light(pj, p, Color(1.0, 0.86, 0.6), 5.0, 10.0, 0.4)


static func _crackle(pj: PathJutsu, q: Vector3) -> void:
	L.sparks(pj, q, 26, 0.5, {"vmin": 6.0, "vmax": 13.0, "life": 0.35, "size": 0.09, "damp": 4.0})
	L.flash(pj, q + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.5), randf_range(-0.4, 0.4)), 1.0, 0.14, {"spikes": 4.0, "warm": 1.0, "near": 4.0})


# ================================================================== Bakuha Rensa
## Ayaktan ileri, zeminde parlayan bir fitil tohumu koşar; geçtiği yerde sırayla büyüyen patlamalar öne eğik açılır (her biri
## yön boyunca uzar), arkalarında birbirine değen kurum zinciri; büyükler zemin halkası açar. Aralarda artçı kıvılcım çıtırtıları.
static func bakuha_rensa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	_fuse_runner(pj, c.global_position, d, 21.0, 0.87)
	for k in 7:
		var p = pj.gp(c.global_position + d * (3.0 + k * 3.0))
		pj.after(0.15 + k * 0.12, func():
			_lean_blast(pj, p, d, 0.8 + k * 0.18, k)
			_blast_side(pj, p + Vector3.UP * 0.5, 0.8 + k * 0.18)
			_crack_zone(p, 2.0 + k * 0.3, 6.0)
			pj.hit(c, p + Vector3.UP, 2.0 + k * 0.25, pj.inf(c, "bakuha_rensa", 0.35, {"knock": 9.0, "launch": 5.0, "kind": "heavy", "element": "bakuton"}))
			pj.shake(0.25 + k * 0.05))
	Sfx.play("boom", c.global_position, 0.9)
	for k in 5:
		pj.after(0.2 + k * 0.15, func():
			if pj.live(c):
				var q = pj.gp(c.global_position + d * (3.0 + k * 3.0)) + Vector3.UP
				_crackle(pj, q)
				_blast_side(pj, q, 0.6 + k * 0.15))


## Zeminde koşan parlak fitil tohumu (arkasında soğuyan çizgi kıvılcımları)
static func _fuse_runner(pj: PathJutsu, from: Vector3, d: Vector3, length: float, dur: float) -> void:
	var seed_mi = L.orb_mi(0.45, 0.6, 5.0)
	var p0 = L.floor_at(from + d * 1.0) + Vector3.UP * 0.2
	L.put(pj, seed_mi, p0)
	var tw = seed_mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(seed_mi):
			seed_mi.global_position = L.floor_at(from + d * (1.0 + u * length)) + Vector3.UP * 0.2, 0.0, 1.0, dur)
	tw.tween_callback(seed_mi.queue_free)
	pj.every(dur, 0.06, func(_i, _k):
		if is_instance_valid(seed_mi):
			L.sparks(pj, seed_mi.global_position, 3, 0.05, {"dir": Vector3.UP, "spread": 50.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -4, 0), "life": 0.35, "size": 0.08}))


static func _lean_blast(pj: PathJutsu, p: Vector3, d: Vector3, s: float, k: int) -> void:
	var c0 = p + Vector3.UP * 0.5
	var lean = (d + Vector3.UP * 0.9).normalized()
	L.flash(pj, c0, 2.0 * s, 0.18, {"spikes": 6.0, "warm": 0.3, "near": 6.0})
	_fb(pj, c0 + d * 0.3 * s, 0.3 * s, 1.3 * s, 0.8 + 0.12 * s, {"near": 7.0, "rise": 0.6, "dir": lean, "squash": Vector3(0.85, 0.85, 1.5), "vel": d * 1.6})
	L.shrapnel(pj, c0, 3 + k, 6.0 + 2.0 * s, 0.1, {"dir": d + Vector3.UP, "bias": 0.5, "col": L.STONE, "life": 0.9})
	L.soot(pj, p + d * 0.8, 1.6 * s, 7.0, {"heat": 0.6})
	if k >= 4:
		L.ring(pj, p + Vector3.UP * 0.1, 0.5, 2.8 * s, 0.4, Vector3.UP, {"w": 0.22, "near": 6.0})


# ================================================================== Bakuton Bōgyo
## Bedenin çevresinde bel hizasında yörüngede dönen altı küçük kil tohum (nabız gibi ışıldar); yaklaşan düşman olunca tohumun
## yönünden ona doğru küçük yönlü patlama sıçrar (dışa uzanan top + çakma + yönlü kıvılcım). 5 sn.
static func bakuton_bogyo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	_seed_orbit(pj, c, 5.0)
	pj.every(5.0, 0.15, func(_i, _k):
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, c.global_position, 1.8):
			if pj.live(e):
				var v = e.global_position - c.global_position
				v.y = 0
				_counter_pop(pj, e.global_position + Vector3.UP, v.normalized())
				_explosion_side(pj, e.global_position + Vector3.UP, 0.6)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "bakuton_bogyo", 0.6, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "bakuton", "dir": v.normalized()})), Callable())
	Sfx.play("boom", c.global_position, 1.4)


static func _seed_orbit(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var root = Node3D.new()
	var seeds = []
	for k in 6:
		var sd = L.lump(0.14, 0.5)
		var a = k * TAU / 6.0
		sd.position = Vector3(cos(a), sin(k * 1.7) * 0.25, sin(a)) * 0.75
		root.add_child(sd)
		seeds.append(sd)
	L.put(pj, root, c.global_position + Vector3.UP * 0.9)
	L.pop_in(root, 0.25, 1.0)
	var follow = func(u: float) -> void:
		if not is_instance_valid(root):
			return
		if not is_instance_valid(c):
			root.queue_free()
			return
		root.global_position = c.global_position + Vector3.UP * 0.9
		root.rotation.y = u * dur * 2.6
		for i in seeds.size():
			if is_instance_valid(seeds[i]):
				L.sp(seeds[i], "glow", 0.35 + 0.35 * sin(u * dur * 9.0 + i * 1.3))
	var tw = root.create_tween()
	tw.tween_method(follow, 0.0, 1.0, dur)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(root.queue_free)


static func _counter_pop(pj: PathJutsu, p: Vector3, v: Vector3) -> void:
	var dv = v if v.length() > 0.1 else Vector3.FORWARD
	L.flash(pj, p - dv * 0.3, 1.4, 0.16, {"spikes": 5.0, "warm": 1.0, "near": 4.0})
	_fb(pj, p, 0.25, 0.85, 0.55, {"near": 5.0, "rise": 0.5, "dir": dv, "squash": Vector3(0.7, 0.7, 1.45), "vel": dv * 2.0})
	L.sparks(pj, p, 8, 0.15, {"dir": dv, "spread": 35.0, "vmin": 5.0, "vmax": 10.0, "life": 0.3, "size": 0.08})


# ================================================================== Kibaku Jirai (C2 mayın ejderi)
## Havada kil ejder esneyerek belirir, kanat çırpar; başı aşağı yukarı sallanarak ağzından on iki gözlü kil mayın tükürür,
## sonra çatlayıp ufalanarak kaybolur, ufalanan kil pul pul yağar. Mayın tetiklenince: artı biçimli çifte çakma, yuvarlak
## kabaran top, savrulan mayın kabuğu parçaları, zemin halkası, yarıklı kurum.
static func kibaku_jirai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var dragon = L.dragon(0.75, 7.0)
	var body = c.global_position + Vector3.UP * 5.0 - d * 1.5
	var mouth = body + d * 3.3
	pj.scene_add(dragon, body)
	dragon.look_at(body + d, Vector3.UP)
	L.pop_in(dragon, 0.3, 1.0)
	var head = dragon.get_meta("head", null)
	if head is Node3D and is_instance_valid(head):
		var th = (head as Node3D).create_tween().set_loops(5)
		th.tween_property(head, "rotation:x", -0.35, 0.12)
		th.tween_property(head, "rotation:x", 0.1, 0.16)
	pj.get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(dragon):
			L.tp(dragon, "crack", 0.0, 0.7, 0.3)
			pj.get_tree().create_timer(0.2).timeout.connect(func():
				if is_instance_valid(dragon):
					L.tp(dragon, "melt", 0.0, 1.0, 0.7))
			L.flakes(pj, dragon.global_position, 40, 2.5, {"col0": L.CLAY, "col1": L.CLAY_SHADE, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -3.0, 0), "life": 1.8, "size": 0.25}))
	L.kill(pj, 2.5, dragon)
	var mines = []
	for k in 12:
		var p = pj.gp(c.global_position + d.rotated(Vector3.UP, randf_range(-0.7, 0.7)) * randf_range(4.0, 15.0))
		var m = L.mine(0.8, 1.5)
		pj.scene_add(m, mouth)
		m.look_at(mouth + d, Vector3.UP)
		var tw = m.create_tween()
		tw.tween_property(m, "global_position", p + Vector3.UP * 0.1, 0.35 + k * 0.03).set_trans(Tween.TRANS_QUAD)
		mines.append(m)
	pj.every(15.0, 0.2, func(_i, _k):
		for m in mines:
			if not is_instance_valid(m):
				continue
			if not pj.enemies_near(c, m.global_position, 2.6).is_empty():
				var at = m.global_position
				m.queue_free()
				_cross_blast(pj, at)
				_blast_side(pj, at, 2.2)
				_crack_zone(pj.gp(at), 4.0, 6.0)
				_mhit(pj, c, at, 3.8, pj.inf(c, "kibaku_jirai", 1.0, {"knock": 12.0, "launch": 4.0, "kind": "heavy"})), func():
		for m in mines:
			if is_instance_valid(m):
				m.queue_free())
	Sfx.play("pop", c.global_position, 1.0)


static func _cross_blast(pj: PathJutsu, at: Vector3) -> void:
	var p = at + Vector3.UP * 0.8
	L.flash(pj, p, 4.4, 0.24, {"spikes": 2.0, "stretch": Vector2(1.8, 0.16), "near": 6.0})
	L.flash(pj, p, 4.4, 0.24, {"spikes": 2.0, "stretch": Vector2(0.16, 1.8), "near": 6.0})
	_fb(pj, p, 0.5, 2.3, 1.2, {"near": 7.0, "rise": 1.0})
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.4
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.36, 0.2, 0.3), L.CLAY, Vector3(0, 0, randf() * 40.0), 8)
		if k % 2 == 0:
			b.add("sphere", Vector3(0.06, 0.07, -0.12), Vector3(0.08, 0.09, 0.05), L.EYE, Vector3.ZERO, 6)
		var piece = Node3D.new()
		piece.add_child(L.clay_mi(b, 1.0))
		L.toss(pj, piece, p, Vector3(cos(a) * randf_range(4.0, 7.0), randf_range(5.0, 8.0), sin(a) * randf_range(4.0, 7.0)), randf_range(0.9, 1.3))
	var g = L.floor_at(at)
	L.ring(pj, g + Vector3.UP * 0.1, 0.6, 5.0, 0.45, Vector3.UP, {"w": 0.26, "near": 6.0})
	L.soot(pj, g, 2.4, 7.0, {"heat": 0.6, "cracks": 0.6})
	L.light(pj, p, Color(1.0, 0.86, 0.6), 5.0, 12.0, 0.4)


# ================================================================== Shi Tsū Bakuretsu Hiryū (C2 dalış)
## Kil ejder havada esneyerek belirir, kanat çırparak yükselir; uçtukça içi kızarır, kuyruğundan kıvılcım dökülür. Hedefe
## dalınca: dev sivri çakma, dalış yönünde zemine saplanan uzun top, ardından zemine oturan geniş kubbe, çifte halka (biri ince
## hızlı, biri kalın yavaş), krater kenarından kopan kaya kütleleri, ejderin kil parçaları, geç yağan kül ve ışınsal yarıklı
## dev kurum.
static func shi_tsu_bakuretsu_hiryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 34.0)
	pj.busy(c, 1.0)
	var dragon = L.dragon(0.75, 7.0)
	var from = c.global_position + Vector3.UP * 4.0 - c.face_dir() * 3.0
	pj.scene_add(dragon, from)
	L.pop_in(dragon, 0.3, 1.0)
	var dest = (tt.global_position if is_instance_valid(tt) else c.global_position + pj.fwd(c, t) * 26.0) + Vector3.UP * 0.6
	var mid = from.lerp(dest, 0.5) + Vector3.UP * 8.0
	dragon.look_at(mid, Vector3.UP)
	L.fuse(dragon, 0.9, 0.7)
	pj.every(0.9, 0.08, func(_i, _k):
		if is_instance_valid(dragon):
			L.sparks(pj, dragon.global_position + dragon.global_basis.z * 2.0, 5, 0.4, {"dir": dragon.global_basis.z, "spread": 40.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -5, 0), "life": 0.5, "size": 0.12}))
	var tw = dragon.create_tween()
	tw.tween_property(dragon, "global_position", mid, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): dragon.look_at(dest, Vector3.UP))
	tw.tween_property(dragon, "global_position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_dive_blast(pj, dest, (dest - mid).normalized())
		_blast_side(pj, dest, 5.0)
		_crack_zone(pj.gp(dest), 12.0, 6.0)
		pj.shake(1.4)
		_mhit(pj, c, dest, 8.5, pj.inf(c, "shi_tsu_bakuretsu_hiryu", 2.4, {"knock": 20.0, "launch": 5.0, "kind": "heavy"}))
		dragon.queue_free())
	Sfx.play("whoosh", c.global_position, 0.7)


static func _dive_blast(pj: PathJutsu, p: Vector3, dv: Vector3) -> void:
	var g = L.floor_at(p)
	L.flash(pj, p, 10.0, 0.34, {"spikes": 10.0, "near": 9.0})
	_fb(pj, p - dv * 0.5, 0.8, 3.6, 0.8, {"near": 8.0, "rise": 0.3, "dir": dv, "squash": Vector3(0.7, 0.7, 1.6), "grow": 0.2})
	L.light(pj, p + Vector3.UP * 2.0, Color(1.0, 0.86, 0.6), 10.0, 40.0, 0.8)
	pj.get_tree().create_timer(0.07).timeout.connect(func():
		_fb(pj, g + Vector3.UP * 0.8, 1.5, 6.5, 2.4, {"near": 9.0, "rise": 1.0, "squash": Vector3(1.2, 0.85, 1.2)})
		L.ring(pj, g + Vector3.UP * 0.15, 1.0, 14.0, 0.55, Vector3.UP, {"w": 0.12, "near": 8.0}))
	pj.get_tree().create_timer(0.2).timeout.connect(func():
		L.ring(pj, g + Vector3.UP * 0.2, 0.6, 9.0, 0.9, Vector3.UP, {"w": 0.4, "near": 8.0}))
	for k in 9:
		var a = k * TAU / 9.0 + randf() * 0.3
		var rd = Vector3(cos(a), 0, sin(a))
		L.toss(pj, L.stone(randf_range(0.5, 0.9), 2.0, false), g + rd * 2.5 + Vector3.UP * 0.4, rd * randf_range(5.0, 9.0) + Vector3.UP * randf_range(7.0, 11.0), randf_range(1.2, 1.7))
	L.shrapnel(pj, p, 8, 14.0, 0.4, {"up": 0.8, "life": 1.6})
	L.soot(pj, g, 9.0, 12.0, {"heat": 1.0, "cracks": 1.0, "grow": 0.4})
	pj.get_tree().create_timer(0.6).timeout.connect(func():
		L.flakes(pj, g + Vector3.UP * 7.0, 70, 5.0, {"col0": Color(0.3, 0.29, 0.28), "col1": Color(0.5, 0.48, 0.46), "vmin": 0.3, "vmax": 1.5, "g": Vector3(0, -1.2, 0), "life": 3.2, "size": 0.2, "burst": 0.4}))


# ================================================================== Nendo Kawarimi
## Yer değiştirme anında bedenden kil kırıntıları savrulur; yerinde kaba yoğrulmuş kil ikiz kalır, yarım saniyede içten kızarıp
## çatlar. Patlama: ikizin kabuğu iri kil levhalar halinde dışa saçılır, ortada küçük yuvarlak top, alçakta krem kil tozu topakları.
static func nendo_kawarimi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.3)
	var at = c.global_position
	var twin = L.clay_twin(1.75, 1.6)
	pj.scene_add(twin, pj.gp(at))
	L.look(twin, c.face_dir())
	L.shrapnel(pj, at + Vector3.UP * 1.0, 7, 3.0, 0.07, {"up": 0.4, "life": 0.7})
	var back = pj.gp(at - pj.fwd(c, t) * 7.0)
	c.global_position = back + Vector3.UP * 0.2
	Buffs.add("nendo_kawarimi", 0.6, {"armor": 0.0, "_desc": "kil kopya"})
	L.fuse(twin, 0.5, 0.9)
	L.kill(pj, 1.0, twin)
	pj.after(0.5, func():
		if is_instance_valid(twin):
			var q = twin.global_position + Vector3.UP * 0.9
			_shell_burst(pj, q)
			_blast_side(pj, q, 1.2)
			_mhit(pj, c, q, 3.0, pj.inf(c, "nendo_kawarimi", 1.3, {"knock": 14.0, "launch": 3.0, "kind": "heavy"}))
			twin.queue_free())
	Sfx.play("pop", at, 1.2)


static func _shell_burst(pj: PathJutsu, q: Vector3) -> void:
	L.flash(pj, q, 2.2, 0.2, {"spikes": 8.0, "warm": 0.5, "near": 5.0})
	_fb(pj, q, 0.3, 1.3, 0.85, {"near": 6.0, "rise": 0.8})
	for k in 10:
		var a = k * TAU / 10.0 + randf() * 0.3
		var plate = L.chip(randf_range(0.22, 0.38), L.CLAY, 1.0)
		plate.scale = Vector3(1.0, 1.4, 0.35)
		var piece = Node3D.new()
		piece.add_child(plate)
		var y0 = randf_range(-0.7, 0.7)
		L.toss(pj, piece, q + Vector3(cos(a) * 0.3, y0, sin(a) * 0.3), Vector3(cos(a) * randf_range(4.0, 7.0), randf_range(2.0, 5.0), sin(a) * randf_range(4.0, 7.0)), randf_range(0.9, 1.3))
	var g = L.floor_at(q)
	for k in 3:
		var a = k * TAU / 3.0 + randf()
		var off = Vector3(cos(a), 0, sin(a)) * 0.9
		_pf(pj, g + off + Vector3.UP * 0.35, 0.5, 1.1, off * 1.2, {"gray": 0.15, "near": 5.0, "grow": 1.8})
	L.light(pj, q, Color(1.0, 0.86, 0.6), 4.0, 8.0, 0.35)


# ================================================================== kamera sınırı + yumuşak solma (büyük toplar ekranı kaplamasın)
## Top yüzeyi kameraya 6 m'den fazla yaklaşmasın; en az 0.6 m
static func _cam_cap(pj: PathJutsu, p: Vector3, r: float) -> float:
	var vp = pj.get_viewport()
	var cam = vp.get_camera_3d() if vp else null
	if cam == null:
		return r
	return clampf(cam.global_position.distance_to(p) - 6.0, 0.6, maxf(r, 0.6))


## Kütüphane malzemesinin türevi: kameraya yakın kısım iri dither ızgarası yerine düzgün saydamlıkla söner
static func _soft(key: String, base: ShaderMaterial, cut_old: String, cut_new: String, alb: String, alpha_expr: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var code: String = base.shader.code
	code = code.replace(cut_old, cut_new)
	code = code.replace(alb, "ALPHA = " + alpha_expr + ";" + String.chr(10) + String.chr(9) + alb)
	code = code.replace("depth_draw_opaque", "depth_draw_never")
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _soft_blast() -> ShaderMaterial:
	return _soft("soft_blast", L.blast_mat(), "if (keep < cut || vis < bdith(FRAGCOORD.xy)) {", "if (keep < cut) {",
		"ALBEDO = pow(col, vec3(2.2)) * (1.0 +", "clamp(vis, 0.0, 1.0)")


static func _soft_puff() -> ShaderMaterial:
	return _soft("soft_puff", L.puff_mat(), "if (smoothstep(near * 0.5, near, -VERTEX.z) < bdith(FRAGCOORD.xy)) {", "if (false) {",
		"ALBEDO = pow(col, vec3(2.2));", "smoothstep(near * 0.5, near, -VERTEX.z)")


## Kabaran top: büyüme kameraya göre sınırlı (ezme oranı dahil), yumuşak solan malzeme
static func _fb(pj: PathJutsu, p: Vector3, r0: float, r1: float, life: float, o := {}) -> MeshInstance3D:
	var sq: Vector3 = o.get("squash", Vector3.ONE)
	var k = maxf(1.0, maxf(sq.x, maxf(sq.y, sq.z)))
	var rb = minf(r1, _cam_cap(pj, p, r1 * k) / k)
	var mi = L.fireball(pj, p, minf(r0, rb), rb, life, o)
	mi.material_override = _soft_blast()
	return mi


## Duman topağı: büyümüş boyu kameraya göre sınırlı, yumuşak solan malzeme
static func _pf(pj: PathJutsu, p: Vector3, r: float, life: float, vel := Vector3.ZERO, o := {}) -> MeshInstance3D:
	var g = float(o.get("grow", 1.6))
	var rr = minf(r, _cam_cap(pj, p, r * g) / g)
	var mi = L.puff(pj, p, rr, life, vel, o)
	mi.material_override = _soft_puff()
	return mi
