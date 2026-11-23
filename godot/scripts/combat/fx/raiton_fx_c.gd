class_name RaitonFXC
extends RefCounted
## Raiton C grubu: 15 tekniğin görseli ve taşınmış oynanışı. Malzeme / yapı taşı RaitonLib'den; her tekniğin şekli,
## hareketi ve sahnelenmesi kendine özgü (A / B gruplarının kompozisyonları kullanılmaz). Oynanış (hasar çağrıları,
## durumlar, süreler, menzil, mermi davranışı) ana ağaçtaki PathJutsu gövdelerinden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/raiton_lib.gd")   # sınıf adı sabit ifade sayılmıyor
const RAI := Color(0.65, 0.85, 1.0)
const EMAG := Color(0.55, 0.8, 1.0)
const RAIKAGE := Color(0.45, 0.7, 1.0)
const PURPLE := Color(0.75, 0.5, 1.0)
const GOLD := Color(1.0, 0.9, 0.5)
const WHITE := Color(0.92, 0.96, 1.0)
const BEDGE := Color(0.9, 0.92, 1.0)
const GIAN := Color(0.6, 0.8, 1.0)

static var _shc := {}
static var _mc := {}


# ═════════════════════════════════════════ kendi gölgelendiricilerim ═════════════════════════════════════════

## Şimşek klonunun derisi: klonun kendi örgüsüne bindirilen soluk camgöbeği cel yıkama, beyaz kontur bandı ve
## birkaç karede bir yer değiştiren beyaz damarlar (kaynak: bedeni beyaz-mavi parlayan klon)
const SH_CLONE := """
uniform vec4 glow : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform float power = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 14.0);
	float n = rn3(lp * 5.0 + vec3(st * 0.37, st * 0.71, -st * 0.23));
	float vein = 1.0 - smoothstep(0.0, 0.04, abs(n - 0.5));
	float band = step(0.55, fr);
	vec3 col = mix(glow.rgb * 1.15, vec3(0.95, 0.98, 1.0), band);
	col = mix(col, vec3(1.0), vein);
	ALBEDO = col;
	ALPHA = clamp(0.5 + band * 0.4 + vein * 0.4, 0.0, 1.0) * power;
}
"""
const MODE_CLONE := "render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;"

## Kara panter gövdesi (kaynak: Darui'nin Kuro Pansā'sı): opak kömür siyahı, kenarda ince beyaz kontur, gövdede
## birkaç karede bir yer değiştiren beyaz şimşek damarları; köşe rengi bölgeyi verir (ağız içi mor, diş / göz beyaz)
const SH_PANTHER := """
uniform vec4 edge_col : source_color = vec4(0.92, 0.94, 1.0, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 16.0);
	float n = rn3(lp * 3.4 + vec3(st * 0.41, -st * 0.29, st * 0.63));
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
	float rim = smoothstep(0.6, 0.68, fr);
	float dark = 1.0 - step(0.25, dot(COLOR.rgb, vec3(0.333)));
	vec3 col = COLOR.rgb;
	col = mix(col, edge_col.rgb * 1.25, max(rim * 0.95, vein * dark * 0.85));
	ALBEDO = col;
}
"""
const MODE_PANTHER := "render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;"

## Gökten inen ışık sütunu (Tenrai): beyaz öz, kenara doğru mavi, aşağı akan dikey çizgiler (toplamalı)
const SH_COLUMN := """
uniform vec4 glow : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform float power = 1.0;
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 20.0);
	float n = rn2(vec2(UV.x * 14.0 + st * 0.3, UV.y * 3.0 + TIME * 30.0));
	float streak = step(0.62, n);
	float core = 1.0 - smoothstep(0.25, 0.6, fr);
	ALBEDO = (glow.rgb * (0.5 + fr * 0.9) + vec3(1.0) * (core * 1.1 + streak * 0.5)) * power;
}
"""
const MODE_COLUMN := "render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;"

## Şimşek yüklü su (Raisuiryūdan ejderi): koyu / orta mavi cel bölgeler, akan beyaz köpük, kenarda açık köpük bandı,
## suyun içinden birkaç karede bir çakan beyaz şimşek damarları
const SH_WATER := """
uniform vec4 deep : source_color = vec4(0.04, 0.27, 0.74, 1.0);
uniform vec4 mid : source_color = vec4(0.2, 0.55, 0.98, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float power = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float n = rn3(wp * 1.2 + vec3(0.0, -TIME * 2.2, TIME * 1.6));
	float n2 = rn3(wp * 2.8 - vec3(TIME * 1.9, 0.0, TIME * 1.1));
	vec3 col = mix(deep.rgb, mid.rgb, step(0.47, n));
	col = mix(col, foam.rgb, step(0.82, n2 * 0.55 + fr * 0.6));
	float st = floor(TIME * 14.0);
	float v = 1.0 - smoothstep(0.0, 0.028, abs(rn3(wp * 1.6 + vec3(st * 0.31, st * 0.17, st * 0.43)) - 0.5));
	col = mix(col, vec3(0.92, 0.98, 1.0) * 1.35, v * 0.85);
	col = mix(col, vec3(0.02, 0.08, 0.25), step(0.86, fr));   // koyu cel kontur
	ALBEDO = col * power;
}
"""
const MODE_WATER := "render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;"


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


## Özü kalın şimşek şeridi (beyaz öz oranı thin ile)
static func _thick_arc(col: Color, thin: float) -> ShaderMaterial:
	var key = "tarc_%s_%.2f" % [col.to_html(), thin]
	if not _mc.has(key):
		_mc[key] = L.mat("arc", {"glow": col, "thin": thin})
	return _mc[key]


## Düz renk (köşe saydamlığıyla söner): yer çatlağı çizgileri
static func _flat_mat(col: Color) -> StandardMaterial3D:
	var key = "flat_" + col.to_html()
	if not _mc.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mc[key] = m
	return _mc[key]


## Köşe renkli ışıksız malzeme (raydaki parlak şeritler, göz / diş)
static func _vc_mat() -> StandardMaterial3D:
	if not _mc.has("vc"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_mc["vc"] = m
	return _mc["vc"]


static func _near_ground(p: Vector3, h := 2.5) -> bool:
	return p.y - Game.jutsu_floor_at(p).y < h


static func _safe(n) -> Node3D:
	return n if L.alive(n) else null


# ═════════════════════════════════════════ Raiton Kage Bunshin ═════════════════════════════════════════

## Kaynak: bedeni baştan aşağı soluk camgöbeği parlayan, kenarları beyaz dişli şimşekle çizilen klon. Klon, atandan
## yana sıçrayan bir chakra şeridi ve tepeden düşen tek bir yıldırımla belirir; derisi şimşek yıkamalı, üstünde
## sürünen arklar. Dağılınca beden boşalır: sekiz kalın şimşek dışa kavis çizip yere saplanır, uçlarında küçük yanıklar.
static func _clone_skin(d: Node3D) -> void:
	if not L.alive(d):
		return
	var m = _smat("clone", MODE_CLONE, SH_CLONE, {"glow": EMAG, "power": 0.0})
	var tw = d.create_tween()
	tw.tween_property(m, "shader_parameter/power", 1.0, 0.25)
	# model birkaç karede kurulabilir: ilk 2 sn içinde yeni beliren örgülere de bindir
	var stt = {"next": 0.0}
	var p = L.Pulse.new()
	p.fn = func(_n, _dt, age) -> bool:
		if age >= float(stt["next"]):
			stt["next"] = age + 0.2
			for mi in d.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).material_overlay == null:
					(mi as MeshInstance3D).material_overlay = m
		return age < 2.0
	d.add_child(p)


static func _clone_discharge(pj: PathJutsu, c: Node3D, pos: Vector3) -> void:
	var core = pos + Vector3.UP
	L.flash(core, 4.2, WHITE, 0.22, 14.0)
	L.light(core, EMAG, 9.0, 12.0, 0.35)
	for k in 8:
		var a = k * TAU / 8.0 + randf_range(-0.25, 0.25)
		var g = L.floor_at(pos + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 3.2))
		var mid = core.lerp(g, 0.5) + Vector3.UP * randf_range(0.8, 1.6)
		L.bolt(core, mid, RAI, 0.14, 0.32, 1, 0.2, 0.05)
		L.bolt(mid, g, RAI, 0.12, 0.32, 1, 0.2, 0.05)
		L.scorch(g, 0.6, RAI, 3.5, 0.6)
	L.crackle(core, 1.5, 0.35, WHITE, 7, 0.05, 0.04)
	L.sparks(core, 30, EMAG, 12.0, 0.5)
	L.ground_arcs(L.floor_at(pos), 3.2, 0.6, RAI, 8)
	for e in pj.hit(c, pos + Vector3.UP, 4.0, pj.inf(c, "raiton_kage_bunshin_no_jutsu", 1.2, {"knock": 6.0, "kind": "heavy", "element": "raiton"})):
		pj.st(e, "stun", 2.0)
		L.body_arcs(e, 2.0, RAI, 4, 0.035)


static func kage_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 2.5)
	L.bolt(L.follow_fn(c, Vector3.UP * 1.1), at + Vector3.UP * 1.0, RAI, 0.08, 0.2, 1, 0.25, 0.04)
	L.bolt(at + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6)), at, WHITE, 0.22, 0.22, 2, 0.16, 0.05)
	L.flash(at + Vector3.UP * 0.9, 2.2, EMAG, 0.18, 11.0)
	L.ground_arcs(at, 1.2, 0.5, RAI, 5, 0.04)
	L.light(at + Vector3.UP, EMAG, 5.0, 8.0, 0.3)
	var d = pj.decoy(c, at, 10.0, func(pos):
		_clone_discharge(pj, c, pos))
	if d:
		d.set_meta("no_smoke", true)   # dağılınca duman değil, kendi boşalması
		_clone_skin(d)
		L.body_arcs(d, 10.0, RAI, 3, 0.03)
		L.crackle(L.follow_fn(d, Vector3.UP * 1.0), 0.8, 10.0, WHITE, 3, 0.025, 0.09, d)
	Sfx.play("chidori", at, 1.2)


# ═════════════════════════════════════════ Raiton: Jibashi ═════════════════════════════════════════

## Kaynak: önü mora boyayan, iç içe geçmiş, her yöne kıvrılan yoğun beyaz şimşek yumağı. Elde mor kıvılcımlar toplanır;
## sonra elden ileri genişleyen bir koridorda dilim dilim rastgele düğümler, düğümler arasında birbirine dolanan mor
## hâleli beyaz şimşekler (her 0.05 sn yeniden örülür), arkada soluk mor yıkama; bitince yol boyunca mor çatlaklı yanık.
static func _jibashi_mass(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float) -> void:
	var mp = _thick_arc(PURPLE, 0.18)
	var mw = L.arc_mat(WHITE)
	var haze = L.arc_mat(Color(0.45, 0.25, 0.75))
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var stt = {"next": 0.0, "pp": [], "pw": [], "hz": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur + 0.15 or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var from: Vector3 = pj.live_hand(x, true)
			var tgt = tw.get_ref() if tw else null
			var d: Vector3 = pj.aim_at(x, tgt if L.alive(tgt) else null, from)
			var side = d.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
			var up = side.cross(d).normalized()
			var prev = [from]
			var pp = []
			var pw = []
			for s in range(1, 9):
				var f = float(s) / 8.0
				var rad = 0.25 + f * 2.6
				var cur = []
				for q in 3:
					var a = randf() * TAU
					var r = rad * sqrt(randf())
					cur.append(from + d * (20.0 * f + randf_range(-0.8, 0.8)) + side * cos(a) * r + up * sin(a) * r * 0.75)
				for p0 in prev:
					for k in 2:
						var line = L.jag(p0, cur[randi() % cur.size()], 0.22, 3)
						pp.append({"p": line, "w": 0.16, "a": randf_range(0.55, 1.0)})
						pw.append({"p": line, "w": 0.05, "a": 1.0})
				if randf() < 0.8:
					var l2 = L.jag(cur[0], cur[1 + randi() % 2], 0.3, 3)
					pp.append({"p": l2, "w": 0.1, "a": 0.7})
					pw.append({"p": l2, "w": 0.03, "a": 0.9})
				prev = cur
			stt["pp"] = pp
			stt["pw"] = pw
			stt["hz"] = [{"p": [from, from + d * 10.0, from + d * 20.0], "w": 2.4, "a": 0.18, "k": 1}]
		var fade = clampf((dur + 0.15 - age) / 0.2, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, haze, stt["hz"], fade, cam)
		L.draw(im, mp, stt["pp"], fade, cam)
		L.draw(im, mw, stt["pw"], fade, cam)
		return true)


