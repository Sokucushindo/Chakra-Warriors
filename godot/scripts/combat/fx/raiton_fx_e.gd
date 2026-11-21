class_name RaitonFXE
extends RefCounted
## Raiton E grubu: 15 tekniğin görseli ve taşınmış oynanışı. Malzeme / yapı taşı RaitonLib'den; her tekniğin şekli,
## hareketi ve sahnelenmesi kendine özgü (A / B / C / D gruplarının kompozisyonları kullanılmaz). Oynanış (hasar çağrıları,
## durumlar, süreler, menzil, mermi davranışı) ana ağaçtaki PathJutsu / ClanJutsu / MsArts gövdelerinden satır satır taşındı.
## Çakmalar küçük ve mavi-beyaz; şimşek her yerde kırık (orta nokta / zikzak), düz şerit yok; taijutsu darbeleri çizgi /
## toz / çatlakla, az ışıkla; yaratık (şimşek tazısı) opak, dış çizgili, yere basar.

const L = preload("res://scripts/combat/fx/lib/raiton_lib.gd")   # sınıf adı sabit ifade sayılmıyor
const RAI := Color(0.65, 0.85, 1.0)
const KURO_BOLT := Color(0.7, 0.85, 1.0)
const RAIKIRI_COL := Color(0.75, 0.88, 1.0)
const RAIKAGE := Color(0.45, 0.7, 1.0)
const WHITE := Color(0.93, 0.97, 1.0)
const SHIDEN := Color(0.62, 0.5, 1.0)
const PURPLE := Color(0.75, 0.4, 1.0)
const SPARK_Y := Color(1.0, 0.94, 0.6)
const LINE_DARK := Color(0.05, 0.11, 0.3)
const EARTH := Color(0.5, 0.42, 0.32)
const DUST := Color(0.62, 0.56, 0.47)
const CHAKRA_OR := Color(1.0, 0.45, 0.2)

static var _sh := {}
static var _mc := {}


# ═════════════════════════════════════════ gölgelendiriciler ═════════════════════════════════════════

## Sis katmanı (Kiri Ikazuchi): iki tonlu cel sis, kenarı gürültüyle dağılır, yavaş kayar; lit ile içten mavi-beyaz
## aydınlanır; kameraya çok yakın kısmı saydamlaşır (ekranı kaplamaz)
const SH_FOG := """
uniform vec4 tint : source_color = vec4(0.4, 0.43, 0.5, 1.0);
uniform float dens = 0.6;
uniform float lit = 0.0;
uniform float sd = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 q = p * 2.2 + vec2(TIME * 0.05 + sd, -TIME * 0.035);
	float n = rn2(q) * 0.6 + rn2(q * 2.3 + vec2(sd, 1.7)) * 0.4;
	float edge = 1.0 - smoothstep(0.4 + n * 0.35, 0.95, r);
	float band = step(0.5, n);
	vec3 col = mix(tint.rgb * 0.78, tint.rgb * 1.12, band);
	col = mix(col, vec3(0.78, 0.9, 1.0), lit * (0.35 + 0.65 * band));
	float cd = smoothstep(1.5, 5.0, length(VERTEX));
	ALBEDO = col;
	ALPHA = clamp(edge * dens * (0.55 + 0.45 * n) * cd, 0.0, 1.0);
}
"""

const BILLBOARD_V := """
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
"""

const MODE_FOG := "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;"

## Kaybolan Rasengan küresi (kaynak: saydam, içinde dönen dairesel beyaz çizgiler, açık kenar bandı): küre içinde iki
## yönde sarmal çizgi bantları, ortası açık, kenarda koyu mavi-beyaz bant; içinden çakan ince şimşek damarları
const SH_RASEN := """
uniform float power = 1.0;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	vec3 p = normalize(lp);
	float ang = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float s1 = fract(ang * 1.2732 + lat * 2.5 - TIME * 9.0);
	float s2 = fract(ang * 0.955 - lat * 3.2 + TIME * 7.0);
	float ln = max(step(0.86, s1), step(0.9, s2) * 0.8);
	float st = floor(TIME * 14.0);
	float vn = rn3(lp * 6.0 + vec3(st * 0.31, st * 0.67, -st * 0.43));
	float vein = (1.0 - smoothstep(0.0, 0.035, abs(vn - 0.5))) * 0.8;
	float mid = 1.0 - smoothstep(0.0, 0.55, fr);
	vec3 col = mix(tint.rgb, vec3(1.0), max(max(ln, vein), mid * 0.6));
	col = mix(col, tint.rgb * 0.72, step(0.85, fr));
	ALBEDO = col;
	ALPHA = clamp(0.16 + mid * 0.3 + ln * 0.6 + vein * 0.5 + step(0.85, fr) * 0.5, 0.0, 1.0) * power;
}
"""

const MODE_RASEN := "render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;"

## Şimşek canavarı gövdesi (Raijū): köşe rengi bölgeyi verir (açık mavi gövde / beyaz yele / koyu burun), sabit ışıkla iki
## tonlu cel gölge, açık mavi bölgede birkaç karede bir yer değiştiren beyaz şimşek damarları (opak)
const SH_BEAST := """
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float l = dot(NORMAL, normalize(vec3(0.35, 0.8, 0.45)));
	vec3 base = COLOR.rgb;
	vec3 col = mix(base * 0.7, base, step(0.12, l));
	float st = floor(TIME * 14.0);
	float n = rn3(lp * 5.0 + vec3(st * 0.31, st * 0.67, -st * 0.43));
	float vein = (1.0 - smoothstep(0.0, 0.04, abs(n - 0.5))) * step(0.7, base.b) * step(base.r, 0.9);
	col = mix(col, vec3(1.0), vein);
	ALBEDO = col;
}
"""

const MODE_BEAST := "render_mode unshaded, cull_back, shadows_disabled;"

## Hareket izi (taijutsu): düz beyaz öz, açık renkli kenar bandı — ışık değil, anime savuruş izi (karışık)
const SH_SMEAR := """
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.55, 0.8, 1.0, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	if (e > 0.96) { discard; }
	ALBEDO = mix(core.rgb, rim.rgb, step(0.55, e));
	ALPHA = COLOR.a * mix(0.95, 0.75, step(0.55, e));
}
"""

const MODE_SMEAR := "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;"


static func _shader(key: String, mode: String, body: String) -> Shader:
	if _sh.has(key):
		return _sh[key]
	var s = Shader.new()
	s.code = "shader_type spatial;\n" + mode + "\n" + L.SH_NOISE + "\n" + body
	_sh[key] = s
	return s


## Her çağrıda yeni malzeme (parametresi tween'lenebilir)
static func _smat(key: String, mode: String, body: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(key, mode, body)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Düz renk, köşe saydamlığıyla söner (çatlak, darbe çizgisi, oluk)
static func _ink(col: Color) -> StandardMaterial3D:
	var key = "ink_" + col.to_html()
	if _mc.has(key):
		return _mc[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	_mc[key] = m
	return m


static func _smear_mat(core: Color, rim: Color) -> ShaderMaterial:
	var key = "smear_" + core.to_html() + rim.to_html()
	if not _mc.has(key):
		_mc[key] = _smat("smear", MODE_SMEAR, SH_SMEAR, {"core": core, "rim": rim})
	return _mc[key]


## Özü kalın şimşek şeridi (paylaşılan)
static func _thick_arc(col: Color, thin: float) -> ShaderMaterial:
	var key = "thick_" + col.to_html() + str(thin)
	if not _mc.has(key):
		_mc[key] = L.mat("arc", {"glow": col, "thin": thin})
	return _mc[key]


static func _beast_mat() -> ShaderMaterial:
	if not _mc.has("beast"):
		_mc["beast"] = _smat("beast", MODE_BEAST, SH_BEAST)
	return _mc["beast"]


static func _flat(col: Color) -> StandardMaterial3D:
	var key = "flat_" + col.to_html()
	if not _mc.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		_mc[key] = m
	return _mc[key]


static func _near_ground(p: Vector3, h := 2.5) -> bool:
	return p.y - Game.jutsu_floor(p.x, p.z) < h


# ═════════════════════════════════════════ ortak yapı taşları (bu grubun) ═════════════════════════════════════════

## Yer çatlağı: merkezden dışa kırık koyu çizgiler (+ yan dallar), 0.1 sn'de merkezden dışa açılır, son 1 sn'de söner;
## glow verilirse ilk anda çatlaklar o renkle yanar
static func _crack_web(g: Vector3, r: float, n: int, life: float, glow := Color(0, 0, 0, 0)) -> void:
	var dark = _ink(Color(0.07, 0.06, 0.07))
	var lines = []
	for i in n:
		var a = TAU * (i + randf_range(-0.35, 0.35)) / n
		var dir = Vector3(cos(a), 0, sin(a))
		var e = g + dir * r * randf_range(0.55, 1.0)
		var main = L.ground_path(e, g + dir * 0.15, 0.22, 3, 0.03)   # uçtan merkeze: k=1 merkezde kalın
		lines.append({"p": main, "w": 0.06, "a": 1.0})
		if randf() < 0.7:
			var mid: Vector3 = main[main.size() / 2]
			var bd = (dir + L.hdir() * 0.9).normalized()
			lines.append({"p": L.ground_path(mid + bd * r * randf_range(0.2, 0.4), mid, 0.3, 2, 0.03), "w": 0.035, "a": 1.0})
	var gm = L.arc_mat(glow) if glow.a > 0.0 else null
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var open = clampf(age / 0.1, 0.0, 1.0)
		var fade = clampf((life - age) / 1.0, 0.0, 1.0)
		var polys = []
		for ln in lines:
			var pts: Array = ln["p"]
			var cnt = clampi(int(ceil(pts.size() * open)), 2, pts.size())
			polys.append({"p": pts.slice(pts.size() - cnt), "w": ln["w"], "a": ln["a"], "k": 1})
		var cam = L.cam_pos()
		L.draw(im, dark, polys, fade, cam, true)
		if gm != null and age < 0.6:
			L.draw(im, gm, polys, (1.0 - age / 0.6) * 0.8, cam, true)
		return true)


## Anime darbe çizgileri: at'tan, nrm'ye dik düzlemde dışa fırlayan sivri uçlu düz çizgiler
static func _impact_lines(at: Vector3, nrm: Vector3, n: int, r0: float, r1: float, life: float, col: Color, w := 0.03) -> void:
	var m = _ink(col)
	var nn = nrm.normalized()
	var u = nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v = nn.cross(u).normalized()
	var rays = []
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / n
		rays.append({"d": u * cos(a) + v * sin(a), "l": randf_range(0.6, 1.0)})
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var f = age / life
		var e = 1.0 - pow(1.0 - f, 3.0)
		var polys = []
		for r in rays:
			var dd: Vector3 = r["d"]
			var ln = float(r["l"])
			var s0 = lerpf(r0, r1 * 0.7, e) * ln
			var s1 = lerpf(r0 + 0.2, r1, e) * ln
			polys.append({"p": [at + dd * s0, at + dd * (s0 + s1) * 0.5, at + dd * s1], "w": w, "a": 1.0 - f * f, "k": 3})
		L.draw(im, m, polys, 1.0, L.cam_pos())
		return true)


