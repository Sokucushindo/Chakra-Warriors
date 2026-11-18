class_name SabakuFXA
extends RefCounted
## Sabaku (Gaara kumu) grubu A: on beş kum tekniğinin görünüşü + taşınan oynanışı.
## Bu dosyanın kendi yapı taşları (ortak efekt yardımcısı yok):
##   kum kütlesi  : ılık ten rengi, ince taneli (piksel bloğu değil; alt-piksel olunca söner), koyu cel gölge lekeleri,
##                  akan kumda dikey koyu izler, sıkışmış kumda çatlak ağı, koyu kontur kenarı, tane tane dağılma,
##                  kameraya yakın yumuşak incelme (büyük kütlelerde 6-9 m)
##   kum örtüsü   : havada açılan, kenarı yırtık dilli, kıvrım çizgili kalkan tabakası (Kūsa Bōheki)
##   yer izi      : kum yayılması (rüzgâr dalgacıkları), bataklık girdabı, sürüklenme izi, mühür dairesi
##   kum pusu     : taneli, kenarı düzensiz ince kum sisi (bulut topu değil)
##   kum tanesi   : ince yuvarlak tane parçacıkları (fışkırma, akıntı, yağmur, yörünge)
##   şekiller     : topak küre, kalın kum ipleri / dilleri (Loft), kum duvarı, kum perdesi, pençe el, basamaklı mühür
## Bedene sarılan kum oyunun kendi SandCoat sistemiyle gerçek bedende (Suna no Yoroi, Kum Klonu, Gōsa Maisō, Sōtaisō).
## Demir kum / altın toz görünüşü KULLANILMAZ. Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi
## davranışı) ana ağacın işleyicilerinden satır satır taşındı.

static var _cache := {}

const SL := Color(0.93, 0.8, 0.56)
const SM := Color(0.84, 0.68, 0.44)
const SD := Color(0.66, 0.5, 0.31)
const SX := Color(0.46, 0.34, 0.2)
const NAIL := Color(0.27, 0.25, 0.27)
const VEIN := Color(0.22, 0.27, 0.52)


# ================================================================== gölgelendiriciler
const NOISE_GLSL := """
float sh3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float sn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(sh3(i), sh3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(sh3(i + vec3(0.0, 1.0, 0.0)), sh3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(sh3(i + vec3(0.0, 0.0, 1.0)), sh3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(sh3(i + vec3(0.0, 1.0, 1.0)), sh3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

float cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 r = o + vec3(sh3(i + o), sh3(i + o + 7.1), sh3(i + o + 3.3)) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}
"""

## Kum kütlesi: köşe rengi (COLOR) x tint taban; cel üç ton, koyu leke / akış izi, ince tane, çatlak, kontur kenarı,
## dağılma (fade), kameraya yakın incelme (near0..near1 m), opacity. Desen nesne kökünden ölçülür (kayan kütlede kaymaz).
const MASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_always, shadows_disabled;

instance uniform vec3 tint = vec3(1.0, 1.0, 1.0);
instance uniform float fade = 0.0;
instance uniform float near0 = 0.0;
instance uniform float near1 = 0.0;
instance uniform float seed = 0.0;
instance uniform float flow = 0.0;
instance uniform float crack = 0.0;
instance uniform float streak = 0.0;
instance uniform float opacity = 1.0;

SNOISE

varying vec3 rp;
varying vec3 wnr;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rp = w - MODEL_MATRIX[3].xyz;
	wnr = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 nn = normalize(wnr);
	if (!FRONT_FACING) {
		nn = -nn;
	}
	vec3 base = tint * COLOR.rgb;
	vec3 sd = vec3(seed * 3.7, seed * 1.3, seed * 5.1);
	vec3 fp = rp + sd + vec3(0.0, mod(TIME, 100.0) * flow, 0.0);
	float sy = 1.0 / (1.0 + streak * 6.0);
	float mott = sn3(fp * vec3(1.6, 1.6 * sy, 1.6));
	vec3 col = base * (0.9 + 0.2 * mott);
	float sm = sn3(fp * vec3(0.8, 0.8 * sy, 0.8) + vec3(4.1, 0.0, 9.3));
	col = mix(col, base * 0.6, smoothstep(0.6, 0.665, sm) * (0.5 + 0.4 * streak));
	float dl = dot(nn, normalize(vec3(0.35, 0.85, 0.4)));
	float tone = 1.0;
	if (dl < 0.28) {
		tone = 0.8;
	}
	if (dl < -0.22) {
		tone = 0.64;
	}
	col *= tone;
	float px = length(fwidth(rp));
	float gk = 1.0 - smoothstep(0.006, 0.022, px);
	float g1 = sn3(fp * 70.0);
	float g2 = sn3(fp * 33.0 + vec3(5.3, 2.2, 1.1));
	col *= 1.0 + gk * (0.14 * smoothstep(0.7, 0.82, g1) - 0.17 * smoothstep(0.72, 0.84, g2));
	col *= 0.95 + 0.1 * sn3(fp * 8.0 + vec3(1.7));
	if (crack > 0.01) {
		float ce = cells((rp + sd) * 1.7);
		col = mix(base * 0.42 * tone, col, smoothstep(0.0, 0.055 * crack, ce));
	}
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	col = mix(col, base * 0.34, smoothstep(0.82, 0.9, rim));
	float dz = sn3((rp + sd) * 1.3);
	float cut = fade * 1.15 - 0.08;
	if (dz < cut) {
		discard;
	}
	if (fade > 0.001) {
		col = mix(base * 0.5, col, smoothstep(cut, cut + 0.06, dz));
	}
	float a = opacity;
	if (near1 > 0.0) {
		a *= smoothstep(near0, near1, -VERTEX.z);
	}
	if (a < 0.02) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""

## Kūsa Bōheki örtüsü: 8x8 ızgara; spread 0→1 ile merkezden açılır, dalgalanır, kenarları aşağı sarkar.
## Kenar yırtık dilli (sivri uçlar), yüzeyde koyu kıvrım çizgileri, alttan bakınca koyu (cel), ince tane.
const SHEET_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_always, shadows_disabled;

instance uniform vec3 tint = vec3(0.84, 0.68, 0.44);
instance uniform float spread = 0.0;
instance uniform float fade = 0.0;
instance uniform float near0 = 0.0;
instance uniform float near1 = 0.0;
instance uniform float seed = 0.0;

SNOISE

varying vec3 rp;
varying vec2 q0;

void vertex() {
	vec2 q = VERTEX.xz / 4.0;
	q0 = q;
	float r = length(q);
	float bil = sn3(vec3(VERTEX.x * 0.45, mod(TIME, 100.0) * 0.35 + seed, VERTEX.z * 0.45)) - 0.5;
	float drape = smoothstep(0.62, 1.0, r);
	VERTEX.y += (0.9 - r * r * 1.1 + bil * 0.9 - drape * 1.5) * spread;
	VERTEX.xz *= mix(0.06, 1.0, spread);
	rp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz;
}

void fragment() {
	float r = length(q0);
	float ang = atan(q0.y, q0.x);
	float lip = 0.84 + 0.06 * sin(ang * 7.0 + seed * 3.0) + 0.16 * (sn3(vec3(cos(ang) * 1.7 + seed, sin(ang) * 1.7, seed)) - 0.5);
	lip += 0.1 * pow(max(sin(ang * 11.0 + seed), 0.0), 6.0);
	if (r > lip) {
		discard;
	}
	vec3 sd = vec3(seed * 2.3, 0.0, seed * 1.1);
	vec3 nn = normalize(cross(dFdx(rp), dFdy(rp)));
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - (rp + MODEL_MATRIX[3].xyz);
	if (dot(nn, tocam) < 0.0) {
		nn = -nn;
	}
	float dl = dot(nn, normalize(vec3(0.35, 0.85, 0.4)));
	float tone = 1.0;
	if (dl < 0.25) {
		tone = 0.8;
	}
	if (dl < -0.25) {
		tone = 0.66;
	}
	vec3 col = tint * (0.92 + 0.16 * sn3((rp + sd) * 1.4)) * tone;
	float fo = sn3((rp + sd) * 0.55);
	col = mix(col, tint * 0.62 * tone, smoothstep(0.5, 0.56, fo) * 0.55);
	float line = 1.0 - smoothstep(0.0, 0.022, abs(fo - 0.5));
	col = mix(col, tint * 0.32, line * 0.85);
	col = mix(col, tint * 0.5 * tone, smoothstep(lip - 0.07, lip, r));
	float px = length(fwidth(rp));
	float gk = 1.0 - smoothstep(0.006, 0.022, px);
	col *= 1.0 + gk * (0.14 * smoothstep(0.7, 0.82, sn3(rp * 70.0 + sd)) - 0.17 * smoothstep(0.72, 0.84, sn3(rp * 33.0 - sd)));
	float dz = sn3((rp + sd) * 1.2);
	if (dz < fade * 1.15 - 0.08) {
		discard;
	}
	float a = 1.0;
	if (near1 > 0.0) {
		a *= smoothstep(near0, near1, -VERTEX.z);
	}
	if (a < 0.02) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""

## Yer izi (2x2 düzlem): mode 0 kum yayılması (rüzgâr dalgacıkları), 1 bataklık girdabı (spin ile döner),
## 2 sürüklenme izi (yerel z boyunca şerit), 3 mühür dairesi. fade ile tane tane söner.
const GROUND_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

instance uniform vec3 tint = vec3(0.84, 0.68, 0.44);
instance uniform float mode = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float spin = 0.0;
instance uniform float opacity = 0.9;

SNOISE

varying vec3 rp;

void vertex() {
	rp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 sd = vec3(seed * 3.1, 0.0, seed * 1.7);
	float edge = 0.86 + 0.2 * (sn3(vec3(cos(ang) * 2.0 + seed, sin(ang) * 2.0, seed)) - 0.5);
	vec3 base = tint;
	vec3 col = base;
	float a = opacity;
	float tm = mod(TIME, 100.0);
	if (mode < 0.5) {
		if (r > edge) {
			discard;
		}
		float rip = sin((rp.x * 0.8 + rp.z * 0.6) * 5.5 + sn3((rp + sd) * 0.7) * 5.0);
		col *= 0.93 + 0.07 * rip;
		col = mix(col, base * 0.64, smoothstep(0.86, 0.97, rip) * 0.7);
		col = mix(col, base * 0.6, smoothstep(edge - 0.12, edge, r));
		a *= 1.0 - smoothstep(edge - 0.06, edge, r);
	} else if (mode < 1.5) {
		if (r > edge) {
			discard;
		}
		float sw = sin(ang * 3.0 + r * 16.0 - tm * spin * 4.0 + sn3(vec3(p * 3.0, seed)) * 2.0);
		col *= 0.88 + 0.12 * sw;
		col = mix(col, base * 0.56, smoothstep(0.75, 0.95, sw) * 0.8);
		col = mix(base * 0.4, col, smoothstep(0.05, 0.4, r));
		col = mix(col, base * 1.08, smoothstep(edge - 0.14, edge - 0.05, r) * (1.0 - smoothstep(edge - 0.05, edge, r)));
	} else if (mode < 2.5) {
		float w = 0.82 + 0.24 * (sn3(vec3(p.y * 3.0, seed, 0.0)) - 0.5);
		if (abs(p.x) > w || abs(p.y) > 0.97) {
			discard;
		}
		float s = sn3(vec3(p.x * 14.0, (p.y + tm * spin * 0.3) * 1.5, seed));
		col *= 0.86 + 0.24 * s;
		col = mix(col, base * 0.6, smoothstep(0.66, 0.74, s) * 0.8);
		a *= (1.0 - smoothstep(w - 0.12, w, abs(p.x))) * (1.0 - smoothstep(0.8, 0.97, abs(p.y)));
	} else {
		if (r > 0.98) {
			discard;
		}
		float ring = 1.0 - smoothstep(0.012, 0.03, abs(r - 0.9));
		ring = max(ring, 1.0 - smoothstep(0.01, 0.025, abs(r - 0.72)));
		float sq = max(abs(p.x), abs(p.y));
		ring = max(ring, (1.0 - smoothstep(0.01, 0.025, abs(sq - 0.5))) * step(r, 0.72));
		float spk = (1.0 - smoothstep(0.01, 0.03, abs(sin(ang * 4.0)) * r)) * step(0.72, r) * step(r, 0.9);
		ring = max(ring, spk);
		col = mix(base * 0.95, base * 0.3, ring);
		a *= 1.0 - smoothstep(0.9, 0.98, r);
	}
	float px = length(fwidth(rp));
	float gk = 1.0 - smoothstep(0.006, 0.022, px);
	col *= 1.0 + gk * (0.14 * smoothstep(0.7, 0.82, sn3(rp * 70.0 + sd)) - 0.16 * smoothstep(0.72, 0.84, sn3(rp * 33.0 - sd)));
	col *= 0.95 + 0.1 * sn3(rp * 6.0 + sd);
	float dz = sn3(rp * 1.1 + sd);
	if (dz < fade * 1.15 - 0.08) {
		discard;
	}
	a *= 1.0 - smoothstep(0.7, 1.0, fade);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""

## Kum pusu: kameraya dönük düzlem; düzensiz kenar, içi taneli (benekli yoğunluk), iki ton (sağ alt gölge),
## yakına gelince incelir, fade ile delinerek söner.
const HAZE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

instance uniform vec3 tint = vec3(0.86, 0.73, 0.5);
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float near0 = 1.5;
instance uniform float near1 = 4.5;

SNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = 0.7 + 0.28 * sn3(vec3(cos(ang) * 1.8 + seed, sin(ang) * 1.8, seed * 2.0));
	if (r > edge) {
		discard;
	}
	float k = r / edge;
	float dens = 1.0 - smoothstep(0.25, 1.0, k);
	float g = sn3(vec3(UV * 26.0, seed * 5.0));
	float speck = smoothstep(0.55, 0.78, g);
	float hole = sn3(vec3(p * 2.5, seed));
	if (hole < fade * 1.1 - 0.1) {
		discard;
	}
	vec3 col = tint;
	if (dot(p, normalize(vec2(0.6, 0.7))) > 0.15) {
		col *= 0.74;
	}
	col *= 0.9 + 0.2 * speck;
	float a = dens * (0.35 + 0.5 * speck) * (1.0 - fade) * 0.7;
	a *= smoothstep(near0, near1, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""


# ================================================================== malzeme / önbellek
static func _smat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var sh = Shader.new()
	sh.code = code.replace("SNOISE", NOISE_GLSL)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[k] = m
	return m


static func _quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache[k] = q
	return _cache[k]


static func _plane() -> PlaneMesh:
	var k = "mesh:plane"
	if not _cache.has(k):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache[k] = p
	return _cache[k]


static func _sheet_plane() -> PlaneMesh:
	var k = "mesh:sheet"
	if not _cache.has(k):
		var p = PlaneMesh.new()
		p.size = Vector2(8.0, 8.0)
		p.subdivide_width = 30
		p.subdivide_depth = 30
		_cache[k] = p
	return _cache[k]


## Kum tanesi: yuvarlak yumuşak kenarlı küçük kart (parçacık rengiyle boyanır)
static func _grain_mesh() -> QuadMesh:
	var k = "mesh:grain"
	if _cache.has(k):
		return _cache[k]
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.55, Color(1, 1, 1, 0.95))
	var tex = GradientTexture2D.new()
	tex.gradient = gr
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	var q = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = m
	_cache[k] = q
	return q


static func _ramp() -> GradientTexture1D:
	var k = "tex:ramp"
	if _cache.has(k):
		return _cache[k]
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.7, Color(1, 1, 1, 0.9))
	var tx = GradientTexture1D.new()
	tx.gradient = gr
	_cache[k] = tx
	return tx


## tane başına ton çeşitliliği (açık / orta / koyu tane)
static func _tones() -> GradientTexture1D:
	var k = "tex:tones"
	if _cache.has(k):
		return _cache[k]
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(0.66, 0.62, 0.58, 1))
	gr.add_point(0.5, Color(0.86, 0.84, 0.8, 1))
	var tx = GradientTexture1D.new()
	tx.gradient = gr
	_cache[k] = tx
	return tx


