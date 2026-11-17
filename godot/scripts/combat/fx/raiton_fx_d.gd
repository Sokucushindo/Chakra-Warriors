class_name RaitonFXD
extends RefCounted
## Raiton D grubu: 15 tekniğin görseli ve taşınmış oynanışı. Malzeme / yapı taşı RaitonLib'den; her tekniğin şekli,
## hareketi ve sahnelenmesi kendine özgü (A / B / C gruplarının kompozisyonları kullanılmaz). Oynanış (hasar çağrıları,
## durumlar, süreler, menzil, mermi davranışı) ana ağaçtaki PathJutsu / ClanJutsu / Jutsu gövdelerinden satır satır taşındı.
## Raikage taijutsuları (Erubō, Jigokuzuki, Raigā Bomu, Sutorēto, Doroppu Kikku) ışık şovu değil: hız çizgisi, darbe
## çizgisi, toz, çatlak, kaya; şimşek yalnız ince zırh çatırtısı.

const L = preload("res://scripts/combat/fx/lib/raiton_lib.gd")   # sınıf adı sabit ifade sayılmıyor
const RAI := Color(0.65, 0.85, 1.0)
const RAIKAGE := Color(0.45, 0.7, 1.0)
const KURO_BOLT := Color(0.7, 0.85, 1.0)
const WHITE := Color(0.93, 0.97, 1.0)
const DEEP := Color(0.2, 0.45, 0.95)
const EDGE := Color(0.06, 0.17, 0.5)
const EARTH := Color(0.55, 0.42, 0.3)
const DUST := Color(0.62, 0.56, 0.47)

static var _shc := {}
static var _mc := {}


# ═════════════════════════════════════════ kendi gölgelendiricilerim ═════════════════════════════════════════

const MODE_BAND := "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;"
const MODE_SOLID := "render_mode unshaded, cull_back, shadows_disabled;"

## Kalın cel şimşek şeridi (sahte karanlık / diş / kırbaç): düz beyaz öz, açık mavi bant, koyu mavi kenar çizgisi;
## karışık (gündüz de seçilir), parça parça kırpışır
const SH_FANG := """
uniform vec4 mid_col : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform vec4 edge_col : source_color = vec4(0.06, 0.17, 0.5, 1.0);
uniform float core_w = 0.45;
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	if (e > 0.97) { discard; }
	vec3 col = mix(vec3(1.0), mid_col.rgb, step(core_w, e));
	col = mix(col, edge_col.rgb, step(0.8, e));
	float fl = 0.86 + 0.14 * step(0.5, rh2(vec2(floor(UV.x * 2.0), floor(TIME * 24.0))));
	ALBEDO = col * fl * 1.12;
	ALPHA = COLOR.a;
}
"""

## Kakashi'nin tazısı: kristal kırığı gibi dişli gövde; içte beyaz, kenara doğru buz mavisi, en dışta koyu mavi bant;
## gövde boyunca geriye akan beyaz akım çizgileri (tazı elden akan chakradan yapılmış)
const SH_SHARD := """
uniform vec4 inner : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 rim_col : source_color = vec4(0.28, 0.58, 1.0, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float flow = rn3(vec3(lp.x * 3.2, lp.y * 3.2, lp.z * 1.2 + TIME * 7.0));
	float streak = 1.0 - smoothstep(0.0, 0.06, abs(flow - 0.5));
	vec3 col = inner.rgb;
	col = mix(col, glow.rgb, step(0.5, fr + streak * 0.2));
	col = mix(col, rim_col.rgb, step(0.8, fr));
	col = mix(col, vec3(1.0), streak * step(fr, 0.62));
	ALBEDO = col;
}
"""

## Kara panter (Raiton Kuropansā, kaynak görsel): kömür siyahı gövdede karalama gibi ince gri-mor fırça çizgileri
## (birkaç karede bir kayar), kenarda beyaz kontur; köşe rengi siyah olmayan bölgeler (mor ağız, beyaz diş, sarı göz)
const SH_INK := """
uniform vec4 rim_col : source_color = vec4(0.92, 0.93, 1.0, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float dark = 1.0 - step(0.3, dot(COLOR.rgb, vec3(0.333)));
	float st = floor(TIME * 10.0);
	float hatch = rn2(vec2(lp.x * 26.0 + lp.y * 9.0 + st * 0.13, lp.z * 5.0 - lp.y * 7.0));
	float stroke = (1.0 - smoothstep(0.0, 0.05, abs(hatch - 0.5))) * dark;
	float rim = smoothstep(0.62, 0.7, fr) * dark;
	vec3 col = COLOR.rgb;
	col = mix(col, vec3(0.34, 0.31, 0.42), stroke * 0.8);
	col = mix(col, rim_col.rgb * 1.2, rim);
	ALBEDO = col;
}
"""

## Fırtına bulutu (Raiton Raiga): iki tonlu koyu arduvaz cel bulut (üstü açık), flash ile içten mavi-beyaz aydınlanır
const SH_CLOUD := """
uniform float flash = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	float lit = step(0.25, normalize(wn).y + rn3(wp * 0.6) * 0.3);
	vec3 col = mix(vec3(0.12, 0.13, 0.19), vec3(0.26, 0.28, 0.37), lit);
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	col = mix(col, vec3(0.6, 0.8, 1.0), clamp(flash, 0.0, 1.0) * (0.35 + 0.65 * step(0.5, fr)));
	ALBEDO = col;
}
"""


static func _shader(key: String, mode: String, body: String) -> Shader:
	if not _shc.has(key):
		var s = Shader.new()
		s.code = "shader_type spatial;\n" + mode + "\n" + L.SH_NOISE + "\n" + body
		_shc[key] = s
	return _shc[key]


