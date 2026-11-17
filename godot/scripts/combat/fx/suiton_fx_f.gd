class_name SuitonFXF
extends RefCounted
## Suiton grubu F (son grup): on sekiz su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (su gölgelendiricisi, damla, birikinti, taç, sis, kabarcık). Bu dosyanın kendi parçaları: gerçek boyda kurulan köpekbalığı
## (sırt / göğüs yüzgeci, hilal kuyruk, solungaç yarıkları, göz, açılan alt çene, diş dizileri), su ejderi başı + izleyen
## yılan gövdesi, kıvrık girdaplı Tate Eboshi kubbesi, ayna diski, kıvrılan dalga duvarı, hortum bantları, kan → su akışı,
## su altı kubbesi (dünya uzayında ışık ağı), köpekbalığı derisi katmanı.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağacın işleyicilerinden satır satır taşındı.
## Büyük su kütleleri gerçek boyda kurulur (küçük mesh büyütülmez); kameraya yakın kısımlar incelir.

const L = preload("res://scripts/combat/fx/lib/suiton_lib.gd")

static var _cache := {}

## köpekbalığı gövde yarıçapı / boy (u: burun 0 → kuyruk sapı 1)
const SK_R := [[0.0, 0.0], [0.025, 0.04], [0.07, 0.07], [0.15, 0.097], [0.27, 0.116], [0.41, 0.114], [0.55, 0.096], [0.69, 0.068], [0.82, 0.04], [0.92, 0.026], [1.0, 0.02]]

# ------------------------------------------------------------------ gölgelendiriciler (bu gruba özgü)
## Tate Eboshi: soluk, yarı saydam su kütlesi; yüzeyde yavaşça yukarı akan, ucu kıvrık ak girdap çizgileri
const EBOSHI_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	vec3 base = mix(vec3(0.82, 0.89, 0.94), vec3(0.6, 0.73, 0.86), smoothstep(0.25, 0.95, fr));
	vec2 uv = vec2(UV.x * 16.0, UV.y * 7.0 - TIME * 0.22);
	vec2 cell = floor(uv);
	float rnd = h21(cell + vec2(seed, seed * 0.37));
	vec2 q = fract(uv) - 0.5 + (vec2(h21(cell + vec2(3.1, 0.0)), h21(cell + vec2(0.0, 7.7))) - 0.5) * 0.22;
	float r = length(q);
	float a = atan(q.y, q.x) / 6.2832 + 0.5;
	float sp = abs(fract(r * 5.5 - a * sign(rnd - 0.5) + rnd) - 0.5);
	float curl = step(sp, 0.085) * step(0.06, r) * step(r, 0.4) * step(0.24, fract(a + rnd)) * step(0.22, rnd);
	vec3 col = mix(base, vec3(0.97, 0.99, 1.0), curl);
	float rim = step(0.9, fr);
	col = mix(col, vec3(0.3, 0.44, 0.62), rim);
	ALBEDO = pow(col, vec3(2.2));
	float al = 0.4 + 0.3 * smoothstep(0.3, 1.0, fr) + curl * 0.45 + rim * 0.4;
	al *= smoothstep(1.5, 7.5, -VERTEX.z);
	ALPHA = clamp(al, 0.0, 1.0) * fade;
}
"""

## Mizukagami: dik su aynası — gök yansıması, dışa yayılan halka dalgacıkları, çapraz parıltı, koyu su kenarı
const MIRROR_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	vec3 sky = mix(vec3(0.8, 0.91, 0.98), vec3(0.4, 0.6, 0.82), clamp(q.y * 0.5 + 0.5, 0.0, 1.0));
	float rip = step(0.84, sin(r * 22.0 - TIME * 3.0 + sin(q.x * 3.0 + TIME + seed) * 0.6));
	vec3 col = mix(sky, vec3(0.95, 0.98, 1.0), rip * 0.5);
	float g1 = step(abs(q.x + q.y * 0.6 - 0.35 + sin(TIME * 0.7) * 0.1), 0.06);
	float g2 = step(abs(q.x + q.y * 0.6 - 0.12), 0.025);
	col = mix(col, vec3(1.0), clamp(g1 + g2, 0.0, 1.0) * 0.8);
	float edge = smoothstep(0.86, 0.9, r);
	col = mix(col, vec3(0.18, 0.4, 0.7), edge);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(0.7 + rip * 0.15 + edge * 0.25, 0.0, 1.0) * fade * smoothstep(0.6, 2.0, -VERTEX.z);
}
"""

## Suirō Sameodori kubbesi: derin mavi su; dünya uzayında kayan ışık ağı (kostik), içeriden bakınca çok ince
const DOME_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

instance uniform float fade = 1.0;
varying vec3 wp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - clamp(abs(dot(n, VIEW)), 0.0, 1.0);
	float cn = abs(vn(wp.xz * 0.4 + vec2(wp.y * 0.1 + TIME * 0.35, 0.0)) - vn(wp.zx * 0.4 + vec2(5.0, TIME * 0.3)));
	float caus = step(cn, 0.045);
	vec3 col = mix(vec3(0.05, 0.3, 0.62), vec3(0.16, 0.52, 0.86), fr);
	col = mix(col, vec3(0.75, 0.95, 1.0), caus * 0.7);
	float rim = step(0.94, fr);
	col = mix(col, vec3(0.02, 0.1, 0.3), rim);
	float a = FRONT_FACING ? (0.3 + fr * 0.4) : 0.14;
	a = max(a, caus * (FRONT_FACING ? 0.6 : 0.28));
	a = max(a, rim * 0.8);
	a *= smoothstep(1.0, 7.0, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
"""

## Ketsueki Henkan: kan akışı; conv eşiğinden sonrası (ele yakın taraf, UV.y) berrak suya döner
const BLOOD_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float conv = 2.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	float w = smoothstep(conv - 0.12, conv + 0.12, UV.y);
	float lit = step(0.4, 1.0 - fr);
	vec3 red = mix(vec3(0.5, 0.02, 0.05), vec3(0.82, 0.1, 0.13), lit);
	vec3 blu = mix(vec3(0.16, 0.56, 0.93), vec3(0.52, 0.88, 1.0), lit);
	vec3 col = mix(red, blu, w);
	float sv = vn(vec2(UV.x * 8.0 + seed, UV.y * 10.0 - TIME * 6.0));
	float stk = step(0.78, sv) * step(fr, 0.7);
	col = mix(col, mix(vec3(1.0, 0.55, 0.55), vec3(0.95, 0.99, 1.0), w), stk * 0.8);
	float rim = step(0.88, fr);
	col = mix(col, mix(vec3(0.2, 0.0, 0.02), vec3(0.03, 0.14, 0.4), w), rim);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(0.88 + rim * 0.12, 0.0, 1.0) * fade * smoothstep(0.4, 1.6, -VERTEX.z);
}
"""

## Bedene geçen su katmanı (erime / yansıma klonu): aşağı akan ak bantlar, fresnel kenar
const SKINW_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

uniform float strength = 0.6;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float fr = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float s = step(0.8, fract(lp.y * 6.0 + TIME * 1.5 + sin(lp.x * 9.0 + TIME) * 0.15));
	vec3 col = mix(vec3(0.3, 0.62, 0.95), vec3(0.85, 0.96, 1.0), max(s * 0.8, step(0.6, fr)));
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(0.35 + fr * 0.5 + s * 0.3, 0.0, 1.0) * strength;
}
"""

## Samehada Yūgō derisi: bel üstünde gri-mavi ten + koyu, dalgalı köpekbalığı çizgileri (modelin yerel uzayında)
const SHARKSKIN_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float up = smoothstep(0.95, 1.05, lp.y);
	float band = step(0.55, sin(lp.y * 26.0 + sin(lp.x * 7.0 + lp.z * 5.0) * 1.4));
	vec3 col = mix(vec3(0.47, 0.56, 0.66), vec3(0.2, 0.25, 0.34), band);
	float fr = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	col = mix(col, vec3(0.12, 0.15, 0.22), step(0.88, fr));
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = up * (0.55 + band * 0.35);
}
"""


# ------------------------------------------------------------------ küçük yardımcılar
static func _c(key: String, build: Callable):
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT


static func _flat(v: Vector3) -> Vector3:
	var f = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


static func _aim(n: Node3D, d: Vector3) -> void:
	if d.length() > 0.001:
		n.look_at(n.global_position + d, _up_for(d))


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _cmat(key: String, col: Color, add := false, toon := false) -> StandardMaterial3D:
	return _c("mat:" + key, func():
		var m = StandardMaterial3D.new()
		m.albedo_color = col
		if toon:
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON
			m.roughness = 0.8
		else:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_receive_shadows = true
		if col.a < 0.999 or add:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func _smat(key: String, code: String) -> ShaderMaterial:
	return _c("shd:" + key, func():
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		return m)


static func _skinw_mat(strength: float) -> ShaderMaterial:
	return _c("shd:skinw_%d" % int(strength * 100.0), func():
		var sh = Shader.new()
		sh.code = SKINW_SHADER
		var m = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("strength", strength)
		return m)


## Tüm alt geometrileri söndürür (gölgelendirici: fade; düz malzeme: saydamlık)
static func _fade_all(n: Node, v: float) -> void:
	if not is_instance_valid(n):
		return
	var list = n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		list.append(n)
	for g0 in list:
		var g = g0 as GeometryInstance3D
		if g.material_override is ShaderMaterial:
			g.set_instance_shader_parameter("fade", v)
		else:
			g.transparency = 1.0 - v


static func _fade_out(n: Node3D, delay: float, t: float, sc := Vector3.ONE) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): _fade_all(n, v), 1.0, 0.0, t)
	if sc != Vector3.ONE:
		tw.parallel().tween_property(n, "scale", n.scale * sc, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## Yerel -Z boyunca açılma (gerilmeden uzayan akış / sütun)
static func _reveal(gi: GeometryInstance3D, ln: float, t: float, delay := 0.0) -> void:
	gi.set_instance_shader_parameter("reveal_d", 0.0)
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("reveal_d", v), 0.0, ln + 0.8, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Dünya noktalarından geçen su tüpü: yerel çerçeve ilk noktada, -Z son noktaya bakar (reveal ile açılabilir)
static func _path_node(h: Node, pts: Array, radii: Array, o := {}) -> MeshInstance3D:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[pts.size() - 1]
	var d = b - a
	if d.length() < 0.01:
		d = Vector3.FORWARD
	var bas = Basis.looking_at(d.normalized(), _up_for(d))
	var inv = bas.inverse()
	var lp = []
	for p0 in pts:
		var pv: Vector3 = p0
		lp.append(inv * (pv - a))
	var n0w: Vector3 = o.get("n0", Vector3.ZERO)
	var mesh = L.tube_mesh(lp, radii, int(o.get("sides", 10)), float(o.get("flat", 1.0)), (inv * n0w) if n0w != Vector3.ZERO else Vector3.ZERO)
	var mi = L.wmi(mesh, o)
	L.put(h, mi, a)
	mi.global_basis = bas
	return mi


## İki nokta arasında kavisli yol (yan şişkinlik + yukarı kemer)
static func _arc_pts(a: Vector3, b: Vector3, n: int, side: float, lift: float) -> Array:
	var sd = (b - a).cross(Vector3.UP)
	sd = sd.normalized() if sd.length() > 0.01 else Vector3.RIGHT
	var out = []
	for i in n:
		var u = float(i) / (n - 1)
		out.append(a.lerp(b, u) + sd * sin(u * PI) * side + Vector3.UP * sin(u * PI) * lift)
	return out


## Toprak / çakıl parçaları (kendi kutu parçacıkları)
static func _dirt(h: Node, pos: Vector3, dir: Vector3, n: int, sp := 6.0) -> void:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = dir.normalized()
	pm.spread = 50.0
	pm.initial_velocity_min = sp * 0.5
	pm.initial_velocity_max = sp
	pm.gravity = Vector3(0, -16, 0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	p.process_material = pm
	p.draw_pass_1 = _c("mesh:pebble", func():
		var bm = BoxMesh.new()
		bm.size = Vector3(0.12, 0.09, 0.1)
		return bm)
	p.material_override = _cmat("dirt", Color(0.42, 0.34, 0.24), false, true)
	p.amount = maxi(1, n)
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.put(h, p, pos)
	p.emitting = true
	L.free_later(h, p, 1.6)


## Zaman yavaşlatma (eski işleyicideki yavaş an, aynı kural: zaten yavaşsa dokunmaz)
static func _slowmo(h: Node, s: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = s
	Engine.time_scale = s
	h.get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if absf(Combat.base_time_scale - s) < 0.001:
			Combat.base_time_scale = 1.0)


## Sinematik an: oyuncu kamerası kısa süre geri çekilir (eski işleyicideki kamera kuralı)
static func _cine(c: Node3D, extra: float, hold: float) -> void:
	if not "cam_dist" in c or c.has_meta("cine"):
		return
	var base: float = c.cam_dist
	c.set_meta("cine", true)
	var tw = c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "cam_dist", base + extra, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(c, "cam_dist", base, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): c.remove_meta("cine"))


## Bedeni dur sn su katmanıyla kaplar (yalnız görünüş)
static func _water_skin(h: Node, c: Node3D, dur: float, strength := 0.6) -> void:
	var mm = c.get("model")
	if mm == null or not is_instance_valid(mm):
		return
	var wm = _skinw_mat(strength)
	var meshes = mm.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = wm
	h.get_tree().create_timer(dur).timeout.connect(func():
		for mi in meshes:
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == wm:
				(mi as MeshInstance3D).material_overlay = null)


# ------------------------------------------------------------------ meshler (gerçek boy)
## Yarım elipsoit kubbe (taban yerde, W yan, H boy, D derinlik), UV: x açı, y enlem
static func _dome_mesh(w: float, hgt: float, dp: float) -> ArrayMesh:
	return _c("mesh:dome_%d_%d_%d" % [int(w * 10.0), int(hgt * 10.0), int(dp * 10.0)], func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 48
		var rings = 20
		for j in rings + 1:
			var la = float(j) / rings * PI * 0.5
			for s in segs + 1:
				var a = float(s) / segs * TAU
				var x = cos(la) * sin(a)
				var y = sin(la)
				var z = cos(la) * cos(a)
				var wob = 1.0 + 0.035 * sin(a * 5.0 + la * 3.0) * cos(la)
				sf.set_normal(Vector3(x / w, y / hgt, z / dp).normalized())
				sf.set_uv(Vector2(float(s) / segs, float(j) / rings))
				sf.add_vertex(Vector3(x * w * wob, y * hgt, z * dp * wob))
		for j in rings:
			for s in segs:
				var a0 = j * (segs + 1) + s
				var b0 = a0 + segs + 1
				sf.add_index(a0)
				sf.add_index(b0)
				sf.add_index(a0 + 1)
				sf.add_index(a0 + 1)
				sf.add_index(b0)
				sf.add_index(b0 + 1)
		return sf.commit())


## Tam elipsoit (rx, ry, rz) — gürültüyle kabarık yüzey (jag), UV: x açı, y enlem
static func _blob_mesh(rx: float, ry: float, rz: float, jag: float, variant: int) -> ArrayMesh:
	return _c("mesh:blob_%d_%d_%d_%d_%d" % [int(rx * 10.0), int(ry * 10.0), int(rz * 10.0), int(jag * 100.0), variant], func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 5113 + variant * 733
		var ph = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 36
		var rings = 20
		for j in rings + 1:
			var la = -PI * 0.5 + float(j) / rings * PI
			for s in segs + 1:
				var a = float(s) / segs * TAU
				var k = 1.0 + jag * (sin(a * 3.0 + ph[0]) * cos(la * 2.0 + ph[1]) * 0.6 + sin(a * 5.0 + la * 4.0 + ph[2]) * 0.4)
				sf.set_uv(Vector2(float(s) / segs, float(j) / rings))
				sf.add_vertex(Vector3(cos(la) * sin(a) * rx * k, sin(la) * ry * k, cos(la) * cos(a) * rz * k))
		for j in rings:
			for s in segs:
				var a0 = j * (segs + 1) + s
				var b0 = a0 + segs + 1
				sf.add_index(a0)
				sf.add_index(b0)
				sf.add_index(a0 + 1)
				sf.add_index(a0 + 1)
				sf.add_index(b0)
				sf.add_index(b0 + 1)
		sf.generate_normals()
		return sf.commit())


## Hortum bandı: kalın, yassı, kenarı dalgalı halka (eliptik kesitli simit), UV.y açı boyunca → akış çizgileri döner
static func _band_mesh(rc: float, ra: float, rb: float, variant: int) -> ArrayMesh:
	return _c("mesh:band_%d_%d_%d_%d" % [int(rc * 10.0), int(ra * 10.0), int(rb * 10.0), variant], func():
		var ph = float(variant) * 1.7
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nt = 14
		var segs = 40
		for j in nt + 1:
			var tt = float(j) / nt * TAU
			for s in segs + 1:
				var a = float(s) / segs * TAU
				var wv = 1.0 + 0.13 * sin(a * 3.0 + ph) + 0.06 * sin(a * 7.0 + ph * 2.0)
				var rr = (rc + ra * cos(tt) * wv)
				sf.set_uv(Vector2(float(j) / nt, float(s) / segs))
				sf.add_vertex(Vector3(cos(a) * rr, rb * sin(tt) * (1.0 + 0.2 * sin(a * 2.0 + ph)), sin(a) * rr))
		for j in nt:
			for s in segs:
				var v00 = j * (segs + 1) + s
				var v01 = v00 + 1
				var v10 = v00 + segs + 1
				var v11 = v10 + 1
				sf.add_index(v00)
				sf.add_index(v01)
				sf.add_index(v10)
				sf.add_index(v01)
				sf.add_index(v11)
				sf.add_index(v10)
		sf.generate_normals()
		return sf.commit())


## Kıvrılan dalga duvarı: kesit X boyunca w genişlikte süpürülür (-Z ileri). Uçlarda alçalır, tepe hafif dişli.
static func _wave_mesh(w: float, hgt: float) -> ArrayMesh:
	return _c("mesh:wave_%d_%d" % [int(w * 10.0), int(hgt * 10.0)], func():
		# (z, y/hgt): arka yamaç → tepe → öne kıvrılan dudak → dudağın altı → ön yüz → yer
		var prof = [Vector2(4.5, 0.0), Vector2(3.2, 0.25), Vector2(1.8, 0.62), Vector2(0.6, 0.92), Vector2(-0.4, 1.0), Vector2(-1.3, 0.93),
			Vector2(-1.9, 0.74), Vector2(-2.0, 0.56), Vector2(-1.6, 0.48), Vector2(-1.05, 0.5), Vector2(-0.8, 0.32), Vector2(-0.95, 0.0)]
		var nx = 56
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var np = prof.size()
		for i in np:
			var pr: Vector2 = prof[i]
			for k in nx + 1:
				var x = -w * 0.5 + w * float(k) / nx
				var ef = clampf(minf(x + w * 0.5, w * 0.5 - x) / 3.5, 0.0, 1.0)
				ef = ef * ef * (3.0 - 2.0 * ef)
				var jag = 1.0 + 0.08 * sin(x * 0.9) + 0.05 * sin(x * 2.3 + 1.0)
				sf.set_uv(Vector2(float(k) / nx * w * 0.08, float(i) / (np - 1)))
				sf.add_vertex(Vector3(x, pr.y * hgt * ef * jag, pr.x * (0.35 + 0.65 * ef)))
		for i in np - 1:
			for k in nx:
				var v00 = i * (nx + 1) + k
				var v01 = v00 + 1
				var v10 = v00 + nx + 1
				var v11 = v10 + 1
				sf.add_index(v00)
				sf.add_index(v10)
				sf.add_index(v01)
				sf.add_index(v10)
				sf.add_index(v11)
				sf.add_index(v01)
		sf.generate_normals()
		return sf.commit())


## Düz disk (XY düzlemi, +Z'ye bakar), UV = konum
static func _disc_mesh(r: float) -> ArrayMesh:
	return _c("mesh:disc_%d" % int(r * 10.0), func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 40
		sf.set_normal(Vector3.BACK)
		sf.set_uv(Vector2(0.5, 0.5))
		sf.add_vertex(Vector3.ZERO)
		for s in segs:
			var a = float(s) / segs * TAU
			sf.set_normal(Vector3.BACK)
			sf.set_uv(Vector2(cos(a) * 0.5 + 0.5, sin(a) * 0.5 + 0.5))
			sf.add_vertex(Vector3(cos(a) * r, sin(a) * r, 0.0))
		for s in segs:
			sf.add_index(0)
			sf.add_index(1 + (s + 1) % segs)
			sf.add_index(1 + s)
		return sf.commit())


## Dikenli düz su yıldızı (XY, +Z'ye bakar): referans isabet sıçraması
static func _star_splat_mesh(variant: int) -> ArrayMesh:
	return _c("mesh:splat_%d" % variant, func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 881 + variant * 397
		var n = 26
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		sf.set_normal(Vector3.BACK)
		sf.set_uv(Vector2(0.5, 0.5))
		sf.add_vertex(Vector3.ZERO)
		for k in n:
			var a = float(k) / n * TAU + rng.randf_range(-0.06, 0.06)
			var r = rng.randf_range(0.75, 1.0) if k % 2 == 0 else rng.randf_range(0.36, 0.5)
			if k % 2 == 0 and rng.randf() < 0.3:
				r *= 1.35
			sf.set_normal(Vector3.BACK)
			sf.set_uv(Vector2(cos(a) * r * 0.5 + 0.5, sin(a) * r * 0.5 + 0.5))
			sf.add_vertex(Vector3(cos(a) * r, sin(a) * r, 0.0))
		for k in n:
			sf.add_index(0)
			sf.add_index(1 + (k + 1) % n)
			sf.add_index(1 + k)
		return sf.commit())


## Su pulu: yatay, dışbükey yüzü öne (-Z) bakan ince hilal bıçak
static func _scale_blade_mesh() -> ArrayMesh:
	return _c("mesh:scale_blade", func():
		var pts = []
		var rad = []
		for i in 11:
			var u = float(i) / 10.0
			var a = lerpf(-1.25, 1.25, u)
			pts.append(Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5 + 0.32))
			rad.append(0.085 * pow(sin(u * PI), 0.7) + 0.004)
		return L.tube_mesh(pts, rad, 6, 0.22, Vector3.FORWARD))


