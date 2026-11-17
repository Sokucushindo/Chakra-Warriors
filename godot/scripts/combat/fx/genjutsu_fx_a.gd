class_name GenjutsuFXA
extends RefCounted
## Genjutsu grubu A: Narakumi, Mugen Onsa, Kokoni Arazu, Utakata, Genjutsu Tsūshin, Uchi Naru Sakura, Nijū Kokoni Arazu,
## Jigoku Kōka, Genjutsu Shibari, Suzune Bunshin, Sōsai no Ne, Jigyaku, Kori Shinchū, Gamarinshō, Makyō no Ran.
## Genjutsu = algı bozulması: efektler kurbanın çevresinde (yanılsama nesneleri: yaprak hortumu, ses kazıkları, bambu
## korusu, alev güneşi, dev gölgeler, sahte ay, kurbağa korosu...), ekran kenarı kararması yalnız oyuncu büyücü / kurban
## olduğunda ve ekranın ortası hep açık; her yanılsamanın bir "kai" (çözülme) anı var. Kameraya yakın kısımlar söner.
## Tüm görseller bu dosyada sıfırdan (kendi shader'ları, kendi parçacık sürüsü, kendi şerit / halka / parıltı yapı taşları).
## Oyunun gerçek sistemleri aynen: decoy (gölge kopya), durumlar (stun / slow / fear), lose_target, Buffs, Doki çağrısı,
## yaşlı kurbağa modeli (_elder_toad), Mateki flütü (hold_temp). Oynanış ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}


# ================================================================== küçük yardımcılar
static func _h(n: Node3D) -> float:
	if n == null or not is_instance_valid(n) or n.get("height") == null:
		return 1.8
	return float(n.get("height"))


static func _sp(m: ShaderMaterial, key: String) -> Callable:
	return func(x): m.set_shader_parameter(key, x)


## +Z ekseni dir'e bakan yatay taban
static func _face_basis(dir: Vector3) -> Basis:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		d = Vector3.BACK
	return Basis.looking_at(-d.normalized(), Vector3.UP)


static func _scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


# ================================================================== malzemeler
static func _std(key: String, add: bool, near_a := 0.3, near_b := 1.5) -> StandardMaterial3D:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = near_a
	m.distance_fade_max_distance = near_b
	_cache[k] = m
	return m


## İç ses silueti: siyah dolgu / beyaz kontur kabuğu (ters yüz)
static func _ink_mat(white: bool) -> StandardMaterial3D:
	var k = "mat:ink_w" if white else "mat:ink_b"
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1) if white else Color(0.02, 0.015, 0.03)
	if white:
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = 0.035
	_cache[k] = m
	return m


static func _shader(key: String, code: String) -> Shader:
	var k = "sh:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code
		_cache[k] = s
	return _cache[k]


static func _smat(sh: Shader, params: Dictionary) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


const _NOISE := """
float gh3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float gvn(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(gh3(i), gh3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(gh3(i + vec3(0.0, 1.0, 0.0)), gh3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(gh3(i + vec3(0.0, 0.0, 1.0)), gh3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(gh3(i + vec3(0.0, 1.0, 1.0)), gh3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
"""

## tam kamera yüzlü (ölçek korunur)
const _BILL := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""

## yalnız Y ekseninde kameraya döner (dikey perde)
const _BILLY := """
	vec3 bo = MODEL_MATRIX[3].xyz;
	vec3 bf = INV_VIEW_MATRIX[3].xyz - bo;
	bf.y = 0.0;
	bf = length(bf) > 0.001 ? normalize(bf) : vec3(0.0, 0.0, 1.0);
	vec3 br = normalize(cross(vec3(0.0, 1.0, 0.0), bf));
	float bsx = length(MODEL_MATRIX[0].xyz);
	float bsy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(br * bsx, 0.0), vec4(0.0, bsy, 0.0, 0.0), vec4(bf, 0.0), vec4(bo, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""


## İnce halka / yay / çiçek halka (ses dalgası, zil yayı, zaman halkası). bill: kameraya döner; ontop: yüzün önünde görünür
static func _ring_sh(bill: bool, add: bool, ontop := false) -> Shader:
	var key = "ring_%d%d%d" % [int(bill), int(add), int(ontop)]
	if _cache.has("sh:" + key):
		return _cache["sh:" + key]
	var code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, %s%s;\n" % ["blend_add" if add else "blend_mix", ", depth_test_disabled" if ontop else ""]
	code += """
uniform vec4 u_col : source_color = vec4(1.0);
uniform vec4 u_hot : source_color = vec4(1.0);
uniform float u_rad = 0.9;
uniform float u_wid = 0.04;
uniform float u_dbl = 0.0;
uniform float u_lobes = 0.0;
uniform float u_lamp = 0.0;
uniform float u_phase = 0.0;
uniform float u_wave = 0.0;
uniform float u_arc = 1.0;
uniform float u_arc0 = 0.0;
uniform float u_alpha = 1.0;
uniform float u_near = 1.4;
void vertex() {
""" + (_BILL if bill else "") + """
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float rr = u_rad * (1.0 + u_lamp * sin(a * u_lobes + u_phase) + u_wave * 0.025 * sin(a * 17.0 + TIME * 11.0));
	float w = max(u_wid, 0.002);
	float r1 = 1.0 - smoothstep(0.0, w, abs(d - rr));
	float r2 = u_dbl * (1.0 - smoothstep(0.0, w * 0.7, abs(d - rr * 0.84)));
	float ang01 = fract((a + 3.14159265) / 6.28318531 - u_arc0);
	float am = 1.0;
	if (u_arc < 0.999) {
		am = smoothstep(0.0, 0.04, ang01) * (1.0 - smoothstep(max(u_arc - 0.06, 0.0), u_arc, ang01));
	}
	float m = max(r1, r2) * am;
	float core = 1.0 - smoothstep(0.0, w * 0.35, abs(d - rr));
	ALBEDO = mix(u_col.rgb, u_hot.rgb, core);
	ALPHA = clamp(m * u_alpha * u_col.a, 0.0, 1.0) * smoothstep(u_near * 0.3, u_near, -VERTEX.z);
}
"""
	return _shader(key, code)


## Yumuşak parıltı diski; u_disk > 0: keskin kenarlı dolunay + hale; u_star > 0: dört köşeli yıldız (göz parıltısı)
static func _glow_sh(bill: bool, add: bool) -> Shader:
	var key = "glow_%d%d" % [int(bill), int(add)]
	if _cache.has("sh:" + key):
		return _cache["sh:" + key]
	var code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, %s;\n" % ("blend_add" if add else "blend_mix")
	code += """
uniform vec4 u_col : source_color = vec4(1.0);
uniform vec4 u_core : source_color = vec4(1.0);
uniform float u_alpha = 1.0;
uniform float u_soft = 1.5;
uniform float u_disk = 0.0;
uniform float u_star = 0.0;
uniform float u_near = 1.2;
void vertex() {
""" + (_BILL if bill else "") + """
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float m = pow(clamp(1.0 - d, 0.0, 1.0), u_soft);
	float core = pow(clamp(1.0 - d * 2.0, 0.0, 1.0), 1.5);
	if (u_disk > 0.0) {
		float dk = 1.0 - smoothstep(u_disk - 0.02, u_disk, d);
		m = max(dk, m * 0.55);
		core = dk;
	}
	if (u_star > 0.0) {
		float s = clamp(1.0 - abs(p.x * p.y) * 60.0 - d * 0.9, 0.0, 1.0);
		m = max(s, m * 0.35);
		core = s;
	}
	ALBEDO = mix(u_col.rgb, u_core.rgb, core);
	ALPHA = clamp(m * u_alpha * u_col.a, 0.0, 1.0) * smoothstep(u_near * 0.3, u_near, -VERTEX.z);
}
"""
	return _shader(key, code)


## Ekran dokusunu büken titreşim (serap / yanılsama perdesi). ybill: dikey perde; değilse yatay (u_ring = 1: halka maske)
static func _shim_sh(ybill: bool) -> Shader:
	var key = "shim_%d" % int(ybill)
	if _cache.has("sh:" + key):
		return _cache["sh:" + key]
	var code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, blend_mix;\n"
	code += """
uniform sampler2D u_scr : hint_screen_texture, filter_linear_mipmap;
uniform float u_amt = 0.02;
uniform float u_alpha = 1.0;
uniform vec4 u_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float u_band = 30.0;
uniform float u_ring = 0.0;
uniform float u_rad = 0.7;
uniform float u_near = 1.6;
void vertex() {
""" + (_BILLY if ybill else "") + """
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = 1.0 - smoothstep(0.5, 1.0, length(p * vec2(1.0, 0.9)));
	if (u_ring > 0.5) {
		m = 1.0 - smoothstep(0.0, 0.2, abs(length(p) - u_rad));
	}
	vec2 off = vec2(sin(UV.y * u_band + TIME * 7.0), cos(UV.x * u_band * 0.7 + TIME * 5.3)) * u_amt * m;
	vec3 sc = textureLod(u_scr, SCREEN_UV + off, 0.0).rgb;
	ALBEDO = mix(sc, u_tint.rgb, u_tint.a * m);
	ALPHA = clamp(m * u_alpha, 0.0, 1.0) * smoothstep(u_near * 0.3, u_near, -VERTEX.z);
}
"""
	return _shader(key, code)


## Hayalet dev: koyu yarı saydam dolgu + parlak kenar; u_cut yukarıdan aşağı parlak kenarlı çözülme
static func _ghost_sh() -> Shader:
	return _shader("ghost", """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
uniform vec4 u_fill : source_color = vec4(0.2, 0.0, 0.05, 0.5);
uniform vec4 u_rim : source_color = vec4(1.0, 0.3, 0.4, 0.9);
uniform float u_alpha = 1.0;
uniform float u_cut = 0.0;
uniform float u_h = 4.0;
uniform float u_near = 2.5;
varying float v_y;
varying vec3 v_p;
""" + _NOISE + """
void vertex() {
	v_y = VERTEX.y / u_h;
	v_p = VERTEX;
}
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float n = gvn(v_p * 2.5 + vec3(0.0, -TIME * 0.7, 0.0));
	float lv = 1.0 - v_y + (n - 0.5) * 0.35;
	float keep = smoothstep(u_cut - 0.04, u_cut + 0.04, lv);
	float band = (u_cut > 0.001) ? (1.0 - smoothstep(0.0, 0.07, abs(lv - u_cut))) : 0.0;
	ALBEDO = mix(u_fill.rgb, u_rim.rgb, clamp(fr + band, 0.0, 1.0));
	ALPHA = clamp((u_fill.a + fr * u_rim.a + band) * keep * u_alpha, 0.0, 1.0) * smoothstep(u_near * 0.3, u_near, -VERTEX.z);
}
""")


## Cehennem güneşi: kaynayan cel alev bantları (kırmızı kenar → turuncu → sarı çekirdek), pütürlü kenar
static func _sun_sh() -> Shader:
	return _shader("sun", """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
uniform float u_alpha = 1.0;
uniform float u_near = 6.0;
uniform float u_heat = 1.0;
varying vec3 v_p;
""" + _NOISE + """
void vertex() {
	v_p = VERTEX;
	float n = gvn(VERTEX * 3.0 + vec3(0.0, TIME * 1.2, 0.0));
	VERTEX += NORMAL * (n - 0.5) * 0.16;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 q = v_p * 2.2 + vec3(0.0, -TIME * 0.5, TIME * 0.2);
	float n = gvn(q) * 0.6 + gvn(q * 2.3) * 0.3 + gvn(q * 5.1) * 0.1;
	float v = n * 0.85 + (1.0 - fr) * 0.45 - 0.15;
	vec3 c = vec3(0.62, 0.08, 0.03);
	c = mix(c, vec3(0.95, 0.32, 0.05), step(0.38, v));
	c = mix(c, vec3(1.0, 0.62, 0.12), step(0.52, v));
	c = mix(c, vec3(1.0, 0.9, 0.45), step(0.68, v));
	c = mix(c, vec3(0.35, 0.05, 0.02), step(0.9, fr));
	ALBEDO = c * u_heat;
	ALPHA = clamp(u_alpha, 0.0, 1.0) * smoothstep(u_near * 0.4, u_near, -VERTEX.z);
}
""")


## Karşı ses kabarcığı: yalnız kenarda görünen ince eş merkezli dalga (içi boş, içeriden görünmez)
static func _bubble_sh() -> Shader:
	return _shader("bubble", """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;
uniform vec4 u_col : source_color = vec4(0.85, 0.97, 0.9, 1.0);
uniform float u_alpha = 1.0;
uniform float u_ph = 0.0;
uniform float u_near = 2.0;
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(fr, 3.0);
	float band = 0.5 + 0.5 * sin(fr * 26.0 - TIME * 8.0 + u_ph);
	ALBEDO = u_col.rgb;
	ALPHA = clamp((edge * 0.75 + band * edge * 0.35) * u_alpha * u_col.a, 0.0, 1.0) * smoothstep(u_near * 0.3, u_near, -VERTEX.z);
}
""")


## Ekran kenarı kararması (yalnız oyuncu büyücü / kurban): orta hep açık, kenar dalgalı
static func _vig_sh() -> Shader:
	return _shader("vig", """