# ================================================================== temel yardımcılar
static func _put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


## Çağırandan bağımsız silme (atan ölse de efekt dünyada kalmaz)
static func _kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func _later(host: Node, sec: float, fn: Callable) -> void:
	if sec <= 0.0:
		fn.call()
		return
	host.get_tree().create_timer(sec).timeout.connect(fn)


static func _pf(mi: GeometryInstance3D, k: String) -> Callable:
	var w = weakref(mi)
	return func(v: float) -> void:
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.set_instance_shader_parameter(k, v)


## Düğüm ağacındaki tüm kum parçalarının fade değerini birlikte ayarlayan çağrı
static func _fade_all(root: Node) -> Callable:
	var list = []
	if root is MeshInstance3D:
		list.append(weakref(root))
	for n in root.find_children("*", "MeshInstance3D", true, false):
		list.append(weakref(n))
	return func(v: float) -> void:
		for w in list:
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.set_instance_shader_parameter("fade", v)


static func _gi(mesh: Mesh, mat: Material, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in o:
		var v = o[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		mi.set_instance_shader_parameter(k, v)
	return mi


## Kum kütlesi parçası. o: tint, near0, near1, crack, streak, flow, opacity, seed
static func sand(mesh: Mesh, o := {}, shadow := false) -> MeshInstance3D:
	var d = {"seed": randf() * 20.0}
	d.merge(o, true)
	var mi = _gi(mesh, _smat("mass", MASS_SHADER), d)
	if shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## Kum dağılır: tane tane delinir, sonra silinir (çağırandan bağımsız)
static func crumble(host: Node, n: Node3D, delay: float, dur := 0.5) -> void:
	var w = weakref(n)
	_later(host, delay, func():
		var x = w.get_ref()
		if x == null or not is_instance_valid(x):
			return
		if not x.is_inside_tree():
			x.queue_free()
			return
		var f = _fade_all(x)
		var tw = x.create_tween()
		tw.tween_method(f, 0.0, 1.0, dur)
		tw.tween_callback(x.queue_free))


## İnce kum tanesi parçacıkları. o: n, life, stream (+dur; dur<=0 sonsuz), burst, box / ring (+ring_in, ring_h) / r,
## dir, spread, v0, v1, g, damp, radial, s0, s1, col, parent (verilirse pos yereldir), local, yaw
static func grains(host: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var stream = bool(o.get("stream", false))
	p.amount = maxi(1, int(o.get("n", 40)))
	p.lifetime = float(o.get("life", 1.0))
	p.one_shot = not stream
	p.explosiveness = float(o.get("burst", 0.0 if stream else 0.92))
	p.randomness = 0.4
	p.local_coords = bool(o.get("local", false))
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm = ParticleProcessMaterial.new()
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	elif o.has("ring"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = float(o["ring"])
		pm.emission_ring_inner_radius = float(o.get("ring_in", float(o["ring"]) * 0.8))
		pm.emission_ring_height = float(o.get("ring_h", 0.1))
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(o.get("r", 0.4))
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 40.0))
	pm.initial_velocity_min = float(o.get("v0", 1.0))
	pm.initial_velocity_max = float(o.get("v1", 3.0))
	pm.gravity = o.get("g", Vector3(0, -9.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0)) * 1.3
	pm.radial_accel_min = float(o.get("radial", 0.0))
	pm.radial_accel_max = float(o.get("radial", 0.0))
	pm.scale_min = float(o.get("s0", 0.035))
	pm.scale_max = float(o.get("s1", 0.075))
	pm.color = o.get("col", SL)
	pm.color_initial_ramp = _tones()
	pm.color_ramp = _ramp()
	p.process_material = pm
	p.draw_pass_1 = _grain_mesh()
	var par = o.get("parent", null)
	if par is Node3D and is_instance_valid(par):
		par.add_child(p)
		p.position = pos
	else:
		_put(host, p, pos)
	if o.has("yaw"):
		p.rotation.y = float(o["yaw"])
	p.emitting = true
	if stream:
		var dur = float(o.get("dur", 1.0))
		if dur > 0.0:
			var w = weakref(p)
			host.get_tree().create_timer(dur).timeout.connect(func():
				var x = w.get_ref()
				if x != null and is_instance_valid(x):
					x.emitting = false)
			_kill(host, dur + p.lifetime + 0.3, p)
	else:
		_kill(host, p.lifetime + 0.4, p)
	return p


## Yer izi. mode: 0 kum yayılması, 1 bataklık girdabı, 2 sürüklenme şeridi, 3 mühür dairesi.
## o: scale (Vector3, varsayılan r,1,r), yaw, grow_t, spin, tint, alpha, lift
static func ground(host: Node, pos: Vector3, r: float, mode: int, life: float, o := {}) -> MeshInstance3D:
	var mi = _gi(_plane(), _smat("ground", GROUND_SHADER), {"tint": o.get("tint", SM), "mode": float(mode), "seed": randf() * 20.0,
		"spin": float(o.get("spin", 0.0)), "opacity": float(o.get("alpha", 0.9))})
	var sc: Vector3 = o.get("scale", Vector3(r, 1.0, r))
	_put(host, mi, Vector3(pos.x, Game.jutsu_floor(pos.x, pos.z) + 0.05 + float(o.get("lift", 0.0)), pos.z))
	mi.rotation.y = float(o.get("yaw", randf() * TAU))
	var gt = float(o.get("grow_t", 0.25))
	mi.scale = Vector3(sc.x * 0.25, 1.0, sc.z * 0.25)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", sc, gt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life * 0.6 - gt))
	tw.tween_method(_pf(mi, "fade"), 0.0, 1.0, life * 0.4)
	tw.tween_callback(mi.queue_free)
	return mi


## Taneli kum pusu (az sayıda, alçakta; ekranı kaplamaz)
static func haze(host: Node, pos: Vector3, size: float, life: float, o := {}) -> MeshInstance3D:
	var mi = _gi(_quad(), _smat("haze", HAZE_SHADER), {"tint": o.get("tint", SL), "seed": randf() * 20.0,
		"near0": float(o.get("near0", 1.5)), "near1": float(o.get("near1", 4.5))})
	_put(host, mi, pos)
	mi.scale = Vector3.ONE * size * 0.6
	var vel: Vector3 = o.get("vel", Vector3.UP * 0.6)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "global_position", pos + vel * life, life)
	tw.parallel().tween_method(_pf(mi, "fade"), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== geometri
## Birim yarıçaplı topak küre (lump: yüzey dalgalanması)
static func _ball(lump: float, sd: int) -> ArrayMesh:
	var key = "mesh:ball:%.3f:%d" % [lump, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var ph = []
	for i in 6:
		ph.append(rng.randf() * TAU)
	var rings = 16
	var segs = 24
	var grid = []
	for i in rings + 1:
		var th = PI * float(i) / rings
		var row = []
		for j in segs + 1:
			var phi = TAU * float(j % segs) / segs
			var dv = Vector3(sin(th) * cos(phi), cos(th), sin(th) * sin(phi))
			var nz = sin(dv.x * 2.6 + ph[0]) * sin(dv.y * 3.1 + ph[1]) * sin(dv.z * 2.2 + ph[2]) + 0.45 * sin(dv.x * 5.3 + ph[3]) * sin(dv.z * 4.7 + ph[4]) * sin(dv.y * 6.1 + ph[5])
			row.append(dv * (1.0 + lump * nz))
		grid.append(row)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		for j in segs:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var cc: Vector3 = grid[i + 1][j + 1]
			var dd: Vector3 = grid[i][j + 1]
			st.add_vertex(a)
			st.add_vertex(cc)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(dd)
			st.add_vertex(cc)
	st.generate_normals()
	var m = st.commit()
	_cache[key] = m
	return m


static func _tube(pts: Array, rads: Array, col, seg := 10, sub := 3, cap_a := true, cap_b := true) -> ArrayMesh:
	var mb = MB.new()
	Loft.tube(mb, pts, rads, col, seg, sub, cap_a, cap_b)
	return mb.build(null)


## Birim yarıçaplı kapalı kum halkası (kesit rad: yan, dikey)
static func _ring_mesh(rad: Vector2, sd: int) -> ArrayMesh:
	var key = "mesh:ring:%.2f:%.2f:%d" % [rad.x, rad.y, sd]
	if _cache.has(key):
		return _cache[key]
	var pts = []
	var rads = []
	var cols = []
	for i in 25:
		var a = TAU * float(i % 24) / 24.0
		pts.append(Vector3(cos(a), 0.0, sin(a)))
		rads.append(rad * (0.8 + 0.4 * absf(sin(float(i % 24) * 1.7 + sd))))
		cols.append(SM if i % 3 != 0 else SL)
	var m = _tube(pts, rads, cols, 10, 3, false, false)
	_cache[key] = m
	return m


## Çöl Dalgası duvarı: yassı, dik, üstü hafif yuvarlak kum levhası + yayvan, yırtık taban
static func _wall_mesh() -> ArrayMesh:
	var key = "mesh:wall"
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7071
	var mb = MB.new()
	var o = PackedVector2Array()
	for i in 13:
		o.append(Vector2(-2.5 + rng.randf() * 0.15, lerpf(-5.2, 5.2, i / 12.0)))
	o.append(Vector2(-1.7, 5.0))
	o.append(Vector2(-0.4, 4.85))
	o.append(Vector2(1.9, 4.8))
	o.append(Vector2(2.45, 4.55))
	for i in 9:
		o.append(Vector2(2.5 + rng.randf_range(-0.12, 0.1), lerpf(4.3, -4.3, i / 8.0)))
	o.append(Vector2(2.45, -4.55))
	o.append(Vector2(1.9, -4.8))
	o.append(Vector2(-0.4, -4.85))
	o.append(Vector2(-1.7, -5.0))
	mb.add_slab(o, 1.7, SM, Transform3D.IDENTITY, Callable(), SD)
	var f = PackedVector2Array()
	for i in 17:
		f.append(Vector2(-2.55, lerpf(-6.0, 6.0, i / 16.0)))
	for i in 17:
		var z = lerpf(6.0, -6.0, i / 16.0)
		var top = -1.2 - absf(z) / 6.0 * 1.0 + (rng.randf() - 0.5) * 0.5 + (0.35 if i % 2 == 0 else -0.1)
		f.append(Vector2(maxf(top, -2.35), z))
	mb.add_slab(f, 2.9, SD.lerp(SM, 0.4), Transform3D.IDENTITY, func(q: Vector2): return 2.9 - (q.x + 2.55) * 0.9, SD)
	var m = mb.build(null)
	_cache[key] = m
	return m


## Akan Kum Çağlayanı perdesi: 16 x 10 m, üstü öne kıvrılan, yanları geriye bükülen, dalgalı kum yüzü (çift yüzlü)
static func _curtain_mesh() -> ArrayMesh:
	var key = "mesh:curtain"
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 911
	var nx = 26
	var ny = 18
	var grid = []
	var cols = []
	for j in ny + 1:
		var v = float(j) / ny
		var row = []
		var crow = []
		for i in nx + 1:
			var u = float(i) / nx
			var x = lerpf(-8.0, 8.0, u)
			var edge = 1.0 - pow(absf(u - 0.5) * 2.0, 6.0)
			var y = lerpf(-5.0, 5.0, v)
			if j == ny:
				y += rng.randf_range(-0.5, 0.3)
			var curl = pow(clampf((v - 0.45) / 0.55, 0.0, 1.0), 2.0) * 2.6
			var z = curl + sin(x * 0.9 + v * 3.0) * 0.35 + rng.randf_range(-0.08, 0.08) - (1.0 - edge) * 1.6
			row.append(Vector3(x, y, z))
			crow.append(SD.lerp(SM, clampf(v * 1.6, 0.0, 1.0)).lerp(SL, clampf((v - 0.7) * 2.5, 0.0, 1.0)))
		grid.append(row)
		cols.append(crow)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny:
		for i in nx:
			var quad = [[j, i], [j + 1, i + 1], [j + 1, i], [j, i], [j, i + 1], [j + 1, i + 1]]
			for q in quad:
				st.set_color(cols[q[0]][q[1]])
				st.add_vertex(grid[q[0]][q[1]])
	st.generate_normals()
	var m = st.commit()
	_cache[key] = m
	return m


## Perdenin tepesinde öne kıvrılan kalın kum sırtı
static func _crest_mesh() -> ArrayMesh:
	var key = "mesh:crest"
	if _cache.has(key):
		return _cache[key]
	var pts = []
	var rads = []
	for i in 9:
		var x = lerpf(-7.6, 7.6, i / 8.0)
		pts.append(Vector3(x, 4.9 + sin(i * 1.3) * 0.25, 2.5 + sin(x * 0.9 + 3.0) * 0.35))
		rads.append(Vector2(0.95, 0.75) * (0.75 + 0.35 * absf(sin(i * 2.1))))
	var m = _tube(pts, rads, SL, 12, 3, true, true)
	_cache[key] = m
	return m


## Kum Shurikeni bıçağı: ince uzun, iki ucu sivri mekik
static func _blade_mesh() -> ArrayMesh:
	var key = "mesh:blade"
	if not _cache.has(key):
		_cache[key] = _tube([Vector3(0, 0, 0.85), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3), Vector3(0, 0, -0.85)],
			[Vector2(0.01, 0.01), Vector2(0.13, 0.05), Vector2(0.13, 0.05), Vector2(0.01, 0.01)], [SD, SM, SL, SD], 8, 4, true, true)
	return _cache[key]


## Kum Çiseleme damlası: önde yuvarlak baş, arkada incelen uzun kuyruk (-Z ileri)
static func _drop_mesh() -> ArrayMesh:
	var key = "mesh:drop"
	if not _cache.has(key):
		_cache[key] = _tube([Vector3(0, 0, -0.5), Vector3(0, 0, -0.4), Vector3(0, 0, -0.12), Vector3(0, 0, 0.4), Vector3(0, 0, 0.95)],
			[Vector2(0.04, 0.04), Vector2(0.17, 0.15), Vector2(0.19, 0.17), Vector2(0.1, 0.09), Vector2(0.02, 0.02)], [SL, SL, SM, SM, SD], 10, 3, true, true)
	return _cache[key]


## Mühür basamağı: kat bloğu + üst kenarda koyu mühür bandı + her yüzde dikey mühür çizgisi ve noktalı mühür dairesi
static func _tier_mesh(i: int, tiers: int, w0: float, hstep: float) -> ArrayMesh:
	var key = "mesh:tier:%d:%d:%.2f:%.2f" % [i, tiers, w0, hstep]
	if _cache.has(key):
		return _cache[key]
	var fit = w0 / 8.0
	var w = w0 * (1.0 - float(i) / tiers) * 0.92
	var mb = MB.new()
	var body = SM.lerp(SL, float(i) / tiers)
	mb.add("box", Vector3(0, hstep * 0.47, 0), Vector3(w, hstep * 0.94, w), body)
	mb.add("box", Vector3(0, hstep * 0.9, 0), Vector3(w * 1.012, hstep * 0.05, w * 1.012), SX)
	var rad = minf(w, hstep) * 0.26
	for f in 4:
		var yaw = f * 90.0
		var nrm = Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
		var side = Vector3(nrm.z, 0, -nrm.x)
		var fc = nrm * (w * 0.5 + 0.01 * fit) + Vector3.UP * hstep * 0.45
		mb.add("box", fc, Vector3(0.05 * fit, hstep * 0.78, 0.05 * fit), SX, Vector3(0, yaw, 0))
		for q in 14:
			var a = TAU * q / 14.0
			mb.add("box", fc + side * cos(a) * rad + Vector3.UP * sin(a) * rad, Vector3(0.08, 0.08, 0.03) * fit, SX, Vector3(0, yaw, rad_to_deg(a)))
	if i == 0:
		for q in 12:
			var a = TAU * q / 12.0 + 0.2
			mb.add("boulder", Vector3(cos(a), 0, sin(a)) * w * 0.55, Vector3(w * 0.22, hstep * 0.22, w * 0.22), SD, Vector3(0, rad_to_deg(a), 0), q % 7)
	var m = mb.build(null)
	_cache[key] = m
	return m


# ================================================================== küçük parçalar
## Kalkanın yakaladığı mermi: iki kum topağı çarpıp yutar
static func _catch(host: Node, pos: Vector3) -> void:
	for s in [-1.0, 1.0]:
		var b = sand(_ball(0.15, 12), {"tint": SM, "near0": 1.0, "near1": 2.5})
		_put(host, b, pos + Vector3(s * 0.5, 0.0, 0.0))
		b.scale = Vector3.ONE * 0.1
		var tw = b.create_tween()
		tw.tween_property(b, "scale", Vector3.ONE * 0.45, 0.08)
		tw.parallel().tween_property(b, "global_position", pos, 0.08)
		crumble(host, b, 0.12, 0.3)
	grains(host, pos, {"r": 0.3, "n": 22, "life": 0.6, "dir": Vector3.DOWN, "spread": 70.0, "v0": 0.5, "v1": 2.0, "g": Vector3(0, -8.0, 0)})


## Zırhtan dökülen çatlak kum pulu
static func _flake(host: Node, pos: Vector3) -> void:
	grains(host, pos, {"r": 0.2, "n": 6, "life": 0.6, "dir": Vector3.DOWN, "spread": 30.0, "v0": 0.1, "v1": 0.5, "g": Vector3(0, -6.0, 0), "s0": 0.02, "s1": 0.045})
	if randf() > 0.5:
		return
	var fl = sand(_ball(0.2, 13 + randi() % 3), {"tint": SM, "crack": 1.0, "near0": 0.6, "near1": 1.5})
	fl.scale = Vector3(0.07, 0.022, 0.06)
	_put(host, fl, pos)
	fl.rotation = Vector3(randf() * 2.0, randf() * TAU, randf() * 2.0)
	var tw = fl.create_tween()
	tw.tween_property(fl, "global_position", pos + Vector3(randf_range(-0.2, 0.2), -pos.y + Game.jutsu_floor(pos.x, pos.z) + 0.03, randf_range(-0.2, 0.2)), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fl, "rotation", fl.rotation + Vector3(4.0, 1.0, 3.0), 0.5)
	crumble(host, fl, 0.7, 0.5)


## Kum Çiseleme: halkadan tomurcuklanan damla kökü
static func _bud(host: Node, pos: Vector3) -> void:
	var b = sand(_ball(0.1, 21), {"tint": SL, "near0": 0.8, "near1": 2.0})
	_put(host, b, pos)
	b.scale = Vector3.ONE * 0.05
	var tw = b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE * 0.24, 0.06)
	crumble(host, b, 0.07, 0.15)


## Gōsa Maisō: hedefin çevresinde yükselen kabarık kum dudağı (yavaşça döner)
static func _lip_ring(host: Node, p: Vector3, r: float) -> MeshInstance3D:
	var mi = sand(_ring_mesh(Vector2(0.32, 0.26), 3), {"tint": Color.WHITE, "near0": 2.0, "near1": 4.0})
	_put(host, mi, p - Vector3.UP * 0.3)
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", p + Vector3.UP * 0.05, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", 2.0, 3.4)
	_kill(host, 4.0, mi)
	return mi


