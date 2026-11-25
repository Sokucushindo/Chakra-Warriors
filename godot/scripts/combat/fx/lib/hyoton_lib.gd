class_name HyotonLib
extends RefCounted
## Hyōton (buz) doğası kütüphanesi: kendi buz gölgelendiricisi + yapı taşları. Oyunun ortak buz / efekt yardımcılarını kullanmaz.
## Görünüş: soluk camgöbeği-beyaz yarı saydam buz; yüzlü (her yüz düz ton), yüz kenarlarında ince parlak beyaz çizgi,
## içeride kırılma (refraksiyon) çizgileri, tabanda kırağı kabuğu, isteğe bağlı koyu kontur (yaratıklar okunur kalsın).
## Palet: 0 buz, 1 kara buz (kara tipi), 2 kar (opak beyaz, mavi çizgi), 3 derin camgöbeği buz (kaplan / balina karnı).
## Yapı taşları: sivri buz parçası / yaprak / levha / yonga / kubbe / kılıf meshleri + gövde germe (loft) aracı;
## kar tanesi, kırağı parıltısı, buz yongası parçacıkları, yerde kırağı tabakası (çatlaklı / kar örtüsü / kırık çizgileri),
## soğuk nefes sisi, yuvarlanan buz kırıntıları. Kompozisyon (şekil, hareket, sahneleme) her tekniğin kendi dosyasındadır.

static var _cache := {}

const ICE := 0.0
const BLACK := 1.0
const SNOW := 2.0
const DEEP := 3.0

const C_ICE := Color(0.72, 0.9, 1.0)
const C_FROST := Color(0.9, 0.96, 1.0)

## imi / setp sözlük anahtarı → gölgelendirici örnek parametresi
const KEYS := {"fade": "fade", "alpha": "alpha_k", "pal": "pal", "near": "near_d", "frost": "frost_b", "glow": "glow",
	"reveal": "reveal_d", "ow": "ow", "crack": "crack", "grow": "grow", "mode": "mode", "tone": "tone", "kind": "kind"}

# ------------------------------------------------------------------ gölgelendiriciler
const ICE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float alpha_k = 0.78;
instance uniform float pal = 0.0;
instance uniform float near_d = 2.5;
instance uniform float seed = 0.0;
instance uniform float frost_b = -1000.0;
instance uniform float glow = 0.0;
instance uniform float reveal_d = 100000.0;
instance uniform float crack = 0.0;

varying vec3 lp;
varying vec3 bc;

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

// sRGB renkler: koyu yüz, orta, aydınlık yüz, yüz kenarı çizgisi, kenar (fresnel) tonu
void pal_cols(float p, out vec3 dk, out vec3 md, out vec3 lt, out vec3 ed, out vec3 rm) {
	dk = vec3(0.34, 0.6, 0.84);
	md = vec3(0.62, 0.85, 0.97);
	lt = vec3(0.88, 0.97, 1.0);
	ed = vec3(1.0, 1.0, 1.0);
	rm = vec3(0.24, 0.46, 0.74);
	if (p > 0.5 && p < 1.5) {
		dk = vec3(0.02, 0.02, 0.035);
		md = vec3(0.08, 0.08, 0.11);
		lt = vec3(0.22, 0.23, 0.29);
		ed = vec3(0.58, 0.6, 0.68);
		rm = vec3(0.0, 0.0, 0.01);
	} else if (p > 1.5 && p < 2.5) {
		dk = vec3(0.74, 0.82, 0.93);
		md = vec3(0.92, 0.95, 1.0);
		lt = vec3(1.0, 1.0, 1.0);
		ed = vec3(0.5, 0.62, 0.82);
		rm = vec3(0.66, 0.76, 0.9);
	} else if (p > 2.5) {
		dk = vec3(0.1, 0.42, 0.52);
		md = vec3(0.36, 0.7, 0.8);
		lt = vec3(0.74, 0.94, 0.97);
		ed = vec3(0.92, 1.0, 1.0);
		rm = vec3(0.05, 0.3, 0.42);
	}
}

void vertex() {
	lp = VERTEX;
	bc = CUSTOM0.xyz;
}

