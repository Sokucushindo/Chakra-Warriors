class_name MudFX
extends RefCounted
## Deiton (çamur) görselleri ve on Deiton tekniğinin tamamı.
## Ortak efekt yardımcısı yok: kendi çamur shader'ı (ıslak koyu kahve, parlak çizgi, kenarda bordo/ten rengi, kuruyunca mat
## bej-gri kil + kendi çatlak deseni), kendi topak / sıçrama lekesi / akış yüzeyi / el / kol / kil parçası geometrisi.
## Davranış: ağır topaklar yay çizip düşer ve yapışır (sekmez), yüzeyler sarkar, damlar; kil olunca çatlayıp parçalara ayrılır.

static var _cache := {}

const G := 17.0   # çamur ağırdır: topaklar sert düşer

# ------------------------------------------------------------------ malzemeler
const MUD_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

instance uniform float dry = 0.0;
instance uniform float deep = 0.0;
instance uniform float edge = 0.0;
instance uniform float wob = 1.0;
instance uniform float seed = 0.0;
instance uniform float folds = 0.0;

// renkler sRGB yazıldı, fragment'ta doğrusala çevrilir (gök yansıması / ortam ışığı kapalı: soğuk griye kaymasın)
const vec3 WET_S = vec3(0.36, 0.2, 0.1);
const vec3 DEEP_S = vec3(0.13, 0.07, 0.04);
const vec3 MAROON_S = vec3(0.3, 0.07, 0.05);
const vec3 THIN_S = vec3(0.55, 0.39, 0.23);
const vec3 CLAY_S = vec3(0.58, 0.52, 0.42);
const vec3 CRACK_S = vec3(0.25, 0.2, 0.15);

