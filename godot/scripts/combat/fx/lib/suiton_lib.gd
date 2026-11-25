class_name SuitonLib
extends RefCounted
## Suiton (su) doğası kütüphanesi: kendi su gölgelendiricisi + yapı taşları. Oyunun ortak su / efekt yardımcılarını kullanmaz.
## Görünüş: berrak mavi-camgöbeği cel su (iki ton + derin kenar), akan beyaz parıltı çizgileri, beyaz köpük tepeleri,
## kenarda koyu çizgi (fresnel konturu). Palet: 0 su, 1 kara mürekkep / yağ, 2 şurup, 3 kırağı, 4 sabun balçığı, 5 derin su.
## Yapı taşları: damla / sivri / dart / taç sıçraması / şuriken / sarmal / akış tüpü / birikinti / halka meshleri;
## sıçrama ve iz parçacıkları, toplanma, birikinti, halka dalgacık, sis, sabun köpüğü.
## Kompozisyon (şekil, hareket, sahneleme) her tekniğin kendi dosyasındadır.

static var _cache := {}

const WATER := 0.0
const INK := 1.0
const SYRUP := 2.0
const FROST := 3.0
const SOAP := 4.0   # sabunlu balçık (yeşil-camgöbeği)
const DEEP := 5.0   # derin / karanlık su (gece mavisi, yılan ağzı gibi koyu su kütleleri)

## wmi / setp sözlük anahtarı → gölgelendirici örnek parametresi
const KEYS := {"alpha": "alpha_k", "fade": "fade", "foam": "foam", "flow": "flow", "pal": "pal", "wob": "wob",
	"ripple": "ripple", "swirl": "swirl", "line": "line_w", "flat": "flat_k", "streak": "streak_k", "near": "near_k", "neard": "near_d",
	"reveal": "reveal_d"}

# ------------------------------------------------------------------ gölgelendiriciler
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

instance uniform float alpha_k = 0.85;
instance uniform float fade = 1.0;
instance uniform float foam = 0.0;
instance uniform float flow = 1.0;
instance uniform float pal = 0.0;
instance uniform float seed = 0.0;
instance uniform float wob = 0.0;
instance uniform float ripple = 0.0;
instance uniform float swirl = 0.0;
instance uniform float line_w = 0.1;
instance uniform float flat_k = 0.0;
instance uniform float streak_k = 1.0;
instance uniform float near_k = 1.0;
instance uniform float near_d = 3.2;   // incelme mesafesi (m): near_d*0.25 .. near_d arası söner
instance uniform float reveal_d = 100000.0;   // yerel -Z boyunca görünen boy (m): ilerleyen akış / sütun gerilmeden açılır

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
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

// renkler sRGB yazılır, sonda doğrusala çevrilir
void pal_cols(float p, out vec3 deep, out vec3 mid, out vec3 shal, out vec3 fc, out vec3 lc) {
	deep = vec3(0.05, 0.27, 0.66);
	mid = vec3(0.16, 0.56, 0.93);
	shal = vec3(0.52, 0.88, 1.0);
	fc = vec3(0.95, 0.99, 1.0);
	lc = vec3(0.03, 0.14, 0.4);
	if (p > 0.5 && p < 1.5) {
		deep = vec3(0.01, 0.01, 0.014);
		mid = vec3(0.055, 0.05, 0.058);
		shal = vec3(0.19, 0.18, 0.2);
		fc = vec3(0.5, 0.49, 0.52);
		lc = vec3(0.0);
	} else if (p > 1.5 && p < 2.5) {
		deep = vec3(0.55, 0.36, 0.13);
		mid = vec3(0.8, 0.62, 0.34);
		shal = vec3(0.96, 0.87, 0.62);
		fc = vec3(1.0, 0.97, 0.87);
		lc = vec3(0.36, 0.22, 0.07);
	} else if (p > 2.5 && p < 3.5) {
		deep = vec3(0.5, 0.64, 0.8);
		mid = vec3(0.76, 0.87, 0.96);
		shal = vec3(0.92, 0.97, 1.0);
		fc = vec3(1.0, 1.0, 1.0);
		lc = vec3(0.32, 0.45, 0.62);
	} else if (p > 3.5 && p < 4.5) {
		deep = vec3(0.1, 0.33, 0.3);
		mid = vec3(0.27, 0.58, 0.5);
		shal = vec3(0.6, 0.88, 0.77);
		fc = vec3(0.9, 1.0, 0.95);
		lc = vec3(0.04, 0.19, 0.17);
	} else if (p > 4.5) {
		deep = vec3(0.02, 0.05, 0.16);
		mid = vec3(0.08, 0.15, 0.36);
		shal = vec3(0.22, 0.34, 0.6);
		fc = vec3(0.62, 0.74, 0.95);
		lc = vec3(0.01, 0.02, 0.07);
	}
}

