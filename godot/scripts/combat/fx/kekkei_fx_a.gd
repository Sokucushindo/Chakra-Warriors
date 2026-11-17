class_name KekkeiFXA
extends RefCounted
## Kekkei genkai grubu A: Shikotsumyaku (Kaguya kemik dansları), Ōtsutsuki kül kemikleri ve Yasogami Kugeki,
## Hyūga Jūken (vakum avuçları, avuç kökü, ikiz aslan yumrukları). Hepsi bu dosyada sıfırdan:
## konturlu cel kemik gölgelendiricisi (fildişi + yumuşak gri gölge + koyu kenar; bitince ufalanarak çözülür),
## gerçek iskelet kemiklerine bağlı büyüyen dikenler, kemik ormanı (çarpışması kendi koni şeklinden), ekranı kıran
## basınç halkaları ve hava duvarı, çakra aslan başı, cel toz, zemin çatlakları. Kameraya yaklaşan her parça incelip söner.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const UP := Vector3.UP
const IVORY := Color(0.98, 0.96, 0.9)
const ASH_T := Color(0.68, 0.68, 0.7)
const FERN_T := Color(0.9, 0.95, 1.03)
const ASH_DUST := Color(0.56, 0.56, 0.58)
const GROUND_DUST := Color(0.82, 0.76, 0.64)
const BONE_DUST := Color(0.93, 0.92, 0.88)
const JUKEN := Color(0.84, 0.93, 1.0)
const JDEEP := Color(0.4, 0.6, 0.9)
const LION_RING := Color(0.6, 0.8, 1.0)
const INKC := Color(0.25, 0.27, 0.32)

# ================================================================== gölgelendiriciler
const NOISE := """
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnz(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Kameraya dönük düzlem; kameraya yaklaşınca küçülür (ekranı kaplamasın)
const BBV := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	VERTEX *= clamp(length(MODELVIEW_MATRIX[3].xyz) / 6.0, 0.35, 1.0);
"""

## Cel kemik: köşe rengi × k_tint, sabit ışıkla iki ton (fildişi / mavimsi gri), kenarda hafif koyulaşma.
## k_dis: dünya konumlu gürültüyle ufalanarak çözülme (kırık kenarı koyu). Kameraya çok yakınsa titreşimli incelme.
const BONE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
instance uniform vec4 k_tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float k_dis = 0.0;
varying vec3 wpos;
NOISE
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float nd = vnz(wpos.xz * 9.0 + wpos.y * 4.3) * 0.65 + vnz(wpos.zy * 21.0 + wpos.x * 2.0) * 0.35;
	if (nd < k_dis) {
		discard;
	}
	float nf = smoothstep(0.5, 1.4, length(VERTEX));
	if (hsh(floor(FRAGCOORD.xy)) > nf) {
		discard;
	}
	vec3 ldir = normalize(vec3(0.35, 0.85, 0.4));
	float lam = dot(NORMAL, ldir);
	vec3 bcol = COLOR.rgb * k_tint.rgb;
	vec3 col = mix(bcol * vec3(0.7, 0.71, 0.77), bcol, smoothstep(0.02, 0.1, lam));
	col = mix(col, bcol * 1.05, smoothstep(0.74, 0.8, lam) * 0.6);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col *= 1.0 - smoothstep(0.6, 0.85, fr) * 0.16;
	if (k_dis > 0.001 && nd < k_dis + 0.07) {
		col *= 0.5;
	}
	ALBEDO = col;
}
"""

## Kemiğin koyu konturu (ters kabuk): kalınlık uzaklıkla artar ki uzaktan da çizgi okunsun; çözülmeyi kemikle aynı izler
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, world_vertex_coords;
instance uniform vec4 k_tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float k_dis = 0.0;
uniform float ow = 0.011;
uniform vec3 ocol = vec3(0.13, 0.12, 0.13);
varying vec3 wpos;
NOISE
void vertex() {
	wpos = VERTEX;
	float dc = length(VERTEX - CAMERA_POSITION_WORLD);
	VERTEX += normalize(NORMAL) * ow * clamp(dc / 5.0, 0.7, 3.5);
}
void fragment() {
	float nd = vnz(wpos.xz * 9.0 + wpos.y * 4.3) * 0.65 + vnz(wpos.zy * 21.0 + wpos.x * 2.0) * 0.35;
	if (nd < k_dis) {
		discard;
	}
	float nf = smoothstep(0.5, 1.4, length(VERTEX));
	if (hsh(floor(FRAGCOORD.xy)) > nf) {
		discard;
	}
	ALBEDO = ocol;
}
"""

## Mürekkep çizgisi (hız izi, kesik yayı, şok taraması): UV.x boyunca açılır, ortası açık, kenarı koyu bant
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 k_edge = vec4(0.3, 0.35, 0.45, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
void fragment() {
	if (UV.x > k_grow) {
		discard;
	}
	float ac = 1.0 - abs(UV.y * 2.0 - 1.0);
	vec3 col = mix(k_edge.rgb, k_col.rgb, smoothstep(0.3, 0.55, ac));
	float a = smoothstep(0.0, 0.2, ac) * smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.06, k_grow - UV.x + 0.03);
	ALBEDO = col;
	ALPHA = clamp(a * k_a * smoothstep(0.7, 2.6, length(VERTEX)), 0.0, 1.0);
}
"""

## Cel toz bulutu: loblu kenar, iki ton, koyu kenar çizgisi; k_a düşünce delik delik dağılır
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.85, 0.8, 0.7, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void vertex() {
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = 0.8 + 0.1 * sin(ang * 5.0 + k_seed * 5.0) + 0.1 * (vnz(vec2(ang * 2.0, k_seed)) - 0.5);
	if (r > edge) {
		discard;
	}
	float holes = vnz(p * 2.7 + k_seed * 7.0);
	if (holes * 0.9 + 0.1 > k_a + (1.0 - r / edge) * 0.3) {
		discard;
	}
	float lit = step(0.0, -p.y * 0.7 + p.x * 0.3 + (holes - 0.5) * 0.5 + 0.05);
	vec3 col = mix(k_col.rgb * 0.75, k_col.rgb, lit);
	if (r > edge - 0.07) {
		col *= 0.66;
	}
	ALBEDO = col;
	ALPHA = smoothstep(0.8, 2.8, length(VERTEX));
}
"""

