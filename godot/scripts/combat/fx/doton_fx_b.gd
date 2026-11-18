class_name DotonFXB
extends RefCounted
## Doton grubu B: on beş toprak tekniğinin görselleri — malzeme ve yapı taşları DotonLib'den (kendi kaya / çamur / toz / zemin /
## bataklık shader'ları, döner profil ağı), her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt
## yardımcısı yok. Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, yarık zemin bölgeleri) ana
## ağaçtaki işleyicilerden satır satır taşındı.

const DL = preload("res://scripts/combat/fx/lib/doton_lib.gd")
const VX = preload("res://scripts/combat/vfx.gd")   # yalnız destan ölçeği sayısı (epic) okunur; görsel kullanılmaz
const CHAKRA := Color(0.45, 0.72, 1.0, 0.85)

static var _cache := {}


# ================================================================== ortak oynanış izleri
## Eski zemin çatlağının oyun tarafı (birebir): büyük yarık üstünden geçeni yavaşlatır; boy destan ölçeğiyle büyür
static func _zone(pos: Vector3, size: float, dur := 6.0) -> void:
	var s = size * VX.epic
	if s >= 1.5:
		GroundFX.add(pos, "cracked", s * 0.6, clampf(dur, 3.0, 5.0))


## Eski "toprak çıkışı" patlamasının oyun tarafı (çatlak 2.2 * s)
static func _burst_zone(pos: Vector3, s: float) -> void:
	_zone(pos, 2.2 * s, 6.0)


static func _prof(arr: Array) -> PackedVector2Array:
	var o = PackedVector2Array()
	for q in arr:
		o.append(q)
	return o


static func _add(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	return DL.put(host, n, pos)


## Sürekli parçacık yayıcı (toprak tanesi ya da chakra zerresi): parent'a bağlı, dünya uzayında iz bırakır
static func _stream(parent: Node3D, offset: Vector3, amount: int, life: float, col: Color, o := {}) -> GPUParticles3D:
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.DOWN)
	pm.spread = float(o.get("spread", 30.0))
	pm.initial_velocity_min = float(o.get("vmin", 0.5))
	pm.initial_velocity_max = float(o.get("vmax", 2.0))
	pm.gravity = Vector3(0, -float(o.get("g", 9.0)), 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, float(o.get("r", 0.4)))
	pm.scale_min = float(o.get("smin", 0.5))
	pm.scale_max = float(o.get("smax", 1.3))
	pm.color = col
	if o.has("ramp"):
		var gt = GradientTexture1D.new()
		gt.gradient = o["ramp"]
		pm.color_ramp = gt
	var ps = GPUParticles3D.new()
	ps.process_material = pm
	ps.amount = maxi(1, amount)
	ps.lifetime = life
	ps.local_coords = false
	ps.draw_pass_1 = o.get("mesh", DL.chunk_mesh(0, 2, float(o.get("size", 0.06))))
	ps.material_override = o.get("mat", DL.grit_mat())
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	parent.add_child(ps)
	ps.position = offset
	ps.emitting = true
	return ps


static func _fade_ramp(col: Color) -> Gradient:
	var g = Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, col.a))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	return g


static func _bead_mesh(r: float) -> SphereMesh:
	var key = "bead_%.3f" % r
	if not _cache.has(key):
		var s = SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 8
		s.rings = 4
		_cache[key] = s
	return _cache[key]


static func _line_mat(col: Color) -> StandardMaterial3D:
	var key = "line_" + col.to_html(true)
	if not _cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		_cache[key] = m
	return _cache[key]


## Uçtan uca bakan taban (Y ekseni a → b)
static func _basis_up(yv: Vector3) -> Basis:
	var y = yv.normalized()
	var ref = Vector3.FORWARD if absf(y.y) > 0.95 else Vector3.UP
	var x = ref.cross(y).normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)


# ================================================================== 1) Doryūheki: köpek yüzlü toprak duvar (Kakashi)
## Duvar kaba taş bloklardan örülü yükselir (ref 1: düz, dikey lekeli kum rengi yüz; ref 2: büyük kesme bloklar ve ön yüzde
## kabartma dört köpek başı, ortadaki ağzı açık). Tabanında iki yanda kırık levha moloz sırası, kalkarken taban boyunca kısa
## toz perdesi, tepeden dökülen çakıl, zeminde duvar boyunca yarık. (Çarpışma, element duvarı, süreler eski duvarla aynı.)
static func _wall_tone(pl: Dictionary) -> Color:
	return pl["body"].lerp(Color(0.8, 0.7, 0.52), 0.55)


static func _dog_head(col: Color, open: bool) -> Node3D:
	var h = Node3D.new()
	var dark = col.darkened(0.55)
	var parts = [
		# [kind, var, pos, scale, color]
		[0, 0, Vector3(0, 0, 0), Vector3(0.78, 0.66, 0.6), col],
		[0, 1, Vector3(0, -0.24, -0.44), Vector3(0.46, 0.32, 0.42), col.lightened(0.04)],
		[0, 2, Vector3(-0.27, -0.4, -0.4), Vector3(0.32, 0.3, 0.3), col.darkened(0.05)],
		[0, 3, Vector3(0.27, -0.4, -0.4), Vector3(0.32, 0.3, 0.3), col.darkened(0.05)],
		[0, 4, Vector3(0, 0.27, -0.42), Vector3(0.62, 0.15, 0.22), col.darkened(0.08)],
		[0, 5, Vector3(0, -0.12, -0.83), Vector3(0.13, 0.1, 0.1), dark],
		[0, 0, Vector3(-0.23, 0.12, -0.55), Vector3(0.07, 0.05, 0.05), dark],
		[0, 1, Vector3(0.23, 0.12, -0.55), Vector3(0.07, 0.05, 0.05), dark],
	]
	if open:
		parts.append([0, 2, Vector3(0, -0.56, -0.6), Vector3(0.32, 0.2, 0.12), Color(0.12, 0.08, 0.06)])
		parts.append([1, 3, Vector3(-0.12, -0.46, -0.66), Vector3(0.05, 0.05, 0.05), col.lightened(0.15)])
		parts.append([1, 4, Vector3(0.12, -0.46, -0.66), Vector3(0.05, 0.05, 0.05), col.lightened(0.15)])
	for pr in parts:
		var mi = DL.rock(DL.chunk_mesh(int(pr[0]), int(pr[1])), pr[4], {"ow": 0.03})
		mi.position = pr[2]
		mi.scale = pr[3]
		if int(pr[0]) == 1:
			mi.rotation = Vector3(PI, 0, 0)
		h.add_child(mi)
	for sx in [-1.0, 1.0]:   # sarkık kulaklar
		var ear = DL.rock(DL.chunk_mesh(1, 2 + int(sx)), col.darkened(0.12), {"ow": 0.03})
		ear.position = Vector3(0.6 * sx, 0.05, -0.05)
		ear.scale = Vector3(0.2, 0.24, 0.12)
		ear.rotation = Vector3(0, 0, PI - 0.35 * sx)
		h.add_child(ear)
	return h


static func _dog_wall(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var tone = _wall_tone(pl)
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()
	var rows = [[0.0, 2.4], [2.4, 4.7], [4.7, 7.0]]
	for r in rows.size():
		var x = -6.0
		var off = rng.randf_range(0.6, 1.8) if r % 2 == 1 else 0.0
		var widths = []
		var acc = off
		if off > 0.0:
			widths.append(off)
		while acc < 12.0 - 0.01:
			var w = minf(rng.randf_range(2.0, 3.4), 12.0 - acc)
			if 12.0 - acc - w < 0.8:
				w = 12.0 - acc
			widths.append(w)
			acc += w
		for w in widths:
			var y0: float = rows[r][0]
			var y1: float = rows[r][1]
			var ol = DL.jag_rect(w - 0.08, 2.0 + rng.randf_range(-0.05, 0.12), 2, 0.04, rng)
			var top = 0.0 if r < 2 else rng.randf_range(-0.15, 0.2)
			var blk = DL.rock(DL.prism_mesh(ol, 0.0, (y1 - y0) - 0.05 + top, 0.05, 0.03, rng.randi()), tone.darkened(rng.randf_range(-0.04, 0.1)), {"ow": 0.05, "strata": 0.0, "shadow": true})
			blk.position = Vector3(x + w * 0.5, y0, rng.randf_range(-0.05, 0.05))
			root.add_child(blk)
			x += w
	# kırık tepe kenarı: tepe boyunca yontuk taş dişler
	for i in 9:
		var sp = DL.rock(DL.chunk_mesh(2, i), tone.darkened(rng.randf_range(0.0, 0.1)), {"ow": 0.04})
		sp.position = Vector3(-5.4 + i * 1.35 + rng.randf_range(-0.2, 0.2), 7.05, rng.randf_range(-0.3, 0.3))
		sp.scale = Vector3(rng.randf_range(0.7, 1.1), rng.randf_range(0.3, 0.55), 1.2)
		root.add_child(sp)
	# ön yüzde (düşmana bakan -Z) kabartma köpek başları; ikincisi ağzı açık havlar
	for i in 4:
		var hd = _dog_head(tone.darkened(0.04), i == 1)
		hd.position = Vector3(-4.2 + i * 2.8, 3.6 + rng.randf_range(-0.2, 0.2), -1.05)
		hd.scale = Vector3.ONE * 1.15
		hd.rotation.z = rng.randf_range(-0.12, 0.12)
		root.add_child(hd)
	# taban: iki yanda kırık levha moloz sırası (ref 1)
	for side in [-1.0, 1.0]:
		var x = -6.2
		while x < 6.2:
			var w = rng.randf_range(0.6, 1.2)
			var rb = DL.rock(DL.chunk_mesh(2, rng.randi() % 6), pl["body"].lerp(tone, 0.5).darkened(rng.randf_range(0.0, 0.15)), {"ow": 0.035, "top": pl["top"], "top_y": 0.3})
			rb.position = Vector3(x + w * 0.5, 0.05, side * rng.randf_range(1.3, 1.65))
			rb.scale = Vector3(w * 0.95, rng.randf_range(0.3, 0.5), rng.randf_range(0.55, 0.8))
			rb.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.25, 0.25))
			root.add_child(rb)
			x += w * rng.randf_range(0.8, 1.0)
	return root