## Savuruş izi: düğümün son keep sn'lik yolu boyunca kalınlaşan düz beyaz şerit (ışık değil)
static func _smear(n: Node3D, dur: float, keep: float, w: float, core: Color, rim: Color) -> void:
	var m = _smear_mat(core, rim)
	var nw = weakref(n)
	var pts = []
	L.host(func(im, _n, _dt, age) -> bool:
		var x = nw.get_ref()
		if age < dur and x != null and is_instance_valid(x) and x.is_inside_tree():
			pts.append({"p": x.global_position, "t": age})
		while pts.size() > 0 and age - float(pts[0]["t"]) > keep:
			pts.pop_front()
		if age > dur + keep:
			return false
		if pts.size() < 2:
			return true
		var line = []
		for q in pts:
			line.append(q["p"])
		L.draw(im, m, [{"p": line, "w": w, "a": 0.9, "k": 1}], 1.0, L.cam_pos())
		return true)


## Raikiri (Kakashi'nin): avuçta küçük, çok dişli beyaz çakma özü; çevresinde her 0.045 sn'de yeniden kırılan, sert köşeli
## kısa zikzaklar (yarısı ileri, "kesen" yöne uzar); öz çevresinde ardı ardına çıtırdayan minik çakmalar (kuş cıvıltısı).
## Chidori'den farkı: yere sarkan uzun dallar yok, derli toplu, ileri bakan kesici bir yük.
static func _raikiri(pj: PathJutsu, c: Node3D, right: bool, dur: float, s := 1.0, owned := true) -> void:
	var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
	if ba == null:
		L.crackle(L.hand_fn(pj, c, right), 0.4 * s, dur, RAIKIRI_COL, 5, 0.03)
		return
	if owned:
		pj.free_after(dur, ba)
	var sm = L.mat("star", {"glow": RAIKIRI_COL, "power": 1.0, "spikes": 13.0, "sd": randf() * 100.0})
	var core = L.mi_of(L.quad_mesh(), sm)
	ba.add_child(core)
	core.scale = Vector3.ONE * 0.4 * s
	var am = L.arc_mat(RAIKIRI_COL)
	var bw = weakref(ba)
	var cw = weakref(c)
	var stt = {"next": 0.0, "chirp": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = bw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var p0: Vector3 = x.global_position
		if age >= float(stt["next"]):
			stt["next"] = age + 0.045
			sm.set_shader_parameter("sd", randf() * 100.0)
			if is_instance_valid(core):
				core.scale = Vector3.ONE * 0.4 * s * randf_range(0.8, 1.15)
			var fw = Vector3.ZERO
			var cc = cw.get_ref()
			if cc != null and is_instance_valid(cc) and cc.has_method("face_dir"):
				fw = cc.face_dir()
			var out = []
			for k in 9:
				var dir = (L.rdir() + fw * (0.9 if k < 4 else 0.0)).normalized()
				var ln = randf_range(0.18, 0.5) * s * (1.4 if k < 4 else 1.0)
				out.append({"p": L.zigzag(p0 + dir * 0.04, p0 + dir * ln, 4, ln * 0.16), "w": 0.022 * s, "a": randf_range(0.6, 1.0), "k": 3})
			stt["polys"] = out
		if age >= float(stt["chirp"]):
			stt["chirp"] = age + randf_range(0.07, 0.14)
			L.flash(p0 + L.rdir() * 0.22 * s, 0.15 * s, RAIKIRI_COL, 0.06, 7.0)
		L.draw(im, am, stt["polys"], 1.0, L.cam_pos())
		return true)


## Gölge klonu belirişi: küçük, kısa ömürlü opak beyaz cel topakları (dış çizgili) dışa açılıp söner — büyük bulut değil
static func _clone_pop(pos: Vector3, s: float) -> void:
	var m = _flat(Color(0.94, 0.95, 0.97))
	var lm = L.line_mat(Color(0.42, 0.45, 0.55), 0.03)
	for k in 6:
		var mi = L.mi_of(L.sphere_mesh(), m)
		mi.material_overlay = lm
		L.root().add_child(mi)
		var off = L.rdir() * 0.35 * s
		off.y = absf(off.y) * 0.6
		mi.global_position = pos + off
		mi.scale = Vector3.ONE * 0.1 * s
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * randf_range(0.5, 0.75) * s, 0.12).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "global_position", pos + off * 2.0 + Vector3.UP * 0.2, 0.3)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


# ═════════════════════════════════════════ Kiri Ikazuchi ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Hedef alanına yere yakın, iki tonlu koyu gri-mavi cel sis çöker (üst üste üç yatay sis
## katmanı + kenarda kabaran sis kümeleri); sisin içinde ara ara yatay "perde şimşeği" kıpırdar ve sis içten aydınlanır.
## İçindeki birinin üstüne tepeden ince kırık bir yıldırım iner: küçük mavi-beyaz çakma, gövdede çatırtı, yerde yanık,
## bütün sis bir an içten parlar.
static func _mist_bank(at: Vector3, R: float, dur: float) -> Dictionary:
	var state = {"lit": 0.0}
	var mats = []
	var p = L.pulse(at, func(_n, dt, age) -> bool:
		var env = clampf(age / 0.6, 0.0, 1.0) * clampf((dur + 0.5 - age) / 1.1, 0.0, 1.0)
		state["lit"] = maxf(0.0, float(state["lit"]) - dt * 4.0)
		for e in mats:
			var m: ShaderMaterial = e["m"]
			m.set_shader_parameter("dens", float(e["d"]) * env)
			m.set_shader_parameter("lit", state["lit"])
		return age < dur + 0.5)
	for k in 3:
		var m = _smat("fog", MODE_FOG, SH_FOG, {"dens": 0.0, "sd": randf() * 40.0})
		var mi = L.mi_of(L.plane_mesh(), m)
		p.add_child(mi)
		var w = R * 2.3 - k * 1.3
		mi.position = Vector3(0, 0.25 + k * 0.6, 0)
		mi.rotation.y = randf() * TAU
		mi.scale = Vector3(w, 1.0, w)
		mats.append({"m": m, "d": [0.72, 0.55, 0.35][k]})
	for k in 9:
		var m = _smat("fog_bb", MODE_FOG, SH_FOG + BILLBOARD_V, {"dens": 0.0, "sd": randf() * 40.0})
		var mi = L.mi_of(L.quad_mesh(), m)
		p.add_child(mi)
		var a = TAU * k / 9.0 + randf_range(-0.3, 0.3)
		var rr = R * randf_range(0.45, 0.85)
		mi.position = Vector3(cos(a) * rr, randf_range(0.8, 1.4), sin(a) * rr)
		mi.scale = Vector3.ONE * randf_range(2.8, 4.2)
		mats.append({"m": m, "d": 0.5})
	return state


static func _mist_strike(e: Node3D, p: Vector3, fog: Dictionary) -> void:
	L.bolt(p + Vector3(randf_range(-1, 1), 12.0, randf_range(-1, 1)), p, KURO_BOLT, 0.12, 0.25, 3, 0.2)
	L.flash(p, 0.6, KURO_BOLT, 0.08, 10.0)
	L.body_arcs(e, 0.35, KURO_BOLT, 3, 0.03)
	var g = L.floor_at(e.global_position)
	if p.y - g.y < 2.5:
		L.scorch(g, 0.55, KURO_BOLT, 3.0, 0.4)
	fog["lit"] = 1.0


## Sisin içinde yatay kıpırdayan ince perde şimşeği
static func _mist_flicker(at: Vector3, R: float, fog: Dictionary) -> void:
	var a = at + L.hdir() * R * randf_range(0.0, 0.7) + Vector3.UP * randf_range(1.3, 2.1)
	var b = a + L.hdir() * randf_range(1.5, 3.0) + Vector3.UP * randf_range(-0.3, 0.3)
	L.bolt(a, b, KURO_BOLT, 0.03, 0.14, 1, 0.25)
	fog["lit"] = maxf(float(fog["lit"]), 0.45)


static func kiri_ikazuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "kiri_ikazuchi"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var R = 6.0
	var DUR = 4.5
	var fog = _mist_bank(at, R, DUR)
	pj.every(DUR, 0.3, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var foes = pj.enemies_near(cc, at, R)
		for f in foes:
			if f.has_method("lose_target"):
				f.lose_target(0.5)
		if i % 2 == 0 and not foes.is_empty():   # sisin içinde birine yıldırım iner
			var e = foes[randi() % foes.size()]
			var p: Vector3 = e.global_position + Vector3.UP
			_mist_strike(e, p, fog)
			Sfx.play("thunder", p, 1.1)
			e.take_hit(pj.inf(cc, id, 0.45, {"knock": 1.0, "kind": "heavy", "element": "raiton", "stun": 0.3, "hitstop": 0.04}))
		elif i % 3 == 1:
			_mist_flicker(at, R, fog))


# ═════════════════════════════════════════ Shiden Kago ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım; Shiden = mor şimşek) Rakibin dört köşesine gökten dört kırık yıldırım düşer ve DİREK
## YERİNE ayakta kalan, sürekli yeniden kırılan dört dikey mor şimşek kanalına döner; kanallar arasında üç yükseklikte
## sert köşeli zikzak bağlar çatırdar (rastgele yanıp söner). Kapanırken dört kanalın tepesi hedefin üstünde birleşir
## (şimşekten kafes kubbesi), ortadan aşağı tek mor yıldırım iner; köşelerde mor yanık, ortada yer arkları.
static func _kago_cage(posts: Array, at: Vector3, hold: float) -> void:
	var am = L.arc_mat(KURO_BOLT)
	var pm = L.arc_mat(SHIDEN)
	var top = at + Vector3.UP * 2.8
	var stt = {"next": 0.0, "polys": [], "bonds": []}
	var close0 = hold - 0.3
	L.host(func(im, _n, _dt, age) -> bool:
		if age > hold + 0.1:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var f = clampf((age - close0) / 0.3, 0.0, 1.0)
			var chans = []
			for q in posts.size():
				var base: Vector3 = posts[q]
				var tip = (base + Vector3.UP * 3.0).lerp(top, f * f)
				L.fork(base, tip, 0.1, 4, 1, chans, 0.06, 1.0)
			stt["polys"] = chans
			var bonds = []
			if f < 0.95:
				for q in posts.size():
					var a: Vector3 = posts[q]
					var b: Vector3 = posts[(q + 1) % posts.size()]
					for hgt in [0.5, 1.3, 2.1]:
						if randf() < 0.3:
							continue
						var y = Vector3.UP * hgt * (1.0 - f * 0.4)
						bonds.append({"p": L.zigzag(a + y, b + y, 6, 0.12), "w": 0.03, "a": randf_range(0.6, 1.0), "k": 3})
			stt["bonds"] = bonds
		var cam = L.cam_pos()
		L.draw(im, pm, stt["polys"], 1.0, cam)
		L.draw(im, am, stt["bonds"], 1.0, cam)
		return true)