static func jibashi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 22.0)
	var hf = L.hand_fn(pj, c)
	L.converge(hf, 1.4, 0.24, PURPLE, 14, 0.025)
	L.crackle(hf, 0.3, 0.3, PURPLE, 4, 0.03, 0.05)
	var stt = {"on": false}
	pj.every(1.0, 0.06, func(i, _k):
		if not pj.live(c) or i < 4:
			return
		var from = pj.hand_pos(c, true)
		if not stt["on"]:
			stt["on"] = true
			_jibashi_mass(pj, c, tt, 0.74)
			L.light(from, PURPLE, 6.0, 12.0, 0.8)
		if i == 14:
			var d = pj.aim_at(c, _safe(tt), from)
			for k in 3:
				var q = from + d * (5.0 + k * 6.0)
				if _near_ground(q, 3.0):
					L.scorch(L.floor_at(q), 1.0 + k * 0.4, PURPLE, 4.0, 0.8)
		if i % 3 == 0:
			Combat.hit_zone(c, c.global_position, pj.aim_at(c, _safe(tt), from), 20.0, 6.0, 3.0, pj.inf(c, "raiton_jibashi", 0.3, {"knock": 4.0, "kind": "light", "element": "raiton", "stun": 0.3})), Callable())
	Sfx.play("thunder", c.global_position, 0.9)


# ═════════════════════════════════════════ Kuro Pansā / Daburu Kuropansā ═════════════════════════════════════════

## Kaynak: kara şimşekten panter — opak siyah gövde, beyaz kontur, gövdede beyaz şimşek damarları, açık çenede mor
## ağız içi ve beyaz sivri dişler, parlak gözler. Sıçrayarak koşar (ön / arka bacak çiftleri karşı evrede, omurga
## esner), çene kükreyerek açılır kapanır, kuyruk yukarı kıvrılıp sallanır; sırtından ve kuyruğundan kara şimşek
## saçakları geriye akar, bastığı yerde kara yanık.
static func _panther(s: float, eye: Color, edge: Color) -> Node3D:
	var m = _smat("panther", MODE_PANTHER, SH_PANTHER, {"edge_col": edge})
	var BK = Color(0.035, 0.03, 0.06)
	var MOUTH = Color(0.36, 0.3, 0.58)
	var FANG = Color(0.95, 0.95, 1.0)
	var root_n = Node3D.new()
	var rig = Node3D.new()
	rig.scale = Vector3.ONE * s
	root_n.add_child(rig)
	var body = Node3D.new()
	rig.add_child(body)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.5, 0.02), Vector3(0.4, 0.34, 1.05), BK, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.53, -0.36), Vector3(0.46, 0.44, 0.52), BK, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.5, 0.4), Vector3(0.4, 0.38, 0.44), BK, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.62, -0.62), Vector3(0.26, 0.28, 0.34), BK, Vector3(-25, 0, 0), 10)
	body.add_child(L.mi_of(b.build(), m))
	# baş + üst çene
	var head = Node3D.new()
	head.position = Vector3(0, 0.68, -0.8)
	body.add_child(head)
	var hb = MB.new()
	hb.add("sphere", Vector3(0, 0.02, 0), Vector3(0.3, 0.25, 0.3), BK, Vector3.ZERO, 12)
	hb.add("box", Vector3(0, -0.01, -0.2), Vector3(0.19, 0.1, 0.22), BK, Vector3(8, 0, 0))
	hb.add("box", Vector3(0, -0.07, -0.19), Vector3(0.16, 0.035, 0.2), MOUTH)
	hb.add("cone", Vector3(0.1, 0.15, 0.03), Vector3(0.08, 0.13, 0.06), BK, Vector3(-10, 0, -15), 5)
	hb.add("cone", Vector3(-0.1, 0.15, 0.03), Vector3(0.08, 0.13, 0.06), BK, Vector3(-10, 0, 15), 5)
	hb.add("sphere", Vector3(0.085, 0.05, -0.13), Vector3(0.07, 0.035, 0.05), eye, Vector3(0, 0, -15), 8)
	hb.add("sphere", Vector3(-0.085, 0.05, -0.13), Vector3(0.07, 0.035, 0.05), eye, Vector3(0, 0, 15), 8)
	for sx in [-1.0, 1.0]:
		hb.add("cone", Vector3(0.06 * sx, -0.11, -0.28), Vector3(0.035, 0.09, 0.035), FANG, Vector3(180, 0, 0), 5)
		hb.add("cone", Vector3(0.035 * sx, -0.09, -0.22), Vector3(0.02, 0.05, 0.02), FANG, Vector3(180, 0, 0), 4)
	head.add_child(L.mi_of(hb.build(), m))
	# alt çene
	var jaw = Node3D.new()
	jaw.position = Vector3(0, -0.07, -0.05)
	head.add_child(jaw)
	var jb = MB.new()
	jb.add("box", Vector3(0, -0.035, -0.14), Vector3(0.16, 0.05, 0.24), BK)
	jb.add("box", Vector3(0, -0.005, -0.13), Vector3(0.13, 0.02, 0.2), MOUTH)
	for sx in [-1.0, 1.0]:
		jb.add("cone", Vector3(0.055 * sx, 0.03, -0.23), Vector3(0.03, 0.07, 0.03), FANG, Vector3.ZERO, 5)
	jaw.add_child(L.mi_of(jb.build(), m))
	# bacaklar: kalça / diz mafsalı
	var ub = MB.new()
	ub.add("cyl", Vector3(0, -0.12, 0), Vector3(0.13, 0.26, 0.13), BK, Vector3.ZERO, 8)
	ub.add("sphere", Vector3.ZERO, Vector3(0.16, 0.16, 0.16), BK, Vector3.ZERO, 8)
	var lb = MB.new()
	lb.add("cyl", Vector3(0, -0.11, 0), Vector3(0.09, 0.24, 0.09), BK, Vector3.ZERO, 8)
	lb.add("sphere", Vector3(0, -0.24, -0.04), Vector3(0.13, 0.07, 0.17), BK, Vector3.ZERO, 8)
	var um = ub.build()
	var lm = lb.build()
	var legs = []
	for q in [[0.14, -0.4, 0.0], [-0.14, -0.4, 0.35], [0.14, 0.42, PI], [-0.14, 0.42, PI + 0.35]]:
		var hip = Node3D.new()
		hip.position = Vector3(q[0], 0.48, q[1])
		body.add_child(hip)
		hip.add_child(L.mi_of(um, m))
		var knee = Node3D.new()
		knee.position = Vector3(0, -0.24, 0)
		hip.add_child(knee)
		knee.add_child(L.mi_of(lm, m))
		legs.append([hip, knee, float(q[2]), float(q[1]) < 0.0])
	# kuyruk: üç zincirli parça
	var tb = MB.new()
	tb.add("cyl", Vector3(0, 0, 0.17), Vector3(0.07, 0.36, 0.07), BK, Vector3(90, 0, 0), 6)
	var tm = tb.build()
	var tail = []
	var par: Node3D = body
	var p0 = Vector3(0, 0.56, 0.6)
	for k in 3:
		var sg = Node3D.new()
		sg.position = p0
		par.add_child(sg)
		sg.add_child(L.mi_of(tm, m))
		tail.append(sg)
		par = sg
		p0 = Vector3(0, 0, 0.34)
	var p = L.Pulse.new()
	p.fn = func(_n, _dt, age) -> bool:
		if not is_instance_valid(body):
			return false
		var ph = age * 10.0
		body.rotation.x = sin(ph) * 0.12
		body.position.y = absf(sin(ph)) * 0.12
		for lg in legs:
			var hip: Node3D = lg[0]
			var knee: Node3D = lg[1]
			var a = ph + float(lg[2])
			hip.rotation.x = sin(a) * 0.9
			knee.rotation.x = maxf(0.0, -cos(a)) * 0.9 * (-1.0 if lg[3] else 1.0)
		var roar = pow(maxf(0.0, sin(age * 3.2)), 3.0)
		jaw.rotation.x = -(0.15 + roar * 0.6)
		head.rotation.x = roar * 0.15
		for k in tail.size():
			var sg: Node3D = tail[k]
			sg.rotation.x = (-0.45 if k == 0 else 0.3) + sin(ph - k * 0.8) * 0.2
			sg.rotation.y = sin(age * 4.0 - k * 0.9) * 0.3
		return true
	root_n.add_child(p)
	return root_n


## Sırttan / kuyruktan geriye akan kara şimşek saçakları, gövdede ince beyaz çatırtı, patilerin altında kara yanık
static func _panther_aura(pj: PathJutsu, pr: Node3D, s: float) -> void:
	var dm = L.dark_mat(BEDGE)
	var w = weakref(pr)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		if age > 2.2 or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var o: Vector3 = x.global_position + Vector3.DOWN * 0.9
			var back: Vector3 = x.global_transform.basis.z
			back.y = 0.0
			back = back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
			var out = []
			for k in 4:
				var sp = o + Vector3.UP * 0.62 * s + back * randf_range(-0.6, 0.7) * s
				var e = sp + back * randf_range(0.4, 1.1) * s + Vector3.UP * randf_range(0.2, 0.7) * s + L.perp(back) * randf_range(-0.3, 0.3) * s
				L.fork(sp, e, 0.3, 3, 1, out, 0.07 * s, 1.0)
			var tp = o + Vector3.UP * 0.6 * s + back * 1.1 * s
			L.fork(tp, tp + back * 1.6 * s + Vector3.UP * randf_range(-0.2, 0.6), 0.25, 4, 1, out, 0.06 * s, 1.0)
			stt["polys"] = out
		L.draw(im, dm, stt["polys"], 1.0, L.cam_pos())
		return true)
	L.crackle(L.follow_fn(pr, Vector3.DOWN * 0.3), 0.45 * s, 2.0, WHITE, 3, 0.02, 0.07, pr)
	pj.every(2.0, 0.16, func(_i, _k):
		if L.alive(pr):
			var g = L.floor_at(pr.global_position)
			L.scorch(g + L.hdir() * 0.3 * s, 0.32 * s, BEDGE, 2.0, 0.3), Callable())