void fragment() {
	if (lp.y > reveal_d) {
		discard;
	}
	vec3 dk;
	vec3 md;
	vec3 lt;
	vec3 ed;
	vec3 rm;
	pal_cols(pal, dk, md, lt, ed, rm);
	// yüzlü görünüş: her üçgen kendi düz normaliyle
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.4, 0.85, 0.3, 0.0)).xyz);
	float ndl = dot(fn, ld);
	float fr = 1.0 - clamp(dot(fn, VIEW), 0.0, 1.0);
	vec3 col = mix(md, lt, step(0.42, ndl));
	col = mix(col, dk, step(ndl, -0.12) * 0.85);
	col = mix(col, rm, smoothstep(0.6, 0.85, fr) * 0.55);
	// içeride kırılma çizgileri: yüzeye eğik, gürültüyle kesik ince açık bantlar
	float n = vn3(lp * 2.1 + vec3(seed * 5.0));
	float s1 = abs(fract(dot(lp, vec3(0.55, 1.0, 0.35)) * 1.3 + n * 0.9 + seed) - 0.5);
	float s2 = abs(fract(dot(lp, vec3(-0.8, 0.4, 0.6)) * 0.9 + n * 1.3 + seed * 0.7) - 0.5);
	float streak = (1.0 - smoothstep(0.0, 0.03, s1)) * step(0.5, n) + (1.0 - smoothstep(0.0, 0.02, s2)) * step(0.62, n) * 0.7;
	col = mix(col, lt, clamp(streak, 0.0, 1.0) * 0.75);
	// kırılma eşiği: çatlak çizgileri koyulaşır
	float ck = (1.0 - smoothstep(0.0, 0.025, abs(vn3(lp * 3.3 + vec3(seed)) - 0.5))) * crack;
	col = mix(col, rm * 0.7, clamp(ck, 0.0, 1.0));
	// yüz kenarları: ekran sabit kalınlıkta parlak çizgi
	float e = min(min(bc.x, bc.y), bc.z);
	float ew = fwidth(e);
	float edge = 1.0 - smoothstep(ew * 0.7, ew * 2.0, e);
	col = mix(col, ed, edge);
	// tabanda kırağı kabuğu
	float fb = step(lp.y + (n - 0.5) * 0.35, frost_b);
	col = mix(col, vec3(0.95, 0.98, 1.0), fb * 0.85);
	col += lt * glow;
	col *= COLOR.rgb;
	float a = alpha_k + fr * 0.22 + edge * 0.6 + fb * 0.5 + streak * 0.15 + ck * 0.3;
	a = clamp(a, 0.0, 1.0) * fade * COLOR.a;
	// kameraya yakın kısım incelir (ekranı kaplamasın)
	a *= smoothstep(near_d * 0.35, near_d, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""

## Kontur (ters kabuk): yaratıklar ve büyük kütleler okunur kalsın
const OUTLINE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_front, unshaded, shadows_disabled, depth_draw_always;

instance uniform float fade = 1.0;
instance uniform float near_d = 2.5;
instance uniform float ow = 0.04;
instance uniform float pal = 0.0;
instance uniform float reveal_d = 100000.0;

varying float ly;

void vertex() {
	ly = VERTEX.y;
	vec3 od = CUSTOM1.xyz;
	if (length(od) < 0.5) {
		od = NORMAL;
	}
	float vz = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += normalize(od) * ow * clamp(vz * 0.06, 0.5, 4.0);
}

void fragment() {
	if (ly > reveal_d) {
		discard;
	}
	vec3 c = vec3(0.13, 0.26, 0.45);
	if (pal > 0.5 && pal < 1.5) {
		c = vec3(0.5, 0.52, 0.6);
	} else if (pal > 1.5 && pal < 2.5) {
		c = vec3(0.3, 0.42, 0.62);
	} else if (pal > 2.5) {
		c = vec3(0.04, 0.2, 0.3);
	}
	ALBEDO = pow(c, vec3(2.2));
	ALPHA = clamp(fade * smoothstep(near_d * 0.35, near_d, -VERTEX.z) * step(0.001, ow), 0.0, 1.0);
}
"""

## Yer kırağısı: büyüyen çatlaklı buz tabakası (mode 0), yumuşak kar örtüsü (1), yalnız kırık çizgileri (2)
const FROST_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float grow = 1.0;
instance uniform float seed = 0.0;
instance uniform float mode = 0.0;
instance uniform float pal = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

// hücre sınırına uzaklık (kırık buz levhaları)
float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + h22(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q);
	float ang = atan(q.y, q.x);
	float n = vn(q * 3.0 + vec2(seed * 7.0));
	float er = grow * (0.8 + 0.2 * vn(vec2(ang * 2.5 + seed * 11.0, seed * 3.0)));
	if (d > er) {
		discard;
	}
	// eğrelti gibi ışınsal kırağı dalları
	float br = abs(fract(ang * 7.0 / 6.2832 + n * 0.35 + seed) - 0.5);
	float branch = 1.0 - smoothstep(0.0, 0.05 * (1.2 - d * 0.6), br);
	float cells = 1.0 - smoothstep(0.0, 0.05, cell_edge(q * 4.0 + vec2(seed * 3.0)));
	vec3 base = vec3(0.84, 0.93, 1.0);
	vec3 line = vec3(0.42, 0.64, 0.9);
	vec3 gl = vec3(1.0);
	if (pal > 0.5) {
		base = vec3(0.15, 0.15, 0.19);
		line = vec3(0.03, 0.03, 0.05);
		gl = vec3(0.48, 0.5, 0.58);
	}
	vec3 col = mix(base, line, cells * 0.7);
	col = mix(col, gl, branch * 0.75);
	float a = 0.5 + n * 0.25;
	float rim = smoothstep(er - 0.07, er, d);
	col = mix(col, gl, rim * 0.6);
	a = mix(a, 0.95, rim * 0.5);
	a *= 1.0 - smoothstep(0.7, 1.0, d) * 0.55;
	if (mode > 0.5 && mode < 1.5) {
		col = mix(vec3(0.96, 0.98, 1.0), vec3(0.76, 0.84, 0.95), smoothstep(0.45, 0.6, n));
		if (pal > 0.5) {
			col = mix(vec3(0.2, 0.2, 0.24), vec3(0.07, 0.07, 0.09), smoothstep(0.45, 0.6, n));
		}
		a = 0.9 * (1.0 - smoothstep(0.65, 1.0, d + (n - 0.5) * 0.3));
	} else if (mode > 1.5) {
		float rad = 1.0 - smoothstep(0.0, 0.02, br);
		float cr = max(cells * step(0.45, n), rad * step(d, 0.9));
		if (cr < 0.3) {
			discard;
		}
		col = line * 0.55;
		a = cr * 0.9;
	}
	vec2 tc = floor(q * 38.0);
	float tw = step(0.992, h21(tc + vec2(seed))) * step(0.3, sin(TIME * 4.0 + h21(tc) * 50.0));
	col = mix(col, vec3(1.0), tw);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
"""

## Soğuk nefes / tipi sisi: yatay lifli, iki kademeli cel yoğunluk (tone 0 beyaz-mavi, 1 kara tipi)
const MIST_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float tone = 0.0;
instance uniform float near_d = 4.0;
instance uniform float alpha_k = 0.6;

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
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	vec2 sp = vec2(UV.x * 2.0 + TIME * 0.12 + seed, UV.y * 5.5 + seed * 1.3);
	float n = vn(sp) * 0.6 + vn(sp * 2.3 + vec2(3.1, 1.7)) * 0.4;
	float m = smoothstep(1.0, 0.25, d + (n - 0.5) * 0.85);
	float dens = smoothstep(0.22, 0.32, m) * 0.55 + smoothstep(0.55, 0.62, m) * 0.45;
	vec3 base = vec3(0.93, 0.97, 1.0);
	vec3 sh = vec3(0.68, 0.8, 0.93);
	if (tone > 0.5) {
		base = vec3(0.2, 0.2, 0.25);
		sh = vec3(0.06, 0.06, 0.08);
	}
	vec3 col = mix(sh, base, step(0.5, n + (0.5 - UV.y) * 0.6));
	float a = dens * alpha_k * fade * COLOR.a;
	float vz = -VERTEX.z;
	a *= smoothstep(near_d * 0.3, near_d, vz);
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float sz = -vp.z / vp.w;
	a *= clamp((sz - vz) / 1.0, 0.0, 1.0);
	ALBEDO = pow(col * COLOR.rgb, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Kar tanesi / kırağı parıltısı parçacığı (kameraya dönük): kind 0 yuvarlak kar topağı, 1 altı kollu kar yıldızı
const FLAKE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float fade = 1.0;
instance uniform float near_d = 1.5;

void vertex() {
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q);
	vec3 col = COLOR.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		a = 1.0 - smoothstep(0.8, 1.0, d);
		col = mix(col, col * 0.78, step(0.55, d) * step(q.y, -0.05));
	} else {
		float ang = atan(q.y, q.x);
		float arm = 1.0 - smoothstep(0.03, 0.1, abs(sin(ang * 3.0)) * d);
		float core = 1.0 - smoothstep(0.12, 0.22, d);
		a = max(arm * (1.0 - smoothstep(0.65, 1.0, d)), core);
		col = mix(col, vec3(1.0), core);
	}
	a *= COLOR.a * fade * smoothstep(near_d * 0.3, near_d, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


# ------------------------------------------------------------------ malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


## Buz malzemesi. outline: koyu kontur geçişi; two: iki yüzlü (kubbe gibi içi görünen kabuklar)
static func ice_mat(outline := false, two := false) -> ShaderMaterial:
	var key = "ice_%d_%d" % [int(outline), int(two)]
	if _cache.has(key):
		return _cache[key]
	var code = ICE_SHADER if not two else ICE_SHADER.replace("cull_back", "cull_disabled")
	var m = _mat(key + "_base", code).duplicate() as ShaderMaterial
	if outline:
		m.next_pass = _mat("ice_outline", OUTLINE_SHADER)
	_cache[key] = m
	return m


static func frost_mat() -> ShaderMaterial:
	return _mat("frost", FROST_SHADER)


static func mist_mat() -> ShaderMaterial:
	return _mat("mist", MIST_SHADER)


static func flake_mat() -> ShaderMaterial:
	return _mat("flake", FLAKE_SHADER)


## Parlayan düz renk (göz, ağız içi gibi küçük ayrıntılar)
static func glow_mat(col: Color) -> StandardMaterial3D:
	var key = "glow_" + col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.disable_receive_shadows = true
	_cache[key] = m
	return m


static func setp(gi: GeometryInstance3D, o: Dictionary) -> void:
	for k in o:
		if KEYS.has(k):
			gi.set_instance_shader_parameter(KEYS[k], float(o[k]))


## Buz malzemeli mesh örneği. o: pal, alpha, fade, near, frost, glow, reveal, ow (kontur), crack, outline, two
static func imi(mesh: Mesh, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ice_mat(bool(o.get("outline", false)), bool(o.get("two", false)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	if not o.has("ow"):
		mi.set_instance_shader_parameter("ow", 0.04 if bool(o.get("outline", false)) else 0.0)
	setp(mi, o)
	return mi


# ------------------------------------------------------------------ sahne yardımcıları
static func put(h: Node, n: Node3D, pos: Vector3) -> Node3D:
	h.get_tree().current_scene.add_child(n)
	n.global_position = pos
	preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(n)   # yere serili düz efekt engebeli araziye oturur
	return n


static func ground(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


static func later(h: Node, t: float, fn: Callable) -> void:
	h.get_tree().create_timer(t).timeout.connect(fn)


static func free_later(h: Node, n: Node, t: float) -> void:
	var w = weakref(n)
	h.get_tree().create_timer(t).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


## fade parametresini gecikmeyle söndürüp siler
static func fade_free(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Yerel Y boyunca görünen boyu açar (gerilmeden büyüme): 0 → h
static func reveal(gi: GeometryInstance3D, h: float, t: float, delay := 0.0) -> void:
	gi.set_instance_shader_parameter("reveal_d", -0.01)
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("reveal_d", v), -0.01, h, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


static func look_dir(n: Node3D, d: Vector3) -> void:
	if d.length() < 0.001:
		return
	var f = d.normalized()
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)


# ------------------------------------------------------------------ yüzlü mesh kurucu
## Her üçgen: düz normal, CUSTOM0 = barisentrik (kenar çizgisi; +1 o kenarı gizler), CUSTOM1 = kontur yönü
static func begin() -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## ctr: yüzün "içerisi" (normal dışa, sarım Godot'nun ön yüzüne göre çevrilir). hm: gizlenecek kenarlar (karşı köşe ekseni 1)
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ctr: Vector3, hm := Vector3.ZERO) -> void:
	var cr = (b - a).cross(c - a)
	if cr.length() < 0.000001:
		return
	var out = (a + b + c) / 3.0 - ctr
	if cr.dot(out) > 0.0:
		var t = b
		b = c
		c = t
		hm = Vector3(hm.x, hm.z, hm.y)
		cr = -cr
	var nrm = -cr.normalized()
	var vs = [a, b, c]
	var bs = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for i in 3:
		var b3: Vector3 = bs[i] + hm
		var v: Vector3 = vs[i]
		var od = v - ctr
		od = od.normalized() if od.length() > 0.0001 else nrm
		st.set_normal(nrm)
		st.set_custom(0, Color(b3.x, b3.y, b3.z, 1.0))
		st.set_custom(1, Color(od.x, od.y, od.z, 1.0))
		st.add_vertex(v)


## Dörtgen (köşegen çizgisi gizli); uçlardan biri çökmüşse tek üçgen
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ctr: Vector3) -> void:
	if c.distance_to(d) < 0.0001:
		tri(st, a, b, c, ctr)
		return
	if a.distance_to(b) < 0.0001:
		tri(st, a, c, d, ctr)
		return
	tri(st, a, b, c, ctr, Vector3(0, 1, 0))
	tri(st, a, c, d, ctr, Vector3(0, 0, 1))


## Gövde germe: halkalar boyunca yüzlü tüp. rings: [{"p": Vector3, "rx": float, "ry": float, (ops.) "up": Vector3, "rot": float}]
static func loft(st: SurfaceTool, rings: Array, sides: int, jit := 0.0, sd := 0, cap0 := true, cap1 := true) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var n = rings.size()
	if n < 2:
		return
	var pts: Array = []
	var fs: Array = []
	for i in n:
		var r: Dictionary = rings[i]
		var p: Vector3 = r["p"]
		var pa: Vector3 = rings[maxi(i - 1, 0)]["p"]
		var pb: Vector3 = rings[mini(i + 1, n - 1)]["p"]
		var f = pb - pa
		f = f.normalized() if f.length() > 0.0001 else Vector3.FORWARD
		fs.append(f)
		var upr: Vector3 = r.get("up", Vector3.UP)
		if absf(f.dot(upr.normalized())) > 0.97:
			upr = Vector3.FORWARD if absf(f.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var sv = f.cross(upr).normalized()
		var u = sv.cross(f).normalized()
		var rx: float = float(r.get("rx", 0.0))
		var ry: float = float(r.get("ry", rx))
		var rot: float = float(r.get("rot", 0.0))
		var ring: Array = []
		for k in sides:
			var an = k * TAU / sides + rot
			var j = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jit * maxf(rx, ry)
			ring.append(p + sv * cos(an) * rx + u * sin(an) * ry + j)
		pts.append(ring)
	for i in n - 1:
		var c0: Vector3 = (rings[i]["p"] + rings[i + 1]["p"]) * 0.5
		for k in sides:
			var k1 = (k + 1) % sides
			quad(st, pts[i][k], pts[i][k1], pts[i + 1][k1], pts[i + 1][k], c0)
	if cap0 and float(rings[0].get("rx", 0.0)) > 0.0001:
		var p0: Vector3 = rings[0]["p"]
		for k in sides:
			tri(st, p0, pts[0][k], pts[0][(k + 1) % sides], p0 + fs[0] * 0.2, Vector3(0, 1, 1))
	if cap1 and float(rings[n - 1].get("rx", 0.0)) > 0.0001:
		var p1: Vector3 = rings[n - 1]["p"]
		for k in sides:
			tri(st, p1, pts[n - 1][k], pts[n - 1][(k + 1) % sides], p1 - fs[n - 1] * 0.2, Vector3(0, 1, 1))


# ------------------------------------------------------------------ hazır şekiller (önbellekli)
## Sivri buz parçası: tabanı y=0, ucu +Y'de (boy L, taban yarıçapı r). Yontulmuş, hafif eğri uç
static func shard_mesh(L: float, r: float, variant := 0, sides := 5) -> ArrayMesh:
	var key = "shard_%.2f_%.2f_%d_%d" % [L, r, variant, sides]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7001 + variant * 31
	var lean = Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)) * L
	var st = begin()
	loft(st, [
		{"p": Vector3(0, -0.05 * L, 0), "rx": r * 0.92, "ry": r, "rot": rng.randf() * TAU},
		{"p": Vector3(0, L * 0.55, 0) + lean * 0.3, "rx": r * rng.randf_range(0.72, 0.9), "ry": r * rng.randf_range(0.7, 0.88), "rot": rng.randf() * TAU},
		{"p": Vector3(0, L, 0) + lean, "rx": 0.0, "ry": 0.0}], sides, 0.18, 9100 + variant, true, false)
	var m = finish(st)
	_cache[key] = m
	return m


## Tumturak buz kütlesi (iki uçlu kristal): kırıntı / blok
static func chunk_mesh(s: float, variant := 0) -> ArrayMesh:
	var key = "chunk_%.2f_%d" % [s, variant]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3301 + variant * 17
	var st = begin()
	loft(st, [
		{"p": Vector3(rng.randf_range(-0.2, 0.2), -s * 0.7, rng.randf_range(-0.2, 0.2)) * Vector3(s, 1, s), "rx": 0.0},
		{"p": Vector3(0, -s * 0.15, 0), "rx": s * 0.8, "ry": s * 0.65, "rot": rng.randf() * TAU},
		{"p": Vector3(0, s * 0.25, 0), "rx": s * 0.62, "ry": s * 0.7, "rot": rng.randf() * TAU},
		{"p": Vector3(rng.randf_range(-0.25, 0.25) * s, s * 0.85, rng.randf_range(-0.25, 0.25) * s), "rx": 0.0}], 5, 0.22, 4400 + variant)
	var m = finish(st)
	_cache[key] = m
	return m


## İnce buz yaprağı / bıçak: -Z boyunca L uzunluk, w genişlik; ortasında sırt (eşkenar dörtgen kesit)
static func leaf_mesh(L: float, w: float) -> ArrayMesh:
	var key = "leaf_%.2f_%.2f" % [L, w]
	if _cache.has(key):
		return _cache[key]
	var st = begin()
	loft(st, [
		{"p": Vector3(0, 0, L * 0.45), "rx": 0.0},
		{"p": Vector3(0, 0, L * 0.12), "rx": w, "ry": w * 0.16},
		{"p": Vector3(0, 0, -L * 0.2), "rx": w * 0.7, "ry": w * 0.12},
		{"p": Vector3(0, 0, -L * 0.55), "rx": 0.0}], 4, 0.0, 1)
	var m = finish(st)
	_cache[key] = m
	return m


## Kalın buz levhası (yere dikili duvar parçası / kubbe panosu): tabanı y=0, genişlik w (X), boy h (Y), kalınlık t (Z)
static func slab_mesh(w: float, h: float, t: float, variant := 0) -> ArrayMesh:
	var key = "slab_%.2f_%.2f_%.2f_%d" % [w, h, t, variant]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 5501 + variant * 13
	var st = begin()
	loft(st, [
		{"p": Vector3(0, -0.1, 0), "rx": w * 0.5, "ry": t * 0.5},
		{"p": Vector3(rng.randf_range(-0.06, 0.06) * w, h * 0.55, 0), "rx": w * rng.randf_range(0.42, 0.5), "ry": t * 0.45},
		{"p": Vector3(rng.randf_range(-0.15, 0.15) * w, h * 0.88, 0), "rx": w * rng.randf_range(0.22, 0.32), "ry": t * 0.35},
		{"p": Vector3(rng.randf_range(-0.2, 0.2) * w, h, 0), "rx": 0.0}], 6, 0.12, 6600 + variant, true, false)
	var m = finish(st)
	_cache[key] = m
	return m


## Buz kubbesi: blok blok örülmüş yarım küre (yarıçap r, gerçek boyda); paneller arasında kenar çizgileri
static func dome_mesh(r: float) -> ArrayMesh:
	var key = "dome_%.2f" % r
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 808
	var lats = [0.0, 0.3, 0.6, 0.88, 1.15, 1.4]
	var lon = 12
	var rows: Array = []
	for li in lats.size():
		var el: float = lats[li]
		var row: Array = []
		var tw = rng.randf() * 0.3
		for k in lon:
			var az = (k + tw) * TAU / lon
			var rr = r * rng.randf_range(0.95, 1.05)
			row.append(Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)) * rr + (Vector3.DOWN * 0.08 if li == 0 else Vector3.ZERO))
		rows.append(row)
	var st = begin()
	for li in rows.size() - 1:
		for k in lon:
			var k1 = (k + 1) % lon
			quad(st, rows[li][k], rows[li][k1], rows[li + 1][k1], rows[li + 1][k], Vector3.ZERO)
	var top = Vector3(0, r * 1.02, 0)
	var last: Array = rows[rows.size() - 1]
	for k in lon:
		tri(st, top, last[k], last[(k + 1) % lon], Vector3.ZERO)
	var m = finish(st)
	_cache[key] = m
	return m


## Bedeni saran buz kılıfı: düzensiz altıgen sütun, yontulmuş tepe (yarıçap r, boy h; tabanı y=0)
static func encase_mesh(r: float, h: float) -> ArrayMesh:
	var key = "encase_%.2f_%.2f" % [r, h]
	if _cache.has(key):
		return _cache[key]
	var st = begin()
	loft(st, [
		{"p": Vector3(0, -0.05, 0), "rx": r * 1.05, "ry": r * 0.95, "rot": 0.3},
		{"p": Vector3(0.05, h * 0.45, 0), "rx": r, "ry": r * 1.02, "rot": 0.45},
		{"p": Vector3(-0.04, h * 0.82, 0.03), "rx": r * 0.86, "ry": r * 0.8, "rot": 0.2},
		{"p": Vector3(0.1, h, -0.05), "rx": r * 0.35, "ry": r * 0.3, "rot": 0.6}], 6, 0.1, 919, true, true)
	var m = finish(st)
	_cache[key] = m
	return m


static func quad_mesh() -> QuadMesh:
	if _cache.has("quad"):
		return _cache["quad"]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	_cache["quad"] = q
	return q


# ------------------------------------------------------------------ parçacıklar
static func _curve(key: String, pts: Array) -> CurveTexture:
	if _cache.has(key):
		return _cache[key]
	var cv = Curve.new()
	for p in pts:
		cv.add_point(p)
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache[key] = ct
	return ct


static func _ramp(cols: Array) -> GradientTexture1D:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	var t = GradientTexture1D.new()
	t.gradient = g
	return t


## Parçacık yayıcısı. o: n, life, dir, spread, vmin, vmax, g, damp, smin, smax, r, align, mesh, mat, one_shot, burst, local,
## cols (renk rampası), kind (kar topağı 0 / yıldız 1), box (Vector3 kutu yayımı)
static func particles(o: Dictionary) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 3.0))
	pm.gravity = o.get("g", Vector3(0, -3.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.scale_min = float(o.get("smin", 0.08))
	pm.scale_max = float(o.get("smax", 0.18))
	pm.scale_curve = _curve("pop", [Vector2(0.0, 0.4), Vector2(0.1, 1.0), Vector2(0.75, 0.85), Vector2(1.0, 0.0)])
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(o.get("r", 0.2))
	pm.particle_flag_align_y = bool(o.get("align", false))
	pm.color_ramp = _ramp(o.get("cols", [Color(1, 1, 1, 1), Color(0.9, 0.95, 1.0, 0.9), Color(0.85, 0.92, 1.0, 0.0)]))
	p.process_material = pm
	p.draw_pass_1 = o.get("mesh", quad_mesh())
	p.material_override = o.get("mat", flake_mat())
	p.amount = maxi(1, int(o.get("n", 16)))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("burst", 0.9))
	p.randomness = 0.5
	p.local_coords = bool(o.get("local", false))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -16, -16), Vector3(32, 32, 32))
	p.set_instance_shader_parameter("kind", float(o.get("kind", 0.0)))
	p.set_instance_shader_parameter("seed", randf() * 10.0)
	setp(p, o)
	return p