static func shiden_kago(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "shiden_kago"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.3)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var R = 1.6 * (ClanJutsu.body_scale(tt) if tt else 1.0)
	var posts = []
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		posts.append(at + Vector3(cos(a) * R, 0, sin(a) * R))
	for p in posts:
		L.bolt(p + Vector3.UP * 14.0, p, KURO_BOLT, 0.14, 0.3, 2, 0.2)
		L.flash(p + Vector3.UP * 0.3, 0.6, SHIDEN, 0.1, 10.0)
		L.scorch(L.floor_at(p), 0.5, SHIDEN, 4.0, 0.6)
	Sfx.play("thunder", at, 1.0)
	var caught = []
	for e in pj.enemies_near(c, at, R):
		caught.append(weakref(e))
		pj.st(e, "bind", 2.2)
	_kago_cage(posts, at, 2.2)
	var tick = func(i, _k):
		var cc = cw.get_ref()
		if i % 6 == 0 and cc != null and pj.live(cc):
			for w in caught:
				var e = w.get_ref()
				if e != null and pj.live(e):
					e.take_hit(pj.inf(cc, id, 0.2, {"knock": 0.0, "kind": "light", "element": "raiton", "hitstop": 0.0}))
	var close = func():
		var cc = cw.get_ref()
		var top = at + Vector3.UP * 2.8
		L.bolt(top, at + Vector3.UP * 0.9, SHIDEN, 0.1, 0.25, 3, 0.18)
		L.flash(at + Vector3.UP, 0.8, KURO_BOLT, 0.1, 11.0)
		L.ground_arcs(at, R * 1.5, 0.4, KURO_BOLT, 5, 0.035)
		Sfx.play("thunder", at, 1.3)
		if cc == null or not pj.live(cc):
			return
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e):
				e.take_hit(pj.inf(cc, id, 0.7, {"knock": 6.0, "launch": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.5, "hitstop": 0.08}))
	pj.every(2.2, 0.12, tick, close)


# ═════════════════════════════════════════ Fang's Rush ═════════════════════════════════════════

## Kaynak (Ringo Ameyuri, Kiba): iki ince kılıç, uçları çatallı (iki diş), çevresinde büyük, sert köşeli mavi-beyaz
## zikzak şimşekler. Kılıçlar elde; çevrelerinde kırık teller ve ara ara bıçaktan havaya atlayan kısa zikzak. Hücumda
## hız çizgileri; vuruş "diş" gibi: üstten ve alttan iki testere dişli şimşek çenesi 0.08 sn'de birbirine kapanır,
## kapanma noktasında küçük çakma, öne kıvılcım ve dışa kısa zikzaklar.
static func _kiba_sword(pj: PathJutsu, c: Node3D, right: bool, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
	if ba == null:
		return
	pj.free_after(dur, ba)
	var b = MB.new()
	var steel = Color(0.72, 0.82, 0.95)
	b.add("box", Vector3(0, 0, 0.5), Vector3(0.022, 0.06, 0.82), steel)
	b.add("cone", Vector3(0.0, 0.022, 0.98), Vector3(0.02, 0.22, 0.04), steel, Vector3(80, 0, 0), 4)    # çatallı uç: iki diş
	b.add("cone", Vector3(0.0, -0.022, 0.98), Vector3(0.02, 0.22, 0.04), steel, Vector3(100, 0, 0), 4)
	b.add("box", Vector3(0, 0, 0.06), Vector3(0.05, 0.12, 0.025), Color(0.22, 0.2, 0.2))
	b.add("cyl", Vector3(0, 0, -0.07), Vector3(0.035, 0.2, 0.035), Color(0.14, 0.12, 0.1), Vector3(90, 0, 0), 8)
	var mi = L.mi_of(b.build(Props.toon()), null)
	mi.material_overlay = L.line_mat(LINE_DARK, 0.012)
	ba.add_child(mi)
	var am = L.arc_mat(RAI)
	var bw = weakref(ba)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = bw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var xf: Transform3D = x.global_transform
			var h0 = xf * Vector3(0, 0, 0.12)
			var h1 = xf * Vector3(0, 0, 1.05)
			var out = [{"p": L.zigzag(h0, h1, 6, 0.08), "w": 0.025, "a": 1.0, "k": 3},
				{"p": L.zigzag(h0, h1, 5, 0.13), "w": 0.016, "a": 0.7, "k": 3}]
			if randf() < 0.5:
				var s0 = h0.lerp(h1, randf_range(0.3, 1.0))
				out.append({"p": L.zigzag(s0, s0 + L.rdir() * randf_range(0.4, 0.8), 4, 0.12), "w": 0.02, "a": 0.9, "k": 3})
			stt["polys"] = out
		L.draw(im, am, stt["polys"], 1.0, L.cam_pos())
		return true)


## Testere dişli çene: from'dan to'ya, teeth yönünde sivri dişler (kapalı uçlu zikzak)
static func _jaw_line(a: Vector3, b: Vector3, teeth: Vector3, n: int, depth: float) -> Array:
	var pts = []
	for i in n * 2 + 1:
		var f = float(i) / float(n * 2)
		var bulge = sin(f * PI) * 0.25
		var p = a.lerp(b, f) + teeth * (-bulge)
		if i % 2 == 1:
			p += teeth * depth
		pts.append(p)
	return pts


static func _fang_bite(at: Vector3, d: Vector3) -> void:
	var am = L.arc_mat(RAI)
	var side = d.cross(Vector3.UP).normalized()
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.3:
			return false
		var close = clampf(age / 0.08, 0.0, 1.0)
		var gap = lerpf(0.9, 0.06, close * close)
		var fwd_bow = d * 0.25 * (1.0 - close)
		var top_a = at - side * 1.1 + Vector3.UP * gap + fwd_bow
		var top_b = at + side * 1.1 + Vector3.UP * gap + fwd_bow
		var bot_a = at - side * 1.1 - Vector3.UP * gap + fwd_bow
		var bot_b = at + side * 1.1 - Vector3.UP * gap + fwd_bow
		var polys = [{"p": _jaw_line(top_a, top_b, Vector3.DOWN, 5, 0.28), "w": 0.045, "a": 1.0, "k": 3},
			{"p": _jaw_line(bot_a, bot_b, Vector3.UP, 5, 0.28), "w": 0.045, "a": 1.0, "k": 3}]
		var fade = 1.0 - clampf((age - 0.15) / 0.15, 0.0, 1.0)
		L.draw(im, am, polys, fade, L.cam_pos())
		return true)
	var pw = {"done": false}
	L.pulse(at, func(_n, _dt, age) -> bool:
		if age < 0.08:
			return true
		if not pw["done"]:
			pw["done"] = true
			L.flash(at, 0.7, RAI, 0.08, 11.0)
			L.sparks(at, 12, RAI, 10.0, 0.35, d, 0.6, 0.02)
			for k in 4:
				var dir = (side * (1.0 if k % 2 == 0 else -1.0) + L.rdir() * 0.6).normalized()
				L.zig_bolt(at, at + dir * randf_range(0.8, 1.4), RAI, 0.03, 0.15, 4, 0.12)
		return false)


static func fang_s_rush(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.8)
	for right in [true, false]:
		_kiba_sword(pj, c, right, 0.8)
	var d = pj._jump_at(c, tt, 0.0, 22.0 if tt else 8.0)
	L.speed_lines(c, d, 0.3, WHITE, 8)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 1.8)
		var at = c.global_position + Vector3.UP * 1.1 + d * 1.0
		_fang_bite(at + d * 0.3, d)
		var hs = pj.hit(c, at + d * 0.6, 2.2, pj.inf(c, "fang_s_rush", 1.6, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
		L.wet_shock(at + d * 0.6, 0.9)
		pj.shake(0.45 if not hs.is_empty() else 0.3)
		Sfx.play("thunder", at, 1.6, 0.5))


# ═════════════════════════════════════════ Girochin Doroppu ═════════════════════════════════════════

## Kaynak (A'nın giyotin topuğu): gövdeyi saran, siluetin dışında aşağıdan yukarı uzanan uzun, sert köşeli ince mavi
## şimşek çizgileri (zırh). Taijutsu: inişte topuğun çizdiği yay boyunca beyaz savuruş izi (giyotin bıçağı gibi hilal),
## yere vuruşta merkezden dışa koyu kırık çatlak ağı (ilk anda mavi yanar), toz halkası, kaya kırıntısı, yatay darbe
## çizgileri ve küçük mavi-beyaz çakma — ışık şovu yok.
static func _armor_lines(c: Node3D, dur: float) -> void:
	if not L.alive(c):
		return
	var am = L.arc_mat(RAIKAGE)
	var cw = weakref(c)
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var base: Vector3 = x.global_position
			var out = []
			for k in 5:
				if randf() < 0.25:
					continue
				var a = randf() * TAU
				var r0 = randf_range(0.45, 0.7)
				var pts = []
				for i in 6:
					var f = i / 5.0
					var aa = a + randf_range(-0.25, 0.25)
					var rr = r0 * (0.75 + 0.35 * sin(f * PI))
					pts.append(base + Vector3(cos(aa) * rr, -0.05 + f * 2.25, sin(aa) * rr))
				out.append({"p": pts, "w": 0.025, "a": randf_range(0.6, 1.0), "k": 3})
			stt["polys"] = out
		L.draw(im, am, stt["polys"], clampf((dur - age) / 0.15, 0.0, 1.0), L.cam_pos())
		return true)


## Topuğun çizdiği hilal: from (tepe) -> to (yer), d yönüne bombeli; 0.14 sn'de çizilir, sonra söner
static func _guillotine_arc(from: Vector3, to: Vector3, d: Vector3) -> void:
	var m = _smear_mat(Color(1, 1, 1), Color(0.6, 0.82, 1.0))
	var pts = []
	for i in 13:
		var f = i / 12.0
		pts.append(from.lerp(to, f) + d * sin(f * PI) * 1.1)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.4:
			return false
		var cnt = clampi(int(ceil(pts.size() * clampf(age / 0.14, 0.0, 1.0))), 2, pts.size())
		var fade = 1.0 - clampf((age - 0.18) / 0.22, 0.0, 1.0)
		L.draw(im, m, [{"p": pts.slice(0, cnt), "w": 0.3, "a": 0.9, "k": 1}], fade, L.cam_pos())
		return true)


static func _heel_impact(at: Vector3) -> void:
	_crack_web(at, 3.2, 9, 3.5, RAIKAGE)
	L.dust_ring(at, 0.5, 4.0, 0.6, DUST)
	L.debris(at, 12, 9.0, EARTH)
	_impact_lines(at + Vector3.UP * 0.25, Vector3.UP, 14, 0.6, 3.0, 0.25, WHITE, 0.035)
	L.flash(at + Vector3.UP * 0.4, 0.9, RAIKAGE, 0.09, 10.0)