static func doryuheki(pj, c: Node3D, _t: Node3D) -> void:
	var d = pj._aim_flat(c, _t)
	var pos = c.global_position + d * 3.5
	pos.y = Game.jutsu_floor(pos.x, pos.z)
	var wall = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	var wk = clampf(VX.epic, 1.0, 1.4)
	sh.size = Vector3(12, 7, 2) * wk
	cs.shape = sh
	cs.position.y = 3.5 * wk
	wall.add_child(cs)
	var pl = DL.pal(pos)
	var vis = _dog_wall(pl)
	vis.scale = Vector3.ONE * wk
	wall.add_child(vis)
	pj.get_tree().current_scene.add_child(wall)
	pj._element_wall(wall, "doton", c, Vector3(0, 3.5, 0) * wk, Vector3(6, 3.5, 1) * wk, 45.0 * pj._mult(c))
	wall.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), pos - Vector3(0, 7.5 * wk, 0))
	var tw = wall.create_tween()
	tw.tween_property(wall, "global_position:y", pos.y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(14.0)
	tw.tween_property(wall, "global_position:y", pos.y - 7.5 * wk, 0.6)
	tw.tween_callback(wall.queue_free)
	# zemin: duvar boyunca yarık (oyun tarafı: eski 10 m çatlak), taban tozu, tepeden dökülen çakıl
	_zone(pos, 10.0)
	var side_v = d.cross(Vector3.UP).normalized()
	for k in 3:
		DL.crack(pj, pos + side_v * (k - 1) * 4.2 * wk, 3.4 * wk, 14.5, 0.3, 0.0, 6.0)
	var dust_c: Color = pl["dust"].lerp(_wall_tone(pl), 0.3)
	for k in 4:
		var bp = pos + side_v * (-4.5 + k * 3.0) * wk
		for fs in [-1.0, 1.0]:
			if randf() < 0.6:
				DL.dust(pj, bp + d * fs * 1.6 * wk + Vector3.UP * 0.5, 2.2, 1.3, d * fs * 1.6 + Vector3.UP * 0.6, dust_c)
	var host_tree = pj.get_tree()
	host_tree.create_timer(0.3).timeout.connect(func():
		if not is_instance_valid(wall):
			return
		for k in 4:
			DL.grit(wall, pos + Vector3.UP * 7.0 * wk + side_v * randf_range(-5.0, 5.0) * wk, 14, pl["body"], {"dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.5, "vmax": 2.0, "r": 0.8, "life": 1.1, "g": 14.0}))
	Sfx.play("earth", pos)
	if Game.world:
		Game.world.env.add_shake(0.4)


# ================================================================== 2) Doton Kekkai: Dorō Dōmu — taş örgü hapis kubbesi
## Hedefin çevresinden taşlar zeminden sökülüp halka halka içe uçar, aralarında koyu derz kalan kubbe örülür (ref: mozaik taş
## kubbe, zeminde yayılan çatlaklar). Her emişte kubbenin taş aralarından mavi chakra zerreleri kıvrılarak büyücüye akar. Bitişte
## taşlar çatlayıp yere dökülür, kubbe toprağa gömülür.
static func kekkai_doro_domu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var pl = DL.pal(at)
	var dome = Node3D.new()
	_add(pj, dome, at)
	var R = 2.5
	# iç koyu harç kabuğu (taş aralarındaki derz görünsün diye)
	var hemi = _prof([Vector2(R - 0.25, -0.3), Vector2(R - 0.25, 0.4), Vector2((R - 0.25) * 0.8, 1.7), Vector2((R - 0.25) * 0.45, 2.45), Vector2(0, 2.7)])
	var core = DL.rock(DL.lathe_mesh(hemi, 18, 0.0, 0.0, 0.02, 3), pl["deep"].darkened(0.45), {"ow": 0.0})
	dome.add_child(core)
	core.scale = Vector3(1, 0.02, 1)
	core.create_tween().tween_property(core, "scale", Vector3.ONE, 0.4).set_delay(0.1)
	var rings = [[0.1, 13], [0.48, 11], [0.86, 8], [1.22, 5]]
	var ri = 0
	var stones = []
	for rg in rings:
		var e: float = rg[0]
		var n: int = rg[1]
		var off = randf() * TAU
		for i in n:
			var a = off + TAU * i / float(n)
			var outv = Vector3(cos(a) * cos(e), sin(e) * 1.05, sin(a) * cos(e))
			var s = TAU * R * cos(e) / float(n) * 0.6
			var st = DL.rock(DL.chunk_mesh(0, (i + ri) % 6), pl["body"].darkened(randf_range(-0.05, 0.16)).lerp(pl["stone"], randf() * 0.3), {"ow": 0.04, "strata": 0.0})
			st.basis = Basis.looking_at(-outv, Vector3.UP if absf(outv.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(s * 0.95, s * 0.8, 0.55))
			dome.add_child(st)
			var slot = outv * R
			st.position = Vector3(cos(a) * (R + 1.8), -1.2, sin(a) * (R + 1.8))
			var tw = st.create_tween()
			tw.tween_property(st, "position", slot, 0.28).set_delay(ri * 0.06 + randf() * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stones.append(st)
		ri += 1
	var cap = DL.rock(DL.chunk_mesh(0, 5), pl["body"].darkened(0.05), {"ow": 0.04})
	cap.scale = Vector3(1.1, 0.5, 1.1)
	cap.position = Vector3(0, 6.0, 0)
	dome.add_child(cap)
	cap.create_tween().tween_property(cap, "position", Vector3(0, R * 1.05 + 0.05, 0), 0.25).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# zemin: kubbeden dışa yayılan çatlak ağı, taban çevresinde sökülmüş toprak izi
	_burst_zone(at, 2.0)
	DL.crack(pj, at, 5.0, 6.0, 0.35, 0.0, 11.0)
	DL.grit(pj, at + Vector3.UP * 0.3, 26, pl["body"], {"dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "r": R})
	pj.after(0.38, func():
		DL.dust_ring(pj, at, R, R + 2.2, 7, 1.6, 1.1, pl["dust"]))
	pj.st(tt, "bind", 5.0)
	pj.every(5.0, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "doton_kekkai_doro_domu", 0.1, {"knock": 0.0, "kind": "light"}))
			pj.chakra_gain(c, 4.0)
			_drain_beads(pj, at, R, c), Callable())
	# bitiş: taşlar çatlar, dökülür; kubbe gömülür
	pj.get_tree().create_timer(5.35).timeout.connect(func():
		if not is_instance_valid(dome):
			return
		_burst_zone(at, 2.0)
		DL.burst_chunks(pj, at + Vector3.UP * 1.2, 12, 0.3, 6.0, pl["body"], 0.7, 0, 1.1)
		DL.crack(pj, at, 3.5, 4.0, 0.2, 0.4, 7.0)
		var tw2 = dome.create_tween()
		tw2.tween_property(dome, "global_position", at - Vector3.UP * 3.6, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.tween_callback(dome.queue_free))
	DL.kill(pj, 6.5, dome)
	pj.shake(0.6)
	Sfx.play("earth", at, 0.7)


## Emilen chakra: kubbenin taş aralarından çıkan mavi zerreler kavis çizerek büyücünün göğsüne akar
static func _drain_beads(pj: PathJutsu, at: Vector3, R: float, c: Node3D) -> void:
	if not pj.live(c):
		return
	for i in 4:
		var a = randf() * TAU
		var e = randf_range(0.3, 1.1)
		var p0 = at + Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * (R + 0.1)
		var b = MeshInstance3D.new()
		b.mesh = _bead_mesh(randf_range(0.05, 0.09))
		b.material_override = DL.bead_mat(CHAKRA)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(pj, b, p0)
		var lift = randf_range(1.0, 2.2)
		var delay = i * 0.08
		var tw = b.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(b):
				return
			var tgt = c.global_position + Vector3.UP * 1.3 if is_instance_valid(c) else p0
			var q = p0.lerp(tgt, u) + Vector3.UP * sin(u * PI) * lift
			b.global_position = q
			b.scale = Vector3.ONE * (1.0 - u * 0.6), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)


# ================================================================== 3) Kajūgan: ağırlık ekleme (Ōnoki)
## Kaya kabuğu yok: dokunulan bedenin üstüne anime ağırlık çizgileri yağar (yukarıdan aşağı inen koyu baskı çizgileri), ayak
## çevresinde zemin kabarıp kenara itilir (batan ağırlık), dokunuşta taneler saçılır; 0.3 sn sonra ayak altında çöküntü + çatlak.
static func kajugan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt8 = pj.tg(c, t, 8.0)
	var tt = pj.tg(c, t, 5.0)
	if tt == null:
		Hud.msg("Kajūgan: hedefe dokunmalısın (5 m)", Color(0.85, 0.8, 0.7))
	else:
		pj.anim(c, "cross", 1.4)
		pj.st(tt, "slow", 8.0)
		_weight_marks(pj, tt, 8.0)
		Sfx.play("earth", tt.global_position, 1.4)
	if tt8:
		pj.after(0.3, func():
			if pj.live(tt8):
				var g = pj.gp(tt8.global_position)
				_zone(g, 3.5)
				var pl = DL.pal(g)
				DL.pit(pj, g, 0.95, 7.5, 0.12)
				DL.crack(pj, g, 2.0, 6.0, 0.15, 0.0, 9.0)
				DL.dust_ring(pj, g, 0.6, 2.0, 6, 1.0, 0.8, pl["dust"])
				DL.grit(pj, g + Vector3.UP * 0.15, 16, pl["body"], {"dir": Vector3.UP, "spread": 80.0, "vmin": 1.5, "vmax": 3.5, "r": 0.6, "life": 0.6}))


static func _weight_marks(pj: PathJutsu, tt: Node3D, dur: float) -> void:
	var g = pj.gp(tt.global_position)
	var pl = DL.pal(g)
	var hgt = float(tt.get("height")) if tt.get("height") != null else 1.8
	# dokunuş: göğüs hizasında saçılan ince taneler
	DL.grit(pj, tt.global_position + Vector3.UP * hgt * 0.6, 12, pl["dust"], {"dir": Vector3.DOWN, "spread": 160.0, "vmin": 1.0, "vmax": 2.5, "r": 0.2, "life": 0.5, "size": 0.04})
	# ayak çevresinde itilip kabaran toprak (hedefi izler)
	var heap = Node3D.new()
	_add(pj, heap, g)
	for i in 7:
		var a = TAU * (i + randf_range(-0.2, 0.2)) / 7.0
		var lp = DL.rock(DL.chunk_mesh(0, i), pl["body"].darkened(randf_range(0.0, 0.12)), {"ow": 0.025, "top": pl["top"], "top_y": 0.5})
		lp.position = Vector3(cos(a) * 0.55, -0.05, sin(a) * 0.55)
		lp.scale = Vector3(0.3, 0.01, 0.3)
		lp.rotation.y = randf() * TAU
		heap.add_child(lp)
		lp.create_tween().tween_property(lp, "scale", Vector3(randf_range(0.26, 0.36), randf_range(0.14, 0.22), randf_range(0.22, 0.3)), 0.25).set_delay(0.2).set_trans(Tween.TRANS_BACK)
	var lc = _line_mat(Color(0.18, 0.12, 0.08, 0.85))
	pj.every(dur, 0.22, func(_i, _k):
		if not pj.live(tt) or not is_instance_valid(heap):
			return
		var p = pj.gp(tt.global_position)
		heap.global_position = p
		# yukarıdan inen baskı çizgileri
		for j in 2:
			var a = randf() * TAU
			var rr = randf_range(0.5, 0.8)
			var ln = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.025, randf_range(0.6, 1.0), 0.025)
			ln.mesh = bm
			ln.material_override = lc
			ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var top = p + Vector3(cos(a) * rr, hgt + 0.9, sin(a) * rr)
			_add(pj, ln, top)
			var tw = ln.create_tween().set_parallel()
			tw.tween_property(ln, "global_position", top - Vector3.UP * (hgt * 0.75), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(ln, "scale", Vector3(1, 0.2, 1), 0.2).set_delay(0.05)
			tw.chain().tween_callback(ln.queue_free), func():
		if is_instance_valid(heap):
			var t2 = heap.create_tween()
			t2.tween_property(heap, "position", heap.position - Vector3.UP * 0.35, 0.5)
			t2.tween_callback(heap.queue_free))
	DL.kill(pj, dur + 1.5, heap)


# ================================================================== 4) Doryūkatsu: toprak yarma (yol açma)
## Önündeki zemin ileri doğru sırayla ikiye yarılır: ortada uzanan yarık / hendek, iki yanda dışa yatık, çimen örtülü toprak
## sırtlar kalkar (ref: iki yana açılmış toprak yamaçlar arasında yol). Kalkışta yanlara çakıl savrulur; sırtlar sonra gömülür.
static func doryukatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	for k in 8:
		pj.after(k * 0.05, func():
			var q = pj.gp(c.global_position + d * (2.0 + k * 2.0))
			_zone(q, 2.5)
			_divide_segment(pj, q, d, k))
	pj.shake(0.5)
	_divide_buff(c)


static func _divide_segment(pj: PathJutsu, q: Vector3, d: Vector3, k: int) -> void:
	var pl = DL.pal(q)
	var sd = DL.side_of(d)
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()
	for sx in [-1.0, 1.0]:
		var root = Node3D.new()
		var base = q + sd * sx * randf_range(1.15, 1.35)
		_add(pj, root, base - Vector3.UP * 1.8)
		root.basis = Basis.looking_at(d, Vector3.UP)
		var h = rng.randf_range(1.1, 1.6) + k * 0.06
		var ol = DL.jag_rect(rng.randf_range(0.9, 1.2), 2.3, 2, 0.1, rng)
		var slab = DL.rock(DL.prism_mesh(ol, -0.4, h, 0.1, 0.12, rng.randi()), pl["body"].darkened(rng.randf_range(0.0, 0.1)), {"top": pl["top"], "top_y": h - 0.12, "strata": 2.2, "ow": 0.045, "shadow": true})
		slab.rotation.z = deg_to_rad(18.0) * sx
		root.add_child(slab)
		# dış yamaçtaki sarkık toprak
		var lump = DL.rock(DL.chunk_mesh(0, k % 6), pl["body"], {"ow": 0.03, "top": pl["top"], "top_y": 0.5})
		lump.scale = Vector3(0.45, 0.3, 0.6)
		lump.position = Vector3(0.55 * sx, 0.2, rng.randf_range(-0.6, 0.6))
		root.add_child(lump)
		var tw = root.create_tween()
		tw.tween_property(root, "global_position", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(4.6 - k * 0.05)
		tw.tween_property(root, "global_position", base - Vector3.UP * 1.9, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(root.queue_free)
		DL.grit(pj, base + Vector3.UP * 0.3, 8, pl["body"], {"dir": (sd * sx + Vector3.UP).normalized(), "spread": 35.0, "vmin": 3.0, "vmax": 6.0, "r": 0.5, "life": 0.7})
	var tr = DL.pit(pj, q, 0.7, 5.3, 0.1, Vector2(0.75, 1.9))
	tr.rotation.y = atan2(-d.x, -d.z)
	if k % 3 == 0:
		DL.dust(pj, q + Vector3.UP * 0.4, 1.4, 0.9, Vector3.UP * 0.8, pl["dust"])


## Eski genel motorun "utility" biçiminden taşındı (Data'daki tier'e göre süre ve bonuslar; toprak doğası kolu)
static func _divide_buff(c: Node3D) -> void:
	var dd: Dictionary = Data.jutsu.get("doton_doryukatsu", {})
	if dd.is_empty():
		return
	var tier = int(dd.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	var mods = {"armor": maxf(0.5, 0.9 - 0.06 * tier), "melee": 1.05 + 0.04 * tier}
	Buffs.add(String(dd.get("id", "buff")), dur, mods)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(dd.get("name", "")).split(" (")[0], int(dur)], Color(0.86, 0.74, 0.55))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== 5) Doryō Dango: dev toprak köftesi
## Büyücünün önündeki zemin çimen örtüsüyle birlikte koca, basık bir toprak kütlesi halinde koparılır ve başın üstüne kaldırılır
## (ref: yatay katman çizgili dev yumru, altında toz). Kalkarken kopma yerinde çukur kalır, kütlenin altından toprak taneleri
## dökülür; kavisle hedefe çakılır: geniş çatlak, çukur, iri parça saçılması, yer seviyesinde toz halkası; sonra ufalanıp gömülür.
static func _dango_mass(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var prof = _prof([Vector2(0, -1.95), Vector2(1.5, -1.8), Vector2(2.6, -1.25), Vector2(3.1, -0.4), Vector2(3.05, 0.5), Vector2(2.55, 1.3), Vector2(1.6, 1.85), Vector2(0, 2.05)])
	var body = DL.rock(DL.lathe_mesh(prof, 20, 7.0, 0.1, 0.06, randi() % 5), pl["body"], {"top": pl["top"], "top_y": 1.45, "strata": 1.3, "ow": 0.07, "shadow": true})
	root.add_child(body)
	for i in 7:
		var a = TAU * i / 7.0 + randf() * 0.4
		var cl = DL.rock(DL.chunk_mesh(0, i), pl["deep"].darkened(randf_range(0.0, 0.15)), {"ow": 0.04})
		cl.position = Vector3(cos(a) * randf_range(0.6, 2.0), -1.75, sin(a) * randf_range(0.6, 2.0))
		cl.scale = Vector3.ONE * randf_range(0.35, 0.6)
		root.add_child(cl)
	return root


static func doryo_dango(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	pj.anim(c, "crouch", 1.2)
	var tt = pj.tg(c, t, 24.0)
	var target = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var start = pj.gp(c.global_position + c.face_dir() * 1.5)
	var pl = DL.pal(start)
	var m = _dango_mass(pl)
	_add(pj, m, start - Vector3.UP * 3.0)
	var drip = _stream(m, Vector3(0, -1.8, 0), 30, 0.9, pl["body"], {"dir": Vector3.DOWN, "spread": 20.0, "vmin": 0.2, "vmax": 1.0, "r": 1.8, "g": 14.0, "size": 0.08})
	# kopma yeri
	_burst_zone(start, 2.4)
	DL.pit(pj, start, 3.0, 4.5, 0.3)
	DL.crack(pj, start, 4.5, 5.0, 0.3, 0.0, 8.0)
	DL.dust_ring(pj, start, 2.2, 5.0, 8, 2.0, 1.2, pl["dust"])
	DL.burst_chunks(pj, start, 9, 0.4, 7.0, pl["body"], 1.1, -1, 1.0)
	pj.shake(0.6)
	var tw = m.create_tween()
	tw.tween_property(m, "global_position", c.global_position + Vector3.UP * 6.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_method(func(u):
		if is_instance_valid(m):
			var a = c.global_position + Vector3.UP * 6.5 if pj.live(c) else m.global_position
			m.global_position = a.lerp(target + Vector3.UP * 2.0, u) + Vector3.UP * sin(u * PI) * 3.0
			m.rotate_x(0.04), 0.0, 1.0, 0.55)
	tw.tween_callback(func():
		if is_instance_valid(drip):
			drip.emitting = false
		var tp = DL.pal(target)
		# çakılma (oyun tarafı: eski isabet çatlağı 3.5 * 2.4 + 10 m çatlak)
		_zone(target, 3.5 * 2.4)
		_zone(target, 10.0)
		DL.crack(pj, target, 7.0, 7.0, 0.2, 0.0, 10.0)
		DL.pit(pj, target, 2.6, 5.0, 0.15)
		DL.dust_ring(pj, target, 3.0, 8.0, 10, 2.8, 1.5, tp["dust"])
		DL.burst_chunks(pj, target + Vector3.UP * 0.5, 14, 0.55, 11.0, tp["body"], 0.9, -1, 1.3)
		DL.grit(pj, target + Vector3.UP * 0.5, 40, tp["body"], {"dir": Vector3.UP, "spread": 75.0, "vmin": 5.0, "vmax": 12.0, "r": 2.5})
		pj.hit(c, target + Vector3.UP, 6.5, pj.inf(c, "doton_doryo_dango", 2.2, {"knock": 16.0, "launch": 6.0, "kind": "heavy", "element": "doton", "hitstop": 0.1}))
		pj.shake(0.85)
		pj.shake(1.2))
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		var tp = DL.pal(target)
		DL.burst_chunks(pj, m.global_position + Vector3.UP * 1.0, 10, 0.4, 4.0, tp["body"], 1.2, 0, 1.0))
	tw.tween_property(m, "global_position", target - Vector3.UP * 2.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "scale", Vector3(1.0, 0.5, 1.0), 0.6)
	tw.tween_callback(m.queue_free)
	Sfx.play("earth", start, 0.6)


# ================================================================== 6) Kaido Shōkutsu: açılan toprak (yanardağ tümseği)
## Hedefin altında zemin oluklu yamaçlı, ağzı dudaklı bir koni (yanardağ gibi) halinde fışkırır; tepesinden gökyüzüne yüzlerce
## toprak tanesi ve parça püskürür (ref), yamaçtan parçalar yuvarlanır; sonra koni geri gömülür.
static func kaido_shokutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var pl = DL.pal(at)
	var prof = _prof([Vector2(3.7, -0.4), Vector2(3.1, 0.8), Vector2(2.3, 2.1), Vector2(1.6, 3.3), Vector2(1.3, 3.9), Vector2(1.1, 4.15), Vector2(0.82, 4.02), Vector2(0.55, 3.6), Vector2(0, 3.45)])
	var mound = DL.rock(DL.lathe_mesh(prof, 26, 15.0, 0.24, 0.04, randi() % 5), pl["body"].darkened(0.08), {"strata": 0.0, "ow": 0.06, "shadow": true})
	_add(pj, mound, at - Vector3.UP * 4.0)
	mound.rotation.y = randf() * TAU
	var tw = mound.create_tween()
	tw.tween_property(mound, "global_position", at, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		var top = at + Vector3.UP * 4.0
		DL.grit(pj, top, 70, pl["body"].lightened(0.1), {"dir": Vector3.UP, "spread": 28.0, "vmin": 9.0, "vmax": 17.0, "r": 0.7, "life": 1.5, "g": 12.0, "burst": 0.35})
		DL.grit(pj, top, 30, pl["dust"], {"dir": Vector3.UP, "spread": 40.0, "vmin": 6.0, "vmax": 11.0, "r": 0.5, "life": 1.3, "g": 10.0, "size": 0.04})
		for i in 9:
			var a = randf() * TAU
			var dv = Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35).normalized()
			DL.toss(pj, DL.chunk(randf_range(0.18, 0.4), randi() % 3, pl["body"].darkened(randf() * 0.2), {"ow": 0.03}), top, dv * randf_range(9.0, 14.0), 1.6)
		for i in 2:
			DL.dust(pj, top + Vector3.UP * (0.8 + i * 1.2), 2.4, 1.2, Vector3.UP * 1.5, pl["dust"])
		_zone(at, 8.0)
		DL.crack(pj, at, 6.0, 5.0, 0.15, 0.0, 12.0)
		pj.hit(c, at + Vector3.UP, 4.5, pj.inf(c, "doton_kaido_shokutsu", 1.5, {"knock": 4.0, "launch": 18.0, "kind": "heavy", "element": "doton"}))
		pj.shake(0.9))
	tw.tween_interval(1.0)
	tw.tween_property(mound, "global_position", at - Vector3.UP * 4.2, 0.6)
	tw.tween_callback(mound.queue_free)
	# yükseliş: tabanda halka toz, yamaçtan düşen parçalar
	_burst_zone(at, 2.5)
	DL.dust_ring(pj, at, 3.2, 6.0, 8, 2.0, 1.2, pl["dust"])
	pj.after(0.5, func():
		for i in 6:
			var a = randf() * TAU
			var p0 = at + Vector3(cos(a) * 1.8, 2.6, sin(a) * 1.8)
			DL.toss(pj, DL.chunk(randf_range(0.2, 0.35), 0, pl["body"], {"ow": 0.03}), p0, Vector3(cos(a), 0.3, sin(a)) * randf_range(3.0, 5.0), 1.0))
	Sfx.play("earth", at, 0.6)


# ================================================================== 7) Sando no Jutsu: sandviç (iki yarım kubbe)
## Hedefin iki yanından düz yüzleri birbirine dönük, yosun tonlu iki dev yarım kaya kubbesi yükselir (ref) ve hızla kapanıp hedefi
## arada ezer; birleşme çizgisinden yukarı toz ve çakıl fışkırır. Sonra iki yarım toprağa geri gömülür.
static func sando_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var side = (tt.global_position - c.global_position).cross(Vector3.UP).normalized()
	var pl = DL.pal(at)
	var tone: Color = pl["stone"].lerp(Color(0.36, 0.43, 0.37), 0.5)
	var prof = _prof([Vector2(2.7, -0.6), Vector2(2.68, 0.6), Vector2(2.45, 1.6), Vector2(1.95, 2.5), Vector2(1.1, 3.1), Vector2(0, 3.3)])
	for sx in [-1.0, 1.0]:
		var w = DL.rock(DL.lathe_mesh(prof, 14, 0.0, 0.0, 0.05, 11 + int(sx), PI), tone.darkened(randf_range(0.0, 0.08)), {"strata": 0.7, "ow": 0.07, "shadow": true})
		_add(pj, w, at + side * sx * 3.5 - Vector3.UP * 4.5)
		w.basis = Basis.looking_at(-side * sx, Vector3.UP)
		var tw = w.create_tween()
		tw.tween_property(w, "global_position", at + side * sx * 3.5, 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_property(w, "global_position", at + side * sx * 1.0, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_interval(1.6)
		tw.tween_property(w, "global_position", at + side * sx * 1.0 - Vector3.UP * 4.5, 0.5)
		tw.tween_callback(w.queue_free)
		var bp = at + side * sx * 3.5
		_burst_zone(bp, 1.4)
		DL.crack(pj, bp, 3.2, 3.0, 0.2, 0.0, 7.0)
		DL.grit(pj, bp + Vector3.UP * 0.3, 18, pl["body"], {"dir": Vector3.UP, "spread": 50.0, "vmin": 3.0, "vmax": 7.0, "r": 2.0})
		DL.dust(pj, bp + side * sx * 2.2 + Vector3.UP * 0.6, 2.0, 1.1, side * sx * 1.5, pl["dust"])
	pj.after(0.45, func():
		var seam = at + Vector3.UP * 1.5
		var fv = side.cross(Vector3.UP)
		DL.grit(pj, seam, 36, pl["body"], {"dir": Vector3.UP, "spread": 30.0, "vmin": 6.0, "vmax": 12.0, "r": 0.8})
		for i in 6:
			var dv = (Vector3.UP * 1.2 + fv * randf_range(-1.0, 1.0)).normalized()
			DL.toss(pj, DL.chunk(randf_range(0.15, 0.3), 2, tone, {"ow": 0.03}), seam + Vector3.UP * 1.2, dv * randf_range(6.0, 10.0), 1.2)
		for fs in [-1.0, 1.0]:
			DL.dust(pj, at + fv * fs * 2.6 + Vector3.UP * 1.0, 1.8, 1.0, fv * fs * 2.0 + Vector3.UP, pl["dust"])
		pj.hit(c, at + Vector3.UP, 2.0, pj.inf(c, "doton_sando_no_jutsu", 1.8, {"knock": 0.0, "kind": "heavy", "element": "doton"}))
		pj.st(tt, "stun", 1.5)
		pj.shake(0.8))
	Sfx.play("earth", at, 0.6)


# ================================================================== 8) Sokonashi Numa: dipsiz bataklık
## Zemin geniş, ıslak kahve bir bataklığa döner (ref: koyu hilal çizgileri yavaşça dönen çamur yüzeyi); kenarında kabaran çamur
## dudakları, yüzeyde patlayan kabarcıklar; içinde kalanların bellerine çamur halkası sarılır (batma). Sonra kuruyup kapanır.
static func sokonashi_numa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "crouch", 1.3)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	var pl = DL.pal(at)
	var mud: Color = pl["mud"].lerp(Color(0.45, 0.3, 0.17), 0.5)
	var pool = DL.disc(pj, at, 6.0, DL.swamp_mat())
	pool.set_instance_shader_parameter("mcol", DL.v3(mud))
	pool.set_instance_shader_parameter("seed", randf() * 10.0)
	pool.set_instance_shader_parameter("grow", 0.0)
	pool.set_instance_shader_parameter("fade", 0.0)
	var tw = pool.create_tween()
	tw.tween_method(DL.pf(pool, "grow"), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(8.0)
	tw.tween_method(DL.pf(pool, "fade"), 0.0, 1.0, 0.6)
	tw.tween_callback(pool.queue_free)
	# kenarda kabaran çamur dudakları
	var rim = Node3D.new()
	_add(pj, rim, at)
	for i in 14:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / 14.0
		var b = DL.mud_blob(randf_range(0.4, 0.65), mud.darkened(randf_range(0.0, 0.15)), 0.03)
		b.position = Vector3(cos(a) * 5.4, -0.1, sin(a) * 5.4)
		b.scale = Vector3(0.6, 0.05, 0.6)
		rim.add_child(b)
		b.create_tween().tween_property(b, "scale", Vector3(randf_range(0.5, 0.75), randf_range(0.18, 0.28), randf_range(0.4, 0.6)), 0.45).set_delay(0.2 + randf() * 0.2).set_trans(Tween.TRANS_BACK)
	var rt = rim.create_tween()
	rt.tween_interval(8.6)
	rt.tween_property(rim, "position", rim.position - Vector3.UP * 0.5, 0.6)
	rt.tween_callback(rim.queue_free)
	_zone(at, 7.0, 9.0)
	DL.ripple(pj, at, 6.5, 1.1)
	var collars = {}
	pj.every(8.5, 0.3, func(_i, _k):
		for j in 2:
			var a = randf() * TAU
			_mud_bubble(pj, at + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 5.0), mud)
		var seen = {}
		for e in pj.enemies_near(c, at, 6.0):
			pj.st(e, "bind", 0.5)
			pj.st(e, "slow", 1.0)
			var id = e.get_instance_id()
			seen[id] = true
			if not collars.has(id) or not is_instance_valid(collars[id]):
				collars[id] = _mud_collar(pj, e, mud)
			var cl: Node3D = collars[id]
			cl.create_tween().tween_property(cl, "global_position", pj.gp(e.global_position) + Vector3.UP * 0.05, 0.28)
		for id in collars.keys():
			if not seen.has(id):
				var cl2 = collars[id]
				if is_instance_valid(cl2):
					cl2.queue_free()
				collars.erase(id), func():
		for id in collars.keys():
			if is_instance_valid(collars[id]):
				collars[id].queue_free()
		collars.clear())
	Sfx.play("water", at, 0.5)


static func _mud_bubble(pj: PathJutsu, p: Vector3, mud: Color) -> void:
	var b = DL.mud_blob(randf_range(0.14, 0.26), mud.lightened(0.08), 0.02)
	_add(pj, b, DL.floor_at(p) + Vector3.UP * 0.02)
	var s = b.scale
	b.scale = s * Vector3(1.0, 0.1, 1.0)
	var tw = b.create_tween()
	tw.tween_property(b, "scale", s * Vector3(1.0, 0.75, 1.0), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_method(DL.pf(b, "melt"), 0.0, 1.0, 0.25)
	tw.tween_callback(b.queue_free)


static func _mud_collar(pj: PathJutsu, e: Node3D, mud: Color) -> Node3D:
	var root = Node3D.new()
	_add(pj, root, pj.gp(e.global_position))
	for i in 7:
		var a = TAU * i / 7.0 + randf() * 0.3
		var b = DL.mud_blob(randf_range(0.28, 0.38), mud.darkened(randf_range(0.0, 0.1)), 0.025)
		b.position = Vector3(cos(a) * 0.48, 0.25, sin(a) * 0.48)
		b.scale = Vector3(0.3, 0.32, 0.3)
		root.add_child(b)
	root.scale = Vector3(1, 0.1, 1)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	DL.kill(pj, 9.5, root)
	return root


# ================================================================== 9) Dorojigoku: ters karınca aslanı (toprak etek)
## Hedefin çevresinde kum huni açılır, içinden kıvrım kıvrım sırtlı bir toprak etek fışkırıp onu beline kadar yutar (ref: belden
## aşağısı yerden kabaran, derin oluklu toprak çan). Huniye taneler süzülür; bitişte etek patlayıp geri gömülür.
static func dorojigoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var pl = DL.pal(at)
	var tone: Color = pl["body"].lerp(Color(0.62, 0.38, 0.22), 0.4)
	_burst_zone(at, 1.4)
	DL.pit(pj, at, 2.3, 4.2, 0.2)
	DL.grit(pj, at + Vector3.UP * 0.2, 22, tone, {"dir": Vector3.UP, "spread": 60.0, "vmin": 3.0, "vmax": 6.0, "r": 1.2})
	var prof = _prof([Vector2(1.75, -0.25), Vector2(1.55, 0.15), Vector2(1.15, 0.5), Vector2(0.78, 0.85), Vector2(0.52, 1.08), Vector2(0.42, 1.17), Vector2(0.34, 1.07), Vector2(0.3, 0.8)])
	var skirt = DL.rock(DL.lathe_mesh(prof, 22, 9.0, 0.5, 0.04, randi() % 5), tone, {"strata": 0.0, "ow": 0.045, "shadow": true})
	_add(pj, skirt, at - Vector3.UP * 1.2)
	skirt.rotation.y = randf() * TAU
	var tw = skirt.create_tween()
	tw.tween_property(skirt, "global_position", at, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(3.2)
	tw.tween_callback(func():
		_burst_zone(at, 1.0)
		DL.burst_chunks(pj, at + Vector3.UP * 0.6, 9, 0.28, 6.0, tone, 1.0, -1, 0.9)
		DL.dust_ring(pj, at, 0.8, 2.6, 6, 1.3, 0.9, pl["dust"]))
	tw.tween_property(skirt, "global_position", at - Vector3.UP * 1.3, 0.4)
	tw.tween_callback(skirt.queue_free)
	pj.every(3.2, 0.4, func(_i, _k):
		var a = randf() * TAU
		DL.grit(pj, at + Vector3(cos(a), 0.15, sin(a)) * 2.0, 6, pl["dust"], {"dir": (-Vector3(cos(a), 0, sin(a)) + Vector3.DOWN * 0.2).normalized(), "spread": 15.0, "vmin": 1.0, "vmax": 2.0, "r": 0.3, "life": 0.7, "g": 2.0, "size": 0.04}), Callable())
	pj.st(tt, "bind", 3.5)
	tt.take_hit(pj.inf(c, "doton_dorojigoku", 0.4, {"knock": 0.0, "kind": "light", "element": "doton"}))
	Combat.popup_text(at + Vector3.UP * 2.2, "Toprağa hapsoldu!", Color(0.55, 0.42, 0.3).lightened(0.3))
	Sfx.play("earth", at, 0.9)


# ================================================================== 10) Dangan no Jutsu: mermi kaya (Ōnoki)
## Önündeki zemin yarılır, çimen tepeli iri bir kaya yerden kopup havada asılı kalır (altından toprak dökülür); itişle döne döne
## fırlar, arkasında çakıl izi; çarpınca parçalanır: kıymıklar, çatlak, yer seviyesi toz.
static func _boulder(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var rk = DL.rock(DL.chunk_mesh(0, randi() % 6), pl["body"].lerp(Color(0.72, 0.6, 0.44), 0.3), {"top": pl["top"], "top_y": 0.6, "strata": 1.6, "ow": 0.05, "shadow": true})
	rk.scale = Vector3(1.3, 1.05, 1.3)
	root.add_child(rk)
	for i in 3:
		var bp = DL.rock(DL.chunk_mesh(2, i), pl["deep"], {"ow": 0.035})
		var a = TAU * i / 3.0
		bp.position = Vector3(cos(a) * 0.8, -0.65, sin(a) * 0.8)
		bp.scale = Vector3.ONE * 0.45
		root.add_child(bp)
	return root


static func dangan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.2)
	pj.anim(c, "cast", 1.0)
	var g = pj.gp(c.global_position + c.face_dir() * 2.2)
	var pl = DL.pal(g)
	var rk = _boulder(pl)
	_add(pj, rk, g - Vector3.UP * 1.6)
	rk.create_tween().tween_property(rk, "global_position", g + Vector3.UP * 3.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rk.create_tween().tween_property(rk, "rotation:y", randf_range(-0.6, 0.6), 0.75)
	_stream(rk, Vector3(0, -0.9, 0), 18, 0.8, pl["body"], {"dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.2, "vmax": 1.0, "r": 0.8, "g": 12.0, "size": 0.06})
	_burst_zone(g, 1.6)
	DL.pit(pj, g, 1.5, 3.0, 0.15)
	DL.crack(pj, g, 2.6, 3.5, 0.2, 0.0, 7.0)
	DL.grit(pj, g + Vector3.UP * 0.2, 20, pl["body"], {"dir": Vector3.UP, "spread": 40.0, "vmin": 4.0, "vmax": 8.0, "r": 0.9})
	DL.burst_chunks(pj, g, 6, 0.25, 5.0, pl["body"], 1.2, 0, 0.9)
	pj.shake(0.35)
	Sfx.play("earth", g, 0.9)
	pj.after(0.75, func():
		if not is_instance_valid(rk):
			return
		var from = rk.global_position
		rk.queue_free()
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.5)
		var mesh = _boulder(pl)
		_stream(mesh, Vector3.ZERO, 40, 0.6, pl["body"], {"dir": Vector3.UP, "spread": 180.0, "vmin": 0.3, "vmax": 1.2, "r": 0.9, "g": 6.0, "size": 0.07})
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 26.0, mesh, pj.inf(c, "doton_dangan_no_jutsu", 1.0, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "element": "doton"}), null, false, 1.8, func(p, _h):
			var gg = DL.floor_at(p)
			var tp = DL.pal(gg)
			if p.y - gg.y < 2.5:
				_zone(gg, 3.5 * 1.6)
				DL.crack(pj, gg, 3.6, 4.5, 0.15, 0.0, 9.0)
				DL.dust_ring(pj, gg, 1.0, 4.0, 7, 1.8, 1.1, tp["dust"])
			for i in 10:
				var dv = Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
				DL.toss(pj, DL.chunk(randf_range(0.2, 0.45), 1 if i % 2 == 0 else 0, tp["body"].darkened(randf() * 0.15), {"ow": 0.03}), p, dv * randf_range(6.0, 12.0), 1.2)
			DL.grit(pj, p, 34, tp["body"], {"spread": 180.0, "vmin": 4.0, "vmax": 10.0, "r": 0.6})
			pj.shake(0.65)
			pj.shake(0.5))
		if pr:
			pr.radius = 1.5
			pr.spin = Vector3(3, 1, 0))


# ================================================================== 11) Senpuku: toprak gizlenmesi (Kabuto)
## Bacaklarda mavi chakra tüter, beden yere gömülürken ayak çevresinde çimenli toprak kabarır ve kırılır. 3 sn sonra hedefin
## dibinden çıkarken çimen tabakası halka halinde kalkıp dışa devrilir (ref: kırık toprak ayak bileklerinde), yumruklardan mavi
## chakra parlar, çakıl yukarı fışkırır.
static func _chakra_wisp(parent: Node3D, offset: Vector3, amount: int) -> GPUParticles3D:
	return _stream(parent, offset, amount, 0.55, CHAKRA, {"dir": Vector3.UP, "spread": 25.0, "vmin": 0.6, "vmax": 1.8, "r": 0.35, "g": -1.0,
		"mesh": _bead_mesh(0.05), "mat": DL.bead_mat(Color(1, 1, 1, 1)), "ramp": _fade_ramp(CHAKRA), "smin": 0.6, "smax": 1.6})


static func senpuku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.4)
	pj.anim(c, "crouch", 1.6)
	var g0 = pj.gp(c.global_position)
	var pl = DL.pal(g0)
	var glow = _chakra_wisp(c, Vector3(0, 0.35, 0), 40)
	# gömülme: ayak çevresinde kabarıp kırılan çimenli toprak
	var heap = Node3D.new()
	_add(pj, heap, g0)
	for i in 8:
		var a = TAU * (i + randf_range(-0.2, 0.2)) / 8.0
		var lp = DL.rock(DL.chunk_mesh(2, i), pl["body"], {"ow": 0.03, "top": pl["top"], "top_y": 0.3})
		lp.position = Vector3(cos(a) * 0.7, -0.2, sin(a) * 0.7)
		lp.scale = Vector3(0.36, 0.22, 0.3)
		lp.rotation = Vector3(0, -a, deg_to_rad(randf_range(15, 35)))
		heap.add_child(lp)
		lp.create_tween().tween_property(lp, "position:y", 0.05, 0.35).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK)
	var ht = heap.create_tween()
	ht.tween_interval(3.0)
	ht.tween_property(heap, "position", heap.position - Vector3.UP * 0.5, 0.6)
	ht.tween_callback(heap.queue_free)
	DL.crack(pj, g0, 1.5, 3.4, 0.2, 0.0, 6.0)
	DL.grit(pj, g0 + Vector3.UP * 0.2, 14, pl["body"], {"dir": Vector3.UP, "spread": 60.0, "vmin": 1.5, "vmax": 3.0, "r": 0.5, "life": 0.6})
	Sfx.play("earth", c.global_position, 0.6)
	var m = c.get("model")
	if m:
		m.create_tween().tween_property(m, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)   # yavaşça batar
	pj.after(0.65, func():
		if is_instance_valid(glow):
			glow.emitting = false
			DL.kill(pj, 0.7, glow))
	if c is Player:
		Buffs.add("stealth_senpuku", 3.0, {"stealth": 1.0, "armor": 0.0, "_desc": "Yerin altındasın: görünmez, hasar almazsın"})
	pj.after(3.0, func():
		if not pj.live(c):
			return
		var tt = pj.tg(c, t, 14.0)
		if tt:
			c.global_position = pj.gp(tt.global_position + pj.fwd(c, tt) * -0.8)
		if m:
			m.create_tween().tween_property(m, "position:y", 0.0, 0.15)
		pj.anim(c, "hook", 1.6)
		_burst_zone(c.global_position, 1.6)
		_turf_burst(pj, c.global_position)
		var fist = _chakra_wisp(c, Vector3(0, 1.2, 0), 30)
		pj.after(0.35, func():
			if is_instance_valid(fist):
				fist.emitting = false
				DL.kill(pj, 0.7, fist))
		Sfx.play("hit_heavy", c.global_position, 0.9)
		var hs = pj.hit(c, c.global_position + Vector3.UP * 1.0, 2.0, pj.inf(c, "senpuku", 1.0, {"launch": 9.0, "knock": 4.0, "kind": "heavy"}))
		if not hs.is_empty() and is_instance_valid(hs[0]):
			var hp = hs[0].global_position + Vector3.UP * 1.0
			DL.grit(pj, hp, 16, DL.pal(hp)["body"], {"dir": Vector3.UP, "spread": 35.0, "vmin": 4.0, "vmax": 8.0, "r": 0.3, "life": 0.7}))


static func _turf_burst(pj: PathJutsu, p0: Vector3) -> void:
	var g = DL.floor_at(p0)
	var pl = DL.pal(g)
	DL.crack(pj, g, 2.6, 4.0, 0.12, 0.0, 8.0)
	DL.pit(pj, g, 0.9, 3.0, 0.1)
	for i in 9:
		var a = TAU * (i + randf_range(-0.25, 0.25)) / 9.0
		var outv = Vector3(cos(a), 0, sin(a))
		var slab = DL.rock(DL.chunk_mesh(2, i), pl["body"], {"ow": 0.035, "top": pl["top"], "top_y": 0.32})
		slab.scale = Vector3(randf_range(0.4, 0.6), randf_range(0.3, 0.42), randf_range(0.3, 0.45))
		var pv = Node3D.new()
		pv.add_child(slab)
		slab.position = Vector3(0, 0.15, 0)
		_add(pj, pv, g + outv * 0.75 - Vector3.UP * 0.3)
		pv.basis = Basis.looking_at(-outv, Vector3.UP)
		var tw = pv.create_tween()
		tw.tween_property(pv, "global_position", g + outv * 0.85, 0.12).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(pv, "rotation:x", deg_to_rad(randf_range(-55, -35)), 0.18)
		tw.tween_interval(2.0)
		tw.tween_property(pv, "global_position", g + outv * 0.85 - Vector3.UP * 0.6, 0.6)
		tw.tween_callback(pv.queue_free)
	DL.grit(pj, g + Vector3.UP * 0.3, 30, pl["body"], {"dir": Vector3.UP, "spread": 45.0, "vmin": 5.0, "vmax": 10.0, "r": 0.6})
	DL.dust(pj, g + Vector3.UP * 0.6, 1.6, 0.9, Vector3.UP * 1.2, pl["dust"])


# ================================================================== 12) Doryū Jōheki: toprak sur (dev uçurum)
## Önünde 18 m'lik kızıl kahve, dikey oluklu bir uçurum duvarı yükselir; tepesi çimen örtülü, ön yüzünde sıra sıra dik sütunlar
## ve gölgeli oluklar, tabanında toz perdesi, yüzünden dökülen ince toprak şeritleri (ref). Mermileri durdurur (çakıla döner).
static func doryu_joheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 4.0)
	var side = d.cross(Vector3.UP)
	var pl = DL.pal(at)
	var tone: Color = pl["body"].lerp(Color(0.6, 0.38, 0.3), 0.45)
	var wall = Node3D.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()
	for k in 9:
		var x = -8.0 + k * 2.0
		var h = 7.0 + rng.randf_range(-0.6, 0.8)
		var col = DL.rock(DL.prism_mesh(DL.jag_rect(2.25, 1.8, 2, 0.14, rng), -0.5, h, 0.04, 0.12, rng.randi()), tone.darkened(rng.randf_range(0.0, 0.12)), {"top": pl["top"], "top_y": h - 0.2, "strata": 0.5, "ow": 0.06, "shadow": true})
		col.position = Vector3(x, 0, rng.randf_range(-0.12, 0.12))
		wall.add_child(col)
		# ön yüzde (+Z, düşmana bakan) dik sütun sırtları ve aralarında koyu oluklar
		for f in 2:
			var fx = x + (f - 0.5) * 1.0 + rng.randf_range(-0.2, 0.2)
			var fh = h * rng.randf_range(0.6, 0.95)
			var rib = DL.rock(DL.prism_mesh(DL.jag_circle(0.32, 5, 0.2, rng), -0.5, fh, 0.08, 0.15, rng.randi()), tone.lightened(rng.randf_range(0.0, 0.08)), {"strata": 0.5, "ow": 0.04})
			rib.position = Vector3(fx, 0, 0.95)
			wall.add_child(rib)
		var gul = DL.rock(DL.prism_mesh(DL.jag_rect(0.35, 0.3, 1, 0.05, rng), -0.5, h * 0.85, 0.05, 0.1, rng.randi()), tone.darkened(0.45), {"ow": 0.0})
		gul.position = Vector3(x + 1.0, 0, 0.88)
		wall.add_child(gul)
	_add(pj, wall, at - Vector3.UP * 7.5)
	wall.rotation.y = atan2(d.x, d.z)
	for k in 5:
		var bp = at + side * ((k - 2) * 4.0)
		_burst_zone(bp, 1.4)
		DL.crack(pj, bp, 3.0, 10.0, 0.25, 0.0, 7.0)
		DL.grit(pj, bp + Vector3.UP * 0.3, 14, pl["body"], {"dir": (Vector3.UP + d * 0.4).normalized(), "spread": 40.0, "vmin": 3.0, "vmax": 7.0, "r": 1.2})
		if k % 2 == 0:
			DL.dust(pj, bp + d * 1.8 + Vector3.UP * 0.7, 2.6, 1.6, d * 1.5 + Vector3.UP * 0.4, pl["dust"])
	var body = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new()
	bx.size = Vector3(18.0, 7.0, 1.6)
	cs.shape = bx
	body.add_child(cs)
	wall.add_child(body)
	body.position = Vector3.UP * 3.5
	var tw = wall.create_tween()
	tw.tween_property(wall, "global_position", at, 0.5).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(9.0)
	tw.tween_property(wall, "global_position", at - Vector3.UP * 7.5, 0.6)
	tw.tween_callback(wall.queue_free)
	# yüzden dökülen ince toprak şeritleri
	pj.after(0.45, func():
		if not is_instance_valid(wall):
			return
		for k in 5:
			var q = at + side * rng.randf_range(-8.0, 8.0) + d * 1.1 + Vector3.UP * rng.randf_range(5.0, 7.0)
			DL.grit(pj, q, 14, pl["dust"], {"dir": Vector3.DOWN, "spread": 6.0, "vmin": 0.5, "vmax": 1.5, "r": 0.15, "life": 1.3, "g": 8.0, "size": 0.05, "burst": 0.2}))
	pj.every(9.5, 0.1, func(_i, _k):
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and is_instance_valid(wall) and absf((p.global_position - at).dot(d)) < 1.2 and absf((p.global_position - at).dot(side)) < 9.0:
				DL.grit(pj, p.global_position, 10, tone, {"vmin": 2.0, "vmax": 5.0, "spread": 140.0, "life": 0.6, "r": 0.2})
				p.queue_free(), Callable())
	pj.shake(0.9)
	Sfx.play("earth", at, 0.5)


# ================================================================== 13) Kengan no Jutsu: kaya yumruk (Ōnoki)
## Yumruklar yüzey yüzey yontulmuş kaya plakalarla kaplanır (ref: iri, köşeli taş eldiven); oluşurken zeminden çakıllar ele
## doğru uçar. 12 sn sonra kaplama ufalanıp yere dökülür.
static func _gauntlet(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var tone: Color = pl["body"].lerp(Color(0.6, 0.47, 0.33), 0.5)
	var core = DL.rock(DL.chunk_mesh(2, randi() % 6), tone, {"ow": 0.012})
	core.scale = Vector3(0.18, 0.15, 0.17)
	core.position = Vector3(0, 0.07, 0.01)
	root.add_child(core)
	for i in 6:
		var a = TAU * i / 6.0 + randf() * 0.3
		var pd = DL.rock(DL.chunk_mesh(2, i), tone.darkened(randf_range(0.0, 0.14)), {"ow": 0.01})
		pd.scale = Vector3.ONE * randf_range(0.07, 0.095)
		pd.position = Vector3(cos(a) * 0.12, 0.07 + sin(a) * 0.11, 0.06 * (1.0 if i % 2 == 0 else -1.0))
		pd.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		root.add_child(pd)
	return root


static func kengan_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var parts = []
	var pl = DL.pal(c.global_position)
	for right in [true, false]:
		var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
		if ba == null:
			continue
		var gl = _gauntlet(pl)
		ba.add_child(gl)
		gl.scale = Vector3.ONE * 0.1
		gl.create_tween().tween_property(gl, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		parts.append(ba)
		var hp = pj.hand_pos(c, right)
		for i in 5:
			var pb = DL.chunk(randf_range(0.04, 0.07), 0, pl["body"], {"ow": 0.01})
			var a = randf() * TAU
			var p0 = DL.floor_at(c.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 1.4)) + Vector3.UP * 0.05
			_add(pj, pb, p0)
			var tw = pb.create_tween()
			tw.tween_method(func(u: float) -> void:
				if is_instance_valid(pb):
					pb.global_position = p0.lerp(hp, u) + Vector3.UP * sin(u * PI) * 0.5, 0.0, 1.0, 0.22 + i * 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(pb.queue_free)
	if c is Player:
		Buffs.add("kengan", 12.0, {"melee": 1.35, "_name": "Kaya Yumruk", "_desc": "yumruklar kaya kaplı: yakın dövüş +%35"})
	pj.after(12.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				var hp2 = pp.global_position
				for i in 5:
					var cb = DL.chunk(randf_range(0.04, 0.08), 2, pl["body"], {"ow": 0.01})
					DL.toss(pj, cb, hp2, Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5)), 0.9, 18.0, 0.5)
				DL.grit(pj, hp2, 10, pl["body"], {"spread": 120.0, "vmin": 0.5, "vmax": 2.0, "r": 0.1, "life": 0.6, "size": 0.035})
				pp.queue_free())
	Sfx.play("earth", c.global_position, 1.3)


# ================================================================== 14) Keijūgan no Jutsu: hafifletme / uçuş (Ōnoki)
## Kaya kabuğu yok: beden hafiflerken ayak çevresindeki toz ve çakıl yerden kalkıp süzülür, bedenden ince kum taneleri tüy gibi
## yavaşça dökülür; uçarken ayaklardan süzülen taneler ve belde ağır ağır dönen birkaç küçük çakıl (ağırlıksızlık) eşlik eder.
static func _light_vis(pl: Dictionary) -> Node3D:
	var vis = Node3D.new()
	var sand: Color = pl["dust"].lightened(0.1)
	_stream(vis, Vector3(0, 0.5, 0), 26, 1.8, sand, {"dir": Vector3.DOWN, "spread": 60.0, "vmin": 0.1, "vmax": 0.5, "r": 0.4, "g": 1.2, "size": 0.035, "ramp": _fade_ramp(sand)})
	var pivot = Node3D.new()
	pivot.name = "Orbit"
	pivot.position = Vector3(0, 0.95, 0)
	vis.add_child(pivot)
	for i in 5:
		var a = TAU * i / 5.0
		var pb = DL.rock(DL.chunk_mesh(i % 3, i), pl["body"].lightened(0.05), {"ow": 0.012})
		pb.scale = Vector3.ONE * randf_range(0.05, 0.09)
		pb.position = Vector3(cos(a) * 0.75, randf_range(-0.35, 0.35), sin(a) * 0.75)
		pivot.add_child(pb)
	return vis


## Ağırlıksız çakılların dönüşü ve salınımı (görsel sahneye girdikten sonra başlar: ağaç dışı düğümde tween kurulamaz)
static func _light_vis_anim(vis: Node3D) -> void:
	if not is_instance_valid(vis) or not vis.is_inside_tree():
		return
	var pivot = vis.get_node_or_null("Orbit")
	if pivot == null:
		return
	var i = 0
	for pb in pivot.get_children():
		var bt = Game.safe_loops(pb.create_tween())
		var y0 = pb.position.y
		bt.tween_property(pb, "position:y", y0 + 0.12, 0.9 + i * 0.1).set_trans(Tween.TRANS_SINE)
		bt.tween_property(pb, "position:y", y0 - 0.12, 0.9 + i * 0.1).set_trans(Tween.TRANS_SINE)
		i += 1
	var rt = Game.safe_loops(pivot.create_tween())
	rt.tween_property(pivot, "rotation:y", TAU, 5.0).from(0.0)


static func keijugan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	var pl = DL.pal(g)
	DL.grit(pj, g + Vector3.UP * 0.1, 22, pl["dust"], {"dir": Vector3.UP, "spread": 85.0, "vmin": 1.0, "vmax": 2.5, "r": 1.0, "life": 1.4, "g": 1.0, "size": 0.04})
	DL.grit(pj, c.global_position + Vector3.UP * 1.0, 16, pl["dust"].lightened(0.1), {"dir": Vector3.DOWN, "spread": 40.0, "vmin": 0.2, "vmax": 0.8, "r": 0.5, "life": 1.2, "g": 1.5, "size": 0.035})
	for i in 5:
		var a = randf() * TAU
		var p0 = DL.floor_at(g + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 1.6)) + Vector3.UP * 0.05
		var pb = DL.chunk(randf_range(0.06, 0.12), 0, pl["body"], {"ow": 0.015})
		_add(pj, pb, p0)
		var tw = pb.create_tween()
		tw.tween_property(pb, "global_position", p0 + Vector3.UP * randf_range(1.0, 1.8), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(pb, "global_position", p0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(pb.queue_free)
	# oynanış (klan işleyicisinden birebir)
	if not c is Player:
		return
	if c.flight_source() == "light":
		c.stop_flight()
		return
	var vis = _light_vis(pl)
	c.start_flight("light", {"speed": 13.0, "lift": 9.0, "drain": 3.0, "vis": vis, "name": "Hafif Kaya"})
	_light_vis_anim(vis)


# ================================================================== 15) Iwayado Kuzushi: kaya konağı yıkımı
## Gökten sekiz uzun, köşeli kaya levha düşüp hedefin çevresine saplanır; tepeleri içe yaslanarak bir taş çadır (konak) kurar.
## Kapanınca dibinde toz ve çakıl; sonra levhalar içe çöküp parçalanır: kırık taş saçılması, çatlak, toz halkası.
static func iwayado_kuzushi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt24 = pj.tg(c, t, 24.0)
	var tt = pj.tg(c, t, 22.0)
	if tt != null:
		var p = pj.gp(tt.global_position)
		pj.st(tt, "bind", 3.0)
		var pl = DL.pal(p)
		var tone: Color = pl["stone"].lerp(Color(0.52, 0.47, 0.4), 0.5)
		var rng = RandomNumberGenerator.new()
		rng.seed = randi()
		var slabs = []
		for k in 8:
			var a = k * TAU / 8.0
			var radial = Vector3(cos(a), 0, sin(a))
			var h = rng.randf_range(3.0, 3.6)
			var sl = DL.rock(DL.prism_mesh(DL.jag_rect(rng.randf_range(1.1, 1.4), 0.5, 2, 0.12, rng), -0.4, h, 0.06, 0.25, rng.randi()), tone.darkened(rng.randf_range(0.0, 0.14)), {"strata": 1.2, "ow": 0.05, "shadow": true})
			var base = p + radial * 1.6
			var apex = p + Vector3.UP * (h * 0.85)
			_add(pj, sl, p + radial * 1.7 + Vector3.UP * 14.0)
			var bs = _basis_up(apex - base)
			# levhanın geniş yüzü merkeze baksın
			var zf = (Vector3(-radial.x, 0, -radial.z) - bs.y * (-radial).dot(bs.y)).normalized()
			sl.basis = Basis(bs.y.cross(zf).normalized(), bs.y, zf)
			sl.set_meta("base", base)
			sl.set_meta("radial", radial)
			var tw = sl.create_tween()
			tw.tween_property(sl, "global_position", base, 0.35).set_delay(k * 0.05).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				DL.grit(pj, base + Vector3.UP * 0.2, 8, pl["body"], {"dir": Vector3.UP, "spread": 60.0, "vmin": 2.0, "vmax": 4.0, "r": 0.4, "life": 0.6}))
			slabs.append(sl)
			DL.kill(pj, 3.6, sl)
		pj.after(0.75, func():
			DL.dust_ring(pj, p, 1.8, 3.6, 7, 1.4, 1.0, pl["dust"])
			DL.crack(pj, p, 2.8, 3.0, 0.15, 0.0, 8.0)
			pj.shake(0.5))
		pj.after(2.9, func():
			for sl in slabs:
				if is_instance_valid(sl):
					var rd: Vector3 = sl.get_meta("radial")
					var ct = sl.create_tween()
					ct.tween_property(sl, "global_position", p + rd * 0.7 + Vector3.UP * 0.3, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					ct.tween_callback(func():
						if is_instance_valid(sl):
							DL.burst_chunks(pj, sl.global_position + Vector3.UP * 0.8, 4, 0.32, 5.0, tone, 0.9, 2, 1.0)
							sl.queue_free())
			DL.crack(pj, p, 3.4, 4.0, 0.12, 0.3, 9.0)
			DL.dust_ring(pj, p, 1.0, 4.5, 8, 1.8, 1.2, pl["dust"])
			DL.grit(pj, p + Vector3.UP * 1.0, 30, tone, {"spread": 120.0, "vmin": 4.0, "vmax": 9.0, "r": 1.0})
			if pj.live(tt):
				pj.hit(c, tt.global_position + Vector3.UP, 1.6, pj.inf(c, "doton_iwayado_kuzushi", 2.2, {"knock": 4.0, "kind": "heavy", "hitstop": 0.12}))
			Sfx.play("earth", p, 0.6))
	if tt24:
		pj.after(0.4, func():
			if pj.live(tt24):
				var q = tt24.global_position
				DL.grit(pj, q + Vector3.UP * 3.0, 18, DL.pal(q)["body"], {"dir": Vector3.DOWN, "spread": 50.0, "vmin": 1.0, "vmax": 3.0, "r": 1.4, "life": 0.9}))
