class_name FuttonLib
extends RefCounted
## Kaynama doğası malzeme / şekil kütüphanesi (Futton: Mei, Han). Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları:
##   buhar bulutu : kabaran, karnabahar loblu cel bulut — beyaz gövde, alt-yan tarafta gri gölge kademeleri, ince gri kenar;
##                  yaşlandıkça gürültüyle aşınıp dağılır (yumuşak sis lekesi değil). tint ile asit sisi (soluk sarı-yeşil)
##   buhar fışkırması: Han'ın zırh deliklerinden çıkan basınçlı, kenarı testere gibi dişli, içi gri çizgili beyaz buhar dili
##   şok halkası  : yerde ya da dikey açılan kabarık buhar halkası
##   zemin        : haşlanmış ıslak koyu zemin (çatlak açık çizgiler) / asitle aşınmış sarı-yeşil, kabarcıklanan zemin
##   zerre        : yoğuşup düşen su damlaları, asit kabarcıkları, kızgın dip parıltısı
## Hiçbir parça ekranı kaplamaz: buhar parçaları kameraya 6–9 m'den itibaren incelir, boyları sınırlıdır.
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

const STEAM := Color(1.0, 1.0, 1.0)
const ACID := Color(0.9, 0.96, 0.66)      # Kōmu: soluk sarı-yeşil aşındırıcı sis
const ACID_THICK := Color(0.84, 0.93, 0.52)
const R_MAX := 3.0                        # tek bulutun en büyük yarıçapı

static var _cache := {}

# ================================================================== shader parçaları
const FNOISE := """
float fu_h(vec2 p) {
	p = fract(p * vec2(312.47, 189.53));
	p += dot(p, p + 27.19);
	return fract(p.x * p.y);
}

float fu_n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(fu_h(i), fu_h(i + vec2(1.0, 0.0)), f.x);
	float b = mix(fu_h(i + vec2(0.0, 1.0)), fu_h(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float fu_f(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * fu_n(p);
		p = p * 2.03 + vec2(5.1, 2.9);
		a *= 0.5;
	}
	return s;
}
"""

## Buhar bulutu (QuadMesh, merkez orijinde, kameraya dönük). erode 0 dolu → 1 dağıldı.
const STEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float erode = 0.0;
instance uniform vec3 tint = vec3(1.0, 1.0, 1.0);
instance uniform float near = 6.0;
instance uniform float spin = 0.0;

FNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ca = cos(spin + seed);
	float sa = sin(spin + seed);
	vec2 q = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
	float ang = atan(q.y, q.x);
	float lob = 0.7 + 0.11 * sin(ang * 5.0 + seed * 7.0) + 0.07 * sin(ang * 9.0 + seed * 3.0) + (fu_n(vec2(ang * 1.5 + seed, seed * 2.0)) - 0.5) * 0.16;
	float r = length(p) / lob;
	float n = fu_f(q * 2.0 + vec2(seed * 3.0, seed - TIME * 0.3));
	float body = 1.0 - r + (n - 0.5) * 0.3 - erode * (0.55 + n * 0.8);
	if (body < 0.0) {
		discard;
	}
	float sub = fu_n(q * 3.2 + vec2(seed * 5.0, 1.3));
	float sh = p.y * 0.75 - p.x * 0.25 + (sub - 0.5) * 0.55 + r * 0.25;
	vec3 col = vec3(0.98, 0.98, 0.99);
	if (sh > 0.3) {
		col = vec3(0.82, 0.84, 0.88);
	}
	if (sh > 0.72) {
		col = vec3(0.67, 0.69, 0.75);
	}
	if (body < 0.06) {
		col = mix(col, vec3(0.6, 0.62, 0.68), 0.6);
	}
	col *= tint;
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * smoothstep(near * 0.45, near, -VERTEX.z) * (body < 0.06 ? 0.8 : 0.96);
}
"""

## Basınçlı buhar dili (QuadMesh, taban orijinde, Y ekseni yön; eksen çevresinde kameraya döner): dipte dar, uca doğru açılır,
## kenarları testere gibi dişli ve akar, içi gri çizgili; ucu yırtık. grow görünen boyu açar.
const JET_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float grow = 1.0;
instance uniform vec3 tint = vec3(1.0, 1.0, 1.0);
instance uniform float near = 6.0;

FNOISE

void vertex() {
	vec3 ax = MODEL_MATRIX[1].xyz;
	float sy = max(length(ax), 0.0001);
	ax /= sy;
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 rt = cross(ax, tocam);
	float rl = length(rt);
	rt = rl > 0.0001 ? rt / rl : vec3(1.0, 0.0, 0.0);
	vec3 fw = cross(rt, ax);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sx, 0.0), vec4(ax * sy, 0.0), vec4(fw * sx, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float y = 1.0 - UV.y;
	if (y > grow) {
		discard;
	}
	float x = UV.x * 2.0 - 1.0;
	float w = 0.16 + 0.84 * pow(y, 0.6);
	float side = x > 0.0 ? 0.37 : 0.0;
	float saw = abs(fract(y * 5.5 + seed + side - TIME * 2.6) - 0.5) * 2.0;
	float jag = w * (0.7 + 0.3 * saw);
	float n = fu_n(vec2(x * 3.0 + seed, y * 6.0 - TIME * 5.0));
	float e = 1.0 - abs(x) / max(jag, 0.01) + (n - 0.5) * 0.22;
	if (e < 0.0) {
		discard;
	}
	if (grow - y < 0.14 * n) {
		discard;
	}
	vec3 col = vec3(0.98, 0.98, 0.99);
	float streak = fu_n(vec2(x * 9.0 + seed * 4.0, y * 1.6 - TIME * 6.0));
	if (streak > 0.66) {
		col = vec3(0.83, 0.85, 0.89);
	}
	if (e < 0.13) {
		col = vec3(0.72, 0.74, 0.8);
	}
	col *= tint;
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * smoothstep(near * 0.45, near, -VERTEX.z) * (1.0 - smoothstep(0.8, 1.0, y)) * (e < 0.13 ? 0.85 : 0.97);
}
"""