static func girochin_doroppu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_armor_lines(c, 1.6)
	var tt = pj.tg(c, t, 14.0)
	var at = pj.gp(tt.global_position if tt else Jutsu._aim_ground(c, t, 6.0, 14.0))
	pj.busy(c, 1.3)
	# Girochin Doroppu (anime A): hedefin üstüne yay çizerek yüksek sıçrar, havada dizleri toplayıp takla atar,
	# şimşekli topuğu giyotin gibi tepesine indirir — ışınlanma yok
	var start = c.global_position
	var apex = at + Vector3.UP * 7.0 - (at - start).normalized() * 0.5
	var md = c.get("model")
	pj.anim(c, "jump", 1.6)
	var dur_up = 0.5
	var rise = func(_i, k):
		if not is_instance_valid(c):
			return
		c.velocity = Vector3.ZERO
		var u = clampf(k, 0.0, 1.0)
		var flat = start.lerp(apex, u)
		flat.y = lerpf(start.y, apex.y, sin(u * PI * 0.5))
		c.global_position = flat
		if md and md.get("overlay"):
			md.overlay.tuck = sin(u * PI)   # havada takla: dizler göğse
		if c is Player:
			var dd = at - c.global_position
			dd.y = 0
			if dd.length() > 0.1:
				c.facing = atan2(-dd.x, -dd.z)
	var drop = func():
		if not is_instance_valid(c):
			return
		if md and md.get("overlay"):
			md.overlay.tuck = 0.0
		pj.anim(c, "slash_c", 2.2)
		var hd = at - c.global_position
		hd.y = 0.0
		hd = hd.normalized() if hd.length() > 0.05 else c.face_dir()
		_guillotine_arc(c.global_position + Vector3.UP * 1.6 - hd * 0.3, at + Vector3.UP * 0.1, hd)
		var tw = c.create_tween()
		tw.tween_property(c, "global_position", at + Vector3.UP * 0.05, 0.14).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			_heel_impact(at)
			for h in pj.hit(c, at + Vector3.UP, 3.4, pj.inf(c, "girochin_doroppu", 2.0, {"knock": 12.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "hitstop": 0.12})):
				pj.st(h, "stun", 1.2)
			pj.shake(1.0)
			Sfx.play("thunder", at, 1.0))
	pj.every(dur_up, 1.0 / 60.0, rise, drop)


# ═════════════════════════════════════════ Kage Bunshin: Raikirisō ═════════════════════════════════════════

## (Kaynak: Kakashi'nin klonu iki elde Raikiri) Klon küçük beyaz cel topaklarıyla belirir; iki elinde Raikiri, koşarken
## ellerinden yere kısa kırık şimşekler damlar. Saldırı "kıskaç": her el hedefin göğsüne kırık bir zikzakla saplanır ve
## şimşek saplandığı noktadan, saplanma eksenine dik bir disk halinde yana doğru kısa zikzaklarla patlar; gövdede çatırtı.
static func _pinch(h: Vector3, o: Vector3, x: Node3D) -> void:
	L.zig_bolt(h, o, RAIKIRI_COL, 0.06, 0.2, 5, 0.16, 0.04)
	var ax = (o - h).normalized() if (o - h).length() > 0.05 else Vector3.FORWARD
	var u = ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v = ax.cross(u).normalized()
	var am = L.arc_mat(RAIKIRI_COL)
	var rays = []
	for k in 8:
		var a = TAU * (k + randf_range(-0.3, 0.3)) / 8.0
		rays.append((u * cos(a) + v * sin(a)) * randf_range(0.8, 1.6))
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.2:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var out = []
			for r in rays:
				out.append({"p": L.zigzag(o + Vector3(r), o, 4, 0.12), "w": 0.03, "a": 1.0, "k": 1})
			stt["polys"] = out
		L.draw(im, am, stt["polys"], 1.0 - age / 0.2, L.cam_pos())
		return true)
	L.flash(o, 0.7, RAIKIRI_COL, 0.09, 11.0)
	if L.alive(x):
		L.body_arcs(x, 0.5, RAIKIRI_COL, 3, 0.03)


static func kage_bunshin_raikiriso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Kage Bunshin: Raikirisō: klonun saldıracağı hedef yok", Color(0.8, 0.9, 1.0))
		return
	pj.busy(c, 0.6)
	var id = "kage_bunshin_raikiriso"
	var d = pj._face(c, tt)
	pj.anim(c, "seal", 1.6)
	var at = c.global_position + d.cross(Vector3.UP).normalized() * 1.3
	_clone_pop(at + Vector3.UP, 0.8)   # gölge klonunun kanon belirişi
	Sfx.play("poof", at, 0.9)
	var cl = pj.decoy(c, at, 3.2)
	cl.tgt = tt
	_raikiri(pj, cl, true, 3.2, 1.1, false)
	_raikiri(pj, cl, false, 3.2, 1.1, false)
	Sfx.play("chidori", at, 1.0)
	var cw = weakref(c)
	var tw = weakref(tt)
	var lw = weakref(cl)
	var s = {"done": false}
	var run = func(i, _k):
		if s["done"]:
			return
		var cc = cw.get_ref()
		var x = tw.get_ref()
		var k2 = lw.get_ref()
		if cc == null or x == null or k2 == null or not pj.live(cc) or not pj.live(x) or k2.is_dead():
			return
		if i % 2 == 0:
			for right in [true, false]:
				var h = pj.hand_pos(k2, right)
				L.bolt(h, pj.gp(h) + Vector3(randf_range(-0.4, 0.4), 0.02, randf_range(-0.4, 0.4)), RAIKIRI_COL, 0.03, 0.1, 0, 0.25)   # şimşek yeri dağlar
		if k2.global_position.distance_to(x.global_position) > 2.3:
			return
		s["done"] = true
		k2.cd = 9.0   # klon kendi yumruğunu atmaz: iki Raikiri'yi indirir
		if k2.get("model"):
			k2.model.play("cross", 0.05, 2.0, true)
		for j in 2:
			var strike = func():
				var c3 = cw.get_ref()
				var x3 = tw.get_ref()
				var k3 = lw.get_ref()
				if c3 == null or x3 == null or k3 == null or not pj.live(c3) or not pj.live(x3):
					return
				var o = x3.global_position + Vector3.UP * 1.1
				var h = pj.hand_pos(k3, j == 0)
				x3.take_hit(pj.inf(c3, id, 1.4, {"knock": 9.0 if j == 1 else 0.0, "launch": 2.0, "kind": "heavy", "element": "raiton", "hitstop": 0.1, "stun": 0.8}))
				_pinch(h, o, x3)
				Sfx.play("thunder", o, 1.4)
				if j == 1:
					pj.shake(0.5)
			pj.after(0.08 + j * 0.16, strike)
		var pop = func():
			var k4 = lw.get_ref()
			if k4 != null and is_instance_valid(k4) and not k4.is_dead():
				k4.vanish()
		pj.after(0.6, pop)
	pj.every(3.0, 1.0 / 30.0, run, Callable())


# ═════════════════════════════════════════ Raiton: Rariatto ═════════════════════════════════════════

## Kaynak (B'nin Lariat'ı): hız çizgileri ve darbede boyun hizasında dışa fırlayan anime darbe çizgileri — ışık değil.
## Koşu boyunca açık sağ kolun ardında düz beyaz savuruş izi (mavi kenarlı), kolda ince çatırtı, ayak dibinde koyu
## kayma izi; çarpışta hedefin boyun hizasında koşu eksenine dik düzlemde darbe çizgisi yıldızı, küçük çakma, toz.
static func _clothesline(h: Node3D, d: Vector3) -> void:
	if not L.alive(h):
		return
	var p = h.global_position + Vector3.UP * 1.5
	_impact_lines(p, d, 12, 0.3, 1.8, 0.22, WHITE, 0.03)
	L.flash(p, 0.5, RAIKAGE, 0.07, 9.0)
	L.dust_ring(L.floor_at(h.global_position), 0.3, 1.8, 0.4, DUST)


## Ayak dibindeki kayma izi: atanın zemindeki yolu boyunca iki koyu paralel çizgi, yavaş söner
static func _skid(c: Node3D, dur: float, life: float) -> void:
	var m = _ink(Color(0.12, 0.1, 0.09))
	var cw = weakref(c)
	var pts = []
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var x = cw.get_ref()
		if age < dur and x != null and is_instance_valid(x) and x.is_inside_tree():
			var g = L.floor_at(x.global_position) + Vector3.UP * 0.03
			if pts.is_empty() or Vector3(pts[pts.size() - 1]).distance_to(g) > 0.25:
				pts.append(g)
		if pts.size() < 2:
			return true
		var d: Vector3 = Vector3(pts[pts.size() - 1]) - Vector3(pts[0])
		var side = d.cross(Vector3.UP).normalized() * 0.18 if d.length() > 0.1 else Vector3.ZERO
		var a = []
		var b = []
		for q in pts:
			a.append(Vector3(q) + side)
			b.append(Vector3(q) - side)
		var fade = clampf((life - age) / 1.0, 0.0, 1.0)
		L.draw(im, m, [{"p": a, "w": 0.05, "a": 0.7, "k": 1}, {"p": b, "w": 0.05, "a": 0.7, "k": 1}], fade, L.cam_pos(), true)
		return true)


static func raiton_rariatto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	L.body_arcs(c, 1.4, RAIKAGE, 2, 0.025)
	var d = pj.fwd(c, t)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		pj.free_after(0.9, ba)
		L.crackle(L.follow_fn(ba), 0.35, 0.7, RAIKAGE, 3, 0.025, 0.06, ba)
		_smear(ba, 0.65, 0.14, 0.18, Color(1, 1, 1), Color(0.6, 0.8, 1.0))
	L.speed_lines(c, d, 0.6, WHITE, 9)
	_skid(c, 0.6, 2.5)
	var hits = []
	# kaymadan koşar: koşu animasyonu, sağ kol yana açık (lariat); gövde koşu yönüne bakar
	var tick = func(pt):
		if is_instance_valid(c) and c.get("model"):
			c.model.play("run", 0.06, 2.1)
		for h in pj.hit(c, pt + c.global_transform.basis.x * 0.6, 1.8, pj.inf(c, "raiton_rariatto", 1.8, {"knock": 18.0, "launch": 9.0, "kind": "heavy", "element": "raiton", "hitstop": 0.08}), hits):
			hits.append(h)
			_clothesline(h, c.face_dir())
	Jutsu._dash(c, t, 0.6, 30.0, tick)
	Sfx.play("chidori", c.global_position, 1.2)


# ═════════════════════════════════════════ Kieru Rasengan ═════════════════════════════════════════

## Kaynak (Boruto): saydam, açık mavi-beyaz küre, içinde dönen dairesel beyaz çizgiler, kenarında açık bant. Elde küçük
## küre; fırlatılınca 0.1 sn'de saydamlaşıp kaybolur (geride ince bir halka kıpırtısı), hedefin yanında küçük bir çakmayla
## yeniden belirir. Çarpınca küre, kameraya dönük üç kollu dönen bir sarmala açılır, kıvılcım ve yerde toz halkası.
static func _rasen_ball(r: float) -> Node3D:
	var root = Node3D.new()
	var m = _smat("rasen", MODE_RASEN, SH_RASEN, {"power": 1.0})
	var mi = L.mi_of(L.sphere_mesh(), m)
	mi.scale = Vector3.ONE * r * 2.0
	root.add_child(mi)
	root.set_meta("rmat", m)
	var spin = func(_n, dt, _age) -> bool:
		if not is_instance_valid(mi):
			return false
		mi.rotate_y(dt * 14.0)
		mi.rotate_x(dt * 5.0)
		return true
	L.pulse(Vector3.ZERO, spin, root)
	return root


static func _ripple(p: Vector3, r0: float, r1: float, life: float, col: Color) -> void:
	var am = L.arc_mat(col)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var f = age / life
		var cam = L.cam_pos()
		var view = (cam - p).normalized()
		var u = view.cross(Vector3.UP if absf(view.y) < 0.95 else Vector3.RIGHT).normalized()
		var v = view.cross(u).normalized()
		var r = lerpf(r0, r1, 1.0 - pow(1.0 - f, 2.0))
		var ring = []
		for i in 25:
			var a = TAU * i / 24.0
			ring.append(p + (u * cos(a) + v * sin(a)) * r)
		L.draw(im, am, [{"p": ring, "w": 0.018, "a": 1.0 - f, "k": 2}], 1.0, cam)
		return true)


