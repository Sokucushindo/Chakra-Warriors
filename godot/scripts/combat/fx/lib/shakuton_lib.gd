class_name ShakutonLib
extends RefCounted
## Kavurma doğası malzeme / şekil kütüphanesi (Shakuton, Pakura). Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları:
##   kavurucu küre : yuvarlak kalan akkor küre — kameraya bakan yüz beyaz-sarı çekirdek, yüzeyde dönen turuncu ateş bantları,
##                   parlak loblar, ince koyu turuncu cel kontur. Alev dili YOK (Katon değil): küre yörüngede döner, süzülür.
##   kuyruk        : kürenin ardında sıvı gibi incelen sarı-turuncu "iribaş" kuyruğu (anime: kürenin arkasındaki parlak iz)
##   ısı           : yumuşak hale, sıcak hava dalgalanması (arkadaki görüntü titrer), ısı zerreleri
##   kurutma       : kurbandan yükselen ince, dalgalı beyaz buhar şeritleri; ten kararır, kuru deri pulları dökülür;
##                   yerde suyu çekilmiş soluk gri-bej kuru zemin ve kurumuş ot çizgileri (ref: Scorch Release Aftermath)
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

const PAL_SUN := 0.0      # Pakura: sarı-turuncu akkor
const PAL_CRIMSON := 1.0  # büyük patlama: beyaz çekirdek, kızıl-pembe kenar (ref: Great Steaming Explosive Blast)

const DRY_SKIN := Color(0.34, 0.25, 0.19)

static var _cache := {}

# ================================================================== shader parçaları
const SNOISE := """
float sk_h(vec2 p) {
	p = fract(p * vec2(234.71, 517.13));
	p += dot(p, p + 31.77);
	return fract(p.x * p.y);
}

float sk_n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(sk_h(i), sk_h(i + vec2(1.0, 0.0)), f.x);
	float b = mix(sk_h(i + vec2(0.0, 1.0)), sk_h(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float sk_f(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * sk_n(p);
		p = p * 2.13 + vec2(1.7, 4.3);
		a *= 0.5;
	}
	return s;
}

void sk_pal(float p, out vec3 c0, out vec3 c1, out vec3 c2, out vec3 c3, out vec3 c4) {
	if (p < 0.5) {
		c0 = vec3(1.0, 0.99, 0.88);
		c1 = vec3(1.0, 0.9, 0.45);
		c2 = vec3(1.0, 0.66, 0.2);
		c3 = vec3(0.95, 0.4, 0.12);
		c4 = vec3(0.6, 0.18, 0.06);
	} else {
		c0 = vec3(1.0, 0.98, 0.95);
		c1 = vec3(1.0, 0.88, 0.78);
		c2 = vec3(1.0, 0.55, 0.45);
		c3 = vec3(0.92, 0.27, 0.24);
		c4 = vec3(0.5, 0.08, 0.09);
	}
}
"""

## Kavurucu küre (küre mesh, r = 1). Yüzey yuvarlak kalır (yalnız hafif nabız); ateş bantları küre etrafında sarmal döner.
const ORB_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float swirl = 1.0;
instance uniform float near = 3.0;

varying vec3 lp;

SNOISE

