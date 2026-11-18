class_name DotonFXD
extends RefCounted
## Doton grubu D: on üç toprak tekniğinin görselleri. Malzeme / yapı taşı DotonLib'den (kaya, çamur, toz, zemin izi shader'ları,
## pahlı prizma, döner profil); bu dosyanın kendi shader'ları: Yomi Numa'nın içe dönen yeraltı girdabı, Tsuiga'nın mürekkep mühür
## şeridi, Tsuchigumo'nun doğa enerjisiyle kızaran yarıkları. Her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden
## ayrı. Ortak efekt yardımcısı yok. Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden
## satır satır taşındı.

const DL = preload("res://scripts/combat/fx/lib/doton_lib.gd")
const VX = preload("res://scripts/combat/vfx.gd")   # yalnız destan ölçeği sayısı (epic) okunur; görsel kullanılmaz

static var _cache := {}


# ================================================================== oynanış izi (eski zemin çatlağının oyun tarafı, birebir)
## Yarık zemin: üstünden geçen yavaşlar; boy destan ölçeğiyle büyür (eski çatlak çağrısının bölge kısmı)
static func _zone(pos: Vector3, size: float, dur := 6.0) -> void:
	var s = size * VX.epic
	if s >= 1.5:
		GroundFX.add(pos, "cracked", s * 0.6, clampf(dur, 3.0, 5.0))


# ================================================================== küçük yardımcılar
static func _rng(sd: int) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new()
	r.seed = sd
	return r


## Yerel +Y verilen yöne bakan taban
static func _basis_up(yv: Vector3) -> Basis:
	var y = yv.normalized()
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)


## Yerel +Z yatay yöne bakar (yerel X yan)
static func _yaw(n: Node3D, f: Vector3) -> void:
	n.rotation.y = atan2(f.x, f.z)


## Kalın levha (prizma): w en (yerel X), dp derinlik (yerel Z), h boy (0..h), gerçek ölçüde kurulur (doku metre ölçeğinde ince kalır)
static func _slab_mesh(w: float, dp: float, h: float, sd: int, bevel := 0.12) -> ArrayMesh:
	var key = "slab_%.2f_%.2f_%.2f_%d_%.2f" % [w, dp, h, sd, bevel]
	if _cache.has(key):
		return _cache[key]
	var r = _rng(sd)
	var m = DL.prism_mesh(DL.jag_rect(w, dp, 2, 0.05, r), 0.0, h, bevel, 0.05, sd)
	_cache[key] = m
	return m