## Pençe izi: kameraya dönük düzlemde, bir an içinde çekilen, hafif kavisli kalın kara şerit(ler)
static func _claw_marks(p: Vector3, n: int, tilt: float, life: float) -> void:
	var dm = L.dark_mat(BEDGE)
	var to_cam = L.cam_pos() - p
	to_cam.y = 0.0
	to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.FORWARD
	var side = to_cam.cross(Vector3.UP).normalized()
	var sl = (side * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var pd = sl.cross(to_cam).normalized()
	var lines = []
	for k in n:
		var off = pd * (float(k) - (n - 1) * 0.5) * 0.55 + to_cam * 0.6
		var a = p + off - sl * 1.8
		var b = p + off + sl * 1.8
		var pts = []
		for i in 9:
			var f = i / 8.0
			pts.append(a.lerp(b, f) + pd * sin(f * PI) * 0.35)
		lines.append(pts)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var grow = clampf(age / 0.08, 0.0, 1.0)
		var polys = []
		for pts in lines:
			var cnt = maxi(2, int(ceil(pts.size() * grow)))
			polys.append({"p": pts.slice(0, cnt), "w": 0.2, "a": 1.0})
		L.draw(im, dm, polys, clampf((life - age) / (life * 0.5), 0.0, 1.0), L.cam_pos())
		return true)


## Tek panter çarpması: çapraz aşağı üç pençe izi, her yöne kara şimşek, beyaz dişli çakma, kara yanık
static func _pounce_burst(pj: PathJutsu, p: Vector3) -> void:
	var dm = L.dark_mat(BEDGE)
	L.flash(p, 3.4, Color(1, 1, 1), 0.2, 7.0)
	_claw_marks(p, 3, -0.9, 0.6)
	for k in 8:
		L.bolt_m(p, p + Vector3(randf_range(-3, 3), randf_range(0, 3), randf_range(-3, 3)), dm, 0.26, 0.4, 2, 0.2, 0.06, 4)
	L.light(p, Color(0.8, 0.8, 0.95), 4.0, 9.0, 0.3)
	if _near_ground(p):
		L.scorch(L.floor_at(p), 2.0, BEDGE, 5.0, 0.8)
	pj.shake(0.5)


## İkiz panter çarpması: X biçiminde çapraz iki pençe çifti, yerde dışa açılan kara yer arkları, alçak yatay kara dallar
static func _twin_burst(pj: PathJutsu, p: Vector3) -> void:
	var dm = L.dark_mat(BEDGE)
	L.flash(p, 2.4, Color(0.92, 0.9, 1.0), 0.16, 5.0)
	_claw_marks(p, 2, 0.8, 0.5)
	_claw_marks(p, 2, -0.8, 0.5)
	for k in 6:
		var h = L.hdir()
		L.bolt_m(p, p + h * randf_range(2.0, 3.2) + Vector3.UP * randf_range(-0.4, 0.6), dm, 0.18, 0.35, 1, 0.22, 0.06, 3)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		var stt = {"next": 0.0, "polys": []}
		L.host(func(im, _n, _dt, age) -> bool:
			if age > 0.7:
				return false
			if age >= float(stt["next"]):
				stt["next"] = age + 0.07
				var out = []
				for k in 6:
					var h = L.hdir()
					out.append({"p": L.ground_path(g + h * 0.5, g + h * randf_range(2.0, 3.4), 0.25, 3), "w": 0.09, "a": 1.0})
				stt["polys"] = out
			L.draw(im, dm, stt["polys"], clampf((0.7 - age) / 0.25, 0.0, 1.0), L.cam_pos(), true)
			return true)
		L.scorch(g, 1.4, BEDGE, 4.0, 0.6)
	pj.shake(0.5)


## Panter mermisi (oynanış ana ağaçtaki _black_panther_shot'tan aynen: hız 24, takip 4, yarıçap 1.2, yere yapışık)
static func _panther_shot(pj: PathJutsu, c: Node3D, tt: Node3D, from: Vector3, dir: Vector3, id: String, mul: float, s: float, twin: bool) -> Projectile:
	var pan = Node3D.new()
	var pa: Node3D
	if twin:
		pa = _panther(s, Color(0.92, 0.9, 1.0), Color(0.82, 0.78, 1.0))
	else:
		pa = _panther(s, Color(1.0, 0.96, 0.75), BEDGE)
	pa.position.y = -0.9
	pan.add_child(pa)
	dir.y = 0.0
	var pr = pj.shot(c, from, dir.normalized(), 24.0, pan, pj.inf(c, id, mul, {"knock": 14.0, "kind": "heavy", "element": "raiton", "stun": 1.5, "hitstop": 0.1}), tt, false, 2.0, func(p, _h):
		if twin:
			_twin_burst(pj, p)
		else:
			_pounce_burst(pj, p))
	pr.homing_turn = 4.0
	pr.radius = 1.2
	pr.on_tick = func(p, _dt):
		p.global_position.y = Game.jutsu_floor_at(p.global_position).y + 0.9
	_panther_aura(pj, pr, s)
	return pr


static func kuro_pansa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 30.0)
	var dm = L.dark_mat(BEDGE)
	var hf = L.hand_fn(pj, c)
	L.converge(hf, 1.4, 0.4, Color(0.9, 0.9, 0.95), 14)
	L.bolt_m(hf, func() -> Vector3: return Vector3(hf.call()) + Vector3.UP * 0.6, dm, 0.05, 0.4, 2, 0.5, 0.06, 3)
	pj.after(0.4, func():
		if pj.live(c):
			var from = pj.gp(c.global_position + c.face_dir() * 1.5) + Vector3.UP * 0.9
			# doğuş: önde yerden kara şimşek kümesi fışkırır, panter içinden atılır
			var g = L.floor_at(from)
			for k in 5:
				L.bolt_m(g + L.hdir() * 0.6, g + Vector3.UP * randf_range(2.0, 3.2) + L.hdir() * 0.8, dm, 0.12, 0.3, 1, 0.2, 0.06, 3)
			L.flash(from + Vector3.UP * 0.5, 2.6, Color(1, 1, 1), 0.15, 6.0)
			_panther_shot(pj, c, tt, from, pj.aim_at(c, _safe(tt), from), "kokuton_kuro_pansa", 2.6, 2.4, false))
	Sfx.play("thunder", c.global_position, 0.7)


## İkizleri birbirine bağlayan, koşu boyunca çatırdayan kara şimşek köprüsü (ortasında ince beyaz tel)
static func _twin_link(a: Node3D, b: Node3D) -> void:
	var dm = L.dark_mat(Color(0.82, 0.78, 1.0))
	var mw = L.arc_mat(WHITE)
	var wa = weakref(a)
	var wb = weakref(b)
	var stt = {"next": 0.0, "d": [], "w": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = wa.get_ref()
		var y = wb.get_ref()
		if age > 2.1 or x == null or y == null or not is_instance_valid(x) or not is_instance_valid(y) or not x.is_inside_tree() or not y.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.07
			var p0: Vector3 = x.global_position + Vector3.UP * 0.4
			var p1: Vector3 = y.global_position + Vector3.UP * 0.4
			var out = []
			L.fork(p0, p1, 0.16, 4, 2, out, 0.1, 1.0)
			stt["d"] = out
			stt["w"] = [{"p": L.jag(p0, p1, 0.1, 3), "w": 0.025, "a": 0.8}]
		var cam = L.cam_pos()
		L.draw(im, dm, stt["d"], 1.0, cam)
		L.draw(im, mw, stt["w"], 1.0, cam)
		return true)


static func daburu_kuropansa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 30.0)
	var col = Color(0.9, 0.9, 0.95)
	L.converge(L.hand_fn(pj, c, true), 1.3, 0.25, col, 10)
	L.converge(L.hand_fn(pj, c, false), 1.3, 0.25, col, 10)
	var pair = []
	for sgn in [-1.0, 1.0]:
		pj.after(0.25, func():
			if not pj.live(c):
				return
			var side = c.face_dir().cross(Vector3.UP).normalized() * sgn
			var from = pj.gp(c.global_position + c.face_dir() + side * 2.0) + Vector3.UP * 0.9
			L.flash(from, 1.8, col, 0.12, 6.0)
			var pr = _panther_shot(pj, c, tt, from, (pj.aim_at(c, _safe(tt), from) + side * 0.5).normalized(), "daburu_kuropansa", 1.5, 2.1, true)
			pair.append(pr)
			if pair.size() == 2:
				_twin_link(pair[0], pair[1]))
	Sfx.play("roar", c.global_position, 1.0)


# ═════════════════════════════════════════ Kaminarimon: Denji Hōkō ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Elektromıknatıs topu: göğüs hizasında öne iki koyu çelik ray açılır (iç yüzlerinde parlak
## şerit); raylar arasında arkadan öne sırayla çakan basamak arkları, rayları saran daralan manyetik alan halkaları,
## namluda büyüyen plazma çekirdek. Atışta dümdüz beyaz mermi demeti 0.08 sn'de 40 m koşar; geçtiği yerde sırayla
## dışa açılan dişli şimşek halkaları (ses duvarı gibi) basar; namluda çok dişli çakma, öne kıvılcım, ayakta geri tepme tozu.
static func _rails(base: Vector3, d: Vector3, side: Vector3, dur: float) -> void:
	for sx in [-1.0, 1.0]:
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.09, 0.09, 2.2), Color(0.16, 0.17, 0.2))
		for k in 3:
			b.add("box", Vector3(0, 0, -0.8 + k * 0.8), Vector3(0.13, 0.13, 0.08), Color(0.28, 0.3, 0.34))
		var gb = MB.new()
		gb.add("box", Vector3(-sx * 0.048, 0, 0), Vector3(0.012, 0.05, 2.2), Color(0.7, 0.92, 1.0))
		var rn = Node3D.new()
		rn.add_child(L.mi_of(b.build(Props.toon()), null))
		rn.add_child(L.mi_of(gb.build(), _vc_mat()))
		L.root().add_child(rn)
		rn.global_position = base + side * sx * 0.25 + d * 1.1
		rn.look_at(rn.global_position + d + Vector3(0, 0.001, 0), Vector3.UP)
		rn.scale = Vector3(1, 1, 0.05)
		var tw = rn.create_tween()
		tw.tween_property(rn, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(dur - 0.25, 0.05))
		tw.tween_property(rn, "scale", Vector3(0.2, 0.2, 1.0), 0.13)
		tw.tween_callback(rn.queue_free)


static func _field_loops(base: Vector3, d: Vector3, side: Vector3, dur: float) -> void:
	var m = L.web_mat(EMAG)
	var up = side.cross(d).normalized()
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = age / dur
		var polys = []
		for sx in [-1.0, 1.0]:
			for k in 3:
				var cpos = base + side * sx * 0.25 + d * (0.4 + k * 0.7)
				var r = lerpf(0.32, 0.12, f) * (1.0 + 0.15 * sin(age * 40.0 + k))
				var loop = []
				for i in 15:
					var a = TAU * i / 14.0
					loop.append(cpos + (side * cos(a) + up * sin(a) * 1.3) * r)
				polys.append({"p": loop, "w": 0.018, "a": 0.5 + f * 0.5, "k": 2})
		L.draw(im, m, polys, 1.0, L.cam_pos())
		return true)


