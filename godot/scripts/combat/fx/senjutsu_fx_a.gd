class_name SenjutsuFXA
extends RefCounted
## Senjutsu grubu A: on beş bilge / lanet mührü / Altı Yol tekniğinin görselleri — hepsi bu dosyada, sıfırdan.
## Yapı taşları: doğa enerjisi akışı (çevreden içe süzülen turuncu-sarı zerreler, yavaş girdap), cel malzeme + kalın kontur,
## kameraya yaklaşınca sönen enerji gölgelendiricisi, yer yarığı izi, balistik kırıntı, canlı tüp (dil / zincir kol / boyun).
## Beden modları gerçek bedeni kullanır: ten rengi (CharacterModel.set_skin_tint), ten desenleri (toon sage_marks: lanet
## mührü 5), bilge göz/yüz izi (CharacterModel.set_sage), Altı Yol örtüsü bedenin kendi derili örgüsünden kabuk. Kutu kabuk yok.
## Yılan teknikleri oyunun gerçek yılan gövdesini (SleeveSnake) beyaz bilge yılanı rengiyle kullanır.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, zemin bölgeleri) ana ağaçtan taşındı.

const NAT := Color(1.0, 0.6, 0.15)          # doğa enerjisi turuncusu
const NAT_HI := Color(1.0, 0.92, 0.55)      # zerre çekirdeği
const JUGO_SKIN := Color(0.58, 0.5, 0.44)   # Jūgo klanı bilge dönüşümü teni (boz-gri)
const FLESH := Color(0.6, 0.55, 0.5)        # dönüşen kol eti
const SNAKE_W := Color(0.9, 0.9, 0.85)      # beyaz bilge yılanı sırtı
const SNAKE_B := Color(0.95, 0.88, 0.7)     # karın
const INK := Color(0.04, 0.03, 0.04)
const GOLD := Color(1.0, 0.8, 0.28)
const KABUTO := Color(0.55, 0.95, 0.8)      # Kabuto'nun bilge chakrası (soluk yeşil-turkuaz)
const EARTHC := Color(0.5, 0.42, 0.33)

static var _shaders := {}
static var _cache := {}


# ================================================================== gölgelendiriciler
const CEL_SH := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 glow_col : source_color = vec4(1.0, 0.6, 0.2, 1.0);
void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_col.rgb * glow * (0.35 + fr);
	ROUGHNESS = 1.0;
}
"""

const LINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled, shadows_disabled;
uniform vec4 line_col : source_color = vec4(0.06, 0.045, 0.04, 1.0);
uniform float width = 0.012;
void vertex() {
	VERTEX += normalize(NORMAL) * width;
}
void fragment() {
	ALBEDO = line_col.rgb;
}
"""

# enerji: kenarı parlayan, akan gürültülü, kameraya yakın kısmı sönen (ekranı kaplamasın)
const EN_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float amount = 1.0;
uniform float flow = 2.0;
uniform float edge = 1.0;
uniform float near_fade = 1.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 lp;
varying float camd;
void vertex() {
	lp = VERTEX;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float n = vnoise(lp.xy * 5.0 + vec2(0.0, -TIME * flow)) * 0.6 + vnoise(lp.zy * 9.0 + vec2(TIME * flow * 0.7, 0.0)) * 0.4;
	vec3 c = mix(core.rgb, col.rgb, clamp(fres * edge + n * 0.35, 0.0, 1.0));
	ALBEDO = c * COLOR.rgb;
	float a = clamp(0.3 + fres * 0.55 + n * 0.3, 0.0, 1.0) * amount * COLOR.a;
	ALPHA = clamp(a, 0.0, 1.0) * smoothstep(near_fade * 0.4, near_fade, camd);
}
"""

# düz yer izi (yarık, toz eteği): köşe rengi × renk, yavaş sönme
const FLAT_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 col : source_color = vec4(0.1, 0.08, 0.06, 0.9);
uniform float amount = 1.0;
void fragment() {
	ALBEDO = col.rgb * COLOR.rgb;
	ALPHA = col.a * amount * COLOR.a;
}
"""

# arayış topu: mürekkep siyahı, ince mor-gri kenar, keskin beyaz parlama noktası
const ORB_SH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float amount = 1.0;
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 c = mix(vec3(0.025, 0.02, 0.03), vec3(0.32, 0.26, 0.4), fr);
	vec3 hl = normalize(vec3(-0.35, 0.55, 0.75));
	if (dot(NORMAL, hl) > 0.93) c = vec3(0.92, 0.9, 0.95);
	ALBEDO = c;
}
"""

# yüze/boyna basılan mühür: kameraya dönük, yüzeyin hafif önüne itilir (boyna çizilmiş gibi her açıdan okunur)
const MARK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float amount = 1.0;
uniform vec4 col : source_color = vec4(0.03, 0.02, 0.04, 1.0);
uniform vec4 halo : source_color = vec4(0.6, 0.2, 0.75, 1.0);
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	VERTEX.z += 0.15 / max(s, 0.001);
}
void fragment() {
	ALBEDO = mix(halo.rgb, col.rgb, COLOR.r);
	ALPHA = amount * mix(0.55, 1.0, COLOR.r);
}
"""

