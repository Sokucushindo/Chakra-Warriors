class_name MokutonFXB
extends RefCounted
## Mokuton grubu B: on ahşap tekniğinin görselleri. Malzeme ve yapı taşları MokutonLib'den (canlı ahşap shader'ı: kökten uca
## gerçek zamanlı büyüme, kabuk / budak / kesik yüz halkası, kontur, kameraya yakın noktalı inceltme). Her tekniğin şekli, hareketi
## ve sahnelenmesi bu dosyada ve birbirinden ayrı; grup A'nın kompozisyonları kullanılmadı. Ortak efekt yardımcısı yok.
## Oynanış (hasar, durum, süre, menzil, hedefleme, zemin bölgeleri) ana ağaçtaki işleyicilerden satır satır taşındı.
## Mevcut sistemler korunur: Shin Sūsenju heykeli gerçek ShinSusenju modeli; Chōjō Kebutsu da aynı modeli uzak bulut setinde kullanır.

const ML = preload("res://scripts/combat/fx/lib/mokuton_lib.gd")

const PETAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

instance uniform float nf = 4.0;

NOISE

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) {
		discard;
	}
	vec3 c = COLOR.rgb;
	float ndv = abs(dot(NORMAL, VIEW));
	c *= mix(0.72, 1.0, smoothstep(0.08, 0.4, ndv));
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
}
"""

## Polen pusu: kenarı yumuşak, içi gürültüyle kıpırdayan sarı sis kütlesi; kameraya yaklaşınca tamamen saydamlaşır
const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float dens = 0.0;
instance uniform float seed = 0.0;
uniform vec3 hz = vec3(0.98, 0.88, 0.46);

NOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(0.05, 0.75, ndv);
	float n = mf3(lp * 1.6 + vec3(seed, TIME * 0.15, seed * 0.5));
	float dist = length(VERTEX);
	float camf = smoothstep(8.0, 14.0, dist);
	ALBEDO = pow(hz * (0.92 + 0.12 * n), vec3(2.2));
	ALPHA = clamp(dens * edge * (0.55 + 0.6 * n) * camf, 0.0, 1.0);
}
"""

static var _cache := {}


# ================================================================== ortak oynanış izi
## Eski zemin çatlağının oyun tarafı: büyük yarık zemin üstünden geçeni yavaşlatır (boy >= 1.5)
static func _crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(pos, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


# ================================================================== malzemeler
static func _smat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("NOISE", ML.NOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _flat(key0: String, col: Color, alpha := false, vcol := false) -> StandardMaterial3D:
	var key = "flat:" + key0   # önbellekte aynı adlı mesh ile çakışmasın
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if vcol:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	_cache[key] = m
	return m


static func _ball(r: float) -> SphereMesh:
	var key = "ball_%.3f" % r
	if _cache.has(key):
		return _cache[key]
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	_cache[key] = s
	return s


## Eğri boyunca q (0..1) konumu
static func _along(pts: Array, q: float) -> Vector3:
	var n = pts.size()
	if n == 0:
		return Vector3.ZERO
	var f = clampf(q, 0.0, 1.0) * float(n - 1)
	var i = mini(int(f), n - 2)
	if n < 2:
		return pts[0]
	var a: Vector3 = pts[i]
	var b: Vector3 = pts[i + 1]
	return a.lerp(b, f - float(i))


## Yay çizerek konumdan konuma uçuş (yükseklik h)
static func _arc_to(n: Node3D, p0: Vector3, p1: Vector3, h: float, dur: float) -> Tween:
	var mid = (p0 + p1) * 0.5 + Vector3.UP * h
	var tw = n.create_tween()
	tw.tween_method(func(q: float):
		if is_instance_valid(n):
			n.global_position = p0.lerp(mid, q).lerp(mid.lerp(p1, q), q), 0.0, 1.0, dur)
	return tw


# ================================================================== el yapı taşı
## Ahşap el (yerel: bilek o.base'de, parmaklar +Y, avuç içi +Z). o: arm (ön kol boyu), curl (parmak kıvrımı, rad), spread,
## band (bilek bandı), cuff (geniş yen ağzı), thumb (başparmak yanı ±1), seed. Dönüş: parmak ucunun kökten uzaklığı.
static func _hand(g, s: float, o := {}) -> float:
	var b0: Vector3 = o.get("base", Vector3.ZERO)
	var arm: float = float(o.get("arm", 2.0)) * s
	var curl: float = float(o.get("curl", 0.4))
	var spread: float = float(o.get("spread", 0.08))
	var sd: float = float(o.get("seed", 0.0))
	var side: float = float(o.get("thumb", 1.0))
	var fr = 0.34 * s
	var s1 = ML.tube(g, [b0 + Vector3(0, -arm, -0.06 * s), b0 + Vector3(0, -arm * 0.5, -0.03 * s), b0 + Vector3(0, 0.05 * s, 0)],
		[fr * 1.15, fr, fr * 0.9], {"sides": 12, "seed": sd, "cap_end": false, "gnarl": 0.05})
	if bool(o.get("band", false)):
		ML.tube(g, [b0 + Vector3(0, -0.34 * s, 0), b0 + Vector3(0, -0.12 * s, 0)], [fr * 1.16, fr * 1.12],
			{"sides": 12, "gnarl": 0.0, "tint": Color(0.5, 0.47, 0.44), "s0": s1 - 0.3 * s, "cap_end": false})
	if bool(o.get("cuff", false)):
		ML.tube(g, [b0 + Vector3(0, -arm * 0.75, -0.06 * s), b0 + Vector3(0, -arm * 0.55, -0.05 * s), b0 + Vector3(0, -arm * 0.42, -0.04 * s)],
			[fr * 1.25, fr * 1.6, fr * 1.75], {"sides": 14, "gnarl": 0.02, "tint": Color(0.8, 0.76, 0.72), "s0": arm * 0.25, "cap_end": true})
	var palm_n = func(_i, _p, _ti): return Vector3.RIGHT
	var s2 = ML.tube(g, [b0 + Vector3(0, -0.05 * s, 0), b0 + Vector3(0, 0.36 * s, 0.03 * s), b0 + Vector3(0, 0.78 * s, 0.05 * s)],
		[0.4 * s, 0.47 * s, 0.44 * s], {"sides": 12, "sy": 0.42, "nfn": palm_n, "s0": s1 - 0.1 * s, "cap_end": false, "seed": sd + 1.0})
	var FL = [0.62, 0.72, 0.68, 0.52]
	var tip = s2
	for f in 4:
		var fx = lerpf(-0.31, 0.31, f / 3.0) * s
		var L = float(FL[f]) * s
		var p = b0 + Vector3(fx, 0.74 * s, 0.05 * s)
		var pts: Array = [p]
		var ang = 0.0
		for i in 4:
			ang += curl * (0.25 + 0.35 * i)
			var dv = Vector3(fx / s * spread * 2.0, cos(ang), sin(ang)).normalized()
			p = p + dv * L / 4.0
			pts.append(p)
		var r = 0.1 * s
		tip = maxf(tip, ML.tube(g, pts, [r, r * 0.98, r * 0.92, r * 0.8, r * 0.4], {"sides": 8, "s0": s2 - 0.05 * s, "seed": sd + 2.0 + f, "cap_end": false}))
	var tx = 0.42 * s * side
	ML.tube(g, ML.bez(b0 + Vector3(tx * 0.8, 0.1 * s, 0.04 * s), b0 + Vector3(tx * 1.45, 0.45 * s, 0.16 * s + curl * 0.2 * s),
		b0 + Vector3(tx * 1.25, 0.8 * s, 0.3 * s + curl * 0.35 * s), 5), [0.13 * s, 0.12 * s, 0.11 * s, 0.09 * s, 0.045 * s],
		{"sides": 8, "s0": s1, "seed": sd + 7.0, "cap_end": false})
	return tip


# ================================================================== Sōshinki
## Ref (Yamato, iletim tohumları): avuçtan bir avuç soluk tohum saçılır, kullanıcının çevresinde yere düşüp minik iki yapraklı
## filizlere döner. Menzildeki her düşmana yerden kıl inceliğinde bir kök koşar; kök boyunca yeşil öz damlası ileti gibi akar ve
## ucunda düşmanın üstüne bir tohum yapışır: tohum bedende küçük bir filiz olarak süre boyunca kalır (izleme). Sonra kökler çekilir,
## filizler kurur.
static func _seed_mesh() -> SphereMesh:
	if _cache.has("seed"):
		return _cache["seed"]
	var s = SphereMesh.new()
	s.radius = 0.05
	s.height = 0.07
	s.radial_segments = 8
	s.rings = 4
	_cache["seed"] = s
	return s


static func _seed_node(host: Node, p: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _seed_mesh()
	mi.material_override = _flat("seed", Color(0.93, 0.88, 0.72))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ML.put(host, mi, p)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	return mi


## Minik filiz: sap yerden büyür, tepesinde iki yaprak açılır; life sonunda kurur, küçülür
static func _sprout(host: Node, parent: Node3D, p: Vector3, s: float, life_t: float) -> Node3D:
	var root = Node3D.new()
	if parent != null:
		parent.add_child(root)
		root.global_position = p
	else:
		ML.put(host, root, p)
	var g = ML.Geo.new()
	var L = ML.tube(g, ML.bez(Vector3.ZERO, Vector3(0.02, 0.5, 0.0) * s, Vector3(-0.03, 1.0, 0.04) * s, 5), [0.04 * s, 0.035 * s, 0.03 * s, 0.025 * s, 0.02 * s],
		{"sides": 5, "cap_end": false, "gnarl": 0.0})
	var stem = ML.inst(host, g.build(), Vector3.ZERO, {"grow": 0.0, "parent": root, "body": Color(0.45, 0.62, 0.3), "ow": 0.008, "nf": 1.2, "taper": 0.15})
	ML.grow_to(stem, 0.0, L + 0.2, 0.25)
	var lm = _flat("sprout_leaf", ML.LEAF.lightened(0.15), false, true)
	for k in 2:
		var lf = MeshInstance3D.new()
		lf.mesh = ML._leaf_mesh()
		lf.material_override = lm
		lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lf)
		lf.position = Vector3(-0.03, 1.0, 0.04) * s
		lf.rotation = Vector3(0.0, k * PI, 1.0 if k == 0 else -1.0)
		lf.scale = Vector3.ONE * 0.01
		var tw = lf.create_tween()
		tw.tween_interval(0.2)
		tw.tween_property(lf, "scale", Vector3(0.45, 0.6, 0.45) * s, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.1, life_t - 0.8))
		tw.tween_property(lf, "rotation:z", (1.0 if k == 0 else -1.0) * 2.1, 0.35)
	var rt = root.create_tween()
	rt.tween_interval(maxf(0.2, life_t - 0.4))
	rt.tween_method(ML.pf(stem, "wither"), 0.0, 0.8, 0.3)
	rt.tween_property(root, "scale", Vector3.ONE * 0.02, 0.3)
	rt.tween_callback(root.queue_free)
	return root


static func _signal_root(pj: PathJutsu, c: Node3D, e: Node3D, life_t: float) -> void:
	var org = ML.floor_at(c.global_position)
	var to = ML.floor_at(e.global_position)
	var dv = to - org
	dv.y = 0.0
	var L = dv.length()
	if L < 0.5:
		return
	var n = maxi(6, int(L / 1.2))
	var pts = ML.wander(Vector3.ZERO, dv, L, n, {"hug": true, "lift": 0.03, "bend": 0.3, "org": org})
	var radii: Array = []
	for i in n:
		radii.append(lerpf(0.055, 0.025, float(i) / float(n - 1)))
	var g = ML.Geo.new()
	var Lr = ML.tube(g, pts, radii, {"sides": 5, "cap_end": false, "gnarl": 0.1, "seed": randf() * 9.0})
	var mi = ML.inst(pj, g.build(), org, {"ow": 0.012, "nf": 2.0, "taper": 0.5, "body": ML.BARK.lightened(0.05)})
	var t_in = clampf(L / 45.0, 0.25, 0.7)
	ML.life(mi, Lr, t_in, 1.4, 0.5, 0.0, {"taper": 0.5})
	# ileti: kök boyunca akan öz damlaları
	var wp: Array = []
	for p in pts:
		wp.append(org + (p as Vector3) + Vector3.UP * 0.05)
	for b in 2:
		var bead = MeshInstance3D.new()
		bead.mesh = _ball(0.07)
		bead.material_override = ML.glow_mat(ML.SAP, 2.2)
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ML.put(pj, bead, wp[0])
		var tw = bead.create_tween()
		tw.tween_interval(t_in + 0.1 + b * 0.35)
		tw.tween_method(func(q: float):
			if is_instance_valid(bead):
				bead.global_position = _along(wp, q), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bead, "scale", Vector3.ONE * 0.05, 0.15)
		tw.tween_callback(bead.queue_free)
	# uçta tohum düşmanın bedenine yapışır ve filizlenir
	pj.after(t_in + 0.2, func():
		if not pj.live(e):
			return
		var h = 1.8
		if e.get("height") != null:
			h = clampf(float(e.get("height")), 1.0, 40.0)
		var toward = (c.global_position - e.global_position) if is_instance_valid(c) else Vector3.FORWARD
		toward.y = 0.0
		toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
		var sp = e.global_position + Vector3.UP * h * 0.72 + toward * clampf(h * 0.16, 0.25, 3.0)
		var sd = _seed_node(pj, to + Vector3.UP * 0.1)
		var tw2 = _arc_to(sd, to + Vector3.UP * 0.1, sp, 0.6, 0.25)
		tw2.tween_callback(func():
			if is_instance_valid(sd):
				sd.queue_free()
			if pj.live(e):
				var spr = _sprout(pj, e, sp, clampf(h * 0.12, 0.22, 3.0), life_t)
				spr.look_at(spr.global_position + toward, Vector3.UP)
				spr.rotate_object_local(Vector3.RIGHT, -1.1)
				ML.leaves(pj, sp, 4, 1.2, {"size": 0.12, "life": 0.9})))


static func soshinki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# mekanik: eski genel "utility" kalıbı (tier'a göre süre, hız +%10); eski algı dalgası yalnız görseldi
	var d: Dictionary = Data.jutsu.get("soshinki", {})
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	var mods = {"speed": 1.1}
	if c is Player:
		Buffs.add("soshinki", dur, mods)
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], ML.SAP)
	elif c.has_method("add_buff"):
		c.add_buff("soshinki", dur, mods)   # AI eşitliği
	var org = ML.floor_at(c.global_position)
	var hp = pj.hand_pos(c, true)
	ML.light(pj, hp, ML.SAP, 1.2, 3.0, 0.5)
	# hazırlık: avuçtaki tohumlar çevreye saçılır, düştükleri yerde filizlenir
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.25, 0.25)
		var land = ML.floor_at(org + Vector3(cos(a), 0, sin(a)) * randf_range(0.9, 2.2)) + Vector3.UP * 0.03
		var sd = _seed_node(pj, hp)
		var tw = _arc_to(sd, hp, land, randf_range(0.6, 1.1), 0.32 + k * 0.025)
		tw.tween_callback(func():
			if is_instance_valid(sd):
				sd.queue_free()
			_sprout(pj, null, land, randf_range(0.3, 0.42), 2.8))
	# ileti kökleri: menzildeki her düşmana
	for e in pj.enemies_near(c, c.global_position, 30.0):
		pj.after(0.4, func():
			if pj.live(c) and pj.live(e):
				_signal_root(pj, c, e, minf(dur, 8.0)))
	ML.scar(pj, org, 1.2, 2.4, {"lines": 0.0, "pit": 0.0, "rings": 3.0})
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== Hotei no Jutsu
## Ref (üstten çekim): hedefin altında koyu yosun yeşili, iç içe halkalı dev sarmal ahşap zemin dıştan içe doğru kıvrılarak
## büyür; çemberin kenarından on dev ahşap el kökten parmak ucuna büyüyerek fışkırır ve hedefe doğru kapanıp onu kavrar.
## Her elin dibinde toprak yarılır, kıymık ve toz sıçrar; süre bitince eller kuruyup gömülür, sarmal merkezden dışa çözülür.
static func _hotei_hand() -> Dictionary:
	if _cache.has("hotei_hand"):
		return _cache["hotei_hand"]
	var g = ML.Geo.new()
	var L = _hand(g, 1.0, {"base": Vector3(0, 2.5, 0), "arm": 3.7, "curl": 0.75, "spread": 0.12, "seed": 2.0})
	var out = {"mesh": g.build(), "len": L}
	_cache["hotei_hand"] = out
	return out