static func _rasen_grind(pj: PathJutsu, p: Vector3) -> void:
	var am = L.arc_mat(Color(0.8, 0.92, 1.0))
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.4:
			return false
		var f = age / 0.4
		var cam = L.cam_pos()
		var view = (cam - p).normalized()
		var u = view.cross(Vector3.UP if absf(view.y) < 0.95 else Vector3.RIGHT).normalized()
		var v = view.cross(u).normalized()
		var R = lerpf(0.3, 1.8, 1.0 - pow(1.0 - f, 2.0))
		var polys = []
		for arm in 3:
			var line = []
			for j in 14:
				var tj = j / 13.0
				var a = arm * TAU / 3.0 + tj * 3.5 + age * 25.0
				line.append(p + (u * cos(a) + v * sin(a)) * tj * R)
			polys.append({"p": line, "w": 0.05, "a": 1.0, "k": 1})
		L.draw(im, am, polys, 1.0 - f * f, cam)
		return true)
	L.flash(p, 0.6, RAI, 0.08, 10.0)
	L.sparks(p, 14, RAI, 9.0, 0.35)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.dust_ring(g, 0.4, 2.6, 0.5, DUST)
		L.debris(g, 6, 6.0, EARTH)
	pj.shake(0.65)


static func kieru_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 22.0)
	var from = pj.hand_pos(c, true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(_rasen_ball(0.2))
		pj.free_after(0.4, ba)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var r = _rasen_ball(0.35)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 24.0, r, pj.inf(c, "kieru_rasengan", 1.8, {"knock": 18.0, "launch": 4.0, "kind": "heavy"}), tt, false, 1.6, func(p, _h):
			_rasen_grind(pj, p))
		pr.homing_turn = 6.0
		var rm: ShaderMaterial = r.get_meta("rmat")
		var fade = r.create_tween()
		fade.tween_interval(0.05)
		fade.tween_property(rm, "shader_parameter/power", 0.0, 0.1)
		pj.after(0.15, func():
			if is_instance_valid(r):
				_ripple(r.global_position, 0.3, 0.8, 0.22, WHITE)
				r.visible = false)
		pj.after(0.4, func():
			if is_instance_valid(r):
				r.visible = true
				rm.set_shader_parameter("power", 1.0)
				L.flash(r.global_position, 0.6, RAI, 0.08, 9.0)
				_ripple(r.global_position, 0.9, 0.35, 0.15, RAI)))
	Sfx.play("wind", c.global_position, 1.4)


# ═════════════════════════════════════════ Uchiha Ryū Shurikenjutsu: Ikazuchi Sanren ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Atanın gözlerinde kısa kırmızı parıltı (Sharingan). Kendi dört uçlu shurikenimiz (koyu
## çelik, ince); dönerken yalnız dört ucundan dışa kısa zikzak kıvılcımlar atar (çember yok), arkasında ince titrek şimşek
## kuyruğu. Değince küçük çakma, hedefin gövdesinde felç süresince sürünen arklar, dışa üç kısa zikzak.
static func _sanren_star() -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var steel = Color(0.32, 0.33, 0.4)
	for n in 4:
		var a = n * PI * 0.5
		b.add("cone", Vector3(cos(a) * 0.17, 0, sin(a) * 0.17), Vector3(0.018, 0.3, 0.11), steel, Vector3(0, -rad_to_deg(a), -90), 4)
	b.add("cyl", Vector3.ZERO, Vector3(0.1, 0.035, 0.1), Color(0.18, 0.18, 0.22), Vector3.ZERO, 8)
	var mi = L.mi_of(b.build(Props.toon()), null)
	mi.material_overlay = L.line_mat(Color(0.03, 0.03, 0.06), 0.01)
	root.add_child(mi)
	var am = L.arc_mat(RAI)
	var stt = {"next": 0.0, "polys": []}
	var host = L.host(func(im, _n, _dt, age) -> bool:
		if not is_instance_valid(root) or not root.is_inside_tree():
			return age < 0.05   # sahneye eklenmeden önceki ilk kare
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var xf: Transform3D = root.global_transform
			var out = []
			for n in 4:
				if randf() < 0.3:
					continue
				var a = n * PI * 0.5
				var tip = xf * Vector3(cos(a) * 0.33, 0, sin(a) * 0.33)
				var dir = (tip - xf.origin).normalized()
				out.append({"p": L.zigzag(tip, tip + (dir + L.rdir() * 0.5).normalized() * randf_range(0.15, 0.3), 3, 0.05), "w": 0.018, "a": 1.0, "k": 3})
			stt["polys"] = out
		L.draw(im, am, stt["polys"], 1.0, L.cam_pos())
		return true)
	root.tree_exiting.connect(func():
		if is_instance_valid(host):
			host.queue_free())
	return root


static func _sanren_hit(p: Vector3, h) -> void:
	L.flash(p, 0.5, RAI, 0.07, 9.0)
	for n in 3:
		L.zig_bolt(p, p + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() * randf_range(0.7, 1.2), RAI, 0.025, 0.14, 4, 0.1)
	if h is Node3D and L.alive(h):
		L.body_arcs(h, 0.45, RAI, 3, 0.025)


static func uchiha_ryu_shurikenjutsu_ikazuchi_sanren(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb:
		for sx in [-1.0, 1.0]:
			L.flash(Vector3(sx * 0.032, 0.065, 0.095), 0.05, Color(1.0, 0.12, 0.08), 1.2, 6.0, hb)
		pj.free_after(1.5, hb)
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 0.6)
	var aim = pj._aim_tt(c, t, tt, Jutsu._hand(c))
	for k in 3:
		pj.after(k * 0.11, func():
			if not is_instance_valid(c):
				return
			pj.anim(c, ["throw", "slash_a", "throw"][k], 2.2)
			var d = aim.rotated(Vector3.UP, [-0.55, 0.55, 0.0][k]) + Vector3.UP * [0.05, 0.05, 0.12][k]
			var root = _sanren_star()
			var pr = pj.shot(c, Jutsu._hand(c), d.normalized(), 34.0, root, pj.inf(c, "uchiha_ryu_shurikenjutsu_ikazuchi_sanren", 0.4, {"knock": 3.0, "element": "raiton", "stun": 0.45}), tt, false, 1.8, func(p, h):
				_sanren_hit(p, h))
			pr.homing_turn = 5.0
			pr.spin = Vector3(0, 30, 0)
			L.trail(root, RAI, 0.05, 0.18, 0.05)
			Sfx.play("throw_kunai", c.global_position, 1.3))


# ═════════════════════════════════════════ Chō Biburāto Raitontō ═════════════════════════════════════════

## Kaynak (titreşimli şimşek kılıcı: kurşun kalemin bile delip geçmesi, kılıcın değdiği yerde fıskiye gibi kavisli soluk
## sarı kıvılcım çizgileri): ince kılıcın kenarlarında titreşen hayalet kenar çizgileri ve ortasında yüksek frekanslı
## duran dalga; her kesik düz, keskin, beyaz bir kesik çizgisi + iki yanında titreşim yankısı ve boyunca sinüs dalgası;
## değdiği yerde uzun, kavisli, yerçekimiyle düşen soluk sarı kıvılcım çizgileri ve küçük sarı-beyaz çakma.
static func _vibro_blade(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	pj.free_after(dur, ba)
	var b = MB.new()
	b.add("box", Vector3(0, 0, 0.6), Vector3(0.022, 0.075, 1.1), Color(0.8, 0.88, 0.96))
	b.add("box", Vector3(0, 0, 0.03), Vector3(0.05, 0.13, 0.025), Color(0.25, 0.22, 0.2))
	b.add("cyl", Vector3(0, 0, -0.08), Vector3(0.035, 0.2, 0.035), Color(0.15, 0.12, 0.1), Vector3(90, 0, 0), 8)
	var mi = L.mi_of(b.build(Props.toon()), null)
	mi.material_overlay = L.line_mat(LINE_DARK, 0.01)
	ba.add_child(mi)
	var am = L.arc_mat(Color(0.75, 0.95, 1.0))
	var bw = weakref(ba)
	L.host(func(im, _n, _dt, age) -> bool:
		var x = bw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if is_instance_valid(mi):
			mi.position = Vector3(0, randf_range(-0.006, 0.006), 0)
		var xf: Transform3D = x.global_transform
		var up = xf.basis.y.normalized()
		var polys = []
		for sgn in [-1.0, 1.0]:
			var off = up * sgn * randf_range(0.05, 0.08)
			polys.append({"p": [xf * Vector3(0, 0, 0.1) + off, xf * Vector3(0, 0, 1.15) + off], "w": 0.008, "a": randf_range(0.4, 0.8), "k": 3})
		var wave = []
		for i in 17:
			var f = i / 16.0
			wave.append(xf * Vector3(0, 0, 0.08 + f * 1.07) + up * sin(f * PI * 9.0 + age * 90.0) * 0.03 * sin(f * PI))
		polys.append({"p": wave, "w": 0.012, "a": 0.9, "k": 3})
		L.draw(im, am, polys, 1.0, L.cam_pos())
		return true)


static func _vibro_cut(at: Vector3, d: Vector3, a0: float, a1: float, tilt: float) -> void:
	var cm = L.arc_mat(WHITE)
	var em = L.arc_mat(Color(0.7, 0.92, 1.0))
	var p0 = at + d.rotated(Vector3.UP, deg_to_rad(a0)) * 1.5 + Vector3.UP * tilt
	var p1 = at + d.rotated(Vector3.UP, deg_to_rad(a1)) * 1.5 - Vector3.UP * tilt
	var axis = (p1 - p0).normalized()
	var nrm = axis.cross(d).normalized()
	if nrm.length() < 0.1:
		nrm = Vector3.UP
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.24:
			return false
		var sweep = clampf(age / 0.05, 0.0, 1.0)
		var e = p0.lerp(p1, sweep)
		var fade = 1.0 - clampf((age - 0.08) / 0.16, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, cm, [{"p": [p0, p0.lerp(e, 0.5), e], "w": 0.035, "a": 1.0, "k": 3}], fade, cam)
		var echo = []
		for o in [-0.14, -0.07, 0.07, 0.14]:
			echo.append({"p": [p0 + nrm * o, e + nrm * o], "w": 0.01, "a": 0.7 - absf(o) * 2.5, "k": 3})
		var wave = []
		for i in 25:
			var f = i / 24.0
			wave.append(p0.lerp(e, f) + nrm * sin(f * PI * 10.0 + age * 60.0) * 0.06)
		echo.append({"p": wave, "w": 0.01, "a": 0.6, "k": 3})
		L.draw(im, em, echo, fade * fade, cam)
		return true)