static func _rail_beam(from: Vector3, dd: Vector3, reach: float, life: float) -> void:
	var mc = _thick_arc(EMAG, 0.5)
	var mo = L.arc_mat(Color(0.3, 0.6, 1.0))
	var mr = L.arc_mat(WHITE)
	var sd = dd.cross(Vector3.UP)
	sd = sd.normalized() if sd.length_squared() > 0.0001 else Vector3.RIGHT
	var up = sd.cross(dd).normalized()
	var speed = reach / 0.08
	var nring = int(reach / 4.0)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var head = minf(reach, age * speed)
		var tail = clampf((age - 0.1) * speed * 0.5, 0.0, head)
		var fade = clampf((life - age) / 0.15, 0.0, 1.0)
		var a = from + dd * tail
		var b = from + dd * head
		var cam = L.cam_pos()
		if head - tail > 0.05:
			L.draw(im, mo, [{"p": [a, a.lerp(b, 0.5), b], "w": 0.45, "a": 0.45, "k": 2}], fade, cam)
			L.draw(im, mc, [{"p": [a, a.lerp(b, 0.5), b], "w": 0.16, "a": 1.0, "k": 2}], fade, cam)
		var rings = []
		for k in nring:
			var dist = 2.0 + k * 4.0
			var ra = age - dist / speed
			if ra < 0.0 or ra > 0.25:
				continue
			var r = 0.3 + ra * 6.0
			var c0 = from + dd * dist
			var loop = []
			for i in 15:
				var an = TAU * (i % 14) / 14.0
				loop.append(c0 + (sd * cos(an) + up * sin(an)) * r * randf_range(0.85, 1.15) + dd * randf_range(-0.12, 0.12))
			rings.append({"p": loop, "w": 0.05, "a": 1.0 - ra / 0.25, "k": 2})
		L.draw(im, mr, rings, 1.0, cam)
		return true)


static func denji_hoko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 40.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var base = c.global_position + Vector3.UP * 1.3 + d * 0.6
	_rails(base, d, side, 0.8)
	_field_loops(base, d, side, 0.45)
	for k in 6:
		pj.after(k * 0.06, func():
			L.bolt(base - side * 0.25 + d * (k * 0.35), base + side * 0.25 + d * (k * 0.35), EMAG, 0.06, 0.15, 0))
	var orb = L.orb(0.12, Color(1, 1, 1), EMAG, WHITE)
	L.root().add_child(orb)
	orb.global_position = base + d * 2.2
	orb.scale = Vector3.ONE * 0.3
	var otw = orb.create_tween()
	otw.tween_property(orb, "scale", Vector3.ONE * 2.2, 0.45).set_ease(Tween.EASE_IN)
	otw.tween_callback(orb.queue_free)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		var from = base + d * 2.2
		var dd = pj.aim_at(c, _safe(tt), from)
		_rail_beam(from, dd, 40.0, 0.35)
		L.flash(from, 2.6, WHITE, 0.15, 16.0)
		L.sparks(from, 30, EMAG, 16.0, 0.4, dd, 0.35)
		L.light(from, EMAG, 9.0, 16.0, 0.3)
		L.dust_ring(pj.gp(c.global_position), 0.3, 1.8, 0.4)
		Combat.hit_zone(c, from - Vector3.UP * 1.3, dd, 40.0, 5.0, 1.5, pj.inf(c, "kaminarimon_denji_hoko", 2.8, {"knock": 16.0, "kind": "heavy", "element": "raiton", "pierce_guard": true, "hitstop": 0.12}))
		pj.shake(0.6))
	Sfx.play("thunder", c.global_position, 1.6)


# ═════════════════════════════════════════ Kaminarimon: Kuro Ikazuchi ═════════════════════════════════════════

## (Kaynak: kara şimşeğin kendisi Darui; kompozisyon kendi tasarım) Elden yere damlayan kara şimşek, zeminde hedefe
## doğru sürünerek 0.12 sn'de koşan kalın kara yer şimşeği (yanlara kısa kara çatallar, arkasında beyaz çatlaklı kara
## yanık dizisi); hedefin dibinde yukarı fışkıran kara şimşek sütunu ve hedefin gövdesini yatay halkalar halinde saran
## kara arklar.
static func _ground_crawl(from: Vector3, end: Vector3, life: float) -> void:
	var dm = L.dark_mat(BEDGE)
	var g0 = L.floor_at(from)
	var g1 = L.floor_at(end)
	L.bolt_m(from, g0, dm, 0.12, 0.25, 1, 0.2, 0.06, 3)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var reach = clampf(age / 0.12, 0.0, 1.0)
		if age >= float(stt["next"]):
			stt["next"] = age + (0.03 if reach < 1.0 else 0.07)
			var tip = g0.lerp(g1, reach)
			var main = L.ground_path(g0, tip, 0.08, 5, 0.08)
			var out = [{"p": main, "w": 0.26, "a": 1.0}]
			for k in 4:
				if main.size() < 3:
					break
				var s: Vector3 = main[randi_range(1, main.size() - 2)]
				out.append({"p": L.ground_path(s, s + L.hdir() * randf_range(0.8, 1.8), 0.3, 3, 0.08), "w": 0.1, "a": 0.9})
			stt["polys"] = out
		L.draw(im, dm, stt["polys"], clampf((life - age) / 0.2, 0.0, 1.0), L.cam_pos(), true)
		return true)
	var n = int(clampf(g0.distance_to(g1) / 4.0, 1.0, 7.0))
	for k in n:
		L.scorch(g0.lerp(g1, (k + 0.5) / n), 0.6, BEDGE, 4.0, 0.5)


static func _black_eruption(end: Vector3, tt: Node3D) -> void:
	var dm = L.dark_mat(BEDGE)
	var g = L.floor_at(end)
	var base = g if end.y - g.y < 3.0 else end - Vector3.UP * 1.0
	for k in 6:
		L.bolt_m(base + L.hdir() * 0.4, base + Vector3.UP * randf_range(4.0, 7.0) + L.hdir() * randf_range(0.5, 1.6), dm, 0.3, 0.45, 2, 0.14, 0.06, 4)
	L.flash(end, 2.6, Color(1, 1, 1), 0.18, 7.0)
	L.light(end, Color(0.8, 0.8, 0.9), 5.0, 9.0, 0.3)
	if L.alive(tt):
		var w = weakref(tt)
		var hgt = float(tt.get("height")) if tt.get("height") != null else 1.8
		var rad = float(tt.get("radius")) if tt.get("radius") != null else 0.45
		var stt = {"next": 0.0, "polys": []}
		L.host(func(im, _n, _dt, age) -> bool:
			var x = w.get_ref()
			if age > 0.6 or x == null or not is_instance_valid(x) or not x.is_inside_tree():
				return false
			if age >= float(stt["next"]):
				stt["next"] = age + 0.06
				var bp: Vector3 = x.global_position
				var out = []
				for k in 3:
					var y = hgt * (0.25 + k * 0.3) + randf_range(-0.1, 0.1)
					var a0 = randf() * TAU
					var ring = []
					for i in 9:
						var a = a0 + i * 0.6
						ring.append(bp + Vector3(cos(a) * rad * 1.25, y + randf_range(-0.08, 0.08), sin(a) * rad * 1.25))
					out.append({"p": ring, "w": 0.06, "a": 1.0})
				stt["polys"] = out
			L.draw(im, dm, stt["polys"], clampf((0.6 - age) / 0.15, 0.0, 1.0), L.cam_pos())
			return true)


static func kuro_ikazuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 28.0)
	var dm = L.dark_mat(BEDGE)
	var hf = L.hand_fn(pj, c)
	L.converge(hf, 1.0, 0.3, Color(0.9, 0.9, 0.95), 10)
	L.bolt_m(hf, func() -> Vector3: return L.floor_at(hf.call()), dm, 0.04, 0.3, 1, 0.3, 0.06, 3)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var tv = _safe(tt)
		var end = (tv.global_position + Vector3.UP) if tv else from + pj.aim_at(c, tv, from) * 28.0
		_ground_crawl(from, end, 0.55)
		_black_eruption(end, tv)
		pj.hit(c, end, 2.2, pj.inf(c, "kaminarimon_kuro_ikazuchi", 2.0, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 2.2}))
		Combat.hit_zone(c, c.global_position, pj.aim_at(c, tv, from), from.distance_to(end), 5.0, 3.0, pj.inf(c, "kaminarimon_kuro_ikazuchi", 0.6, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 1.0}))
		pj.shake(0.5))
	Sfx.play("thunder", c.global_position, 0.8)


# ═════════════════════════════════════════ Kaminarimon: Tenrai ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Hedefin altında dönen şimşek mührü (dış çember açı açı çizilir, iç çember, iki çember
## arasında zikzak kollar) ve 25 m yukarıda yatay çatırdayan bulut tavanı arkları; ardından gökten 40 m'lik kalın
## beyaz ışık sütunu (aşağı akan çizgiler) + dört dallı yıldırım; yerde dev çakma, geniş çatlaklı yanık, yer arkları,
## fırlayan kaya, toz halkası.
static func _seal(at: Vector3, r: float, dur: float) -> void:
	var m = L.web_mat(EMAG)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur + 0.3:
			return false
		var draw_f = clampf(age / 0.3, 0.0, 1.0)
		var fade = clampf((dur + 0.3 - age) / 0.3, 0.0, 1.0)
		var rot = age * 1.4
		var polys = []
		for ring in [[r, 48], [r * 0.62, 32]]:
			var rr = float(ring[0])
			var nseg = int(ring[1])
			var cnt = maxi(2, int(nseg * draw_f) + 1)
			var line = []
			for i in cnt:
				var a = TAU * i / nseg + rot * (1.0 if rr > r * 0.8 else -1.0)
				var q = at + Vector3(cos(a), 0, sin(a)) * rr
				line.append(Vector3(q.x, Game.jutsu_floor_at(q).y + 0.07, q.z))
			polys.append({"p": line, "w": 0.06, "a": 1.0, "k": 2})
		if draw_f >= 1.0:
			for k in 8:
				var a = TAU * k / 8.0 + rot
				var p0 = at + Vector3(cos(a), 0, sin(a)) * r * 0.62
				var p1 = at + Vector3(cos(a + 0.35), 0, sin(a + 0.35)) * r
				polys.append({"p": L.ground_path(p0, p1, 0.2, 2, 0.07), "w": 0.04, "a": 0.9, "k": 2})
		L.draw(im, m, polys, fade, L.cam_pos(), true)
		return true)


static func _sky_ceiling(at: Vector3, dur: float) -> void:
	var m = L.arc_mat(EMAG)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.08
			var out = []
			for k in 4:
				var s = at + Vector3.UP * 25.0 + L.hdir() * randf_range(1.0, 6.0)
				var e = at + Vector3.UP * randf_range(24.0, 26.0) + L.hdir() * randf_range(0.0, 2.0)
				L.fork(s, e, 0.2, 3, 1, out, 0.08, randf_range(0.5, 1.0))
			stt["polys"] = out
		L.draw(im, m, stt["polys"], 1.0, L.cam_pos())
		return true)


static func _light_column(at: Vector3, r: float, h: float, life: float) -> void:
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	cm.rings = 1
	var m = _smat("column", MODE_COLUMN, SH_COLUMN, {"glow": EMAG, "power": 1.0})
	var mi = L.mi_of(cm, m)
	L.root().add_child(mi)
	mi.global_position = at + Vector3.UP * h * 0.5
	mi.scale = Vector3(0.3, 1, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.3, 1, 1.3), 0.06)
	tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), life)
	tw.parallel().tween_property(m, "shader_parameter/power", 0.0, life)
	tw.tween_callback(mi.queue_free)


static func tenrai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	_seal(at, 3.0, 0.8)
	_sky_ceiling(at, 0.7)
	pj.after(0.7, func():
		_light_column(at, 1.2, 40.0, 0.45)
		for k in 4:
			L.bolt(at + Vector3(randf_range(-1, 1), 40.0, randf_range(-1, 1)), at, EMAG, 1.0, 0.4, 3)
		L.flash(at + Vector3.UP * 0.8, 5.5, WHITE, 0.25, 12.0)
		L.light(at + Vector3.UP * 2.0, EMAG, 12.0, 22.0, 0.4)
		L.scorch(at, 4.0, EMAG, 7.0, 1.6)
		L.ground_arcs(at, 5.0, 1.2, RAI, 9)
		L.debris(at, 16, 9.0)
		L.dust_ring(at, 1.0, 7.0, 1.0)
		L.sparks(at + Vector3.UP * 0.5, 40, RAI, 16.0, 0.5, Vector3.UP, 0.8)
		pj.hit(c, at + Vector3.UP, 5.0, pj.inf(c, "kaminarimon_tenrai", 3.0, {"knock": 14.0, "launch": 8.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.15}))
		pj.shake(1.2))
	Sfx.play("thunder", at, 0.6)