# Altı Yol örtüsü: bedenin kendi derili örgüsü, dinlenme pozuna (CUSTOM0) bağlı desen — altın-turuncu kaynayan chakra,
# önde iki kara şerit, kol ağzında ve etekte kara bant; baş, el ve alt bacak açık
const CLOAK_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;
uniform float amount = 0.0;
uniform vec4 gold : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform vec4 deep : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float grow = 0.035;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 rp;
varying float camd;
void vertex() {
	rp = CUSTOM0.xyz;
	float b = vnoise(rp.xy * 8.0 + vec2(0.0, -TIME * 2.0));
	VERTEX += NORMAL * grow * (0.8 + b * 0.6);
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	if (rp.y > 1.5 || rp.y < 0.32 || abs(rp.x) > 0.64) discard;
	float rimv = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.7);
	float fl = vnoise(vec2(rp.x * 7.0 + rp.z * 5.0, rp.y * 5.0 - TIME * 2.5));
	vec3 c = mix(gold.rgb, deep.rgb, smoothstep(0.35, 0.9, fl) * 0.6 + rimv * 0.4);
	bool arm = abs(rp.x) > 0.24 && rp.y > 1.0;
	float ink = 0.0;
	if (!arm && rp.z > 0.0 && abs(abs(rp.x) - 0.07) < 0.012 && rp.y < 1.3) ink = 1.0;
	if (arm && abs(abs(rp.x) - 0.58) < 0.022) ink = 1.0;
	if (rp.y < 0.39) ink = 1.0;
	c = mix(c, vec3(0.04, 0.03, 0.02), ink);
	ALBEDO = c * (0.9 + rimv * 0.5);
	float a = mix(0.5 + rimv * 0.45 + fl * 0.1, 0.95, ink);
	ALPHA = clamp(a * amount, 0.0, 1.0) * smoothstep(0.5, 1.4, camd);
}
"""


static func _sh(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s = Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]


## Cel malzeme (köşe rengi × tint) + kalın kontur geçişi
static func cel(tint := Color.WHITE, line := 0.012, glow := 0.0, glow_col := NAT) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("cel", CEL_SH)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("glow_col", glow_col)
	if line > 0.0:
		var o = ShaderMaterial.new()
		o.shader = _sh("line", LINE_SH)
		o.set_shader_parameter("width", line)
		m.next_pass = o
	return m


## Enerji malzemesi (her çağrıda yeni: ayrı ayrı söner)
static func energy(col: Color, core: Color, add := true, flow := 2.0, near := 1.6) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("en_add" if add else "en_mix", EN_SH % ("add" if add else "mix"))
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("near_fade", near)
	return m


static func flat(col: Color) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("flat", FLAT_SH)
	m.set_shader_parameter("col", col)
	return m


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Malzemenin "amount"unu söndürüp düğümü siler
static func _fade(n: Node, m: ShaderMaterial, delay: float, dur: float, free := true) -> void:
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var a0 = m.get_shader_parameter("amount")
	tw.tween_method(func(x: float): m.set_shader_parameter("amount", x), 1.0 if a0 == null else float(a0), 0.0, dur)
	if free:
		tw.tween_callback(n.queue_free)


## Katı (opak) parçayı küçültüp siler
static func _shrink(n: Node3D, delay: float, dur: float) -> void:
	var tw = n.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(n, "scale", Vector3.ONE * 0.02, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


static func _basis_y(v: Vector3) -> Basis:
	var y = v.normalized() if v.length() > 0.0001 else Vector3.UP
	var x = y.cross(Vector3.UP)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


## d yönüne bakan taban (-Z = d)
static func _basis_look(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
	var up = Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(f, up)


static func _ring_mesh(inner: float, outer: float, seg := 40) -> ArrayMesh:
	var key = "ring_%.2f_%.2f_%d" % [inner, outer, seg]
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var p = [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer),
			Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		var cs = [Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25)]
		for q in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_color(cs[q])
			st.add_vertex(p[q])
	var m = st.commit()
	_cache[key] = m
	return m


# ================================================================== yapı taşları
## Doğa enerjisi akışı: çevreden içe süzülen turuncu-sarı ince zerreler, yavaş girdap, merkeze yaklaştıkça hızlanır.
## outward: tersine — merkezden dışa savrulur (Altı Yol salınımı)
class Inflow extends MultiMeshInstance3D:
	var center: Callable
	var radius := 4.0
	var swirl := 1.2
	var speed := 3.0
	var dur := 1.0
	var outward := false
	var t := 0.0
	var parts: Array = []

	func setup(n: int, mat: Material, len_k := 1.0) -> void:
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.instance_count = n
		var cm = CapsuleMesh.new()
		cm.radius = 0.03
		cm.height = 0.28 * len_k
		cm.radial_segments = 6
		cm.rings = 1
		mm.mesh = cm
		multimesh = mm
		material_override = mat
		for i in n:
			parts.append(_fresh(true))

	func _fresh(first: bool) -> Array:
		var r0 = (radius * (randf_range(0.35, 1.0) if first else randf_range(0.8, 1.0))) if not outward else randf_range(0.1, 0.4)
		return [randf() * TAU, r0, randf_range(-0.5, 1.1), speed * randf_range(0.7, 1.3)]

	func _process(dt: float) -> void:
		t += dt
		if not center.is_valid() or t > dur + 6.0:
			queue_free()
			return
		var cp: Vector3 = center.call()
		var alive = 0
		for i in parts.size():
			var s: Array = parts[i]
			if s[1] < 0.0:
				multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), cp))
				continue
			if outward:
				s[1] += s[3] * dt * 1.6
				s[0] += swirl * dt * 0.6
				if s[1] > radius:
					s[1] = -1.0
					continue
			else:
				s[1] -= s[3] * dt * (0.6 + 0.9 * (1.0 - s[1] / radius))
				s[0] += swirl * dt * (1.5 / (s[1] + 0.5))
				if s[1] <= 0.12:
					if t < dur:
						parts[i] = _fresh(false)
						s = parts[i]
					else:
						s[1] = -1.0
						continue
			alive += 1
			var r: float = s[1]
			var ang: float = s[0]
			var p = cp + Vector3(cos(ang) * r, float(s[2]) * r * 0.45, sin(ang) * r)
			var inward = (cp - p).normalized() * (-1.0 if outward else 1.0)
			var tang = Vector3(-sin(ang), 0, cos(ang)) * swirl * 0.6
			var b = SenjutsuFXA._basis_y(inward + tang)
			var a = clampf((radius - r) / (radius * 0.3), 0.0, 1.0) * clampf(r / 0.4, 0.15, 1.0)
			if outward:
				a = clampf(1.0 - r / radius, 0.0, 1.0)
			if t > dur:
				a *= clampf(1.0 - (t - dur) / 0.6, 0.0, 1.0) if outward else 1.0
			multimesh.set_instance_transform(i, Transform3D(b, p))
			multimesh.set_instance_color(i, Color(1, 1, 1, a))
		if t > dur and alive == 0:
			queue_free()


static func _inflow(pj: PathJutsu, center: Callable, radius: float, n: int, dur: float, col := NAT, core := NAT_HI, swirl := 1.2, speed := 3.0, outward := false) -> Inflow:
	var f = Inflow.new()
	f.center = center
	f.radius = radius
	f.dur = dur
	f.swirl = swirl
	f.speed = speed
	f.outward = outward
	f.setup(n, energy(col, core, true, 3.0, 1.2), 1.0)
	pj.get_tree().current_scene.add_child(f)
	return f


static func _chest_of(c: Node3D) -> Callable:
	var last = {"p": c.global_position + Vector3.UP}
	return func() -> Vector3:
		if is_instance_valid(c):
			last["p"] = c.global_position + Vector3.UP * 1.0
		return last["p"]


## Kırıntı: balistik uçuş, yere değince durur, sonra küçülüp kaybolur
class Debris extends Node3D:
	var bits: Array = []   # [düğüm, hız, dönüş ekseni]
	var t := 0.0
	var life := 1.6
	var floor_y := 0.0
	var grav := 18.0

	func _process(dt: float) -> void:
		t += dt
		for b in bits:
			var n = b[0]
			if not is_instance_valid(n):
				continue
			var v: Vector3 = b[1]
			if n.global_position.y > floor_y + 0.04 or v.y > 0.0:
				v.y -= grav * dt
				n.global_position += v * dt
				n.rotate(b[2], dt * 7.0)
				b[1] = v
			else:
				n.global_position.y = floor_y + 0.03
			if t > life:
				n.scale = n.scale * maxf(0.0, 1.0 - dt * 4.0)
		if t > life + 0.9:
			queue_free()


static func _debris(pj: PathJutsu, at: Vector3, n: int, spd: float, col: Color, size: float, up := 0.7, dir := Vector3.ZERO, life := 1.6, round_bits := false) -> Debris:
	var db = Debris.new()
	db.life = life
	pj.get_tree().current_scene.add_child(db)
	db.global_position = Vector3.ZERO
	db.floor_y = pj.gp(at).y
	var mat = cel(col, 0.008)
	for i in n:
		var b = MB.new()
		var s = size * randf_range(0.5, 1.2)
		if round_bits:
			b.add("sphere", Vector3.ZERO, Vector3.ONE * s, Color.WHITE, Vector3.ZERO, 6)
		else:
			b.add("box", Vector3.ZERO, Vector3(s, s * randf_range(0.5, 0.9), s * randf_range(0.6, 1.1)), Color.WHITE, Vector3(randf() * 90, randf() * 90, 0))
		var mi = _mi(b.build(), mat)
		db.add_child(mi)
		mi.global_position = at
		var h = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		if dir.length() > 0.01:
			h = (h * 0.6 + dir.normalized()).normalized()
		var v = (h * (1.0 - up) + Vector3.UP * up * randf_range(0.6, 1.2)).normalized() * spd * randf_range(0.5, 1.1)
		db.bits.append([mi, v, Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()])
	return db


## Yer yarığı izi: kırık kırık, uca doğru incelen kara çizgiler; dallanır; yavaşça söner
static func _cracks(pj: PathJutsu, at: Vector3, r: float, n: int, col: Color, dur: float, dir := Vector3.ZERO, spread := TAU, w := -1.0) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ww = w if w > 0.0 else clampf(0.05 * r, 0.04, 0.22)
	var base_a = atan2(dir.z, dir.x) if dir.length() > 0.01 else randf() * TAU
	for i in n:
		var a = base_a + (randf_range(-0.5, 0.5) * spread if dir.length() > 0.01 else i * TAU / n + randf_range(-0.3, 0.3))
		_crack_line(st, Vector2.ZERO, a, r * randf_range(0.6, 1.0), ww, 2)
	var mat = flat(col)
	var mi = _mi(st.commit(), mat)
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * 0.03)
	_fade(mi, mat, dur, 1.2)
	return mi


static func _crack_line(st: SurfaceTool, p: Vector2, a: float, L: float, w: float, depth: int) -> void:
	var steps = 6
	var q = p
	for s in steps:
		a += randf_range(-0.45, 0.45)
		var nq = q + Vector2(cos(a), sin(a)) * L / steps
		var w0 = w * (1.0 - float(s) / steps)
		var w1 = w * (1.0 - float(s + 1) / steps)
		var nr = Vector2(-sin(a), cos(a))
		var pts = [q + nr * w0, q - nr * w0, nq - nr * w1, nq + nr * w1]
		for k in [0, 1, 2, 0, 2, 3]:
			var v: Vector2 = pts[k]
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(v.x, 0, v.y))
		if depth > 0 and (s == 2 or s == 3) and randf() < 0.55:
			_crack_line(st, nq, a + randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0), L * 0.45, w0 * 0.6, depth - 1)
		q = nq


## Halka dalgası (yüzeye dik normal), genişleyip söner
static func _ripple(pj: PathJutsu, pos: Vector3, normal: Vector3, r0: float, r1: float, dur: float, col: Color, core: Color, thick := 0.75, add := true) -> MeshInstance3D:
	var mat = energy(col, core, add, 4.0, 1.4)
	var mi = _mi(_ring_mesh(thick, 1.0), mat)
	pj.scene_add(mi, pos)
	mi.basis = _basis_y(normal)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Yükselen ince alev dili (iki çapraz şerit): kendi rengiyle, sivri uçlu, hafif S kıvrımlı
static func _tongue_mesh() -> ArrayMesh:
	if _cache.has("tongue"):
		return _cache["tongue"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 8
	for plane in 2:
		var ax = Vector3.RIGHT if plane == 0 else Vector3.BACK
		var bend = Vector3.BACK if plane == 0 else Vector3.RIGHT
		for i in n:
			var k0 = float(i) / n
			var k1 = float(i + 1) / n
			var w0 = 0.5 * (1.0 - k0) * (0.6 + 0.4 * sin(k0 * PI))
			var w1 = 0.5 * (1.0 - k1) * (0.6 + 0.4 * sin(k1 * PI))
			var c0 = Vector3.UP * k0 + bend * sin(k0 * TAU * 0.8) * 0.12
			var c1 = Vector3.UP * k1 + bend * sin(k1 * TAU * 0.8) * 0.12
			var p = [c0 - ax * w0, c0 + ax * w0, c1 + ax * w1, c1 - ax * w1]
			var cs = [Color(1, 1, 1, 1.0 - k0 * 0.5), Color(1, 1, 1, 1.0 - k0 * 0.5), Color(1, 1, 1, 1.0 - k1 * 0.5), Color(1, 1, 1, 1.0 - k1 * 0.5)]
			for q in [0, 1, 2, 0, 2, 3]:
				st.set_normal(bend)
				st.set_color(cs[q])
				st.add_vertex(p[q])
	var m = st.commit()
	_cache["tongue"] = m
	return m


static func _flame_tongue(pj: PathJutsu, pos: Vector3, h: float, w: float, col: Color, core: Color, life: float, add := true, parent: Node3D = null) -> MeshInstance3D:
	var mat = energy(col, core, add, 5.0, 1.4)
	var mi = _mi(_tongue_mesh(), mat)
	if parent:
		parent.add_child(mi)
		mi.position = pos
	else:
		pj.scene_add(mi, pos)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(w, h * 0.2, w)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(w, h, w), life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "position:y", mi.position.y + h * 0.3, life)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Hız çizgileri: d boyunca kayan ince uzun çizgiler (yönlü bir koninin içinde)
static func _streaks(pj: PathJutsu, from: Vector3, d: Vector3, n: int, L: float, col: Color, spread := 0.5, rad := 0.6, life := 0.25, add := false) -> void:
	var dn = d.normalized()
	var side = _basis_look(dn)
	for i in n:
		var mat = energy(col, col.lightened(0.3), add, 0.0, 1.2)
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.025, 0.025, L * randf_range(0.6, 1.0)), Color.WHITE)
		var mi = _mi(b.build(), mat)
		var off = side.x * randf_range(-rad, rad) + side.y * randf_range(-rad, rad)
		var dir = (dn + side.x * randf_range(-spread, spread) + side.y * randf_range(-spread, spread)).normalized()
		pj.scene_add(mi, from + off)
		mi.basis = _basis_look(dir)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + dir * L * 1.6, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, life)
		tw.tween_callback(mi.queue_free)


## Canlı tüp: iki uç her kare yeniden okunur; arada sarkık/kıvrımlı eğri. reach 0..1 görünen uzunluk.
## deco: eğri boyunca eşit aralıkla dizilen süs düğümleri (+Y teğet) — zincir halkası, dil kabarcığı, yılan başı
class Rope extends Node3D:
	var a_fn: Callable
	var b_fn: Callable
	var radius := 0.1
	var r_tip := 1.0
	var sag := 0.15
	var wave := 0.0
	var reach := 0.0
	var segs := 18
	var deco: Array = []
	var deco_end: Node3D = null
	var mat: Material
	var t := 0.0
	var _im: ImmediateMesh
	var _mi: MeshInstance3D

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		if radius > 0.0:
			_im = ImmediateMesh.new()
			_mi = MeshInstance3D.new()
			_mi.mesh = _im
			_mi.material_override = mat
			_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mi.extra_cull_margin = 40.0
			add_child(_mi)

	func add_deco(n: Node3D) -> void:
		deco.append(n)
		add_child(n)
		n.top_level = true

	func set_end(n: Node3D) -> void:
		deco_end = n
		add_child(n)
		n.top_level = true

	func _points() -> PackedVector3Array:
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var out = PackedVector3Array()
		var d = b - a
		var L = d.length()
		var side = d.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		var rr = clampf(reach, 0.0, 1.0)
		for i in segs + 1:
			var k = float(i) / segs * rr
			var s = sin(k * PI)
			out.append(a.lerp(b, k) + Vector3.DOWN * sag * L * 0.25 * s + side * sin(k * TAU * 1.5 - t * 12.0) * wave * s)
		return out

	func _process(dt: float) -> void:
		t += dt
		if not a_fn.is_valid() or not b_fn.is_valid():
			queue_free()
			return
		var pts = _points()
		var n = pts.size()
		var vis = reach > 0.01
		for dn in deco:
			dn.visible = vis
		if deco_end:
			deco_end.visible = vis
		if _im:
			_im.clear_surfaces()
		if not vis or n < 2:
			return
		var frames = []
		var prev_up = Vector3.UP
		for i in n:
			var tng = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			tng = tng.normalized() if tng.length() > 0.00001 else Vector3.FORWARD
			var bb = tng.cross(prev_up)
			if bb.length() < 0.05:
				bb = tng.cross(Vector3.RIGHT)
			bb = bb.normalized()
			var u = bb.cross(tng).normalized()
			prev_up = u
			frames.append([u, bb, tng])
		if _im:
			var ring = 8
			_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in n - 1:
				for j in ring:
					for q in [[i, j], [i + 1, j], [i, j + 1], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
						var ii: int = q[0]
						var ang = TAU * float(q[1]) / ring
						var fr: Array = frames[ii]
						var nrm: Vector3 = fr[0] * cos(ang) + fr[1] * sin(ang)
						var r = radius * lerpf(1.0, r_tip, float(ii) / (n - 1))
						_im.surface_set_normal(nrm)
						_im.surface_add_vertex(pts[ii] + nrm * r)
			_im.surface_end()
		for j in deco.size():
			var u2 = (float(j) + 0.5) / deco.size() * (n - 1)
			var i0 = mini(int(u2), n - 2)
			var f = u2 - i0
			var dnode = deco[j]
			var fr2: Array = frames[i0]
			dnode.global_transform = Transform3D(Basis(fr2[1], fr2[2], fr2[0]).orthonormalized() * Basis.from_scale(dnode.get_meta("s", Vector3.ONE)), pts[i0].lerp(pts[i0 + 1], f))
		if deco_end:
			var tng2 = (pts[n - 1] - pts[n - 2]).normalized()
			deco_end.global_position = pts[n - 1]
			if tng2.length() > 0.01:
				deco_end.global_basis = SenjutsuFXA._basis_look(tng2) * Basis.from_scale(deco_end.get_meta("s", Vector3.ONE))


static func _rope(pj: PathJutsu, a_fn: Callable, b_fn: Callable, radius: float, mat: Material) -> Rope:
	var r = Rope.new()
	r.a_fn = a_fn
	r.b_fn = b_fn
	r.radius = radius
	r.mat = mat
	pj.get_tree().current_scene.add_child(r)
	return r


## Bir düğümün son bilinen konumu (düğüm silinse de son yer döner)
static func _track(n: Node3D, off: Vector3, fn := Callable()) -> Callable:
	var last = {"p": n.global_position + off if is_instance_valid(n) else Vector3.ZERO}
	return func() -> Vector3:
		if is_instance_valid(n) and n.is_inside_tree():
			last["p"] = (fn.call() if fn.is_valid() else n.global_position + off)
		return last["p"]


## Ten rengi (gerçek beden): dur sonra eski haline; üst üste gelen dökümde sonuncunun süresi geçerli
static func _tint_for(pj: PathJutsu, c: Node3D, col: Color, k: float, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_skin_tint") or c.has_meta("senninka_look"):
		return
	var until = Time.get_ticks_msec() + int(dur * 1000.0)
	c.set_meta("sjfx_tint_until", until)
	var tw = m.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(m):
			m.set_skin_tint(col, x), 0.0, k, 0.25)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if not is_instance_valid(c) or not is_instance_valid(m):
			return
		if int(c.get_meta("sjfx_tint_until", 0)) > Time.get_ticks_msec() + 50:
			return
		var tw2 = m.create_tween()
		tw2.tween_method(func(x: float):
			if is_instance_valid(m):
				m.set_skin_tint(col, x), k, 0.0, 0.4))


## Tene çizilen desen (toon sage_marks = kind, yüz juin_marks): bitince ÖNCEKİ desene döner (bilge modu izi silinmesin)
static func _skin_marks(pj: PathJutsu, c: Node3D, kind: int, face_param: String, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return
	var bm = m.get("body_mesh")
	var smat = bm.get_surface_override_material(0) if bm else null
	var prev = 0
	if smat is ShaderMaterial:
		var pv = smat.get_shader_parameter("sage_marks")
		prev = int(pv) if pv != null else 0
		if prev == kind:
			prev = 0
		smat.set_shader_parameter("sage_marks", kind)
	var fmat = m.get("face_skin_mat")
	if fmat is ShaderMaterial and face_param != "":
		fmat.set_shader_parameter(face_param, 1.0)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if smat is ShaderMaterial and is_instance_valid(smat) and _pi(smat, "sage_marks") == kind:
			smat.set_shader_parameter("sage_marks", prev)
		if fmat is ShaderMaterial and is_instance_valid(fmat) and face_param != "":
			fmat.set_shader_parameter(face_param, 0.0))


static func _pi(m: ShaderMaterial, key: String) -> int:
	var v = m.get_shader_parameter(key)
	return int(v) if v != null else 0


## Jūgo klanı bilge dönüşümü (Senjutsu Beden): ten boz-griye döner, boyundan kara lanet lekeleri yayılır (gerçek ten)
static func _jugo_skin(pj: PathJutsu, c: Node3D, dur: float) -> void:
	_tint_for(pj, c, JUGO_SKIN, 0.75, dur)
	_skin_marks(pj, c, 5, "juin_marks", dur)


## Bilge gözü + yüz izi (CharacterModel.set_sage: 1 kurbağa turuncu pigment + yatay göz bebeği). eyes_only: yalnız göz.
## Gerçek bilge modu (Buffs "sage") açıksa ona dokunulmaz.
static func _sage_face(pj: PathJutsu, c: Node3D, kind: int, dur: float, eyes_only := false) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_sage"):
		return
	var em = m.get("eye_mat")
	var bm = m.get("body_mesh")
	var smat = bm.get_surface_override_material(0) if bm else null
	if em is ShaderMaterial and _pi(em, "sage_eyes") > 0:
		return   # zaten bilge gözü açık
	if eyes_only:
		if em is ShaderMaterial:
			em.set_shader_parameter("sage_eyes", kind)
	else:
		m.set_sage(kind)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if not is_instance_valid(m) or (is_instance_valid(c) and c is Player and Buffs.has("sage")):
			return
		if em is ShaderMaterial and is_instance_valid(em) and _pi(em, "sage_eyes") == kind:
			em.set_shader_parameter("sage_eyes", 0)
		if not eyes_only and smat is ShaderMaterial and is_instance_valid(smat) and _pi(smat, "sage_marks") == kind:
			smat.set_shader_parameter("sage_marks", 0))


## Düz toz eteği: yerde genişleyen yumuşak kenarlı halka (duman bulutu değil; zemine yapışık)
static func _dust_skirt(pj: PathJutsu, at: Vector3, r0: float, r1: float, dur: float, col: Color) -> void:
	var mat = flat(col)
	var mi = _mi(_ring_mesh(0.55, 1.0), mat)
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * 0.06)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 1.0, r1), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


# ================================================================== ağ yapıları (önbellekli)
## Masakari: ön kol şişip ete gömülü dev hilal baltaya döner (ref: Broadaxe — kolun sırtından çıkan gri et bıçağı, kıvrım çizgileri)
## Kemik çerçevesi: +Y ön kol boyunca, +Z yumruk önü
static func _axe_mesh() -> ArrayMesh:
	if _cache.has("axe"):
		return _cache["axe"]
	var b = MB.new()
	var sk = FLESH
	Loft.tube(b, [Vector3(0, 0.0, 0), Vector3(0, 0.12, 0.01), Vector3(0, 0.26, 0.02), Vector3(0, 0.36, 0.02)],
		[Vector2(0.065, 0.06), Vector2(0.09, 0.085), Vector2(0.105, 0.1), Vector2(0.08, 0.075)], [sk.darkened(0.1), sk, sk, sk.lightened(0.04)], 12, 3, true, true)
	# hilal bıçak: Y-Z düzleminde, kesici dış kavis +Z yönünde; köke doğru kalın, ağza doğru ince
	var out = PackedVector2Array([Vector2(0.06, 0.05), Vector2(0.2, 0.2), Vector2(0.38, 0.33), Vector2(0.6, 0.38), Vector2(0.82, 0.32),
		Vector2(0.98, 0.18), Vector2(1.06, 0.02), Vector2(0.92, 0.08), Vector2(0.74, 0.13), Vector2(0.55, 0.13), Vector2(0.38, 0.08), Vector2(0.24, 0.02)])
	b.add_slab(out, 0.07, sk.lightened(0.06), Transform3D.IDENTITY, func(p: Vector2) -> float: return lerpf(0.09, 0.016, clampf(p.y / 0.36, 0.0, 1.0)), sk.darkened(0.2))
	# etin kıvrım çizgileri (ref: bıçak yüzünde koyu kıvrımlar) — iki yüzde ince koyu şeritler
	for sx in [-1.0, 1.0]:
		for k in 4:
			var y = 0.3 + k * 0.16
			b.add("box", Vector3(sx * 0.03, y, 0.12 + k * 0.02), Vector3(0.006, 0.012, 0.16), sk.darkened(0.45), Vector3.ZERO, 4)
	for k in 4:   # yumruk boğumları
		b.add("sphere", Vector3((k - 1.5) * 0.045, 0.37, 0.06), Vector3(0.055, 0.05, 0.05), sk.lightened(0.05), Vector3.ZERO, 6)
	var m = b.build()
	_cache["axe"] = m
	return m


## Kassokuken: ön kol dev piston silindirine döner — halka sırtlar, düz basma yüzü, dirsek tarafında üç jet deliği (ref: Living Wall Fist)
static func _piston_mesh() -> ArrayMesh:
	if _cache.has("piston"):
		return _cache["piston"]
	var b = MB.new()
	var sk = FLESH.darkened(0.05)
	Loft.tube(b, [Vector3(0, 0.0, 0), Vector3(0, 0.1, 0), Vector3(0, 0.24, 0), Vector3(0, 0.42, 0), Vector3(0, 0.52, 0)],
		[0.08, 0.15, 0.17, 0.175, 0.17], [sk.darkened(0.1), sk, sk, sk.lightened(0.04), sk], 16, 3, true, true)
	for k in 4:   # halka sırtları (ete gömülü alev biçimli kıvrımlar yerine kalın bilezikler)
		b.add("cyl", Vector3(0, 0.16 + k * 0.1, 0), Vector3(0.37, 0.025, 0.37), sk.darkened(0.12), Vector3.ZERO, 16)
	b.add("cyl", Vector3(0, 0.53, 0), Vector3(0.36, 0.03, 0.36), sk.lightened(0.1), Vector3.ZERO, 16)   # basma yüzü
	b.add("cyl", Vector3(0, 0.546, 0), Vector3(0.22, 0.008, 0.22), sk.darkened(0.25), Vector3.ZERO, 16)
	for k in 3:   # jet delikleri (dirsek tarafı -Z)
		b.add("cyl", Vector3((k - 1) * 0.08, 0.2, -0.16), Vector3(0.06, 0.06, 0.06), INK, Vector3(90, 0, 0), 8)
		b.add("cyl", Vector3((k - 1) * 0.08, 0.2, -0.15), Vector3(0.085, 0.03, 0.085), sk.darkened(0.3), Vector3(90, 0, 0), 10)
	var m = b.build()
	_cache["piston"] = m
	return m


## Beyaz bilge yılanı başı: -Z öne; açık çene, iki diş, sarı yarık göz
static func _snake_head(s: float) -> Node3D:
	var key = "shead_%.2f" % s
	if not _cache.has(key):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0.02, -0.2) * s, Vector3(0.36, 0.24, 0.55) * s, SNAKE_W, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, 0.0, -0.46) * s, Vector3(0.26, 0.15, 0.34) * s, SNAKE_W, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, -0.1, -0.38) * s, Vector3(0.24, 0.07, 0.42) * s, SNAKE_B, Vector3(-24, 0, 0), 8)
		b.add("sphere", Vector3(0, -0.06, -0.4) * s, Vector3(0.2, 0.08, 0.3) * s, Color(0.55, 0.12, 0.16), Vector3(-12, 0, 0), 8)   # ağız içi
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.07, -0.08, -0.58) * s, Vector3(0.035, 0.11, 0.035) * s, Color(1, 1, 0.97), Vector3(180, 0, 0), 5)
			b.add("sphere", Vector3(sx * 0.12, 0.08, -0.4) * s, Vector3(0.065, 0.065, 0.065) * s, Color(1.0, 0.85, 0.15), Vector3.ZERO, 8)
			b.add("box", Vector3(sx * 0.15, 0.08, -0.4) * s, Vector3(0.01, 0.05, 0.012) * s, INK)
		_cache[key] = b.build()
	return _mi(_cache[key], cel(Color.WHITE, 0.01 * s / 0.3))


## Muki Tensei taş yılanı: eski düzen (sekiz boğum yukarı, kıvrımlı) ama tek parça canlanmış kaya gövde + çeneli baş,
## gövdede kara çatlaklar, sırtta sarkıt sivrileri (ref: mağaranın sarkıtları canlanır)
static func _stone_serpent() -> ArrayMesh:
	if _cache.has("stone_snake"):
		return _cache["stone_snake"]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7741
	var b = MB.new()
	var stone = Color(0.6, 0.66, 0.68)
	var pts = []
	var rad = []
	var cols = []
	for j in 8:
		pts.append(Vector3(0, j * 0.6, sin(j * 0.9) * 0.6))
		rad.append((0.7 - j * 0.05) * 0.45)
		cols.append(stone.darkened(0.15 * (1.0 - j / 7.0)))
	var top = Vector3(0, 8 * 0.6, sin(7.2) * 0.6)
	pts.append(top)
	rad.append(0.17)
	cols.append(stone.lightened(0.05))
	Loft.tube(b, pts, rad, cols, 12, 3, true, true)
	# çatlaklar ve sarkıt sivrileri
	for j in 7:
		var p: Vector3 = pts[j]
		var r: float = rad[j]
		for k in 3:
			var a = rng.randf() * TAU
			var nrm = Vector3(cos(a), 0, sin(a))
			b.add("box", p + nrm * r * 0.98 + Vector3.UP * rng.randf_range(-0.2, 0.2), Vector3(0.02, rng.randf_range(0.15, 0.32), 0.02), INK.lightened(0.15), Vector3(0, rad_to_deg(-a), rng.randf_range(-35, 35)), 4)
		b.add("cone", p + Vector3(-r * 0.9, 0.1, 0), Vector3(0.09, 0.3, 0.09) * (1.0 + r), stone.lightened(0.12), Vector3(0, 0, 70), 5)
	# baş: gövdenin ucu, +Y yönüne bakar
	var hd = top + Vector3.UP * 0.2
	b.add("sphere", hd + Vector3(0, 0.18, 0), Vector3(0.42, 0.62, 0.36), stone.lightened(0.08), Vector3.ZERO, 10)
	b.add("sphere", hd + Vector3(0, 0.5, 0.06), Vector3(0.3, 0.38, 0.22), stone.lightened(0.1), Vector3.ZERO, 8)
	b.add("sphere", hd + Vector3(0, 0.36, 0.16), Vector3(0.26, 0.44, 0.1), stone.darkened(0.1), Vector3(24, 0, 0), 8)   # alt çene
	for sx in [-1.0, 1.0]:
		b.add("sphere", hd + Vector3(sx * 0.15, 0.36, 0.1), Vector3(0.07, 0.07, 0.05), Color(0.75, 1.0, 0.85), Vector3.ZERO, 6)
		b.add("cone", hd + Vector3(sx * 0.08, 0.66, 0.12), Vector3(0.04, 0.12, 0.04), Color(0.92, 0.94, 0.9), Vector3(150, 0, 0), 4)
	var m = b.build()
	_cache["stone_snake"] = m
	return m


## Hakugeki canavarı: yarı saydam pembe chakra yaratığı — iri kafatası, açık çene, testere dişler, parlak göz, ağızdan çıkan boyun
## (ref: Senpō Hakugeki). -Z öne; boyun +Z'de (ağıza) biter
static func _rage_beast_mesh() -> ArrayMesh:
	if _cache.has("rage"):
		return _cache["rage"]
	var b = MB.new()
	var w = Color.WHITE
	b.add("sphere", Vector3(0, 0.5, -1.0), Vector3(1.6, 1.2, 2.2), w, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.22, -2.2), Vector3(1.1, 0.6, 1.6), w, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, -0.5, -1.9), Vector3(1.0, 0.36, 1.7), w, Vector3(-18, 0, 0), 12)
	for i in 8:   # üst testere dişler
		var x = (i - 3.5) * 0.12
		b.add("cone", Vector3(x, -0.06, -2.55 + absf(x) * 1.2), Vector3(0.1, 0.32, 0.1), Color(1, 0.95, 0.95), Vector3(180, 0, 0), 4)
	for i in 7:   # alt dişler
		var x = (i - 3.0) * 0.13
		b.add("cone", Vector3(x, -0.44, -2.35 + absf(x) * 1.1), Vector3(0.09, 0.26, 0.09), Color(1, 0.95, 0.95), Vector3.ZERO, 4)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.55, 0.78, -1.5), Vector3(0.3, 0.26, 0.26), Color(1.6, 1.3, 1.3), Vector3.ZERO, 8)
		for k in 3:   # yeleye benzeyen geriye savrulan çizgiler
			b.add("cone", Vector3(sx * (0.35 + k * 0.15), 1.0 - k * 0.1, -0.2 + k * 0.25), Vector3(0.18, 1.1, 0.18), w, Vector3(-70, sx * 20, 0), 5)
	Loft.tube(b, [Vector3(0, 0.2, -0.3), Vector3(0, -0.1, 0.8), Vector3(0, 0.0, 2.0), Vector3(0, 0.0, 3.0)], [0.75, 0.55, 0.35, 0.12], w, 12, 3, false, true)
	var m = b.build()
	_cache["rage"] = m
	return m


## Arayış topu
static func _seeker_orb(s: float) -> MeshInstance3D:
	if not _cache.has("orb"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 16
		sm.rings = 8
		_cache["orb"] = sm
	if not _cache.has("orb_mat"):
		var m = ShaderMaterial.new()
		m.shader = _sh("orb", ORB_SH)
		var o = ShaderMaterial.new()
		o.shader = _sh("line", LINE_SH)
		o.set_shader_parameter("width", 0.035)
		m.next_pass = o
		_cache["orb_mat"] = m
	var mi = _mi(_cache["orb"], _cache["orb_mat"])
	mi.scale = Vector3.ONE * s
	return mi


## Cennet Lanet Mührü: üç kara tomoe (yuvarlak baş + kıvrık kuyruk), mor hale
static func _tomoe_mesh() -> ArrayMesh:
	if _cache.has("tomoe"):
		return _cache["tomoe"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a = k * TAU / 3.0 + 0.4
		var cen = Vector2(cos(a), sin(a)) * 0.45
		for layer in 2:   # 0: hale (geniş, mor), 1: kara tomoe
			var grow = 0.07 if layer == 0 else 0.0
			var colv = Color(0, 0, 0, 1) if layer == 0 else Color(1, 1, 1, 1)
			var z = 0.0 if layer == 0 else 0.002
			var rr = 0.26 + grow
			for i in 14:   # baş
				var a0 = TAU * i / 14
				var a1 = TAU * (i + 1) / 14
				for v in [cen, cen + Vector2(cos(a0), sin(a0)) * rr, cen + Vector2(cos(a1), sin(a1)) * rr]:
					st.set_color(colv)
					st.add_vertex(Vector3(v.x, v.y, z))
			var prev = []
			for i in 9:   # kuyruk: başın dışından kıvrılan sivri hilal
				var u = float(i) / 8.0
				var ang = a + 0.9 + u * 1.5
				var rad = 0.45 + 0.26 * (1.0 - u) - 0.02
				var mid = Vector2(cos(ang), sin(ang)) * rad
				var wdt = (0.2 + grow) * (1.0 - u)
				var nr = Vector2(cos(ang), sin(ang))
				var pa = mid + nr * wdt * 0.5
				var pb = mid - nr * wdt * 0.5
				if not prev.is_empty():
					for v in [prev[0], prev[1], pb, prev[0], pb, pa]:
						st.set_color(colv)
						st.add_vertex(Vector3(v.x, v.y, z))
				prev = [pa, pb]
	var m = st.commit()
	_cache["tomoe"] = m
	return m


# ================================================================== 1) Masakari
## Doğa enerjisi kolu ete gömülü dev hilal baltaya çevirir (Jūgo klanı): ten boz-griye döner, lanet lekeleri yayılır; sıçrayıp
## tepeden iner — gri hilal savuruş izi ve kara hız çizgileri, yer balta doğrultusunda boydan boya yarılır, iki yanında kaya
## dudakları kalkar, kırıntılar yana saçılır; yarık yavaşça söner.
static func masakari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 3.0, 10.0 if tt else 3.0)
	pj.busy(c, 0.9)
	_jugo_skin(pj, c, 1.2)
	var ba = pj.bone_attach(c, "RightLowerArm")
	if ba:
		var axe = _mi(_axe_mesh(), cel(Color.WHITE, 0.01))
		ba.add_child(axe)
		axe.scale = Vector3.ONE * 0.1
		axe.create_tween().tween_property(axe, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		pj.free_after(0.9, ba)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 1.4)
		var at = pj.gp(c.global_position + d * 1.6)
		GroundFX.add(at, "cracked", 3.0, 5.0)   # eski zemin yarığının oyun tarafı (üstünden geçen yavaşlar)
		_cleave_arc(pj, c, d)
		var hs = pj.hit(c, at + Vector3.UP, 2.6, pj.inf(c, "masakari", 2.0, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "bleed": 3.0}))
		_fissure(pj, at, d)
		pj.shake(0.65 if not hs.is_empty() else 0.4)
		Sfx.play("hit_heavy", at, 0.8))


## Tepeden inen balta savuruşu: d ile yukarının oluşturduğu düzlemde soluk gri hilal + kara hız çizgileri (ref)
static func _cleave_arc(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var o = c.global_position + Vector3.UP * 1.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 18
	for i in n:
		var a0 = lerpf(deg_to_rad(110.0), deg_to_rad(-35.0), float(i) / n)
		var a1 = lerpf(deg_to_rad(110.0), deg_to_rad(-35.0), float(i + 1) / n)
		var k0 = float(i) / n
		var k1 = float(i + 1) / n
		var p = [d * cos(a0) * 1.15 + Vector3.UP * sin(a0) * 1.15, d * cos(a0) * 1.85 + Vector3.UP * sin(a0) * 1.85,
			d * cos(a1) * 1.85 + Vector3.UP * sin(a1) * 1.85, d * cos(a1) * 1.15 + Vector3.UP * sin(a1) * 1.15]
		var cs = [Color(1, 1, 1, k0 * 0.4), Color(1, 1, 1, k0), Color(1, 1, 1, k1), Color(1, 1, 1, k1 * 0.4)]
		for q in [0, 1, 2, 0, 2, 3]:
			st.set_normal(d.cross(Vector3.UP).normalized())
			st.set_color(cs[q])
			st.add_vertex(p[q])
	var mat = energy(Color(0.72, 0.7, 0.68), Color(0.95, 0.94, 0.92), false, 6.0, 1.8)
	var mi = _mi(st.commit(), mat)
	pj.scene_add(mi, o)
	_fade(mi, mat, 0.06, 0.2)
	# kara hız çizgileri savuruş boyunca
	for k in 7:
		var a = deg_to_rad(lerpf(90.0, -20.0, k / 6.0))
		var p0 = o + d * cos(a) * 1.6 + Vector3.UP * sin(a) * 1.6
		var tng = (-d * sin(a) + Vector3.UP * cos(a)) * -1.0
		_streaks(pj, p0, tng, 1, 0.7, INK.lightened(0.1), 0.05, 0.08, 0.18, false)


## Balta yarığı: d boyunca uzun ana yarık + dallar, iki yanda kalkan kaya dudakları, yana saçılan kırıntı, alçak toz eteği
static func _fissure(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var dh = Vector3(d.x, 0, d.z).normalized() if Vector3(d.x, 0, d.z).length() > 0.01 else Vector3.FORWARD
	var side = dh.cross(Vector3.UP).normalized()
	_cracks(pj, at - dh * 0.6, 4.8, 1, Color(0.08, 0.06, 0.05, 0.92), 4.0, dh, 0.15, 0.22)
	_cracks(pj, at, 2.2, 5, Color(0.1, 0.08, 0.06, 0.85), 4.0)
	var mat = cel(EARTHC, 0.01)
	for sx in [-1.0, 1.0]:
		for k in 4:
			var b = MB.new()
			b.add("box", Vector3.ZERO, Vector3(0.55, 0.12, 0.7) * randf_range(0.7, 1.1), Color.WHITE.darkened(randf() * 0.15))
			var lip = _mi(b.build(), mat)
			var p = pj.gp(at + dh * (k * 0.9 - 0.6) + side * sx * 0.45)
			pj.scene_add(lip, p + Vector3.DOWN * 0.15)
			lip.basis = _basis_look(dh) * Basis(Vector3.BACK, sx * deg_to_rad(randf_range(28.0, 45.0)))
			var tw = lip.create_tween()
			tw.tween_interval(k * 0.03)
			tw.tween_property(lip, "global_position:y", p.y + 0.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(3.5)
			tw.tween_property(lip, "global_position:y", p.y - 0.3, 0.8)
			tw.tween_callback(lip.queue_free)
		_debris(pj, at + side * sx * 0.4 + Vector3.UP * 0.2, 6, 7.0, EARTHC, 0.16, 0.6, side * sx, 1.4)
	_dust_skirt(pj, at, 0.6, 3.6, 0.7, Color(0.62, 0.55, 0.45, 0.55))


# ================================================================== 2) Kusari
## İki kol doğa enerjisiyle uzayıp boğumlu zincir-kola döner (ref: plaka plaka gri et halkaları); hedefe fırlar, gövdesine
## sarmal halinde dolanır; her sıkışta halkalar daralır. Bitince kollar geri çekilir.
static func kusari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	_jugo_skin(pj, c, 2.7)
	var link_mesh = _link_mesh()
	var lmat = cel(Color.WHITE, 0.008)
	for k in 2:
		var right = k == 0
		var rp = _rope(pj, _track(c, Vector3.UP, func(): return pj.hand_pos(c, right)), _track(tt, Vector3.UP * (0.7 + k * 0.5)), 0.055, cel(FLESH.darkened(0.15), 0.008))
		rp.sag = 0.08
		rp.wave = 0.06
		for j in 14:
			var ln = _mi(link_mesh, lmat)
			ln.set_meta("s", Vector3.ONE)
			rp.add_deco(ln)
		var tw = rp.create_tween()
		tw.tween_property(rp, "reach", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.1)
		tw.tween_property(rp, "reach", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(rp.queue_free)
	pj.after(0.2, func():
		if not pj.live(tt):
			return
		var root = Node3D.new()
		tt.add_child(root)
		ClanJutsu.fit_body(tt, root)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		var wrap = _mi(_chain_coil_mesh(), lmat)
		root.add_child(wrap)
		wrap.scale = Vector3(1.35, 1.0, 1.35)
		wrap.create_tween().tween_property(wrap, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pj.get_tree().create_timer(2.3).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free())
		pj.st(tt, "bind", 2.3)
		pj.every(2.3, 0.5, func(_i, _k):
			if pj.live(tt):
				if is_instance_valid(wrap):   # sıkış: halkalar daralıp gevşer
					var sq = wrap.create_tween()
					sq.tween_property(wrap, "scale", Vector3(0.86, 1.04, 0.86), 0.08)
					sq.tween_property(wrap, "scale", Vector3.ONE, 0.2)
				tt.take_hit(pj.inf(c, "kusari", 0.25, {"knock": 0.0, "kind": "light"})), Callable()))
	Sfx.play("clink", c.global_position, 0.9)


## Zincir-kol halkası: yassı et plakası (bilezik), koyu derz
static func _link_mesh() -> ArrayMesh:
	if _cache.has("link"):
		return _cache["link"]
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.16, 0.1, 0.16), FLESH, Vector3.ZERO, 10)
	b.add("cyl", Vector3(0, 0.055, 0), Vector3(0.13, 0.015, 0.13), FLESH.darkened(0.4), Vector3.ZERO, 10)
	b.add("box", Vector3(0.075, 0, 0), Vector3(0.025, 0.08, 0.04), FLESH.darkened(0.25))   # yan tırnak
	var m = b.build()
	_cache["link"] = m
	return m


## Hedefi saran zincir sarmalı (iki tur, belden göğse)
static func _chain_coil_mesh() -> ArrayMesh:
	if _cache.has("coil"):
		return _cache["coil"]
	var b = MB.new()
	var n = 26
	for i in n:
		var u = float(i) / n
		var a = u * TAU * 2.2
		var p = Vector3(cos(a) * 0.48, 0.45 + u * 1.15, sin(a) * 0.48)
		var tng = Vector3(-sin(a) * 0.48 * TAU * 2.2, 1.15, cos(a) * 0.48 * TAU * 2.2).normalized()
		var bas = _basis_y(tng)
		b.add_xf("cyl", Transform3D(bas * Basis.from_scale(Vector3(0.16, 0.12, 0.16)), p), FLESH, 10)
		b.add_xf("cyl", Transform3D(bas * Basis.from_scale(Vector3(0.13, 0.13, 0.13)), p + tng * 0.01), FLESH.darkened(0.4), 8)
	var m = b.build()
	_cache["coil"] = m
	return m


# ================================================================== 3) Chi no Juin
## Toprak Lanet Mührü (Kimimaro): önce boyundan kara mühür çizgileri bedene yayılır (1. seviye — gerçek ten deseni), ardından ten
## koyulaşır (2. seviye). Ayak dibinde kahverengi-koyu toprak chakrası alev dilleri gibi yükselir, zemin ışınsal çatlar,
## çakıllar yerden kalkıp mühür süresince dizden bele yavaşça yörüngede döner.
static func chi_no_juin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	_skin_marks(pj, c, 5, "juin_marks", 15.0)
	pj.after(0.5, func():
		if pj.live(c):
			_tint_for(pj, c, Color(0.42, 0.33, 0.28), 0.6, 14.5))
	var base = pj.gp(c.global_position)
	for k in 9:
		var a = k * TAU / 9.0 + randf() * 0.3
		_flame_tongue(pj, base + Vector3(cos(a), 0, sin(a)) * randf_range(0.35, 0.8), randf_range(1.6, 2.4), 0.55,
			Color(0.32, 0.2, 0.12), Color(0.62, 0.46, 0.3), 0.9 + randf() * 0.3, false)
	_cracks(pj, base, 3.0, 7, Color(0.1, 0.07, 0.05, 0.9), 6.0)
	GroundFX.add(base, "cracked", 1.8, 5.0)   # eski zemin yarığının oyun tarafı
	var orbit = Node3D.new()
	c.add_child(orbit)
	orbit.position = Vector3(0, 0.0, 0)
	var rmat = cel(Color(0.52, 0.44, 0.36), 0.008)
	for k in 7:
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.14, 0.1, 0.12) * randf_range(0.7, 1.3), Color.WHITE.darkened(randf() * 0.2), Vector3(randf() * 60, randf() * 60, 0))
		var rock = _mi(b.build(), rmat)
		orbit.add_child(rock)
		var a = k * TAU / 7.0
		var h = randf_range(0.4, 1.1)
		rock.position = Vector3(cos(a) * 0.85, 0.02, sin(a) * 0.85)
		var tw = rock.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(rock, "position:y", h, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var bob = rock.create_tween().set_loops(15)
		bob.tween_property(rock, "rotation", Vector3(0.8, 1.2, 0.3), 1.0).as_relative()
	var spin = orbit.create_tween().set_loops(4)
	spin.tween_property(orbit, "rotation:y", TAU, 3.8).as_relative()
	if c is Player:
		Buffs.add("chi_no_juin", 15.0, {"melee": 1.3, "armor": 0.8, "_name": "Toprak Lanet Mührü", "_desc": "doğa enerjisi: güç +%30, gelen hasar azalır"})
	pj.get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(orbit):
			for r in orbit.get_children():   # çakıllar düşer
				var tw2 = r.create_tween()
				tw2.tween_property(r, "position:y", 0.02, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			var tw3 = orbit.create_tween()
			tw3.tween_interval(0.5)
			tw3.tween_callback(orbit.queue_free))
	Sfx.play("genjutsu", c.global_position, 0.7)


# ================================================================== 4) Zessenbaku
## Kurbağa dili: ağızdan kalın, pembe, üstünde yuvarlak kabarcıklar olan dil (ref) fırlar; hedefin beline sıkıca dolanır,
## dolanma gerilip sıkışır; dil geri çekilirken salya damlaları düşer.
static func zessenbaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var pink = Color(0.9, 0.66, 0.64)
	var tmat = cel(pink, 0.012)
	var rp = _rope(pj, _track(c, Vector3.UP * 1.55, func(): return pj._mouth_pos(c)), _track(tt, Vector3.UP), 0.14, tmat)
	rp.sag = 0.12
	rp.wave = 0.05
	rp.r_tip = 0.8
	for j in 9:   # kabarcıklar
		var b = MB.new()
		b.add("sphere", Vector3(0.11 if j % 2 == 0 else -0.11, 0, 0.04), Vector3(0.1, 0.1, 0.08), Color.WHITE, Vector3.ZERO, 8)
		var bump = _mi(b.build(), tmat)
		bump.set_meta("s", Vector3.ONE)
		rp.add_deco(bump)
	var tw = rp.create_tween()
	tw.tween_property(rp, "reach", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(rp, "reach", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(rp.queue_free)
	pj.after(0.12, func():
		if not pj.live(tt):
			return
		var holder = Node3D.new()
		tt.add_child(holder)
		ClanJutsu.fit_body(tt, holder)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		var coil = _mi(_tongue_coil_mesh(), tmat)
		holder.add_child(coil)
		coil.scale = Vector3(1.3, 1.0, 1.3)
		var tw2 = coil.create_tween()
		tw2.tween_property(coil, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(0.68)
		tw2.tween_callback(holder.queue_free)
		pj.st(tt, "bind", 1.0))
	pj.after(0.3, func():
		if pj.live(tt) and tt.get("velocity") != null:
			var v = c.global_position - tt.global_position
			tt.velocity = v.normalized() * minf(22.0, v.length() * 2.5) + Vector3.UP * 3.0)
	pj.after(0.72, func():
		if pj.live(c):   # geri çekilen dilden salya
			var mid = (pj._mouth_pos(c) + (tt.global_position + Vector3.UP if is_instance_valid(tt) else pj._mouth_pos(c))) * 0.5
			_debris(pj, mid, 5, 1.5, Color(0.95, 0.88, 0.9), 0.05, 0.3, Vector3.ZERO, 0.6, true))
	Sfx.play("whoosh", c.global_position, 0.8)


## Hedefin beline dolanan dil sarmalı (kabarcıklı)
static func _tongue_coil_mesh() -> ArrayMesh:
	if _cache.has("tcoil"):
		return _cache["tcoil"]
	var b = MB.new()
	var pts = []
	var n = 22
	for i in n + 1:
		var u = float(i) / n
		var a = u * TAU * 1.6
		pts.append(Vector3(cos(a) * 0.52, 0.72 + u * 0.55, sin(a) * 0.52))
	var rad = []
	for i in n + 1:
		rad.append(0.13 * (1.0 - 0.3 * float(i) / n))
	Loft.tube(b, pts, rad, Color.WHITE, 10, 2, true, true)
	for i in range(1, n, 3):
		var p: Vector3 = pts[i]
		b.add("sphere", p + Vector3(p.x, 0, p.z).normalized() * 0.1 + Vector3.UP * 0.03, Vector3(0.09, 0.09, 0.09), Color.WHITE, Vector3.ZERO, 8)
	var m = b.build()
	_cache["tcoil"] = m
	return m


# ================================================================== 5) Kawazu Kumite
## Kurbağa Kata: hareketsiz duruşta çevreden doğa enerjisi zerreleri içe süzülür; kata süresince yumruklarda ince turuncu enerji
## tütsüsü tüter. Yumruk ileri atıldığında görünmeyen uzantı darbesi gösterilir: yumruğun ötesinde, erimin ucunda turuncu enerji
## halkası açılır (anime: darbe yumruktan önce yüze iner).
static func kawazu_kumite(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	pj.anim(c, "fold", 1.0)
	_inflow(pj, _chest_of(c), 3.0, 26, 0.6, NAT, NAT_HI, 1.0, 3.5)
	_ripple(pj, pj.gp(c.global_position) + Vector3.UP * 0.05, Vector3.UP, 0.4, 2.2, 0.6, NAT, NAT_HI, 0.88)
	if c is Player:
		Buffs.add("kawazu_kumite", 12.0, {"melee": 1.3, "reach": 1.5, "_name": "Kurbağa Kata", "_desc": "doğa enerjisi aurası: yakın dövüş +%30, menzil +%25"})
	var prev = {}
	pj.every(12.0, 0.25, func(_i, _k):
		if not pj.live(c):
			return
		var f = c.face_dir()
		for right in [true, false]:
			var hp = pj.hand_pos(c, right)
			var rel = hp - c.global_position
			var key = 1 if right else 0
			var moved = (rel - prev[key]).dot(f) if prev.has(key) else 0.0
			prev[key] = rel
			if moved > 0.28:   # yumruk ileri atıldı: erimin ucunda görünmez darbe halkası
				var tip = hp + f * 0.9
				_ripple(pj, tip, f, 0.12, 0.75, 0.22, NAT, NAT_HI, 0.6)
				_ripple(pj, tip + f * 0.25, f, 0.08, 0.45, 0.18, NAT_HI, Color.WHITE, 0.7)
			elif randf() < 0.5:
				_flame_tongue(pj, hp + Vector3.UP * 0.03, 0.35, 0.12, NAT, NAT_HI, 0.45, true), Callable())
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== 6) Kawazu Tataki
## Kurbağa Vuruşu: yumruk değmeden önce doğa enerjisi çarpar — önde turuncu basınç merceği sıkışıp patlar, ileri doğru üç
## basınç halkası ve koni biçimli hız çizgileri; vurulan hedefin gövdesinde enerji dalgası.
static func kawazu_tataki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 0.0, 10.0 if tt else 3.0)
	pj.busy(c, 0.6)
	_inflow(pj, _track(c, Vector3.UP, func(): return pj.hand_pos(c, true)), 1.1, 12, 0.18, NAT, NAT_HI, 2.0, 5.0)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.4)
		var f = c.face_dir()
		var at = c.global_position + f * 1.4 + Vector3.UP * 1.1
		_pressure_lens(pj, at, f)
		for k in 3:
			var ring = _ripple(pj, at + f * (0.2 + k * 0.45), f, 0.3 + k * 0.2, 1.6 + k * 0.5, 0.28 + k * 0.06, NAT, NAT_HI, 0.82)
			ring.create_tween().tween_property(ring, "global_position", ring.global_position + f * 1.4, 0.3)
		_streaks(pj, at, f, 12, 1.4, NAT_HI, 0.35, 0.3, 0.22, true)
		pj.shake(0.5)
		var hs = pj.hit(c, at, 2.0, pj.inf(c, "kawazu_tataki", 1.8, {"knock": 24.0, "launch": 4.0, "kind": "heavy"}))
		for e in hs:
			if is_instance_valid(e):
				_ripple(pj, e.global_position + Vector3.UP * 1.0, f, 0.3, 1.2, 0.25, NAT, Color.WHITE, 0.85)
		Sfx.play("hit_heavy", at, 0.8))


## Basınç merceği: yassı turuncu enerji diski sıkışır, sonra açılıp söner
static func _pressure_lens(pj: PathJutsu, at: Vector3, f: Vector3) -> void:
	if not _cache.has("lens"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 20
		sm.rings = 10
		_cache["lens"] = sm
	var mat = energy(NAT, NAT_HI, true, 6.0, 1.4)
	var mi = _mi(_cache["lens"], mat)
	pj.scene_add(mi, at)
	mi.basis = _basis_look(f)
	mi.scale = Vector3(0.4, 0.4, 0.15)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.25, 0.25, 0.3), 0.05)
	tw.tween_property(mi, "scale", Vector3(2.2, 2.2, 0.2), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, 0.22)
	tw.tween_callback(mi.queue_free)


# ================================================================== 7) Daijatsuki
## Büyük Yılan Saplaması: uzatılan kol beyaz bilge yılanına döner (oyunun yılan gövdesi, beyaz sırt / krem karın) — kıvrılarak
## hedefe atılır, ağzı açık; saplamada iki diş parlaması ve mor zehir damlaları; sonra kola geri çekilir.
static func daijatsuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.8)
	pj._face(c, tt)
	var end = (tt.global_position + Vector3.UP if tt else c.global_position + c.face_dir() * 10.0 + Vector3.UP * 1.2)
	var sn = SleeveSnake.new()
	sn.back_col = SNAKE_W
	sn.belly_col = SNAKE_B
	sn.radius = 0.11
	sn.anchor = _track(c, Vector3.UP * 1.2, func(): return pj.hand_pos(c, true))
	sn.aim_dir = c.face_dir()
	sn.target = null
	sn.free_to = end
	sn.side = 0.22
	sn.lift = 0.18
	sn.phase = randf() * 2.0
	pj.get_tree().current_scene.add_child(sn)
	sn.set_head(_snake_head(0.36))
	var from = pj.hand_pos(c, true)
	_streaks(pj, from, end - from, 6, 1.6, Color(0.2, 0.2, 0.22), 0.08, 0.25, 0.25, false)
	sn.extend(0.25, func():
		if not is_instance_valid(c):
			return
		pj.hit(c, end, 1.4, pj.inf(c, "daijatsuki", 1.3, {"knock": 8.0, "kind": "heavy", "poison": 3.0}))
		_bite(pj, end, (end - from).normalized()))
	pj.get_tree().create_timer(0.55).timeout.connect(func():
		if is_instance_valid(sn):
			sn.retract(0.25))
	Sfx.play("whoosh", c.global_position, 0.9)


## Isırık: iki diş parlaması (beyaz kısa çizgi) + mor zehir damlaları
static func _bite(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized() if d.cross(Vector3.UP).length() > 0.05 else Vector3.RIGHT
	for sx in [-1.0, 1.0]:
		_streaks(pj, at + side * sx * 0.12 + Vector3.UP * 0.15, Vector3.DOWN + d * 0.3, 1, 0.35, Color(1, 1, 1), 0.02, 0.02, 0.14, true)
	_debris(pj, at, 7, 3.0, Color(0.5, 0.2, 0.62), 0.06, 0.5, -d, 0.8, true)


# ================================================================== 8) Orochimaru no Juinjutsu
## Lanetli Mühür Verme: boyun yılan gibi uzayıp hedefin boynuna atılır, ısırır; ısırık yerinde kan damlaları, boynun üstünde üç
## kara tomoe (Cennet Mührü) belirir ve mühür kara alev dilleri hâlinde hedefin GERÇEK tenine yayılır (lanet deseni); her
## saniye boyundan mor-kara alev dilleri tüter, mühür zonklar.
static func orochimaru_no_juinjutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj.busy(c, 0.6)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.0, 12.0)
	var neck = _rope(pj, _track(c, Vector3.UP * 1.55), _track(tt, Vector3.UP * 1.45), 0.06, cel(Color(0.92, 0.88, 0.84), 0.01))
	neck.sag = -0.1
	neck.wave = 0.08
	neck.set_end(_snake_head(0.2))
	var tw = neck.create_tween()
	tw.tween_property(neck, "reach", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)
	tw.tween_property(neck, "reach", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(neck.queue_free)
	pj.after(0.2, func():
		if not pj.live(tt):
			return
		var h = float(tt.get("height")) if tt.get("height") != null else 1.7
		var mat = ShaderMaterial.new()
		mat.shader = _sh("mark", MARK_SH)
		var mark = _mi(_tomoe_mesh(), mat)
		mark.position = Vector3.UP * h * 0.86
		mark.scale = Vector3.ONE * 0.02
		tt.add_child(mark)
		var tw2 = mark.create_tween()
		tw2.tween_property(mark, "scale", Vector3.ONE * 0.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pj.get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(mark):
				_fade(mark, mat, 0.0, 0.4))
		_skin_marks(pj, tt, 5, "juin_marks", 6.0)   # mühür hedefin gerçek tenine yayılır
		_debris(pj, tt.global_position + Vector3.UP * h * 0.84, 3, 0.6, Color(0.45, 0.04, 0.06), 0.035, 0.2, Vector3.ZERO, 0.8, true)
		_ripple(pj, tt.global_position + Vector3.UP * h * 0.84, (c.global_position - tt.global_position).normalized(), 0.1, 0.7, 0.25, Color(0.5, 0.15, 0.6), Color(0.85, 0.6, 0.95), 0.7, false)
		pj.st(tt, "stun", 2.0)
		pj.every(6.0, 1.0, func(_i, _k):
			if pj.live(tt):
				if is_instance_valid(mark):
					var p = mark.create_tween()
					p.tween_property(mark, "scale", Vector3.ONE * 0.26, 0.1)
					p.tween_property(mark, "scale", Vector3.ONE * 0.2, 0.3)
				for k in 2:
					_flame_tongue(pj, Vector3(randf_range(-0.12, 0.12), h * 0.82, randf_range(-0.12, 0.12)), 0.5, 0.16, Color(0.35, 0.08, 0.45), Color(0.06, 0.02, 0.08), 0.6, false, tt)
				tt.take_hit(pj.inf(c, "orochimaru_no_juinjutsu", 0.2, {"knock": 0.0, "kind": "light", "poison": 2.0})), Callable())
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Lanetlendi!", Color(0.7, 0.3, 0.8)))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== 9) Kassokuken
## Piston Yumruk: ön kol dev piston silindirine döner (halka sırtlar, düz basma yüzü, dirsekte jet delikleri); ateşlemede
## deliklerden geriye üç beyaz cel jet fışkırır, önde beyaz testere kenarlı dev patlama yıldızı açılır (ref: Living Wall Fist).
static func kassokuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.7)
	_jugo_skin(pj, c, 1.0)
	var ba = pj.bone_attach(c, "RightLowerArm")
	if ba:
		var arm = _mi(_piston_mesh(), cel(Color.WHITE, 0.012))
		ba.add_child(arm)
		arm.scale = Vector3.ONE * 0.2
		var tw = arm.create_tween()
		tw.tween_property(arm, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.5)
		tw.tween_callback(ba.queue_free)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.8)
		var at = c.global_position + Vector3.UP * 1.2 + d * 2.0
		_jets(pj, c.global_position + Vector3.UP * 1.2 - d * 0.4, -d)
		var hs = pj.hit(c, at, 2.4, pj.inf(c, "kassokuken", 2.0, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.1}))
		_spike_burst(pj, at, d)
		if not hs.is_empty():
			pj.shake(0.7)
		Sfx.play("boom", at, 1.2))


## Üç beyaz jet: dirsekten geriye fışkıran kalın konturlu koniler, hızla uzayıp söner
static func _jets(pj: PathJutsu, at: Vector3, back: Vector3) -> void:
	var bas = _basis_look(back)
	var mat = cel(Color(0.97, 0.97, 0.97), 0.02)
	for k in 3:
		var b = MB.new()
		b.add("cone", Vector3(0, 0.5, 0), Vector3(0.22, 1.0, 0.22), Color.WHITE, Vector3.ZERO, 8)
		var jet = _mi(b.build(), mat)
		pj.scene_add(jet, at + bas.x * (k - 1) * 0.12)
		var dir = (back + bas.x * (k - 1) * 0.25 + bas.y * randf_range(-0.1, 0.1)).normalized()
		jet.basis = _basis_y(dir)   # koninin tabanı delikte, sivri ucu geriye
		jet.scale = Vector3(1.0, 0.05, 1.0)
		var tw = jet.create_tween()
		tw.tween_property(jet, "scale", Vector3(1.2, 1.8, 1.2), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(jet, "scale", Vector3(0.05, 2.4, 0.05), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(jet.queue_free)


## Beyaz testere kenarlı patlama yıldızı (d'ye dik düzlem) + dışa fırlayan beyaz sivriler
static func _spike_burst(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var bas = _basis_look(d)
	for layer in 2:
		var out = PackedVector2Array()
		var n = 22
		for i in n * 2:
			var a = PI * i / n
			var r = (1.0 if i % 2 == 0 else 0.45) * randf_range(0.75, 1.15) * (1.0 - layer * 0.4)
			out.append(Vector2(cos(a), sin(a)) * r)
		var b = MB.new()
		b.add_slab(out, 0.04, Color.WHITE if layer == 0 else Color(0.82, 0.82, 0.84))
		var star = _mi(b.build(), cel(Color.WHITE, 0.025 if layer == 0 else 0.0))
		pj.scene_add(star, at + d * (0.05 * layer))
		# levha kalınlığı +X: d'ye hizala (sağ elli: x = d, y = yukarı, z = sağ)
		var sb = Basis(-bas.z, bas.y, bas.x).rotated(-bas.z, randf() * TAU)
		star.basis = sb
		star.scale = Vector3.ONE * 0.3
		var tw = star.create_tween()
		tw.tween_property(star, "scale", Vector3(1.0, 1.7, 1.7), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.08)
		tw.tween_property(star, "scale", Vector3(0.02, 0.04, 0.04), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(star.queue_free)
	var smat = cel(Color.WHITE, 0.015)
	for i in 10:
		var a = TAU * i / 10.0 + randf() * 0.3
		var dir = (bas.x * cos(a) + bas.y * sin(a) + d * 0.6).normalized()
		var b2 = MB.new()
		b2.add("cone", Vector3(0, 0.5, 0), Vector3(0.12, 1.0, 0.12), Color.WHITE, Vector3.ZERO, 5)
		var sp = _mi(b2.build(), smat)
		pj.scene_add(sp, at)
		sp.basis = _basis_y(dir)
		sp.scale = Vector3(1, 0.2, 1)
		var tw2 = sp.create_tween()
		tw2.tween_property(sp, "global_position", at + dir * 1.8, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(sp, "scale", Vector3(0.3, 1.2, 0.3), 0.18)
		tw2.tween_callback(sp.queue_free)


# ================================================================== 10) Senpō: Muki Tensei
## İnorganik Reenkarnasyon (Kabuto): önde zemin canlanır — soluk yeşil yaşam damarları topraktan yayılır, halka hâlinde sarkıt
## sivrileri yükselip nefes alır gibi kabarır; üç noktada toprak yarılıp kayadan canlanmış yılanlar (çatlaklı taş gövde, çeneli
## baş) dikilir, hedefe dalar; çarpışta kaya kırılır, yer yarılır; yılanlar küçülüp toprağa döner.
static func senpo_muki_tensei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(c.global_position + c.face_dir() * 2.0)
	_awaken_ground(pj, at)
	for k in 3:
		pj.after(0.3 + k * 0.2, func():
			if not pj.live(c):
				return
			var q = at + c.face_dir().cross(Vector3.UP) * (k - 1) * 3.0
			GroundFX.add(q, "cracked", 2.2 * 0.6, 5.0)   # eski toprak çıkışının oyun tarafı
			_cracks(pj, q, 2.2, 6, Color(0.08, 0.07, 0.06, 0.9), 4.0)
			_debris(pj, q + Vector3.UP * 0.2, 10, 6.5, Color(0.55, 0.58, 0.58), 0.2, 0.75, Vector3.ZERO, 1.3)
			var snake = Node3D.new()
			pj.get_tree().current_scene.add_child(snake)
			snake.global_position = q
			var body = _mi(_stone_serpent(), cel(Color.WHITE, 0.025, 0.25, KABUTO))
			snake.add_child(body)
			var goal = pj.gp(tt.global_position if tt and pj.live(tt) else q + c.face_dir() * 12.0)
			snake.look_at(Vector3(goal.x, q.y, goal.z) + Vector3(0.001, 0, 0), Vector3.UP)
			body.scale = Vector3(1, 0.05, 1)
			body.create_tween().tween_property(body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var tw = snake.create_tween()
			tw.tween_property(snake, "rotation:x", -1.2, 0.3)
			tw.tween_property(snake, "global_position", goal, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_stone_impact(pj, goal)
				pj.shake(0.6)
				pj.hit(c, goal + Vector3.UP, 2.8, pj.inf(c, "senpo_muki_tensei", 1.0, {"knock": 12.0, "kind": "heavy"})))
			tw.tween_interval(0.5)
			tw.tween_property(snake, "scale", Vector3.ONE * 0.05, 0.3)
			tw.tween_callback(snake.queue_free))
	Sfx.play("earth", at, 0.8)


## Zemin canlanır: soluk yeşil yaşam damarları (parlayan çatlak) + halka hâlinde nefes alan sarkıt sivrileri
static func _awaken_ground(pj: PathJutsu, at: Vector3) -> void:
	var veins = _cracks(pj, at, 4.2, 9, Color(KABUTO.r, KABUTO.g, KABUTO.b, 0.85), 1.6, Vector3.ZERO, TAU, 0.06)
	veins.scale = Vector3.ONE * 0.1
	veins.create_tween().tween_property(veins, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var smat = cel(Color(0.6, 0.66, 0.68), 0.015, 0.2, KABUTO)
	for i in 7:
		var a = TAU * i / 7.0 + randf() * 0.4
		var p = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 2.8))
		var b = MB.new()
		b.add("cone", Vector3(0, 0.5, 0), Vector3(0.35, 1.0, 0.35), Color.WHITE, Vector3.ZERO, 6)
		b.add("box", Vector3(0.06, 0.35, 0.06), Vector3(0.02, 0.3, 0.02), INK.lightened(0.2), Vector3(0, 0, 8))
		var sp = _mi(b.build(), smat)
		pj.scene_add(sp, p + Vector3.DOWN * 0.1)
		var hh = randf_range(0.9, 1.6)
		sp.scale = Vector3(1, 0.05, 1)
		sp.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
		var tw = sp.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(sp, "scale", Vector3(1, hh, 1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for k in 2:   # nefes: kabarıp iner
			tw.tween_property(sp, "scale", Vector3(1.25, hh * 1.12, 1.25), 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_property(sp, "scale", Vector3(1, hh, 1), 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sp, "scale", Vector3(1, 0.05, 1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(sp.queue_free)


## Taş yılan çarpışı: kaya kırılır (iri kırıntı), yer yarılır (oyun: yarık zemin), alçak toz eteği
static func _stone_impact(pj: PathJutsu, goal: Vector3) -> void:
	var g = pj.gp(goal)
	GroundFX.add(g, "cracked", 3.5 * 1.4 * 0.6, 5.0)   # eski toprak isabetinin oyun tarafı
	_cracks(pj, g, 3.6, 8, Color(0.07, 0.06, 0.05, 0.92), 5.0)
	_debris(pj, g + Vector3.UP * 0.6, 16, 9.0, Color(0.6, 0.66, 0.68), 0.26, 0.6, Vector3.ZERO, 1.6)
	_dust_skirt(pj, g, 0.8, 4.2, 0.6, Color(0.6, 0.6, 0.58, 0.5))


# ================================================================== 11) Senpō: Hakugeki no Jutsu
## Beyaz Öfke: ağza pembe enerji süzülür; ağızdan yarı saydam pembe chakra canavarı (iri kafatası, testere dişler, parlak göz)
## öne atılıp çenesini açar; ağzından sırayla dalgalanan pembe ses bantları 18 m ileri yayılıp açılır.
static func senpo_hakugeki_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d = pj.fwd(c, t)
	var red = Color(1.0, 0.35, 0.4)
	_inflow(pj, _track(c, Vector3.UP * 1.55, func(): return pj._mouth_pos(c)), 1.4, 16, 0.3, red, Color(1.0, 0.8, 0.82), 1.6, 4.0)
	_rage_beast(pj, c, d)
	for k in 6:
		pj.after(0.3 + k * 0.08, func():
			if not pj.live(c):
				return
			var mat = energy(red, Color(1.0, 0.82, 0.85), true, 8.0, 2.5)
			var ring = _mi(_ring_mesh(0.84, 1.0, 48), mat)
			pj.get_tree().current_scene.add_child(ring)
			ring.global_position = pj._mouth_pos(c) + d * 0.6
			ring.basis = _basis_y(d)
			var tw = ring.create_tween()
			tw.tween_property(ring, "global_position", ring.global_position + d * 18.0, 0.5)
			tw.parallel().tween_property(ring, "scale", Vector3(6.0, 1.0, 6.0), 0.5)
			tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(ring.queue_free))
	pj.after(0.4, func():
		if not pj.live(c):
			return
		Combat.hit_zone(c, c.global_position, d, 18.0, 50.0, 4.0, pj.inf(c, "senpo_hakugeki_no_jutsu", 1.6, {"knock": 10.0, "kind": "heavy", "stun": 2.2}))
		pj.shake(0.8))
	Sfx.play("roar", c.global_position, 1.3)


static func _rage_beast(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var mat = energy(Color(1.0, 0.4, 0.48), Color(1.0, 0.82, 0.85), false, 3.0, 3.5)
	var mi = _mi(_rage_beast_mesh(), mat)
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_position = pj._mouth_pos(c)
	root.basis = _basis_look(d)
	root.add_child(mi)
	mi.position = Vector3(0, 0.3, -3.0)   # boyun ucu ağızda
	root.scale = Vector3.ONE * 0.15
	mat.set_shader_parameter("amount", 0.0)
	var tw = root.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(root, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 0.0, 0.85, 0.2)
	tw.tween_property(root, "scale", Vector3.ONE * 1.65, 0.45)
	tw.parallel().tween_property(mi, "rotation:x", -0.12, 0.45)
	tw.tween_method(func(x: float): mat.set_shader_parameter("amount", x), 0.85, 0.0, 0.35)
	tw.tween_callback(root.queue_free)


# ================================================================== 12) Sennin Mōdo
## Bilge Modu: hareketsiz duruşta çevreden doğa enerjisi zerreleri yavaş bir girdapla bedene süzülür; göz bebekleri kurbağa
## gözüne döner ve göz çevresine turuncu pigment çizilir (gerçek yüz); salınımda zemin ışınsal çatlar, yerde toz eteği açılır,
## çakıllar sıçrar. Mod süresince ince zerre akışı sürer.
static func sennin_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	_inflow(pj, _chest_of(c), 4.5, 40, 0.85, NAT, NAT_HI, 1.1, 4.0)
	pj.after(0.45, func():
		if pj.live(c):
			_sage_face(pj, c, 1, 20.6))
	pj.after(0.9, func():
		if not pj.live(c):
			return
		var g = pj.gp(c.global_position)
		_cracks(pj, g, 4.0, 9, Color(0.1, 0.08, 0.06, 0.88), 6.0)
		GroundFX.add(g, "cracked", 2.4, 5.0)   # eski zemin yarığının oyun tarafı
		_dust_skirt(pj, g, 1.0, 8.0, 0.6, Color(0.66, 0.58, 0.46, 0.5))
		_ripple(pj, g + Vector3.UP * 0.08, Vector3.UP, 0.8, 6.0, 0.5, NAT, NAT_HI, 0.92)
		_debris(pj, g + Vector3.UP * 0.1, 12, 4.0, EARTHC, 0.08, 0.85, Vector3.ZERO, 1.0)
		_inflow(pj, _chest_of(c), 2.2, 8, 19.0, NAT, NAT_HI, 0.8, 1.6)
		if c is Player:
			Buffs.add("sennin_modo", 20.0, {"melee": 1.4, "speed": 1.15, "armor": 0.7, "_name": "Bilge Modu", "_desc": "doğa enerjisi: güç, hız, algı"}))
	Sfx.play("chakra", c.global_position, 0.6)


# ================================================================== 13) Senninka
## Bilge Dönüşümü (Jūgo klanı): çevreden doğa enerjisi bedene akar; ten boz-griye döner, boyundan kara lanet lekeleri tüm tene
## yayılır (gerçek beden), beden bir an kabarıp oturur; ayak dibinde yer çatlar.
static func senninka(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("senninka", {})
	var tier = int(d.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	_inflow(pj, _chest_of(c), 3.5, 30, 0.55, NAT, NAT_HI, 1.4, 4.5)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		_jugo_skin(pj, c, dur)
		var m = c.get("model")
		if m and is_instance_valid(m):   # beden bir an kabarır
			var s0: Vector3 = m.scale
			var tw = m.create_tween()
			tw.tween_property(m, "scale", s0 * 1.07, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(m, "scale", s0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var g = pj.gp(c.global_position)
		_cracks(pj, g, 2.0, 6, Color(0.1, 0.08, 0.06, 0.85), 3.0)
		_dust_skirt(pj, g, 0.5, 3.0, 0.45, Color(0.6, 0.55, 0.48, 0.45)))
	# oynanış: senjutsu dönüşüm güçlenmesi (genel motorun senjutsu kipi sayıları)
	if c is Player:
		Buffs.add("senninka", dur, {"melee": 1.2 + 0.06 * tier, "armor": 0.85, "jutsu": 1.15 + 0.05 * tier})
		Hud.msg("%s: %d sn" % [String(d.get("name", "Senninka")).split(" (")[0], int(dur)], JUGO_SKIN.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== 14) Rikudō Sennin Mōdo
## Altı Yol Bilge Modu: bedenden soluk altın ışın çizgileri yatay olarak dışa fırlar, yerde altın halka; göz bebekleri bilge gözüne
## döner (gerçek göz); sırtta dokuz arayış topu yörüngede döner. Toplar yakındaki düşman mermilerini yutar (kara mürekkep
## çöküşü), düzenli aralıkla hedefe atılır (kara iz; çarpınca kara halka + kırık parçalar).
static func rikudo_sennin_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	_rikudo_flash(pj, c)
	_sage_face(pj, c, 1, 20.0, true)
	var orbit = Node3D.new()
	c.add_child(orbit)
	orbit.position = Vector3(0, 1.6, -0.5)
	for k in 9:
		var bb = _seeker_orb(0.3)
		orbit.add_child(bb)
		var an = k * TAU / 9.0
		bb.position = Vector3(cos(an) * 1.0, sin(an) * 1.0, 0)
	var spin = orbit.create_tween().set_loops(40)
	spin.tween_property(orbit, "rotation:z", TAU, 2.0).as_relative()
	if c is Player:
		Buffs.add("rikudo_sennin", 20.0, {"melee": 1.35, "speed": 1.2, "armor": 0.75, "_name": "Altı Yol Bilge Modu", "_desc": "arayış topları mermileri siler, düşmana ateş eder"})
	pj.every(20.0, 0.15, func(i, _k):
		if not (pj.live(c) and is_instance_valid(orbit)):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 3.0:
				_orb_swallow(pj, p.global_position)
				p.queue_free()
		if int(i) % 10 == 5:
			var tt = pj.tg(c, null, 24.0)
			if tt and pj.live(tt):
				var from = orbit.global_position + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0)
				var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, _seeker_orb(0.35), pj.inf(c, "rikudo_sennin_modo", 0.6, {"knock": 6.0, "kind": "heavy"}), tt, false, 1.0, func(pp, _h):
					_orb_hit(pj, pp))
				if pr:
					_orb_trail(pj, pr), func():
		if is_instance_valid(orbit):
			orbit.queue_free())
	Sfx.play("chakra", c.global_position, 0.6)


## Soluk altın ışın çizgileri bedenden yatay dışa + yerde altın halka
static func _rikudo_flash(pj: PathJutsu, c: Node3D) -> void:
	var o = c.global_position + Vector3.UP * 1.1
	for i in 18:
		var a = TAU * i / 18.0 + randf() * 0.2
		var dir = Vector3(cos(a), randf_range(-0.15, 0.25), sin(a))
		_streaks(pj, o + dir * 0.5, dir, 1, randf_range(1.6, 2.6), Color(1.0, 0.95, 0.75), 0.02, 0.05, 0.35, true)
	_ripple(pj, pj.gp(c.global_position) + Vector3.UP * 0.07, Vector3.UP, 0.6, 7.0, 0.55, GOLD, Color(1.0, 0.97, 0.85), 0.9)


## Arayış topu mermiyi yutar: kara disk mermiyi sarıp içe çöker
static func _orb_swallow(pj: PathJutsu, at: Vector3) -> void:
	var orb = _seeker_orb(0.05)
	pj.scene_add(orb, at)
	var tw = orb.create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 0.7, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(orb, "scale", Vector3(0.9, 0.05, 0.9), 0.1)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.01, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(orb.queue_free)


## Arayış topu isabeti: kara halka + kırık kara parçalar
static func _orb_hit(pj: PathJutsu, at: Vector3) -> void:
	_ripple(pj, at, Vector3.UP, 0.3, 2.2, 0.3, Color(0.25, 0.2, 0.3), INK, 0.7, false)
	_debris(pj, at, 6, 5.0, Color(0.06, 0.05, 0.07), 0.08, 0.5, Vector3.ZERO, 0.7)


## Arayış topu izi: topun arkasından kameraya dönük incelen kara şerit
class OrbTrail extends MeshInstance3D:
	var follow: Node3D
	var hist: Array = []
	var t := 0.0
	var gone := 0.0
	var _im := ImmediateMesh.new()

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		mesh = _im
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 40.0

	func _process(dt: float) -> void:
		t += dt
		if is_instance_valid(follow) and follow.is_inside_tree():
			hist.push_front(follow.global_position)
		else:
			gone += dt
			if hist.size() > 0:
				hist.pop_back()
		if hist.size() > 10:
			hist.pop_back()
		_im.clear_surfaces()
		if gone > 0.4 or t > 3.0:
			queue_free()
			return
		var cam = get_viewport().get_camera_3d()
		if cam == null or hist.size() < 2:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in hist.size() - 1:
			var a: Vector3 = hist[i]
			var b: Vector3 = hist[i + 1]
			var v = (cam.global_position - a).normalized()
			var s = (b - a).cross(v).normalized()
			var wa = 0.16 * (1.0 - float(i) / hist.size())
			var wb = 0.16 * (1.0 - float(i + 1) / hist.size())
			var q = [a + s * wa, a - s * wa, b - s * wb, b + s * wb]
			for k in [0, 1, 2, 0, 2, 3]:
				_im.surface_set_color(Color(1, 1, 1, 1.0 - float(i) / hist.size()))
				_im.surface_add_vertex(q[k])
		_im.surface_end()


static func _orb_trail(pj: PathJutsu, pr: Node3D) -> void:
	var tr = OrbTrail.new()
	tr.follow = pr
	tr.material_override = energy(Color(0.2, 0.16, 0.26), Color(0.05, 0.04, 0.06), false, 1.0, 1.4)
	pj.get_tree().current_scene.add_child(tr)


# ================================================================== 15) Rikudō Senjutsu
## Altı Yol Senjutsu: ayak dibinden halka hâlinde altın alev dilleri yükselir, altın zerreler dışa savrulur; beden altın-turuncu
## kaynayan Altı Yol örtüsüne bürünür (bedenin kendi derili örgüsü: önde kara şeritler, kol ağzı ve etekte kara bant), yakada
## dokuz kara magatama halkası, sırtta yay biçiminde altı arayış topu hafifçe süzülür; süre boyunca omuzlardan altın dil tüter.
static func rikudo_senjutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var g = pj.gp(c.global_position)
	for k in 14:
		var a = TAU * k / 14.0
		_flame_tongue(pj, g + Vector3(cos(a), 0, sin(a)) * 0.9, randf_range(2.0, 3.0), 0.5, GOLD, Color(1.0, 0.97, 0.8), 0.8, true)
	_inflow(pj, _chest_of(c), 6.0, 30, 0.6, GOLD, Color(1.0, 0.97, 0.8), 0.8, 7.0, true)
	_ripple(pj, g + Vector3.UP * 0.07, Vector3.UP, 0.8, 8.0, 0.6, GOLD, Color(1.0, 0.95, 0.7), 0.85)
	var cloak = _rikudo_cloak(c)
	var parts = []
	var mr = _magatama_collar(pj, c)
	if mr:
		parts.append(mr)
	var balls = Node3D.new()
	c.add_child(balls)
	for k in 6:
		var bb = _seeker_orb(0.32)
		balls.add_child(bb)
		var an = PI + (k - 2.5) * 0.45
		bb.position = Vector3(sin(an) * 1.1, 1.9 + cos(k * 1.3) * 0.15, cos(an) * 0.6)
		var bob = bb.create_tween().set_loops(20)
		bob.tween_property(bb, "position:y", 0.08, 0.5 + k * 0.05).as_relative().set_trans(Tween.TRANS_SINE)
		bob.tween_property(bb, "position:y", -0.08, 0.5 + k * 0.05).as_relative().set_trans(Tween.TRANS_SINE)
	if c is Player:
		Buffs.add("rikudo_senjutsu", 20.0, {"melee": 1.5, "speed": 1.25, "armor": 0.8, "_name": "Altı Yol Senjutsu", "_desc": "altın örtü + arayış topları"})
	pj.every(20.0, 0.3, func(_i, _k):
		if pj.live(c):
			var sx = 1.0 if randf() < 0.5 else -1.0
			var sh = c.global_position + Vector3.UP * 1.45 + c.face_dir().cross(Vector3.UP) * sx * 0.2 - c.face_dir() * 0.05
			_flame_tongue(pj, sh, 0.55, 0.18, GOLD, Color(1.0, 0.97, 0.8), 0.5, true), func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free()
		if is_instance_valid(balls):
			balls.queue_free()
		if is_instance_valid(cloak):
			_fade(cloak, cloak.material_override, 0.0, 0.5))
	pj.shake(0.6)
	Sfx.play("roar", c.global_position, 1.2)


## Altı Yol örtüsü: bedenin kendi derili örgüsü (iskelete bağlı kopya) + kendi gölgelendiricisi; açılışta belirir
static func _rikudo_cloak(c: Node3D) -> MeshInstance3D:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.get("body_mesh") == null or m.get("skel") == null:
		return null
	var mat = ShaderMaterial.new()
	mat.shader = _sh("cloak", CLOAK_SH)
	var cm = MeshInstance3D.new()
	cm.mesh = m.body_mesh.mesh
	m.skel.add_child(cm)
	cm.skin = m.body_mesh.skin
	cm.skeleton = cm.get_path_to(m.skel)
	cm.material_override = mat
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cm.create_tween().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 0.0, 1.0, 0.4)
	return cm


## Yakada dokuz kara magatama (boyun çevresinde halka) — göğüs kemiğine bağlı
static func _magatama_collar(pj: PathJutsu, c: Node3D) -> Node3D:
	var ba = pj.bone_attach(c, "UpperChest")
	if ba == null:
		return null
	if not _cache.has("magatama"):
		var b = MB.new()
		for k in 9:
			var a = k * TAU / 9.0
			var p = Vector3(sin(a) * 0.15, 0.2, cos(a) * 0.13)
			var out = Vector3(sin(a), 0, cos(a))
			b.add("sphere", p + out * 0.01, Vector3(0.042, 0.042, 0.042), INK, Vector3.ZERO, 8)
			b.add_xf("cone", Transform3D(_basis_y(Vector3.DOWN + out.cross(Vector3.UP) * 0.8) * Basis.from_scale(Vector3(0.03, 0.06, 0.03)), p + Vector3.DOWN * 0.03 + out * 0.01), INK, 5)
		_cache["magatama"] = b.build()
	var mi = _mi(_cache["magatama"], cel(Color.WHITE, 0.0))
	ba.add_child(mi)
	mi.scale = Vector3.ONE * 0.05
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return ba