## Fıskiye kıvılcımları: her biri son yedi konumundan kavisli bir çizgi, yerçekimiyle eğilir
static func _spark_fountain(p: Vector3, d: Vector3, n: int) -> void:
	var m = L.arc_mat(SPARK_Y)
	var ps = []
	for i in n:
		var v = (d * 0.6 + L.rdir() * 0.8 + Vector3.UP * 0.5).normalized() * randf_range(6.0, 13.0)
		ps.append({"p": p, "v": v, "h": [p], "l": randf_range(0.45, 0.8)})
	L.host(func(im, _n, dt, age) -> bool:
		if age > 0.8:
			return false
		var polys = []
		for s in ps:
			if age > float(s["l"]):
				continue
			var v: Vector3 = s["v"]
			v = v * maxf(0.0, 1.0 - 1.5 * dt) + Vector3.DOWN * 14.0 * dt
			s["v"] = v
			s["p"] = Vector3(s["p"]) + v * dt
			var hist: Array = s["h"]
			hist.append(s["p"])
			if hist.size() > 7:
				hist.pop_front()
			if hist.size() >= 2:
				polys.append({"p": hist.duplicate(), "w": 0.012, "a": 1.0 - age / float(s["l"]), "k": 1})
		L.draw(im, m, polys, 1.0, L.cam_pos())
		return true)
	L.flash(p, 0.45, SPARK_Y, 0.07, 12.0)


static func cho_biburato_raitonto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 0.0, 10.0 if tt else 3.0)
	pj.busy(c, 1.0)
	_vibro_blade(pj, c, 1.0)
	for k in 4:
		pj.after(0.15 + k * 0.17, func():
			if not pj.live(c):
				return
			pj.anim(c, ["slash_a", "slash_b", "slash_a", "slash_c"][k], 2.0)
			var at = c.global_position + Vector3.UP * 1.1 + d * 1.0
			_vibro_cut(at, d, -60.0 + k * 20.0, 60.0 + k * 20.0, [0.35, -0.35, 0.2, 0.0][k])
			var hs = pj.hit(c, at + d * 0.6, 1.8, pj.inf(c, "cho_biburato_raitonto", 0.5, {"knock": 4.0 + k * 2.0, "kind": "heavy", "element": "raiton"}))
			if not hs.is_empty() and L.alive(hs[0]):
				_spark_fountain(hs[0].global_position + Vector3.UP * 1.0, d, 18 + k * 3)
				pj.shake(0.25)
			Sfx.play("clink", at, 1.2))


# ═════════════════════════════════════════ Raiden ═════════════════════════════════════════

## Kaynak (Kakashi + klon, Raiden): iki elde Raikiri, aralarında kalın, neredeyse düz, özü beyaz bir şimşek kablosu
## (çevresinde iki ince kırık tel); kablonun altındaki zeminde örümcek ağı gibi dallanan ince şimşek damarları. Hedefi
## biçince kablo hedefin gövdesine üç yükseklikte dönen kırık halkalar halinde sarılır.
static func _raiden_cable(o: Dictionary, hand_of: Callable, dur: float) -> void:
	var core_m = _thick_arc(RAI, 0.5)
	var am = L.arc_mat(RAI)
	var stt = {"next": 0.0, "main": [], "wires": [], "veins": [], "vn": 0.0}
	L.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var na = o["c"]
		var nb = o["cl"]
		if na == null or nb == null or not is_instance_valid(na) or not is_instance_valid(nb):
			return false
		var a: Vector3 = hand_of.call(na)
		var b: Vector3 = hand_of.call(nb)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			stt["main"] = [{"p": L.jag(a, b, 0.03, 4), "w": 0.09, "a": 1.0, "k": 2}]
			stt["wires"] = [{"p": L.jag(a, b, 0.14, 4), "w": 0.025, "a": 0.8}, {"p": L.jag(a, b, 0.14, 4), "w": 0.02, "a": 0.7}]
		if age >= float(stt["vn"]):
			stt["vn"] = age + 0.09
			var veins = []
			for k in 4:
				var g = L.floor_at(a.lerp(b, randf_range(0.15, 0.85)))
				veins.append({"p": L.ground_path(g, g + L.hdir() * randf_range(1.0, 2.6), 0.3, 3), "w": 0.03, "a": randf_range(0.5, 0.9)})
			stt["veins"] = veins
		var cam = L.cam_pos()
		L.draw(im, core_m, stt["main"], 1.0, cam)
		L.draw(im, am, stt["wires"], 1.0, cam)
		L.draw(im, am, stt["veins"], 1.0, cam, true)
		return true)


static func _coil_wrap(e: Node3D, dur: float) -> void:
	var am = L.arc_mat(RAI)
	var ew = weakref(e)
	var rad = 0.55
	var stt = {"next": 0.0, "polys": []}
	L.host(func(im, _n, _dt, age) -> bool:
		var x = ew.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree() or x.is_dead():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.07
			var out = []
			for k in 3:
				var c0: Vector3 = x.global_position + Vector3.UP * (0.7 + k * 0.4)
				var ring = []
				var ph = randf() * TAU
				for i in 13:
					var a = ph + TAU * i / 12.0
					ring.append(c0 + Vector3(cos(a) * rad, sin(a * 3.0 + age * 20.0) * 0.06 + randf_range(-0.04, 0.04), sin(a) * rad))
				out.append({"p": ring, "w": 0.03, "a": randf_range(0.6, 1.0), "k": 2})
			stt["polys"] = out
		L.draw(im, am, stt["polys"], clampf((dur - age) / 0.2, 0.0, 1.0), L.cam_pos())
		return true)


static func raiden(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 18.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var center = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	_raikiri(pj, c, true, 1.2, 1.0)
	_clone_pop(c.global_position + side * 1.5 + Vector3.UP, 0.8)
	var cl = pj.decoy(c, pj.gp(c.global_position + side * 1.5), 1.6)   # gölge klon
	if cl and cl.get("model"):
		cl.model.play("cast", 0.05, 1.0)
	if cl:
		_raikiri(pj, cl, true, 1.6, 1.0, false)
	Sfx.play("chidori", c.global_position, 0.9)
	var o = {"c": c, "cl": cl}
	var hand_of = func(n) -> Vector3:
		return (n.global_position + Vector3.UP * 1.2 + (n.face_dir() if n.has_method("face_dir") else d) * 0.4) if n != null and is_instance_valid(n) else center + Vector3.UP
	# ip: iki el arasında sürekli çıtırdayan keskin şimşek
	_raiden_cable(o, hand_of, 1.4)
	# ikisi hedefin iki yanından geçer
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var a_end = pj.gp(center - side * 2.2 + d * 3.0)
		var b_end = pj.gp(center + side * 2.2 + d * 3.0)
		c.create_tween().tween_property(c, "global_position", a_end, 0.3).set_trans(Tween.TRANS_QUAD)
		pj.anim(c, "dash", 1.4)
		if cl and is_instance_valid(cl):
			cl.create_tween().tween_property(cl, "global_position", b_end, 0.3).set_trans(Tween.TRANS_QUAD)
		pj.after(0.18, func():
			var hit_any = false
			for e in pj.enemies_near(c, center, 3.2):
				hit_any = true
				pj.st(e, "bind", 2.2)
				e.take_hit(pj.inf(c, "raiden", 1.6, {"knock": 0.0, "kind": "heavy", "element": "raiton", "stun": 0.5, "bleed": 3.0}))
				# ip hedefe sarılır
				_coil_wrap(e, 2.0)
			if hit_any:
				L.flash(center + Vector3.UP, 0.8, RAI, 0.09, 11.0)
				L.wet_shock(center + Vector3.UP, 1.4)
				pj.shake(0.5)
			Sfx.play("thunder", center, 1.2)))


# ═════════════════════════════════════════ Raikiri: Sōsenkō ═════════════════════════════════════════

## Kaynak (iki elde birer Raikiri, iki yana açılmış kollarda büyük beyaz çakmalar): iki elde Raikiri; elden yere kısa
## kırık şimşekler damlar. Atılışta iki elin arkasında iki paralel titrek şimşek izi ("çift delen ışık"). Her saplama
## hedefin içinden geçip arkasından dar bir koni halinde fışkıran kırık şimşek mızrağı, öne kıvılcım; ikincisi daha
## uzun ve yerde çatlak açar.
static func _sosen_pierce(at: Vector3, dn: Vector3, last: bool) -> void:
	var reach = 3.4 if last else 2.4
	L.zig_bolt(at - dn * 0.5, at + dn * reach, RAIKIRI_COL, 0.07 if last else 0.05, 0.22, 7, 0.12, 0.04)
	for k in (5 if last else 3):
		var sd = (dn + L.perp(dn) * randf_range(0.25, 0.5)).normalized()
		L.bolt(at + dn * 0.6, at + dn * 0.6 + sd * randf_range(1.2, 2.2) * (1.3 if last else 1.0), RAIKIRI_COL, 0.03, 0.18, 1, 0.22)
	L.flash(at, 0.85 if last else 0.6, RAIKIRI_COL, 0.09, 12.0)
	L.sparks(at + dn * 0.5, 14 if last else 8, RAIKIRI_COL, 11.0, 0.35, dn, 0.5, 0.018)


static func _twin_streak(pj: PathJutsu, c: Node3D, dur: float) -> void:
	for bn in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, bn)
		if ba:
			L.trail(ba, RAIKIRI_COL, 0.1, 0.25, 0.06)
			pj.free_after(dur, ba)


static func raikiri_sosenko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tgn = Jutsu._tg(c, t, 22.0)
	var aim = MsArts._aim_fn(c, tgn, 8.0)
	var d = MsArts._turn(c, aim.call())
	pj.busy(c, 1.25)
	MsArts._anim(c, "cast", 1.4)
	_raikiri(pj, c, true, 1.0, 1.15)
	_raikiri(pj, c, false, 1.3, 1.15)
	Sfx.play("chidori", c.global_position, 1.1)
	for k in 5:
		MsArts._later(0.05 + k * 0.06, func():
			if MsArts._alive(c):
				for r in [true, false]:
					var hp = pj.hand_pos(c, r)
					L.bolt(hp, Jutsu._ground(hp + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))), RAIKIRI_COL, 0.035, 0.12, 1, 0.22))
	MsArts._later(0.36, func():
		if not MsArts._alive(c):
			return
		var to: Vector3 = aim.call()
		to.y = c.global_position.y
		var dd = to - c.global_position
		var dist = minf(maxf(0.0, dd.length() - 1.4), MsArts._free_dist(c.global_position + Vector3.UP, d, 22.0))
		MsArts._anim(c, "dash", 1.6)
		_twin_streak(pj, c, 0.5)
		MsArts._dash_to(c, Jutsu._ground(c.global_position + d * dist) + Vector3.UP * 0.05, 0.2))
	for k in 2:
		MsArts._later(0.6 + k * 0.3, func():
			if not MsArts._alive(c):
				return
			var dn = MsArts._turn(c, aim.call())
			MsArts._anim(c, "cross" if k == 0 else "jab", 1.8)
			var at = c.global_position + Vector3.UP * 1.1 + dn * 1.3
			var last = k == 1
			Combat.hit_sphere(c, at, 2.0, MsArts._inf(c, "raikiri_sosenko", 0.6 if last else 0.4, {"knock": 15.0 if last else 0.5, "launch": 3.0 if last else 0.0, "kind": "heavy",
				"element": "raiton", "stun": 0.4 if last else 0.6, "hitstop": 0.1 if last else 0.06, "pierce_guard": true, "dir": dn}))
			_sosen_pierce(at, dn, last)
			if last:
				_crack_web(Jutsu._ground(at), 3.0, 8, 3.0, RAIKIRI_COL)
				MsArts._shake(0.6)
			Sfx.play("zap", at, 1.0 + k * 0.2))


