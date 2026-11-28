class_name BeastFX
extends RefCounted
## Dev kuyruklu canavarın KENDİ beden eylem efektleri (ortak halka / duman / moloz / patlama YOK; her biri burada sıfırdan).
## Ölçü canavar boyuna göre (h = canavar boyu, metre). Kullananlar: TailedBeast (vahşi / çağrılan / jinchūriki tam dönüşüm),
## BeastRig (ayak tozu, iniş), BeastCloak (pelerin evreleri, tam dönüşüm, kombo).
## Kaynak (anime): kükreme = ağızdan yayılan basınç halkaları, toprak savrulur; kuyruk = yerde yarım ay chakra savuruşu;
## yere vuruş = toprak levhaları kalkar, toz topakları yuvarlanır; dönüşüm = chakra kabarcığı şişip canavar çıkar;
## mühürleme = chakra şeritler halinde mühre akar; lav (Son Gokū) = yapışkan sarı-turuncu akış + koyu kaya kabuğu.

static var _cache := {}
static var _live := 0


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _add(n: Node3D, pos: Vector3) -> bool:
	var t := _tree()
	var sc: Node = t.current_scene if t and t.current_scene else null
	if sc == null:
		n.free()
		return false
	sc.add_child(n)
	n.global_position = pos
	return true


static func _shader(key: String, code: String) -> Shader:
	if not _cache.has(key):
		var sh := Shader.new()
		sh.code = code
		_cache[key] = sh
	return _cache[key]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		_cache["quad"] = q
	return _cache["quad"]


static func _curve(pts: Array) -> CurveTexture:
	var cv := Curve.new()
	for p in pts:
		cv.add_point(Vector2(p[0], p[1]))
	var ct := CurveTexture.new()
	ct.curve = cv
	return ct


# ------------------------------------------------------------------ gölgelendiriciler
## Canavar chakrası halkası: kenarı alev dilli (pelerin kabarcığı gibi tırtıklı), içi boş, dışa açılırken incelir
const _CHAKRA_RING := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float tongue = pow(abs(sin(a * 7.0 + seed + t * 3.0)), 3.0) * 0.12 + 0.04 * sin(a * 19.0 - seed);
	float rad = mix(0.15, 0.82, t);
	float w = mix(0.12, 0.04, t);
	float band = smoothstep(rad - w, rad, r) * (1.0 - smoothstep(rad, rad + w * 0.4 + tongue * (1.0 - t), r));
	float fade = 1.0 - smoothstep(0.5, 1.0, t);
	ALBEDO = mix(col.rgb, vec3(1.0), smoothstep(rad - w * 0.5, rad, r) * 0.5);
	ALPHA = clamp(band * fade * 1.3, 0.0, 1.0);
}
"""

## Canavar chakrası dili (kameraya dönük, dik kart): cel alev — dalgalı damla, üç ton (koyu chakra, chakra, beyaza yakın iç)
const _CHAKRA_TONGUE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 col : source_color = vec4(1.0, 0.4, 0.1, 1.0);
varying float seed;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 rgt = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fw = normalize(cross(rgt, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rgt * sc.x, 0.0), vec4(vec3(0.0, 1.0, 0.0) * sc.y, 0.0), vec4(fw * sc.z, 0.0), MODEL_MATRIX[3]);
	seed = fract(MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.71);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float t = TIME * 3.0 + seed * 20.0;
	float sway = (n2(vec2(p.y * 2.5 - t, seed * 9.0)) - 0.5) * 0.9 * p.y * p.y;
	float w = 0.9 * sqrt(clamp(p.y * 5.0, 0.0, 1.0)) * pow(1.0 - p.y, 0.75) * (0.75 + 0.5 * n2(vec2(p.y * 5.0 - t * 1.3, seed * 5.0)));
	float shape = 1.0 - abs(p.x - sway) / max(w, 0.001);
	if (shape < 0.0 || p.y > 0.98) discard;
	vec3 c = col.rgb * 0.6;
	c = mix(c, col.rgb, step(0.35, shape));
	c = mix(c, mix(col.rgb, vec3(1.0), 0.7), step(0.7, shape) * step(p.y, 0.6));
	ALBEDO = c;
	ALPHA = 0.95;
}
"""