## Kabarık buhar halkası (PlaneMesh 2x2; düğümün Y ekseni halkanın normali). ring yarıçapı 0..1, thick kalınlık.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float ring = 0.5;
instance uniform float thick = 0.12;
instance uniform vec3 tint = vec3(1.0, 1.0, 1.0);
instance uniform float near = 6.0;

FNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float n = fu_f(vec2(ang * 3.0 + seed, r * 3.0 - TIME * 1.2));
	float d = (r - ring) / max(thick * (0.65 + 0.7 * n), 0.005);
	if (abs(d) > 1.0) {
		discard;
	}
	vec3 col = vec3(0.98, 0.98, 0.99);
	if (d > 0.25) {
		col = vec3(0.82, 0.84, 0.88);
	}
	if (abs(d) > 0.82) {
		col = vec3(0.68, 0.7, 0.76);
	}
	col *= tint;
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * smoothstep(near * 0.45, near, -VERTEX.z) * 0.95;
}
"""

## Zemin izi (PlaneMesh 2x2). kind 0: haşlanmış ıslak koyu zemin, açık çatlak çizgileri, kenarda ince buhar lekesi.
## kind 1: asitle aşınmış sarı-yeşil leke, içinde açılıp patlayan kabarcık halkaları ve koyu çukurlar.
const STAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float grow = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float kind = 0.0;

FNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rim = grow * (0.78 + 0.22 * fu_f(vec2(ang * 2.0 + seed * 4.0, seed)));
	if (r > rim) {
		discard;
	}
	float k = r / max(rim, 0.001);
	vec2 sp = p * 5.0 + vec2(seed * 2.3, seed * 1.1);
	float n = fu_f(sp * 0.8);
	vec3 col;
	float a;
	if (kind < 0.5) {
		col = mix(vec3(0.17, 0.16, 0.16), vec3(0.26, 0.25, 0.24), smoothstep(0.3, 0.7, n));
		float cr = fu_f(sp * 0.9 + vec2(3.3, seed));
		col = mix(col, vec3(0.62, 0.63, 0.66), (1.0 - smoothstep(0.0, 0.03, abs(cr - 0.5))) * 0.85);
		a = 0.6;
	} else {
		col = mix(vec3(0.5, 0.58, 0.2), vec3(0.32, 0.38, 0.12), smoothstep(0.3, 0.75, n));
		vec2 cell = floor(sp * 1.3);
		vec2 fr = fract(sp * 1.3) - 0.5;
		float rnd = fu_h(cell + seed);
		float ph = fract(TIME * (0.6 + rnd) + rnd * 5.0);
		float rad = 0.08 + ph * 0.3;
		float bub = (1.0 - smoothstep(0.0, 0.035, abs(length(fr) - rad))) * step(0.45, rnd) * (1.0 - ph);
		col = mix(col, vec3(0.86, 0.92, 0.5), bub);
		float pit = step(length(fr - vec2(rnd - 0.5, 0.2) * 0.4), 0.07) * step(rnd, 0.3);
		col = mix(col, vec3(0.16, 0.18, 0.06), pit);
		a = 0.75;
	}
	col = mix(col, col * 0.7, smoothstep(0.82, 0.96, k));
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * a * (1.0 - smoothstep(0.9, 1.0, k));
}
"""