shader_type canvas_item;
uniform vec4 u_col : source_color = vec4(0.3, 0.1, 0.4, 0.5);
uniform float u_amt = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.6;
	float a = atan(p.y, p.x);
	float d = length(p) + sin(a * 7.0 + TIME * 2.0) * 0.012;
	float m = smoothstep(0.45, 0.88, d);
	COLOR = vec4(u_col.rgb, u_col.a * m * u_amt);
}
""")


# ================================================================== ağlar
static func _qmesh(bill: bool) -> Mesh:
	var k = "mesh:quad" if bill else "mesh:plane"
	if not _cache.has(k):
		if bill:
			var q = QuadMesh.new()
			q.size = Vector2(2, 2)
			_cache[k] = q
		else:
			var p = PlaneMesh.new()
			p.size = Vector2(2, 2)
			_cache[k] = p
	return _cache[k]


static func _mk(mat: Material, bill: bool) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _qmesh(bill)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 3.0
	return mi


## Yaprak: sivri uçlu, ortasında koyu damar
static func _leaf_mesh() -> ArrayMesh:
	var k = "mesh:leaf"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 6
	var top = []
	var mid = []
	var bot = []
	for i in seg + 1:
		var x = float(i) / float(seg) - 0.5
		var w = 0.2 * pow(sin(PI * (x + 0.5)), 0.8)
		top.append(Vector3(x, w, 0.0))
		mid.append(Vector3(x, 0.0, 0.025 * sin(PI * (x + 0.5))))
		bot.append(Vector3(x, -w, 0.0))
	var edge = Color(1, 1, 1)
	var rib = Color(0.6, 0.68, 0.52)
	for i in seg:
		_tri(st, top[i], top[i + 1], mid[i + 1], edge, edge, rib)
		_tri(st, top[i], mid[i + 1], mid[i], edge, rib, rib)
		_tri(st, mid[i], mid[i + 1], bot[i + 1], rib, rib, edge)
		_tri(st, mid[i], bot[i + 1], bot[i], rib, edge, edge)
	var m = st.commit()
	_cache[k] = m
	return m


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Düz çokgen (yırtık kâğıt / kırık kabuk parçası), merkezden yelpaze
static func _poly_mesh(key: String, pts: Array, c_mid: Color, c_edge: Color) -> ArrayMesh:
	var k = "mesh:" + key
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		_tri(st, Vector3.ZERO, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), c_mid, c_edge, c_edge)
	var m = st.commit()
	_cache[k] = m
	return m


static func _paper_mesh() -> ArrayMesh:
	return _poly_mesh("paper", [Vector2(-0.5, -0.4), Vector2(-0.1, -0.52), Vector2(0.12, -0.38), Vector2(0.5, -0.12), Vector2(0.38, 0.2),
		Vector2(0.42, 0.48), Vector2(-0.05, 0.4), Vector2(-0.22, 0.52), Vector2(-0.46, 0.12)], Color(1, 1, 1), Color(0.86, 0.84, 0.8))


static func _shard_mesh() -> ArrayMesh:
	return _poly_mesh("shard", [Vector2(-0.3, -0.5), Vector2(0.36, -0.28), Vector2(0.05, 0.62)], Color(1, 1, 1), Color(0.7, 0.7, 0.75))


static func _cube_mesh() -> Mesh:
	if not _cache.has("mesh:cube"):
		var b = BoxMesh.new()
		b.size = Vector3.ONE
		_cache["mesh:cube"] = b
	return _cache["mesh:cube"]


static func _mote_mesh() -> Mesh:
	if not _cache.has("mesh:mote"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 6
		s.rings = 3
		_cache["mesh:mote"] = s
	return _cache["mesh:mote"]


static func _sphere_mesh() -> Mesh:
	if not _cache.has("mesh:sphere"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 40
		s.rings = 20
		_cache["mesh:sphere"] = s
	return _cache["mesh:sphere"]


# ================================================================== yapı taşları
## Parçacık sürüsü (tek MultiMesh): fn(i, u) -> [Transform3D, Color], u 0..1 (dur boyunca), her kare
static func _swarm(pj: PathJutsu, mesh: Mesh, mat: Material, n: int, dur: float, fn: Callable) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(pj).add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	var upd = func(u: float) -> void:
		for i in n:
			var r: Array = fn.call(i, u)
			mm.set_instance_transform(i, r[0])
			mm.set_instance_color(i, r[1])
	upd.call(0.0)
	var tw = mmi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_callback(mmi.queue_free)
	return mmi


## Kamera yüzlü şerit: pts_fn(u) -> PackedVector3Array, col_fn(u, s) -> Color (s: şerit boyunca 0..1)
static func _ribbon(pj: PathJutsu, dur: float, w: float, pts_fn: Callable, col_fn: Callable, add := true) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _std("rib_add" if add else "rib_mix", add, 0.3, 1.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(pj).add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var upd = func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		im.clear_surfaces()
		var pts: PackedVector3Array = pts_fn.call(u)
		var n = pts.size()
		if n < 2:
			return
		var cam = mi.get_viewport().get_camera_3d()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var p: Vector3 = pts[i]
			var dd: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			var vd: Vector3 = (cam.global_position - p) if cam else Vector3.BACK
			var sd: Vector3 = dd.cross(vd)
			sd = sd.normalized() if sd.length() > 0.0001 else Vector3.UP
			var s = float(i) / float(n - 1)
			var col: Color = col_fn.call(u, s)
			im.surface_set_color(col)
			im.surface_add_vertex(p + sd * w * 0.5)
			im.surface_set_color(col)
			im.surface_add_vertex(p - sd * w * 0.5)
		im.surface_end()
	upd.call(0.0)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)
	return mi


static func _ring_mat(bill: bool, add: bool, col: Color, hot: Color, extra := {}, ontop := false) -> ShaderMaterial:
	var m = _smat(_ring_sh(bill, add, ontop), {"u_col": col, "u_hot": hot, "u_rad": 0.9})
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


## Genişleyen ince halka (çizgi kalınlığı metre cinsinden sabit kalır); r0 > r1 ise daralır
static func _ring_wave(pj: PathJutsu, pos: Vector3, rot: Vector3, bill: bool, add: bool, col: Color, hot: Color, r0: float, r1: float, line_m: float, life: float, extra := {}) -> MeshInstance3D:
	var m = _ring_mat(bill, add, col, hot, extra)
	var mi = _mk(m, bill)
	pj.scene_add(mi, pos)
	mi.rotation = rot
	var a0: float = float(extra.get("u_alpha", 1.0))
	var upd = func(u: float) -> void:
		var r = lerpf(r0, r1, 1.0 - pow(1.0 - u, 2.2))
		var s = maxf(0.01, r / 0.9)
		mi.scale = Vector3(s, s, s)
		m.set_shader_parameter("u_wid", clampf(line_m / s, 0.002, 0.5))
		m.set_shader_parameter("u_alpha", a0 * pow(1.0 - u, 1.4) * clampf(u / 0.08, 0.0, 1.0))
	upd.call(0.0)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Parıltı diski: life > 0 ise kendi açılıp söner (amax'a kadar)
static func _glow(pj: PathJutsu, pos: Vector3, size: float, bill: bool, add: bool, col: Color, core: Color, life: float, amax := 1.0, extra := {}) -> MeshInstance3D:
	var m = _smat(_glow_sh(bill, add), {"u_col": col, "u_core": core, "u_alpha": 0.0 if life > 0.0 else amax})
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	var mi = _mk(m, bill)
	pj.scene_add(mi, pos)
	mi.scale = Vector3.ONE * size
	if life > 0.0:
		var tin = minf(0.25, life * 0.3)
		var tout = minf(0.5, life * 0.4)
		var tw = mi.create_tween()
		tw.tween_method(_sp(m, "u_alpha"), 0.0, amax, tin)
		tw.tween_interval(maxf(0.0, life - tin - tout))
		tw.tween_method(_sp(m, "u_alpha"), amax, 0.0, tout)
		tw.tween_callback(mi.queue_free)
	return mi


## Serap perdesi: ybill dikey perde (sx genişlik, sy yükseklik), değilse yerde (ring: halka maske). life <= 0: elle yönetilir
static func _shimmer(pj: PathJutsu, pos: Vector3, ybill: bool, ring: bool, sx: float, sy: float, amt: float, tint: Color, life: float) -> MeshInstance3D:
	var m = _smat(_shim_sh(ybill), {"u_amt": amt, "u_tint": tint, "u_ring": 1.0 if ring else 0.0, "u_alpha": 0.0 if life > 0.0 else 1.0})
	var mi = _mk(m, ybill)
	pj.scene_add(mi, pos)
	mi.scale = Vector3(sx, sy, 1.0) if ybill else Vector3(sx, 1.0, sx)
	if life > 0.0:
		var tw = mi.create_tween()
		tw.tween_method(_sp(m, "u_alpha"), 0.0, 1.0, minf(0.2, life * 0.25))
		tw.tween_interval(maxf(0.0, life - 0.6))
		tw.tween_method(_sp(m, "u_alpha"), 1.0, 0.0, minf(0.4, life * 0.4))
		tw.tween_callback(mi.queue_free)
	return mi


## Küçük toz / kıvılcım kümesi (yavaşlayarak dağılır, up > 0 yükselir, < 0 düşer)
static func _motes(pj: PathJutsu, at: Vector3, n: int, c0: Color, c1: Color, life: float, spd: float, up: float, size: float, add := true) -> void:
	var seeds := []
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		seeds.append([d * randf_range(0.4, 1.0) * spd, randf_range(0.6, 1.2)])
	var fn = func(i: int, u: float) -> Array:
		var sd: Array = seeds[i]
		var el = u * life
		var drag = (1.0 - exp(-el * 3.0)) / 3.0
		var p: Vector3 = at + (sd[0] as Vector3) * drag + Vector3.UP * up * el * el * 0.5
		var s = size * float(sd[1]) * (1.0 - u * 0.6)
		var col = c0.lerp(c1, u)
		col.a *= (1.0 - u)
		return [Transform3D(Basis.from_scale(Vector3.ONE * s), p), col]
	_swarm(pj, _mote_mesh(), _std("mote_add" if add else "mote_mix", add), n, life, fn)


## Ekran kenarı kararması — yalnız oyuncu bu genjutsunun büyücüsü / kurbanıyken çağrılır; orta hep açık kalır
static func _vignette(pj: PathJutsu, col: Color, dur: float, amt: float) -> void:
	var cl = CanvasLayer.new()
	cl.layer = -1
	var cr = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = _smat(_vig_sh(), {"u_col": col, "u_amt": 0.0})
	cr.material = m
	cl.add_child(cr)
	_scene(pj).add_child(cl)
	var tin = minf(0.25, dur * 0.3)
	var tw = cr.create_tween()
	tw.tween_method(_sp(m, "u_amt"), 0.0, amt, tin)
	tw.tween_interval(maxf(0.0, dur - tin - 0.3))
	tw.tween_method(_sp(m, "u_amt"), amt, 0.0, 0.3)
	tw.tween_callback(cl.queue_free)


# ================================================================== 1) Magen: Narakumi
## Kanon (Kakashi'nin cehennem görüntüsü): kurbanın etrafında yapraklar toplanıp dev bir hortuma döner, kâbusu görürken
## yapraklar sarar; kai anında hortum dışa savrulup yere dökülür. Mekanik: Jutsu.j_narakumi aynen (stun 3 + fear 3).
static func narakumi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt:
		_leaf_vortex(pj, tt)
	if c is Player:
		_vignette(pj, Color(0.3, 0.12, 0.38, 0.45), 1.0, 0.6)
	# --- Jutsu.j_narakumi
	if t == null:
		return
	Sfx.play("genjutsu", t.global_position)
	if t.has_method("apply_status"):
		t.apply_status("stun", 3.0)
		t.apply_status("fear", 3.0)
	if t == Game.player:
		_vignette(pj, Color(0.16, 0.05, 0.2, 0.6), 3.0, 1.0)


static func _leaf_vortex(pj: PathJutsu, v: Node3D) -> void:
	var n := 150
	var dur := 3.6
	var h := _h(v)
	var bs := ClanJutsu.body_scale(v)
	var wv = weakref(v)
	var anchor := {"p": v.global_position}
	var seeds := []
	for i in n:
		seeds.append([randf() * TAU, randf(), randf_range(0.6, 1.4), randi() % 4, randf_range(0.2, 0.36)])
	var greens := [Color(0.16, 0.36, 0.14), Color(0.3, 0.55, 0.2), Color(0.47, 0.7, 0.3), Color(0.09, 0.22, 0.1)]
	var fn = func(i: int, u: float) -> Array:
		if i == 0:
			var vv = wv.get_ref()
			if vv != null and is_instance_valid(vv):
				anchor["p"] = vv.global_position
		var sd: Array = seeds[i]
		var el: float = u * dur
		# toplanma (geniş halkadan içe sarmal) → sıkı hortum → kai: dışa savrulup düşer
		var gather := clampf(el / 0.6, 0.0, 1.0)
		var burst := clampf((el - 2.9) / 0.7, 0.0, 1.0)
		var ang: float = float(sd[0]) + el * 5.0 * float(sd[2]) * (1.0 - burst * 0.5)
		var r: float = (lerpf(6.5 + float(sd[1]) * 2.5, 0.8 + float(sd[1]) * 1.4, ease(gather, 0.5)) + burst * (2.5 + float(sd[1]) * 3.5)) * bs
		var y: float = (lerpf(0.15 + float(sd[1]) * 0.6, 0.2 + float(sd[1]) * h * 1.9, gather) + sin(el * 3.0 + float(sd[0])) * 0.25) * bs - burst * burst * float(sd[1]) * 2.2
		var p: Vector3 = anchor["p"] + Vector3(cos(ang) * r, maxf(0.05, y), sin(ang) * r)
		var bas := Basis.from_euler(Vector3(el * 3.0 * float(sd[2]) + float(sd[0]), -ang, sin(el * 4.0 + float(sd[0])) * 1.2)).scaled(Vector3.ONE * float(sd[4]) * bs)
		var col: Color = greens[int(sd[3])]
		col.a = clampf(el / 0.15, 0.0, 1.0) * (1.0 - burst * burst)
		return [Transform3D(bas, p), col]
	_swarm(pj, _leaf_mesh(), _std("leaf", false, 0.4, 1.6), n, dur, fn)
	pj.after(dur - 0.15, func(): _fallen_leaves(pj, anchor["p"], bs))


## Kai sonrası yere düşmüş yapraklar yavaşça solar
static func _fallen_leaves(pj: PathJutsu, center: Vector3, bs: float) -> void:
	var xs := []
	var cs := []
	var greens := [Color(0.16, 0.36, 0.14), Color(0.3, 0.55, 0.2), Color(0.47, 0.7, 0.3)]
	for i in 26:
		var a = randf() * TAU
		var r = randf_range(0.4, 3.6) * bs
		var p = pj.gp(center + Vector3(cos(a) * r, 0, sin(a) * r)) + Vector3.UP * 0.03
		var bas = (Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * randf_range(0.2, 0.32) * bs)
		xs.append(Transform3D(bas, p))
		cs.append(greens[i % 3])
	var fn = func(i: int, u: float) -> Array:
		var col: Color = cs[i]
		col.a = 1.0 - smoothstep(0.55, 1.0, u)
		return [xs[i], col]
	_swarm(pj, _leaf_mesh(), _std("leaf", false, 0.4, 1.6), 26, 2.8, fn)


# ================================================================== 2) Mateki: Mugen Onsa
## Kanon (Tayuya, ref: kızıl dünya + ucunda ses halkası titreşen ince kazıklar): flüt ezgisi kızıl çift halkalar halinde
## yayılır; duyanların çevresine gökten ince ses kazıkları saplanır, her birinin tepesinde halka titrer, kazıklardan kurbana
## gergin kızıl teller uzanır. 3 sn sonra kazıklar çekilir (kai).
static func mateki_mugen_onsa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var red = Color(0.9, 0.2, 0.25)
	var m = c.get("model")
	if m and m.has_method("hold_temp"):
		m.hold_temp("mateki", 1.2, "Right", 1.0)
	for k in 5:
		pj.after(k * 0.12, func():
			if pj.live(c):
				_sound_ripple(pj, c, k))
	pj.after(0.5, func():
		if not is_instance_valid(c):
			return
		for e in pj.enemies_near(c, c.global_position, 16.0):
			pj.st(e, "stun", 3.0)
			_sound_stakes(pj, e, 3.0)
			Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Ses zinciri!", red))
	Sfx.play("genjutsu", c.global_position, 1.6)


static func _sound_ripple(pj: PathJutsu, c: Node3D, k: int) -> void:
	var red := Color(0.92, 0.18, 0.24)
	var o: Vector3 = c.global_position + Vector3.UP * 1.4
	_ring_wave(pj, o, Vector3.ZERO, false, true, red, Color(1, 0.8, 0.75), 0.4, 4.0 + k * 3.0, 0.07, 0.55, {"u_dbl": 1.0, "u_lobes": 7.0, "u_lamp": 0.035, "u_wave": 1.0})
	if k % 2 == 0:
		_ring_wave(pj, o + c.face_dir() * 0.4, Vector3.ZERO, true, true, red, Color(1, 0.85, 0.8), 0.15, 1.1, 0.035, 0.4, {"u_dbl": 1.0})


static func _rod_mesh() -> ArrayMesh:
	var k = "mesh:rod"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("cyl", Vector3(0, 0.5, 0), Vector3(0.05, 1.0, 0.05), Color(0.26, 0.12, 0.14), Vector3.ZERO, 6)
	b.add("cone", Vector3(0, -0.04, 0), Vector3(0.05, 0.08, 0.05), Color(0.2, 0.1, 0.12), Vector3(180, 0, 0), 6)
	var m = b.build(null)
	_cache[k] = m
	return m


static func _sound_stakes(pj: PathJutsu, e: Node3D, dur: float) -> void:
	var bs := ClanJutsu.body_scale(e)
	var base: Vector3 = pj.gp(e.global_position)
	var we = weakref(e)
	var chest = func() -> Vector3:
		var x = we.get_ref()
		if x != null and is_instance_valid(x):
			return x.global_position + Vector3.UP * _h(x) * 0.6
		return base + Vector3.UP * 1.0
	# kurbanın gördüğü dünya kızıla döner: ayağının altında kızıl leke
	_glow(pj, base + Vector3.UP * 0.04, 3.4 * bs, false, false, Color(0.7, 0.04, 0.08, 0.5), Color(0.95, 0.2, 0.22, 0.6), dur + 0.3, 0.8, {"u_soft": 0.8})
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.25, 0.25)
		var rr = randf_range(1.8, 3.0) * bs
		var foot: Vector3 = pj.gp(base + Vector3(cos(a) * rr, 0, sin(a) * rr))
		var away: Vector3 = (foot - base).normalized()
		var axis: Vector3 = (Vector3.UP + away * randf_range(0.12, 0.4)).normalized()
		var L = randf_range(4.0, 5.5) * bs
		pj.after(k * 0.05, func(): _stake(pj, foot, axis, L, dur - k * 0.05, chest, bs))
	if e == Game.player:
		_vignette(pj, Color(0.75, 0.05, 0.1, 0.55), dur, 0.9)


## Tek ses kazığı: gökten düşüp saplanır, tepesinde halka titrer, kurbana gergin tel uzanır; sonunda yukarı çekilir
static func _stake(pj: PathJutsu, foot: Vector3, axis: Vector3, L: float, life: float, chest: Callable, bs: float) -> void:
	var rod = MeshInstance3D.new()
	rod.mesh = _rod_mesh()
	rod.material_override = _std("rod", false, 0.3, 1.2)
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(rod, foot + axis * 9.0)
	rod.basis = Basis(Quaternion(Vector3.UP, axis)) * Basis.from_scale(Vector3(bs, L, bs))
	var tw = rod.create_tween()
	tw.tween_property(rod, "global_position", foot, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_ring_wave(pj, foot + Vector3.UP * 0.05, Vector3.ZERO, false, true, Color(0.9, 0.2, 0.25), Color(1, 0.8, 0.8), 0.1, 0.8 * bs, 0.04, 0.3))
	tw.tween_interval(maxf(0.1, life - 0.45))
	tw.tween_property(rod, "global_position", foot + axis * 9.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rod, "transparency", 1.0, 0.28)
	tw.tween_callback(rod.queue_free)
	# tepedeki titreşen halka
	var top: Vector3 = foot + axis * L
	var rm = _ring_mat(true, true, Color(0.95, 0.3, 0.35, 0.9), Color(1, 0.85, 0.85), {"u_dbl": 1.0})
	var ring = _mk(rm, true)
	pj.scene_add(ring, top)
	var rupd = func(u: float) -> void:
		var el = u * life
		var f = fposmod(el * 1.6, 1.0)
		var s = (0.25 + f * 0.35) * bs
		ring.scale = Vector3.ONE * s
		rm.set_shader_parameter("u_wid", 0.03 / maxf(s, 0.05))
		rm.set_shader_parameter("u_alpha", (1.0 - f) * clampf((el - 0.16) / 0.1, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, u)))
	rupd.call(0.0)
	var rt = ring.create_tween()
	rt.tween_method(rupd, 0.0, 1.0, life)
	rt.tween_callback(ring.queue_free)
	# gergin tel (titrer)
	var from: Vector3 = foot + axis * L * 0.82
	var pts_fn = func(u: float) -> PackedVector3Array:
		var el = u * life
		if el < 0.18:
			return PackedVector3Array()
		var b: Vector3 = chest.call()
		var out := PackedVector3Array()
		var side = (b - from).cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		for j in 6:
			var q = float(j) / 5.0
			out.append(from.lerp(b, q) + side * sin(q * PI) * sin(el * 45.0) * 0.03)
		return out
	var col_fn = func(u: float, _s: float) -> Color:
		return Color(0.95, 0.22, 0.28, 0.8 * (1.0 - smoothstep(0.85, 1.0, u)))
	_ribbon(pj, life, 0.035, pts_fn, col_fn)


# ================================================================== 3) Magen: Kokoni Arazu no Jutsu
## Kanon (sahte çevre; ref: "301" levhasının "201"e dönüşmesi — gerçek yer gizlenir): büyücü sarı-yeşil bir serap
## titreşimiyle çevreye karışıp kaybolur, yerde serap halkası yayılır, kopyanın durduğu yerde dikey bir bükülme yarığı
## açılıp yanılsama belirir. 5 sn sonra görünürken serap yeniden toplanıp dağılır (kai).
static func magen_kokoni_arazu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_mirage(pj, c)
	# --- c_magen_kokoni_arazu_no_jutsu
	pj.decoy(c, c.global_position + c.face_dir() * 2.0, 8.0)
	if c.get("model"):
		c.model.visible = false
		pj.after(5.0, func():
			if is_instance_valid(c):
				c.model.visible = true
				_mirage_release(pj, c))
	Sfx.play("genjutsu", c.global_position, 1.3)


static func _mirage(pj: PathJutsu, c: Node3D) -> void:
	var at: Vector3 = c.global_position
	var fd: Vector3 = c.face_dir()
	var tint := Color(0.85, 0.95, 0.5, 0.12)
	# büyücü titreşip çevreye karışır
	_shimmer(pj, at + Vector3.UP * 1.1, true, false, 0.9, 1.35, 0.03, tint, 1.1)
	# yerde yayılan serap halkası
	var g = _shimmer(pj, pj.gp(at) + Vector3.UP * 0.05, false, true, 1.0, 1.0, 0.025, Color(0.8, 0.95, 0.45, 0.1), 0.0)
	var gm := g.material_override as ShaderMaterial
	var gtw = g.create_tween()
	gtw.tween_property(g, "scale", Vector3(9.0, 1.0, 9.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gtw.parallel().tween_method(_sp(gm, "u_alpha"), 1.0, 0.0, 0.9)
	gtw.tween_callback(g.queue_free)
	# kopya noktasında açılan dikey yarık
	var dp: Vector3 = pj.gp(at + fd * 2.0)
	var seam = _shimmer(pj, dp + Vector3.UP * 1.05, true, false, 0.03, 1.3, 0.04, Color(0.95, 1.0, 0.75, 0.3), 0.0)
	var sm := seam.material_override as ShaderMaterial
	var stw = seam.create_tween()
	stw.tween_property(seam, "scale", Vector3(1.0, 1.3, 1.0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stw.tween_method(_sp(sm, "u_alpha"), 1.0, 0.0, 0.5)
	stw.tween_callback(seam.queue_free)
	var line_pts = func(u: float) -> PackedVector3Array:
		return PackedVector3Array([dp + Vector3.UP * 0.05, dp + Vector3.UP * (0.4 + 1.9 * minf(1.0, u * 3.0))])
	var line_col = func(u: float, s: float) -> Color:
		return Color(0.95, 1.0, 0.7, 0.9 * (1.0 - u) * sin(s * PI))
	_ribbon(pj, 0.35, 0.05, line_pts, line_col)
	if c is Player:
		_vignette(pj, Color(0.7, 0.85, 0.35, 0.35), 1.2, 0.6)


## Kai: görünürken serap yeniden toplanıp dağılır
static func _mirage_release(pj: PathJutsu, c: Node3D) -> void:
	var at: Vector3 = c.global_position
	_shimmer(pj, at + Vector3.UP * 1.1, true, false, 0.95, 1.4, 0.04, Color(0.9, 1.0, 0.6, 0.2), 0.6)
	var g = _shimmer(pj, pj.gp(at) + Vector3.UP * 0.05, false, true, 0.5, 1.0, 0.03, Color(0.85, 1.0, 0.5, 0.12), 0.0)
	var gm := g.material_override as ShaderMaterial
	var tw = g.create_tween()
	tw.tween_property(g, "scale", Vector3(3.0, 1.0, 3.0), 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_sp(gm, "u_alpha"), 1.0, 0.0, 0.5)
	tw.tween_callback(g.queue_free)
	if c is Player:
		_vignette(pj, Color(0.8, 0.95, 0.5, 0.3), 0.45, 0.6)


# ================================================================== 4) Utakata
## Göz temassız hafif genjutsu (ref: kurbanın yüzü yırtılan kâğıt gibi başka bir yüze dönüyor): başın önünde bükülme
## perdesi titrer, yüzü ortadan bölen kırık bir çizgi belirir, renkli yırtık kâğıt parçaları yüzden soyulup savrulur.
static func utakata(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.4)
	if tt == null:
		return
	_ephemeral_peel(pj, tt)
	pj.st(tt, "stun", 1.5)
	pj.st(tt, "slow", 3.0)
	Sfx.play("genjutsu", tt.global_position, 1.4)


static func _ephemeral_peel(pj: PathJutsu, v: Node3D) -> void:
	var h := _h(v)
	var bs := ClanJutsu.body_scale(v)
	var wv = weakref(v)
	var head := {"p": v.global_position + Vector3.UP * h * 0.88}
	# yüz perdesi (kurbanla birlikte gider)
	var vm = _smat(_shim_sh(true), {"u_amt": 0.025, "u_tint": Color(0.85, 0.75, 0.95, 0.14), "u_alpha": 0.0, "u_band": 44.0, "u_near": 1.0})
	var veil = _mk(vm, true)
	v.add_child(veil)
	veil.position = Vector3.UP * h * 0.88
	veil.scale = Vector3(0.55, 0.6, 1.0) * bs
	var vt = veil.create_tween()
	vt.tween_method(_sp(vm, "u_alpha"), 0.0, 1.0, 0.1)
	vt.tween_interval(1.3)
	vt.tween_method(_sp(vm, "u_alpha"), 1.0, 0.0, 0.3)
	vt.tween_callback(veil.queue_free)
	# soyulan kâğıt parçaları
	var n := 30
	var life := 1.9
	var seeds := []
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.5, 1.0), randf_range(-1, 1)).normalized()
		seeds.append([d, randf_range(0.0, 0.7), randf_range(0.6, 1.3), randi() % 4, randf_range(0.07, 0.13), randf() * TAU])
	var cols := [Color(0.97, 0.68, 0.66), Color(0.98, 0.86, 0.36), Color(0.96, 0.88, 0.76), Color(1, 1, 1)]
	var fn = func(i: int, u: float) -> Array:
		if i == 0:
			var vv = wv.get_ref()
			if vv != null and is_instance_valid(vv):
				head["p"] = vv.global_position + Vector3.UP * _h(vv) * 0.88
		var sd: Array = seeds[i]
		var el = u * life
		var peel = clampf((el - float(sd[1])) / 1.0, 0.0, 1.0)
		var d: Vector3 = sd[0]
		var fl = Vector3(sin(el * 7.0 + float(sd[5])), 0.0, cos(el * 6.0 + float(sd[5]))) * 0.06 * peel
		var p: Vector3 = head["p"] + d * (0.22 * bs + peel * peel * float(sd[2]) * bs) + Vector3.UP * (peel * 0.35 - peel * peel * 0.45) + fl
		var bas = Basis.from_euler(Vector3(el * 4.0 * float(sd[2]) * peel + float(sd[5]), float(sd[5]), el * 3.0 * peel)).scaled(Vector3.ONE * float(sd[4]) * bs)
		var col: Color = cols[int(sd[3])]
		col.a = clampf(el / 0.08, 0.0, 1.0) * (1.0 - smoothstep(0.6, 1.0, peel)) * (0.8 if peel <= 0.0 else 1.0)
		return [Transform3D(bas, p), col]
	_swarm(pj, _paper_mesh(), _std("paper", false, 0.3, 1.0), n, life, fn)
	# yüzü ortadan bölen kırık çizgi (kameraya bakan yüzün önünde)
	var jit := [0.0, 0.03, -0.025, 0.02, -0.03, 0.01]
	var crack_pts = func(u: float) -> PackedVector3Array:
		var vv = wv.get_ref()
		if vv == null or not is_instance_valid(vv):
			return PackedVector3Array()
		var cam = vv.get_viewport().get_camera_3d()
		var hb: Vector3 = vv.global_position
		var hh = _h(vv)
		var tc: Vector3 = (cam.global_position - hb) if cam else Vector3.BACK
		tc.y = 0.0
		tc = tc.normalized() if tc.length() > 0.01 else Vector3.BACK
		var sd = tc.cross(Vector3.UP).normalized()
		var out := PackedVector3Array()
		var grow = minf(1.0, u * 5.0)
		for j in jit.size():
			var q = float(j) / float(jit.size() - 1) * grow
			out.append(hb + Vector3.UP * hh * lerpf(0.99, 0.74, q) + tc * 0.2 * bs + sd * float(jit[j]) * bs)
		return out
	var crack_col = func(u: float, _s: float) -> Color:
		return Color(0.08, 0.06, 0.1, 0.9 * (1.0 - smoothstep(0.7, 1.0, u)))
	_ribbon(pj, 1.3, 0.03, crack_pts, crack_col, false)


# ================================================================== 5) Genjutsu Tsūshin
## Kanon (Boruto, ref: kapüşonlu kullanıcının önünde mavi parlak veri küplerinden yığın): yerden mavi-camgöbeği küpler
## kabarır, sarmal çizerek baş üstüne akar ve dağılır; bağlantı süresince başın çevresinde birkaç küp döner.
## Mekanik: motorun genel "utility" güçlendirmesi aynen (8 + kademe×2 sn, hız ×1.1, oyuncuya yazı).
static func genjutsu_tsushin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("genjutsu_tsushin", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	_data_link(pj, c, dur)
	Buffs.add(String(d.get("id", "buff")), dur, {"speed": 1.1})
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], Color(0.55, 0.75, 1.0))
	Sfx.play("seal", c.global_position, 0.8)


static func _data_link(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var wc = weakref(c)
	var h := _h(c)
	var anchor := {"p": c.global_position}
	var n := 170
	var life := 1.8
	var seeds := []
	for i in n:
		seeds.append([randf() * TAU, randf_range(0.3, 1.9), randf(), randf_range(0.07, 0.2), randi() % 4, randf_range(0.6, 1.4)])
	var cols := [Color(0.25, 0.45, 1.0), Color(0.3, 0.85, 1.0), Color(0.55, 0.7, 1.0), Color(0.9, 0.97, 1.0)]
	var fn = func(i: int, u: float) -> Array:
		if i == 0:
			var cc = wc.get_ref()
			if cc != null and is_instance_valid(cc):
				anchor["p"] = cc.global_position
		var sd: Array = seeds[i]
		var el = u * life
		var rise = clampf(el / 0.35, 0.0, 1.0)
		var lift = clampf((el - 0.45 - float(sd[2]) * 0.5) / 0.9, 0.0, 1.0)
		var ang = float(sd[0]) + lift * lift * 4.0 * float(sd[5])
		var r = float(sd[1]) * (1.0 - lift * 0.85)
		var y = rise * 1.3 * (1.0 - float(sd[1]) / 2.2) * float(sd[2])
		y = lerpf(y, h * 1.2 + lift * 1.6 + float(sd[2]) * 0.5, lift)
		var p: Vector3 = anchor["p"] + Vector3(cos(ang) * r, y, sin(ang) * r)
		var s = float(sd[3]) * (1.0 - lift * 0.7) * rise
		var bas = Basis(Vector3.UP, float(sd[0]) + el * float(sd[5]) * 2.0).scaled(Vector3.ONE * maxf(s, 0.001))
		var col: Color = cols[int(sd[4])]
		col.a = rise * (1.0 - lift * lift) * (0.6 + 0.4 * (1.0 if fposmod(el * 7.0 + float(sd[2]) * 13.0, 1.0) >= 0.5 else 0.0))
		return [Transform3D(bas, p), col]
	var cm = _std("cube", true, 0.4, 1.6)
	_swarm(pj, _cube_mesh(), cm, n, life, fn)
	# bağlantı süresince başın çevresinde dönen küçük küpler
	var head := {"p": c.global_position + Vector3.UP * h * 1.05}
	var m := 12
	var fn2 = func(i: int, u: float) -> Array:
		if i == 0:
			var cc = wc.get_ref()
			if cc != null and is_instance_valid(cc):
				head["p"] = cc.global_position + Vector3.UP * h * 1.05
		var el = u * dur
		var ang = i * TAU / m + el * 1.2
		var p: Vector3 = head["p"] + Vector3(cos(ang) * 0.55, sin(el * 2.0 + i) * 0.08, sin(ang) * 0.55)
		var col = Color(0.35, 0.8, 1.0, 0.55 * clampf((el - 1.2) / 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, u)))
		return [Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * 0.06), p), col]
	_swarm(pj, _cube_mesh(), cm, m, dur, fn2)
	if c is Player:
		_vignette(pj, Color(0.2, 0.45, 1.0, 0.35), 0.9, 0.7)


# ================================================================== 6) Uchi Naru Sakura
## Kanon (ref: beyaz konturlu siyah "iç ses" silueti, yıldız gözler, yumruk sıkar): büyücünün ardında iç benliği belirir,
## yumruğunu sallar; "KAI!" ile bedeni saran yanılsama kabuğu siyah-beyaz parçalara ayrılıp savrulur.
static func uchi_naru_sakura(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var pink = Color(1, 0.55, 0.75)
	if c.has_method("clear_status"):
		c.clear_status()
	elif c.get("status") is Dictionary:
		for k in ["stun", "bind", "slow"]:
			c.status.erase(k)
	if c is Player:
		Buffs.add("uchi_naru", 6.0, {"_name": "İç Ses", "_desc": "genjutsu kırıldı; kısa süre etkilenmezsin"})
	_inner_self(pj, c)
	if c is Player:
		_vignette(pj, Color(1.0, 0.5, 0.72, 0.45), 0.6, 0.6)
	Combat.popup_text(c.global_position + Vector3.UP * 2.6, "KAI!!", pink)
	Sfx.play("seal", c.global_position, 1.4)


static func _inner_mesh() -> ArrayMesh:
	var k = "mesh:inner"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	var w = Color.WHITE
	b.add("sphere", Vector3(0, 1.62, 0.02), Vector3(0.36, 0.4, 0.36), w, Vector3.ZERO, 12)   # baş
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.17, 1.38, -0.04), Vector3(0.14, 0.62, 0.12), w, Vector3(180, 0, -sx * 6.0), 6)   # uzun saç
		b.add("cone", Vector3(sx * 0.2, 1.62, 0.0), Vector3(0.1, 0.22, 0.08), w, Vector3(0, 0, -sx * 80.0), 4)   # yan perçem
		b.add("cyl", Vector3(sx * 0.3, 1.27, 0.05), Vector3(0.1, 0.36, 0.1), w, Vector3(0, 0, sx * 30.0), 6)   # üst kol
		b.add("cyl", Vector3(sx * 0.24, 1.42, 0.16), Vector3(0.09, 0.3, 0.09), w, Vector3(-35, 0, -sx * 18.0), 6)   # ön kol yukarı
		b.add("sphere", Vector3(sx * 0.17, 1.56, 0.22), Vector3(0.14, 0.15, 0.14), w, Vector3.ZERO, 8)   # sıkılmış yumruk
		b.add("cyl", Vector3(sx * 0.11, 0.45, 0.0), Vector3(0.14, 0.9, 0.14), w, Vector3.ZERO, 6)   # bacak
	b.add("cone", Vector3(0, 1.88, 0.04), Vector3(0.22, 0.1, 0.2), w, Vector3.ZERO, 6)   # tepe kabarığı
	b.add("box", Vector3(0, 1.15, 0.0), Vector3(0.42, 0.6, 0.24), w)   # gövde
	b.add("cyl", Vector3(0, 0.88, 0.0), Vector3(0.46, 0.14, 0.28), w, Vector3.ZERO, 8)   # bel
	var m = b.build(null)
	_cache[k] = m
	return m


static func _inner_self(pj: PathJutsu, c: Node3D) -> void:
	var fd: Vector3 = c.face_dir()
	fd.y = 0.0
	fd = fd.normalized() if fd.length() > 0.01 else Vector3.BACK
	var side := fd.cross(Vector3.UP).normalized()
	var h := _h(c)
	var root := Node3D.new()
	pj.scene_add(root, c.global_position - fd * 0.55 - side * 0.55)
	root.basis = _face_basis(fd)
	var fill = MeshInstance3D.new()
	fill.mesh = _inner_mesh()
	fill.material_override = _ink_mat(false)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fill)
	var hull = MeshInstance3D.new()
	hull.mesh = _inner_mesh()
	hull.material_override = _ink_mat(true)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hull)
	for sx in [-1.0, 1.0]:
		var em = _smat(_glow_sh(true, true), {"u_col": Color(1.0, 0.85, 0.35, 1.0), "u_core": Color(1, 1, 0.9, 1), "u_alpha": 1.0, "u_star": 1.0, "u_near": 0.6})
		var eye = _mk(em, true)
		root.add_child(eye)
		eye.position = Vector3(sx * 0.085, 1.66, 0.2)
		eye.scale = Vector3.ONE * 0.11
	var s0 := h / 1.8 * 1.15
	root.scale = Vector3.ONE * s0 * 0.4
	var p0: Vector3 = root.position
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * s0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "position", p0 + fd * 0.35 + Vector3.UP * 0.12, 0.1)   # yumruk silkeleme
	tw.tween_property(root, "position", p0, 0.08)
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _kai_shatter(pj, c, root.global_position, h))
	tw.tween_property(root, "scale", Vector3(s0 * 1.3, s0 * 0.02, s0 * 1.3), 0.12)
	tw.tween_callback(root.queue_free)


## KAI: bedeni saran yanılsama kabuğu kırılır — siyah / beyaz / pembe parçalar dışa savrulur, başta kısa ışın çizgileri
static func _kai_shatter(pj: PathJutsu, c: Node3D, fallback: Vector3, h: float) -> void:
	var ctr: Vector3 = (c.global_position if is_instance_valid(c) else fallback) + Vector3.UP * h * 0.6
	var n := 46
	var life := 0.8
	var seeds := []
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.6, 1.0), randf_range(-1, 1)).normalized()
		seeds.append([d, randf_range(4.0, 8.0), Vector3(randf(), randf(), randf()) * 12.0, i % 3, randf_range(0.12, 0.24)])
	var cols := [Color(0.05, 0.03, 0.08), Color(1, 1, 1), Color(1, 0.55, 0.75)]
	var fn = func(i: int, u: float) -> Array:
		var sd: Array = seeds[i]
		var el = u * life
		var d: Vector3 = sd[0]
		var p: Vector3 = ctr + d * (0.45 * h / 1.8) + d * float(sd[1]) * (1.0 - exp(-el * 4.0)) / 4.0 * 1.6 + Vector3.DOWN * 4.0 * el * el
		var sp: Vector3 = sd[2]
		var bas = Basis.from_euler(sp * el).scaled(Vector3.ONE * float(sd[4]))
		var col: Color = cols[int(sd[3])]
		col.a = 1.0 - smoothstep(0.55, 1.0, u)
		return [Transform3D(bas, p), col]
	_swarm(pj, _shard_mesh(), _std("shard", false, 0.3, 1.2), n, life, fn)
	var head: Vector3 = ctr + Vector3.UP * h * 0.3
	for k in 12:
		var a = TAU * k / 12.0 + randf_range(-0.1, 0.1)
		var dir = Vector3(cos(a), sin(a) * 0.8, sin(a) * 0.4).normalized()
		var ray_pts = func(u: float) -> PackedVector3Array:
			return PackedVector3Array([head + dir * (0.4 + u * 1.2), head + dir * (0.9 + u * 2.4)])
		var ray_col = func(u: float, s: float) -> Color:
			return Color(1.0, 0.85, 0.92, (1.0 - u) * (0.4 + 0.6 * s))
		_ribbon(pj, 0.22, 0.05, ray_pts, ray_col)
	_ring_wave(pj, head, Vector3.ZERO, true, true, Color(1, 0.55, 0.75, 0.9), Color(1, 1, 1), 0.3, 2.2, 0.06, 0.3)


# ================================================================== 7) Magen: Nijū Kokoni Arazu no Jutsu
## Kanon (ref: turkuaz parlak sivri kemerin çerçevelediği yanılsama bambu korusu): iki yanda yerden bambu koruları yükselir,
## her birini turkuaz çatı biçimli ışık çizgisi çerçeveler, önünde kopya durur. Kopya dağılınca kemer kırılır, bambular
## kıymık kıymık çöker, yerde turkuaz şok halkası (sersemletme alanı) yayılır.
static func magen_niju_kokoni_arazu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var fd: Vector3 = c.face_dir()
	for side in [-1.0, 1.0]:
		var p = c.global_position + c.global_transform.basis.x * side * 3.0
		var grove = _bamboo_gate(pj, pj.gp(p), fd, 4.3)
		pj.decoy(c, p, 4.0, func(q: Vector3):
			_gate_burst(pj, q, grove)
			if not is_instance_valid(c):
				return
			for e in pj.enemies_near(c, q, 5.0):
				pj.st(e, "stun", 2.0))
	for e in pj.enemies_near(c, c.global_position, 20.0):
		if e.has_method("lose_target"):
			e.lose_target(1.0)
	Sfx.play("genjutsu", c.global_position, 1.0)


static func _bamboo_mesh() -> ArrayMesh:
	var k = "mesh:bamboo"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	var xs = [-1.55, -1.05, -0.55, -0.05, 0.45, 0.95, 1.5]
	var zs = [-0.3, 0.1, -0.45, 0.0, -0.2, 0.15, -0.35]
	var hs = [4.2, 4.8, 4.5, 5.0, 4.6, 4.3, 3.9]
	var rs = [0.2, 0.24, 0.18, 0.26, 0.22, 0.2, 0.18]
	for i in xs.size():
		var x: float = xs[i]
		var z: float = zs[i]
		var hh: float = hs[i]
		var r: float = rs[i]
		b.add_grad("cyl", Vector3(x, hh * 0.5, z), Vector3(r, hh, r), Color(0.55, 0.78, 0.36), Color(0.28, 0.48, 0.2), Vector3.ZERO, 8)
		var y = 0.6
		while y < hh - 0.2:
			b.add("cyl", Vector3(x, y, z), Vector3(r * 1.12, 0.06, r * 1.12), Color(0.22, 0.38, 0.15), Vector3.ZERO, 8)   # boğum
			y += 0.75
		for j in 3:
			var ly = hh * (0.55 + j * 0.15)
			var sx = 1.0 if (i + j) % 2 == 0 else -1.0
			b.add("cone", Vector3(x + sx * 0.35, ly, z + 0.05), Vector3(0.12, 0.8, 0.04), Color(0.32, 0.6, 0.25), Vector3(0, 0, -sx * 70.0), 4)   # yaprak
	var m = b.build(Props.toon())
	_cache[k] = m
	return m


static func _bamboo_gate(pj: PathJutsu, base: Vector3, fd: Vector3, life: float) -> Node3D:
	var root := Node3D.new()
	pj.scene_add(root, base - fd * 0.9)
	root.basis = _face_basis(fd)
	var mi := MeshInstance3D.new()
	mi.mesh = _bamboo_mesh()
	root.add_child(mi)
	var o: Vector3 = root.global_position + fd.normalized() * 0.35
	var ax: Vector3 = root.global_transform.basis.x.normalized()
	root.scale = Vector3(1, 0.05, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, life - 0.6))
	tw.tween_property(root, "scale", Vector3(1, 0.02, 1), 0.25)
	tw.tween_callback(root.queue_free)
	# turkuaz çatı kemeri: iki bacak yerden tepeye çizilir (parlak çekirdek + geniş soluk hale)
	var apex: Vector3 = o + Vector3.UP * 5.3
	var ribs := []
	for sx in [-1.0, 1.0]:
		var foot: Vector3 = o + ax * sx * 2.1 + Vector3.UP * 0.05
		for wide in [false, true]:
			var leg_pts = func(u: float) -> PackedVector3Array:
				var el = u * life
				return PackedVector3Array([foot, foot.lerp(apex, clampf(el / 0.4, 0.02, 1.0))])
			var leg_col = func(u: float, _s: float) -> Color:
				var a = (0.22 if wide else 0.95) * (1.0 - smoothstep(0.9, 1.0, u)) * (0.85 + 0.15 * sin(u * life * 20.0))
				return Color(0.3, 0.9, 0.85, a) if wide else Color(0.4, 1.0, 0.95, a)
			ribs.append(_ribbon(pj, life, 0.45 if wide else 0.11, leg_pts, leg_col))
	root.set_meta("ribs", ribs)
	return root


static func _gate_burst(pj: PathJutsu, q: Vector3, grove) -> void:
	if is_instance_valid(grove):
		for rb in grove.get_meta("ribs", []):
			if is_instance_valid(rb):
				rb.queue_free()
		var o: Vector3 = grove.global_position
		var ax: Vector3 = grove.global_transform.basis.x.normalized()
		var tw = grove.create_tween()
		tw.tween_property(grove, "scale", Vector3(1.15, 0.02, 1.15), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(grove.queue_free)
		_splinters(pj, o, ax)
	_ring_wave(pj, pj.gp(q) + Vector3.UP * 0.06, Vector3.ZERO, false, true, Color(0.4, 1.0, 0.95), Color(0.9, 1, 1), 0.3, 5.0, 0.12, 0.45, {"u_dbl": 1.0})


## Bambu kıymıkları: ince yeşil-sarı çubuklar dışa savrulup düşer
static func _splinters(pj: PathJutsu, o: Vector3, ax: Vector3) -> void:
	var n := 36
	var life := 0.85
	var seeds := []
	for i in n:
		var p0 = o + ax * randf_range(-1.6, 1.6) + Vector3.UP * randf_range(0.3, 4.5)
		var v = (ax * randf_range(-1, 1) + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))).normalized() * randf_range(3.0, 7.0)
		seeds.append([p0, v, Vector3(randf(), randf(), randf()) * 10.0, randf_range(0.3, 0.7)])
	var fn = func(i: int, u: float) -> Array:
		var sd: Array = seeds[i]
		var el = u * life
		var p: Vector3 = (sd[0] as Vector3) + (sd[1] as Vector3) * el + Vector3.DOWN * 7.0 * el * el
		var bas = Basis.from_euler((sd[2] as Vector3) * el).scaled(Vector3(0.05, float(sd[3]), 0.05))
		var col = Color(0.55, 0.78, 0.36).lerp(Color(0.85, 0.85, 0.5), float(i % 3) / 3.0)
		col.a = 1.0 - smoothstep(0.6, 1.0, u)
		return [Transform3D(bas, p), col]
	_swarm(pj, _cube_mesh(), _std("splinter", false, 0.3, 1.2), n, life, fn)


# ================================================================== 8) Magen: Jigoku Kōka no Jutsu
## Kanon (ref: gökten iniş yapan dev, kaynayan alev güneşi): kurbanın üstüne cel alev bantlı bir güneş iner, büyür,
## kor yağdırır; yer ve hava sıcakla titrer. Süre bitince güneş içine çöküp kıvılcımlara dağılır (kai).
static func magen_jigoku_koka_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	_hell_sun(pj, tt)
	pj.st(tt, "stun", 3.5)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Kâbus!", Color(1, 0.5, 0.2))
	Sfx.play("genjutsu", tt.global_position, 0.6)


static func _hell_sun(pj: PathJutsu, v: Node3D) -> void:
	var base: Vector3 = pj.gp(v.global_position)
	var bs := ClanJutsu.body_scale(v)
	var m = _smat(_sun_sh(), {"u_alpha": 0.0, "u_near": 7.0, "u_heat": 1.0})
	var sun := MeshInstance3D.new()
	sun.mesh = _sphere_mesh()
	sun.material_override = m
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(sun, base + Vector3.UP * 18.0 * bs)
	var hover: Vector3 = base + Vector3.UP * 10.5 * bs
	var R := 5.0 * bs
	var tw = sun.create_tween()
	tw.tween_method(_sp(m, "u_alpha"), 0.0, 1.0, 0.3)
	tw.parallel().tween_property(sun, "global_position", hover, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sun, "scale", Vector3.ONE * R, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sun, "scale", Vector3.ONE * R * 1.06, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sun, "scale", Vector3.ONE * R, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sun, "scale", Vector3.ONE * 0.05, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_sp(m, "u_heat"), 1.0, 1.6, 0.35)
	tw.tween_callback(sun.queue_free)
	pj.after(3.45, func():
		_motes(pj, hover, 40, Color(1.0, 0.85, 0.4), Color(0.9, 0.25, 0.05), 0.8, 9.0 * bs, -2.0, 0.22 * bs)
		_glow(pj, hover, R * 1.1, true, true, Color(1.0, 0.55, 0.15, 0.9), Color(1, 0.95, 0.7, 1), 0.3, 1.0, {"u_near": 6.0}))
	# güneşten yağan korlar
	var n := 70
	var seeds := []
	for i in n:
		var a = randf() * TAU
		seeds.append([Vector2(cos(a), sin(a)) * sqrt(randf()) * R * 0.8, randf(), randf_range(0.6, 1.2), randf_range(0.06, 0.12) * bs])
	var top_y: float = hover.y - R * 0.6
	var fn = func(i: int, u: float) -> Array:
		var sd: Array = seeds[i]
		var el = u * 3.3
		var f = fposmod(el * 0.55 * float(sd[2]) + float(sd[1]), 1.0)
		var xz: Vector2 = sd[0]
		var p = Vector3(base.x + xz.x * (1.0 - f * 0.5), lerpf(top_y, base.y + 0.1, f), base.z + xz.y * (1.0 - f * 0.5))
		var col = Color(1.0, 0.75, 0.25).lerp(Color(0.95, 0.3, 0.05), f)
		col.a = clampf((el - 1.0) / 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.88, 1.0, u)) * (1.0 - f * 0.5)
		return [Transform3D(Basis.from_scale(Vector3.ONE * float(sd[3])), p), col]
	_swarm(pj, _mote_mesh(), _std("ember", true, 0.4, 1.6), n, 3.3, fn)
	# yerde sıcak parıltı + kurbanın çevresinde sıcak titreşimi
	_glow(pj, base + Vector3.UP * 0.04, 3.6 * bs, false, true, Color(0.95, 0.4, 0.1, 0.8), Color(1.0, 0.8, 0.4, 0.9), 3.5, 0.55)
	_shimmer(pj, base + Vector3.UP * 1.2 * bs, true, false, 1.3 * bs, 1.6 * bs, 0.02, Color(1.0, 0.5, 0.15, 0.1), 3.3)
	if v == Game.player:
		_vignette(pj, Color(0.95, 0.35, 0.05, 0.5), 3.5, 0.85)


# ================================================================== 9) Genjutsu Shibari
## Ref (kurbanın üstüne eğilen dev bedenler, kurban küçücük kalmış): kurbanın önünde yerden iki dev, yarı saydam kızıl
## gölge-siluet yükselir, üstüne eğilip bakar; gölgeleri ayağına uzanır, ayağının çevresinde kızıl halka daralır.
## Süre bitince devler parlak kenarla yukarıdan aşağı çözülür (kai).
static func genjutsu_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var col = Color(0.85, 0.15, 0.25)
	_looming_giants(pj, c, tt, 3.0)
	pj.st(tt, "stun", 3.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Genjutsu!", col)
	Sfx.play("genjutsu", tt.global_position, 0.8)


static func _giant_mesh() -> ArrayMesh:
	var k = "mesh:giant"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	var w = Color.WHITE
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * 0.32, 0.75, 0), Vector3(0.42, 1.5, 0.42), w, Vector3.ZERO, 10)   # bacak
		b.add("cyl", Vector3(sx * 0.95, 2.35, 0.1), Vector3(0.36, 1.1, 0.36), w, Vector3(15, 0, sx * 18.0), 8)   # üst kol
		b.add("cyl", Vector3(sx * 1.12, 1.45, 0.3), Vector3(0.32, 1.0, 0.32), w, Vector3(35, 0, sx * 6.0), 8)   # ön kol
		b.add("sphere", Vector3(sx * 1.15, 0.95, 0.55), Vector3(0.38, 0.42, 0.38), w, Vector3.ZERO, 8)   # yumruk
	b.add("sphere", Vector3(0, 2.05, 0.05), Vector3(1.5, 1.5, 1.1), w, Vector3.ZERO, 14)   # gövde
	b.add("sphere", Vector3(0, 2.75, 0), Vector3(1.6, 0.8, 0.95), w, Vector3.ZERO, 12)   # omuzlar
	b.add("sphere", Vector3(0, 3.4, 0.12), Vector3(0.62, 0.7, 0.62), w, Vector3.ZERO, 12)   # baş
	b.add("cone", Vector3(0, 3.85, -0.05), Vector3(0.22, 0.3, 0.22), w, Vector3(-20, 0, 0), 8)   # tepe topuzu
	var m = b.build(null)
	_cache[k] = m
	return m


static func _looming_giants(pj: PathJutsu, c: Node3D, v: Node3D, dur: float) -> void:
	var base: Vector3 = pj.gp(v.global_position)
	var bs := ClanJutsu.body_scale(v)
	var d: Vector3 = c.global_position - v.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.BACK
	var side := d.cross(Vector3.UP).normalized()
	for sx in [-1.0, 1.0]:
		var p: Vector3 = pj.gp(base + d * 2.4 * bs + side * sx * 1.7 * bs)
		var m = _smat(_ghost_sh(), {"u_fill": Color(0.22, 0.03, 0.08, 0.55), "u_rim": Color(1.0, 0.3, 0.38, 0.9), "u_alpha": 1.0, "u_cut": 0.0, "u_h": 4.0, "u_near": 2.5})
		var g := MeshInstance3D.new()
		g.mesh = _giant_mesh()
		g.material_override = m
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pj.scene_add(g, p - Vector3.UP * 4.8 * bs)
		var to_v: Vector3 = base - p
		g.basis = _face_basis(to_v) * Basis(Vector3.RIGHT, deg_to_rad(14.0)) * Basis.from_scale(Vector3.ONE * 1.15 * bs)
		for ex in [-1.0, 1.0]:
			var em = _smat(_glow_sh(true, true), {"u_col": Color(1.0, 0.2, 0.25, 1.0), "u_core": Color(1, 0.85, 0.8, 1), "u_alpha": 1.0, "u_soft": 2.0, "u_near": 1.0})
			var eye = _mk(em, true)
			g.add_child(eye)
			eye.position = Vector3(ex * 0.16, 3.48, 0.42)
			eye.scale = Vector3.ONE * 0.13
		var tw = g.create_tween()
		tw.tween_property(g, "global_position", p, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.1, dur - 1.15))
		tw.tween_method(_sp(m, "u_cut"), 0.0, 1.25, 0.6)
		tw.tween_callback(g.queue_free)
		# devin gölgesi kurbanın ayağına uzanır
		var pool = _glow(pj, base.lerp(p, 0.55) + Vector3.UP * 0.04, 1.0, false, false, Color(0.08, 0.0, 0.03, 0.6), Color(0.15, 0.0, 0.05, 0.7), dur, 0.75, {"u_soft": 0.9})
		pool.basis = _face_basis(p - base) * Basis.from_scale(Vector3(1.4 * bs, 1.0, 2.8 * bs))
	# ayağın çevresinde daralan kızıl halka
	var rm = _ring_mat(false, true, Color(0.95, 0.2, 0.3, 0.8), Color(1, 0.75, 0.8), {"u_dbl": 1.0})
	var ring = _mk(rm, false)
	pj.scene_add(ring, base + Vector3.UP * 0.06)
	var rupd = func(u: float) -> void:
		var s = lerpf(1.4, 0.55, u) * bs / 0.9
		ring.scale = Vector3(s, 1.0, s)
		rm.set_shader_parameter("u_wid", 0.05 / s)
		rm.set_shader_parameter("u_alpha", clampf(u * 6.0, 0.0, 1.0) * (1.0 - smoothstep(0.88, 1.0, u)))
	rupd.call(0.0)
	var rt = ring.create_tween()
	rt.tween_method(rupd, 0.0, 1.0, dur)
	rt.tween_callback(ring.queue_free)
	if v == Game.player:
		_vignette(pj, Color(0.45, 0.02, 0.08, 0.55), dur, 0.8)


# ================================================================== 10) Genjutsu: Suzune Bunshin
## Ref (ince gümüş ses yayları + sıra sıra özdeş kopyalar): büyücünün elinde küçük altın zil sallanır, çevreye gümüş ses
## yayları savrulur; hedefin çevresinde her kopya bir zil halkasıyla belirir, hedefin ayağında titreşen gümüş halka.
static func genjutsu_suzune_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	Sfx.play("seal", c.global_position, 2.0)
	var gold = Color(1, 0.88, 0.45)
	_bell(pj, c)
	for k in 4:
		pj.after(k * 0.12, func():
			if pj.live(c):
				_chime_arcs(pj, c, k))
	if tt == null:
		return
	for k in 6:
		var a = TAU * k / 6.0
		var at = tt.global_position + Vector3(cos(a), 0, sin(a)) * 2.6
		pj.decoy(c, at, 3.0)
		_chime_mark(pj, pj.gp(at), k)
	_bell_hold(pj, tt, 2.2)
	pj.st(tt, "stun", 2.2)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Çın çın...", gold)


static func _bell_mesh() -> ArrayMesh:
	var k = "mesh:bell"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	var gold = Color(0.95, 0.75, 0.25)
	b.add("cyl", Vector3(0, 0.07, 0), Vector3(0.008, 0.12, 0.008), Color(0.75, 0.15, 0.15), Vector3.ZERO, 4)   # ip
	b.add("sphere", Vector3(0, 0.0, 0), Vector3(0.1, 0.1, 0.1), gold, Vector3.ZERO, 10)   # kubbe
	b.add("cyl", Vector3(0, -0.04, 0), Vector3(0.12, 0.025, 0.12), gold.darkened(0.15), Vector3.ZERO, 10)   # ağız
	b.add("box", Vector3(0, -0.01, 0.0), Vector3(0.11, 0.008, 0.02), Color(0.3, 0.2, 0.08))   # yarık
	b.add("sphere", Vector3(0, -0.06, 0), Vector3(0.03, 0.03, 0.03), Color(0.25, 0.18, 0.1), Vector3.ZERO, 6)   # dil
	var m = b.build(Props.toon())
	_cache[k] = m
	return m


## Elde sallanan zil (el konumunu izler, dünyaya göre sarkar)
static func _bell(pj: PathJutsu, c: Node3D) -> void:
	var bell := MeshInstance3D.new()
	bell.mesh = _bell_mesh()
	bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(bell, pj.hand_pos(c, true))
	var wc = weakref(c)
	var upd = func(u: float) -> void:
		var cc = wc.get_ref()
		if cc != null and is_instance_valid(cc):
			bell.global_position = pj.hand_pos(cc, true) + Vector3.DOWN * 0.12
		var el = u * 1.1
		bell.rotation = Vector3(sin(el * 22.0) * 0.5 * (1.0 - u), 0.0, cos(el * 18.0) * 0.4 * (1.0 - u))
		bell.scale = Vector3.ONE * clampf(el / 0.08, 0.05, 1.0) * (1.0 - smoothstep(0.85, 1.0, u)) + Vector3.ONE * 0.001
	var tw = bell.create_tween()
	tw.tween_method(upd, 0.0, 1.0, 1.1)
	tw.tween_callback(bell.queue_free)


static func _chime_arcs(pj: PathJutsu, c: Node3D, k: int) -> void:
	var o: Vector3 = c.global_position + Vector3.UP * 1.3
	for j in 3:
		_ring_wave(pj, o, Vector3(PI * 0.5 + randf_range(-0.5, 0.5), randf() * TAU, 0.0), false, true, Color(0.86, 0.9, 0.97, 0.9), Color(1, 0.9, 0.55),
			0.6, 4.0 + k * 3.0, 0.035, 0.5, {"u_arc": randf_range(0.35, 0.6), "u_arc0": randf()})


## Kopyanın belirdiği yerde çınlayan dikey halka + yerde küçük halka
static func _chime_mark(pj: PathJutsu, at: Vector3, k: int) -> void:
	pj.after(k * 0.05, func():
		_ring_wave(pj, at + Vector3.UP * 1.0, Vector3.ZERO, true, true, Color(0.88, 0.92, 1.0, 0.9), Color(1, 0.92, 0.6), 0.2, 1.2, 0.04, 0.35, {"u_dbl": 1.0})
		_ring_wave(pj, at + Vector3.UP * 0.05, Vector3.ZERO, false, true, Color(0.88, 0.92, 1.0, 0.8), Color(1, 1, 1), 0.1, 0.9, 0.03, 0.35))


## Hedefin çevresinde (kopya çemberinde) titreşen gümüş halka
static func _bell_hold(pj: PathJutsu, v: Node3D, dur: float) -> void:
	var rm = _ring_mat(false, true, Color(0.88, 0.92, 1.0, 0.7), Color(1, 0.92, 0.6), {"u_wave": 1.0, "u_dbl": 1.0})
	var ring = _mk(rm, false)
	pj.scene_add(ring, pj.gp(v.global_position) + Vector3.UP * 0.06)
	var s := 2.6 / 0.9
	ring.scale = Vector3(s, 1.0, s)
	rm.set_shader_parameter("u_wid", 0.04 / s)
	var upd = func(u: float) -> void:
		rm.set_shader_parameter("u_alpha", clampf(u * 8.0, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, u)) * (0.7 + 0.3 * sin(u * dur * 30.0)))
	upd.call(0.0)
	var tw = ring.create_tween()
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_callback(ring.queue_free)


# ================================================================== 11) Sōsai no Ne
## Ref (flüt çalanın çevresinde soluk, iç içe saydam ses küreleri): karşı ses iç içe kabarcık küreler olarak yayılır
## (yalnız kenarlarında ince dalga), söndürülen her merminin yerinde iki halka birbirini yutar (ses sese karşı).
static func sosai_no_ne(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.anim(c, "cast", 1.4)
	for k in 5:
		pj.after(k * 0.08, func():
			if pj.live(c):
				_null_bubble(pj, c.global_position + Vector3.UP * 1.3, 3.0 + k * 2.5, k))
	for p in pj.get_tree().get_nodes_in_group("projectiles"):
		if p.get("shooter") != c and p.global_position.distance_to(c.global_position) < 10.0:
			_cancel_mark(pj, p.global_position)
			p.queue_free()
	for e in pj.enemies_near(c, c.global_position, 6.0):
		pj.st(e, "stun", 0.8)
	Sfx.play("genjutsu", c.global_position, 2.0)


static func _null_bubble(pj: PathJutsu, at: Vector3, r: float, k: int) -> void:
	var m = _smat(_bubble_sh(), {"u_col": Color(0.85, 0.97, 0.9, 1.0), "u_alpha": 0.0, "u_ph": float(k) * 1.3, "u_near": 2.0})
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(mi, at)
	var upd = func(u: float) -> void:
		var s = lerpf(0.3, r, 1.0 - pow(1.0 - u, 2.0))
		mi.scale = Vector3.ONE * s
		m.set_shader_parameter("u_alpha", 0.9 * pow(1.0 - u, 1.3) * clampf(u / 0.1, 0.0, 1.0))
	upd.call(0.0)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, 0.55)
	tw.tween_callback(mi.queue_free)
	if k % 2 == 0:
		_ring_wave(pj, Vector3(at.x, at.y - 1.22, at.z), Vector3.ZERO, false, true, Color(0.85, 0.95, 0.9, 0.6), Color(1, 1, 1), 0.5, r, 0.05, 0.5, {"u_lobes": 9.0, "u_lamp": 0.02})


## Söndürülen mermi: biri daralan biri açılan iki halka birbirini yutar
static func _cancel_mark(pj: PathJutsu, p: Vector3) -> void:
	_ring_wave(pj, p, Vector3.ZERO, true, true, Color(0.75, 0.7, 1.0, 0.9), Color(1, 1, 1), 0.9, 0.05, 0.04, 0.3)
	_ring_wave(pj, p, Vector3.ZERO, true, true, Color(0.75, 0.7, 1.0, 0.9), Color(1, 1, 1), 0.05, 0.9, 0.04, 0.3)


# ================================================================== 12) Jigyaku no Jutsu
## Ref (kurbanın yüzünde yeşil kenarlı krem renkli dalgalı çiçek halkalar + çevresinde kıvrık yeşil teller): yüzün önünde
## çiçek biçimli halkalar dıştan içe akar (zaman geri sarılıyor), çevresinde dalgalı yeşil teller ters yönde döner.
## Süre bitince halkalar dışa savrulup söner (kai).
static func jigyaku_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var col = Color(0.5, 1.0, 0.6)
	_rewind(pj, tt, 4.0)
	pj.st(tt, "stun", 4.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Anılarda kayboldu...", col)
	Sfx.play("genjutsu", tt.global_position, 0.9)


static func _rewind(pj: PathJutsu, v: Node3D, dur: float) -> void:
	var h := _h(v)
	var bs := ClanJutsu.body_scale(v)
	var holder := Node3D.new()
	v.add_child(holder)
	holder.position = Vector3.UP * h * 0.86
	var rings := []
	for k in 4:
		var m = _ring_mat(true, true, Color(0.45, 1.0, 0.6, 0.95), Color(1.0, 0.97, 0.75), {"u_lobes": 6.0, "u_lamp": 0.12, "u_near": 0.8}, true)
		var mi = _mk(m, true)
		holder.add_child(mi)
		mi.scale = Vector3.ONE * 0.75 * bs
		rings.append(m)
	var upd = func(u: float) -> void:
		var el = u * dur
		for k in rings.size():
			var f = fposmod(float(k) / float(rings.size()) - el * 0.45, 1.0)   # dıştan içe: geri sarma
			var mm: ShaderMaterial = rings[k]
			mm.set_shader_parameter("u_rad", lerpf(0.12, 0.92, f))
			mm.set_shader_parameter("u_wid", 0.03 + f * 0.02)
			mm.set_shader_parameter("u_phase", -el * 2.5 + k)
			mm.set_shader_parameter("u_alpha", sin(f * PI) * clampf(el / 0.2, 0.0, 1.0))
	upd.call(0.0)
	var tw = holder.create_tween()
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_property(holder, "scale", Vector3.ONE * 2.0, 0.25).set_ease(Tween.EASE_OUT)   # kai: halkalar dışa savrulur
	for k in rings.size():
		tw.parallel().tween_method(_sp(rings[k], "u_alpha"), 0.8, 0.0, 0.25)
	tw.tween_callback(holder.queue_free)
	# dalgalı yeşil teller
	var wv = weakref(v)
	for k in 6:
		var th_pts = func(u: float) -> PackedVector3Array:
			var vv = wv.get_ref()
			if vv == null or not is_instance_valid(vv):
				return PackedVector3Array()
			var el = u * dur
			var cp: Vector3 = vv.global_position
			var a = k * TAU / 6.0 - el * 0.6
			var rad = (1.0 + 0.25 * sin(el * 1.5 + k)) * bs
			var tg := Vector3(-sin(a), 0.0, cos(a))
			var out := PackedVector3Array()
			for j in 14:
				var y = float(j) / 13.0 * 3.4 * bs
				out.append(cp + Vector3(cos(a), 0.0, sin(a)) * rad + tg * sin(y * 2.2 - el * 5.0 + k) * 0.22 * bs + Vector3.UP * y)
			return out
		var th_col = func(u: float, s: float) -> Color:
			return Color(0.45, 1.0, 0.65, 0.75 * sin(s * PI) * clampf(u * dur / 0.3, 0.0, 1.0) * (1.0 - smoothstep(0.9, 1.0, u)))
		_ribbon(pj, dur, 0.05, th_pts, th_col)
	if v == Game.player:
		_vignette(pj, Color(0.25, 0.8, 0.4, 0.4), dur, 0.8)


# ================================================================== 13) Kori Shinchū no Jutsu
## Ref (koyu camgöbeği gece, yeşil haleli dolunay, bilinmeyen kule): kurbanın üstünde yeşil haleli sahte bir ay belirir
## ve onun çevresinde döner; ayağının çevresinde dairesel bir iz çizilir, adım adım parlayan ayak izleri hep aynı çemberi
## dolaşır (düz gittiğini sanıp daire çizer).
static func sly_mind_affect_technique(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.5)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var col = Color(0.55, 0.85, 0.6)
	_false_moon(pj, tt, 6.0)
	pj.st(tt, "slow", 6.0)
	if tt.has_method("lose_target"):
		tt.lose_target(6.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.3, "Kayboldu...", col)
	Sfx.play("genjutsu", tt.global_position, 1.3)


static func _false_moon(pj: PathJutsu, v: Node3D, dur: float) -> void:
	var bs := ClanJutsu.body_scale(v)
	var wv = weakref(v)
	var anchor := {"p": v.global_position}
	var moon = _glow(pj, v.global_position + Vector3.UP * 4.2 * bs, 1.5 * bs, true, true, Color(0.45, 0.95, 0.55, 0.85), Color(0.96, 1.0, 0.86, 1), dur, 1.0, {"u_disk": 0.42, "u_soft": 1.2, "u_near": 2.0})
	# dairesel iz (kesik çizgi yavaşça döner)
	var trm = _ring_mat(false, true, Color(0.5, 0.95, 0.6, 0.5), Color(0.85, 1, 0.85), {"u_arc": 0.85, "u_alpha": 0.0})
	var trk = _mk(trm, false)
	pj.scene_add(trk, pj.gp(v.global_position) + Vector3.UP * 0.05)
	var ts := 1.8 * bs / 0.9
	trk.scale = Vector3(ts, 1.0, ts)
	trm.set_shader_parameter("u_wid", 0.05 / ts)
	var upd = func(u: float) -> void:
		var el = u * dur
		var vv = wv.get_ref()
		if vv != null and is_instance_valid(vv):
			anchor["p"] = vv.global_position
		if is_instance_valid(moon):
			moon.global_position = anchor["p"] + Vector3(cos(el * 0.9) * 2.2 * bs, 4.2 * bs + sin(el * 1.3) * 0.15, sin(el * 0.9) * 2.2 * bs)
		trk.global_position = pj.gp(anchor["p"]) + Vector3.UP * 0.05
		trm.set_shader_parameter("u_arc0", el * 0.15)
		trm.set_shader_parameter("u_alpha", clampf(el / 0.4, 0.0, 1.0) * (1.0 - smoothstep(0.9, 1.0, u)))
	upd.call(0.0)
	var tw = trk.create_tween()
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_callback(trk.queue_free)
	# hep aynı çemberi dolaşan ayak izleri
	pj.every(dur - 0.3, 0.28, func(i, _k):
		var a = i * 0.42
		var lr = 1.0 if i % 2 == 0 else -1.0
		var r = 1.8 * bs + lr * 0.16
		var ctr: Vector3 = anchor["p"]
		var p = pj.gp(ctr + Vector3(cos(a) * r, 0, sin(a) * r)) + Vector3.UP * 0.04
		var fp = _glow(pj, p, 1.0, false, true, Color(0.55, 1.0, 0.65, 0.8), Color(0.9, 1, 0.9, 1), 1.6, 0.8, {"u_soft": 0.8})
		fp.basis = _face_basis(Vector3(-sin(a), 0.0, cos(a))) * Basis.from_scale(Vector3(0.11, 1.0, 0.24) * bs))
	if v == Game.player:
		_vignette(pj, Color(0.15, 0.55, 0.45, 0.45), dur, 0.7)


# ================================================================== 14) Magen: Gamarinshō
## Kanon (Fukasaku + Shima düeti): omuzdaki iki yaşlı kurbağa sallanarak şarkı söyler, ağızlarından iç içe geçen pembe
## ve altın ses dalgaları (düet) yayılır; duyan her düşmanın çevresinde dört yanılsama kurbağası yerden çıkıp koro olur,
## ayağının altında pembe gölet halkaları açılır. Süre bitince kurbağalar yere batar (kai).
static func magen_gamarinsho(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.0)
	var elders = []
	var toads = []
	for sx in [-1.0, 1.0]:
		var ba = pj.bone_attach(c, "LeftShoulder" if sx > 0 else "RightShoulder")
		if ba:
			var mi = MeshInstance3D.new()
			mi.mesh = pj._elder_toad(sx < 0).build(Props.toon())
			ba.add_child(mi)
			mi.position = Vector3(0, 0.08, 0)
			mi.scale = Vector3.ONE * 0.05
			mi.create_tween().tween_property(mi, "scale", Vector3.ONE * 0.6, 0.3).set_trans(Tween.TRANS_BACK)
			elders.append(ba)
			toads.append(mi)
	var col = Color(0.85, 0.35, 0.4)
	_duet(pj, c, toads, 1.6)
	Sfx.play("genjutsu", c.global_position, 0.4)
	pj.after(1.6, func():
		if not is_instance_valid(c):
			return
		for e in pj.enemies_near(c, c.global_position, 22.0):
			pj.st(e, "stun", 7.0)
			_toad_chorus(pj, e, 7.0)
			Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Gamarinshō!", col))
	pj.after(2.2, func():
		for ba in elders:
			if is_instance_valid(ba):
				ba.queue_free())


static func _duet(pj: PathJutsu, c: Node3D, toads: Array, dur: float) -> void:
	var wc = weakref(c)
	var bob = func(u: float) -> void:
		var el = u * dur
		if el < 0.3:
			return
		for j in toads.size():
			var td = toads[j]
			if is_instance_valid(td):
				var b = absf(sin(el * 8.0 + j * 1.7))
				td.position.y = 0.08 + b * 0.025
				td.scale = Vector3(0.6 + b * 0.03, 0.6 - b * 0.03, 0.6 + b * 0.03)
	pj.get_tree().create_tween().tween_method(bob, 0.0, 1.0, dur)
	pj.every(dur, 0.2, func(i, _k):
		var cc = wc.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		for j in toads.size():
			var td = toads[j]
			if is_instance_valid(td):
				_song_wave(pj, cc, td.global_position + Vector3.UP * 0.12, j, i))


## Tek ses dalgası: kurbağanın ağzından açılıp uzayan sinüs şerit (dişi: pembe, erkek: altın; ters fazda iç içe)
static func _song_wave(pj: PathJutsu, c: Node3D, o: Vector3, j: int, i: int) -> void:
	var fd: Vector3 = c.face_dir()
	var dir: Vector3 = fd.rotated(Vector3.UP, (0.6 if j == 0 else -0.6) + sin(i * 1.3) * 0.3)
	var side := dir.cross(Vector3.UP).normalized()
	var col := Color(1.0, 0.72, 0.8) if j == 0 else Color(1.0, 0.88, 0.5)
	var wave_pts = func(u: float) -> PackedVector3Array:
		var L = 0.3 + u * 7.0
		var out := PackedVector3Array()
		for s in 18:
			var q = float(s) / 17.0
			out.append(o + dir * (q * L) + side * sin(q * 14.0 - u * 22.0 + j * PI) * 0.28 * q + Vector3.UP * (cos(q * 9.0 - u * 16.0) * 0.12 * q + q * 0.6))
		return out
	var wave_col = func(u: float, s: float) -> Color:
		return Color(col.r, col.g, col.b, 0.85 * (1.0 - u) * sin(s * PI))
	_ribbon(pj, 1.0, 0.07, wave_pts, wave_col)


static func _chorus_toad_mesh() -> ArrayMesh:
	var k = "mesh:chorus_toad"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	var skin = Color(0.55, 0.6, 0.42)
	b.add("sphere", Vector3(0, 0.22, 0), Vector3(0.5, 0.38, 0.46), skin, Vector3.ZERO, 12)   # gövde
	b.add("sphere", Vector3(0, 0.18, 0.12), Vector3(0.36, 0.26, 0.3), Color(0.85, 0.82, 0.62), Vector3.ZERO, 10)   # karın
	b.add("sphere", Vector3(0, 0.42, 0.12), Vector3(0.38, 0.24, 0.32), skin, Vector3.ZERO, 10)   # baş
	b.add("box", Vector3(0, 0.36, 0.27), Vector3(0.2, 0.05, 0.04), Color(0.45, 0.1, 0.12))   # açık ağız
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.11, 0.52, 0.2), Vector3(0.12, 0.12, 0.12), Color(0.95, 0.85, 0.3), Vector3.ZERO, 8)   # göz
		b.add("box", Vector3(sx * 0.11, 0.52, 0.26), Vector3(0.07, 0.015, 0.01), Color(0.05, 0.05, 0.05))   # yatık göz bebeği
		b.add("cyl", Vector3(sx * 0.16, 0.08, 0.18), Vector3(0.1, 0.16, 0.1), skin.darkened(0.1), Vector3.ZERO, 6)   # ön ayak
		b.add("sphere", Vector3(sx * 0.22, 0.1, -0.08), Vector3(0.18, 0.14, 0.28), skin.darkened(0.1), Vector3.ZERO, 8)   # arka bacak
	var m = b.build(Props.toon())
	_cache[k] = m
	return m


static func _toad_chorus(pj: PathJutsu, e: Node3D, dur: float) -> void:
	var base: Vector3 = pj.gp(e.global_position)
	var bs := ClanJutsu.body_scale(e)
	var root := Node3D.new()
	pj.scene_add(root, base)
	var tds := []
	for k in 4:
		var a = TAU * k / 4.0 + PI * 0.25
		var off = Vector3(cos(a), 0, sin(a)) * 1.5 * bs
		var tmi := MeshInstance3D.new()
		tmi.mesh = _chorus_toad_mesh()
		root.add_child(tmi)
		tmi.position = off - Vector3.UP * 0.8 * bs
		tmi.basis = _face_basis(-off) * Basis.from_scale(Vector3.ONE * bs)
		var tw = tmi.create_tween()
		tw.tween_interval(k * 0.1)
		tw.tween_property(tmi, "position", off, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tds.append(tmi)
	var sing = func(u: float) -> void:
		var el = u * dur
		for k in tds.size():
			var td = tds[k]
			if is_instance_valid(td):
				var b = absf(sin(el * 6.0 + k * 0.9))
				td.basis = td.basis.orthonormalized() * Basis.from_scale(Vector3(1.0 + b * 0.06, 1.0 + b * 0.12, 1.0 + b * 0.06) * bs)
	var st = root.create_tween()
	st.tween_method(sing, 0.0, 1.0, dur - 0.5)
	for k in tds.size():   # kai: kurbağalar yere batar
		st.parallel().tween_property(tds[k], "position:y", -1.0 * bs, 0.45).set_delay(dur - 0.5)
	st.tween_interval(0.5)
	st.tween_callback(root.queue_free)
	pj.every(dur - 0.6, 0.9, func(_i, _k):
		_ring_wave(pj, base + Vector3.UP * 0.05, Vector3.ZERO, false, true, Color(1.0, 0.7, 0.8, 0.7), Color(1, 0.95, 0.9), 0.3, 2.4 * bs, 0.05, 1.4))
	_glow(pj, base + Vector3.UP * 0.03, 2.4 * bs, false, true, Color(0.95, 0.55, 0.65, 0.35), Color(1, 0.85, 0.8, 0.4), dur, 0.6)
	if e == Game.player:
		_vignette(pj, Color(0.9, 0.45, 0.55, 0.4), dur, 0.75)


# ================================================================== 15) Makyō no Ran
## Kanon (Tayuya'nın finali): üç Doki yerde açılan mor-kara iblis yarıklarından yükselir; ağızlarından çok ağızlı, boğumlu
## mor ruh solucanları dans ederek hedeflerin içinden geçer ve ısırır, değdikleri yerde mor buhar dağılır. Sonunda Doki'ler
## yarıklara geri gömülür.
static func makyo_no_ran(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	pj.anim(c, "cast", 1.0)
	var dokis = []
	var fw = c.face_dir()
	var sd = fw.cross(Vector3.UP).normalized()
	for k in 3:
		var dp = pj.gp(c.global_position - fw * 2.5 + sd * (k - 1) * 3.0)
		_demon_rift(pj, dp, 3.6)
		var dk = Doki.spawn(_scene(pj), dp, atan2(-fw.x, -fw.z), k)
		dk.global_position = dp - Vector3.UP * 5.0
		dk.create_tween().tween_property(dk, "global_position", dp, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dokis.append(dk)
	Sfx.play("genjutsu", c.global_position, 0.8)
	pj.after(0.6, func():
		if not is_instance_valid(c):
			return
		var foes = pj.enemies_near(c, c.global_position, 26.0)
		if foes.is_empty() and t != null and pj.live(t):
			foes = [t]
		for k in 9:
			pj.after(k * 0.12, func():
				if foes.is_empty():
					return
				var dk = dokis[k % dokis.size()]
				var tgt = foes[k % foes.size()]
				if not is_instance_valid(dk) or not pj.live(tgt) or not pj.live(c):
					return
				_soul_worm(pj, dk.mouth_pos(), tgt.global_position + Vector3.UP * 1.0 + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)), 0.7, func(p: Vector3):
					_motes(pj, p, 16, Color(0.75, 0.5, 0.8, 0.9), Color(0.3, 0.18, 0.38, 0.6), 0.55, 4.0, 0.6, 0.22, false)
					if pj.live(c):
						for h in pj.hit(c, p, 1.6, pj.inf(c, "makyo_no_ran", 0.2, {"knock": 2.0, "kind": "light", "pierce_guard": true})):
							pj.st(h, "slow", 2.0)   # fiziksel enerjisi ısırılan beden ağırlaşır
							Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Ruh ısırığı!", Color(0.85, 0.55, 0.85)))))
	pj.after(3.0, func():
		for dk in dokis:
			if is_instance_valid(dk):
				var dp: Vector3 = dk.global_position
				_demon_rift(pj, dp, 0.9)
				var tw = dk.create_tween()
				tw.tween_property(dk, "global_position", dp - Vector3.UP * 5.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(dk.queue_free))


## Yerde açılan iblis yarığı: kara-mor leke, pütürlü parlak mor kenar, yükselen mor buğu
static func _demon_rift(pj: PathJutsu, pos: Vector3, life: float) -> void:
	_glow(pj, pos + Vector3.UP * 0.04, 2.0, false, false, Color(0.06, 0.0, 0.08, 0.8), Color(0.02, 0.0, 0.03, 0.95), life, 1.0, {"u_soft": 0.6})
	var rm = _ring_mat(false, true, Color(0.65, 0.25, 0.85, 0.9), Color(0.95, 0.7, 1.0), {"u_lobes": 9.0, "u_lamp": 0.16, "u_alpha": 0.0})
	var ring = _mk(rm, false)
	pj.scene_add(ring, pos + Vector3.UP * 0.06)
	var s := 2.1 / 0.9
	ring.scale = Vector3(s, 1.0, s)
	var upd = func(u: float) -> void:
		var el = u * life
		rm.set_shader_parameter("u_wid", 0.07 / s)
		rm.set_shader_parameter("u_phase", el * 0.8)
		rm.set_shader_parameter("u_alpha", clampf(el / 0.15, 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, u)))
	upd.call(0.0)
	var tw = ring.create_tween()
	tw.tween_method(upd, 0.0, 1.0, life)
	tw.tween_callback(ring.queue_free)
	var n := 26
	var seeds := []
	for i in n:
		var a = randf() * TAU
		seeds.append([Vector2(cos(a), sin(a)) * sqrt(randf()) * 1.6, randf(), randf_range(0.08, 0.16)])
	var fn = func(i: int, u: float) -> Array:
		var sd: Array = seeds[i]
		var el = u * life
		var f = fposmod(el * 0.7 + float(sd[1]), 1.0)
		var xz: Vector2 = sd[0]
		var p = pos + Vector3(xz.x * (1.0 + f * 0.3), f * 2.5, xz.y * (1.0 + f * 0.3))
		var col = Color(0.6, 0.25, 0.8, 0.7 * sin(f * PI) * (1.0 - smoothstep(0.8, 1.0, u)))
		return [Transform3D(Basis.from_scale(Vector3.ONE * float(sd[2]) * (1.0 + f)), p), col]
	_swarm(pj, _mote_mesh(), _std("wisp", true, 0.4, 1.6), n, life, fn)


static func _worm_seg_mesh() -> ArrayMesh:
	var k = "mesh:worm_seg"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.66, 0.66, 0.56), Color(0.52, 0.32, 0.58), Vector3.ZERO, 10)
	b.add("torus", Vector3.ZERO, Vector3(0.7, 0.12, 0.7), Color(0.36, 0.2, 0.42), Vector3(90, 0, 0), 10)   # boğum
	var m = b.build(Props.toon())
	_cache[k] = m
	return m


## Baş: üç küçük dişli ağız (-Z ileri)
static func _worm_head_mesh() -> ArrayMesh:
	var k = "mesh:worm_head"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.8, 0.75, 0.8), Color(0.55, 0.34, 0.62), Vector3.ZERO, 12)
	for mp in [Vector3(0, 0.18, -0.34), Vector3(-0.2, -0.12, -0.3), Vector3(0.2, -0.12, -0.3)]:
		b.add("sphere", mp, Vector3(0.18, 0.16, 0.1), Color(0.35, 0.05, 0.1), Vector3.ZERO, 8)   # ağız
		for tx in [-0.05, 0.0, 0.05]:
			b.add("cone", mp + Vector3(tx, 0.06, -0.03), Vector3(0.025, 0.06, 0.025), Color(0.95, 0.93, 0.85), Vector3(180, 0, 0), 4)   # diş
	var m = b.build(Props.toon())
	_cache[k] = m
	return m


## Ruh solucanı: boğumlu mor gövde, dans eden yol (yay + iki yana kıvrılma + dalgalanma); değince on_hit(to)
static func _soul_worm(pj: PathJutsu, from: Vector3, to: Vector3, dur: float, on_hit: Callable) -> void:
	var root := Node3D.new()
	_scene(pj).add_child(root)
	var segs := []
	for k in 11:
		var mi := MeshInstance3D.new()
		mi.mesh = _worm_head_mesh() if k == 0 else _worm_seg_mesh()
		root.add_child(mi)
		mi.global_position = from
		segs.append(mi)
	var side: Vector3 = (to - from).cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var swing := randf_range(-2.5, 2.5)
	var ph := randf() * TAU
	var path = func(q: float) -> Vector3:
		return from.lerp(to, q) + Vector3.UP * sin(q * PI) * 2.6 + side * (sin(q * PI) * swing + sin(q * TAU * 1.5 + ph) * 0.7) + Vector3(0, sin(q * 14.0 + ph) * 0.3, 0)
	var upd = func(q: float) -> void:
		for k in segs.size():
			var sg = segs[k]
			if not is_instance_valid(sg):
				continue
			var qq = clampf(q - k * 0.03, 0.0, 1.0)
			var p: Vector3 = path.call(qq)
			var dd: Vector3 = path.call(minf(1.0, qq + 0.02)) - p
			sg.global_position = p
			if dd.length() > 0.001 and absf(dd.normalized().y) < 0.98:
				sg.look_at(p + dd, Vector3.UP)
			sg.scale = Vector3.ONE * (1.0 - k * 0.06)
	var tw = root.create_tween()
	tw.tween_method(upd, 0.0, 1.3, dur)
	tw.tween_callback(func():
		on_hit.call(to)
		root.queue_free())