## Basınç halkası: görünmez hava itişi — halkanın içinden arka plan kırılarak görünür, kenarında ince ak çizgi
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform vec4 k_col = vec4(0.86, 0.94, 1.0, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_th = 0.16;
instance uniform float k_line = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float band = 1.0 - smoothstep(0.0, k_th, abs(r - (1.0 - k_th)));
	float ln = 1.0 - smoothstep(0.0, 0.025, abs(r - 0.975));
	float ln2 = 1.0 - smoothstep(0.0, 0.02, abs(r - (1.0 - 2.0 * k_th)));
	float m = max(band, ln * k_line);
	if (m < 0.002) {
		discard;
	}
	vec2 off = (p / max(r, 0.001)) * band * 0.03 * k_a;
	vec3 bg = textureLod(scr, SCREEN_UV - off, 0.0).rgb;
	vec3 col = mix(bg * 1.05 + k_col.rgb * 0.06, k_col.rgb, clamp(ln * k_line + ln2 * 0.35 * k_line, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(m * k_a * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Sıkıştırılmış hava gövdesi (vakum yumruğu, hayalet kollar): arka planı kırar, kenarı ak çizgi
const AIR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform vec4 k_col = vec4(0.9, 0.95, 1.0, 1.0);
instance uniform float k_a = 1.0;
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 off = NORMAL.xy * 0.035 * k_a * (0.4 + fr);
	vec3 bg = textureLod(scr, SCREEN_UV - off, 0.0).rgb;
	float ln = smoothstep(0.7, 0.88, fr);
	vec3 col = mix(bg * 1.05, k_col.rgb, ln * 0.85);
	ALBEDO = col;
	ALPHA = clamp(k_a * (0.7 + 0.3 * ln) * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Vakum duvarı: yatay hareket bulanıklığı bantları, arkasındaki dünya bükülür; yanlar / tepe yumuşak söner
const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void fragment() {
	float ex = smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	float ey = smoothstep(0.0, 0.1, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float stk = vnz(vec2(UV.x * 3.0 + k_seed, UV.y * 26.0));
	float flow = vnz(vec2(UV.x * 8.0 - TIME * 6.0, UV.y * 9.0 + k_seed));
	float m = ex * ey;
	vec2 off = vec2((flow - 0.5) * 0.04, (stk - 0.5) * 0.02) * m * k_a;
	vec3 bg = textureLod(scr, SCREEN_UV + off, 0.0).rgb;
	vec3 tint = mix(vec3(0.72, 0.86, 0.95), vec3(0.95, 0.99, 1.0), smoothstep(0.45, 0.8, stk));
	float bands = smoothstep(0.5, 0.85, stk) * 0.55 + 0.18;
	ALBEDO = mix(bg, tint, bands * m);
	ALPHA = clamp(m * k_a * (0.75 + 0.25 * bands) * smoothstep(1.0, 4.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Zemin izi: 0 yıldız çatlak + çukur, 1 uzun sürtme yarığı (yerel -Z boyunca), 2 süpürülmüş zemin (ileri çizgiler)
const DECAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.08, 0.06, 0.05, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_mode = 0.0;
instance uniform float k_seed = 0.0;
NOISE
float crk(vec2 p, float n, float sd, float wid) {
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 * n;
	float id = floor(a);
	float wob = (vnz(vec2(r * 5.0 + sd, id * 2.3 + sd)) - 0.5) * 0.6;
	float f = abs(fract(a + wob) - 0.5) / n * 6.2831853 * r;
	float ln = 0.45 + 0.55 * hsh(vec2(id, sd));
	if (r > ln) {
		return 0.0;
	}
	float w = wid * (1.0 - r / ln) + 0.003;
	return 1.0 - smoothstep(w * 0.5, w, f);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	int md = int(k_mode + 0.5);
	float a = 0.0;
	float rv = r;
	if (md == 0) {
		a = max(crk(p, 9.0, k_seed, 0.035), crk(p, 17.0, k_seed + 4.0, 0.02) * 0.8);
		a = max(a, (1.0 - smoothstep(0.07, 0.18, r)) * 0.65);
	} else if (md == 1) {
		float x = p.x + (vnz(vec2(p.y * 7.0, k_seed)) - 0.5) * 0.12;
		float w = 0.11 * (1.0 - smoothstep(0.7, 1.0, abs(p.y)));
		a = (1.0 - smoothstep(w * 0.5, w, abs(x))) * 0.7;
		rv = (1.0 - p.y) * 0.5;
	} else {
		float s = vnz(vec2(p.x * 22.0, k_seed));
		a = smoothstep(0.55, 0.8, s) * (1.0 - smoothstep(0.75, 1.0, r)) * 0.45;
		rv = (1.0 - p.y) * 0.5;
	}
	if (rv > k_grow) {
		a = 0.0;
	}
	ALBEDO = k_col.rgb;
	ALPHA = clamp(a * k_a, 0.0, 1.0);
}
"""

## Aslan başı köşe hareketi: üst yarıda yukarı yalayan alev dilleri (zamanla titrer)
const LION_V := """
	vec3 p0 = VERTEX;
	float ang = atan(p0.z, p0.x);
	float upw = smoothstep(-0.05, 0.45, p0.y);
	float fl = pow(max(0.0, sin(ang * 4.0 + k_seed + sin(TIME * 3.0 + p0.y * 4.0) * 0.6)), 4.0);
	float wob = vnz(vec2(ang * 3.0 + k_seed, TIME * 2.5));
	VERTEX.y += upw * (fl * 0.42 + wob * 0.1);
	VERTEX.xz *= 1.0 + upw * fl * 0.08 - upw * 0.12 * smoothstep(0.3, 0.6, p0.y);
	opos = p0;
"""

## Jūho Sōshiken aslan başı: yarı saydam mavi çakra, kenarı ak parlar; önde (yerel -Z) aslan yüzü: ak parlayan gözler,
## koyu kaş kıvrımları, zikzak dişli ağız; yanlarda koyu alev kıvrımları
const LION_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
varying vec3 opos;
NOISE
void vertex() {
//LV
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 deep = vec3(0.14, 0.32, 0.72);
	vec3 bodyc = vec3(0.46, 0.7, 1.0);
	vec3 rimc = vec3(0.9, 0.97, 1.0);
	float swirl = vnz(opos.xy * 5.0 + vec2(0.0, -TIME * 1.6) + k_seed);
	vec3 col = mix(bodyc, rimc, smoothstep(0.45, 0.85, fr));
	col = mix(col, bodyc * 0.85, smoothstep(0.55, 0.9, swirl) * 0.4);
	float a = 0.4 + 0.5 * smoothstep(0.35, 0.9, fr) + swirl * 0.08;
	float front = smoothstep(0.05, 0.3, -opos.z);
	vec2 f = opos.xy * 2.0;
	float sx = sign(f.x);
	vec2 e = vec2(abs(f.x) - 0.36, f.y - 0.14);
	e = vec2(e.x * 0.94 + e.y * 0.34, e.y * 0.94 - e.x * 0.34);
	float eye = 1.0 - smoothstep(0.8, 1.0, length(e / vec2(0.16, 0.075)));
	vec2 b = vec2(abs(f.x) - 0.33, f.y - 0.1) / vec2(0.3, 0.2);
	float brow = (1.0 - smoothstep(0.0, 0.09, abs(length(b) - 1.0))) * step(0.12, f.y) * step(abs(f.x), 0.72);
	float zig = abs(fract(f.x * 3.5 + 0.25) - 0.5) * 0.22;
	float mouth = (1.0 - smoothstep(0.03, 0.06, abs(f.y + 0.42 - zig + 0.05))) * step(abs(f.x), 0.62);
	float nose = (1.0 - smoothstep(0.02, 0.05, abs(abs(f.x) - 0.08))) * step(-0.28, f.y) * step(f.y, 0.0);
	float ink = max(max(brow, mouth), nose * 0.8) * front;
	float curl = smoothstep(0.8, 0.9, vnz(vec2(atan(opos.z, opos.x) * 3.0 + sx * 0.1, opos.y * 4.0 - TIME * 0.8) + k_seed));
	ink = max(ink, curl * 0.7 * (1.0 - front));
	col = mix(col, deep, ink * 0.9);
	a = max(a, ink * 0.85);
	col = mix(col, vec3(1.0), eye * front);
	a = max(a, eye * front);
	ALBEDO = col;
	ALPHA = clamp(a * k_a * smoothstep(0.4, 1.4, length(VERTEX)), 0.0, 1.0);
}
"""

## Aslan başının dış parıltısı: şişirilmiş ters kabuk, kenara doğru açılan soluk ak-mavi hale
const LION_HALO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
varying vec3 opos;
NOISE
void vertex() {
//LV
	VERTEX += NORMAL * 0.05;
}
void fragment() {
	float fr = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.78, 0.9, 1.0);
	ALPHA = clamp((1.0 - fr) * 0.55 * k_a * smoothstep(0.4, 1.4, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzemeler
static func _shader(key0: String, code: String) -> Shader:
	var key = "shd:" + key0
	if _cache.has(key):
		return _cache[key]
	var s = Shader.new()
	s.code = code.replace("//LV", LION_V).replace("NOISE", NOISE).replace("//BB", BBV)
	_cache[key] = s
	return s


static func _mat(key0: String, code: String) -> ShaderMaterial:
	var key = "mat:" + key0
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _shader(key0, code)
	_cache[key] = m
	return m


static func _bone_mat() -> ShaderMaterial:
	var key = "mat:bone_full"
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _shader("bone", BONE_SHADER)
	var ol = ShaderMaterial.new()
	ol.shader = _shader("bone_ol", OUTLINE_SHADER)
	m.next_pass = ol
	_cache[key] = m
	return m


static func _lion_mat() -> ShaderMaterial:
	var key = "mat:lion_full"
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _shader("lion", LION_SHADER)
	var halo = ShaderMaterial.new()
	halo.shader = _shader("lion_halo", LION_HALO_SHADER)
	m.next_pass = halo
	_cache[key] = m
	return m


# ================================================================== temel yardımcılar
static func _put(pj: PathJutsu, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ipar(mi: GeometryInstance3D, vals: Dictionary) -> void:
	for k in vals:
		mi.set_instance_shader_parameter(k, vals[k])


static func _pf(mi: GeometryInstance3D, key: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(key, v)


## Kök altındaki tüm kemik parçalarının çözülme değerini birlikte sürer
static func _dis_all(root: Node) -> Callable:
	return func(v: float) -> void:
		if not is_instance_valid(root):
			return
		if root is GeometryInstance3D:
			(root as GeometryInstance3D).set_instance_shader_parameter("k_dis", v)
		for ch in root.find_children("*", "GeometryInstance3D", true, false):
			(ch as GeometryInstance3D).set_instance_shader_parameter("k_dis", v)


static func _flat(d: Vector3) -> Vector3:
	var f = Vector3(d.x, 0.0, d.z)
	if f.length() < 0.01:
		return Vector3.FORWARD
	return f.normalized()


static func _side(d: Vector3) -> Vector3:
	var s = d.cross(UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


## -Z ekseni d yönüne bakan taban
static func _basis(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	return Basis.looking_at(f, UP if absf(f.y) < 0.97 else Vector3.RIGHT)


## +Y ekseni dir yönüne bakan taban (kemik dikenleri +Y boyunca büyür)
static func _ybasis(dir: Vector3) -> Basis:
	var y = dir.normalized() if dir.length() > 0.001 else UP
	var rf = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x = rf.cross(y).normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)


static func _rdir3() -> Vector3:
	var v = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if v.length() < 0.05:
		return UP
	return v.normalized()


static func _rdir() -> Vector3:
	var a = randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))


static func _gcol(p: Vector3) -> Color:
	if Game.world == null:
		return GROUND_DUST
	var b = Game.biome_at(p.x, p.z)
	if b in [1, 3, 13]:
		return Color(0.93, 0.84, 0.64)
	if b in [8, 15]:
		return Color(0.92, 0.94, 0.98)
	if b in [5, 9, 14]:
		return Color(0.8, 0.78, 0.74)
	return GROUND_DUST


static func _mk(v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var col := PackedColorArray()
	col.resize(v.size())
	col.fill(Color.WHITE)
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ================================================================== geometri
static func _quad() -> QuadMesh:
	var key = "mesh:quad"
	if not _cache.has(key):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache[key] = q
	return _cache[key]


static func _plane() -> PlaneMesh:
	var key = "mesh:plane"
	if not _cache.has(key):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache[key] = p
	return _cache[key]


## Birim çizgi: -Z boyunca 1 uzun, çapraz iki düzlem, iki ucu sivri
static func _strip_mesh() -> ArrayMesh:
	var key = "mesh:strip"
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var seg = 8
	for pl in 2:
		var base = v.size()
		for i in seg + 1:
			var t = float(i) / seg
			var hw = 0.5 * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.6)
			if pl == 0:
				v.append(Vector3(-hw, 0.0, -t))
				v.append(Vector3(hw, 0.0, -t))
			else:
				v.append(Vector3(0.0, -hw, -t))
				v.append(Vector3(0.0, hw, -t))
			uv.append(Vector2(t, 0.0))
			uv.append(Vector2(t, 1.0))
		for i in seg:
			var b = base + i * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, idx)
	_cache[key] = m
	return m


## Hilal kesik yayı: yarıçap 1, yerel XZ düzleminde a0→a1 derece (0 = ileri -Z), wr göreli kalınlık; baş a1'de
static func _arc_mesh(a0: float, a1: float, wr: float) -> ArrayMesh:
	var key = "mesh:arc_%.0f_%.0f_%.2f" % [a0, a1, wr]
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var seg = 28
	for i in seg + 1:
		var t = float(i) / seg
		var a = deg_to_rad(lerpf(a0, a1, t))
		var dv = Vector3(-sin(a), 0.0, -cos(a))
		var th = wr * pow(sin(PI * t), 0.6) * (0.35 + 0.65 * t)
		v.append(dv * (1.0 - th))
		v.append(dv * (1.0 + th * 0.2))
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
	for i in seg:
		var b = i * 2
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, idx)
	_cache[key] = m
	return m


## Vakum duvarı yayı: yarıçap 1, ±19 derece (35 derecelik vuruş alanı), yükseklik 1 (taban y=0)
static func _wall_mesh() -> ArrayMesh:
	var key = "mesh:wall"
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var seg = 24
	for i in seg + 1:
		var t = float(i) / seg
		var a = deg_to_rad(lerpf(-19.0, 19.0, t))
		var dv = Vector3(-sin(a), 0.0, -cos(a))
		for j in 2:
			v.append(dv + UP * float(j))
			uv.append(Vector2(t, float(j)))
	for i in seg:
		var b = i * 2
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, idx)
	_cache[key] = m
	return m


## Kemik dikeni: +Y boyunca 1 boy, taban çapı 1 (ölçek: (çap, boy, çap)); bend: genişlik biriminde uç kavisi,
## fork: üst yarıda yana açılan ikinci uç (Sawarabi çatalları). Taban gri, uç fildişi.
static func _spike_mesh(v: int, bend: float, fork: bool) -> ArrayMesh:
	var key = "mesh:spk_%d_%.2f_%s" % [v, bend, str(fork)]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4447 + v * 7919
	var a = rng.randf() * TAU
	var bd = Vector3(cos(a), 0.0, sin(a)) * bend
	var pts = []
	var rad = []
	var cols = []
	for i in 7:
		var t = i / 6.0
		pts.append(Vector3(0.0, t, 0.0) + bd * t * t)
		var r = 0.5 * pow(1.0 - t, 0.9) + 0.01
		rad.append(Vector2(r, r * rng.randf_range(0.82, 1.0)))
		cols.append(Color(0.8, 0.8, 0.83).lerp(Color.WHITE, minf(1.0, t * 1.6)))
	var mb = MB.new()
	Loft.tube(mb, pts, rad, cols, 8, 3, false, true)
	if fork:
		var s0 = 0.5 + rng.randf() * 0.15
		var sd = Vector3(cos(a + 1.7), 0.0, sin(a + 1.7))
		var p0 = Vector3(0.0, s0, 0.0) + bd * s0 * s0
		var r0 = (0.5 * pow(1.0 - s0, 0.9)) * 0.7
		Loft.tube(mb, [p0, p0 + sd * 0.8 + UP * 0.12, p0 + sd * 2.0 + UP * 0.28], [Vector2(r0, r0), Vector2(r0 * 0.55, r0 * 0.55), Vector2(0.01, 0.01)], Color.WHITE, 6, 3, false, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Ōtsutsuki kül kemiği iğnesi: -Z boyunca, düğümlü dip, sivri uç
static func _needle_mesh(v: int) -> ArrayMesh:
	var key = "mesh:needle_%d" % v
	if _cache.has(key):
		return _cache[key]
	var L = 1.3 + v * 0.1
	var pts = [Vector3(0, 0, 0.12), Vector3(0, 0, 0.0), Vector3(0, 0, -L * 0.3), Vector3(0, 0, -L * 0.6), Vector3(0, 0, -L * 0.85), Vector3(0, 0, -L)]
	var rad = [0.055, 0.07, 0.05, 0.04, 0.026, 0.004]
	var cols = [Color(0.85, 0.85, 0.86), Color(0.9, 0.9, 0.9), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var mb = MB.new()
	Loft.tube(mb, pts, rad, cols, 7, 2, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Elde tutulan kemik kılıç (Tsubaki): +Z boyunca, dipte yumru, ince uzun namlu
static func _hand_sword_mesh(len_: float) -> ArrayMesh:
	var key = "mesh:hsword_%.2f" % len_
	if _cache.has(key):
		return _cache[key]
	var pts = [Vector3(0, 0, -0.16), Vector3(0, 0, -0.1), Vector3(0, 0, 0.05), Vector3(0, 0.0, len_ * 0.5), Vector3(0, 0.01, len_ * 0.85), Vector3(0, 0.015, len_)]
	var rad = [0.05, 0.034, 0.03, 0.027, 0.02, 0.003]
	var mb = MB.new()
	Loft.tube(mb, pts, rad, Color.WHITE, 8, 3, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Ön koldan fışkıran yassı kemik kılıç: kemiğin +Y'si (ön kol doğrultusu) boyunca, hafif kavisli
static func _arm_sword_mesh(len_: float) -> ArrayMesh:
	var key = "mesh:asword_%.2f" % len_
	if _cache.has(key):
		return _cache[key]
	var pts = [Vector3(0, 0.1, 0), Vector3(0, 0.3, 0.0), Vector3(0, 0.3 + len_ * 0.5, 0.02), Vector3(0, 0.3 + len_ * 0.9, 0.05), Vector3(0, 0.3 + len_, 0.06)]
	var rad = [Vector2(0.05, 0.03), Vector2(0.06, 0.022), Vector2(0.05, 0.018), Vector2(0.025, 0.01), Vector2(0.004, 0.004)]
	var cols = [Color(0.85, 0.85, 0.86), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var mb = MB.new()
	Loft.tube(mb, pts, rad, cols, 8, 3, true, true, Callable(), Vector3.FORWARD)
	var m = mb.build()
	_cache[key] = m
	return m


## Bedenden yelpaze gibi fışkıran uzun yassı kıvrık kemik şerit (Yaemugura bitirişi): +Y boyunca 1 boy
static func _ribbon_mesh(v: int) -> ArrayMesh:
	var key = "mesh:ribbon_%d" % v
	if _cache.has(key):
		return _cache[key]
	var sg = 1.0 if v % 2 == 0 else -1.0
	var cv = 0.3 + 0.12 * (v % 3)
	var pts = [Vector3(0, 0, 0), Vector3(0.04 * sg, 0.33, 0), Vector3(0.14 * sg * cv * 3.0, 0.68, 0), Vector3(0.3 * sg * cv * 3.0, 0.92, 0.04), Vector3(0.4 * sg * cv * 3.0, 1.0, 0.06)]
	var rad = [Vector2(0.06, 0.03), Vector2(0.09, 0.032), Vector2(0.075, 0.026), Vector2(0.035, 0.014), Vector2(0.004, 0.004)]
	var cols = [Color(0.84, 0.84, 0.86), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var mb = MB.new()
	Loft.tube(mb, pts, rad, cols, 8, 3, true, true, Callable(), Vector3.FORWARD)
	var m = mb.build()
	_cache[key] = m
	return m


## Tessenka matkabı çekirdeği: -Z boyunca sivrilen koni
static func _drill_core_mesh() -> ArrayMesh:
	var key = "mesh:drill_core"
	if _cache.has(key):
		return _cache[key]
	var pts = []
	var rad = []
	for i in 7:
		var u = i / 6.0
		pts.append(Vector3(0, 0, 0.12 - u * 2.85))
		rad.append(0.46 * pow(1.0 - u, 0.95) + 0.012)
	var mb = MB.new()
	Loft.tube(mb, pts, rad, Color(0.94, 0.93, 0.9), 12, 3, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Tessenka matkabı sarmal katmanı (altı tanesi çekirdeği sarar; katman aralarındaki kontur ref'teki çizgileri verir)
static func _drill_plate_mesh(sp: int) -> ArrayMesh:
	var key = "mesh:drill_plate_%d" % sp
	if _cache.has(key):
		return _cache[key]
	var pts = []
	var rad = []
	for k in 14:
		var u = k / 13.0
		var a = sp * TAU / 6.0 + u * TAU * 1.1
		var r = 0.47 * (1.0 - u) + 0.03
		pts.append(Vector3(cos(a) * r, sin(a) * r, -u * 2.7))
		rad.append(Vector2(0.13, 0.06) * (1.0 - u * 0.75))
	var mb = MB.new()
	Loft.tube(mb, pts, rad, Color.WHITE, 6, 2, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Kazaguruma: aşağı bakan sarmal kemik ucu + bedenin çevresinde yel değirmeni gibi dört uzun kemik kanat
static func _windmill_mesh() -> ArrayMesh:
	var key = "mesh:windmill"
	if _cache.has(key):
		return _cache[key]
	var mb = MB.new()
	var pts = []
	var rad = []
	for i in 7:
		var u = i / 6.0
		pts.append(Vector3(0, 0.2 - u * 2.5, 0))
		rad.append(0.5 * pow(1.0 - u, 0.9) + 0.01)
	Loft.tube(mb, pts, rad, Color(0.94, 0.93, 0.9), 10, 3, true, true, Callable(), Vector3.FORWARD)
	for sp in 4:
		var sp_pts = []
		var sp_rad = []
		for k in 10:
			var u = k / 9.0
			var a = sp * TAU / 4.0 + u * TAU * 0.9
			var r = 0.5 * (1.0 - u) + 0.05
			sp_pts.append(Vector3(cos(a) * r, 0.1 - u * 2.3, sin(a) * r))
			sp_rad.append(0.09 * (1.0 - u * 0.8))
		Loft.tube(mb, sp_pts, sp_rad, Color.WHITE, 6, 2, true, true, Callable(), Vector3.FORWARD)
	for q in 4:
		var ang = q * TAU / 4.0
		var vp = []
		var vr = []
		for k in 6:
			var u = k / 5.0
			var a = ang + u * 0.55
			vp.append(Vector3(cos(a) * (0.25 + u * 1.5), -0.1 - u * 0.3, sin(a) * (0.25 + u * 1.5)))
			vr.append(Vector2(0.12 * (1.0 - u) + 0.008, 0.035 * (1.0 - u * 0.7)))
		Loft.tube(mb, vp, vr, Color.WHITE, 6, 3, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Küçük kemik kıymığı
static func _chip_mesh(v: int) -> ArrayMesh:
	var key = "mesh:chip_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 311 + v * 97
	var mb = MB.new()
	var pts = [Vector3.ZERO, Vector3(rng.randf_range(-0.03, 0.03), 0.06, rng.randf_range(-0.02, 0.02)), Vector3(0, 0.12 + v * 0.02, 0)]
	Loft.tube(mb, pts, [0.025, 0.04, 0.004], Color.WHITE, 4, 1, true, true, Callable(), Vector3.FORWARD)
	var m = mb.build()
	_cache[key] = m
	return m


## Kül pulu: yassı düzensiz yaprakçık
static func _flake_mesh(v: int) -> ArrayMesh:
	var key = "mesh:flake_%d" % v
	if _cache.has(key):
		return _cache[key]
	var w = 0.06 + v * 0.015
	var mb = MB.new()
	Loft.tube(mb, [Vector3(0, 0, -0.07), Vector3(0.01 * v, 0, 0), Vector3(0, 0, 0.07)], [Vector2(0.02, 0.004), Vector2(w, 0.011), Vector2(0.02, 0.004)], Color.WHITE, 5, 2, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Yasogami vakum yumruğu: -Z ileri, küt önlü (yumruk) arkaya incelen damla
static func _fist_mesh() -> ArrayMesh:
	var key = "mesh:airfist"
	if _cache.has(key):
		return _cache[key]
	var mb = MB.new()
	Loft.tube(mb, [Vector3(0, 0, 0.85), Vector3(0, 0, 0.4), Vector3(0, 0, 0.0), Vector3(0, 0, -0.35), Vector3(0, 0, -0.6)], [0.04, 0.3, 0.5, 0.55, 0.42], Color.WHITE, 14, 3, false, true)
	var m = mb.build()
	_cache[key] = m
	return m


## Hayalet hava kolu: omuzdan -Z boyunca uzanan kol + yumruk
static func _arm_mesh() -> ArrayMesh:
	var key = "mesh:airarm"
	if _cache.has(key):
		return _cache[key]
	var mb = MB.new()
	Loft.tube(mb, [Vector3(0, 0, 0), Vector3(0, 0, -0.7), Vector3(0, 0, -1.3), Vector3(0, 0, -1.5), Vector3(0, 0, -1.68)], [0.1, 0.085, 0.075, 0.13, 0.1], Color.WHITE, 10, 3, true, true)
	var m = mb.build()
	_cache[key] = m
	return m


static func _lion_mesh() -> SphereMesh:
	var key = "mesh:lion"
	if not _cache.has(key):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 36
		s.rings = 22
		_cache[key] = s
	return _cache[key]


# ================================================================== yapı taşları
## Konturlu cel kemik örneği
static func _bone_mi(mesh: Mesh, tint: Color) -> MeshInstance3D:
	var mi = _gi(mesh, _bone_mat())
	mi.set_instance_shader_parameter("k_tint", tint)
	mi.set_instance_shader_parameter("k_dis", 0.0)
	return mi


## Kemiğin fışkırması: +Y boyunca neredeyse sıfırdan aşıp yerine oturan büyüme
static func _pop(n: Node3D, s: Vector3, t: float, delay := 0.0) -> void:
	n.scale = Vector3(s.x * 0.4, maxf(s.y * 0.02, 0.004), s.z * 0.4)
	var tw = n.create_tween()
	if delay > 0.0:
		n.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func(): n.visible = true)
	tw.tween_property(n, "scale", s * Vector3(1.0, 1.1, 1.0), t * 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", s, t * 0.3).set_trans(Tween.TRANS_SINE)


## Düzgün büyüme (matkap katmanları)
static func _pop_u(n: Node3D, t: float, delay := 0.0) -> void:
	n.scale = Vector3.ONE * 0.05
	var tw = n.create_tween()
	if delay > 0.0:
		n.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func(): n.visible = true)
	tw.tween_property(n, "scale", Vector3.ONE * 1.06, t * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector3.ONE, t * 0.25)


## Bekle, sonra ufalanarak çözül ve sil
static func _crumble(n: Node, delay: float, dur := 0.45) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_dis_all(n), 0.0, 1.05, dur)
	tw.tween_callback(n.queue_free)


## Balistik savrulma: yere değince durur, sonra ufalanır
static func _toss(pj: PathJutsu, n: Node3D, v: Vector3, life: float, g := 20.0, spin := 10.0) -> void:
	var p0 = n.global_position
	var fl = pj.gp(p0).y + 0.03
	var t_land = (v.y + sqrt(maxf(0.0, v.y * v.y + 2.0 * g * maxf(0.0, p0.y - fl)))) / g
	var rax = _rdir3()
	var b0 = n.global_basis
	var step = func(tt: float) -> void:
		if not is_instance_valid(n):
			return
		var te = minf(tt, t_land)
		n.global_position = p0 + v * te + Vector3.DOWN * 0.5 * g * te * te
		n.global_basis = Basis(rax, te * spin) * b0
	var tw = n.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_method(_dis_all(n), 0.0, 1.05, 0.3)
	tw.tween_callback(n.queue_free)


## Kemik kıymığı saçılımı
static func _chips(pj: PathJutsu, at: Vector3, n: int, spd: float, tint := IVORY, life := 0.9) -> void:
	for i in n:
		var mi = _bone_mi(_chip_mesh(i % 4), tint)
		_put(pj, mi, at + _rdir3() * 0.15)
		mi.scale = Vector3.ONE * randf_range(0.6, 1.4)
		var v = _rdir3() * spd * randf_range(0.4, 1.0) + UP * spd * randf_range(0.2, 0.6)
		_toss(pj, mi, v, life * randf_range(0.8, 1.2))


## Mürekkep çizgisi: from'dan dir boyunca len_; başa doğru açılır, söner; drift: sönerken kayma
static func _line(pj: PathJutsu, from: Vector3, dir: Vector3, len_: float, w: float, col: Color, edge: Color, life: float, drift := Vector3.ZERO, grow := 0.05) -> MeshInstance3D:
	var mi = _gi(_strip_mesh(), _mat("streak", STREAK_SHADER))
	_put(pj, mi, from)
	mi.global_basis = _basis(dir) * Basis.from_scale(Vector3(w, w, len_))
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_grow": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, grow)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	if drift != Vector3.ZERO:
		tw.parallel().tween_property(mi, "global_position", from + drift, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)
	return mi


## Kesik yayı: bs tabanında (yerel XZ düzlemi), r yarıçap, a0→a1 süpürülür, kısa durur, söner
static func _arc(pj: PathJutsu, at: Vector3, bs: Basis, r: float, a0: float, a1: float, wr: float, col: Color, edge: Color, life: float, sweep := 0.08) -> void:
	var mi = _gi(_arc_mesh(a0, a1, wr), _mat("streak", STREAK_SHADER))
	_put(pj, mi, at)
	mi.global_basis = bs * Basis.from_scale(Vector3(r, 1.0, r))
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_grow": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, sweep).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.04)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life)
	tw.tween_callback(mi.queue_free)


## Cel toz bulutu: p'den vel ile kayar, büyür, delik delik dağılır
static func _dust(pj: PathJutsu, p: Vector3, s: float, life: float, vel: Vector3, col: Color, delay := 0.0) -> void:
	var mi = _gi(_quad(), _mat("dust", DUST_SHADER))
	_put(pj, mi, p)
	mi.scale = Vector3.ONE * s * 0.6
	mi.visible = delay <= 0.0
	_ipar(mi, {"k_col": col, "k_a": 1.0, "k_seed": randf() * 10.0})
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mi, "global_position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * s * 1.5, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Yerde dışa itilen toz halkası
static func _dust_ring(pj: PathJutsu, c: Vector3, r0: float, r1: float, n: int, s: float, life: float, col: Color, up := 0.3) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / n
		var dv = Vector3(cos(a), 0.0, sin(a))
		_dust(pj, c + dv * r0 + UP * s * 0.35, s * randf_range(0.75, 1.15), life * randf_range(0.8, 1.1), dv * (r1 - r0) / life + UP * up, col, randf() * 0.05)


## Basınç halkası: normal yönüne dik, r0→r1 açılır; o: move (kayma), th (bant kalınlığı), line (ak çizgi), col
static func _ring(pj: PathJutsu, at: Vector3, normal: Vector3, r0: float, r1: float, life: float, o := {}) -> MeshInstance3D:
	var mi = _gi(_quad(), _mat("ring", RING_SHADER))
	_put(pj, mi, at)
	mi.global_basis = _basis(normal)
	mi.scale = Vector3.ONE * r0 * 2.0
	_ipar(mi, {"k_col": o.get("col", JUKEN), "k_a": 1.0, "k_th": float(o.get("th", 0.16)), "k_line": float(o.get("line", 1.0))})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if o.has("move"):
		var mv: Vector3 = o["move"]
		tw.parallel().tween_property(mi, "global_position", at + mv, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Zemin izi (çatlak / sürtme yarığı / süpürülmüş zemin)
static func _decal(pj: PathJutsu, p: Vector3, r: float, mode: int, life: float, dir := Vector3.FORWARD, col := Color(0.08, 0.06, 0.05), grow := 0.2) -> void:
	var mi = _gi(_plane(), _mat("decal", DECAL_SHADER))
	_put(pj, mi, pj.gp(p) + UP * 0.04)
	mi.global_basis = _basis(_flat(dir)) * Basis.from_scale(Vector3(r, 1.0, r))
	_ipar(mi, {"k_mode": float(mode), "k_seed": randf() * 20.0, "k_col": col, "k_grow": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, grow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.8)
	tw.tween_callback(mi.queue_free)


## Çakra toplanması: çevreden noktaya akan ince çizgiler
static func _gather(pj: PathJutsu, at: Vector3, col: Color, n: int, r: float, dur: float) -> void:
	for i in n:
		var dv = _rdir3()
		var from = at + dv * r * randf_range(0.7, 1.1)
		_line(pj, from, -dv, randf_range(0.25, 0.4), 0.035, col, JDEEP, dur, -dv * r * 0.85, 0.03)


## Kaguya imzası: alında iki kırmızı nokta
static func _mark(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var b = MB.new()
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.022, 0.1, 0.105), Vector3(0.017, 0.017, 0.006), Color(0.78, 0.08, 0.1), Vector3.ZERO, 8)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hb.add_child(mi)
	pj.free_after(dur, hb)


## Byakugan: oyunun göz sistemiyle damarlı ak gözler; süre sonunda gözün kendi durumuna döner
static func _byaku(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_dojutsu_eyes"):
		return
	m.set_dojutsu_eyes(2, 1, 2, 1, true)
	pj.after(dur, func():
		if is_instance_valid(c) and c.get("model"):
			if c is Player and c.combat and c.combat.modes and c.combat.modes.eyes:
				c.combat.modes.eyes.refresh_visual()
			else:
				c.model.set_dojutsu_eyes(0, 0, 0, 0, false))


## Gerçek kemiklerden fışkıran dikenler (Karamatsu, Yaemugura, Kazaguruma): her kemiğe n diken, dur sonunda ufalanır.
## İskelet yoksa gövde çevresine aynı dikenler.
static func _body_bones(pj: PathJutsu, c: Node3D, bones: Array, dur: float, n_per: int, l0: float, l1: float, w: float) -> void:
	var any = false
	for bn in bones:
		var ba = pj.bone_attach(c, String(bn))
		if ba == null:
			continue
		any = true
		var nm = String(bn)
		var rr = 0.12 if nm in ["UpperChest", "Chest", "Spine", "Hips"] else (0.075 if nm.ends_with("Leg") else 0.055)
		for i in n_per:
			var dir = Vector3(randf_range(-1.0, 1.0), randf_range(-0.35, 0.55), randf_range(-1.0, 1.0))
			if Vector2(dir.x, dir.z).length() < 0.2:
				dir.x = 0.8
			dir = dir.normalized()
			var sp = Node3D.new()
			ba.add_child(sp)
			sp.position = Vector3(dir.x, 0.0, dir.z).normalized() * rr + UP * randf_range(-0.02, 0.18)
			sp.basis = _ybasis(dir)
			sp.add_child(_bone_mi(_spike_mesh(i % 4, 2.4, false), IVORY))
			_pop(sp, Vector3(w, randf_range(l0, l1), w), 0.13, randf() * 0.08)
		_crumble(ba, dur, 0.3)
		pj.free_after(dur + 0.6, ba)
	if any:
		return
	var root = Node3D.new()
	_put(pj, root, c.global_position)
	for i in n_per * 6:
		var dir = Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.9), randf_range(-1.0, 1.0)).normalized()
		var sp = Node3D.new()
		root.add_child(sp)
		sp.position = Vector3(dir.x, 0.0, dir.z).normalized() * 0.3 + UP * randf_range(0.4, 1.5)
		sp.basis = _ybasis(dir)
		sp.add_child(_bone_mi(_spike_mesh(i % 4, 2.4, false), IVORY))
		_pop(sp, Vector3(w, randf_range(l0, l1), w), 0.13, randf() * 0.08)
	var fol = func(_x: float) -> void:
		if is_instance_valid(root) and is_instance_valid(c):
			root.global_position = c.global_position
	var tw = root.create_tween()
	tw.tween_method(fol, 0.0, dur, dur)
	tw.tween_method(_dis_all(root), 0.0, 1.05, 0.3)
	tw.tween_callback(root.queue_free)


## Ön koldan fışkıran kemik kılıç (gerçek ön kol kemiğine bağlı)
static func _arm_sword(pj: PathJutsu, c: Node3D, arm: String, len_: float, dur: float) -> void:
	var ba = pj.bone_attach(c, arm)
	if ba == null:
		return
	var mi = _bone_mi(_arm_sword_mesh(len_), IVORY)
	ba.add_child(mi)
	_pop(mi, Vector3.ONE, 0.12)
	_crumble(ba, dur, 0.25)
	pj.free_after(dur + 0.5, ba)


## Basınç dikeni taraması (avuç kökü ref'i): çarpma noktasının çevresinde üçlü kısa paralel çizgi kümeleri dışa savrulur
static func _hatch(pj: PathJutsu, at: Vector3, d: Vector3, n: int, r: float, col: Color, edge: Color) -> void:
	for j in n:
		var a = TAU * (j + randf_range(-0.3, 0.3)) / n
		var sd = _side(d)
		var out = (sd * cos(a) + UP * sin(a) + d * randf_range(-0.2, 0.5)).normalized()
		var perp = out.cross(d).normalized()
		if perp.length() < 0.1:
			perp = UP
		var cen = at + out * r * randf_range(0.45, 0.9)
		for q in 3:
			var o2 = perp * (q - 1) * 0.06 + out * randf_range(-0.05, 0.05)
			_line(pj, cen + o2, out, randf_range(0.28, 0.48), 0.028, col, edge, randf_range(0.16, 0.24), out * randf_range(0.3, 0.6), 0.03)


# ================================================================== 1) Tomogoroshi no Haikotsu
## Ref (Kaguya Ōtsutsuki): sırttan yelpaze gibi gri kemik dikenleri açılır, avuçtan kül grisi uzun kemik iğneleri fırlar.
## Saplanan iğne hedefte kalır; hedefin yüzeyinden kül pulları kopup savrulur, ayak dibine gri kül çöker.
static func tomogoroshi_no_haikotsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 30.0)
	_back_fan(pj, c, 1.3)
	_palm_tips(pj, c, 0.75)
	for k in 5:
		pj.after(0.25 + k * 0.08, func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, true)
			var holder = Node3D.new()
			holder.add_child(_bone_mi(_needle_mesh(k % 3), ASH_T))
			var tail = _gi(_strip_mesh(), _mat("streak", STREAK_SHADER))
			holder.add_child(tail)
			tail.basis = Basis.from_scale(Vector3(0.05, 0.05, 1.5))
			tail.position = Vector3(0, 0, 1.55)
			_ipar(tail, {"k_col": Color(0.85, 0.85, 0.86), "k_edge": Color(0.4, 0.4, 0.42), "k_grow": 1.0, "k_a": 0.55})
			var d = (pj.aim_at(c, tt, from) + Vector3(randf_range(-0.06, 0.06), randf_range(-0.03, 0.05), 0)).normalized()
			pj.shot(c, from, d, 44.0, holder, pj.inf(c, "tomogoroshi_no_haikotsu", 0.8, {"knock": 2.0, "kind": "heavy", "bleed": 3.0}), tt, false, 1.0, func(p, h):
				_ash_hit(pj, p, h, d))
			_dust(pj, from + d * 0.2, 0.22, 0.3, d * 1.5, ASH_DUST))
	Sfx.play("blade", c.global_position, 1.1)


## Sırttan (gerçek göğüs kemiğine bağlı) arkaya-yukarı açılan gri kemik yelpazesi
static func _back_fan(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "UpperChest")
	if ba == null:
		return
	for i in 6:
		var a = lerpf(-1.0, 1.0, i / 5.0)
		var dir = Vector3(a * 0.75, 0.45 + (1.0 - absf(a)) * 0.4, -0.75).normalized()
		var sp = Node3D.new()
		ba.add_child(sp)
		sp.position = Vector3(a * 0.1, 0.04, -0.13)
		sp.basis = _ybasis(dir)
		sp.add_child(_bone_mi(_spike_mesh(i % 4, 1.2, false), ASH_T))
		_pop(sp, Vector3(0.11, randf_range(0.85, 1.25) * (1.15 - absf(a) * 0.3), 0.11), 0.16, 0.03 * i)
	_crumble(ba, dur, 0.4)
	pj.free_after(dur + 0.6, ba)


## Avuçtan (el kemiği +Y, parmak yönü) çıkan kısa gri kemik uçları
static func _palm_tips(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	for i in 3:
		var sp = Node3D.new()
		ba.add_child(sp)
		sp.position = Vector3((i - 1) * 0.025, 0.06, 0.0)
		sp.basis = _ybasis(Vector3((i - 1) * 0.2, 1.0, 0.1))
		sp.add_child(_bone_mi(_spike_mesh(i, 0.6, false), ASH_T))
		_pop(sp, Vector3(0.035, 0.24, 0.035), 0.1, 0.05 * i)
	_crumble(ba, dur, 0.3)
	pj.free_after(dur + 0.5, ba)


## Kül kemiği isabeti: iğne hedefte kalır, hedeften kül pulları kopar
static func _ash_hit(pj: PathJutsu, p: Vector3, h, d: Vector3) -> void:
	_chips(pj, p, 5, 4.0, ASH_T, 0.7)
	for i in 4:
		_dust(pj, p + _rdir3() * 0.2, randf_range(0.35, 0.55), randf_range(0.6, 0.9), _rdir3() * 0.8 + UP * 0.6, ASH_DUST, i * 0.03)
	if h == null or not is_instance_valid(h) or not pj.live(h):
		return
	var hh = float(h.get("height")) if h.get("height") != null else 1.8
	var hr = float(h.get("radius")) if h.get("radius") != null else 0.38
	var stuck = Node3D.new()
	h.add_child(stuck)
	stuck.global_position = p
	stuck.global_basis = _basis(d)
	var nd = _bone_mi(_needle_mesh(0), ASH_T)
	stuck.add_child(nd)
	nd.position = Vector3(0, 0, 0.35)
	_crumble(stuck, 1.0, 0.5)
	var hp: Vector3 = h.global_position
	var yh = clampf(p.y - hp.y, 0.3, hh)
	for i in 14:
		var a = randf() * TAU
		var y = clampf(yh + randf_range(-0.7, 0.7), 0.2, hh)
		var fl = _bone_mi(_flake_mesh(i % 3), Color(0.58, 0.58, 0.6))
		_put(pj, fl, hp + Vector3(cos(a) * hr, y, sin(a) * hr))
		fl.scale = Vector3.ONE * randf_range(0.7, 1.3)
		var v = Vector3(cos(a), 0.0, sin(a)) * randf_range(0.6, 1.6) + UP * randf_range(0.3, 1.2)
		_drift(pj, fl, v, randf_range(1.0, 1.5), i * 0.04)
	for i in 5:
		var gq = pj.gp(hp + _rdir() * randf_range(0.1, hr + 0.3))
		_dust(pj, gq + UP * 0.15, randf_range(0.4, 0.6), randf_range(0.9, 1.3), _rdir() * 0.6 + UP * 0.1, ASH_DUST, 0.2 + i * 0.06)


## Kül pulu süzülmesi: hafif yerçekimi, dönerek kayar, ufalanır
static func _drift(pj: PathJutsu, n: Node3D, v: Vector3, life: float, delay: float) -> void:
	var p0 = n.global_position
	var rax = _rdir3()
	var b0 = n.global_basis
	n.visible = delay <= 0.0
	var step = func(tt: float) -> void:
		if not is_instance_valid(n):
			return
		var drag = 1.0 - exp(-tt * 2.2)
		n.global_position = p0 + v * drag / 2.2 + Vector3.DOWN * 0.9 * tt * tt
		n.global_basis = Basis(rax, tt * 7.0) * b0
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): n.visible = true)
	tw.tween_method(step, 0.0, life, life)
	tw.parallel().tween_method(_dis_all(n), 0.0, 1.05, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


# ================================================================== 2) Tsubaki no Mai
## Ref: Kimimaro omzundan çektiği ince uzun kemik kılıçla saplar; saplamada ince ak kesik çizgisi parlar.
## Omuzdan kemik ucu belirip çekilir, kılıç sağ elde (gerçek el kemiği); her saplamada ince delici çizgi, uçta kıymık yıldızı,
## ayakta kayma tozu.
static func tsubaki_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_mark(pj, c, 2.0)
	_shoulder_draw(pj, c)
	var sw = pj.bone_attach(c, "RightHand")
	if sw:
		var bl = _bone_mi(_hand_sword_mesh(1.3), IVORY)
		sw.add_child(bl)
		_pop_u(bl, 0.12, 0.06)
		_crumble(sw, 1.4, 0.3)
		pj.free_after(1.9, sw)
	pj.busy(c, 1.2)
	pj.every(1.2, 0.2, func(i, _k):
		var d = pj.fwd(c, t)
		c.velocity = d * 9.0 + Vector3(0, c.velocity.y, 0)
		pj.anim(c, ["jab", "cross"][i % 2], 2.6)
		var p = c.global_position + UP * 1.1
		for k in 3:
			pj.hit(c, p + d * (1.0 + k * 0.9), 0.7, pj.inf(c, "tsubaki_no_mai", 0.3, {"knock": 2.0, "kind": "light", "burn": 1.0}))
		_thrust_fx(pj, c, p, d, i)
		Sfx.play("kunai", p, 1.3))


## Sol omuzdan bir an beliren, çekilip ele geçen kemik ucu
static func _shoulder_draw(pj: PathJutsu, c: Node3D) -> void:
	var ba = pj.bone_attach(c, "LeftShoulder")
	if ba == null:
		return
	var sp = Node3D.new()
	ba.add_child(sp)
	sp.position = Vector3(0, 0.08, 0.04)
	sp.basis = _ybasis(Vector3(0.2, 1.0, 0.4))
	sp.add_child(_bone_mi(_spike_mesh(1, 0.4, false), IVORY))
	_pop(sp, Vector3(0.06, 0.35, 0.06), 0.08)
	_crumble(ba, 0.14, 0.12)
	pj.free_after(0.6, ba)


## Saplama izi: delici ince çizgi + uçta kemik kıymığı yıldızı + ayakta kayma tozu
static func _thrust_fx(pj: PathJutsu, c: Node3D, p: Vector3, d: Vector3, i: int) -> void:
	var sd = _side(d)
	var y = randf_range(-0.12, 0.12)
	var from = p + d * 0.5 + UP * y + sd * (0.12 if i % 2 == 0 else -0.08)
	_line(pj, from, d, 2.5, 0.07, Color(1.0, 1.0, 0.97), Color(0.55, 0.56, 0.62), 0.16, d * 0.4, 0.04)
	_line(pj, from + UP * 0.05, d, 1.6, 0.03, Color(0.96, 0.97, 1.0), INKC, 0.12, d * 0.8, 0.03)
	var tip = from + d * 2.6
	for q in 5:
		var a = TAU * q / 5.0 + randf_range(-0.3, 0.3)
		var out = (d * 0.9 + sd * cos(a) * 0.6 + UP * sin(a) * 0.6).normalized()
		_line(pj, tip, out, randf_range(0.22, 0.38), 0.03, IVORY, INKC, 0.14, out * 0.3, 0.02)
	_chips(pj, tip, 3, 3.5)
	if i % 2 == 0 and is_instance_valid(c):
		var fq = pj.gp(c.global_position)
		_dust(pj, fq + UP * 0.15 - d * 0.3, 0.32, 0.4, -d * 1.5 + UP * 0.3, _gcol(fq))


# ================================================================== 3) Yaemugura no Mai
## Ref: iki kemik kılıçla dalış, sonra bedenden dev yassı kıvrık kemik şeritleri yelpaze gibi fışkırır.
## İki çapraz kesik yayı, saplama sağanağında ince delici çizgiler, bitirişte gerçek kemiklerden dikenler +
## göğüsten dışa açılan 14 uzun kıvrık kemik şerit, ayak altında çatlak ve toz halkası.
static func yaemugura_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 2.0)
	_mark(pj, c, 2.2)
	_arm_sword(pj, c, "RightLowerArm", 0.95, 1.9)
	_arm_sword(pj, c, "LeftLowerArm", 0.95, 1.9)
	pj._jump_at(c, tt, 3.5, 12.0)
	pj.anim(c, "slash_a", 1.6)
	for k in 2:
		pj.after(0.28 + k * 0.17, func():
			if not pj.live(c):
				return
			var d = pj.fwd(c, tt)
			var at = c.global_position + UP * 1.1 + d * 1.2
			pj.anim(c, "slash_b" if k == 0 else "slash_c", 2.2)
			var roll = 28.0 if k == 0 else -28.0
			var bs = _basis(d) * Basis(Vector3(0, 0, 1), deg_to_rad(roll))
			_arc(pj, at - d * 0.9, bs, 1.9, -70.0 if k == 0 else 70.0, 70.0 if k == 0 else -70.0, 0.14, IVORY, Color(0.5, 0.52, 0.58), 0.2)
			_arc(pj, at - d * 0.9, bs, 1.6, -60.0 if k == 0 else 60.0, 60.0 if k == 0 else -60.0, 0.06, Color(1, 1, 1), INKC, 0.14, 0.06)
			pj.hit(c, at, 2.0, pj.inf(c, "yaemugura_no_mai", 0.5, {"knock": 1.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.05}))
			Sfx.play("blade", at, 1.1))
	for k in 6:
		pj.after(0.7 + k * 0.09, func():
			if not pj.live(c):
				return
			var d = pj.fwd(c, tt)
			c.velocity = d * 4.0 + Vector3(0, c.velocity.y, 0)
			pj.anim(c, "jab" if k % 2 == 0 else "cross", 3.2)
			var at = c.global_position + UP * randf_range(0.8, 1.4) + d * 1.3
			_line(pj, at - d * 0.9, d, 1.9, 0.06, IVORY, Color(0.5, 0.52, 0.58), 0.12, d * 0.5, 0.03)
			_chips(pj, at + d * 0.6, 2, 3.0)
			pj.hit(c, at, 1.4, pj.inf(c, "yaemugura_no_mai", 0.2, {"knock": 8.0 if k == 5 else 0.5, "kind": "light", "bleed": 1.0}))
			Sfx.play("kunai", at, 1.4))
	pj.after(1.4, func():
		if not pj.live(c):
			return
		if pj.live(tt):
			var d = pj.fwd(c, tt)
			c.global_position = pj.gp(tt.global_position + d * 1.5)
			if "facing" in c:
				c.facing = atan2(d.x, d.z)
		_body_bones(pj, c, ["UpperChest", "Spine", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"], 0.5, 3, 0.35, 0.65, 0.08)
		var o = c.global_position + UP * 1.1
		for q in 14:
			var dir = Vector3(randf_range(-1.0, 1.0), randf_range(-0.25, 0.7), randf_range(-1.0, 1.0)).normalized()
			var sp = Node3D.new()
			_put(pj, sp, o + dir * 0.25)
			sp.global_basis = _ybasis(dir) * Basis(UP, randf() * TAU)
			sp.add_child(_bone_mi(_ribbon_mesh(q % 6), IVORY))
			var L = randf_range(1.8, 2.8)
			_pop(sp, Vector3(L, L, L), 0.1, q * 0.008)
			_crumble(sp, 0.42 + randf() * 0.1, 0.35)
		_chips(pj, o, 14, 8.0)
		var g = pj.gp(c.global_position)
		_decal(pj, g, 2.8, 0, 2.0)
		_dust_ring(pj, g, 0.6, 3.2, 10, 0.6, 0.6, _gcol(g))
		pj.hit(c, o, 3.0, pj.inf(c, "yaemugura_no_mai", 1.7, {"knock": 12.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12}))
		pj.shake(0.6)
		Sfx.play("hit_heavy", o, 1.0))


# ================================================================== 4) Kazaguruma
## Ref (yel değirmeni): hedefin tepesinde belirir, bedenden kemikler + kollardan kemik kılıçlar, altında sarmal kemik ucu ve
## yel değirmeni kanatları gibi dört kemik; dönerek iner — çevresinde yatay dönüş yayları, yukarıda dikey hız çizgileri.
## İnişte matkap yere saplanıp ufalanır, yerde yıldız çatlak, kıymık ve toz halkası.
static func kazaguruma(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Üstüne inilecek hedef yok", Color(1, 0.7, 0.5))
		return
	pj.busy(c, 1.3)
	_mark(pj, c, 1.6)
	_chips(pj, c.global_position + UP, 8, 5.0)
	_dust(pj, c.global_position + UP * 0.6, 0.6, 0.4, UP * 0.6, BONE_DUST)
	var top = tt.global_position + UP * 7.0
	c.global_position = top
	_body_bones(pj, c, ["UpperChest", "Spine", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"], 1.1, 3, 0.3, 0.55, 0.07)
	_arm_sword(pj, c, "RightLowerArm", 1.3, 1.2)
	_arm_sword(pj, c, "LeftLowerArm", 1.3, 1.2)
	pj.anim(c, "air", 1.0)
	var drill = Node3D.new()
	drill.add_child(_bone_mi(_windmill_mesh(), IVORY))
	_put(pj, drill, top)
	_pop_u(drill, 0.15)
	var hits = {"n": 0, "tick": 0}
	var k_tick = func(_i, k):
		if not pj.live(c):
			return
		var base = (tt.global_position if pj.live(tt) else top - UP * 7.0)
		var p = top.lerp(base + UP * 0.3, k * k)
		c.global_position = p
		if c is CharacterBody3D:
			c.velocity = Vector3.ZERO
		if "facing" in c:
			c.facing += 0.9
		if is_instance_valid(drill):
			drill.global_position = p + UP * 0.4
			drill.rotation.y += 1.1
		hits["tick"] += 1
		if hits["tick"] % 4 == 0:
			var bs = Basis(UP, randf() * TAU)
			_arc(pj, p + UP * randf_range(0.2, 1.0), bs, randf_range(1.2, 1.7), -100.0, 100.0, 0.1, IVORY, Color(0.55, 0.57, 0.63), 0.14, 0.05)
			var sd = _rdir()
			_line(pj, p + UP * 2.4 + sd * randf_range(0.3, 0.8), Vector3.DOWN, randf_range(1.6, 2.6), 0.05, Color(0.97, 0.98, 1.0), INKC, 0.18, Vector3.DOWN * 0.8, 0.03)
		if k > 0.55 and int(k * 20.0) > hits["n"]:
			hits["n"] = int(k * 20.0)
			pj.hit(c, p, 2.2, pj.inf(c, "kazaguruma", 0.3, {"knock": 0.0, "kind": "light", "bleed": 1.5, "hitstop": 0.03}))
			_chips(pj, p, 3, 6.0)
	var k_done = func():
		if not pj.live(c):
			if is_instance_valid(drill):
				drill.queue_free()
			return
		var p = pj.gp(c.global_position)
		if is_instance_valid(drill):
			drill.global_position = p + UP * 0.9
			_crumble(drill, 0.5, 0.4)
		_decal(pj, p, 5.0, 0, 2.5)
		_chips(pj, p + UP * 0.5, 18, 9.0)
		_dust_ring(pj, p, 0.6, 4.2, 12, 0.75, 0.7, _gcol(p))
		pj.hit(c, p + UP * 0.8, 3.2, pj.inf(c, "kazaguruma", 1.4, {"knock": 12.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.12}))
		pj.shake(0.8)
		Sfx.play("hit_heavy", p, 0.9)
	pj.every(0.6, 1.0 / 60.0, k_tick, k_done)
	Sfx.play("wind", top, 1.4)


# ================================================================== 5) Tessenka no Mai: Hana
## Ref: koldan öne uzanan dev, sivri, sarmal katmanlı kemik matkap (katman araları koyu çizgi).
## Önce çekirdek, sonra altı sarmal katman sırayla sarılır; atılışta matkap döner, ardında sarmal hız çizgileri ve zemin
## sürtme izi; isabette ileri saçılan kemik kıymıkları + delici şok taraması; sonunda matkap ufalanır.
static func tessenka_no_mai_hana(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_mark(pj, c, 2.0)
	var host: Node3D = c
	var md = c.get("model")
	if md != null and is_instance_valid(md) and md is Node3D:
		host = md
	var drill = Node3D.new()
	host.add_child(drill)
	drill.position = Vector3(-0.28, 1.1, -0.35)
	var core = _bone_mi(_drill_core_mesh(), IVORY)
	drill.add_child(core)
	_pop_u(core, 0.3)
	for sp in 6:
		var pl = _bone_mi(_drill_plate_mesh(sp), IVORY)
		drill.add_child(pl)
		_pop_u(pl, 0.22, 0.08 + sp * 0.045)
	_crumble(drill, 1.3, 0.35)
	pj.free_after(1.9, drill)
	pj.busy(c, 1.2)
	pj.after(0.5, func():
		var hits = []
		var st = {"n": 0}
		Jutsu._dash(c, t, 0.35, 34.0, func(pt):
			if is_instance_valid(drill):
				drill.rotation.z += 0.8
			var bound_mul = 1.0
			for e2 in pj.enemies_near(c, pt + c.face_dir() * 1.5, 1.8):
				if e2.has_method("has_status") and e2.has_status("bind"):
					bound_mul = 1.6
			for h in pj.hit(c, pt + c.face_dir() * 1.5, 1.8, pj.inf(c, "tessenka_no_mai_hana", 1.7 * bound_mul, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "pierce_guard": true, "hitstop": 0.1}), hits):
				hits.append(h)
				_drill_impact(pj, h.global_position + UP, c.face_dir())
			st["n"] += 1
			if st["n"] % 3 == 1:
				var fd: Vector3 = c.face_dir()
				var a = st["n"] * 0.9
				var off = _side(fd) * cos(a) * 0.5 + UP * sin(a) * 0.5
				_line(pj, pt + off - fd * 0.5, -fd, randf_range(1.6, 2.4), 0.05, IVORY, Color(0.55, 0.57, 0.63), 0.2, Vector3.ZERO, 0.03)
				var g = pj.gp(c.global_position)
				_dust(pj, g + UP * 0.2, 0.4, 0.45, -fd * 2.0 + UP * 0.4, _gcol(g)))
		var fd0: Vector3 = c.face_dir()
		_decal(pj, c.global_position + fd0 * 6.0, 6.5, 1, 1.4, fd0, Color(0.1, 0.08, 0.06), 0.35))
	Sfx.play("whoosh", c.global_position, 0.6)


## Matkap isabeti: ileri saçılan kıymık + delici şok taraması + arkadan çıkan kemik tozu
static func _drill_impact(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	_chips(pj, at + d * 0.3, 10, 8.0)
	_hatch(pj, at, d, 7, 1.1, IVORY, Color(0.5, 0.52, 0.58))
	for i in 3:
		_dust(pj, at + d * (0.6 + i * 0.3), 0.45, 0.5, d * 3.0 + _rdir3() * 0.6, BONE_DUST, i * 0.03)


# ================================================================== 6) Karamatsu no Mai
## Ref: kollardan, omuzlardan, göğüsten her yöne uzun, ince, kıvrık ak dikenler. Gerçek kemiklere bağlı ~40 diken sırayla
## fışkırır, 5 sn kalır, sonra ufalanır; çıkışta ayak dibinde kemik tozu halkası ve kıymıklar.
static func karamatsu_no_mai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_mark(pj, c, 8.0)
	_body_bones(pj, c, ["UpperChest", "Chest", "Spine", "LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"], 5.0, 3, 0.4, 0.8, 0.075)
	var g = pj.gp(c.global_position)
	_dust_ring(pj, g, 0.4, 2.2, 9, 0.45, 0.55, BONE_DUST, 0.5)
	_chips(pj, c.global_position + UP * 1.1, 10, 5.0)
	Buffs.add("karamatsu", 5.0, {"_name": "Karamatsu no Mai", "_desc": "yakın dövüşle vuran kemiklere saplanır"})
	Sfx.play("hit_heavy", c.global_position, 1.1)


# ================================================================== 7) Sawarabi no Mai
## Ref: yerden çok sık, ince, sivri, ak-mavimsi kemik bıçaklardan bir orman (kimi çatallı). Merkezden dışa dalga dalga yükselir;
## her diken kendi koni şeklinde katı (çarpışma görselden), 10 sn duvar gibi kalır, sonra gömülüp ufalanır.
## Zeminde dev yıldız çatlak, diken diplerinde toz.
static func sawarabi_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_mark(pj, c, 3.0)
	var center = pj.gp(Jutsu._aim_ground(c, t, 10.0, 25.0))
	_decal(pj, center, 12.0, 0, 11.0, Vector3.FORWARD, Color(0.08, 0.07, 0.07), 0.8)
	pj.busy(c, 0.8)
	var n = 120
	for k in n:
		var ring = sqrt(float(k) / n)
		var a = k * 2.4
		var p = center + Vector3(cos(a), 0, sin(a)) * ring * 18.0
		pj.after(ring * 0.8, func():
			var h = randf_range(3.5, 9.0) * (1.25 - ring * 0.4)
			_fern(pj, p, h, randf_range(0.22, 0.42), Vector3(randf_range(-18, 18), 0, randf_range(-18, 18)), 10.0, k % 4 == 0)
			for e in pj.enemies_near(c, p, 1.6):
				pj.hit(c, e.global_position + UP, 1.2, pj.inf(c, "sawarabi_no_mai", 0.7, {"knock": 2.0, "launch": 6.0, "kind": "heavy"}))
				pj.st(e, "bind", 2.0))
	pj.after(0.2, func():
		pj.shake(1.0)
		Sfx.play("earth", center, 0.6))
	# kanon: lanet mührü II'deyken Kimimaro kemik ormanıyla birleşir, hedefin kör noktasındaki kemikten çıkıp bitirir
	var j2 = Buffs.has("juin2") if c is Player else (c.get("buffs") != null and c.buffs.has("juin2"))
	var tt = pj.tg(c, t, 30.0)
	if j2 and tt:
		pj.after(1.3, func():
			if not (pj.live(c) and pj.live(tt)):
				return
			var back = -tt.face_dir() if tt.has_method("face_dir") else Vector3.BACK
			_chips(pj, c.global_position + UP, 10, 6.0, FERN_T)
			c.global_position = pj.gp(tt.global_position + back * 1.4)
			_fern(pj, c.global_position, 3.0, 0.9, Vector3.ZERO, 1.0, true)
			if c is Player:
				c.combat.face_to(tt)
			pj.anim(c, "cross", 2.0)
			Combat.popup_text(tt.global_position + UP * 2.5, "Kemikten çıktı!", Color(0.97, 0.95, 0.88))
			pj.hit(c, tt.global_position + UP, 1.3, pj.inf(c, "sawarabi_no_mai", 1.4, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "pierce_guard": true})))


## Kemik ormanı dikeni: yerden fışkırır, kendi koni şeklinde katı, dur sn kalır, gömülüp ufalanır
static func _fern(pj: PathJutsu, p: Vector3, h: float, w: float, tilt: Vector3, dur: float, dusty: bool) -> void:
	var root = Node3D.new()
	_put(pj, root, pj.gp(p) - UP * 0.15)
	root.rotation_degrees = tilt
	var v = randi() % 8
	var mi = _bone_mi(_spike_mesh(v, 0.35, v % 3 == 2), FERN_T)
	mi.scale = Vector3(w, h, w)
	root.add_child(mi)
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var shp = ConvexPolygonShape3D.new()
	var pts = PackedVector3Array()
	for i in 6:
		var a = TAU * i / 6.0
		pts.append(Vector3(cos(a) * w * 0.45, 0.0, sin(a) * w * 0.45))
	pts.append(Vector3(0.0, h * 0.92, 0.0))
	shp.points = pts
	cs.shape = shp
	sb.add_child(cs)
	root.add_child(sb)
	root.scale = Vector3(1.0, 0.02, 1.0)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.0, 1.06, 1.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3.ONE, 0.06)
	tw.tween_interval(dur)
	tw.tween_property(root, "scale", Vector3(1.0, 0.3, 1.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_dis_all(root), 0.0, 1.05, 0.45)
	tw.tween_callback(root.queue_free)
	if dusty:
		var g = pj.gp(p)
		var col = _gcol(g)
		for i in 2:
			_dust(pj, g + UP * 0.25, randf_range(0.5, 0.75), randf_range(0.5, 0.8), _rdir() * 1.6 + UP * 0.8, col, i * 0.05)


# ================================================================== 8) Hakke Kūshō
## Ref (Hinata): avuç ileri itilir, avucun önünde hava bükülür. Byakugan damarları açılır, avuca çakra çizgileri toplanır;
## salınımda avuçta küçük sıkışma halkası, dar koni boyunca ileri kayan beş kırılma halkası, ince hava çizgileri,
## yerde dar hat boyunca kalkan toz ve sürtme izi, menzil sonunda toz patlaması.
static func hakke_kusho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 18.0)
	var d = pj.fwd(c, tt)
	_byaku(pj, c, 1.2)
	_gather(pj, pj.hand_pos(c, true), JUKEN, 10, 0.9, 0.15)
	pj.after(0.15, func():
		if not pj.live(c):
			return
		var hp = pj.hand_pos(c, true)
		var o = c.global_position + UP * 1.2
		_ring(pj, hp + d * 0.2, d, 0.12, 0.85, 0.22, {"th": 0.3})
		for k in 5:
			pj.after(k * 0.035, func():
				var d0 = 0.8 + k * 0.4
				var d1 = 3.0 + k * 2.6
				_ring(pj, o + d * d0, d, 0.35 + k * 0.05, 0.5 + d1 * 0.13, 0.32, {"move": d * (d1 - d0), "th": 0.18, "line": 0.9}))
		var sd = _side(d)
		for k in 9:
			var off = sd * randf_range(-0.6, 0.6) + UP * randf_range(-0.5, 0.5)
			_line(pj, o + off + d * randf_range(0.5, 2.0), d, randf_range(3.0, 6.0), 0.05, Color(0.95, 0.98, 1.0), JDEEP, 0.25, d * randf_range(4.0, 7.0))
		for k in 7:
			var gq = pj.gp(c.global_position + d * (1.5 + k * 1.8))
			_dust(pj, gq + UP * 0.2, 0.5 + k * 0.06, 0.6, d * 3.0 + UP * 0.6 + sd * randf_range(-1.0, 1.0), _gcol(gq), k * 0.03)
		_decal(pj, c.global_position + d * 7.0, 7.0, 1, 1.6, d, Color(0.1, 0.08, 0.06), 0.25)
		var endp = pj.gp(c.global_position + d * 14.0)
		pj.after(0.22, func():
			_dust_ring(pj, endp, 0.3, 2.4, 8, 0.6, 0.5, _gcol(endp), 0.8)
			_ring(pj, endp + UP * 1.2, d, 0.8, 2.2, 0.25, {"th": 0.2, "line": 0.7}))
		Combat.hit_zone(c, c.global_position, d, 14.0, 15.0, 3.0, pj.inf(c, "hakke_kusho", 1.2, {"knock": 22.0, "launch": 3.0, "kind": "heavy"}))
		pj.shake(0.4))
	Sfx.play("wind", c.global_position, 1.1)


# ================================================================== 9) Hakke Kūhekishō
## Ref: iki avuç; önünde yatay bulanık çizgilerle akan geniş hava duvarı. Duvar 35 derecelik yay halinde ileri koşar
## (arkasındaki dünya bükülür, yatay hareket bantları), önünde yerden kalkan toz cephesi, ardında süpürülmüş zemin izi.
static func hakke_kuhekisho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	_byaku(pj, c, 1.4)
	_gather(pj, pj.hand_pos(c, true), JUKEN, 8, 1.0, 0.2)
	_gather(pj, pj.hand_pos(c, false), JUKEN, 8, 1.0, 0.2)
	pj.after(0.2, func():
		if not is_instance_valid(c):
			return
		var base = pj.gp(c.global_position)
		for right in [true, false]:
			_ring(pj, pj.hand_pos(c, right) + d * 0.2, d, 0.15, 1.0, 0.25, {"th": 0.3})
		var wall = _gi(_wall_mesh(), _mat("wall", WALL_SHADER))
		_put(pj, wall, base)
		wall.global_basis = _basis(d)
		wall.scale = Vector3(1.5, 0.8, 1.5)
		_ipar(wall, {"k_a": 1.0, "k_seed": randf() * 10.0})
		var tw = wall.create_tween()
		tw.tween_property(wall, "scale", Vector3(16.0, 3.8, 16.0), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(_pf(wall, "k_a"), 1.0, 0.0, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_callback(wall.queue_free)
		var col = _gcol(base)
		pj.every(0.36, 0.04, func(_i, k):
			var R = lerpf(1.5, 16.0, sin(k * PI * 0.5))
			for q in 5:
				var a = deg_to_rad(lerpf(-16.0, 16.0, (q + randf()) / 5.0))
				var dv = d.rotated(UP, a)
				var gq = pj.gp(base + dv * R)
				_dust(pj, gq + UP * 0.3, randf_range(0.5, 0.8) + k * 0.4, 0.55, dv * 5.0 + UP * 0.6, col, 0.0))
		_decal(pj, base + d * 8.5, 8.5, 2, 1.8, d, Color(0.12, 0.1, 0.08), 0.38)
		Combat.hit_zone(c, c.global_position, d, 16.0, 35.0, 3.5, pj.inf(c, "hakke_kuhekisho", 1.6, {"knock": 24.0, "launch": 4.0, "kind": "heavy"}))
		pj.shake(0.6))
	Sfx.play("wind", c.global_position, 0.8)


# ================================================================== 10) Jūho Sōshiken
## Ref (Hinata): iki elde gövde boyunda yarı saydam mavi aslan başı; kenarı ak parlar, üstü alev dilli, önde koyu çizgili
## yüz (ak gözler, zikzak dişler). Avuçlara çakra çizgileri toplanır, ayakta çakra basınç halkası; baş eli izler,
## hızlı ileri vuruşta öne atılıp ısırır, 15 sn sonra söner.
static func juho_soshiken(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	pj.anim(c, "power", 1.2)
	_byaku(pj, c, 15.0)
	for side in ["RightHand", "LeftHand"]:
		_gather(pj, pj.hand_pos(c, side == "RightHand"), LION_RING, 10, 1.1, 0.3)
		_lion(pj, c, side, 15.0)
	_ring(pj, c.global_position + UP * 0.08, UP, 0.4, 2.6, 0.45, {"th": 0.12, "col": LION_RING})
	# kanon: menzil ve yıkıcılık artar, aslan başları dokunduğunun chakrasını emer (Combat._lion_drain); düşman da aynı buff'ı alır
	Buffs.add("juho_soshiken", 15.0, {"melee": 1.4, "reach": 1.4, "_name": "İkiz Aslan Yumrukları", "_desc": "aslan çakrası: yakın dövüş +%40, menzil +%40, vuruşlar chakra emer"})
	Sfx.play("fire", c.global_position, 1.2)


## Bir elin aslan başı: eli izler, yüzü bakış yönüne dönük; ileri savrulan yumrukla öne atılır
static func _lion(pj: PathJutsu, c: Node3D, bone: String, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.get("skel") == null:
		return
	var bi: int = m.skel.find_bone(bone)
	if bi < 0:
		return
	var root = Node3D.new()
	_put(pj, root, c.global_position)
	var head = _gi(_lion_mesh(), _lion_mat())
	root.add_child(head)
	head.scale = Vector3(0.86, 1.3, 0.72)
	head.position = Vector3(0, 0.14, -0.05)
	_ipar(head, {"k_seed": randf() * 10.0, "k_a": 1.0})
	var st = {"g": 0.02, "prev": Vector3.INF, "lunge": 0.0}
	var gt = root.create_tween()
	gt.tween_interval(0.15)
	gt.tween_method(func(x: float): st["g"] = x, 0.02, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gt.tween_interval(maxf(0.0, dur - 0.5))
	gt.tween_method(func(x: float): st["g"] = x, 1.0, 0.02, 0.3)
	var follow = func(_x: float) -> void:
		if not is_instance_valid(root):
			return
		if not is_instance_valid(c) or not is_instance_valid(m) or (c.has_method("is_dead") and c.is_dead()):
			root.queue_free()
			return
		var hp: Vector3 = m.skel.global_transform * m.skel.get_bone_global_pose(bi).origin
		var fd: Vector3 = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
		fd.y = 0.0
		if fd.length() < 0.01:
			fd = Vector3.FORWARD
		fd = fd.normalized()
		var dt = maxf(pj.get_process_delta_time(), 0.001)
		var pv: Vector3 = st["prev"]
		if pv != Vector3.INF:
			var cv: Vector3 = c.velocity if c.get("velocity") != null else Vector3.ZERO
			var vf = (hp - pv).dot(fd) / dt - cv.dot(fd)
			if vf > 3.0:
				st["lunge"] = minf(1.0, float(st["lunge"]) + dt * 9.0)
			else:
				st["lunge"] = maxf(0.0, float(st["lunge"]) - dt * 3.5)
		st["prev"] = hp
		var bite = sin(float(st["lunge"]) * PI * 0.5)
		var sc = float(st["g"]) * (1.0 + 0.18 * bite)
		root.global_transform = Transform3D(Basis.looking_at(fd, UP) * Basis.from_scale(Vector3(sc, sc, sc * (1.0 + 0.35 * bite))), hp + UP * 0.05 + fd * (0.1 + 0.7 * bite))
	follow.call(0.0)
	var ft = root.create_tween()
	ft.tween_method(follow, 0.0, dur + 0.2, dur + 0.2)
	ft.tween_callback(root.queue_free)


# ================================================================== 11) Shōtei
## Ref: avuç kökü göğse oturur, çarpma çevresinde kısa paralel ak çizgi kümeleri savrulur. Atılışta ayakta kayma tozu ve
## gövde hizasında hız çizgileri; temasta avuç önünde küçük sıkışma halkası + şok taraması; isabette çakra hedefin
## sırtından çıkar (arkada açılan halka + ileri fırlayan ince çizgiler).
static func shotei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.5)
	_byaku(pj, c, 0.9)
	var g0 = pj.gp(c.global_position)
	_dust(pj, g0 + UP * 0.15, 0.4, 0.4, -d * 2.0 + UP * 0.3, _gcol(g0))
	_decal(pj, g0 + d * 1.2, 1.4, 1, 0.8, d, Color(0.12, 0.1, 0.08), 0.15)
	var sd = _side(d)
	for k in 4:
		_line(pj, c.global_position + UP * randf_range(0.7, 1.6) + sd * randf_range(-0.5, 0.5) - d * 0.4, -d, randf_range(1.0, 1.6), 0.035, Color(0.96, 0.98, 1.0), INKC, 0.2, -d * 0.6, 0.03)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		pj.anim(c, "jab", 1.8)
		var at = c.global_position + UP * 1.2 + d * 1.2
		var hs = pj.hit(c, at, 1.8, pj.inf(c, "shotei", 1.3, {"knock": 20.0, "kind": "heavy"}))
		_ring(pj, at - d * 0.25, d, 0.1, 0.7, 0.16, {"th": 0.35})
		var tgt = at
		if not hs.is_empty() and is_instance_valid(hs[0]):
			tgt = hs[0].global_position + UP * 1.0
		_hatch(pj, tgt, d, 8, 1.1, Color(0.97, 0.98, 1.0), Color(0.45, 0.5, 0.6))
		if not hs.is_empty():
			_ring(pj, tgt + d * 0.45, d, 0.25, 1.3, 0.24, {"th": 0.22, "move": d * 0.8, "col": Color(0.75, 0.88, 1.0)})
			for q in 5:
				var off = sd * randf_range(-0.3, 0.3) + UP * randf_range(-0.3, 0.3)
				_line(pj, tgt + d * 0.4 + off, d, randf_range(0.8, 1.4), 0.04, Color(0.85, 0.93, 1.0), JDEEP, 0.18, d * 1.2, 0.03)
		Sfx.play("punch", at, 1.0))


# ================================================================== 12) Yasogami Kugeki
## Kaynak görsel yok — tasarım: Kaguya'nın omuzları arkasında yelpaze gibi açılan saydam "bin kol" hayaleti barajla
## ileri geri vurur; her vakum yumruğu arka planı büken küt önlü hava damlası, önünde ak basınç halkası, ardında iki ince
## iz; çıkışta her üç yumrukta bir fırlatma halkası, isabette yönlü halka ve hafif toz.
static func yasogami_kugeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	_ghost_arms(pj, c, d, 1.25)
	for k in 24:
		pj.after(0.2 + k * 0.04, func():
			if not pj.live(c):
				return
			var from = c.global_position + Vector3.UP * randf_range(0.8, 2.2) + side * randf_range(-1.2, 1.2) + d * 0.8
			var fist = _air_fist()
			var pr = pj.shot(c, from, (d + side * randf_range(-0.12, 0.12)).normalized(), 40.0, fist, pj.inf(c, "yasogami_kugeki", 0.25, {"knock": 4.0, "kind": "light", "element": "fuuton"}), null, false, 0.6, func(p, _h):
				_ring(pj, p, d, 0.3, 1.5, 0.2, {"th": 0.2, "line": 0.8})
				_dust(pj, p, 0.4, 0.35, d * 1.5 + _rdir3() * 0.5, Color(0.88, 0.9, 0.93)))
			pr.radius = 0.8
			if k % 3 == 0:
				_ring(pj, from + d * 0.4, d, 0.4, 1.4, 0.15, {"th": 0.25, "line": 0.6}))
	Sfx.play("wind", c.global_position, 1.2)


## Vakum yumruğu mermisi: kırılma gövdesi + önde basınç halkası + iki iz çizgisi (mermiyle döner, -Z ileri)
static func _air_fist() -> Node3D:
	var holder = Node3D.new()
	var body = _gi(_fist_mesh(), _mat("air", AIR_SHADER))
	holder.add_child(body)
	body.scale = Vector3(1.15, 1.15, 1.0)
	_ipar(body, {"k_col": Color(0.93, 0.96, 1.0), "k_a": 0.9})
	var rg = _gi(_quad(), _mat("ring", RING_SHADER))
	holder.add_child(rg)
	rg.position = Vector3(0, 0, -0.7)
	rg.scale = Vector3.ONE * 1.4
	_ipar(rg, {"k_col": Color(0.95, 0.97, 1.0), "k_a": 0.8, "k_th": 0.18, "k_line": 1.0})
	for sx in [-1.0, 1.0]:
		var tl = _gi(_strip_mesh(), _mat("streak", STREAK_SHADER))
		holder.add_child(tl)
		tl.basis = Basis.from_scale(Vector3(0.05, 0.05, 1.6))
		tl.position = Vector3(sx * 0.35, 0.1, 2.2)
		_ipar(tl, {"k_col": Color(0.96, 0.98, 1.0), "k_edge": Color(0.55, 0.6, 0.7), "k_grow": 1.0, "k_a": 0.6})
	return holder


## Bin kol hayaleti: omuzların arkasında yelpaze gibi on saydam hava kolu, barajda sırayla ileri vurup geri çekilir
static func _ghost_arms(pj: PathJutsu, c: Node3D, d: Vector3, dur: float) -> void:
	var halo = Node3D.new()
	_put(pj, halo, c.global_position + UP * 1.4)
	halo.global_basis = _basis(d)
	var arms = []
	for k in 10:
		var a = lerpf(-PI * 0.72, PI * 0.72, k / 9.0)
		var arm = _gi(_arm_mesh(), _mat("air", AIR_SHADER))
		halo.add_child(arm)
		arm.position = Vector3(sin(a) * 0.9, cos(a) * 0.65 + 0.1, 0.35)
		arm.basis = Basis.looking_at(Vector3(sin(a) * 0.35, cos(a) * 0.25, -1.0).normalized(), UP)
		_ipar(arm, {"k_col": Color(0.96, 0.98, 1.0), "k_a": 0.0})
		arms.append([arm, 0.35, k * 1.3])
	var step = func(tt: float) -> void:
		if not is_instance_valid(halo):
			return
		if is_instance_valid(c):
			halo.global_position = c.global_position + UP * 1.4
		var env = clampf(tt / 0.15, 0.0, 1.0) * clampf((dur - tt) / 0.25, 0.0, 1.0)
		for ar in arms:
			var mi = ar[0]
			if not is_instance_valid(mi):
				continue
			var ph = maxf(0.0, sin(tt * 38.0 + float(ar[2])))
			mi.position.z = float(ar[1]) - 0.75 * ph
			mi.set_instance_shader_parameter("k_a", env * (0.35 + 0.45 * ph))
	var tw = halo.create_tween()
	tw.tween_method(step, 0.0, dur, dur)
	tw.tween_callback(halo.queue_free)