static func _emit(h: Node, p: GPUParticles3D, pos: Vector3) -> GPUParticles3D:
	put(h, p, pos)
	p.emitting = true
	if p.one_shot:
		free_later(h, p, p.lifetime + 0.4)
	return p


## Savrulan kar taneleri (beyaz ya da kara)
static func snow(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var dark = bool(o.get("dark", false))
	var cols = [Color(1, 1, 1, 1), Color(0.93, 0.97, 1.0, 0.95), Color(0.86, 0.93, 1.0, 0.0)]
	if dark:
		cols = [Color(0.12, 0.12, 0.16, 1.0), Color(0.08, 0.08, 0.11, 0.9), Color(0.05, 0.05, 0.08, 0.0)]
	var d = {"n": 24, "life": 0.9, "spread": 180.0, "vmin": 1.5, "vmax": 5.0, "g": Vector3(0, -5.0, 0), "smin": 0.08, "smax": 0.2,
		"r": 0.4, "damp": 1.5, "cols": cols, "kind": 0.0}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


## Kırağı parıltısı: altı kollu küçük yıldızlar (toplanma / donma anı)
static func glints(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var d = {"n": 14, "life": 0.7, "spread": 180.0, "vmin": 0.3, "vmax": 1.4, "g": Vector3.ZERO, "smin": 0.18, "smax": 0.36,
		"r": 0.6, "kind": 1.0, "cols": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1), Color(0.8, 0.94, 1.0, 0.0)]}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


