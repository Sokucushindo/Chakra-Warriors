class_name FutonFXC
extends RefCounted
## Fūton grubu C: on beş rüzgâr tekniğinin görselleri. Malzeme ve yapı taşları FutonLib'den (akım çizgisi, hava perdesi,
## kesici hilal, basınç bükülmesi, zemin izi, savrulan parçalar); bu gruba özgü üç gölgelendirici burada:
##   sarmal bantlı hava topu (Rasen Kyūdan), dönen Rasengan çekirdeği, dalgalanan sancak kumaşı (Hataryū).
## Katı koni / kubbe / kabuk yok; geniş perdeler kameraya 6-9 m içinde söner.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı;
## eski görsel çağrıların oyun etkisi (saç/kumaş savrulması) açıkça korunur.

const WHITE := Color(1.0, 1.0, 1.0, 0.95)
const ICE := Color(0.8, 0.92, 1.0, 0.95)
const STORM := Color(0.82, 0.85, 0.9, 0.95)
const SAND := Color(0.9, 0.78, 0.55, 0.95)
const SAND_L := Color(0.98, 0.9, 0.72, 0.95)
const SAND_D := Color(0.74, 0.6, 0.4, 0.95)
const JADE := Color(0.6, 0.95, 0.75, 0.95)
const MINT := Color(0.84, 1.0, 0.93, 0.95)

static var _cache := {}