void vertex() {
	lp = VERTEX;
	float w = sk_n(VERTEX.xz * 2.0 + vec2(seed * 3.0, TIME * 0.9 * swirl));
	VERTEX *= 1.0 + (w - 0.5) * 0.06 + sin(TIME * 5.0 + seed * 4.0) * 0.015;
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lon = atan(lp.z, lp.x);
	float lat = lp.y;
	float t = TIME * swirl;
	float tw = lat * 4.2 + sin(lon * 2.0 + t * 2.1 + seed) * 0.8 + sk_f(vec2(lon * 1.1 + t * 1.3, lat * 2.6 + seed)) * 2.4;
	float band = 0.5 + 0.5 * sin(tw * 2.2 - t * 3.4);
	float lobe = sk_f(vec2(lon * 1.6 - t * 0.7, lat * 2.0 + seed * 2.0));
	float e = fv * 0.82 + band * 0.24 * (1.0 - fv * 0.4);
	if (lobe > 0.6 && fv > 0.35) {
		e += 0.22;
	}
	e *= heat;
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	sk_pal(pal, c0, c1, c2, c3, c4);
	vec3 col = c3;
	if (e > 0.34) {
		col = c2;
	}
	if (e > 0.56) {
		col = c1;
	}
	if (e > 0.8) {
		col = c0;
	}
	if (fv < 0.16) {
		col = c4;
	}
	float cam = smoothstep(near * 0.4, near, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2)) * 1.5;
	ALPHA = fade * cam * (fv < 0.16 ? 0.9 : 1.0);
}
"""

## Yumuşak ısı halesi (kameraya dönük, toplamalı): halka halka hafif dalgalanan sıcak parıltı
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 hcol = vec3(1.0, 0.6, 0.2);
instance uniform float fade = 1.0;
instance uniform float near = 4.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float rip = 0.85 + 0.15 * sin(r * 18.0 - TIME * 6.0);
	float a = pow(max(1.0 - r, 0.0), 2.4) * rip * fade;
	ALBEDO = hcol;
	ALPHA = a * smoothstep(near * 0.4, near, -VERTEX.z);
}
"""

## Sıcak hava: arkadaki görüntü yukarı akan dalgalarla titrer (kameraya dönük, dikey eksen sabit)
const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D under_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

SNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 rt = normalize(cross(up, tocam) + vec3(0.0001, 0.0, 0.0));
	vec3 fw = cross(rt, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * s, 0.0), vec4(up * sy, 0.0), vec4(fw * s, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = (1.0 - smoothstep(0.3, 1.0, length(p * vec2(1.0, 0.8)))) * fade;
	float w1 = sk_n(vec2(UV.x * 6.0 + seed, UV.y * 5.0 + TIME * 2.2));
	float w2 = sin(UV.y * 22.0 + TIME * 7.0 + seed * 3.0);
	vec2 off = vec2((w1 - 0.5) * 0.03 + w2 * 0.004, (sk_n(vec2(UV.x * 4.0, UV.y * 6.0 + TIME * 3.0 + seed)) - 0.5) * 0.012) * m;
	ALBEDO = texture(under_tex, SCREEN_UV + off).rgb;
	ALPHA = m * smoothstep(0.8, 3.0, -VERTEX.z);
}
"""

## Akkor şerit (strip mesh; UV.x 0 baş → 1 kuyruk, UV.y en): ortası sarı-beyaz, kenarı turuncu, kuyruğa doğru incelir ve saydamlaşır;
## kenar sıvı gibi dalgalanır. head / tail görünen aralığı keser (kesik yayı, ışın).
const TAIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float head = 0.0;
instance uniform float tail = 1.0;
instance uniform float near = 3.0;

SNOISE

void fragment() {
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	if (u < head || u > tail) {
		discard;
	}
	float n = sk_n(vec2(u * 7.0 - TIME * 4.0, seed));
	float wdt = (1.0 - u * 0.75) * (0.82 + 0.3 * n);
	float e = (1.0 - abs(v) / max(wdt, 0.05)) * (1.15 - u * 0.75) * heat;
	if (e < 0.05) {
		discard;
	}
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	sk_pal(pal, c0, c1, c2, c3, c4);
	vec3 col = c3;
	if (e > 0.25) {
		col = c2;
	}
	if (e > 0.5) {
		col = c1;
	}
	if (e > 0.78) {
		col = c0;
	}
	float span = max(tail - head, 0.001);
	float k = (u - head) / span;
	ALBEDO = pow(col, vec3(2.2)) * 1.4;
	ALPHA = fade * (1.0 - smoothstep(0.55, 1.0, k)) * smoothstep(near * 0.4, near, -VERTEX.z);
}
"""