# ═════════════════════════════════════════ Raiton Chakura Mōdo ═════════════════════════════════════════

## (Kaynak: Dördüncü Raikage'nin şimşek chakra modu; zırhın parlak kabuğundan farklı) Bedenden yukarı alev gibi
## yükselen keskin manga zikzakları: başta uzun, saç gibi dikilen dikenler, omuz / ön kol / göğüs / kalçada daha kısa
## yükselen dilleri (gerçek kemiklere bağlı, her 0.05 sn yeniden çakar); ateşlemede göğüste çakma, toz halkası, yer arkları.
static func _mantle(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var anchors = []
	for q in [["Head", Vector3(0, 1.65, 0), 1.7], ["LeftShoulder", Vector3(-0.22, 1.42, 0), 1.2], ["RightShoulder", Vector3(0.22, 1.42, 0), 1.2],
			["LeftUpperArm", Vector3(-0.3, 1.3, 0), 1.0], ["RightUpperArm", Vector3(0.3, 1.3, 0), 1.0],
			["LeftLowerArm", Vector3(-0.35, 1.05, 0), 1.0], ["RightLowerArm", Vector3(0.35, 1.05, 0), 1.0],
			["LeftHand", Vector3(-0.4, 0.85, 0), 0.9], ["RightHand", Vector3(0.4, 0.85, 0), 0.9],
			["UpperChest", Vector3(0, 1.3, 0.1), 1.2], ["Spine", Vector3(0, 1.1, 0.1), 1.0], ["Hips", Vector3(0, 0.95, 0), 0.9],
			["LeftUpperLeg", Vector3(-0.12, 0.7, 0), 0.8], ["RightUpperLeg", Vector3(0.12, 0.7, 0), 0.8]]:
		var ba = pj.bone_attach(c, q[0])
		if ba:
			pj.free_after(dur + 0.2, ba)
			anchors.append([L.follow_fn(ba), float(q[2])])
		else:
			anchors.append([L.follow_fn(c, q[1]), float(q[2])])
	var mw = L.arc_mat(WHITE)
	var mg = _thick_arc(RAIKAGE, 0.16)
	var cw = weakref(c)
	var hgt = float(c.get("height")) if c.get("height") != null else 1.8
	var rad = float(c.get("radius")) if c.get("radius") != null else 0.4
	var stt = {"next": 0.0, "g": [], "w": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree() or (x.has_method("is_dead") and x.is_dead()):
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var back: Vector3 = -x.face_dir() if x.has_method("face_dir") else Vector3.ZERO
			var g = []
			var w = []
			for an in anchors:
				var p0: Vector3 = (an[0] as Callable).call()
				var sc = float(an[1])
				var cnt = 4 if sc > 1.5 else (3 if sc > 1.1 else 2)
				for k in cnt:
					if randf() < 0.2:
						continue
					var s0 = p0 + L.rdir() * 0.1
					var up = (Vector3.UP + L.hdir() * 0.45 + back * 0.25).normalized()
					var line = L.zigzag(s0, s0 + up * randf_range(0.45, 0.95) * sc, 5, 0.08 * sc)
					g.append({"p": line, "w": 0.15, "a": randf_range(0.7, 1.0)})
					w.append({"p": line, "w": 0.05, "a": 1.0})
			# gövde kapsülünün her yerinden yükselen diller (kemik bulunamasa da bedeni kaplar)
			var base: Vector3 = x.global_position
			for k in 10:
				var a = randf() * TAU
				var s1 = base + Vector3(cos(a) * rad * 1.05, randf_range(0.25, hgt * 0.95), sin(a) * rad * 1.05)
				var up2 = (Vector3.UP + Vector3(cos(a), 0, sin(a)) * 0.5 + back * 0.2).normalized()
				var l2 = L.zigzag(s1, s1 + up2 * randf_range(0.4, 0.85), 4, 0.07)
				g.append({"p": l2, "w": 0.13, "a": randf_range(0.6, 1.0)})
				w.append({"p": l2, "w": 0.045, "a": 1.0})
			stt["g"] = g
			stt["w"] = w
		var fade = clampf(age / 0.2, 0.0, 1.0) * clampf((dur - age) / 0.4, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, mg, stt["g"], fade, cam)
		L.draw(im, mw, stt["w"], fade, cam)
		return true)


## Bedenin kendi örgüsüne bindirilen soluk mavi-beyaz parıltı (kabuk değil: yalnız kenar hâlesi + titreşen iç ışık, toplamalı)
const SH_GLOW := """
uniform vec4 glow : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float power = 1.0;
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fl = 0.8 + 0.2 * step(0.5, rh2(vec2(floor(TIME * 18.0), 3.0)));
	ALBEDO = (glow.rgb * (0.12 + pow(fr, 2.0) * 1.1) + vec3(0.9, 0.95, 1.0) * step(0.72, fr) * 0.5) * power * fl;
}
"""
const MODE_GLOW := "render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled;"


static func _body_glow(c: Node3D, dur: float) -> void:
	var mdl = c.get("model")
	if mdl == null or not is_instance_valid(mdl):
		return
	var m = _smat("glow", MODE_GLOW, SH_GLOW, {"glow": RAIKAGE, "power": 0.0})
	var mine = []
	for mi in (mdl as Node).find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay == null:
			(mi as MeshInstance3D).material_overlay = m
			mine.append(weakref(mi))
	var tw = (mdl as Node).create_tween()
	tw.tween_property(m, "shader_parameter/power", 1.0, 0.25)
	tw.tween_interval(maxf(dur - 0.65, 0.1))
	tw.tween_property(m, "shader_parameter/power", 0.0, 0.4)
	tw.tween_callback(func():
		for w in mine:
			var x = w.get_ref()
			if x != null and is_instance_valid(x) and x.material_overlay == m:
				x.material_overlay = null)


static func chakura_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	L.converge(L.follow_fn(c, Vector3.UP), 1.6, 0.3, RAI, 16)
	_mantle(pj, c, 15.0)
	_body_glow(c, 15.0)
	L.body_arcs(c, 15.0, RAI, 4, 0.04)
	var g = pj.gp(c.global_position)
	L.flash(c.global_position + Vector3.UP * 1.1, 2.6, RAIKAGE, 0.2, 10.0)
	L.dust_ring(g, 0.4, 3.0, 0.6)
	L.ground_arcs(g, 2.0, 0.6, RAIKAGE, 8)
	if c is Player:
		Buffs.add("raiton_chakura_modo", 15.0, {"speed": 1.3, "melee": 1.25, "armor": 0.9})
	elif c.has_method("add_buff"):
		c.add_buff("raiton_chakura_modo", 15.0, {"speed": 1.3, "melee": 1.25, "armor": 0.9})
	pj.every(15.0, 0.25, func(_i, _k):
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, c.global_position, 2.2):
			if pj.live(e):
				L.bolt(c.global_position + Vector3.UP, e.global_position + Vector3.UP, RAI, 0.12, 0.12, 1)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "raiton_chakura_modo", 0.12, {"knock": 2.0, "kind": "light", "element": "raiton", "stun": 0.4})), Callable())
	L.light(c.global_position + Vector3.UP, RAI, 8.0, 14.0, 0.3)
	Sfx.play("chidori", c.global_position, 0.7)


# ═════════════════════════════════════════ Raiton: Gian ═════════════════════════════════════════

## Kaynak: maskeden fışkıran dev beyaz şimşek mızrağı — birkaç kalın, sert köşeli beyaz kol birbirini keserek
## aralarında üçgen mavi boşluklar bırakır, kenarı mavi hâleli; gövdeden geriye kıvrılan kısa kanca arklar. Ağızda
## yük; uç 0.06 sn'de 32 m'ye fırlar, 0.07 sn'de bir yeniden kırılır; uçta ileri yelpazelenen delici dallar.
static func _gian_spear(mo: Vector3, end: Vector3, d: Vector3, life: float) -> void:
	var core = _thick_arc(GIAN, 0.62)
	var halo = L.arc_mat(Color(0.25, 0.5, 1.0))
	var stt = {"next": 0.0, "s": [], "h": [], "f": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var reach = clampf(age / 0.06, 0.05, 1.0)
		if age >= float(stt["next"]):
			stt["next"] = age + (0.02 if reach < 1.0 else 0.07)
			var tip = mo.lerp(end, reach)
			var s = []
			for k in 3:
				var off = Vector3.ZERO if k == 0 else L.rdir() * 1.2
				s.append({"p": L.zigzag(mo, tip + off, 6 + k, 0.35 + 0.25 * k), "w": [0.75, 0.45, 0.32][k], "a": 1.0})
			stt["s"] = s
			stt["h"] = [{"p": [mo, mo.lerp(tip, 0.5), tip], "w": 1.8, "a": 0.35}]
			var f = []
			for b in 4:
				var q = mo.lerp(tip, randf_range(0.15, 0.9))
				var hook = q + L.perp(d) * randf_range(1.5, 3.5) - d * randf_range(0.3, 1.2)
				f.append({"p": L.zigzag(q, hook, 3, 0.3), "w": 0.12, "a": 0.9})
			stt["f"] = f
		var fade = clampf((life - age) / 0.18, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, halo, stt["h"], fade, cam)
		L.draw(im, core, stt["s"], fade, cam)
		L.draw(im, core, stt["f"], fade, cam)
		return true)


static func _gian_pierce(p: Vector3, d: Vector3) -> void:
	for k in 7:
		var e = p + (d + L.perp(d) * randf_range(0.2, 0.7)).normalized() * randf_range(3.0, 6.0)
		L.bolt(p, e, GIAN, 0.2, 0.35, 1, 0.2, 0.05)
	L.flash(p, 3.0, GIAN, 0.2, 6.0)
	L.sparks(p, 30, GIAN, 14.0, 0.45, d, 0.6)
	if _near_ground(p):
		var g = L.floor_at(p)
		L.scorch(g, 1.8, GIAN, 5.0, 1.0)
		L.ground_arcs(g, 2.0, 0.5, GIAN, 5)


static func gian(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 34.0)
	var m0 = pj._mouth_pos(c)
	L.converge(m0, 1.2, 0.35, Color(0.4, 0.6, 1.0), 12)
	L.crackle(m0, 0.3, 0.35, Color(0.4, 0.6, 1.0), 4, 0.03, 0.05)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var mo = pj._mouth_pos(c)
		var d = pj.aim_at(c, _safe(tt), mo)
		var end = mo + d * 32.0
		_gian_spear(mo, end, d, 0.5)
		L.flash(mo + d * 0.4, 0.9, Color(0.3, 0.55, 1.0), 0.14, 8.0)
		L.light(mo + d * 3.0, Color(0.35, 0.55, 1.0), 4.0, 10.0, 0.4)
		Combat.hit_zone(c, c.global_position, d, 32.0, 10.0, 3.0, pj.inf(c, "raiton_gian", 2.0, {"knock": 14.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "dir": d}))
		_gian_pierce(pj.gp(end) + Vector3.UP, d)
		pj.shake(0.9))
	Sfx.play("thunder", c.global_position, 1.2)