static func mokuton_hotei_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	# kanon (Hotei no Jutsu): avuçlar birleşir; hedefin çevresinde yerden halka hâlinde çok sayıda dev ahşap el fışkırır,
	# onu çevreleyip kavrar ve tutar. Hedef büyükse eller de büyür.
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	# kanon (Databook): her el bir kuyruklu canavar büyüklüğünde — insan hedefe karşı da dev (~25 m), dev hedefte daha da büyür
	var big = 6.0
	if tt and tt.get("height") != null:
		big = clampf(float(tt.get("height")) / 2.0, 6.0, 14.0)
	# zeminde dıştan içe kıvrılan sarmal ahşap (ellerin çıktığı yer)
	var g = ML.Geo.new()
	var sp: Array = []
	var sr: Array = []
	var ridge: Array = []
	var rr: Array = []
	for i in 160:
		var a = i * 0.42 * 60.0 / 160.0
		var rad = (6.0 - i * 0.092 * 60.0 / 160.0) * big
		var p = Vector3(cos(a), 0.0, sin(a)) * rad
		var w = at + p
		p.y = Game.jutsu_floor(w.x, w.z) - at.y + 0.06 * big
		sp.append(p)
		sr.append(0.95 * big)
		ridge.append(p + Vector3.UP * 0.1 * big)
		rr.append(0.16 * big)
	var up_n = func(_i, _p, _ti): return Vector3.UP
	var L = ML.tube(g, sp, sr, {"sides": 10, "sx": 0.17, "sy": 1.0, "nfn": up_n, "cap_end": true, "gnarl": 0.04, "seed": 3.0})
	ML.tube(g, ridge, rr, {"sides": 6, "sx": 0.5, "sy": 1.0, "nfn": up_n, "cap_end": false, "tint": Color(0.7, 0.74, 0.7), "gnarl": 0.1, "seed": 5.0})
	var coil = ML.inst(pj, g.build(), at, {"grow": 0.0, "body": Color(0.3, 0.36, 0.3), "ow": 0.05 * big, "nf": 8.0, "taper": 2.0 * big, "fresh": 0.3})
	var ctw = ML.grow_to(coil, 0.0, L + 2.0 * big, 0.3, 0.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
	ctw.tween_interval(4.55)
	ctw.tween_method(ML.pf(coil, "grow"), L + 2.0 * big, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ctw.tween_callback(coil.queue_free)
	ML.dust_ring(pj, at, 5.0 * big, 16, 1.2 * big, 1.6, {"spd": big * 1.5, "nf": 8.0})
	var hh = _hotei_hand()
	var n = 8 if big < 2.0 else 10
	for k in n:
		var a = TAU * k / n + randf() * 0.2
		var sh = big * randf_range(0.9, 1.1)
		var base = at + Vector3(cos(a), 0, sin(a)) * (3.8 * big)
		base.y = Game.jutsu_floor(base.x, base.z)
		var holder = Node3D.new()
		ML.put(pj, holder, base + Vector3.DOWN * 2.0 * big)
		holder.look_at_from_position(holder.global_position, Vector3(at.x, holder.global_position.y, at.z), Vector3.UP)
		holder.rotate_y(PI)   # avuç (+z) hedefe dönük
		var mi = ML.inst(pj, hh["mesh"], Vector3.ZERO, {"grow": 0.0, "parent": holder, "ow": 0.05 * sh, "nf": 10.0, "taper": 1.2, "seed": k * 1.3, "shadow": true})
		mi.scale = Vector3.ONE * sh
		var Lh: float = float(hh["len"])
		var dl = 0.1 + k * 0.05
		ML.grow_to(mi, 0.0, Lh + 1.3, 0.4, dl, Tween.TRANS_QUAD, Tween.EASE_OUT)
		var tw = holder.create_tween()
		tw.tween_interval(dl)
		tw.tween_property(holder, "global_position", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "rotation:x", 0.35, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # öne kapanıp kavrar
		tw.tween_interval(4.0)
		tw.tween_method(ML.pf(mi, "wither"), 0.0, 0.7, 0.2)
		tw.tween_property(holder, "global_position", base + Vector3.DOWN * 5.0 * big, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(holder.queue_free)
		pj.after(dl, func():
			var sl = ML.soil_col(base)
			ML.scar(pj, base, 1.6 * big, 5.0, {"lines": 7.0, "pit": 1.0})
			ML.chips(pj, base + Vector3.UP * 0.5, 16, 4.0 * big * 0.6, {"col": sl, "col2": sl.lightened(0.3), "size": 0.25 * big, "rad": 0.4 * big, "spread": 50.0})
			ML.splinters(pj, base + Vector3.UP * 0.4 * big, 3, 0.45 * big, 3.0 * big * 0.5, {"col": sl})
			for j in 3:
				var q = base + Vector3(cos(a + (j - 1) * 0.5), 0, sin(a + (j - 1) * 0.5)) * 0.9 * big
				ML.dust(pj, ML.floor_at(q) + Vector3.UP * 0.3 * big, 0.9 * big, 1.2, {"col": ML.dust_col(base), "vel": Vector3.UP * big * 0.4, "nf": 8.0})
			_crack_zone(base, 2.2 * big * 0.7))
	pj.after(0.6, func():
		for e in pj.enemies_near(c, at, 2.6 * big):
			if not (is_instance_valid(e) and not e.is_dead()):
				continue
			pj.st(e, "bind", 4.0)
			e.take_hit(pj.inf(c, "mokuton_hotei_no_jutsu", 0.8, {"knock": 0.0, "launch": 0.0, "kind": "crush", "element": "mokuton"}))
		ML.chips(pj, at + Vector3.UP * 1.5, 18, 6.0, {"size": 0.4, "rad": 1.5})
		ML.leaves(pj, at + Vector3.UP * 2.0, 14, 4.0, {"size": 0.35, "rad": 2.0}))
	pj.shake(0.6 * big)
	Sfx.play("earth", at, 0.5)


# ================================================================== Ahşap Pranga
## Ref (Yamato'nun prangası): hedefin iki yanında yarıklı kare direkler yerden büyür; alt tahta iki direkten ortaya doğru
## uzayıp ortada buluşur, üst tahta yukarıdan inip üstüne kapanır (çakma: toz + kıymık). Ön yüzde boyun ve bilekler için üç
## demir halka. Süre bitince pranga kuruyup toprağa çekilir.
static func _stocks_mesh() -> Dictionary:
	if _cache.has("stocks"):
		return _cache["stocks"]
	var out := {}
	# direkler + alt tahta
	var g = ML.Geo.new()
	var Lp = 0.0
	var right_n = func(_i, _p, _ti): return Vector3.RIGHT
	for sx in [-1.0, 1.0]:
		Lp = maxf(Lp, ML.beam(g, Vector3(sx * 1.42, -0.25, 0), 2.35, 0.36, {"seed": 1.0 + sx}))
		for i in 3:
			var y = 0.45 + i * 0.6
			ML.tube(g, [Vector3(sx * 1.42, y - 0.17, 0.17), Vector3(sx * 1.42, y + 0.17, 0.17)], [0.075, 0.075],
				{"sides": 4, "hard": true, "a0": PI * 0.25, "sx": 1.0, "sy": 0.6, "tint": Color(0.35, 0.3, 0.27), "s0": 0.4 + y, "cap_end": false,
				"nfn": right_n})
	var flat_n = func(_i, _p, _ti): return Vector3.UP
	var Lb = 0.0
	for sx in [-1.0, 1.0]:
		for pl in 2:
			var y = 1.0 + pl * 0.18
			Lb = maxf(Lb, ML.tube(g, [Vector3(sx * 1.25, y, 0), Vector3(sx * 0.6, y, 0), Vector3(0.0, y, 0)], [1.0 / 0.7071, 1.0 / 0.7071, 1.0 / 0.7071],
				{"sides": 4, "hard": true, "a0": PI * 0.25, "sx": 0.085, "sy": 0.16, "nfn": flat_n, "s0": 1.6, "cap_end": true,
				"face_tint": [Color(1, 1, 1), Color(0.8, 0.8, 0.8), Color(1, 1, 1), Color(0.7, 0.7, 0.7)], "seed": pl + sx * 3.0}))
	out["low"] = g.build()
	out["low_len"] = maxf(Lp, Lb)
	# üst tahta (iki kalas)
	var g2 = ML.Geo.new()
	for pl in 2:
		var y = 1.36 + pl * 0.18
		ML.tube(g2, [Vector3(-1.25, y, 0), Vector3(0.0, y, 0), Vector3(1.25, y, 0)], [1.0 / 0.7071, 1.0 / 0.7071, 1.0 / 0.7071],
			{"sides": 4, "hard": true, "a0": PI * 0.25, "sx": 0.085, "sy": 0.16, "nfn": flat_n, "cap_end": true, "cap_start": true,
			"face_tint": [Color(1, 1, 1), Color(0.8, 0.8, 0.8), Color(1, 1, 1), Color(0.7, 0.7, 0.7)], "seed": 7.0 + pl})
	out["top"] = g2.build()
	# demir halkalar (boyun, iki bilek) + perçinler
	var g3 = ML.Geo.new()
	for h in [[Vector3(0, 1.36, 0.19), 0.3], [Vector3(-0.72, 1.36, 0.19), 0.21], [Vector3(0.72, 1.36, 0.19), 0.21]]:
		var cc: Vector3 = h[0]
		var rad: float = h[1]
		var pts: Array = []
		var radii: Array = []
		for i in 17:
			var a = TAU * i / 16.0
			pts.append(cc + Vector3(cos(a), sin(a), 0.0) * rad)
			radii.append(0.055)
		ML.tube(g3, pts, radii, {"sides": 6, "cap_end": false, "gnarl": 0.0})
		for i in 4:
			var a = TAU * i / 4.0 + PI * 0.25
			var rp = cc + Vector3(cos(a), sin(a), 0.0) * (rad + 0.02)
			ML.tube(g3, [rp, rp + Vector3(0, 0, 0.04)], [0.025, 0.02], {"sides": 5, "cap_end": false, "gnarl": 0.0, "tint": Color(0.75, 0.75, 0.75)})
	out["iron"] = g3.build()
	_cache["stocks"] = out
	return out


static func wood_release_stocks(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var face = (c.global_position - at)
	face.y = 0
	face = face.normalized()
	var sm = _stocks_mesh()
	var root = Node3D.new()
	ML.put(pj, root, at)
	root.rotation.y = atan2(face.x, face.z)   # ön yüz (+z) kullanıcıya
	var low = ML.inst(pj, sm["low"], Vector3.ZERO, {"grow": 0.0, "parent": root, "ow": 0.03, "nf": 2.5, "taper": 0.5, "shadow": true})
	var Ll: float = float(sm["low_len"])
	ML.grow_to(low, 0.0, Ll + 0.6, 0.25, 0.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
	var top = ML.inst(pj, sm["top"], Vector3(0, 1.3, 0), {"parent": root, "ow": 0.03, "nf": 2.5, "shadow": true})
	top.visible = false
	var iron = MeshInstance3D.new()
	iron.mesh = sm["iron"]
	iron.material_override = ML.wood_mat()
	root.add_child(iron)
	iron.set_instance_shader_parameter("body", Vector3(0.36, 0.37, 0.4))
	iron.set_instance_shader_parameter("fresh", 0.0)
	iron.set_instance_shader_parameter("nf", 2.5)
	iron.scale = Vector3.ONE * 0.01
	var tw = root.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func(): top.visible = true)
	tw.tween_property(top, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var seam = root.global_transform * Vector3(0, 1.4, 0.15)
		ML.chips(pj, seam, 14, 4.5, {"size": 0.22, "rad": 1.0, "dir": Vector3(face.x, 0.6, face.z), "spread": 70.0})
		ML.splinters(pj, seam, 2, 0.35, 4.0)
		pj.shake(0.3))
	tw.tween_property(iron, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.6)
	tw.tween_method(ML.pf(low, "wither"), 0.0, 0.7, 0.2)
	tw.tween_method(ML.pf(top, "wither"), 0.0, 0.7, 0.01)
	tw.tween_property(root, "global_position", at - Vector3.UP * 2.6, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	var sl = ML.soil_col(at)
	ML.scar(pj, at, 2.0, 4.6, {"lines": 6.0, "pit": 0.0})
	for sx in [-1.0, 1.0]:
		var q = root.global_transform * Vector3(sx * 1.42, 0.2, 0)
		ML.chips(pj, q, 8, 4.0, {"col": sl, "col2": sl.lightened(0.3), "size": 0.2})
		ML.dust(pj, q, 0.9, 0.8, {"col": ML.dust_col(at), "vel": Vector3.UP * 0.6, "nf": 2.5})
	_crack_zone(at, 2.2 * 1.2)
	pj.st(tt, "bind", 4.2)
	Combat.popup_text(at + Vector3.UP * 2.6, "Prangalandı!", ML.FRESH)
	Sfx.play("earth", at, 1.0)


# ================================================================== Sashiki no Jutsu
## Ref (Yamato / Tobi): kolun üstünden dört kısa sivri ahşap diken fışkırır; sonra avuçtan yontma, köşeli, ucu taze açık renk
## ince kazıklar uzayarak fırlar — arkalarında beyaz hız çizgileri. Saplandığı yerde kazık titreyerek kalır, kıymık saçılır,
## sonra kurur.
static func _stake_mesh() -> Dictionary:
	if _cache.has("stake"):
		return _cache["stake"]
	var g = ML.Geo.new()
	var L = ML.tube(g, [Vector3(0, 0, 0.8), Vector3(0.01, 0.01, 0.2), Vector3(0, 0, -0.4), Vector3(0, 0, -0.75), Vector3(0, 0, -0.95)],
		[0.075, 0.085, 0.07, 0.04, 0.0], {"sides": 5, "hard": true, "cap_end": false, "cap_start": true, "seed": 3.0})
	var out = {"mesh": g.build(), "len": L}
	_cache["stake"] = out
	return out


static func _stake_hit(pj: PathJutsu, p: Vector3, dv: Vector3) -> void:
	var sm = _stake_mesh()
	var mi = ML.inst(pj, sm["mesh"], p - dv.normalized() * 0.35, {"ow": 0.014, "nf": 1.5})
	if dv.length() > 0.01:
		mi.look_at(mi.global_position + dv, Vector3.UP if absf(dv.normalized().y) < 0.95 else Vector3.RIGHT)
	var r0 = mi.rotation
	var tw = mi.create_tween()
	tw.tween_method(func(q: float):
		if is_instance_valid(mi):
			mi.rotation = r0 + Vector3(sin(q * 40.0), cos(q * 33.0), 0.0) * 0.06 * (1.0 - q), 0.0, 1.0, 0.35)
	tw.tween_interval(0.5)
	tw.tween_method(ML.pf(mi, "wither"), 0.0, 0.8, 0.25)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(mi.queue_free)
	ML.chips(pj, p, 8, 5.0, {"size": 0.18, "dir": -dv.normalized(), "spread": 70.0, "life": 0.7})
	ML.splinters(pj, p, 2, 0.3, 4.0, {"life": 0.8})


static func mokuton_sashiki_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 22.0)
	var from = pj.hand_pos(c, true)
	# hazırlık: koldan dışa dikenler fışkırır
	var fd = c.face_dir()
	var g = ML.Geo.new()
	var Ls = 0.0
	for k in 4:
		var dv = (fd * 0.4 + Vector3(randf_range(-1, 1), randf_range(-0.2, 0.9), randf_range(-1, 1)).normalized()).normalized()
		var b = Vector3(randf_range(-0.12, 0.12), randf_range(-0.15, 0.1), randf_range(-0.12, 0.12)) - fd * 0.15 * k
		Ls = maxf(Ls, ML.tube(g, [b, b + dv * 0.25, b + dv * 0.55], [0.05, 0.035, 0.0], {"sides": 5, "hard": true, "cap_end": false}))
	var spk = ML.inst(pj, g.build(), from, {"ow": 0.012, "nf": 1.2, "taper": 0.2})
	ML.life(spk, Ls, 0.1, 0.25, 0.15, 0.0, {"taper": 0.2})
	ML.chips(pj, from, 6, 3.0, {"size": 0.12, "dir": fd, "spread": 60.0, "life": 0.6})
	var sm = _stake_mesh()
	var lm = _flat("speedline", Color(1, 1, 1, 0.75), true)
	for k in 6:
		pj.after(0.12 + k * 0.05, func():
			if not pj.live(c):
				return
			var holder = Node3D.new()
			var dv = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.08, 0.08))
			var pr = pj.shot(c, from, dv, 40.0, holder, pj.inf(c, "mokuton_sashiki_no_jutsu", 0.3, {"knock": 2.0, "kind": "heavy", "element": "mokuton", "bleed": 2.0}), tt, false, 1.0, func(p, _h):
				_stake_hit(pj, p, dv))
			pr.homing_turn = 4.0
			var stake = ML.inst(pj, sm["mesh"], Vector3.ZERO, {"grow": 0.0, "parent": holder, "ow": 0.014, "nf": 1.5, "taper": 0.35})
			for j in 3:
				var ln = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.012, 0.012, randf_range(0.8, 1.6))
				ln.mesh = bm
				ln.material_override = lm
				ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(ln)
				ln.position = Vector3(randf_range(-0.16, 0.16), randf_range(-0.16, 0.16), 1.2 + randf() * 0.6)
			ML.grow_to(stake, 0.0, float(sm["len"]) + 0.4, 0.08)
			ML.chips(pj, from, 3, 2.5, {"size": 0.1, "dir": dv, "spread": 40.0, "life": 0.5}))
	Sfx.play("whoosh", from, 1.3)


# ================================================================== Hōbi no Jutsu
## Ref (Hashirama, Kurama'yı bastırma): kullanıcının çevresinde otuz kalın kaburga yerden fışkırıp tepede birleşerek oluklu
## ahşap kubbe olur; ön yüzde oyma bir yüz büyür — kesik yüzlü (yıllık halkalı) iri gözler ve koyu halka çizgileri, kalın kaşlar,
## yassı burun, dudak çıkıntısı, kare dişler. Süre bitince kubbe ortadan ikiye yarılıp açılır, yarık boyunca kıymık saçılır.
static func _dome_p(x: float, y: float, R: float) -> Vector3:
	var zz = R * R - x * x - y * y
	return Vector3(x, y, -sqrt(maxf(zz, 0.04)))


static func _hobi_half(sx: float, R: float) -> Dictionary:
	var key = "hobi_%d" % int(sx)
	if _cache.has(key):
		return _cache[key]
	var g = ML.Geo.new()
	var Lr = 0.0
	for k in 30:
		var a = (k + 0.5) * TAU / 30.0
		if (cos(a) >= 0.0) != (sx > 0.0):
			continue
		var pts: Array = []
		var rad: Array = []
		var emax = lerpf(1.5, 0.5, smoothstep(-0.1, 0.8, sin(a)))   # arka (kamera) tarafı alçak, açık kabuk
		for q in 10:
			var e = emax * q / 9.0
			pts.append(Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * R + Vector3.DOWN * (0.2 if q == 0 else 0.0))
			rad.append(lerpf(0.44, 0.2, q / 9.0))
		Lr = maxf(Lr, ML.tube(g, pts, rad, {"sides": 9, "cap_end": false, "seed": k * 0.7, "tint": Color(1, 1, 1).darkened(0.06 * (k % 3))}))
	var s0 = Lr * 0.85
	var dark = Color(0.3, 0.24, 0.2)
	# gözler: kesik yüzlü disk (yıllık halkalar = göz akı) + koyu halka çizgileri + bebek
	var ec = _dome_p(sx * 0.95, 1.55, R + 0.18)
	var en = ec.normalized()
	ML.tube(g, [ec - en * 0.35, ec + en * 0.1], [0.82, 0.85], {"sides": 20, "gnarl": 0.0, "s0": s0, "cap_end": true, "tint": Color(1.05, 1.0, 0.95)})
	var t1 = en.cross(Vector3.UP).normalized()
	var t2 = t1.cross(en).normalized()
	var lip = ec + en * 0.12
	for rg in [[0.84, 0.08], [0.6, 0.07], [0.33, 0.07], [0.1, 0.1]]:
		var pts: Array = []
		var radii: Array = []
		for i in 21:
			var a = TAU * i / 20.0
			pts.append(lip + (t1 * cos(a) + t2 * sin(a)) * float(rg[0]))
			radii.append(float(rg[1]))
		ML.tube(g, pts, radii, {"sides": 6, "gnarl": 0.0, "s0": s0 + 0.3, "cap_end": false, "tint": dark})
	# kaş
	var bp: Array = []
	var br: Array = []
	for q in 7:
		var u = q / 6.0
		bp.append(_dome_p(sx * lerpf(0.2, 1.75, u), 2.45 + sin(u * PI) * 0.25 - u * 0.2, R + 0.25))
		br.append(lerpf(0.2, 0.14, u))
	ML.tube(g, bp, br, {"sides": 8, "s0": s0, "cap_end": false, "tint": Color(0.62, 0.56, 0.52)})
	# yassı burun yarısı + burun deliği
	var nc = _dome_p(sx * 0.22, 1.0, R)
	var nn = nc.normalized()
	ML.tube(g, [nc - nn * 0.2, nc + nn * 0.25, nc + nn * 0.45 + Vector3.DOWN * 0.08], [0.3, 0.34, 0.24],
		{"sides": 10, "sx": 1.0, "sy": 1.3, "s0": s0, "cap_end": true})
	var nh = _dome_p(sx * 0.3, 0.8, R + 0.38)
	ML.tube(g, [nh, nh + nh.normalized() * 0.05], [0.09, 0.09], {"sides": 8, "s0": s0 + 0.4, "cap_end": false, "tint": dark})
	# dudak çıkıntısı
	var lp: Array = []
	var lr: Array = []
	for q in 7:
		var u = q / 6.0
		lp.append(_dome_p(sx * lerpf(0.05, 1.6, u), 0.74 + u * u * 0.16, R + 0.18))
		lr.append(lerpf(0.16, 0.1, u))
	ML.tube(g, lp, lr, {"sides": 8, "s0": s0, "cap_end": false, "tint": Color(0.7, 0.64, 0.6)})
	# ağız boşluğu + kare dişler (kesik yüzleri açık)
	var mp: Array = []
	var mr: Array = []
	for q in 6:
		var u = q / 5.0
		mp.append(_dome_p(sx * lerpf(0.0, 1.45, u), 0.4 + u * u * 0.12, R + 0.05))
		mr.append(0.2)
	ML.tube(g, mp, mr, {"sides": 8, "sy": 0.6, "s0": s0, "cap_end": false, "tint": Color(0.22, 0.18, 0.16)})
	var tooth_n = func(_i, _p, _ti): return Vector3.UP
	for row in 2:
		for q in 4:
			var u = q / 3.0
			var tc = _dome_p(sx * lerpf(0.18, 1.3, u), (0.53 if row == 0 else 0.28) + u * u * 0.12, R + 0.05)
			var tn = tc.normalized()
			ML.tube(g, [tc - tn * 0.1, tc + tn * 0.14], [0.16, 0.16], {"sides": 4, "hard": true, "a0": PI * 0.25, "sx": 1.0, "sy": 0.75,
				"s0": s0 + 0.2, "cap_end": true, "tint": Color(1.1, 1.06, 1.0),
				"nfn": tooth_n})
	var out = {"mesh": g.build(), "len": s0 + 1.0}
	_cache[key] = out
	return out


static func mokuton_hobi_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# kanon (Hōbi, fūinjutsu): kullanıcının çevresinde bir anda yüz oymalı dolu ahşap kubbe; içerideyken gelen saldırılar
	# büyük ölçüde zayıflar; süre bitince kubbe ortadan ikiye açılır.
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position)
	var yaw = atan2(-c.face_dir().x, -c.face_dir().z)
	var root = Node3D.new()
	ML.put(pj, root, at)
	root.rotation.y = yaw
	var R = 3.0
	var halves: Array = []
	var mis: Array = []
	for hi in 2:
		var sx = 1.0 - hi * 2.0
		var h = Node3D.new()
		root.add_child(h)
		halves.append(h)
		var hd = _hobi_half(sx, R)
		var mi = ML.inst(pj, hd["mesh"], Vector3.ZERO, {"grow": 0.0, "parent": h, "ow": 0.04, "nf": 9.0, "taper": 0.8, "seed": hi * 4.0})
		ML.grow_to(mi, 0.0, float(hd["len"]) + 0.8, 0.3, 0.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
		mis.append(mi)
	var tw = root.create_tween()
	tw.tween_interval(4.3)
	tw.tween_callback(func():   # komutla ortadan ikiye açılır
		var bz = root.global_basis.z
		for i in 4:
			var q = root.global_transform * Vector3(0, 0.4 + i * 0.75, 0)
			var zz = root.global_transform * Vector3(0, 0.3 + i * 0.7, -R * cos(0.2 + i * 0.32))
			ML.chips(pj, zz, 8, 4.0, {"size": 0.26, "rad": 0.4})
			ML.chips(pj, q + bz * R * 0.9, 5, 3.0, {"size": 0.22})
		ML.splinters(pj, at + Vector3.UP * 2.6, 4, 0.6, 5.0)
		var tw2 = root.create_tween().set_parallel(true)
		tw2.tween_property(halves[0], "position", Vector3(2.6, -0.4, 0), 0.5)
		tw2.tween_property(halves[1], "position", Vector3(-2.6, -0.4, 0), 0.5)
		tw2.tween_property(halves[0], "rotation:z", -0.5, 0.5)
		tw2.tween_property(halves[1], "rotation:z", 0.5, 0.5)
		for mi in mis:
			tw2.tween_method(ML.pf(mi, "wither"), 0.0, 0.6, 0.5)
		tw2.chain().tween_callback(root.queue_free))
	ML.dust_ring(pj, at, R + 0.2, 14, 1.3, 1.1, {"spd": 3.5, "nf": 9.0})
	ML.scar(pj, at, R + 0.8, 4.8, {"lines": 30.0, "pit": 0.0, "rings": 1.0})
	ML.chips(pj, at + Vector3.UP * 0.3, 18, 6.0, {"size": 0.3, "rad": R, "spread": 40.0})
	_crack_zone(at, 2.2 * 2.0)
	var mods = {"armor": 0.08, "_name": "Hōbi", "_desc": "yüz oymalı ahşap kubbe gelen saldırıları söndürüyor"}
	if c is Player:
		Buffs.add("mokuton_hobi", 4.3, mods)
	elif c.has_method("add_buff"):
		c.add_buff("mokuton_hobi", 4.3, mods)
	Sfx.play("earth", at, 0.6)


# ================================================================== Tajū Mokuton Bunshin
## Ref (Madara'nın ahşap klon kalabalığı): kullanıcının ayağından sekiz kök yıldız gibi dışa koşar; her kökün ucunda altı ince
## lif sarmal çizerek insan boyuna dolanır, sonra yukarıdan aşağı çözülüp içindeki klonu açar — klonlar ahşap kabuklu kalır.
## Hedefe atılan klon kolunu ahşap kazık gibi uzatıp vurur; yıkılan klon kabuk şeritlerine dağılır.
static func _clone_cocoon(pj: PathJutsu, from: Vector3, q: Vector3) -> void:
	var dv = q - from
	dv.y = 0.0
	var L = dv.length()
	if L > 0.3:
		var org = ML.floor_at(from)
		var pts = ML.wander(Vector3.ZERO, dv, L, 6, {"hug": true, "lift": 0.05, "bend": 0.25, "org": org})
		var g0 = ML.Geo.new()
		var Lr = ML.tube(g0, pts, [0.11, 0.1, 0.09, 0.08, 0.07, 0.05], {"sides": 6, "cap_end": false})
		var root_mi = ML.inst(pj, g0.build(), org, {"ow": 0.015, "nf": 2.0, "taper": 0.4})
		ML.life(root_mi, Lr, 0.12, 0.5, 0.3, 0.0, {"taper": 0.4})
	var g = ML.Geo.new()
	var Lh = 0.0
	for i in 6:
		var sgn = 1.0 if i % 2 == 0 else -1.0
		var hp = ML.helix(0.5, 0.28, 1.95, 1.1, 10, TAU * i / 6.0, sgn, -0.05)
		Lh = maxf(Lh, ML.tube(g, hp, [0.07, 0.07, 0.065, 0.06, 0.055, 0.05, 0.045, 0.04, 0.035, 0.02], {"sides": 5, "cap_end": false, "seed": i * 1.1}))
	var mi = ML.inst(pj, g.build(), q, {"ow": 0.015, "nf": 2.0, "taper": 0.4, "body": ML.BARK.lightened(0.1)})
	ML.life(mi, Lh, 0.25, 0.15, 0.3, 0.1, {"taper": 0.4})
	ML.chips(pj, q + Vector3.UP * 0.2, 6, 3.0, {"size": 0.16, "col": ML.soil_col(q)})


static func _clone_lash(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var g = ML.Geo.new()
	var mid = (a + b) * 0.5 + Vector3.UP * 0.25
	var L = ML.tube(g, ML.bez(Vector3.ZERO, mid - a, b - a, 6), [0.1, 0.1, 0.09, 0.07, 0.05, 0.0], {"sides": 6, "cap_end": false})
	var mi = ML.inst(pj, g.build(), a, {"ow": 0.015, "nf": 1.5, "taper": 0.25})
	ML.life(mi, L, 0.08, 0.1, 0.15, 0.0, {"taper": 0.25})
	ML.chips(pj, b, 10, 5.0, {"size": 0.2, "dir": (b - a).normalized(), "spread": 55.0, "life": 0.7})
	ML.splinters(pj, b, 2, 0.35, 4.0, {"life": 0.8})


static func taju_mokuton_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 24.0)
	ML.scar(pj, c.global_position, 2.6, 2.0, {"lines": 8.0, "pit": 0.0})
	for k in 8:
		pj.after(k * 0.06, func():
			if not pj.live(c):
				return
			var a = k * TAU / 8.0
			var q = pj.gp(c.global_position + Vector3(cos(a), 0, sin(a)) * 2.0)
			_clone_cocoon(pj, c.global_position, q)
			var cl = pj.decoy(c, q, 4.0, func(pos):   # ahşap klon: kırılınca kabuk şeritleri, duman yok
				ML.splinters(pj, pos + Vector3.UP, 5, 0.6, 5.0)
				ML.chips(pj, pos + Vector3.UP, 16, 4.0, {"size": 0.28, "rad": 0.5})
				ML.dust(pj, pos + Vector3.UP * 0.3, 0.9, 0.7, {"col": ML.dust_col(pos), "nf": 2.0}))
			if cl:
				cl.set_meta("no_smoke", true)
				pj.after(0.05, func():
					if is_instance_valid(cl) and cl.get("model"):
						ML.skin_on(cl.model, ML.BARK.lightened(0.14), cl.global_position.y, 1.9, 0.0))
			if cl and tt:
				pj.after(0.4, func():
					if not (is_instance_valid(cl) and pj.live(tt)):
						return
					var tw = cl.create_tween()
					tw.tween_property(cl, "global_position", pj.gp(tt.global_position + Vector3(cos(a), 0, sin(a)) * 1.2), 0.3)
					tw.tween_callback(func():
						if pj.live(tt) and pj.live(c):
							if is_instance_valid(cl):
								_clone_lash(pj, cl.global_position + Vector3.UP * 1.3, tt.global_position + Vector3.UP)
							tt.take_hit(pj.inf(c, "taju_mokuton_bunshin_no_jutsu", 0.4, {"knock": 3.0, "kind": "light", "element": "mokuton"})))))
	Sfx.play("earth", c.global_position, 1.2)


# ================================================================== Senpō Mokuton: Shin Sūsenju
## Ref (Hashirama): gerçek ShinSusenju heykeli kullanıcının arkasında yeri yırtarak yükselir — tabanında dev toz setleri ve
## yarıklar. Sonra binlerce kolundan ahşap eller kopup hedef alanına iner: her biri bilek bantlı uzun ön kol + açık avuç (kameraya
## yakın kısım noktalı silinir); düştüğü yerde avuç izi, kıymık ve toz halkası kalır, el kuruyup geri çekilir.
static func _susenju_hand() -> Dictionary:
	if _cache.has("susenju_hand"):
		return _cache["susenju_hand"]
	var g = ML.Geo.new()
	# yerel: kol +Y boyunca, parmak uçları ~42 m'de (eski kol ölçeğiyle aynı iniş mesafesi)
	var L = _hand(g, 8.5, {"base": Vector3(0, 30.0, 0), "arm": 3.5, "curl": 0.12, "spread": 0.16, "band": true, "seed": 4.0})
	var out = {"mesh": g.build(), "len": L}
	_cache["susenju_hand"] = out
	return out


static func _palm_print_mesh() -> ArrayMesh:
	if _cache.has("palm_print"):
		return _cache["palm_print"]
	var g = ML.Geo.new()
	var col = Color(1, 1, 1)
	var z = Vector3.ZERO
	var blobs = [[Vector2(0, 0), Vector2(0.48, 0.55)]]
	for f in 4:
		var fx = lerpf(-0.31, 0.31, f / 3.0)
		var FLs = [0.62, 0.72, 0.68, 0.52]
		var fl: float = FLs[f]
		blobs.append([Vector2(fx * 1.1, 0.55 + fl * 0.55), Vector2(0.11, fl * 0.5)])
	blobs.append([Vector2(0.62, 0.12), Vector2(0.12, 0.32)])
	for bl in blobs:
		var cc: Vector2 = bl[0]
		var rs: Vector2 = bl[1]
		var c0 = g.add(Vector3(cc.x, 0, cc.y), Vector3.UP, Vector3.UP, col, Vector2.ZERO, Vector2.ZERO, z)
		var first = g.v.size()
		for i in 15:
			var a = TAU * i / 14.0
			var w = 1.0 + 0.08 * sin(a * 5.0 + cc.x * 9.0)
			g.add(Vector3(cc.x + cos(a) * rs.x * w, 0, cc.y + sin(a) * rs.y * w), Vector3.UP, Vector3.UP, col, Vector2.ZERO, Vector2.ZERO, z)
		for i in 14:
			g.tri(c0, first + i, first + i + 1)
	var m = g.build()
	_cache["palm_print"] = m
	return m


## Avuç izi: zemine basılmış koyu el şekli (yön dv), yavaşça solar
static func _palm_print(pj: PathJutsu, q: Vector3, dv: Vector3, s: float, life_t: float) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _palm_print_mesh()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sc = ML.soil_col(q) * 0.38
	m.albedo_color = Color(sc.r, sc.g, sc.b, 0.85)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ML.put(pj, mi, ML.floor_at(q) + Vector3.UP * (0.06 + s * 0.004))
	var f = Vector3(dv.x, 0.0, dv.z)
	if f.length() < 0.01:
		f = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	mi.rotation.y = atan2(f.x, f.z)
	mi.scale = Vector3.ONE * s * 0.6
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life_t * 0.65)
	tw.tween_property(m, "albedo_color:a", 0.0, life_t * 0.35)
	tw.tween_callback(mi.queue_free)


static func senpo_mokuton_shin_susenju(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	var tt = pj.tg(c, t, 80.0)
	var fd = pj.fwd(c, t)
	var goal0 = pj.gp(tt.global_position if tt else c.global_position + fd * 40.0)
	var at = pj.gp(c.global_position - fd * 260.0)
	var ss = ShinSusenju.spawn(pj.get_tree().current_scene, at - Vector3.UP * 480.0, atan2(fd.x, fd.z))   # ön -Z: hedefe bakar
	# yükseliş: tabanda yırtılan yer, dev toz setleri
	var sl = ML.soil_col(at)
	ML.scar(pj, at, 95.0, 7.0, {"lines": 16.0, "pit": 0.6})
	for k in 10:
		var q = at + Vector3(cos(k * 0.63) * 70.0, 0, sin(k * 0.63) * 70.0)
		_crack_zone(q, 2.2 * 6.0)
		ML.scar(pj, q, 14.0, 6.0, {"lines": 9.0, "pit": 1.0})
		ML.splinters(pj, ML.floor_at(q) + Vector3.UP * 2.0, 3, 5.0, 26.0, {"col": sl, "life": 1.8})
		ML.chips(pj, ML.floor_at(q) + Vector3.UP * 2.0, 20, 22.0, {"col": sl, "col2": sl.lightened(0.3), "size": 2.4, "rad": 6.0, "life": 1.8})
	pj.every(2.2, 0.35, func(_i, k):
		for j in 6:
			var a = randf() * TAU
			var q = ML.floor_at(at + Vector3(cos(a), 0, sin(a)) * randf_range(55.0, 95.0))
			ML.dust(pj, q + Vector3.UP * 10.0, randf_range(26.0, 40.0) * (1.0 - k * 0.3), 2.4, {"col": ML.dust_col(at), "vel": Vector3(cos(a), 0.5, sin(a)) * 9.0, "nf": 30.0}))
	pj.shake(2.0)
	Sfx.play("earth", at, 0.3)
	var hd = _susenju_hand()
	var tw = ss.create_tween()
	tw.tween_property(ss, "global_position", at, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		for k in 36:   # Chōjō Kebutsu: eller kuyruktan kopup hedef alana iner
			pj.after(k * 0.07, func():
				if not is_instance_valid(ss):
					return
				var goal = pj.gp(tt.global_position if tt and pj.live(tt) else goal0)
				var q = goal + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
				var src = ss.random_hand_world()
				var hand = ML.inst(pj, hd["mesh"], src, {"ow": 0.35, "nf": 30.0, "seed": k * 0.37})
				hand.look_at(q + Vector3(0.001, 0, 0), Vector3.UP)
				hand.rotate_object_local(Vector3.RIGHT, -PI * 0.5)   # kol (+Y) hedefe uzanır
				var dir = (q - src).normalized()
				var tw2 = hand.create_tween()
				var dur = clampf(src.distance_to(q) / 420.0, 0.35, 0.8)
				tw2.tween_property(hand, "global_position", q - dir * 42.0, dur).set_ease(Tween.EASE_IN)
				tw2.tween_callback(func():
					_palm_print(pj, q, dir, 9.0, 6.0)
					var s2 = ML.soil_col(q)
					ML.dust_ring(pj, q, 6.0, 8, 4.5, 1.4, {"spd": 7.0, "nf": 10.0})
					ML.chips(pj, q + Vector3.UP * 1.0, 18, 14.0, {"col": s2, "col2": s2.lightened(0.3), "size": 0.9, "rad": 3.0})
					ML.splinters(pj, q + Vector3.UP * 2.0, 3, 1.6, 10.0, {"col": s2})
					_crack_zone(q, 9.0)
					pj.hit(c, q + Vector3.UP, 7.0, pj.inf(c, "senpo_mokuton_shin_susenju", 0.35, {"knock": 14.0, "kind": "heavy", "element": "mokuton"}))
					pj.shake(0.6))
				tw2.tween_interval(0.5)
				tw2.tween_method(ML.pf(hand, "wither"), 0.0, 0.8, 0.1)
				tw2.tween_property(hand, "global_position", q - dir * 75.0, 0.3).set_ease(Tween.EASE_IN)
				tw2.tween_callback(hand.queue_free)))
	tw.tween_interval(4.2)
	tw.tween_property(ss, "global_position", at - Vector3.UP * 480.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(ss.queue_free)


# ================================================================== Jukai Heki
## Ref (Yamato): birbirine örülmüş, çapraz kıvrılarak üst üste geçen yassı kalın gövdelerden duvar — gövdeler yerden kökten uca
## büyür, dipte toprak rengi çalı / toz seti kabarır. Duvara çarpan mermiler kıymık saçarak söner. Süre bitince duvar kuruyup
## toprağa gömülür.
static func mokuton_jukai_heki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 3.0)
	var side = d.cross(Vector3.UP)
	var g = ML.Geo.new()
	var L = 0.0
	var side_n = func(_i, _p, _ti): return side
	for k in 18:
		var h = randf_range(5.5, 7.5)
		var u0 = (k - 8.5) * 0.52
		var ph = (0.0 if k % 2 == 0 else PI) + randf_range(-0.4, 0.4)
		var fq = TAU / randf_range(3.0, 3.8)
		var amp = randf_range(0.6, 0.95)
		var pts: Array = []
		var radii: Array = []
		var r0 = randf_range(0.36, 0.48)
		for i in 13:
			var y = h * i / 12.0
			var ramp = clampf(y / 1.2, 0.0, 1.0)
			var u = u0 + amp * sin(y * fq + ph) * ramp
			var w = 0.28 * cos(y * fq + ph) * ramp + (0.2 if k % 2 == 0 else -0.2)
			var wy = at + side * u
			var fl = Game.jutsu_floor(wy.x, wy.z) - at.y if i == 0 else 0.0
			pts.append(side * u + d * w + Vector3.UP * (y - 0.4 + fl))
			radii.append(r0 * lerpf(1.1, 0.75, float(i) / 12.0))
		L = maxf(L, ML.tube(g, pts, radii, {"sides": 9, "sx": 1.0, "sy": 0.55, "nfn": side_n, "cap_end": true, "gnarl": 0.06, "seed": k * 0.9}))
	var wall = ML.inst(pj, g.build(), at, {"ow": 0.04, "nf": 3.0, "taper": 1.0, "shadow": true})
	ML.life(wall, L, 0.4, 7.0, 0.5, 0.0, {"out": "sink", "depth": 7.8, "taper": 1.0})
	# dipte toprak rengi çalı seti
	var dc = ML.dust_col(at).lerp(Color(0.72, 0.7, 0.5), 0.5)
	for k in 12:
		var q = ML.floor_at(at + side * ((k - 5.5) * 0.85) + d * randf_range(-0.4, 0.4))
		ML.dust(pj, q + Vector3.UP * 0.5, randf_range(1.3, 1.8), randf_range(1.6, 2.2), {"col": dc, "vel": d * randf_range(-0.3, 0.6) + Vector3.UP * 0.25, "nf": 3.0})
	ML.leaves(pj, at + Vector3.UP * 1.5, 16, 3.0, {"size": 0.3, "rad": 3.0, "life": 2.0})
	for k in 4:
		var q = at + side * ((k - 1.5) * 2.5)
		_crack_zone(q, 2.2)
		ML.scar(pj, q, 2.2, 7.5, {"lines": 7.0, "pit": 0.0})
		ML.chips(pj, q + Vector3.UP * 0.3, 10, 6.0, {"col": ML.soil_col(q), "size": 0.3, "spread": 45.0})
	pj.every(7.5, 0.1, func(_i, _k):
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and absf((p.global_position - at).dot(d)) < 1.0 and absf((p.global_position - at).dot(side)) < 4.8:
				ML.chips(pj, p.global_position, 8, 4.0, {"size": 0.22, "dir": -d, "spread": 70.0, "life": 0.6})
				ML.splinters(pj, p.global_position, 1, 0.35, 3.0, {"life": 0.7})
				p.queue_free(), Callable())
	pj.shake(0.5)
	Sfx.play("earth", at, 0.7)


# ================================================================== Kajukai Kōrin
## Kaynak görsel yok (kanon: Hashirama'nın çiçekli ormanı, çiçek tozu uyutur). Tasarım: kullanıcının çevresinde on üç kıvrık
## gövde dallanarak büyür; dal uçlarında pembe çiçekler gonca hâlinden taç yapraklarını açar (iki kat, uçları beyazımsı, ortası
## sarı tohum kesesi). Her çiçekten sarı polen zerreleri süzülür, alanın dibini kameraya yaklaşınca saydamlaşan yumuşak sarı pus
## kaplar. Uyuyan düşmanın başında polen halkası döner. Sonunda yapraklar dökülür, ağaçlar kuruyup gömülür.
static func _petal_mesh(pl: float, wid: float, c0: Color, c1: Color) -> ArrayMesh:
	var key = "petal_%.2f_%.2f_%s" % [pl, wid, c1.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var g = ML.Geo.new()
	var z = Vector3.ZERO
	var rows = 6
	var cols = 5
	for i in rows + 1:
		var v = float(i) / float(rows)
		var w = wid * pow(sin(PI * clampf(v * 0.92 + 0.08, 0.0, 1.0)), 0.7)
		if i == rows:
			w = 0.0
		var col = c0.lerp(c1, pow(v, 0.8))
		for j in cols:
			var u = lerpf(-1.0, 1.0, float(j) / float(cols - 1))
			var p = Vector3(u * w, v * pl, -0.3 * wid * u * u - 0.12 * pl * v * v)
			var cc = col.darkened(0.12) if j == 2 else col
			g.add(p, Vector3.BACK, Vector3.BACK, cc, Vector2.ZERO, Vector2.ZERO, z)
	for i in rows:
		for j in cols - 1:
			var a = i * cols + j
			g.quad(a, a + cols, a + 1, a + cols + 1)
	var m = g.build()
	_cache[key] = m
	return m


static func _flower(size: float) -> Dictionary:
	var root = Node3D.new()
	var mat = _smat("petal", PETAL_SHADER)
	var piv: Array = []
	var deep = Color(0.9, 0.42, 0.62)
	for layer in 2:
		var n = 8 if layer == 0 else 6
		var pm = _petal_mesh(0.62 if layer == 0 else 0.48, 0.24 if layer == 0 else 0.2, deep if layer == 0 else deep.lightened(0.1),
			Color(1.0, 0.86, 0.92) if layer == 0 else Color(1.0, 0.93, 0.96))
		for i in n:
			var pv = Node3D.new()
			pv.rotation.y = TAU * i / n + layer * 0.26
			root.add_child(pv)
			var mi = MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pv.add_child(mi)
			mi.position = Vector3(0, 0.04, 0.06 if layer == 0 else 0.03)
			mi.rotation.x = 0.12
			piv.append([mi, 1.3 if layer == 0 else 0.75])
	var pod = MeshInstance3D.new()
	pod.mesh = _ball(0.16)
	pod.material_override = ML.glow_mat(Color(1.0, 0.82, 0.3), 0.5)
	pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pod)
	pod.position = Vector3(0, 0.1, 0)
	pod.scale = Vector3(1.0, 0.55, 1.0)
	root.scale = Vector3.ONE * 0.01
	return {"node": root, "petals": piv, "size": size}


static func _bloom(fl: Dictionary, delay: float) -> void:
	var root: Node3D = fl["node"]
	var size: float = fl["size"]
	var tw = root.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(root, "scale", Vector3.ONE * size, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for e in fl["petals"]:
		var mi: Node3D = e[0]
		var ptw = mi.create_tween()
		ptw.tween_interval(delay + 0.15 + randf() * 0.12)
		ptw.tween_property(mi, "rotation:x", float(e[1]) + randf_range(-0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _pollen_mote_mat() -> StandardMaterial3D:
	return ML.glow_mat(Color(1.0, 0.88, 0.35), 0.9)


## Çiçekten süzülen polen zerreleri (sürekli, dur sn)
static func _pollen_drip(host: Node, parent: Node3D, size: float, dur: float) -> void:
	var cp = CPUParticles3D.new()
	cp.mesh = _ball(0.045)
	cp.material_override = _pollen_mote_mat()
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = 9
	cp.lifetime = 2.2
	cp.local_coords = false
	cp.direction = Vector3.DOWN
	cp.spread = 70.0
	cp.initial_velocity_min = 0.2
	cp.initial_velocity_max = 0.6
	cp.gravity = Vector3(0, -0.6, 0)
	cp.damping_min = 0.4
	cp.damping_max = 0.9
	cp.scale_amount_min = 0.8
	cp.scale_amount_max = 1.4
	cp.scale_amount_curve = ML._shrink_curve()
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = 0.45
	parent.add_child(cp)
	cp.position = Vector3.UP * 0.2
	cp.emitting = true
	host.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(cp):
			cp.emitting = false)


static func _haze_mesh() -> SphereMesh:
	if _cache.has("haze_mesh"):
		return _cache["haze_mesh"]
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 20
	s.rings = 10
	_cache["haze_mesh"] = s
	return s


static func _haze_blob(pj: PathJutsu, p: Vector3, sz: Vector3, dur: float, delay: float) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _haze_mesh()
	mi.material_override = _smat("haze", HAZE_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ML.put(pj, mi, p)
	mi.scale = sz * 0.6
	mi.set_instance_shader_parameter("dens", 0.0)
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	var drift = Vector3(randf_range(-1, 1), 0.15, randf_range(-1, 1)) * 1.2
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_method(ML.pi_set(mi, "dens"), 0.0, 0.42, 1.0).set_delay(delay)
	tw.tween_property(mi, "scale", sz, 1.6).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", p + drift, dur).set_delay(delay)
	tw.tween_method(ML.pi_set(mi, "dens"), 0.42, 0.0, 1.0).set_delay(delay + dur - 1.0)
	tw.chain().tween_callback(mi.queue_free)


static func _sleep_ring(pj: PathJutsu, e: Node3D) -> void:
	var h = 1.8
	if e.get("height") != null:
		h = clampf(float(e.get("height")), 1.0, 40.0)
	var cp = CPUParticles3D.new()
	cp.mesh = _ball(0.05)
	cp.material_override = _pollen_mote_mat()
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = 18
	cp.lifetime = 1.4
	cp.one_shot = true
	cp.explosiveness = 0.8
	cp.local_coords = false
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	cp.emission_ring_axis = Vector3.UP
	cp.emission_ring_radius = clampf(h * 0.3, 0.4, 6.0)
	cp.emission_ring_inner_radius = cp.emission_ring_radius * 0.8
	cp.emission_ring_height = 0.1
	cp.direction = Vector3.UP
	cp.spread = 20.0
	cp.initial_velocity_min = 0.2
	cp.initial_velocity_max = 0.5
	cp.tangential_accel_min = 1.5
	cp.tangential_accel_max = 2.5
	cp.gravity = Vector3.ZERO
	cp.scale_amount_curve = ML._shrink_curve()
	ML.put(pj, cp, e.global_position + Vector3.UP * h * 0.95)
	cp.emitting = true
	ML.kill(pj, 2.2, cp)


static func mokuton_kajukai_korin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# kanon: kalın kıvrık gövdeler fışkırır, tepelerinde çiçekler açar; alanı polen sisi kaplar, soluyan uyur
	pj.busy(c, 1.4)
	var at = pj.gp(c.global_position)
	var flowers: Array = []
	var away = ML.away_dir(pj, at)   # kameradan kullanıcıya yatay yön
	for k in 13:
		var p = Vector3.ZERO
		var ok = false
		for _try in 6:
			var a = TAU * k / 13.0 + randf() * 0.3 + _try * 0.9
			p = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 9.0))
			var rel = p - at
			rel.y = 0.0
			if ML.near_cam(pj, p + Vector3.UP * 2.0, 8.0):
				continue
			if away != Vector3.ZERO and rel.normalized().dot(-away) > 0.45:
				continue
			ok = true
			break
		if not ok:
			continue
		var h = randf_range(4.0, 7.5)
		var top = Vector3(randf_range(-1.2, 1.2), h, randf_range(-1.2, 1.2))
		var g = ML.Geo.new()
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var tr = ML.tree(g, Vector3.DOWN * 0.3, top.normalized(), h * 1.05, randf_range(0.42, 0.6),
			{"rng": rng, "depth": 1, "kids": 3, "spread": 0.75, "tip": 0.22, "bend": 0.4, "seg_len": 0.9, "gnarl": 0.12, "sides": 10,
			"up": Vector3.UP * 0.12})
		var mi = ML.inst(pj, g.build(), p, {"ow": 0.035, "nf": 8.0, "taper": 1.3, "body": ML.BARK.darkened(0.05)})
		ML.life(mi, float(tr["len"]), 0.4 + 0.2, 6.0, 0.45, k * 0.05, {"out": "sink", "depth": h + 1.0, "taper": 1.3})
		var tips: Array = tr["tips"]
		for i in mini(tips.size(), 4):
			var fsz = randf_range(1.4, 2.0) if i == 0 else randf_range(0.9, 1.3)
			var fl = _flower(fsz)
			var fnode: Node3D = fl["node"]
			mi.add_child(fnode)
			fnode.position = tips[i]
			fnode.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
			_bloom(fl, 0.65 + k * 0.05 + i * 0.08)
			flowers.append(fl)
			pj.after(1.1 + k * 0.05, func():
				if is_instance_valid(fnode):
					_pollen_drip(pj, fnode, fsz, 5.2))
		ML.chips(pj, p + Vector3.UP * 0.3, 8, 4.0, {"col": ML.soil_col(p), "size": 0.3})
		ML.dust(pj, p + Vector3.UP * 0.4, 1.4, 1.0, {"col": ML.dust_col(p), "vel": Vector3.UP * 0.5, "nf": 4.0})
	# alanın dibinde yumuşak sarı polen pusu
	for k in 14:
		var a = randf() * TAU
		var q = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 8.0))
		var rel = q - at
		rel.y = 0.0
		if away != Vector3.ZERO and rel.length() > 0.5 and rel.normalized().dot(-away) > 0.2:
			continue
		if ML.near_cam(pj, q, 10.0):
			continue
		_haze_blob(pj, q + Vector3.UP * randf_range(0.3, 0.6), Vector3(randf_range(3.5, 5.5), randf_range(0.9, 1.4), randf_range(3.5, 5.5)), 5.6, 0.6 + randf() * 0.5)
	var cloud = CPUParticles3D.new()
	cloud.mesh = _ball(0.05)
	cloud.material_override = _pollen_mote_mat()
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.amount = 160
	cloud.lifetime = 3.0
	cloud.local_coords = false
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cloud.emission_box_extents = Vector3(8.5, 1.2, 8.5)
	cloud.direction = Vector3.UP
	cloud.spread = 180.0
	cloud.initial_velocity_min = 0.1
	cloud.initial_velocity_max = 0.35
	cloud.gravity = Vector3(0, 0.05, 0)
	cloud.scale_amount_min = 0.6
	cloud.scale_amount_max = 1.4
	cloud.scale_amount_curve = ML._shrink_curve()
	cloud.emitting = false
	ML.put(pj, cloud, at + Vector3.UP * 1.5)
	pj.after(0.7, func():
		if is_instance_valid(cloud):
			cloud.emitting = true)
	pj.after(6.3, func():
		if is_instance_valid(cloud):
			cloud.emitting = false)
	ML.kill(pj, 9.8, cloud)
	ML.scar(pj, at, 9.5, 7.0, {"lines": 13.0, "pit": 0.0, "rings": 2.0})
	# sonda taç yaprakları dökülür
	pj.after(6.1, func():
		for fl in flowers:
			var fn: Node3D = fl["node"]
			if is_instance_valid(fn):
				ML.leaves(pj, fn.global_position, 6, 1.6, {"col": Color(0.98, 0.7, 0.82), "size": 0.3 * float(fl["size"]), "life": 2.2, "spread": 120.0})
				var ftw = fn.create_tween()
				ftw.tween_property(fn, "scale", Vector3.ONE * 0.02, 0.35).set_ease(Tween.EASE_IN))
	pj.every(6.0, 0.35, func(_i, _k):
		# kanon: çiçek tozunu soluyan bilinçsiz düşer — ~2 sn soluyan uyur (rastgele değil)
		for e in pj.enemies_near(c, at, 9.0):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("slow", 0.6)
				var pt = float(e.get_meta("pollen_t", 0.0)) + 0.35
				e.set_meta("pollen_t", pt)
				if pt >= 2.0:
					e.set_meta("pollen_t", -3.0)
					e.apply_status("sleep", 4.0)
					_sleep_ring(pj, e)
					Combat.popup_text(e.global_position + Vector3.UP * 2.2, "Zzz", Color(1, 0.9, 0.95)), Callable())
	pj.shake(0.8)
	Sfx.play("earth", at, 0.6)


# ================================================================== Senpō: Chōjō Kebutsu
## Kaynak görsel yok (kanon: Hashirama, Shin Sūsenju'nun tepesinden; yüzlerce Buda eli gökten yağar). Tasarım: hedefin çok
## ötesinde (kameranın karşısında, ~230 m) gerçek ShinSusenju heykeli küçültülmüş ölçekte bulut setinin içinden yükselir.
## Sonra gökten dik inen Buda elleri — parmakları bitişik düz avuç, ön kolda geniş yen ağzı, arkalarında beyaz düşüş çizgileri —
## alanı döver: her biri yere el biçiminde koyu bir iz basar, çevresine toz tacı ve toprak kıymığı saçar, sonra göğe geri çekilir.
static func _kebutsu_hand() -> Dictionary:
	if _cache.has("kebutsu_hand"):
		return _cache["kebutsu_hand"]
	var g = ML.Geo.new()
	# yerel: kol +Y boyunca, parmak uçları ~9 m'de (eski iniş mesafesi)
	var L = _hand(g, 1.85, {"base": Vector3(0, 7.2, 0), "arm": 3.8, "curl": 0.05, "spread": 0.0, "cuff": true, "seed": 6.0})
	var out = {"mesh": g.build(), "len": L}
	_cache["kebutsu_hand"] = out
	return out


static func chojo_kebutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 34.0)
	var fd = pj.fwd(c, t)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	# uzak heykel: hedefin ötesinde, kullanıcıya dönük; bulut setinden yükselip sonra geri batar (oynanışa katılmaz)
	var sp = pj.gp(at + fd * 230.0)
	var ss = ShinSusenju.spawn(pj.get_tree().current_scene, sp - Vector3.UP * 200.0, atan2(fd.x, fd.z))
	ss.scale = Vector3.ONE * 0.4
	var stw = ss.create_tween()
	stw.tween_property(ss, "global_position", sp - Vector3.UP * 22.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stw.tween_interval(2.6)
	stw.tween_property(ss, "global_position", sp - Vector3.UP * 200.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	stw.tween_callback(ss.queue_free)
	var cc = Color(0.62, 0.66, 0.6)
	for k in 12:
		var a = TAU * k / 12.0
		var q = ML.floor_at(sp + Vector3(cos(a), 0, sin(a)) * randf_range(40.0, 70.0))
		ML.dust(pj, q + Vector3.UP * 12.0, randf_range(34.0, 48.0), 4.6, {"col": cc, "vel": Vector3(cos(a), 0.2, sin(a)) * 4.0, "nf": 40.0})
	var hd = _kebutsu_hand()
	var lm = _flat("fall_line", Color(1, 1, 1, 0.6), true)
	for k in 16:
		pj.after(0.4 + k * 0.08, func():
			# Chōjō Kebutsu: binlerce ahşap koldan açık avuçlar gökten iner, yeri döver
			var q = pj.gp(at + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7)))
			var src = q + Vector3(randf_range(-8, 8), 38.0, randf_range(-8, 8))
			var hand = ML.inst(pj, hd["mesh"], src, {"ow": 0.09, "nf": 10.0, "seed": k * 0.53, "body": Color(0.56, 0.5, 0.4)})
			hand.look_at(q + Vector3(0.001, 0, 0), Vector3.UP)
			hand.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
			hand.rotate_object_local(Vector3.UP, randf_range(-0.6, 0.6))
			for j in 4:
				var ln = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.05, randf_range(5.0, 9.0), 0.05)
				ln.mesh = bm
				ln.material_override = lm
				ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				hand.add_child(ln)
				ln.position = Vector3(randf_range(-1.8, 1.8), randf_range(-6.0, -3.0), randf_range(-1.8, 1.8))
			var dir = (q - src).normalized()
			var tw = hand.create_tween()
			tw.tween_property(hand, "global_position", q - dir * 9.0, 0.35).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				for ch in hand.get_children():
					if ch is MeshInstance3D and ch.name != "ol":
						ch.queue_free()
				_palm_print(pj, q, dir, 2.2, 4.0)
				var sl = ML.soil_col(q)
				ML.dust_ring(pj, q, 2.0, 8, 1.4, 1.0, {"spd": 4.0, "nf": 5.0})
				ML.chips(pj, q + Vector3.UP * 0.4, 12, 8.0, {"col": sl, "col2": sl.lightened(0.3), "size": 0.35, "rad": 1.2})
				ML.splinters(pj, q + Vector3.UP * 0.5, 2, 0.5, 6.0, {"col": sl})
				_crack_zone(q, 3.0)
				pj.hit(c, q + Vector3.UP, 2.6, pj.inf(c, "chojo_kebutsu", 0.5, {"knock": 8.0, "launch": 4.0, "kind": "heavy", "element": "mokuton"})))
			tw.tween_interval(1.2)
			tw.tween_property(hand, "global_position", src, 0.5).set_ease(Tween.EASE_IN)
			tw.tween_callback(hand.queue_free))
	pj.shake(1.4)
	Sfx.play("earth", at, 0.5)