# ================================================================== bu gruba özgü gölgelendiriciler
## Sarmal bantlı hava topu (ref: Rasen Kyūdan — üst üste dizilmiş, birbirine sarılan soluk mavi-beyaz hava katmanları,
## aralarında koyu mavi oluklar, tepede küçük ağız, yumuşak parlak kenar)
const BAND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near = 1.6;
instance uniform float bands = 4.5;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(lp);
	float ang = atan(n.z, n.x) / 6.2831853;
	float s = n.y * bands + ang - TIME * 2.4;
	float f = fract(s);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(vec3(0.78, 0.86, 1.0), vec3(0.97, 0.99, 1.0), smoothstep(-0.3, 0.7, n.y));
	float a = 0.9;
	if (f < 0.15) {
		col = vec3(0.42, 0.52, 0.86);
		a = 0.62;
	} else if (f < 0.22) {
		col = mix(col, vec3(1.0), 0.6);
	}
	if (n.y > 0.94) {
		col = vec3(1.0);
		a = 0.95;
	} else if (n.y > 0.9) {
		col = vec3(0.42, 0.52, 0.86);
		a = 0.8;
	}
	if (fr > 0.84) {
		col = mix(vec3(0.55, 0.7, 1.0), vec3(1.0), 0.35);
		a = 0.55 * (1.0 - smoothstep(0.92, 1.0, fr));
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Rasengan çekirdeği (ref: Fūton Rasengan — açık mavi küre, içinde döne döne akan beyaz / koyu mavi çizgiler, koyu ince kontur)
const RASEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near = 1.2;
varying vec3 lp;

FNOISE

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(lp);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(n.z, n.x);
	float sw = wf(vec2(ang * 1.6 + n.y * 3.0 - TIME * 9.0, n.y * 2.5 + TIME * 1.5));
	vec3 col = mix(vec3(0.84, 0.94, 1.0), vec3(0.38, 0.64, 1.0), smoothstep(0.2, 0.75, fr));
	if (sw > 0.6) {
		col = mix(col, vec3(1.0), 0.65);
	} else if (sw < 0.3) {
		col = mix(col, vec3(0.22, 0.44, 0.92), 0.5);
	}
	float a = 0.88;
	if (fr > 0.9) {
		col = vec3(0.14, 0.27, 0.62);
		a = 0.95;
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Sancak kumaşı (ref: Hataryū — beyaz bez, çapraz yeşil-mavi şerit, kahverengi kanat işareti, serbest ucu basamak basamak yırtık);
## köşe gölgelendiricisinde dalga sapa doğru söner
const CLOTH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

instance uniform float wave = 1.0;
varying float sh;

void vertex() {
	float u = UV.x;
	float ph = u * 9.0 - TIME * 16.0;
	VERTEX.z += sin(ph) * 0.18 * u * wave;
	VERTEX.y += sin(ph * 0.6 + 1.3) * 0.05 * u * wave;
	sh = cos(ph);
}

void fragment() {
	vec2 p = UV;
	float row = floor(p.y * 7.0);
	float cut = 0.88 + 0.1 * fract(row * 0.37 + 0.2);
	if (p.x > cut) {
		discard;
	}
	vec3 col = vec3(0.96, 0.95, 0.9);
	float bd = abs(p.y - 0.5 + (p.x - 0.5) * 0.2);
	if (bd < 0.2 && p.x > 0.1 && p.x < cut - 0.08) {
		col = vec3(0.3, 0.64, 0.58);
	}
	vec2 q = p - vec2(0.42, 0.48);
	float wing = abs(q.y + q.x * 0.45);
	if (abs(q.x) < 0.24 && wing < 0.075 * (1.0 - abs(q.x) * 3.2)) {
		col = vec3(0.45, 0.28, 0.18);
	}
	float edge = min(min(p.y, 1.0 - p.y), cut - p.x);
	if (edge < 0.022) {
		col *= 0.42;
	}
	if (sh < -0.2) {
		col *= 0.82;
	}
	ALBEDO = col;
}
"""


static func _smat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("FNOISE", FutonLib.FNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _sphere(r: float) -> SphereMesh:
	var key = "sph_%.2f" % r
	if not _cache.has(key):
		var s = SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 24
		s.rings = 14
		_cache[key] = s
	return _cache[key]


## Yakın dövüş vuruşu (eski ortak vuruşun oynanış kısmı: hasar + ekran sarsıntısı); görsel her teknikte kendisinin
static func _melee_hit(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary) -> Array:
	var hs = pj.hit(c, pos, r, info)
	if not hs.is_empty():
		var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
		var heavy = String(info.get("kind", "")) == "heavy"
		pj.shake(0.2 + 0.3 * (s if heavy else s * 0.7))
	return hs


## Daire çizgisi (ax eksenine dik düzlemde, r yarıçap)
static func _ring_pts(center: Vector3, ax: Vector3, r: float, n := 20, span := 0.92) -> PackedVector3Array:
	return FutonLib.helix_pts(center, ax, r, r, 0.0, 0.0, randf() * TAU, span, n)


# ================================================================== 1. Shinkūken (Vakum Kılıcı)
## Ref: Asuma'nın bıçağından uzayan chakra kılıcı; savuruşta tek, çok ince, göz alıcı beyaz yay (iki katlı, uçları sivri).
## Görünüş: bıçak boyunca titreyen ince vakum kenarı (çift çizgi) → savuruşta ileri giderek genişleyen ince parlak yay dizisi
## (ana yay + yanında ince yankı), yay boyunca yatay basınç yarığı, yolda yere kesik yarıkları, kesiğin geçtiği hedeflerde çapraz çizik.
static func shinkuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var _tt = pj.tg(c, t, 12.0)
	var d = pj.fwd(c, t)
	var kat = pj.jutsu_weapon(c, "katana", 0.8)
	_vacuum_edge(pj, kat, 0.8)
	pj.anim(c, "slash_a", 1.6)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		var o = c.global_position + Vector3.UP * 1.2 + d * 0.6
		_vacuum_arc(pj, c, o, d)
		Combat.hit_zone(c, c.global_position, d, 11.0, 14.0, 2.0, pj.inf(c, "shinkuken", 1.4, {"knock": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 5.0, "dir": d}))
		Sfx.play("wind", o, 2.0, 0.5))


static func _vacuum_edge(pj: PathJutsu, kat: Node3D, dur: float) -> void:
	if kat == null or not is_instance_valid(kat):
		return
	# bıçağın iki yüzünde, ucun ötesine uzanan ince titrek vakum kenarı
	for sgn in [-1.0, 1.0]:
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return Vector3(sgn * (0.04 + u * 0.03), 0.15 + u * 1.9, 0.0), 12)
		var mi = FutonLib.fixed(pj, pts, 0.035 if sgn > 0.0 else 0.022, "line", ICE, {"parent": kat, "flow": 9.0, "near": 1.2})
		mi.scale = Vector3(1.0, 0.2, 1.0)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for _k in 6:
			tw.tween_method(FutonLib.pf(mi, "fade"), 1.0, 0.45, 0.05)
			tw.tween_method(FutonLib.pf(mi, "fade"), 0.45, 1.0, 0.05)
		FutonLib.kill(pj, dur, mi)


static func _vacuum_arc(pj: PathJutsu, c: Node3D, o: Vector3, d: Vector3) -> void:
	var side = FutonLib.side_of(d)
	var tilt = randf_range(0.15, 0.35)
	# giderek açılan ince yay: dört anlık görüntü ileri kayar (yay ileri uçuyormuş gibi)
	for k in 4:
		var s = [1.6, 4.2, 7.3, 10.6][k]
		var W = lerpf(3.0, 4.8, k / 3.0)
		var sag = lerpf(0.9, 1.4, k / 3.0)
		var arc = func(u: float) -> Vector3:
			var x = u * 2.0 - 1.0
			return o + side * x * W * 0.5 + d * (s + sag * (1.0 - x * x)) + Vector3.UP * x * tilt
		var life = 0.3 - k * 0.03
		FutonLib.line(pj, FutonLib.path_pts(arc, 22), 0.075, life, WHITE, {"delay": k * 0.035, "grow": 0.3, "flow": 8.0})
		var echo = func(u: float) -> Vector3: return arc.call(u) - d * 0.28 + Vector3.UP * 0.1
		FutonLib.line(pj, FutonLib.path_pts(echo, 18), 0.028, life * 0.9, ICE, {"delay": k * 0.035 + 0.02, "grow": 0.3, "flow": 8.0})
		if k == 0:
			FutonLib.sheet(pj, FutonLib.path_pts(arc, 18), 0.35, 0.32, ICE, {"opacity": 0.3, "lines": 3.0, "grow": 0.3, "hint": Vector3.UP, "twin": false})
	# yay boyunca yatay basınç yarığı (arkasındaki görüntü kırılır)
	var f = Vector3(d.x, 0.0, d.z).normalized()
	var sd = FutonLib.side_of(f)
	FutonLib.warp(pj, o + d * 5.5, 0.35, 0.5, 0.35, {"ring": false, "bill": false, "basis": Basis(sd, f, sd.cross(f)), "aspect": Vector3(3.5, 9.0, 1.0), "power": 1.0, "fade_from": 0.3})
	FutonLib.scour(pj, c.global_position + d * 6.0, d, 10.0, 3.2, 1.6, 2)
	# kesiğin geçtiği hedeflerde ince çapraz çizik
	for e in pj.enemies_near(c, c.global_position + d * 5.5, 6.0):
		if pj.live(e):
			var p = e.global_position + Vector3.UP * 1.1
			FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + side * lerpf(-0.8, 0.8, u) + Vector3.UP * lerpf(0.5, -0.5, u) - d * 0.3, 8), 0.03, 0.22, WHITE, {"delay": 0.08, "grow": 0.25})


# ================================================================== 2. Fūton: Rasen Kyūdan (Sarmal Rüzgâr Topu)
## Ref: avuç önünde, üst üste sarılmış soluk mavi-beyaz hava katmanlarından arı kovanı gibi top, aralarda koyu mavi oluklar.
## Görünüş: avuçta sarmal çizgiler toplanıp küçük bantlı top olur → fırlayan büyük bantlı top (bantlar döner, yolda büyür),
## arkasında top kenarından kopan iki sarmal çizgi + soluk iz; çarpınca bantlar yatay halkalar halinde açılıp dağılır.
static func futon_rasen_kyudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 30.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		_kyudan_form(pj, ba, 0.45)
		pj.free_after(0.45, ba)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		var ball = Node3D.new()
		var from = pj.hand_pos(c, true)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, ball, pj.inf(c, "futon_rasen_kyudan", 1.0, {"knock": 10.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0}), null, true, 1.4, func(p, _h):
			_kyudan_pop(pj, p))
		pr.radius = 0.9
		_kyudan_ball(pj, ball, 0.55)
		pj.every(1.4, 0.1, func(_i, k):
			if is_instance_valid(ball):
				ball.scale = Vector3.ONE * (1.0 + k * 1.2), Callable()))
	Sfx.play("rasengan", c.global_position, 1.5)


static func _band_ball(r: float) -> MeshInstance3D:
	var mi = FutonLib.gi(_sphere(r), _smat("band", BAND_SHADER))
	mi.scale = Vector3(1.0, 1.1, 1.0)
	return mi


static func _kyudan_form(pj: PathJutsu, ba: Node3D, dur: float) -> void:
	for k in 5:
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.75, 0.06, 0.55, 0.05, TAU * k / 5.0, 1.4, 16)
		FutonLib.line(pj, pts, 0.03, dur * 0.85, ICE, {"parent": ba, "delay": k * 0.03, "grow": 0.55, "flow": 7.0, "near": 1.0})
	var core = _band_ball(0.2)
	FutonLib.put(pj, core, Vector3(0.0, 0.08, 0.0), ba)
	core.scale = Vector3.ONE * 0.1
	var tw = core.create_tween()
	tw.tween_property(core, "scale", Vector3(1.0, 1.1, 1.0), dur * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _kyudan_ball(pj: PathJutsu, ball: Node3D, r: float) -> void:
	var core = _band_ball(r)
	FutonLib.put(pj, core, Vector3.ZERO, ball)
	core.set_instance_shader_parameter("bands", 4.0)
	# top kenarından kopup arkada sarmal çizen iki ince çizgi + soluk hava izi
	for k in 2:
		var off = Vector3(r * 1.05, 0.0, 0.0).rotated(Vector3.FORWARD, PI * k)
		FutonLib.follow(pj, ball, 0.04, 14, ICE, {"offset": off, "spin": 16.0, "flow": 9.0})
	FutonLib.follow(pj, ball, r * 0.8, 9, ICE, {"kind": "sheet", "opacity": 0.3, "lines": 3.0, "near": 4.0})


static func _kyudan_pop(pj: PathJutsu, p: Vector3) -> void:
	# bantlar çözülür: üst üste yatay halkalar (merkezdeki düğüme bağlı) dışa açılarak dağılır
	var hub = Node3D.new()
	FutonLib.put(pj, hub, p)
	FutonLib.kill(pj, 0.6, hub)
	for k in 4:
		var h = (k - 1.5) * 0.45
		var pts = _ring_pts(Vector3.UP * h, Vector3.UP, 0.5, 22, 0.9)
		var mi = FutonLib.line(pj, pts, 0.06, 0.45, WHITE if k % 2 == 0 else ICE, {"parent": hub, "grow": 0.25, "flow": 10.0})
		var wide = 5.5 - absf(h) * 2.0
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(wide, 1.0, wide), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	FutonLib.warp(pj, p, 0.3, 3.4, 0.38, {"power": 1.3, "band": 0.12})
	FutonLib.bits(pj, p, 10, "grit", {"life": 0.6, "size": 0.12, "vmin": 5.0, "vmax": 10.0, "spread": 180.0, "radius": 0.4, "g": Vector3(0, -10.0, 0),
		"cols": [Color(0.86, 0.9, 1.0, 1), Color(0.7, 0.78, 0.95, 1), Color(0.7, 0.78, 0.95, 0)]})


# ================================================================== 3. Fūton: Hataryū (Sancak Akımı)
## Ref: elde dalgalanan uzun sancak (beyaz bez, yeşil-mavi şerit, kahverengi işaret, basamaklı yırtık uç); arkasında kum bulutları,
## savruluş yönünde uzun yumuşak akım bantları.
## Görünüş: elde açılıp dalgalanan sancak → sancak savruluşundan çıkan beş dalgalı uzun bant (ucu bayrak gibi genişler,
## üst kenarı keskin beyaz), yerde süpürülmüş toz izi, akımın ucunda kabaran kum bulutu topakları.
static func futon_hata_ryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var o = c.global_position + Vector3.UP * 1.0
	_banner(pj, c, 0.8)
	for i in 5:
		var off = (i - 2) * 1.1
		var ph = randf() * TAU
		_banner_stream(pj, o, d, side, off, ph, i)
	FutonLib.scour(pj, c.global_position + d * 1.0, d, 21.0, 8.0, 1.8, 0)
	Combat.hit_zone(c, c.global_position, d, 22.0, 30.0, 3.0, pj.inf(c, "futon_hata_ryu", 1.0, {"knock": 16.0, "launch": 1.0, "kind": "heavy", "element": "fuuton", "dir": d}))
	Sfx.play("wind", c.global_position, 1.0)


static func _banner(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	if not _cache.has("pole"):
		var b = MB.new()
		b.add("cyl", Vector3(0, 0.55, 0), Vector3(0.05, 2.3, 0.05), Color(0.32, 0.22, 0.14), Vector3.ZERO, 8)
		b.add("cone", Vector3(0, 1.78, 0), Vector3(0.09, 0.2, 0.09), Color(0.8, 0.7, 0.4), Vector3.ZERO, 6)
		_cache["pole"] = b.build(FutonLib.rock_mat())
	FutonLib.put(pj, FutonLib.gi(_cache["pole"], null), Vector3.ZERO, ba)
	var pivot = Node3D.new()
	FutonLib.put(pj, pivot, Vector3(0.0, 1.28, 0.0), ba)
	var q = QuadMesh.new()
	q.size = Vector2(1.9, 0.85)
	q.subdivide_width = 18
	q.subdivide_depth = 5
	var cloth = FutonLib.gi(q, _smat("cloth", CLOTH_SHADER))
	FutonLib.put(pj, cloth, Vector3(0.97, 0.0, 0.0), pivot)
	pivot.scale = Vector3(0.15, 1.0, 1.0)
	var tw = pivot.create_tween()
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.free_after(dur + 0.1, ba)


static func _banner_stream(pj: PathJutsu, o: Vector3, d: Vector3, side: Vector3, off: float, ph: float, i: int) -> void:
	var fn = func(q: float) -> Vector3: return o + d * q * 22.0 + side * (off + sin(q * 10.0 + ph) * 0.9) + Vector3.UP * (cos(q * 7.0 + ph) * 0.6 + 0.4)
	var n = 30
	var pts = FutonLib.path_pts(fn, n)
	var ws = PackedFloat32Array()
	for k in n:
		var u = float(k) / float(n - 1)
		ws.append(lerpf(0.35, 1.3, u * u))
	var tint = SAND_L if i % 2 == 0 else Color(0.92, 0.93, 0.9, 0.95)
	FutonLib.sheet(pj, pts, 0.7, 1.7, tint, {"delay": i * 0.06, "opacity": 0.55, "lines": 3.0, "widths": ws, "grow": 0.5, "flow": 4.0, "near": 7.0})
	# bandın üst kenarında keskin beyaz kenar çizgisi
	var top = FutonLib.path_pts(func(q: float) -> Vector3: return fn.call(q) + Vector3.UP * lerpf(0.3, 0.85, q * q), n)
	FutonLib.line(pj, top, 0.05, 1.5, WHITE, {"delay": i * 0.06 + 0.04, "grow": 0.5, "flow": 5.0, "near": 7.0})
	# akımın ucunda kabaran kum bulutu topakları
	var end = fn.call(0.8)
	FutonLib.bits(pj, end, 4, "puff", {"life": 1.7, "size": 1.5, "vmin": 2.0, "vmax": 5.0, "dir": d, "spread": 50.0, "radius": 1.2, "damp": 1.5,
		"g": Vector3(0, 0.3, 0), "grow": [0.6, 1.7], "spin": 30.0, "cols": FutonLib.dust_cols(end, 0.8)})


# ================================================================== 4. Shakujō Senpū (Asa Burgusu)
## Görünüş: asanın tepesindeki halkalar çevresinde dönen ince çember çizgileri → önünde yatay eksenli, ileri doğru incelen
## sarmal burgu (çizgilerden; ağzında dönen tırtıklı hava hilali), her darbede çekilen hedeften burguya uzanan emme çizgisi,
## içe doğru çekilen çakıl, yerde ışınsal süpürme izi.
static func shakujo_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var staff = pj.jutsu_weapon(c, "shakujo", 1.4)
	var at = pj.gp(c.global_position + d * 4.0)
	_staff_rings(pj, staff, 1.3)
	FutonLib.scour(pj, at, d, 9.0, 9.0, 1.6, 1)
	pj.every(1.2, 0.3, func(i, _k):
		_auger(pj, at, d, i)
		for e in pj.enemies_near(c, at, 7.0):
			if pj.live(e):
				_suction(pj, e.global_position + Vector3.UP, at + Vector3.UP * 0.9)
				e.global_position = e.global_position.lerp(at + Vector3.UP * 0.5, 0.25)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "shakujo_senpu", 0.28, {"knock": 2.0, "launch": 3.0, "kind": "light", "element": "fuuton"})), Callable())
	Sfx.play("wind", at, 0.9)


static func _staff_rings(pj: PathJutsu, staff: Node3D, dur: float) -> void:
	if staff == null or not is_instance_valid(staff):
		return
	var pivot = Node3D.new()
	FutonLib.put(pj, pivot, Vector3(0.0, 1.62, 0.0), staff)
	for k in 2:
		FutonLib.fixed(pj, _ring_pts(Vector3.UP * (k * 0.22 - 0.1), Vector3.UP, 0.5 + k * 0.12, 18, 0.8), 0.03, "line", WHITE, {"parent": pivot, "flow": 8.0, "near": 1.2})
	var tw = pivot.create_tween()
	tw.tween_property(pivot, "rotation:y", TAU * 9.0, dur)
	FutonLib.kill(pj, dur, pivot)


static func _auger(pj: PathJutsu, at: Vector3, d: Vector3, i: int) -> void:
	var f = Vector3(d.x, 0.0, d.z).normalized()
	var mouth = at + Vector3.UP * 1.2 - f * 1.6
	# ileri doğru incelen yatay sarmal: üç kol, her darbede biraz dönmüş
	for k in 3:
		var pts = FutonLib.helix_pts(mouth, f, 1.7, 0.15, 0.0, 3.8, i * 0.9 + TAU * k / 3.0, 1.7, 26)
		FutonLib.line(pj, pts, 0.06, 0.42, WHITE if k == 0 else ICE, {"grow": 0.45, "flow": 9.0, "near": 3.0})
	FutonLib.sheet(pj, FutonLib.helix_pts(mouth, f, 1.4, 0.2, 0.0, 3.6, i * 0.9 + 1.0, 1.2, 20), 0.45, 0.45, ICE, {"opacity": 0.35, "lines": 3.0, "grow": 0.45, "near": 3.0})
	FutonLib.blade(pj, mouth, FutonLib.blade_basis(Vector3.UP.rotated(f, i * 1.3), f), 3.0, 0.35, WHITE, {"spin": 14.0, "jag": 0.7, "thick": 0.18, "near": 3.0})
	FutonLib.bits(pj, at + Vector3.UP * 0.6, 12, "grit", {"life": 0.6, "size": 0.12, "vmin": 0.5, "vmax": 1.5, "radius": 4.0, "radial": -14.0, "tang": 10.0,
		"g": Vector3(0, 2.0, 0), "cols": [FutonLib.ground_col(at).darkened(0.25), FutonLib.ground_col(at).darkened(0.3), Color(0.5, 0.45, 0.4, 0.0)]})


static func _suction(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var bow = Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 0.8), randf_range(-0.6, 0.6))
	FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return from.lerp(to, u) + bow * sin(u * PI), 12), 0.04, 0.3, ICE, {"grow": 0.6, "flow": 10.0})


# ================================================================== 5. Kujaku Senpū (Tavus Kuşu Kasırgası)
## Görünüş: ortadan yanlara sırayla açılan dokuz renkli tüy (kemerli, uca doğru genişleyen yarı saydam perde + beyaz tüy sapı);
## her tüyün ucunda iki renkli "göz" hilali belirip kesik olarak ileri fırlar; tabandan renkli tüy kırıntıları, yerde yelpaze izi.
static func kujaku_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var o = c.global_position + Vector3.UP * 1.3
	var cols = [Color(0.55, 0.85, 1.0), Color(0.6, 1.0, 0.75), Color(1.0, 0.85, 0.5), Color(0.85, 0.65, 1.0), Color(0.55, 0.85, 1.0)]
	for i in 9:
		var ang = deg_to_rad(lerpf(-70.0, 70.0, i / 8.0))
		var dd = d.rotated(Vector3.UP, ang)
		var ccol: Color = cols[i % cols.size()]
		_feather(pj, o, dd, ccol, absf(i - 4) * 0.03)
	FutonLib.scour(pj, c.global_position, d, 7.0, 7.0, 1.4, 1, Color(0.7, 0.8, 0.85, 0.55))
	FutonLib.bits(pj, o, 22, "leaf", {"life": 1.2, "size": 0.3, "vmin": 6.0, "vmax": 12.0, "dir": d, "spread": 70.0, "radius": 0.5, "g": Vector3(0, -2.0, 0),
		"cols": [Color(0.45, 0.85, 0.85, 1), Color(1.0, 0.85, 0.45, 1), Color(0.8, 0.6, 1.0, 0)]})
	Combat.hit_zone(c, c.global_position, d, 14.0, 140.0, 3.0, pj.inf(c, "kujaku_senpu", 1.1, {"knock": 10.0, "launch": 3.0, "kind": "heavy", "element": "fuuton", "bleed": 3.0, "dir": d}))
	Sfx.play("wind", c.global_position, 1.2)


static func _feather(pj: PathJutsu, o: Vector3, dd: Vector3, col: Color, dl: float) -> void:
	var fn = func(q: float) -> Vector3: return o + dd * q * 14.0 + Vector3.UP * sin(q * PI) * 1.5
	var n = 24
	var ws = PackedFloat32Array()
	for k in n:
		var u = float(k) / float(n - 1)
		ws.append(maxf(0.12, smoothstep(0.0, 0.75, u) * (1.0 - smoothstep(0.86, 1.0, u))))
	var tint = Color(col.r, col.g, col.b, 0.95)
	FutonLib.sheet(pj, FutonLib.path_pts(fn, n), 0.8, 1.5, tint, {"delay": dl, "opacity": 0.6, "lines": 7.0, "widths": ws, "grow": 0.4, "flow": 3.0, "hint": Vector3.UP, "near": 7.0})
	FutonLib.line(pj, FutonLib.path_pts(func(q: float) -> Vector3: return fn.call(q) + Vector3.UP * 0.05, n), 0.04, 1.4, WHITE, {"delay": dl, "grow": 0.4, "flow": 6.0, "near": 7.0})
	# tüy gözü: iki renkli hilal, ileri kesik olarak fırlar
	var tip = fn.call(0.82)
	var bas = FutonLib.blade_basis(dd, Vector3.UP)
	FutonLib.blade(pj, tip, bas, 1.5, 0.55, Color(col.r, col.g, col.b, 0.95), {"delay": dl + 0.55, "thick": 0.5, "wisp": 0.6, "vel": dd * 12.0, "near": 5.0})
	FutonLib.blade(pj, tip - dd * 0.15, bas, 0.75, 0.5, Color(1.0, 0.85, 0.45, 0.95), {"delay": dl + 0.58, "thick": 0.6, "wisp": 0.3, "vel": dd * 12.0, "near": 5.0})


# ================================================================== 6. Fūton: Sasandan (Kum Bilye Yağmuru)
## Görünüş: ağızda basınç halkası ve kısa kum perdeleri yelpazesi + ağızdan saçılan çakıl → her bilye kendi kum renkli katı
## topağı ve arkasında ince kum izi; çarpınca küçük çakıl serpintisi ve toz topağı.
static func futon_sasandan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 28.0)
	var sand = Color(0.88, 0.76, 0.52)
	for k in 14:
		pj.after(0.2 + k * 0.035, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c) + c.face_dir() * 0.6
			var b = _pellet(sand)
			var dir = pj.aim_at(c, tt, from).rotated(Vector3.UP, deg_to_rad(randf_range(-14.0, 14.0))).rotated(c.face_dir().cross(Vector3.UP).normalized(), deg_to_rad(randf_range(-4.0, 6.0)))
			var pr = pj.shot(c, from, dir, 42.0, b, pj.inf(c, "futon_sasandan", 0.12, {"knock": 1.5, "kind": "light", "element": "fuuton"}), null, false, 1.0, func(p, _h):
				_pellet_hit(pj, p, sand))
			FutonLib.follow(pj, pr, 0.05, 7, Color(sand.r, sand.g, sand.b, 0.8), {"flow": 10.0}))
	var mo = pj._mouth_pos(c)
	var fd = c.face_dir()
	Dangle.gust(mo + fd * 5.0, fd * 28.0, 6.0, 0.7)   # yoldaki saç/kumaş savrulur (eski hamlenin oyun etkisi)
	_sand_breath(pj, mo, fd)
	Sfx.play("wind", c.global_position, 1.3)


static func _pellet(sand: Color) -> Node3D:
	if not _cache.has("pellet"):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.26, 0.24, 0.28), sand, Vector3(10, 30, 0), 6)
		b.add("sphere", Vector3(0.05, 0.06, 0.02), Vector3(0.13, 0.1, 0.12), sand.lightened(0.25), Vector3.ZERO, 5)
		b.add("box", Vector3(-0.06, -0.04, 0.05), Vector3(0.1, 0.08, 0.09), sand.darkened(0.25), Vector3(20, 40, 10))
		_cache["pellet"] = b.build(FutonLib.rock_mat())
	var root = Node3D.new()
	var mi = FutonLib.gi(_cache["pellet"], null)
	root.add_child(mi)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	return root


static func _pellet_hit(pj: PathJutsu, p: Vector3, sand: Color) -> void:
	FutonLib.bits(pj, p, 6, "grit", {"life": 0.5, "size": 0.1, "vmin": 2.0, "vmax": 5.0, "spread": 180.0, "radius": 0.15, "g": Vector3(0, -12.0, 0),
		"cols": [sand, sand.darkened(0.2), Color(sand.r, sand.g, sand.b, 0.0)]})
	FutonLib.bits(pj, p, 2, "puff", {"life": 0.6, "size": 0.6, "vmin": 0.5, "vmax": 1.5, "spread": 180.0, "radius": 0.2, "g": Vector3.ZERO, "grow": [0.5, 1.3],
		"cols": [Color(sand.r, sand.g, sand.b, 0.0), Color(sand.r, sand.g, sand.b, 0.7), Color(sand.r, sand.g, sand.b, 0.0)]})


static func _sand_breath(pj: PathJutsu, mo: Vector3, fd: Vector3) -> void:
	FutonLib.warp(pj, mo + fd * 0.4, 0.15, 1.1, 0.25, {"ring": true, "power": 1.6})
	for k in 5:
		var dd = fd.rotated(Vector3.UP, deg_to_rad(lerpf(-14.0, 14.0, k / 4.0)))
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return mo + dd * (0.5 + u * 10.0) + Vector3.UP * sin(u * PI) * 0.3, 14)
		FutonLib.sheet(pj, pts, 0.3, 0.6, SAND, {"delay": 0.15 + k * 0.03, "opacity": 0.35, "lines": 2.0, "grow": 0.4, "near": 5.0})
	FutonLib.bits(pj, mo + fd * 0.6, 30, "grit", {"life": 0.6, "size": 0.09, "vmin": 18.0, "vmax": 30.0, "dir": fd, "spread": 14.0, "radius": 0.15, "g": Vector3(0, -6.0, 0),
		"cols": [SAND_L, SAND, Color(SAND.r, SAND.g, SAND.b, 0.0)]})


# ================================================================== 7. Sunaarashi no Jutsu (Kum Fırtınası)
## Görünüş: hedef alanın üstünden kum yağar, yere çarpınca yassı toz yayılır ve alan çevresinde basınç halkası; 5 sn boyunca
## yönü dönerek alanı baştan başa kesen kum cepheleri (alçak, uzun kum perdeleri + üstünde ince açık çizgiler + yatay uçan çakıl),
## yerde dönen süpürme izleri, alçakta yuvarlanan toz topakları.
static func suna_arashi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var sand = Color(0.9, 0.78, 0.55)
	_sand_fall(pj, at)
	pj.every(5.0, 0.25, func(i, _k):
		var d = Vector3(cos(i * 0.4), 0, sin(i * 0.4))
		var h = randf_range(0.5, 3.0)
		Dangle.gust(at + Vector3.UP * h, d * 28.0, 10.8, 0.7)   # yoldaki saç/kumaş savrulur (eski hamlenin oyun etkisi)
		_sand_front(pj, at, d, h, i, sand)
		for e in pj.enemies_near(c, at, 9.0):
			if pj.live(e):
				if e.has_method("apply_status"):
					e.apply_status("slow", 0.6)
				if e.has_method("lose_target"):
					e.lose_target(0.5)
				if i % 2 == 0:
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "suna_arashi_no_jutsu", 0.1, {"knock": 0.5, "kind": "light", "element": "fuuton"})), Callable())
	Sfx.play("wind", at, 0.6)


static func _sand_fall(pj: PathJutsu, at: Vector3) -> void:
	FutonLib.bits(pj, at + Vector3.UP * 10.0, 70, "grit", {"life": 1.3, "size": 0.12, "vmin": 4.0, "vmax": 8.0, "dir": Vector3.DOWN, "spread": 10.0, "box": Vector3(8.0, 1.0, 8.0),
		"g": Vector3(0, -12.0, 0), "burst": 0.3, "cols": [SAND_L, SAND, Color(SAND.r, SAND.g, SAND.b, 0.0)]})
	FutonLib.bits(pj, at + Vector3.UP * 0.4, 18, "puff", {"life": 1.8, "size": 1.3, "vmin": 2.0, "vmax": 4.0, "dir": Vector3.UP, "spread": 85.0, "radius": 5.0, "damp": 2.0,
		"g": Vector3.ZERO, "grow": [0.5, 1.7], "spin": 25.0, "cols": FutonLib.dust_cols(at, 0.75)})
	FutonLib.warp(pj, at + Vector3.UP * 0.3, 1.0, 9.5, 0.6, {"ring": true, "bill": false, "basis": FutonLib.flat_basis(), "power": 1.2, "near": 6.0})


static func _sand_front(pj: PathJutsu, at: Vector3, d: Vector3, h: float, i: int, sand: Color) -> void:
	var s = FutonLib.side_of(d)
	var o = at - d * 9.0
	for k in 2:
		var lat = randf_range(-5.0, 5.0)
		var y = h * (0.4 + k * 0.5)
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return o + d * u * 18.0 + s * (lat + sin(u * 5.0 + ph) * 0.8) + Vector3.UP * (y + sin(u * 3.0 + ph) * 0.4), 20)
		FutonLib.sheet(pj, pts, 1.4, 1.0, SAND, {"delay": k * 0.06, "opacity": 0.5, "lines": 4.0, "grow": 0.5, "flow": 5.0, "near": 8.0})
	for k in 3:
		var lat2 = randf_range(-6.0, 6.0)
		var y2 = randf_range(1.0, 3.5)
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3: return o + d * u * 18.0 + s * lat2 + Vector3.UP * (y2 + sin(u * PI) * 0.4), 14)
		FutonLib.line(pj, pts2, 0.04, 0.7, SAND_L, {"delay": 0.05 + k * 0.05, "grow": 0.45, "flow": 9.0, "near": 7.0})
	FutonLib.bits(pj, o + Vector3.UP * 1.2, 10, "grit", {"life": 1.0, "size": 0.1, "vmin": 14.0, "vmax": 22.0, "dir": d, "spread": 12.0, "radius": 3.0, "g": Vector3(0, -2.0, 0),
		"burst": 0.4, "cols": [Color(sand.r, sand.g, sand.b, 1.0), sand.darkened(0.2), Color(sand.r, sand.g, sand.b, 0.0)]})
	if i % 2 == 0:
		FutonLib.scour(pj, at - d * 8.0, d, 16.0, 10.0, 1.4, 0, Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.6))
		var q = at + Vector3(randf_range(-6.0, 6.0), 0.4, randf_range(-6.0, 6.0))
		FutonLib.bits(pj, q, 3, "puff", {"life": 1.3, "size": 1.0, "vmin": 3.0, "vmax": 6.0, "dir": d, "spread": 25.0, "radius": 1.0, "g": Vector3.ZERO, "grow": [0.6, 1.5],
			"cols": FutonLib.dust_cols(q, 0.7)})


# ================================================================== 8. Kaze no Yaiba (Rüzgâr Bıçağı)
## Ref (Danzō): iki parmaktan uzanan, neredeyse görünmez, arkasını bulanıklaştıran kılıç.
## Görünüş: parmak ucunda küçük basınç noktası ve içe kıvrılan kıl çizgiler → parmaktan hedefe uzanan, yalnız arkasındaki görüntüyü
## büken uzun ince sıcak hava gibi bıçak (iki dik düzlemde basınç bükülmesi) + iki kenarında kıl inceliğinde beyaz çizgi;
## hedefte tek temiz çapraz kesik, kısa hava çatlaması.
static func kaze_no_yaiba(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	_two_finger(pj, c)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var end = (tt.global_position + Vector3.UP if tt else from + d * 14.0)
		_unseen_blade(pj, from, end)
		if tt:
			_unseen_cut(pj, tt.global_position + Vector3.UP, d)
			_melee_hit(pj, c, tt.global_position + Vector3.UP, 1.6, pj.inf(c, "kaze_no_yaiba", 1.6, {"knock": 4.0, "kind": "heavy", "element": "fuuton", "bleed": 5.0}))
		Sfx.play("wind", from, 2.0, 0.5))


static func _two_finger(pj: PathJutsu, c: Node3D) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	FutonLib.warp(pj, Vector3(0.0, 0.12, 0.0), 0.04, 0.22, 0.3, {"ring": false, "power": 2.2, "parent": ba, "near": 0.8})
	for k in 3:
		FutonLib.line(pj, FutonLib.helix_pts(Vector3(0.0, 0.12, 0.0), Vector3.UP, 0.35, 0.02, 0.3, 0.0, TAU * k / 3.0, 1.0, 10), 0.012, 0.22, WHITE,
			{"parent": ba, "grow": 0.6, "flow": 10.0, "near": 0.8})
	pj.free_after(0.45, ba)


static func _unseen_blade(pj: PathJutsu, from: Vector3, end: Vector3) -> void:
	var dl = end - from
	var L = maxf(dl.length(), 0.5)
	var dir = dl / L
	var v = FutonLib.up_of(dir)
	var s = FutonLib.side_of(dir)
	var mid = from + dl * 0.5
	for pl in 2:
		var y = v if pl == 0 else s
		FutonLib.warp(pj, mid, 0.42, 0.5, 0.42, {"ring": false, "bill": false, "basis": Basis(dir, y, dir.cross(y).normalized()), "aspect": Vector3(L, 0.32, 1.0),
			"power": 1.8, "glint": 0.0, "fade_from": 0.5, "grow": 0.25, "near": 1.0})
	for sgn in [-1.0, 1.0]:
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return from + dl * u + v * sgn * 0.07 * sin(u * PI), 12)
		FutonLib.line(pj, pts, 0.012, 0.3, Color(1.0, 1.0, 1.0, 0.7), {"grow": 0.22, "flow": 12.0, "near": 1.0})


static func _unseen_cut(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var s = FutonLib.side_of(d)
	var a = p + s * 0.9 + Vector3.UP * 0.75 - d * 0.3
	var b = p - s * 0.9 - Vector3.UP * 0.75 - d * 0.3
	FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return a.lerp(b, u), 8), 0.035, 0.26, WHITE, {"grow": 0.18, "flow": 12.0})
	FutonLib.blade(pj, p - d * 0.3, FutonLib.blade_basis((b - a).normalized().cross(d).normalized(), d), 1.7, 0.24, Color(0.92, 1.0, 0.96, 0.9), {"thick": 0.1, "wisp": 0.5})
	FutonLib.warp(pj, p, 0.2, 1.3, 0.22, {"power": 1.8, "band": 0.1, "glint": 0.0})


# ================================================================== 9. Fūton: Rasengan
## Ref: avuçta açık mavi Rasengan küresi, çevresini saran parlak beyaz rüzgâr bandı (yan yatık halka gibi döner).
## Görünüş: avuca sarmal çizgiler çekilip mavi çekirdek açılır, çevresinde yan yatık hızla dönen halka: iki beyaz çember çizgi + üç
## küçük hava hilali → atılırken arkada hız çizgileri; saplanınca hedef yönünde ileri delen sarmal kesik kolları, girdap bükülmesi,
## dışa saçılan küçük kesik hilalleri, ileri savrulan rüzgâr çizgileri, toz.
static func futon_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	pj.busy(c, 1.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		_rasen_hold(pj, ba, 1.0)
		pj.free_after(1.0, ba)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		var d = pj._jump_at(c, tt, 0.0, 16.0 if tt else 4.0)
		_rasen_rush(pj, c, d)
		pj.after(0.15, func():
			if not pj.live(c):
				return
			var at = c.global_position + Vector3.UP * 1.2 + d * 1.2
			Dangle.gust(at + d * 4.5, d * 28.0, 5.4, 0.7)   # yoldaki saç/kumaş savrulur (eski hamlenin oyun etkisi)
			_rasen_grind(pj, at, d)
			_melee_hit(pj, c, at, 2.4, pj.inf(c, "futon_rasengan", 2.0, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "element": "fuuton", "bleed": 3.0}))
			Sfx.play("wind", at, 0.9)))
	Sfx.play("wind", c.global_position, 1.6, 0.5)


static func _rasen_hold(pj: PathJutsu, ba: Node3D, dur: float) -> void:
	var holder = Node3D.new()
	FutonLib.put(pj, holder, Vector3(0.0, 0.05, 0.0), ba)
	for k in 4:
		FutonLib.line(pj, FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.9, 0.12, 0.5, -0.1, TAU * k / 4.0, 1.3, 14), 0.03, 0.4, ICE,
			{"parent": holder, "delay": k * 0.04, "grow": 0.55, "flow": 8.0, "near": 1.0})
	var core = FutonLib.gi(_sphere(0.3), _smat("rasen", RASEN_SHADER))
	FutonLib.put(pj, core, Vector3.ZERO, holder)
	core.scale = Vector3.ONE * 0.1
	var tw = core.create_tween()
	tw.tween_property(core, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# yan yatık dönen rüzgâr halkası
	var tilt = Node3D.new()
	FutonLib.put(pj, tilt, Vector3.ZERO, holder)
	tilt.rotation = Vector3(deg_to_rad(24.0), 0.0, deg_to_rad(-18.0))
	var spin = Node3D.new()
	FutonLib.put(pj, spin, Vector3.ZERO, tilt)
	spin.scale = Vector3.ONE * 0.2
	for k in 2:
		FutonLib.fixed(pj, _ring_pts(Vector3.UP * (k * 0.06 - 0.03), Vector3.UP, 0.5 + k * 0.08, 22, 0.78), 0.045 - k * 0.015, "line", WHITE,
			{"parent": spin, "flow": 12.0, "hint": Vector3.UP, "near": 1.0})
	for k in 3:
		var a = TAU * k / 3.0
		var pos = Vector3(cos(a), 0.0, sin(a)) * 0.58
		var lead = Vector3(-sin(a), 0.0, cos(a))
		FutonLib.blade(pj, pos, FutonLib.blade_basis(lead, pos.normalized()), 0.42, dur, WHITE, {"parent": spin, "thick": 0.22, "wisp": 1.2, "grow": 0.3, "near": 1.0})
	var tw2 = spin.create_tween().set_parallel()
	tw2.tween_property(spin, "scale", Vector3.ONE, 0.3).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(spin, "rotation:y", -TAU * 7.0 * dur, dur)


static func _rasen_rush(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var o = c.global_position + Vector3.UP * 1.1
	var s = FutonLib.side_of(d)
	for k in 4:
		var off = s * randf_range(-0.6, 0.6) + Vector3.UP * randf_range(-0.5, 0.5)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return o + off - d * (1.0 + (1.0 - u) * 3.5), 8)
		FutonLib.line(pj, pts, 0.03, 0.22, ICE, {"delay": k * 0.02, "grow": 0.3, "flow": 12.0, "near": 2.0})


static func _rasen_grind(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	# hedef yönünde ileri delen sarmal kesik kolları
	for k in 4:
		var pts = FutonLib.helix_pts(at, d, 0.3, 2.4, 0.0, 1.8, TAU * k / 4.0, 1.2, 22)
		FutonLib.line(pj, pts, 0.06, 0.45, WHITE if k % 2 == 0 else ICE, {"grow": 0.4, "flow": 12.0, "near": 2.5})
	FutonLib.warp(pj, at + d * 0.4, 0.3, 2.8, 0.45, {"ring": false, "swirl": 1.4, "power": 1.4})
	# dışa saçılan küçük kesik hilalleri (yaralar kanar)
	for k in 8:
		var dir = (d * 0.6 + Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()).normalized()
		var nrm = dir.cross(Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))).normalized()
		FutonLib.blade(pj, at + dir * 0.5, FutonLib.blade_basis(dir, nrm), randf_range(0.5, 0.9), 0.3, WHITE, {"vel": dir * 7.0, "jag": 0.5, "thick": 0.16, "delay": k * 0.015, "near": 2.0})
	# ileri savrulan rüzgâr çizgileri
	var s = FutonLib.side_of(d)
	for k in 6:
		var off = s * randf_range(-1.6, 1.6) + Vector3.UP * randf_range(-0.6, 0.9)
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3: return at + off * (0.4 + u) + d * (0.8 + u * 9.0), 12)
		FutonLib.line(pj, pts2, 0.05, 0.5, ICE, {"delay": 0.05 + k * 0.02, "grow": 0.4, "flow": 9.0, "near": 3.0})
	var g = FutonLib.floor_at(at)
	if at.y - g.y < 3.0:
		FutonLib.bits(pj, g + Vector3.UP * 0.3, 7, "puff", {"life": 1.1, "size": 0.9, "vmin": 2.0, "vmax": 5.0, "dir": d, "spread": 50.0, "radius": 0.8, "g": Vector3.ZERO,
			"grow": [0.5, 1.5], "cols": FutonLib.dust_cols(g, 0.75)})


# ================================================================== 10. Fūton: Sabaku Arashi (Çöl Fırtınası)
## Görünüş: 8 sn, merkez çevresinde dairesel dönen alçak geniş kum perdeleri ve yörüngede uçan çakıl, yerde ışınsal kum izi,
## başta yassı basınç halkası; kullanıcının etrafında rüzgârla teğet savrulan kum çizgisi ve toz (hızlanır).
static func kazahana_sabaku_arashi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.every(8.0, 0.2, func(_i, _k):
		if pj.live(c):
			var a = randf() * TAU
			_dune_gust(pj, c.global_position + Vector3(cos(a) * 5.0, 1.0, sin(a) * 5.0), Vector3(-sin(a), 0.1, cos(a))), Callable())
	# c_kazahana_sabaku_arashi'nin oynanışı (görseli yukarıdaki / aşağıdaki kendi efekt)
	var center = c.global_position
	_sand_veil(pj, center, 8.0)
	if c is Player:
		Buffs.add("sabaku_arashi", 8.0, {"speed": 1.3})
	pj.every(8.0, 0.5, func(i, _k):
		for e in pj.enemies_near(c, center, 14.0):
			if not pj.live(e):
				continue
			pj.st(e, "slow", 0.6)
			if i % 2 == 0 and e.has_method("lose_target"):
				e.lose_target(0.8)
			if i % 4 == 0:
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "kazahana_sabaku_arashi", 0.1, {"knock": 0.0, "element": "fuuton"})))
	Sfx.play("wind", center, 0.4)
	pj.shake(0.4)


static func _dune_gust(pj: PathJutsu, pos: Vector3, dir: Vector3) -> void:
	var dd = dir.normalized()
	var inward = Vector3(-dd.z, 0.0, dd.x)
	var pts = FutonLib.path_pts(func(u: float) -> Vector3: return pos + dd * u * 4.0 + inward * u * u * 1.2 + Vector3.UP * sin(u * PI) * 0.3, 12)
	FutonLib.line(pj, pts, 0.05, 0.55, SAND_L, {"grow": 0.45, "flow": 9.0, "near": 6.0})
	FutonLib.bits(pj, pos, 4, "puff", {"life": 1.2, "size": 0.9, "vmin": 3.0, "vmax": 6.0, "dir": dd, "spread": 30.0, "radius": 0.6, "g": Vector3.ZERO, "grow": [0.6, 1.4],
		"cols": [Color(SAND.r, SAND.g, SAND.b, 0.0), Color(SAND.r, SAND.g, SAND.b, 0.75), Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.5), Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.0)]})


static func _sand_veil(pj: PathJutsu, center: Vector3, dur: float) -> void:
	var g = FutonLib.floor_at(center)
	FutonLib.warp(pj, g + Vector3.UP * 0.4, 2.0, 14.0, 0.7, {"ring": true, "bill": false, "basis": FutonLib.flat_basis(), "power": 1.2, "near": 6.0})
	FutonLib.scour(pj, g, Vector3.FORWARD, 28.0, 28.0, dur, 1, Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.55))
	pj.every(dur, 0.5, func(i, _k):
		for k in 3:
			var R = randf_range(6.0, 13.0)
			var a0 = randf() * TAU
			var y = randf_range(0.4, 3.5)
			var pts = FutonLib.path_pts(func(u: float) -> Vector3:
				var a = a0 + u * 1.8
				return g + Vector3(cos(a) * R, y + sin(u * PI) * 0.6, sin(a) * R), 22)
			FutonLib.sheet(pj, pts, 1.3, 1.6, SAND, {"delay": k * 0.1, "opacity": 0.45, "lines": 4.0, "grow": 0.5, "flow": 4.0, "near": 8.0})
		if i % 2 == 0:
			FutonLib.bits(pj, g + Vector3.UP * 1.2, 40, "grit", {"life": 2.0, "size": 0.11, "vmin": 0.5, "vmax": 2.0, "radius": 12.0, "tang": 12.0, "radial": -1.0, "burst": 0.2,
				"g": Vector3(0, 0.2, 0), "cols": [SAND_L, SAND, Color(SAND.r, SAND.g, SAND.b, 0.0)]}), Callable())


# ================================================================== 11. Fūton: Tatsumaki Kabe (Hortum Duvarı)
## Görünüş: kullanıcının çevresinde açılan, yukarı tırmanan ince kumlu sarmal çizgiler ve yarı saydam sarmal perdelerden dönen duvar
## (çevresinde yörüngede çakıl), yerde ışınsal iz; savrulan her merminin yerinde teğet kıvrılan çizgi + küçük hilal;
## sonunda duvar dışa dağılır.
static func kazahana_tatsumaki_kabe(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	_whirl_wall(pj, c, 6.0)
	pj.every(6.0, 0.1, func(i, _k):
		if not pj.live(c):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 4.5:
				_flick(pj, p.global_position, c.global_position)
				p.queue_free()
		if i % 4 == 0:
			for e in pj.enemies_near(c, c.global_position, 4.5):
				if pj.live(e):
					e.take_hit(pj.inf(c, "kazahana_tatsumaki_kabe", 0.2, {"knock": 8.0, "kind": "light", "element": "fuuton", "bleed": 1.0})), Callable())
	if c is Player:
		Buffs.add("tatsumaki_kabe", 6.0, {"armor": 0.5, "_name": "Hortum Duvarı", "_desc": "mermiler savrulur"})
	Sfx.play("wind", c.global_position, 0.8)


static func _whirl_wall(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var anchor = Node3D.new()
	c.add_child(anchor)
	anchor.position = Vector3.ZERO
	anchor.scale = Vector3(0.15, 1.0, 0.15)
	var tw = anchor.create_tween()
	tw.tween_property(anchor, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur - 0.6)
	tw.tween_property(anchor, "scale", Vector3(1.6, 1.0, 1.6), 0.3)
	tw.tween_callback(anchor.queue_free)
	FutonLib.scour(pj, c.global_position, Vector3.FORWARD, 10.0, 10.0, dur, 1, Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.6))
	pj.every(dur - 0.3, 0.25, func(i, _k):
		if not is_instance_valid(anchor):
			return
		for k in 3:
			var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, randf_range(3.3, 3.7), randf_range(4.2, 4.7), 0.2, randf_range(6.0, 7.5), randf() * TAU, 0.9, 26)
			FutonLib.line(pj, pts, 0.06, 0.9, SAND_L if k != 0 else WHITE, {"parent": anchor, "grow": 0.5, "flow": 7.0, "near": 8.0})
		if i % 2 == 0:
			var sp = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 3.5, 4.4, 0.4, 6.5, randf() * TAU, 0.7, 22)
			FutonLib.sheet(pj, sp, 0.7, 1.1, SAND, {"parent": anchor, "opacity": 0.4, "lines": 4.0, "grow": 0.5, "flow": 5.0, "near": 8.0})
		if i % 4 == 0 and pj.live(c):
			FutonLib.bits(pj, c.global_position + Vector3.UP * 1.5, 24, "grit", {"life": 1.2, "size": 0.11, "vmin": 1.0, "vmax": 2.5, "radius": 4.0, "tang": 30.0, "radial": -3.0,
				"g": Vector3(0, 2.5, 0), "burst": 0.3, "cols": [SAND_L, SAND, Color(SAND.r, SAND.g, SAND.b, 0.0)]}), Callable())
	# sonunda duvar dışa dağılır
	pj.after(dur - 0.3, func():
		if not pj.live(c):
			return
		var o = c.global_position
		for k in 10:
			var a = TAU * k / 10.0
			var dir = Vector3(cos(a), 0.0, sin(a))
			var y = randf_range(0.8, 5.0)
			var pts2 = FutonLib.path_pts(func(u: float) -> Vector3: return o + dir * (4.0 + u * 4.0) + Vector3(-dir.z, 0.0, dir.x) * u * 1.5 + Vector3.UP * y, 10)
			FutonLib.line(pj, pts2, 0.05, 0.45, SAND_L, {"grow": 0.5, "flow": 8.0, "near": 7.0}))


static func _flick(pj: PathJutsu, p: Vector3, center: Vector3) -> void:
	var r = p - center
	r.y = 0.0
	var tng = Vector3(-r.z, 0.0, r.x).normalized() if r.length() > 0.01 else Vector3.RIGHT
	var out = r.normalized() if r.length() > 0.01 else Vector3.FORWARD
	FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + tng * u * 2.2 + out * u * u * 1.5 + Vector3.UP * u * 0.6, 8), 0.04, 0.3, WHITE, {"grow": 0.4, "flow": 10.0})
	FutonLib.blade(pj, p, FutonLib.blade_basis(tng, Vector3.UP), 0.8, 0.25, SAND_L, {"vel": tng * 6.0, "thick": 0.2})


# ================================================================== 12. Fūton: Ōkakeami (Büyük Rüzgâr Ağı)
## Görünüş: hedefin üstünde, 12 m yükseklikte içe kıvrılarak toplanan rüzgâr çizgileri → oradan geniş ağ (12 ışın + 3 halka,
## ince akan çizgilerden) açılarak çöker ve yere bastırır; yere değdiğinde yassı basınç halkası, dışa kaçan toz halkası, yerde ışınsal iz;
## yakalananların üstüne bastıran kısa dikey çizgiler; ağ 3 sn yerde titreşip söner.
static func futon_okakeami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 30.0)
	var at = tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0
	_sky_gather(pj, pj.gp(at) + Vector3.UP * 12.0, 7.0)
	pj.after(0.35, func():
		_great_net(pj, c, at, 8.0, 3.0, "futon_okakeami")
		_net_slam(pj, pj.gp(at), 9.0)
		pj.shake(0.6))
	Sfx.play("wind", at, 0.7)


## Ana ağaçtaki _wind_net(..., from_sky = true) oynanışı satır satır; görseli bu dosyada
static func _great_net(pj: PathJutsu, c: Node3D, at: Vector3, r: float, hold: float, id: String) -> void:
	var g = pj.gp(at)
	_net_drop(pj, g, r, hold)
	pj.after(0.3, func():
		for e in pj.enemies_near(c, g, r):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("bind", hold)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, id, 0.6, {"knock": 0.0, "kind": "light", "element": "fuuton"}))
				_pin_lines(pj, e.global_position)
		pj.every(hold, 0.4, func(_i, _k):
			for e in pj.enemies_near(c, g, r):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, id, 0.15, {"knock": 0.0, "kind": "light", "element": "fuuton"})), Callable()))


static func _sky_gather(pj: PathJutsu, top: Vector3, r: float) -> void:
	for k in 8:
		var pts = FutonLib.helix_pts(top, Vector3.UP, r, 0.4, 0.0, -0.6, TAU * k / 8.0, 0.9, 18)
		FutonLib.line(pj, pts, 0.06, 0.45, MINT, {"delay": k * 0.02, "grow": 0.6, "flow": 8.0, "near": 6.0})
	FutonLib.warp(pj, top, 0.5, 2.5, 0.4, {"ring": false, "swirl": 1.6, "power": 1.2, "near": 6.0})


static func _net_drop(pj: PathJutsu, g: Vector3, r: float, hold: float) -> void:
	var net = Node3D.new()
	FutonLib.put(pj, net, g + Vector3.UP * 12.0)
	net.scale = Vector3(0.25, 0.25, 0.25)
	var parts: Array = []
	var spokes = 12
	var sag = func(u: float) -> float: return 0.9 * (1.0 - u * u) - 0.4 * u
	for k in spokes:
		var a = TAU * k / spokes
		var dir = Vector3(cos(a), 0.0, sin(a))
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return dir * r * u + Vector3.UP * sag.call(u), 10)
		parts.append(FutonLib.fixed(pj, pts, 0.07, "line", MINT, {"parent": net, "flow": 5.0, "near": 6.0}))
	for ring in 3:
		var rr = r * (ring + 1) / 3.0
		var u0 = float(ring + 1) / 3.0
		var pts2 = PackedVector3Array()
		for k in spokes + 1:
			var a0 = TAU * k / spokes
			var a1 = TAU * (k + 0.5) / spokes
			pts2.append(Vector3(cos(a0), 0.0, sin(a0)) * rr + Vector3.UP * sag.call(u0))
			if k < spokes:
				pts2.append(Vector3(cos(a1), 0.0, sin(a1)) * rr * 0.96 + Vector3.UP * (sag.call(u0) - 0.12))
		parts.append(FutonLib.fixed(pj, pts2, 0.05, "line", WHITE if ring == 2 else MINT, {"parent": net, "flow": 4.0, "near": 6.0}))
	var tw = net.create_tween()
	tw.tween_property(net, "global_position", g + Vector3.UP * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(net, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# yerde titreşir (bastırma)
	for _k in int(hold / 0.3):
		tw.tween_property(net, "scale", Vector3(1.0, 0.75, 1.0), 0.15)
		tw.tween_property(net, "scale", Vector3.ONE, 0.15)
	tw.tween_callback(func():
		for mi in parts:
			if is_instance_valid(mi):
				mi.create_tween().tween_method(FutonLib.pf(mi, "fade"), 1.0, 0.0, 0.4))
	tw.tween_interval(0.45)
	tw.tween_callback(net.queue_free)


static func _net_slam(pj: PathJutsu, g: Vector3, r: float) -> void:
	pj.after(0.3, func():
		FutonLib.warp(pj, g + Vector3.UP * 0.3, 1.0, r, 0.45, {"ring": true, "bill": false, "basis": FutonLib.flat_basis(), "power": 1.5, "near": 6.0})
		FutonLib.scour(pj, g, Vector3.FORWARD, r * 2.0, r * 2.0, 3.4, 1)
		FutonLib.bits(pj, g + Vector3.UP * 0.3, 22, "puff", {"life": 1.2, "size": 1.0, "vmin": 6.0, "vmax": 10.0, "dir": Vector3.UP, "spread": 88.0, "radius": r * 0.5,
			"radial": 6.0, "damp": 3.0, "g": Vector3.ZERO, "grow": [0.5, 1.5], "cols": FutonLib.dust_cols(g, 0.75)}))


static func _pin_lines(pj: PathJutsu, p: Vector3) -> void:
	for k in 3:
		var off = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + off + Vector3.UP * lerpf(3.2, 0.3, u), 6), 0.04, 0.35, WHITE, {"delay": k * 0.05, "grow": 0.35, "flow": 12.0})


# ================================================================== 13. Fūton: Taifū Ikka (Tayfun)
## Görünüş: önünde doğan, yukarı doğru genişleyen dev hortum (yürüyen düğüme bağlı dönen sarmal çizgiler + geniş yarı saydam
## sarmal perdeler), tabanında dönen toz eteği, gövdesinde yörüngede yükselen yaprak / çakıl, geçtiği yerde süpürülmüş iz;
## yakalanan ninjanın çevresinde sarılan çizgiler.
static func futon_taifu_ikka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var d = pj.fwd(c, t)
	var start = pj.gp(c.global_position + d * 4.0)
	var caught = {}
	var eye = Node3D.new()
	FutonLib.put(pj, eye, start)
	FutonLib.kill(pj, 4.2, eye)
	pj.every(3.2, 1.0 / 20.0, func(i, k):
		var p = pj.gp(start + d * k * 30.0)
		if is_instance_valid(eye):
			eye.global_position = p
			if i % 3 == 0:
				_typhoon_tick(pj, eye, p, d, k, i)
		for e in pj.enemies_near(c, p, 5.5):
			if pj.live(e) and not caught.has(e):
				caught[e] = true
				pj._wind_lift(c, e, 9.0, 1.4)
				_flung(pj, e.global_position)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, "futon_taifu_ikka", 1.3, {"knock": 4.0, "launch": 10.0, "kind": "heavy", "element": "fuuton"})), Callable())
	pj.shake(0.9)
	Sfx.play("wind", start, 0.5)


static func _typhoon_tick(pj: PathJutsu, eye: Node3D, p: Vector3, d: Vector3, k: float, i: int) -> void:
	var top = 5.0 + k * 2.0
	for j in 2:
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 1.0, top, 0.1, 18.0, randf() * TAU, 2.2, 36)
		FutonLib.line(pj, pts, 0.1, 0.7, WHITE if j == 0 else STORM, {"parent": eye, "grow": 0.55, "flow": 8.0, "near": 8.0})
	if i % 6 == 0:
		var sp = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 1.4, top * 0.9, 0.5, 16.0, randf() * TAU, 1.4, 30)
		FutonLib.sheet(pj, sp, 1.3, 0.9, STORM, {"parent": eye, "opacity": 0.4, "lines": 5.0, "grow": 0.5, "flow": 5.0, "near": 8.0})
		FutonLib.bits(pj, p + Vector3.UP * 0.4, 6, "puff", {"life": 1.0, "size": 1.2, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 70.0, "radius": 2.2, "tang": 22.0,
			"g": Vector3.ZERO, "grow": [0.6, 1.6], "spin": 60.0, "cols": FutonLib.dust_cols(p, 0.75)})
		var g = FutonLib.floor_at(p)
		if FutonLib.has_leaves(g):
			FutonLib.bits(pj, p + Vector3.UP * 1.0, 10, "leaf", {"life": 1.4, "size": 0.25, "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP, "spread": 30.0, "radius": 2.0, "tang": 28.0,
				"radial": 2.0, "g": Vector3(0, 7.0, 0), "cols": FutonLib.leaf_cols(g)})
		else:
			var dc = FutonLib.ground_col(g).darkened(0.25)
			FutonLib.bits(pj, p + Vector3.UP * 1.0, 10, "grit", {"life": 1.4, "size": 0.14, "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP, "spread": 30.0, "radius": 2.0, "tang": 28.0,
				"radial": 2.0, "g": Vector3(0, 7.0, 0), "cols": [dc, dc, Color(dc.r, dc.g, dc.b, 0.0)]})
	if i % 12 == 0:
		FutonLib.scour(pj, p - d * 2.0, d, 7.0, 5.0, 2.2, 0)


static func _flung(pj: PathJutsu, p: Vector3) -> void:
	for k in 2:
		FutonLib.line(pj, FutonLib.helix_pts(p, Vector3.UP, 1.3, 0.6, 0.2, 4.5, TAU * k / 2.0, 1.6, 22), 0.05, 0.7, WHITE, {"grow": 0.5, "flow": 10.0})


# ================================================================== 14. Fūton: Ryū no Ōshigoto (Rüzgâr Ejderi)
## Görünüş: kullanıcının çevresinde yukarı sarılan çizgilerle ejder doğar → mercek gibi bükülen hava başlı (tırtıklı hilal çeneler,
## geriye kıvrık boynuz ve bıyık çizgileri) ejder; gövdesi başı izleyen uzun yarı saydam perde + çevresinde dönerek örülen üç ince
## çizgi + sırt yelesi; çarptığı yerde aşağıdan geniş yukarı daralan kısa girdap, yassı dönen basınç halkası, toz.
static func futon_ryu_no_oshigoto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 34.0)
	var from = c.global_position + Vector3.UP * 2.0 + c.face_dir()
	_dragon_rise(pj, c)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var head = Node3D.new()
		var pr = pj.shot(c, from, (pj.aim_at(c, tt, from) + Vector3.UP * 0.3).normalized(), 16.0, head, pj.inf(c, "futon_ryu_no_oshigoto", 1.6, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "fuuton"}), tt, false, 3.0, func(p, _h):
			_dragon_burst(pj, p)
			pj.shake(0.6))
		pr.homing_turn = 2.0
		pr.radius = 1.3
		_dragon_head(pj, head)
		_dragon_body(pj, pr))
	Sfx.play("wind", c.global_position, 0.9)


static func _dragon_rise(pj: PathJutsu, c: Node3D) -> void:
	var o = c.global_position
	for k in 3:
		FutonLib.line(pj, FutonLib.helix_pts(o, Vector3.UP, 1.2, 0.6, 0.1, 2.8, TAU * k / 3.0, 1.3, 18), 0.05, 0.4, MINT, {"delay": k * 0.04, "grow": 0.55, "flow": 9.0, "near": 2.5})


static func _dragon_head(pj: PathJutsu, head: Node3D) -> void:
	FutonLib.orb(pj, Vector3(0.0, 0.0, 0.2), 0.75, MINT, {"parent": head, "tear": 0.7, "near": 2.0})
	# çeneler: tırtıklı hilaller (yan düzlemde, ön kenar ileri)
	FutonLib.blade(pj, Vector3(0.0, 0.25, -0.75), FutonLib.blade_basis(Vector3(0.0, 0.15, -1.0), Vector3.RIGHT), 2.0, 3.4, MINT, {"parent": head, "jag": 0.9, "thick": 0.28, "wisp": 1.4, "near": 2.0})
	FutonLib.blade(pj, Vector3(0.0, -0.35, -0.6), FutonLib.blade_basis(Vector3(0.0, -0.35, -1.0), Vector3.RIGHT), 1.5, 3.4, WHITE, {"parent": head, "jag": 0.9, "thick": 0.24, "wisp": 1.0, "near": 2.0})
	for sgn in [-1.0, 1.0]:
		var horn = FutonLib.path_pts(func(u: float) -> Vector3: return Vector3(sgn * (0.35 + u * 0.35), 0.4 + u * 0.7 - u * u * 0.2, 0.1 + u * 1.7), 10)
		FutonLib.fixed(pj, horn, 0.06, "line", WHITE, {"parent": head, "flow": 6.0, "near": 2.0})
		var whisk = FutonLib.path_pts(func(u: float) -> Vector3: return Vector3(sgn * (0.3 + u * 1.2), -0.15 - sin(u * PI) * 0.3, -1.1 + u * 2.2), 12)
		FutonLib.fixed(pj, whisk, 0.035, "line", MINT, {"parent": head, "flow": 9.0, "near": 2.0})


static func _dragon_body(pj: PathJutsu, pr: Node3D) -> void:
	FutonLib.follow(pj, pr, 0.85, 44, MINT, {"kind": "sheet", "opacity": 0.5, "lines": 4.0, "flow": 4.0, "near": 6.0})
	for k in 3:
		var off = Vector3(0.85, 0.0, 0.0).rotated(Vector3.FORWARD, TAU * k / 3.0)
		FutonLib.follow(pj, pr, 0.05, 40, WHITE if k == 0 else ICE, {"offset": off, "spin": 7.0, "flow": 8.0, "near": 4.0})
	FutonLib.follow(pj, pr, 0.07, 34, WHITE, {"offset": Vector3(0.0, 0.9, 0.6), "flow": 10.0, "near": 4.0})


static func _dragon_burst(pj: PathJutsu, p: Vector3) -> void:
	var g = FutonLib.floor_at(p)
	var base = Vector3(p.x, minf(p.y, g.y + 0.2), p.z) if p.y - g.y < 4.0 else p - Vector3.UP * 1.0
	for k in 6:
		FutonLib.line(pj, FutonLib.helix_pts(base, Vector3.UP, 3.5, 0.8, 0.0, 7.0, TAU * k / 6.0, 1.4, 26), 0.08, 0.8, WHITE if k % 2 == 0 else MINT,
			{"delay": k * 0.03, "grow": 0.5, "flow": 9.0, "near": 5.0})
	FutonLib.warp(pj, base + Vector3.UP * 0.3, 1.0, 7.0, 0.55, {"ring": true, "bill": false, "basis": FutonLib.flat_basis(), "swirl": 1.2, "power": 1.4, "near": 5.0})
	FutonLib.bits(pj, base + Vector3.UP * 0.3, 14, "puff", {"life": 1.2, "size": 1.0, "vmin": 2.0, "vmax": 5.0, "dir": Vector3.UP, "spread": 80.0, "radius": 2.5, "tang": 18.0,
		"g": Vector3.ZERO, "grow": [0.5, 1.5], "cols": FutonLib.dust_cols(base, 0.75)})


# ================================================================== 15. Fūton: Suiran Reppū (Yeşim Fırtınası)
## Görünüş: kullanıcının dört yanında sırayla, ince, çok kıvrımlı yeşim renkli rüzgâr sütunları yükselir (sarmal çizgiler + ince
## yarı saydam perde), içinde yörüngede tırmanan yapraklar; sütun tepesinden dışa fırlayan küçük yeşim kesik hilalleri,
## yerde yeşil tonlu ışınsal iz.
static func futon_suiran_reppu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position)
	for k in 4:
		pj.after(k * 0.2, func():
			var a = TAU * k / 4.0
			var q = at + Vector3(cos(a), 0, sin(a)) * 4.0
			_jade_whirl(pj, q, k)
			pj.hit(c, q + Vector3.UP, 3.0, pj.inf(c, "futon_suiran_reppu", 0.4, {"knock": 6.0, "launch": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0})))
	Sfx.play("wind", at, 0.8)


static func _jade_whirl(pj: PathJutsu, q: Vector3, k: int) -> void:
	for j in 3:
		var pts = FutonLib.helix_pts(q, Vector3.UP, 0.5, 1.6, 0.0, 8.0, TAU * j / 3.0 + k, 2.6, 40)
		FutonLib.line(pj, pts, 0.07, 1.2, JADE if j != 0 else MINT, {"delay": j * 0.04, "grow": 0.5, "flow": 8.0, "near": 6.0})
	FutonLib.sheet(pj, FutonLib.helix_pts(q, Vector3.UP, 0.7, 1.3, 0.3, 7.0, k * 1.7, 1.6, 28), 0.5, 1.1, JADE, {"opacity": 0.4, "lines": 4.0, "grow": 0.5, "flow": 5.0, "near": 6.0})
	FutonLib.bits(pj, q + Vector3.UP, 22, "leaf", {"life": 1.4, "size": 0.3, "vmin": 4.0, "vmax": 8.0, "dir": Vector3.UP, "spread": 40.0, "radius": 0.6, "tang": 14.0, "spin": 600.0,
		"cols": [Color(0.45, 0.75, 0.3, 1), Color(0.4, 0.65, 0.25, 1), Color(0.35, 0.55, 0.2, 0)]})
	FutonLib.scour(pj, q, Vector3.FORWARD, 4.0, 4.0, 1.6, 1, Color(0.4, 0.62, 0.42, 0.55))
	var top = q + Vector3.UP * 7.5
	for j in 5:
		var a = TAU * j / 5.0 + k
		var dir = Vector3(cos(a), randf_range(-0.3, 0.2), sin(a)).normalized()
		FutonLib.blade(pj, top, FutonLib.blade_basis(dir, Vector3.UP), 1.0, 0.4, JADE, {"delay": 0.5 + j * 0.03, "vel": dir * 9.0, "jag": 0.4, "thick": 0.2, "near": 5.0})