## Kuyruk savuruşu: yere paralel yarım ay; parlak ön kenar açıyla döner, arkası kuyruk izi gibi söner
const _SWEEP := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.4, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float head = t * 1.15;
	float behind = fract(head - a);
	float ring = smoothstep(0.55, 0.72, r) * (1.0 - smoothstep(0.88, 1.0, r));
	float streak = 0.65 + 0.35 * sin(r * 40.0 + behind * 30.0);
	float fade = 1.0 - smoothstep(0.75, 1.0, t);
	ALBEDO = mix(col.rgb, vec3(1.0), (1.0 - smoothstep(0.0, 0.06, behind)) * 0.7) * streak;
	ALPHA = clamp(ring * (1.0 - smoothstep(0.0, 0.45, behind)) * fade * 1.2, 0.0, 1.0);
}
"""

## Altın mühür parlaması: dört kollu yıldız + ince halka (zayıf nokta vuruşu)
const _SEAL_FLASH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float star = max(1.0 - smoothstep(0.0, 0.06, abs(p.x)) , 1.0 - smoothstep(0.0, 0.06, abs(p.y))) * (1.0 - r);
	float ring = 1.0 - smoothstep(0.0, 0.05, abs(r - mix(0.3, 0.9, t)));
	float ctr = 1.0 - smoothstep(0.0, 0.25, r);
	ALBEDO = mix(vec3(1.0, 0.75, 0.25), vec3(1.0, 1.0, 0.9), ctr);
	ALPHA = clamp((star * 1.5 + ring * 0.8 + ctr) * (1.0 - t), 0.0, 1.0);
}
"""

## Zemin izi: toz halkası (yere vuruş / iniş) — kahverengi-bej, tırtıklı dış kenar, içe doğru seyrek
const _DUST_RING := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(0.8, 0.72, 0.6, 1.0);
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 0.08 * sin(a * 11.0 + seed) + 0.05 * sin(a * 27.0 - seed * 1.7);
	float rad = mix(0.2, 0.95, t) + n;
	float band = smoothstep(rad - 0.35, rad, r) * (1.0 - smoothstep(rad, rad + 0.04, r));
	ALBEDO = col.rgb * (0.85 + 0.15 * sin(a * 5.0 + r * 12.0));
	ALPHA = band * (1.0 - smoothstep(0.4, 1.0, t)) * 0.85;
}
"""

## Kırık zemin: ışınsal kahverengi yarıklar (pelerin yere vuruşu)
const _CRACK := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 7.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 7.31 + seed) * 4375.85);
	float ca = (sec + 0.5 + (off - 0.5) * 0.6) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.08 * sin(r * 13.0 + off * 5.0))) * r;
	float line = (1.0 - smoothstep(0.015, 0.06 * (1.2 - r), d)) * (1.0 - smoothstep(mix(0.6, 1.0, off) * 0.85, mix(0.6, 1.0, off), r));
	ALBEDO = vec3(0.12, 0.08, 0.05);
	ALPHA = max(line, (1.0 - smoothstep(0.1, 0.22, r)) * 0.8) * (1.0 - smoothstep(0.7, 1.0, t));
}
"""