## Ağızdan uzanan kısa mermi tanesi (yuvarlak burun, damla kuyruk)
static func _pellet_mesh() -> ArrayMesh:
	return _c("mesh:pellet", func():
		var pts = []
		var rad = []
		var prof = [[-0.12, 0.0], [-0.09, 0.06], [-0.03, 0.075], [0.06, 0.07], [0.2, 0.05], [0.38, 0.025], [0.55, 0.0]]
		for pr in prof:
			pts.append(Vector3(0, 0, float(pr[0])))
			rad.append(float(pr[1]))
		return L.tube_mesh(pts, rad, 8))


## Yatay su sırtı parçası (X boyunca ln uzun, alçak) — deniz dalgası halkasının bir dilimi
static func _crest_seg_mesh(ln: float, r: float) -> ArrayMesh:
	return _c("mesh:crest_%d_%d" % [int(ln * 10.0), int(r * 100.0)], func():
		var pts = []
		var rad = []
		for i in 9:
			var u = float(i) / 8.0
			pts.append(Vector3(-ln * 0.5 + ln * u, 0.0, -sin(u * PI) * ln * 0.06))
			rad.append(r * (0.35 + 0.65 * pow(sin(u * PI), 0.5)))
		return L.tube_mesh(pts, rad, 8, 0.7, Vector3.UP))


## Kapalı halka tüpü (XY düzleminde, yarıçap r, kalınlık w)
static func _loop_mesh(r: float, w: float) -> ArrayMesh:
	return _c("mesh:loop_%d_%d" % [int(r * 100.0), int(w * 1000.0)], func():
		var pts = []
		var rad = []
		for i in 41:
			var a = float(i) / 40.0 * TAU
			pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
			rad.append(w * (1.0 + 0.25 * sin(a * 5.0)))
		return L.tube_mesh(pts, rad, 8))


# ------------------------------------------------------------------ köpekbalığı (gerçek boy, -Z burun)
static func _sk_r(u: float) -> float:
	for i in SK_R.size() - 1:
		var a = SK_R[i]
		var b = SK_R[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return 0.02


static func _shark_meshes(ln: float) -> Dictionary:
	return _c("mesh:shark_%d" % int(ln * 20.0), func():
		var out = {}
		# gövde: burnu hafif yukarı kalkık, yanları basık iğ
		var pts = []
		var rad = []
		for pr in SK_R:
			var u = float(pr[0])
			pts.append(Vector3(0, ln * 0.03 * pow(1.0 - u, 4.0), -ln * 0.5 + u * ln))
			rad.append(float(pr[1]) * ln)
		out["body"] = L.tube_mesh(pts, rad, 14, 0.78, Vector3.UP)
		# yüzgeçler: sırt (büyük + küçük), göğüs (iki yan), karın
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		vc = L.tube_into(sf, vc, [Vector3(0, 0.1 * ln, -0.14 * ln), Vector3(0, 0.19 * ln, -0.05 * ln), Vector3(0, 0.27 * ln, 0.05 * ln), Vector3(0, 0.3 * ln, 0.1 * ln)],
			[0.075 * ln, 0.045 * ln, 0.018 * ln, 0.003 * ln], 6, 0.16, Vector3.BACK)
		vc = L.tube_into(sf, vc, [Vector3(0, 0.05 * ln, 0.24 * ln), Vector3(0, 0.085 * ln, 0.28 * ln), Vector3(0, 0.1 * ln, 0.31 * ln)],
			[0.025 * ln, 0.012 * ln, 0.002 * ln], 5, 0.18, Vector3.BACK)
		for sx in [-1.0, 1.0]:
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.07 * ln, -0.05 * ln, -0.2 * ln), Vector3(sx * 0.18 * ln, -0.1 * ln, -0.12 * ln), Vector3(sx * 0.28 * ln, -0.15 * ln, -0.02 * ln), Vector3(sx * 0.31 * ln, -0.165 * ln, 0.02 * ln)],
				[0.055 * ln, 0.04 * ln, 0.014 * ln, 0.002 * ln], 6, 0.18, Vector3.BACK)
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.03 * ln, -0.07 * ln, 0.18 * ln), Vector3(sx * 0.07 * ln, -0.11 * ln, 0.23 * ln)],
				[0.02 * ln, 0.002 * ln], 5, 0.2, Vector3.BACK)
		sf.generate_normals()
		out["fins"] = sf.commit()
		# hilal kuyruk (kuyruk sapında döner): uzun üst lob, kısa alt lob
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tc = 0
		tc = L.tube_into(st, tc, [Vector3(0, 0, -0.03 * ln), Vector3(0, 0.1 * ln, 0.07 * ln), Vector3(0, 0.2 * ln, 0.16 * ln), Vector3(0, 0.26 * ln, 0.22 * ln)],
			[0.04 * ln, 0.03 * ln, 0.015 * ln, 0.002 * ln], 6, 0.15, Vector3.BACK)
		tc = L.tube_into(st, tc, [Vector3(0, 0, -0.03 * ln), Vector3(0, -0.07 * ln, 0.06 * ln), Vector3(0, -0.13 * ln, 0.12 * ln), Vector3(0, -0.15 * ln, 0.15 * ln)],
			[0.035 * ln, 0.025 * ln, 0.01 * ln, 0.002 * ln], 6, 0.15, Vector3.BACK)
		st.generate_normals()
		out["tail"] = st.commit()
		# alt çene (menteşede döner)
		out["jaw"] = L.tube_mesh([Vector3(0, 0, 0), Vector3(0, -0.012 * ln, -0.07 * ln), Vector3(0, -0.004 * ln, -0.13 * ln), Vector3(0, 0.004 * ln, -0.16 * ln)],
			[0.062 * ln, 0.05 * ln, 0.03 * ln, 0.008 * ln], 10, 0.45, Vector3.RIGHT)
		# dişler: üst sıra (gövdede), alt sıra (çenede) — ak, sivri
		var ub = MB.new()
		for q in 11:
			var ang = (q - 5) * 0.27
			var tp = Vector3(sin(ang) * 0.06 * ln, -0.07 * ln, -0.36 * ln + absf(q - 5) * 0.012 * ln)
			ub.add("cone", tp, Vector3(0.016, 0.04, 0.016) * ln, Color.WHITE, Vector3(180, 0, 0), 4)
		out["uteeth"] = ub.build(_cmat("tooth", Color(0.97, 0.98, 1.0)))
		var lb = MB.new()
		for q in 9:
			var ang2 = (q - 4) * 0.3
			var tp2 = Vector3(sin(ang2) * 0.045 * ln, 0.01 * ln, -0.12 * ln + absf(q - 4) * 0.012 * ln)
			lb.add("cone", tp2, Vector3(0.014, 0.034, 0.014) * ln, Color.WHITE, Vector3.ZERO, 4)
		out["lteeth"] = lb.build(_cmat("tooth", Color(0.97, 0.98, 1.0)))
		# solungaç yarıkları, göz, ağız içi (koyu)
		var gb = MB.new()
		for sx in [-1.0, 1.0]:
			var rr = _sk_r(0.25) * ln
			for g in 5:
				var z = (-0.24 + g * 0.022) * ln
				gb.add("box", Vector3(sx * rr * 0.8, -0.005 * ln, z), Vector3(0.006 * ln, 0.075 * ln, 0.006 * ln), Color.WHITE, Vector3(0, 0, sx * 8.0), 4)
			gb.add("sphere", Vector3(sx * 0.055 * ln, 0.035 * ln, -0.36 * ln), Vector3(0.02, 0.022, 0.022) * ln, Color.WHITE, Vector3.ZERO, 8)
		out["dark"] = gb.build(_cmat("shark_dark", Color(0.03, 0.06, 0.14)))
		var mb = MB.new()
		mb.add("sphere", Vector3(0, -0.068 * ln, -0.3 * ln), Vector3(0.1, 0.05, 0.16) * ln, Color.WHITE, Vector3.ZERO, 12)
		out["maw"] = mb.build(_cmat("shark_maw", Color(0.14, 0.05, 0.1)))
		return out)


## Su köpekbalığı düğümü: o = pal, alpha, open (çene 0..1), wag (kuyruk sallanma hızı)
static func _shark(ln: float, o := {}) -> Node3D:
	var ms: Dictionary = _shark_meshes(ln)
	var wp = {"alpha": float(o.get("alpha", 0.86)), "line": 0.13, "pal": float(o.get("pal", L.WATER)), "flow": 2.0, "streak": 1.6, "foam": 0.06, "neard": 4.0}
	var root = Node3D.new()
	root.add_child(L.wmi(ms["body"], wp))
	root.add_child(L.wmi(ms["fins"], wp))
	root.add_child(_mi(ms["maw"], _cmat("shark_maw", Color(0.14, 0.05, 0.1))))
	root.add_child(_mi(ms["dark"], _cmat("shark_dark", Color(0.03, 0.06, 0.14))))
	root.add_child(_mi(ms["uteeth"], _cmat("tooth", Color(0.97, 0.98, 1.0))))
	var jaw = Node3D.new()
	jaw.position = Vector3(0, -0.062 * ln, -0.24 * ln)
	jaw.add_child(L.wmi(ms["jaw"], wp))
	jaw.add_child(_mi(ms["lteeth"], _cmat("tooth", Color(0.97, 0.98, 1.0))))
	jaw.rotation.x = -0.55 * float(o.get("open", 0.4))
	root.add_child(jaw)
	var tail = Node3D.new()
	tail.position = Vector3(0, 0, 0.5 * ln)
	tail.add_child(L.wmi(ms["tail"], wp))
	root.add_child(tail)
	root.set_meta("jaw", jaw)
	var wag = float(o.get("wag", 9.0))
	var body0: Node3D = root.get_child(0)
	var wagf = func(v: float):
		if is_instance_valid(tail):
			tail.rotation.y = sin(v) * 0.4
			body0.rotation.y = sin(v - 1.2) * 0.06
	root.tree_entered.connect(func():
		var tw = root.create_tween().set_loops()
		tw.tween_method(wagf, 0.0, TAU, TAU / wag), CONNECT_ONE_SHOT)
	return root


## Çeneyi kapat-aç (ısırık)
static func _shark_bite(sh: Node3D) -> void:
	if not is_instance_valid(sh) or not sh.has_meta("jaw"):
		return
	var jaw: Node3D = sh.get_meta("jaw")
	if not is_instance_valid(jaw):
		return
	var open0 = jaw.rotation.x
	var tw = jaw.create_tween()
	tw.tween_property(jaw, "rotation:x", -0.75, 0.08)
	tw.tween_property(jaw, "rotation:x", 0.05, 0.06).set_ease(Tween.EASE_IN)
	tw.tween_property(jaw, "rotation:x", open0, 0.3)


## Köpekbalığı dağılır: gövde boyunca su kopar, ön ucunda taç
static func _shark_pop(h: Node, p: Vector3, ln: float) -> void:
	L.spray(h, p, Vector3.UP, {"n": int(10 + ln * 6), "spread": 75.0, "vmin": 2.0, "vmax": 4.0 + ln * 1.5, "life": 0.55,
		"smin": 0.18 + ln * 0.05, "smax": 0.32 + ln * 0.1, "r": ln * 0.25, "foam": 0.3, "alpha": 0.85})
	if p.y - Game.jutsu_floor(p.x, p.z) < 1.6:
		L.crown(h, L.ground(p), 0.5 + ln * 0.35, {"h": 0.9, "foam": 0.3})
		L.puddle(h, p, 0.6 + ln * 0.4, 1.5, {"alpha": 0.5})