# ═════════════════════════════════════════ Raikiri Issen ═════════════════════════════════════════

## Kaynak (Raikiri ile göz açıp kapayana dek varış, yukarı fışkıran kırık şimşekler, uçuşan kaya parçaları): elde
## Raikiri; varışta hız çizgileri. Kavrayışta küçük çakma ve kısa dallar. Sürüklerken hedefin altında zemine kazınan,
## kenarı mavi-beyaz akkor (yavaş soğuyan) koyu bir oluk; her adımda elden yere kırık şimşek, kaya kırıntısı, üç adımda
## bir çatlak. Fırlatışta öne-yukarı yelpaze gibi açılan kırık şimşekler, çakma, kırıntı, toz halkası.
static func _issen_gouge(m: Node3D, rec: float, life: float) -> void:
	var dark = _ink(Color(0.1, 0.08, 0.07))
	var hot = L.arc_mat(RAI)
	var mw = weakref(m)
	var pts = []
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var x = mw.get_ref()
		if age < rec and x != null and is_instance_valid(x) and x.is_inside_tree():
			var g = L.floor_at(x.global_position) + Vector3.UP * 0.04
			if pts.is_empty() or Vector3(pts[pts.size() - 1]["p"]).distance_to(g) > 0.2:
				pts.append({"p": g, "t": age})
		if pts.size() < 2:
			return true
		var line = []
		var hotl = []
		for q in pts:
			line.append(q["p"])
			if age - float(q["t"]) < 0.5:
				hotl.append(Vector3(q["p"]) + Vector3.UP * 0.02)
		var fade = clampf((life - age) / 1.2, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, dark, [{"p": line, "w": 0.32, "a": 0.85, "k": 2}], fade, cam, true)
		if hotl.size() >= 2:
			L.draw(im, hot, [{"p": hotl, "w": 0.09, "a": 1.0, "k": 1}], 1.0, cam, true)
		return true)


static func _issen_grip(p: Vector3) -> void:
	L.flash(p, 0.55, RAI, 0.08, 10.0)
	for k in 4:
		L.bolt(p, p + L.rdir() * randf_range(0.8, 1.6), RAI, 0.035, 0.16, 1, 0.22)


static func _issen_throw(p: Vector3, d: Vector3) -> void:
	L.flash(p, 0.9, RAI, 0.1, 12.0)
	for k in 8:
		var dir = (d * 0.6 + Vector3.UP * randf_range(0.6, 1.4) + L.perp(d) * randf_range(-0.8, 0.8)).normalized()
		L.bolt(p, p + dir * randf_range(2.0, 3.6), RAI, 0.05, 0.25, 2, 0.2)
	var g = L.floor_at(p)
	L.debris(g, 10, 8.0, EARTH, d * 0.6)
	L.dust_ring(g, 0.4, 3.2, 0.55, DUST)


static func raikiri_issen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tgn = Jutsu._tg(c, t, 26.0)
	if tgn == null:
		if c is Player:
			Hud.msg("Raikiri Issen: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = MsArts._turn(c, tgn.global_position)
	var H = float(tgn.get("height")) if tgn.get("height") != null else 1.8
	var big = H > 4.0
	pj.busy(c, 1.7)
	MsArts._flicker_guard(c, 0.5)
	MsArts._anim(c, "cast", 1.6)
	_raikiri(pj, c, true, 1.6, 1.2)
	Sfx.play("chidori", c.global_position, 1.3)
	var wr = weakref(tgn)
	MsArts._later(0.3, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		d = MsArts._turn(c, n.global_position)
		var gap = c.global_position.distance_to(n.global_position)
		L.speed_lines(c, d, 0.35, WHITE, 10)
		MsArts._anim(c, "dash", 2.0)
		MsArts._dash_to(c, Jutsu._ground(c.global_position + d * maxf(0.0, gap - 1.2 - H * 0.2)) + Vector3.UP * 0.05, 0.1))
	MsArts._later(0.42, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		n.take_hit(MsArts._inf(c, "raikiri_issen", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "element": "raiton", "hitstop": 0.08, "pierce_guard": true, "dir": d}))
		_issen_grip(MsArts._chest(n))
		if big or n.is_dead():
			return
		# sürükleme: önündeki açık mesafe kadar (en fazla 13 m)
		var dist = minf(13.0, MsArts._free_dist(c.global_position + Vector3.UP, d, 14.0))
		var p0 = c.global_position
		n.apply_status("bind", 1.0)
		_issen_gouge(n, 0.9, 4.0)
		var stt = {"k": 0}
		var tw = MsArts._tw()
		tw.tween_method(func(x: float):
			var m = wr.get_ref()
			if not MsArts._alive(c) or m == null or m.is_dead():
				return
			var cp = Jutsu._ground(p0 + d * dist * x)
			MsArts._blink(c, cp + Vector3.UP * 0.05)
			m.global_position = Jutsu._ground(cp + d * 1.1)
			if m is CharacterBody3D:
				m.velocity = Vector3.ZERO
			var step = int(x * 12.0)
			if step != stt["k"]:
				stt["k"] = step
				var hp = pj.hand_pos(c, true)
				L.bolt(hp, Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))), RAI, 0.04, 0.15, 1, 0.22)
				L.debris(m.global_position + Vector3.UP * 0.2, 4, 5.0, EARTH)
				if step % 3 == 0:
					_crack_web(m.global_position, 1.8, 6, 2.5)
					m.take_hit(MsArts._inf(c, "raikiri_issen", 0.1, {"knock": 0.0, "launch": 0.0, "kind": "light", "element": "raiton", "pierce_guard": true}))
					m.apply_status("bind", 0.5), 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not MsArts._alive(c) or m == null or m.is_dead():
				return
			MsArts._anim(c, "push", 1.8)
			m.take_hit(MsArts._inf(c, "raikiri_issen", 0.4, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.8, "hitstop": 0.1, "dir": d}))
			_issen_throw(MsArts._chest(m), d)
			MsArts._shake(0.7)
			Sfx.play("zap", m.global_position, 0.8)))


# ═════════════════════════════════════════ Raijū Hashiri no Jutsu: Sō ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) İki şimşek canavarı: opak, iki tonlu cel gölgeli açık mavi kurt gövdesi (koyu lacivert dış
## çizgi), sivri kulaklar, beyaz diken yele, sivri burun, beyaz-sarı gözler, açılıp kapanan alt çene, yukarı kalkık kuyruk;
## gövdede çakan beyaz damarlar. Ön ve arka bacak çiftleri karşı evrede dörtnala koşar, gövde iner kalkar; çevresinde
## ince çatırtı, bastığı yerde küçük yanıklar. Isırıkta küçük çakma, kıvılcım, yerde yanık ve kısa yer arkları.
static func _leg_mesh() -> ArrayMesh:
	if _mc.has("leg"):
		return _mc["leg"]
	var b = MB.new()
	var body = Color(0.62, 0.82, 1.0)
	b.add("cyl", Vector3(0, -0.22, 0), Vector3(0.09, 0.44, 0.09), body, Vector3.ZERO, 6)
	b.add("sphere", Vector3(0, -0.45, -0.03), Vector3(0.12, 0.07, 0.15), body, Vector3.ZERO, 8)
	var m = b.build(null)
	_mc["leg"] = m
	return m


static func _bolt_hound(s: float) -> Node3D:
	var root = Node3D.new()
	root.scale = Vector3.ONE * s
	var body = Color(0.62, 0.82, 1.0)
	var mane = Color(0.93, 0.97, 1.0)
	var dark = Color(0.08, 0.12, 0.3)
	var eye = Color(1.0, 1.0, 0.85)
	var b = MB.new()
	b.add("sphere", Vector3(0, 0.52, 0.05), Vector3(0.36, 0.34, 0.8), body, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.56, -0.25), Vector3(0.42, 0.42, 0.45), body, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.68, -0.45), Vector3(0.24, 0.3, 0.26), body, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.78, -0.6), Vector3(0.3, 0.26, 0.32), body, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.75, -0.8), Vector3(0.17, 0.3, 0.15), body, Vector3(-90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0.755, -0.95), Vector3(0.06, 0.05, 0.05), dark, Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.09, 0.95, -0.58), Vector3(0.09, 0.2, 0.07), body, Vector3(-10, 0, -sx * 15.0), 5)
		b.add("sphere", Vector3(sx * 0.085, 0.81, -0.73), Vector3(0.07, 0.05, 0.04), eye, Vector3.ZERO, 6)
		b.add("sphere", Vector3(sx * 0.087, 0.81, -0.75), Vector3(0.025, 0.035, 0.02), dark, Vector3.ZERO, 6)
	for k in 5:
		b.add("cone", Vector3(0, 0.8 - k * 0.04, -0.42 + k * 0.13), Vector3(0.07, 0.24 - k * 0.02, 0.07), mane, Vector3(35, 0, 0), 5)
	b.add("cone", Vector3(0, 0.66, 0.55), Vector3(0.1, 0.55, 0.1), body, Vector3(60, 0, 0), 6)
	b.add("cone", Vector3(0, 0.88, 0.78), Vector3(0.06, 0.2, 0.06), mane, Vector3(60, 0, 0), 5)
	var bm = _beast_mat()
	var lm = L.line_mat(LINE_DARK, 0.022)
	var torso = L.mi_of(b.build(null), bm)
	torso.material_overlay = lm
	root.add_child(torso)
	var jb = MB.new()
	jb.add("box", Vector3(0, 0, -0.11), Vector3(0.12, 0.04, 0.22), body)
	jb.add("box", Vector3(0, 0.025, -0.11), Vector3(0.1, 0.012, 0.2), Color(0.7, 0.15, 0.2))
	var jaw = L.mi_of(jb.build(null), bm)
	jaw.material_overlay = lm
	jaw.position = Vector3(0, 0.69, -0.68)
	root.add_child(jaw)
	var legs = []
	for hip in [Vector3(-0.12, 0.42, -0.28), Vector3(0.12, 0.42, -0.28), Vector3(-0.12, 0.42, 0.3), Vector3(0.12, 0.42, 0.3)]:
		var lg = L.mi_of(_leg_mesh(), bm)
		lg.material_overlay = lm
		lg.position = hip
		root.add_child(lg)
		legs.append(lg)
	var stt = {"paw": 0.0}
	var gait = func(_n, _dt, age) -> bool:
		if not is_instance_valid(torso):
			return false
		var w = age * 16.0
		for i in legs.size():
			var lg: MeshInstance3D = legs[i]
			lg.rotation.x = sin(w + (0.0 if i < 2 else PI) + (0.25 if i % 2 == 1 else 0.0)) * 0.8
		torso.position.y = absf(sin(w)) * 0.04
		jaw.rotation.x = -(0.5 + 0.5 * sin(age * 9.0)) * 0.45
		if root.is_inside_tree() and age >= float(stt["paw"]):
			stt["paw"] = age + 0.2
			L.scorch(L.floor_at(root.global_position), 0.25 * s, RAI, 1.5, 0.3)
		return true
	L.pulse(Vector3.ZERO, gait, root)
	return root


static func _hound_snap(p: Vector3) -> void:
	L.flash(p, 0.7, RAI, 0.08, 9.0)
	L.sparks(p, 12, RAI, 9.0, 0.35)
	var g = L.floor_at(p)
	if p.y - g.y < 2.5:
		L.scorch(g, 0.8, RAI, 4.0, 0.5)
		L.ground_arcs(g, 1.2, 0.35, RAI, 4, 0.035)