# ═════════════════════════════════════════ Raitōjutsu: Rakurai ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Elde beliren katana, ağzı boyunca çatırdayan şimşek; dalışta kılıç ucundan şimşek
## kuyruğu. İnişte gökten tek kalın yıldırım doğrudan kılıca iner; kılıcın saplandığı yerden altı yöne dümdüz
## açılan parlak yer yarıkları (her biri ucunda küçük yanık), merkezde çatlaklı yanık, kaya, toz halkası.
static func _rai_katana(pj: PathJutsu, c: Node3D, dur: float) -> Array:
	var b = MB.new()
	b.add("box", Vector3(0, 0.65, 0), Vector3(0.05, 1.0, 0.012), Color(0.85, 0.88, 0.92))
	b.add("box", Vector3(0, 0.12, 0), Vector3(0.16, 0.03, 0.1), Color(0.25, 0.2, 0.12))
	b.add("cyl", Vector3(0, -0.08, 0), Vector3(0.045, 0.32, 0.045), Color(0.15, 0.1, 0.1), Vector3.ZERO, 6)
	var root_n = Node3D.new()
	root_n.add_child(L.mi_of(b.build(Props.toon()), null))
	var sb = MB.new()
	sb.add("box", Vector3(0, 0.66, 0), Vector3(0.1, 1.06, 0.035), Color.WHITE)
	root_n.add_child(L.mi_of(sb.build(), L.plasma_mat(Color(1, 1, 1), RAI, EMAG, 0.55)))
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root_n)
		root_n.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root_n, pj.hand_pos(c, true))
	var mid = Node3D.new()
	mid.position = Vector3(0, 0.65, 0)
	root_n.add_child(mid)
	var tip = Node3D.new()
	tip.position = Vector3(0, 1.12, 0)
	root_n.add_child(tip)
	root_n.scale = Vector3.ONE * 0.05
	var tw = root_n.create_tween()
	tw.tween_property(root_n, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 0.35))
	tw.tween_property(root_n, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root_n):
			root_n.queue_free())
	L.flash(pj.hand_pos(c, true), 1.2, RAI, 0.1, 7.0)
	return [mid, tip]


static func _rakurai_strike(sp: Vector3, tip: Node3D) -> void:
	var top = sp + Vector3(randf_range(-2.0, 2.0), 18.0, randf_range(-2.0, 2.0))
	var hit_p = tip.global_position if L.alive(tip) else sp + Vector3.UP * 0.3
	L.bolt(top, hit_p, RAI, 0.9, 0.22, 0, 0.12, 0.05, 4)
	L.bolt(top, hit_p, WHITE, 0.5, 0.3, 4, 0.16, 0.05, 5)
	L.flash(sp + Vector3.UP * 0.5, 4.0, WHITE, 0.2, 8.0)
	L.light(sp + Vector3.UP * 2.0, RAI, 10.0, 18.0, 0.3)
	var m = L.web_mat(RAI)
	var lines = []
	var a0 = randf() * TAU
	for i in 6:
		var a = a0 + TAU * i / 6.0
		var e = sp + Vector3(cos(a), 0, sin(a)) * 5.0
		lines.append(L.ground_path(sp, e, 0.05, 3, 0.07))
		L.scorch(L.floor_at(e), 0.6, RAI, 3.5, 0.6)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 1.4:
			return false
		var grow = clampf(age / 0.1, 0.0, 1.0)
		var polys = []
		for pts in lines:
			var cnt = maxi(2, int(ceil(pts.size() * grow)))
			polys.append({"p": pts.slice(0, cnt), "w": 0.09, "a": 1.0, "k": 1})
		L.draw(im, m, polys, clampf((1.4 - age) / 0.6, 0.0, 1.0), L.cam_pos(), true)
		return true)
	L.scorch(sp, 2.0, RAI, 5.0, 1.2)
	L.debris(sp, 10, 7.0)
	L.dust_ring(sp, 0.5, 4.5, 0.7)


static func rakurai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj._jump_at(c, tt, 9.0, 8.0 if tt else 2.0)
	pj.busy(c, 1.0)
	var kn = _rai_katana(pj, c, 1.1)
	var mid: Node3D = kn[0]
	var tip: Node3D = kn[1]
	L.crackle(L.follow_fn(mid), 0.55, 1.1, RAI, 4, 0.03, 0.05, mid)
	pj.after(0.55, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_a", 1.8)
		c.velocity = Vector3(c.velocity.x * 0.3, -40.0, c.velocity.z * 0.3)
		if L.alive(tip):
			L.trail(tip, RAI, 0.2, 0.2, 0.06)
		pj.after(0.18, func():
			if not pj.live(c):
				return
			var g = pj.gp(c.global_position)
			var sp = pj.gp(g + c.face_dir() * 0.8)
			_rakurai_strike(sp, tip)
			pj.hit(c, sp + Vector3.UP, 4.0, pj.inf(c, "raitojutsu_rakurai", 1.8, {"knock": 6.0, "launch": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
			pj.shake(1.0)))
	Sfx.play("chidori", c.global_position, 1.1)


# ═════════════════════════════════════════ Raiton: Jūrokuchū Shibari ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) On altı şimşek direği hedefin çevresinde sırayla yerden 4 m yükselir (her biri dimdik,
## az kırılımlı), tepeleri çatırdayan bir şimşek tacıyla birbirine bağlanır; yerde parlak çember, içeriden direkten
## direğe (beşer atlayarak) yıldız kirişleri çakar; her tikte üçte bir direk parlar; sonunda direkler yere çekilir.
## Bağlanan düşmanın gövdesinde arklar.
static func _sixteen_cage(at: Vector3, pts: Array, dur: float, tick: Dictionary) -> void:
	var mp = L.arc_mat(RAI)
	var mw = L.arc_mat(WHITE)
	var mg = L.web_mat(RAI)
	var bases = []
	for p in pts:
		bases.append(L.floor_at(p))
	var stt = {"next": 0.0, "p": [], "c": [], "g": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.07
			var ti = int(tick["i"])
			var pp = []
			var tops = []
			for j in 16:
				var rise = clampf((age - j * 0.015) / 0.25, 0.0, 1.0) * clampf((dur - age) / 0.3, 0.0, 1.0)
				var b: Vector3 = bases[j]
				var top = b + Vector3.UP * 4.0 * rise
				tops.append(top)
				if rise > 0.02:
					var bright = (j + ti) % 3 == 0
					pp.append({"p": L.jag(b, top, 0.05, 3), "w": 0.13 if bright else 0.07, "a": 1.0 if bright else 0.7})
			stt["p"] = pp
			var crown = []
			for j in 17:
				crown.append(Vector3(tops[j % 16]) + L.rdir() * 0.08)
			stt["c"] = [{"p": crown, "w": 0.05, "a": 0.9, "k": 2}]
			var ring = []
			for i in 41:
				var a = TAU * i / 40.0
				var q = at + Vector3(cos(a), 0, sin(a)) * 4.5
				ring.append(Vector3(q.x, Game.jutsu_floor_at(q).y + 0.07, q.z))
			stt["g"] = [{"p": ring, "w": 0.07, "a": 1.0, "k": 2}]
		var cam = L.cam_pos()
		var fade = clampf((dur - age) / 0.3, 0.0, 1.0)
		L.draw(im, mg, stt["g"], fade, cam, true)
		L.draw(im, mp, stt["p"], 1.0, cam)
		L.draw(im, mw, stt["c"], fade, cam)
		return true)


static func jurokuchu_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var pts = []
	for i in 16:
		var a = TAU * i / 16.0
		pts.append(at + Vector3(cos(a), 0, sin(a)) * 4.5)
	var tick = {"i": 0}
	_sixteen_cage(at, pts, 3.0, tick)
	L.light(at + Vector3.UP * 2.0, RAI, 5.0, 10.0, 0.6)
	pj.every(3.0, 0.12, func(i, _k):
		tick["i"] = i
		var j0 = i % 16
		L.bolt(pts[j0] + Vector3.UP * randf_range(1.0, 3.5), pts[(j0 + 5) % 16] + Vector3.UP * randf_range(1.0, 3.5), Color(0.75, 0.9, 1.0), 0.08, 0.15, 1)
		if i % 4 == 0:
			for e in pj.enemies_near(c, at, 4.6):
				if pj.live(e) and e.has_method("apply_status"):
					e.apply_status("bind", 0.6)
					L.body_arcs(e, 0.5, RAI, 3, 0.035)
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "raiton_jurokuchu_shibari", 0.2, {"knock": 0.0, "kind": "light", "element": "raiton", "stun": 0.5})), Callable())
	Sfx.play("chidori", at, 0.8)


# ═════════════════════════════════════════ Vajra Raikyū ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım; "vajra" = yıldırım asası) Altın plazmadan çift uçlu vajra: ortada tutamak ve top, iki
## uçta lotus kaidesi, ortada sivri orta diş ve çevresinde uca doğru içe kıvrılan dört yan diş. Elde küçük vajra belirir;
## fırlatılınca kendi ekseninde döner, iki ucunda dişler arasında altın çatırtı, geride altın kıvılcım dökülür.
## Çarpışta "yıldırım haçı": dört köşeli altın çakma, altı eksen yönünde uzun dallar + kısa dallar, altın yanık.
static func _vajra(s: float) -> Node3D:
	var m = L.plasma_mat(Color(1.0, 1.0, 0.92), GOLD, Color(1.0, 0.75, 0.3))
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.08, 0.36, 0.08), Color.WHITE, Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3.ZERO, Vector3(0.15, 0.15, 0.15), Color.WHITE, Vector3.ZERO, 10)
	for e in [-1.0, 1.0]:
		b.add("sphere", Vector3(0, 0, e * 0.21), Vector3(0.16, 0.16, 0.12), Color.WHITE, Vector3.ZERO, 10)
		b.add("cone", Vector3(0, 0, e * 0.42), Vector3(0.07, 0.32, 0.07), Color.WHITE, Vector3(90.0 * e, 0, 0), 6)
		for k in 4:
			var a = TAU * k / 4.0 + PI * 0.25
			var rad = Vector3(cos(a), sin(a), 0)
			var dir = (Vector3(0, 0, e) - rad * 0.32).normalized()
			var pos = rad * 0.12 + Vector3(0, 0, e * 0.36)
			b.add_xf("cone", Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(0.045, 0.26, 0.045)), pos), Color.WHITE, 5)
			b.add_xf("sphere", Transform3D(Basis.from_scale(Vector3(0.06, 0.06, 0.06)), rad * 0.1 + Vector3(0, 0, e * 0.25)), Color.WHITE, 6)
	var root_n = Node3D.new()
	var spin = Node3D.new()
	spin.scale = Vector3.ONE * s
	root_n.add_child(spin)
	spin.add_child(L.mi_of(b.build(), m))
	var p = L.Pulse.new()
	p.fn = func(_n, dt, _age) -> bool:
		if not is_instance_valid(spin):
			return false
		spin.rotation.z += 11.0 * dt
		return true
	root_n.add_child(p)
	return root_n


static func _vajra_wake(pj: PathJutsu, pr: Node3D, s: float) -> void:
	for e in [-1.0, 1.0]:
		var end = Node3D.new()
		end.position = Vector3(0, 0, e * 0.45 * s)
		pr.add_child(end)
		L.crackle(L.follow_fn(end), 0.3 * s, 2.0, GOLD, 3, 0.03, 0.05, end)
	pj.every(2.0, 0.05, func(_i, _k):
		if L.alive(pr):
			L.sparks(pr.global_position, 3, GOLD, 3.0, 0.35, pr.global_transform.basis.z, 0.6, 0.02), Callable())