# ------------------------------------------------------------------ su ejderi başı (-Z burun)
static func _dragon_meshes() -> Dictionary:
	return _c("mesh:dragon", func():
		var out = {}
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		# kafatası + uzun burun
		vc = L.tube_into(sf, vc, [Vector3(0, 0.0, 0.55), Vector3(0, 0.06, 0.15), Vector3(0, 0.05, -0.3), Vector3(0, 0.0, -0.72), Vector3(0, -0.04, -0.95)],
			[0.36, 0.42, 0.33, 0.2, 0.1], 12, 0.72, Vector3.RIGHT)
		# kaş çıkıntıları
		for sx in [-1.0, 1.0]:
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.12, 0.3, -0.42), Vector3(sx * 0.24, 0.32, -0.15), Vector3(sx * 0.3, 0.26, 0.1)], [0.05, 0.07, 0.02], 6, 0.6, Vector3.UP)
			# yeleli yanak dilleri
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.3, -0.05, 0.2), Vector3(sx * 0.55, -0.02, 0.5), Vector3(sx * 0.7, 0.08, 0.85)], [0.09, 0.06, 0.01], 6, 0.3, Vector3.UP)
		# sırt yelesi (ense boyunca geriye eğik dişler)
		for i in 5:
			var z0 = 0.05 + i * 0.17
			vc = L.tube_into(sf, vc, [Vector3(0, 0.3 - i * 0.02, z0), Vector3(0, 0.55 - i * 0.04, z0 + 0.18), Vector3(0, 0.66 - i * 0.05, z0 + 0.36)], [0.08, 0.04, 0.005], 5, 0.25, Vector3.BACK)
		sf.generate_normals()
		out["skull"] = sf.commit()
		# alt çene (açık)
		out["jaw"] = L.tube_mesh([Vector3(0, -0.18, 0.25), Vector3(0, -0.32, -0.2), Vector3(0, -0.34, -0.55), Vector3(0, -0.28, -0.8)], [0.24, 0.18, 0.12, 0.05], 10, 0.45, Vector3.RIGHT)
		# boynuzlar + bıyıklar (açık renk)
		var hs = SurfaceTool.new()
		hs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hc = 0
		for sx in [-1.0, 1.0]:
			hc = L.tube_into(hs, hc, [Vector3(sx * 0.18, 0.28, 0.05), Vector3(sx * 0.32, 0.48, 0.42), Vector3(sx * 0.4, 0.58, 0.85), Vector3(sx * 0.36, 0.7, 1.15)], [0.075, 0.05, 0.025, 0.004], 7)
			hc = L.tube_into(hs, hc, [Vector3(sx * 0.12, -0.05, -0.82), Vector3(sx * 0.45, -0.08, -0.62), Vector3(sx * 0.85, -0.25, -0.2), Vector3(sx * 1.1, -0.45, 0.35), Vector3(sx * 1.2, -0.62, 0.9)],
				[0.035, 0.028, 0.02, 0.012, 0.004], 5)
		hs.generate_normals()
		out["horns"] = hs.commit()
		var tb = MB.new()
		for q in 7:
			var ang = (q - 3) * 0.32
			tb.add("cone", Vector3(sin(ang) * 0.17, -0.12, -0.62 + absf(q - 3) * 0.08), Vector3(0.05, 0.12, 0.05), Color.WHITE, Vector3(180, 0, 0), 4)
		out["teeth"] = tb.build(_cmat("tooth", Color(0.97, 0.98, 1.0)))
		var eb = MB.new()
		for sx in [-1.0, 1.0]:
			eb.add("sphere", Vector3(sx * 0.27, 0.17, -0.22), Vector3(0.11, 0.08, 0.12), Color.WHITE, Vector3(0, 0, sx * -15.0), 8)
		out["eyes"] = eb.build(_cmat("dragon_eye", Color(0.96, 0.99, 1.0)))
		var pb = MB.new()
		for sx in [-1.0, 1.0]:
			pb.add("sphere", Vector3(sx * 0.31, 0.18, -0.25), Vector3(0.04, 0.06, 0.05), Color.WHITE, Vector3.ZERO, 6)
		out["pupils"] = pb.build(_cmat("shark_dark", Color(0.03, 0.06, 0.14)))
		return out)


static func _dragon_head(s: float) -> Node3D:
	var ms: Dictionary = _dragon_meshes()
	var wp = {"alpha": 0.88, "line": 0.13, "flow": 3.0, "streak": 2.0, "foam": 0.1, "neard": 4.0}
	var root = Node3D.new()
	var inner = Node3D.new()
	inner.scale = Vector3.ONE * s
	root.add_child(inner)
	inner.add_child(L.wmi(ms["skull"], wp))
	inner.add_child(L.wmi(ms["jaw"], wp))
	inner.add_child(L.wmi(ms["horns"], {"alpha": 0.92, "line": 0.12, "pal": L.FROST, "flow": 2.0}))
	inner.add_child(_mi(ms["teeth"], _cmat("tooth", Color(0.97, 0.98, 1.0))))
	inner.add_child(_mi(ms["eyes"], _cmat("dragon_eye", Color(0.96, 0.99, 1.0))))
	inner.add_child(_mi(ms["pupils"], _cmat("shark_dark", Color(0.03, 0.06, 0.14))))
	return root


# ================================================================== TEKNİKLER
## Mizudeppō Nichō (Gengetsu): iki elin işaret parmağından art arda su kurşunları; isabette dikenli yıldız sıçrama
static func mizudeppo_nicho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	for rh in [true, false]:
		L.gather(pj, pj.hand_pos(c, rh) + c.face_dir() * 0.25, 0.5, 5, 0.16, 0.08)
	pj.every(0.9, 0.11, func(i, _k):
		if not is_instance_valid(c):
			return
		var side = c.global_transform.basis.x * (0.35 if i % 2 == 0 else -0.35)
		var from = c.global_position + Vector3.UP * 1.3 + side + c.face_dir() * 0.5
		var d = Jutsu._aim(c, t)
		var bullet = L.wmi(_pellet_mesh(), {"alpha": 0.95, "line": 0.18, "flow": 6.0, "streak": 3.0})
		var pr = pj.shot(c, from, d, 46.0, bullet, pj.inf(c, "mizudeppo_nicho", 0.2, {"knock": 3.0, "kind": "light"}), null, true, 1.2, func(p, _h):
			_star_splat(pj, p, d))
		if pr:
			L.trail(pr, {"n": 10, "life": 0.18, "vmin": 0.3, "vmax": 1.0, "spread": 12.0, "smin": 0.08, "smax": 0.14, "g": Vector3(0, -6, 0), "alpha": 0.8})
		_muzzle(pj, from, d)
		Sfx.play("water", from, 1.6, 0.4))


## Parmak ucunda namlu patlaması: geriye açılan küçük halka + öne fışkıran ince damlalar
static func _muzzle(h: Node, at: Vector3, d: Vector3) -> void:
	var ring = L.wmi(_loop_mesh(0.12, 0.018), {"alpha": 0.9, "line": 0.0, "pal": L.FROST})
	L.put(h, ring, at)
	_aim(ring, d)
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.14)
	tw.chain().tween_callback(ring.queue_free)
	L.spray(h, at, d, {"n": 5, "spread": 14.0, "vmin": 5.0, "vmax": 9.0, "life": 0.22, "smin": 0.08, "smax": 0.14, "g": Vector3(0, -8, 0)})


## Dikenli düz yıldız sıçrama (ref): atıcıya bakan, hızla açılıp sönen su yıldızı + geri seken damlalar
static func _star_splat(h: Node, p: Vector3, d: Vector3) -> void:
	var st = L.wmi(_star_splat_mesh(randi() % 4), {"alpha": 0.9, "line": 0.0, "pal": L.FROST, "foam": 0.35, "streak": 0.0})
	L.put(h, st, p)
	_aim(st, d)
	st.rotate_object_local(Vector3.BACK, randf() * TAU)
	st.scale = Vector3.ONE * 0.2
	var s1 = randf_range(0.5, 0.75)
	var tw = st.create_tween()
	tw.tween_property(st, "scale", Vector3.ONE * s1, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): st.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.2)
	tw.parallel().tween_property(st, "scale", Vector3.ONE * s1 * 1.25, 0.2)
	tw.tween_callback(st.queue_free)
	L.spray(h, p, -d + Vector3.UP * 0.4, {"n": 7, "spread": 55.0, "vmin": 2.0, "vmax": 4.5, "life": 0.35, "smin": 0.1, "smax": 0.18})


## Gōsuiwan: bedendeki su damar damar sağ kola akar, kol şişer; yumruk havayı sıkıştırıp beyaz şok halkası, su ileri savrulur
static func suiton_gosuiwan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = c.get("model")
	var ov = m.overlay if m and m.get("overlay") else null
	if c is Player:
		Buffs.add("gosuiwan", 10.0, {"melee": 1.3, "reach": 1.3, "_name": "Gōsuiwan", "_desc": "su pompalanmış kaslı kol"})
	elif c.has_method("add_buff"):
		c.add_buff("gosuiwan", 10.0, {"melee": 1.3})
	if ov:
		var tw = c.create_tween()
		tw.tween_method(func(x: float): if is_instance_valid(m): m.overlay.bulk["RightUpperArm"] = x, 1.0, 2.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(9.4)
		tw.tween_method(func(x: float): if is_instance_valid(m): m.overlay.bulk["RightUpperArm"] = x, 2.6, 1.0, 0.3)
		tw.tween_callback(func(): if is_instance_valid(m): m.overlay.bulk.erase("RightUpperArm"))
	# bedenden kola akan su damarları
	for k in 8:
		var q = Vector3(randf_range(-0.35, 0.35), randf_range(0.3, 1.5), randf_range(-0.3, 0.3))
		pj.after(k * 0.025, func():
			if pj.live(c):
				var to = Jutsu._hand(c) + Vector3.UP * 0.25
				var pts = _arc_pts(c.global_position + q, to, 8, randf_range(-0.25, 0.25), 0.15)
				var v = _path_node(pj, pts, [0.03, 0.05, 0.06, 0.06, 0.055, 0.05, 0.04, 0.02], {"alpha": 0.9, "line": 0.15, "flow": 6.0, "streak": 3.0, "sides": 6})
				var p_a: Vector3 = pts[0]
				_reveal(v, p_a.distance_to(pts[pts.size() - 1]), 0.18)
				_fade_out(v, 0.2, 0.15))
	# kolu saran su kılıfı: kemiğe takılır, kasa emilirken incelip söner
	var ba = pj.bone_attach(c, "RightLowerArm")
	if ba:
		var sleeve = L.wmi(L.sphere_mesh(), {"alpha": 0.7, "wob": 2.0, "line": 0.14, "flow": 3.0, "streak": 2.0})
		ba.add_child(sleeve)
		sleeve.position = Vector3(0, 0.12, 0)
		sleeve.scale = Vector3(0.05, 0.05, 0.05)
		var tw2 = sleeve.create_tween()
		tw2.tween_property(sleeve, "scale", Vector3(0.24, 0.42, 0.24), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(sleeve, "scale", Vector3(0.17, 0.36, 0.17), 0.2)
		tw2.parallel().tween_method(func(v: float): sleeve.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.2)
		tw2.tween_callback(ba.queue_free)
	pj.busy(c, 0.55)
	pj.anim(c, "crouch", 2.0)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.5)
		var d = pj.fwd(c, t)
		var p = c.global_position + Vector3.UP * 1.1 + d * 1.6
		_gosuiwan_impact(pj, c.global_position + Vector3.UP * 1.1 + d * 0.6, p, d)
		pj.hit(c, p, 1.8, pj.inf(c, "suiton_gosuiwan_no_jutsu", 1.8, {"knock": 18.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.1}))
		Sfx.play("punch", p, 0.7))


static func _gosuiwan_impact(h: Node, fist: Vector3, p: Vector3, d: Vector3) -> void:
	# sıkışan hava: art arda iki ak şok halkası
	for k in 2:
		var ring = L.wmi(_loop_mesh(0.5, 0.05), {"alpha": 0.85, "line": 0.0, "pal": L.FROST, "streak": 0.0})
		L.put(h, ring, p + d * (k * 0.7))
		_aim(ring, d)
		ring.scale = Vector3.ONE * 0.4
		var tw = ring.create_tween()
		if k > 0:
			tw.tween_interval(0.05)
		tw.tween_property(ring, "scale", Vector3.ONE * (3.2 + k * 1.4), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.22)
		tw.tween_callback(ring.queue_free)
	# yumruk boyunca hız çizgileri
	var sd = d.cross(Vector3.UP).normalized()
	for k in 6:
		var off = sd * randf_range(-0.45, 0.45) + Vector3.UP * randf_range(-0.4, 0.4)
		var a = fist + off - d * 0.8
		var b = p + off + d * randf_range(0.4, 1.4)
		var ln = _path_node(h, [a, a.lerp(b, 0.5), b], [0.01, 0.025, 0.004], {"alpha": 0.8, "line": 0.0, "pal": L.FROST, "sides": 5})
		_fade_out(ln, 0.04, 0.12)
	# kola dolan su ileri savrulur (koni)
	L.spray(h, p, d, {"n": 26, "spread": 24.0, "vmin": 8.0, "vmax": 15.0, "life": 0.5, "smin": 0.16, "smax": 0.3, "g": Vector3(0, -10, 0), "foam": 0.2})


## Tate Eboshi: yerden kalkan dev, yarı saydam soluk su kütlesi — tepede uzun sırt dikeni, kenar boyunca dışa bakan
## dikenler, yüzeyde yukarı akan ak kıvrık girdaplar (ref: Suigetsu vs Hachibi). Mermileri yutar, dayananı iter.
static func suiton_tate_eboshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	if not (c is Player) and not ClanMech.water_near(c.global_position):
		return
	var d = pj.fwd(c, t)
	d.y = 0.0
	d = d.normalized()
	var W = 8.5
	var H = 9.0
	var D = 6.0
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_position = pj.gp(c.global_position + d * 2.0)
	root.look_at(root.global_position + d, Vector3.UP)
	var body = _mi(_dome_mesh(W, H, D), _smat("eboshi", EBOSHI_SHADER))
	body.set_instance_shader_parameter("seed", randf() * 10.0)
	root.add_child(body)
	# dikenler: kalın tabanlı, hafif kıvrık su sivrileri (gerçek boy)
	var spike = func(pos: Vector3, dir: Vector3, ln: float, rad: float):
		var up = dir.normalized()
		var side = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var pts = []
		var rr = []
		for j in 6:
			var u = j / 5.0
			pts.append(pos - up * rad * 0.6 + up * ln * u + side * sin(u * PI * 0.8) * ln * 0.04)
			rr.append(rad * pow(1.0 - u, 0.9) + 0.01)
		var mi = L.wmi(L.tube_mesh(pts, rr, 10), {"alpha": 0.82, "line": 0.12, "flow": 1.0, "streak": 0.6, "neard": 6.0})
		root.add_child(mi)
	for k in 13:
		var ang = lerpf(-1.45, 1.45, k / 12.0)
		var pos = Vector3(sin(ang) * W, cos(ang) * H, -0.4)
		var nrm = Vector3(sin(ang) / W, cos(ang) / H, 0.0).normalized()
		var top = k == 6
		spike.call(pos * 0.95, (nrm + Vector3(0, 0.2, 0)).normalized() if not top else Vector3.UP, 5.0 if top else randf_range(2.0, 3.0), 0.85 if top else 0.55)
	for k in 5:
		var ang2 = randf_range(-0.9, 0.9)
		var el = randf_range(0.3, 0.75)
		var q = Vector3(sin(ang2) * W * 0.8, el * H, -D * 0.7)
		spike.call(q, (Vector3(sin(ang2) * 0.4, 0.5, -1.0)).normalized(), randf_range(1.0, 1.6), 0.3)
	# taban: kütleyi besleyen köpüklü su halkası
	L.big_puddle(pj, root.global_position, W * 0.85, 5.6, {"alpha": 0.55, "ripple": 0.5, "foam": 0.15, "s0": 0.3, "neard": 6.0})
	# yükseliş: sudan kabarır
	root.scale = Vector3(0.6, 0.05, 0.6)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bt = body.create_tween().set_loops()
	bt.tween_property(body, "scale", Vector3(1.02, 0.98, 1.03), 0.5).set_trans(Tween.TRANS_SINE)
	bt.tween_property(body, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	for k in 6:
		var a = lerpf(-1.3, 1.3, k / 5.0)
		var bp = root.global_position + root.global_basis * Vector3(sin(a) * W * 0.9, 0, -cos(a) * D * 0.9)
		L.crown(pj, L.ground(bp), randf_range(1.6, 2.4), {"h": 1.4, "foam": 0.3, "t": 0.25})
	L.spray(pj, root.global_position + Vector3.UP * 4.0, Vector3.UP, {"n": 22, "spread": 80.0, "vmin": 5.0, "vmax": 10.0, "life": 1.1, "smin": 0.3, "smax": 0.55, "r": 3.0})
	pj.shake(0.5)
	var center = root.global_position + Vector3.UP * H * 0.4
	pj.every(6.0, 0.1, func(_i, _k):
		if not is_instance_valid(root):
			return
		# kütleye giren düşman mermisi yutulur
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and Combat.hostile(c, n.shooter):
				var v2 = n.global_position - root.global_position
				var lx = v2.dot(root.global_basis.x) / W
				var ly = v2.dot(Vector3.UP) / H
				var lz = v2.dot(-root.global_basis.z) / (D + 1.5)
				if ly > -0.1 and lx * lx + ly * ly + lz * lz < 1.1:
					_gulp(pj, n.global_position, 1.0)
					n.queue_free()
		# kütleye dayanan düşman dışarı itilir
		for e in pj.enemies_near(c, root.global_position + d * 1.5, W + 0.5):
			var v = e.global_position - root.global_position
			v.y = 0
			if v.dot(d) > -0.5:
				e.global_position = pj.gp(e.global_position + (d * 0.6 + v.normalized() * 0.2)))
	# çöküş: kütle yere boşalır, ıslak zemin bırakır (raitonla elektriklenebilir)
	pj.after(6.0, func():
		if not is_instance_valid(root):
			return
		var tw2 = root.create_tween()
		tw2.tween_property(root, "scale", Vector3(1.25, 0.02, 1.25), 0.35).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_method(func(v: float): _fade_all(root, v), 1.0, 0.3, 0.35)
		tw2.tween_callback(root.queue_free)
		var g = root.global_position
		L.big_puddle(pj, g + d * 1.0, W * 1.1, 6.0, {"alpha": 0.5, "ripple": 0.4, "s0": 0.5, "spread": 0.5, "neard": 6.0})
		L.ripple(pj, g, 2.0, W + 3.0, 0.7, {"alpha": 0.8})
		for k in 5:
			L.crown(pj, L.ground(g + Vector3(randf_range(-W, W) * 0.6, 0, randf_range(-D, D) * 0.6)), randf_range(1.8, 2.8), {"h": 1.0, "fall": 0.5, "foam": 0.25})
		L.spray(pj, center, Vector3.UP, {"n": 24, "spread": 110.0, "vmin": 4.0, "vmax": 8.0, "life": 0.9, "smin": 0.3, "smax": 0.55, "r": 3.0, "foam": 0.2})
		GroundFX.add(root.global_position + d * 1.5, "wet", W + 1.0, 10.0, c))
	Sfx.play("water", c.global_position, 0.6)


## Yutulan merminin küçük su lokması: mermi suya gömülür, halka + birkaç damla
static func _gulp(h: Node, p: Vector3, s: float) -> void:
	var ring = L.wmi(_loop_mesh(0.3, 0.03), {"alpha": 0.85, "line": 0.0, "pal": L.FROST})
	L.put(h, ring, p)
	var cam = h.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(p) > 0.1:
		ring.look_at(cam.global_position, _up_for(cam.global_position - p))
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 3.0 * s, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)
	L.spray(h, p, Vector3.UP, {"n": 6, "spread": 60.0, "vmin": 1.5, "vmax": 3.0, "life": 0.4, "smin": 0.12, "smax": 0.2})