## Buhar şeridi: kurbandan yükselen ince, dalgalı beyaz kurdele (dikey eksen, kameraya döner). rise 0..1 görünür pencereyi yukarı taşır.
const WISP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float rise = 0.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float amp = 0.18;
instance uniform float near = 3.0;

SNOISE

void vertex() {
	float u = 1.0 - UV.y;
	vec3 ax = MODEL_MATRIX[1].xyz;
	float sy = max(length(ax), 0.0001);
	ax /= sy;
	float sx = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 rt = cross(ax, tocam);
	float rl = length(rt);
	rt = rl > 0.0001 ? rt / rl : vec3(1.0, 0.0, 0.0);
	vec3 fw = cross(rt, ax);
	float off = sin(u * 7.5 + TIME * 3.6 + seed * 6.0) * amp * u + sin(u * 15.0 - TIME * 5.0 + seed) * amp * 0.25 * u;
	VERTEX.x += off / sx;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sx, 0.0), vec4(ax * sy, 0.0), vec4(fw * sx, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float u = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float lo = rise - 0.75;
	if (u > rise || u < lo) {
		discard;
	}
	float k = (u - lo) / 0.75;
	float wdt = 0.55 + 0.45 * sin(k * 3.14159);
	wdt *= 0.75 + 0.35 * sk_n(vec2(u * 9.0 - TIME * 2.0, seed));
	float e = 1.0 - abs(x) / max(wdt, 0.05);
	if (e < 0.0) {
		discard;
	}
	vec3 col = vec3(0.97, 0.97, 0.98);
	if (x > wdt * 0.35) {
		col = vec3(0.8, 0.82, 0.86);
	}
	ALBEDO = col;
	ALPHA = fade * smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.75, 1.0, k)) * (e < 0.2 ? 0.75 : 0.95) * smoothstep(near * 0.4, near, -VERTEX.z);
}
"""

## Kurutulmuş zemin (PlaneMesh 2x2): suyu çekilmiş soluk gri-bej leke, kurumuş ot / dal çizgileri, kenarda ince koyu sınır
const DRY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float grow = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float heat = 0.0;

SNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rim = grow * (0.82 + 0.18 * sk_f(vec2(ang * 2.2 + seed * 5.0, seed)));
	if (r > rim) {
		discard;
	}
	float k = r / max(rim, 0.001);
	vec2 sp = p * 6.0 + vec2(seed * 3.1, seed * 1.7);
	float n = sk_f(sp * 0.7);
	vec3 col = mix(vec3(0.78, 0.74, 0.66), vec3(0.66, 0.62, 0.55), smoothstep(0.35, 0.75, n));
	// kurumuş ot çizgileri: kısa, çatallı açık renkli çöpler
	vec2 cell = floor(sp * 1.4);
	vec2 fr = fract(sp * 1.4) - 0.5;
	float rnd = sk_h(cell + seed);
	float ca = rnd * 6.28;
	vec2 dirv = vec2(cos(ca), sin(ca));
	float along = dot(fr, dirv);
	float across = abs(dot(fr, vec2(-dirv.y, dirv.x)));
	float twig = step(across, 0.025) * step(abs(along), 0.32) * step(0.35, rnd);
	float fork = step(abs(dot(fr - dirv * 0.12, vec2(-dirv.x + dirv.y, -dirv.y - dirv.x) * 0.7071)), 0.02) * step(abs(along - 0.18), 0.1) * step(0.6, rnd);
	col = mix(col, vec3(0.9, 0.88, 0.82), max(twig, fork));
	// çatlak ağı
	float cr = sk_f(sp * 0.9 + vec2(7.3, seed));
	col = mix(col, vec3(0.45, 0.4, 0.34), (1.0 - smoothstep(0.0, 0.025, abs(cr - 0.5))) * 0.8);
	// kenar sınırı
	col = mix(col, vec3(0.42, 0.36, 0.3), smoothstep(0.86, 0.95, k));
	// sıcakken hafif kızıl parlama
	col = mix(col, vec3(1.0, 0.55, 0.35), heat * (1.0 - k) * 0.35);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * (1.0 - smoothstep(0.95, 1.0, k)) * 0.92;
}
"""