static func _smat(key: String, mode: String, body: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(key, mode, body)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Kalın cel şimşek şeridi malzemesi (paylaşılan)
static func _fang(mid: Color, edge := EDGE, core := 0.45) -> ShaderMaterial:
	var key = "fang_%s_%s_%.2f" % [mid.to_html(), edge.to_html(), core]
	if not _mc.has(key):
		_mc[key] = _smat("fang", MODE_BAND, SH_FANG, {"mid_col": mid, "edge_col": edge, "core_w": core})
	return _mc[key]


## Düz renk, köşe saydamlığıyla söner (darbe çizgisi, çatlak, hız çizgisi)
static func _ink(col: Color) -> StandardMaterial3D:
	var key = "ink_" + col.to_html()
	if not _mc.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mc[key] = m
	return _mc[key]


## Köşe renkli ışıksız malzeme (göz, ağız, kılıç)
static func _vc() -> StandardMaterial3D:
	if not _mc.has("vc"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_mc["vc"] = m
	return _mc["vc"]


static func _near_ground(p: Vector3, h := 2.5) -> bool:
	return p.y - Game.jutsu_floor(p.x, p.z) < h


## a → b arası n eşit nokta (inceltmeli şeritler için)
static func _seg(a: Vector3, b: Vector3, n := 5) -> Array:
	var out = []
	for i in n:
		out.append(a.lerp(b, float(i) / float(n - 1)))
	return out


## Diken: base'den dir yönünde ln boyunda koni (gövde dikenleri, bacak, pençe, diş)
static func _spike(b: MB, base: Vector3, dir: Vector3, ln: float, w: float, col := Color.WHITE) -> void:
	var y = dir.normalized()
	var x = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z = x.cross(y).normalized()
	b.add_xf("cone", Transform3D(Basis(x * w, y * ln, z * w), base + y * ln * 0.5), col, 5)


## a → b arası kalın silindir (panter bacağı)
static func _rod(b: MB, a: Vector3, e: Vector3, w: float, col: Color) -> void:
	var y = e - a
	var ln = y.length()
	y = y / maxf(ln, 0.001)
	var x = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z = x.cross(y).normalized()
	b.add_xf("cyl", Transform3D(Basis(x * w, y * ln, z * w), (a + e) * 0.5), col, 8)


## Yer çatlağı: merkezden dışa dişli koyu çizgiler (+ yan dallar), 0.1 sn'de açılır, sonunda söner; glow verilirse ilk
## anda çatlaklar parlak yanar. zone_dur > 0 ise eski oynanış: yarık zemin bölgesi (üstünden geçen yavaşlar)
static func _cracks(g: Vector3, size: float, vis_dur: float, zone_dur := 0.0, glow := Color(0, 0, 0, 0)) -> void:
	if zone_dur > 0.0 and size >= 1.5:
		GroundFX.add(g, "cracked", size * 0.6, clampf(zone_dur, 3.0, 5.0))
	var lines = []
	var n = 6 + int(size * 0.6)
	for k in n:
		var a = TAU * k / n + randf_range(-0.3, 0.3)
		var e = g + Vector3(cos(a), 0, sin(a)) * size * 0.5 * randf_range(0.55, 1.0)
		var main = L.ground_path(g, e, 0.22, 3, 0.05)
		lines.append({"p": main, "w": 0.04 + size * 0.006, "a": 1.0})
		if randf() < 0.6 and main.size() > 4:
			var s: Vector3 = main[int(main.size() * 0.5)]
			var e2 = s + (Vector3(cos(a), 0, sin(a)) + L.hdir() * 0.8).normalized() * size * 0.18
			lines.append({"p": L.ground_path(s, e2, 0.25, 2, 0.05), "w": 0.025 + size * 0.004, "a": 0.9})
	var m = _ink(Color(0.08, 0.07, 0.07, 0.9))
	var gm = L.arc_mat(glow) if glow.a > 0.0 else null
	L.host(func(im, _n, _dt, age) -> bool:
		if age > vis_dur:
			return false
		var grow = clampf(age / 0.1, 0.0, 1.0)
		var polys = []
		for ln in lines:
			var pts: Array = ln["p"]
			var cnt = maxi(2, int(ceil(pts.size() * grow)))
			polys.append({"p": pts.slice(0, cnt), "w": ln["w"], "a": ln["a"]})
		L.draw(im, m, polys, clampf((vis_dur - age) / 0.8, 0.0, 1.0), L.cam_pos(), true)
		if gm != null and age < 0.5:
			L.draw(im, gm, polys, 1.0 - age / 0.5, L.cam_pos(), true)
		return true)


## Anime darbe çizgileri: at'tan normale dik düzlemde dışa fırlayan düz, sivri uçlu çizgiler
static func _strokes(at: Vector3, nrm: Vector3, n: int, r0: float, r1: float, life: float, col: Color, w := 0.035) -> void:
	var m = _ink(col)
	var nn = nrm.normalized()
	var u = nn.cross(Vector3.UP)
	if u.length_squared() < 0.001:
		u = nn.cross(Vector3.RIGHT)
	u = u.normalized()
	var v = nn.cross(u).normalized()
	var dirs = []
	for k in n:
		var a = TAU * k / n + randf_range(-0.2, 0.2)
		dirs.append({"d": u * cos(a) + v * sin(a), "l": randf_range(0.5, 1.0)})
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var f = age / life
		var r = lerpf(r0, r1, 1.0 - pow(1.0 - f, 3.0))
		var polys = []
		for s in dirs:
			var dv: Vector3 = s["d"]
			var ln = (r1 - r0) * 0.45 * float(s["l"]) * (1.0 - f * 0.7)
			polys.append({"p": _seg(at + dv * r, at + dv * (r + ln)), "w": w, "a": 1.0, "k": 3})
		L.draw(im, m, polys, 1.0 - f * f, L.cam_pos())
		return true)


## Raikage'nin şimşek zırhı (eski "_rai_cloak" oynanışsızdı): gövdede ince mavi çatırtı + göğüste küçük çakma
static func _rai_armor(c: Node3D, dur: float) -> void:
	if not L.alive(c):
		return
	L.body_arcs(c, dur, RAIKAGE, 3, 0.03)
	L.flash(c.global_position + Vector3.UP * 1.1, 0.8, RAIKAGE, 0.08, 10.0)


## Kol çatırtısı (eski "_lightning_limb"): sağ elde / önkolda dolanan kısa arklar
static func _limb_arcs(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		L.crackle(L.hand_fn(pj, c), 0.45, dur, RAIKAGE, 3, 0.03)
		return
	L.crackle(L.follow_fn(ba), 0.45, dur, RAIKAGE, 3, 0.03, 0.06, ba)
	pj.free_after(dur, ba)


# ═════════════════════════════════════════ Hatake Raijū Tsuiga ═════════════════════════════════════════

## Kaynak (Kakashi, anime + manga): elden fışkıran Raikiri akımı, alçakta saldıran dev bir tazıya döner — gövdesi düzgün
## değil, her yanından dışa ve geriye fırlayan kristal dikenlerle dişli bir siluet; kırmızı gözler, açık çenede kırmızı
## gırtlak. Tazı ATANIN ELİNE BAĞLI kalır: arka gövdesi kalın bir şimşek akımı olarak ele kadar uzanır. Koşu dörtnala
## değil, iki ön bacak birlikte uzanıp iki arka bacak birlikte iten sıçrayış; çene sürekli açılıp kapanır.
static func _hatake_hound() -> Node3D:
	var root_n = Node3D.new()
	var rig = Node3D.new()
	root_n.add_child(rig)
	var rig_z = 1.45   # ağız mermi noktasında: gövde arkaya, elden tazıya doğru uzanır (isabet anında baş hedefte)
	rig.position.z = rig_z
	var tail = Node3D.new()   # elden gelen akımın bağlandığı kuyruk noktası
	tail.position = Vector3(0, 0.8, 1.0)
	rig.add_child(tail)
	root_n.set_meta("tail", tail)
	var body_m = _smat("shard", MODE_SOLID, SH_SHARD)
	var ol = L.line_mat(Color(0.05, 0.14, 0.42), 0.028)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.78, 0.15), Vector3(0.62, 0.55, 1.45), Color.WHITE, Vector3(-6, 0, 0), 7)
	b.add("sphere", Vector3(0, 0.88, -0.5), Vector3(0.82, 0.78, 0.78), Color.WHITE, Vector3.ZERO, 7)
	b.add("sphere", Vector3(0, 0.82, -1.0), Vector3(0.52, 0.48, 0.55), Color.WHITE, Vector3(10, 0, 0), 7)
	b.add("cone", Vector3(0, 0.9, -1.38), Vector3(0.38, 0.6, 0.2), Color.WHITE, Vector3(-72, 0, 0), 6)   # üst çene, açık
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.17 * sx, 1.08, -0.92), Vector3(0.14, 0.42, 0.1), Color.WHITE, Vector3(55, 0, -20 * sx), 5)
	# dişli siluet: gövdenin her yanından dışa + geriye yatık kristal dikenler (sabit tohum: her tazı aynı biçim)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7331
	for k in 28:
		var z = rng.randf_range(-0.95, 0.95)
		var a = rng.randf_range(-PI * 0.92, PI * 0.92)
		var o = Vector3(sin(a) * 0.3, 0.82 + cos(a) * 0.28, z)
		var dir = Vector3(sin(a), cos(a) * 0.9 + 0.25, 0.9 + rng.randf_range(0.0, 0.7))
		_spike(b, o, dir, rng.randf_range(0.35, 0.85) * (1.2 - absf(z) * 0.3), rng.randf_range(0.07, 0.13))
	var body = L.mi_of(b.build(), body_m)
	body.material_overlay = ol
	rig.add_child(body)
	# alt çene (eklemli)
	var jaw = Node3D.new()
	jaw.position = Vector3(0, 0.74, -1.12)
	rig.add_child(jaw)
	var jb = MB.new()
	jb.add("cone", Vector3(0, 0, -0.26), Vector3(0.3, 0.52, 0.14), Color.WHITE, Vector3(-95, 0, 0), 6)
	for q in 3:
		for sx in [-1.0, 1.0]:
			_spike(jb, Vector3(0.08 * sx * (1.0 - q * 0.25), 0.03, -0.18 - q * 0.11), Vector3.UP, 0.12, 0.035)
	var jm = L.mi_of(jb.build(), body_m)
	jm.material_overlay = ol
	jaw.add_child(jm)
	# kırmızı gözler, koyu kırmızı gırtlak, üst dişler
	var vb = MB.new()
	vb.add("box", Vector3(0, 0.8, -1.3), Vector3(0.24, 0.16, 0.42), Color(0.6, 0.05, 0.1), Vector3(-10, 0, 0))
	for sx in [-1.0, 1.0]:
		vb.add("sphere", Vector3(0.15 * sx, 0.95, -1.18), Vector3(0.13, 0.08, 0.07), Color(0.95, 0.12, 0.15), Vector3(0, 0, -18 * sx), 8)
		for q in 3:
			_spike(vb, Vector3(0.1 * sx * (1.0 - q * 0.3), 0.88, -1.3 - q * 0.11), Vector3.DOWN, 0.14, 0.04, Color(1, 1, 1))
	rig.add_child(L.mi_of(vb.build(), _vc()))
	# bacaklar: ön çift öne uzanır, arka çift geriye iter (sivri kristal bacak + pençe dikenleri)
	var legs = []
	for q in [[0.26, 0.82, -0.55, -1.0], [-0.26, 0.82, -0.55, -1.0], [0.24, 0.78, 0.6, 1.0], [-0.24, 0.78, 0.6, 1.0]]:
		var piv = Node3D.new()
		piv.position = Vector3(q[0], q[1], q[2])
		rig.add_child(piv)
		var fz = float(q[3])
		var paw = Vector3(0.03 * signf(q[0]), -0.78, 0.5 * fz)
		var lb = MB.new()
		_spike(lb, paw.normalized() * 0.1, paw, paw.length() * 1.05, 0.17)
		for cl in 3:
			_spike(lb, paw, Vector3((cl - 1) * 0.4, -0.25, fz), 0.22, 0.05)
		var lm = L.mi_of(lb.build(), body_m)
		lm.material_overlay = ol
		piv.add_child(lm)
		legs.append([piv, fz])
	var p = L.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(rig):
			return false
		var ph = age * 11.0
		for lg in legs:
			var pv: Node3D = lg[0]
			pv.rotation.x = sin(ph + (0.0 if float(lg[1]) < 0.0 else PI)) * 0.5
		rig.position = Vector3(0, absf(sin(ph)) * 0.16, rig_z)
		rig.rotation.x = sin(ph) * 0.1
		jaw.rotation.x = -0.3 - 0.3 * absf(sin(age * 6.5)) if not root_n.has_meta("bite") else -0.75 * clampf(1.0 - (age - float(root_n.get_meta("bite"))) / 0.08, 0.0, 1.0)
		return true
	root_n.add_child(p)
	root_n.set_meta("pulse", p)
	root_n.scale = Vector3.ONE * 2.1
	return root_n


## Elden tazıya uzanan kalın akım (tazının arka gövdesi): dişli beyaz-mavi şerit + iki ince tel; tazı uzaklaştıkça incelir
static func _hound_leash(hf: Callable, tail: Node3D) -> void:
	var fm = _fang(RAI, EDGE, 0.5)
	var am = L.arc_mat(RAI)
	var w = weakref(tail)
	var stt = {"next": 0.0, "main": [], "wires": [], "gone": -1.0, "end": Vector3.ZERO}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		var live = x != null and is_instance_valid(x) and x.is_inside_tree()
		if live:
			stt["end"] = x.global_position
		elif float(stt["gone"]) < 0.0:
			stt["gone"] = age
		if age > 2.9 or (not live and age - float(stt["gone"]) > 0.15):
			return false
		var a: Vector3 = hf.call()
		var e: Vector3 = stt["end"]
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var dist = a.distance_to(e)
			var main = L.jag(e, a, 0.06, 4)
			stt["main"] = [{"p": main, "w": clampf(0.36 - dist * 0.01, 0.12, 0.34), "a": 1.0, "k": 1}]
			var wires = []
			for q in 2:
				wires.append({"p": L.jag(e, a, 0.12, 4), "w": 0.035, "a": 0.9})
			stt["wires"] = wires
		var fade = 1.0 if live else clampf(1.0 - (age - float(stt["gone"])) / 0.15, 0.0, 1.0)
		L.draw(im, fm, stt["main"], fade, L.cam_pos())
		L.draw(im, am, stt["wires"], fade * randf_range(0.6, 1.0), L.cam_pos())
		return true)


## Isırık: küçük mavi-beyaz çakma, öne yelpaze gibi açılan dişli şimşekler, öne kıvılcım; yerde tazının fren pençelerinin
## açtığı iki parlak kenarlı oluk
static func _hatake_bite(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	L.flash(p, 1.3, Color(0.55, 0.78, 1.0), 0.12, 7.0)
	L.light(p, Color(0.6, 0.8, 1.0), 3.0, 8.0, 0.15)
	var side = d.cross(Vector3.UP).normalized()
	for k in 7:
		var f = (k - 3) / 3.0
		var e = p + (d + side * f * 0.8).normalized() * randf_range(2.5, 3.8) + Vector3.UP * randf_range(-0.6, 0.8)
		L.bolt(p, e, RAI, 0.09, 0.3, 2, 0.24, 0.05)
	L.sparks(p, 22, WHITE, 12.0, 0.35, d, 0.6)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		var dm = _ink(Color(0.07, 0.07, 0.09, 0.9))
		var gm = L.arc_mat(RAI)
		var furrows = []
		for sx in [-0.45, 0.45]:
			furrows.append({"p": L.ground_path(g - d * 3.2 + side * sx, g + side * sx * 1.3, 0.05, 3, 0.05), "w": 0.09, "a": 1.0, "k": 1})
		L.host(func(im, _n, _dt, age) -> bool:
			if age > 3.0:
				return false
			L.draw(im, dm, furrows, clampf((3.0 - age) / 0.8, 0.0, 1.0), L.cam_pos(), true)
			if age < 0.45:
				L.draw(im, gm, furrows, 1.0 - age / 0.45, L.cam_pos(), true)
			return true)
	L.wet_shock(p, 1.6)
	pj.shake(0.65)


## İsabette tazı mermiyle silinmez: dünyaya bırakılır, çenesi hedefe kapanmış halde 0.5 sn durur, sonra küçülüp söner
static func _hound_hold(hound: Node3D) -> void:
	if not L.alive(hound):
		return
	hound.reparent(L.root(), true)
	var ap = hound.get_meta("pulse")
	hound.set_meta("bite", float(ap.age) if is_instance_valid(ap) else 0.0)   # ısırık anı: tazının kendi saatiyle
	var tw = hound.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(hound, "scale", Vector3.ONE * 0.05, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_callback(hound.queue_free)


## Raikiri hazırlığı: elde cıvıldayan çatırtı, toplanan kıvılcımlar, elden yere damlayan kısa şimşekler
static func _raikiri_drip(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hf = L.hand_fn(pj, c)
	L.crackle(hf, 0.4, dur, WHITE, 5, 0.03)
	L.converge(hf, 1.2, 0.3, WHITE, 10)
	pj.every(dur, 0.12, func(_i, _k):
		var h: Vector3 = hf.call()
		var g = L.floor_at(h + L.hdir() * 0.3)
		L.bolt(h, g + Vector3.UP * 0.03, RAI, 0.03, 0.12, 1, 0.22, 0.04, 3), Callable())


static func hatake_raiju_tsuiga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 30.0)
	_raikiri_drip(pj, c, 0.8)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var d = pj.fwd(c, tt)
		var head = Node3D.new()
		var hound = _hatake_hound()
		hound.position.y = -1.3
		head.add_child(hound)
		hound.scale = Vector3.ONE * 0.5   # elden fışkırır: 0.15 sn'de tam boya büyür
		hound.create_tween().tween_property(hound, "scale", Vector3.ONE * 2.1, 0.15).set_ease(Tween.EASE_OUT)
		var pr = pj.shot(c, pj.gp(c.global_position + d) + Vector3.UP * 1.3, d, 24.0, head, pj.inf(c, "hatake_raiju_tsuiga", 2.0, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 1.2}), tt, false, 2.0, func(p, _h):
			_hound_hold(hound)
			_hatake_bite(pj, p, d))
		var hf = L.hand_fn(pj, c)
		L.flash(hf.call(), 0.9, RAI, 0.08, 7.0)
		_hound_leash(hf, hound.get_meta("tail"))
		L.crackle(L.follow_fn(hound, Vector3.UP * 1.6), 1.8, 2.6, WHITE, 4, 0.04, 0.06, hound)
		pj.every(2.0, 0.18, func(_i, _k):   # sıçrayış inişlerinde patiler yerde kısa ark bırakır
			if L.alive(pr):
				var g = L.floor_at(pr.global_position)
				if pr.global_position.y - g.y < 2.2:
					L.ground_arcs(g + pr.global_transform.basis.z * -1.2, 0.7, 0.25, RAI, 3, 0.03), Callable()))
	Sfx.play("chidori", c.global_position, 1.2)