## Buz yongaları: hıza hizalı ince sivri parçalar (kırılma, saçılma)
static func chips(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var pal = float(o.get("pal", ICE))
	var d = {"n": 18, "life": 0.7, "spread": 180.0, "vmin": 3.0, "vmax": 8.0, "g": Vector3(0, -12.0, 0), "smin": 0.6, "smax": 1.2,
		"r": 0.3, "align": true, "mesh": shard_mesh(0.42, 0.07, 3, 4), "mat": ice_mat(), "cols": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)],
		"alpha": 0.9, "pal": pal, "near": 1.2}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


## Bir düğümün ardında kalan iz (mermi silinince Projectile parçacığı sahneye bırakır, kendi ömrüyle söner)
static func trail(parent: Node3D, o := {}) -> GPUParticles3D:
	var d = {"n": 30, "life": 0.6, "spread": 25.0, "dir": Vector3(0, 0, 1), "vmin": 0.2, "vmax": 0.8, "g": Vector3(0, -1.0, 0),
		"smin": 0.1, "smax": 0.22, "r": 0.2, "one_shot": false, "burst": 0.0, "kind": 0.0}
	d.merge(o, true)
	var p = particles(d)
	parent.add_child(p)
	p.emitting = true
	return p


## Soğuk nefes / tipi kartı: yavaş kayan, büyüyen, sönen
static func mist(h: Node, pos: Vector3, size: float, life: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = quad_mesh()
	mi.material_override = mist_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tone", float(o.get("tone", 0.0)))
	mi.set_instance_shader_parameter("near_d", float(o.get("near", 4.0)))
	var ak = float(o.get("alpha", 0.6))
	mi.set_instance_shader_parameter("alpha_k", ak)
	mi.set_instance_shader_parameter("fade", 0.0)
	var par: Node = o.get("parent", null)
	if par:
		par.add_child(mi)
		mi.position = pos
	else:
		put(h, mi, pos)
	var s0 = float(o.get("s0", 0.5))
	var grow = float(o.get("grow", 0.6))
	mi.scale = Vector3.ONE * size * s0
	var drift: Vector3 = o.get("drift", Vector3(0, 0.4, 0))
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * (s0 + grow), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "position", mi.position + drift * life, life)
	var fin = float(o.get("fin", 0.15))
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			var k = v / life
			var e = minf(1.0, k / maxf(0.01, fin)) * minf(1.0, (1.0 - k) / 0.45)
			mi.set_instance_shader_parameter("fade", clampf(e, 0.0, 1.0)), 0.0, life, life)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Yerde kırağı tabakası: r yarıçapında büyüyerek açılır, life sonra söner. o: mode (0 buz, 1 kar örtüsü, 2 kırık çizgisi),