static func _vajra_burst(p: Vector3) -> void:
	L.flash(p, 4.5, GOLD, 0.25, 4.0)
	L.light(p, GOLD, 10.0, 16.0, 0.3)
	for dv in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3(0.0, -0.4, 0.0)]:
		var e = p + Vector3(dv) * 5.0 + L.rdir() * 0.4
		L.bolt(p, e, GOLD, 0.24, 0.4, 2, 0.14, 0.05)
	for k in 8:
		L.bolt(p, p + L.rdir() * randf_range(2.0, 3.0), Color(1.0, 0.95, 0.75), 0.1, 0.3, 1, 0.22, 0.05)
	L.sparks(p, 40, GOLD, 15.0, 0.5)
	if _near_ground(p):
		var g = L.floor_at(p)
		L.scorch(g, 1.8, GOLD, 5.0, 1.0)
		L.ground_arcs(g, 2.6, 0.6, GOLD, 6)


static func vajra_raikyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 30.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(_vajra(0.45))
		L.crackle(L.follow_fn(ba), 0.35, 0.45, GOLD, 4, 0.025, 0.05, ba)
		pj.free_after(0.45, ba)
	L.converge(L.hand_fn(pj, c), 1.2, 0.45, GOLD, 12)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var pr = pj.shot(c, from, pj.aim_at(c, _safe(tt), from), 28.0, _vajra(1.0), pj.inf(c, "vajra_raikyu", 1.6, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 1.0}), tt, false, 2.0, func(p, _h):
			_vajra_burst(p)
			pj.hit(c, p, 4.0, pj.inf(c, "vajra_raikyu", 0.6, {"knock": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.8})))
		pr.homing_turn = 3.0
		L.flash(from, 1.6, GOLD, 0.12, 4.0)
		_vajra_wake(pj, pr, 1.0))
	Sfx.play("chidori", c.global_position, 1.3)


# ═════════════════════════════════════════ Raisuiryūdan ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Şimşek yüklü su ejderi: önde yerden kendi su sıçraması (damlalar + yayılan dalga
## halkası), ejder başı (burun, açılıp kapanan alt çene, beyaz dişler, köpük gözler, geriye yatık boynuzlar, yan
## yüzgeçler) ve geçtiği yolu izleyen, kuyruğa doğru incelen dalgalı su gövdesi — suyun içinde çakan beyaz damarlar,
## başın çevresinde çatırtı, gövde boyunca yüzeyde kayan şimşekler. Mermi bitince gövde çöküp düşer; çarpışta büyük
## sıçrama ve yere yayılan on şimşek.
static func _water_mat() -> ShaderMaterial:
	if not _mc.has("water"):
		_mc["water"] = _smat("water", MODE_WATER, SH_WATER)
	return _mc["water"]


static func _dragon_head(s: float) -> Node3D:
	var wm = _water_mat()
	var W = Color.WHITE
	var root_n = Node3D.new()
	var rig = Node3D.new()
	rig.scale = Vector3.ONE * s
	root_n.add_child(rig)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.1, 0.12), Vector3(0.6, 0.5, 0.7), W, Vector3.ZERO, 14)
	b.add("box", Vector3(0, 0.05, -0.35), Vector3(0.4, 0.2, 0.6), W, Vector3(6, 0, 0))
	b.add("sphere", Vector3(0.1, 0.15, -0.62), Vector3(0.13, 0.12, 0.13), W, Vector3.ZERO, 8)
	b.add("sphere", Vector3(-0.1, 0.15, -0.62), Vector3(0.13, 0.12, 0.13), W, Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.18 * sx, 0.34, 0.25), Vector3(0.09, 0.6, 0.09), W, Vector3(62, 0, -12 * sx), 6)
		b.add("box", Vector3(0.32 * sx, 0.0, 0.28), Vector3(0.04, 0.32, 0.42), W, Vector3(0, 25 * sx, 0))
		b.add("box", Vector3(0.2 * sx, 0.27, -0.1), Vector3(0.16, 0.06, 0.24), W, Vector3(0, 0, 18 * sx))
	for k in 4:
		b.add("cone", Vector3(0, 0.36 - k * 0.04, 0.35 + k * 0.18), Vector3(0.1, 0.32, 0.1), W, Vector3(70, 0, 0), 5)
	rig.add_child(L.mi_of(b.build(), wm))
	var eb = MB.new()
	for sx in [-1.0, 1.0]:
		eb.add("sphere", Vector3(0.2 * sx, 0.2, -0.13), Vector3(0.12, 0.08, 0.1), Color(0.95, 0.98, 1.0), Vector3.ZERO, 8)
		for k in 3:
			eb.add("cone", Vector3((0.07 + k * 0.05) * sx, -0.08, -0.6 + k * 0.1), Vector3(0.035, 0.1, 0.035), Color(0.95, 0.97, 1.0), Vector3(180, 0, 0), 4)
	rig.add_child(L.mi_of(eb.build(), _vc_mat()))
	var jaw = Node3D.new()
	jaw.position = Vector3(0, -0.06, 0.05)
	rig.add_child(jaw)
	var jb = MB.new()
	jb.add("box", Vector3(0, -0.07, -0.33), Vector3(0.34, 0.1, 0.56), W)
	jaw.add_child(L.mi_of(jb.build(), wm))
	var tb = MB.new()
	for sx in [-1.0, 1.0]:
		for k in 3:
			tb.add("cone", Vector3((0.07 + k * 0.05) * sx, 0.0, -0.55 + k * 0.1), Vector3(0.03, 0.08, 0.03), Color(0.95, 0.97, 1.0), Vector3.ZERO, 4)
	jaw.add_child(L.mi_of(tb.build(), _vc_mat()))
	var p = L.Pulse.new()
	p.fn = func(_n, _dt, age) -> bool:
		if not is_instance_valid(jaw):
			return false
		jaw.rotation.x = -(0.25 + 0.3 * absf(sin(age * 4.0)))
		rig.rotation.z = sin(age * 5.0) * 0.08
		return true
	root_n.add_child(p)
	return root_n


static func _tv(im: ImmediateMesh, v: Array) -> void:
	im.surface_set_normal(v[1])
	im.surface_add_vertex(v[0])


## Noktalar boyunca tüp (baştan kuyruğa incelen, dalgalanan yarıçap)
static func _tube(im: ImmediateMesh, m: Material, pts: Array, rad: float, age: float) -> void:
	var n = pts.size()
	var sides = 10
	var rings = []
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = Vector3(pts[mini(i + 1, n - 1)]) - Vector3(pts[maxi(i - 1, 0)])
		if tn.length_squared() < 0.000001:
			tn = Vector3.FORWARD
		tn = tn.normalized()
		var sd = tn.cross(Vector3.UP)
		if sd.length_squared() < 0.0001:
			sd = tn.cross(Vector3.RIGHT)
		sd = sd.normalized()
		var up = sd.cross(tn).normalized()
		var f = float(i) / float(n - 1)
		var r = rad * (1.0 - 0.82 * f) * (0.9 + 0.12 * sin(i * 0.9 - age * 9.0))
		var ring = []
		for k in sides + 1:
			var a = TAU * k / sides
			var nrm = sd * cos(a) + up * sin(a)
			ring.append([p + nrm * r, nrm])
		rings.append(ring)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, m)
	for i in n - 1:
		for k in sides:
			_tv(im, rings[i][k])
			_tv(im, rings[i + 1][k])
			_tv(im, rings[i][k + 1])
			_tv(im, rings[i][k + 1])
			_tv(im, rings[i + 1][k])
			_tv(im, rings[i + 1][k + 1])
	im.surface_end()


## Merminin izinden su gövdesi + ayrı görsel baş (vh). Gövde, sıçrama noktasından yükselen hazır bir kavisle başlar
## (ejder sudan çıkar); mermi bitince gövde çarpma noktasına akarak boşalır, baş o noktada küçülüp suya döner.
## Döndürdüğü sözlükteki "hist" gövde noktalarıdır (baş önde).
static func _water_body(pr: Node3D, vh: Node3D, hold: Dictionary, init: Array, npts: int, step: float, rad: float) -> Dictionary:
	var wm = _water_mat()
	var hist = init.duplicate()
	var w = weakref(pr)
	var stt = {"gone": -1.0, "hist": hist, "drain": 0.0, "s0": vh.scale}
	L.host(func(im, _n, dt, age) -> bool:
		var x = w.get_ref()
		var live = x != null and is_instance_valid(x) and x.is_inside_tree() and not bool(x.get("dead"))
		if live:
			var hp: Vector3 = x.global_position
			if is_instance_valid(vh):
				vh.global_transform = Transform3D(x.global_transform.basis, hp)
			if hist.is_empty() or Vector3(hist[0]).distance_to(hp) >= step:
				hist.push_front(hp)
				if hist.size() > npts:
					hist.pop_back()
			else:
				hist[0] = hp
		elif float(stt["gone"]) < 0.0:
			stt["gone"] = age
			if hold.has("p") and hist.size() > 0:
				hist[0] = hold["p"]
		if float(stt["gone"]) >= 0.0:
			# boşalma: gövde başın girdiği noktaya akar (her 0.025 sn bir halka içeri çekilir)
			stt["drain"] = float(stt["drain"]) + dt
			while float(stt["drain"]) >= 0.025 and hist.size() > 2:
				stt["drain"] = float(stt["drain"]) - 0.025
				hist.remove_at(1)
			var ga = age - float(stt["gone"])
			if is_instance_valid(vh) and hist.size() > 0:
				vh.global_position = Vector3(hist[0])
				vh.scale = Vector3(stt["s0"]) * clampf(1.0 - ga / 0.9, 0.05, 1.0)
			if hist.size() <= 2 or ga > 1.2:
				if is_instance_valid(vh):
					vh.queue_free()
				return false
		if hist.size() < 2:
			return true
		_tube(im, wm, hist, rad, age)
		return true)
	return stt