# ═════════════════════════════════════════ Raiton Nagashi ═════════════════════════════════════════

## Kaynak (sahte karanlık karesi): ince elektrik değil, düz beyaz özlü, keskin köşeli, kalın cel şimşek şeritleri.
## Beden önce kendine yapışık dikey dişli şeritlerle sarılır, sonra göğüsten sekiz kalın köşeli şerit dışa ve aşağı
## yere saplanır (uçlarında küçük çakma); yerde ilk anda mavi yanan, sonra kararan köşeli çatlak ağı kalır.
static func _body_sheath(c: Node3D, dur: float) -> void:
	var fm = _fang(RAI, EDGE, 0.58)
	var hm = L.arc_mat(Color(0.4, 0.7, 1.0))
	var cw = weakref(c)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var base: Vector3 = x.global_position
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var out = []
			for k in 8:
				var a = TAU * k / 8.0 + randf_range(-0.3, 0.3)
				var y0 = randf_range(0.0, 0.6)
				var p0 = base + Vector3(cos(a) * 0.55, y0, sin(a) * 0.55)
				var p1 = base + Vector3(cos(a + 0.5) * 0.65, y0 + randf_range(1.2, 1.9), sin(a + 0.5) * 0.65)
				out.append({"p": L.zigzag(p0, p1, 4, 0.22), "w": 0.13, "a": 1.0, "k": 3})
			stt["polys"] = out
		var al = clampf((dur - age) / 0.15, 0.0, 1.0)
		var halo = []
		for pl in stt["polys"]:
			halo.append({"p": pl["p"], "w": 0.32, "a": 0.7, "k": 3})
		L.draw(im, hm, halo, al, L.cam_pos())
		L.draw(im, fm, stt["polys"], al, L.cam_pos())
		return true)


static func _nagashi_burst(c: Node3D) -> void:
	var fm = _fang(Color(0.5, 0.78, 1.0), EDGE, 0.55)
	var hm = L.arc_mat(Color(0.4, 0.7, 1.0))
	var cen = c.global_position + Vector3.UP * 1.0
	var ends = []
	for k in 8:
		var a = k * TAU / 8.0 + randf_range(-0.15, 0.15)
		var e = c.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.4, 4.2)
		ends.append(L.floor_at(e) + Vector3.UP * 0.05)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.55:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.07
			var out = []
			for e in ends:
				out.append({"p": L.zigzag(cen, e, 4, 0.45), "w": 0.3, "a": 1.0, "k": 0})
			stt["polys"] = out
		var grow = clampf(age / 0.05, 0.0, 1.0)
		var polys = []
		for pl in stt["polys"]:
			var pts: Array = pl["p"]
			polys.append({"p": pts.slice(0, maxi(2, int(ceil(pts.size() * grow)))), "w": pl["w"], "a": 1.0, "k": 0})
		var al = clampf((0.55 - age) / 0.18, 0.0, 1.0)
		var halo = []
		for pl in polys:
			halo.append({"p": pl["p"], "w": 0.7, "a": 0.6, "k": 0})
		L.draw(im, hm, halo, al, L.cam_pos())
		L.draw(im, fm, polys, al, L.cam_pos())
		return true)
	for e in ends:
		L.flash(e + Vector3.UP * 0.15, 0.6, RAI, 0.1, 6.0)


static func raiton_nagashi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# Jutsu.j_raiton_nagashi'nin oynanışı (Arcs / halka / yıldız görselleri yerine kendi görselim)
	var m = Jutsu._mult(c) * Jutsu._elem_bonus(c, "raiton")
	Sfx.play("chidori", c.global_position, 1.3)
	_body_sheath(c, 0.8)
	_nagashi_burst(c)
	L.light(c.global_position + Vector3.UP, Color(0.5, 0.75, 1.0), 3.0, 9.0, 0.3)
	Combat.hit_sphere(c, c.global_position + Vector3.UP, 4.0, {"dmg": 16.0 * m, "element": "raiton", "knock": 8.0, "kind": "heavy", "stun": 1.5, "hitstop": 0.06})
	# p_raiton_nagashi: yarık zemin (eski çatlak yardımcısı 4 m, varsayılan 6 sn -> bölge 5 sn)
	_cracks(pj.gp(c.global_position), 4.0, 3.5, 6.0, RAI)


# ═════════════════════════════════════════ Sōrei no Kane ═════════════════════════════════════════

## Kendi tasarım: ata ruhlarının çanı. Her vuruşta (üç vuruş) önce tepeden yere tek ince bir "tokmak" şimşeği çakar,
## sonra yerde kesik kesik, dişli bir ses halkası dışa koşar; halkanın her parçasından yukarı titreşen kısa dikey
## dişler (çan titreşimi) uzayıp kısalır. Her vuruş bir ton koyulaşır (beyaz -> açık mavi -> derin mavi); halka
## geçtiği en dış yerde ince koyu bir iz bırakır, yavaşça söner.
static func _toll(cen: Vector3, k: int, col: Color) -> void:
	var m = L.arc_mat(col)
	var span = 5.0 + k * 1.5
	var stt = {"next": 0.0, "polys": []}
	L.bolt(cen + Vector3.UP * 3.5, cen + Vector3.UP * 0.05, col, 0.07, 0.15, 1, 0.16, 0.05)
	L.flash(cen + Vector3.UP * 0.2, 0.8, col, 0.1, 8.0)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.34:
			return false
		var r = 0.8 + clampf(age / 0.3, 0.0, 1.0) * span
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var polys = []
			var nseg = 9
			for q in nseg:
				var a0 = TAU * q / nseg + randf_range(0.0, 0.15)
				var a1 = a0 + TAU / nseg * randf_range(0.55, 0.8)
				var pts = []
				for i in 6:
					var a = lerpf(a0, a1, i / 5.0)
					var rr = r + randf_range(-0.18, 0.18)
					var p = cen + Vector3(cos(a) * rr, 0, sin(a) * rr)
					pts.append(Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.08, p.z))
				polys.append({"p": pts, "w": 0.06, "a": 1.0})
				var mid: Vector3 = pts[3]
				var hgt = (1.1 - age * 2.2) * randf_range(0.5, 1.0)
				if hgt > 0.12:
					polys.append({"p": L.zigzag(mid, mid + Vector3.UP * hgt, 3, 0.07), "w": 0.03, "a": 0.9, "k": 1})
			stt["polys"] = polys
		L.draw(im, m, stt["polys"], clampf((0.34 - age) / 0.08, 0.0, 1.0), L.cam_pos())
		return true)
	# dış izin: halkanın vardığı yerde ince koyu daire
	var trace = []
	var rmax = 0.8 + span
	for i in 49:
		var a = TAU * i / 48.0
		var q = cen + Vector3(cos(a), 0, sin(a)) * rmax * randf_range(0.97, 1.03)
		trace.append(Vector3(q.x, Game.jutsu_floor(q.x, q.z) + 0.05, q.z))
	var dm = _ink(Color(0.1, 0.12, 0.2, 0.75))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 1.9:
			return false
		if age < 0.3:
			return true
		L.draw(im, dm, [{"p": trace, "w": 0.035, "a": 1.0, "k": 2}], clampf((1.9 - age) / 1.0, 0.0, 1.0), L.cam_pos(), true)
		return true)


static func sorei_no_kane(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "sorei_no_kane"
	pj.anim(c, "crouch", 1.5)
	var cw = weakref(c)
	var cen: Vector3 = pj.gp(c.global_position)
	var hitk = {}
	var tints = [WHITE, KURO_BOLT, Color(0.4, 0.62, 1.0)]
	for k in 3:
		pj.after(0.2 + k * 0.32, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			Sfx.play("thunder", cen, 1.6 - k * 0.2)
			_toll(cen, k, tints[k])
			pj.every(0.3, 0.03, func(_i, kk):
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				var r = 0.8 + kk * (5.0 + k * 1.5)
				for e in pj.enemies_near(c2, cen, r + 0.5):
					if not is_instance_valid(e) or e.is_dead():
						continue
					var key = "%d_%d" % [e.get_instance_id(), k]
					var dd = Vector2(e.global_position.x - cen.x, e.global_position.z - cen.z).length()
					if hitk.has(key) or dd < r - 1.2:
						continue
					hitk[key] = true
					e.take_hit(pj.inf(c2, id, 0.55, {"knock": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.5, "hitstop": 0.04}))))


# ═════════════════════════════════════════ Raijin Kenbu ═════════════════════════════════════════

## Kendi tasarım: şimşek tanrısının kılıç dansı. İki avuçtan düz, dişli kenarlı şimşek kılıçları uzar (elde kalın, uçta
## sivri); her kesik havada yay çizen geniş hilal bir şimşek izi bırakır (sağdan sola / soldan sağa sırayla, 0.07 sn'de
## süpürülür), arkasında ince yankı izi. Son kesik ikinci bir hilalle çarpı çizer, öne kıvılcım saçılır.
static func _thunder_blade(hold: Node3D, dur: float) -> void:
	var fm = _fang(KURO_BOLT, EDGE, 0.5)
	var am = L.arc_mat(KURO_BOLT)
	var hw = weakref(hold)
	var stt = {"next": 0.0, "blade": [], "wires": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var h = hw.get_ref()
		if age > dur or h == null or not is_instance_valid(h) or not h.is_inside_tree():
			return false
		var p0: Vector3 = h.global_position
		var dir: Vector3 = h.global_transform.basis.y.normalized()
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			stt["blade"] = [{"p": L.zigzag(p0 + dir * 0.95, p0 + dir * 0.04, 5, 0.035), "w": 0.06, "a": 1.0, "k": 1}]
			var wires = []
			for q in 2:
				var s = p0 + dir * randf_range(0.1, 0.8)
				wires.append({"p": L.jag(s, s + L.perp(dir) * randf_range(0.15, 0.3) + dir * 0.1, 0.3, 2), "w": 0.02, "a": 1.0})
			stt["wires"] = wires
		L.draw(im, fm, stt["blade"], 1.0, L.cam_pos())
		L.draw(im, am, stt["wires"], randf_range(0.5, 1.0), L.cam_pos())
		return true)


static func _kenbu_sweep(a: Vector3, b: Vector3, f: Vector3) -> void:
	var fm = _fang(KURO_BOLT, EDGE, 0.4)
	var am = L.arc_mat(KURO_BOLT)
	var base = []
	for i in 12:
		var u = i / 11.0
		base.append(a.lerp(b, u) + f * sin(PI * u) * 0.9)
	var stt = {"next": 0.0, "pts": base}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.28:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var np = []
			for i in base.size():
				np.append(Vector3(base[i]) + (L.rdir() * 0.07 if i > 0 and i < base.size() - 1 else Vector3.ZERO))
			stt["pts"] = np
		var cnt = maxi(2, int(ceil(base.size() * clampf(age / 0.07, 0.0, 1.0))))
		var pts: Array = stt["pts"]
		var cut = pts.slice(0, cnt)
		var echo = []
		for q in cut:
			echo.append(Vector3(q) - f * 0.28)
		var al = clampf((0.28 - age) / 0.14, 0.0, 1.0)
		L.draw(im, fm, [{"p": cut, "w": 0.15, "a": 1.0, "k": 3}], al, L.cam_pos())
		L.draw(im, am, [{"p": echo, "w": 0.04, "a": 0.7, "k": 3}], al * 0.8, L.cam_pos())
		return true)


