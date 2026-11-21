class_name FinalFX3
extends RefCounted
## Son karışık grup 3: taijutsu kombolari (Tarenken, Tarenkyaku, Naruto Ittai Rendan, Sōtenkyaku), çağrı hayvanı darbeleri
## (Makitsuki, Ai no Muchi, Kagenade), Yamanaka zihin teknikleri (Shindenshin, Shindenshōsen, Chakura Kami Torappu,
## Shinten Bunshin), Ino–Shika–Chō düzeni, Uchiha Ryū Kenjutsu, Shiranui Tenketsu Bari ve Hokage Muhafız Hiraijin'i.
## Görünen her şey bu dosyanın kendi gölgelendiricileri ve şekilleriyle sıfırdan üretilir (çarpma karesi, hız çizgisi, cel toz,
## çatlak, ruh izi, zihin ipi, armalar, mühür formülü, yılan, kurbağa, kabuk topu...). Ortak efekt kütüphanesi kullanılmaz.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, gerçek zihin / klon / ışınlanma sistemleri) ana ağaçtaki işleyicilerden
## satır satır taşındı. Kameraya yakın parçalar gölgelendiricide yumuşakça söner (büyük levhalar 6–9 m), ekranı kaplamaz.

static var _c := {}

const NEAR_S := Vector2(0.7, 2.2)
const NEAR_M := Vector2(2.2, 4.8)
const NEAR_L := Vector2(6.0, 9.0)

const INK := Color(0.07, 0.05, 0.08, 1.0)
const DUST_C := Color(0.8, 0.72, 0.6, 0.9)
const ROCK_C := Color(0.47, 0.4, 0.32)
const KURAMA := Color(1.0, 0.6, 0.15)
const KURAMA_Y := Color(1.0, 0.9, 0.45)
const GOLD := Color(1.0, 0.86, 0.3)
const MIND := Color(0.82, 0.62, 1.0)
const SOUL := Color(0.75, 0.92, 1.0)
const HEAL_G := Color(0.45, 1.0, 0.55)
const STEEL_C := Color(0.8, 0.83, 0.88)
const TCH := Color(0.55, 0.8, 1.0)
const CUT_BLUE := Color(0.7, 0.85, 1.0)


# ================================================================== gölgelendiriciler (kendi)
## Levha: tek düzlemde yordamsal çizim. mode: 0 şok halkası, 1 krater, 2 Hiraishin formülü, 3 Yamanaka arması, 4 Nara arması,
## 5 Akimichi arması, 6 şifa alanı, 7 Yamanaka elmas mührü, 8 çarpma yıldızı, 9 tenketsu noktası, 10 gölge havuzu
const SHEET_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float mode = 0.0;
instance uniform float prog = 1.0;
instance uniform float width = 0.12;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 tint2 : source_color = vec4(0.07, 0.05, 0.08, 1.0);
instance uniform vec2 nearz = vec2(2.2, 4.8);

float sgd(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}

float hsh(float n) {
	return fract(sin(n * 91.345 + 7.13) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	int m = int(mode + 0.5);
	if (m == 2) {
		float cs = cos(TIME * 0.5 + seed);
		float sn = sin(TIME * 0.5 + seed);
		q = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	}
	vec2 p = vec2(q.x, -q.y);
	float r = length(q);
	float ang = atan(q.y, q.x);
	float a01 = ang / 6.2831853 + 0.5;
	vec3 col = tint.rgb;
	float al = 0.0;
	if (m == 0) {
		float e = prog * (1.0 + 0.07 * sin(ang * 9.0 + seed * 3.0) + 0.04 * sin(ang * 23.0 + seed * 5.0));
		float band = step(e - width, r) * step(r, e);
		float lnw = width * 0.22;
		float ln = band * max(step(e - lnw, r), step(r, e - width + lnw));
		col = mix(tint.rgb, tint2.rgb, ln);
		al = band * mix(tint.a, tint2.a, ln);
	} else if (m == 1) {
		float e = prog * (1.0 + 0.12 * sin(ang * 7.0 + seed * 2.0) + 0.06 * sin(ang * 19.0 + seed * 4.0));
		float inside = step(r, e);
		float rimb = step(e - width, r) * inside;
		float ln = step(e - width * 0.2, r) * inside;
		col = mix(tint2.rgb, tint.rgb, rimb);
		col = mix(col, tint2.rgb * 0.6, ln);
		al = inside * mix(tint2.a * 0.8, tint.a, rimb);
	} else if (m == 6) {
		float soft = 1.0 - smoothstep(prog * 0.55, prog, r);
		float wave = 0.5 + 0.5 * sin(r * 16.0 - TIME * 2.5 + seed);
		float edg = 1.0 - smoothstep(0.0, 0.025, abs(r - prog * 0.96));
		col = mix(tint.rgb, tint2.rgb, edg);
		al = max(soft * tint.a * (0.45 + 0.55 * wave * soft), edg * tint2.a);
	} else if (m == 8) {
		float k = fract(a01 * 9.0 + seed);
		float sid = floor(a01 * 9.0 + seed);
		float tri = 1.0 - abs(k * 2.0 - 1.0);
		float f = prog * (0.34 + 0.66 * pow(tri, 2.2) * (0.7 + 0.3 * hsh(sid + seed)));
		float inside = step(r, f);
		float core = step(r, f * 0.55);
		float ln = step(f - 0.06, r) * inside;
		col = mix(tint.rgb, vec3(1.0), core);
		col = mix(col, tint2.rgb, ln);
		al = inside * mix(tint.a, tint2.a, ln);
	} else if (m == 9) {
		float pt = step(r, 0.13);
		float ring = 1.0 - smoothstep(width * 0.5, width, abs(r - prog));
		float ln = step(0.09, r) * pt;
		col = mix(tint.rgb, vec3(1.0), step(r, 0.06));
		col = mix(col, tint2.rgb, ln);
		al = max(pt * tint.a, ring * tint.a * 0.9);
	} else if (m == 10) {
		float e = prog * (1.0 + 0.06 * sin(ang * 7.0 + TIME * 3.0 + seed) + 0.03 * sin(ang * 15.0 - TIME * 4.0));
		float inside = step(r, e);
		col = tint.rgb;
		al = inside * tint.a * (0.75 + 0.25 * (1.0 - smoothstep(e * 0.5, e, r)));
	} else {
		float dd = 10.0;
		if (m == 2) {
			dd = min(abs(r - 0.88), abs(r - 0.36));
			if (r > 0.45 && r < 0.8) {
				float s = a01 * 16.0;
				float sid2 = floor(s);
				vec2 lp = vec2((fract(s) - 0.5) * 1.6, (r - 0.625) / 0.175);
				for (int i = 0; i < 3; i++) {
					float h1 = hsh(sid2 * 3.0 + float(i) + seed);
					float h2 = hsh(sid2 * 5.0 + float(i) * 1.7 + seed);
					vec2 a = vec2(h1 - 0.5, h2 * 2.0 - 1.0) * 0.8;
					vec2 b = a + vec2(cos(h1 * 6.28), sin(h2 * 6.28)) * 0.55;
					dd = min(dd, sgd(lp, a, b) * 0.18);
				}
			}
			for (int i = 0; i < 3; i++) {
				float aa = 1.5708 + float(i) * 2.0944;
				dd = min(dd, sgd(p, vec2(0.0), vec2(cos(aa), sin(aa)) * 0.28));
			}
			if (a01 > prog) {
				dd = 10.0;
			}
		} else if (m == 3) {
			dd = abs(r - 0.86);
			vec2 c0 = vec2(0.0, 0.02);
			if (p.y > 0.02) {
				dd = min(dd, abs(length(p - c0) - 0.5));
			}
			dd = min(dd, sgd(p, vec2(-0.5, 0.02), vec2(0.5, 0.02)));
			dd = min(dd, sgd(p, vec2(0.0, 0.02), vec2(0.0, -0.66)));
			dd = min(dd, sgd(p, vec2(-0.25, 0.02), vec2(-0.25, 0.3)));
			dd = min(dd, sgd(p, vec2(0.25, 0.02), vec2(0.25, 0.3)));
		} else if (m == 4) {
			dd = abs(r - 0.86);
			if (r < 0.74) {
				float s = (p.x + p.y) * 0.7071;
				float g = (p.x - p.y) * 0.7071;
				float k = s * 2.6;
				float row = floor(k + 0.5);
				float ds = abs(k - row) / 2.6;
				float gap = fract(g * 1.4 + row * 0.37);
				if (gap > 0.14) {
					dd = min(dd, ds);
				}
			}
		} else if (m == 5) {
			dd = abs(r - 0.86);
			dd = min(dd, sgd(p, vec2(-0.5, 0.4), vec2(0.5, 0.4)));
			dd = min(dd, sgd(p, vec2(-0.45, 0.4), vec2(0.45, -0.5)));
			dd = min(dd, sgd(p, vec2(0.45, 0.4), vec2(-0.45, -0.5)));
			dd = min(dd, sgd(p, vec2(-0.3, -0.5), vec2(0.3, -0.5)));
		} else if (m == 7) {
			dd = abs(abs(p.x) + abs(p.y) - 0.62) * 0.7071;
			dd = min(dd, max(length(p) - 0.12, 0.0));
		}
		float lines = 1.0 - smoothstep(width * 0.55, width, dd);
		float halo = (1.0 - smoothstep(width, width * 4.5, dd)) * 0.55;
		col = mix(tint2.rgb, tint.rgb, lines);
		al = max(lines * tint.a, halo * tint2.a);
	}
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(al * fade * nf, 0.0, 1.0);
}
"""

## Şerit / çizgi / iz: köşe rengi x tint; istenirse iki kenarda koyu çizgi, istenirse akan bantlar (chakra akışı)
const RIB_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform vec2 nearz = vec2(0.7, 2.2);
instance uniform float flow = 0.0;
instance uniform float edge = 0.0;
instance uniform vec4 edge_col : source_color = vec4(0.07, 0.05, 0.08, 1.0);
void fragment() {
	vec4 c = COLOR * tint;
	float v = abs(UV.y * 2.0 - 1.0);
	float pulse = 1.0;
	if (flow > 0.0) {
		pulse = 0.72 + 0.28 * step(0.55, fract(UV.x * 5.0 - TIME * flow));
	}
	vec3 col = c.rgb * pulse;
	float e = step(1.0 - edge, v) * step(0.001, edge);
	col = mix(col, edge_col.rgb, e);
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(mix(c.a, edge_col.a * c.a, e) * fade * nf, 0.0, 1.0);
}
"""

## Katı cel nesne (yılan, kurbağa, kabuk, yumruk, iğne, moloz): köşe rengi, iki ton + parlak tepe
const TOON_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec2 nearz = vec2(0.7, 2.2);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 base = COLOR.rgb;
	float l = dot(wn, normalize(vec3(0.3, 1.0, 0.35)));
	vec3 col = mix(base * 0.6, base, step(0.05, l));
	col = mix(col, min(base * 1.18 + vec3(0.04), vec3(1.0)), step(0.8, l));
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(fade * nf, 0.0, 1.0);
}
"""

## Ters kabuk kontur (anime koyu kenarı)
const HULL_SH := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec2 nearz = vec2(0.7, 2.2);
uniform float thick = 0.03;
uniform vec4 ink_col : source_color = vec4(0.07, 0.05, 0.08, 1.0);
void vertex() {
	VERTEX += NORMAL * thick;
}
void fragment() {
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = ink_col.rgb;
	ALPHA = clamp(ink_col.a * fade * nf, 0.0, 1.0);
}
"""

## Ruh / hayalet: yarı saydam gövde, koyu kenar kuşağı, içinde yukarı akan dalga (ek kollar, ruh izi, zırh kırıkları)
const SPIRIT_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.7, 0.9, 1.0, 0.5);
instance uniform vec4 rim : source_color = vec4(0.2, 0.35, 0.7, 0.9);
instance uniform float fade = 1.0;
instance uniform vec2 nearz = vec2(0.7, 2.2);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ripple = 0.88 + 0.12 * sin(wp.y * 9.0 + wp.x * 3.0 - TIME * 7.0);
	float body = smoothstep(0.18, 0.4, f);
	vec3 col = mix(rim.rgb, tint.rgb * ripple, body);
	col = mix(col, vec3(1.0), smoothstep(0.82, 1.0, f) * 0.45);
	float a = mix(rim.a, tint.a, body);
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(a * fade * nf, 0.0, 1.0);
}
"""

## Kurama chakra pelerini: dörtgen üzerinde yalazlanan dil biçimi, sarı çekirdek, koyu turuncu kontur
const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform vec2 nearz = vec2(0.7, 2.2);
uniform vec4 core : source_color = vec4(1.0, 0.96, 0.62, 1.0);
uniform vec4 body : source_color = vec4(1.0, 0.62, 0.15, 1.0);
uniform vec4 ink_c : source_color = vec4(0.62, 0.2, 0.02, 1.0);
void vertex() {
	float h = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 8.0 + seed + VERTEX.y * 4.0) * 0.06 * h;
}
void fragment() {
	float h = 1.0 - UV.y;
	float x = abs(UV.x * 2.0 - 1.0);
	float lick = 0.5 + 0.5 * sin(UV.x * 9.0 + seed * 2.0 + TIME * 6.0);
	float top = 0.68 + 0.32 * lick;
	float hn = h / top;
	if (hn >= 1.0) {
		discard;
	}
	float w = 1.0 - pow(hn, 1.6);
	if (x > w) {
		discard;
	}
	vec3 col = body.rgb;
	col = mix(col, core.rgb, step(x, w * 0.45) * step(hn, 0.6));
	col = mix(col, ink_c.rgb, step(w - 0.13, x));
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(0.72 * fade * nf, 0.0, 1.0);
}
"""