static func raiju_hashiri_so(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tgn = Jutsu._tg(c, t, 34.0)
	var aim = MsArts._aim_fn(c, tgn, 14.0)
	var d = MsArts._turn(c, aim.call())
	pj.busy(c, 0.8)
	MsArts._anim(c, "cast", 1.2)
	_raikiri(pj, c, true, 0.5, 0.9)
	_raikiri(pj, c, false, 0.5, 0.9)
	Sfx.play("chidori", c.global_position, 1.2)
	MsArts._later(0.3, func():
		if not MsArts._alive(c):
			return
		MsArts._anim(c, "cast_out", 1.4)
		for sgn in [-1.0, 1.0]:
			var head = Node3D.new()
			var hound = _bolt_hound(1.9)
			hound.position.y = -0.8
			head.add_child(hound)
			var dir = d.rotated(Vector3.UP, sgn * 0.75)   # önce yana açılır, sonra hedefe kıvrılır
			var from = Jutsu._ground(c.global_position + dir * 1.2) + Vector3.UP * 0.9
			var pr = pj.shot(c, from, dir, 26.0, head, MsArts._inf(c, "raiju_hashiri_so", 0.5, {"knock": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.9}), tgn, false, 2.2, func(p, _h):
				_hound_snap(p)
				L.wet_shock(p, 1.3)
				pj.shake(0.57))
			pr.homing_turn = 5.5
			pr.radius = 0.7
			L.crackle(L.follow_fn(hound, Vector3.UP * 1.0), 1.1, 2.2, RAI, 4, 0.03, 0.06, hound))


# ═════════════════════════════════════════ Raiton: Daburu Rariatto ═════════════════════════════════════════

## Kaynak (A ve B'nin makası): ortağın çevresinde turuncu-kırmızı, koyu kırmızı çizgili kabarcıklı chakra dilleri;
## arka planda dışa koşan hız çizgileri; iki kol hedefin boynunda buluşur. Taijutsu: iki yandan (önden atanın mavi
## kenarlı, arkadan ortağın turuncu kenarlı) beyaz savuruş hilali boyunda kapanır; buluşma noktasında koşu eksenine dik
## düzlemde darbe çizgisi yıldızı, bir an iki el arasında kısa kırık şimşek, küçük turuncu-beyaz çakma, yerde toz halkası
## ve kırıntı.
static func _bijuu_tongues(n: Node3D, dur: float) -> void:
	var m = L.band_mat(Color(1.0, 0.82, 0.55), CHAKRA_OR, Color(0.55, 0.08, 0.04))
	var nw = weakref(n)
	var seeds = []
	for k in 8:
		seeds.append({"a": TAU * k / 8.0 + randf_range(-0.2, 0.2), "ph": randf() * TAU, "h": randf_range(1.7, 2.3)})
	L.host(func(im, _n, _dt, age) -> bool:
		var x = nw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var base: Vector3 = x.global_position
		var polys = []
		for sd in seeds:
			var a = float(sd["a"]) + sin(age * 3.0 + float(sd["ph"])) * 0.2
			var pts = []
			for i in 7:
				var f = i / 6.0
				var r = 0.5 + 0.12 * sin(f * 9.0 - age * 14.0 + float(sd["ph"])) + f * f * 0.35
				var aa = a + f * 0.6
				pts.append(base + Vector3(cos(aa) * r, 0.1 + f * float(sd["h"]), sin(aa) * r))
			polys.append({"p": pts, "w": 0.09, "a": 0.85, "k": 0})
		var env = clampf(age / 0.15, 0.0, 1.0) * clampf((dur - age) / 0.3, 0.0, 1.0)
		L.draw(im, m, polys, env, L.cam_pos())
		return true)


## İki hilal: from_a ve from_b'den boyun noktasına kapanan kalın savuruş izleri (0.06 sn), sonra söner
static func _scissor_arcs(neck: Vector3, from_a: Vector3, from_b: Vector3, d: Vector3) -> void:
	var ma = _smear_mat(Color(1, 1, 1), Color(0.55, 0.78, 1.0))
	var mb = _smear_mat(Color(1, 1, 1), Color(1.0, 0.55, 0.25))
	var side = d.cross(Vector3.UP).normalized()
	var arcs = []
	for q in 2:
		var src: Vector3 = from_a if q == 0 else from_b
		var pts = []
		for i in 9:
			var f = i / 8.0
			pts.append(src.lerp(neck, f) + side * sin(f * PI) * (0.9 if q == 0 else -0.9))
		arcs.append(pts)
	L.host(func(im, _n, _dt, age) -> bool:
		if age > 0.35:
			return false
		var cnt = clampi(int(ceil(9.0 * clampf(age / 0.06, 0.0, 1.0))), 2, 9)
		var fade = 1.0 - clampf((age - 0.12) / 0.23, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, ma, [{"p": (arcs[0] as Array).slice(0, cnt), "w": 0.26, "a": 0.9, "k": 1}], fade, cam)
		L.draw(im, mb, [{"p": (arcs[1] as Array).slice(0, cnt), "w": 0.26, "a": 0.9, "k": 1}], fade, cam)
		return true)


static func raiton_daburu_rariatto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	var partner: Node3D = null
	var best = 21.0
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if f == c or f.is_dead() or Combat.hostile(c, f) or f is TailedBeast:
			continue
		var dd = f.global_position.distance_to(c.global_position)
		if dd < best and (f.get("team") == c.get("team")):
			best = dd
			partner = f
	if partner == null:
		if c is Player:
			Hud.msg("Daburu Rariatto iki kişilik tekniktir: yakında bir ortak (takım arkadaşı, gölge klon ya da çağrı) olmalı.", Color(0.75, 0.88, 1.0))
		return
	if tt == null:
		return
	L.body_arcs(c, 1.4, RAIKAGE, 2, 0.025)
	pj.busy(c, 1.0)
	_bijuu_tongues(partner, 1.4)
	pj.after(0.3, func():
		if not (pj.live(c) and pj.live(tt)):
			return
		var d = (tt.global_position - c.global_position)
		d.y = 0
		d = d.normalized()
		var p1 = pj.gp(tt.global_position - d * 1.2)   # önden (kullanıcı)
		var p2 = pj.gp(tt.global_position + d * 1.2)   # arkadan (ortak)
		var tw = c.create_tween()
		tw.tween_property(c, "global_position", p1, 0.2)
		L.speed_lines(c, d, 0.25, WHITE, 8)
		if is_instance_valid(partner):
			var back = partner.global_position
			var tw2 = partner.create_tween()
			tw2.tween_property(partner, "global_position", p2, 0.2)
			tw2.tween_interval(0.5)
			tw2.tween_property(partner, "global_position", back, 0.25)
		pj.after(0.22, func():
			if pj.live(tt):
				var neck = tt.global_position + Vector3.UP * 1.5
				_scissor_arcs(neck, p1 + Vector3.UP * 1.5 - d * 0.6, p2 + Vector3.UP * 1.5 + d * 0.6, d)
				_impact_lines(neck, d, 16, 0.35, 2.4, 0.26, WHITE, 0.035)
				L.zig_bolt(p1 + Vector3.UP * 1.5, p2 + Vector3.UP * 1.5, RAIKAGE, 0.05, 0.2, 6, 0.15)
				L.flash(neck, 0.8, Color(1.0, 0.7, 0.4), 0.09, 10.0)
				var g = L.floor_at(tt.global_position)
				L.dust_ring(g, 0.4, 2.8, 0.5, DUST)
				L.debris(g, 10, 8.0, EARTH)
				tt.take_hit(pj.inf(c, "raiton_daburu_rariatto", 3.6, {"knock": 6.0, "launch": 10.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.18, "pierce_guard": true}))
				pj.shake(1.0)))
	Sfx.play("thunder", c.global_position, 1.0)


# ═════════════════════════════════════════ Hatake: Shiden ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım; Kakashi'nin mor şimşeği) Elde mor kıvılcımlar toplanır, avuçta küçük mor çakma ve
## çatırtı. Salınım kalın bir dal değil: dümdüz beyaz-leylak ince öz iplik çevresinde burularak örülen dört ince, kırık
## mor tel (helis), 0.08 sn'de 30 m'ye uzanır; ucunda üç dişli sivri mor çatal. Sonra örgü kökten uca doğru çözülüp söner;
## yol boyunca aşağı damlayan mor kıvılcımlar, uçta küçük mor çakma.
static func _shiden_lance(from: Vector3, d: Vector3, reach: float) -> void:
	var pm = L.arc_mat(PURPLE)
	var wm = _thick_arc(Color(0.85, 0.7, 1.0), 0.5)
	var u = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var v = d.cross(u).normalized()
	var stt = {"next": 0.0, "polys": [], "core": []}
	var life = 0.5
	L.host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		var grow = clampf(age / 0.08, 0.0, 1.0)
		var tip = from + d * reach * grow
		var unr = clampf((age - 0.15) / 0.35, 0.0, 1.0)
		var base = from + d * reach * unr * 0.9
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var strands = []
			var n = 26
			for q in 4:
				var line = []
				for i in n + 1:
					var f = float(i) / n
					var p = base.lerp(tip, f)
					var a = (p - from).length() * 1.4 + q * TAU / 4.0 + age * 30.0
					line.append(p + (u * cos(a) + v * sin(a)) * randf_range(0.1, 0.17) + L.rdir() * 0.05)
				strands.append({"p": line, "w": 0.026, "a": 1.0, "k": 2})
			for q in 3:
				var pd = (d + (u * cos(q * TAU / 3.0) + v * sin(q * TAU / 3.0)) * 0.35).normalized()
				strands.append({"p": L.zigzag(tip + pd * 1.3, tip, 4, 0.12), "w": 0.035, "a": 1.0, "k": 1})
			stt["polys"] = strands
			stt["core"] = [{"p": L.jag(base, tip, 0.006, 3), "w": 0.05, "a": 1.0, "k": 2}]
		var fade = 1.0 - clampf((age - 0.35) / 0.15, 0.0, 1.0)
		var cam = L.cam_pos()
		L.draw(im, wm, stt["core"], fade, cam)
		L.draw(im, pm, stt["polys"], fade, cam)
		return true)
	for k in 6:
		L.sparks(from + d * (k + 0.5) * 5.0, 4, PURPLE, 4.0, 0.4, Vector3.DOWN, 0.6, 0.015)
	L.flash(from + d * reach, 0.6, PURPLE, 0.1, 10.0)


static func hatake_shiden(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 34.0)
	var hf = L.hand_fn(pj, c, true)
	L.converge(hf, 1.3, 0.4, PURPLE, 12, 0.02)
	L.crackle(hf, 0.3, 0.8, PURPLE, 4, 0.025)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		L.flash(Vector3.ZERO, 0.3, PURPLE, 0.4, 11.0, ba)
		pj.free_after(0.8, ba)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var d = pj.aim_at(c, tt, from)
		_shiden_lance(from, d, 30.0)
		Combat.hit_zone(c, from - Vector3.UP * 1.2, d, 30.0, 8.0, 2.0, pj.inf(c, "hatake_shiden", 1.8, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8})))
	Sfx.play("chidori", c.global_position, 1.0)