static func raijin_kenbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.2)
	var id = "raijin_kenbu"
	pj._jump_at(c, tt, 0.0, 12.0 if tt and tt.global_position.distance_to(c.global_position) > 2.4 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	for hand in ["RightHand", "LeftHand"]:   # avuçlardan uzayan şimşek kılıçları
		var ba = pj.bone_attach(c, hand)
		if ba:
			var hold = Node3D.new()
			ba.add_child(hold)
			hold.position = Vector3(0, 0.1, 0)
			pj.free_after(1.2, ba)
			_thunder_blade(hold, 1.15)
	for k in 3:
		pj.after(0.25 + k * 0.28, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var f: Vector3 = pj._face(cc, x) if x != null and pj.live(x) else cc.face_dir()
			pj.anim(cc, ["slash_a", "slash_b", "slash_c"][k], 2.2)
			if x != null and pj.live(x) and cc is CharacterBody3D:   # her kesikte rakibe doğru atılır
				cc.velocity = f * clampf((cc.global_position.distance_to(x.global_position) - 1.6) / 0.15, 0.0, 16.0)
			var sd = f.cross(Vector3.UP).normalized()
			var base: Vector3 = cc.global_position + Vector3.UP * 1.1 + f * 1.2
			var s = 1.0 if k % 2 == 0 else -1.0
			_kenbu_sweep(base - sd * 1.1 * s + Vector3.UP * 0.7, base + sd * 1.1 * s - Vector3.UP * 0.6, f)
			Sfx.play("zap", cc.global_position, 1.0 + k * 0.1)
			var last = k == 2
			Combat.hit_zone(cc, pj.gp(cc.global_position), f, 2.8, 60.0, 2.4, pj.inf(cc, id, 1.1 if last else 0.5, {"knock": 12.0 if last else 2.0, "launch": 3.0 if last else 0.0, "kind": "heavy", "element": "raiton", "stun": 0.4 if last else 0.15, "hitstop": 0.07 if last else 0.03}))
			if last:   # çarpı: ters yönde ikinci hilal + öne kıvılcım
				_kenbu_sweep(base + sd * 1.1 + Vector3.UP * 0.7, base - sd * 1.1 - Vector3.UP * 0.6, f)
				L.sparks(base, 26, WHITE, 13.0, 0.4, f, 0.5)
				L.flash(base, 1.1, KURO_BOLT, 0.1, 8.0)
				L.light(base, KURO_BOLT, 2.5, 7.0, 0.15))


# ═════════════════════════════════════════ Raidō Hashiri ═════════════════════════════════════════

## Kendi tasarım: yerde koşan yıldırım yolu. Şimşek toprağı yararak hedefe koşar: arkasında kızgın mavi kenarlı, sonra
## kararan dişli bir oluk kalır, başında kıvılcım saçılır. Varınca hedefin altından dört şimşek YERDEN GÖĞE fışkırır
## (aşağıdan yukarı büyür), toz halkası, fırlayan taşlar, yanık.
static func _groove(a: Vector3, b: Vector3) -> void:
	var pts = L.ground_path(a, b, 0.12, 2, 0.05)
	var dm = _ink(Color(0.07, 0.07, 0.1, 0.9))
	var gm = L.arc_mat(KURO_BOLT)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 2.5:
			return false
		L.draw(im, dm, [{"p": pts, "w": 0.09, "a": 1.0, "k": 2}], clampf((2.5 - age) / 0.8, 0.0, 1.0), L.cam_pos(), true)
		if age < 0.55:
			L.draw(im, gm, [{"p": pts, "w": 0.12, "a": 1.0, "k": 2}], 1.0 - age / 0.55, L.cam_pos(), true)
		return true)
	L.sparks(b + Vector3.UP * 0.1, 4, WHITE, 5.0, 0.25, b - a, 0.8)


static func _uprising(at: Vector3) -> void:
	var fm = _fang(KURO_BOLT, EDGE, 0.45)
	var cols = []
	for q in 4:
		cols.append([at + Vector3(randf_range(-0.5, 0.5), 0.02, randf_range(-0.5, 0.5)), at + Vector3(randf_range(-0.6, 0.6), 7.0 + q, randf_range(-0.6, 0.6))])
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.32:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var out = []
			for cl in cols:
				out.append({"p": L.jag(cl[0], cl[1], 0.12, 4), "w": 0.16, "a": 1.0, "k": 0})
			stt["polys"] = out
		var grow = clampf(age / 0.06, 0.0, 1.0)
		var polys = []
		for pl in stt["polys"]:
			var pts: Array = pl["p"]
			polys.append({"p": pts.slice(0, maxi(2, int(ceil(pts.size() * grow)))), "w": pl["w"], "a": 1.0, "k": 0})
		L.draw(im, fm, polys, clampf((0.32 - age) / 0.12, 0.0, 1.0), L.cam_pos())
		return true)
	L.flash(at + Vector3.UP * 0.3, 1.2, KURO_BOLT, 0.12, 9.0)
	L.dust_ring(at, 0.4, 3.5, 0.6, DUST)
	L.debris(at, 10, 8.0, Color(0.42, 0.38, 0.33))
	L.scorch(at, 1.4, KURO_BOLT, 4.0, 0.8)


static func raido_hashiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "raido_hashiri"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var start: Vector3 = pj.gp(c.global_position + d * 1.0)
	var prev = {"p": start}
	Sfx.play("zap", start, 0.7)
	L.flash(start + Vector3.UP * 0.2, 0.7, KURO_BOLT, 0.1, 7.0)
	pj.every(0.5, 0.04, func(_i, k):
		var x = tw.get_ref() if tw else null
		var end: Vector3 = pj.gp(x.global_position) if x != null and is_instance_valid(x) else start + d * 12.0
		var p: Vector3 = pj.gp(start.lerp(end, k)) + Vector3.UP * 0.1
		_groove(prev["p"], p + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))
		prev["p"] = p, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		var at: Vector3 = pj.gp(x.global_position) if x != null and is_instance_valid(x) else start + d * 12.0
		_uprising(at)
		Sfx.play("thunder", at, 0.9)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 2.2):
			if is_instance_valid(e) and not e.is_dead():
				e.take_hit(pj.inf(cc, id, 1.5, {"knock": 1.0, "launch": 9.0, "kind": "heavy", "element": "raiton", "stun": 0.6, "hitstop": 0.08, "dir": Vector3.UP})))


# ═════════════════════════════════════════ Raisō Tomurai ═════════════════════════════════════════

## Kendi tasarım: yıldırım cenazesi. Şimşek düz gitmez, rakipten rakibe KEMER çizerek sıçrar (yukarı kavisli kalın dişli
## köprü); vurulan her bedende kısa çatırtı, küçük beyaz çakma ve aşağı süzülen soluk kül kıvılcımları. Bütün zincir
## boyunca soluk bir "cenaze alayı" teli bir süre asılı kalır, sonra söner.
static func _arch_bolt(a: Vector3, b: Vector3, col: Color, w: float, life: float) -> void:
	var fm = _fang(col, EDGE, 0.45)
	var am = L.arc_mat(col)
	var ctl = (a + b) * 0.5 + Vector3.UP * (1.0 + a.distance_to(b) * 0.12)
	var stt = {"next": 0.0, "main": [], "br": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var pts = []
			for i in 11:
				var u = i / 10.0
				var q = a.lerp(ctl, u).lerp(ctl.lerp(b, u), u)
				pts.append(q + (L.rdir() * 0.14 if i > 0 and i < 10 else Vector3.ZERO))
			stt["main"] = [{"p": pts, "w": w, "a": 1.0, "k": 0}]
			var br = []
			var s: Vector3 = pts[randi_range(2, 8)]
			L.fork(s, s + L.rdir() * 0.9 + Vector3.DOWN * 0.3, 0.3, 2, 0, br, 0.03, 0.9)
			stt["br"] = br
		var al = clampf((life - age) / (life * 0.5), 0.0, 1.0)
		L.draw(im, fm, stt["main"], al, L.cam_pos())
		L.draw(im, am, stt["br"], al, L.cam_pos())
		return true)


static func _procession(path: Dictionary, dur: float) -> void:
	var m = L.arc_mat(Color(0.35, 0.45, 0.72))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var pts: Array = path["pts"]
		if pts.size() < 2:
			return true
		var line = []
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			for j in 6:
				var u = j / 6.0
				line.append(a.lerp(b, u) + Vector3.DOWN * sin(PI * u) * 0.35)
		line.append(pts[pts.size() - 1])
		L.draw(im, m, [{"p": line, "w": 0.025, "a": 0.6, "k": 2}], clampf((dur - age) / 0.4, 0.0, 1.0), L.cam_pos())
		return true)


static func _mourn(e: Node3D, to: Vector3) -> void:
	L.body_arcs(e, 0.35, KURO_BOLT, 3, 0.03)
	L.flash(to, 0.7, WHITE, 0.08, 6.0)
	L.sparks(to + Vector3.UP * 0.6, 8, Color(0.7, 0.75, 0.85), 2.0, 0.6, Vector3.DOWN, 0.6, 0.018)


static func raiso_tomurai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "raiso_tomurai"
	var tt = pj.tg(c, t, 18.0)
	pj._face(c, tt)
	pj.anim(c, "push", 1.8)
	if tt == null:
		return
	var cw = weakref(c)
	var chain = [tt]
	var cur = tt
	for k in 4:   # en yakın vurulmamış rakibe sıçrar
		var best = null
		var bd = 9.0
		for e in pj.enemies_near(c, cur.global_position, 9.0):
			if e in chain:
				continue
			var dd = e.global_position.distance_to(cur.global_position)
			if dd < bd:
				bd = dd
				best = e
		if best == null:
			break
		chain.append(best)
		cur = best
	var prev: Vector3 = pj.hand_pos(c)
	var path = {"pts": [prev]}
	_procession(path, 0.2 + chain.size() * 0.1 + 0.7)
	for k in chain.size():
		var ew = weakref(chain[k])
		var from: Vector3 = prev
		prev = chain[k].global_position + Vector3.UP * 1.1
		pj.after(0.1 + k * 0.1, func():
			var cc = cw.get_ref()
			var e = ew.get_ref()
			if cc == null or e == null or not pj.live(cc) or not pj.live(e):
				return
			var to: Vector3 = e.global_position + Vector3.UP * 1.1
			_arch_bolt(from, to, KURO_BOLT, 0.13, 0.3)
			(path["pts"] as Array).append(to)
			_mourn(e, to)
			Sfx.play("zap", to, 1.0 + k * 0.1)
			e.take_hit(pj.inf(cc, id, 1.2 * pow(0.8, k), {"knock": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.35, "hitstop": 0.05})))


# ═════════════════════════════════════════ Iwa Nadare ═════════════════════════════════════════

## Kaynak (kaya çığı karesi): yamacın tepesine şimşek düşer, tepe çatlar, kayalar havaya savrulur ve aralarında ince
## şimşek telleriyle yamaçtan yuvarlanarak iner; yuvarlanan her kaya arkasında yere yapışık toz izi bırakır. Kayalar
## kendi köşeli cel kaya örgüm (koyu dış çizgi), bazılarına ince şimşek telleri dolanır.
static func _rock_node(s: float) -> MeshInstance3D:
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3(s, s * 0.8, s), EARTH.darkened(randf_range(0.0, 0.25)), Vector3(randf() * 360, randf() * 360, 0), randi_range(1, 6))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	mi.material_overlay = L.line_mat(Color(0.12, 0.08, 0.05), 0.03)
	return mi


static func _dust_trail(rk: Node3D) -> void:
	var m = L.dust_mat(DUST)
	var w = weakref(rk)
	var pts = []
	var stt = {"gone": -1.0}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		var live = x != null and is_instance_valid(x) and x.is_inside_tree()
		if live:
			pts.append({"p": L.floor_at(x.global_position) + Vector3.UP * 0.12, "t": age})
		elif float(stt["gone"]) < 0.0:
			stt["gone"] = age
		while pts.size() > 0 and age - float(pts[0]["t"]) > 0.5:
			pts.pop_front()
		if not live and (pts.size() < 2 or age - float(stt["gone"]) > 0.5):
			return false
		if pts.size() < 2:
			return true
		var line = []
		for q in pts:
			line.append(q["p"])
		L.draw(im, m, [{"p": line, "w": 0.55, "a": 0.8, "k": 1}], 1.0, L.cam_pos(), true)
		return true)