## Kızgın dip parıltısı (kameraya dönük, toplamalı)
const HOT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 hcol = vec3(1.0, 0.6, 0.25);
instance uniform float fade = 1.0;
instance uniform float near = 5.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = hcol;
	ALPHA = pow(max(1.0 - r, 0.0), 2.0) * fade * smoothstep(near * 0.45, near, -VERTEX.z);
}
"""


# ================================================================== malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("FNOISE", FNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func steam_mat() -> ShaderMaterial:
	return _mat("steam", STEAM_SHADER)


static func jet_mat() -> ShaderMaterial:
	return _mat("jet", JET_SHADER)


static func ring_mat() -> ShaderMaterial:
	return _mat("ring", RING_SHADER)


static func stain_mat() -> ShaderMaterial:
	return _mat("stain", STAIN_SHADER)


static func hot_mat() -> ShaderMaterial:
	return _mat("hot", HOT_SHADER)


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _quad_base() -> QuadMesh:
	if not _cache.has("qb"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.center_offset = Vector3(0.0, 0.5, 0.0)
		_cache["qb"] = q
	return _cache["qb"]


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


## Y ekseni a olan dik taban
static func axis_basis(a: Vector3) -> Basis:
	var y = a.normalized()
	if y.length() < 0.5:
		y = Vector3.UP
	var rf = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x = rf.cross(y).normalized()
	var z = x.cross(y)
	return Basis(x, y, z)


## Boya göre kameraya yakınlık sönümü: büyük buhar 6–9 m'den itibaren incelir, küçük parça yakında da görünür
static func near_of(r: float) -> float:
	return clampf(3.0 + r * 2.2, 3.5, 9.0)


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


# ================================================================== yapı taşları: bulut
## Kabaran buhar bulutu: r0 → r1 (yarıçap, R_MAX ile sınırlı), vel yönünde sürüklenip yavaşlar, yükselir, sonunda aşınıp dağılır.
## o: tint (Color), rise (yukarı sürüklenme m), delay, erode_at (dağılmanın başladığı oran), parent
static func puff(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, o := {}) -> MeshInstance3D:
	r1 = minf(r1, R_MAX)
	r0 = minf(r0, r1)
	var mi = gi(_quad(), steam_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("tint", _v3(o.get("tint", STEAM)))
	mi.set_instance_shader_parameter("near", near_of(r1))
	var sp0 = randf() * TAU
	mi.set_instance_shader_parameter("spin", sp0)
	var par: Node3D = o.get("parent", null)
	if par and is_instance_valid(par):
		par.add_child(mi)
		mi.position = p
	else:
		put(host, mi, p)
	mi.scale = Vector3.ONE * maxf(0.02, r0 * 2.0)
	var dl = float(o.get("delay", 0.0))
	if dl > 0.0:
		mi.visible = false
	var rise = float(o.get("rise", 0.6))
	var ea = clampf(float(o.get("erode_at", 0.4)), 0.0, 0.95)
	var end_p = p + vel * life * 0.55 + Vector3.UP * rise
	var tw = mi.create_tween().set_parallel()
	if dl > 0.0:
		tw.tween_callback(func():
			if is_instance_valid(mi):
				mi.visible = true).set_delay(dl)
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, life).set_delay(dl).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", end_p, life).set_delay(dl).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "spin"), sp0, sp0 + randf_range(-0.6, 0.6), life).set_delay(dl)
	tw.tween_method(pf(mi, "erode"), 0.0, 1.0, life * (1.0 - ea)).set_delay(dl + life * ea).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


# ================================================================== yapı taşları: fışkırma
## Basınçlı buhar dili: p'den dir yönünde ln boyunda, w enli; grow ile açılır, kısa durur, incelip söner. parent verilirse ona bağlı
static func jet(host: Node, p: Vector3, dir: Vector3, ln: float, w: float, life: float, o := {}) -> MeshInstance3D:
	var mi = gi(_quad_base(), jet_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("tint", _v3(o.get("tint", STEAM)))
	mi.set_instance_shader_parameter("near", near_of(w))
	var par: Node3D = o.get("parent", null)
	if par and is_instance_valid(par):
		par.add_child(mi)
		mi.position = p
		mi.basis = axis_basis(dir) * Basis.from_scale(Vector3(w, minf(ln, 9.0), w))
	else:
		put(host, mi, p)
		mi.global_basis = axis_basis(dir) * Basis.from_scale(Vector3(w, minf(ln, 9.0), w))
	var dl = float(o.get("delay", 0.0))
	var tw = mi.create_tween()
	if dl > 0.0:
		tw.tween_interval(dl)
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, life * 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.38)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== yapı taşları: halka, zemin, parıltı
## Açılan buhar halkası: r yarıçapa genişler, incelip söner. normal: halkanın düzlem normali (UP = yerde)
static func ring(host: Node, p: Vector3, r: float, life: float, normal := Vector3.UP, o := {}) -> MeshInstance3D:
	var mi = gi(_plane(), ring_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("ring", 0.15)
	mi.set_instance_shader_parameter("thick", float(o.get("thick", 0.14)))
	mi.set_instance_shader_parameter("tint", _v3(o.get("tint", STEAM)))
	mi.set_instance_shader_parameter("near", near_of(r * 0.5))
	put(host, mi, p)
	mi.global_basis = axis_basis(normal) * Basis.from_scale(Vector3(r, 1.0, r))
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(pf(mi, "ring"), 0.15, 0.92, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "thick"), float(o.get("thick", 0.14)), 0.03, life)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Zemin izi: kind 0 haşlanmış ıslak zemin, 1 asitle aşınmış kabarcıklı zemin
static func stain(host: Node, p: Vector3, r: float, life: float, kind := 0.0) -> MeshInstance3D:
	var mi = gi(_plane(), stain_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("kind", kind)
	put(host, mi, floor_at(p) + Vector3.UP * 0.05)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, minf(0.6, life * 0.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life * 0.6))
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, minf(1.5, life * 0.25))
	tw.tween_callback(mi.queue_free)
	return mi


## Kızgın dip parıltısı (püskürme ağzı)
static func hot(host: Node, p: Vector3, s: float, life: float, c := Color(1.0, 0.6, 0.25)) -> MeshInstance3D:
	var mi = gi(_quad(), hot_mat())
	mi.set_instance_shader_parameter("hcol", _v3(c))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", near_of(s * 0.4))
	put(host, mi, p)
	mi.scale = Vector3.ONE * s * 0.4
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
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


# ================================================================== yapı taşları: zerre
static func _dot_tex() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 32
	tx.height = 32
	_cache["dot"] = tx
	return tx


static func _drop_mat() -> StandardMaterial3D:
	if _cache.has("drop_mat"):
		return _cache["drop_mat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["drop_mat"] = m
	return m


static func _grains(host: Node, p: Vector3, n: int, r: float, life: float, g: Gradient, o: Dictionary) -> GPUParticles3D:
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 60.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 4.0))
	pm.gravity = o.get("g", Vector3(0, -9.0, 0))
	pm.damping_min = float(o.get("damp", 0.4))
	pm.damping_max = float(o.get("damp", 0.4))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, r)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, n)
	gpp.lifetime = life
	var emit = float(o.get("emit", 0.0))
	gpp.one_shot = emit <= 0.0
	gpp.explosiveness = float(o.get("burst", 0.8 if emit <= 0.0 else 0.0))
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.07))
	q.material = _drop_mat()
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


## Yoğuşan su damlaları: buhar soğuyup damla damla düşer. o: dir, spread, vmin, vmax, life, size
static func droplets(host: Node, p: Vector3, n: int, r: float, o := {}) -> GPUParticles3D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(0.92, 0.97, 1.0, 0.95), Color(0.75, 0.86, 0.96, 0.85), Color(0.7, 0.82, 0.95, 0.0)])
	return _grains(host, p, n, r, float(o.get("life", 0.9)), g, o)


## Asit kabarcıkları: sarı-yeşil küçük zerreler yükselip söner (aşınan beden / zemin). o: emit, parent
static func fizz(host: Node, p: Vector3, n: int, r: float, o := {}) -> GPUParticles3D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.95, 1.0, 0.6, 0.9), Color(0.75, 0.86, 0.3, 0.8), Color(0.6, 0.7, 0.2, 0.0)])
	var oo = {"dir": Vector3.UP, "spread": 35.0, "vmin": 0.4, "vmax": 1.4, "g": Vector3(0, 0.6, 0), "damp": 1.0, "size": 0.06}
	oo.merge(o, true)
	return _grains(host, p, n, r, float(o.get("life", 0.7)), g, oo)