## Suisairin (Funato): Shiomaneki kıskacından yelpaze halinde ince ak hilal su pulları fırlar
static func funato_suisairin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var cs = pj._crab_of(c)
	if cs.is_empty():
		if c is Player:
			Hud.msg("Önce Kuchiyose: Shiomaneki ile kıskacı çağır.", Color(1, 0.75, 0.45))
		return
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.8)
	pj._crab_snap(cs, 40.0, 0.12, 0.6)
	var root0: Node3D = cs.get("root")
	if is_instance_valid(root0):
		L.gather(pj, root0.global_position + root0.global_transform.basis.z * 0.8, 1.0, 8, 0.12, 0.18)
	for k in 18:
		pj.after(0.12 + k * 0.025, func():
			if not pj.live(c):
				return
			var root: Node3D = cs.get("root")
			var from = root.global_position + root.global_transform.basis.z * 0.8 if is_instance_valid(root) else pj.hand_pos(c, true)
			var dir = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.28, 0.28)) + Vector3(0, randf_range(-0.05, 0.08), 0)
			var holder = Node3D.new()
			var blade = L.wmi(_scale_blade_mesh(), {"alpha": 0.92, "line": 0.12, "pal": L.FROST, "streak": 3.0, "flow": 8.0, "near": 1.0, "neard": 2.0})
			holder.add_child(blade)
			blade.rotation.z = randf_range(-0.8, 0.8)
			blade.scale = Vector3.ONE * randf_range(0.8, 1.15)
			var pr = pj.shot(c, from, dir.normalized(), 38.0, holder, pj.inf(c, "funato_suisairin", 0.18, {"knock": 1.0, "kind": "light", "element": "suiton", "bleed": 0.5}), null, false, 1.0, func(p, h):
				_scale_hit(pj, p, dir)
				if h and pj.live(h):
					pj.st(h, "wet", 3.0))
			if pr:
				L.trail(pr, {"n": 8, "life": 0.15, "vmin": 0.2, "vmax": 0.8, "spread": 20.0, "smin": 0.06, "smax": 0.1, "g": Vector3(0, -4, 0), "pal": L.FROST, "alpha": 0.7})
			if k % 3 == 0:
				L.spray(pj, from, dir, {"n": 4, "spread": 30.0, "vmin": 3.0, "vmax": 6.0, "life": 0.25, "smin": 0.08, "smax": 0.14}))
	Sfx.play("water", c.global_position, 1.3)


## Pulun isabeti: yana iki ince kesik çizgi + ince püskürtü (kesme izi)
static func _scale_hit(h: Node, p: Vector3, d: Vector3) -> void:
	var sd = d.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		var a = p - d * 0.1
		var b = p + sd * s * randf_range(0.5, 0.8) + d * 0.3 + Vector3.UP * randf_range(-0.2, 0.3)
		var ln = _path_node(h, [a, a.lerp(b, 0.5) + Vector3.UP * 0.05, b], [0.02, 0.03, 0.003], {"alpha": 0.9, "line": 0.0, "pal": L.FROST, "sides": 5})
		_fade_out(ln, 0.03, 0.15)
	L.spray(h, p, d + Vector3.UP * 0.3, {"n": 6, "spread": 40.0, "vmin": 2.0, "vmax": 4.0, "life": 0.3, "smin": 0.08, "smax": 0.14})


## Bakusui Shōha (Kisame): ağızdan yere gürül gürül boşalan su, dışa yuvarlanan dalga sırtıyla 20 m'lik sığ denize döner
static func hoshigaki_bakusui_shoha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var at = c.global_position
	L.gather(pj, pj._mouth_pos(c), 1.4, 12, 0.35, 0.35)
	pj.after(0.4, func():
		var g0 = pj.gp(at)
		var mouth = pj._mouth_pos(c) if pj.live(c) else at + Vector3.UP * 1.55
		var fd = c.face_dir() if is_instance_valid(c) else Vector3.FORWARD
		# ağızdan yere dökülen kalın su (yuvarlak, sallanan dil)
		var land = pj.gp(mouth + fd * 1.6)
		var gush = _path_node(pj, [mouth, mouth + fd * 0.7 + Vector3.UP * 0.1, mouth.lerp(land, 0.6) + fd * 0.3, land + Vector3.UP * 0.2],
			[0.22, 0.45, 0.75, 1.0], {"alpha": 0.9, "line": 0.1, "flow": 6.0, "streak": 2.5, "wob": 1.5, "foam": 0.1, "neard": 5.0})
		_reveal(gush, 2.6, 0.2)
		_fade_out(gush, 1.4, 0.4)
		pj.every(1.4, 0.1, func(_i, _k):
			L.crown(pj, land, randf_range(1.0, 1.5), {"h": 0.8, "foam": 0.35, "t": 0.12}))
		# deniz: gerçek boyda sığ su tabakası (≤ 0.5 m), dışa yayılır
		L.big_puddle(pj, g0, 20.0, 4.5, {"alpha": 0.72, "ripple": 0.22, "pal": L.WATER, "foam": 0.04, "s0": 0.03, "spread": 0.8, "dry": 0.6, "neard": 7.0, "lift": 0.06})
		# dışa yuvarlanan dalga sırtı: gerçek boyda dilimler (büyütülmez, yalnız kayar)
		for k in 36:
			var a = k * TAU / 36.0
			var rd = Vector3(cos(a), 0, sin(a))
			var seg = L.wmi(_crest_seg_mesh(3.8, 0.5), {"alpha": 0.88, "line": 0.12, "foam": 0.35, "flow": 3.0, "streak": 1.4, "neard": 6.0})
			L.put(pj, seg, g0 + rd * 1.0 + Vector3.UP * 0.2)
			seg.look_at(seg.global_position + rd, Vector3.UP)
			var tw = seg.create_tween()
			tw.tween_method(func(r: float):
				if is_instance_valid(seg):
					seg.global_position = Vector3(g0.x, 0, g0.z) + rd * r
					seg.global_position.y = Game.jutsu_floor(seg.global_position.x, seg.global_position.z) + 0.15 + 0.15 * (1.0 - r / 20.0), 1.0, 20.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v: float): if is_instance_valid(seg): _fade_all(seg, v), 1.0, 0.0, 0.5)
			tw.tween_callback(seg.queue_free)
		for k in 12:
			var a = k * TAU / 12.0
			pj.after(0.2 + k * 0.04, func():
				var sp = at + Vector3(cos(a), 0.5, sin(a)) * 10.0
				L.crown(pj, L.ground(sp), randf_range(2.2, 3.0), {"h": 1.6, "foam": 0.3, "t": 0.2, "fall": 0.6})
				L.spray(pj, sp, Vector3(cos(a), 1.2, sin(a)), {"n": 14, "spread": 35.0, "vmin": 5.0, "vmax": 9.0, "life": 0.9, "smin": 0.28, "smax": 0.5, "r": 0.8, "foam": 0.2}))
		pj.every(5.0, 0.5, func(_i, _k):
			# denizde yer yer dalgacık (sığ suyun yaşadığı)
			for q in 3:
				var rp = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(2.0, 17.0)
				L.ripple(pj, rp, 0.4, randf_range(1.6, 2.6), 0.9, {"alpha": 0.6})
			for e in pj.enemies_near(c, at, 20.0):
				if not is_instance_valid(e) or e.is_dead():
					continue
				pj.st(e, "slow", 0.6)
				e.take_hit(pj.inf(c, "hoshigaki_bakusui_shoha", 0.3, {"knock": 0.0, "kind": "light", "element": "suiton"}))
				L.spray(pj, e.global_position + Vector3.UP * 0.3, Vector3.UP, {"n": 5, "spread": 40.0, "vmin": 1.5, "vmax": 3.0, "life": 0.35, "smin": 0.1, "smax": 0.18}), Callable())
		if c is Player:
			Buffs.add("bakusui", 5.0, {"speed": 1.4, "_name": "Patlayan Su Dalgası", "_desc": "suda hızlanırsın"})
		pj.shake(0.8))
	Sfx.play("water", at, 0.5)


## Taihōdan: ağızdan 16 m'lik kalın, öne genişleyen su topu akışı; çevresinde burgulu ince jetler, ucunda sürekli patlayan sıçrama
static func suiton_taihodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	pj.busy(c, 1.3)
	pj.anim(c, "cast", 1.0)
	L.gather(pj, pj._mouth_pos(c), 1.0, 9, 0.28, 0.32)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj._mouth_pos(c)
		var LN = 16.0
		var to = from + d * LN - Vector3.UP * 0.6
		var sd = d.cross(Vector3.UP).normalized()
		# ana kütle: ağızda ince, ileride kalınlaşan, yer yer şişen su sütunu
		var pts = []
		var rad = []
		for i in 13:
			var u = i / 12.0
			pts.append(from.lerp(to, u) + Vector3.UP * sin(u * PI) * 0.35)
			rad.append(lerpf(0.3, 1.75, pow(u, 0.6)) * (1.0 + 0.08 * sin(u * 23.0)))
		var main = _path_node(pj, pts, rad, {"alpha": 0.86, "line": 0.1, "flow": 6.0, "streak": 2.8, "foam": 0.12, "wob": 1.2, "neard": 6.0, "sides": 16})
		_reveal(main, LN, 0.16)
		var core_r = []
		for r in rad:
			core_r.append(float(r) * 0.55)
		var core = _path_node(pj, pts, core_r, {"alpha": 0.55, "line": 0.0, "pal": L.FROST, "flow": 10.0, "streak": 4.0, "neard": 6.0, "sides": 10})
		_reveal(core, LN, 0.12)
		# burgulu ince jetler (ana kütleye sarılır)
		for arm in 3:
			var hp = []
			var hr = []
			for i in 20:
				var u = i / 19.0
				var a = arm * TAU / 3.0 + u * 9.0
				var rr = lerpf(0.4, 2.1, pow(u, 0.6))
				hp.append(from.lerp(to, u) + Vector3.UP * sin(u * PI) * 0.35 + (sd * cos(a) + Vector3.UP * sin(a)) * rr)
				hr.append(0.07 + 0.05 * u)
			var hx = _path_node(pj, hp, hr, {"alpha": 0.9, "line": 0.1, "pal": L.FROST, "flow": 8.0, "sides": 6, "neard": 5.0})
			_reveal(hx, LN, 0.2)
			_fade_out(hx, 0.6, 0.25)
		_fade_out(main, 0.7, 0.3, Vector3(0.6, 0.6, 1.0))
		_fade_out(core, 0.6, 0.25)
		L.crown(pj, L.ground(to), 2.6, {"h": 1.6, "foam": 0.3, "t": 0.2, "fall": 0.7})
		Sfx.play("water", from, 0.9)
		var seen = []
		pj.every(0.7, 0.1, func(_i, _k):
			if not pj.live(c):
				return
			L.spray(pj, to, -d + Vector3.UP * 0.6, {"n": 14, "spread": 50.0, "vmin": 5.0, "vmax": 10.0, "life": 0.7, "smin": 0.3, "smax": 0.55, "r": 1.0, "foam": 0.25})
			for q in 6:
				var p = from.lerp(to, (q + 0.5) / 6.0)
				for e in pj.hit(c, p, 1.3, pj.inf(c, "suiton_taihodan", 0.22, {"knock": 9.0, "kind": "heavy", "element": "suiton", "dir": d}), seen):
					seen.append(e), func():
			L.big_puddle(pj, pj.gp(to), 3.2, 6.0, {"alpha": 0.6, "ripple": 0.4, "s0": 0.4})
			L.ripple(pj, pj.gp(to), 0.6, 4.5, 0.6, {"alpha": 0.7})))