# ================================================================== malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("SNOISE", SNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func orb_mat() -> ShaderMaterial:
	return _mat("orb", ORB_SHADER)


static func halo_mat() -> ShaderMaterial:
	return _mat("halo", HALO_SHADER)


static func haze_mat() -> ShaderMaterial:
	return _mat("haze", HAZE_SHADER)


static func tail_mat() -> ShaderMaterial:
	return _mat("tail", TAIL_SHADER)


static func wisp_mat() -> ShaderMaterial:
	return _mat("wisp", WISP_SHADER)


static func dry_mat() -> ShaderMaterial:
	return _mat("dry", DRY_SHADER)


## Paletin tek rengi (ışık / hale): 0 çekirdek … 4 kontur
static func col(pal: float, i: int) -> Color:
	var tabs = [
		[Color(1.0, 0.99, 0.88), Color(1.0, 0.9, 0.45), Color(1.0, 0.66, 0.2), Color(0.95, 0.4, 0.12), Color(0.6, 0.18, 0.06)],
		[Color(1.0, 0.98, 0.95), Color(1.0, 0.88, 0.78), Color(1.0, 0.55, 0.45), Color(0.92, 0.27, 0.24), Color(0.5, 0.08, 0.09)],
	]
	var row: Array = tabs[clampi(int(round(pal)), 0, 1)]
	return row[clampi(i, 0, 4)]