## Yere yayılan alçak kum kabarması halkası (r0 → r1)
static func _surge(host: Node, at: Vector3, r0: float, r1: float, h: float, dur: float) -> void:
	var mi = sand(_ring_mesh(Vector2(0.08, 0.5), 5), {"tint": Color.WHITE, "near0": 3.0, "near1": 6.0})
	_put(host, mi, at + Vector3.UP * 0.1)
	mi.scale = Vector3(r0, h, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, h * 0.35, r1), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "fade"), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Suna no Kaiwan pençesi: kalın bilek, topak avuç, aşağı kıvrık dört parmak + başparmak, koyu tırnak uçları (-Z ileri)
static func _claw_hand() -> Node3D:
	var root = Node3D.new()
	var o = {"near0": 1.5, "near1": 3.5, "crack": 0.45, "tint": Color.WHITE}
	var wrist = sand(_tube([Vector3(0, 0.05, 1.6), Vector3(0, 0.0, 0.8), Vector3(0, 0.0, 0.0)], [0.75, 0.8, 0.85], [SD, SM, SM], 12, 3, true, false), o)
	root.add_child(wrist)
	var palm = sand(_ball(0.08, 66), o)
	palm.scale = Vector3(0.95, 0.55, 0.9)
	root.add_child(palm)
	var piv_list = []
	for k in 5:
		var thumb = k == 4
		var piv = Node3D.new()
		if thumb:
			piv.position = Vector3(0.85, -0.05, 0.05)
			piv.rotation.y = -1.1
		else:
			piv.position = Vector3(-0.6 + k * 0.4, 0.05, -0.55)
		var L = 0.95 if thumb else 1.25 - absf(k - 1.5) * 0.08
		var r0 = 0.27
		var mb = MB.new()
		Loft.tube(mb, [Vector3.ZERO, Vector3(0, 0.12, -L * 0.45), Vector3(0, -0.05, -L * 0.85), Vector3(0, -0.4, -L * 1.1)],
			[r0, r0 * 0.9, r0 * 0.75, r0 * 0.5], [SM, SM, SL, SM], 10, 3, true, false)
		Loft.tube(mb, [Vector3(0, -0.4, -L * 1.1), Vector3(0, -0.65, -L * 1.2), Vector3(0, -0.95, -L * 1.15)],
			[r0 * 0.5, r0 * 0.3, 0.015], [NAIL, NAIL, NAIL], 8, 3, true, true)
		var fm = sand(mb.build(null), o)
		piv.add_child(fm)
		piv.rotation.x = 0.55
		root.add_child(piv)
		piv_list.append(piv)
	root.scale = Vector3.ONE * 1.3
	root.set_meta("fingers", piv_list)
	return root