## Kaisui Hōdan (Yagura): hedefin üstünde dört yandan toplanan su, ak damarlı dev su kütlesine kabarır; düşer, yayvan çöküp ezer
static func suiton_kaisui_hodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.9)
	var id = "suiton_kaisui_hodan"
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var at: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + d * 10.0)
	var top = at + Vector3.UP * 9.0
	var ball = Node3D.new()
	var mass = L.wmi(_blob_mesh(2.6, 2.3, 2.6, 0.09, randi() % 3), {"alpha": 0.86, "line": 0.1, "flow": 1.2, "streak": 1.0, "wob": 1.6, "foam": 0.05, "neard": 6.0})
	ball.add_child(mass)
	var inner = L.wmi(_blob_mesh(1.7, 1.5, 1.7, 0.12, 3), {"alpha": 0.4, "line": 0.0, "pal": L.DEEP, "wob": 2.0, "flow": 0.6})
	ball.add_child(inner)
	pj.scene_add(ball, top)
	ball.scale = Vector3.ONE * 0.1
	var bt = ball.create_tween()
	bt.tween_property(ball, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin = mass.create_tween().set_loops()
	spin.tween_property(mass, "rotation:y", TAU, 3.0).from(0.0)
	for k in 10:   # su dört bir yandan toplanır
		var a = TAU * k / 10.0
		var o = Vector3(cos(a), randf_range(-0.6, 0.6), sin(a)) * 6.0
		var pts = _arc_pts(top + o, top, 8, randf_range(-1.0, 1.0), randf_range(0.0, 1.2))
		var s = _path_node(pj, pts, [0.06, 0.16, 0.24, 0.28, 0.28, 0.24, 0.18, 0.1], {"alpha": 0.9, "line": 0.12, "flow": 7.0, "streak": 2.5, "sides": 8})
		_reveal(s, 6.5, 0.3, k * 0.02)
		_fade_out(s, 0.4, 0.15)
	Sfx.play("water", c.global_position, 0.7)
	var bw = weakref(ball)
	pj.after(0.55, func():   # iner
		var b = bw.get_ref()
		var x = tw.get_ref() if tw else null
		var p: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else at
		if b != null:
			var t2 = b.create_tween()
			t2.tween_property(b, "global_position", p + Vector3.UP * 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t2.parallel().tween_property(b, "scale", Vector3(1.1, 0.85, 1.1), 0.22)
			t2.tween_callback(b.queue_free))
	pj.after(0.78, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		var p: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else at
		# yayvan çöküş: kütle yere yapışıp yassılaşır
		var slump = L.wmi(_blob_mesh(2.8, 1.6, 2.8, 0.1, 1), {"alpha": 0.85, "line": 0.1, "flow": 1.0, "foam": 0.1, "neard": 6.0})
		L.put(pj, slump, p + Vector3.UP * 0.6)
		var st2 = slump.create_tween()
		st2.tween_property(slump, "scale", Vector3(1.7, 0.08, 1.7), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		st2.parallel().tween_property(slump, "global_position", p + Vector3.UP * 0.05, 0.45)
		st2.tween_method(func(v: float): slump.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.35)
		st2.tween_callback(slump.queue_free)
		L.crown(pj, p, 3.6, {"h": 1.3, "foam": 0.35, "t": 0.14, "fall": 0.6})
		L.big_puddle(pj, p, 4.5, 3.0, {"alpha": 0.62, "ripple": 0.45, "s0": 0.3, "spread": 0.3})
		L.ripple(pj, p, 1.0, 11.0, 0.8, {"alpha": 0.75})
		for k in 8:
			var a = TAU * k / 8.0
			L.spray(pj, p + Vector3(cos(a), 0.3, sin(a)) * 2.0, Vector3(cos(a), 0.6, sin(a)), {"n": 10, "spread": 30.0, "vmin": 5.0, "vmax": 9.0, "life": 0.8, "smin": 0.3, "smax": 0.55, "r": 0.6, "foam": 0.2})
		pj.shake(0.8)
		Sfx.play("water", p, 0.4)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, p, 4.2):
			e.take_hit(pj.inf(cc, id, 2.3 if e == x else 1.2, {"knock": 4.0, "launch": -4.0, "kind": "heavy", "element": "suiton", "stun": 1.0, "hitstop": 0.1}))
			pj.st(e, "wet", 8.0))


## Suichū Hōgeki (Yagura): sopanın kancasıyla rakip havaya takılır, dört yandan geniş, yassı, kıvrık su şeritleri ona çarpar
static func suiton_suichu_hogeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.4)
	var id = "suiton_suichu_hogeki"
	pj._jump_at(c, tt, 0.0, 11.0 if tt and tt.global_position.distance_to(c.global_position) > 2.3 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	pj.anim(c, "hook", 1.5)
	pj.after(0.2, func():   # kancayla havaya
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		Sfx.play("swing_staff", cc.global_position, 1.0)
		var tip = pj._club_tip(cc)
		var hs = pj.hit(cc, tip, 2.3, pj.inf(cc, id, 0.6, {"knock": 0.0, "launch": 13.0, "kind": "heavy", "element": "suiton", "hitstop": 0.06}))
		# kanca yayı: yerden yukarı kıvrılan ince su izi
		var fd: Vector3 = cc.face_dir()
		var arc = []
		for i in 9:
			var u = i / 8.0
			arc.append(tip + fd * (sin(u * PI) * 0.6 - 0.3) + Vector3.UP * lerpf(-1.0, 1.6, u))
		var hk = _path_node(pj, arc, [0.02, 0.06, 0.1, 0.12, 0.12, 0.1, 0.08, 0.05, 0.01], {"alpha": 0.9, "line": 0.12, "pal": L.FROST, "flow": 6.0, "sides": 6})
		_reveal(hk, 2.8, 0.1)
		_fade_out(hk, 0.12, 0.2)
		if not hs.is_empty():
			L.spray(pj, tip + Vector3.UP * 0.5, Vector3.UP, {"n": 10, "spread": 30.0, "vmin": 4.0, "vmax": 8.0, "life": 0.5, "smin": 0.14, "smax": 0.24}))
	pj._yama_seal(c)
	for k in 4:   # dört su sütunu: dört yandan havadaki rakibe
		pj.after(0.5 + k * 0.13, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var p: Vector3 = (x.global_position + Vector3.UP * 0.8) if x != null and pj.live(x) else cc.global_position + cc.face_dir() * 2.0 + Vector3.UP * 3.0
			var a = TAU * k / 4.0 + 0.5
			var g: Vector3 = pj.gp(p + Vector3(cos(a), 0, sin(a)) * 3.2)
			_hogeki_ribbon(pj, g, p, k)
			Sfx.play("water", g, 0.9 + k * 0.05)
			if x != null and pj.live(x):
				var last = k == 3
				x.take_hit(pj.inf(cc, id, 1.0 if last else 0.45, {"knock": 8.0 if last else 1.0, "launch": 4.0 if last else 2.5, "kind": "heavy", "element": "suiton", "hitstop": 0.05, "dir": (p - g).normalized()}))
				pj.st(x, "wet", 8.0))


## Yerden kalkan geniş yassı su şeridi: dibinde taç, hedefte ıslak patlama, sonra kopup yağar
static func _hogeki_ribbon(h: Node, g: Vector3, p: Vector3, k: int) -> void:
	var pts = []
	var rad = []
	var dl = g.distance_to(p)
	for i in 10:
		var u = i / 9.0
		var bend = (p - g).cross(Vector3.UP).normalized() * sin(u * PI) * 0.7 * (1.0 if k % 2 == 0 else -1.0)
		pts.append(g.lerp(p, u) + bend + Vector3.UP * sin(u * PI) * 0.6)
		rad.append(lerpf(0.85, 0.45, u) * (1.0 + 0.12 * sin(u * 13.0 + k)))
	var rb = _path_node(h, pts, rad, {"alpha": 0.88, "line": 0.13, "flow": 9.0, "streak": 3.0, "flat": 0.32, "n0": (p - g).cross(Vector3.UP), "sides": 12, "neard": 5.0})
	_reveal(rb, dl, 0.1)
	_fade_out(rb, 0.3, 0.3, Vector3(1.0, 1.0, 0.7))
	L.crown(h, g, 1.2, {"h": 1.4, "foam": 0.3, "t": 0.1})
	L.spray(h, p, (p - g).normalized() + Vector3.UP * 0.5, {"n": 14, "spread": 70.0, "vmin": 3.0, "vmax": 7.0, "life": 0.7, "smin": 0.2, "smax": 0.38, "r": 0.4, "foam": 0.2})
	L.puddle(h, g, 1.2, 2.0, {"alpha": 0.5})


## Dōgo Tatsumaki: kullanıcıyı içine alan, üst üste yığılmış dönen koyu su bantlarından hortum; ak sarmal şeritler, dibinde
## dişli sıçrama eteği ve savrulan toprak. Hedefe yürür, çevresini içine çeker, sonunda dışa patlar.
static func suiton_dogo_tatsumaki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 3.4)
	var id = "suiton_dogo_tatsumaki"
	var tt = pj.tg(c, t, 30.0)
	pj._face(c, tt)
	pj._yama_seal(c)
	Sfx.play("water", c.global_position, 0.5)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var R := 3.6
	var H := 13.0
	var s = {"g": pj.gp(c.global_position)}
	# hortum gövdesi: dönen bantlar (gerçek boy) + ak sarmal şeritler
	var root = Node3D.new()
	pj.scene_add(root, s["g"])
	var bands = []
	var nb = 7
	for b in nb:
		var u = (b + 0.5) / nb
		var rc = R * lerpf(0.42, 0.68, u)
		var band = L.wmi(_band_mesh(rc, rc * 0.82, H / nb * 0.62, b % 4), {"alpha": 0.9, "line": 0.11, "pal": L.DEEP if b % 2 == 0 else L.WATER, "flow": 4.0, "streak": 2.2, "foam": 0.04, "neard": 7.0})
		root.add_child(band)
		band.position = Vector3(sin(u * 3.0) * 0.35, H * u, cos(u * 2.0) * 0.25)
		bands.append({"n": band, "sp": randf_range(4.0, 7.0) * (1.0 if b % 3 != 1 else 0.8), "ph": randf() * TAU})
	var streaks = []
	for k in 3:
		var hx = L.wmi(L.helix_mesh(R * 0.95, H * 0.95, 2.2, 0.16, k * TAU / 3.0), {"alpha": 0.95, "line": 0.1, "pal": L.FROST, "flow": 8.0, "neard": 6.0})
		root.add_child(hx)
		streaks.append(hx)
	root.scale = Vector3(1.0, 0.2, 1.0)
	var move = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var dirv: Vector3 = cc.face_dir()
		if x != null and pj.live(x):
			dirv = x.global_position - s["g"]
		dirv.y = 0
		if dirv.length() > 0.5 and k > 0.15:   # kullanıcı içeriden yönetir: hortum hedefe doğru yürür
			s["g"] = pj.gp(s["g"] + dirv.normalized() * 6.5 * 0.05)
		var g: Vector3 = s["g"]
		var grow = minf(1.0, k * 6.0) * (1.0 if k < 0.88 else (1.0 - k) / 0.12)
		cc.global_position = g + Vector3.UP * 2.2 * grow   # kullanıcı hortumun içinde, gövdesinin ortasında
		if "velocity" in cc:
			cc.velocity = Vector3.ZERO
		if is_instance_valid(root):
			root.global_position = g
			root.scale = Vector3(maxf(0.3, grow), maxf(0.2, grow), maxf(0.3, grow))
			for bd in bands:
				var bn: Node3D = bd["n"]
				bn.rotation.y += float(bd["sp"]) * 0.05
				bn.rotation.z = sin(i * 0.12 + float(bd["ph"])) * 0.06
			for j in streaks.size():
				var sn: Node3D = streaks[j]
				sn.rotation.y += 0.55 + j * 0.05
		if i % 2 == 0:   # dibinde dönen çalkantı: dişli sıçrama eteği + savrulan toprak
			var a = randf() * TAU
			var bp = g + Vector3(cos(a) * R * 1.1, 0.2, sin(a) * R * 1.1)
			L.spray(pj, bp, Vector3(-sin(a), 0.9, cos(a)), {"n": 9, "spread": 35.0, "vmin": 5.0, "vmax": 10.0, "life": 0.8, "smin": 0.25, "smax": 0.45, "r": 0.5, "foam": 0.2})
			_dirt(pj, g + Vector3(cos(a) * R, 0.2, sin(a) * R), Vector3(-sin(a), 1.2, cos(a)), 3, 8.0)
		if i % 5 == 0:
			L.crown(pj, g, R * 1.05 * maxf(0.4, grow), {"h": 0.55, "foam": 0.4, "t": 0.12, "fall": 0.3})
		if i % 4 == 0:
			for e in pj.enemies_near(cc, g, R * 2.2):   # dışarıdakini içine çeker, içeridekini döndürüp savurur
				var v: Vector3 = e.global_position - g
				v.y = 0
				var dh = v.length()
				if dh > R + 0.6:
					if e is CharacterBody3D:
						e.velocity += -v.normalized() * 9.0
					continue
				var tang = Vector3(-v.z, 0, v.x).normalized() if dh > 0.1 else cc.face_dir()
				e.take_hit(pj.inf(cc, id, 0.16, {"knock": 6.0, "launch": 4.5, "kind": "heavy", "element": "suiton", "hitstop": 0.02, "dir": (tang + v.normalized() * 0.4).normalized()}))
				pj.st(e, "wet", 6.0)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != cc:
				var pv: Vector3 = p.global_position - g
				if Vector2(pv.x, pv.z).length() < R + 0.4 and pv.y < H:
					_gulp(pj, p.global_position, 0.7)
					p.queue_free()
	var end = func():
		var cc = cw.get_ref()
		var g: Vector3 = s["g"]
		if is_instance_valid(root):
			var tw2 = root.create_tween()
			tw2.tween_property(root, "scale", Vector3(1.4, 0.03, 1.4), 0.4).set_ease(Tween.EASE_IN)
			tw2.parallel().tween_method(func(v: float): _fade_all(root, v), 1.0, 0.0, 0.4)
			tw2.tween_callback(root.queue_free)
		L.ripple(pj, g + Vector3.UP * 0.3, 1.5, 12.0, 0.9, {"alpha": 0.8})
		L.big_puddle(pj, g, R * 1.8, 5.0, {"alpha": 0.6, "ripple": 0.4, "s0": 0.5})
		L.crown(pj, g, R * 1.2, {"h": 1.6, "foam": 0.3, "fall": 0.6})
		L.spray(pj, g + Vector3.UP * 3.0, Vector3.UP, {"n": 30, "spread": 120.0, "vmin": 5.0, "vmax": 11.0, "life": 1.0, "smin": 0.3, "smax": 0.6, "r": 2.0, "foam": 0.2})
		if cc == null or not pj.live(cc):
			return
		cc.global_position = g
		for e in pj.enemies_near(cc, g, R + 2.5):
			var v: Vector3 = e.global_position - g
			v.y = 0
			e.take_hit(pj.inf(cc, id, 0.9, {"knock": 20.0, "launch": 6.0, "kind": "heavy", "element": "suiton", "hitstop": 0.08, "dir": v.normalized() if v.length() > 0.1 else cc.face_dir()}))
		Sfx.play("water", g, 0.4)
	pj.every(3.3, 0.05, move, end)


## Suika Bakusō: beden suya erir, yerde parlak bir göl olup hedefe akar; hedefin altında kubbe gibi kabarır ve
## dev su bombası gibi patlar (merkez fışkırma + dışa uçan iri su kütleleri + yana eğik altı fışkırma)
static func suiton_suika_bakuso_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.7)
	var id = "suiton_suika_bakuso_no_jutsu"
	var d = pj._face(c, tt)
	var from = pj.gp(c.global_position)
	var to: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + d * 8.0)
	var cw = weakref(c)
	var m = c.get("model")
	# erir: beden suya döner, göle çöker
	_water_skin(pj, c, 0.3, 0.75)
	L.spray(pj, from + Vector3.UP * 0.9, Vector3.DOWN, {"n": 16, "spread": 60.0, "vmin": 1.0, "vmax": 3.0, "life": 0.45, "smin": 0.16, "smax": 0.28, "r": 0.35, "g": Vector3(0, -14, 0)})
	Sfx.play("water", from, 1.0)
	if c is Player:
		Buffs.add("suika_bakuso", 1.6, {"armor": 0.25, "_name": "Suika Bakusō", "_desc": "beden su: darbeler içinden geçer"})
	elif c.has_method("add_buff"):
		c.add_buff("suika_bakuso", 1.6, {"armor": 0.25})
	var sink = func():
		var cc = cw.get_ref()
		if cc != null and pj.live(cc) and is_instance_valid(m):
			m.visible = false
	pj.after(0.22, sink)
	# akan göl: gerçek boy birikinti, yerde kayar ve büyür; ardında ıslak iz
	var pool = L.wmi(L.puddle_mesh(randi() % 6, 2.0), {"alpha": 0.75, "ripple": 0.6, "flat": 1.0, "line": 0.0, "flow": 0.5, "foam": 0.05})
	pool.sorting_offset = -1.0
	L.put(pj, pool, from + Vector3.UP * 0.05)
	pool.scale = Vector3(0.4, 1.0, 0.4)
	var flow = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p = from.lerp(to, k)
		p.y = Game.jutsu_floor(p.x, p.z)
		cc.global_position = p
		if "velocity" in cc:
			cc.velocity = Vector3.ZERO
		if is_instance_valid(pool):
			pool.global_position = p + Vector3.UP * 0.05
			var sc = lerpf(0.75, 1.6, k)
			pool.scale = Vector3(sc, 1.0, sc * 1.25)
			pool.look_at(p + Vector3.UP * 0.05 + _flat(to - from), Vector3.UP)
		if i % 3 == 0:
			L.puddle(pj, p - _flat(to - from) * 0.8, lerpf(0.9, 1.6, k), 1.2, {"alpha": 0.45, "ripple": 0.2, "spread": 0.15})
		if i % 2 == 0:
			L.spray(pj, p + _flat(to - from) * lerpf(1.4, 2.6, k), _flat(to - from) + Vector3.UP * 0.6, {"n": 4, "spread": 30.0, "vmin": 2.0, "vmax": 4.0, "life": 0.35, "smin": 0.1, "smax": 0.2})
	var rise = func():
		var cc = cw.get_ref()
		if is_instance_valid(m):
			m.visible = true
		if is_instance_valid(pool):
			_fade_out(pool, 0.3, 0.3)
		if cc == null or not pj.live(cc):
			return
		var g = pj.gp(cc.global_position)
		L.big_puddle(pj, g, 3.6, 1.2, {"alpha": 0.65, "ripple": 0.6, "s0": 0.6, "spread": 0.2})
		for e in pj.enemies_near(cc, g, 3.4):
			pj.st(e, "slow", 1.0)
		# kabaran su kubbesi (patlamadan önce)
		var bulge = L.wmi(_blob_mesh(2.4, 1.2, 2.4, 0.06, 2), {"alpha": 0.8, "line": 0.12, "wob": 2.5, "flow": 2.0, "foam": 0.1, "neard": 5.0})
		L.put(pj, bulge, g)
		bulge.scale = Vector3(0.8, 0.05, 0.8)
		var bt = bulge.create_tween()
		bt.tween_property(bulge, "scale", Vector3(1.0, 0.9, 1.0), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		bt.tween_callback(bulge.queue_free)
		var boom = func():
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			_water_skin(pj, c2, 0.5, 0.75)
			_suika_blast(pj, g)
			for e in pj.enemies_near(c2, g, 3.8):
				var v: Vector3 = e.global_position - g
				v.y = 0.0
				e.take_hit(pj.inf(c2, id, 4.0, {"knock": 12.0, "launch": 13.0, "kind": "heavy", "element": "suiton", "hitstop": 0.14, "dir": v.normalized()}))
				pj.st(e, "wet", 8.0)
			pj.shake(0.9)
			Sfx.play("boom", g, 0.9)
			Sfx.play("water", g, 0.5)
		pj.after(0.3, boom)
	pj.every(0.8, 1.0 / 30.0, flow, rise)


static func _suika_blast(h: Node, g: Vector3) -> void:
	# merkez: ampul başlı kalın fışkırma (yukarıda patlayıp açılır)
	var col_pts = []
	var col_r = []
	for i in 9:
		var u = i / 8.0
		col_pts.append(g + Vector3.UP * (u * 6.5))
		col_r.append(lerpf(2.4, 1.0, u) + sin(u * PI) * 0.3 + (0.9 if u > 0.8 else 0.0) * (u - 0.8) * 5.0)
	var geyser = _path_node(h, col_pts, col_r, {"alpha": 0.86, "line": 0.11, "flow": 8.0, "streak": 2.0, "foam": 0.15, "wob": 1.4, "sides": 16, "neard": 7.0})
	_reveal(geyser, 6.5, 0.15)
	_fade_out(geyser, 0.35, 0.4, Vector3(1.3, 1.3, 0.4))
	# yana eğik altı kısa fışkırma
	for k in 6:
		var a = k * TAU / 6.0 + 0.3
		var b = g + Vector3(cos(a), 0, sin(a)) * 2.0
		var tip = b + Vector3(cos(a) * 1.4, 3.3, sin(a) * 1.4)
		var sp = _path_node(h, [b, b.lerp(tip, 0.5) + Vector3.UP * 0.2, tip], [0.9, 0.7, 0.35], {"alpha": 0.86, "line": 0.12, "flow": 7.0, "streak": 2.0, "sides": 10, "neard": 5.0})
		_reveal(sp, 3.8, 0.12, 0.04)
		_fade_out(sp, 0.3, 0.3)
	# dışa uçan iri su kütleleri: balistik yay, düşünce birikinti
	for k in 10:
		var a = randf() * TAU
		var v0 = Vector3(cos(a) * randf_range(4.0, 8.0), randf_range(7.0, 11.0), sin(a) * randf_range(4.0, 8.0))
		var lump = L.wmi(L.sphere_mesh(), {"alpha": 0.9, "line": 0.14, "wob": 3.0, "flow": 2.0})
		var sz = randf_range(0.5, 0.9)
		L.put(h, lump, g + Vector3.UP * 2.0)
		lump.scale = Vector3.ONE * sz
		var p0 = g + Vector3.UP * 2.0
		var dur = randf_range(0.9, 1.3)
		var tw = lump.create_tween()
		tw.tween_method(func(tt: float):
			if is_instance_valid(lump):
				lump.global_position = p0 + v0 * tt + Vector3(0, -9.0, 0) * tt * tt
				lump.scale = Vector3(sz * 0.9, sz * (1.0 + v0.y * 0.04), sz * 0.9), 0.0, dur, dur)
		tw.tween_callback(func():
			if is_instance_valid(lump):
				L.puddle(h, lump.global_position, sz * 1.6, 2.0, {"alpha": 0.5})
				L.spray(h, lump.global_position, Vector3.UP, {"n": 5, "spread": 70.0, "vmin": 1.5, "vmax": 3.0, "life": 0.35, "smin": 0.12, "smax": 0.2})
				lump.queue_free())
	L.ripple(h, g + Vector3.UP * 0.3, 1.0, 10.0, 0.8, {"alpha": 0.8})
	L.crown(h, g, 3.0, {"h": 1.8, "foam": 0.35, "fall": 0.7})
	L.spray(h, g + Vector3.UP * 1.0, Vector3.UP, {"n": 30, "spread": 80.0, "vmin": 6.0, "vmax": 12.0, "life": 1.0, "smin": 0.3, "smax": 0.6, "r": 1.4, "foam": 0.2})
	L.big_puddle(h, g, 4.5, 4.0, {"alpha": 0.55, "ripple": 0.4, "s0": 0.5})


## Daikōdan (Kisame): önde kabaran su kütlesinden, çenesi açık, dişleri dizili dev tek su köpekbalığı fırlar; yoldaki düşman
## jutsularını yutup büyür; çarpınca iki diş yayı kapanır, su taç gibi çöker
static func suiton_daikodan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d0 = pj.fwd(c, t)
	L.gather(pj, c.global_position + Vector3.UP * 1.3 + d0, 1.6, 14, 0.3, 0.6)
	var womb = L.wmi(_blob_mesh(1.6, 1.4, 1.9, 0.08, 0), {"alpha": 0.8, "line": 0.12, "wob": 2.5, "flow": 2.0, "foam": 0.06, "neard": 5.0})
	L.put(pj, womb, c.global_position + Vector3.UP * 1.5 + d0 * 2.2)
	_aim(womb, d0)
	womb.scale = Vector3.ONE * 0.2
	var wt = womb.create_tween()
	wt.tween_property(womb, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wt.tween_property(womb, "scale", Vector3(1.6, 1.6, 0.3), 0.14)
	wt.parallel().tween_method(func(v: float): womb.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.14)
	wt.tween_callback(womb.queue_free)
	var d = Jutsu._aim(c, t)
	var shark = _shark(8.0, {"open": 1.0, "wag": 7.0, "alpha": 0.88})
	var pr = pj.shot(c, c.global_position + Vector3.UP * 1.6 + d * 2.0, d, 20.0, shark, pj.inf(c, "suiton_daikodan_no_jutsu", 1.8, {"knock": 18.0, "launch": 4.0, "kind": "heavy"}), pj.tg(c, t, 40.0), false, 3.0, func(pos, _tg):
		_daikodan_crash(pj, pos, d))
	pr.radius = 1.8
	L.trail(pr, {"n": 40, "life": 0.6, "dir": Vector3(0, 0.3, 1), "spread": 40.0, "vmin": 2.0, "vmax": 5.0, "smin": 0.25, "smax": 0.45, "r": 1.0, "foam": 0.3, "alpha": 0.8})
	pr.on_tick = func(p, _dt):
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and n != p and not n.dead and Combat.hostile(c, n.shooter) and n.global_position.distance_to(p.global_position) < 3.5:
				var np: Vector3 = n.global_position
				n.queue_free()
				shark.scale *= 1.15
				p.info["dmg"] = float(p.info["dmg"]) * 1.2
				_shark_bite(shark)
				_gulp(pj, np, 1.4)
				pj.chakra_gain(c, 6.0)
	Sfx.play("water", c.global_position, 0.6)


## Isırık kapanışı: üst ve alt diş yayı birbirine çarpar, ardından su çöker
static func _daikodan_crash(h: Node, pos: Vector3, d: Vector3) -> void:
	var bite = Node3D.new()
	L.put(h, bite, pos)
	_aim(bite, d)
	var halves = []
	for half in [1.0, -1.0]:
		var b = MB.new()
		for q in 13:
			var a = lerpf(-1.25, 1.25, q / 12.0)
			b.add("cone", Vector3(sin(a) * 2.2, 0.0, -cos(a) * 1.0), Vector3(0.28, 0.75, 0.28), Color.WHITE, Vector3(180.0 if half > 0.0 else 0.0, 0, 0), 4)
		var mi = _mi(b.build(_cmat("tooth", Color(0.97, 0.98, 1.0))), _cmat("tooth", Color(0.97, 0.98, 1.0)))
		bite.add_child(mi)
		mi.position = Vector3(0, half * 1.8, 0)
		halves.append(mi)
	var tw = bite.create_tween().set_parallel(true)
	for k in 2:
		var hm: Node3D = halves[k]
		tw.tween_property(hm, "position", Vector3(0, (1.0 if k == 0 else -1.0) * 0.35, 0), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_interval(0.12)
	tw.chain().tween_method(func(v: float): _fade_all(bite, v), 1.0, 0.0, 0.2)
	tw.chain().tween_callback(bite.queue_free)
	_shark_pop(h, pos, 8.0)
	var g = L.ground(pos)
	h.get_tree().create_timer(0.12).timeout.connect(func():
		L.crown(h, g, 4.0, {"h": 1.7, "foam": 0.35, "t": 0.16, "fall": 0.7})
		L.big_puddle(h, g, 5.0, 4.0, {"alpha": 0.6, "ripple": 0.45, "s0": 0.4})
		L.ripple(h, g, 1.0, 10.0, 0.7, {"alpha": 0.75})
		L.spray(h, pos, Vector3.UP, {"n": 34, "spread": 100.0, "vmin": 5.0, "vmax": 11.0, "life": 1.0, "smin": 0.3, "smax": 0.6, "r": 1.6, "foam": 0.25}))


## Ameshikō (Kisame): avuç yere vurulur, gök yüzüne su sütunu fışkırır; tepeden dört su köpekbalığı dalar, dağılınca
## damla boyu köpekbalıkları yağmaya devam eder
static func suiton_ameshiko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var id = "suiton_ameshiko"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	pj.anim(c, "hook", 1.2)
	var g0 = pj.gp(c.global_position + d * 1.1)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var surge = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		# göğe fışkıran sütun: dibi kalın, yukarı inceler, tepede dağılır
		var pts = []
		var rad = []
		for i in 11:
			var u = i / 10.0
			pts.append(g0 + Vector3.UP * (u * 10.0) + side * sin(u * 5.0) * 0.25)
			rad.append(lerpf(1.5, 0.8, u) * (1.0 + 0.1 * sin(u * 17.0)))
		var col = _path_node(pj, pts, rad, {"alpha": 0.86, "line": 0.11, "flow": 9.0, "streak": 3.0, "foam": 0.12, "sides": 14, "neard": 6.0})
		_reveal(col, 10.0, 0.25)
		_fade_out(col, 0.6, 0.4, Vector3(0.5, 0.5, 1.0))
		L.spray(pj, g0 + Vector3.UP * 10.0, Vector3.UP, {"n": 24, "spread": 110.0, "vmin": 3.0, "vmax": 7.0, "life": 1.1, "smin": 0.25, "smax": 0.5, "r": 1.0, "foam": 0.2})
		L.crown(pj, g0, 1.8, {"h": 1.2, "foam": 0.3})
		L.ripple(pj, g0 + Vector3.UP * 0.2, 0.8, 5.0, 0.6, {"alpha": 0.75})
		Sfx.play("water", g0, 0.8)
		for e in pj.enemies_near(cc, g0, 2.2):   # yükselen su da çarpar
			e.take_hit(pj.inf(cc, id, 0.35, {"knock": 3.0, "launch": 7.0, "kind": "heavy", "element": "suiton"}))
	pj.after(0.3, surge)
	var rain = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var aimp: Vector3 = pj.gp(cc.global_position + d * 9.0)
		for k in 4:
			var from = g0 + Vector3.UP * 9.5 + side * (k - 1.5) * 1.7 + d * (k % 2) * 1.2
			var dive = func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				var x2 = tw.get_ref() if tw else null
				var okx = x2 != null and pj.live(x2)
				var to: Vector3 = (x2.global_position + Vector3.UP * 0.9) if okx else aimp + Vector3.UP * 0.5
				L.spray(pj, from, Vector3.UP, {"n": 8, "spread": 90.0, "vmin": 2.0, "vmax": 4.0, "life": 0.5, "smin": 0.18, "smax": 0.3, "r": 0.5})
				_shark_shot(pj, c2, id, from, (to - from).normalized(), 1.3, 27.0, 0.95, x2 if okx else null, {"knock": 4.0, "launch": -6.0, "hitstop": 0.05}, func(p, _h):
					var c3 = cw.get_ref()
					if c3 == null or not pj.live(c3):
						return
					for j in 5:   # damla boyu köpekbalıkları yağar
						var off = Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2))
						var f2: Vector3 = p + Vector3.UP * randf_range(4.0, 6.0) + off * 0.6
						var drop = func():
							var c4 = cw.get_ref()
							if c4 != null and pj.live(c4):
								_shark_shot(pj, c4, id, f2, (p + off - f2).normalized(), 0.32, 20.0, 0.14, null, {"knock": 0.0, "bleed": 0.5, "kind": "light"})
						pj.after(0.1 + j * 0.06, drop))
				Sfx.play("water", from, 1.4, 0.5)
			pj.after(k * 0.14, dive)
	pj.after(0.75, rain)


## Köpekbalığı mermisi (ana ağaçtaki ortak işleyicinin oynanışı birebir; görünüş: bu dosyanın köpekbalığı)
static func _shark_shot(pj: PathJutsu, c: Node3D, id: String, from: Vector3, dir: Vector3, s: float, speed: float, mul: float, homing: Node3D = null, extra := {}, on_hit := Callable()) -> Projectile:
	var info = {"knock": 6.0 * s, "kind": "heavy", "element": "suiton", "bleed": 1.5}
	info.merge(extra, true)
	var ln = 2.6 * s
	var pr = pj.shot(c, from, dir, speed, _shark(ln, {"open": 0.6, "wag": 11.0}), pj.inf(c, id, mul, info), homing, false, 3.0, func(p, h):
		_shark_pop(pj, p, ln)
		if on_hit.is_valid():
			on_hit.call(p, h))
	if pr:
		pr.radius = maxf(0.45, s * 0.55)
		L.trail(pr, {"n": int(8 + 14 * s), "life": 0.4, "spread": 25.0, "vmin": 0.5, "vmax": 2.0, "smin": 0.1 * s + 0.05, "smax": 0.2 * s + 0.08, "r": 0.2 * s, "foam": 0.2, "alpha": 0.8})
	return pr


## Mizukagami (Yagura): rakibin önünde yerde su yayılır, döner ve dik bir su aynasına dönüşür; aynadan rakibin su
## yansıması çıkıp ona saldırır. Ayna dikken rakibin mermilerini yutar.
static func suiton_mizukagami_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var face = (c.global_position - tt.global_position)
	face.y = 0
	face = face.normalized() if face.length() > 0.1 else -c.face_dir()
	var at = pj.gp(tt.global_position + face * 2.4)
	var pivot = Node3D.new()
	pj.scene_add(pivot, at + Vector3.UP * 0.04)
	pivot.look_at(pivot.global_position + face, Vector3.UP)
	var mirror = Node3D.new()
	pivot.add_child(mirror)
	var disc = _mi(_disc_mesh(1.5), _smat("mirror", MIRROR_SHADER))
	disc.set_instance_shader_parameter("seed", randf() * 10.0)
	mirror.add_child(disc)
	var rim = L.wmi(_loop_mesh(1.5, 0.11), {"alpha": 0.92, "line": 0.14, "flow": 4.0, "streak": 3.0, "foam": 0.25})
	mirror.add_child(rim)
	var rim_spin = rim.create_tween().set_loops()
	rim_spin.tween_property(rim, "rotation:z", TAU, 1.6).from(0.0)
	mirror.rotation.x = -PI * 0.5   # önce yerde yatan su
	mirror.scale = Vector3(0.05, 0.05, 1.0)
	L.crown(pj, at, 0.9, {"h": 0.8, "foam": 0.3})
	var tw = mirror.create_tween()
	tw.tween_property(mirror, "scale", Vector3.ONE, 0.3)   # yerde yayılan su havuzu
	tw.tween_property(mirror, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_BACK)   # 90° çevrilip dikleşir
	tw.parallel().tween_property(mirror, "position", Vector3(0, 1.51, 0), 0.25)
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		var cp = at + Vector3.UP * 1.55
		L.spray(pj, cp, Vector3.UP, {"n": 28, "spread": 110.0, "vmin": 2.0, "vmax": 5.0, "life": 0.7, "smin": 0.2, "smax": 0.38, "r": 1.2, "foam": 0.2})
		L.puddle(pj, at, 1.8, 2.0, {"alpha": 0.55})
		L.ripple(pj, at, 0.5, 3.0, 0.5, {"alpha": 0.7}))
	tw.tween_callback(pivot.queue_free)
	# dik dururken alt kenardan su süzülür
	pj.after(0.6, func():
		if is_instance_valid(mirror):
			var drip = L.trail(mirror, {"n": 14, "life": 0.5, "dir": Vector3(0, -1, 0), "spread": 10.0, "vmin": 0.5, "vmax": 1.5, "smin": 0.1, "smax": 0.16, "r": 0.9})
			drip.position = Vector3(0, -1.3, 0))
	# ayna dikken rakibin mermilerini karşılar
	pj.every(1.5, 0.05, func(_i, _k):
		if not is_instance_valid(mirror):
			return
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.get("shooter") == tt and n.global_position.distance_to(mirror.global_position) < 2.0:
				_gulp(pj, n.global_position, 1.0)
				n.queue_free(), Callable())
	pj.after(0.6, func():
		if not pj.live(tt):
			return
		# yansıma: rakibin kendisi (görünüşü), aynadan çıkıp ona saldırır
		var r = ShadowClone.new()
		var tm = tt.get("model")
		r.look = (tm.look.duplicate() if tm and is_instance_valid(tm) else c.model.look.duplicate())
		r.life = 1.6
		pj.get_tree().current_scene.add_child(r)
		r.team = c.get("team")
		r.global_position = at
		r.tgt = tt
		if r.get("model"):
			for mi in r.model.find_children("*", "MeshInstance3D", true, false):   # su yansıması: hafif saydam, su kaplı
				(mi as MeshInstance3D).transparency = 0.25
				(mi as MeshInstance3D).material_overlay = _skinw_mat(0.7)
		pj.after(0.35, func():
			if pj.live(tt):
				_mirror_strike(pj, tt.global_position + Vector3.UP, _flat(tt.global_position - at))
				tt.take_hit(pj.inf(c, "suiton_mizukagami_no_jutsu", 1.4, {"knock": 12.0, "kind": "heavy", "element": "suiton"}))
			if is_instance_valid(r):
				L.spray(pj, r.global_position + Vector3.UP, Vector3.UP, {"n": 22, "spread": 90.0, "vmin": 2.0, "vmax": 5.0, "life": 0.6, "smin": 0.2, "smax": 0.36, "r": 0.6})
				L.puddle(pj, r.global_position, 1.2, 1.5, {"alpha": 0.5})
				r.queue_free()))
	Sfx.play("water", at, 0.9)