static func _sphere() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sph"] = s
	return _cache["sph"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _wisp_quad() -> QuadMesh:
	if not _cache.has("wq"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.center_offset = Vector3(0.0, 0.5, 0.0)
		q.subdivide_depth = 16
		_cache["wq"] = q
	return _cache["wq"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


# ================================================================== temel yardımcılar
static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(n)   # yere serili düz efekt engebeli araziye oturur
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


static func floor_at(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


static func side_of(d: Vector3) -> Vector3:
	var s = d.cross(Vector3.UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


## Boya göre kameraya yakınlık sönümü: küçük parça yakında görünür kalır, büyük kütle 6–9 m'den itibaren incelir
static func near_of(r: float) -> float:
	return clampf(2.0 + r * 2.6, 2.5, 9.0)


# ================================================================== yapı taşları: küre
## Kavurucu küre örneği (sahneye eklenmez): r yarıçap; yanında hafif ısı halesi (çocuk)
static func orb_mi(r: float, pal := 0.0, heat := 1.0, swirl := 1.0, halo := true) -> MeshInstance3D:
	var mi = gi(_sphere(), orb_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("swirl", swirl)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", near_of(r))
	mi.scale = Vector3.ONE * r
	if halo:
		var h = halo_mi(col(pal, 2), 3.4)
		h.set_instance_shader_parameter("fade", 0.55)
		h.set_instance_shader_parameter("near", near_of(r * 1.7))
		mi.add_child(h)
	return mi


## Küre gövdesi + kuyruk noktası: mermiye eklenecek kök (kuyruk ayrıca tail() ile bağlanır)
static func orb_body(r: float, pal := 0.0, swirl := 1.0) -> Node3D:
	var root = Node3D.new()
	root.add_child(orb_mi(r, pal, 1.0, swirl))
	return root


## Küreyi açar (0'dan r'ye), yerinde nabız gibi atarak durur
static func bloom(n: Node3D, r: float, t := 0.25) -> void:
	if not is_instance_valid(n):
		return
	n.scale = Vector3.ONE * 0.05
	var tw = n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * r * 1.12, t * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector3.ONE * r, t * 0.3).set_trans(Tween.TRANS_SINE)


## Küreyi söndürür: büzülür, ısısı düşer, silinir
static func snuff(n: Node3D, t := 0.25) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	tw.tween_property(n, "scale", n.scale * 0.05, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


# ================================================================== yapı taşları: ısı
static func halo_mi(c: Color, s: float) -> MeshInstance3D:
	var mi = gi(_quad(), halo_mat())
	mi.set_instance_shader_parameter("hcol", Vector3(c.r, c.g, c.b))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", near_of(s * 0.5))
	mi.scale = Vector3.ONE * s
	return mi


## Parlama: s boyuna açılan, life'da sönen sıcak hale
static func flash(host: Node, p: Vector3, s: float, c: Color, life: float) -> MeshInstance3D:
	var mi = halo_mi(c, s * 0.3)
	put(host, mi, p)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Sıcak hava dalgalanması (w en, h boy). parent verilirse ona bağlanır (küreyle birlikte gezer)
static func haze(host: Node, p: Vector3, w: float, h: float, life: float, parent: Node3D = null) -> MeshInstance3D:
	var mi = gi(_quad(), haze_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	if parent and is_instance_valid(parent):
		parent.add_child(mi)
		mi.position = p
	else:
		put(host, mi, p)
	mi.scale = Vector3(minf(w, 7.0), minf(h, 8.0), 1.0)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, minf(0.3, life * 0.25))
	tw.tween_interval(maxf(0.0, life * 0.5))
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.25)
	tw.tween_callback(mi.queue_free)
	return mi


static func light(host: Node, p: Vector3, c: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


static func _dot_tex() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 32
	tx.height = 32
	_cache["dot"] = tx
	return tx


static func _mote_mat(add: bool) -> StandardMaterial3D:
	var key = "mote_add" if add else "mote_mix"
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = _dot_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Isı zerreleri: küçük akkor noktalar yükselip söner. o: dir, spread, vmin, vmax, g, life, size, burst, pal, emit (sürekli sn)
static func motes(host: Node, p: Vector3, n: int, r: float, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 1.0))
	var pal = float(o.get("pal", 0.0))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 50.0))
	pm.initial_velocity_min = float(o.get("vmin", 0.6))
	pm.initial_velocity_max = float(o.get("vmax", 2.0))
	pm.gravity = o.get("g", Vector3(0, 1.0, 0))
	pm.damping_min = 1.0
	pm.damping_max = 1.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, r)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var c2 = col(pal, 2)
	g.colors = PackedColorArray([col(pal, 0), col(pal, 1), Color(c2.r, c2.g, c2.b, 0.0)])
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, n)
	gpp.lifetime = life
	var emit = float(o.get("emit", 0.0))
	gpp.one_shot = emit <= 0.0
	gpp.explosiveness = float(o.get("burst", 0.6 if emit <= 0.0 else 0.0))
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.08))
	q.material = _mote_mat(true)
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var par: Node3D = o.get("parent", null)
	if par and is_instance_valid(par):
		par.add_child(gpp)
		gpp.position = p
	else:
		put(host, gpp, p)
	gpp.emitting = true
	if emit > 0.0:
		var w = weakref(gpp)
		host.get_tree().create_timer(emit).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.emitting = false)
	kill(host, maxf(emit, 0.0) + life + 0.5, gpp)
	return gpp


## Hazırlık: ısı zerreleri sarmal çizerek bir noktaya akar (avuçta küre toplanır)
static func gather(host: Node, to: Vector3, t: float, n := 10, r := 1.3, pal := 0.0) -> void:
	for k in n:
		var a0 = k * TAU / n + randf() * 0.3
		var y0 = randf_range(-0.5, 0.7)
		var mi = halo_mi(col(pal, 1), 0.35)
		put(host, mi, to + Vector3(cos(a0) * r, y0, sin(a0) * r))
		var dly = randf() * t * 0.3
		var tw = mi.create_tween()
		tw.tween_interval(dly)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(mi):
				return
			var a = a0 + u * 4.0
			var rr = r * (1.0 - u)
			mi.global_position = to + Vector3(cos(a) * rr, y0 * (1.0 - u), sin(a) * rr)
			mi.scale = Vector3.ONE * (0.35 + 0.25 * u), 0.0, 1.0, maxf(0.05, t - dly)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