## Chakra kabarcığı: kenarı parlak, içi saydam, yüzeyinde akan kabarcık dalgaları (dönüşüm / kayboluş)
const _BUBBLE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 col : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float a = 1.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = 0.5 + 0.5 * sin(wp.y * 0.9 - TIME * 6.0 + sin(wp.x * 0.7) * 2.0);
	ALBEDO = mix(col.rgb, vec3(1.0), pow(f, 4.0) * 0.6);
	ALPHA = clamp((pow(f, 2.2) * 1.2 + wave * 0.15) * a, 0.0, 1.0);
}
"""

## Lav: sarı-turuncu akan yapışkan sıvı, üstünde koyu soğumuş kabuk lekeleri (ateş topu değil)
const _LAVA := """
shader_type spatial;
render_mode cull_back;
uniform float cool = 0.0;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 q = lp * 3.0 + vec3(0.0, -TIME * 0.8, TIME * 0.3);
	float n = n3(q) * 0.6 + n3(q * 2.3) * 0.4;
	float crust = smoothstep(0.5 - cool * 0.4, 0.56 - cool * 0.4, n);
	vec3 hot = mix(vec3(1.0, 0.62, 0.06), vec3(0.85, 0.2, 0.01), n3(q * 1.7));
	vec3 rock = vec3(0.13, 0.07, 0.05);
	ALBEDO = mix(hot, rock, crust);
	EMISSION = hot * (1.0 - crust) * 0.7 * (1.0 - cool);
	ROUGHNESS = mix(0.35, 0.95, crust);
}
"""

## Saiken sümüğü: parlak, açık yeşil-beyaz yapışkan göl; kenarı damla damla
const _GOO := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(0.75, 0.95, 0.85, 1.0);
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.82 + 0.08 * sin(a * 9.0 + seed) + 0.05 * sin(a * 23.0 - seed);
	float m = 1.0 - smoothstep(edge - 0.03, edge, r / clamp(t * 4.0, 0.05, 1.0));
	float shine = pow(0.5 + 0.5 * sin(p.x * 6.0 + p.y * 4.0 + TIME * 1.5), 8.0);
	ALBEDO = mix(col.rgb * 0.7, vec3(1.0), shine * 0.6);
	ROUGHNESS = 0.15;
	SPECULAR = 0.9;
	ALPHA = m * 0.88 * (1.0 - smoothstep(0.85, 1.0, t));
}
"""