## Yansımanın vuruşu: çapraz su hilali + yüzdeki patlama
static func _mirror_strike(h: Node, p: Vector3, d: Vector3) -> void:
	var blade = L.wmi(_scale_blade_mesh(), {"alpha": 0.92, "line": 0.12, "flow": 6.0, "streak": 3.0})
	L.put(h, blade, p - d * 0.6)
	_aim(blade, d)
	blade.rotate_object_local(Vector3.FORWARD, 0.9)
	blade.scale = Vector3.ONE * 1.2
	var tw = blade.create_tween()
	tw.tween_property(blade, "scale", Vector3.ONE * 3.2, 0.14).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(blade, "global_position", p + d * 0.4, 0.14)
	tw.tween_method(func(v: float): blade.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.18)
	tw.tween_callback(blade.queue_free)
	L.spray(h, p, d + Vector3.UP * 0.4, {"n": 16, "spread": 45.0, "vmin": 4.0, "vmax": 8.0, "life": 0.5, "smin": 0.18, "smax": 0.32, "foam": 0.2})


## Samehada Yūgō (Kisame): bedeni saran su sarmalı içinde köpekbalığı-insana dönüşür — gri-mavi çizgili ten (katman),
## kemiğe takılı köpekbalığı kafası (sivri burun, diş sıraları, solungaç), sırt / kol yüzgeçleri, sallanan kuyruk; iri kollar (kemik)
static func hoshigaki_gyojin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	_gyojin_swirl(pj, c)
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.skel == null:
		return
	var SKIN = Color(0.55, 0.62, 0.72)
	var STRIPE = Color(0.25, 0.3, 0.4)
	var FIN = Color(0.48, 0.55, 0.66)
	# ten: gri-mavi (lanet mührü II'deki ten değişimiyle aynı yol)
	var ratio: Color = m._skin_ratio()
	var skin_mats = []
	for sm in m.materials:
		if sm is ShaderMaterial and sm.get_shader_parameter("tint") == ratio:
			skin_mats.append(sm)
			sm.set_shader_parameter("tint", SKIN)
	# gövde derisi: giysinin bel üstüne köpekbalığı derisi katmanı (pantolon kalır)
	var shark_skin = _smat("sharkskin", SHARKSKIN_SHADER)
	var skinned = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in ["Cloth", "Body"]:
			(mi as MeshInstance3D).material_overlay = shark_skin
			skinned.append(mi)
	# iri gövde ve kollar (kemik)
	m.overlay.bulk["LeftUpperArm"] = 1.45
	m.overlay.bulk["RightUpperArm"] = 1.45
	var fd: Vector3 = c.face_dir()
	var sd: Vector3 = fd.cross(Vector3.UP)
	var fwd_basis = Basis.looking_at(-fd, Vector3.UP)   # yerel +Z = ileri, -Z = geri
	var head_pos: Vector3 = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Head")).origin
	var parts = []
	var hp = pj._bone_world_attach(c, "Head", _gyojin_head(SKIN, STRIPE), Transform3D(fwd_basis, head_pos + Vector3.UP * 0.06 + fd * 0.02))
	if hp:
		parts.append(hp)
	var chest_pos: Vector3 = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("UpperChest")).origin
	var dfin = _toon_tube([Vector3(0, 0, 0.05), Vector3(0, 0.3, -0.1), Vector3(0, 0.55, -0.3)], [0.2, 0.12, 0.015], FIN, 0.15, Vector3.BACK)
	var dp = pj._bone_world_attach(c, "UpperChest", dfin, Transform3D(fwd_basis, chest_pos - fd * 0.18 + Vector3.UP * 0.05))
	if dp:
		parts.append(dp)
	for side in ["LeftLowerArm", "RightLowerArm"]:
		var bi = m.skel.find_bone(side)
		if bi < 0:
			continue
		var ap: Vector3 = m.skel.global_transform * m.skel.get_bone_global_pose(bi).origin
		var outward = sd * (1.0 if side.begins_with("Right") else -1.0)
		var afin = _toon_tube([Vector3(0, 0, 0), Vector3(0, 0.12, -0.08), Vector3(0, 0.24, -0.2)], [0.1, 0.06, 0.008], FIN, 0.15, Vector3.RIGHT)
		var ap2 = pj._bone_world_attach(c, side, afin, Transform3D(Basis.looking_at(outward, Vector3.UP), ap + outward * 0.06))   # ön kolun dışından yukarı-dışa kalkar
		if ap2:
			parts.append(ap2)
	# kuyruk: kalçadan geriye, ucunda hilal yüzgeç; sallanır
	var hips_pos: Vector3 = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Hips")).origin
	var tail = _gyojin_tail(SKIN, FIN)
	var tp2 = pj._bone_world_attach(c, "Hips", tail, Transform3D(fwd_basis, hips_pos - fd * 0.12))
	if tp2:
		parts.append(tp2)
		var tw = tail.create_tween().set_loops()
		var base_rot = tail.rotation
		tw.tween_property(tail, "rotation", base_rot + Vector3(0, 0.35, 0), 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(tail, "rotation", base_rot - Vector3(0, 0.35, 0), 0.4).set_trans(Tween.TRANS_SINE)
	if c is Player:
		Buffs.add("gyojin", 20.0, {"melee": 1.4, "speed": 1.18, "armor": 0.7, "lifesteal": 0.15, "_name": "Samehada Yūgō", "_desc": "köpekbalığı-insan: ısırık can çalar"})
	elif c.has_method("add_buff"):
		c.add_buff("gyojin", 20.0, {"melee": 1.4, "speed": 1.18, "armor": 0.7})
	pj.after(20.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free()
		if is_instance_valid(m):
			m.overlay.bulk.erase("LeftUpperArm")
			m.overlay.bulk.erase("RightUpperArm")
			for sm in skin_mats:
				sm.set_shader_parameter("tint", m._skin_ratio())
			for mi in skinned:
				if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == shark_skin:
					(mi as MeshInstance3D).material_overlay = null
		if is_instance_valid(c):
			L.spray(pj, c.global_position + Vector3.UP, Vector3.UP, {"n": 18, "spread": 90.0, "vmin": 2.0, "vmax": 5.0, "life": 0.6, "smin": 0.18, "smax": 0.32, "r": 0.5}))
	Sfx.play("roar", c.global_position, 1.2)


## Dönüşüm anı: bedeni saran, yükselerek dönen iki su sarmalı + ayak dibinde taç
static func _gyojin_swirl(h: Node, c: Node3D) -> void:
	var at = c.global_position
	L.crown(h, L.ground(at), 1.3, {"h": 1.2, "foam": 0.3})
	L.puddle(h, at, 1.4, 1.5, {"alpha": 0.5})
	for k in 2:
		var hx = L.wmi(L.helix_mesh(0.6, 2.0, 2.2, 0.1, k * PI), {"alpha": 0.92, "line": 0.12, "flow": 6.0, "streak": 2.5, "foam": 0.15})
		L.put(h, hx, at)
		hx.scale = Vector3(1.2, 0.2, 1.2)
		var tw = hx.create_tween().set_parallel(true)
		tw.tween_property(hx, "scale", Vector3(0.85, 1.0, 0.85), 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(hx, "rotation:y", TAU * 1.2 * (1.0 if k == 0 else -1.0), 0.75)
		tw.tween_method(func(v: float): hx.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3).set_delay(0.45)
		tw.chain().tween_callback(hx.queue_free)
	L.spray(h, at + Vector3.UP * 1.0, Vector3.UP, {"n": 20, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "life": 0.7, "smin": 0.18, "smax": 0.32, "r": 0.5})


static func _toon_tube(pts: Array, radii: Array, col: Color, flat: float, n0: Vector3) -> MeshInstance3D:
	var key = "gyo_%s" % col.to_html(false)
	return _mi(L.tube_mesh(pts, radii, 8, flat, n0), _cmat(key, col, false, true))


## Köpekbalığı kafası (+Z ileri): sivri, öne-yukarı uzayan burun, açık alt çene, iki diş sırası, kara göz, solungaç
static func _gyojin_head(skin: Color, stripe: Color) -> Node3D:
	var root = Node3D.new()
	root.add_child(_toon_tube([Vector3(0, 0.0, -0.12), Vector3(0, 0.06, 0.06), Vector3(0, 0.09, 0.26), Vector3(0, 0.1, 0.46)], [0.135, 0.125, 0.07, 0.012], skin, 0.92, Vector3.RIGHT))
	root.add_child(_toon_tube([Vector3(0, -0.12, -0.02), Vector3(0, -0.13, 0.14), Vector3(0, -0.09, 0.26)], [0.11, 0.08, 0.022], skin.lightened(0.25), 0.45, Vector3.RIGHT))
	var tb = MB.new()
	for q in 9:
		var ang = (q - 4) * 0.28
		var tp = Vector3(sin(ang) * 0.1, -0.05, 0.24 - absf(q - 4) * 0.025)
		tb.add("cone", tp, Vector3(0.025, 0.055, 0.02), Color.WHITE, Vector3(180, 0, 0), 4)
		tb.add("cone", tp + Vector3(0, -0.07, -0.02), Vector3(0.022, 0.045, 0.02), Color.WHITE, Vector3.ZERO, 4)
	root.add_child(_mi(tb.build(_cmat("tooth", Color(0.97, 0.98, 1.0))), _cmat("tooth", Color(0.97, 0.98, 1.0))))
	var db = MB.new()
	for sx in [-1.0, 1.0]:
		db.add("sphere", Vector3(sx * 0.11, 0.06, 0.12), Vector3(0.025, 0.03, 0.03), Color.WHITE, Vector3.ZERO, 6)
		for g in 3:
			db.add("box", Vector3(sx * 0.15, -0.04, -0.02 - g * 0.04), Vector3(0.008, 0.08, 0.01), Color.WHITE)
	root.add_child(_mi(db.build(_cmat("gyo_dark_" + stripe.to_html(false), stripe.darkened(0.6))), _cmat("gyo_dark_" + stripe.to_html(false), stripe.darkened(0.6))))
	return root


## Kuyruk (+Z ileri): kalçadan geriye ve aşağı, ucunda dikey hilal yüzgeç
static func _gyojin_tail(skin: Color, fin: Color) -> Node3D:
	var root = Node3D.new()
	root.add_child(_toon_tube([Vector3(0, 0, 0), Vector3(0, -0.15, -0.35), Vector3(0, -0.3, -0.7), Vector3(0, -0.38, -1.05)], [0.12, 0.09, 0.05, 0.02], skin, 1.0, Vector3.RIGHT))
	root.add_child(_toon_tube([Vector3(0, -0.36, -0.98), Vector3(0, -0.15, -1.18), Vector3(0, 0.0, -1.3)], [0.06, 0.035, 0.005], fin, 0.15, Vector3.BACK))
	root.add_child(_toon_tube([Vector3(0, -0.4, -1.0), Vector3(0, -0.52, -1.14), Vector3(0, -0.6, -1.22)], [0.05, 0.03, 0.005], fin, 0.15, Vector3.BACK))
	return root


## Suiryūdan (Mei): ağızdan su ejderi — boynuzlu, yeleli, bıyıklı baş; arkasından kıvrılarak izleyen yılan gövdesi; çarpınca çöker
static func terumi_suiton_suiryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	L.gather(pj, pj._mouth_pos(c), 1.3, 12, 0.45, 0.4)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 2.0
		var head = _dragon_head(1.35)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 22.0, head, pj.inf(c, "terumi_suiton_suiryu", 1.4, {"knock": 14.0, "kind": "heavy", "element": "suiton", "burn": 0.0}), tt, false, 1.8, func(p, _h):
			L.crown(pj, L.ground(p), 2.8, {"h": 1.5, "foam": 0.3, "fall": 0.6})
			L.spray(pj, p, Vector3.UP, {"n": 26, "spread": 90.0, "vmin": 4.0, "vmax": 9.0, "life": 0.9, "smin": 0.25, "smax": 0.5, "r": 1.0, "foam": 0.2})
			L.big_puddle(pj, p, 3.0, 4.0, {"alpha": 0.6, "ripple": 0.4, "s0": 0.4}))
		if pr:
			L.trail(pr, {"n": 24, "life": 0.5, "spread": 30.0, "vmin": 0.5, "vmax": 2.0, "smin": 0.15, "smax": 0.3, "r": 0.5, "foam": 0.25, "alpha": 0.8})
			_dragon_body(pj, pr, from))
	Sfx.play("water", c.global_position, 0.7)