static func iwa_nadare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "iwa_nadare"
	var tt = pj.tg(c, t, 26.0)
	pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	var cw = weakref(c)
	var up: Vector3 = CanonRules.uphill_dir(c)
	var top: Vector3 = pj.gp(c.global_position + up * 16.0)
	var from: Vector3 = pj.hand_pos(c)
	for k in 3:   # yamaca giden şimşek dalgası
		pj.after(k * 0.06, func():
			L.bolt(from, top + Vector3.UP * (0.5 + k * 0.8), Color(0.75, 0.85, 1.0), 0.08, 0.28, 2, 0.16, 0.05))
	Sfx.play("thunder", top, 1.1)
	pj.after(0.3, func():
		_cracks(top, 6.0, 3.0)
		L.flash(top + Vector3.UP * 0.5, 1.2, RAI, 0.1, 8.0)
		L.debris(top, 16, 8.0, EARTH)
		L.dust_ring(top, 1.0, 6.0, 1.0, DUST)
		pj.shake(0.6)
		Sfx.play("earth", top, 0.6))
	var goal: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + c.face_dir() * 10.0)
	for k in 14:   # kayalar yamaçtan yuvarlanarak iner
		var off = Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
		var s = randf_range(0.9, 1.8)
		pj.after(0.4 + k * 0.08, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var rk = _rock_node(s)
			var a: Vector3 = top + off * 0.5 + Vector3.UP * s
			var b: Vector3 = goal + off + Vector3.UP * s * 0.5
			pj.scene_add(rk, a)
			_dust_trail(rk)
			if k % 3 == 0:   # kayaların arasında ince şimşek telleri
				L.crackle(L.follow_fn(rk), s * 0.8, 0.6, RAI, 2, 0.025, 0.07, rk)
			var rw = weakref(rk)
			var roll = func(_i, u):
				var r = rw.get_ref()
				if r == null:
					return
				var p: Vector3 = a.lerp(b, u)
				r.global_position = pj.gp(p) + Vector3.UP * s * 0.5
				r.rotation.x += 0.35
				var c2 = cw.get_ref()
				if c2 != null and _i % 4 == 0:
					for e in pj.enemies_near(c2, r.global_position, s + 0.6):
						if is_instance_valid(e) and not e.is_dead():
							e.take_hit(pj.inf(c2, id, 0.35, {"knock": 9.0, "launch": 2.5, "kind": "heavy", "hitstop": 0.02, "dir": (b - a).normalized()}))
			pj.every(0.9, 0.03, roll, func():
				var r = rw.get_ref()
				if r != null:
					L.debris(r.global_position, 6, 5.0, EARTH)
					r.queue_free()))


# ═════════════════════════════════════════ Erubō ═════════════════════════════════════════

## Kaynak (Raikage dirseği): ışık şovu yok. Koşu boyunca hız çizgileri; dirsek yukarı çakınca darbe noktasından düz beyaz
## anime darbe çizgileri yıldız gibi fırlar, rakibin üstüne doğru yukarı akan hız çizgileri, tek ince yukarı şimşek;
## yerde toz halkası ve birkaç taş.
static func _elbow_burst(p: Vector3, f: Vector3) -> void:
	_strokes(p, (f + Vector3.UP).normalized(), 14, 0.3, 2.2, 0.2, Color(1, 1, 1), 0.04)
	L.flash(p, 0.9, WHITE, 0.08, 6.0)
	L.zig_bolt(p, p + Vector3.UP * 4.0, RAI, 0.045, 0.2, 5, 0.3)
	var m = _ink(Color(1, 1, 1))
	var ls = []
	for k in 8:
		ls.append({"o": Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 1.0), randf_range(-0.8, 0.8)), "l": randf_range(1.0, 2.0)})
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.35:
			return false
		var polys = []
		for s in ls:
			var o: Vector3 = p + Vector3(s["o"]) + Vector3.UP * age * 14.0
			polys.append({"p": _seg(o, o + Vector3.UP * float(s["l"])), "w": 0.025, "a": 1.0, "k": 3})
		L.draw(im, m, polys, 1.0 - age / 0.35, L.cam_pos())
		return true)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.dust_ring(g, 0.4, 2.6, 0.5, DUST)
		L.debris(g, 6, 6.0)


static func erubo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_rai_armor(c, 0.9)
	# ClanJutsu.c_erubo'nun oynanışı
	_limb_arcs(pj, c, 0.6)
	L.speed_lines(c, c.face_dir(), 0.25, WHITE, 8)
	# Erubō (anime A): kaymadan koşar — şimşekli dirsek önde, varınca dirsek darbesi yukarı savurur
	var on_tick = func(_pt):
		if is_instance_valid(c) and c.get("model"):
			c.model.play("run", 0.06, 2.0)
	var on_end = func():
		var p = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.0
		pj.anim(c, "hook", 2.0)
		for h in pj.hit(c, p, 1.6, pj.inf(c, "erubo", 1.4, {"knock": 6.0, "launch": 10.0, "kind": "heavy", "element": "raiton", "hitstop": 0.1})):
			pj.st(h, "stun", 1.4)
		_elbow_burst(p, c.face_dir())
		Sfx.play("thunder", p, 1.4, 0.6)
	Jutsu._dash(c, t, 0.22, 22.0, on_tick, on_end)


# ═════════════════════════════════════════ Jigokuzuki ═════════════════════════════════════════

## Kaynak (Jigokuzuki Yonhon / Sanbon / Ippon): parmak uçları sıkıştırılmış şimşekle düz bir mızrağa döner — elde
## dümdüz, ucu sivri beyaz iğne (parmak azaldıkça incelir ve uzar), çevresinde dönen iki ince tel. Saplama: tek düz,
## sivri beyaz iz + boyunca öne fırlayan anime hız çizgileri, uçta küçük çakma ve öne kıvılcım; Ippon'da uçtan geriye
## açılan ince ses dalgası çizgileri. Sanbon'da kol savruluşu yerde toz halkası + dışa yatık toz çizgileri.
static func _nukite_spear(pj: PathJutsu, c: Node3D, dur: float, fingers: int) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	pj.free_after(dur, ba)
	var fm = _fang(RAIKAGE, EDGE, 0.55)
	var am = L.arc_mat(RAIKAGE)
	var w = {4: 0.07, 3: 0.055, 1: 0.035}[fingers]
	var bw = weakref(ba)
	L.host(func(im, _n, _dt, age) -> bool:
		var x = bw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var p0: Vector3 = x.global_position
		var dir: Vector3 = x.global_transform.basis.z.normalized()
		var tip = p0 + dir * 0.75
		L.draw(im, fm, [{"p": _seg(tip, p0 + dir * 0.05, 6), "w": w, "a": 1.0, "k": 1}], 1.0, L.cam_pos())
		var u = dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
		var v = dir.cross(u).normalized()
		var wires = []
		for q in 2:
			var line = []
			for i in 8:
				var f = i / 7.0
				var a = age * 30.0 + f * TAU * 1.5 + q * PI
				line.append(p0 + dir * (0.05 + f * 0.7) + (u * cos(a) + v * sin(a)) * w * 1.6)
			wires.append({"p": line, "w": 0.012, "a": 1.0, "k": 2})
		L.draw(im, am, wires, randf_range(0.6, 1.0), L.cam_pos())
		return true)


static func _pierce_line(a: Vector3, b: Vector3, d: Vector3, fingers: int) -> void:
	var wm = _ink(Color(1, 1, 1))
	var gm = L.arc_mat(RAIKAGE)
	var w = 0.03 + (5 - fingers) * 0.012
	var u = d.cross(Vector3.UP).normalized()
	var v = d.cross(u).normalized()
	var ls = []
	for k in 12:
		var ang = randf() * TAU
		ls.append({"o": (u * cos(ang) + v * sin(ang)) * randf_range(0.25, 0.75), "x": randf_range(-0.5, 0.6), "l": randf_range(1.0, 2.2)})
	var reach = a.distance_to(b)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.3:
			return false
		var f = age / 0.3
		L.draw(im, wm, [{"p": _seg(b, a, 8), "w": w * (1.0 - f * 0.6), "a": 1.0, "k": 1}], 1.0 - f * f, L.cam_pos())
		if age < 0.12:
			L.draw(im, gm, [{"p": _seg(b, a, 8), "w": w * 2.6, "a": 0.6, "k": 1}], 1.0 - age / 0.12, L.cam_pos())
		var polys = []
		for s in ls:
			var x = (float(s["x"]) + age * 3.5) * reach
			var o: Vector3 = a + d * x + Vector3(s["o"])
			polys.append({"p": _seg(o, o + d * float(s["l"])), "w": 0.018, "a": 1.0, "k": 3})
		L.draw(im, wm, polys, 1.0 - f, L.cam_pos())
		if fingers == 1:   # Ippon: uçtan geriye açılan ince ses dalgası
			var vv = []
			for sx in [-1.0, 1.0]:
				vv.append({"p": _seg(b, b - d * (1.0 + f * 3.0) + u * sx * (0.3 + f * 1.4)), "w": 0.02, "a": 1.0, "k": 1})
			L.draw(im, wm, vv, 1.0 - f, L.cam_pos())
		return true)
	L.flash(b, 0.8, Color(0.6, 0.85, 1.0), 0.08, 5.0)
	L.sparks(b, 10, WHITE, 9.0, 0.25, d, 0.4)


static func _sanbon_sweep(pos: Vector3) -> void:
	var g = L.floor_at(pos)
	L.dust_ring(g, 0.5, 8.0, 0.45, DUST)
	_strokes(g + Vector3.UP * 0.25, Vector3.UP, 18, 0.5, 7.0, 0.35, DUST.darkened(0.15), 0.06)


static func jigokuzuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var modo = (c is Player and Buffs.has("raiton_chakura_modo")) or (not (c is Player) and c.get("buffs") != null and c.buffs.has("raiton_chakura_modo"))
	var mast = Mastery.get_v(Game.profile, "raiton") if c is Player else 50.0
	var fingers = 1 if (modo and mast >= 40.0) else (3 if modo or mast >= 25.0 else 4)
	var reach = {4: 4.0, 3: 5.5, 1: 11.0}[fingers]
	var mul = {4: 0.9, 3: 1.2, 1: 2.0}[fingers]
	_rai_armor(c, 1.0)
	_nukite_spear(pj, c, 0.3 + reach * 0.06, fingers)
	pj.busy(c, 0.5)
	pj.anim(c, "cross", 1.6)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var a = c.global_position + Vector3.UP * 1.2 + d * 0.6
		var b = a + d * reach
		_pierce_line(a, b, d, fingers)
		for k in 6:
			pj.hit(c, a.lerp(b, k / 5.0), 0.8, pj.inf(c, "jigokuzuki", mul / 2.0, {"knock": 8.0, "kind": "heavy", "element": "raiton", "hitstop": 0.05, "pierce_guard": fingers <= 3}))
		if fingers == 3:   # Sanbon: kolu savurunca çevreye şok dalgası
			_sanbon_sweep(c.global_position)
			pj.hit(c, c.global_position + Vector3.UP, 4.0, pj.inf(c, "jigokuzuki", 0.4, {"knock": 18.0, "kind": "heavy", "element": "raiton"}))
		Combat.popup_text(c.global_position + Vector3.UP * 2.5, {4: "Yonhon Nukite", 3: "Sanbon Nukite", 1: "Ippon Nukite!"}[fingers], Color(0.75, 0.9, 1.0))
		Sfx.play("chidori", a, 1.5))


# ═════════════════════════════════════════ Raigā Bomu ═════════════════════════════════════════