## Gyūki mürekkebi: simsiyah yayılan göl, kenarında sıçrama lekeleri
const _INK := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float grow = clamp(t * 5.0, 0.05, 1.0);
	float edge = (0.7 + 0.12 * sin(a * 6.0 + seed) + 0.1 * sin(a * 15.0 + seed * 2.0)) * grow;
	float pool = 1.0 - smoothstep(edge - 0.02, edge, r);
	vec2 c = vec2(cos(seed + floor(a * 2.0) * 1.3), sin(seed + floor(a * 2.0) * 1.3)) * 0.85 * grow;
	float spl = 1.0 - smoothstep(0.05, 0.08, length(p - c));
	ALBEDO = vec3(0.03, 0.02, 0.05);
	ALPHA = max(pool, spl) * 0.95 * (1.0 - smoothstep(0.85, 1.0, t));
}
"""


static func _card(code_key: String, code: String, pos: Vector3, size: float, normal: Vector3, dur: float, params := {}, ease_out := true) -> MeshInstance3D:
	if _live > 80:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	var m := ShaderMaterial.new()
	m.shader = _shader(code_key, code)
	if code.find("uniform float seed") >= 0:
		m.set_shader_parameter("seed", randf() * 100.0)
	for k in params:
		m.set_shader_parameter(k, params[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, pos):
		return null
	_live += 1
	var n := normal.normalized()
	mi.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, n)).scaled(Vector3.ONE * size * 0.5), pos)
	var tw := mi.create_tween()
	var tr := tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur)
	if ease_out:
		tr.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_live -= 1
		mi.queue_free())
	return mi


## Araziye serilen göl (sümük / mürekkep): düz kart eğimli arazide yarısı toprağın altında, yarısı havada kalıyordu
## (Saiken'in sümüğü "yerin altına giriyor"). Izgara köşeleri tek tek arazi yüksekliğine oturur; shader ve süre düz kartla aynı.
static func _pool(code_key: String, code: String, c: Vector3, size: float, dur: float, params := {}) -> MeshInstance3D:
	var mi := _card(code_key, code, c, size, Vector3.UP, dur, params, false)
	if mi == null:
		return null
	var n := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := []
	for iz in n + 1:
		for ix in n + 1:
			var u := float(ix) / n
			var v := float(iz) / n
			var x := c.x + (u - 0.5) * size
			var z := c.z + (v - 0.5) * size
			hs.append(Vector3(x, Game.ground_height(x, z) + 0.22, z))
	for iz in n:
		for ix in n:
			var i0 := iz * (n + 1) + ix
			for k in [i0, i0 + 1, i0 + n + 2, i0, i0 + n + 2, i0 + n + 1]:
				st.set_uv(Vector2(float(k % (n + 1)) / n, float(k / (n + 1)) / n))
				st.set_normal(Vector3.UP)
				st.add_vertex(hs[k] - c)
	mi.mesh = st.commit()
	mi.global_transform = Transform3D(Basis.IDENTITY, c)
	return mi


static func _ground(c: Vector3) -> Vector3:
	return Vector3(c.x, Game.ground_height(c.x, c.z) + 0.45, c.z)


## Parçacık topluluğu: mesh (toz topağı / alev dili / taş / damla), kendi rengi, ölçek eğrisiyle söner
static func _parts(pos: Vector3, mesh: Mesh, n: int, life: float, vmin: float, vmax: float, dir: Vector3, spread: float, grav: Vector3, smin: float, smax: float,
		emit_r: float, align := false, scurve := [[0.0, 0.3], [0.2, 1.0], [1.0, 0.0]], damp := 0.0) -> void:
	if _live > 80 or n <= 0:
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = n
	p.lifetime = life
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.05, emit_r)
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.damping_min = damp
	pm.damping_max = damp * 1.5
	pm.scale_min = smin
	pm.scale_max = smax
	pm.scale_curve = _curve(scurve)
	pm.particle_flag_align_y = align
	if not align:
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -120.0
		pm.angular_velocity_max = 120.0
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-80, -40, -80), Vector3(160, 160, 160))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(p, pos):
		return
	_live += 1
	p.emitting = true
	_tree().create_timer(life + 0.4).timeout.connect(func():
		_live -= 1
		if is_instance_valid(p):
			p.queue_free())


## Toz topağı (toon, yumru)
static func _dust_mesh(col: Color) -> Mesh:
	var k := "dust_%s" % col.to_html()
	if not _cache.has(k):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.8
		m.radial_segments = 8
		m.rings = 4
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 1.0
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.material = mt
		_cache[k] = m
	return _cache[k]


## Alev / chakra dili: dikine incelen koni (hıza hizalı), parlak renk
static func _tongue_mesh(col: Color) -> Mesh:
	var k := "tongue_%s" % col.to_html()
	if not _cache.has(k):
		var m := QuadMesh.new()
		m.size = Vector2(1.4, 2.0)
		m.center_offset = Vector3(0, 0.8, 0)
		var sm := ShaderMaterial.new()
		sm.shader = _shader("chakra_tongue", _CHAKRA_TONGUE)
		sm.set_shader_parameter("col", col)
		m.material = sm
		_cache[k] = m
	return _cache[k]


## Sivri taş (toprak levhası / kaya kıymığı)
static func _rock_mesh(col: Color) -> Mesh:
	var k := "rock_%s" % col.to_html()
	if not _cache.has(k):
		var m := PrismMesh.new()
		m.size = Vector3(1.0, 1.3, 0.7)
		m.left_to_right = 0.35
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 1.0
		m.material = mt
		_cache[k] = m
	return _cache[k]


static func _drop_mesh(col: Color, emit := 0.0, glossy := false) -> Mesh:
	var k := "drop_%s_%.1f_%s" % [col.to_html(), emit, glossy]
	if not _cache.has(k):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 8
		m.rings = 5
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		if emit > 0.0:
			mt.emission_enabled = true
			mt.emission = col
			mt.emission_energy_multiplier = emit
		if glossy:
			mt.roughness = 0.1
			mt.metallic_specular = 0.9
		m.material = mt
		_cache[k] = m
	return _cache[k]


static func _bubble(pos: Vector3, col: Color, r0: float, r1: float, dur: float, a0 := 0.9, a1 := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = _shader("bubble", _BUBBLE)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("a", a0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, pos):
		return
	mi.scale = Vector3.ONE * r0 * 2.0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("a", x), a0, a1, dur)
	tw.chain().tween_callback(mi.queue_free)


static func _light(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	if not _add(l, pos):
		return
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ eylemler
## Zayıf noktaya vuruş: altın mühür yıldızı + kısa ışık
static func weak_hit(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	var m := ShaderMaterial.new()
	m.shader = _shader("seal", _SEAL_FLASH)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, pos):
		return
	mi.scale = Vector3.ONE * 1.6
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, 0.35)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.6, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	_light(pos, Color(1, 0.85, 0.4), 6.0, 10.0, 0.3)


## Dönüşüm: canavar chakrası kabarcığı şişer, patlarken yukarı chakra dilleri fışkırır (anime: pelerinden dev bedene geçiş)
static func erupt(pos: Vector3, h: float, col: Color) -> void:
	_bubble(pos, col, h * 0.08, h * 0.55, 0.55, 1.0, 0.0)
	_parts(pos - Vector3.UP * h * 0.3, _tongue_mesh(col), 46, 1.1, h * 0.25, h * 0.6, Vector3.UP, 35.0, Vector3(0, h * 0.2, 0), h * 0.15, h * 0.3, h * 0.3, true)
	_card("cring", _CHAKRA_RING, _ground(pos), h * 1.4, Vector3.UP, 0.6, {"col": col})
	_light(pos, col, 12.0, h * 2.0, 0.8)


## Kayboluş (çağrı bitti / dönüşüm çözüldü): chakra dilleri yukarı süzülür, kabarcık küçülerek söner
static func vanish(pos: Vector3, h: float, col: Color) -> void:
	_bubble(pos, col, h * 0.5, h * 0.05, 0.7, 0.8, 0.0)
	_parts(pos, _tongue_mesh(col), 36, 1.4, h * 0.1, h * 0.3, Vector3.UP, 50.0, Vector3(0, h * 0.15, 0), h * 0.12, h * 0.25, h * 0.35, true)


## Kuyruk savuruşu: yerde 360° dönen chakra yarım ayı + savrulan toz
static func tail_sweep(pos: Vector3, col: Color, size: float) -> void:
	var g := _ground(pos) + Vector3.UP * size * 0.04
	var mi := _card("sweep", _SWEEP, g, size, Vector3.UP, 0.8, {"col": col.lightened(0.2)}, false)
	if mi:
		mi.rotate_y(randf() * TAU)
	_parts(_ground(pos), _dust_mesh(Color(0.78, 0.7, 0.58)), 22, 1.2, size * 0.15, size * 0.35, Vector3.UP, 85.0, Vector3(0, -6, 0), size * 0.06, size * 0.12, size * 0.4)


## Kükreme: ağızdan namlu yönünde art arda chakra basınç halkaları + önündeki zeminden savrulan toz
static func roar(mouth: Vector3, col: Color, size: float, dir: Vector3) -> void:
	var t := _tree()
	if t == null:
		return
	for k in 4:
		t.create_timer(k * 0.09).timeout.connect(func():
			_card("cring", _CHAKRA_RING, mouth + dir * size * 0.18 * k, size * (0.5 + k * 0.25), dir, 0.55, {"col": col.lightened(0.15 * (k % 2))}))
	var g := _ground(mouth + dir * size * 0.4)
	_parts(g, _dust_mesh(Color(0.8, 0.72, 0.6)), 26, 1.2, size * 0.2, size * 0.45, (dir * Vector3(1, 0, 1)).normalized() + Vector3.UP * 0.3, 40.0, Vector3(0, -4, 0), size * 0.06, size * 0.13, size * 0.3)


## Yere vuruş (pençe / sıçrayış sonu): toprak levhaları halka halinde kalkar, toz topakları yuvarlanır, toz halkası
static func stomp(c: Vector3, r: float) -> void:
	var g := _ground(c)
	_parts(g, _rock_mesh(Color(0.42, 0.34, 0.26)), 18, 1.2, r * 0.5, r * 0.9, Vector3.UP, 30.0, Vector3(0, -30, 0), r * 0.14, r * 0.28, r * 0.35, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	_parts(g, _dust_mesh(Color(0.8, 0.72, 0.6)), 34, 1.6, r * 0.3, r * 0.7, Vector3.UP, 85.0, Vector3(0, -3, 0), r * 0.2, r * 0.4, r * 0.3, false, [[0.0, 0.3], [0.25, 1.0], [1.0, 0.0]], 2.0)
	_card("dring", _DUST_RING, g, r * 3.2, Vector3.UP, 0.9, {"col": Color(0.8, 0.72, 0.6)})


## Ayak basışı: birkaç toz topağı (uzakta hiç)
static func foot_dust(w: Vector3, H: float, k: float) -> void:
	_parts(w + Vector3.UP * H * 0.02, _dust_mesh(Color(0.8, 0.72, 0.6)), int(8 * k), 1.0, 2.0, 5.0 * k, Vector3.UP, 80.0, Vector3(0, -2, 0), H * 0.05 * k, H * 0.1 * k, H * 0.05, false, [[0.0, 0.3], [0.25, 1.0], [1.0, 0.0]], 1.5)


## İniş: geniş toz halkası + topaklar
static func land(w: Vector3, H: float) -> void:
	_parts(w + Vector3.UP * H * 0.03, _dust_mesh(Color(0.8, 0.72, 0.6)), 40, 1.4, 4.0, 12.0, Vector3.UP, 85.0, Vector3(0, -3, 0), H * 0.1, H * 0.18, H * 0.25, false, [[0.0, 0.3], [0.25, 1.0], [1.0, 0.0]], 2.0)
	_card("dring", _DUST_RING, _ground(w), H * 1.4, Vector3.UP, 0.8, {"col": Color(0.85, 0.78, 0.65)})


## Son Gokū lav topu (görsel düğüm): akan lav küresi, üstünde kabuk, ardında damlayan lav
class _Drip extends Node3D:
	var r := 1.0
	var acc := 0.0
	var life := 5.0
	func _process(d: float) -> void:
		life -= d
		if life <= 0.0:
			queue_free()
			return
		acc += d
		if acc < 0.09:
			return
		acc = 0.0
		var dr := MeshInstance3D.new()
		dr.mesh = BeastFX._drop_mesh(Color(1.0, 0.45, 0.05), 3.0)
		dr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc := get_tree().current_scene
		if sc == null:
			return
		sc.add_child(dr)
		dr.global_position = global_position + Vector3(randf_range(-1, 1), -0.5, randf_range(-1, 1)) * r * 0.4
		dr.scale = Vector3.ONE * r * randf_range(0.18, 0.3)
		var tw := dr.create_tween().set_parallel(true)
		tw.tween_property(dr, "global_position", dr.global_position + Vector3.DOWN * r * 2.5, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_property(dr, "scale", Vector3(0.02, 0.06, 0.02) * r, 0.6)
		tw.chain().tween_callback(dr.queue_free)


static func lava_ball(d: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = _shader("lava", _LAVA)
	mi.material_override = m
	mi.scale = Vector3(1.0, 0.9, 1.1) * d
	root.add_child(mi)
	var dr := _Drip.new()
	dr.r = d
	root.add_child(dr)
	return root


## Lav çarpması: yapışkan lav topakları sıçrar, koyu kaya parçaları, yerde soğuyan lav gölü
static func lava_hit(pos: Vector3, r: float) -> void:
	_parts(pos, _drop_mesh(Color(1.0, 0.5, 0.06), 3.5), 22, 1.1, r * 3.0, r * 7.0, Vector3.UP, 70.0, Vector3(0, -28, 0), r * 0.25, r * 0.5, r * 0.4, false, [[0.0, 1.0], [0.8, 0.9], [1.0, 0.0]])
	_parts(pos, _rock_mesh(Color(0.16, 0.09, 0.06)), 10, 1.2, r * 3.0, r * 6.0, Vector3.UP, 60.0, Vector3(0, -28, 0), r * 0.15, r * 0.3, r * 0.4, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	var g := _ground(pos)
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.55
	cm.height = 0.08
	pool.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = _shader("lava", _LAVA)
	pool.material_override = m
	if not _add(pool, g):
		return
	pool.scale = Vector3(r * 0.5, 1.0, r * 0.5)
	pool.rotate_y(randf() * TAU)
	var tw := pool.create_tween()
	tw.tween_property(pool, "scale", Vector3(r * 3.2, 1.0, r * 2.8), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("cool", x), 0.0, 1.0, 4.0)
	tw.tween_property(pool, "scale", Vector3(r * 3.0, 0.01, r * 2.6), 1.5)
	tw.tween_callback(pool.queue_free)
	_light(pos, Color(1.0, 0.5, 0.1), 8.0, r * 8.0, 0.8)


## Canavar mermisi (görsel düğüm): doğasına göre — kum-hava küresi, mavi alev topu, su kütlesi
static func shot_ball(d: float, col: Color, el: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = _shader("bubble", _BUBBLE)
	m.set_shader_parameter("col", Color(0.95, 0.88, 0.7) if el == "fuuton" else col)
	m.set_shader_parameter("a", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * d
	root.add_child(mi)
	var core := MeshInstance3D.new()
	core.mesh = _drop_mesh(col.lightened(0.5), 2.5, el == "suiton")
	core.scale = Vector3(0.55, 0.55, 0.75) * d
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	return root


## Canavar mermisi çarpması — doğasına göre kendi görünüşü
static func shot_hit(pos: Vector3, r: float, col: Color, el: String) -> void:
	r *= 2.5   # canavar mermisi dev: çarpma izi gövde boyuna göre
	match el:
		"fuuton":   # Shukaku hava mermisi: sıkışmış havanın açılan halkaları + savrulan kum taneleri
			var cam := _tree().root.get_viewport().get_camera_3d()
			var nv := (cam.global_position - pos).normalized() if cam else Vector3.UP
			for k in 2:
				_card("cring", _CHAKRA_RING, pos, r * (4.0 + k * 2.5), nv, 0.35 + k * 0.15, {"col": Color(1.0, 1.0, 1.0)})
			_parts(pos, _dust_mesh(Color(0.62, 0.5, 0.3)), 30, 0.9, r * 6.0, r * 12.0, Vector3.UP, 90.0, Vector3(0, -18, 0), r * 0.08, r * 0.18, r * 0.3)
		"katon":   # Matatabi mavi kedi alevi: mavi alev dilleri dört yana fışkırır
			_parts(pos, _tongue_mesh(col), 30, 0.7, r * 4.0, r * 9.0, Vector3.UP, 80.0, Vector3(0, r * 4.0, 0), r * 0.6, r * 1.2, r * 0.4, true)
			_light(pos, col, 8.0, r * 8.0, 0.5)
		"suiton":   # Isobu su kütlesi: çarpınca su tacı yükselir, damlalar düşer
			_parts(pos, _drop_mesh(Color(0.55, 0.78, 1.0), 0.0, true), 40, 1.1, r * 5.0, r * 9.0, Vector3.UP, 30.0, Vector3(0, -30, 0), r * 0.12, r * 0.25, r * 0.8, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])
			_card("dring", _DUST_RING, _ground(pos), r * 6.0, Vector3.UP, 0.7, {"col": Color(0.6, 0.8, 1.0)})
		_:
			_bubble(pos, col, r * 0.4, r * 2.2, 0.35, 1.0, 0.0)
			_parts(pos, _tongue_mesh(col), 20, 0.6, r * 3.0, r * 7.0, Vector3.UP, 90.0, Vector3.ZERO, r * 0.2, r * 0.4, r * 0.3, true)


## Hasar alanı görünüşü (dur sn): "saiken" sümük gölü + kabarcıklar, "chomei" parlayan pul tozu, "gyuki" mürekkep gölü
static func field(c: Vector3, r: float, col: Color, dur: float, kind: String) -> void:
	var g := _ground(c)
	match kind:
		"saiken":
			_pool("goo", _GOO, g, r * 2.0, dur, {"col": col})
			var t := _tree()
			for k in int(dur / 0.8):
				t.create_timer(k * 0.8).timeout.connect(func():
					_parts(g + Vector3.UP * 0.2, _drop_mesh(col, 0.0, true), 6, 1.2, 1.0, 2.5, Vector3.UP, 20.0, Vector3(0, 1.0, 0), r * 0.1, r * 0.2, r * 0.6, false, [[0.0, 0.2], [0.7, 1.0], [1.0, 0.0]]))
		"chomei":
			var t2 := _tree()
			for k in int(dur / 0.6):
				t2.create_timer(k * 0.6).timeout.connect(func():
					_parts(g + Vector3.UP * r * 0.4, _drop_mesh(col, 4.0), 40, 1.6, 0.3, 1.5, Vector3.UP, 180.0, Vector3(0, -0.4, 0), 0.5, 1.2, r * 0.9, false, [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]], 0.5))
		_:
			_pool("ink", _INK, g, r * 2.0, dur)
			_parts(g + Vector3.UP * 0.5, _drop_mesh(Color(0.03, 0.02, 0.05)), 20, 1.0, r * 0.6, r * 1.2, Vector3.UP, 60.0, Vector3(0, -20, 0), r * 0.05, r * 0.1, r * 0.4)


## Kokuō buharı: boynuz hücumunun ardından yükselen beyaz buhar dilleri
static func steam(pos: Vector3, h: float) -> void:
	_parts(pos, _tongue_mesh(Color(0.9, 0.92, 0.95)), 34, 1.5, h * 0.08, h * 0.2, Vector3.UP, 40.0, Vector3(0, h * 0.06, 0), h * 0.05, h * 0.1, h * 0.25, true)


## Çağrılan küçük yaratık (Chōmei böcekleri vb.) belirişi: küçük chakra kabarcığı
static func minion(p: Vector3, col: Color) -> void:
	_bubble(p, col, 0.2, 1.4, 0.35, 0.9, 0.0)
	_parts(p, _tongue_mesh(col), 10, 0.6, 2.0, 5.0, Vector3.UP, 45.0, Vector3.ZERO, 0.25, 0.45, 0.6, true)


## Mühürleme: canavar chakrası halkalar halinde daralır, şeritler mühre doğru akar
static func sealed(pos: Vector3, h: float, col: Color, tgt: Vector3) -> void:
	var t := _tree()
	for i in 6:
		t.create_timer(i * 0.25).timeout.connect(func():
			var mi := _card("cring", _CHAKRA_RING, pos, h * (1.2 - i * 0.18), Vector3.UP, 0.45, {"col": col})
			if mi:
				var mt: ShaderMaterial = mi.material_override
				var tw := mi.create_tween()
				tw.tween_method(func(x: float): mt.set_shader_parameter("t", 1.0 - x), 0.0, 0.9, 0.4))
	_parts(pos, _tongue_mesh(col), 120, 1.6, 2.0, 8.0, (tgt - pos).normalized(), 70.0, (tgt - pos).normalized() * 30.0, h * 0.08, h * 0.16, h * 0.4, true)


## Pelerin evresi açılışı / öfke patlaması: yerde alev dilli chakra halkası + yukarı dilleri
static func cloak_pulse(pos: Vector3, col: Color, size: float) -> void:
	_card("cring", _CHAKRA_RING, _ground(pos), size, Vector3.UP, 0.5, {"col": col})
	_parts(_ground(pos), _tongue_mesh(col), int(clampf(size * 1.5, 8, 30)), 0.7, size * 0.2, size * 0.5, Vector3.UP, 30.0, Vector3.ZERO, size * 0.05, size * 0.1, size * 0.3, true)


## Pelerinli dev kombo yere vuruşu: ışınsal yarıklar
static func slam_cracks(c: Vector3, size: float) -> void:
	GroundFX.add(c, "cracked", size * 0.6, 4.0)
	_card("crack", _CRACK, _ground(c) + Vector3.UP * 0.05, size, Vector3.UP, 4.0, {}, false)


## Canavar pençesinin çarpması: chakra renginde kısa basınç halkası (kameraya dönük) + toz topakları
static func paw_hit(pt: Vector3, col: Color, s: float) -> void:
	var cam := _tree().root.get_viewport().get_camera_3d()
	_card("cring", _CHAKRA_RING, pt, 4.0 * s, (cam.global_position - pt).normalized() if cam else Vector3.UP, 0.25, {"col": col})
	_parts(pt, _dust_mesh(Color(0.78, 0.7, 0.58)), 8, 0.8, 3.0 * s, 7.0 * s, Vector3.UP, 70.0, Vector3(0, -10, 0), 0.4 * s, 0.8 * s, 0.6 * s, false, [[0.0, 0.3], [0.25, 1.0], [1.0, 0.0]], 1.5)