# ================================================================== yapı taşları: şerit (kuyruk, yay, ışın)
## Kameraya dönük şerit mesh'i (nokta dizisi; widths her noktanın yarı eni)
static func strip(host: Node, pts: PackedVector3Array, widths: PackedFloat32Array) -> ArrayMesh:
	var n = pts.size()
	var am = ArrayMesh.new()
	if n < 2:
		return am
	var cam: Camera3D = host.get_viewport().get_camera_3d() if host.is_inside_tree() else null
	var cp = cam.global_position if cam else pts[0] + Vector3(0, 3, 6)
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var idx = PackedInt32Array()
	for i in n:
		var tv = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tv.length() < 0.0001:
			tv = Vector3.FORWARD
		var tc = cp - pts[i]
		var s = tv.cross(tc)
		if s.length() < 0.0001:
			s = tv.cross(Vector3.UP)
		s = s.normalized() * (widths[i] if i < widths.size() else 0.1)
		var u = float(i) / (n - 1)
		verts.append(pts[i] - s)
		uvs.append(Vector2(u, 0.0))
		verts.append(pts[i] + s)
		uvs.append(Vector2(u, 1.0))
	for i in n - 1:
		var a = i * 2
		for q in [a, a + 1, a + 3, a, a + 3, a + 2]:
			idx.append(q)
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func band_mi(pal := 0.0, heat := 1.0, near := 3.0) -> MeshInstance3D:
	var mi = gi(null, tail_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("tail", 1.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", near)
	return mi


## İribaş kuyruğu: node'un geçtiği yolu izleyen, incelen akkor şerit. node silinince kuyruk toplanıp söner.
## curl: kuyruğun yana kıvrılması (anime: küreler gerisinde dışa-geriye kıvrılan kuyruk)
static func tail(host: Node, node: Node3D, w: float, n := 10, pal := 0.0, curl := Vector3.ZERO) -> MeshInstance3D:
	var mi = band_mi(pal, 1.05, near_of(w))
	put(host, mi, Vector3.ZERO)
	var hist: Array = []
	var st = {"t": 0.0}
	var tw = Game.safe_loops(mi.create_tween())
	tw.tween_interval(1.0 / 60.0)
	tw.tween_callback(func():
		if not is_instance_valid(mi):
			return
		st["t"] += 1.0 / 60.0
		if is_instance_valid(node) and node.is_inside_tree():
			hist.push_front(node.global_position)
			if hist.size() > n:
				hist.pop_back()
		elif hist.size() > 0:
			hist.pop_back()
		if hist.size() < 2:
			if not (is_instance_valid(node) and node.is_inside_tree()):
				mi.queue_free()
			else:
				mi.mesh = null
			return
		var pts = PackedVector3Array()
		var ws = PackedFloat32Array()
		var m = hist.size()
		for i in m:
			var k = float(i) / maxf(1.0, n - 1.0)
			var wob = Vector3(0, sin(st["t"] * 9.0 + i * 0.9) * 0.05 * k, 0)
			pts.append(hist[i] + curl * k * k + wob)
			ws.append(w * (1.0 - k * 0.85))
		mi.mesh = strip(host, pts, ws))
	return mi


## Kısa akkor şerit: nokta dizisi boyunca baş ilerler, kuyruk toplanır (kesik yayı / ısı ışını)
static func sweep(host: Node, pts: PackedVector3Array, w: float, life: float, pal := 0.0, taper := true) -> MeshInstance3D:
	var ws = PackedFloat32Array()
	for i in pts.size():
		var k = float(i) / maxf(1.0, pts.size() - 1.0)
		ws.append(w * (sin(k * PI) * 0.8 + 0.2 if taper else 1.0))
	var mi = band_mi(pal, 1.1, near_of(w * 2.0))
	mi.mesh = strip(host, pts, ws)
	put(host, mi, Vector3.ZERO)
	mi.set_instance_shader_parameter("tail", 0.0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(pf(mi, "tail"), 0.0, 1.0, life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "head"), 0.0, 1.0, life * 0.65).set_delay(life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


# ================================================================== yapı taşları: kurutma
## Tek buhar şeridi: p'den h boyunca yükselen ince dalgalı beyaz kurdele. parent verilirse ona bağlı (kurbanla gezer)
static func wisp(host: Node, p: Vector3, h: float, life: float, w := 0.16, parent: Node3D = null) -> MeshInstance3D:
	var mi = gi(_wisp_quad(), wisp_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("rise", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("amp", 0.12 + h * 0.06)
	mi.set_instance_shader_parameter("near", 2.6)
	if parent and is_instance_valid(parent):
		parent.add_child(mi)
		mi.position = p
	else:
		put(host, mi, p)
	mi.scale = Vector3(w, minf(h, 6.0), w)
	mi.rotation.z = randf_range(-0.15, 0.15)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "rise"), 0.0, 1.75, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)
	return mi


static func _flake_mesh() -> ArrayMesh:
	if _cache.has("flake"):
		return _cache["flake"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = [Vector3(0, 0.5, 0), Vector3(0.42, 0.1, 0), Vector3(0.2, -0.45, 0), Vector3(-0.3, -0.35, 0), Vector3(-0.45, 0.15, 0)]
	for i in pts.size():
		st.set_color(Color(1, 1, 1))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i] * 0.09)
		st.add_vertex(pts[(i + 1) % pts.size()] * 0.09)
	var m = st.commit()
	m.surface_set_material(0, _flake_mat())
	_cache["flake"] = m
	return m


static func _flake_mat() -> StandardMaterial3D:
	if _cache.has("flake_mat"):
		return _cache["flake_mat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["flake_mat"] = m
	return m


## Kuru deri pulları: koyu kahve, dönerek düşen küçük yapraklar. parent'a bağlıysa emit sn boyunca döker
static func flakes(host: Node, p: Vector3, n: int, r: float, emit := 0.0, parent: Node3D = null) -> GPUParticles3D:
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r, r * 2.0, r)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(0.3, 0.22, 0.16, 1.0), Color(0.42, 0.34, 0.26, 0.9), Color(0.5, 0.44, 0.36, 0.0)])
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, n)
	gpp.lifetime = 1.2
	gpp.one_shot = emit <= 0.0
	gpp.explosiveness = 0.5 if emit <= 0.0 else 0.0
	gpp.randomness = 0.5
	gpp.local_coords = false
	gpp.process_material = pm
	gpp.draw_pass_1 = _flake_mesh()
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	if parent and is_instance_valid(parent):
		parent.add_child(gpp)
		gpp.position = p
	else:
		put(host, gpp, p)
	gpp.emitting = true
	if emit > 0.0:
		var w = weakref(gpp)
		host.get_tree().create_timer(emit).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.emitting = false)
	kill(host, emit + 1.8, gpp)
	return gpp