static func _close_claw(claw: Node3D) -> void:
	if not is_instance_valid(claw):
		return
	for piv in claw.get_meta("fingers", []):
		if is_instance_valid(piv):
			var tw = piv.create_tween()
			tw.tween_property(piv, "rotation:x", -0.75, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sabaku Rō küresi: pürüzsüz, sıkışmış (çatlaklı) kum küresi; yüzeyde kapanan dillerin sarmal dikiş izleri
static func _prison_ball(fit: float) -> Node3D:
	var root = Node3D.new()
	var core = sand(_ball(0.025, 81), {"crack": 0.5, "near0": 2.0, "near1": 4.0, "tint": SM}, true)
	core.scale = Vector3.ONE * 1.35 * fit
	root.add_child(core)
	for k in 6:
		var ax = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var perp = ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
		var a0 = randf() * TAU
		var pts = []
		var rads = []
		for s in 6:
			pts.append(perp.rotated(ax, a0 + s * 0.32) * 1.37 * fit)
			rads.append(lerpf(0.2, 0.05, s / 5.0) * fit)
		var seam = sand(_tube(pts, rads, [SD, SM, SL, SL, SM, SD], 8, 3, true, true), {"near0": 2.0, "near1": 4.0, "tint": Color.WHITE})
		root.add_child(seam)
	return root


## Kum Dolusu bulutu: yassı topak kum kütlesi, altından aşağı sivrilen kum dilleri
static func _hail_cloud() -> Node3D:
	var root = Node3D.new()
	var body = sand(_ball(0.15, 95), {"near0": 6.0, "near1": 9.0, "tint": SM, "streak": 0.5, "flow": 1.0})
	body.scale = Vector3(6.0, 1.5, 6.0)
	root.add_child(body)
	for k in 11:
		var a = TAU * k / 11.0 + randf_range(-0.2, 0.2)
		var rr = randf_range(0.5, 4.6)
		var b0 = Vector3(cos(a) * rr, -0.6, sin(a) * rr)
		var L = randf_range(2.5, 5.0) * (1.0 - rr / 8.0)
		var sp = sand(_tube([b0, b0 + Vector3(randf_range(-0.3, 0.3), -L * 0.55, randf_range(-0.3, 0.3)), b0 + Vector3(0, -L, 0)],
			[randf_range(0.9, 1.4), 0.5, 0.03], [SM, SL, SL], 8, 3, true, true), {"near0": 6.0, "near1": 9.0, "tint": Color.WHITE, "streak": 0.6, "flow": 1.5})
		root.add_child(sp)
	return root


## Karakterin kol kemiklerine bağlı dev kum kolları (Kum Shurikeni). Mesh'ler model uzayında (dinlenme pozu) kurulur ve
## kemiğe bağlanır; kol nereye giderse kum kol da oraya gider. Döner: ön kol + el düğümleri (meta "edge": bıçak çıkış noktaları)
static func _sand_arms(c: Node3D) -> Array:
	var out = []
	var m = c.get("model")
	if m == null or m.skel == null:
		return out
	var sk: Skeleton3D = m.skel
	var o = {"near0": 0.5, "near1": 1.4, "tint": Color.WHITE}
	for side in ["Left", "Right"]:
		var bu = sk.find_bone(side + "UpperArm")
		var bl = sk.find_bone(side + "LowerArm")
		var bh = sk.find_bone(side + "Hand")
		if bu < 0 or bl < 0 or bh < 0:
			continue
		var p_sh: Vector3 = m._grest(bu).origin
		var p_el: Vector3 = m._grest(bl).origin
		var p_wr: Vector3 = m._grest(bh).origin
		var dir = (p_wr - p_el).normalized()
		var up = Vector3.UP - dir * dir.dot(Vector3.UP)
		up = up.normalized() if up.length() > 0.01 else Vector3.FORWARD
		var fw = dir.cross(up).normalized()
		if fw.z < 0.0:
			fw = -fw
		var s = clampf(float(m.age_scale), 0.6, 1.0)
		# üst kol (omuz-dirsek): kalın kum manşon, geriye yatık dikenler
		var mu = MB.new()
		Loft.tube(mu, [p_sh - (p_el - p_sh) * 0.1, p_sh.lerp(p_el, 0.5) + up * 0.03, p_el], [0.13 * s, 0.17 * s, 0.2 * s], SM, 12, 3, true, true)
		for k in 3:
			var q = p_sh.lerp(p_el, 0.25 + k * 0.3)
			BeastRig.claw(mu, q + up * 0.15 * s, (up * 0.7 - dir * 0.7).normalized(), 0.22 * s, 0.05 * s, SD)
		var au = m._attach(side + "UpperArm", Transform3D.IDENTITY)
		var mu_i = sand(mu.build(null), o)
		var pu = Node3D.new()
		pu.position = p_sh
		au.get_child(0).add_child(pu)
		pu.add_child(mu_i)
		mu_i.position = -p_sh
		# ön kol + dev el: dirsekten bileğin ötesine uzanır, kalınlaşır
		var L = 1.25 * s
		var wr2 = p_el + dir * ((p_wr - p_el).length() + 0.15 * s)
		var palm0 = wr2 + dir * 0.15 * s
		var palm1 = wr2 + dir * L * 0.55
		var ml = MB.new()
		Loft.tube(ml, [p_el - dir * 0.05, p_el.lerp(wr2, 0.5) + up * 0.04 * s, wr2, palm0], [0.2 * s, 0.26 * s, 0.32 * s, 0.36 * s], SM, 14, 3, true, false)
		Loft.tube(ml, [palm0, palm0.lerp(palm1, 0.5), palm1], [Vector2(0.2, 0.36) * s, Vector2(0.2, 0.5) * s, Vector2(0.17, 0.46) * s], SM, 12, 3, false, true)
		var edge = PackedVector3Array()
		for f in 5:
			var a = deg_to_rad(-48.0 + f * 24.0)
			var fdir = (dir * cos(a) + up * sin(a) + fw * 0.15).normalized()
			var f0 = palm1 + up * sin(a) * 0.28 * s
			var f1 = f0 + fdir * 0.42 * s
			var f2 = f1 + (fdir + fw * 0.35).normalized() * 0.32 * s
			Loft.tube(ml, [f0, f1, f2], [0.1 * s, 0.085 * s, 0.065 * s], SM, 8, 2, true, false)
			BeastRig.claw(ml, f2, (fdir + fw * 0.6).normalized(), 0.3 * s, 0.065 * s, NAIL)
			edge.append(f2)
		for k in 6:
			var q = p_el.lerp(palm1, 0.15 + k * 0.15)
			var r = lerpf(0.24, 0.44, k / 5.0) * s
			BeastRig.claw(ml, q + up * r * 0.85, (up * 0.65 - dir * 0.75).normalized(), (0.28 + k * 0.03) * s, 0.07 * s, SD)
			BeastRig.claw(ml, q - up * r * 0.8, (-up * 0.6 - dir * 0.8).normalized(), 0.2 * s, 0.05 * s, SD)
			edge.append(q + up * r * 1.1)
		# mavi damarlar: kol boyunca dalgalı ince çizgiler (yüzeyde)
		for vk in 3:
			var off = (up * cos(vk * 2.1) + fw * sin(vk * 2.1)).normalized()
			var vp = []
			for k in 7:
				var tq = k / 6.0
				var q = p_el.lerp(palm1, tq)
				var rr = lerpf(0.22, 0.4, tq) * s * 1.01
				vp.append(q + off * rr + dir.cross(off) * sin(tq * 9.0 + vk) * 0.04 * s)
			Loft.tube(ml, vp, [0.018 * s, 0.018 * s, 0.018 * s, 0.018 * s, 0.018 * s, 0.018 * s, 0.018 * s], VEIN, 5, 1, false, false)
		var al = m._attach(side + "LowerArm", Transform3D.IDENTITY)
		var ml_i = sand(ml.build(null), o)
		var pl = Node3D.new()
		pl.position = p_el
		al.get_child(0).add_child(pl)
		pl.add_child(ml_i)
		ml_i.position = -p_el
		ml_i.set_meta("edge", Array(edge))
		ml_i.set_meta("mid", p_el.lerp(palm1, 0.5))
		for pv in [pu, pl]:
			pv.scale = Vector3.ONE * 0.2
			pv.create_tween().tween_property(pv, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK)
		ml_i.set_meta("pivots", [pu, pl])
		ml_i.set_meta("bas", [au, al])
		ml_i.set_meta("upper", mu_i)
		out.append(ml_i)
	return out


# ================================================================== teknikler
## Kūsa Bōheki: kum altı kalın dil olarak sarmal çizip başın üstüne tırmanır, orada yırtık kenarlı, kıvrımlı, kenarları
## sarkan geniş bir kum örtüsüne açılır; kenarlardan ince kum perdesi dökülür, çevrede dönen kum akıntısı. 8 sn mermileri
## yutar (iki topak çarpıp kapanır), yaklaşanı iter; sonunda örtü kum yağmuru olarak çöker.
static func kusa_boheki(pj: ClanJutsu, c: Node3D, _t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	var bs = ClanJutsu.body_scale(c)
	ground(pj, g, 3.6 * bs, 0, 8.8, {"grow_t": 0.3})
	grains(pj, g + Vector3.UP * 0.2, {"ring": 2.4 * bs, "n": 70, "life": 0.9, "dir": Vector3.UP, "spread": 18.0, "v0": 3.0, "v1": 6.0, "g": Vector3(0, -3.0, 0)})
	for k in 6:
		var a0 = TAU * k / 6.0 + randf_range(-0.2, 0.2)
		var pts = []
		var rads = []
		for s in 8:
			var u = s / 7.0
			var a = a0 + u * 1.7
			var rr = lerpf(2.5, 1.1, u) * bs
			pts.append(Vector3(cos(a) * rr, u * 3.1 * bs, sin(a) * rr))
			rads.append(lerpf(0.42, 0.2, u) * (0.85 + 0.25 * sin(u * 9.0 + k)) * bs)
		var rope = sand(_tube(pts, rads, [SD, SD, SM, SM, SM, SL, SL, SL]), {"near0": 1.6, "near1": 3.6})
		_put(pj, rope, g)
		rope.scale = Vector3(1, 0.05, 1)
		var tw = rope.create_tween()
		tw.tween_interval(k * 0.03)
		tw.tween_property(rope, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		crumble(pj, rope, 0.42, 0.35)
	# örtü: başın üstünde açılır (atana bağlı)
	var sheet = _gi(_sheet_plane(), _smat("sheet", SHEET_SHADER), {"spread": 0.0, "seed": randf() * 20.0, "near0": 2.2, "near1": 4.6, "tint": SM})
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	c.add_child(sheet)
	sheet.position = Vector3.UP * 3.2 * bs
	sheet.scale = Vector3.ONE * bs
	_kill(pj, 8.0, sheet)
	var sw = sheet.create_tween()
	sw.tween_interval(0.2)
	sw.tween_method(_pf(sheet, "spread"), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sw.tween_interval(6.8)
	sw.tween_method(_pf(sheet, "spread"), 1.0, 0.55, 0.5)
	sw.parallel().tween_method(_pf(sheet, "fade"), 0.0, 1.0, 0.5)
	# kenarlardan dökülen ince kum perdesi + çevrede dönen kum akıntısı
	grains(pj, Vector3.UP * 2.6 * bs, {"parent": c, "stream": true, "dur": 7.4, "ring": 3.3 * bs, "ring_in": 2.6 * bs, "n": 90, "life": 1.1,
		"dir": Vector3.DOWN, "spread": 8.0, "v0": 0.5, "v1": 1.5, "g": Vector3(0, -7.0, 0), "s0": 0.03, "s1": 0.06})
	var spin = Node3D.new()
	c.add_child(spin)
	_kill(pj, 8.0, spin)
	var sp = spin.create_tween().set_loops(16)
	sp.tween_property(spin, "rotation:y", TAU, 0.5).from(0.0)
	grains(pj, Vector3.UP * 1.0, {"parent": spin, "local": true, "stream": true, "dur": 7.6, "ring": 3.5 * bs, "ring_in": 3.1 * bs, "ring_h": 1.2,
		"n": 80, "life": 0.8, "dir": Vector3.UP, "spread": 30.0, "v0": 0.2, "v1": 0.8, "g": Vector3.ZERO, "s0": 0.03, "s1": 0.07})
	pj.after(7.45, func():
		if is_instance_valid(c):
			grains(pj, c.global_position + Vector3.UP * 3.0 * bs, {"box": Vector3(3.0, 0.2, 3.0) * bs, "n": 90, "life": 1.0, "burst": 0.6,
				"dir": Vector3.DOWN, "spread": 15.0, "v0": 0.5, "v1": 2.0, "g": Vector3(0, -12.0, 0)}))
	# oynanış: 8 sn yakındaki düşman mermilerini yutar, yaklaşanı iter
	pj.every(8.0, 0.1, func(_i, _k):
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and Combat.hostile(c, n.shooter) and n.global_position.distance_to(c.global_position + Vector3.UP) < 3.6:
				_catch(pj, n.global_position)
				n.queue_free()
		for e in pj.enemies_near(c, c.global_position, 3.6):
			var v = e.global_position - c.global_position
			v.y = 0
			e.global_position = pj.gp(e.global_position + v.normalized() * 0.5))
	Sfx.play("earth", c.global_position, 0.9)


## Suna no Yoroi: ayak dibinde kum yayılır, taneler sarmal çizip bedene tırmanır; tüm bedeni ince, çatlak kum katmanı
## kaplar (gerçek beden, SandCoat); 20 sn boyunca kenarlardan çatlak pullar ve ince tane dökülür, sonunda dökülerek çözülür.
static func suna_no_yoroi(pj: ClanJutsu, c: Node3D, _t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	ground(pj, g, 1.5, 0, 2.4, {"grow_t": 0.2})
	grains(pj, g + Vector3.UP * 0.1, {"ring": 0.9, "ring_in": 0.5, "n": 70, "life": 0.6, "dir": Vector3.UP, "spread": 12.0, "v0": 2.5, "v1": 4.5,
		"g": Vector3(0, -1.0, 0), "radial": -2.5})
	var old = c.get_meta("sand_coat") if c.has_meta("sand_coat") else {}
	if not old.is_empty():
		SandCoat.remove(old, 0.1)
	var coat = SandCoat.apply(c, 1.35, 0.35, 0.012, 1.6)
	if c is Player:
		Buffs.add("suna_no_yoroi", 20.0, {"armor": 0.75})
	elif c.has_method("add_buff"):
		c.add_buff("suna_no_yoroi", 20.0, {"armor": 0.75})   # AI eşitliği
	pj.after(20.0, func():
		if is_instance_valid(c):
			SandCoat.remove(coat, 0.6)
			grains(pj, c.global_position + Vector3.UP * 0.9, {"box": Vector3(0.3, 0.8, 0.3), "n": 60, "life": 0.9, "dir": Vector3.DOWN, "spread": 30.0,
				"v0": 0.2, "v1": 1.0, "g": Vector3(0, -9.0, 0)}))
	pj.every(20.0, 0.6, func(_i, _k):
		if pj.live(c):
			_flake(pj, c.global_position + Vector3.UP * randf_range(0.8, 1.5) + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))), Callable())
	Sfx.play("earth", c.global_position, 1.4)


## Sabaku Fuyū: yerden kum toplanıp ayağın altında yassı üstlü, altı yuvarlak topaklı, çatlak dokulu kum kütlesine
## dönüşür; altından sürekli ince kum dökülür. Kum bulutu uçuşu (yalnız oyuncu; tekrar basınca iner).
static func sabaku_fuyu(pj: ClanJutsu, c: Node3D, _t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	grains(pj, g + Vector3.UP * 0.2, {"r": 1.2, "n": 60, "life": 0.8, "dir": Vector3.UP, "spread": 35.0, "v0": 2.0, "v1": 5.0, "g": Vector3(0, -4.0, 0), "radial": -1.5})
	ground(pj, g, 1.6, 0, 2.0)
	if not c is Player:
		return
	if c.flight_source() == "sand":
		c.stop_flight()
		return
	var vis = Node3D.new()
	var body = Node3D.new()
	vis.add_child(body)
	body.position = Vector3(0, -0.32, 0)
	var top = sand(_ball(0.06, 41), {"crack": 0.3, "near0": 0.7, "near1": 2.0, "tint": SM})
	top.scale = Vector3(0.86, 0.3, 0.8)
	body.add_child(top)
	var under = sand(_ball(0.12, 42), {"crack": 0.15, "near0": 0.7, "near1": 2.0, "tint": SD.lerp(SM, 0.5)})
	under.scale = Vector3(0.66, 0.42, 0.62)
	under.position = Vector3(0, -0.2, 0.03)
	body.add_child(under)
	for k in 5:
		var a = k * TAU / 5.0 + 0.4
		var lump = sand(_ball(0.1, 43 + k), {"near0": 0.7, "near1": 2.0, "tint": SM})
		lump.scale = Vector3(0.36, 0.22, 0.34)
		lump.position = Vector3(cos(a) * 0.55, -0.08, sin(a) * 0.5)
		body.add_child(lump)
	body.scale = Vector3.ONE * 0.2
	_put(pj, vis, c.global_position)
	body.create_tween().tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grains(pj, Vector3(0, -0.6, 0), {"parent": vis, "stream": true, "dur": 0.0, "box": Vector3(0.5, 0.05, 0.45), "n": 36, "life": 0.9,
		"dir": Vector3.DOWN, "spread": 10.0, "v0": 0.3, "v1": 1.0, "g": Vector3(0, -6.0, 0), "s0": 0.025, "s1": 0.055})
	c.start_flight("sand", {"speed": 15.0, "lift": 8.0, "drain": 2.0, "vis": vis, "name": "Kum bulutu"})


## Sabakuha: önünde yerden yassı, dik bir kum levhası (yırtık, yayvan tabanlı duvar) yükselip ileri süpürür; tepesinden
## geriye kum savrulur, geçtiği yerde sürüklenme izi ve alçak kum pusu kalır; sonunda çöküp kum yığınına döner.
static func sabakuha(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var wave = Node3D.new()
	var wall = sand(_wall_mesh(), {"near0": 6.0, "near1": 9.0, "tint": Color.WHITE}, true)
	wall.rotation.y = PI * 0.5
	wave.add_child(wall)
	pj.get_tree().current_scene.add_child(wave)
	var start = pj.gp(c.global_position + d * 2.0)
	wave.global_position = start - Vector3.UP * 5.0
	wave.rotation.y = atan2(d.x, d.z)
	var tw = wave.create_tween()
	tw.tween_property(wave, "global_position", start + Vector3.UP * 2.5, 0.3)
	tw.tween_property(wave, "global_position", start + d * 20.0 + Vector3.UP * 2.5, 0.8)
	tw.tween_property(wave, "scale", Vector3(1, 0.3, 1), 0.3)
	tw.parallel().tween_property(wave, "global_position", start + d * 20.0 + Vector3.UP * 0.9, 0.3)
	tw.parallel().tween_method(_pf(wall, "fade"), 0.0, 1.0, 0.3)
	tw.tween_callback(wave.queue_free)
	grains(pj, Vector3(0, 2.4, 0), {"parent": wave, "stream": true, "dur": 1.1, "box": Vector3(4.6, 0.15, 0.4), "n": 110, "life": 0.7,
		"dir": (Vector3.UP * 0.8 - d).normalized(), "spread": 25.0, "v0": 3.0, "v1": 7.0, "g": Vector3(0, -9.0, 0)})
	var yaw = atan2(d.x, d.z)
	pj.every(1.1, 0.1, func(i, _k):
		if is_instance_valid(wave):
			var gpos = pj.gp(wave.global_position)
			if i % 2 == 0:
				ground(pj, gpos, 1.0, 2, 3.4, {"scale": Vector3(5.4, 1.0, 2.6), "yaw": yaw, "grow_t": 0.15})
				haze(pj, gpos + Vector3.UP * 0.6 - d * 1.2, 2.6, 0.9, {"vel": -d * 1.5 + Vector3.UP * 0.4})
			pj.hit(c, wave.global_position, 4.5, pj.inf(c, "sabakuha", 0.3, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "dir": d})), Callable())
	pj.after(1.15, func():
		var endp = start + d * 20.0
		ground(pj, endp, 5.5, 0, 3.2, {"grow_t": 0.3})
		grains(pj, endp + Vector3.UP * 0.5, {"box": Vector3(4.5, 0.4, 0.8), "yaw": yaw, "n": 80, "life": 0.9, "dir": Vector3.UP, "spread": 40.0,
			"v0": 2.0, "v1": 5.0, "g": Vector3(0, -9.0, 0)}))
	Sfx.play("earth", c.global_position, 0.6)


## Sabaku Hando: hedefin altında kum kabarır, yerden kalın bir önkol ve açık dev el fışkırır; beş parmak hedefin
## üstüne kapanır, her sıkışta parmaklar gerilir ve aralarından kum dökülür; sonunda el açılıp kuma çözülerek batar.
static func sabaku_hando(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var s = ClanJutsu.body_scale(tt)
	var hand = Node3D.new()
	var grip = Node3D.new()
	hand.add_child(grip)
	var o = {"near0": 2.0, "near1": 4.0, "tint": Color.WHITE}
	var arm = sand(_tube([Vector3(0, -3.4, 0), Vector3(0.1, -2.2, 0.05), Vector3(-0.05, -1.0, 0), Vector3(0, 0.05, 0)], [1.3, 1.18, 1.1, 1.2], [SD, SD, SM, SM], 14, 3, false, true), o, true)
	grip.add_child(arm)
	var palm = sand(_ball(0.08, 51), o, true)
	palm.scale = Vector3(1.55, 0.6, 1.45)
	palm.position = Vector3(0, 0.15, 0)
	grip.add_child(palm)
	var fingers = []
	for k in 5:
		var thumb = k == 4
		var a = deg_to_rad(180.0) if thumb else deg_to_rad(-80.0 + k * 42.0)
		var piv = Node3D.new()
		piv.position = Vector3(sin(a) * 1.15, 0.35, cos(a) * 1.15)
		piv.rotation = Vector3(0.85, a, 0)
		var L = 2.0 if thumb else 2.5 - absf(k - 1.5) * 0.18
		var r0 = 0.36 if thumb else 0.3
		var fm = sand(_tube([Vector3.ZERO, Vector3(0, L * 0.4, -0.04), Vector3(0, L * 0.72, -0.18), Vector3(0, L, -0.46)],
			[r0, r0 * 0.92, r0 * 0.8, r0 * 0.45], [SD, SM, SM, SL], 10, 3, true, true), o, true)
		piv.add_child(fm)
		grip.add_child(piv)
		fingers.append(piv)
	hand.scale = Vector3.ONE * s
	_put(pj, hand, at - Vector3.UP * 3.0 * s)
	var tw = hand.create_tween()
	tw.tween_property(hand, "global_position", at, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(3.0)
	tw.tween_property(hand, "global_position", at - Vector3.UP * 3.0 * s, 0.4)
	tw.parallel().tween_method(_fade_all(hand), 0.0, 1.0, 0.4)
	tw.tween_callback(hand.queue_free)
	for k in fingers.size():
		var piv: Node3D = fingers[k]
		var ft = piv.create_tween()
		ft.tween_interval(0.14 + k * 0.025)
		ft.tween_property(piv, "rotation:x", -0.42, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ft.tween_interval(2.75)
		ft.tween_property(piv, "rotation:x", 0.3, 0.35)
	ground(pj, at, 2.8 * s, 0, 4.4, {"grow_t": 0.25})
	grains(pj, at + Vector3.UP * 0.3, {"ring": 1.6 * s, "ring_in": 0.9 * s, "n": 80, "life": 1.0, "dir": Vector3.UP, "spread": 25.0, "v0": 4.0, "v1": 8.0, "g": Vector3(0, -12.0, 0)})
	haze(pj, at + Vector3.UP * 0.8, 3.2 * s, 1.0)
	pj.after(0.4, func():
		grains(pj, at + Vector3.UP * 2.0 * s, {"stream": true, "dur": 2.8, "ring": 0.9 * s, "ring_in": 0.4 * s, "n": 40, "life": 0.8, "dir": Vector3.DOWN,
			"spread": 10.0, "v0": 0.2, "v1": 0.8, "g": Vector3(0, -9.0, 0), "s0": 0.03, "s1": 0.06}))
	pj.st(tt, "bind", 3.2)
	pj.every(3.2, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "sabaku_hando", 0.25, {"knock": 0.0, "kind": "light"}))
			if is_instance_valid(grip):
				var sq = grip.create_tween()
				sq.tween_property(grip, "scale", Vector3(1.05, 0.93, 1.05), 0.07)
				sq.tween_property(grip, "scale", Vector3.ONE, 0.18)
				grains(pj, tt.global_position + Vector3.UP * 1.2, {"r": 0.6, "n": 16, "life": 0.6, "dir": Vector3.UP, "spread": 70.0, "v0": 1.0, "v1": 3.0}), Callable())
	Sfx.play("earth", at, 0.9)


## Suna no Kaiwan: sırttan kum fışkırır, üst üste binen kum boğumlarından kalın, eğri dev bir kol yay çizerek uzanır;
## ucunda koyu tırnaklı dev pençe hedefi kavrar, parmaklar kapanır, her sıkışta kum saçılır; sonunda kol kuma çözülür.
static func suna_no_kaiwan(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.0)
	if tt == null:
		return
	var tip = {"p": c.global_position + Vector3.UP * 1.5}
	var back = c.global_position + Vector3.UP * 1.4 - c.face_dir() * 0.3
	grains(pj, back, {"r": 0.4, "n": 60, "life": 0.6, "dir": (Vector3.UP - c.face_dir() * 0.5).normalized(), "spread": 40.0, "v0": 2.0, "v1": 5.0, "g": Vector3(0, -6.0, 0)})
	ground(pj, c.global_position, 1.6, 0, 3.0)
	var segs = []
	var ns = 22
	for i in ns:
		var sg = sand(_ball(0.14, 60 + i % 6), {"near0": 1.2, "near1": 3.0, "crack": 0.25, "tint": SM.lerp(SD, 0.25 * float(i % 3) / 2.0)}, true)
		_put(pj, sg, back)
		sg.scale = Vector3.ONE * 0.01
		segs.append(sg)
	var claw = _claw_hand()
	pj.get_tree().current_scene.add_child(claw)
	claw.global_position = tip["p"]
	pj.every(2.6, 1.0 / 30.0, func(_i, _k):
		if not pj.live(c):
			return
		var a = c.global_position + Vector3.UP * 1.4 - c.face_dir() * 0.3
		var b: Vector3 = tip["p"]
		var dist = a.distance_to(b)
		var mid = a.lerp(b, 0.5) + Vector3.UP * (1.2 + dist * 0.18) - c.face_dir() * 0.4
		var prev = a
		for i in ns:
			var u = float(i + 1) / ns
			var q = a.lerp(mid, u).lerp(mid.lerp(b, u), u)
			var sg = segs[i]
			if not is_instance_valid(sg):
				continue
			var tv = q - prev
			var L = maxf(tv.length(), 0.05)
			var r = lerpf(0.5, 0.82, u) * (0.92 + 0.12 * sin(u * 17.0))
			var dv = tv / L
			var upv = Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT
			sg.global_transform = Transform3D(Basis.looking_at(dv, upv) * Basis.from_scale(Vector3(r, r, maxf(r, L * 0.85))), prev.lerp(q, 0.5))
			prev = q
		if is_instance_valid(claw):
			var hd = (b - mid).normalized()
			if hd.length() > 0.01:
				claw.global_transform = Transform3D(Basis.looking_at(hd, Vector3.UP if absf(hd.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(claw.scale), claw.global_position), Callable())
	var tw = claw.create_tween()
	tw.tween_method(func(u):
		if is_instance_valid(claw) and pj.live(c):
			var end = tt.global_position + Vector3.UP if pj.live(tt) else claw.global_position
			var q = (c.global_position + Vector3.UP * 1.5).lerp(end, u) + Vector3.UP * sin(u * PI) * 2.5
			claw.global_position = q
			tip["p"] = q, 0.0, 1.0, 0.35)
	tw.tween_callback(func():
		if pj.live(tt):
			pj.st(tt, "bind", 2.2)
			_close_claw(claw)
			grains(pj, tt.global_position + Vector3.UP, {"r": 0.8, "n": 60, "life": 0.8, "dir": Vector3.UP, "spread": 60.0, "v0": 2.0, "v1": 5.0, "g": Vector3(0, -9.0, 0)})
			haze(pj, tt.global_position + Vector3.UP * 0.8, 2.4, 0.8))
	for k in 4:
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			if pj.live(tt):
				claw.global_position = tt.global_position + Vector3.UP
				tip["p"] = claw.global_position
				tt.take_hit(pj.inf(c, "suna_no_kaiwan", 0.35, {"knock": 0.0, "kind": "heavy"}))
				var sq = claw.create_tween()
				sq.tween_property(claw, "scale", Vector3.ONE * 1.18, 0.06)
				sq.tween_property(claw, "scale", Vector3.ONE * 1.3, 0.16)
				grains(pj, tt.global_position + Vector3.UP * 1.2, {"r": 0.7, "n": 22, "life": 0.6, "dir": Vector3.UP, "spread": 80.0, "v0": 1.0, "v1": 3.5}))
	tw.tween_method(_fade_all(claw), 0.0, 1.0, 0.25)
	tw.tween_callback(claw.queue_free)
	_kill(pj, 3.2, claw)
	_later(pj, 2.6, func():
		for i in segs.size():
			var sg = segs[i]
			if is_instance_valid(sg):
				if i % 5 == 0:
					grains(pj, sg.global_position, {"r": 0.6, "n": 24, "life": 0.9, "dir": Vector3.DOWN, "spread": 50.0, "v0": 0.3, "v1": 1.5, "g": Vector3(0, -9.0, 0)})
				crumble(pj, sg, i * 0.012, 0.3))
	Sfx.play("earth", c.global_position, 0.9)


## Gokusa Maisō: hedefin altındaki zemin yavaş dönen bataklık kum girdabına döner, çevresinde kum dudağı kabarır; hedef
## gömülürken kum bedenine beline dek tırmanır (gerçek beden); sonunda kum sütun olup hedefin üstüne kapanır, ezer, yığılır.
static func gokusa_maiso(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	if tt == null:
		return
	var p = pj.gp(tt.global_position)
	var s = ClanJutsu.body_scale(tt)
	ground(pj, p, 5.0 * s, 0, 4.6, {"grow_t": 0.5, "alpha": 0.7})
	ground(pj, p, 3.6 * s, 1, 3.6, {"spin": 1.0, "grow_t": 0.35})
	grains(pj, p + Vector3.UP * 0.2, {"ring": 3.0 * s, "ring_in": 1.0 * s, "n": 70, "life": 0.8, "dir": Vector3.UP, "spread": 30.0, "v0": 2.0, "v1": 5.0, "g": Vector3(0, -9.0, 0)})
	var lip = _lip_ring(pj, p, 1.6 * s)
	pj.st(tt, "bind", 3.4)
	if tt.get("model"):
		var tw = tt.model.create_tween()
		tw.tween_property(tt.model, "position:y", -1.2, 2.4)
		tw.tween_property(tt.model, "position:y", 0.0, 0.3).set_delay(0.6)
	var coat = SandCoat.apply(tt, 0.62, 2.3, 0.03, 0.7)
	grains(pj, p + Vector3.UP * 0.1, {"stream": true, "dur": 2.5, "ring": 3.0 * s, "ring_in": 1.6 * s, "n": 70, "life": 0.9, "dir": Vector3.UP, "spread": 20.0,
		"v0": 0.3, "v1": 1.2, "g": Vector3(0, -1.0, 0), "radial": -3.0})
	var tick = func(i, _k):
		if i % 4 == 1:
			var a = randf() * TAU
			haze(pj, p + Vector3(cos(a), 0.3, sin(a)) * 2.4 * s, 1.4 * s, 0.8, {"vel": Vector3(-cos(a), 0.3, -sin(a)) * 1.5})
	var fin = func():
		_burial_slam(pj, p, s)
		if pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP, 1.6, pj.inf(c, "gokusa_maiso", 2.0, {"knock": 2.0, "kind": "heavy", "hitstop": 0.12}))
		pj.shake(0.7)
		_later(pj, 0.35, func(): SandCoat.remove(coat, 0.5))
		crumble(pj, lip, 0.2, 0.5)
	pj.every(2.6, 0.2, tick, fin)
	Sfx.play("earth", p, 0.7)


## Gokusa Maisō kapanışı: girdaptan kum sütunu fışkırıp hedefi yutar, sonra üstüne çökerek yayvan yığına döner
static func _burial_slam(pj: ClanJutsu, p: Vector3, s: float) -> void:
	var pts = []
	var rads = []
	for i in 6:
		var u = i / 5.0
		pts.append(Vector3(randf_range(-0.15, 0.15) * u, -0.5 + u * 4.1, randf_range(-0.15, 0.15) * u))
		rads.append(lerpf(1.35, 0.55, u) * (0.9 + 0.2 * randf()))
	var pil = sand(_tube(pts, rads, [SD, SM, SM, SL, SL, SL], 14, 3, true, true), {"near0": 2.5, "near1": 5.0, "tint": Color.WHITE, "streak": 0.8, "flow": -4.0}, true)
	_put(pj, pil, p)
	pil.scale = Vector3(s, 0.05 * s, s)
	var tw = pil.create_tween()
	tw.tween_property(pil, "scale", Vector3(s, s, s), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(pil, "scale", Vector3(s * 1.25, s * 0.3, s * 1.25), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(pil, "fade"), 0.0, 1.0, 0.45)
	tw.tween_callback(pil.queue_free)
	grains(pj, p + Vector3.UP * 0.5, {"ring": 1.4 * s, "ring_in": 0.4 * s, "n": 120, "life": 1.1, "dir": Vector3.UP, "spread": 35.0, "v0": 6.0, "v1": 14.0, "g": Vector3(0, -14.0, 0)})
	for k in 3:
		var a = TAU * k / 3.0 + randf()
		haze(pj, p + Vector3(cos(a) * 1.6 * s, 0.9, sin(a) * 1.6 * s), 2.6 * s, 1.2, {"vel": Vector3(cos(a), 0.4, sin(a)) * 1.6})
	var mound = sand(_ball(0.12, 77), {"near0": 2.0, "near1": 4.0, "tint": SM, "crack": 0.2})
	_put(pj, mound, p)
	mound.scale = Vector3(0.1, 0.05, 0.1)
	var mt = mound.create_tween()
	mt.tween_interval(0.25)
	mt.tween_property(mound, "scale", Vector3(1.6 * s, 0.5 * s, 1.6 * s), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	crumble(pj, mound, 2.6, 0.8)
	ground(pj, p, 3.4 * s, 0, 4.2, {"grow_t": 0.3})


## Ryūsa Bakuryū: atanın önünde yerden kum kabarır, 16 m genişlikte, üstü öne kıvrılan dev kum perdesi yükselir; yüzünden
## kum aşağı akar (koyu dikey izler), tepeden kum savrulur; perde hedefin üstüne şelale gibi devrilir, kum seli çevreye
## yayılır. Kameraya yakın kısım yalnız alçak sel (zemin akışı + alçak pus, ≤1 m); dev perde 6-9 m'de incelir.
static func ryusa_bakuryu(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	pj.anim(c, "crouch", 1.2)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var d = pj.fwd(c, t)
	var wave = Node3D.new()
	var curtain = sand(_curtain_mesh(), {"near0": 6.0, "near1": 9.0, "streak": 1.0, "flow": 3.5, "tint": Color.WHITE}, true)
	wave.add_child(curtain)
	var crest = sand(_crest_mesh(), {"near0": 6.0, "near1": 9.0, "streak": 0.3, "flow": 1.0, "tint": Color.WHITE}, true)
	wave.add_child(crest)
	pj.get_tree().current_scene.add_child(wave)
	var flat = c.global_position.distance_to(at)
	var rise_at = pj.gp(c.global_position + d * clampf(flat * 0.5, 3.0, 6.0))
	wave.global_position = rise_at - Vector3.UP * 10.0
	wave.rotation.y = atan2(d.x, d.z)
	var tw = wave.create_tween()
	tw.tween_property(wave, "global_position", rise_at + Vector3.UP * 5.0, 0.5)
	tw.tween_property(wave, "global_position", at + Vector3.UP * 1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(wave, "rotation:x", deg_to_rad(70), 0.45)
	tw.tween_callback(func():
		_flood_impact(pj, at)
		pj.hit(c, at + Vector3.UP, 7.0, pj.inf(c, "ryusa_bakuryu", 2.0, {"knock": 10.0, "kind": "heavy"}))
		for e in pj.enemies_near(c, at, 7.0):
			pj.st(e, "bind", 2.0)
		pj.shake(1.2))
	tw.tween_interval(1.0)
	tw.tween_property(wave, "scale", Vector3(1, 0.02, 1), 0.6)
	tw.parallel().tween_method(_fade_all(wave), 0.0, 1.0, 0.6)
	tw.tween_callback(wave.queue_free)
	# tepeden savrulan kum
	grains(pj, Vector3(0, 5.0, 2.0), {"parent": wave, "stream": true, "dur": 0.95, "box": Vector3(7.0, 0.3, 0.6), "n": 140, "life": 0.9,
		"dir": Vector3.UP, "spread": 35.0, "v0": 2.0, "v1": 6.0, "g": Vector3(0, -9.0, 0), "s0": 0.05, "s1": 0.1})
	# kameraya yakın: alçak kum seli (zemin akışı + alçak pus)
	var mid = c.global_position.lerp(at, 0.5)
	var yaw = atan2(d.x, d.z)
	ground(pj, mid, 1.0, 2, 3.4, {"scale": Vector3(4.6, 1.0, maxf(2.0, flat * 0.5)), "yaw": yaw, "spin": 2.5, "grow_t": 0.5})
	for k in 4:
		var q = pj.gp(c.global_position.lerp(at, 0.2 + k * 0.2)) + Vector3.UP * 0.45
		pj.after(0.15 + k * 0.1, func():
			haze(pj, q, 1.6, 1.0, {"vel": d * 2.0 + Vector3.UP * 0.1}))
	grains(pj, pj.gp(mid) + Vector3.UP * 0.2, {"stream": true, "dur": 0.9, "box": Vector3(3.6, 0.1, maxf(1.0, flat * 0.45)), "yaw": yaw, "n": 90, "life": 0.6,
		"dir": d, "spread": 15.0, "v0": 3.0, "v1": 6.0, "g": Vector3(0, -6.0, 0)})
	Sfx.play("earth", c.global_position, 0.4)


## Akan kum perdesinin çöküşü: geniş kum seli, dışa yayılan alçak kabarma halkası, tane fışkırması, alçak pus halkası
static func _flood_impact(pj: ClanJutsu, at: Vector3) -> void:
	ground(pj, at, 9.0, 0, 5.0, {"grow_t": 0.35})
	ground(pj, at, 5.0, 1, 3.0, {"spin": 0.6, "grow_t": 0.3, "alpha": 0.6})
	_surge(pj, at, 2.0, 9.0, 0.7, 0.9)
	grains(pj, at + Vector3.UP * 0.6, {"ring": 6.0, "ring_in": 2.0, "n": 160, "life": 1.2, "dir": Vector3.UP, "spread": 60.0, "v0": 4.0, "v1": 10.0, "g": Vector3(0, -12.0, 0),
		"s0": 0.05, "s1": 0.1})
	for k in 6:
		var a = TAU * k / 6.0 + randf() * 0.4
		haze(pj, at + Vector3(cos(a) * 5.0, 1.0, sin(a) * 5.0), 3.5, 1.4, {"vel": Vector3(cos(a), 0.2, sin(a)) * 2.5, "near0": 2.0, "near1": 5.0})


## Suna Bunshin: kum yerden döne döne yükselir, kopya alttan üste kumla dolarak belirir (kumdan beden, SandCoat);
## vurulunca yığılıp dağılır, kumu vuranların üstüne atılıp bedenlerine sarılır ve onları bağlar.
static func suna_bunshin(pj: ClanJutsu, c: Node3D, _t: Node3D) -> void:
	var at = c.global_position + c.global_transform.basis.x * 2.5
	var g = pj.gp(at)
	grains(pj, g + Vector3.UP * 0.1, {"ring": 0.7, "ring_in": 0.3, "n": 70, "life": 0.7, "dir": Vector3.UP, "spread": 10.0, "v0": 2.5, "v1": 4.5, "g": Vector3(0, -2.0, 0), "radial": -1.0})
	ground(pj, g, 1.3, 0, 3.0)
	var col = sand(_tube([Vector3(0, 0, 0), Vector3(0.15, 0.6, 0.0), Vector3(-0.1, 1.2, 0.08), Vector3(0.05, 1.8, 0)], [0.5, 0.4, 0.36, 0.2], [SD, SM, SM, SL], 10, 3, true, true),
		{"near0": 1.2, "near1": 3.0, "tint": Color.WHITE})
	_put(pj, col, g)
	col.scale = Vector3(1, 0.05, 1)
	var ct = col.create_tween()
	ct.tween_property(col, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.parallel().tween_property(col, "rotation:y", PI, 0.4)
	crumble(pj, col, 0.22, 0.3)
	var dec = pj.decoy(c, at, 12.0, func(p: Vector3):
		_clone_burst(pj, p)
		for e in pj.enemies_near(c, p, 4.5):
			pj.st(e, "bind", 2.5)
			_wrap_enemy(pj, e, p))
	if dec != null:
		var w = weakref(dec)
		_later(pj, 0.03, func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x) and x.get("model") != null:
				SandCoat.apply(x, 1.35, 0.5, 0.012, 1.3))
	grains(pj, c.global_position + Vector3.UP * 0.2, {"r": 0.5, "n": 24, "life": 0.5, "dir": Vector3.UP, "spread": 50.0, "v0": 1.0, "v1": 3.0})


static func _clone_burst(pj: ClanJutsu, p: Vector3) -> void:
	var heap = sand(_ball(0.12, 31), {"near0": 1.2, "near1": 3.0, "tint": SM})
	_put(pj, heap, pj.gp(p))
	heap.scale = Vector3(0.4, 0.9, 0.4)
	var tw = heap.create_tween()
	tw.tween_property(heap, "scale", Vector3(0.9, 0.3, 0.9), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	crumble(pj, heap, 1.2, 0.6)
	grains(pj, p + Vector3.UP, {"r": 0.7, "n": 90, "life": 0.9, "dir": Vector3.UP, "spread": 70.0, "v0": 2.0, "v1": 6.0, "g": Vector3(0, -10.0, 0)})
	ground(pj, p, 1.8, 0, 3.0)


## Klondan fırlayan kum topağı yay çizip düşmana çarpar, bedenine sarılır (gerçek beden), ayağında kum yığını
static func _wrap_enemy(pj: ClanJutsu, e: Node3D, from: Vector3) -> void:
	var glob = sand(_ball(0.15, 33), {"near0": 1.0, "near1": 2.5, "tint": SM})
	_put(pj, glob, from + Vector3.UP)
	glob.scale = Vector3.ONE * 0.35
	var we = weakref(e)
	var tw = glob.create_tween()
	tw.tween_method(func(u: float):
		var x = we.get_ref()
		if x != null and is_instance_valid(x) and is_instance_valid(glob):
			glob.global_position = (from + Vector3.UP).lerp(x.global_position + Vector3.UP, u) + Vector3.UP * sin(u * PI) * 1.2, 0.0, 1.0, 0.18)
	tw.tween_callback(glob.queue_free)
	_later(pj, 0.18, func():
		var x = we.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return
		var coat = SandCoat.apply(x, 0.8, 0.22, 0.04, 1.0)
		_later(pj, 2.5, func(): SandCoat.remove(coat, 0.4))
		var bs = ClanJutsu.body_scale(x)
		var col = sand(_ball(0.14, 35), {"near0": 1.0, "near1": 2.5, "tint": SM, "crack": 0.3})
		x.add_child(col)
		col.position = Vector3.UP * 0.1
		col.scale = Vector3(0.9, 0.35, 0.9) * bs
		crumble(pj, col, 2.3, 0.4)
		grains(pj, x.global_position + Vector3.UP, {"r": 0.5, "n": 30, "life": 0.6, "dir": Vector3.UP, "spread": 80.0, "v0": 1.0, "v1": 3.0}))


## Suna Shuriken: kum, karakterin gerçek kollarını sarıp kemiklere bağlı dev pençe kollara döner (mavi damar, sırt
## dikenleri, koyu tırnaklar); kollar öne savrulunca kenarlarından mekik kum bıçakları yelpaze gibi fırlar (arkalarında ince
## tane izi), değdiği yerde kum saçılır, vurulan yavaşlar; sonra kollar ufalanıp dökülür.
static func suna_shuriken(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var base = c.global_position
	Sfx.play("earth", base, 1.6, 0.7)
	grains(pj, base + Vector3.UP * 0.1, {"ring": 1.0, "ring_in": 0.4, "n": 60, "life": 0.6, "dir": Vector3.UP, "spread": 20.0, "v0": 1.5, "v1": 3.5, "g": Vector3(0, -2.0, 0), "radial": -1.5})
	var arms = _sand_arms(c)
	pj.get_tree().create_timer(0.42).timeout.connect(func():
		if not is_instance_valid(c):
			return
		CastAnim.play(c, "suna_shuriken_swing")
		Sfx.play("whoosh", c.global_position, 1.1, 0.9))
	pj.get_tree().create_timer(0.56).timeout.connect(func():
		if not is_instance_valid(c):
			return
		var aim = pj.fwd(c, t)
		var tgt0 = pj.tg(c, t, 40.0)
		var info = pj.inf(c, "suna_shuriken", 0.13, {"knock": 3.0, "kind": "light"})
		var k = 0
		var on_hit = func(p, tgt):
			pj.st(tgt, "slow", 2.5)
			grains(pj, p, {"r": 0.3, "n": 24, "life": 0.6, "dir": Vector3.UP, "spread": 80.0, "v0": 1.5, "v1": 4.0, "g": Vector3(0, -9.0, 0)})
		for arm in arms:
			if not is_instance_valid(arm):
				continue
			var pts: Array = arm.get_meta("edge")
			for q in pts:
				var from: Vector3 = arm.global_transform * q
				var d = aim
				if tgt0:
					d = (tgt0.global_position + Vector3.UP * 1.0 - from).normalized()
				d = d.rotated(Vector3.UP, randf_range(-0.22, 0.22))
				d.y += randf_range(-0.05, 0.09)
				var blade = sand(_blade_mesh(), {"near0": 0.6, "near1": 1.6, "tint": Color.WHITE})
				var sx = 1.0 if k % 2 == 0 else -1.0
				var pr = pj.shot(c, from, d.normalized(), 40.0 + randf_range(-4, 6), blade, info, null, false, 1.3, on_hit)
				pr.spin = Vector3(0, 0, 30.0 * sx)
				grains(pj, Vector3.ZERO, {"parent": pr, "stream": true, "dur": 1.3, "r": 0.08, "n": 16, "life": 0.3, "dir": Vector3.UP, "spread": 180.0,
					"v0": 0.1, "v1": 0.4, "g": Vector3(0, -3.0, 0), "s0": 0.025, "s1": 0.05})
				k += 1
		grains(pj, c.global_position + Vector3.UP * 1.4, {"r": 0.5, "n": 50, "life": 0.35, "dir": aim, "spread": 30.0, "v0": 10.0, "v1": 18.0, "g": Vector3.ZERO,
			"s0": 0.03, "s1": 0.06}))
	# kollar ufalanır
	pj.get_tree().create_timer(1.25).timeout.connect(func():
		for arm in arms:
			if not is_instance_valid(arm):
				continue
			grains(pj, arm.global_transform * Vector3(arm.get_meta("mid")), {"r": 0.6, "n": 50, "life": 0.9, "dir": Vector3.DOWN, "spread": 60.0,
				"v0": 0.3, "v1": 2.0, "g": Vector3(0, -7.0, 0)})
			var bas: Array = arm.get_meta("bas")
			for pv in arm.get_meta("pivots"):
				if is_instance_valid(pv):
					var tw = pv.create_tween()
					tw.tween_property(pv, "scale", Vector3(0.7, 0.05, 0.7), 0.3)
			var up_m = arm.get_meta("upper")
			var ft = arm.create_tween()
			ft.tween_method(_pf(arm, "fade"), 0.0, 1.0, 0.3)
			if is_instance_valid(up_m):
				ft.parallel().tween_method(_pf(up_m, "fade"), 0.0, 1.0, 0.3)
			arm.get_tree().create_timer(0.32).timeout.connect(func():
				for ba in bas:
					if is_instance_valid(ba):
						ba.queue_free()))


## Sabaku Taisō: hedefin çevresinden kum sütunlar halinde göğe akar, yukarıda dağ büyüklüğünde topak kum kütlesi toplanır
## (altından kum dilleri sarkar, kum yağar); kütle düşüp alanı gömer: yayvan kum tepesi, dışa kabaran kum halkası,
## geniş kum örtüsü yere yayılır, yavaşça söner.
static func sabaku_taiso(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var root = Node3D.new()
	var mass = sand(_ball(0.12, 71), {"near0": 6.0, "near1": 9.0, "tint": SM, "streak": 0.4, "flow": 1.5}, true)
	mass.scale = Vector3(8.0, 4.0, 8.0)
	root.add_child(mass)
	var tend = []
	for k in 9:
		var a = TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var rr = randf_range(2.0, 6.5)
		var o = Vector3(cos(a) * rr, -2.2, sin(a) * rr)
		var L = randf_range(5.0, 9.0)
		var tm = sand(_tube([o, o + Vector3(randf_range(-0.4, 0.4), -L * 0.5, randf_range(-0.4, 0.4)), o + Vector3(randf_range(-0.6, 0.6), -L, randf_range(-0.6, 0.6))],
			[randf_range(0.8, 1.3), 0.6, 0.15], [SM, SM, SL], 8, 3, true, true), {"near0": 6.0, "near1": 9.0, "streak": 1.0, "flow": 6.0, "tint": Color.WHITE})
		root.add_child(tm)
		tend.append(tm)
	pj.get_tree().current_scene.add_child(root)
	root.global_position = at + Vector3.UP * 26.0
	root.scale = Vector3.ONE * 0.4
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kill(pj, 4.0, root)
	# yerden göğe akan kum sütunları + kütlenin altından yağan kum
	for k in 6:
		var a = TAU * k / 6.0 + randf() * 0.5
		grains(pj, at + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 9.0) + Vector3.UP * 0.2, {"stream": true, "dur": 0.45, "r": 0.8, "n": 40, "life": 1.1,
			"dir": Vector3.UP, "spread": 4.0, "v0": 18.0, "v1": 24.0, "g": Vector3.ZERO, "s0": 0.12, "s1": 0.22})
	grains(pj, at + Vector3.UP * 22.0, {"stream": true, "dur": 0.8, "box": Vector3(6.0, 0.5, 6.0), "n": 120, "life": 1.4, "dir": Vector3.DOWN, "spread": 6.0,
		"v0": 8.0, "v1": 14.0, "g": Vector3(0, -9.0, 0), "s0": 0.08, "s1": 0.16})
	var tw = root.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(root, "global_position", at + Vector3.UP * 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_taiso_impact(pj, at)
		pj.hit(c, at + Vector3.UP, 9.0, pj.inf(c, "sabaku_taiso", 3.2, {"knock": 6.0, "kind": "heavy", "hitstop": 0.15}))
		for e in pj.enemies_near(c, at, 9.0):
			pj.st(e, "bind", 2.0)
		pj.shake(1.8)
		for tm in tend:
			crumble(pj, tm, 0.0, 0.3))
	tw.tween_property(mass, "scale", Vector3(9.0, 0.25, 9.0), 0.6)
	tw.parallel().tween_property(root, "global_position", at + Vector3.UP * 0.1, 0.6)
	tw.tween_interval(1.0)
	tw.tween_property(mass, "scale", Vector3(9.0, 0.01, 9.0), 0.6)
	tw.parallel().tween_method(_pf(mass, "fade"), 0.0, 1.0, 0.6)
	tw.tween_callback(root.queue_free)
	Sfx.play("earth", at, 0.4)


static func _taiso_impact(pj: ClanJutsu, at: Vector3) -> void:
	ground(pj, at, 14.0, 0, 6.0, {"grow_t": 0.4})
	_surge(pj, at, 4.0, 15.0, 1.2, 1.0)
	grains(pj, at + Vector3.UP * 0.8, {"ring": 9.0, "ring_in": 5.0, "n": 200, "life": 1.3, "dir": Vector3.UP, "spread": 50.0, "v0": 6.0, "v1": 14.0, "g": Vector3(0, -12.0, 0),
		"s0": 0.06, "s1": 0.14})
	for k in 8:
		var a = TAU * k / 8.0 + randf() * 0.3
		haze(pj, at + Vector3(cos(a) * 8.0, 1.5, sin(a) * 8.0), 4.5, 1.6, {"vel": Vector3(cos(a), 0.2, sin(a)) * 3.0, "near0": 2.0, "near1": 5.0})


## Sabaku Rō: hedefin çevresinden ucu koyu sivri yedi kalın kum dili kıvrılarak kalkar, üstünde buluşur; kapanınca pürüzsüz,
## sıkışmış (çatlaklı) kum küresine döner, yüzeyde kapanan dillerin sarmal dikişleri kalır; içeride sıkıştırır, sonra kum
## yağmuru olarak dökülür.
static func sabaku_ro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.7)
	if tt == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	pj.anim(c, "push", 1.2)
	var fit = pj._tgt_fit(tt)
	var cen = tt.global_position + Vector3.UP * 0.9 * fit
	var g = pj.gp(tt.global_position)
	Sfx.play("th_sand", g, 0.9)
	grains(pj, g + Vector3.UP * 0.2, {"ring": 3.6 * fit, "ring_in": 1.5 * fit, "n": 80, "life": 0.9, "dir": Vector3.UP, "spread": 25.0, "v0": 3.0, "v1": 7.0, "g": Vector3(0, -9.0, 0)})
	ground(pj, g, 4.4 * fit, 0, 4.6, {"grow_t": 0.3})
	var petals = []
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		var o = Vector3(cos(a), 0, sin(a))
		var r0 = 4.2 * fit
		var pts = []
		var rads = []
		for s in 7:
			var u = float(s) / 6.0
			var ang = u * PI * 0.92
			pts.append(o * (r0 * cos(ang * 0.55) * (1.0 - u * 0.75)) + Vector3.UP * (sin(ang) * 2.4 * fit + u * 0.8 * fit) - Vector3.UP * 0.9 * fit)
			rads.append(Vector2(lerpf(0.75, 0.25, u), lerpf(0.55, 0.2, u)) * fit)
		var last: Vector3 = pts[6]
		var prev: Vector3 = pts[5]
		pts.append(last + (last - prev).normalized() * 0.55 * fit)
		rads.append(Vector2(0.03, 0.03) * fit)
		var mi = sand(_tube(pts, rads, [SD, SM, SL, SL, SM, SM, SD, SX], 12, 4, false, true), {"crack": 0.2, "near0": 2.0, "near1": 4.0, "tint": Color.WHITE}, true)
		_put(pj, mi, cen)
		mi.scale = Vector3(1, 0.05, 1)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.03)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		petals.append(mi)
		_kill(pj, 1.5, mi)
	pj.after(0.4, func():
		if not pj.live(tt):
			for pm in petals:
				crumble(pj, pm, 0.0, 0.3)
			return
		pj.st(tt, "bind", 3.2)
		if tt is CharacterBody3D:
			tt.velocity = Vector3.ZERO
		var ball = _prison_ball(fit)
		_put(pj, ball, cen)
		_kill(pj, 4.5, ball)
		ball.scale = Vector3.ONE * 0.6
		ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for pm in petals:
			crumble(pj, pm, 0.05, 0.25)
		pj.shake(0.4)
		Sfx.play("earth", cen, 0.8)
		var tick = func(_i, _k):
			if pj.live(tt):
				tt.global_position = cen - Vector3.UP * 0.9 * fit
				if tt is CharacterBody3D:
					tt.velocity = Vector3.ZERO
				tt.take_hit(pj.inf(c, "sabaku_ro", 0.18, {"knock": 0.0, "launch": 0.0, "kind": "crush", "pierce_guard": true}))
				if is_instance_valid(ball):
					var sq = ball.create_tween()
					sq.tween_property(ball, "scale", Vector3.ONE * 0.93, 0.08)
					sq.tween_property(ball, "scale", Vector3.ONE, 0.2)
					grains(pj, cen, {"r": 1.3 * fit, "n": 18, "life": 0.6, "dir": Vector3.DOWN, "spread": 60.0, "v0": 0.2, "v1": 1.0, "g": Vector3(0, -9.0, 0)})
		var fin = func():
			# dağılış: küre kum yağmuru olarak dökülür
			grains(pj, cen, {"r": 1.4 * fit, "n": 140, "life": 1.1, "burst": 0.7, "dir": Vector3.DOWN, "spread": 70.0, "v0": 0.5, "v1": 3.0, "g": Vector3(0, -9.0, 0)})
			haze(pj, cen - Vector3.UP * 0.5 * fit, 3.0 * fit, 1.2)
			ground(pj, cen, 3.0 * fit, 0, 3.5)
			if is_instance_valid(ball):
				crumble(pj, ball, 0.0, 0.4)
		pj.every(3.0, 0.6, tick, fin))


## Suna Arare: hedefin üstünde, altı sivri kum dilli yassı kum bulutu toplanır, ince kum çiseler; bulutun altından yuvarlak,
## ince taneli kum topakları (yanlarında küçük kırıntılar) yağar; yere çarpan topak yassılaşıp kalır, çukur ve sıçrayan
## kumla çözülür.
static func suna_arare(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.2)
	var tt = pj.tg(c, t, 34.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 14.0)
	Sfx.play("th_sand", c.global_position, 0.8)
	grains(pj, pj.gp(c.global_position) + Vector3.UP * 0.3, {"r": 1.5, "n": 50, "life": 0.9, "dir": Vector3.UP, "spread": 25.0, "v0": 6.0, "v1": 12.0, "g": Vector3(0, -2.0, 0)})
	var cloud = _hail_cloud()
	_put(pj, cloud, at + Vector3.UP * 17.0)
	cloud.scale = Vector3.ONE * 0.3
	cloud.create_tween().tween_property(cloud, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	crumble(pj, cloud, 2.2, 0.7)
	grains(pj, at + Vector3.UP * 15.0, {"stream": true, "dur": 1.9, "box": Vector3(5.0, 0.3, 5.0), "n": 80, "life": 1.6, "dir": Vector3.DOWN, "spread": 8.0,
		"v0": 4.0, "v1": 8.0, "g": Vector3(0, -6.0, 0), "s0": 0.05, "s1": 0.1})
	var hits = []
	for k in 16:
		pj.after(0.35 + k * 0.08, func():
			var off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.0, 7.0)
			if k < 3 and tt and pj.live(tt):
				off = Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))   # ilk birkaçı hedefin tepesine
			var land = pj.gp(at + off)
			var r = randf_range(0.55, 1.25)
			var holder = Node3D.new()
			var ball = sand(_ball(0.035, 90 + k % 5), {"near0": 2.0, "near1": 4.5, "tint": SM}, true)
			ball.scale = Vector3.ONE * r
			holder.add_child(ball)
			for m in 3:
				var crumb = sand(_ball(0.1, 96 + m), {"near0": 1.0, "near1": 2.5, "tint": SL})
				crumb.scale = Vector3.ONE * r * randf_range(0.1, 0.2)
				crumb.position = Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 2.0), randf_range(-1.0, 1.0)) * r
				holder.add_child(crumb)
			_put(pj, holder, land + Vector3.UP * 16.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
			_kill(pj, 3.5, holder)
			var tw = holder.create_tween()
			tw.tween_property(holder, "global_position", land + Vector3.UP * r, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(ball, "rotation", Vector3(randf() * 3, randf() * 3, 0), 0.55)
			tw.tween_callback(func():
				if k % 4 == 0:
					hits.clear()   # her dört topakta bir aynı hedef yeniden vurulabilir
				for h in pj.hit(c, land + Vector3.UP * 0.8, 1.6 + r, pj.inf(c, "suna_arare", 0.22, {"knock": 7.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.04}), hits):
					hits.append(h)
					pj.st(h, "slow", 1.5)
				ground(pj, land, 1.2 + r, 0, 2.6, {"grow_t": 0.15})
				grains(pj, land + Vector3.UP * 0.3, {"ring": r, "ring_in": r * 0.5, "n": 26, "life": 0.7, "dir": Vector3.UP, "spread": 75.0, "v0": 2.0, "v1": 5.0, "g": Vector3(0, -12.0, 0)})
				haze(pj, land + Vector3.UP * 0.5, r * 2.2, 0.8)
				Sfx.play("earth", land, randf_range(0.9, 1.15), 0.6)
				for ch in holder.get_children():
					if ch != ball:
						crumble(pj, ch, 0.0, 0.2)
				var tw2 = ball.create_tween()
				tw2.tween_property(ball, "scale", Vector3(1.3 * r, 0.25 * r, 1.3 * r), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw2.parallel().tween_property(holder, "global_position", land + Vector3.UP * 0.2 * r, 0.35)
				crumble(pj, holder, 1.4, 0.6)))
	pj.shake(0.4)


## Rendan Suna Shigure: atanın çevresinde eğik, kalın, taneli kum halkası döner; halkanın yüzünden tomurcuklanan, önü
## yuvarlak arkası uzun kuyruklu kum damlaları art arda fırlar (arkalarında ince tane izi), değdiği yerde kum sıçrar.
static func rendan_suna_shigure(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 34.0)
	Sfx.play("th_sand", c.global_position, 1.1)
	var ring = Node3D.new()
	_put(pj, ring, c.global_position + Vector3.UP * 1.2)
	ring.rotation = Vector3(0.28, 0.0, 0.18)
	var spinner = Node3D.new()
	ring.add_child(spinner)
	var pts = []
	var rads = []
	for s in 14:
		var a = s / 13.0 * TAU * 0.85
		pts.append(Vector3(cos(a) * 1.6, sin(s * 0.7) * 0.25, sin(a) * 1.6))
		rads.append(Vector2(0.3, 0.24) * (0.6 + 0.4 * sin(s / 13.0 * PI)))
	var rm = sand(_tube(pts, rads, [SD, SM, SM, SL, SL, SM, SM, SL, SL, SM, SM, SL, SM, SD], 12, 4, true, true), {"near0": 1.0, "near1": 2.6, "tint": Color.WHITE})
	spinner.add_child(rm)
	spinner.scale = Vector3.ONE * 0.3
	spinner.create_tween().tween_property(spinner, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	var rt = Game.safe_loops(spinner.create_tween())
	rt.tween_property(spinner, "rotation:y", TAU, 0.6).from(0.0)
	grains(pj, pj.gp(c.global_position) + Vector3.UP * 0.1, {"ring": 1.4, "ring_in": 0.8, "n": 50, "life": 0.5, "dir": Vector3.UP, "spread": 10.0, "v0": 2.0, "v1": 3.5, "g": Vector3.ZERO})
	var info = pj.inf(c, "rendan_suna_shigure", 0.1, {"knock": 2.5, "kind": "light", "hitstop": 0.02})
	var on_hit = func(p, _h):
		grains(pj, p, {"r": 0.15, "n": 14, "life": 0.45, "dir": Vector3.UP, "spread": 90.0, "v0": 1.0, "v1": 3.0, "g": Vector3(0, -8.0, 0)})
	for k in 14:
		pj.after(0.12 + k * 0.05, func():
			if not pj.live(c):
				return
			var a = randf() * TAU
			var from = c.global_position + Vector3.UP * (1.0 + randf() * 0.6) + Vector3(cos(a), 0, sin(a)) * 1.6
			var aim = c.face_dir()
			if tt and pj.live(tt):
				aim = (tt.global_position + Vector3.UP * 1.0 - from).normalized()
			aim = (aim + Vector3(randf_range(-0.05, 0.05), randf_range(-0.03, 0.05), randf_range(-0.05, 0.05))).normalized()
			_bud(pj, from)
			var drop = sand(_drop_mesh(), {"near0": 0.6, "near1": 1.6, "tint": Color.WHITE})
			var pr = pj.shot(c, from, aim, 46.0, drop, info, null, false, 1.2, on_hit)
			grains(pj, Vector3.ZERO, {"parent": pr, "stream": true, "dur": 1.2, "r": 0.06, "n": 10, "life": 0.25, "dir": Vector3.UP, "spread": 180.0,
				"v0": 0.1, "v1": 0.3, "g": Vector3(0, -3.0, 0), "s0": 0.02, "s1": 0.045})
			Sfx.play("whoosh", from, 1.5, 0.3))
	_later(pj, 0.95, func():
		if is_instance_valid(ring):
			grains(pj, ring.global_position, {"ring": 1.6, "ring_in": 1.2, "n": 50, "life": 0.8, "dir": Vector3.DOWN, "spread": 30.0, "v0": 0.2, "v1": 1.0, "g": Vector3(0, -9.0, 0)}))
	crumble(pj, ring, 0.95, 0.3)


## Sabaku Sōtaisō Fūin: kum hedefin ayaklarından boynuna dek sarılır (gerçek beden), zeminde kum mühür dairesi belirir;
## kat kat kum levhaları yukarıdan inip üst üste oturarak basamaklı dev bir mühür piramidi kurar (koyu mühür bantları,
## her yüzde dikey mühür çizgisi ve mühür dairesi); mühür boyunca çatlaklar nabız gibi atar, sonunda piramit kuma çöker.
static func sabaku_sotaiso_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.4)
	if tt == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	pj.anim(c, "seal", 1.0)
	var fit = pj._tgt_fit(tt, 1.8, 8.0)
	var g = pj.gp(tt.global_position)
	pj.st(tt, "bind", 1.6)
	Sfx.play("th_sand", g, 0.7)
	# kum ayaktan boyna sarılır: bağlama + ses + gerçek beden kaplaması
	grains(pj, g + Vector3.UP * 0.2, {"ring": 1.2, "ring_in": 0.5, "n": 60, "life": 0.6, "dir": Vector3.UP, "spread": 20.0, "v0": 2.0, "v1": 4.0, "g": Vector3(0, -2.0, 0), "radial": -2.0})
	pj.st(tt, "bind", 2.6)
	Sfx.play("earth", tt.global_position, 1.3)
	var coat = SandCoat.apply(tt, 0.78, 0.4, 0.03, 1.0)
	grains(pj, g + Vector3.UP * 0.2, {"ring": 4.0 * fit, "ring_in": 1.5 * fit, "n": 90, "life": 1.0, "dir": Vector3.UP, "spread": 35.0, "v0": 2.0, "v1": 6.0, "g": Vector3(0, -6.0, 0)})
	var tiers = 4 if fit > 2.0 else 3
	var w0 = 8.0 * fit
	var hgt = 7.5 * fit
	var hstep = hgt / tiers
	var root = Node3D.new()
	_put(pj, root, g)
	root.rotation.y = PI * 0.25
	var rise = 0.35 + tiers * 0.25
	var lock_t = 6.0
	_kill(pj, 0.3 + rise + lock_t + 3.0, root)
	ground(pj, g, w0 * 0.85, 3, 0.3 + rise + lock_t + 1.5, {"grow_t": 0.4, "tint": SM, "yaw": PI * 0.25})
	var slabs = []
	for i in tiers:
		var slab = sand(_tier_mesh(i, tiers, w0, hstep), {"near0": 4.0, "near1": 7.0, "tint": Color.WHITE}, true)
		root.add_child(slab)
		var y0 = hstep * i
		slab.position = Vector3(0, y0 + 4.0 * fit, 0)
		slab.visible = false
		var t0 = 0.3 + rise * float(i) / tiers
		var t1 = 0.3 + rise * float(i + 1) / tiers
		var tw = slab.create_tween()
		tw.tween_interval(t0)
		tw.tween_callback(func(): slab.visible = true)
		tw.tween_property(slab, "position:y", y0, t1 - t0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slabs.append(slab)
	for i in tiers:
		var lvl = i
		pj.after(0.3 + rise * float(i + 1) / tiers, func():
			Sfx.play("earth", g + Vector3.UP * hstep * lvl, 0.85, 0.7)
			var wl = w0 * 0.46 * (1.0 - float(lvl) / tiers)
			grains(pj, g + Vector3.UP * hstep * (lvl + 0.1), {"ring": wl, "ring_in": wl * 0.8, "n": 60, "life": 0.9, "dir": Vector3.UP, "spread": 70.0,
				"v0": 1.0, "v1": 4.0, "g": Vector3(0, -9.0, 0), "s0": 0.05, "s1": 0.1})
			haze(pj, g + Vector3.UP * hstep * (lvl + 0.2) + Vector3(wl, 0, 0).rotated(Vector3.UP, randf() * TAU), 2.0 * fit, 1.0, {"near0": 2.0, "near1": 5.0})
			pj.shake(0.25))
	# mühür: hedef piramidin içinde; bağlı, chakrası emilir, ağır hasar
	pj.after(0.3 + rise, func():
		if not pj.live(tt):
			crumble(pj, root, 1.0, 0.6)
			SandCoat.remove(coat, 0.4)
			return
		pj.st(tt, "bind", lock_t)
		Combat.popup_text(g + Vector3.UP * hgt, "Mühürlendi!", Color(0.95, 0.85, 0.55))
		var tick = func(_i, _k):
			if pj.live(tt):
				tt.global_position = g
				if tt is CharacterBody3D:
					tt.velocity = Vector3.ZERO
				tt.take_hit(pj.inf(c, "sabaku_sotaiso_fuin", 0.3, {"knock": 0.0, "kind": "crush", "pierce_guard": true}))
				if "chakra" in tt:
					tt.chakra = maxf(0.0, float(tt.chakra) - 12.0)   # mühür chakrayı söndürür
				for sl in slabs:
					if is_instance_valid(sl):
						var ct = sl.create_tween()
						ct.tween_method(_pf(sl, "crack"), 0.9, 0.15, 0.6)
		var fin = func():
			# çözülme: piramit kum olarak çöker
			grains(pj, g + Vector3.UP * hgt * 0.3, {"ring": w0 * 0.45, "ring_in": w0 * 0.2, "n": 160, "life": 1.3, "dir": Vector3.UP, "spread": 60.0,
				"v0": 1.0, "v1": 4.0, "g": Vector3(0, -9.0, 0), "s0": 0.06, "s1": 0.12})
			for k in 4:
				var a = TAU * k / 4.0
				haze(pj, g + Vector3(cos(a), 0, sin(a)) * w0 * 0.4 + Vector3.UP * 1.2, 3.0 * fit, 1.4, {"near0": 2.0, "near1": 5.0})
			ground(pj, g, w0 * 0.7, 0, 4.0, {"grow_t": 0.5})
			SandCoat.remove(coat, 0.6)
			if is_instance_valid(root):
				var cl = root.create_tween()
				cl.tween_property(root, "scale", Vector3(1.08, 0.02, 1.08), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				cl.parallel().tween_method(_fade_all(root), 0.0, 1.0, 0.7)
				cl.tween_callback(root.queue_free)
		pj.every(lock_t, 1.0, tick, fin))
	pj.shake(0.6)