## Cel toz topağı: dünya normaline göre iki ton, kenarda koyu kuşak
const DUST_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.8, 0.72, 0.6, 0.9);
instance uniform float fade = 1.0;
instance uniform vec2 nearz = vec2(2.2, 4.8);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float l = dot(wn, normalize(vec3(0.25, 1.0, 0.3)));
	vec3 col = mix(tint.rgb * 0.72, tint.rgb, step(0.1, l));
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, tint.rgb * 0.4, step(f, 0.22));
	float nf = smoothstep(nearz.x, nearz.y, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(tint.a * fade * nf, 0.0, 1.0);
}
"""


# ================================================================== altyapı
static func _sm(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _c.has(k):
		return _c[k]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_c[k] = m
	return m


static func _toon(thick := 0.03) -> ShaderMaterial:
	var k = "mat:toon_%d" % int(thick * 1000.0)
	if _c.has(k):
		return _c[k]
	var m = _sm("toon_base", TOON_SH).duplicate() as ShaderMaterial
	var o = _sm("hull_base", HULL_SH).duplicate() as ShaderMaterial
	o.set_shader_parameter("thick", thick)
	m.next_pass = o
	_c[k] = m
	return m


static func _plane() -> PlaneMesh:
	var k = "mesh:plane"
	if not _c.has(k):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		_c[k] = p
	return _c[k]


static func _quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _c.has(k):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_c[k] = q
	return _c[k]


static func _lump() -> SphereMesh:
	var k = "mesh:lump"
	if not _c.has(k):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		_c[k] = s
	return _c[k]


static func _shard_mesh() -> PrismMesh:
	var k = "mesh:shard"
	if not _c.has(k):
		var s = PrismMesh.new()
		s.size = Vector3(1, 1, 1)
		_c[k] = s
	return _c[k]


static func _chip(i: int) -> ArrayMesh:
	var k = "mesh:chip_%d" % i
	if not _c.has(k):
		var b = MB.new()
		var cols = [ROCK_C, ROCK_C.lightened(0.15), ROCK_C.darkened(0.2)]
		b.add("boulder", Vector3.ZERO, Vector3.ONE, cols[i % 3], Vector3.ZERO, 3 + i)
		_c[k] = b.build(null)
	return _c[k]


static func _stv(st: SurfaceTool, p: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(uv)
	st.add_vertex(p)


## İğ çizgi: z=0 opak sivri baş, z=0.28 en geniş, z=1 sönük kuyruk (XZ düzleminde yassı)
static func _spike() -> ArrayMesh:
	var k = "mesh:spike"
	if _c.has(k):
		return _c[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w1 = Color(1, 1, 1, 1)
	var w0 = Color(1, 1, 1, 0)
	var tip = Vector3.ZERO
	var l = Vector3(-0.5, 0, 0.28)
	var r = Vector3(0.5, 0, 0.28)
	var tail = Vector3(0, 0, 1)
	_stv(st, tip, Vector2(0.0, 0.5), w1)
	_stv(st, l, Vector2(0.28, 0.0), w1)
	_stv(st, r, Vector2(0.28, 1.0), w1)
	_stv(st, l, Vector2(0.28, 0.0), w1)
	_stv(st, tail, Vector2(1.0, 0.5), w0)
	_stv(st, r, Vector2(0.28, 1.0), w1)
	_c[k] = st.commit()
	return _c[k]


static func _spawn(pj: PathJutsu, mesh: Mesh, mat: Material, p: Vector3, near := NEAR_S, parent: Node = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
		mi.position = p
	else:
		pj.get_tree().current_scene.add_child(mi)
		mi.global_position = p
	mi.set_instance_shader_parameter("nearz", near)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	var w = weakref(mi)
	return func(v: float) -> void:
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.set_instance_shader_parameter(pname, v)


static func _set_tree(n: Node, pname: String, v: float) -> void:
	if not is_instance_valid(n):
		return
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter(pname, v)
	for ch in n.get_children():
		_set_tree(ch, pname, v)


static func _fade_free(n: GeometryInstance3D, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_pf(n, "fade"), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


static func _fade_tree(root: Node3D, delay: float, dur: float) -> void:
	if not is_instance_valid(root):
		return
	var tw = root.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: _set_tree(root, "fade", v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(root.queue_free)


static func _cam(pj: PathJutsu) -> Vector3:
	var vp = pj.get_viewport()
	if vp:
		var cam = vp.get_camera_3d()
		if cam:
			return cam.global_position
	return Vector3(0, 50, 50)


static func _cam_dir(pj: PathJutsu, p: Vector3) -> Vector3:
	var d = _cam(pj) - p
	if d.length() < 0.01:
		return Vector3.UP
	return d.normalized()


static func _perp(v: Vector3) -> Vector3:
	var n = v.normalized()
	var a = Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	return n.cross(a).normalized()


## Yerel +Y → n
static func _basis_y(n: Vector3) -> Basis:
	var y = n.normalized()
	if y.length() < 0.01:
		y = Vector3.UP
	var x = _perp(y)
	var z = x.cross(y)
	return Basis(x, y, z)


## Yerel +Y → n (kameraya), yerel -Z → dünya yukarısı (armalar dik durur)
static func _upright(n: Vector3) -> Basis:
	var y = n.normalized()
	if y.length() < 0.01:
		y = Vector3.BACK
	var z = Vector3.DOWN - y * Vector3.DOWN.dot(y)
	if z.length() < 0.01:
		z = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	z = z.normalized()
	var x = y.cross(z)
	return Basis(x, y, z)


## Yerel +Z → zdir, yassı yüz kameraya
static func _view_basis(zdir: Vector3, to_cam: Vector3) -> Basis:
	var z = zdir.normalized()
	if z.length() < 0.01:
		z = Vector3.FORWARD
	var x = to_cam.cross(z)
	if x.length() < 0.001:
		x = _perp(z)
	x = x.normalized()
	var y = z.cross(x)
	return Basis(x, y, z)


static func _cone(axis: Vector3, deg: float) -> Vector3:
	var a = axis.normalized()
	var u = _perp(a)
	var v = a.cross(u)
	var th = deg_to_rad(randf() * deg)
	var ph = randf() * TAU
	return (a * cos(th) + (u * cos(ph) + v * sin(ph)) * sin(th)).normalized()


static func _fill(n: int, v) -> Array:
	var out = []
	for i in n:
		out.append(v)
	return out


static func _hgt(n: Node3D) -> float:
	if n == null or not is_instance_valid(n):
		return 1.8
	var h = n.get("height")
	return float(h) if h != null else 1.8


static func _rad(n: Node3D) -> float:
	if n == null or not is_instance_valid(n):
		return 0.4
	var r = n.get("radius")
	return float(r) if r != null else 0.4


# ------------------------------------------------------------------ levhalar
static func _sheet_cfg(mi: MeshInstance3D, mode: int, col: Color, col2: Color, width: float) -> void:
	mi.set_instance_shader_parameter("mode", float(mode))
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("tint2", col2)
	mi.set_instance_shader_parameter("width", width)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("prog", 1.0)


static func _face_sheet(pj: PathJutsu, p: Vector3, size: float, mode: int, col: Color, col2: Color, near := NEAR_M, width := 0.06) -> MeshInstance3D:
	var mi = _spawn(pj, _plane(), _sm("sheet", SHEET_SH), p, near)
	mi.global_basis = _upright(_cam_dir(pj, p))
	mi.scale = Vector3(size, 1.0, size)
	_sheet_cfg(mi, mode, col, col2, width)
	return mi


static func _flat_sheet(pj: PathJutsu, p: Vector3, normal: Vector3, size: float, mode: int, col: Color, col2: Color, near := NEAR_M, width := 0.12) -> MeshInstance3D:
	var mi = _spawn(pj, _plane(), _sm("sheet", SHEET_SH), p, near)
	mi.global_basis = _basis_y(normal)
	mi.scale = Vector3(size, 1.0, size)
	_sheet_cfg(mi, mode, col, col2, width)
	return mi


## prog p0→p1 (grow sn, gecikmeli), bekle, sön, sil
static func _anim_sheet(mi: MeshInstance3D, p0: float, p1: float, grow: float, hold: float, out: float, delay := 0.0) -> void:
	mi.set_instance_shader_parameter("prog", p0)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_pf(mi, "prog"), p0, p1, maxf(grow, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, maxf(out, 0.01))
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ şeritler (ImmediateMesh)
static func _ribbon(pj: PathJutsu, near := NEAR_M) -> MeshInstance3D:
	return _spawn(pj, ImmediateMesh.new(), _sm("rib", RIB_SH), Vector3.ZERO, near)


static func _style_rib(mi: GeometryInstance3D, col: Color, edge := 0.0, edge_col := INK, flow := 0.0) -> void:
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("edge", edge)
	mi.set_instance_shader_parameter("edge_col", edge_col)
	mi.set_instance_shader_parameter("flow", flow)


static func _vx(im: ImmediateMesh, p: Vector3, uv: Vector2, col: Color) -> void:
	im.surface_set_color(col)
	im.surface_set_uv(uv)
	im.surface_add_vertex(p)


## Dünya koordinatında şerit çiz: flat_up verilirse o düzlemde yatar, yoksa kameraya döner
static func _redraw(mi: MeshInstance3D, pts: Array, widths: Array, cols: Array, cam: Vector3, flat_up := Vector3.ZERO) -> void:
	if not is_instance_valid(mi):
		return
	var im = mi.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	var n = pts.size()
	if n < 2 or widths.size() < n or cols.size() < n:
		return
	var sides = []
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var here: Vector3 = pts[i]
		var tn = b - a
		var s = tn.cross(flat_up) if flat_up != Vector3.ZERO else tn.cross(cam - here)
		if s.length() < 0.0001:
			s = Vector3.RIGHT
		sides.append(s.normalized() * float(widths[i]) * 0.5)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var s0: Vector3 = sides[i]
		var s1: Vector3 = sides[i + 1]
		var u0 = float(i) / float(n - 1)
		var u1 = float(i + 1) / float(n - 1)
		var c0: Color = cols[i]
		var c1: Color = cols[i + 1]
		_vx(im, p0 - s0, Vector2(u0, 0.0), c0)
		_vx(im, p0 + s0, Vector2(u0, 1.0), c0)
		_vx(im, p1 + s1, Vector2(u1, 1.0), c1)
		_vx(im, p0 - s0, Vector2(u0, 0.0), c0)
		_vx(im, p1 + s1, Vector2(u1, 1.0), c1)
		_vx(im, p1 - s1, Vector2(u1, 0.0), c1)
	im.surface_end()


## Her karede yeniden çizilen şerit: build(u) -> [noktalar, genişlikler, renkler, flat_up] (boş dizi = bu kare çizme)
static func _live_ribbon(pj: PathJutsu, mi: MeshInstance3D, dur: float, build: Callable, delay := 0.0) -> void:
	var cb = func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var r: Array = build.call(u)
		if r.size() < 4:
			return
		_redraw(mi, r[0], r[1], r[2], _cam(pj), r[3])
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(cb, 0.0, 1.0, maxf(dur, 0.01))
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ yapı taşları
static func _spike_mi(pj: PathJutsu, p: Vector3, zdir: Vector3, w: float, l: float, col: Color, near := NEAR_M) -> MeshInstance3D:
	var mi = _spawn(pj, _spike(), _sm("rib", RIB_SH), p, near)
	mi.global_basis = _view_basis(zdir, _cam(pj) - p)
	mi.scale = Vector3(w, 1.0, maxf(l, 0.01))
	_style_rib(mi, col)
	return mi


## Çarpma karesi çizgileri: merkezden dışa fırlayan iğler (kamera düzleminde ya da bias konisinde)
static func _burst_lines(pj: PathJutsu, p: Vector3, n: int, r0: float, len_: float, life: float, col: Color, w := 0.08, bias := Vector3.ZERO, spread := 180.0) -> void:
	var view = _cam_dir(pj, p)
	var u = _perp(view)
	var v = view.cross(u)
	for i in n:
		var d: Vector3
		if bias != Vector3.ZERO:
			d = _cone(bias, spread)
		else:
			var a = TAU * (float(i) + randf_range(-0.3, 0.3)) / float(n)
			d = u * cos(a) + v * sin(a)
		var L = len_ * randf_range(0.6, 1.0)
		var mi = _spike_mi(pj, p + d * r0, -d, w * randf_range(0.7, 1.3), L * 0.15, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale:z", L, life * 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + d * (r0 + L), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Sıkışma çizgileri: dıştan merkeze kayan iğler (yumruk geri çekiş / sıkma)
static func _pull_in(pj: PathJutsu, p: Vector3, n: int, r: float, life: float, col: Color, w := 0.06) -> void:
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var L = r * randf_range(0.45, 0.75)
		var mi = _spike_mi(pj, p + d * r, d, w, L, col, NEAR_S)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + d * (r * 0.2), life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale:z", L * 0.3, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(mi.queue_free)


## Hız çizgileri: d yönünde ilerleyen bir şeyin arkasında kalan, geriye kayıp sönen iğler
static func _speed_lines(pj: PathJutsu, p: Vector3, d: Vector3, n: int, len_: float, rad: float, life: float, col: Color, w := 0.05) -> void:
	var dd = d.normalized()
	if dd.length() < 0.01:
		return
	var u = _perp(dd)
	var v = dd.cross(u)
	for i in n:
		var a = randf() * TAU
		var rr = rad * (0.35 + 0.65 * sqrt(randf()))
		var off = (u * cos(a) + v * sin(a)) * rr + dd * randf_range(-len_ * 0.3, len_ * 0.3)
		var L = len_ * randf_range(0.5, 1.0)
		var mi = _spike_mi(pj, p + off, -dd, w * randf_range(0.7, 1.2), L * 0.3, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale:z", L, life * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + off - dd * len_ * 0.8, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
		tw.chain().tween_callback(mi.queue_free)


## Yerde çatlak: kırık zikzak kollar + yan dallar; yavaş söner
static func _cracks(pj: PathJutsu, p: Vector3, r: float, arms: int, hold: float, align := Vector3.ZERO) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a0 = randf() * TAU
	if align != Vector3.ZERO:
		a0 = atan2(align.z, align.x)
	for i in arms:
		var a = a0 + TAU * float(i) / float(arms) + randf_range(-0.25, 0.25)
		_crack_path(st, Vector2.ZERO, a, r * randf_range(0.6, 1.0), 0.08 + r * 0.01, 2)
	var mi = _spawn(pj, st.commit(), _sm("rib", RIB_SH), p + Vector3.UP * 0.04, NEAR_M)
	_style_rib(mi, Color(1, 1, 1, 1))
	mi.scale = Vector3(0.12, 1.0, 0.12)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.9)
	tw.tween_callback(mi.queue_free)


static func _crack_path(st: SurfaceTool, s: Vector2, a: float, L: float, w: float, depth: int) -> void:
	var col = Color(0.09, 0.07, 0.06, 0.9)
	var steps = 5
	var p = s
	var ang = a
	for i in steps:
		var k0 = float(i) / steps
		var k1 = float(i + 1) / steps
		ang += randf_range(-0.55, 0.55)
		var q = p + Vector2(cos(ang), sin(ang)) * (L / steps)
		var nrm = Vector2(-sin(ang), cos(ang))
		var w0 = w * (1.0 - k0 * 0.8)
		var w1 = w * (1.0 - k1 * 0.8)
		var A = Vector3(p.x + nrm.x * w0, 0, p.y + nrm.y * w0)
		var B = Vector3(p.x - nrm.x * w0, 0, p.y - nrm.y * w0)
		var C = Vector3(q.x + nrm.x * w1, 0, q.y + nrm.y * w1)
		var D = Vector3(q.x - nrm.x * w1, 0, q.y - nrm.y * w1)
		_stv(st, A, Vector2(k0, 0.0), col)
		_stv(st, B, Vector2(k0, 1.0), col)
		_stv(st, C, Vector2(k1, 0.0), col)
		_stv(st, B, Vector2(k0, 1.0), col)
		_stv(st, D, Vector2(k1, 1.0), col)
		_stv(st, C, Vector2(k1, 0.0), col)
		if depth > 0 and i > 0 and randf() < 0.4:
			_crack_path(st, q, ang + randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0), L * 0.38, w0 * 0.6, depth - 1)
		p = q


## Cel toz topakları: halka hâlinde dışa, biraz yukarı; bias yönüne kayabilir
static func _dust(pj: PathJutsu, p: Vector3, n: int, r: float, rise: float, life: float, size: float, col := DUST_C, bias := Vector3.ZERO) -> void:
	for i in n:
		var a = TAU * float(i) / float(maxi(n, 1)) + randf_range(-0.3, 0.3)
		var dir = Vector3(cos(a), 0, sin(a))
		var s = size * randf_range(0.7, 1.2)
		var mi = _spawn(pj, _lump(), _sm("dust", DUST_SH), p + dir * r * 0.25 + Vector3.UP * s * 0.3, NEAR_M)
		mi.set_instance_shader_parameter("tint", col)
		mi.scale = Vector3.ONE * s * 0.4
		var to = p + dir * r * randf_range(0.7, 1.0) + bias * randf_range(0.6, 1.0) + Vector3.UP * (rise * randf_range(0.5, 1.0) + s * 0.3)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", to, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(s, s * 0.8, s), life * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Yerçekimli uçuş (moloz, kırık, damla)
static func _fly(mi: Node3D, p0: Vector3, v: Vector3, life: float, spin: Vector3, grav := 9.8) -> void:
	var w = weakref(mi)
	var tw = mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.global_position = p0 + v * t + Vector3.DOWN * grav * t * t * 0.5
			x.rotation = spin * t, 0.0, life, life)
	tw.tween_callback(mi.queue_free)
	if mi is GeometryInstance3D:
		var tf = mi.create_tween()
		tf.tween_interval(life * 0.65)
		tf.tween_method(_pf(mi as GeometryInstance3D, "fade"), 1.0, 0.0, life * 0.35)


static func _chips(pj: PathJutsu, p: Vector3, n: int, spd: float, size: float, up := 1.0, bias := Vector3.ZERO, life := 0.9) -> void:
	for i in n:
		var mi = _spawn(pj, _chip(i % 3), _toon(0.02), p, NEAR_S)
		mi.scale = Vector3.ONE * size * randf_range(0.6, 1.3)
		var v = Vector3(randf_range(-1, 1), randf_range(0.4, 1.0) * up, randf_range(-1, 1)).normalized() * spd * randf_range(0.5, 1.0) + bias
		_fly(mi, p, v, life * randf_range(0.8, 1.1), Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))


static func _flash(pj: PathJutsu, p: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	pj.scene_add(l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Kırık şimşek kolu (iai çıtırtısı, kesik dalları): kameraya dönük zikzak, koyu mavi kenar, titreyerek söner
static func _zig(pj: PathJutsu, a: Vector3, b: Vector3, col: Color, w: float, life: float) -> void:
	var n = 7
	var d = b - a
	if d.length() < 0.01:
		return
	var u = _perp(d)
	var v = d.normalized().cross(u)
	var pts = []
	var ws = []
	for i in n:
		var k = float(i) / float(n - 1)
		var off = Vector3.ZERO
		if i > 0 and i < n - 1:
			off = (u * randf_range(-1, 1) + v * randf_range(-1, 1)) * d.length() * 0.14
		pts.append(a + d * k + off)
		ws.append(w * (1.0 - k * 0.6))
	var mi = _ribbon(pj, NEAR_S)
	_style_rib(mi, col.lightened(0.25), 0.45, Color(0.12, 0.22, 0.6, 1.0))
	_redraw(mi, pts, ws, _fill(n, Color(1, 1, 1, 1)), _cam(pj))
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.25, life * 0.35)
	tw.tween_method(_pf(mi, "fade"), 0.25, 1.0, life * 0.15)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5)
	tw.tween_callback(mi.queue_free)


## Yükselen küçük ışık zerresi
static func _mote(pj: PathJutsu, p: Vector3, col: Color, size: float, rise: float, life: float) -> void:
	var mi = _spawn(pj, _lump(), _sm("rib", RIB_SH), p, NEAR_S)
	_style_rib(mi, col)
	mi.scale = Vector3.ONE * size
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "global_position", p + Vector3(randf_range(-0.15, 0.15), rise, randf_range(-0.15, 0.15)), life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)


## Ukon'un ek uzuvları (ref: yarı saydam, üst üste binen ek yumruklar): kemiğe bağlı ruh gövdesi, fırlar, söner
static func _ghost_limbs(pj: PathJutsu, c: Node3D, bone: String, leg: bool, dur: float) -> void:
	var ba = pj.bone_attach(c, bone)
	if ba == null:
		return
	var skin = Color(0.93, 0.8, 0.7)
	for k in 2:
		var sx = 1.0 if k == 0 else -1.0
		var b = MB.new()
		var L = 0.62 if not leg else 0.8
		Loft.tube(b, [Vector3(0, 0.05, 0), Vector3(sx * 0.02, L * 0.55, 0), Vector3(0, L, 0)], [0.06, 0.055, 0.05], skin, 8, 2, false, false)
		if leg:
			b.add("box", Vector3(0, L + 0.06, 0.06), Vector3(0.12, 0.1, 0.25), skin, Vector3.ZERO, 1)
		else:
			b.add("sphere", Vector3(0, L + 0.07, 0), Vector3(0.15, 0.17, 0.14), skin, Vector3.ZERO, 8)
		var holder = Node3D.new()
		ba.add_child(holder)
		holder.position = Vector3(sx * 0.09, 0.0, (0.05 if not leg else -0.04) * sx)
		holder.rotation = Vector3(0, 0, -sx * 0.18)
		holder.scale = Vector3(1, 0.05, 1)
		var mi = _spawn(pj, b.build(null), _sm("spirit", SPIRIT_SH), Vector3.ZERO, NEAR_S, holder)
		mi.set_instance_shader_parameter("tint", Color(0.97, 0.86, 0.76, 0.62))
		mi.set_instance_shader_parameter("rim", Color(0.32, 0.2, 0.18, 0.9))
		var tw = holder.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(holder, "scale", Vector3(1, 1.5, 1), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(dur)
		tw.tween_method(func(v: float) -> void: _set_tree(holder, "fade", v), 1.0, 0.0, 0.12)
		tw.tween_callback(holder.queue_free)
	pj.free_after(dur + 0.5, ba)


## Ruh izi (Yamanaka): parlak baş + arkasında incelen kristalimsi kuyruk; a düğümünden b'nin başına kavisle gider
static func _soul_streak(pj: PathJutsu, a: Node3D, b: Node3D, dur: float, col: Color, rim: Color, w: float) -> void:
	var aw = weakref(a)
	var bw = weakref(b)
	var start = a.global_position + Vector3.UP * 1.2
	var last = {"a": start, "b": b.global_position + Vector3.UP * (_hgt(b) * 0.9)}
	var head = _spawn(pj, _lump(), _sm("spirit", SPIRIT_SH), start, NEAR_S)
	head.set_instance_shader_parameter("tint", Color(col.r, col.g, col.b, 0.9))
	head.set_instance_shader_parameter("rim", rim)
	head.scale = Vector3(w * 1.5, w * 1.5, w * 3.0)
	var trail = _ribbon(pj, NEAR_S)
	_style_rib(trail, col, 0.35, rim, 4.0)
	var hist = []
	var step = func(u: float) -> void:
		if not is_instance_valid(head):
			return
		var x = aw.get_ref()
		var y = bw.get_ref()
		if x != null and is_instance_valid(x):
			last["a"] = (x as Node3D).global_position + Vector3.UP * 1.2
		if y != null and is_instance_valid(y):
			last["b"] = (y as Node3D).global_position + Vector3.UP * (_hgt(y as Node3D) * 0.9)
		var pa: Vector3 = last["a"]
		var pb: Vector3 = last["b"]
		var mid = (pa + pb) * 0.5 + Vector3.UP * (pa.distance_to(pb) * 0.16)
		var e = u * u * (3.0 - 2.0 * u)
		var p = pa.lerp(mid, e).lerp(mid.lerp(pb, e), e)
		var e2 = minf(e + 0.03, 1.0)
		var p2 = pa.lerp(mid, e2).lerp(mid.lerp(pb, e2), e2)
		head.global_position = p
		if p2.distance_to(p) > 0.001:
			head.global_basis = _view_basis(p2 - p, Vector3.UP).orthonormalized()
			head.scale = Vector3(w * 1.5, w * 1.5, w * 3.0)
		hist.append(p)
		if hist.size() > 14:
			hist.pop_front()
		var n = hist.size()
		if n >= 2:
			var ws = []
			var cs = []
			for i in n:
				var k = float(i) / float(n - 1)
				ws.append(w * (0.15 + 0.85 * k))
				cs.append(Color(1, 1, 1, k))
			_redraw(trail, hist, ws, cs, _cam(pj))
	var tw = head.create_tween()
	tw.tween_method(step, 0.0, 1.0, maxf(dur, 0.05))
	tw.tween_callback(func() -> void:
		var pb: Vector3 = last["b"]
		var r1 = _face_sheet(pj, pb, 0.7, 0, col, rim, NEAR_S, 0.18)
		_anim_sheet(r1, 0.15, 1.0, 0.25, 0.0, 0.2)
		var r2 = _face_sheet(pj, pb, 0.5, 0, Color(1, 1, 1, 0.9), rim, NEAR_S, 0.22)
		_anim_sheet(r2, 0.15, 1.0, 0.3, 0.0, 0.2, 0.08)
		_fade_free(trail, 0.0, 0.25)
		head.queue_free())


## Zihin ipi: a'nın başından b'ye ince, dalgalı ip; açılır, durur, söner
static func _mind_thread(pj: PathJutsu, a: Node3D, b: Node3D, dur: float, col: Color, delay: float, w := 0.035) -> void:
	var aw = weakref(a)
	var bw = weakref(b)
	var last = {"a": a.global_position + Vector3.UP * 1.6, "b": b.global_position + Vector3.UP * (_hgt(b) * 0.85)}
	var mi = _ribbon(pj, NEAR_M)
	_style_rib(mi, col, 0.4, Color(0.3, 0.12, 0.5, 0.9), 2.0)
	var sd0 = randf() * 10.0
	var build = func(u: float) -> Array:
		var x = aw.get_ref()
		var y = bw.get_ref()
		if x != null and is_instance_valid(x):
			last["a"] = (x as Node3D).global_position + Vector3.UP * 1.6
		if y != null and is_instance_valid(y):
			last["b"] = (y as Node3D).global_position + Vector3.UP * (_hgt(y as Node3D) * 0.85)
		var pa: Vector3 = last["a"]
		var pb: Vector3 = last["b"]
		var reach = clampf(u / 0.3, 0.0, 1.0)
		var alpha = 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
		var dv = pb - pa
		var side = _perp(dv)
		var n = 16
		var pts = []
		var ws = []
		var cs = []
		for i in n:
			var k = float(i) / float(n - 1) * reach
			var wob = sin(k * 9.0 + u * 14.0 + sd0) * 0.12 * sin(k * PI)
			pts.append(pa + dv * k + side * wob + Vector3.UP * sin(k * PI) * minf(dv.length() * 0.05, 1.5))
			ws.append(w)
			cs.append(Color(1, 1, 1, alpha))
		return [pts, ws, cs, Vector3.ZERO]
	_live_ribbon(pj, mi, dur, build, delay)


# ================================================================== 1) Shiranui: Tenketsu Bari
## Tek senbon: parmak arasında kısa ışıltı → ince çelik iğne, arkasında soluk iz → isabette tenketsu noktası daralan halkayla
## kapanır, chakra damarları maviden griye söner, iğne bedende saplı kalır, kapanan noktalar söner-yanar
static func shiranui_tenketsu_bari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var id = "shiranui_tenketsu_bari"
	var tt = pj.tg(c, t, 22.0)
	pj._face(c, tt)
	pj.anim(c, "throw", 2.0)
	var from: Vector3 = pj.hand_pos(c)
	var gl = _face_sheet(pj, from, 0.26, 8, TCH, INK, NEAR_S)
	_anim_sheet(gl, 0.2, 1.0, 0.05, 0.04, 0.12)
	var on_hit = func(p, h):
		if h and is_instance_valid(h) and pj.live(h):
			_tenketsu_seal(pj, h, p, 4.0)
		_needle_tick(pj, p)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 70.0, _needle(pj), pj.inf(c, id, 0.5, {"knock": 0.0, "kind": "light", "hitstop": 0.05, "pierce_guard": true}), tt, false, 1.0, on_hit)
	pr.radius = 0.25
	Sfx.play("throw_kunai", from, 2.0)


static func _needle_mesh() -> ArrayMesh:
	var k = "mesh:needle"
	if not _c.has(k):
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.016, 0.5, 0.016), STEEL_C, Vector3(90, 0, 0), 5)
		b.add("cone", Vector3(0, 0, -0.27), Vector3(0.018, 0.06, 0.018), Color(0.95, 0.97, 1.0), Vector3(-90, 0, 0), 5)
		_c[k] = b.build(null)
	return _c[k]


static func _needle(_pj: PathJutsu) -> Node3D:
	var n = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = _needle_mesh()
	mi.material_override = _toon(0.008)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	for k in 2:
		var tr = MeshInstance3D.new()
		tr.mesh = _spike()
		tr.material_override = _sm("rib", RIB_SH)
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tr.set_instance_shader_parameter("tint", Color(0.85, 0.93, 1.0, 0.55))
		tr.set_instance_shader_parameter("nearz", NEAR_S)
		n.add_child(tr)
		tr.position = Vector3(0, 0, 0.22)
		tr.rotation = Vector3(0, 0, PI * 0.5 * k)
		tr.scale = Vector3(0.05, 1.0, 1.6)
	return n


static func _needle_tick(pj: PathJutsu, p: Vector3) -> void:
	var s = _face_sheet(pj, p, 0.3, 8, Color(0.9, 0.96, 1.0), INK, NEAR_S)
	_anim_sheet(s, 0.3, 1.0, 0.04, 0.03, 0.1)
	_burst_lines(pj, p, 3, 0.05, 0.35, 0.15, Color(0.85, 0.92, 1.0), 0.03)


## Chakra noktası kapanır (kapatma mekaniği: sealed durumu + yazı), görseli burada
static func _tenketsu_seal(pj: PathJutsu, h: Node3D, p: Vector3, dur: float) -> void:
	if not pj.live(h):
		return
	pj.st(h, "sealed", dur)
	Combat.popup_text(h.global_position + Vector3.UP * (_hgt(h) + 1.0), "Chakra noktaları kapandı!", TCH)
	# nokta: daralan halka (akış tıkanıyor)
	var pt = _face_sheet(pj, p, 0.45, 9, TCH, INK, NEAR_S, 0.08)
	_anim_sheet(pt, 1.0, 0.15, 0.3, 0.25, 0.3)
	# damarlar: kısa kırık çizgiler, mavi → gri
	var view = _cam_dir(pj, p)
	var u = _perp(view)
	var v = view.cross(u)
	for i in 6:
		var a = TAU * float(i) / 6.0 + randf_range(-0.3, 0.3)
		var d = u * cos(a) + v * sin(a)
		_zig(pj, p, p + d * randf_range(0.22, 0.45), Color(0.45, 0.6, 0.75), 0.025, 0.4)
	# saplı iğne
	var ndl = MeshInstance3D.new()
	ndl.mesh = _needle_mesh()
	ndl.material_override = _toon(0.008)
	ndl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(ndl)
	ndl.global_position = p
	var cen = h.global_position + Vector3.UP * (_hgt(h) * 0.55)
	if cen.distance_to(p) > 0.05:
		ndl.look_at(cen, Vector3.UP if absf((cen - p).normalized().y) < 0.95 else Vector3.RIGHT)
		ndl.global_position = p - (cen - p).normalized() * 0.12
	pj.free_after(dur, ndl)
	# kapanan noktalar: bedende üç küçük nokta söner-yanar, rengi soluk griye döner
	var dots = Node3D.new()
	h.add_child(dots)
	dots.position = Vector3.ZERO
	var rr = _rad(h)
	var hh = _hgt(h)
	for k in 3:
		var a2 = randf() * TAU
		var dm = _spawn(pj, _lump(), _sm("rib", RIB_SH), Vector3(cos(a2) * rr * 1.05, hh * (0.35 + 0.2 * k), sin(a2) * rr * 1.05), NEAR_S, dots)
		_style_rib(dm, TCH)
		dm.scale = Vector3.ONE * 0.07
	var dw = weakref(dots)
	pj.every(dur, 0.25, func(i, k):
		var x = dw.get_ref()
		if x != null and is_instance_valid(x):
			var nd: Node3D = x
			nd.visible = i % 2 == 0 or i > dur * 3.0
			var col = TCH.lerp(Color(0.55, 0.58, 0.62), k)
			for ch in (x as Node3D).get_children():
				if ch is GeometryInstance3D:
					(ch as GeometryInstance3D).set_instance_shader_parameter("tint", col), func():
		var x = dw.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


# ================================================================== 2) Shiranui: Hiraijin no Jutsu (Hokage Muhafız Birliği)
## ref: üç kişi halka olup parmaklarını birleştirir. Göğüs hizasında altın bağ halkası el ele dolaşır, yerde dönen mühür
## formülü açılır; ışınlanmada her kişide dikey altın çakma, varışta Kage Kulesi önünde formül + toz halkası.
static func hiraijin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var allies = []
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if f != c and is_instance_valid(f) and f is Enemy and not f.dead and f.get("team") == c.get("team") and f.global_position.distance_to(c.global_position) < 6.0:
			allies.append(f)
	if allies.size() < 2:
		if c is Player:
			Hud.msg("Hiraijin üç kişiyle yapılır: yanında (6 m) en az iki takım arkadaşın olmalı.", Color(1, 0.75, 0.45), 5.0)
		return
	if Interiors.inst and Interiors.inst.inside != "":
		if c is Player:
			Hud.msg("Kapalı bir yerdesin: işarete ışınlanmak için dışarıda ol.", Color(1, 0.75, 0.45))
		return
	if c is Player and Orgs.is_rogue():
		Hud.msg("İşaret köyünün Kage'sinde — kaçak bir ninjaya o halka açılmaz.", Color(1, 0.6, 0.5))
		return
	var vid = Progress.home() if c is Player else String(c.get("look").get("village", "konoha") if c.get("look") is Dictionary else "konoha")
	var dest = Missions.open_ground(Exams.find_point(["mission_board"], vid), 25.0)
	var group = [c] + allies.slice(0, 5)
	pj.busy(c, 1.0)
	pj.anim(c, "seal", 1.0)
	_hiraijin_ring(pj, group, 0.55)
	Sfx.play("whoosh", c.global_position, 1.6)
	pj.after(0.55, func():
		for i in group.size():
			var g = group[i]
			if not is_instance_valid(g):
				continue
			var a = TAU * i / group.size()
			var q = pj.gp(dest + Vector3(cos(a), 0, sin(a)) * 2.2)
			_hiraijin_blink(pj, g.global_position, false)
			g.global_position = q + Vector3.UP * 0.1
			if g is CharacterBody3D:
				g.velocity = Vector3.ZERO
			if g.has_method("reset_physics_interpolation"):
				g.reset_physics_interpolation()
			if g is Enemy:
				g.home = q
				g.target = null
			if g is Player:
				g.cam_pivot.global_position = q + Vector3.UP * 1.6 * g.model.age_scale
			_hiraijin_blink(pj, q, true)
		_hiraijin_mark(pj, pj.gp(dest))
		if c is Player:
			Hud.msg("Hiraijin — takım %s Kulesi'nin önüne indi." % Progress.kage_title(vid), Color(1, 0.9, 0.5)))


static func _hiraijin_ring(pj: PathJutsu, group: Array, dur: float) -> void:
	var cen = Vector3.ZERO
	for g in group:
		cen += (g as Node3D).global_position
	cen /= float(group.size())
	var R = 0.0
	var pairs = []
	for g in group:
		var off = (g as Node3D).global_position - cen
		off.y = 0.0
		R = maxf(R, off.length())
		pairs.append([atan2(off.z, off.x), weakref(g)])
	pairs.sort_custom(func(x, y): return x[0] < y[0])
	# yerde dönerek açılan mühür formülü
	var seal = _flat_sheet(pj, pj.gp(cen) + Vector3.UP * 0.05, Vector3.UP, clampf(R + 1.2, 2.5, 5.0), 2, GOLD, Color(1.0, 0.7, 0.1, 0.55), NEAR_M, 0.035)
	_anim_sheet(seal, 0.0, 1.0, dur, 0.1, 0.35)
	# göğüs hizasında el ele altın bağ
	var link = _ribbon(pj, NEAR_M)
	_style_rib(link, GOLD, 0.35, Color(0.45, 0.25, 0.02, 1.0))
	var build = func(u: float) -> Array:
		var pts = []
		for pr in pairs:
			var x = (pr[1] as WeakRef).get_ref()
			if x != null and is_instance_valid(x):
				pts.append((x as Node3D).global_position + Vector3.UP * 1.15)
		if pts.size() < 2:
			return []
		pts.append(pts[0])
		var n = pts.size()
		var al = clampf(u / 0.3, 0.0, 1.0) * (1.0 - clampf((u - 0.85) / 0.15, 0.0, 1.0))
		return [pts, _fill(n, 0.07), _fill(n, Color(1, 1, 1, al)), Vector3.ZERO]
	_live_ribbon(pj, link, dur, build)
	for pr in pairs:
		var x = (pr[1] as WeakRef).get_ref()
		if x != null and is_instance_valid(x):
			var gp_ = (x as Node3D).global_position + Vector3.UP * 1.15
			var s = _face_sheet(pj, gp_, 0.35, 8, GOLD, Color(0.45, 0.25, 0.02, 1.0), NEAR_S)
			_anim_sheet(s, 0.0, 1.0, 0.12, dur * 0.6, 0.15, 0.15)


## Işınlanma çakması: kalkışta dikey çizgiler dışa açılıp söner; varışta dıştan içe kapanır + toz
static func _hiraijin_blink(pj: PathJutsu, p: Vector3, arrive: bool) -> void:
	var ch = p + Vector3.UP * 1.0
	for sgn in [1.0, -1.0]:
		var d = Vector3.UP * float(sgn)
		var mi = _spike_mi(pj, ch, -d, 0.14, 0.1 if not arrive else 2.4, Color(1.0, 0.95, 0.65), NEAR_M)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale:z", 2.4 if not arrive else 0.1, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.14).set_delay(0.12)
		tw.chain().tween_callback(mi.queue_free)
	_flash(pj, ch, GOLD, 2.5, 6.0, 0.25)
	var g = pj.gp(p) + Vector3.UP * 0.05
	var rg = _flat_sheet(pj, g, Vector3.UP, 1.2, 0, GOLD, Color(0.45, 0.25, 0.02, 1.0), NEAR_M, 0.16)
	_anim_sheet(rg, 0.1, 1.0, 0.2, 0.0, 0.2)
	if arrive:
		_dust(pj, g, 4, 1.4, 0.3, 0.6, 0.45)


static func _hiraijin_mark(pj: PathJutsu, g: Vector3) -> void:
	var f = _flat_sheet(pj, g + Vector3.UP * 0.06, Vector3.UP, 4.5, 2, GOLD, Color(1.0, 0.7, 0.1, 0.55), NEAR_M, 0.03)
	_anim_sheet(f, 0.0, 1.0, 0.25, 0.6, 0.6)
	var r = _flat_sheet(pj, g + Vector3.UP * 0.07, Vector3.UP, 5.0, 0, Color(1.0, 0.92, 0.6, 0.85), Color(0.45, 0.25, 0.02, 1.0), NEAR_M, 0.08)
	_anim_sheet(r, 0.2, 1.0, 0.35, 0.0, 0.3)


# ================================================================== 3) Tarenken
## ref: Sakon'un yumruğuyla kolundan iki yarı saydam ek kol fışkırır; üç yumruk üçgen dizilip aynı anda çarpar —
## üç ayrı çarpma yıldızı, arkalarında kısa hız çizgileri, önde dikey kırılma halkası (kaya delen güç)
static func tarenken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.55)
	var tt = pj.tg(c, t, 4.0)
	if tt and "facing" in c:
		var dd = tt.global_position - c.global_position
		c.facing = atan2(-dd.x, -dd.z)
	pj.anim(c, "cross", 1.4)
	_pull_in(pj, pj.hand_pos(c), 5, 0.7, 0.12, Color(0.95, 0.9, 0.82))
	pj.after(0.12, func():
		if not pj.live(c):
			return
		_ghost_limbs(pj, c, "RightLowerArm", false, 0.3)
		Sfx.play("punch", c.global_position, 0.85)
		var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.3
		pj.hit(c, at, 1.4, pj.inf(c, "tarenken", 0.55, {"knock": 9.0, "kind": "heavy", "hitstop": 0.08}))
		_triple_fist(pj, at, c.face_dir()))


static func _triple_fist(pj: PathJutsu, at: Vector3, fd: Vector3) -> void:
	var sd = fd.cross(Vector3.UP).normalized()
	var offs = [sd * -0.3 + Vector3.UP * 0.18, sd * 0.3 + Vector3.UP * 0.18, Vector3.DOWN * 0.2]
	for k in 3:
		var p: Vector3 = at + offs[k]
		var s = _face_sheet(pj, p, 0.55, 8, Color(1.0, 0.93, 0.78), INK, NEAR_S)
		_anim_sheet(s, 0.0, 1.0, 0.05, 0.05, 0.12, k * 0.035)
		_speed_lines(pj, p - fd * 0.5, fd, 3, 0.9, 0.12, 0.2, Color(0.95, 0.92, 0.85), 0.035)
	var ring = _flat_sheet(pj, at + fd * 0.25, fd, 1.1, 0, Color(1.0, 0.96, 0.88, 0.85), INK, NEAR_S, 0.14)
	_anim_sheet(ring, 0.15, 1.0, 0.16, 0.0, 0.12)
	_burst_lines(pj, at + fd * 0.2, 7, 0.4, 0.8, 0.2, Color(1.0, 0.95, 0.85), 0.06)
	_dust(pj, at + fd * 0.4 - Vector3.UP * 0.6, 3, 0.4, 0.2, 0.45, 0.35, DUST_C, fd * 1.2)


# ================================================================== 4) Tarenkyaku
## ref: tekmeyle bacaktan iki ek bacak fışkırır; üç tekme üç farklı düzlemde kontur çizgili yay lekesi bırakır
## (yatay süpürme → çapraz → dikey yükselen), sonuncusu hedefi savurur: yukarı çarpma çizgileri + yerden toz
static func tarenkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.75)
	pj.anim(c, "kick", 1.3)
	for k in 3:
		pj.after(0.1 + k * 0.12, func():
			if not pj.live(c):
				return
			if k == 0:
				_ghost_limbs(pj, c, "RightLowerLeg", true, 0.4)
			Sfx.play("hit_heavy" if k == 2 else "punch", c.global_position, 0.9 + k * 0.05)
			var at = c.global_position + Vector3.UP * 0.9 + c.face_dir() * 1.4
			pj.hit(c, at, 1.5, pj.inf(c, "tarenkyaku", 0.25 if k < 2 else 0.4, {"knock": 3.0 if k < 2 else 13.0, "launch": 0.0 if k < 2 else 5.0, "kind": "light" if k < 2 else "heavy", "hitstop": 0.05}))
			_kick_arc(pj, c, at, k))


static func _kick_arc(pj: PathJutsu, c: Node3D, at: Vector3, k: int) -> void:
	var fd: Vector3 = c.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	var nrm = Vector3.UP
	var cen = c.global_position + Vector3.UP * 0.8
	var r = 1.4
	if k == 1:
		nrm = (Vector3.UP + sd).normalized()
		cen = c.global_position + Vector3.UP * 1.0
		r = 1.5
	elif k == 2:
		nrm = sd
		cen = c.global_position + Vector3.UP * 0.9
		r = 1.6
	var u = (fd - nrm * fd.dot(nrm)).normalized()
	var v = nrm.cross(u)
	var a0 = -1.2 if k < 2 else -1.6
	var a1 = 0.75 if k < 2 else 1.2
	var mi = _ribbon(pj, NEAR_S)
	_style_rib(mi, Color(1.0, 0.97, 0.9, 0.9), 0.22, INK)
	var w = 0.34 if k < 2 else 0.5
	var build = func(t: float) -> Array:
		var rev = clampf(t / 0.3, 0.0, 1.0)
		var al = 1.0 - clampf((t - 0.45) / 0.55, 0.0, 1.0)
		var n = 14
		var pts = []
		var ws = []
		var cs = []
		var head = lerpf(a0, a1, rev)
		var tail = lerpf(a0, head, 0.15)
		for i in n:
			var kk = float(i) / float(n - 1)
			var a = lerpf(tail, head, kk)
			pts.append(cen + (u * cos(a) + v * sin(a)) * r)
			ws.append(w * (0.1 + 0.9 * pow(kk, 0.7)))
			cs.append(Color(1, 1, 1, al * (0.15 + 0.85 * kk)))
		return [pts, ws, cs, nrm]
	_live_ribbon(pj, mi, 0.26, build)
	var s = _face_sheet(pj, at, 0.5 + 0.25 * k, 8, Color(1.0, 0.94, 0.8), INK, NEAR_S)
	_anim_sheet(s, 0.0, 1.0, 0.05, 0.04, 0.12)
	if k == 2:
		_burst_lines(pj, at, 7, 0.3, 1.3, 0.28, Color(1.0, 0.95, 0.85), 0.07, Vector3.UP, 32.0)
		var g = pj.gp(at)
		_dust(pj, g, 5, 1.2, 0.5, 0.55, 0.5)
		var rg = _flat_sheet(pj, g + Vector3.UP * 0.05, Vector3.UP, 1.4, 0, Color(0.9, 0.84, 0.72, 0.8), INK, NEAR_M, 0.14)
		_anim_sheet(rg, 0.15, 1.0, 0.2, 0.0, 0.2)


# ================================================================== 5) Naruto Ittai Rendan
## ref: Kurama chakrasına bürünmüş klon ordusu: her klonun çevresinde yalazlanan turuncu chakra dilleri ve iki "kulak" alevi;
## U-ZU-MA-KI her vuruşta yukarı fırlayan çarpma çizgileri, havada küçük turuncu darbe yıldızları, bitişte yukarıdan inen
## hız çizgileri ve turuncu kenarlı krater
static func naruto_ittai_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 2.0)
	if tt == null:
		return
	var at = tt.global_position
	var clones = []
	for k in 10:
		var a = k * TAU / 10.0
		var q = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 2.2)
		_clone_pop(pj, q)
		var d = pj.decoy(c, q, 2.4)
		if d:
			_kurama_cloak(pj, d, 2.4)
			clones.append(d)
	var words = ["U", "ZU", "MA", "KI"]
	for k in 4:
		pj.after(0.25 + k * 0.18, func():
			if pj.live(tt):
				Combat.popup_text(tt.global_position + Vector3.UP * (2.0 + k * 0.6), words[k] + "!", KURAMA)
				_uzumaki_blow(pj, tt.global_position + Vector3.UP, k)
				tt.take_hit(pj.inf(c, "naruto_ittai_rendan", 0.35, {"knock": 0.0, "launch": 6.0 if k < 3 else 16.0, "kind": "heavy" if k == 3 else "light"}))
				Sfx.play("punch", tt.global_position, 0.9 + k * 0.1))
	# havada her yönden yumruk yağmuru
	pj.every(0.6, 0.06, func(i, _k):
		if pj.live(tt) and i > 1:
			var hp = tt.global_position + Vector3.UP
			_rain_blow(pj, hp + Vector3(randf_range(-0.7, 0.7), randf_range(-0.5, 0.7), randf_range(-0.7, 0.7)))
			tt.take_hit(pj.inf(c, "naruto_ittai_rendan", 0.06, {"knock": 0.0, "launch": 0.6, "kind": "light"})), Callable())
	pj.after(1.55, func():
		if not pj.live(c) or not pj.live(tt):
			return
		c.global_position = tt.global_position + Vector3.UP * 1.4
		pj._kick_pose(c, 0.3)
		Combat.popup_text(c.global_position + Vector3.UP * 2.0, "Naruto Ittai Rendan!", KURAMA)
		_speed_lines(pj, c.global_position + Vector3.UP * 1.2, Vector3.DOWN, 9, 2.6, 0.6, 0.3, KURAMA_Y, 0.07)
		tt.take_hit(pj.inf(c, "naruto_ittai_rendan", 1.6, {"knock": 6.0, "launch": -26.0, "kind": "heavy", "pierce_guard": true}))
		pj.after(0.3, func():
			if pj.live(tt):
				_rendan_crash(pj, tt.global_position + Vector3.UP * 0.3)
				pj.shake(0.9)))


static func _clone_pop(pj: PathJutsu, q: Vector3) -> void:
	var rg = _flat_sheet(pj, q + Vector3.UP * 0.05, Vector3.UP, 1.1, 0, KURAMA, Color(0.62, 0.2, 0.02, 1.0), NEAR_M, 0.2)
	_anim_sheet(rg, 0.1, 1.0, 0.18, 0.0, 0.18)
	for i in 3:
		var p = q + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
		var mi = _spike_mi(pj, p, Vector3.DOWN, 0.12, 0.2, KURAMA_Y)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + Vector3.UP * 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale:z", 1.2, 0.15)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.15).set_delay(0.15)
		tw.chain().tween_callback(mi.queue_free)


## Kurama chakra pelerini: gövde çevresinde altı yalazlanan dil + başta iki kulak alevi (klona bağlı)
static func _kurama_cloak(pj: PathJutsu, host: Node3D, dur: float) -> void:
	var root = Node3D.new()
	host.add_child(root)
	for i in 6:
		var a = TAU * float(i) / 6.0
		var q = _spawn(pj, _quad(), _sm("flame", FLAME_SH), Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3), NEAR_S, root)
		q.rotation.y = PI * 0.5 - a
		q.scale = Vector3(0.95, 2.2, 1.0)
		q.set_instance_shader_parameter("seed", randf() * 10.0)
	for sx in [-1.0, 1.0]:
		var e = _spawn(pj, _quad(), _sm("flame", FLAME_SH), Vector3(float(sx) * 0.14, 2.0, 0.0), NEAR_S, root)
		e.rotation = Vector3(0, 0, -float(sx) * 0.3)
		e.scale = Vector3(0.32, 0.6, 1.0)
		e.set_instance_shader_parameter("seed", randf() * 10.0)
	root.scale = Vector3(0.3, 0.3, 0.3)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.45, 0.05))
	tw.tween_method(func(v: float) -> void: _set_tree(root, "fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(root.queue_free)


static func _uzumaki_blow(pj: PathJutsu, p: Vector3, k: int) -> void:
	var s = _face_sheet(pj, p, 0.75 + 0.18 * k, 8, KURAMA, Color(0.5, 0.15, 0.02, 1.0), NEAR_M)
	_anim_sheet(s, 0.0, 1.0, 0.05, 0.05, 0.14)
	_burst_lines(pj, p, 6, 0.3, 1.2 + 0.2 * k, 0.26, KURAMA_Y, 0.08, Vector3.UP, 36.0)
	_speed_lines(pj, p - Vector3.UP * 0.8, Vector3.UP, 4, 1.6, 0.4, 0.22, Color(1.0, 0.8, 0.45), 0.05)


static func _rain_blow(pj: PathJutsu, p: Vector3) -> void:
	var s = _face_sheet(pj, p, 0.32, 8, KURAMA_Y, Color(0.6, 0.2, 0.02, 1.0), NEAR_S)
	_anim_sheet(s, 0.0, 1.0, 0.03, 0.03, 0.08)


static func _rendan_crash(pj: PathJutsu, p: Vector3) -> void:
	var g = pj.gp(p)
	var cr = _flat_sheet(pj, g + Vector3.UP * 0.035, Vector3.UP, 1.9, 1, Color(0.66, 0.55, 0.42, 0.85), Color(0.16, 0.1, 0.06, 0.88), NEAR_M, 0.22)
	_anim_sheet(cr, 0.3, 0.9, 0.12, 3.0, 0.8)
	_cracks(pj, g, 3.2, 7, 3.0)
	var rg = _flat_sheet(pj, g + Vector3.UP * 0.06, Vector3.UP, 3.6, 0, KURAMA, Color(0.5, 0.15, 0.02, 1.0), NEAR_M, 0.12)
	_anim_sheet(rg, 0.1, 1.0, 0.3, 0.0, 0.25)
	var s = _face_sheet(pj, p + Vector3.UP * 0.4, 1.5, 8, KURAMA, Color(0.5, 0.15, 0.02, 1.0), NEAR_M)
	_anim_sheet(s, 0.0, 1.0, 0.06, 0.06, 0.16)
	_dust(pj, g, 9, 2.6, 0.7, 0.75, 0.75)
	_chips(pj, g + Vector3.UP * 0.2, 10, 7.0, 0.22)
	_flash(pj, p + Vector3.UP, KURAMA, 3.0, 8.0, 0.3)
	pj.shake(0.5)


# ================================================================== 6) Sōtenkyaku
## ref: Tsunade'nin topuğu Susanoo kaburgalarını parçalar. Kalkışta toz halkası ve yukarı çizgiler, tepede topukta soluk
## chakra topağı, inişte mızrak gibi aşağı akan hız çizgileri; çarpmada büyük krater, geniş çatlak ağı, iki şok halkası,
## moloz yağmuru ve vurulan hedeften kopan saydam mavi zırh kırıkları
static func sotenkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.2)
	var a0 = c.global_position
	var land = pj.gp(tt.global_position if tt else a0 + c.face_dir() * 6.0)
	pj.anim(c, "jump", 1.0)
	_takeoff(pj, pj.gp(a0))
	var tw = c.create_tween()
	tw.tween_method(func(u: float):
		if pj.live(c):
			c.global_position = a0.lerp(land, u) + Vector3.UP * sin(u * PI) * 12.0
			if c is CharacterBody3D:
				c.velocity = Vector3.ZERO, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	pj.after(0.55, func():
		if pj.live(c):
			pj._kick_pose(c, 0.4)
			_heel_charge(pj, c, land))
	tw.tween_callback(func():
		if not pj.live(c):
			return
		_heaven_crash(pj, land)
		for h in pj.hit(c, land + Vector3.UP, 4.0, pj.inf(c, "sotenkyaku", 2.0, {"knock": 16.0, "launch": 6.0, "kind": "heavy", "armor_break": true, "hitstop": 0.12})):
			if h.has_method("apply_status"):
				h.apply_status("armor_break", 4.0)
			_armor_shards(pj, h)
		Sfx.play("boom", land, 0.8)
		pj.shake(1.0))


static func _takeoff(pj: PathJutsu, g: Vector3) -> void:
	var rg = _flat_sheet(pj, g + Vector3.UP * 0.05, Vector3.UP, 2.0, 0, Color(0.9, 0.84, 0.72, 0.85), INK, NEAR_M, 0.16)
	_anim_sheet(rg, 0.1, 1.0, 0.25, 0.0, 0.2)
	_dust(pj, g, 8, 1.8, 0.4, 0.6, 0.6)
	_burst_lines(pj, g + Vector3.UP * 0.5, 7, 0.3, 2.0, 0.3, Color(0.95, 0.92, 0.85), 0.07, Vector3.UP, 15.0)


static func _heel_charge(pj: PathJutsu, c: Node3D, land: Vector3) -> void:
	var ba = pj.bone_attach(c, "RightFoot")
	if ba:
		var orb = _spawn(pj, _lump(), _sm("spirit", SPIRIT_SH), Vector3.ZERO, NEAR_S, ba)
		orb.set_instance_shader_parameter("tint", Color(0.8, 0.98, 1.0, 0.75))
		orb.set_instance_shader_parameter("rim", Color(0.2, 0.55, 0.75, 0.95))
		orb.scale = Vector3.ONE * 0.1
		var tw = orb.create_tween()
		tw.tween_property(orb, "scale", Vector3.ONE * 0.32, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(orb, "scale", Vector3.ONE * 0.26, 0.08)
		pj.free_after(0.4, ba)
	var cw = weakref(c)
	pj.every(0.33, 0.05, func(_i, _k):
		var x = cw.get_ref()
		if x != null and is_instance_valid(x):
			var p = (x as Node3D).global_position + Vector3.UP * 0.6
			var d = land - p
			if d.length() > 0.5:
				_speed_lines(pj, p, d.normalized(), 3, 2.4, 0.5, 0.2, Color(0.85, 0.95, 1.0), 0.05), Callable())


static func _heaven_crash(pj: PathJutsu, land: Vector3) -> void:
	var cr = _flat_sheet(pj, land + Vector3.UP * 0.035, Vector3.UP, 3.0, 1, Color(0.66, 0.56, 0.44, 0.85), Color(0.15, 0.1, 0.07, 0.9), NEAR_M, 0.2)
	_anim_sheet(cr, 0.3, 0.92, 0.12, 6.0, 1.0)
	_cracks(pj, land, 6.0, 9, 7.0)
	var r1 = _flat_sheet(pj, land + Vector3.UP * 0.07, Vector3.UP, 6.5, 0, Color(0.97, 0.94, 0.86, 0.85), INK, NEAR_M, 0.1)
	_anim_sheet(r1, 0.08, 1.0, 0.4, 0.0, 0.3)
	var r2 = _flat_sheet(pj, land + Vector3.UP * 0.08, Vector3.UP, 4.5, 0, Color(0.85, 0.95, 1.0, 0.8), INK, NEAR_M, 0.12)
	_anim_sheet(r2, 0.08, 1.0, 0.35, 0.0, 0.25, 0.08)
	var s = _face_sheet(pj, land + Vector3.UP * 0.7, 1.8, 8, Color(1.0, 0.97, 0.85), INK, NEAR_M)
	_anim_sheet(s, 0.0, 1.0, 0.06, 0.07, 0.18)
	_burst_lines(pj, land + Vector3.UP * 0.4, 10, 0.5, 2.8, 0.35, Color(1.0, 0.96, 0.86), 0.1, Vector3.UP, 55.0)
	_chips(pj, land + Vector3.UP * 0.3, 18, 9.0, 0.35, 1.2)
	_dust(pj, land, 12, 4.5, 0.9, 0.9, 1.0)
	_flash(pj, land + Vector3.UP * 1.0, Color(1.0, 0.95, 0.85), 3.5, 10.0, 0.35)
	pj.shake(0.6)


## Zırh kırıkları: saydam mavi parçalar göğüsten dışa savrulur, döner, söner (ref: Susanoo kaburgası kırılır)
static func _armor_shards(pj: PathJutsu, h: Node3D) -> void:
	if not is_instance_valid(h):
		return
	var cp = h.global_position + Vector3.UP * (_hgt(h) * 0.6)
	for i in 7:
		var mi = _spawn(pj, _shard_mesh(), _sm("spirit", SPIRIT_SH), cp, NEAR_S)
		mi.set_instance_shader_parameter("tint", Color(0.62, 0.86, 1.0, 0.6))
		mi.set_instance_shader_parameter("rim", Color(0.15, 0.35, 0.85, 0.95))
		mi.scale = Vector3(0.25, 0.4, 0.06) * randf_range(0.7, 1.4)
		var v = Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized() * randf_range(3.0, 6.0)
		_fly(mi, cp, v, 0.8, Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), 7.0)


# ================================================================== 7) Makitsuki
## ref: Manda'nın mor, koyu bantlı, iç yüzü ak gövdesi hedefe sarılır. Yerden toprak kırılarak burgu gibi döne döne yükselir,
## her sıkışta içe doğru sıkıştırma çizgileri, bitişte ters dönerek toprağa çekilir
static func makitsuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	if tt == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var fit = pj._tgt_fit(tt)
	var g = pj.gp(tt.global_position)
	_burrow(pj, g, 1.7 * fit)
	Sfx.play("th_snake", g, 0.8)
	var coil = _snake_coil(pj, g, fit)
	coil.scale = Vector3(1, 0.02, 1)
	coil.rotation.y = -1.6
	var gw = coil.create_tween().set_parallel()
	gw.tween_property(coil, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gw.tween_property(coil, "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pj.st(tt, "bind", 3.2)
	pj.every(3.0, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.global_position = Vector3(g.x, tt.global_position.y, g.z)
			tt.take_hit(pj.inf(c, "makitsuki", 0.2, {"knock": 0.0, "kind": "crush", "pierce_guard": true}))
			_pull_in(pj, tt.global_position + Vector3.UP * 1.1 * fit, 6, 1.5 * fit, 0.2, Color(0.28, 0.16, 0.36, 0.9), 0.07)
			if is_instance_valid(coil):
				var sq = coil.create_tween()
				sq.tween_property(coil, "scale", Vector3(0.9, 1.0, 0.9), 0.1)
				sq.tween_property(coil, "scale", Vector3.ONE, 0.2), func():
		if is_instance_valid(coil):
			_unwind(pj, coil, g, fit))


static func _snake_coil(pj: PathJutsu, g: Vector3, fit: float) -> MeshInstance3D:
	var b = MB.new()
	var pts = []
	var rads = []
	var body = Color(0.5, 0.38, 0.6)
	var band = Color(0.22, 0.16, 0.13)
	var belly = Color(0.9, 0.93, 0.96)
	var blue = Color(0.18, 0.42, 0.58)
	for s in 40:
		var u = s / 39.0
		var a = u * TAU * 2.6
		var r = (1.25 + 0.1 * sin(u * 9.0)) * fit
		pts.append(Vector3(cos(a) * r, 0.5 * fit + u * 2.6 * fit, sin(a) * r))
		rads.append(Vector2(0.6, 0.55) * fit * (1.0 - u * 0.3))
	var col_fn = func(t2: float, ang: float, sdir: Vector3) -> Color:
		var a = t2 * TAU * 2.6
		var inward = -Vector3(cos(a), 0, sin(a))
		var bd = sdir.dot(inward)
		if bd > 0.5:
			return belly
		if bd > 0.36:
			return blue
		if fposmod(t2 * 30.0 + 0.12 * sin(ang * 2.0), 1.0) < 0.13:
			return band
		return body
	Loft.tube(b, pts, rads, body, 10, 3, true, true, col_fn)
	var hp: Vector3 = pts[-1] + Vector3.UP * 0.3 * fit
	b.add("sphere", hp, Vector3(1.2, 0.8, 1.6) * fit, body, Vector3.ZERO, 12)
	b.add("sphere", hp + Vector3(0, -0.2, 0.15) * fit, Vector3(1.0, 0.45, 1.4) * fit, belly, Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		var ep = hp + Vector3(float(sx) * 0.42, 0.28, 0.45) * fit
		b.add("sphere", ep, Vector3.ONE * 0.24 * fit, Color(0.96, 0.84, 0.28), Vector3.ZERO, 8)
		b.add("box", ep + Vector3(0, 0, 0.1) * fit, Vector3(0.04, 0.2, 0.06) * fit, Color(0.05, 0.04, 0.05), Vector3.ZERO, 1)
	return _spawn(pj, b.build(null), _toon(0.05), g, NEAR_M)


static func _burrow(pj: PathJutsu, g: Vector3, r: float) -> void:
	_cracks(pj, g, r, 8, 3.2)
	var rg = _flat_sheet(pj, g + Vector3.UP * 0.05, Vector3.UP, r * 1.2, 0, Color(0.6, 0.5, 0.38, 0.85), INK, NEAR_M, 0.2)
	_anim_sheet(rg, 0.2, 1.0, 0.3, 0.0, 0.25)
	_chips(pj, g + Vector3.UP * 0.2, 8, 5.0, 0.25)
	_dust(pj, g, 6, r, 0.6, 0.7, 0.7)


static func _unwind(pj: PathJutsu, coil: MeshInstance3D, g: Vector3, fit: float) -> void:
	var tw = coil.create_tween().set_parallel()
	tw.tween_property(coil, "rotation:y", 1.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(coil, "scale", Vector3(1, 0.02, 1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(coil.queue_free)
	_dust(pj, g, 6, 1.6 * fit, 0.4, 0.6, 0.6)


# ================================================================== 8) Ai no Muchi
## ref: turuncu, mavi lekeli savaş kurbağasının ağzından pembe dil kamçı gibi kıvrılarak uzanır, hedefe çarpar (pembe çarpma
## yıldızı), etrafına iki tur dolanır, savurup yere çarpar (yana uzanan çatlak, yan toz); kurbağa yere basılıp kaybolur
static func ai_no_muchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.0)
	var d = pj.fwd(c, tt)
	var sd = d.cross(Vector3.UP).normalized()
	var toad_at = pj.gp(c.global_position - d * 1.5 + sd * 2.2)
	Sfx.play("th_frog", toad_at, 0.8)
	var toad = _toad(pj, toad_at, d)
	if tt == null:
		_toad_leave(pj, toad, toad_at, 1.0)
		return
	var mouth = toad_at + Vector3.UP * 1.2 + d * 1.2
	_tongue(pj, mouth, tt, 0.9)
	pj.after(0.12, func():
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "ai_no_muchi", 0.6, {"knock": 2.0, "kind": "heavy", "hitstop": 0.06}))
			pj.st(tt, "bind", 0.6)
			Sfx.play("hit_heavy", tt.global_position, 0.9)
			var hp = tt.global_position + Vector3.UP
			var s = _face_sheet(pj, hp, 0.65, 8, Color(1.0, 0.72, 0.78), Color(0.45, 0.08, 0.15, 1.0), NEAR_S)
			_anim_sheet(s, 0.0, 1.0, 0.04, 0.04, 0.12)
			_burst_lines(pj, hp, 6, 0.25, 0.8, 0.18, Color(1.0, 0.9, 0.92), 0.06))
	pj.after(0.45, func():
		if not pj.live(tt):
			return
		var a0 = tt.global_position
		var land = pj.gp(a0 + sd * 3.0)
		var tw = tt.create_tween()
		tw.tween_method(func(u: float):
			if pj.live(tt):
				tt.global_position = a0.lerp(land, u) + Vector3.UP * sin(u * PI) * 4.0, 0.0, 1.0, 0.4)
		tw.tween_callback(func():
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "ai_no_muchi", 0.9, {"knock": 4.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08}))
				_tongue_slam(pj, land, sd)
				pj.shake(0.6)))
	_toad_leave(pj, toad, toad_at, 1.0)


static func _toad(pj: PathJutsu, at: Vector3, d: Vector3) -> Node3D:
	var b = MB.new()
	var orange = Color(0.93, 0.45, 0.18)
	var cream = Color(0.98, 0.8, 0.55)
	var blot = Color(0.13, 0.38, 0.62)
	b.add("sphere", Vector3(0, 1.2, 0.1), Vector3(2.6, 2.0, 2.5), orange, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.95, -0.55), Vector3(2.0, 1.2, 1.4), cream, Vector3.ZERO, 12)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 11:
		var a = rng.randf() * TAU
		var el = rng.randf_range(0.15, 1.1)
		var dv = Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		if dv.z < -0.5 and dv.y < 0.5:
			continue
		b.add("sphere", Vector3(0, 1.2, 0.1) + Vector3(dv.x * 1.28, dv.y * 0.98, dv.z * 1.23), Vector3(0.5, 0.18, 0.38) * rng.randf_range(0.7, 1.3), blot, Vector3(rad_to_deg(-el), rad_to_deg(-a), 0), 8)
	for sx in [-1.0, 1.0]:
		var ep = Vector3(float(sx) * 0.72, 2.2, -0.55)
		b.add("sphere", ep, Vector3.ONE * 0.62, orange, Vector3.ZERO, 10)
		b.add("sphere", ep + Vector3(0, 0.04, -0.16), Vector3(0.44, 0.42, 0.36), Color(0.98, 0.84, 0.25), Vector3.ZERO, 10)
		b.add("box", ep + Vector3(0, 0.04, -0.33), Vector3(0.3, 0.07, 0.04), Color(0.06, 0.04, 0.04), Vector3.ZERO, 1)
		b.add("sphere", Vector3(float(sx) * 0.95, 0.35, -0.8), Vector3(0.6, 0.5, 0.8), orange, Vector3.ZERO, 8)
	b.add("box", Vector3(0, 1.25, -1.2), Vector3(1.9, 0.07, 0.08), Color(0.35, 0.1, 0.06), Vector3.ZERO, 1)
	var mi = _spawn(pj, b.build(null), _toon(0.04), at, NEAR_M)
	mi.look_at(at + d, Vector3.UP)
	mi.scale = Vector3.ONE * 0.05
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.12, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.08)
	var rg = _flat_sheet(pj, at + Vector3.UP * 0.05, Vector3.UP, 2.2, 0, Color(0.9, 0.84, 0.72, 0.8), INK, NEAR_M, 0.16)
	_anim_sheet(rg, 0.2, 1.0, 0.25, 0.0, 0.2)
	_dust(pj, at, 4, 1.8, 0.3, 0.6, 0.6)
	return mi


static func _toad_leave(pj: PathJutsu, toad: Node3D, at: Vector3, delay: float) -> void:
	if not is_instance_valid(toad):
		return
	var tw = toad.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(toad, "scale", Vector3(1.3, 0.08, 1.3), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_dust(pj, at, 6, 2.0, 0.3, 0.6, 0.6)
		toad.queue_free())


## Dil: ağızdan kavisle kamçılanır (0.1 sn), hedefin çevresine iki tur dolanır, savrulmayı izler, sonda geri çekilir
static func _tongue(pj: PathJutsu, mouth: Vector3, tt: Node3D, dur: float) -> void:
	var mi = _ribbon(pj, NEAR_S)
	_style_rib(mi, Color(0.96, 0.52, 0.6), 0.3, Color(0.45, 0.08, 0.15, 1.0))
	var tw_ = weakref(tt)
	var last = {"tip": tt.global_position + Vector3.UP}
	var build = func(u: float) -> Array:
		var T = u * dur
		var x = tw_.get_ref()
		if pj.live(x):
			last["tip"] = (x as Node3D).global_position + Vector3.UP * 1.0
		var tip: Vector3 = last["tip"]
		var ext = clampf(T / 0.1, 0.0, 1.0)
		var ret = clampf((T - (dur - 0.08)) / 0.08, 0.0, 1.0)
		var reach = ext * (1.0 - ret)
		var end = mouth.lerp(tip, reach)
		var dv = end - mouth
		var L = dv.length()
		var side = _perp(dv) if L > 0.01 else Vector3.RIGHT
		var pts = []
		var ws = []
		var n = 14
		for i in n:
			var k = float(i) / float(n - 1)
			var whip = sin(k * PI * 2.0 - T * 30.0) * 0.25 * (1.0 - ext * 0.8) * sin(k * PI)
			pts.append(mouth + dv * k + side * whip + Vector3.UP * sin(k * PI) * minf(L * 0.08, 0.8))
			ws.append(0.22 - 0.06 * k)
		var wrapped = reach >= 1.0 and T > 0.12 and T < dur - 0.1
		if wrapped:
			for j in 10:
				var a = float(j) / 9.0 * TAU * 1.5 + T * 2.0
				pts.append(tip + Vector3(cos(a) * 0.45, -0.35 + j * 0.06, sin(a) * 0.45))
				ws.append(0.15)
		else:
			ws[n - 1] = 0.3
		return [pts, ws, _fill(pts.size(), Color(1, 1, 1, 1)), Vector3.ZERO]
	_live_ribbon(pj, mi, dur, build)


static func _tongue_slam(pj: PathJutsu, land: Vector3, sd: Vector3) -> void:
	_cracks(pj, land, 2.4, 6, 5.0, sd)
	var cr = _flat_sheet(pj, land + Vector3.UP * 0.035, Vector3.UP, 1.2, 1, Color(0.66, 0.56, 0.44, 0.85), Color(0.15, 0.1, 0.07, 0.9), NEAR_M, 0.22)
	_anim_sheet(cr, 0.3, 0.9, 0.1, 4.0, 0.8)
	var rg = _flat_sheet(pj, land + Vector3.UP * 0.06, Vector3.UP, 2.6, 0, Color(0.92, 0.86, 0.74, 0.85), INK, NEAR_M, 0.14)
	_anim_sheet(rg, 0.1, 1.0, 0.25, 0.0, 0.2)
	_chips(pj, land + Vector3.UP * 0.2, 10, 5.0, 0.25, 1.0, sd * 2.0)
	_dust(pj, land, 8, 1.6, 0.4, 0.7, 0.65, DUST_C, sd * 1.4)


# ================================================================== 9) Kagenade
## ref: Isobu'nun gri, dikenli kabuğu top olup yuvarlanır; arkasında yatay hız çizgileri ve yerde oyulmuş koyu iz kalır,
## çarptığı yerde ak tırtıklı sıçrama ve kaya kırıkları; bitişte kabuk açılır, parçalar dağılır
static func kagenade(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.1)
	var d = pj.fwd(c, tt)
	var mi = _shell_ball(pj, c.global_position + Vector3.UP * 1.5)
	if c.get("model"):
		c.model.visible = false
	var a0 = c.global_position
	var dist = (tt.global_position.distance_to(a0) + 3.0) if tt else 12.0
	var hits = []
	Sfx.play("earth", a0, 0.7)
	var furrow = _ribbon(pj, NEAR_M)
	_style_rib(furrow, Color(0.3, 0.24, 0.18, 0.6), 0.3, Color(0.1, 0.07, 0.05, 0.85))
	var track = [pj.gp(a0) + Vector3.UP * 0.04]
	pj.every(0.8, 1.0 / 30.0, func(_i, k):
		if not pj.live(c):
			return
		var p = pj.gp(a0 + d * dist * k)
		c.global_position = p
		if is_instance_valid(mi):
			mi.global_position = p + Vector3.UP * 1.5
			mi.rotate(d.cross(Vector3.UP).normalized(), -0.45)
		for h in pj.hit(c, p + Vector3.UP, 2.4, pj.inf(c, "kagenade", 1.1, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.06}), hits):
			hits.append(h)
			_shell_hit(pj, (h as Node3D).global_position + Vector3.UP, d)
		track.append(p + Vector3.UP * 0.04)
		if is_instance_valid(furrow) and track.size() >= 2:
			_redraw(furrow, track, _fill(track.size(), 1.7), _fill(track.size(), Color(1, 1, 1, 1)), _cam(pj), Vector3.UP)
		if _i % 2 == 0:
			_speed_lines(pj, p + Vector3.UP * 1.5 - d * 1.4, d, 2, 2.6, 1.6, 0.22, Color(0.82, 0.9, 0.88), 0.07)
		if _i % 3 == 0:
			_dust(pj, p - d * 1.2, 2, 0.6, 0.5, 0.55, 0.6, DUST_C, -d * 1.2)
			_chips(pj, p - d * 1.0 + Vector3.UP * 0.2, 2, 4.0, 0.2, 1.0, -d * 2.0), func():
		if is_instance_valid(mi):
			_shell_open(pj, mi)
		if pj.live(c) and c.get("model"):
			c.model.visible = true
		if is_instance_valid(furrow):
			_fade_free(furrow, 2.5, 0.8)
		_dust(pj, c.global_position, 6, 1.6, 0.4, 0.6, 0.6))


static func _shell_ball(pj: PathJutsu, p: Vector3) -> MeshInstance3D:
	var k = "mesh:isobu_ball"
	if not _c.has(k):
		var b = MB.new()
		var shell = Color(0.42, 0.45, 0.4)
		var plate = Color(0.32, 0.35, 0.31)
		var spike = Color(0.86, 0.82, 0.7)
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 3.0, shell, Vector3.ZERO, 14)
		var rng = RandomNumberGenerator.new()
		rng.seed = 31
		for i in 9:
			var dv = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var bb = _basis_y(dv)
			b.add_xf("sphere", Transform3D(Basis(bb.x * 1.1, bb.y * 0.2, bb.z * 0.9), dv * 1.45), plate, 8)
		for i in 22:
			var dv = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var bb = _basis_y(dv)
			b.add_xf("cone", Transform3D(Basis(bb.x * 0.35, bb.y * 1.0, bb.z * 0.35), dv * 1.6), spike, 5)
		_c[k] = b.build(null)
	return _spawn(pj, _c[k], _toon(0.05), p, NEAR_M)


static func _shell_hit(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var s = _face_sheet(pj, p, 1.0, 8, Color(0.96, 0.98, 0.96), Color(0.1, 0.18, 0.16, 1.0), NEAR_M)
	_anim_sheet(s, 0.0, 1.0, 0.05, 0.05, 0.15)
	_burst_lines(pj, p, 6, 0.4, 1.0, 0.22, Color(0.95, 0.97, 0.95), 0.08, d, 70.0)
	_chips(pj, p, 5, 6.0, 0.18, 1.0, d * 2.0)


static func _shell_open(pj: PathJutsu, mi: MeshInstance3D) -> void:
	var p = mi.global_position
	for i in 6:
		var sh = _spawn(pj, _shard_mesh(), _toon(0.03), p, NEAR_M)
		sh.scale = Vector3(0.9, 0.5, 0.2) * randf_range(0.7, 1.2)
		var v = Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized() * randf_range(3.0, 5.0)
		_fly(sh, p, v, 0.7, Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)))
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


# ================================================================== 10) Ino–Shika–Chō Düzeni
## ref: üç kişinin başı üstünde ak çizgili klan armaları (Yamanaka yeşil, Nara kızıl, Akimichi mavi parıltı) ve arkalarında
## renkli chakra fışkırması. Nara: yerde yırtık kenarlı gölge şeridi hedefe uzanır, altında gölge havuzu; Yamanaka: sarı ruh
## oku hedefin başına girer, titreşen halkalar; Akimichi: bandajlı dev yumruk tepeden iner, krater + çatlak + toz
static func formation_ino_shika_cho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var clan = String(Game.profile.get("clan", "")) if c is Player else String(c.get("arch").get("clan", "")) if c.get("arch") is Dictionary else ""
	if not clan in ["yamanaka", "nara", "akimichi"]:
		if c is Player:
			Hud.msg("Ino–Shika–Chō düzeni yalnız Yamanaka, Nara ya da Akimichi klanından biri yapabilir.", Color(1.0, 0.7, 0.4))
		return
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 1.6)
	if tt == null:
		return
	var at = tt.global_position
	var d = pj.fwd(c, tt)
	var sd = d.cross(Vector3.UP).normalized()
	# yoldaşlar (gölge klon görünüşünde) iki yanda belirir
	var mates = []
	for sx in [-1.0, 1.0]:
		var q = pj.gp(c.global_position + sd * sx * 2.0)
		_mate_arrive(pj, q)
		mates.append(pj.decoy(c, q, 1.8))
	_trio_crests(pj, c, mates, clan)
	# 1) Nara: gölge rakibe uzanıp bağlar
	_shadow_bind(pj, c, tt, at, 1.5)
	pj.st(tt, "bind", 1.5)
	Combat.popup_text(at + Vector3.UP * 2.4, "Kagemane!", Color(0.6, 0.6, 0.7))
	# 2) Yamanaka: zihin karışır (sersem)
	pj.after(0.45, func():
		if pj.live(tt):
			pj.st(tt, "stun", 1.0)
			_soul_streak(pj, c, tt, 0.14, Color(1.0, 0.9, 0.5), Color(0.6, 0.4, 0.05, 0.95), 0.12)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Shinranshin!", Color(1.0, 0.85, 0.4)))
	# 3) Akimichi: dev yumruk tepeden ezer
	pj.after(0.95, func():
		if not pj.live(tt) or not pj.live(c):
			return
		var fm = _giant_fist(pj, tt.global_position + Vector3.UP * 7.0)
		var tw = fm.create_tween()
		tw.tween_property(fm, "global_position", tt.global_position + Vector3.UP * 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "formation_ino_shika_cho", 2.2, {"knock": 8.0, "launch": -6.0, "kind": "heavy", "pierce_guard": true, "hitstop": 0.12}))
			_fist_crash(pj, pj.gp(at) + Vector3.UP * 0.3)
			pj.shake(0.8))
		tw.tween_interval(0.3)
		tw.tween_callback(fm.queue_free))


static func _mate_arrive(pj: PathJutsu, q: Vector3) -> void:
	var rg = _flat_sheet(pj, q + Vector3.UP * 0.05, Vector3.UP, 1.0, 0, Color(0.85, 0.88, 0.8, 0.8), INK, NEAR_M, 0.2)
	_anim_sheet(rg, 0.2, 1.0, 0.2, 0.0, 0.2)
	var mi = _spike_mi(pj, q + Vector3.UP * 2.2, Vector3.UP, 0.18, 2.2, Color(0.95, 0.97, 0.92, 0.9))
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale:z", 0.05, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func _trio_crests(pj: PathJutsu, c: Node3D, mates: Array, clan: String) -> void:
	var order = ["yamanaka", "nara", "akimichi"]
	var modes = {"yamanaka": 3, "nara": 4, "akimichi": 5}
	var glow = {"yamanaka": Color(0.4, 1.0, 0.35, 0.75), "nara": Color(1.0, 0.3, 0.25, 0.75), "akimichi": Color(0.3, 0.6, 1.0, 0.75)}
	var rest = order.filter(func(x): return x != clan)
	var who = [[c, clan]]
	for i in mates.size():
		if i < rest.size():
			who.append([mates[i], rest[i]])
	for w in who:
		var n = w[0]
		if n == null or not is_instance_valid(n):
			continue
		var key: String = w[1]
		var col: Color = glow[key]
		var p = (n as Node3D).global_position
		var cr = _face_sheet(pj, p + Vector3.UP * 2.7, 0.55, int(modes[key]), Color(1, 1, 1, 1), col, NEAR_M, 0.07)
		_anim_sheet(cr, 0.0, 1.0, 0.2, 1.0, 0.3)
		for k in 5:
			var b = p + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4))
			var sp = _spike_mi(pj, b, Vector3.DOWN, 0.22, 0.3, Color(col.r, col.g, col.b, 0.85))
			var tw = sp.create_tween().set_parallel()
			tw.tween_property(sp, "global_position", b + Vector3.UP * 2.4, 0.45).set_delay(k * 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(sp, "scale:z", 1.6, 0.25).set_delay(k * 0.06)
			tw.tween_method(_pf(sp, "fade"), 1.0, 0.0, 0.2).set_delay(k * 0.06 + 0.25)
			tw.chain().tween_callback(sp.queue_free)


## Nara gölgesi: ayaktan hedefe yerde uzanan yırtık kenarlı kara şerit + hedefin altında gölge havuzu
static func _shadow_bind(pj: PathJutsu, c: Node3D, tt: Node3D, at: Vector3, dur: float) -> void:
	var mi = _ribbon(pj, NEAR_M)
	_style_rib(mi, Color(0.03, 0.03, 0.05, 0.88))
	var cw = weakref(c)
	var tw_ = weakref(tt)
	var last = {"a": c.global_position, "b": at}
	var build = func(u: float) -> Array:
		var x = cw.get_ref()
		var y = tw_.get_ref()
		if x != null and is_instance_valid(x):
			last["a"] = (x as Node3D).global_position
		if pj.live(y):
			last["b"] = (y as Node3D).global_position
		var pa: Vector3 = last["a"]
		var pb: Vector3 = last["b"]
		var reach = clampf(u * dur / 0.15, 0.0, 1.0)
		var al = 1.0 - clampf((u - 0.85) / 0.15, 0.0, 1.0)
		var n = 14
		var pts = []
		var ws = []
		for i in n:
			var k = float(i) / float(n - 1) * reach
			var q = pa.lerp(pb, k)
			pts.append(Vector3(q.x, Game.jutsu_floor(q.x, q.z) + 0.03, q.z))
			ws.append(0.34 + 0.08 * sin(k * 23.0 + u * 30.0))
		return [pts, ws, _fill(n, Color(1, 1, 1, al)), Vector3.UP]
	_live_ribbon(pj, mi, dur, build)
	var pool = _flat_sheet(pj, pj.gp(at) + Vector3.UP * 0.04, Vector3.UP, 0.8, 10, Color(0.03, 0.03, 0.05, 0.85), INK, NEAR_M)
	_anim_sheet(pool, 0.0, 1.0, 0.18, dur - 0.4, 0.2, 0.12)


static func _giant_fist(pj: PathJutsu, p: Vector3) -> Node3D:
	var k = "mesh:chouji_fist"
	if not _c.has(k):
		var fist = MB.new()
		var sk = Color(0.93, 0.78, 0.66)
		var wrp = Color(0.92, 0.9, 0.85)
		Loft.tube(fist, [Vector3(0, 6.0, 0), Vector3(0, 3.5, 0), Vector3(0, 1.4, 0)], [Vector2(0.9, 0.9), Vector2(0.95, 0.95), Vector2(1.0, 1.0)], [wrp, wrp, sk], 12, 4, true, false,
			func(t2: float, _a: float, _d: Vector3) -> Color: return wrp.darkened(0.15) if fposmod(t2 * 9.0, 1.0) < 0.18 else (wrp if t2 < 0.75 else sk))
		fist.add("sphere", Vector3(0, 0.6, 0), Vector3(2.4, 2.0, 2.2), sk, Vector3.ZERO, 12)
		for i in 4:
			fist.add("sphere", Vector3((i - 1.5) * 0.5, -0.15, 0.75), Vector3(0.55, 0.5, 0.5), sk.darkened(0.08), Vector3.ZERO, 8)
		_c[k] = fist.build(null)
	return _spawn(pj, _c[k], _toon(0.06), p, NEAR_M)


static func _fist_crash(pj: PathJutsu, p: Vector3) -> void:
	var g = pj.gp(p)
	var cr = _flat_sheet(pj, g + Vector3.UP * 0.035, Vector3.UP, 2.3, 1, Color(0.66, 0.56, 0.44, 0.85), Color(0.15, 0.1, 0.07, 0.9), NEAR_M, 0.2)
	_anim_sheet(cr, 0.3, 0.9, 0.1, 3.0, 0.8)
	_cracks(pj, g, 3.4, 8, 3.0)
	var rg = _flat_sheet(pj, g + Vector3.UP * 0.06, Vector3.UP, 4.2, 0, Color(0.95, 0.9, 0.8, 0.85), INK, NEAR_M, 0.12)
	_anim_sheet(rg, 0.1, 1.0, 0.3, 0.0, 0.25)
	var s = _face_sheet(pj, p + Vector3.UP * 0.6, 1.6, 8, Color(0.75, 0.86, 1.0), INK, NEAR_M)
	_anim_sheet(s, 0.0, 1.0, 0.06, 0.06, 0.16)
	_dust(pj, g, 10, 3.0, 0.7, 0.8, 0.8)
	_chips(pj, g + Vector3.UP * 0.2, 12, 7.0, 0.28)
	_flash(pj, p + Vector3.UP, Color(1.0, 0.95, 0.85), 2.5, 8.0, 0.3)
	pj.shake(0.45)


# ================================================================== 11) Uchiha Ryū Kenjutsu
## ref: Sasuke çekip geçer, kılıcı omzunda, ayağından toz kalkar; hedef bir an sonra kesilir. Gözde kızıl ışıltı, iai
## duruşunda kılıçta kısa mavi çıtırtılar, geçişte ince ak-mavi yol çizgisi, gecikmeli düz çapraz kesik + kan damlaları
static func uchiha_ryu_kenjutsu(pj: PathJutsu, c: Node3D, t: Node3D, with_eyes := true) -> void:
	if with_eyes:
		_red_eyes(pj, c, 1.5)
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.0)
	if c.get("model"):
		c.model.hold_temp("katana", 1.1, "Right", 1.0, 0.0, false, true)
		c.model.play("crouch", 0.05, 1.0)
	var blue = CUT_BLUE
	# iai duruşu: el kabzada, kılıç boyunca şimşek
	pj.every(0.35, 0.05, func(_i, _k):
		if is_instance_valid(c):
			var h = Jutsu._hand(c)
			_zig(pj, h, h + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.5), randf_range(-0.6, 0.6)), blue, 0.05, 0.08))
	Sfx.play("chidori", c.global_position, 1.6, 0.4)
	pj.after(0.35, func():
		if not is_instance_valid(c):
			return
		var from = c.global_position
		var dist = (from.distance_to(tt.global_position) + 3.0) if pj.live(tt) else 9.0
		var dur = clampf(dist / 70.0, 0.08, 0.26)
		pj.anim(c, "slash_c", 3.0)
		if c is Player:
			c.combat.invuln = maxf(c.combat.invuln, dur + 0.1)
		var hits = []
		Sfx.play("throw_kunai", from, 1.4)
		var dd = pj._aim_tt(c, t, tt, from + Vector3.UP)
		dd.y = 0.0
		dd = dd.normalized()
		if "facing" in c:
			c.facing = atan2(-dd.x, -dd.z)
		var dest = pj.gp(from + dd * dist)
		_dust(pj, pj.gp(from), 3, 0.5, 0.25, 0.5, 0.45, DUST_C, -dd * 1.0)
		var tw = c.create_tween()
		tw.tween_method(func(x: float):
			if not is_instance_valid(c):
				return
			var p = from.lerp(dest, x)
			p.y = maxf(p.y, Game.jutsu_floor(p.x, p.z))
			c.global_position = p
			if "velocity" in c:
				c.velocity = Vector3.ZERO
			var hp = p + Vector3.UP * 1.0
			for e in pj.hit(c, hp, 1.8, pj.inf(c, "uchiha_ryu_kenjutsu", 1.4, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.7, "hitstop": 0.1}), hits):
				hits.append(e)
			if randf() < 0.5:
				_zig(pj, hp, hp + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.6), randf_range(-1, 1)), blue, 0.06, 0.12), 0.0, 1.0, dur)
		tw.tween_callback(func():
			if not is_instance_valid(c):
				return
			var to = c.global_position
			# geçilen yol boyunca ince ak-mavi kesik izi
			_iai_trace(pj, from + Vector3.UP * 1.1, to + Vector3.UP * 1.1)
			# gecikmeli kesik: hedefin üzerinde açılır
			pj.after(0.22, func():
				for e in hits:
					if pj.live(e):
						var q = e.global_position + Vector3.UP * 1.1
						_iai_cut(pj, q, (to - from).normalized())
						for k in 4:
							_zig(pj, q, q + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * 2.0, blue, 0.08, 0.2)
				if not hits.is_empty():
					pj.shake(0.4)
					Sfx.play("thunder", to, 1.6, 0.4))))


## Kızıl göz ışıltısı (kafa kemiğine bağlı iki küçük parlak nokta)
static func _red_eyes(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var b = MB.new()
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(float(sx) * 0.032, 0.065, 0.095), Vector3(0.022, 0.016, 0.008), Color.WHITE, Vector3.ZERO, 6)
	var mi = _spawn(pj, b.build(null), _sm("rib", RIB_SH), Vector3.ZERO, Vector2(0.3, 0.8), hb)
	_style_rib(mi, Color(1.0, 0.12, 0.1, 1.0))
	pj.free_after(dur, hb)


static func _iai_trace(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var n = 6
	var pts = []
	var ws = []
	for i in n:
		var k = float(i) / float(n - 1)
		pts.append(a.lerp(b, k))
		ws.append(0.09 * sin(k * PI) + 0.01)
	var mi = _ribbon(pj, NEAR_S)
	_style_rib(mi, Color(0.96, 0.98, 1.0, 0.95), 0.4, Color(0.25, 0.45, 0.9, 1.0))
	_redraw(mi, pts, ws, _fill(n, Color(1, 1, 1, 1)), _cam(pj))
	_fade_free(mi, 0.05, 0.3)
	_speed_lines(pj, b - (b - a).normalized() * 0.5, (b - a), 4, 1.8, 0.35, 0.25, Color(0.9, 0.95, 1.0), 0.04)


## Gecikmeli iai kesiği: gövdeyi çapraz geçen düz, iki ucu sivri ak çizgi (mavi kenar) + iki yana açılan yarımlar + kan damlaları
static func _iai_cut(pj: PathJutsu, q: Vector3, dir: Vector3) -> void:
	var sd = dir.cross(Vector3.UP).normalized()
	if sd.length() < 0.01:
		sd = Vector3.RIGHT
	var rr = deg_to_rad(-20.0)
	var ax = (sd * cos(rr) + Vector3.UP * sin(rr)).normalized()
	var off = ax.cross(dir).normalized() * 0.05
	for half in 2:
		var n = 7
		var pts = []
		var ws = []
		for i in n:
			var k = float(i) / float(n - 1)
			pts.append(q + ax * lerpf(-1.25, 1.25, k))
			ws.append(0.14 * pow(sin(k * PI), 0.6) * (1.0 if half == 0 else 0.55))
		var mi = _ribbon(pj, NEAR_S)
		_style_rib(mi, Color(1, 1, 1, 0.98) if half == 0 else Color(0.85, 0.93, 1.0, 0.8), 0.35, Color(0.2, 0.4, 0.9, 1.0))
		_redraw(mi, pts, ws, _fill(n, Color(1, 1, 1, 1)), _cam(pj))
		var tw = mi.create_tween().set_parallel()
		var sgn = 1.0 if half == 0 else -1.0
		tw.tween_property(mi, "position", off * sgn * 3.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.25).set_delay(0.12)
		tw.chain().tween_callback(mi.queue_free)
	for i in 6:
		var dr = _spawn(pj, _lump(), _sm("dust", DUST_SH), q, NEAR_S)
		dr.set_instance_shader_parameter("tint", Color(0.72, 0.04, 0.07, 1.0))
		dr.scale = Vector3.ONE * randf_range(0.05, 0.09)
		var v = (ax * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(0.3, 1.0) + dir * randf_range(0.2, 0.8)).normalized() * randf_range(2.0, 4.0)
		_fly(dr, q, v, 0.6, Vector3.ZERO)


# ================================================================== 12) Shindenshin no Jutsu
## ref: Inoichi elini başa koyar, zihinler bağlanır (görünür dalga yok). Alında küçük Yamanaka elmas mührü, her düşmana
## ince, dalgalı mor zihin ipi uzanıp söner; işaret: başın üstünde dönen küçük elmas (15 sn)
static func shindenshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D, with_seal := true) -> void:
	if with_seal:
		pj._yama_seal(c)
	var sig = _face_sheet(pj, c.global_position + Vector3.UP * 1.65 + c.face_dir() * 0.3, 0.3, 7, Color(1, 1, 1, 1), Color(MIND.r, MIND.g, MIND.b, 0.7), NEAR_S, 0.08)
	_anim_sheet(sig, 0.0, 1.0, 0.15, 0.3, 0.3)
	var n = 0
	for e in pj.enemies_near(c, c.global_position, 60.0):
		pj.st(e, "marked", 15.0)
		# zihin ağıyla aktarılan konum: başın üstünde küçük işaret (12 m ışık sütunu animede yok)
		var mk = _mind_marker()
		pj.attach(e, mk, 15.0, Vector3.UP * (e.height + 0.9), 2)
		if is_instance_valid(mk) and mk.is_inside_tree():
			var tw = Game.safe_loops(mk.create_tween())
			tw.tween_property(mk, "rotation:y", TAU, 2.4).from(0.0)
		if n < 8:
			_mind_thread(pj, c, e, 0.9, MIND, n * 0.04)
		n += 1
	Hud.msg("Zihin ağı: düşmanların yerini görüyorsun", Color(0.85, 0.7, 1.0))
	Sfx.play("genjutsu", c.global_position, 1.5)


static func _mind_marker() -> Node3D:
	var k = "mesh:mind_marker"
	if not _c.has(k):
		var b = MB.new()
		b.add("cone", Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), MIND, Vector3.ZERO, 4)
		b.add("cone", Vector3(0, -0.14, 0), Vector3(0.3, 0.28, 0.3), MIND.darkened(0.25), Vector3(180, 0, 0), 4)
		_c[k] = b.build(null)
	var mi = MeshInstance3D.new()
	mi.mesh = _c[k]
	mi.material_override = _toon(0.015)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("nearz", NEAR_S)
	return mi


# ================================================================== 13) Shindenshōsen Jutsu
## ref (oyun): Ino'nun çevresinde yeşil şifa alanı, havada yeşil zerreler, iyileşen dostların ayağında mavi halka.
## Avuçta yeşil ışık, şifa anlarında kullanıcıdan dostlara yeşil akan bağ, zerreler yükselir
static func shindenshosen_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 4.0)
	pj._yama_seal(c)
	Sfx.play("heal", c.global_position, 1.0)
	var field = _flat_sheet(pj, pj.gp(c.global_position) + Vector3.UP * 0.05, Vector3.UP, 4.2, 6, Color(0.45, 1.0, 0.55, 0.35), Color(0.75, 1.0, 0.78, 0.7), NEAR_M)
	_anim_sheet(field, 0.1, 1.0, 0.5, 3.0, 0.5)
	_palm_glow(pj, c, 4.0)
	var mend = func(i, _k):
		if not pj.live(c):
			return
		if "velocity" in c:
			c.velocity = Vector3.ZERO
		if i % 2 == 0:
			_mote(pj, c.global_position + Vector3(randf_range(-2.5, 2.5), 0.2, randf_range(-2.5, 2.5)), HEAL_G, 0.08, randf_range(1.0, 2.0), 0.9)
		if i % 5 == 4:
			var who = [c]
			for f in pj.get_tree().get_nodes_in_group("fighters"):
				if f != c and is_instance_valid(f) and not f.is_dead() and f.get("team") == c.get("team") and f.global_position.distance_to(c.global_position) < 30.0:
					who.append(f)
			for f in who:
				if f.hp < f.max_hp:
					pj.heal(f, f.max_hp * 0.035)
					_mend_mark(pj, c, f)
	pj.every(4.0, 0.1, mend, Callable())


static func _palm_glow(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var orb = _spawn(pj, _lump(), _sm("spirit", SPIRIT_SH), Vector3(0, 0.08, 0), NEAR_S, ba)
	orb.set_instance_shader_parameter("tint", Color(0.7, 1.0, 0.72, 0.7))
	orb.set_instance_shader_parameter("rim", Color(0.15, 0.6, 0.25, 0.9))
	orb.scale = Vector3.ONE * 0.16
	var tw = Game.safe_loops(orb.create_tween())
	tw.tween_property(orb, "scale", Vector3.ONE * 0.22, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.15, 0.35).set_trans(Tween.TRANS_SINE)
	var l = OmniLight3D.new()
	l.light_color = HEAL_G
	l.light_energy = 1.2
	l.omni_range = 2.5
	l.shadow_enabled = false
	ba.add_child(l)
	pj.free_after(dur, ba)


static func _mend_mark(pj: PathJutsu, c: Node3D, f: Node3D) -> void:
	var g = pj.gp(f.global_position) + Vector3.UP * 0.05
	var rg = _flat_sheet(pj, g, Vector3.UP, 0.85, 0, Color(0.45, 0.78, 1.0, 0.9), Color(0.15, 0.35, 0.8, 1.0), NEAR_M, 0.12)
	_anim_sheet(rg, 0.4, 1.0, 0.2, 0.2, 0.2)
	for i in 3:
		_mote(pj, f.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.4, 1.2), randf_range(-0.35, 0.35)), HEAL_G, 0.06, 0.9, 0.7)
	if f != c:
		var a = c.global_position + Vector3.UP * 1.2
		var b = f.global_position + Vector3.UP * 1.1
		var n = 8
		var pts = []
		for i in n:
			var k = float(i) / float(n - 1)
			pts.append(a.lerp(b, k) + Vector3.UP * sin(k * PI) * 0.4)
		var mi = _ribbon(pj, NEAR_M)
		_style_rib(mi, Color(0.55, 1.0, 0.6, 0.75), 0.3, Color(0.1, 0.45, 0.2, 0.9), 4.0)
		_redraw(mi, pts, _fill(n, 0.06), _fill(n, Color(1, 1, 1, 1)), _cam(pj))
		_fade_free(mi, 0.15, 0.3)


# ================================================================== 14) Chakura Kami Torappu
## ref: Ino'nun kestiği ak/sarı saç telleri yere serpilir, üstlerinden mavi chakra akımı yılan gibi kıvrılarak hedefe akar.
## Basan rakibin bacaklarına mavi ve saç renginde teller sarmal sarılır
static func chakura_kami_torappu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 14.0)
	var d = pj._face(c, tt)
	var hair: Color = c.model.look.get("hair", Color(0.95, 0.86, 0.5)) if c.get("model") else Color(0.95, 0.86, 0.5)
	var goal: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + d * 8.0)
	var from = pj.gp(c.global_position + d * 0.5)
	Sfx.play("throw_kunai", c.global_position, 1.4, 0.5)
	_hair_bed(pj, from, goal, d, hair, 4.2)
	var snare = func(_i, _k):
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, goal, 1.6):
			if not e.has_status("bind"):
				pj.st(e, "bind", 3.5)
				pj.st(e, "marked", 3.5)   # kıpırdayamayan kolay hedef
				_hair_wrap(pj, e, hair, 3.5)
				Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Saç tuzağı!", Color(0.95, 0.9, 0.6))
	pj.every(4.0, 0.15, snare, Callable())


static func _hair_bed(pj: PathJutsu, from: Vector3, goal: Vector3, d: Vector3, hair: Color, life: float) -> void:
	var side = d.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var mb = MB.new()
	# uzun teller: yere yapışık, ince, hafif dalgalı
	for k in 9:
		var pts = []
		var rr = []
		var sw = randf_range(-0.6, 0.6)
		var end = goal + side * randf_range(-0.5, 0.5) + d * randf_range(-0.3, 0.5)
		for j in 12:
			var u = j / 11.0
			var p = from.lerp(end, u) + side * (sin(u * PI * 2.0 + k) * 0.12 + sw * sin(u * PI))
			p.y = Game.jutsu_floor(p.x, p.z) + 0.04
			pts.append(p)
			rr.append(Vector2(0.012, 0.012))
		Loft.tube(mb, pts, rr, hair, 4, 1)
	# kısa serpili teller (ref: yol boyunca dağınık ak ve koyu kıl)
	for k in 24:
		var u = randf()
		var c0 = from.lerp(goal, u) + side * randf_range(-0.7, 0.7)
		var ang = randf() * TAU
		var dl = Vector3(cos(ang), 0, sin(ang)) * randf_range(0.25, 0.55)
		var a = c0 - dl * 0.5
		var b = c0 + dl * 0.5
		a.y = Game.jutsu_floor(a.x, a.z) + 0.035
		b.y = Game.jutsu_floor(b.x, b.z) + 0.035
		var m = (a + b) * 0.5 + side * randf_range(-0.05, 0.05)
		Loft.tube(mb, [a, m, b], [0.009, 0.009, 0.009], hair if k % 3 != 0 else hair.darkened(0.55), 4, 1)
	var root = Node3D.new()
	pj.scene_add(root, Vector3.ZERO)
	var strands = _spawn(pj, mb.build(null), _sm("rib", RIB_SH), Vector3.ZERO, NEAR_S, root)
	_style_rib(strands, Color(1, 1, 1, 1))
	# mavi chakra akımı: tellerin üstünde kıvrılarak hedefe akar
	var flow = _ribbon(pj, NEAR_S)
	flow.reparent(root)
	_style_rib(flow, Color(0.5, 0.78, 1.0, 0.9), 0.3, Color(0.15, 0.35, 0.85, 1.0), 3.0)
	var n = 22
	var base = []
	for i in n:
		var u = float(i) / float(n - 1)
		var p = from.lerp(goal, u) + side * sin(u * PI * 3.0) * 0.35
		p.y = Game.jutsu_floor(p.x, p.z) + 0.06
		base.append(p)
	var fw = weakref(flow)
	var tw = flow.create_tween()
	tw.tween_method(func(r: float) -> void:
		var x = fw.get_ref()
		if x == null or not is_instance_valid(x):
			return
		var m = maxi(2, int(ceil(r * n)))
		var pts = base.slice(0, m)
		var ws = []
		for i in m:
			ws.append(0.13 if i < m - 1 else 0.05)
		_redraw(x as MeshInstance3D, pts, ws, _fill(m, Color(1, 1, 1, 1)), _cam(pj), Vector3.UP), 0.0, 1.0, 0.25)
	_fade_tree(root, maxf(life - 0.5, 0.1), 0.5)


static func _hair_wrap(pj: PathJutsu, e: Node3D, hair: Color, dur: float) -> void:
	var root = Node3D.new()
	e.add_child(root)
	root.position = Vector3.ZERO
	var rr = _rad(e) * 0.75
	var mb = MB.new()
	for s in 3:
		var pts = []
		var rad = []
		for j in 14:
			var u = j / 13.0
			var a = u * TAU * 2.2 + s * TAU / 3.0
			pts.append(Vector3(cos(a) * rr, 0.05 + u * 0.85, sin(a) * rr))
			rad.append(0.012 if s < 2 else 0.02)
		Loft.tube(mb, pts, rad, hair if s < 2 else Color(0.5, 0.78, 1.0), 4, 1)
	var mi = _spawn(pj, mb.build(null), _sm("rib", RIB_SH), Vector3.ZERO, NEAR_S, root)
	_style_rib(mi, Color(1, 1, 1, 1))
	root.scale = Vector3(1, 0.05, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.5, 0.05))
	tw.tween_method(func(v: float) -> void: _set_tree(root, "fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(root.queue_free)
	var rg = _flat_sheet(pj, pj.gp(e.global_position) + Vector3.UP * 0.05, Vector3.UP, 0.9, 0, Color(0.5, 0.78, 1.0, 0.9), Color(0.15, 0.35, 0.85, 1.0), NEAR_M, 0.16)
	_anim_sheet(rg, 0.2, 1.0, 0.2, 0.0, 0.25)


# ================================================================== 15) Shinten Bunshin no Jutsu
## Ruh izi: kullanıcının göğsünden açık mavi, kristalimsi ruh kuyruklu yıldız gibi kavisle hedefin başına girer, giriş
## anında başta titreşen halkalar; ele geçirilen hedef kendi dostuna saldırırken aralarında mor zihin ipi
static func shinten_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D, with_seal := true) -> void:
	if with_seal:
		pj._yama_seal(c)
	var tt = pj.tg(c, t, 20.0)
	if tt == null or not tt is Enemy:
		return
	var others = pj.enemies_near(c, tt.global_position, 25.0).filter(func(e): return e != tt)
	var sdur = clampf((Jutsu._hand(c) + Vector3.UP * 0.2).distance_to(tt.global_position) / 30.0, 0.15, 0.7)
	_soul_streak(pj, c, tt, sdur, SOUL, Color(0.2, 0.4, 0.85, 0.95), 0.22)
	pj._mind_orb(c, tt, func(): if is_instance_valid(tt): pj._mind_halo(tt, 1.6))
	if others.is_empty():
		pj.st(tt, "stun", 2.5)
		return
	var old = tt.team
	tt.team = c.team
	var jl: Array = tt.arch.get("jutsu", []) if tt.get("arch") else []
	if jl.is_empty():
		pj.hit(tt, others[0].global_position + Vector3.UP, 1.5, pj.inf(c, "shinten_bunshin_no_jutsu", 1.4, {"knock": 8.0, "kind": "heavy"}))
	else:
		Jutsu.execute(tt, jl.pick_random(), others[0])
	_mind_thread(pj, tt, others[0], 0.8, MIND, sdur, 0.045)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Kendi dostuna saldırdı!", Color(0.8, 0.6, 1))
	pj.after(1.2, func():
		if is_instance_valid(tt):
			tt.team = old
			pj.st(tt, "stun", 1.5))