static func _shader(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("DNOISE", DL.DNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _light(host: Node, p: Vector3, col: Color, energy: float, rng_m: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	DL.put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Sürekli parçacık akışı (parent'a bağlı): toprak tanesi / chakra zerresi
static func _flow(parent: Node3D, offset: Vector3, amount: int, life: float, col: Color, o := {}) -> GPUParticles3D:
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.DOWN)
	pm.spread = float(o.get("spread", 30.0))
	pm.initial_velocity_min = float(o.get("vmin", 0.5))
	pm.initial_velocity_max = float(o.get("vmax", 2.0))
	pm.gravity = Vector3(0, -float(o.get("g", 9.0)), 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, float(o.get("r", 0.4)))
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color = col
	if o.get("fade", false):
		var g = Gradient.new()
		g.set_color(0, col)
		g.set_color(1, Color(col.r, col.g, col.b, 0.0))
		var gt = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
	var ps = GPUParticles3D.new()
	ps.process_material = pm
	ps.amount = maxi(1, amount)
	ps.lifetime = life
	ps.local_coords = false
	ps.draw_pass_1 = o.get("mesh", DL.chunk_mesh(0, 2, float(o.get("size", 0.05))))
	ps.material_override = o.get("mat", DL.grit_mat())
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	parent.add_child(ps)
	ps.position = offset
	ps.emitting = true
	if o.has("dur"):   # akış bu sürede durur; çıkmış taneler ömrünü doldurur
		var w = weakref(ps)
		ps.get_tree().create_timer(float(o["dur"])).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.emitting = false)
	return ps


static func _bead_mesh(r: float) -> SphereMesh:
	var key = "bead_%.3f" % r
	if not _cache.has(key):
		var s = SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 6
		s.rings = 3
		_cache[key] = s
	return _cache[key]


# ================================================================== 1) Yomi Numa: yeraltı bataklığı (ref: koyu bordo, kenarı açık kuru dudak)
## Hedef noktada zemin koyu kızıl-kahve bir girdaba döner: içe doğru sarmal akış, ortası kapkara; kenarda kuru, açık renk dudak ve
## kopup içeri kayan çimenli toprak levhaları yavaşça batar; ortadan ağır kara kabarcıklar kabarıp çöker; içinde yürüyen düşmanın
## ayağından kara çamur sıçrar. Altı saniye sonra kuruyup delik delik söner.
const YOMI_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float grow = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

DNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = grow * (0.8 + 0.13 * dn(vec2(ang * 1.6 + seed, seed)) + 0.05 * sin(ang * 5.0 + seed * 2.0));
	if (r > edge) {
		discard;
	}
	float k = r / max(edge, 0.001);
	float sw = ang + 2.4 * log(max(r, 0.02)) + TIME * 0.32;
	float bands = df(vec2(sw * 1.4, r * 2.2 - TIME * 0.12) + vec2(seed));
	vec3 col = vec3(0.32, 0.12, 0.09);
	if (bands > 0.56) {
		col = vec3(0.17, 0.06, 0.05);
	}
	float s2 = sin(sw * 3.0 + seed) * 0.5 + 0.5;
	if (s2 > 0.94 && k > 0.2 && k < 0.86) {
		col = vec3(0.46, 0.2, 0.14);
	}
	col = mix(vec3(0.05, 0.015, 0.015), col, smoothstep(0.0, 0.32, k));
	if (k > 0.9) {
		col = vec3(0.13, 0.05, 0.04);
	}
	if (k > 0.955) {
		col = vec3(0.74, 0.64, 0.44);
	}
	float hn = df(p * 4.0 + vec2(seed * 3.0));
	if (fade > 0.0 && hn < fade) {
		discard;
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


static func yomi(js, c: Node3D, t: Node3D) -> void:
	var pos = js._aim_ground(c, t, 8.0)
	pos.y = Game.jutsu_floor(pos.x, pos.z) + 0.05
	var pl = DL.pal(pos)
	var mi = DL.disc(js, pos, 6.0, _shader("yomi", YOMI_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	var vt = mi.create_tween()
	vt.tween_method(DL.pf(mi, "grow"), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	vt.tween_interval(4.6)
	vt.tween_method(DL.pf(mi, "fade"), 0.0, 1.0, 0.65)
	DL.dust_ring(js, pos, 1.0, 4.5, 6, 1.0, 0.9, pl["dust"])
	Sfx.play("earth", pos, 0.7)
	# kenar: kopan çimenli toprak levhaları içe kayıp batar (dünya yutuluyor)
	for i in 9:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / 9.0
		var dv = Vector3(cos(a), 0.0, sin(a))
		var p0 = DL.floor_at(pos + dv * randf_range(4.6, 5.6))
		var sl = DL.rock(_slab_mesh(randf_range(0.9, 1.4), randf_range(0.7, 1.0), 0.3, i), pl["body"], {"ow": 0.025, "top": pl["top"], "top_y": 0.2})
		DL.put(js, sl, p0 - Vector3.UP * 0.12)
		_yaw(sl, -dv)
		sl.rotation.x = -randf_range(0.15, 0.35)
		var dl = randf_range(0.6, 2.2)
		var tw = sl.create_tween()
		tw.tween_interval(dl)
		tw.tween_property(sl, "global_position", p0 - dv * randf_range(1.2, 2.2) - Vector3.UP * 0.75, 5.8 - dl).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(sl, "rotation:x", -0.9, 5.8 - dl)
		tw.tween_callback(sl.queue_free)
	# kenar dudağı: yarı gömük kuru toprak topakları
	for i in 14:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / 14.0
		var ck = DL.chunk(randf_range(0.28, 0.42), 0, pl["dust"].darkened(randf_range(0.05, 0.2)), {"ow": 0.02, "upright": true})
		DL.put(js, ck, DL.floor_at(pos + Vector3(cos(a), 0, sin(a)) * randf_range(5.7, 6.1)) - Vector3.UP * 0.35)
		var tw = ck.create_tween()
		tw.tween_property(ck, "position:y", ck.position.y + 0.25, 0.4).set_delay(0.3 + randf() * 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(4.8)
		tw.tween_property(ck, "position:y", ck.position.y - 0.4, 0.5)
		tw.tween_callback(ck.queue_free)
	var sink = Color(0.14, 0.05, 0.04)
	var gt = mi.create_tween()
	for i in 20:
		gt.tween_callback(func():
			# ortadan ağır kara kabarcık: yavaş kabarır, sonra delinerek çöker
			if i % 2 == 0:
				var a = randf() * TAU
				var b = DL.mud_blob(randf_range(0.35, 0.6), sink, 0.03)
				DL.put(js, b, DL.floor_at(pos + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 3.5)) + Vector3.UP * 0.02)
				var s = b.scale
				b.scale = s * Vector3(1.0, 0.05, 1.0)
				var bt = b.create_tween()
				bt.tween_property(b, "scale", s * Vector3(1.1, 0.6, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
				bt.tween_method(DL.pf(b, "melt"), 0.0, 1.0, 0.35)
				bt.tween_callback(b.queue_free)
			for f in js.get_tree().get_nodes_in_group("fighters"):
				if Combat.hostile(c, f) and f.global_position.distance_to(pos) < 6.0 and f.has_method("apply_status"):
					f.apply_status("slow", 0.6)
					if i % 2 == 1:
						var fp = DL.floor_at(f.global_position)
						for j in 2:
							var dd = DL.mud_blob(randf_range(0.1, 0.16), sink.lightened(0.08), 0.02)
							var a2 = randf() * TAU
							DL.toss(js, dd, fp + Vector3.UP * 0.1, Vector3(cos(a2) * 1.2, randf_range(2.0, 3.2), sin(a2) * 1.2), 0.6, 18.0, 0.3))
		gt.tween_interval(0.3)
	gt.tween_callback(mi.queue_free)


# ================================================================== 2) Goremu: toprak golem (ref: Kitsuchi / Ōnoki taş devi)
## Avuç yere iner, önde zemin tümsek gibi kabarır, tümseğin yüzü yarılır ve kırılıp dışa savrulur; golem toprağın içinden
## omuzlarından toprak dökerek yükselir. Çağırma yerinde yarık zemin kalır.
static func goremu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd = c.face_dir()
	var p25 = pj.gp(c.global_position + fd * 2.5)
	_zone(p25, 2.2 * 1.6)
	_zone(p25, 6.0)
	var gat = pj.gp(c.global_position + fd * 4.5)
	var pl = DL.pal(gat)
	pj.anim(c, "crouch", 1.3)
	DL.crack(pj, p25, 2.4, 6.0, 0.2, 0.0, 6.0)
	# tümsek: çimen örtülü, oluklu toprak kubbe
	var prof = PackedVector2Array([Vector2(2.4, -0.4), Vector2(2.1, 0.5), Vector2(1.5, 1.25), Vector2(0.7, 1.7), Vector2(0.0, 1.8)])
	var mound = DL.rock(DL.lathe_mesh(prof, 14, 6.0, 0.12, 0.05, randi() % 50), pl["body"], {"ow": 0.035, "top": pl["top"], "top_y": 1.0, "strata": 2.2})
	DL.put(pj, mound, gat - Vector3.UP * 1.9)
	mound.rotation.y = randf() * TAU
	var mt = mound.create_tween()
	mt.tween_property(mound, "global_position", gat - Vector3.UP * 0.2, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_interval(0.15)
	mt.tween_property(mound, "global_position", gat - Vector3.UP * 2.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	mt.tween_callback(mound.queue_free)
	DL.crack(pj, gat, 3.2, 6.0, 0.35, 0.0, 9.0)
	pj.after(0.45, func():
		# tümsek yarılır: parçalar yanlara ve geriye savrulur (kameraya doğru değil)
		var cam = pj.get_viewport().get_camera_3d()
		var toc = DL.flat(cam.global_position - gat) if cam else -fd
		for i in 12:
			var a = TAU * (i + randf_range(-0.3, 0.3)) / 12.0
			var dv = Vector3(cos(a), 0, sin(a))
			if dv.dot(toc) > 0.4:
				dv = (dv - toc * 1.2).normalized()
			var ck = DL.chunk(randf_range(0.25, 0.5), randi() % 3, pl["body"].darkened(randf_range(0.0, 0.15)), {"ow": 0.03, "top": pl["top"], "top_y": 0.5})
			DL.toss(pj, ck, gat + dv * 1.4 + Vector3.UP * 1.0, dv * randf_range(4.0, 7.0) + Vector3.UP * randf_range(4.0, 7.0), 1.1)
		DL.grit(pj, gat + Vector3.UP * 0.8, 30, pl["body"], {"dir": Vector3.UP, "spread": 70.0, "vmin": 3.0, "vmax": 8.0, "r": 1.2, "life": 0.9})
		DL.dust_ring(pj, gat, 1.6, 4.0, 7, 1.2, 1.0, pl["dust"])
		pj.shake(0.5))
	var units = ClanConstruct.spawn(c, "golem", 1, Jutsu._jd("doton_goremu_no_jutsu"))
	Sfx.play("earth", c.global_position, 0.5)
	for u in units:
		var v = u.get("vis")
		if v is Node3D:
			var y0 = v.position.y
			v.position.y = y0 - 3.2
			var vt = v.create_tween()
			vt.tween_property(v, "position:y", y0, 0.85).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		# omuzlardan dökülen toprak
		var src = Node3D.new()
		u.add_child(src)
		src.position = Vector3(0, 3.0, 0)
		_flow(src, Vector3.ZERO, 40, 0.9, pl["body"], {"dir": Vector3.DOWN, "spread": 60.0, "vmin": 0.5, "vmax": 2.0, "g": 14.0, "r": 1.1, "size": 0.07, "dur": 1.0})
		DL.kill(pj, 2.1, src)
		for j in 4:
			pj.after(0.5 + j * 0.15, func():
				if is_instance_valid(u):
					var a = randf() * TAU
					var ck = DL.chunk(randf_range(0.15, 0.28), 0, pl["body"], {"ow": 0.025})
					DL.toss(pj, ck, u.global_position + Vector3(cos(a) * 1.2, 2.8, sin(a) * 1.2), Vector3(cos(a) * 1.5, 1.0, sin(a) * 1.5), 1.0))


# ================================================================== 3) Ressenga: yaran matkap dişi (ref: Kakashi, radyal toprak patlaması)
## Yumruğun çevresinde sarmal dizilmiş kaya kıymıkları matkap gibi döner, koşu boyunca taneler saçılır; yere / hedefe çarpınca
## zemin sarmal yarılır ve önüne doğru yelpaze gibi açılan, dışa yatık iki sıra kaya dişi fışkırır (ref: ışınsal patlama).
static func ressenga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 0.0, 14.0 if tt else 3.0)
	pj.busy(c, 0.9)
	var pl = DL.pal(c.global_position)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var piv = Node3D.new()
		ba.add_child(piv)
		for k in 8:
			var f = float(k) / 7.0
			var sh = DL.rock(DL.chunk_mesh(1, k), pl["stone"].lerp(pl["body"], 0.4), {"ow": 0.012})
			sh.scale = Vector3.ONE * lerpf(0.13, 0.06, f)
			var a = k * 1.7
			var rr = 0.2 * (1.0 - f * 0.65)
			sh.position = Vector3(cos(a) * rr, sin(a) * rr, 0.12 + f * 0.8)
			sh.rotation = Vector3(PI * 0.5, 0.0, a)
			piv.add_child(sh)
		Game.safe_loops(piv.create_tween()).tween_property(piv, "rotation:z", TAU, 0.12).from(0.0)
		pj.free_after(0.9, ba)
	pj.every(0.6, 0.1, func(_i, _k):
		if pj.live(c):
			DL.grit(pj, c.global_position + Vector3.UP * 1.0 + d * 1.2, 5, pl["body"], {"dir": -d + Vector3.UP * 0.3, "spread": 35.0, "vmin": 2.0, "vmax": 5.0, "r": 0.2, "life": 0.45, "size": 0.05}), Callable())
	pj.after(0.35, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = pj.gp(c.global_position + d * 1.4)
		_zone(at, 4.0)
		var pl2 = DL.pal(at)
		DL.crack(pj, at, 2.6, 5.0, 0.15, 7.0, 8.0)
		DL.pit(pj, at, 0.8, 4.0, 0.1)
		for k in 10:
			var row = k % 2
			var ang = lerpf(-0.75, 0.75, float(k) / 9.0) + randf_range(-0.08, 0.08)
			var dir = d.rotated(Vector3.UP, ang)
			var q = DL.floor_at(at + dir * (0.7 + row * 1.0 + randf_range(0.0, 0.3)))
			var ln = 0.75 + row * 0.55 + randf_range(0.0, 0.25)
			var fang = DL.rock(DL.chunk_mesh(1, k, ln * 0.6), pl2["stone"].lerp(pl2["body"], 0.35).darkened(randf_range(0.0, 0.12)), {"ow": 0.03, "strata": 3.0})
			DL.put(pj, fang, q)
			fang.basis = _basis_up(Vector3.UP * cos(0.75) + dir * sin(0.75) * randf_range(0.8, 1.2))
			fang.scale = Vector3.ONE * 0.05
			var tw = fang.create_tween()
			tw.tween_interval(k * 0.025 + row * 0.04)
			tw.tween_property(fang, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.4)
			tw.tween_property(fang, "scale", Vector3.ONE * 0.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(fang.queue_free)
		for i in 7:
			var dv = d.rotated(Vector3.UP, randf_range(-0.9, 0.9))
			var ck = DL.chunk(randf_range(0.14, 0.3), randi() % 3, pl2["body"].darkened(randf_range(0.0, 0.15)), {"ow": 0.025})
			DL.toss(pj, ck, at + Vector3.UP * 0.5, dv * randf_range(5.0, 9.0) + Vector3.UP * randf_range(3.0, 6.0), 1.0)
		DL.grit(pj, at + Vector3.UP * 0.3, 26, pl2["body"], {"dir": (d + Vector3.UP).normalized(), "spread": 55.0, "vmin": 4.0, "vmax": 10.0, "r": 0.5, "life": 0.8})
		DL.dust(pj, at + d * 1.8 + Vector3.UP * 0.6, 1.6, 0.8, d * 2.0, pl2["dust"])
		pj.hit(c, at + Vector3.UP, 2.2, pj.inf(c, "doton_ressenga", 1.8, {"knock": 14.0, "kind": "heavy", "element": "doton", "bleed": 2.0}))
		Sfx.play("earth", at, 1.0))


# ================================================================== 4) Chōkajūgan: süper ağırlık (ref: Ōnoki — çokgen yarılan zemin, yaprak gibi kalkan levhalar)
## Dokunulan hedefin bedeni taş gibi ağırlaşır: üstünden aşağı ağır toprak tozu süzülür, model yere gömülür; altındaki zemin
## çokgen levhalara bölünüp dış kenarları yukarı kalkacak biçimde içe çöker (taç yaprağı gibi); her ağırlık vuruşunda levhalar
## biraz daha yatar, ayak altından çakıl fışkırır. Sonunda levhalar düşüp toprağa gömülür.
static func chokajugan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt10 = pj.tg(c, t, 10.0)
	# --- ana ağaçtaki c_doton_chokajugan_no_jutsu (oynanış birebir)
	var tt = pj.tg(c, t, 6.0)
	if tt == null:
		Hud.msg("Chōkajūgan: hedefe dokunmalısın (6 m)", Color(0.85, 0.8, 0.7))
	else:
		pj.anim(c, "cross", 1.2)
		pj.st(tt, "bind", 4.0)
		var p = pj.gp(tt.global_position)
		_zone(p, 4.5)
		var pl = DL.pal(p)
		DL.pit(pj, p, 1.1, 4.6, 0.15)
		if tt.get("model"):
			var tw = tt.model.create_tween()
			tw.tween_property(tt.model, "position:y", -0.45, 0.2)
			tw.tween_property(tt.model, "position:y", 0.0, 0.3).set_delay(3.6)
		# beden etkisi: omuzlardan aşağı çakılan ağır toz (hedefe bağlı)
		var hgt = float(tt.get("height")) if tt.get("height") != null else 1.8
		var src = Node3D.new()
		tt.add_child(src)
		src.position = Vector3(0, hgt * 0.95, 0)
		_flow(src, Vector3.ZERO, 36, 0.45, pl["dust"].darkened(0.15), {"dir": Vector3.DOWN, "spread": 12.0, "vmin": 4.0, "vmax": 7.0, "g": 30.0, "r": 0.45, "size": 0.035, "dur": 3.8})
		DL.kill(pj, 4.4, src)
		# çöken levhalar: iç kenarda menteşe, dış kenar kalkar
		var plates = []
		for i in 7:
			var a = TAU * (i + randf_range(-0.15, 0.15)) / 7.0
			var dv = Vector3(cos(a), 0, sin(a))
			var hinge = Node3D.new()
			DL.put(pj, hinge, DL.floor_at(p + dv * 0.55) - Vector3.UP * 0.05)
			_yaw(hinge, dv)
			var sl = DL.rock(_slab_mesh(randf_range(1.1, 1.5), 1.5, 0.28, i + 11), pl["body"], {"ow": 0.03, "top": pl["top"], "top_y": 0.18, "strata": 5.0})
			hinge.add_child(sl)
			sl.position = Vector3(0, -0.24, 0.78)
			var tw = hinge.create_tween()
			tw.tween_interval(0.05 + i * 0.02)
			tw.tween_property(hinge, "rotation:x", -randf_range(0.45, 0.65), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			plates.append(hinge)
		pj.every(4.0, 1.0, func(_i, _k):
			if pj.live(tt):
				pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, "doton_chokajugan_no_jutsu", 0.3, {"knock": 0.0, "kind": "light"}))
				DL.grit(pj, pj.gp(tt.global_position) + Vector3.UP * 0.1, 12, pl["body"], {"dir": Vector3.UP, "spread": 85.0, "vmin": 2.0, "vmax": 4.0, "r": 0.5, "life": 0.5})
			for h in plates:
				if is_instance_valid(h):
					h.create_tween().tween_property(h, "rotation:x", h.rotation.x - 0.08, 0.12).set_trans(Tween.TRANS_BACK), func():
			for h in plates:
				if is_instance_valid(h):
					var t2 = h.create_tween()
					t2.tween_property(h, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					t2.tween_property(h, "position:y", h.position.y - 0.5, 0.6)
					t2.tween_callback(h.queue_free))
		for h in plates:
			DL.kill(pj, 6.0, h)
		pj.shake(0.5)
		Sfx.play("earth", p, 0.5)
	# --- p_ katmanı: 0.3 sn sonra geniş çökme
	if tt10:
		pj.after(0.3, func():
			if pj.live(tt10):
				var g = pj.gp(tt10.global_position)
				_zone(g, 9.0)
				var pl3 = DL.pal(g)
				DL.crack(pj, g, 5.0, 6.0, 0.2, 0.0, 10.0)
				DL.ripple(pj, g, 6.0, 0.7)
				DL.dust_ring(pj, g, 1.5, 4.0, 6, 1.1, 0.9, pl3["dust"])
				# çökmeyle dikine fışkıran toz sütunu yerine ince çakıl perdesi (ref'teki dikey toz çizgileri)
				DL.grit(pj, g + Vector3.UP * 0.2, 30, pl3["dust"].darkened(0.1), {"dir": Vector3.UP, "spread": 18.0, "vmin": 6.0, "vmax": 11.0, "r": 1.2, "life": 0.9, "size": 0.05})
				pj.shake(0.7))


# ================================================================== 5) Ganbankyū: kaya tabut (iki levha kapanır)
## Hedefin iki yanında katmanlı iki dev kaya levha yerden dikilir ve kitap kapağı gibi üstüne kapanır; ek yerinden yukarı kıymık,
## iki açık uçtan ileri-geri toz ve çakıl fışkırır. Kısa tutuştan sonra levhalar toprağa geri iner.
static func ganbankyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var pl = DL.pal(at)
	DL.crack(pj, at, 2.4, 4.0, 0.2, 0.0, 5.0)
	for s in [-1.0, 1.0]:
		var hinge = Node3D.new()
		DL.put(pj, hinge, at + side * s * 2.4 - Vector3.UP * 3.8)
		_yaw(hinge, d)
		var slab = DL.rock(_slab_mesh(0.8, 3.4, 3.6, int(s + 3)), pl["stone"].lerp(pl["body"], 0.5), {"ow": 0.04, "strata": 1.6, "top": pl["top"], "top_y": 3.45})
		hinge.add_child(slab)
		slab.position = Vector3(0, 0, 0)
		var tw = hinge.create_tween()
		tw.tween_property(hinge, "global_position", at + side * s * 2.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hinge, "global_position", at + side * s * 0.55, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(hinge, "rotation:z", -s * 0.16, 0.18)
		tw.tween_interval(1.4)
		tw.tween_property(hinge, "global_position", at + side * s * 0.9 - Vector3.UP * 3.9, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(hinge.queue_free)
		DL.grit(pj, at + side * s * 2.4, 14, pl["body"], {"dir": Vector3.UP, "spread": 40.0, "vmin": 3.0, "vmax": 6.0, "r": 1.0, "life": 0.6})
	pj.after(0.43, func():
		for e2 in [-1.0, 1.0]:
			var end = at + d * e2 * 1.9 + Vector3.UP * 0.9
			DL.grit(pj, end, 16, pl["body"], {"dir": (d * e2 + Vector3.UP * 0.25).normalized(), "spread": 25.0, "vmin": 6.0, "vmax": 11.0, "r": 0.4, "life": 0.6})
			DL.dust(pj, DL.floor_at(end) + Vector3.UP * 0.5 + d * e2 * 0.6, 1.3, 0.8, d * e2 * 3.0, pl["dust"])
		for i in 5:
			var ck = DL.chunk(randf_range(0.12, 0.22), 1, pl["stone"], {"ow": 0.02})
			DL.toss(pj, ck, at + Vector3.UP * 3.5 + d * randf_range(-1.4, 1.4), Vector3(randf_range(-1, 1), randf_range(5.0, 8.0), randf_range(-1, 1)), 1.2))
	pj.after(0.45, func():
		pj.shake(0.6)
		for e in pj.enemies_near(c, at, 2.2):
			if pj.live(e):
				if e.has_method("apply_status"):
					e.apply_status("bind", 1.6)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "doton_ganbankyu", 1.8, {"knock": 0.0, "kind": "heavy", "element": "doton"})))
	Sfx.play("earth", at, 0.8)


# ================================================================== 6) Daichi Dōkaku: yer çekirdeği oynar
## Hedefin altında dairesel bir fay açılır, koca bir toprak plato (üstü çimenli, yanları katmanlı) birden yükselip hedefi fırlatır,
## fay çizgisi boyunca köşeli kaya blokları yırtılıp kalkar; sonra plato ağır ağır yerine oturur. Çağıran yakındaysa platonun ona
## bakan dilimi açık kalır (kamera ile çağıran arasına duvar girmesin).
static func daichi_dokaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	_zone(at, 9.0, 5.0)
	var pl = DL.pal(at)
	DL.crack(pj, at, 6.8, 5.0, 0.25, 0.0, 12.0)
	var near = c.global_position.distance_to(at) < 8.5
	var prof = PackedVector2Array([Vector2(6.1, -2.6), Vector2(6.0, -0.7), Vector2(5.8, 0.0), Vector2(5.3, 0.18), Vector2(2.5, 0.24), Vector2(0.0, 0.26)])
	var plat = DL.rock(DL.lathe_mesh(prof, 30, 9.0, 0.06, 0.04, 77, TAU * 0.72 if near else TAU), pl["body"], {"ow": 0.05, "top": pl["top"], "top_y": 0.05, "strata": 1.4})
	DL.put(pj, plat, at - Vector3.UP * 0.3)
	if near:
		DL.look(plat, DL.flat(c.global_position - at))   # açık dilim (-Z) çağırana
	var tw = plat.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(plat, "global_position", at + Vector3.UP * 1.6, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(plat, "global_position", at - Vector3.UP * 0.1, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(plat, "global_position", at - Vector3.UP * 3.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(plat.queue_free)
	for k in 10:
		var a = TAU * k / 10.0
		var dv = Vector3(cos(a), 0, sin(a))
		var q = DL.floor_at(at + dv * 6.5)
		var blk = DL.rock(DL.chunk_mesh(2, k, 1.6), pl["body"].darkened(randf_range(0.0, 0.15)), {"ow": 0.04, "top": pl["top"], "top_y": 0.45, "strata": 2.0})
		blk.rotation = Vector3(0, randf() * TAU, 0)
		DL.rise(pj, blk, q + Vector3.UP * 0.6, 2.4, 0.2, 1.6, 0.6, 0.1 + k * 0.03)
		var tl = blk.create_tween()
		tl.tween_interval(0.1 + k * 0.03)
		tl.tween_property(blk, "rotation", Vector3(-dv.z * 0.35, blk.rotation.y, dv.x * 0.35), 0.25)
	pj.after(0.3, func():
		for e in pj.enemies_near(c, at, 7.0):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "doton_daichi_dokaku", 1.4, {"knock": 4.0, "launch": 9.0, "kind": "heavy", "element": "doton"}))
		DL.grit(pj, at + Vector3.UP * 1.6, 40, pl["body"], {"dir": Vector3.UP, "spread": 80.0, "vmin": 4.0, "vmax": 9.0, "r": 5.0, "life": 1.0})
		DL.dust_ring(pj, at, 6.2, 9.0, 10, 1.4, 1.1, pl["dust"])
		pj.shake(1.2))
	Sfx.play("earth", at, 0.5)


# ================================================================== 7) Tekkenrō: demir hapis (ref: daire çevirmiş gri taş paneller, içi kabarık toprak)
## Hedefin çevresinde gri taş panellerden bir halka duvar sırayla dikilir; içi kabarık toprak topakları ve toz yumaklarıyla dolar
## (ref). Her sıkıştırmada paneller içe kasılır ve içten çakıl fışkırır. Süre bitince paneller içe yıkılıp gömülür.
static func tekkenro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var pl = DL.pal(at)
	var cam = pj.get_viewport().get_camera_3d()
	var toc = DL.flat(cam.global_position - at) if cam else Vector3.ZERO
	var grey = Color(0.66, 0.66, 0.64).lerp(pl["stone"], 0.25)
	var panels = []
	var n = 14
	var R = 2.75
	for k in n:
		var a = TAU * k / n
		var dv = Vector3(cos(a), 0, sin(a))
		var h = 3.0 - 0.7 * maxf(0.0, dv.dot(toc))   # kamera tarafı biraz alçak
		var pn = DL.rock(_slab_mesh(2.0 * PI * R / n * 0.96, 0.32, h, 40 + k, 0.04), grey.darkened(randf_range(0.0, 0.06)), {"ow": 0.03})
		var base = DL.floor_at(at + dv * R)
		DL.put(pj, pn, base - Vector3.UP * (h + 0.2))
		_yaw(pn, dv)
		var tw = pn.create_tween()
		tw.tween_interval(k * 0.018)
		tw.tween_property(pn, "global_position", base - Vector3.UP * 0.1, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		panels.append([pn, dv, base])
		DL.kill(pj, 4.2, pn)
	DL.crack(pj, at, 3.4, 4.0, 0.2, 0.0, 8.0)
	DL.grit(pj, at + Vector3.UP * 0.4, 24, pl["body"], {"dir": Vector3.UP, "spread": 50.0, "vmin": 3.0, "vmax": 7.0, "r": R, "life": 0.7})
	pj.after(0.4, func():
		_zone(at, 3.5)
		# iç dolgu: kabarık toprak topakları (hacim) + üstte toz yumakları
		var fill = Node3D.new()
		DL.put(pj, fill, at)
		for i in 11:
			var a = randf() * TAU
			var rr = sqrt(randf()) * (R - 0.7)
			var lp = DL.rock(DL.chunk_mesh(0, i, randf_range(0.55, 0.85)), pl["dust"].darkened(randf_range(0.15, 0.3)), {"ow": 0.03})
			lp.position = Vector3(cos(a) * rr, randf_range(0.6, 2.0), sin(a) * rr)
			lp.rotation = Vector3(randf(), randf() * TAU, randf())
			fill.add_child(lp)
			lp.scale = Vector3.ONE * 0.05
			lp.create_tween().tween_property(lp, "scale", Vector3.ONE, 0.25).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK)
		var ft = fill.create_tween()
		ft.tween_interval(2.6)
		ft.tween_property(fill, "position:y", fill.position.y - 2.6, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ft.tween_callback(fill.queue_free)
		for e in pj.enemies_near(c, at, 2.4):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("bind", 2.4)
		pj.every(2.4, 0.6, func(_i, _k):
			for e in pj.enemies_near(c, at, 2.4):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "doton_tekkenro", 0.45, {"knock": 0.0, "kind": "heavy", "element": "doton"}))
			for pp in panels:
				var pn2 = pp[0]
				if is_instance_valid(pn2):
					var t2 = pn2.create_tween()
					t2.tween_property(pn2, "global_position", pp[2] - Vector3.UP * 0.1 - pp[1] * 0.18, 0.08)
					t2.tween_property(pn2, "global_position", pp[2] - Vector3.UP * 0.1, 0.2).set_trans(Tween.TRANS_BACK)
			for j in 3:
				var a3 = randf() * TAU
				DL.dust(pj, at + Vector3(cos(a3), 0, sin(a3)) * randf_range(0.0, 1.4) + Vector3.UP * randf_range(2.2, 3.0), 1.3, 1.0, Vector3.UP * 0.6, pl["dust"])
			DL.grit(pj, at + Vector3.UP * 2.6, 10, pl["body"], {"dir": Vector3.UP, "spread": 30.0, "vmin": 3.0, "vmax": 6.0, "r": 1.4, "life": 0.6}), func():
			for pp in panels:
				var pn3 = pp[0]
				if is_instance_valid(pn3):
					var t3 = pn3.create_tween()
					t3.tween_property(pn3, "rotation:x", -0.5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					t3.parallel().tween_property(pn3, "global_position", pp[2] - Vector3.UP * 3.4, 0.5).set_delay(0.15)))
	Sfx.play("earth", at, 0.7)


# ================================================================== 8) Chōkeijūgan: süper hafiflik (Ōnoki — dev kayayı tüy gibi kaldırıp fırlatır)
## Çağıranın bedeni hafifler: üstünden ince taneler yukarı süzülür, model hafifçe havalanıp salınır. Önündeki zemin yırtılır,
## çimen örtülü dev kaya altından toprak dökerek yavaşça yükselir (geride çukur), sonra hedefe düşer: çukur, yarık, yere saplanan
## parçalar; kaya kendisi ikiye ayrılıp toprağa gömülür.
static func chokeijugan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var at = pj.gp(c.global_position + c.face_dir() * 3.0)
	var pl = DL.pal(at)
	var boulder = DL.rock(DL.chunk_mesh(0, randi() % 6, 2.4), pl["stone"].lerp(pl["body"], 0.5), {"ow": 0.06, "top": pl["top"], "top_y": 1.25, "strata": 1.2, "shadow": true})
	boulder.scale = Vector3(1.04, 0.94, 1.04)
	DL.put(pj, boulder, at + Vector3.UP * 2.0)
	DL.pit(pj, at, 2.6, 4.0, 0.25)
	DL.crack(pj, at, 3.5, 4.0, 0.2, 0.0, 8.0)
	var under = Node3D.new()
	boulder.add_child(under)
	under.position = Vector3(0, -1.6, 0)
	_flow(under, Vector3.ZERO, 40, 0.9, pl["body"], {"dir": Vector3.DOWN, "spread": 40.0, "vmin": 0.2, "vmax": 1.2, "g": 14.0, "r": 1.4, "size": 0.08, "dur": 0.8})
	DL.kill(pj, 1.8, under)
	# beden etkisi: yukarı süzülen ince taneler + hafif salınım
	var lift = Node3D.new()
	c.add_child(lift)
	lift.position = Vector3(0, 0.9, 0)
	_flow(lift, Vector3.ZERO, 26, 1.3, Color(0.92, 0.88, 0.76, 0.9), {"dir": Vector3.UP, "spread": 25.0, "vmin": 0.4, "vmax": 1.2, "g": -1.5, "r": 0.5, "size": 0.03, "fade": true, "mat": DL.bead_mat(Color(1, 0.96, 0.85)), "dur": 2.6})
	DL.kill(pj, 4.0, lift)
	var m = c.get("model")
	if m and is_instance_valid(m):
		var y0 = m.position.y
		var bt = m.create_tween()
		bt.tween_property(m, "position:y", y0 + 0.16, 0.5).set_trans(Tween.TRANS_SINE)
		bt.tween_property(m, "position:y", y0 + 0.06, 0.8).set_trans(Tween.TRANS_SINE)
		bt.tween_property(m, "position:y", y0 + 0.14, 0.8).set_trans(Tween.TRANS_SINE)
		bt.tween_property(m, "position:y", y0, 0.5).set_trans(Tween.TRANS_SINE)
	if c is Player:
		Buffs.add("doton_chokeijugan", 8.0, {"speed": 1.4})
	var tt = pj.tg(c, t, 34.0)
	var tw = boulder.create_tween()
	tw.tween_property(boulder, "global_position", at + Vector3.UP * 8.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(boulder, "rotation:y", boulder.rotation.y + 0.6, 0.8)
	tw.tween_callback(func():
		var dest = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 18.0)
		var tw2 = boulder.create_tween()
		tw2.tween_property(boulder, "global_position", dest + Vector3.UP * 1.8, 0.45).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(boulder, "rotation:x", boulder.rotation.x + 1.1, 0.45)
		tw2.tween_callback(func():
			_zone(dest, 6.0, 5.0)
			var pl2 = DL.pal(dest)
			DL.pit(pj, dest, 3.4, 6.0, 0.12)
			DL.crack(pj, dest, 6.0, 5.0, 0.15, 0.0, 11.0)
			var cam = pj.get_viewport().get_camera_3d()
			var toc = DL.flat(cam.global_position - dest) if cam else Vector3.ZERO
			for i in 14:
				var a = TAU * (i + randf_range(-0.3, 0.3)) / 14.0
				var dv = Vector3(cos(a), 0, sin(a))
				if dv.dot(toc) > 0.5:
					dv = (dv - toc).normalized()
				var ck = DL.chunk(randf_range(0.3, 0.65), randi() % 3, pl2["body"].darkened(randf_range(0.0, 0.18)), {"ow": 0.035, "top": pl2["top"], "top_y": 0.5})
				DL.toss(pj, ck, dest + dv * 1.5 + Vector3.UP * 0.6, dv * randf_range(6.0, 11.0) + Vector3.UP * randf_range(5.0, 9.0), 1.3)
			DL.grit(pj, dest + Vector3.UP * 0.5, 40, pl2["body"], {"dir": Vector3.UP, "spread": 75.0, "vmin": 5.0, "vmax": 12.0, "r": 1.8, "life": 1.0})
			DL.dust_ring(pj, dest, 2.0, 6.0, 8, 1.4, 1.1, pl2["dust"])
			pj.hit(c, dest + Vector3.UP, 4.5, pj.inf(c, "doton_chokeijugan", 2.2, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "doton"}))
			pj.shake(1.4))
		tw2.tween_interval(1.0)
		tw2.tween_property(boulder, "global_position", dest - Vector3.UP * 2.6, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(boulder, "scale", Vector3(1.25, 0.6, 1.25), 0.55)
		tw2.tween_callback(boulder.queue_free))
	Sfx.play("earth", c.global_position, 0.7)


# ================================================================== 9) Doryūsō: toprak akış mızrakları (ref: eğik, uzun, yassı bıçak gibi kaya mızraklar)
## Önüne doğru sekiz adımda, her adımda üç uzun yassı bıçak-mızrak ileri yatık fışkırır (yüzleri keskin, iki yanı düz), dibinde
## yarılma ve çakıl; tutulup geri gömülür.
static func _blade_mesh(v: int) -> ArrayMesh:
	var key = "blade_%d" % (v % 8)
	if _cache.has(key):
		return _cache[key]
	var r = _rng(311 + v % 8)
	var h = r.randf_range(2.6, 3.8)
	var w = r.randf_range(0.34, 0.46)
	var th = w * r.randf_range(0.3, 0.42)
	var vv = PackedVector3Array()
	var ring = [Vector2(w, 0.0), Vector2(0.0, th), Vector2(-w, 0.0), Vector2(0.0, -th)]
	for q in ring:
		vv.append(Vector3(q.x, -0.8, q.y))
	var sh = r.randf_range(-0.08, 0.08)
	for q in ring:
		vv.append(Vector3(q.x * 0.72 + sh, h * 0.55, q.y * 0.78))
	vv.append(Vector3(r.randf_range(-0.12, 0.12) * w + w * 0.25, h, 0.0))
	var tris = PackedInt32Array()
	for i in 4:
		var j = (i + 1) % 4
		tris.append_array([i, j, 4 + j, i, 4 + j, 4 + i])
		tris.append_array([4 + i, 4 + j, 8])
	var m = DL.facet(vv, tris, func(cp: Vector3) -> Vector3: return Vector3(cp.x, 0.0, cp.z))
	_cache[key] = m
	return m


static func doryuusou(js, c: Node3D, t: Node3D) -> void:
	var m = js._mult(c) * js._elem_bonus(c, "doton")
	var d = js._aim(c, t)
	d.y = 0
	d = d.normalized()
	var side = DL.side_of(d)
	Sfx.play("earth", c.global_position, 1.2)
	for k in 8:
		js.get_tree().create_timer(k * 0.06).timeout.connect(func():
			if not is_instance_valid(c):
				return
			var p = c.global_position + d * (2.0 + k * 1.8)
			p.y = Game.jutsu_floor(p.x, p.z)
			var pl = DL.pal(p)
			for s in 3:
				var q = DL.floor_at(p + side * randf_range(-0.7, 0.7) + d * randf_range(-0.4, 0.4))
				var bl = DL.rock(_blade_mesh(k * 3 + s), pl["stone"].lerp(pl["deep"], 0.4).darkened(randf_range(0.0, 0.15)), {"ow": 0.035})
				var lean = d * randf_range(0.2, 0.45) + side * randf_range(-0.25, 0.25) + Vector3.UP
				var dep = 4.2
				DL.put(js, bl, q - Vector3.UP * dep)
				bl.basis = _basis_up(lean).rotated(lean.normalized(), randf() * TAU)
				var tw = bl.create_tween()
				tw.tween_property(bl, "global_position", q, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_interval(1.2)
				tw.tween_property(bl, "global_position", q - Vector3.UP * dep, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(bl.queue_free)
			_zone(p, 3.0)
			DL.crack(js, p, 1.5, 3.0, 0.12, 0.0, 6.0)
			DL.grit(js, p + Vector3.UP * 0.3, 10, pl["body"], {"dir": (Vector3.UP + d * 0.4).normalized(), "spread": 45.0, "vmin": 4.0, "vmax": 9.0, "r": 0.6, "life": 0.6})
			if k % 3 == 1:
				DL.dust(js, p + Vector3.UP * 0.5 + side * 0.9, 1.1, 0.8, side * 1.5, pl["dust"])
			Combat.hit_sphere(c, p + Vector3.UP, 1.6, {"dmg": 9.0 * m, "element": "doton", "knock": 4.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.03}))


# ================================================================== 10) Nendo Bunshin: kil klon (ref: bembeyaz, çatlak çizgili kil beden)
## Yanda yerden beyaz kil topağı insan boyunda kabarıp akarak biçim alır; klon belirdiğinde bedeni önce beyaz kil kaplamalıdır, kil
## süzülüp renkler ortaya çıkar, ayaklarından kil damlaları düşer. Patladığında (bitiş ya da yakına düşman gelince) beyaz kil
## parçaları ve sıcak ışıkla patlar.
static func _clay_burst(pj: PathJutsu, pos: Vector3) -> void:
	var p = pos + Vector3.UP
	_light(pj, p, Color(1.0, 0.85, 0.7), 6.0, 9.0, 0.5)
	var core = MeshInstance3D.new()
	core.mesh = _bead_mesh(0.5)
	var cm = StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(1.0, 0.97, 0.9, 0.95)
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	DL.put(pj, core, p)
	core.scale = Vector3.ONE * 0.4
	var ct = core.create_tween().set_parallel()
	ct.tween_property(core, "scale", Vector3.ONE * 3.2, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ct.tween_property(cm, "albedo_color", Color(1.0, 0.6, 0.35, 0.0), 0.3).set_delay(0.06)
	ct.chain().tween_callback(core.queue_free)
	for i in 12:
		var a = randf() * TAU
		var dv = Vector3(cos(a), randf_range(0.2, 1.0), sin(a)).normalized()
		var b = DL.mud_blob(randf_range(0.1, 0.22), Color(0.92, 0.9, 0.85), 0.025)
		DL.toss(pj, b, p + dv * 0.4, dv * randf_range(7.0, 12.0), 0.9, 18.0, 0.4)
	DL.grit(pj, p, 30, Color(0.95, 0.94, 0.9), {"dir": Vector3.UP, "spread": 180.0, "vmin": 6.0, "vmax": 13.0, "r": 0.4, "life": 0.6, "size": 0.05})
	DL.crack(pj, pos, 3.0, 4.0, 0.12, 0.0, 9.0)


static func nendo_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 2.5)
	var clay = Color(0.94, 0.93, 0.89)
	# yerden kabaran kil kütlesi
	var lump = DL.mud_blob(1.0, clay, 0.03)
	DL.put(pj, lump, at)
	lump.scale = Vector3(0.6, 0.05, 0.6)
	var lt = lump.create_tween()
	lt.tween_property(lump, "scale", Vector3(0.42, 0.95, 0.42), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_method(DL.pf(lump, "melt"), 0.0, 1.0, 0.35)
	lt.tween_callback(lump.queue_free)
	for i in 6:
		var a = TAU * i / 6.0
		var b = DL.mud_blob(randf_range(0.14, 0.22), clay.darkened(0.04), 0.02)
		DL.put(pj, b, at + Vector3(cos(a), 0, sin(a)) * 0.55)
		b.scale = Vector3(b.scale.x, 0.02, b.scale.z)
		var bt = b.create_tween()
		bt.tween_property(b, "scale:y", randf_range(0.1, 0.16), 0.25).set_trans(Tween.TRANS_BACK)
		bt.tween_interval(0.9)
		bt.tween_method(DL.pf(b, "melt"), 0.0, 1.0, 0.5)
		bt.tween_callback(b.queue_free)
	var d = pj.decoy(c, at, 10.0, func(pos):
		_clay_burst(pj, pos)
		pj.hit(c, pos + Vector3.UP, 4.0, pj.inf(c, "nendo_bunshin", 1.4, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "bakuton"})))
	if d:
		# kil kaplaması: klonun bütün parçaları önce beyaz, kil süzülerek renk ortaya çıkar
		var ov = StandardMaterial3D.new()
		ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ov.albedo_color = Color(0.95, 0.94, 0.9, 0.95)
		pj.after(0.05, func():
			if not is_instance_valid(d):
				return
			var meshes = d.find_children("*", "MeshInstance3D", true, false)
			for mi in meshes:
				if mi.material_overlay == null:
					mi.material_overlay = ov
			var ot = d.create_tween()
			ot.tween_interval(0.35)
			ot.tween_property(ov, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			ot.tween_callback(func():
				for mi in meshes:
					if is_instance_valid(mi) and mi.material_overlay == ov:
						mi.material_overlay = null)
			var drip = Node3D.new()
			d.add_child(drip)
			drip.position = Vector3(0, 0.9, 0)
			_flow(drip, Vector3.ZERO, 14, 0.6, clay, {"dir": Vector3.DOWN, "spread": 10.0, "vmin": 0.2, "vmax": 0.8, "g": 12.0, "r": 0.35, "size": 0.05, "dur": 0.7})
			DL.kill(pj, 1.4, drip))
		pj.every(10.0, 0.2, func(_i, _k):
			if is_instance_valid(d) and not pj.enemies_near(c, d.global_position, 2.0).is_empty():
				d.queue_free(), Callable())
	Sfx.play("poof", at, 1.0)


# ================================================================== 11) Tsuchi Nami: toprak dalgası (ref: zemin dalga gibi kıvrılır)
## Yumruk yere iner, zeminin kendisi yay biçiminde bir sırt olarak kabarır ve dalga gibi ileri yuvarlanır (üstü çimen / toprak,
## yanları katmanlı); arkasında zemin dalgalanır. Üç dalga ardı ardına; sırt ilerledikçe alçalır, sonunda yere yatıp kaybolur.
static func _crest_seg(pl: Dictionary, sd: int) -> MeshInstance3D:
	return DL.rock(_slab_mesh(1.0, 0.95, 1.0, 600 + sd % 6, 0.42), pl["body"], {"ow": 0.03, "top": pl["top"], "top_y": 0.82, "strata": 4.0})


static func tsuchi_nami_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "doton_tsuchi_nami_no_jutsu"
	var d = pj.fwd(c, t)
	d.y = 0.0
	d = d.normalized()
	pj.anim(c, "hook", 1.2)
	var g0 = pj.gp(c.global_position + d * 0.7)
	var cw = weakref(c)
	var pl = DL.pal(g0)
	var slam = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		DL.crack(pj, g0, 1.6, 4.0, 0.12, 0.0, 7.0)
		DL.grit(pj, g0 + Vector3.UP * 0.2, 14, pl["body"], {"dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "r": 0.4, "life": 0.5})
		DL.ripple(pj, g0 + d * 6.0, 9.0, 1.6)
		pj.shake(0.5)
		Sfx.play("earth", g0, 0.8)
		for w in 3:
			var hitset = []
			var segs = []
			var n = 15
			for j in n:
				var sg = _crest_seg(pl, j + w * 5)
				DL.put(pj, sg, g0 - Vector3.UP * 0.4)
				sg.scale = Vector3(0.1, 0.02, 1.0)
				segs.append(sg)
			var front = func(_i, k):
				var c2 = cw.get_ref()
				var r = lerpf(1.6, 13.0, k)
				var crest = (1.45 - k * 0.75) * (1.0 - w * 0.18)
				for j in n:
					var sg2 = segs[j]
					if not is_instance_valid(sg2):
						continue
					var a = lerpf(-0.85, 0.85, float(j) / float(n - 1))
					var dir = d.rotated(Vector3.UP, a)
					var p = g0 + dir * r
					p.y = Game.jutsu_floor(p.x, p.z) - 0.12
					sg2.global_position = p
					_yaw(sg2, dir)
					var edge = 1.0 - pow(absf(a) / 0.85, 3.0) * 0.55
					sg2.scale = Vector3(r * 1.7 / float(n) * 1.25, crest * edge * (0.9 + 0.1 * sin(k * 20.0 + j)), 1.0)
				if randf() < 0.45:
					var sa = randf_range(-0.8, 0.8)
					DL.grit(pj, g0 + d.rotated(Vector3.UP, sa) * r + Vector3.UP * crest, 5, pl["body"], {"dir": (d.rotated(Vector3.UP, sa) + Vector3.UP).normalized(), "spread": 30.0, "vmin": 2.0, "vmax": 4.0, "r": 0.3, "life": 0.5})
				if c2 == null or not pj.live(c2):
					return
				for e in pj.enemies_near(c2, g0, 14.5):
					if e in hitset:
						continue
					var v: Vector3 = e.global_position - g0
					v.y = 0.0
					if absf(v.length() - r) < 1.1 and absf(d.signed_angle_to(v.normalized(), Vector3.UP)) < 0.95:
						hitset.append(e)
						e.take_hit(pj.inf(c2, id, 0.36, {"knock": 2.0, "launch": 6.0, "kind": "heavy", "element": "doton", "hitstop": 0.03}))
						pj.st(e, "slow", 2.5)
						if w == 2:
							pj.st(e, "stun", 0.9)   # üçüncü dalga yere serer
			var done = func():
				for sg3 in segs:
					if is_instance_valid(sg3):
						var t3 = sg3.create_tween()
						t3.tween_property(sg3, "scale:y", 0.02, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						t3.tween_callback(sg3.queue_free)
				if w == 2:
					var e2 = g0 + d * 13.0
					DL.dust(pj, DL.floor_at(e2) + Vector3.UP * 0.5, 1.4, 0.9, d * 1.5, pl["dust"])
			for sg4 in segs:
				DL.kill(pj, 2.5, sg4)
			pj.after(w * 0.24, func(): pj.every(0.9, 0.07, front, done))
	pj.after(0.3, slam)


# ================================================================== 12) Kuchiyose Doton Tsuiga: toprak altından takip eden köpekler (ref: Kakashi'nin ninkenleri)
## Kanla yazılmış mühür parşömeni yere basılır: mürekkep yazılı mühür çizgisi zeminde hedefe doğru koşar, çağıranın çevresine kısa
## kollar açılır. Hedefin çevresinde altı noktada toprak delinip açılır, oyunun gerçek ninken modelleri topraktan fırlayıp hedefe
## dişlerini geçirir; iş bitince köpekler geldikleri deliklere geri gömülür.
const SEAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float head = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

DNOISE

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;
	if (y > head) {
		discard;
	}
	float cell = floor(y / 0.42);
	float fy = fract(y / 0.42);
	float g = dh(vec2(cell, seed));
	float g2 = dh(vec2(cell + 7.0, seed));
	bool ink = false;
	if (abs(x) < 0.06) {
		ink = true;
	}
	if (fy > 0.12 && fy < 0.22 && abs(x) < 0.3 + 0.45 * g) {
		ink = true;
	}
	if (g > 0.35 && fy > 0.48 && fy < 0.56 && abs(x - (g2 - 0.5) * 0.6) < 0.28) {
		ink = true;
	}
	if (g2 > 0.55 && abs(x + 0.4 * sign(g - 0.5)) < 0.06 && fy > 0.22 && fy < 0.8) {
		ink = true;
	}
	if (!ink) {
		discard;
	}
	if (dh(vec2(floor(y * 7.0), floor(x * 5.0) + seed)) < fade) {
		discard;
	}
	ALBEDO = vec3(0.012, 0.008, 0.008);
}
"""


static func _seal_line(pj: PathJutsu, a: Vector3, b: Vector3, w: float, run_t: float, life: float) -> void:
	var dv = DL.flat(b - a)
	var ln = maxf(0.5, Vector3(b.x - a.x, 0, b.z - a.z).length())
	var n = maxi(2, int(ln / 0.5) + 1)
	var pts = PackedVector3Array()
	var ws = PackedFloat32Array()
	for i in n:
		var q = a.lerp(b, float(i) / float(n - 1))
		pts.append(DL.floor_at(q))
		ws.append(w)
	var mi = DL.gi(DL.strip_mesh(pts, ws, DL.side_of(dv), 0.06), _shader("seal", SEAL_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	pj.get_tree().current_scene.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_method(DL.pf(mi, "head"), 0.0, ln + 0.5, run_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life - run_t - 0.6))
	tw.tween_method(DL.pf(mi, "fade"), 0.0, 1.0, 0.6)
	tw.tween_callback(mi.queue_free)


static func kuchiyose_doton_tsuiga_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.8)
	pj.anim(c, "crouch", 1.4)
	var cp = pj.gp(c.global_position)
	var fd = c.face_dir()
	# parşömenin bastığı yer: kısa mühür kolları
	for k in 5:
		var a = (k - 2) * 0.9 + PI
		_seal_line(pj, cp + fd * 0.4, cp + fd * 0.4 + fd.rotated(Vector3.UP, a) * randf_range(1.2, 1.7), 0.36, 0.2, 1.6)
	DL.crack(pj, cp + fd * 0.4, 0.9, 2.0, 0.1, 0.0, 5.0)
	Sfx.play("poof", cp, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	_seal_line(pj, cp + fd * 0.4, at, 0.5, 0.28, 1.8)
	var pl = DL.pal(at)
	for k in 6:
		var a = k * TAU / 6.0
		var q = at + Vector3(cos(a), 0, sin(a)) * 1.2
		pj.after(0.3 + k * 0.05, func():
			_zone(q, 2.2 * 0.9)
			DL.pit(pj, q, 0.75, 3.4, 0.1)
			DL.grit(pj, q + Vector3.UP * 0.2, 12, pl["body"], {"dir": Vector3.UP, "spread": 45.0, "vmin": 3.0, "vmax": 6.0, "r": 0.35, "life": 0.6})
			for j in 3:
				var b2 = randf() * TAU
				var ck = DL.chunk(randf_range(0.1, 0.18), 0, pl["body"], {"ow": 0.02, "top": pl["top"], "top_y": 0.5})
				DL.toss(pj, ck, q + Vector3.UP * 0.2, Vector3(cos(b2) * 2.0, randf_range(3.0, 5.0), sin(b2) * 2.0), 0.8)
			# oyunun gerçek ninken modeli (Hatake Tsuiga ve köpek sözleşmesiyle aynı: SummonModels "dog_pack"; ilki küçük Pakkun)
			var dog: Node3D = SummonModels.build("dog_small" if k == 0 else "dog_pack", 0.45 if k == 0 else 0.66, 1.0)["root"]
			pj.get_tree().current_scene.add_child(dog)
			dog.global_position = q - Vector3.UP * 0.8
			dog.look_at(Vector3(at.x, dog.global_position.y, at.z), Vector3.UP)   # model -Z'ye (başa) bakar
			var mid = q + (at - q) * 0.5 + Vector3.UP * 0.2
			var tw = dog.create_tween()
			tw.tween_property(dog, "global_position", mid, 0.2)
			tw.tween_interval(2.5)
			tw.tween_property(dog, "global_position", q - Vector3.UP * 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(dog.queue_free))
	pj.after(0.55, func():
		if pj.live(tt):
			pj.st(tt, "bind", 3.0)
			DL.grit(pj, tt.global_position + Vector3.UP * 0.6, 14, pl["body"], {"dir": Vector3.UP, "spread": 120.0, "vmin": 2.0, "vmax": 5.0, "r": 0.4, "life": 0.5})
			tt.take_hit(pj.inf(c, "kuchiyose_doton_tsuiga_no_jutsu", 1.0, {"knock": 0.0, "kind": "heavy", "bleed": 3.0})))
	Sfx.play("earth", at, 1.0)


# ================================================================== 13) Tsuchigumo kinjutsu: Dohatsuten (yasak doğa enerjisi patlaması)
## Toplanan doğa enerjisi zemine akar: hedef bölgede kenardan içe doğru kızıl-turuncu yarıklar ilerler, rastgele yerler yarılır,
## yarıklardan sıcak zerreler yükselir. 1.4 sn sonra zemin kubbe gibi kabarıp patlar: dikine fırlayan dev kaya sütunu, dışa
## savrulan levhalar, kocaman çukur ve yarık, enerji ışığı; ağır kaya yağmuru yere saplanıp gömülür.
const ENERGY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float grow = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

DNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < 1.0 - grow) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float br = 13.0;
	float a = ang + (dn(vec2(r * 4.0, seed)) - 0.5) * 0.55;
	float sec = a * br / 6.2831853;
	float da = abs(fract(sec) - 0.5) * 6.2831853 / br * r;
	float w = 0.008 + 0.016 * r;
	float ringd = abs(r - 0.965);
	bool core = da < w || ringd < 0.008;
	bool halo = da < w * 2.8 || ringd < 0.02;
	if (!halo) {
		discard;
	}
	if (dh(floor(p * 40.0) + vec2(seed)) < fade) {
		discard;
	}
	vec3 col = vec3(0.95, 0.42, 0.1);
	if (core) {
		col = vec3(1.0, 0.93, 0.62);
	}
	ALBEDO = col;
}
"""


static func tsuchigumo_kinjutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	if not c.has_meta("dohatsuten_until") or float(c.get_meta("dohatsuten_until")) < Time.get_ticks_msec() / 1000.0:
		if c is Player:
			Hud.msg("Dohatsuten için önce Tenchi Kaibyaku ile doğa enerjisi toplamalısın.", Color(1, 0.75, 0.45), 5.0)
		# şart yok: ayak altında kısa, sönük bir enerji yarığı titreyip söner (oynanış yok; tekniğin neden çıkmadığı görünsün)
		var fz = DL.disc(pj, pj.gp(c.global_position), 1.6, _shader("dohatsu", ENERGY_SHADER))
		fz.set_instance_shader_parameter("seed", randf() * 10.0)
		fz.set_instance_shader_parameter("grow", 0.0)
		fz.set_instance_shader_parameter("fade", 0.0)
		var ft = fz.create_tween()
		ft.tween_method(DL.pf(fz, "grow"), 0.0, 0.45, 0.3)
		ft.tween_method(DL.pf(fz, "fade"), 0.0, 1.0, 0.4)
		ft.tween_callback(fz.queue_free)
		return
	c.remove_meta("dohatsuten_until")
	pj.busy(c, 2.0)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position) if tt else pj.gp(Jutsu._aim_ground(c, t, 10.0, 20.0))
	var pl = DL.pal(at)
	Sfx.play("poof", at, 0.8)
	if c is Player:
		c.hp = maxf(1.0, c.hp - c.max_hp * 0.3)
	# kenardan içe ilerleyen enerji yarıkları
	var ring = DL.disc(pj, at, 6.6, _shader("dohatsu", ENERGY_SHADER))
	ring.set_instance_shader_parameter("seed", randf() * 10.0)
	ring.set_instance_shader_parameter("grow", 0.0)
	ring.set_instance_shader_parameter("fade", 0.0)
	var rt = ring.create_tween()
	rt.tween_method(DL.pf(ring, "grow"), 0.0, 1.0, 1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rt.tween_method(DL.pf(ring, "fade"), 0.0, 1.0, 0.25)
	rt.tween_callback(ring.queue_free)
	# yarıklardan yükselen sıcak zerreler (sahneye bağlı akış)
	var em = Node3D.new()
	DL.put(pj, em, at)
	_flow(em, Vector3.ZERO, 60, 1.0, Color(1.0, 0.6, 0.2, 0.9), {"dir": Vector3.UP, "spread": 10.0, "vmin": 1.5, "vmax": 4.0, "g": -1.0, "r": 5.5, "size": 0.05, "fade": true, "mat": DL.bead_mat(Color(1.0, 0.7, 0.3)), "dur": 1.35})
	DL.kill(pj, 2.5, em)
	var hum = OmniLight3D.new()
	hum.light_color = Color(1.0, 0.55, 0.2)
	hum.light_energy = 0.0
	hum.omni_range = 10.0
	DL.put(pj, hum, at + Vector3.UP * 0.8)
	var ht = hum.create_tween()
	ht.tween_property(hum, "light_energy", 2.5, 1.35)
	ht.tween_callback(hum.queue_free)
	for k in 8:
		pj.after(k * 0.15, func():
			var q = at + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			_zone(q, 5.0)
			DL.crack(pj, q, 2.6, 4.0, 0.12, randf_range(-3.0, 3.0), 7.0)
			DL.grit(pj, DL.floor_at(q) + Vector3.UP * 0.1, 8, pl["body"], {"dir": Vector3.UP, "spread": 30.0, "vmin": 1.5, "vmax": 3.5, "r": 0.8, "life": 0.5})
			pj.shake(0.15))
	# kabaran zemin (patlamadan hemen önce)
	pj.after(1.15, func():
		var prof = PackedVector2Array([Vector2(7.0, -0.6), Vector2(6.0, 0.6), Vector2(4.2, 1.6), Vector2(2.0, 2.2), Vector2(0.0, 2.4)])
		var dome = DL.rock(DL.lathe_mesh(prof, 26, 8.0, 0.1, 0.06, 91), pl["body"], {"ow": 0.05, "top": pl["top"], "top_y": 1.6, "strata": 1.5})
		DL.put(pj, dome, at - Vector3.UP * 2.5)
		var dt = dome.create_tween()
		dt.tween_property(dome, "global_position", at - Vector3.UP * 0.3, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dt.tween_callback(dome.queue_free))
	pj.after(1.4, func():
		_zone(at, 24.0)
		_light(pj, at + Vector3.UP * 3.0, Color(1.0, 0.7, 0.35), 9.0, 30.0, 0.9)
		DL.pit(pj, at, 9.0, 10.0, 0.18)
		DL.crack(pj, at, 16.0, 9.0, 0.3, 0.0, 14.0)
		var cam = pj.get_viewport().get_camera_3d()
		var toc = DL.flat(cam.global_position - at) if cam else Vector3.ZERO
		# dikine kaya sütunu
		for i in 16:
			var a = randf() * TAU
			var rr = randf_range(0.0, 3.0)
			var ck = DL.chunk(randf_range(0.5, 1.1), randi() % 3, pl["body"].darkened(randf_range(0.0, 0.2)), {"ow": 0.04, "top": pl["top"], "top_y": 0.5})
			DL.toss(pj, ck, at + Vector3(cos(a) * rr, 0.8, sin(a) * rr), Vector3(cos(a) * randf_range(1.0, 4.0), randf_range(14.0, 22.0), sin(a) * randf_range(1.0, 4.0)), 2.6)
		# dışa savrulan zemin levhaları (kameraya doğru gitmez)
		for i in 14:
			var a = TAU * (i + randf_range(-0.3, 0.3)) / 14.0
			var dv = Vector3(cos(a), 0, sin(a))
			if dv.dot(toc) > 0.4:
				dv = (dv - toc * 1.1).normalized()
			var sl = DL.rock(_slab_mesh(randf_range(1.2, 2.0), randf_range(0.9, 1.4), 0.4, 700 + i), pl["body"], {"ow": 0.04, "top": pl["top"], "top_y": 0.3, "strata": 4.0})
			DL.toss(pj, sl, at + dv * randf_range(3.0, 5.0) + Vector3.UP * 0.5, dv * randf_range(9.0, 16.0) + Vector3.UP * randf_range(6.0, 11.0), 1.8)
		var bm = DL.bead_mat(Color(1.0, 0.75, 0.4))
		DL.grit(pj, at + Vector3.UP * 1.0, 60, Color(1.0, 0.72, 0.35), {"dir": Vector3.UP, "spread": 70.0, "vmin": 8.0, "vmax": 20.0, "r": 3.0, "life": 1.2, "size": 0.07})
		var ember = Node3D.new()
		DL.put(pj, ember, at + Vector3.UP * 0.5)
		_flow(ember, Vector3.ZERO, 70, 1.4, Color(1.0, 0.65, 0.25, 0.9), {"dir": Vector3.UP, "spread": 60.0, "vmin": 6.0, "vmax": 14.0, "g": 4.0, "r": 4.0, "size": 0.06, "fade": true, "mat": bm, "dur": 0.25})
		DL.kill(pj, 1.8, ember)
		DL.dust_ring(pj, at, 5.0, 16.0, 14, 2.4, 1.6, pl["dust"])
		pj.hit(c, at + Vector3.UP, 16.0, pj.inf(c, "tsuchigumo_kinjutsu", 6.0, {"knock": 34.0, "launch": 14.0, "kind": "heavy", "element": "doton", "hitstop": 0.2}))
		pj.shake(3.0))
	Sfx.play("boom", at, 0.3)