## Kendi su sıçraması: balistik damlalar + yere yatık yayılan dalga halkası
static func _water_burst(pos: Vector3, n: int, sp: float, ring_r: float) -> void:
	var wm = _water_mat()
	for i in n:
		var mi = L.mi_of(L.sphere_mesh(), wm)
		L.root().add_child(mi)
		mi.global_position = pos + L.rdir() * 0.4
		var sc = randf_range(0.15, 0.4)
		mi.scale = Vector3.ONE * sc
		var v = (Vector3.UP * randf_range(0.6, 1.4) + L.hdir() * randf_range(0.3, 1.0)).normalized() * sp * randf_range(0.5, 1.0)
		var st = {"v": v}
		var p = L.Pulse.new()
		p.fn = func(_n, dt, age) -> bool:
			if not is_instance_valid(mi):
				return false
			if age > 1.0:
				mi.queue_free()
				return false
			var vv: Vector3 = st["v"]
			vv.y -= 16.0 * dt
			st["v"] = vv
			mi.global_position += vv * dt
			mi.scale = Vector3(sc * 0.8, sc * (1.0 + minf(vv.length() * 0.06, 0.8)), sc * 0.8) * clampf((1.0 - age) / 0.4, 0.0, 1.0)
			if vv.length() > 0.5:
				mi.look_at(mi.global_position + vv, Vector3.UP if absf(vv.normalized().y) < 0.95 else Vector3.RIGHT)
				mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			return true
		mi.add_child(p)
	var g = L.floor_at(pos)
	if pos.y - g.y < 3.0:
		var rb = MB.new()
		rb.add("torus", Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color.WHITE, Vector3.ZERO, 24)
		var ring = L.mi_of(rb.build(), wm)
		L.root().add_child(ring)
		ring.global_position = g + Vector3.UP * 0.05
		ring.scale = Vector3(0.6, 2.0, 0.6)
		var tw = ring.create_tween()
		tw.tween_property(ring, "scale", Vector3(ring_r * 2.0, 0.6, ring_r * 2.0), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_callback(ring.queue_free)


static func raisuiryudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 34.0)
	var start = pj.gp(c.global_position + c.face_dir() * 2.5) + Vector3.UP * 2.0
	_water_burst(start - Vector3.UP * 1.8, 18, 9.0, 2.2)
	var dir0 = (pj.aim_at(c, _safe(tt), start) + Vector3.UP * 0.4).normalized()
	# görsel baş mermiden ayrı: çarpmadan sonra da gövde boşalırken görünür kalır
	var vh = _dragon_head(3.4)
	L.root().add_child(vh)
	vh.global_position = start
	var hold = {}
	var pr = pj.shot(c, start, dir0, 18.0, Node3D.new(), pj.inf(c, "raisuiryudan", 2.0, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "stun": 1.0}), tt, false, 3.0, func(p, _h):
		hold["p"] = p
		_water_burst(p, 30, 13.0, 3.0)
		L.flash(p, 4.0, RAI, 0.2, 10.0)
		L.light(p, RAI, 8.0, 16.0, 0.35)
		for i in 10:
			var a = TAU * i / 10.0
			L.bolt(p, pj.gp(p) + Vector3(cos(a), 0.1, sin(a)) * randf_range(5.0, 9.0), RAI, 0.25, 0.4, 2)
		if _near_ground(p, 3.0):
			L.ground_arcs(L.floor_at(p), 6.0, 1.0, RAI, 8)
		pj.hit(c, p, 7.0, pj.inf(c, "raisuiryudan", 0.6, {"knock": 6.0, "kind": "heavy", "element": "raiton", "stun": 1.2}))
		pj.shake(0.8))
	pr.homing_turn = 2.0
	pr.radius = 1.6
	vh.global_transform = Transform3D(pr.global_transform.basis, start)
	# gövde sıçramadan yükselen kavisle başlar (ejder sudan çıkar)
	var gs = L.floor_at(start)
	var back = Vector3(-dir0.x, 0, -dir0.z)
	back = back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
	var init = []
	for i in 9:
		var f = float(i) / 8.0
		init.append(start.lerp(gs + back * 1.5 - Vector3.UP * 0.6, f) + back * sin(f * PI) * 1.2)
	var body = _water_body(pr, vh, hold, init, 40, 0.75, 1.0)
	var hist: Array = body["hist"]
	L.crackle(L.follow_fn(vh), 2.4, 3.0, RAI, 7, 0.07, 0.06, vh)
	pj.every(3.0, 0.12, func(_i, _k):   # gövde yüzeyinde kayan şimşekler
		if is_instance_valid(pr) and hist.size() > 10:
			var i0 = randi_range(2, hist.size() - 6)
			var a: Vector3 = hist[i0]
			var b: Vector3 = hist[i0 + 4]
			var off = L.perp(b - a) * 1.2 * (1.0 - float(i0) / hist.size())
			L.bolt(a + off, b + off, WHITE, 0.08, 0.15, 1, 0.2, 0.05)
			L.bolt(a, a + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), RAI, 0.12, 0.12, 1), Callable())
	Sfx.play("water", c.global_position, 0.9)


# ═════════════════════════════════════════ Hayabusa Otoshi ═════════════════════════════════════════

## Kaynak: hedef baş aşağı yakalanıp tepeden yere çakılır (taijutsu). Abartılı ışık yok: atanın bedeninde kısa mavi
## arklar, kalkışta ayak tozu; hedef yükselirken altında, dalarken üstünde uzayan hız çizgileri; çakılınca kısa beyaz
## çakma, zeminde ışınsal koyu çatlaklar, toz halkası, kaya; tepeden tek kısa şimşek.
static func _falcon_streaks(tt: Node3D, dur: float) -> void:
	var m = L.arc_mat(Color(0.85, 0.9, 1.0))
	var w = weakref(tt)
	var stt = {"prev": tt.global_position + Vector3.UP, "dir": Vector3.UP}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = w.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var p: Vector3 = x.global_position + Vector3.UP
		var mv = p - Vector3(stt["prev"])
		stt["prev"] = p
		if mv.length() > 0.02:
			stt["dir"] = mv.normalized()
		var back = -Vector3(stt["dir"])
		var polys = []
		for k in 10:
			var a = randf() * TAU
			var o = p + Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 1.0) + Vector3.UP * randf_range(-0.6, 0.8)
			polys.append({"p": [o + back * randf_range(1.5, 3.5), o], "w": 0.025, "a": randf_range(0.4, 0.9), "k": 1})
		L.draw(im, m, polys, 1.0, L.cam_pos())
		return true)


static func _falcon_crater(pj: PathJutsu, at: Vector3) -> void:
	var g = L.floor_at(at)
	L.flash(at, 2.4, Color(1, 0.95, 0.85), 0.12, 6.0)
	var cm = _flat_mat(Color(0.1, 0.09, 0.08, 0.85))
	var lines = []
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.25, 0.25)
		lines.append(L.ground_path(g, g + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.2), 0.18, 3, 0.05))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 2.5:
			return false
		var grow = clampf(age / 0.06, 0.0, 1.0)
		var polys = []
		for pts in lines:
			var cnt = maxi(2, int(ceil(pts.size() * grow)))
			polys.append({"p": pts.slice(0, cnt), "w": 0.07, "a": 1.0, "k": 1})
		L.draw(im, cm, polys, clampf((2.5 - age) / 0.6, 0.0, 1.0), L.cam_pos(), true)
		return true)
	# yerde dışa fırlayan kısa basınç çizgileri
	var sm = L.arc_mat(Color(0.95, 0.93, 0.88))
	var dirs = []
	for k in 12:
		dirs.append(L.hdir())
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.2:
			return false
		var polys = []
		for dv in dirs:
			var r0 = 0.6 + age * 18.0
			var q0 = g + Vector3(dv) * r0 + Vector3.UP * 0.3
			polys.append({"p": [q0, q0 + Vector3(dv) * 1.2], "w": 0.04, "a": 1.0 - age / 0.2, "k": 1})
		L.draw(im, sm, polys, 1.0, L.cam_pos())
		return true)
	L.dust_ring(g, 0.5, 4.0, 0.8)
	L.debris(g, 14, 7.0)
	pj.shake(0.5)


static func hayabusa_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.2)
	if not tt:
		return
	L.body_arcs(c, 1.2, RAIKAGE, 3, 0.035)
	L.flash(c.global_position + Vector3.UP, 1.6, RAIKAGE, 0.12, 8.0)
	pj._jump_at(c, tt, 0.0, 12.0)
	L.dust_ring(pj.gp(c.global_position), 0.3, 1.8, 0.4)
	pj.after(0.25, func():
		if not pj.live(c) or not pj.live(tt):
			return
		var top = tt.global_position + Vector3.UP * 9.0
		var tw = tt.create_tween()
		tw.tween_property(tt, "global_position", top, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(tt, "global_position", pj.gp(tt.global_position), 0.2).set_ease(Tween.EASE_IN)
		c.velocity = Vector3.UP * 20.0
		_falcon_streaks(tt, 0.5)
		pj.after(0.5, func():
			if pj.live(tt):
				_falcon_crater(pj, pj.gp(tt.global_position) + Vector3.UP * 0.4)
				L.bolt(tt.global_position + Vector3.UP * 3.0, tt.global_position, RAI, 0.4, 0.25, 3)
				pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.5, pj.inf(c, "hayabusa_otoshi", 2.4, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 1.5}))))
	Sfx.play("punch", c.global_position, 0.7)


# ═════════════════════════════════════════ Raiton: Sandāgēto ═════════════════════════════════════════

## Kaynak: iki yumrukta tutulan kısa saptan göğe dimdik yükselen iki kalın, kenarı dişli camgöbeği şimşek sütunu
## (beyaz öz). Sütunlar 1.5 sn yanar; bu sırada hedef alanına gökten beş kalın, dalgalı sütun-yıldırım düşer (yukarıdan
## aşağı 0.04 sn'de iner), yerde dişli çakma, yanık, yer arkları, küçük toz halkası.
static func _sky_tether(hf: Callable, dur: float) -> void:
	var mg = _thick_arc(Color(0.3, 0.65, 1.0), 0.35)
	var mw = L.arc_mat(WHITE)
	var stt = {"next": 0.0, "g": [], "w": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var p: Vector3 = hf.call()
			var line = L.jag(p, p + Vector3(randf_range(-1, 1), 30.0, randf_range(-1, 1)), 0.04, 5)
			stt["g"] = [{"p": line, "w": 0.32, "a": 1.0, "k": 2}]
			stt["w"] = [{"p": line, "w": 0.08, "a": 1.0, "k": 2}]
		var fade = clampf(age / 0.15, 0.0, 1.0) * clampf((dur - age) / 0.2, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, mg, stt["g"], fade, cam)
		L.draw(im, mw, stt["w"], fade, cam)
		return true)


static func _gate_column(at: Vector3) -> void:
	var mg = _thick_arc(Color(0.3, 0.65, 1.0), 0.4)
	var mw = L.arc_mat(WHITE)
	var top = at + Vector3(randf_range(-1, 1), 40.0, randf_range(-1, 1))
	var stt = {"next": 0.0, "pts": []}
	var life = 0.35
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			stt["pts"] = L.jag(top, at, 0.03, 5)
		var pts: Array = stt["pts"]
		var cnt = maxi(2, int(ceil(pts.size() * clampf(age / 0.04, 0.05, 1.0))))
		var line = pts.slice(0, cnt)
		var fade = clampf((life - age) / 0.15, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, mg, [{"p": line, "w": 0.75, "a": 1.0, "k": 2}], fade, cam)
		L.draw(im, mw, [{"p": line, "w": 0.25, "a": 1.0, "k": 2}], fade, cam)
		return true)
	for j in 2:
		L.bolt(top + L.hdir() * 3.0, at + L.hdir() * 0.6, Color(0.7, 0.85, 1.0), 0.18, 0.3, 1)
	L.flash(at + Vector3.UP * 0.4, 2.6, EMAG, 0.18, 10.0)
	L.light(at + Vector3.UP * 2.0, EMAG, 7.0, 14.0, 0.25)
	L.scorch(at, 1.8, EMAG, 5.0, 1.0)
	L.ground_arcs(at, 2.2, 0.5, EMAG, 5)
	L.dust_ring(at, 0.3, 2.5, 0.5)


static func sandageto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 34.0)
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			var hb = MB.new()
			hb.add("cyl", Vector3(0, 0.12, 0), Vector3(0.05, 0.45, 0.05), Color(0.3, 0.22, 0.15), Vector3.ZERO, 6)
			ba.add_child(L.mi_of(hb.build(Props.toon()), null))
			_sky_tether(L.follow_fn(ba, Vector3.UP * 0.3), 1.5)
			L.crackle(L.follow_fn(ba), 0.3, 1.5, EMAG, 3, 0.03, 0.06, ba)
			pj.free_after(1.5, ba)
	for k in 5:
		pj.after(0.35 + k * 0.22, func():
			if not pj.live(c):
				return
			var at = pj.gp((tt.global_position if tt and pj.live(tt) else c.global_position + c.face_dir() * 14.0) + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
			_gate_column(at)
			pj.hit(c, at + Vector3.UP, 4.0, pj.inf(c, "raiton_sandageto", 1.0, {"knock": 8.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
			pj.shake(0.8))
	Sfx.play("thunder", c.global_position, 0.7)