varying vec3 wp;
varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float vor_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			float dd = length(g + o - f);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return d2 - d1;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	float w = wob * (1.0 - dry);
	float t = TIME * 1.3 + seed * 6.0;
	vec3 v = VERTEX;
	float n = sin(v.x * 4.0 + t) * sin(v.z * 3.5 - t * 0.8) + 0.6 * sin(v.y * 5.0 + t * 1.3);
	v += NORMAL * n * 0.035 * w;
	VERTEX = v;
	lp = v;
	wp = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
}

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 sp = wp.xz * 1.3 + vec2(wp.y * 0.9, -wp.y * 0.7) + vec2(seed * 3.1);
	float n = vnoise(sp * 2.0);
	float n2 = vnoise(sp * 0.55 + vec2(5.3));
	vec3 WET = lin(WET_S);
	vec3 DEEP = lin(DEEP_S);
	vec3 wet = mix(WET, DEEP, clamp(deep, 0.0, 1.0) * 0.8);
	wet = mix(wet, wet * 0.7, step(0.55, n));
	// katman katman düzensiz kıvrımlar: her kıvrımın üstü açık, altı koyu + çizilmiş kontur çizgisi (gürültüyle bükülür, kırılır)
	float fl = lp.y * 5.0 + length(lp.xz) * 1.1 + n * 1.3 + n2 * 2.8 + seed;
	float band = fract(fl);
	wet *= mix(1.0, 0.78 + 0.38 * smoothstep(0.35, 0.65, band), folds);
	float cl = abs(band - 0.5);
	float brk = step(0.3, vnoise(sp * 1.3 + vec2(fl * 0.2)));   // kontur yer yer kopar
	wet = mix(wet, DEEP * 0.7, step(0.455, cl) * folds * brk);
	wet = mix(wet, DEEP * 0.8, step(0.6, fres) * 0.8);
	float e = 1.0 - COLOR.a;
	vec3 edge_col = mix(lin(THIN_S), lin(MAROON_S), clamp(edge, 0.0, 1.0));
	wet = mix(wet, edge_col, step(0.72, e));
	float streak = step(0.88, sin(lp.y * 7.0 + lp.x * 2.3 + lp.z * 1.7 + seed * 4.0 + n * 2.5)) * step(fres, 0.42) * (1.0 - step(0.72, e));
	vec3 clay = lin(CLAY_S) * (0.88 + 0.16 * n);
	clay = mix(clay, clay * 0.7, step(0.6, fres));
	float ce = vor_edge(sp * 1.6);
	float cr = (1.0 - smoothstep(0.035, 0.075, ce)) * smoothstep(0.55, 0.95, dry);
	clay = mix(clay, lin(CRACK_S), cr);
	float d = smoothstep(0.0, 1.0, dry);
	vec3 alb = mix(wet, clay, d) * COLOR.rgb;
	ALBEDO = alb;
	// ortam ışığı yerine sıcak dolgu (gölgede de kahve kalır) + ıslak parlak çizgiler
	EMISSION = alb * 0.32 + lin(vec3(0.78, 0.62, 0.45)) * streak * (1.0 - d) * 0.45;
	ROUGHNESS = mix(0.35, 1.0, d);
	SPECULAR = mix(0.3, 0.0, d);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.3 ? 1.0 : (ndl > -0.1 ? 0.6 : 0.3);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
	vec3 hv = normalize(VIEW + LIGHT);
	float s = pow(max(dot(NORMAL, hv), 0.0), 60.0);
	SPECULAR_LIGHT += step(0.5, s) * (1.0 - ROUGHNESS) * ATTENUATION * LIGHT_COLOR / PI * 0.8;
}
"""

## Model yüzeyine giydirilen çamur deri (Doro Bunshin): yamalar halinde, yavaşça aşağı süzülen ıslak çamur
const SKIN_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

uniform float cover = 0.8;
varying vec3 lp;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	float s = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	lp = VERTEX * s;
	VERTEX += NORMAL * 0.012 / s;
}

void fragment() {
	vec3 q = lp * 4.0 + vec3(0.0, TIME * 0.3, 0.0);
	float n = vn3(q) * 0.65 + vn3(q * 2.3 + vec3(7.0)) * 0.35;
	float drip = vn3(vec3(lp.x * 16.0, lp.y * 1.5 + TIME * 0.6, lp.z * 16.0));
	float m = max(step(1.0 - cover, n), step(0.7, drip) * step(0.35, n));
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(pow(vec3(0.36, 0.2, 0.1), vec3(2.2)), pow(vec3(0.13, 0.07, 0.04), vec3(2.2)), step(0.6, fres));
	col = mix(col, col * 0.7, step(0.55, vn3(q * 1.7 + vec3(3.0))));
	float streak = step(0.9, sin(lp.y * 22.0 + lp.x * 6.0 + n * 4.0)) * step(fres, 0.4);
	ALBEDO = col;
	EMISSION = col * 0.32 + pow(vec3(0.78, 0.62, 0.45), vec3(2.2)) * streak * 0.45;
	ROUGHNESS = 0.35;
	SPECULAR = 0.3;
	ALPHA = m;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""


static func mud_mat() -> ShaderMaterial:
	if _cache.has("mat"):
		return _cache["mat"]
	var sh = Shader.new()
	sh.code = MUD_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["mat"] = m
	return m


static func skin_mat() -> ShaderMaterial:
	if _cache.has("skin"):
		return _cache["skin"]
	var sh = Shader.new()
	sh.code = SKIN_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["skin"] = m
	return m


## Yer çatlağı çizgisi malzemesi (düz renk, gölgesiz)
static func _crack_mat() -> StandardMaterial3D:
	if _cache.has("crack"):
		return _cache["crack"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_cache["crack"] = m
	return m


## Çamur malzemeli mesh örneği; ıslaklık / derinlik / kenar türü örnek başına (tek malzeme paylaşılır)
static func _mi(mesh: Mesh, dry := 0.0, deep := 0.0, edge := 0.0, wob := 1.0, shadow := false) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mud_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("dry", dry)
	mi.set_instance_shader_parameter("deep", deep)
	mi.set_instance_shader_parameter("edge", edge)
	mi.set_instance_shader_parameter("wob", wob)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	return mi


## Katmanlı kıvrım çizgileri (bataklık, kavrayan eller, dalga): her alt mesh'e
static func fold(n: Node, v := 1.0) -> Node:
	if n is GeometryInstance3D:
		n.set_instance_shader_parameter("folds", v)
	for ch in n.find_children("*", "MeshInstance3D", true, false):
		ch.set_instance_shader_parameter("folds", v)
	return n


## Havuz üstünde iç içe yığılmış kalın çamur kıvrımları (teraslar): halka biçimli, dalgalı yuvarlak sırtlar
static func fold_rolls(pj: PathJutsu, center: Vector3, R: float, n: int, parent: Node3D = null) -> Node3D:
	var root = Node3D.new()
	var c = pj.gp(center)
	# düzenli halka değil: kaymış merkezli, farklı uzunlukta kopuk yaylar; kalınlığı boyunca şişip incelir, uçları sivrilir
	for k in n * 3:
		var band = float(k % n) / maxf(1.0, n - 1)
		var rr = R * (0.22 + 0.68 * band) * randf_range(0.85, 1.12)
		var off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * R * 0.12
		var a0 = randf() * TAU
		var span = randf_range(1.1, 3.4)
		var pts = []
		var radii = []
		var ph = randf() * TAU
		var segn = int(clampf(span * 6.0, 6.0, 20.0))
		var thick = R * randf_range(0.02, 0.05) + 0.06
		for s in segn + 1:
			var u = float(s) / segn
			var a = a0 + span * u
			var wob = rr * (1.0 + 0.16 * sin(a * 3.0 + ph) + 0.08 * sin(a * 7.0 + ph * 2.0))
			var lx = off.x + cos(a) * wob
			var lz = off.z + sin(a) * wob
			pts.append(Vector3(lx, Game.jutsu_floor(c.x + lx, c.z + lz) - c.y + 0.05, lz))
			radii.append(thick * (0.35 + 0.65 * sin(u * PI)) * (1.0 + 0.45 * sin(u * 9.0 + ph)))
		var mi = _mi(tube_mesh(pts, radii, 7, 0.25, randf() * 10.0, 0.5), 0.0, 0.55, 0.0, 1.0)
		root.add_child(mi)
	for k in n * 2:   # kıvrımlar arasında yığılmış topaklar
		var a = randf() * TAU
		var dist = R * randf_range(0.15, 0.85)
		var lx = cos(a) * dist
		var lz = sin(a) * dist
		var lm = _mi(lump_mesh(randi() % 6, 0.35, 0.7), 0.0, 0.5, 0.0, 1.2)
		lm.position = Vector3(lx, Game.jutsu_floor(c.x + lx, c.z + lz) - c.y + 0.02, lz)
		var sz = R * randf_range(0.04, 0.09)
		lm.scale = Vector3(sz * randf_range(1.0, 1.8), sz * 0.6, sz)
		lm.rotation.y = randf() * TAU
		root.add_child(lm)
	fold(root)
	if parent:
		parent.add_child(root)
	else:
		pj.scene_add(root, c)
	return root


static func _dry_fn(mi: GeometryInstance3D) -> Callable:
	return func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("dry", v)


## Kuruma: ıslak koyu kahveden mat bej-gri kile (dry 1'e yaklaştıkça shader çatlak çizgileri belirir)
static func harden(mi: GeometryInstance3D, t: float, delay := 0.0, to := 1.0) -> void:
	if not is_instance_valid(mi):
		return
	var from = mi.get_instance_shader_parameter("dry")
	if from == null:
		from = 0.0
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_dry_fn(mi), float(from), to, t)


static func harden_all(n: Node, t: float, delay := 0.0, to := 1.0) -> void:
	if not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		harden(n, t, delay, to)
	for ch in n.find_children("*", "MeshInstance3D", true, false):
		harden(ch, t, delay, to)


## Yavaşça yere çöküp silinme (çamur yere oturur, kaybolur)
static func sink_free(n: Node3D, delay: float, t := 0.6) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if not is_instance_valid(n):
			return
		var t2 = n.create_tween()
		t2.tween_property(n, "scale", Vector3(n.scale.x * 1.05, n.scale.y * 0.03, n.scale.z * 1.05), t).set_ease(Tween.EASE_IN)
		t2.tween_callback(n.queue_free))


## Yerel +Z = d olacak yatay yön tabanı
static func _face_basis(d: Vector3) -> Basis:
	var f = Vector3(d.x, 0, d.z)
	if f.length() < 0.01:
		f = Vector3.FORWARD
	return Basis.looking_at(-f.normalized(), Vector3.UP)


# ------------------------------------------------------------------ geometri
## Topak: tümsekli, düzensiz küre (birim yarıçap). flat > 0: alt yarı basık (yere oturan kütle)
static func lump_mesh(variant: int, rough := 0.24, flat := 0.0, rings := 9, segs := 12) -> ArrayMesh:
	var key = "lump_%d_%d_%d_%d_%d" % [variant, int(rough * 100), int(flat * 100), rings, segs]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7919 * (variant + 3)
	var bumps = []
	for k in 6:
		bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.5, 1.0)])
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings + 1:
		var v = float(r) / rings
		var phi = v * PI
		for s in segs + 1:
			var u = float(s) / segs
			var th = u * TAU
			var dir = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var rad = 1.0 - rough * 0.35
			for b in bumps:
				rad += rough * b[1] * pow(maxf(0.0, dir.dot(b[0])), 3.0)
			var p = dir * rad
			if flat > 0.0 and p.y < 0.0:
				p.y *= (1.0 - flat)
			sf.set_color(Color.WHITE)
			sf.set_uv(Vector2(u, v))
			sf.add_vertex(p)
	for r in rings:
		for s in segs:
			var a = r * (segs + 1) + s
			var b2 = a + segs + 1
			sf.add_index(a)
			sf.add_index(b2)
			sf.add_index(a + 1)
			sf.add_index(a + 1)
			sf.add_index(b2)
			sf.add_index(b2 + 1)
	sf.generate_normals()
	var m = sf.commit()
	_cache[key] = m
	return m


## Sıçrama lekesi: yırtık kenarlı, dilli, ortası kabarık düzensiz leke + çevresine saçılmış küçük damlalar.
## center verilirse (büyük havuzlar) köşeler arazinin gerçek yüksekliğine oturur; dome metre cinsinden kabarıklık
static func splat_mesh(variant: int, R := 1.0, center = null, rag := 0.32, dome := 0.14, sats := 7) -> ArrayMesh:
	var conform = center != null
	var key = "splat_%d_%d_%d" % [variant, int(rag * 100), sats]
	if not conform and _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 104729 + variant * 7907
	var segs = 36
	var ph = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var tongues = []
	for k in rng.randi_range(3, 6):
		tongues.append([rng.randf() * TAU, rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.28)])
	var rads = []
	for s in segs:
		var a = s * TAU / segs
		var r = 1.0 + rag * (0.5 * sin(a * 3.0 + ph[0]) + 0.3 * sin(a * 5.0 + ph[1]) + 0.2 * sin(a * 9.0 + ph[2]))
		for tq in tongues:
			var da = absf(wrapf(a - tq[0], -PI, PI))
			r += tq[1] * maxf(0.0, 1.0 - da / tq[2])
		r += rng.randf_range(-0.06, 0.06)
		rads.append(r)
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vadd = func(x: float, y: float, z: float, alpha: float):
		var yy = y
		if conform:
			yy += Game.jutsu_floor(center.x + x, center.z + z) - center.y + 0.03
		sf.set_color(Color(1, 1, 1, alpha))
		sf.set_uv(Vector2(x, z))
		sf.add_vertex(Vector3(x, yy, z))
	# [yarıçap oranı, yükseklik oranı, alfa]: son halka alfa 0 = kenar rengi (ince ten / bordo)
	var rings = [[0.45, 0.92, 1.0], [0.8, 0.55, 1.0], [0.95, 0.18, 1.0], [1.0, 0.0, 0.0]]
	vadd.call(0.0, dome, 0.0, 1.0)
	for rg in rings:
		for s in segs:
			var a = s * TAU / segs
			var rr = rads[s] * rg[0] * R
			vadd.call(cos(a) * rr, dome * rg[1], sin(a) * rr, rg[2])
	for s in segs:
		sf.add_index(0)
		sf.add_index(1 + s)
		sf.add_index(1 + (s + 1) % segs)
	for ri in rings.size() - 1:
		var ib = 1 + ri * segs
		var ob = 1 + (ri + 1) * segs
		for s in segs:
			var s1 = (s + 1) % segs
			sf.add_index(ib + s)
			sf.add_index(ob + s)
			sf.add_index(ob + s1)
			sf.add_index(ib + s)
			sf.add_index(ob + s1)
			sf.add_index(ib + s1)
	# çevreye saçılmış küçük damlalar
	var base = 1 + rings.size() * segs
	for k in sats:
		var a = rng.randf() * TAU
		var si = int(a / TAU * segs) % segs
		var dist = rads[si] * rng.randf_range(1.12, 1.6) * R
		var cr = rng.randf_range(0.05, 0.15) * R
		var cx = cos(a) * dist
		var cz = sin(a) * dist
		vadd.call(cx, dome * 0.35, cz, 1.0)
		for q in 8:
			var b = q * TAU / 8.0
			var rr = cr * (1.0 + 0.25 * sin(b * 2.0 + a))
			vadd.call(cx + cos(b) * rr, 0.0, cz + sin(b) * rr, 0.0)
		for q in 8:
			sf.add_index(base)
			sf.add_index(base + 1 + q)
			sf.add_index(base + 1 + (q + 1) % 8)
		base += 9
	sf.generate_normals()
	var m = sf.commit()
	if not conform:
		_cache[key] = m
	return m


## İnce halka dalgacık (bataklık yüzeyi)
static func ring_mesh() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache["ring"]
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs = 32
	var prof = [[0.84, 0.0, 0.0], [0.92, 0.05, 1.0], [1.0, 0.0, 0.0]]
	for pr in prof:
		for s in segs:
			var a = s * TAU / segs
			sf.set_color(Color(1, 1, 1, pr[2]))
			sf.set_uv(Vector2(0, 0))
			sf.add_vertex(Vector3(cos(a) * pr[0], pr[1], sin(a) * pr[0]))
	for ri in 2:
		var ib = ri * segs
		var ob = (ri + 1) * segs
		for s in segs:
			var s1 = (s + 1) % segs
			sf.add_index(ib + s)
			sf.add_index(ob + s)
			sf.add_index(ob + s1)
			sf.add_index(ib + s)
			sf.add_index(ob + s1)
			sf.add_index(ib + s1)
	sf.generate_normals()
	var m = sf.commit()
	_cache["ring"] = m
	return m


## Çizgi boyunca düzensiz kalınlıkta tüp (kol, parmak, sarkan çamur sırtı); uçta yuvarlak damla ucu
static func tube_mesh(pts: Array, radii: Array, sides := 9, rough := 0.15, sd := 0.0, tip := 0.6) -> ArrayMesh:
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	var nn = Vector3.ZERO
	var t0 = Vector3.UP
	var tl = Vector3.UP
	for i in n:
		var p: Vector3 = pts[i]
		var tng: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if i == 0:
			t0 = tng
			var rf = Vector3.RIGHT if absf(tng.y) > 0.9 else Vector3.UP
			nn = tng.cross(rf).normalized()
		else:
			nn = (nn - tng * nn.dot(tng)).normalized()   # paralel taşıma: halkalar burulmaz
		tl = tng
		var bb = tng.cross(nn)
		for s in sides + 1:
			var a = s * TAU / sides
			var r = float(radii[i]) * (1.0 + rough * (0.6 * sin(a * 2.0 + i * 1.3 + sd) + 0.4 * sin(a * 3.0 - i * 0.7 + sd * 2.0)))
			sf.set_color(Color.WHITE)
			sf.set_uv(Vector2(float(s) / sides, float(i) / maxf(1.0, n - 1)))
			sf.add_vertex(p + (nn * cos(a) + bb * sin(a)) * r)
	for i in n - 1:
		for s in sides:
			var a0 = i * (sides + 1) + s
			var u0 = a0 + sides + 1
			sf.add_index(a0)
			sf.add_index(u0)
			sf.add_index(a0 + 1)
			sf.add_index(a0 + 1)
			sf.add_index(u0)
			sf.add_index(u0 + 1)
	var tip_i = n * (sides + 1)
	sf.set_color(Color.WHITE)
	sf.set_uv(Vector2(0.5, 1.0))
	sf.add_vertex(pts[n - 1] + tl * float(radii[n - 1]) * tip)
	var bot_i = tip_i + 1
	sf.set_color(Color.WHITE)
	sf.set_uv(Vector2(0.5, 0.0))
	sf.add_vertex(pts[0] - t0 * float(radii[0]) * 0.3)
	var lb = (n - 1) * (sides + 1)
	for s in sides:
		sf.add_index(lb + s)
		sf.add_index(tip_i)
		sf.add_index(lb + s + 1)
		sf.add_index(s)
		sf.add_index(s + 1)
		sf.add_index(bot_i)
	sf.generate_normals()
	return sf.commit()


## Akan çamur yüzeyi parçası: yanlara doğru incelen (kenarı açık ten rengi), V biçimli kıvrımlı / dalgalı sırt; arazide oturur.
## Yerel +Z = d, yerel X = UP x d. z_off: parçalar arası kıvrım sürekliliği
static func flow_mesh(origin: Vector3, d: Vector3, w0: float, w1: float, L: float, h: float, z_off: float, sd: float, nx := 9, nz := 8) -> ArrayMesh:
	var side = Vector3.UP.cross(d).normalized()
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz + 1:
		var z = L * iz / nz
		var zg = z + z_off
		var w = lerpf(w0, w1, float(iz) / nz) * (1.0 + 0.12 * sin(zg * 1.1 + sd))
		var sx = 0.18 * sin(zg * 0.7 + sd * 2.0)
		for ix in nx + 1:
			var u = float(ix) / nx * 2.0 - 1.0
			var x = u * w * 0.5 + sx
			var prof = sqrt(maxf(0.0, 1.0 - u * u))
			var fld = 0.22 * sin(zg * 1.7 - absf(u) * 2.2 + sd) + 0.12 * sin(zg * 3.1 + u * 4.0)
			var y = h * prof * (1.0 + fld)
			var wpos = origin + side * x + d * z
			y += Game.jutsu_floor(wpos.x, wpos.z) - origin.y + 0.03
			var a = 0.0 if ix == 0 or ix == nx else 1.0
			sf.set_color(Color(1, 1, 1, a))
			sf.set_uv(Vector2(u, zg))
			sf.add_vertex(Vector3(x, y, z))
	for iz in nz:
		for ix in nx:
			var A = iz * (nx + 1) + ix
			var B = A + 1
			var C = A + nx + 1
			var D = C + 1
			sf.add_index(A)
			sf.add_index(B)
			sf.add_index(C)
			sf.add_index(B)
			sf.add_index(D)
			sf.add_index(C)
	sf.generate_normals()
	return sf.commit()


## Kil parçası: köşeli, iki üst üste kutudan (kırık kil kenarı)
static func chunk_mesh(variant: int) -> ArrayMesh:
	var key = "chunk_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3571 * (variant + 1)
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(1.0, rng.randf_range(0.45, 0.8), rng.randf_range(0.55, 0.9)), Color.WHITE, Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 90), rng.randf_range(-30, 30)), 4)
	b.add("box", Vector3(rng.randf_range(-0.2, 0.2), 0.15, rng.randf_range(-0.2, 0.2)), Vector3(0.7, 0.55, 0.65), Color.WHITE, Vector3(rng.randf_range(20, 60), rng.randf_range(0, 90), rng.randf_range(-40, 40)), 4)
	var m = b.build(null)
	_cache[key] = m
	return m


# ------------------------------------------------------------------ hareketli parçalar
## Balistik uçuş: yere değince on_land(mi, yer) çağrılır (sekmez). tumble verilmezse topak hız yönünde uzar (ağır damla)
static func _fly(mi: MeshInstance3D, p0: Vector3, v0: Vector3, g: float, size: float, stretch: float, on_land: Callable, tumble := Vector3.ZERO, max_t := 2.5) -> void:
	var stt = {"done": false}
	var step = func(tt: float):
		if stt["done"] or not is_instance_valid(mi):
			return
		var p = p0 + v0 * tt + Vector3.DOWN * 0.5 * g * tt * tt
		var fl = Game.jutsu_floor(p.x, p.z)
		if tt > 0.03 and p.y <= fl:
			stt["done"] = true
			on_land.call(mi, Vector3(p.x, fl, p.z))
			return
		mi.global_position = p
		if tumble != Vector3.ZERO:
			mi.rotation = tumble * tt
			mi.scale = Vector3.ONE * size
		else:
			var v = v0 + Vector3.DOWN * g * tt
			if v.length() > 0.2:
				var f = v.normalized()
				var k = 1.0 + minf(stretch, v.length() * 0.08)
				mi.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(size / sqrt(k), size / sqrt(k), size * k))
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, max_t, max_t)
	tw.tween_callback(func():
		if not stt["done"] and is_instance_valid(mi):
			mi.queue_free())


## Düşen topak yere yapışır: ezilip yırtık kenarlı küçük lekeye döner, yavaşça matlaşır, sonra yere çöker
static func _stick(mi: MeshInstance3D, pos: Vector3, r: float, life: float, dry_to: float) -> void:
	if not is_instance_valid(mi):
		return
	mi.mesh = splat_mesh(randi() % 6)
	mi.set_instance_shader_parameter("wob", 0.3)
	mi.global_basis = Basis(Vector3.UP, randf() * TAU)
	mi.global_position = pos + Vector3.UP * 0.015
	mi.scale = Vector3(r * 0.5, r * 2.2, r * 0.5)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r, r * 0.8, r), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_dry_fn(mi), 0.0, dry_to, life)
	tw.tween_property(mi, "scale", Vector3(r * 1.05, 0.01, r * 1.05), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Tek ağır çamur topağı (fırlatılmış ya da damla)
static func clump(pj: PathJutsu, pos: Vector3, vel: Vector3, size: float, life := 2.5, dry_to := 0.35) -> void:
	var mi = _mi(lump_mesh(randi() % 6), 0.0, 0.0, 0.0, 1.6)
	pj.scene_add(mi, pos)
	mi.scale = Vector3.ONE * size
	var land = func(m, p):
		_stick(m, p, size * 2.4, life, dry_to)
	_fly(mi, pos, vel, G, size, 1.6, land)


## Damla: uzayarak düşer, yere yapışır
static func drip(pj: PathJutsu, pos: Vector3, size := 0.09, life := 1.8) -> void:
	clump(pj, pos, Vector3(randf_range(-0.2, 0.2), -0.5, randf_range(-0.2, 0.2)), size, life, 0.3)


## Bir noktadan saçılan topaklar: bias eklenen hız (yönlü sıçrama), up dikey pay
static func clumps(pj: PathJutsu, pos: Vector3, n: int, spd: float, size: float, bias := Vector3.ZERO, up := 0.7, life := 2.5) -> void:
	for k in n:
		var a = randf() * TAU
		var h = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.35, 1.0)
		var v = h + Vector3.UP * spd * up * randf_range(0.6, 1.2) + bias * randf_range(0.7, 1.2)
		clump(pj, pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2)), v, size * randf_range(0.6, 1.3), life)


## Yere yapışan leke (along verilirse o yönde uzamış iz)
static func splat(pj: PathJutsu, pos: Vector3, r: float, life: float, dry_to := 0.3, deep := 0.0, edge := 0.0, along := Vector3.ZERO, stretch := 1.0) -> MeshInstance3D:
	var mi = _mi(splat_mesh(randi() % 6), 0.0, deep, edge, 0.4)
	pj.scene_add(mi, pj.gp(pos) + Vector3.UP * 0.02)
	mi.global_basis = Basis(Vector3.UP, randf() * TAU) if along == Vector3.ZERO else _face_basis(along)
	var full = Vector3(r, r * 0.8, r * stretch)
	mi.scale = full * Vector3(0.3, 2.0, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", full, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dry_to >= 0.0:
		tw.tween_method(_dry_fn(mi), 0.0, dry_to, life)
	else:   # kurumayı çağıran yönetir (harden)
		tw.tween_interval(life)
	tw.tween_property(mi, "scale", Vector3(r * 1.05, 0.01, r * stretch * 1.05), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Araziye oturan büyük çamur / bataklık havuzu (tam boyda kurulur, büyütmeyi çağıran yapar)
static func pool(pj: PathJutsu, center: Vector3, R: float, deep: float, edge: float, dome := 0.1, rag := 0.2) -> MeshInstance3D:
	var c = pj.gp(center)
	var mi = _mi(splat_mesh(randi() % 6, R, c, rag, dome, 9), 0.0, deep, edge, 0.5)
	pj.scene_add(mi, c)
	return mi


## Kil parçası: savrulur, yere düşüp kalır, sonra toprağa çöker
static func chunk(pj: PathJutsu, pos: Vector3, vel: Vector3, size: float) -> void:
	var mi = _mi(chunk_mesh(randi() % 6), 1.0, 0.0, 0.0, 0.0)
	pj.scene_add(mi, pos)
	mi.scale = Vector3.ONE * size
	var tum = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var land = func(m, p):
		if not is_instance_valid(m):
			return
		m.global_position = p + Vector3.UP * size * 0.2
		var tw = m.create_tween()
		tw.tween_interval(randf_range(0.9, 1.6))
		tw.tween_property(m, "global_position", p - Vector3.UP * size * 0.6, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(m.queue_free)
	_fly(mi, pos, vel, 22.0, size, 0.0, land, tum)


static func chunks(pj: PathJutsu, pos: Vector3, n: int, spd: float, size: float, bias := Vector3.ZERO, up := 0.6) -> void:
	for k in n:
		var a = randf() * TAU
		var h = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.3, 1.0)
		var v = h + Vector3.UP * spd * up * randf_range(0.5, 1.1) + bias * randf_range(0.6, 1.2)
		chunk(pj, pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3)), v, size * randf_range(0.5, 1.2))


## Kendi yer çatlağı: merkezden kırık çizgilerle yayılan, dallanan ince yarıklar (araziye oturur)
static func ground_cracks(pj: PathJutsu, pos: Vector3, R: float, n: int, col: Color, dur: float) -> void:
	var c = pj.gp(pos)
	var b = MB.new()
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dir = Vector3(cos(a), 0, sin(a))
		var p = dir * R * 0.12
		var L = R * randf_range(0.55, 1.0)
		var segn = 5
		var wd = 0.16
		for s in segn:
			dir = dir.rotated(Vector3.UP, randf_range(-0.55, 0.55))
			var q = p + dir * L / segn
			var mid = (p + q) * 0.5
			mid.y = Game.jutsu_floor(c.x + mid.x, c.z + mid.z) - c.y + 0.035
			b.add("box", mid, Vector3(wd, 0.03, L / segn + 0.06), col, Vector3(0, rad_to_deg(atan2(dir.x, dir.z)), 0), 4)
			if s > 0 and randf() < 0.35:   # yan dal
				var bd = dir.rotated(Vector3.UP, 0.9 if randf() < 0.5 else -0.9)
				var bm = p + bd * L / segn * 0.35
				bm.y = Game.jutsu_floor(c.x + bm.x, c.z + bm.z) - c.y + 0.035
				b.add("box", bm, Vector3(wd * 0.6, 0.03, L / segn * 0.7), col, Vector3(0, rad_to_deg(atan2(bd.x, bd.z)), 0), 4)
			wd *= 0.8
			p = q
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = _crack_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(mi, c)
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(mi.queue_free)


## Bataklık kabarcığı: yüzeyden yavaşça şişer, patlayınca halka dalgacık bırakır
static func bubble(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var mi = _mi(lump_mesh(randi() % 6, 0.1), 0.0, 0.6, 0.0, 0.5)
	pj.scene_add(mi, pos)
	mi.scale = Vector3.ONE * 0.02
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(s, s * 0.8, s), randf_range(0.35, 0.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(s * 1.5, s * 0.08, s * 1.5), 0.07)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			ripple(pj, mi.global_position, s * 0.6, s * 2.6, 0.5, 1.0, 0.0)
			mi.queue_free())


## Halka dalgacık: r0'dan r1'e yayılıp söner
static func ripple(pj: PathJutsu, pos: Vector3, r0: float, r1: float, t: float, edge := 1.0, deep := 0.0) -> void:
	var mi = _mi(ring_mesh(), 0.0, deep, edge, 0.3)
	pj.scene_add(mi, pos + Vector3.UP * 0.03)
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 0.4, r1), t).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


## Çamurdan el: yerden kalkan kalın kol, avuç ve damla uçlu kalın parmaklar. Yerel -Z = face, avuç / parmaklar +Z'ye kıvrık
static func mud_hand(pj: PathJutsu, at: Vector3, face: Vector3, h: float) -> Node3D:
	var root = Node3D.new()
	var sdv = randf() * 10.0
	root.add_child(_mi(tube_mesh([Vector3(0, -0.25, 0), Vector3(0, h * 0.3, 0.02), Vector3(0.02, h * 0.6, 0.07), Vector3(0, h * 0.82, 0.15)], [0.3, 0.2, 0.17, 0.19], 9, 0.2, sdv, 0.2), 0.0, 0.25, 0.0, 1.4))
	var palm = _mi(lump_mesh(randi() % 6, 0.2), 0.0, 0.25, 0.0, 1.2)
	palm.position = Vector3(0, h * 0.88, 0.2)
	palm.scale = Vector3(0.24, 0.2, 0.14)
	root.add_child(palm)
	for f in 4:
		var x = (f - 1.5) * 0.11
		var y0 = h * 0.95
		var pts = [Vector3(x, y0, 0.22), Vector3(x * 1.2, y0 + 0.22, 0.3), Vector3(x * 1.25, y0 + 0.36, 0.44), Vector3(x * 1.25, y0 + 0.34, 0.56)]
		root.add_child(_mi(tube_mesh(pts, [0.065, 0.058, 0.05, 0.04], 6, 0.15, sdv + f, 0.9), 0.0, 0.25, 0.0, 1.4))
	root.add_child(_mi(tube_mesh([Vector3(-0.2, h * 0.86, 0.2), Vector3(-0.33, h * 0.94, 0.32), Vector3(-0.36, h * 1.0, 0.45)], [0.07, 0.06, 0.045], 6, 0.15, sdv + 7.0, 0.9), 0.0, 0.25, 0.0, 1.4))
	var mound = _mi(lump_mesh(randi() % 6, 0.3, 0.8), 0.0, 0.5, 0.0, 0.8)
	mound.position = Vector3(0, 0.0, 0)
	mound.scale = Vector3(0.48, 0.2, 0.48)
	root.add_child(mound)
	for ch in root.get_children():   # okunur boy: kalın, ağır el
		ch.position *= 1.45
		ch.scale *= 1.45
	fold(root, 0.9)   # kalın, katmanlı kıvrımlı çamur kolu
	pj.scene_add(root, at)
	root.global_basis = Basis.looking_at(face.normalized(), Vector3.UP)
	return root


## Bedeni saran kil kabuğu: ıslak çamur bacaklardan yukarı tırmanır, hızla kuruyup kile döner, süre bitince çatlayıp parça parça dökülür
static func clay_shell(pj: PathJutsu, x: Node3D, dur: float) -> void:
	var bs = ClanJutsu.body_scale(x)
	for bone in ["LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg", "Hips"]:
		var ba = pj.bone_attach(x, bone)
		if ba == null:
			continue
		var holder = Node3D.new()
		ba.add_child(holder)
		for q in 2:
			var mi = _mi(lump_mesh(randi() % 6, 0.3), 0.0, 0.2, 0.0, 1.2, true)
			mi.position = Vector3(randf_range(-0.03, 0.03), 0.06 + q * 0.13, randf_range(-0.03, 0.03)) * bs
			mi.scale = Vector3(0.13, 0.15, 0.13) * bs
			holder.add_child(mi)
			harden(mi, 0.35, 0.2)
		holder.scale = Vector3(1, 0.1, 1)
		var tw = holder.create_tween()
		tw.tween_property(holder, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
		pj.free_after(dur, ba)
	var foot = splat(pj, x.global_position, 0.75 * bs, dur, -1.0, 0.2, 0.0)
	harden(foot, 0.35, 0.2)
	var xw = weakref(x)
	pj.after(dur, func():
		var x2 = xw.get_ref()
		if x2 != null and is_instance_valid(x2):
			chunks(pj, x2.global_position + Vector3.UP * 0.5, 10, 4.0, 0.14 * bs))


## Hazırlık: ayak dibinde toprak çamura kesilir — koyulaşan leke, yayılan halka, kabarıp geri çöken topaklar
static func well_up(pj: PathJutsu, pos: Vector3, r: float, n := 6) -> void:
	var g = pj.gp(pos)
	splat(pj, g, r, 1.6, 0.25, 0.5, 1.0)
	ripple(pj, g, r * 0.3, r * 1.6, 0.45, 1.0, 0.3)
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var p = pj.gp(g + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.5, 1.0))
		var mi = _mi(lump_mesh(randi() % 6, 0.3, 0.6), 0.0, 0.4, 0.0, 2.0)
		pj.scene_add(mi, p)
		mi.scale = Vector3.ONE * 0.02
		var sz = randf_range(0.18, 0.32) * r
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.02)
		tw.tween_property(mi, "scale", Vector3(sz, sz * 1.3, sz), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(sz * 1.5, sz * 0.1, sz * 1.5), 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Hazırlık: yerden kopan çamur topakları kavis çizerek bir noktada (el / baş üstü / göğüs) toplanır
static func gather(pj: PathJutsu, to: Vector3, from_c: Vector3, n: int, t: float, r := 1.4) -> void:
	for k in n:
		var a = randf() * TAU
		var p0 = pj.gp(from_c + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.6, 1.0)) + Vector3.UP * 0.1
		var mi = _mi(lump_mesh(randi() % 6, 0.25), 0.0, 0.2, 0.0, 2.0)
		pj.scene_add(mi, p0)
		var sz = randf_range(0.07, 0.13)
		mi.scale = Vector3.ONE * sz
		var mid = (p0 + to) * 0.5 + Vector3.UP * randf_range(0.3, 0.8)
		var path = func(u: float):
			if is_instance_valid(mi):
				mi.global_position = p0.lerp(mid, u).lerp(mid.lerp(to, u), u)
				var s2 = sz * (1.0 + 0.6 * sin(u * PI))
				mi.scale = Vector3(s2 * 0.8, s2 * 1.4, s2 * 0.8)
		var tw = mi.create_tween()
		tw.tween_interval(randf_range(0.0, t * 0.3))
		tw.tween_method(path, 0.0, 1.0, t * randf_range(0.55, 0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


# ================================================================== TEKNİKLER

## Deiryū Nadare — ağızdan kusulan ağır çamur, önde yuvarlanan kabarık bir dudakla 14 m akan sel; arkasında kıvrımlı, kenarı
## açık renkli bir çamur örtüsü kalır, sarkıp yavaşça çöker
static func deiryu_nadare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "deiton_deiryu_nadare"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.3)
	var cw = weakref(c)
	var from: Vector3 = c.global_position + d * 1.2
	well_up(pj, c.global_position, 1.3, 7)   # hazırlık: ayak dibi çamura kesilir
	_flood(pj, c, from, d, 14.0, 5.0, 0.9)
	Sfx.play("water", c.global_position, 0.5)
	var hit_k = {}
	var tick = func(_i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var front: Vector3 = pj.gp(from + d * 14.0 * k)
		for e in pj.enemies_near(cc, front, 3.0):
			var key = e.get_instance_id()
			if hit_k.has(key):
				if e is CharacterBody3D:
					e.velocity = d * 7.0   # sel sürükler
				continue
			hit_k[key] = true
			clumps(pj, e.global_position + Vector3.UP * 0.8, 6, 4.0, 0.16, d * 3.0)
			e.take_hit(pj.inf(cc, id, 2.0, {"knock": 12.0, "launch": 1.0, "kind": "heavy", "element": "deiton", "hitstop": 0.05, "dir": d}))
			pj.st(e, "slow", 5.0)
	pj.every(0.9, 0.06, tick)


## Sel görseli: ağızdan kalın çamur akıntısı + araziye oturan akış örtüsü parçaları + önde yuvarlanan topak dudak
static func _flood(pj: PathJutsu, c: Node3D, from: Vector3, d: Vector3, L: float, w: float, dur: float) -> void:
	var sd = d.cross(Vector3.UP).normalized()
	var mouth: Vector3 = c.global_position + Vector3.UP * 1.5 * ClanJutsu.body_scale(c) + d * 0.35
	var spew = func(_i, _k):
		clump(pj, mouth + sd * randf_range(-0.08, 0.08), d * randf_range(5.0, 7.0) + Vector3.UP * randf_range(-0.5, 1.2) + sd * randf_range(-0.7, 0.7), randf_range(0.13, 0.22), 1.4)
	pj.every(0.45, 0.035, spew)
	var gush = _mi(lump_mesh(2, 0.3), 0.0, 0.2, 0.0, 3.0)   # ağızda kabaran çamur kütlesi
	pj.scene_add(gush, mouth)
	gush.global_basis = _face_basis(d)
	gush.scale = Vector3.ONE * 0.05
	var gt0 = gush.create_tween()
	gt0.tween_property(gush, "scale", Vector3(0.3, 0.28, 0.45), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gt0.tween_interval(0.3)
	gt0.tween_property(gush, "scale", Vector3.ONE * 0.02, 0.15).set_ease(Tween.EASE_IN)
	gt0.tween_callback(gush.queue_free)
	var o = pj.gp(from)
	var fb = _face_basis(d)
	var segs = []
	var nseg = 7
	var sl = L / nseg
	var sdv = randf() * 10.0
	for i in nseg:
		var org = pj.gp(from + d * sl * i)
		var w0 = w * (0.5 + 0.5 * minf(1.0, float(i) / 2.0))
		var w1 = w * (0.5 + 0.5 * minf(1.0, float(i + 1) / 2.0))
		var mi = _mi(flow_mesh(org, d, w0, w1, sl + 0.3, 0.45, sl * i, sdv), 0.0, 0.15, 0.0, 1.4)
		pj.scene_add(mi, org)
		mi.global_basis = fb
		mi.scale = Vector3(1, 1, 0.02)
		mi.visible = false
		segs.append(mi)
		fold(mi, 0.8)
		pj.free_after(dur + 4.5, mi)
	var lip = Node3D.new()
	pj.scene_add(lip, o)
	lip.global_basis = fb
	var lumps = []
	for k in 5:
		var lm = _mi(lump_mesh(k, 0.3), 0.0, 0.1, 0.0, 2.0, true)
		lm.position = Vector3((k - 2) * w * 0.2, 0.45, randf_range(-0.2, 0.2))
		lm.scale = Vector3(0.8, 0.65, 0.75)
		lip.add_child(lm)
		lumps.append(lm)
		fold(lm, 0.7)
	pj.free_after(dur + 0.5, lip)
	var roll = func(i, k):
		if not is_instance_valid(lip):
			return
		var fd = L * k
		lip.global_position = pj.gp(from + d * fd)
		var sw = 0.55 + 0.55 * sin(k * PI) + 0.2
		lip.scale = Vector3(1.0 + k * 0.6, sw, sw)
		for lm in lumps:
			if is_instance_valid(lm):
				lm.rotate_object_local(Vector3.RIGHT, 0.32)   # öne yuvarlanır
		for si in segs.size():
			var sm = segs[si]
			if is_instance_valid(sm) and not sm.visible and fd >= sl * si:
				sm.visible = true
				var gt = sm.create_tween()
				gt.tween_property(sm, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT)
		if i % 3 == 0:
			var pp = lip.global_position + Vector3.UP * 0.8 * sw + sd * randf_range(-w * 0.4, w * 0.4)
			clump(pj, pp, d * randf_range(4.0, 7.0) + Vector3.UP * randf_range(2.0, 4.0) + sd * randf_range(-1.5, 1.5), randf_range(0.14, 0.24), 2.0)
	var settle = func():
		if is_instance_valid(lip):
			for lm in lumps:
				if is_instance_valid(lm):
					splat(pj, lm.global_position, randf_range(0.9, 1.3), 2.5, 0.35, 0.1, 0.0, d, 1.5)
			clumps(pj, lip.global_position + Vector3.UP * 0.5, 8, 4.0, 0.18, d * 3.0)
			lip.queue_free()
		for sm in segs:   # örtü sarkar, matlaşır, sonra çöker
			if is_instance_valid(sm):
				sm.visible = true
				var st2 = sm.create_tween()
				st2.tween_property(sm, "scale", Vector3(1.0, 0.45, 1.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				harden(sm, 2.5, 0.0, 0.35)
				sink_free(sm, 2.8, 0.7)
	pj.every(dur, 1.0 / 30.0, roll, settle)


## Kōdei Kasen — üç ağır, damla biçimli çamur mermisi; arkalarından çamur damlar. Değdiği yerde leke anında kile kesilip çatlar,
## vurulanın bacakları kil kabuğuna gömülür
static func kodei_kasen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "deiton_kodei_kasen"
	var tt = pj.tg(c, t, 26.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	var cw = weakref(c)
	gather(pj, pj.hand_pos(c), c.global_position, 7, 0.28)   # hazırlık: çamur ele toplanır
	for k in 3:
		var fire = func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var from: Vector3 = pj.hand_pos(cc)
			var holder = Node3D.new()
			var ball = _mi(lump_mesh(k, 0.22), 0.0, 0.1, 0.0, 2.2)
			ball.scale = Vector3(0.34, 0.31, 0.4)
			holder.add_child(ball)
			var tail = _mi(lump_mesh(k + 3, 0.2), 0.0, 0.2, 0.0, 2.2)   # arkaya sarkan damla kuyruğu (+Z = geri)
			tail.position = Vector3(0, 0, 0.4)
			tail.scale = Vector3(0.19, 0.17, 0.34)
			holder.add_child(tail)
			var on_hit = func(p, h):
				_kasen_impact(pj, p, h)
				if h and is_instance_valid(h) and pj.live(h):
					clay_shell(pj, h, 1.8)
					pj.st(h, "bind", 1.8)
			var pr = pj.shot(cc, from, pj.aim_at(cc, tt, from).rotated(Vector3.UP, (k - 1) * 0.08), 30.0, holder, pj.inf(cc, id, 0.8, {"knock": 2.0, "kind": "heavy", "element": "deiton"}), tt, false, 1.4, on_hit)
			pr.gravity = 4.0
			pr.radius = 0.45
			var dt_s = {"t": 0.0}
			pr.on_tick = func(p2, dt):
				dt_s["t"] -= dt
				if dt_s["t"] <= 0.0 and is_instance_valid(p2):
					dt_s["t"] = 0.07
					drip(pj, p2.global_position + Vector3.DOWN * 0.15, 0.06, 1.2)
		pj.after(k * 0.1, fire)
	Sfx.play("water", c.global_position, 0.8)


static func _kasen_impact(pj: PathJutsu, p: Vector3, h) -> void:
	var g = pj.gp(p)
	clumps(pj, p, 5, 3.5, 0.11, Vector3.ZERO, 0.6, 1.6)
	if h == null and p.y - g.y < 1.5:   # yere değdi: leke anında kile kesilir, çatlar
		var s = splat(pj, g, 0.9, 2.2, -1.0, 0.1, 0.0)
		harden(s, 0.3, 0.12)


## Deishō Kōka — ayağının altından yayılan, kenarı bordo kara-kahve bir bataklık; yüzeyi kabarcıklanır, içindekilerin
## ayaklarında halkalar açılır; sonra bir anda kile kesilir, çatlak ağıyla bölünüp parçalara ayrılır
static func deisho_koka(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "deiton_deisho_koka"
	pj.anim(c, "crouch", 1.4)
	var cw = weakref(c)
	var cen: Vector3 = pj.gp(c.global_position)
	var R := 6.5
	well_up(pj, cen, 1.6, 8)
	var pl = pool(pj, cen, R, 0.9, 1.0, 0.08, 0.16)
	fold(pl, 0.6)
	fold_rolls(pj, cen, R, 4, pl)   # iç içe yığılmış kıvrım sırtları
	pl.scale = Vector3(0.08, 1.0, 0.08)
	var pt = pl.create_tween()
	pt.tween_property(pl, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pj.free_after(4.6, pl)
	ripple(pj, cen, 0.5, R * 0.9, 0.5, 1.0, 0.3)
	Sfx.play("water", cen, 0.4)
	var boil = func(_i, _k):
		if not is_instance_valid(pl):
			return
		var a = randf() * TAU
		var q = cen + Vector3(cos(a), 0, sin(a)) * R * sqrt(randf()) * 0.85
		bubble(pj, pj.gp(q) + Vector3.UP * 0.08, randf_range(0.18, 0.4))
	pj.every(1.6, 0.12, boil)
	var tick = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, cen, R):
			pj.st(e, "slow", 0.6)
			if i % 3 == 0:
				var fp = pj.gp(e.global_position)
				ripple(pj, fp, 0.4, 1.3 * ClanJutsu.body_scale(e), 0.5, 1.0, 0.2)
				clumps(pj, fp + Vector3.UP * 0.2, 2, 2.0, 0.1, Vector3.ZERO, 1.0, 1.2)
				e.take_hit(pj.inf(cc, id, 0.3, {"knock": 0.0, "kind": "light", "element": "deiton", "hitstop": 0.0}))
	pj.every(1.6, 0.2, tick)
	var set_hard = func():   # sertleşir: kile döner
		var cc = cw.get_ref()
		if is_instance_valid(pl):
			harden_all(pl, 0.35)
			var t2 = pl.create_tween()
			t2.tween_interval(1.8)
			t2.tween_callback(func():
				for q in 14:
					var a = randf() * TAU
					var pp = pj.gp(cen + Vector3(cos(a), 0, sin(a)) * R * sqrt(randf()) * 0.9)
					chunk(pj, pp + Vector3.UP * 0.1, Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 4.0), randf_range(-1.5, 1.5)), randf_range(0.2, 0.4)))
			t2.tween_property(pl, "scale", Vector3(1.0, 0.01, 1.0), 0.5)
			t2.tween_callback(pl.queue_free)
		ground_cracks(pj, cen, R, 9, Color(0.24, 0.19, 0.14), 2.0)
		Sfx.play("earth", cen, 0.8)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, cen, R):
			clay_shell(pj, e, 2.2)
			pj.st(e, "bind", 2.2)
			e.take_hit(pj.inf(cc, id, 1.6, {"knock": 0.0, "kind": "heavy", "element": "deiton", "hitstop": 0.05}))
	pj.after(1.6, set_hard)


## Doro Bunshin — yerde çamur kabarır, kopya o kütlenin içinden yükselir; bedeni aşağı süzülen ıslak çamurla kaplı, damlar.
## Vurulunca kendi ağırlığıyla çöker: çamur sütunu yayvanlaşıp lekeye döner, topaklar her yana saçılır
static func doro_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "deiton_doro_bunshin"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(c.global_position + d * 1.6 + d.cross(Vector3.UP) * 1.0)
	well_up(pj, at, 1.2, 6)
	gather(pj, at + Vector3.UP * 0.6, c.global_position, 5, 0.3, 1.0)
	var mound = _mi(lump_mesh(2, 0.3, 0.7), 0.0, 0.3, 0.0, 2.0, true)   # kopyanın çıktığı kabaran kütle
	pj.scene_add(mound, at)
	mound.scale = Vector3(0.1, 0.05, 0.1)
	var mt = mound.create_tween()
	mt.tween_property(mound, "scale", Vector3(0.75, 0.9, 0.75), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	mt.tween_property(mound, "scale", Vector3(1.1, 0.12, 1.1), 0.45).set_ease(Tween.EASE_IN)
	mt.tween_callback(mound.queue_free)
	splat(pj, at, 1.1, 3.0, 0.4, 0.2)
	clumps(pj, at + Vector3.UP * 0.5, 6, 2.5, 0.13)
	Sfx.play("water", at, 0.5)
	var on_pop = func(p):
		var cc = cw.get_ref()
		_mud_collapse(pj, p)
		Sfx.play("water", p, 0.4)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, p, 3.2):
			pj.st(e, "slow", 3.0)
			clay_shell(pj, e, 1.5)
			pj.st(e, "bind", 1.5)
			e.take_hit(pj.inf(cc, id, 0.9, {"knock": 4.0, "kind": "heavy", "element": "deiton", "hitstop": 0.06}))
	var cl = pj.decoy(c, at, 8.0, on_pop)
	if cl:   # kopyanın bedeni çamurdan: üstünden çamur süzülür; dağılırken duman değil çamur
		cl.set_meta("no_smoke", true)
		var cm = cl.get("model")
		if cm and is_instance_valid(cm):
			for mi in (cm as Node).find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = skin_mat()
			if cm is Node3D:
				var s0: Vector3 = cm.scale
				cm.scale = Vector3(s0.x * 1.15, s0.y * 0.05, s0.z * 1.15)
				var rt = cm.create_tween()
				rt.tween_property(cm, "scale", s0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var clw = weakref(cl)
		var drips = func(_i, _k):
			var x = clw.get_ref()
			if x != null and is_instance_valid(x):
				var a = randf() * TAU
				drip(pj, x.global_position + Vector3(cos(a) * 0.3, randf_range(0.6, 1.5), sin(a) * 0.3), randf_range(0.06, 0.1))
		pj.every(8.0, 0.4, drips)


## Kopya çöküşü: insan boyu çamur sütunu kendi ağırlığıyla yayvanlaşıp lekeye döner
static func _mud_collapse(pj: PathJutsu, p: Vector3) -> void:
	var g = pj.gp(p)
	var col = _mi(lump_mesh(4, 0.3), 0.0, 0.2, 0.0, 2.5, true)
	pj.scene_add(col, g + Vector3.UP * 0.9)
	fold(col, 0.8)
	col.scale = Vector3(0.42, 0.95, 0.4)
	var tw = col.create_tween()
	tw.set_parallel(true)
	tw.tween_property(col, "scale", Vector3(1.3, 0.14, 1.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(col, "global_position", g + Vector3.UP * 0.08, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(col):
			col.queue_free()
		splat(pj, g, 2.0, 3.0, 0.45, 0.25)
		clumps(pj, g + Vector3.UP * 0.4, 14, 5.0, 0.17))


## Doronuma Hikizuri — rakibin altında kara-kahve, bordo kenarlı bir bataklık açılır; içinden beş çamur eli kalkıp bacaklara
## kapanır, halkalar yayılırken onu aşağı çeker; sonra eller bataklığa gömülür
static func doronuma_hikizuri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "deiton_doronuma_hikizuri"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.4)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var bs = ClanJutsu.body_scale(tt) if tt else 1.0
	var R = 2.6 * bs
	well_up(pj, c.global_position, 0.9, 5)   # avuçlar yere: çamur yerin altından hedefe akar
	well_up(pj, at, R * 0.6, 7)
	var pl = pool(pj, at, R, 1.0, 1.0, 0.06, 0.22)
	fold(pl, 0.6)
	fold_rolls(pj, at, R, 3, pl)
	pl.scale = Vector3(0.12, 1.0, 0.12)
	var pt = pl.create_tween()
	pt.tween_property(pl, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
	pt.tween_interval(2.4)
	pt.tween_property(pl, "scale", Vector3(1.0, 0.01, 1.0), 0.4)
	pt.tween_callback(pl.queue_free)
	var rip = func(_i, _k):
		ripple(pj, at, 0.3 * bs, R * 0.95, 0.7, 1.0, 0.2)
	pj.every(2.4, 0.45, rip)
	Sfx.play("water", at, 0.4)
	var hands = []
	for k in 5:
		var a = k * TAU / 5.0
		var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * 0.75 * bs
		var hnd = mud_hand(pj, p, (p - at).normalized() + Vector3.UP * 0.01, 1.1 * bs)
		hnd.scale = Vector3(1, 0.05, 1)
		var ht = hnd.create_tween()
		ht.tween_interval(0.15 + k * 0.05)
		ht.tween_property(hnd, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ht.tween_property(hnd, "rotation:x", hnd.rotation.x + 0.6, 0.2)   # bacaklara kapanır
		ht.tween_interval(1.9)
		ht.tween_property(hnd, "global_position", p - Vector3.UP * 1.4 * bs, 0.4).set_ease(Tween.EASE_IN)   # bataklığa gömülür
		ht.tween_callback(hnd.queue_free)
		hands.append(hnd)
		pj.free_after(3.2, hnd)
	var caught = []
	var grab = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, R):
			caught.append(weakref(e))
			pj.st(e, "bind", 2.3)
			e.take_hit(pj.inf(cc, id, 0.4, {"knock": 0.0, "kind": "heavy", "element": "deiton", "hitstop": 0.05}))
			var ebs = ClanJutsu.body_scale(e)   # bacaklara sarılan çamur yakası: kurban batıyormuş gibi
			var collar = _mi(lump_mesh(randi() % 6, 0.35, 0.5), 0.0, 0.7, 1.0, 2.0)
			e.add_child(collar)
			collar.position = Vector3.UP * 0.15 * ebs
			collar.scale = Vector3(0.05, 0.05, 0.05)
			var ct = collar.create_tween()
			ct.tween_property(collar, "scale", Vector3(0.55, 0.4, 0.55) * ebs, 0.25).set_ease(Tween.EASE_OUT)
			ct.tween_property(collar, "scale", Vector3(0.6, 0.62, 0.6) * ebs, 1.9).set_trans(Tween.TRANS_SINE)
			pj.free_after(2.3, collar)
	pj.after(0.4, grab)
	var squeeze = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e):
				var fp = pj.gp(e.global_position)
				clumps(pj, fp + Vector3.UP * 0.25, 3, 1.8, 0.1, Vector3.ZERO, 1.0, 1.2)
				ripple(pj, fp, 0.3, 1.0 * ClanJutsu.body_scale(e), 0.4, 1.0, 0.4)
				if i % 2 == 1:
					e.take_hit(pj.inf(cc, id, 0.22, {"knock": 0.0, "kind": "light", "element": "deiton", "hitstop": 0.0}))
	pj.every(2.3, 0.3, squeeze)


## Deigandan — üstünden topaklar sallanan, yalpalayan dev bir çamur güllesi damlaya damlaya yay çizer; düştüğü yerde çamur
## taç gibi kalkıp sarkarak geri çöker, her yana topak saçar, yayılan havuz biraz sonra kile kesilip parçalanır
static func deigandan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "deiton_deigandan"
	var tt = pj.tg(c, t, 26.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.2)
	var cw = weakref(c)
	var from: Vector3 = c.global_position + Vector3.UP * 1.8 + d * 0.6
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 12.0)
	var ball = _mi(lump_mesh(1, 0.3), 0.0, 0.15, 0.0, 3.0, true)
	ball.scale = Vector3.ONE * 0.3   # toplanarak büyür
	for q in 3:   # üstüne yapışık sarkan topaklar
		var sat = _mi(lump_mesh(q + 2, 0.25), 0.0, 0.2, 0.0, 3.0)
		sat.position = Vector3(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7), randf_range(-0.7, 0.7)).normalized() * 0.85
		sat.scale = Vector3.ONE * randf_range(0.3, 0.42)
		ball.add_child(sat)
	pj.scene_add(ball, from)
	gather(pj, from, c.global_position, 9, 0.22, 1.6)   # hazırlık: güllenin kütlesi yerden toplanır
	var gt1 = ball.create_tween()
	gt1.tween_property(ball, "scale", Vector3.ONE * 0.75, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fly = 0.75
	var arc = func(u: float):
		if is_instance_valid(ball):
			ball.global_position = from.lerp(at, u) + Vector3.UP * sin(u * PI) * 5.0
			ball.rotate_x(0.15)
	var tw_ = ball.create_tween()
	tw_.tween_method(arc, 0.0, 1.0, fly)
	tw_.tween_callback(ball.queue_free)
	var drops = func(_i, _k):
		if is_instance_valid(ball):
			drip(pj, ball.global_position + Vector3.DOWN * 0.6, randf_range(0.08, 0.13), 1.6)
	pj.every(fly, 0.08, drops)
	Sfx.play("water", from, 0.6)
	var land = func():
		var cc = cw.get_ref()
		_crown(pj, at, 1.0)
		clumps(pj, at + Vector3.UP * 0.5, 18, 9.0, 0.2)
		Sfx.play("water", at, 0.3)
		Sfx.play("boom", at, 0.5)
		pj.shake(0.35)
		var R = 4.0
		var pl = pool(pj, at, R, 0.3, 0.0, 0.12, 0.3)
		fold(pl, 0.4)
		pl.scale = Vector3(0.2, 1.0, 0.2)
		var gt = pl.create_tween()
		gt.tween_property(pl, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pj.free_after(4.2, pl)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, R):
			var v: Vector3 = e.global_position - at
			v.y = 0
			var near = v.length() < 1.8 + e.radius
			pj.st(e, "slow", 2.5)
			e.take_hit(pj.inf(cc, id, 1.5 if near else 0.7, {"knock": 8.0 if near else 3.0, "launch": 2.0, "kind": "heavy", "element": "deiton", "hitstop": 0.08, "dir": v.normalized() if v.length() > 0.1 else d}))
		var to_clay = func():   # kile döner
			var c2 = cw.get_ref()
			if is_instance_valid(pl):
				harden(pl, 0.4)
				var t2 = pl.create_tween()
				t2.tween_interval(1.4)
				t2.tween_callback(func():
					for q in 10:
						var a = randf() * TAU
						var pp = pj.gp(at + Vector3(cos(a), 0, sin(a)) * R * sqrt(randf()) * 0.85)
						chunk(pj, pp + Vector3.UP * 0.1, Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 3.5), randf_range(-1.5, 1.5)), randf_range(0.2, 0.38)))
				t2.tween_property(pl, "scale", Vector3(1.0, 0.01, 1.0), 0.4)
				t2.tween_callback(pl.queue_free)
			ground_cracks(pj, at, R, 8, Color(0.26, 0.2, 0.15), 1.8)
			Sfx.play("earth", at, 0.9)
			if c2 == null or not pj.live(c2):
				return
			for e in pj.enemies_near(c2, at, R):
				clay_shell(pj, e, 1.6)
				pj.st(e, "bind", 1.6)
		pj.after(1.1, to_clay)
	pj.after(fly, land)


## Çarpma tacı: düşüş noktasının çevresinden kalkan kalın çamur dilleri; ağırlıkla dışa sarkıp çöker
static func _crown(pj: PathJutsu, at: Vector3, s: float) -> void:
	var root = Node3D.new()
	fold(root, 0.8)
	pj.scene_add(root, pj.gp(at))
	var n = 10
	for k in n:
		var a = k * TAU / n + randf_range(-0.15, 0.15)
		var dv = Vector3(cos(a), 0, sin(a))
		var hh = randf_range(0.9, 1.6) * s
		var pts = [dv * 0.9 * s, dv * 1.25 * s + Vector3.UP * hh * 0.55, dv * 1.6 * s + Vector3.UP * hh, dv * 1.85 * s + Vector3.UP * hh * 0.9]
		root.add_child(_mi(tube_mesh(pts, [0.32 * s, 0.22 * s, 0.14 * s, 0.11 * s], 7, 0.2, randf() * 10.0, 1.0), 0.0, 0.2, 0.0, 2.0))
	root.scale = Vector3(0.6, 0.05, 0.6)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3(1.35, 0.15, 1.35), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # ağırlıkla sarkar
	tw.tween_callback(root.queue_free)


## Deiheki — yerden kabaran, tepesi öne doğru sarkıp damlayan kalın çamur sırtlarından duvar; gelen atışlar içine gömülür
## (yüzeyde kabarıp kapanır). Süre sonunda kuruyup kile döner, çatlaklarla bölünür ve önüne doğru kil parçaları halinde patlar
static func deiheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "deiton_deiheki"
	var d = pj._face(c, t)
	pj._yama_seal(c)
	var DUR = 4.5
	var at: Vector3 = pj.gp(c.global_position + d * 2.0)
	var sd = d.cross(Vector3.UP).normalized()
	well_up(pj, at, 2.2, 9)
	var wall = Node3D.new()
	var core = _mi(lump_mesh(0, 0.28), 0.0, 0.3, 0.0, 1.4, true)   # tek parça gövde: sırtlar bunun üstünde kabarır
	core.position = Vector3(0, 1.15, 0.0)
	core.scale = Vector3(2.55, 1.45, 0.62)
	wall.add_child(core)
	for k in 9:   # düzensiz yükseklik ve kalınlıkta, tepesi öne sarkıp yayvanlaşan çamur sırtları (birbirine kaynaşık)
		var x = (k - 4) * 0.52 + randf_range(-0.12, 0.12)
		var h = 2.75 - absf(k - 4) * 0.16 + randf_range(-0.45, 0.3)
		var j = randf_range(-0.12, 0.12)
		var rr = randf_range(0.45, 0.62)
		var lean = randf_range(0.35, 0.75)
		var pts = [Vector3(x, -0.3, 0.0), Vector3(x + j, h * 0.45, 0.06), Vector3(x - j, h * 0.82, 0.14), Vector3(x + 0.08, h, lean * 0.6), Vector3(x + 0.12, h * 0.86, lean)]
		wall.add_child(_mi(tube_mesh(pts, [rr, rr * 0.92, rr * 0.82, rr * 0.62, rr * 0.34], 10, 0.24, randf() * 10.0, 0.9), 0.0, 0.2, 0.0, 1.6, true))
		if randf() < 0.75:   # öne sarkan tepeden asılı kalın damla
			var dr = _mi(lump_mesh(randi() % 6, 0.15), 0.0, 0.2, 0.0, 2.0)
			dr.position = Vector3(x + 0.12, h * 0.86 - 0.25, lean + 0.05)
			dr.scale = Vector3(0.11, randf_range(0.22, 0.4), 0.11)
			wall.add_child(dr)
	var foot = _mi(lump_mesh(5, 0.3, 0.8), 0.0, 0.35, 0.0, 1.2)   # tabanda yayılan kütle
	foot.position = Vector3(0, 0.0, 0.1)
	foot.scale = Vector3(2.8, 0.45, 0.9)
	wall.add_child(foot)
	fold(wall, 0.7)   # katman katman sarkan sırtlar
	pj.scene_add(wall, at - Vector3.UP * 3.0)
	wall.global_basis = Basis.looking_at(-d, Vector3.UP)
	var wt = wall.create_tween()
	wt.tween_property(wall, "global_position", at, 0.3).set_ease(Tween.EASE_OUT)
	pj.free_after(DUR + 1.5, wall)
	splat(pj, at + d * 0.4, 1.6, DUR, 0.35, 0.2, 0.0, sd, 2.0)
	clumps(pj, at + Vector3.UP, 10, 4.0, 0.15, d * 2.0)
	Sfx.play("water", at, 0.5)
	var cw = weakref(c)
	var eaten = {"n": 0}
	var tick = func(i, _k):
		var cc = cw.get_ref()
		if i % 10 == 0 and is_instance_valid(wall):   # ön yüzden aşağı süzülen damla
			_slide_drip(pj, at + sd * randf_range(-2.2, 2.2) + Vector3.UP * randf_range(1.2, 2.6) + d * 0.6)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # atışlar çamura gömülür
			if not is_instance_valid(p) or p.get("shooter") == cc:
				continue
			var v: Vector3 = p.global_position - at
			if absf(v.dot(d)) < 0.8 and absf(v.dot(sd)) < 2.6 and v.y > -0.3 and v.y < 3.0:
				_gulp(pj, p.global_position, d)
				Sfx.play("water", p.global_position, 1.2)
				eaten["n"] += 1
				p.queue_free()
	var finish = func():
		var cc = cw.get_ref()
		if not is_instance_valid(wall):
			return
		harden_all(wall, 0.45)   # kurur
		Sfx.play("earth", at, 0.9)
		var burst = func():
			var c2 = cw.get_ref()
			if is_instance_valid(wall):
				wall.queue_free()
			for q in 22:   # kil parçaları önüne doğru
				var pp = at + sd * randf_range(-2.2, 2.2) + Vector3.UP * randf_range(0.3, 2.6)
				chunk(pj, pp, d * randf_range(7.0, 13.0) + Vector3.UP * randf_range(1.0, 4.0) + sd * randf_range(-2.0, 2.0), randf_range(0.22, 0.45))
			ground_cracks(pj, at, 2.8, 6, Color(0.24, 0.19, 0.14), 1.2)
			Sfx.play("boom", at, 0.8)
			pj.shake(0.3)
			if c2 == null or not pj.live(c2):
				return
			for e in pj.enemies_near(c2, at + d * 4.0, 4.5):
				if (e.global_position - at).dot(d) > 0.0:
					e.take_hit(pj.inf(c2, id, 1.0 + 0.15 * mini(eaten["n"], 6), {"knock": 10.0, "launch": 2.0, "kind": "heavy", "element": "deiton", "bleed": 1.5, "hitstop": 0.06, "dir": d}))
		pj.after(0.5, burst)
	pj.every(DUR, 0.04, tick, finish)


## Duvar yüzünden yavaşça aşağı süzülen çamur damlası; dibe varınca yere yapışır
static func _slide_drip(pj: PathJutsu, p: Vector3) -> void:
	var mi = _mi(lump_mesh(randi() % 6, 0.15), 0.0, 0.2, 0.0, 1.0)
	pj.scene_add(mi, p)
	mi.scale = Vector3(0.12, 0.2, 0.1)
	var g = pj.gp(p)
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", g + Vector3.UP * 0.05, randf_range(0.9, 1.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "scale", Vector3(0.1, 0.34, 0.09), 0.9)
	tw.chain().tween_callback(func():
		if is_instance_valid(mi):
			_stick(mi, g, 0.25, 1.5, 0.3))


## Duvar bir atışı yutar: yüzeyde kabarıp kapanan çamur + aşağı düşen topaklar
static func _gulp(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var mi = _mi(lump_mesh(randi() % 6, 0.3), 0.0, 0.25, 0.0, 2.5)
	pj.scene_add(mi, p)
	mi.scale = Vector3.ONE * 0.05
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.45, 0.4, 0.3), 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	for k in 3:
		clump(pj, p + d * 0.2, d * randf_range(0.5, 1.5) + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.0), randf_range(-0.6, 0.6)), randf_range(0.08, 0.13), 1.6)


## Doryū Suberi — ayağının altında kabaran, arkada kıvrılıp öne iten çamur dalgasının sırtında kayarsın; yanlardan çamur
## savrulur, arkanda uzamış ıslak bir iz kalır, çarptığını çamur patlamasıyla savurur
static func doryu_suberi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	var id = "deiton_doryu_suberi"
	var d = pj._face(c, tt)
	pj.anim(c, "slide", 1.2)
	var cw = weakref(c)
	var hitk = {}
	var trail = []
	well_up(pj, c.global_position, 1.2, 6)
	var wave = Node3D.new()
	var base = _mi(lump_mesh(3, 0.3, 0.7), 0.0, 0.25, 0.0, 2.5, true)   # ayağın altındaki kabarık sırt
	base.position = Vector3(0, -0.15, 0.1)
	base.scale = Vector3(1.3, 0.45, 1.6)
	wave.add_child(base)
	var swell = _mi(lump_mesh(1, 0.3, 0.6), 0.0, 0.3, 0.0, 2.5)   # arkadaki kabarık sırt (tek kütle)
	swell.position = Vector3(0, 0.05, -0.9)
	swell.scale = Vector3(1.5, 0.55, 0.7)
	wave.add_child(swell)
	for k in 7:   # sırtın üstünden öne dökülen alçak, kaynaşık kıvrımlar (+Z = ileri); bacakları geçmez
		var x = (k - 3) * 0.36 + randf_range(-0.08, 0.08)
		var hk = 0.75 - absf(k - 3) * 0.08 + randf_range(-0.1, 0.06)
		var pts = [Vector3(x * 1.3, 0.0, -1.3), Vector3(x * 1.2, 0.45 * hk, -1.15), Vector3(x * 1.1, 0.75 * hk, -0.8), Vector3(x, 0.62 * hk, -0.45), Vector3(x * 0.95, 0.35 * hk, -0.2)]
		wave.add_child(_mi(tube_mesh(pts, [0.32, 0.3, 0.24, 0.17, 0.09], 8, 0.22, randf() * 10.0, 1.0), 0.0, 0.2, 0.0, 2.2))
	for k in 2:   # yan kanatlar: sağa sola yayılan çamur
		var sg = -1.0 if k == 0 else 1.0
		var wing = _mi(lump_mesh(k + 2, 0.3, 0.7), 0.0, 0.2, 0.0, 2.5)
		wing.position = Vector3(sg * 1.1, -0.12, -0.2)
		wing.scale = Vector3(0.7, 0.3, 1.3)
		wing.rotation.y = sg * 0.4
		wave.add_child(wing)
	var lip = _mi(lump_mesh(5, 0.3, 0.6), 0.0, 0.1, 0.0, 2.5)   # önde dökülen dudak
	lip.position = Vector3(0, -0.1, 1.0)
	lip.scale = Vector3(1.0, 0.25, 0.5)
	wave.add_child(lip)
	fold(wave, 1.0)
	pj.scene_add(wave, c.global_position)
	pj.free_after(2.0, wave)
	Sfx.play("water", c.global_position, 0.5)
	var sd = d.cross(Vector3.UP).normalized()
	var tick = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = d * 22.0
		var p: Vector3 = pj.gp(cc.global_position)
		if is_instance_valid(wave):   # ayağın altında kabaran dalga
			wave.global_position = p - d * 0.3 + Vector3.UP * 0.2
			wave.global_basis = _face_basis(d) * Basis.from_scale(Vector3(1.0, 0.9 + sin(i * 0.4) * 0.1, 1.0))
		if i % 3 == 0:   # yanlardan savrulan çamur
			var sg = 1.0 if i % 6 == 0 else -1.0
			clump(pj, p + Vector3.UP * 0.5 + sd * sg * 0.9, sd * sg * randf_range(3.0, 5.0) + Vector3.UP * randf_range(2.0, 3.5) - d * randf_range(1.0, 3.0), randf_range(0.12, 0.2), 1.8)
		if i % 6 == 0:
			trail.append(p)
			splat(pj, p, 1.0, 4.0 + 0.75 - i / 60.0, 0.35, 0.15, 0.0, d, 2.2)   # arkada kalan ıslak iz
		for e in pj.enemies_near(cc, p + d * 0.8, 1.8):
			var key = e.get_instance_id()
			if hitk.has(key):
				continue
			hitk[key] = true
			clumps(pj, e.global_position + Vector3.UP * 0.5, 10, 4.5, 0.18, (d + Vector3.UP * 0.3) * 4.0)
			e.take_hit(pj.inf(cc, id, 1.5, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "element": "deiton", "hitstop": 0.08, "dir": (d + Vector3.UP * 0.3).normalized()}))
			pj.st(e, "slow", 3.0)
	var done = func():
		var cc = cw.get_ref()
		if is_instance_valid(wave):   # dalga yere yığılır
			splat(pj, wave.global_position, 1.6, 3.5, 0.35, 0.2, 0.0, d, 1.4)
			clumps(pj, wave.global_position + Vector3.UP * 0.6, 8, 3.5, 0.17, d * 3.0)
			var t2 = wave.create_tween()
			t2.tween_property(wave, "scale", Vector3(1.2, 0.05, 1.1), 0.3).set_ease(Tween.EASE_IN)
			t2.tween_callback(wave.queue_free)
		if cc != null and cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		# çamur izi: 4 sn, basan yavaşlar
		var slow = func(_i, _k):
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			for q in trail:
				for e in pj.enemies_near(c2, q, 1.2):
					pj.st(e, "slow", 0.5)
		pj.every(4.0, 0.3, slow)
	pj.every(0.75, 1.0 / 60.0, tick, done)


## Nendo Kyoken — rakibin yanında çamur kabarır, içinden damlaya damlaya dev bir kol kalkar; havada kuruyup kile döner,
## yumruğu iner, yer çatlar, kil parçaları halka halinde savrulur; kol sonra parça parça dağılır
static func nendo_kyoken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "deiton_nendo_kyoken"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.4)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var sd = d.cross(Vector3.UP).normalized()
	var base: Vector3 = pj.gp(at + sd * 2.6 + d * 0.6)
	well_up(pj, base, 2.0, 9)   # hazırlık: kolun çıkacağı yer kabarır
	var arm = Node3D.new()
	var sdv = randf() * 10.0
	arm.add_child(_mi(tube_mesh([Vector3(0, -0.6, 0), Vector3(0.05, 1.2, 0.0), Vector3(-0.05, 2.6, -0.05), Vector3(0, 3.7, 0)], [0.9, 0.74, 0.66, 0.62], 12, 0.2, sdv, 0.3), 0.0, 0.2, 0.0, 1.0, true))   # ön kol
	var fist = _mi(lump_mesh(0, 0.2), 0.0, 0.2, 0.0, 1.0, true)
	fist.position = Vector3(0, 4.45, 0)
	fist.scale = Vector3(1.05, 0.8, 0.72)
	arm.add_child(fist)
	for f in 4:   # avuca kıvrılmış kalın parmaklar: boğumları hedefe (yerel -Z) bakar
		var x = (f - 1.5) * 0.42
		var fy = 4.75 - absf(f - 1.5) * 0.06
		var pts = [Vector3(x, fy + 0.05, -0.05), Vector3(x, fy + 0.2, -0.5), Vector3(x, fy - 0.08, -0.82), Vector3(x, fy - 0.45, -0.72), Vector3(x * 0.95, fy - 0.6, -0.4)]
		arm.add_child(_mi(tube_mesh(pts, [0.22, 0.23, 0.22, 0.2, 0.17], 8, 0.12, sdv + f, 0.6), 0.0, 0.2, 0.0, 1.0))
	var wrist = _mi(lump_mesh(3, 0.25), 0.0, 0.2, 0.0, 1.0)   # bilek kabarıklığı
	wrist.position = Vector3(0, 3.75, 0)
	wrist.scale = Vector3(0.72, 0.45, 0.66)
	arm.add_child(wrist)
	for q in 4:   # kolun altından sarkan kalın damlalar (kuruyunca kalır)
		var dr = _mi(lump_mesh(randi() % 6, 0.15), 0.0, 0.2, 0.0, 2.0)
		dr.position = Vector3(randf_range(-0.5, 0.5), randf_range(1.0, 3.4), randf_range(0.45, 0.6))
		dr.scale = Vector3(0.13, randf_range(0.25, 0.45), 0.13)
		arm.add_child(dr)
	arm.add_child(_mi(tube_mesh([Vector3(-0.75, 4.1, -0.2), Vector3(-0.95, 4.5, -0.45), Vector3(-0.7, 4.75, -0.7)], [0.26, 0.22, 0.16], 8, 0.15, sdv + 3.0, 0.8), 0.0, 0.2, 0.0, 1.0))   # başparmak
	var mound = _mi(lump_mesh(4, 0.3, 0.8), 0.0, 0.4, 0.0, 1.0)   # yerden kabaran taban
	mound.position = Vector3(0, 0.1, 0)
	mound.scale = Vector3(1.25, 0.38, 1.25)
	arm.add_child(mound)
	fold(arm, 0.6)
	pj.scene_add(arm, base - Vector3.UP * 5.0)
	arm.global_basis = Basis.looking_at(-sd, Vector3.UP)
	pj.free_after(2.2, arm)
	var at2 = arm.create_tween()
	at2.tween_property(arm, "global_position", base, 0.35).set_ease(Tween.EASE_OUT)
	at2.tween_callback(func(): harden_all(arm, 0.18))   # havada kurur
	at2.tween_interval(0.15)
	at2.tween_property(arm, "rotation:x", deg_to_rad(-95.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # yumruk iner
	at2.tween_interval(0.6)
	at2.tween_callback(func():   # parça parça dağılır
		if not is_instance_valid(arm):
			return
		for q in 12:
			var lp = Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 4.8), randf_range(-0.6, 0.6))
			chunk(pj, arm.global_transform * lp, Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.5), randf_range(-1.5, 1.5)), randf_range(0.25, 0.5)))
	at2.tween_property(arm, "scale", Vector3(0.8, 0.02, 0.8), 0.3).set_ease(Tween.EASE_IN)
	at2.tween_callback(arm.queue_free)
	splat(pj, base, 2.2, 2.0, 0.4, 0.4)
	clumps(pj, base + Vector3.UP, 10, 4.5, 0.18)
	var rise_drip = func(_i, _k):
		if is_instance_valid(arm):
			drip(pj, base + sd * randf_range(-0.7, 0.7) + d * randf_range(-0.7, 0.7) + Vector3.UP * randf_range(1.0, 4.0), randf_range(0.09, 0.15), 1.5)
	pj.every(0.45, 0.05, rise_drip)
	Sfx.play("earth", base, 0.6)
	var slam = func():
		var cc = cw.get_ref()
		var hitp: Vector3 = at
		chunks(pj, hitp + Vector3.UP * 0.3, 18, 10.0, 0.32)
		ground_cracks(pj, hitp, 3.5, 8, Color(0.12, 0.09, 0.07), 3.0)
		for q in 12:   # yumruğun çevresinden halka halinde savrulan kil
			var a = q * TAU / 12.0
			var dv = Vector3(cos(a), 0, sin(a))
			chunk(pj, pj.gp(hitp + dv * 1.2) + Vector3.UP * 0.15, dv * randf_range(6.0, 8.0) + Vector3.UP * randf_range(1.5, 2.5), randf_range(0.18, 0.3))
		Sfx.play("boom", hitp, 0.6)
		pj.shake(0.6)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, hitp, 2.8):
			e.take_hit(pj.inf(cc, id, 2.0, {"knock": 4.0, "launch": -6.0, "kind": "heavy", "element": "deiton", "stun": 1.2, "hitstop": 0.12, "pierce_guard": true}))
	pj.after(0.72, slam)


## Doro Yoroi — bedeni topak topak ıslak çamur kaplar, damlar; hızla kuruyup çatlak desenli mat kil zırha döner.
## Süre bitince zırh dışa doğru kil parçaları halinde patlar
static func doro_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "deiton_doro_yoroi"
	pj.anim(c, "crouch", 1.2)
	var DUR = 7.0
	well_up(pj, c.global_position, 1.0, 6)
	gather(pj, c.global_position + Vector3.UP * 1.1, c.global_position, 10, 0.35, 1.2)
	var parts = []
	var bs = ClanJutsu.body_scale(c)
	for bone in ["Chest", "Hips", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			continue
		var holder = Node3D.new()
		ba.add_child(holder)
		var big = bone in ["Chest", "Hips"]
		for q in (3 if big else 2):   # topak topak, düz kabuk değil
			var mi = _mi(lump_mesh(randi() % 6, 0.3), 0.0, 0.2, 0.0, 1.5, true)
			mi.position = Vector3(randf_range(-0.05, 0.05), 0.08 + q * (0.12 if big else 0.1), randf_range(-0.04, 0.06)) * bs
			mi.scale = (Vector3(0.27, 0.15, 0.21) if big else Vector3(0.14, 0.15, 0.14)) * bs
			holder.add_child(mi)
			harden(mi, 0.4, 1.2)   # kurur
		holder.scale = Vector3.ONE * 0.1
		var tw = holder.create_tween()
		tw.tween_property(holder, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		parts.append(weakref(holder))
		pj.free_after(DUR, ba)
	var cwd = weakref(c)
	var wet_drip = func(_i, _k):   # kurumadan önce damlar
		var x = cwd.get_ref()
		if x != null and is_instance_valid(x):
			var a = randf() * TAU
			drip(pj, x.global_position + Vector3(cos(a) * 0.3, randf_range(0.4, 1.4), sin(a) * 0.3), randf_range(0.06, 0.1), 1.4)
	pj.every(1.2, 0.08, wet_drip)
	splat(pj, c.global_position, 1.0, 2.5, 0.4, 0.2)
	Sfx.play("water", c.global_position, 0.6)
	var mods = {"armor": 0.45, "speed": 0.85, "_name": "Doro Yoroi", "_desc": "kil zırh: darbeleri yutar, ağırdır"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	var cw = weakref(c)
	var crack_off = func():   # çatlayıp patlar
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p: Vector3 = cc.global_position + Vector3.UP * 1.0
		for q in 24:
			var a = randf() * TAU
			var dv = Vector3(cos(a), 0, sin(a))
			chunk(pj, p + dv * 0.3 + Vector3.UP * randf_range(-0.7, 0.6), dv * randf_range(4.0, 9.0) + Vector3.UP * randf_range(1.0, 4.0), randf_range(0.14, 0.3))
		Sfx.play("earth", p, 1.1)
		for e in pj.enemies_near(cc, cc.global_position, 3.5):
			var v: Vector3 = e.global_position - cc.global_position
			v.y = 0
			e.take_hit(pj.inf(cc, id, 0.8, {"knock": 9.0, "launch": 2.0, "kind": "heavy", "bleed": 1.5, "element": "deiton", "hitstop": 0.05, "dir": v.normalized() if v.length() > 0.1 else cc.face_dir()}))
	pj.after(DUR, crack_off)