## Kaynak (Liger Bomb 1-2): rakibi boynundan tutup yükselirken ikisinin çevresinde kalın, dişli şimşek şeritleri sarmal
## çizerek döner; yere çakışta zemin kırılır — merkezden dişli çatlaklar, çevreye dışa yatık köşeli kaya levhaları fışkırır
## (bir süre durup gömülür), kalın S kıvrımlı şimşek kırbaçları dışa ve yukarı savrulur, tepeden tek kalın şerit iner,
## taşlar ve toz halkası.
static func _lift_coils(c: Node3D, tt: Node3D, dur: float) -> void:
	var fm = _fang(RAIKAGE, EDGE, 0.5)
	var am = L.arc_mat(RAIKAGE)
	var cw = weakref(c)
	var tw = weakref(tt)
	var stt = {"next": 0.0, "polys": [], "br": []}
	L.body_arcs(tt, dur, RAIKAGE, 3, 0.03)
	L.host(func(im, _n, _dt, age) -> bool:
		var a = tw.get_ref()
		var b = cw.get_ref()
		if age > dur or a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			return false
		var lo: Vector3 = a.global_position
		var hi: Vector3 = b.global_position + Vector3.UP * 1.0
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			# sarmal yalnız iskelet: iskelet noktaları arası orta nokta kırılımlı dişli şimşek + dışa çatallar
			var out = []
			var br = []
			for q in 2:
				var keys = []
				for i in 11:
					var f = i / 10.0
					var ang = f * TAU * 2.5 + age * 9.0 + q * PI
					var r = 1.1 + sin(f * PI) * 0.4
					keys.append(lo.lerp(hi, f) + Vector3(cos(ang) * r, 0, sin(ang) * r))
				var line = [keys[0]]
				for i in keys.size() - 1:
					var seg = L.jag(keys[i], keys[i + 1], 0.32, 2)
					seg.pop_front()
					line.append_array(seg)
				out.append({"p": line, "w": 0.075, "a": 1.0, "k": 3})
				for j in 3:
					var sp: Vector3 = line[randi_range(2, line.size() - 3)]
					L.fork(sp, sp + (sp - lo.lerp(hi, 0.5)).normalized() * randf_range(0.6, 1.2) + L.rdir() * 0.3, 0.35, 2, 1, br, 0.03, 0.9)
			stt["polys"] = out
			stt["br"] = br
		var al = clampf((dur - age) / 0.1, 0.0, 1.0)
		L.draw(im, fm, stt["polys"], al, L.cam_pos())
		L.draw(im, am, stt["br"], al * randf_range(0.6, 1.0), L.cam_pos())
		return true)


static func _slab(at: Vector3, dir: Vector3, life: float) -> void:
	var b = MB.new()
	b.add("box", Vector3(0, 0.4, 0), Vector3(randf_range(0.9, 1.6), 0.8, randf_range(0.22, 0.35)), Color(0.45, 0.38, 0.3).darkened(randf_range(0.0, 0.25)))
	b.add("crag", Vector3(randf_range(-0.2, 0.2), 0.85, 0), Vector3(0.6, 0.5, 0.3), Color(0.42, 0.36, 0.28), Vector3.ZERO, randi_range(1, 5))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	mi.material_overlay = L.line_mat(Color(0.1, 0.07, 0.05), 0.025)
	L.root().add_child(mi)
	var side = dir.cross(Vector3.UP).normalized()
	var bs = Basis(side, Vector3.UP, -dir).rotated(side, -deg_to_rad(randf_range(30.0, 60.0)))
	var g = L.floor_at(at)
	mi.global_transform = Transform3D(bs, g - Vector3.UP * 0.9)
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", g - Vector3.UP * 0.1, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_property(mi, "global_position", g - Vector3.UP * 1.2, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func _whip(base: Vector3, dir: Vector3) -> void:
	var fm = _fang(RAIKAGE, EDGE, 0.42)
	var side = dir.cross(Vector3.UP).normalized()
	var h = randf_range(2.0, 4.0)
	var curl = randf_range(0.8, 1.4) * (1.0 if randf() < 0.5 else -1.0)
	var stt = {"next": 0.0, "pts": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.45:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var np = []
			for i in 16:
				var u = i / 15.0
				np.append(base + Vector3.UP * 0.3 + dir * 5.0 * u + Vector3.UP * sin(PI * u) * h + side * sin(TAU * u) * curl + L.rdir() * 0.1)
			stt["pts"] = np
		var pts: Array = stt["pts"]
		var cnt = maxi(2, int(ceil(pts.size() * clampf(age / 0.08, 0.0, 1.0))))
		L.draw(im, fm, [{"p": pts.slice(0, cnt), "w": 0.22, "a": 1.0, "k": 3}], clampf((0.45 - age) / 0.15, 0.0, 1.0), L.cam_pos())
		return true)


static func _bomb_crater(base: Vector3) -> void:
	_cracks(base, 7.0, 4.0, 6.0)   # eski çatlak yardımcısı (base, 7): yarık zemin bölgesi
	for k in 8:
		var a = TAU * k / 8.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		_slab(base + dv * randf_range(1.4, 2.8), dv, 2.5)
	for k in 4:
		_whip(base, L.hdir())
	var fm = _fang(RAIKAGE, EDGE, 0.42)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:   # tepeden inen tek kalın şerit
		if age > 0.22:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			stt["polys"] = [{"p": L.jag(base + Vector3.UP * 0.1, base + Vector3.UP * 9.0, 0.1, 4), "w": 0.3, "a": 1.0, "k": 1}]
		L.draw(im, fm, stt["polys"], 1.0 - age / 0.22, L.cam_pos())
		return true)
	L.debris(base, 14, 11.0, Color(0.5, 0.42, 0.32))
	L.dust_ring(base, 1.0, 6.0, 0.8, DUST)
	L.flash(base + Vector3.UP * 0.5, 1.4, RAIKAGE, 0.12, 9.0)
	L.light(base + Vector3.UP, RAIKAGE, 3.0, 10.0, 0.25)


static func raiga_bomu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_rai_armor(c, 1.8)
	# ClanJutsu.c_raiga_bomu'nun oynanışı: hedef 16 m içindeyse önce ona koşup yakalar
	var tt = pj.tg(c, t, 16.0)
	if tt == null:
		Hud.msg("Raigā Bomu: yakında hedef yok", Color(0.8, 0.9, 1))
		return
	_limb_arcs(pj, c, 1.6)
	pj.busy(c, 1.7)
	var grab = func():
		if not (pj.live(c) and pj.live(tt)):
			return
		# anime A: rakibi boynundan yakalar, birlikte havaya sıçrar, en tepede ters çevirip şimşekli dirsekle yere çakar
		pj.st(tt, "bind", 1.3)
		pj.anim(c, "jump", 1.4)
		var base = pj.gp(tt.global_position)
		var fd = c.face_dir()
		_lift_coils(c, tt, 0.9)
		pj.every(0.9, 1.0 / 30.0, func(_i, k):
			var h = sin(minf(k * 1.4, 1.0) * PI * 0.5) * 7.0 if k < 0.7 else lerpf(7.0, 0.0, (k - 0.7) / 0.3)
			if pj.live(tt):
				tt.global_position = base + Vector3.UP * h
				tt.rotation.x = lerpf(0.0, PI, clampf((k - 0.55) / 0.2, 0.0, 1.0))   # tepede ters döner
			if is_instance_valid(c):
				c.global_position = base + Vector3.UP * (h + 1.3) - fd * 0.5
				c.velocity = Vector3.ZERO, func():
			if pj.live(tt):
				tt.global_position = base
				tt.rotation.x = 0.0
			pj.anim(c, "slash_c", 2.0)
			_bomb_crater(base)
			pj.hit(c, base + Vector3.UP, 3.0, pj.inf(c, "raiga_bomu", 2.4, {"knock": 10.0, "launch": 2.0, "kind": "heavy", "element": "raiton", "hitstop": 0.15}))
			pj.shake(1.1)
			Sfx.play("thunder", base, 0.8))
	if c.global_position.distance_to(tt.global_position) > 2.2:
		L.speed_lines(c, c.face_dir(), minf(0.5, c.global_position.distance_to(tt.global_position) / 30.0), WHITE, 8)
		Jutsu._dash(c, tt, minf(0.5, c.global_position.distance_to(tt.global_position) / 30.0), 30.0, func(_pt):
			if is_instance_valid(c) and c.get("model"):
				c.model.play("run", 0.06, 2.0), grab)
	else:
		grab.call()


# ═════════════════════════════════════════ Raiton Kuropansā ═════════════════════════════════════════

## Kaynak (Raiton Kuropansā karesi): görüntüyü kaplayan dev, AÇIK ÇENE — mor ağız içi, iki sıra beyaz sivri diş, gırtlakta
## beyaz dişli şimşek; kömür siyahı gövdede karalama gibi fırça çizgileri, beyaz kontur, parlak sarı-beyaz gözler.
## Gövde baş ve ön bacaklarla sınırlı: arka yarısı yoktur, kara şimşek tellerine dağılarak geriye akar (tam bir
## koşan panter değil, kara şimşekten fırlayan bir av saldırısı). Sıçrayarak ilerler, çene açılıp kapanır.
## Çarpışta iki sıra kara-beyaz diş yukarıdan ve aşağıdan kapanır, ardından kara şimşekler dışa savrulur.
static func _ink_panther(s: float) -> Node3D:
	var m = _smat("ink", MODE_SOLID, SH_INK)
	var ol = L.line_mat(Color(0.82, 0.84, 0.96), 0.014)
	var BK = Color(0.03, 0.03, 0.05)
	var MOUTH = Color(0.42, 0.34, 0.62)
	var FANG = Color(0.96, 0.96, 1.0)
	var EYE = Color(1.0, 0.95, 0.62)
	var root_n = Node3D.new()
	var rig = Node3D.new()
	rig.scale = Vector3.ONE * s
	root_n.add_child(rig)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.48, -0.15), Vector3(0.42, 0.42, 0.75), BK, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.58, -0.38), Vector3(0.48, 0.36, 0.4), BK, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.5, 0.45), Vector3(0.36, 0.7, 0.3), BK, Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0.66, -0.68), Vector3(0.36, 0.3, 0.36), BK, Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.11 * sx, 0.8, -0.62), Vector3(0.08, 0.14, 0.05), BK, Vector3(35, 0, -15 * sx), 5)
		b.add("box", Vector3(0.09 * sx, 0.73, -0.82), Vector3(0.09, 0.03, 0.03), EYE, Vector3(0, 0, 18 * sx))
	var body = L.mi_of(b.build(), m)
	body.material_overlay = ol
	rig.add_child(body)
	# çeneler: üst kalkık, alt sarkık; içte mor plaka, iki sıra beyaz diş
	var jaws = []
	for q in [[0.68, -0.78, 1.0], [0.6, -0.76, -1.0]]:
		var piv = Node3D.new()
		piv.position = Vector3(0, q[0], q[1])
		rig.add_child(piv)
		var up_j = float(q[2]) > 0.0
		var jb = MB.new()
		jb.add("cone", Vector3(0, 0.02 if up_j else -0.02, -0.16), Vector3(0.3 if up_j else 0.26, 0.38 if up_j else 0.34, 0.14 if up_j else 0.1), BK, Vector3(-90, 0, 0), 8)
		jb.add("box", Vector3(0, -0.05 if up_j else 0.04, -0.14), Vector3(0.22, 0.03, 0.3), MOUTH)
		for k in 5:
			var fx = (k - 2) * 0.045
			var fz = -0.04 - absf(k - 2) * 0.05 - 0.12
			_spike(jb, Vector3(fx, -0.06 if up_j else 0.05, fz), Vector3.DOWN if up_j else Vector3.UP, 0.1 - absf(k - 2) * 0.015, 0.03, FANG)
		var jm = L.mi_of(jb.build(), m)
		jm.material_overlay = ol
		piv.add_child(jm)
		jaws.append([piv, float(q[2])])
	# ön bacaklar: öne uzanan kalın kollar, beyaz pençeler
	var legs = []
	for sx in [-1.0, 1.0]:
		var piv = Node3D.new()
		piv.position = Vector3(0.15 * sx, 0.5, -0.4)
		rig.add_child(piv)
		var lb = MB.new()
		var paw = Vector3(0.02 * sx, -0.46, -0.28)
		_rod(lb, Vector3.ZERO, paw, 0.11, BK)
		lb.add("sphere", paw, Vector3(0.12, 0.07, 0.14), BK, Vector3.ZERO, 8)
		for cl in 3:
			_spike(lb, paw + Vector3((cl - 1) * 0.035, -0.01, -0.05), Vector3((cl - 1) * 0.3, -0.4, -1.0), 0.08, 0.02, FANG)
		var lm = L.mi_of(lb.build(), m)
		lm.material_overlay = ol
		piv.add_child(lm)
		legs.append(piv)
	var p = L.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(rig):
			return false
		var ph = age * 8.0
		rig.position.y = absf(sin(ph)) * 0.25 * s / 2.4
		rig.rotation.x = cos(ph) * 0.14
		for lg in legs:
			lg.rotation.x = sin(ph) * 0.6
		var open = 0.35 + 0.18 * sin(age * 5.0)
		for jw in jaws:
			var pv: Node3D = jw[0]
			pv.rotation.x = open if float(jw[1]) > 0.0 else -open * 1.1
		return true
	root_n.add_child(p)
	return root_n