## Ejderin gövdesi: başın geçtiği yolu izleyen, kuyruğa doğru incelen, yana salınan tüp (her adımda yeniden kurulur);
## baş düşünce kuyruk toplanıp söner
static func _dragon_body(pj: PathJutsu, pr: Node3D, from: Vector3) -> void:
	var body = L.wmi(ArrayMesh.new(), {"alpha": 0.86, "line": 0.12, "flow": 4.0, "streak": 2.2, "foam": 0.08, "neard": 5.0})
	L.put(pj, body, Vector3.ZERO)
	var hist = [from]
	var st = {"t": 0.0}
	pj.every(3.0, 1.0 / 30.0, func(_i, _k):
		if not is_instance_valid(body):
			return
		st["t"] += 1.0 / 30.0
		if is_instance_valid(pr) and not pr.dead:
			var hp: Vector3 = pr.global_position + pr.global_basis.z * 0.6
			var sway: Vector3 = pr.global_basis.x * sin(float(st["t"]) * 11.0) * 0.35 + Vector3.UP * cos(float(st["t"]) * 7.0) * 0.2
			for j in hist.size():
				var hv: Vector3 = hist[j]
				hist[j] = hv + sway * 0.04 * float(j + 1) / hist.size()
			var last: Vector3 = hist[hist.size() - 1]
			if last.distance_to(hp) > 0.2:
				hist.append(hp)
			if hist.size() > 16:
				hist.remove_at(0)
		elif hist.size() > 2:
			hist.remove_at(0)
			if hist.size() > 2:
				hist.remove_at(0)
		else:
			body.queue_free()
			return
		if hist.size() >= 2:
			var rad = []
			var n = hist.size()
			for i in n:
				var u = float(i) / maxf(1.0, n - 1)
				rad.append(0.08 + 0.48 * pow(u, 0.7))
			body.mesh = L.tube_mesh(hist, rad, 10, 0.85, Vector3.UP), func():
		if is_instance_valid(body):
			_fade_out(body, 0.0, 0.3))