void vertex() {
	lp = VERTEX;
	float t = TIME * 3.0 + seed * 7.0;
	float w = sin(t + VERTEX.y * 4.0 + VERTEX.x * 3.0) * 0.5 + sin(t * 1.7 + VERTEX.z * 5.0) * 0.5;
	VERTEX += NORMAL * w * 0.05 * wob;
}

void fragment() {
	vec3 deep;
	vec3 mid;
	vec3 shal;
	vec3 fc;
	vec3 lc;
	pal_cols(pal, deep, mid, shal, fc, lc);
	vec3 n = normalize(NORMAL);
	float fres = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.35, 0.85, 0.4, 0.0)).xyz);
	float ndl = dot(n, ld);
	// iki ton cel + derin kenar bandı
	vec3 col = mix(mid, shal, step(0.18, ndl));
	col = mix(col, deep, step(0.6, fres) * 0.7);
	// birikinti kipi: koyu, yarı saydam ıslak yüzey (gök yansıması lekeli), kenarı köşe rengiyle yumuşar
	float fl = step(0.5, flat_k);
	col = mix(col, mix(deep, mid, 0.25 + 0.3 * vn(lp.xz * 1.6 + vec2(seed))), fl);
	// akış yönünde kayan beyaz parıltı çizgileri
	float sv = vn(vec2(UV.x * 9.0 * max(1.0, streak_k * 0.6) + seed * 3.0, UV.y * 2.5 * streak_k - TIME * flow * 1.6 * streak_k));
	float streak = step(0.75, sv) * step(fres, 0.72);
	col = mix(col, fc, streak * 0.85);
	// sert cel ışık lekesi
	vec3 hv = normalize(ld + VIEW);
	float spec = step(0.95, dot(n, hv));
	col = mix(col, vec3(1.0), spec);
	// köpük: yerel konumda kaynayan beyaz lekeler (iki ton)
	float fnz = vn3(lp * 3.2 + vec3(0.0, -TIME * 0.9, seed)) * 0.65 + vn3(lp * 7.0 + vec3(seed, TIME * 0.4, 0.0)) * 0.35;
	float fm = step(1.0 - foam, fnz) * step(0.001, foam);
	col = mix(col, mix(fc * 0.8, fc, step(0.0, ndl)), fm);
	// birikinti halkaları
	float rr = length(lp.xz);
	float ring = step(0.9, sin(rr * 7.0 - TIME * 2.6 + vn(lp.xz * 2.0 + vec2(seed)) * 2.5)) * ripple;
	col = mix(col, mix(shal * 1.08, mix(mid, shal, 0.5), fl), ring * 0.75);
	// hapis küresi sarmalı (yerel XY düzleminde Arşimet sarmalı)
	float sa = atan(lp.y, lp.x) / 6.2832;
	float sr = length(lp.xy) / max(length(lp), 0.0001);
	float sp = fract(sr * 2.6 - sa + TIME * 0.08);
	float swl = step(0.86, sp) * swirl * step(0.12, sr);
	col = mix(col, fc, swl);
	// koyu kontur (kenar)
	float rim = step(1.0 - line_w, fres) * step(0.001, line_w);
	col = mix(col, lc, rim);
	ALBEDO = pow(col, vec3(2.2));
	float a = alpha_k * mix(0.78 + 0.22 * fres, 1.0, fl);
	a = max(a, ring * 0.7 * alpha_k);
	a = max(a, fm * 0.96);
	a = max(a, max(streak, swl) * 0.92 * alpha_k);
	a = max(a, rim * min(1.0, alpha_k * 1.2));
	// kameraya çok yakın kısım incelir (ekranı kaplamasın)
	float nearf = mix(1.0, smoothstep(near_d * 0.25, near_d, -VERTEX.z), near_k);
	// açılma ucu: yerel -Z'de reveal_d'den ötesi görünmez (yumuşak ön)
	float rvl = 1.0 - smoothstep(reveal_d - 0.7, reveal_d, -lp.z);
	ALPHA = clamp(a, 0.0, 1.0) * fade * mix(1.0, COLOR.a, fl) * nearf * rvl;
}
"""

const MIST_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
instance uniform float alpha_k = 0.5;
instance uniform float seed = 0.0;
instance uniform float tone = 0.0;
instance uniform float sparkle = 0.0;
instance uniform float near_fade = 4.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vn(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// kameraya dönük kart (ölçek korunur)
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	float n = fbm(UV * 2.4 + vec2(seed * 3.1, seed * 1.7) + vec2(TIME * 0.035, TIME * 0.02));
	float m = smoothstep(1.0, 0.2, d + (n - 0.5) * 0.75);
	// anime sisi: yumuşak ama kademeli yoğunluk
	float dens = m * 0.55 + smoothstep(0.32, 0.42, m) * 0.25 + smoothstep(0.62, 0.72, m) * 0.2;
	vec3 base = vec3(0.9, 0.93, 0.97);
	vec3 sh = vec3(0.7, 0.76, 0.85);
	if (tone > 0.5 && tone < 1.5) {
		base = vec3(0.9, 0.96, 1.0);
		sh = vec3(0.66, 0.79, 0.93);
	} else if (tone > 1.5 && tone < 2.5) {
		base = vec3(0.17, 0.16, 0.17);
		sh = vec3(0.05, 0.045, 0.05);
	} else if (tone > 2.5 && tone < 3.5) {
		base = vec3(0.4, 0.47, 0.58);
		sh = vec3(0.2, 0.25, 0.34);
	} else if (tone > 3.5) {
		base = vec3(0.82, 0.9, 0.56);
		sh = vec3(0.55, 0.66, 0.3);
	}
	vec3 col = mix(base, sh, clamp(UV.y * 0.75 + (0.5 - n) * 0.5, 0.0, 1.0));
	float a = dens * alpha_k;
	// kırağı parıltısı
	float g = h21(floor(UV * 46.0) + vec2(seed * 13.0));
	float tw = step(0.986, g) * step(0.35, sin(TIME * 5.0 + g * 80.0)) * sparkle * step(0.25, m);
	col = mix(col, vec3(1.0), tw);
	a = max(a, tw * 0.9 * clamp(alpha_k * 2.0, 0.0, 1.0));
	// kameraya yakın kısım incelir (ekranı kaplamasın)
	float vz = -VERTEX.z;
	a *= smoothstep(near_fade * 0.3, near_fade, vz);
	// zemine / gövdeye yumuşak geçiş
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float sz = -vp.z / vp.w;
	a *= clamp((sz - vz) / 1.2, 0.0, 1.0);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

const BUBBLE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float wob = 0.35;

varying vec3 lp;

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
	lp = VERTEX;
	float t = TIME * 2.2 + seed * 5.0;
	VERTEX *= 1.0 + (sin(t + VERTEX.y * 5.0) * 0.5 + sin(t * 1.3 + VERTEX.x * 4.0) * 0.5) * 0.04 * wob;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	// ince zar girişimi: kenara doğru gökkuşağı
	float th = fr * 1.8 + vn(lp.xy * 3.0 + vec2(seed, TIME * 0.12)) * 1.2 + TIME * 0.1 + seed;
	vec3 irid = 0.55 + 0.45 * cos(6.2832 * (th + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(vec3(0.82, 0.92, 1.0), irid, smoothstep(0.3, 0.8, fr));
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.4, 0.8, 0.45, 0.0)).xyz);
	float sp = step(0.965, dot(n, normalize(ld + VIEW)));
	vec3 ld2 = normalize((VIEW_MATRIX * vec4(0.5, -0.3, -0.2, 0.0)).xyz);
	float k2 = dot(n, normalize(ld2 + VIEW));
	float arc = step(0.86, k2) * step(k2, 0.9);
	float edge = step(0.97, fr);
	col = mix(col, vec3(1.0), max(sp, arc));
	col = mix(col, vec3(0.12, 0.16, 0.24), edge);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(0.05 + smoothstep(0.45, 0.95, fr) * 0.55 + max(sp, arc) * 0.9 + edge * 0.6, 0.0, 1.0) * fade;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func water_mat() -> ShaderMaterial:
	return _mat("water", WATER_SHADER)


static func mist_mat() -> ShaderMaterial:
	return _mat("mist", MIST_SHADER)


static func bubble_mat() -> ShaderMaterial:
	return _mat("bubble", BUBBLE_SHADER)


## Su malzemesi örnek parametreleri (KEYS sözlüğündeki adlar)
static func setp(gi: GeometryInstance3D, o: Dictionary) -> void:
	for k in o:
		if KEYS.has(k):
			gi.set_instance_shader_parameter(KEYS[k], float(o[k]))


## Su malzemeli mesh örneği
static func wmi(mesh: Mesh, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = water_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	setp(mi, o)
	return mi


static func put(h: Node, n: Node3D, pos: Vector3) -> Node3D:
	h.get_tree().current_scene.add_child(n)
	n.global_position = pos
	preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(n)   # yere serili düz efekt engebeli araziye oturur
	return n


static func ground(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


static func free_later(h: Node, n: Node, t: float) -> void:
	var w = weakref(n)
	h.get_tree().create_timer(t).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


## Saydamlığı (fade) gecikmeyle söndürüp siler
static func fade_free(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## 0..1 ömür boyunca giriş / çıkış zarfı
static func env(k: float, fi: float, fo: float) -> float:
	return clampf(minf(k / maxf(fi, 0.001), (1.0 - k) / maxf(fo, 0.001)), 0.0, 1.0)


# ------------------------------------------------------------------ meshler
## pts boyunca tüp (kesit elips: flat < 1 → yassı şerit; n0 geniş eksenin yönü). sf'ye ekler, yeni köşe sayısını döndürür.
## UV.x çevre, UV.y boy (akış çizgileri UV.y boyunca kayar)
static func tube_into(sf: SurfaceTool, vc: int, pts: Array, radii: Array, sides := 10, flat := 1.0, n0 := Vector3.ZERO) -> int:
	var n = pts.size()
	var nn = Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var nx: Vector3 = pts[mini(i + 1, n - 1)]
		var pv: Vector3 = pts[maxi(i - 1, 0)]
		var tng = (nx - pv).normalized()
		if i == 0:
			if n0 != Vector3.ZERO and absf(n0.normalized().dot(tng)) < 0.97:
				nn = (n0 - tng * n0.dot(tng)).normalized()
			else:
				var rf = Vector3.RIGHT if absf(tng.y) > 0.9 else Vector3.UP
				nn = tng.cross(rf).normalized()
		else:
			nn = (nn - tng * nn.dot(tng)).normalized()   # paralel taşıma: halkalar burulmaz
		var bb = tng.cross(nn)
		var r = maxf(0.002, float(radii[i]))
		for s in sides + 1:
			var a = s * TAU / sides
			sf.set_uv(Vector2(float(s) / sides, float(i) / maxf(1.0, n - 1)))
			sf.add_vertex(p + nn * (cos(a) * r) + bb * (sin(a) * r * flat))
	for i in n - 1:
		for s in sides:
			var a0 = vc + i * (sides + 1) + s
			var u0 = a0 + sides + 1
			sf.add_index(a0)
			sf.add_index(u0)
			sf.add_index(a0 + 1)
			sf.add_index(a0 + 1)
			sf.add_index(u0)
			sf.add_index(u0 + 1)
	return vc + n * (sides + 1)


static func tube_mesh(pts: Array, radii: Array, sides := 10, flat := 1.0, n0 := Vector3.ZERO) -> ArrayMesh:
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	tube_into(sf, 0, pts, radii, sides, flat, n0)
	sf.generate_normals()
	return sf.commit()


## Eksen boyunca profil (z, yarıçap) → kapalı gövde; -Z öne (mermi yönü)
static func _axis_mesh(key: String, axis: Vector3, prof: Array, sides: int) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var pts = []
	var rad = []
	for pr in prof:
		pts.append(axis * float(pr[0]))
		rad.append(float(pr[1]))
	var m = tube_mesh(pts, rad, sides)
	_cache[key] = m
	return m


## Gözyaşı damlası: yuvarlak ön (-Z), incelen kuyruk (+Z)
static func drop_mesh() -> ArrayMesh:
	return _axis_mesh("drop", Vector3.BACK, [[-0.26, 0.0], [-0.2, 0.12], [-0.1, 0.17], [0.04, 0.17], [0.2, 0.14], [0.45, 0.09], [0.75, 0.045], [1.1, 0.0]], 12)


## Parçacık damlası: +Y öne (hız yönüne hizalı), kısa kuyruk
static func drop_y_mesh() -> ArrayMesh:
	return _axis_mesh("drop_y", Vector3.DOWN, [[-0.35, 0.0], [-0.25, 0.14], [-0.1, 0.19], [0.1, 0.17], [0.35, 0.1], [0.6, 0.04], [0.8, 0.0]], 8)


## Sivri su mermisi: keskin uç (-Z), uzun incelen gövde
static func spike_mesh() -> ArrayMesh:
	return _axis_mesh("spike", Vector3.BACK, [[-0.75, 0.0], [-0.5, 0.11], [-0.25, 0.19], [0.05, 0.22], [0.4, 0.2], [0.8, 0.16], [1.3, 0.12], [1.8, 0.08], [2.4, 0.04], [2.9, 0.0]], 10)


## Dört yüzlü dart (saçma tanesi): elmas kesit
static func dart_mesh() -> ArrayMesh:
	return _axis_mesh("dart", Vector3.BACK, [[-0.55, 0.0], [-0.3, 0.085], [0.0, 0.11], [0.28, 0.07], [0.6, 0.0]], 4)


## Akış tüpü: 0'dan -Z 1'e (birim boy; z ölçeğiyle uzatılır), ağızda ince sonda geniş
static func stream_mesh() -> ArrayMesh:
	return _axis_mesh("stream", Vector3.FORWARD, [[0.0, 0.14], [0.15, 0.2], [0.35, 0.32], [0.6, 0.5], [0.85, 0.72], [1.0, 0.85]], 14)


## İnce su teli: 0'dan -Z 1'e sabit kalınlık
static func strand_mesh() -> ArrayMesh:
	return _axis_mesh("strand", Vector3.FORWARD, [[0.0, 0.07], [0.3, 0.085], [0.7, 0.09], [0.92, 0.12], [1.0, 0.05]], 8)


## Dikey şelale perdesi: 0'dan -Y 1'e (birim), altta genişler
static func fall_mesh() -> ArrayMesh:
	return _axis_mesh("fall", Vector3.DOWN, [[0.0, 1.1], [0.2, 1.15], [0.45, 1.25], [0.7, 1.45], [0.9, 1.75], [1.0, 2.0]], 20)


## Dikey fışkırma: 0'dan +Y 1'e (birim), yukarıda genişler
static func geyser_mesh() -> ArrayMesh:
	return _axis_mesh("geyser", Vector3.UP, [[0.0, 0.12], [0.25, 0.18], [0.5, 0.26], [0.8, 0.36], [1.0, 0.42]], 12)


static func sphere_mesh() -> SphereMesh:
	if _cache.has("sphere"):
		return _cache["sphere"]
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 22
	s.rings = 11
	_cache["sphere"] = s
	return s


static func quad_mesh() -> QuadMesh:
	if _cache.has("quad"):
		return _cache["quad"]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	_cache["quad"] = q
	return q


## Taç sıçraması: halka boyunca dışa eğik, sivri uçlu yassı su dilleri (birim yarıçap, ~1 boy)
static func crown_mesh(variant: int) -> ArrayMesh:
	var key = "crown_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4421 + variant * 977
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc = 0
	var nb = 18
	for k in nb:
		var th = k * TAU / nb + rng.randf_range(-0.12, 0.12)
		var rd = Vector3(cos(th), 0, sin(th))
		var tg = Vector3(-sin(th), 0, cos(th))
		var tall = rng.randf_range(0.6, 1.25) if k % 2 == 0 else rng.randf_range(0.28, 0.6)
		var lean = rng.randf_range(0.25, 0.75)
		var w = rng.randf_range(0.12, 0.21)
		var curl = rng.randf_range(-0.12, 0.12)
		var pts = []
		var rad = []
		for j in 6:
			var u = j / 5.0
			pts.append(rd * (0.82 + lean * u * u) + Vector3.UP * tall * u + tg * (curl * u * u))
			rad.append(w * pow(1.0 - u, 0.8))
		vc = tube_into(sf, vc, pts, rad, 6, 0.35, tg)
	sf.generate_normals()
	var m = sf.commit()
	_cache[key] = m
	return m


## Sıvı taç: yuvarlak, kalın su dilleri; uçları damla gibi şişip dışa sarkar (buz sivrisi değil). Birim yarıçap, ~0.8 boy
static func liquid_crown_mesh(variant: int) -> ArrayMesh:
	var key = "lcrown_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 9203 + variant * 1213
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc = 0
	var nb = 14
	for k in nb:
		var th = k * TAU / nb + rng.randf_range(-0.15, 0.15)
		var rd = Vector3(cos(th), 0, sin(th))
		var tg = Vector3(-sin(th), 0, cos(th))
		var tall = rng.randf_range(0.45, 0.85) if k % 2 == 0 else rng.randf_range(0.22, 0.45)
		var lean = rng.randf_range(0.35, 0.7)
		var w = rng.randf_range(0.16, 0.24)
		var pts = []
		var rad = []
		var prof = [1.0, 0.85, 0.62, 0.45, 0.4, 0.55, 0.5, 0.0]   # incelir, uçta damla şişkinliği
		for j in prof.size():
			var u = j / float(prof.size() - 1)
			var droop = maxf(0.0, u - 0.6) * 0.5   # uç dışa ve aşağı sarkar
			pts.append(rd * (0.8 + lean * u) + Vector3.UP * (tall * sin(u * PI * 0.5) - droop * tall))
			rad.append(w * float(prof[j]))
		vc = tube_into(sf, vc, pts, rad, 7, 0.6, tg)
	sf.generate_normals()
	var m = sf.commit()
	_cache[key] = m
	return m


## Dört kanatlı su şurikeni: XZ düzleminde kıvrık, yassı kanatlar
static func star_mesh() -> ArrayMesh:
	if _cache.has("star"):
		return _cache["star"]
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc = 0
	for b in 4:
		var ph = b * TAU / 4.0
		var pts = []
		var rad = []
		for j in 8:
			var u = j / 7.0
			var ang = ph + u * 1.1
			var rr = 0.04 + 0.46 * u
			pts.append(Vector3(cos(ang) * rr, 0, sin(ang) * rr))
			rad.append(0.16 * pow(1.0 - u, 0.75) * minf(1.0, 0.45 + u * 3.0))
		var a0: Vector3 = pts[0]
		var a1: Vector3 = pts[1]
		vc = tube_into(sf, vc, pts, rad, 6, 0.22, (a1 - a0).normalized().cross(Vector3.UP))
	sf.generate_normals()
	var m = sf.commit()
	_cache["star"] = m
	return m


## Bedeni saran sarmal şerit (Y ekseni çevresinde, geniş yüzü dikey)
static func helix_mesh(r: float, hgt: float, turns: float, w: float, ph := 0.0) -> ArrayMesh:
	var pts = []
	var rad = []
	var n = 44
	for i in n:
		var u = float(i) / (n - 1)
		var a = ph + u * turns * TAU
		var rr = r * (1.0 + 0.12 * sin(u * 9.0 + ph))
		pts.append(Vector3(cos(a) * rr, 0.1 + u * hgt, sin(a) * rr))
		rad.append(w * pow(absf(sin(PI * u)), 0.4))
	return tube_mesh(pts, rad, 6, 0.3, Vector3.UP)


## Yere serilen düzensiz kenarlı birikinti (birim yarıçap, XZ düzlemi, yukarı bakar) + çevresinde damla lekeleri.
## rs: gerçek yarıçap (büyük birikinti gerilmeden kurulur, köpük / leke gürültüsü metre ölçeğinde kalır)
static func puddle_mesh(variant: int, rs := 1.0) -> ArrayMesh:
	var key = ("puddle_%d" % variant) if rs == 1.0 else ("puddle_%d_%d" % [variant, int(rs * 4.0)])
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7307 + variant * 6151
	var segs = 32
	var ph = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var rads = []
	for s in segs:
		var a = s * TAU / segs
		rads.append(1.0 + 0.16 * sin(a * 3.0 + ph[0]) + 0.1 * sin(a * 5.0 + ph[1]) + 0.06 * sin(a * 9.0 + ph[2]) + rng.randf_range(-0.04, 0.04))
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vadd = func(x: float, y: float, z: float, al: float):   # köşe alfası: kenar yumuşak söner
		sf.set_color(Color(1, 1, 1, al))
		sf.set_uv(Vector2(x * 0.5 + 0.5, z * 0.5 + 0.5))
		sf.add_vertex(Vector3(x * rs, y, z * rs))
	vadd.call(0.0, 0.012, 0.0, 1.0)
	var rings = [[0.5, 0.01, 1.0], [0.85, 0.006, 0.8], [1.0, 0.0, 0.0]]
	for rg in rings:
		for s in segs:
			var a = s * TAU / segs
			var rr = float(rads[s]) * float(rg[0])
			vadd.call(cos(a) * rr, float(rg[1]), sin(a) * rr, float(rg[2]))
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
	var base = 1 + rings.size() * segs
	for k in 6:
		var a = rng.randf() * TAU
		var dist = rng.randf_range(1.15, 1.55)
		var cr = rng.randf_range(0.05, 0.13)
		var cx = cos(a) * dist
		var cz = sin(a) * dist
		vadd.call(cx, 0.008, cz, 0.75)
		for q in 8:
			var b = q * TAU / 8.0
			vadd.call(cx + cos(b) * cr * (1.0 + 0.3 * sin(b * 2.0 + a)), 0.0, cz + sin(b) * cr, 0.0)
		for q in 8:
			sf.add_index(base)
			sf.add_index(base + 1 + q)
			sf.add_index(base + 1 + (q + 1) % 8)
		base += 9
	sf.generate_normals()
	var m = sf.commit()
	_cache[key] = m
	return m


## Yassı halka (dalgacık / köpük çemberi), birim dış yarıçap
static func ring_mesh() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache["ring"]
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs = 40
	var prof = [[0.8, 0.0, 0.0], [0.9, 0.04, 1.0], [1.0, 0.0, 0.0]]
	for pr in prof:
		for s in segs:
			var a = s * TAU / segs
			sf.set_color(Color(1, 1, 1, float(pr[2])))
			sf.set_uv(Vector2(float(s) / segs, float(pr[0])))
			sf.add_vertex(Vector3(cos(a) * float(pr[0]), float(pr[1]), sin(a) * float(pr[0])))
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


# ------------------------------------------------------------------ parçacıklar
static func _shrink_curve() -> CurveTexture:
	if _cache.has("shrink"):
		return _cache["shrink"]
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 0.7))
	cv.add_point(Vector2(0.15, 1.0))
	cv.add_point(Vector2(0.7, 0.8))
	cv.add_point(Vector2(1.0, 0.0))
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache["shrink"] = ct
	return ct


## Damla parçacık yayıcısı. o: n, life, dir, spread, vmin, vmax, g, damp, smin, smax, r, align, mesh, one_shot, burst, local
## + su parametreleri (foam, pal, alpha, line...)
static func particles(o: Dictionary) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 30.0))
	pm.initial_velocity_min = float(o.get("vmin", 3.0))
	pm.initial_velocity_max = float(o.get("vmax", 7.0))
	pm.gravity = o.get("g", Vector3(0, -14, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.scale_min = float(o.get("smin", 0.5))
	pm.scale_max = float(o.get("smax", 1.0))
	pm.scale_curve = _shrink_curve()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(o.get("r", 0.15))
	pm.particle_flag_align_y = bool(o.get("align", true))
	p.process_material = pm
	p.draw_pass_1 = o.get("mesh", drop_y_mesh())
	p.material_override = water_mat()
	p.amount = maxi(1, int(o.get("n", 16)))
	p.lifetime = float(o.get("life", 0.6))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("burst", 0.92))
	p.randomness = 0.4
	p.local_coords = bool(o.get("local", false))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))
	p.set_instance_shader_parameter("seed", randf() * 10.0)
	p.set_instance_shader_parameter("line_w", 0.14)
	setp(p, o)
	return p


## Tek seferlik damla sıçraması
static func spray(h: Node, pos: Vector3, dir: Vector3, o := {}) -> GPUParticles3D:
	var q = o.duplicate()
	q["dir"] = dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var p = particles(q)
	put(h, p, pos)
	p.emitting = true
	free_later(h, p, float(o.get("life", 0.6)) + 0.5)
	return p


## Sürekli iz (parent'a eklenir; yön parent'ın yerel ekseninde, varsayılan +Z = geri)
static func trail(parent: Node3D, o := {}) -> GPUParticles3D:
	var q = o.duplicate()
	q["one_shot"] = false
	if not q.has("burst"):
		q["burst"] = 0.0
	if not q.has("dir"):
		q["dir"] = Vector3(0, 0, 1)
	var p = particles(q)
	parent.add_child(p)
	p.emitting = true
	return p


# ------------------------------------------------------------------ yapı taşları
## Hazırlık: çevreden damlalar bir noktaya akar, orada su boncuğu (s çaplı) kabarır
static func gather(h: Node, at: Vector3, r := 1.0, n := 10, t := 0.3, s := 0.25, pal := 0.0) -> void:
	for k in n:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var d = wmi(sphere_mesh(), {"alpha": 0.9, "line": 0.16, "pal": pal, "flow": 3.0})
		put(h, d, at + dv * r * randf_range(0.6, 1.0))
		var sz = randf_range(0.06, 0.12) * (0.6 + r * 0.4)
		d.scale = Vector3(sz, sz, sz * 2.2)
		d.look_at(at, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT)
		var tw = d.create_tween()
		tw.tween_property(d, "global_position", at, t * randf_range(0.6, 1.0)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(d.queue_free)
	if s > 0.0:
		var orb = wmi(sphere_mesh(), {"alpha": 0.85, "wob": 1.6, "flow": 2.0, "line": 0.12, "pal": pal})
		put(h, orb, at)
		orb.scale = Vector3.ONE * 0.01
		var tw2 = orb.create_tween()
		tw2.tween_property(orb, "scale", Vector3.ONE * s, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw2.tween_property(orb, "scale", Vector3.ONE * 0.01, 0.1)
		tw2.tween_callback(orb.queue_free)


## Taç sıçraması: dilleri yükselir, dışa açılıp çöker. o: h (boy çarpanı), t (yükseliş), fall, foam, alpha, pal
static func crown(h: Node, pos: Vector3, s := 1.0, o := {}) -> MeshInstance3D:
	var mi = wmi(liquid_crown_mesh(randi() % 4), {"foam": o.get("foam", 0.2), "alpha": o.get("alpha", 0.85), "pal": o.get("pal", 0.0), "wob": 0.9, "line": 0.12, "flow": 2.5})
	put(h, mi, pos)
	mi.rotation.y = randf() * TAU
	var hs = float(o.get("h", 1.0))
	var fall = float(o.get("fall", 0.45))
	mi.scale = Vector3(s * 0.5, 0.05, s * 0.5)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(s, s * hs, s), float(o.get("t", 0.16))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(s * 1.35, s * hs * 0.05, s * 1.35), fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, fall)
	tw.tween_callback(mi.queue_free)
	return mi


## Yerde açılan köpük halkası
static func ripple(h: Node, pos: Vector3, r0: float, r1: float, t: float, o := {}) -> MeshInstance3D:
	var mi = wmi(ring_mesh(), {"foam": o.get("foam", 1.0), "alpha": o.get("alpha", 0.7), "pal": o.get("pal", 0.0), "line": 0.0, "flat": 1.0})
	put(h, mi, ground(pos) + Vector3.UP * 0.05)
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(r1, 0.6, r1), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Yayılan, sonra kuruyan birikinti. o: alpha, ripple, pal, foam, dir + stretch (yönde uzama), spread (açılma süresi), lift
static func puddle(h: Node, pos: Vector3, r: float, life: float, o := {}) -> MeshInstance3D:
	var mi = wmi(puddle_mesh(randi() % 6), {"alpha": o.get("alpha", 0.6), "ripple": o.get("ripple", 0.35), "pal": o.get("pal", 0.0),
		"foam": o.get("foam", 0.0), "line": 0.0, "flow": 0.3, "flat": 1.0})
	mi.sorting_offset = -1.0
	put(h, mi, ground(pos) + Vector3.UP * float(o.get("lift", 0.03)))
	var sx = 1.0
	if o.has("dir"):
		var d: Vector3 = o["dir"]
		mi.rotation.y = atan2(d.x, d.z)
		sx = float(o.get("stretch", 1.0))
	else:
		mi.rotation.y = randf() * TAU
	var full = Vector3(r, 1.0, r * sx)
	mi.scale = Vector3(full.x * 0.2, 1.0, full.z * 0.2)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", full, float(o.get("spread", 0.35))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(life)
	tw.tween_property(mi, "scale", full * Vector3(1.08, 1.0, 1.08), 0.9)
	tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.9)
	tw.tween_callback(mi.queue_free)
	return mi


## Sis / buhar kartı (kameraya döner, kameraya yakınken incelir).
## o: tone (0 sis, 1 kırağı, 2 kara bulut, 3 kurşuni-mavi yoğun sis, 4 asit buharı), sparkle, near, alpha, s0, grow, drift, fin, fout, parent (verilirse pos yereldir)
static func mist(h: Node, pos: Vector3, size: float, life: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = quad_mesh()
	mi.material_override = mist_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tone", float(o.get("tone", 0.0)))
	mi.set_instance_shader_parameter("sparkle", float(o.get("sparkle", 0.0)))
	mi.set_instance_shader_parameter("near_fade", float(o.get("near", 4.0)))
	mi.set_instance_shader_parameter("alpha_k", 0.0)
	var par = o.get("parent", null)
	if par != null and is_instance_valid(par):
		par.add_child(mi)
		mi.position = pos
	else:
		put(h, mi, pos)
	var a = float(o.get("alpha", 0.55))
	var fi = float(o.get("fin", 0.15))
	var fo = float(o.get("fout", 0.4))
	var drift: Vector3 = o.get("drift", Vector3.ZERO)
	mi.scale = Vector3.ONE * size * float(o.get("s0", 0.5))
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, life * float(o.get("grow", 0.35))).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", mi.position + drift, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float): mi.set_instance_shader_parameter("alpha_k", a * env(k, fi, fo)), 0.0, 1.0, life)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Sabun / su köpüğü: kabarır, süzülür, sonunda patlar
static func bubble(h: Node, pos: Vector3, size: float, life: float, vel := Vector3(0, 0.6, 0), pop := true) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = sphere_mesh()
	mi.material_override = bubble_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	put(h, mi, pos)
	mi.scale = Vector3.ONE * size * 0.2
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", mi.position + vel * life, life).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		if pop:
			bubble_pop(h, mi.global_position, size)
		mi.queue_free())
	return mi


## Köpük patlaması: zar ince damlalara dağılır
static func bubble_pop(h: Node, p: Vector3, s: float) -> void:
	spray(h, p, Vector3.UP, {"n": maxi(4, int(6 + s * 8)), "spread": 180.0, "vmin": 1.5, "vmax": 3.5 + s * 2.0, "life": 0.3,
		"smin": 0.08 + s * 0.05, "smax": 0.14 + s * 0.08, "g": Vector3(0, -8, 0), "r": s * 0.45, "foam": 0.6, "alpha": 0.7})


## Gerçek boyutta kurulan büyük birikinti / sel izi (ölçeklenmez: gürültü ince kalır). o: puddle ile aynı + s0 (açılış oranı)
static func big_puddle(h: Node, pos: Vector3, r: float, life: float, o := {}) -> MeshInstance3D:
	var rs = maxf(0.5, snappedf(r, 0.25))
	var mi = wmi(puddle_mesh(randi() % 6, rs), {"alpha": o.get("alpha", 0.6), "ripple": o.get("ripple", 0.35), "pal": o.get("pal", 0.0),
		"foam": o.get("foam", 0.0), "line": 0.0, "flow": 0.3, "flat": 1.0, "neard": o.get("neard", 3.2)})
	mi.sorting_offset = -1.0
	put(h, mi, ground(pos) + Vector3.UP * float(o.get("lift", 0.04)))
	mi.rotation.y = randf() * TAU
	var s0 = float(o.get("s0", 0.45))
	mi.scale = Vector3(s0, 1.0, s0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, float(o.get("spread", 0.4))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(life)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, float(o.get("dry", 1.2)))
	tw.tween_callback(mi.queue_free)
	return mi