## Arka yarının yerine geriye akan kara şimşek telleri + gırtlakta çakan beyaz dişli şimşek
static func _panther_wake(pr: Node3D, s: float) -> void:
	var dm = L.dark_mat(Color(0.9, 0.92, 1.0))
	var am = L.arc_mat(WHITE)
	var w = weakref(pr)
	var stt = {"next": 0.0, "dark": [], "white": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		if age > 2.1 or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var o: Vector3 = x.global_position
		var bz: Vector3 = x.global_transform.basis.z.normalized()
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var dark = []
			var rear = o + bz * 0.55 * s + Vector3.UP * (0.5 * s - 0.9)
			for k in 5:
				var e = rear + bz * randf_range(1.5, 3.0) + L.perp(bz) * randf_range(0.3, 1.0) + Vector3.UP * randf_range(-0.2, 0.6)
				L.fork(rear + L.rdir() * 0.25 * s, e, 0.22, 3, 1, dark, 0.09, 1.0)
			stt["dark"] = dark
			var throat = o - bz * 0.72 * s + Vector3.UP * (0.64 * s - 0.9)
			var white = []
			L.fork(throat + bz * 0.15 * s, throat - bz * 0.25 * s + L.rdir() * 0.1, 0.4, 2, 1, white, 0.03, 1.0)
			stt["white"] = white
		L.draw(im, dm, stt["dark"], 1.0, L.cam_pos())
		L.draw(im, am, stt["white"], randf_range(0.6, 1.0), L.cam_pos())
		return true)


static func _ink_bite(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var m = _smat("ink", MODE_SOLID, SH_INK)
	var side = d.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	for q in [1.0, -1.0]:   # iki sıra diş yukarıdan / aşağıdan kapanır
		var b = MB.new()
		for k in 6:
			_spike(b, side * (k - 2.5) * 0.32, Vector3.DOWN * q, 0.6 - absf(k - 2.5) * 0.08, 0.11, Color(0.96, 0.96, 1.0))
			b.add("box", side * (k - 2.5) * 0.32 + Vector3.UP * q * 0.12, Vector3(0.34, 0.24, 0.34), Color(0.03, 0.03, 0.05))
		var mi = L.mi_of(b.build(), m)
		mi.material_overlay = L.line_mat(Color(0.85, 0.86, 0.98), 0.02)
		L.root().add_child(mi)
		mi.global_position = p + Vector3.UP * q * 1.4
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", p + Vector3.UP * q * 0.35, 0.08).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.1)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	var dm = L.dark_mat(Color(0.9, 0.92, 1.0))
	pj.after(0.08, func():
		for k in 8:
			var a = k * TAU / 8.0 + randf_range(-0.2, 0.2)
			L.bolt_m(p, p + Vector3(cos(a) * 3.0, randf_range(0.2, 2.5), sin(a) * 3.0), dm, 0.2, 0.4, 2, 0.2, 0.05)
		L.flash(p, 1.2, Color(1, 1, 1), 0.1, 6.0)
		var g = L.floor_at(p)
		if p.y - g.y < 2.5:
			L.scorch(g, 1.8, Color(0.9, 0.9, 1.0), 4.0, 0.6)
		pj.shake(0.5))


static func _panther_pounce(pj: PathJutsu, c: Node3D, tt: Node3D, from: Vector3, dir: Vector3, id: String, mul: float, s := 2.4) -> Projectile:
	var pan = Node3D.new()
	var pa = _ink_panther(s)
	pa.position.y = -0.9
	pan.add_child(pa)
	dir.y = 0.0
	var fd = dir.normalized()
	# doğuş: önde yerden kara şimşek kümesi fışkırır
	var dm = L.dark_mat(Color(0.9, 0.92, 1.0))
	var g = L.floor_at(from)
	for k in 3:
		L.bolt_m(g + L.hdir() * 0.5, g + Vector3.UP * randf_range(1.8, 2.6) + L.hdir() * 0.6, dm, 0.1, 0.25, 1, 0.2, 0.06, 3)
	var pr = pj.shot(c, from, fd, 24.0, pan, pj.inf(c, id, mul, {"knock": 14.0, "kind": "heavy", "element": "raiton", "stun": 1.5, "hitstop": 0.1}), tt, false, 2.0, func(p, _h):
		_ink_bite(pj, p, fd))
	pr.homing_turn = 4.0
	pr.radius = 1.2
	pr.on_tick = func(p, _dt):
		p.global_position.y = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 0.9
	_panther_wake(pr, s)
	return pr


static func raiton_kuropansa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	L.converge(L.hand_fn(pj, c, true), 1.3, 0.3, Color(0.9, 0.9, 0.95), 12)
	pj.after(0.25, func():
		if pj.live(c):
			var from = pj.gp(c.global_position + c.face_dir() * 1.5) + Vector3.UP * 0.9
			_panther_pounce(pj, c, tt, from, pj.aim_at(c, tt, from), "raiton_kuropansa", 1.6))
	Sfx.play("roar", c.global_position, 1.0)
	Sfx.play("chidori", c.global_position, 0.8)


# ═════════════════════════════════════════ Kusanagi no Tsurugi: Chidorigatana ═════════════════════════════════════════

## Kaynak (Sasuke'nin Chidori kılıcı): gerçek bir katana (gümüş namlu, koyu kabza, yuvarlak tsuba); namlu boyunca
## sarılan, ondan dışa ince dişli teller fışkıran beyaz-mavi akım. Saplamada akım namlunun ucundan 7 m ileri dar, düz,
## dişli bir uzantı olarak uzayıp geri çekilir; delip geçtiği uçta öne iğne gibi şimşekler ve kıvılcım.
static func _katana() -> Node3D:
	var b = MB.new()
	b.add("box", Vector3(0, 0, 0.68), Vector3(0.02, 0.06, 1.1), Color(0.82, 0.86, 0.92))
	b.add("box", Vector3(0, -0.026, 0.68), Vector3(0.022, 0.012, 1.08), Color(0.98, 0.99, 1.0))
	b.add("cone", Vector3(0, 0, 1.26), Vector3(0.02, 0.1, 0.06), Color(0.82, 0.86, 0.92), Vector3(90, 0, 0), 4)
	b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.12, 0.02, 0.12), Color(0.12, 0.1, 0.12), Vector3(90, 0, 0), 12)
	b.add("cyl", Vector3(0, 0, -0.06), Vector3(0.035, 0.26, 0.035), Color(0.2, 0.16, 0.26), Vector3(90, 0, 0), 8)
	var mi = L.mi_of(b.build(), _vc())
	mi.material_overlay = L.line_mat(Color(0.05, 0.05, 0.08), 0.008)
	var n = Node3D.new()
	n.add_child(mi)
	return n


static func _blade_current(blade: Node3D, dur: float) -> void:
	var am = L.arc_mat(RAI)
	var wm = L.arc_mat(WHITE)
	var bw = weakref(blade)
	var stt = {"next": 0.0, "sheath": [], "wires": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = bw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var xf: Transform3D = x.global_transform
		var p0 = xf * Vector3(0, 0, 0.15)
		var p1 = xf * Vector3(0, 0, 1.28)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var sh = []
			for q in 2:
				sh.append({"p": L.jag(p0, p1, 0.04, 4), "w": 0.035, "a": 1.0, "k": 2})
			stt["sheath"] = sh
			var wires = []
			for q in 3:
				if randf() < 0.3:
					continue
				var s = p0.lerp(p1, randf())
				L.fork(s, s + L.rdir() * randf_range(0.3, 0.7), 0.3, 3, 1, wires, 0.02, 1.0)
			stt["wires"] = wires
		L.draw(im, am, stt["sheath"], 1.0, L.cam_pos())
		L.draw(im, wm, stt["wires"], randf_range(0.6, 1.0), L.cam_pos())
		return true)


static func _katana_lunge(from: Vector3, d: Vector3) -> void:
	var fm = _fang(RAI, EDGE, 0.55)
	var am = L.arc_mat(RAI)
	var stt = {"next": 0.0, "main": [], "wires": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.32:
			return false
		var ext = 7.0 * clampf(age / 0.05, 0.0, 1.0)
		var back = 7.0 * clampf((age - 0.18) / 0.14, 0.0, 1.0)   # ileri uzar, uçtan geri çekilir
		var s0 = from + d * 0.8
		var tip = from + d * maxf(0.9, ext - back)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.03
			stt["main"] = [{"p": L.zigzag(tip, s0, 7, 0.06), "w": 0.075, "a": 1.0, "k": 1}]
			var wires = []
			for q in 2:
				wires.append({"p": L.jag(tip, s0, 0.08, 4), "w": 0.022, "a": 1.0})
			stt["wires"] = wires
		L.draw(im, fm, stt["main"], 1.0, L.cam_pos())
		L.draw(im, am, stt["wires"], randf_range(0.6, 1.0), L.cam_pos())
		return true)


static func _katana_pierce(p: Vector3, d: Vector3) -> void:
	L.flash(p, 0.9, RAI, 0.08, 6.0)
	L.light(p, RAI, 2.0, 6.0, 0.12)
	L.sparks(p, 18, WHITE, 12.0, 0.3, d, 0.35)
	for k in 5:
		L.bolt(p, p + (d + L.rdir() * 0.4).normalized() * randf_range(1.0, 2.0), WHITE, 0.03, 0.15, 0, 0.2, 0.05, 3)