## Kurutma (mumyalaşma): kurbanın teni kararıp kurur, bedeninden ince buhar şeritleri yükselir, kuru pullar dökülür.
## Oyuncunun kendi teninin rengine dokunulmaz (lanet mührü / mod renkleri bozulmasın); yalnız şerit + pul.
static func mummify(host: Node, h: Node3D, dur: float, s := 1.0) -> void:
	if h == null or not is_instance_valid(h):
		return
	var bs = ClanJutsu.body_scale(h)
	var hh = float(h.get("height")) if h.get("height") != null else 1.8
	var m = h.get("model")
	if not (h is Player) and m and is_instance_valid(m) and m.has_method("set_skin_tint"):
		var until = Time.get_ticks_msec() + int(dur * 1000.0)
		h.set_meta("shaku_dry_until", until)
		var k1 = clampf(0.45 + 0.2 * s, 0.4, 0.75)
		var tw = h.create_tween()
		tw.tween_method(func(k: float):
			if is_instance_valid(m):
				m.set_skin_tint(DRY_SKIN, k), 0.0, k1, 0.35)
		tw.tween_interval(maxf(0.1, dur - 0.35))
		tw.tween_callback(func():
			if not is_instance_valid(h) or not is_instance_valid(m):
				return
			if Time.get_ticks_msec() + 30 < int(h.get_meta("shaku_dry_until", 0)):
				return
			var tw2 = h.create_tween()
			tw2.tween_method(func(k: float):
				if is_instance_valid(m):
					m.set_skin_tint(DRY_SKIN, k), k1, 0.0, 1.2))
	# buhar şeritleri: gövdenin farklı yerlerinden, kurbana bağlı (o kaçsa da peşinden tüter)
	var n = maxi(3, int(dur / 0.22))
	var tw3 = h.create_tween()
	for i in n:
		tw3.tween_callback(func():
			if not is_instance_valid(h):
				return
			var q = Vector3(randf_range(-0.25, 0.25), randf_range(0.5, hh * 0.9), randf_range(-0.2, 0.2)) * bs
			wisp(host, q, randf_range(1.2, 2.2) * bs * (0.8 + 0.3 * s), randf_range(0.9, 1.3), randf_range(0.1, 0.16) * bs, h))
		tw3.tween_interval(0.22)
	flakes(host, Vector3.UP * hh * 0.55 * bs, int(10 * s) + 6, 0.25 * bs, dur * 0.8, h)