## pal (0 beyaz-mavi, 1 kara), t (açılma süresi), out (sönme süresi)
static func frost(h: Node, pos: Vector3, r: float, life: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = pm
	mi.material_override = frost_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("mode", float(o.get("mode", 0.0)))
	mi.set_instance_shader_parameter("pal", float(o.get("pal", 0.0)))
	mi.set_instance_shader_parameter("grow", 0.0)
	put(h, mi, ground(pos) + Vector3.UP * float(o.get("lift", 0.04)))
	mi.rotation.y = randf() * TAU
	var tw = mi.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("grow", v), 0.0, 1.0, float(o.get("t", 0.3))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(maxf(0.0, life))
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, float(o.get("out", 0.8)))
	tw.tween_callback(mi.queue_free)
	return mi


## Yuvarlanan buz kırıntıları: n tane yontulmuş parça yerçekimiyle saçılır, yere düşüp söner (kırılma ardılı)
static func debris(h: Node, pos: Vector3, o := {}) -> void:
	var n = int(o.get("n", 8))
	var s = float(o.get("s", 0.35))
	var spd = float(o.get("v", 5.0))
	var up = float(o.get("up", 4.0))
	var pal = float(o.get("pal", ICE))
	var life = float(o.get("life", 1.1))
	var dirb: Vector3 = o.get("dir", Vector3.ZERO)
	var flo = Game.jutsu_floor_at(pos).y
	for i in n:
		var mi = imi(chunk_mesh(s * randf_range(0.6, 1.3), i % 5), {"pal": pal, "alpha": 0.9, "near": 1.5})
		put(h, mi, pos + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * float(o.get("r", 0.4)))
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var v = (Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() + dirb).normalized() * spd * randf_range(0.5, 1.0) + Vector3.UP * up * randf_range(0.6, 1.2)
		var p0 = mi.global_position
		var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var r0 = mi.rotation
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if not is_instance_valid(mi):
				return
			var p = p0 + v * t + Vector3.DOWN * 9.0 * t * t
			if p.y < flo + 0.05:
				p.y = flo + 0.05
			mi.global_position = p
			mi.rotation = r0 + spin * minf(t, 0.6), 0.0, life, life)
		tw.parallel().tween_method(func(f: float): mi.set_instance_shader_parameter("fade", f), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
		tw.tween_callback(mi.queue_free)