static func kusanagi_no_tsurugi_chidorigatana(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	var d = pj._jump_at(c, tt, 0.0, 16.0 if tt else 4.0)
	pj.busy(c, 0.7)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var blade = _katana()
		ba.add_child(blade)
		_blade_current(blade, 0.7)
		pj.free_after(0.7, ba)
	else:
		L.crackle(L.hand_fn(pj, c), 0.4, 0.7, RAI, 4, 0.03)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_a", 1.8)
		var from = c.global_position + Vector3.UP * 1.2
		_katana_lunge(from, d)
		Combat.hit_zone(c, c.global_position, d, 7.5, 12.0, 2.5, pj.inf(c, "kusanagi_no_tsurugi_chidorigatana", 1.6, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
		_katana_pierce(from + d * 6.0, d)
		L.wet_shock(from + d * 6.0, 1.0)
		pj.shake(0.5)
		Sfx.play("chidori", from, 1.4))


# ═════════════════════════════════════════ Raiton: Raiga ═════════════════════════════════════════

## Kaynak (Raiga'nın kılıçları): atanın iki elinden yukarı çapraz kesişen iki şimşek (çarpı kılıçlar) göğe yükselir;
## hedefin 14 m üstünde koyu arduvaz bir cel fırtına bulutu toplanır, içi kesik kesik mavi aydınlanır. Ardından buluttan
## yere, tepesi geniş ucu sivri kalın bir "diş" yıldırım iner (+ iki ince yıldırım); yerde kalın köşeli şimşek dalları
## dışa yayılır, çakma, kıvılcım, toz halkası, yanık. Bulut çakışta bembeyaz parlar, sonra küçülerek dağılır.
static func _crossed_swords(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hr = L.hand_fn(pj, c, true)
	var hl = L.hand_fn(pj, c, false)
	var cf = L.follow_fn(c)
	var side = c.face_dir().cross(Vector3.UP).normalized()
	L.bolt(hr, func() -> Vector3: return Vector3(cf.call()) + Vector3.UP * 4.2 - side * 1.6, WHITE, 0.07, dur, 2, 0.16, 0.05)
	L.bolt(hl, func() -> Vector3: return Vector3(cf.call()) + Vector3.UP * 4.2 + side * 1.6, WHITE, 0.07, dur, 2, 0.16, 0.05)
	L.crackle(hr, 0.35, dur, RAI, 3, 0.03)
	L.crackle(hl, 0.35, dur, RAI, 3, 0.03)


static func _storm_cloud(pos: Vector3, wait: float) -> void:
	var m = _smat("cloud", MODE_SOLID, SH_CLOUD, {"flash": 0.0})
	var b = MB.new()
	for k in 9:
		var a = randf() * TAU
		var r = randf_range(0.0, 3.0) if k > 0 else 0.0
		b.add("sphere", Vector3(cos(a) * r, randf_range(-0.3, 0.4), sin(a) * r), Vector3(randf_range(2.4, 3.6), randf_range(1.2, 1.8), randf_range(2.4, 3.6)), Color.WHITE, Vector3.ZERO, 8)
	var mi = L.mi_of(b.build(), m)
	mi.material_overlay = L.line_mat(Color(0.04, 0.04, 0.08), 0.06)
	var holder = Node3D.new()
	holder.add_child(mi)
	L.root().add_child(holder)
	holder.global_position = pos
	holder.scale = Vector3.ONE * 0.15
	var stt = {"next": 0.0}
	var p = L.Pulse.new()
	p.fn = func(_node, dt, age) -> bool:
		if not is_instance_valid(holder):
			return false
		holder.rotate_y(dt * 0.8)
		if age < 0.4:
			holder.scale = Vector3.ONE * lerpf(0.15, 1.0, 1.0 - pow(1.0 - age / 0.4, 2.0))
		if age < wait:
			if age >= float(stt["next"]):
				stt["next"] = age + 0.08
				m.set_shader_parameter("flash", randf_range(0.0, 0.55) if randf() < 0.5 else 0.0)
		elif age < wait + 0.6:
			m.set_shader_parameter("flash", 1.0 - (age - wait) / 0.6)
		elif age < wait + 1.1:
			holder.scale = Vector3.ONE * maxf(0.02, 1.0 - (age - wait - 0.6) / 0.5)
		else:
			holder.queue_free()
			return false
		return true
	holder.add_child(p)


static func _fang_strike(at: Vector3) -> void:
	var fm = _fang(RAI, EDGE, 0.42)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.4:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			stt["polys"] = [{"p": L.jag(at + Vector3.UP * 0.1, at + Vector3.UP * 13.5, 0.12, 5), "w": 0.55, "a": 1.0, "k": 1}]
		L.draw(im, fm, stt["polys"], clampf((0.4 - age) / 0.15, 0.0, 1.0), L.cam_pos())
		return true)
	for k in 2:
		L.bolt(at + Vector3(randf_range(-2, 2), 13.5, randf_range(-2, 2)), at + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2)), Color(0.8, 0.9, 1.0), 0.12, 0.3, 3, 0.18, 0.05)
	var gm = _fang(RAI, EDGE, 0.42)
	var branches = []
	for k in 6:
		var e = at + L.hdir() * randf_range(3.0, 5.0)
		branches.append(L.ground_path(at, e, 0.3, 3, 0.08))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.5:
			return false
		var polys = []
		var grow = clampf(age / 0.08, 0.0, 1.0)
		for pts in branches:
			polys.append({"p": pts.slice(0, maxi(2, int(ceil(pts.size() * grow)))), "w": 0.13, "a": 1.0, "k": 0})
		L.draw(im, gm, polys, clampf((0.5 - age) / 0.2, 0.0, 1.0), L.cam_pos(), true)
		return true)
	L.flash(at + Vector3.UP * 0.6, 1.6, RAI, 0.12, 10.0)
	L.light(at + Vector3.UP * 2.0, Color(0.6, 0.8, 1.0), 5.0, 14.0, 0.25)
	L.sparks(at + Vector3.UP * 0.3, 30, WHITE, 13.0, 0.4)
	L.scorch(at, 2.6, RAI, 6.0, 1.4)
	L.dust_ring(at, 0.6, 4.0, 0.6, DUST)


static func raiton_raiga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	_crossed_swords(pj, c, 0.55)
	_storm_cloud(at + Vector3.UP * 14.0, 0.5)
	pj.after(0.5, func():
		_fang_strike(at)
		L.wet_shock(at + Vector3.UP * 0.5, 1.8)
		pj.hit(c, at + Vector3.UP, 3.5, pj.inf(c, "raiton_raiga", 1.8, {"knock": 8.0, "launch": 4.0, "kind": "heavy", "element": "raiton", "stun": 1.0}))
		pj.shake(0.7))
	Sfx.play("thunder", at, 0.7)


# ═════════════════════════════════════════ Raiton Sutorēto ═════════════════════════════════════════

## Kendi tasarım (Raikage düz yumruğu, taijutsu): ışık değil basınç. Yumrukta küçük beyaz çakma; önündeki dar koni boyunca
## 8 m ileri fırlayan beyaz hız çizgileri; yerde yumruğun önünden ileri açılan iki sürtünme oluğu, öne savrulan toz
## şeritleri ve taşlar; zırhtan öne birkaç mavi kıvılcım.
static func _straight_blast(at: Vector3, d: Vector3) -> void:
	L.flash(at, 1.0, WHITE, 0.07, 6.0)
	L.sparks(at, 10, RAIKAGE, 10.0, 0.25, d, 0.4)
	var wm = _ink(Color(1, 1, 1))
	var u = d.cross(Vector3.UP).normalized()
	var ls = []
	for k in 16:
		ls.append({"a": randf() * TAU, "r": randf_range(0.3, 1.0), "x": randf_range(0.0, 1.5), "l": randf_range(1.2, 2.2)})
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.3:
			return false
		var polys = []
		for s in ls:
			var x = float(s["x"]) + age * 30.0
			if x > 8.0:
				continue
			var ang = float(s["a"])
			var rr = float(s["r"]) * (0.2 + x * 0.12)
			var o = at + d * x + (u * cos(ang) + Vector3.UP * sin(ang)) * rr
			polys.append({"p": _seg(o, o + d * float(s["l"])), "w": 0.025, "a": 1.0, "k": 3})
		L.draw(im, wm, polys, 1.0 - age / 0.3, L.cam_pos())
		return true)
	var g = L.floor_at(at)
	if at.y - g.y > 2.5:
		return
	var dm = _ink(Color(0.1, 0.09, 0.08, 0.85))
	var furrows = []
	for sx in [-1.0, 1.0]:
		furrows.append(L.ground_path(g + u * sx * 0.45, g + d * 6.5 + u * sx * 0.9, 0.05, 3, 0.05))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 3.0:
			return false
		var grow = clampf(age / 0.12, 0.0, 1.0)
		var polys = []
		for pts in furrows:
			polys.append({"p": pts.slice(0, maxi(2, int(ceil(pts.size() * grow)))), "w": 0.08, "a": 1.0, "k": 0})
		L.draw(im, dm, polys, clampf((3.0 - age) / 0.8, 0.0, 1.0), L.cam_pos(), true)
		return true)
	var sm = L.dust_mat(DUST)
	var fan = []
	for k in 6:
		fan.append((d + u * randf_range(-0.35, 0.35)).normalized())
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.6:
			return false
		var f = age / 0.6
		var polys = []
		for dv in fan:
			var s0 = g + Vector3(dv) * (1.0 + f * 5.0)
			var e0 = s0 + Vector3(dv) * (1.2 + f * 1.5)
			polys.append({"p": [Vector3(s0.x, Game.jutsu_floor(s0.x, s0.z) + 0.2, s0.z), Vector3(e0.x, Game.jutsu_floor(e0.x, e0.z) + 0.25, e0.z)], "w": 0.3 + f * 0.4, "a": 1.0, "k": 2})
		L.draw(im, sm, polys, 1.0 - f, L.cam_pos(), true)
		return true)
	L.debris(g + d * 1.5, 8, 7.0, DUST.darkened(0.3), d * 0.8)


static func raiton_sutoreeto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_rai_armor(c, 1.0)
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 14.0)
	var d = pj._jump_at(c, tt, 0.4, 16.0)
	L.speed_lines(c, d, 0.25, WHITE, 8)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.2
		_straight_blast(at, d)
		L.wet_shock(at, 1.6)
		Combat.hit_zone(c, c.global_position, d, 8.0, 20.0, 2.5, pj.inf(c, "raiton_sutoreeto", 2.0, {"knock": 22.0, "kind": "heavy", "element": "raiton", "stun": 0.6, "hitstop": 0.12}))
		pj.shake(0.7))
	Sfx.play("thunder", c.global_position, 1.4)


# ═════════════════════════════════════════ Doroppu Kikku ═════════════════════════════════════════

## Kendi tasarım (Raikage iki ayaklı uçan tekmesi, taijutsu): sıçrayış boyunca iki ayaktan iki paralel beyaz iz; çarpışta
## tekme yönüne dik düzlemde dışa fırlayan anime darbe çizgileri, küçük sıcak beyaz çakma, tek kısa mavi kıvılcım;
## yere yakınsa çatlak, toz halkası, taşlar. Rakip vurulduysa savrulduğu yöne geriye akan hız çizgileri.
static func _boot_trails(c: Node3D, dur: float) -> void:
	var m = _ink(Color(1, 1, 1))
	var cw = weakref(c)
	var pts = [[], []]
	L.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur + 0.2:
			return false
		if age < dur and x != null and is_instance_valid(x) and x.is_inside_tree():
			var side = x.face_dir().cross(Vector3.UP).normalized()
			for q in 2:
				(pts[q] as Array).append({"p": x.global_position + Vector3.UP * 0.45 + side * (0.16 if q == 0 else -0.16), "t": age})
		var polys = []
		for q in 2:
			var arr: Array = pts[q]
			while arr.size() > 0 and age - float(arr[0]["t"]) > 0.2:
				arr.pop_front()
			if arr.size() >= 2:
				var line = []
				for s in arr:
					line.append(s["p"])
				polys.append({"p": line, "w": 0.05, "a": 0.9, "k": 1})
		L.draw(im, m, polys, 1.0, L.cam_pos())
		return true)


static func _kick_impact(pj: PathJutsu, c: Node3D, at: Vector3) -> void:
	_strokes(at, c.face_dir(), 16, 0.3, 2.8, 0.18, Color(1, 1, 1), 0.04)
	L.flash(at, 1.0, Color(1.0, 0.97, 0.9), 0.07, 6.0)
	L.zig_bolt(at, at + Vector3(randf_range(-1.5, 1.5), 0.8, randf_range(-1.5, 1.5)), RAI, 0.04, 0.15, 4, 0.25)
	var g = L.floor_at(at)
	if at.y - g.y < 2.5:   # eski _tai_impact(s 1.4): 3.08 m çatlak (yarık zemin bölgesi), toz
		_cracks(g, 3.08, 3.0, 6.0)
		L.dust_ring(g, 0.4, 3.0, 0.6, DUST)
		L.debris(g, 6, 6.0)
	pj.shake(0.35)


static func _kick_knock(p: Vector3, f: Vector3) -> void:
	var m = _ink(Color(1, 1, 1))
	var ls = []
	for k in 6:
		ls.append(L.perp(f) * randf_range(0.2, 0.7))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.25:
			return false
		var polys = []
		for o in ls:
			var s = p + Vector3(o) + f * age * 10.0
			polys.append({"p": _seg(s - f * 1.6, s), "w": 0.025, "a": 1.0, "k": 3})
		L.draw(im, m, polys, 1.0 - age / 0.25, L.cam_pos())
		return true)


static func doroppu_kikku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 0.7)
	_rai_armor(c, 0.8)
	pj._jump_at(c, tt, 3.0, 18.0 if tt else 4.0)
	_boot_trails(c, 0.32)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP + c.face_dir()
		_kick_impact(pj, c, at)
		var hs = pj.hit(c, at, 2.0, pj.inf(c, "doroppu_kikku", 1.5, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
		if not hs.is_empty() and is_instance_valid(hs[0]):
			_kick_knock(hs[0].global_position + Vector3.UP, c.face_dir())
		Sfx.play("punch", at, 0.8))