## Kavurma isabeti (alev / patlama yok): kısa akkor parlama, sıcak hava titremesi, noktadan yükselen buhar şeritleri;
## kurban varsa kurur (mummify)
static func sear(host: Node, at: Vector3, s: float, h: Node3D = null, pal := 0.0) -> void:
	flash(host, at, 2.6 * s, col(pal, 1), 0.3)
	flash(host, at, 1.2 * s, col(pal, 0), 0.15)
	light(host, at, col(pal, 2), 3.0 * s, 7.0 * s, 0.25)
	haze(host, at + Vector3.UP * 0.4 * s, 1.8 * s, 2.4 * s, 0.9)
	for k in int(3 + 2 * s):
		var q = at + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4)) * s
		wisp(host, q, randf_range(1.2, 2.0) * s, randf_range(0.8, 1.1), 0.14 * s)
	motes(host, at, int(8 * s) + 4, 0.3 * s, {"vmin": 1.0, "vmax": 3.5, "spread": 160.0, "life": 0.6, "pal": pal})
	if h != null and is_instance_valid(h) and not h.is_dead():
		mummify(host, h, 2.0, s)


## Kurutulmuş zemin izi: r yarıçap, kısa süre kızıl sıcak, sonra soluk kuru leke; kenarında buhar şeritleri tüter
static func dry_patch(host: Node, p: Vector3, r: float, life: float, wisps := 0) -> MeshInstance3D:
	var mi = gi(_plane(), dry_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("heat", 1.0)
	put(host, mi, floor_at(p) + Vector3.UP * 0.04)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(pf(mi, "heat"), 1.0, 0.0, minf(2.0, life * 0.4))
	tw.tween_interval(maxf(0.0, life * 0.6))
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, minf(1.5, life * 0.3))
	tw.tween_callback(mi.queue_free)
	var c0 = floor_at(p)
	for k in wisps:
		var a = k * TAU / maxf(1.0, wisps) + randf() * 0.4
		var q = c0 + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.75, 0.95)
		var dl = randf() * 0.6
		host.get_tree().create_timer(0.2 + dl).timeout.connect(func():
			wisp(host, q, randf_range(1.0, 1.8), randf_range(1.3, 1.9), 0.18))
	return mi