## Ketsueki Henkan: rakibin kanı iki kıvrık kırmızı akış halinde ele çekilir; elin önünde berrak suya döner, avuçta su
## küresi büyür. Kurban kuruyup büzülür (gerçek kemik). Sonda küre yukarı dağılır.
static func ketsueki_henkan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 4.5)
	if tt == null:
		if c == Game.player:
			Hud.msg("Ketsueki Henkan: kanını çekecek kadar yakın hedef yok", Color(0.75, 0.2, 0.25))
		return
	pj.busy(c, 2.3)
	var id = "ketsueki_henkan_no_jutsu"
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.0)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.st(tt, "bind", 2.1)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Kanı çekiliyor!", Color(0.85, 0.2, 0.25))
	Sfx.play("absorb", tt.global_position, 0.8)
	var m = tt.get("model")
	var shrink = {"k": 0.0}
	var bmat = _smat("blood", BLOOD_SHADER)
	var streams = []
	for q in 2:
		var s = _mi(ArrayMesh.new(), bmat)
		s.set_instance_shader_parameter("seed", randf() * 10.0)
		L.put(pj, s, Vector3.ZERO)
		streams.append(s)
	var orb = L.wmi(L.sphere_mesh(), {"alpha": 0.85, "wob": 2.5, "line": 0.14, "flow": 3.0, "streak": 2.0})
	L.put(pj, orb, pj.hand_pos(c))
	orb.scale = Vector3.ONE * 0.05
	var drain = func(i, k):
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var a: Vector3 = x.global_position + Vector3.UP * 1.1
		var b: Vector3 = pj.hand_pos(cc)
		var sd = (b - a).cross(Vector3.UP)
		sd = sd.normalized() if sd.length() > 0.01 else Vector3.RIGHT
		for q in 2:   # kırmızı akış elinin önünde berrak suya döner
			var sm: MeshInstance3D = streams[q]
			if not is_instance_valid(sm):
				continue
			var ph = i * 0.9 + q * PI
			var pts = []
			var rad = []
			for j in 14:
				var u = j / 13.0
				pts.append(a.lerp(b, u) + sd * sin(ph + u * 6.0) * 0.18 + Vector3.UP * sin(u * PI) * 0.4)
				rad.append(0.04 + 0.03 * sin(u * PI) + 0.01 * sin(u * 20.0 + i))
			sm.mesh = L.tube_mesh(pts, rad, 7)
			sm.set_instance_shader_parameter("conv", lerpf(0.85, -0.15, clampf(k * 1.4, 0.0, 1.0)))
		if is_instance_valid(orb):
			orb.global_position = b + (b - a).normalized() * 0.15
			orb.scale = Vector3.ONE * lerpf(0.08, 0.45, k)
		if i % 4 == 0:
			_blood_drops(pj, a, bmat)
			L.spray(pj, b, Vector3.DOWN, {"n": 3, "spread": 25.0, "vmin": 0.4, "vmax": 1.0, "life": 0.4, "smin": 0.08, "smax": 0.12, "g": Vector3(0, -9, 0)})
		shrink["k"] = k
		if m and is_instance_valid(m) and m.get("overlay") != null:   # kurban kuruyup büzülür: kol ve bacaklar incelir (gerçek kemik)
			var th = lerpf(1.0, 0.62, k)
			for bn in ["LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerArm", "RightLowerArm"]:
				m.overlay.bulk[bn] = th
		if i % 5 == 4:
			var info = pj.inf(cc, id, 0.32, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true})
			x.take_hit(info)
			pj.heal(cc, float(info.get("dmg", 10.0)) * 0.6)
			if "chakra" in cc:
				cc.chakra = minf(cc.max_chakra, cc.chakra + cc.max_chakra * 0.02)
	var fin = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		for sm in streams:
			if is_instance_valid(sm):
				_fade_out(sm, 0.0, 0.2)
		if m and is_instance_valid(m) and m.get("overlay") != null:
			var tw2 = m.create_tween()
			tw2.tween_interval(1.5)
			tw2.tween_callback(func():
				if is_instance_valid(m):
					for bn in ["LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerArm", "RightLowerArm"]:
						m.overlay.bulk.erase(bn))
		if is_instance_valid(orb):
			L.spray(pj, orb.global_position, Vector3.UP, {"n": 20, "spread": 50.0, "vmin": 3.0, "vmax": 6.0, "life": 0.7, "smin": 0.14, "smax": 0.26, "foam": 0.2})
			orb.queue_free()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var mx = float(x.get("max_hp")) if x.get("max_hp") != null else 100.0
		var hp = float(x.get("hp")) if x.get("hp") != null else mx
		if hp < mx * 0.3:   # kanı tükenen kurban kurur (güçlü hedefte Combat.cap_one_shot kırpar)
			var ex = pj.inf(cc, id, 1.0, {"knock": 0.0, "kind": "heavy", "pierce_guard": true})
			ex["execute"] = true
			ex["dmg"] = hp + 1.0
			x.take_hit(ex)
			Combat.popup_text(x.global_position + Vector3.UP * 2.8, "Kurudu!", Color(0.85, 0.2, 0.25))
		else:
			x.take_hit(pj.inf(cc, id, 1.0, {"knock": 4.0, "kind": "heavy", "stun": 1.2, "pierce_guard": true}))
	pj.every(2.0, 0.05, drain, fin)


## Kurbandan damlayan kan (kendi kan gölgelendiricisiyle parçacık)
static func _blood_drops(h: Node, at: Vector3, bmat: ShaderMaterial) -> void:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 60.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -12, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.14
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.particle_flag_align_y = true
	p.process_material = pm
	p.draw_pass_1 = L.drop_y_mesh()
	p.material_override = bmat
	p.amount = 4
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.put(h, p, at)
	p.emitting = true
	L.free_later(h, p, 1.0)


## Suirō Sameodori (Kisame): 25 m'lik dev su küresi alanı yutar; içi su altı (kostik ışık ağı, kabarcıklar, inen ışık
## hüzmeleri); içinde sürü halinde yüzen su köpekbalıkları hedefe dalıp ısırır
static func suiro_sameodori_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var center = pj.gp(c.global_position)
	var R = 25.0
	var dome = Node3D.new()
	pj.scene_add(dome, center)
	var shell = _mi(_blob_mesh(R, R * 0.75, R, 0.015, 0), _smat("sea_dome", DOME_SHADER))
	dome.add_child(shell)
	dome.scale = Vector3.ONE * 0.02
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	L.crown(pj, center, 3.0, {"h": 2.0, "foam": 0.3, "fall": 0.7})
	L.ripple(pj, center, 2.0, R, 1.0, {"alpha": 0.8})
	_slowmo(pj, 0.4, 0.6)
	_cine(c, 14.0, 7.0)
	pj.busy(c, 0.9)
	# kabarcıklar: alanın içinden yavaşça yükselir
	var bub = L.particles({"n": 160, "life": 8.0, "dir": Vector3.UP, "spread": 25.0, "vmin": 0.3, "vmax": 1.2, "g": Vector3(0, 1.2, 0),
		"smin": 0.18, "smax": 0.34, "r": R * 0.55, "align": false, "mesh": L.sphere_mesh(), "burst": 0.6, "foam": 0.6, "alpha": 0.55, "line": 0.25})
	L.put(pj, bub, center + Vector3.UP * 4.0)
	bub.emitting = true
	L.free_later(pj, bub, 9.0)
	var sharks = []
	for k in 16:
		var s = _shark(randf_range(2.2, 2.8), {"open": 0.35, "wag": randf_range(7.0, 10.0)})
		pj.get_tree().current_scene.add_child(s)
		s.global_position = center + Vector3(randf_range(-3, 3), randf_range(1.0, 4.0), randf_range(-3, 3))
		sharks.append({"n": s, "r": randf_range(6.0, R - 3.0), "h": randf_range(2.0, R * 0.9), "ph": randf() * TAU, "sp": randf_range(0.6, 1.1) * (1.0 if k % 2 == 0 else -1.0), "atk": -1.0, "tg": null})
	if c is Player:
		Buffs.add("sameodori", 8.0, {"speed": 1.4})
	var bite_cd = {"t": 0.0}
	pj.every(8.0, 1.0 / 30.0, func(i, _k):
		bite_cd["t"] -= 1.0 / 30.0
		var inside = pj.enemies_near(c, center, R)
		# su altı: oyuncu kubbenin içindeyken ekran mavi-yeşil tonlanır, etrafında kabarcıklar yükselir, yukarıdan ışık hüzmeleri iner
		var pl = Game.player
		if pl and is_instance_valid(pl) and Game.world:
			if pl.global_position.distance_to(center) < R * 0.95:
				Game.world.env.set_tint(Color(0.0, 0.28, 0.55, 0.62))
				if i % 2 == 0:
					L.bubble(pj, pl.global_position + Vector3(randf_range(-3, 3), randf_range(0.0, 2.5), randf_range(-3, 3)), randf_range(0.08, 0.16), 1.6, Vector3(0, randf_range(0.6, 1.6), 0))
				if i % 6 == 0:
					_light_shaft(pj, pl.global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
			else:
				Game.world.env.set_tint(Color(0, 0, 0, 0))
		for s in sharks:
			var n: Node3D = s["n"]
			if not is_instance_valid(n):
				continue
			if s["atk"] >= 0.0 and pj.live(s["tg"]):
				# saldırı: hedefe dalar, ısırır, geri çekilir
				s["atk"] += 1.0 / 30.0
				var goal = s["tg"].global_position + Vector3.UP
				var p = n.global_position.lerp(goal, 0.22)
				if n.global_position.distance_to(goal) > 0.05:
					n.look_at(goal, Vector3.UP)
				n.global_position = p
				if p.distance_to(goal) < 1.2 or s["atk"] > 0.8:
					pj.hit(c, goal, 1.2, pj.inf(c, "suiro_sameodori_no_jutsu", 0.3, {"knock": 4.0, "kind": "heavy", "element": "suiton"}))
					_shark_bite(n)
					L.spray(pj, goal, Vector3.UP, {"n": 10, "spread": 80.0, "vmin": 1.5, "vmax": 3.5, "life": 0.5, "smin": 0.14, "smax": 0.26, "foam": 0.4, "alpha": 0.7})
					s["atk"] = -1.0
					s["tg"] = null
				continue
			s["ph"] += 0.035 * s["sp"]
			# av sürüsü: en yakın düşmanın çevresinde 3-7 m yarıçapta dönerek yüzer (düşman yoksa kullanıcının çevresinde)
			var hub: Vector3 = center
			var near_e = null
			var bd = 1e9
			for e in inside:
				var dd = e.global_position.distance_to(n.global_position)
				if dd < bd:
					bd = dd
					near_e = e
			if near_e:
				hub = near_e.global_position
			elif pj.live(c):
				hub = c.global_position
			var rr = 3.0 + fmod(s["r"], 4.0)
			var want = hub + Vector3(cos(s["ph"]) * rr, 1.2 + fmod(s["h"], 3.0) + sin(s["ph"] * 2.0) * 0.8, sin(s["ph"]) * rr)
			var p2 = n.global_position.lerp(want, 0.08)
			var mv = p2 - n.global_position
			if mv.length() > 0.01:
				n.look_at(p2 + mv, Vector3.UP)
			n.global_position = p2
		if bite_cd["t"] <= 0.0 and not inside.is_empty():
			bite_cd["t"] = 0.22
			var free = sharks.filter(func(x): return x["atk"] < 0.0)
			if not free.is_empty():
				var s = free[randi() % free.size()]
				s["atk"] = 0.0
				s["tg"] = inside[randi() % inside.size()]
		if i % 15 == 0:
			for e in inside:
				pj.st(e, "slow", 0.6)
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "suiro_sameodori_no_jutsu", 0.08, {"knock": 0.0, "kind": "light", "element": "suiton"}))   # boğulma
				if e.has_method("lose_target") and i % 45 == 0:
					e.lose_target(0.5), func():
		for s in sharks:
			if is_instance_valid(s["n"]):
				_shark_pop(pj, (s["n"] as Node3D).global_position, 2.5)
				s["n"].queue_free()
		if Game.world:
			Game.world.env.set_tint(Color(0, 0, 0, 0))
		if is_instance_valid(dome):
			var tw2 = dome.create_tween()
			tw2.tween_property(dome, "scale", Vector3(1.2, 0.02, 1.2), 0.5)
			tw2.parallel().tween_method(func(v: float): _fade_all(dome, v), 1.0, 0.2, 0.5)
			tw2.tween_callback(dome.queue_free)
		L.big_puddle(pj, center, 22.0, 3.0, {"alpha": 0.6, "ripple": 0.3, "s0": 0.8, "spread": 0.5, "neard": 7.0})
		L.ripple(pj, center, 4.0, R + 4.0, 1.0, {"alpha": 0.8})
		L.spray(pj, center + Vector3.UP, Vector3.UP, {"n": 40, "spread": 120.0, "vmin": 6.0, "vmax": 12.0, "life": 1.2, "smin": 0.35, "smax": 0.7, "r": 4.0, "foam": 0.2}))
	pj.shake(1.2)
	Sfx.play("water", center, 0.35)


## Su altına inen ışık hüzmesi: yukarıdan aşağı incelen, kameraya Y ekseninde dönen yumuşak şerit
static func _light_shaft(h: Node, base: Vector3) -> void:
	var q = MeshInstance3D.new()
	q.mesh = _c("mesh:shaft", func():
		var qm = QuadMesh.new()
		qm.size = Vector2(1.6, 10.0)
		return qm)
	q.material_override = _c("mat:shaft", func():
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.albedo_color = Color(0.6, 0.9, 1.0, 0.22)
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.set_color(1, Color(1, 1, 1, 1.0))
		var gt = GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 1.0)
		gt.fill_to = Vector2(0.5, 0.0)
		m.albedo_texture = gt
		return m)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.put(h, q, base + Vector3.UP * 5.0)
	q.transparency = 1.0
	var tw = q.create_tween()
	tw.tween_property(q, "transparency", 0.0, 0.4)
	tw.tween_property(q, "transparency", 1.0, 0.8)
	tw.tween_callback(q.queue_free)


## Bashōsen: Mizu no Maki: efsanevi yelpaze savrulur, tüylerinden su saçılır; 24 m genişliğinde kıvrılan dalga duvarı
## 38 m ileri yuvarlanır, önüne kattığını sürükler, ardında ıslak iz bırakır
static func bashosen_mizu_no_maki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	_fan(pj, c)
	pj.after(0.35, func():
		var start = pj.gp(c.global_position + d * 3.0)
		var wave = Node3D.new()
		pj.scene_add(wave, start)
		wave.look_at(start + d, Vector3.UP)
		var wall = L.wmi(_wave_mesh(24.0, 5.0), {"alpha": 0.9, "line": 0.1, "pal": L.WATER, "flow": 3.0, "streak": 1.4, "foam": 0.08, "neard": 7.0})
		wave.add_child(wall)
		var lip_pts = []
		var lip_r = []
		for k in 25:
			var x = -11.0 + k * (22.0 / 24.0)
			var ef = clampf(minf(x + 12.0, 12.0 - x) / 3.5, 0.0, 1.0)
			ef = ef * ef * (3.0 - 2.0 * ef)
			lip_pts.append(Vector3(x, 5.0 * 0.86 * ef * (1.0 + 0.08 * sin(x * 0.9)), -1.6 * (0.35 + 0.65 * ef)))
			lip_r.append(0.35 * ef + 0.02)
		var lip = L.wmi(L.tube_mesh(lip_pts, lip_r, 8, 0.8, Vector3.UP), {"alpha": 0.95, "line": 0.0, "pal": L.FROST, "foam": 0.7, "flow": 4.0, "neard": 6.0})
		wave.add_child(lip)
		wave.scale = Vector3(1.0, 0.1, 1.0)
		Sfx.play("water", start, 0.6)
		pj.shake(0.6)
		pj.every(2.6, 1.0 / 30.0, func(i, k):
			if not is_instance_valid(wave):
				return
			var p = pj.gp(start + d * (k * 38.0))
			wave.global_position = p + Vector3.UP * (sin(k * PI) * 0.3)
			wave.scale = Vector3(1.0, minf(1.0, 0.1 + k * 6.0) * (0.85 + sin(k * PI) * 0.3), 1.0)
			if i % 3 == 0:
				var sp = p + side * randf_range(-10, 10) - d * 1.0
				L.spray(pj, sp + Vector3.UP * 4.0, d + Vector3.UP * 0.8, {"n": 10, "spread": 40.0, "vmin": 4.0, "vmax": 8.0, "life": 0.8, "smin": 0.3, "smax": 0.55, "r": 0.8, "foam": 0.3})
			if i % 6 == 0:
				L.puddle(pj, p + d * 2.0 + side * randf_range(-8, 8), randf_range(2.0, 3.2), 3.0, {"alpha": 0.5, "ripple": 0.3})
			if i % 9 == 0:
				L.crown(pj, p - d * 1.2 + side * randf_range(-9, 9), randf_range(1.6, 2.4), {"h": 1.2, "foam": 0.35, "t": 0.15})
			for e in pj.enemies_near(c, p, 12.0):
				var rel = e.global_position - p
				if absf(rel.dot(d)) < 3.5 and pj.live(e):
					e.global_position = pj.gp(e.global_position + d * 0.9)
					if i % 5 == 0:
						pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.6, pj.inf(c, "bashosen_mizu_no_maki", 0.4, {"element": "suiton", "knock": 3.0, "kind": "heavy"}))
						pj.st(e, "wet", 8.0), func():
			if is_instance_valid(wave):
				var g = wave.global_position
				var tw = wave.create_tween()
				tw.tween_property(wave, "scale", Vector3(1.05, 0.05, 1.3), 0.45).set_ease(Tween.EASE_IN)
				tw.parallel().tween_method(func(v: float): _fade_all(wave, v), 1.0, 0.0, 0.45)
				tw.tween_callback(wave.queue_free)
				for q in 6:
					L.crown(pj, g + side * lerpf(-9.0, 9.0, q / 5.0) - d * 1.0, randf_range(2.2, 3.0), {"h": 1.4, "foam": 0.35, "fall": 0.6})
				L.big_puddle(pj, g, 9.0, 4.0, {"alpha": 0.55, "ripple": 0.3, "s0": 0.6, "neard": 6.0})))


## Bashōsen (kuşanılan silah modeli) elde açılır; sırttaki gizlenir, chakra emilir (bashosen_fan'ın oynanışı birebir).
## Savuruşta tüylerden su damlaları saçılır.
static func _fan(pj: PathJutsu, c: Node3D) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = CharacterModel.weapon_mesh("bashosen")
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	pj.after(0.2, func():
		if is_instance_valid(root):
			var fp = root.global_position + Vector3.UP * 0.8
			L.spray(pj, fp, c.face_dir() + Vector3.UP * 0.5 if is_instance_valid(c) else Vector3.UP, {"n": 22, "spread": 55.0, "vmin": 3.0, "vmax": 7.0, "life": 0.6, "smin": 0.12, "smax": 0.24, "r": 0.6, "foam": 0.2}))
	var md = c.get("model")
	var hidden = []
	if md and "weapons" in md:
		for w in md.weapons:
			if String(w.get("id", "")) == "bashosen" and is_instance_valid(w["node"]) and w["node"].visible:
				w["node"].visible = false
				hidden.append(w["node"])
	pj.after(1.9, func():
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root)
		root.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root, pj.hand_pos(c, true))
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root):
			root.queue_free())
	if c is Player:
		c.chakra = maxf(0.0, c.chakra - c.max_chakra * 0.15)
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Bashōsen chakranı emiyor!", Color(0.95, 0.85, 0.5))
	pj.busy(c, 1.1)
	pj.anim(c, "slash_a", 1.0)
	return root
