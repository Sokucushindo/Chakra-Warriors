class_name TaijutsuFXA
extends RefCounted
## Taijutsu / kenjutsu grubu A: on beş yakın dövüş tekniğinin görselleri. Işık şovu yok: hız çizgileri, ardıl görüntüler,
## anime "çarpma karesi" şok dikenleri, cel toz, zemin çatlağı / göçük, kaya parçası ve kılıç yayı izleri — hepsi bu dosyada,
## kendi gölgelendiricileriyle sıfırdan. Her teknik kendi sahnelemesini kurar (çarpma düzeni, iz şekli, sarsıntı ayrı).
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const UP := Vector3.UP

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

## Kameraya dönük düzlem + kameraya yaklaşınca küçülme (ekranı kaplamasın)
const BBV := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	VERTEX *= clamp(length(MODELVIEW_MATRIX[3].xyz) / 7.0, 0.35, 1.0);
"""

## Mürekkep şerit: kılıç yayı, hız çizgisi, şok dikeni. UV.x boyunca açılır (k_grow), baş (u=1) en dolu; kenarda koyu mürekkep bandı.
const INK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 k_edge = vec4(0.2, 0.22, 0.3, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_tail = 0.0;
void vertex() {
//BB
}
void fragment() {
	float age = k_grow - UV.x;
	if (age < 0.0) {
		discard;
	}
	float tail = pow(clamp(1.0 - age * k_tail, 0.0, 1.0), 1.4);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float body = smoothstep(0.0, 0.2, across);
	vec3 col = mix(k_edge.rgb, k_col.rgb * COLOR.rgb, smoothstep(0.18, 0.42, across));
	float nfade = smoothstep(0.9, 3.2, length(VERTEX));
	ALBEDO = col;
	ALPHA = clamp(k_a * COLOR.a * tail * body * nfade, 0.0, 1.0);
}
"""

## Cel toz bulutu: kameraya dönük, loblu kenar, iki ton + koyu kenar; k_a düşünce kenardan içe doğru dağılır
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.86, 0.77, 0.6, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void vertex() {
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float lobes = 0.78 + 0.12 * sin(ang * 5.0 + k_seed * 6.0) + 0.1 * (vnz(vec2(ang * 2.0, k_seed)) - 0.5);
	if (r > lobes) {
		discard;
	}
	float dn = vnz(p * 3.0 + k_seed * 10.0);
	if (dn * 0.9 + 0.1 > k_a + (1.0 - r / lobes) * 0.35) {
		discard;
	}
	float lit = step(0.0, p.y * 0.7 + p.x * 0.3 + (dn - 0.5) * 0.5 + 0.05);
	vec3 col = mix(k_col.rgb * 0.74, k_col.rgb, lit);
	if (r > lobes - 0.07) {
		col *= 0.62;
	}
	ALBEDO = col;
	ALPHA = smoothstep(0.8, 3.0, length(VERTEX));
}
"""

## Ardıl görüntü: donmuş beden pozu, saydam, kenarı açık, yatay hız taramalı
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.4, 0.45, 0.6, 1.0);
instance uniform float k_a = 0.5;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float band = step(0.35, fract(wpos.y * 9.0));
	ALBEDO = mix(k_col.rgb * 0.55, vec3(0.5) + k_col.rgb * 0.5, fr);
	ALPHA = clamp(k_a * (0.3 + 0.7 * fr) * (0.55 + 0.45 * band) * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Zemin izi: 0 yıldız çatlak, 1 uzun yarık (yerel z boyunca), 2 tuğla halkalı göçük, 3 dört pençe oyuğu, 4 sürtme izi
const DECAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.07, 0.05, 0.04, 1.0);
instance uniform vec4 k_gnd = vec4(0.5, 0.4, 0.3, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_mode = 0.0;
instance uniform float k_seed = 0.0;
instance uniform float k_n = 9.0;
NOISE
float cracks(vec2 p, float n, float sd, float r0, float wid) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = a / 6.2831853 * n;
	float id = floor(s);
	float wob = (vnz(vec2(r * 4.0 + sd, id * 1.7 + sd)) - 0.5) * 0.55 + (vnz(vec2(r * 13.0, id * 3.1 + sd)) - 0.5) * 0.2;
	float f = fract(s + wob) - 0.5;
	float d = abs(f) * 6.2831853 / n * r;
	float len = 0.5 + 0.5 * hsh(vec2(id, sd));
	float w = wid * clamp(1.0 - r / len, 0.0, 1.0) + 0.002;
	if (r < r0 || r > len) {
		return 0.0;
	}
	return 1.0 - smoothstep(w * 0.55, w, d);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	int md = int(k_mode + 0.5);
	vec3 col = k_col.rgb;
	float a = 0.0;
	float reveal = r;
	if (md == 0) {
		a = max(cracks(p, k_n, k_seed, 0.03, 0.03), cracks(p, k_n * 2.0, k_seed + 5.0, 0.25, 0.018) * 0.85);
		float pit = 1.0 - smoothstep(0.06, 0.16, r);
		if (pit > a) {
			a = pit * 0.8;
			col = k_gnd.rgb * 0.45;
		}
	} else if (md == 1) {
		float z = abs(p.y);
		float x = p.x + (vnz(vec2(p.y * 6.0, k_seed)) - 0.5) * 0.14 + (vnz(vec2(p.y * 21.0, k_seed + 3.0)) - 0.5) * 0.05;
		float w = 0.08 * pow(clamp(1.0 - z, 0.0, 1.0), 0.8) + 0.003;
		float core = 1.0 - smoothstep(w * 0.7, w, abs(x));
		float lip = (1.0 - smoothstep(w, w * 2.2, abs(x))) * 0.55;
		float br = max(cracks((p - vec2(0.0, 0.45)) * 2.6, 6.0, k_seed + 2.0, 0.05, 0.03), cracks((p + vec2(0.0, 0.5)) * 2.6, 6.0, k_seed + 9.0, 0.05, 0.03));
		a = max(core, br);
		if (lip > a) {
			a = lip;
			col = k_gnd.rgb * 0.55;
		}
		reveal = z;
	} else if (md == 2) {
		if (r < 0.34) {
			col = k_gnd.rgb * (0.42 + 0.35 * r / 0.34);
			a = 0.92;
			if (cracks(p, 7.0, k_seed + 4.0, 0.02, 0.025) > 0.5) {
				col = k_col.rgb;
			}
		} else if (r < 0.52) {
			float row = floor((r - 0.34) / 0.06);
			float ang = atan(p.y, p.x) / 6.2831853 * (22.0 + row * 4.0) + row * 0.5;
			float ring_l = abs(fract((r - 0.34) / 0.06) - 0.5);
			float rad_l = abs(fract(ang) - 0.5);
			float ln = max(smoothstep(0.4, 0.48, ring_l), smoothstep(0.43, 0.49, rad_l));
			col = mix(k_gnd.rgb * (0.66 + 0.14 * hsh(vec2(floor(ang), row + k_seed))), k_col.rgb, ln);
			a = 0.9;
		} else {
			a = cracks(p, k_n, k_seed, 0.5, 0.025);
		}
	} else if (md == 3) {
		float lw = 0.06 * pow(clamp(1.0 - abs(p.y), 0.0, 1.0), 0.6);
		for (int i = 0; i < 4; i++) {
			float xi = (float(i) - 1.5) * 0.24 + p.y * p.y * 0.18;
			a = max(a, 1.0 - smoothstep(lw * 0.6, lw, abs(p.x - xi)));
		}
		reveal = (p.y + 1.0) * 0.5;
	} else {
		float w = 0.5 * (1.0 - smoothstep(0.6, 1.0, abs(p.y)));
		float streak = vnz(vec2(p.x * 18.0, k_seed)) * 0.6 + 0.4;
		a = (1.0 - smoothstep(w * 0.4, w, abs(p.x))) * 0.45 * streak;
		col = k_gnd.rgb * 0.62;
		reveal = (p.y + 1.0) * 0.5;
	}
	if (reveal > k_grow) {
		a = 0.0;
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_a, 0.0, 1.0);
}
"""

## Yaprak: köşe renkli, iki yüzlü
const LEAF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(k_a * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Hien: rüzgâr doğalı çakra bıçağı — saydam açık mavi, boyunca akan ince rüzgâr çizgileri; k_wisp: yalnız akan sarmal çizgi
const HIEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
instance uniform float k_len = 1.0;
instance uniform float k_wisp = 0.0;
NOISE
void fragment() {
	if (UV.x > k_len) {
		discard;
	}
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float streak = smoothstep(0.55, 0.85, vnz(vec2(UV.x * 14.0 - TIME * 9.0, UV.y * 7.0)));
	float flow = vnz(vec2(UV.x * 5.0 - TIME * 4.0, UV.y * 2.5));
	vec3 col;
	float a;
	if (k_wisp > 0.5) {
		float dash = smoothstep(0.35, 0.7, vnz(vec2(UV.x * 9.0 - TIME * 7.0, 0.5)));
		col = vec3(0.86, 0.96, 1.0);
		a = dash * smoothstep(0.0, 0.5, across) * (1.0 - UV.x) * 0.8;
	} else {
		col = mix(vec3(0.34, 0.62, 0.95), vec3(0.88, 0.97, 1.0), clamp(smoothstep(0.55, 0.92, across) + streak * 0.6, 0.0, 1.0));
		a = smoothstep(0.0, 0.3, across) * (0.42 + 0.3 * flow + 0.3 * streak);
		if (across < 0.14) {
			col = vec3(0.55, 0.85, 1.0);
		}
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_a * smoothstep(0.5, 2.0, length(VERTEX)), 0.0, 1.0);
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float ow = 0.03;
uniform vec3 ocol = vec3(0.08, 0.06, 0.05);
void vertex() {
	VERTEX += NORMAL * ow;
}
void fragment() {
	ALBEDO = ocol;
}
"""


# ================================================================== malzemeler
static func _sh(key0: String, code: String, bb := false) -> ShaderMaterial:
	var key = "sh:" + key0   # önbellekte aynı adlı mesh ile çakışmasın
	if _cache.has(key):
		return _cache[key]
	var s = Shader.new()
	s.code = code.replace("NOISE", NOISE).replace("//BB", BBV if bb else "")
	var m = ShaderMaterial.new()
	m.shader = s
	_cache[key] = m
	return m


static func _ink(bb := false) -> ShaderMaterial:
	return _sh("ink_bb" if bb else "ink", INK_SHADER, bb)


static func _dust_mat() -> ShaderMaterial:
	return _sh("dust", DUST_SHADER, true)


static func _ghost_mat() -> ShaderMaterial:
	return _sh("ghost", GHOST_SHADER)


static func _decal_mat() -> ShaderMaterial:
	return _sh("decal", DECAL_SHADER)


static func _leaf_mat() -> ShaderMaterial:
	return _sh("leaf", LEAF_SHADER)


static func _hien_mat() -> ShaderMaterial:
	return _sh("hien", HIEN_SHADER)


## Koyu konturlu cel malzeme (köşe renkli MB ağları için: kaya, levha, kılıç, boynuz)
static func _cel_mat() -> Material:
	if _cache.has("cel"):
		return _cache["cel"]
	var ol = ShaderMaterial.new()
	ol.shader = _sh("outline_base", OUTLINE_SHADER).shader
	ol.set_shader_parameter("ow", 0.025)
	var m = Props.toon().duplicate() as Material
	m.next_pass = ol
	_cache["cel"] = m
	return m


# ================================================================== zemin rengi
static func _pal(p: Vector3) -> Dictionary:
	var o = {"top": Color(0.42, 0.56, 0.27), "body": Color(0.56, 0.43, 0.3), "dust": Color(0.86, 0.77, 0.6)}
	if Game.world == null:
		return o
	var it = Interiors.inst
	if it and it.inside != "":
		o["top"] = Color(0.5, 0.46, 0.4)
		o["body"] = Color(0.5, 0.46, 0.42)
		o["dust"] = Color(0.78, 0.74, 0.68)
		return o
	var b = Game.biome_at(p.x, p.z)
	if b in [1, 3, 13]:
		o["top"] = Color(0.9, 0.8, 0.58)
		o["body"] = Color(0.8, 0.66, 0.45)
		o["dust"] = Color(0.95, 0.86, 0.66)
	elif b in [8, 15]:
		o["top"] = Color(0.93, 0.95, 1.0)
		o["body"] = Color(0.52, 0.52, 0.56)
		o["dust"] = Color(0.92, 0.94, 0.98)
	elif b in [5, 9, 14]:
		o["top"] = Color(0.62, 0.6, 0.56)
		o["body"] = Color(0.53, 0.5, 0.46)
		o["dust"] = Color(0.8, 0.78, 0.74)
	elif Game.road_at(p.x, p.z) > 0.3:
		o["top"] = Color(0.66, 0.55, 0.4)
	return o


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


## Örnek parametresini tween'leyen ayarlayıcı
static func _pf(mi: GeometryInstance3D, key: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(key, v)


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


static func _basis(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	return Basis.looking_at(f, UP if absf(f.y) < 0.97 else Vector3.RIGHT)


static func _rnd_dir() -> Vector3:
	var a = randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))


## Yerel yay yönü: a=0 ileri (-Z), artı açı Y çevresinde sola döner (d.rotated(UP, a) ile aynı)
static func _adir(a_deg: float) -> Vector3:
	var a = deg_to_rad(a_deg)
	return Vector3(-sin(a), 0.0, -cos(a))


static func _mk(v: PackedVector3Array, uv: PackedVector2Array, col: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
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
## Hilal yay: r yarıçap, a0→a1 (baş a1'de), w kalınlık; prof 0 = ortası geniş hilal, 1 = başı kalın (dönen uç bulanığı)
static func _arc_mesh(r: float, a0: float, a1: float, w: float, prof := 0, seg := 26) -> ArrayMesh:
	var key = "arc_%.2f_%.1f_%.1f_%.2f_%d" % [r, a0, a1, w, prof]
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var t = float(i) / seg
		var dv = _adir(lerpf(a0, a1, t))
		var th = w * (pow(sin(PI * t), 0.7) if prof == 0 else pow(t, 0.6) * (1.0 - pow(t, 8.0) * 0.6))
		v.append(dv * (r - th))
		v.append(dv * (r + th * 0.18))
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
		col.append(Color.WHITE)
		col.append(Color.WHITE)
	for i in seg:
		var b = i * 2
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


## Birim çizgi: -Z boyunca 1 uzun, çapraz iki düzlem (her açıdan görünür), iki ucu sivri
static func _strip_mesh() -> ArrayMesh:
	if _cache.has("strip"):
		return _cache["strip"]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
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
			col.append(Color.WHITE)
			col.append(Color.WHITE)
		for i in seg:
			var b = base + i * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, col, idx)
	_cache["strip"] = m
	return m


## Şok dikenleri (çarpma karesi): r0 iç halka → r1 uç; horiz: yatay düzlem (XZ), değilse XY (kameraya döner)
static func _spike_mesh(n: int, r0: float, r1: float, wdeg: float, jag: float, sd: int, horiz: bool, sector := 360.0) -> ArrayMesh:
	var key = "spk_%d_%.2f_%.2f_%.1f_%.2f_%d_%s_%.0f" % [n, r0, r1, wdeg, jag, sd, str(horiz), sector]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7919 + sd * 104729 + n * 31
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var a = deg_to_rad(-sector * 0.5 + (float(i) + 0.5 + rng.randf_range(-0.3, 0.3)) / n * sector)
		var hw = deg_to_rad(wdeg * rng.randf_range(0.6, 1.3))
		var rin = r0 * rng.randf_range(0.75, 1.1)
		var rout = r1 * rng.randf_range(1.0 - jag, 1.0 + jag * 0.5)
		for pr in [[a - hw, rin, Vector2(0.0, 0.0)], [a + hw, rin, Vector2(0.0, 1.0)], [a, rout, Vector2(1.0, 0.5)]]:
			var aa: float = pr[0]
			var rr: float = pr[1]
			v.append(Vector3(cos(aa), 0.0, sin(aa)) * rr if horiz else Vector3(cos(aa), sin(aa), 0.0) * rr)
			uv.append(pr[2])
			col.append(Color.WHITE)
		var b = i * 3
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


## Yaprak: sivri uçlu, orta damarlı, iki tonlu
static func _leaf_mesh() -> ArrayMesh:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var lt = Color(0.52, 0.8, 0.33)
	var dk = Color(0.3, 0.55, 0.2)
	var tip = Vector3(0, 0, -0.13)
	var base = Vector3(0, 0, 0.1)
	var l = Vector3(-0.055, 0, -0.01)
	var r = Vector3(0.055, 0, -0.01)
	var v := PackedVector3Array([tip, l, base, tip, base, r])
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var col := PackedColorArray([dk, dk, dk, lt, lt, lt])
	var m = _mk(v, uv, col, PackedInt32Array([0, 1, 2, 3, 4, 5]))
	_cache["leaf"] = m
	return m


## Kaya parçası (köşe renkli, konturlu); boyut düğüm ölçeğiyle
static func _chunk(s: float, col: Color) -> MeshInstance3D:
	var vr = randi() % 4
	var key = "chk_%s_%d" % [col.to_html(false), vr]
	if not _cache.has(key):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3(1.0, 0.8, 1.0), col, Vector3(vr * 40.0, vr * 70.0, 0), vr + 1)
		_cache[key] = b.build(_cel_mat())
	var mi = MeshInstance3D.new()
	mi.mesh = _cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * s
	return mi


# ================================================================== yapı taşları
## Kılıç yayı izi: hilal, a0'dan a1'e süpürülür, kısa durur, söner. roll: kesik düzlemini d ekseninde yatırır.
## o: sweep, hold, fade, tail, prof, grow_scale
static func _smear(pj: PathJutsu, at: Vector3, d: Vector3, r: float, a0: float, a1: float, w: float, col: Color, edge: Color, roll := 0.0, o := {}) -> MeshInstance3D:
	var mi = _gi(_arc_mesh(r, a0, a1, w, int(o.get("prof", 0))), _ink(false))
	_put(pj, mi, at)
	var bs = _basis(d) * Basis(Vector3(0, 0, 1), deg_to_rad(roll))
	mi.global_basis = bs
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_grow": 0.0, "k_tail": float(o.get("tail", 0.85)), "k_a": 1.0})
	var sweep = float(o.get("sweep", 0.09))
	var fade = float(o.get("fade", 0.18))
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, sweep).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(float(o.get("hold", 0.06)))
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, fade)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * float(o.get("grow_scale", 1.08)), fade)
	tw.tween_callback(mi.queue_free)
	return mi


## Hız çizgisi: from'dan dir boyunca len; kuyruktan başa fırlar, söner; drift: sönerken kayma
static func _streak(pj: PathJutsu, from: Vector3, dir: Vector3, len_: float, w: float, col: Color, edge: Color, life: float, drift := Vector3.ZERO) -> MeshInstance3D:
	var mi = _gi(_strip_mesh(), _ink(false))
	_put(pj, mi, from)
	mi.global_basis = _basis(dir) * Basis.from_scale(Vector3(w, w, len_))
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_grow": 0.0, "k_tail": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, minf(0.05, life * 0.3))
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	if drift != Vector3.ZERO:
		tw.parallel().tween_property(mi, "global_position", from + drift, life).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)
	return mi


## Şok dikeni çelengi (anime çarpma karesi). o: horiz, basis, wdeg, jag, seed, sector, grow
static func _spikes(pj: PathJutsu, at: Vector3, r0: float, r1: float, n: int, col: Color, edge: Color, life: float, o := {}) -> MeshInstance3D:
	var horiz = bool(o.get("horiz", false))
	var mesh = _spike_mesh(n, r0, r1, float(o.get("wdeg", 4.0)), float(o.get("jag", 0.35)), int(o.get("seed", 0)), horiz, float(o.get("sector", 360.0)))
	var mi = _gi(mesh, _ink(not horiz))
	_put(pj, mi, at)
	var bs: Basis = o.get("basis", Basis())
	mi.global_basis = bs.scaled(Vector3.ONE * 0.9) if horiz else Basis().scaled(Vector3.ONE * 0.9)
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_grow": 0.0, "k_tail": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, float(o.get("grow", 0.06)))
	tw.tween_interval(life * 0.35)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life * 0.65)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * 1.15, life * 0.65)
	tw.tween_callback(mi.queue_free)
	return mi


## Cel toz bulutu: p'den vel ile kayar, büyür, kenardan dağılır
static func _puff(pj: PathJutsu, p: Vector3, s: float, life: float, vel: Vector3, col: Color, delay := 0.0) -> void:
	var mi = _gi(_quad(), _dust_mat())
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
		_puff(pj, c + dv * r0 + UP * s * 0.35, s * randf_range(0.75, 1.15), life * randf_range(0.8, 1.1), dv * (r1 - r0) / life + UP * up, col, randf() * 0.05)


## Zemin izi (çatlak / yarık / göçük / pençe oyuğu / sürtme). o: dir, seed, n, col, gnd, grow_t
static func _decal(pj: PathJutsu, p: Vector3, r: float, mode: int, life: float, o := {}) -> void:
	var mi = _gi(_plane(), _decal_mat())
	_put(pj, mi, pj.gp(p) + UP * 0.035)
	mi.global_basis = _basis(_flat(o.get("dir", Vector3.FORWARD))) * Basis.from_scale(Vector3.ONE * r)
	_ipar(mi, {"k_mode": float(mode), "k_seed": float(o.get("seed", randf() * 20.0)), "k_n": float(o.get("n", 9.0)),
		"k_col": o.get("col", Color(0.07, 0.05, 0.04)), "k_gnd": o.get("gnd", Color(0.5, 0.4, 0.3)), "k_grow": 0.0, "k_a": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, float(o.get("grow_t", 0.2))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.8)
	tw.tween_callback(mi.queue_free)


## Balistik savrulma: yere değince durur, sonra küçülüp gider
static func _toss(pj: PathJutsu, mi: Node3D, p0: Vector3, v: Vector3, life: float, g := 22.0, spin := 9.0) -> void:
	var fl = pj.gp(p0).y
	var t_land = (v.y + sqrt(maxf(0.0, v.y * v.y + 2.0 * g * (p0.y - fl)))) / g
	var rax = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	if rax.length() < 0.1:
		rax = Vector3.RIGHT
	var b0 = mi.global_basis
	var step = func(tt: float) -> void:
		if not is_instance_valid(mi):
			return
		var te = minf(tt, t_land)
		mi.global_position = p0 + v * te + Vector3.DOWN * 0.5 * g * te * te
		mi.global_basis = Basis(rax, te * spin) * b0
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(mi.queue_free)


## Kaya parçası saçılımı
static func _debris(pj: PathJutsu, p: Vector3, n: int, s: float, spd: float, col: Color, up := 0.8, life := 1.0) -> void:
	for i in n:
		var mi = _chunk(s * randf_range(0.35, 1.0), col.darkened(randf() * 0.2))
		_put(pj, mi, p + UP * 0.2 + _rnd_dir() * randf() * 0.5)
		var v = _rnd_dir() * spd * randf_range(0.35, 1.0) + UP * spd * up * randf_range(0.6, 1.2)
		_toss(pj, mi, mi.global_position, v, life * randf_range(0.8, 1.2))


## Ardıl görüntü: o anki beden pozu dondurulur, offs'taki her konuma saydam kopyası bırakılır (ilk en dolu)
static func _ghost(pj: PathJutsu, c: Node3D, col: Color, a: float, life: float, offs: Array, stagger := 0.0) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return
	var parts := []
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var src = node as MeshInstance3D
		if src == null or src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null or src.get_node_or_null(src.skeleton) is Skeleton3D:
			var baked = src.bake_mesh_from_current_skeleton_pose()
			if baked:
				mesh = baked
		parts.append([mesh, src.global_transform])
		if parts.size() >= 24:
			break
	for i in offs.size():
		var off: Vector3 = offs[i]
		var ka = a * (1.0 - 0.5 * float(i) / maxf(1.0, offs.size()))
		for pr in parts:
			var e = _gi(pr[0], _ghost_mat())
			pj.get_tree().current_scene.add_child(e)
			var xf: Transform3D = pr[1]
			e.global_transform = Transform3D(xf.basis, xf.origin + off)
			_ipar(e, {"k_col": col, "k_a": ka})
			var tw = e.create_tween()
			tw.tween_interval(i * stagger)
			tw.tween_method(_pf(e, "k_a"), ka, 0.0, life).set_ease(Tween.EASE_IN)
			tw.tween_callback(e.queue_free)


## El kemiğine bağlı kılıç (namlu + sap + koruma), dur saniye sonra gider
static func _blade(pj: PathJutsu, c: Node3D, dur: float, len_ := 0.9, col := Color(0.82, 0.85, 0.9)) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var b = MB.new()
	b.add("box", Vector3(0, 0, len_ * 0.55), Vector3(0.025, 0.07, len_), col)
	b.add("box", Vector3(0, 0.012, len_ * 0.55), Vector3(0.012, 0.02, len_ * 0.98), col.lightened(0.35))
	b.add("cyl", Vector3(0, 0, -0.06), Vector3(0.03, 0.18, 0.03), Color(0.15, 0.12, 0.1), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.05), Vector3(0.07, 0.015, 0.07), Color(0.3, 0.26, 0.15), Vector3(90, 0, 0), 10)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(_cel_mat())
	ba.add_child(mi)
	pj.free_after(dur, ba)


## Kesik kıymıkları: kesik yönünde fırlayan koyu kırmızı ince damlacık çizgileri
static func _flecks(pj: PathJutsu, at: Vector3, dir: Vector3, n: int, col := Color(0.55, 0.06, 0.06)) -> void:
	for i in n:
		var dv = (dir.normalized() + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.6), randf_range(-0.6, 0.6))).normalized()
		_streak(pj, at, dv, randf_range(0.18, 0.4), 0.035, col, col.darkened(0.5), randf_range(0.22, 0.35), dv * randf_range(0.6, 1.3) + Vector3.DOWN * 0.35)


## Fırlayan yapraklar (çırpınarak, hafif yerçekimi)
static func _leaves_burst(pj: PathJutsu, at: Vector3, n: int, spd := 6.0) -> void:
	for i in n:
		var lf = _gi(_leaf_mesh(), _leaf_mat())
		lf.scale = Vector3.ONE * randf_range(0.9, 1.5)
		var p0 = at + _rnd_dir() * randf() * 0.4
		_put(pj, lf, p0)
		_ipar(lf, {"k_a": 1.0})
		var v = _rnd_dir() * spd * randf_range(0.4, 1.0) + UP * spd * randf_range(0.3, 0.9)
		var rax = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		var b0 = lf.global_basis
		var life = randf_range(0.8, 1.2)
		var step = func(t: float) -> void:
			if not is_instance_valid(lf):
				return
			var drag = 1.0 - exp(-t * 2.5)
			lf.global_position = p0 + v * drag / 2.5 + Vector3.DOWN * 1.2 * t * t
			lf.global_basis = Basis(rax, t * 14.0) * b0
			lf.set_instance_shader_parameter("k_a", clampf((life - t) / (life * 0.35), 0.0, 1.0))
		var tw = lf.create_tween()
		tw.tween_method(step, 0.0, life, life)
		tw.tween_callback(lf.queue_free)


# ================================================================== 1) Zankō: ardıl görüntü zinciri, gecikmeli kesik
## Kalkış noktasında beden pozu donar; yol boyunca giderek solan dört ardıl görüntü kalır. Göğüs hizasında ince hız çizgileri,
## kalkışta zemin sürtme izi + geriye savrulan toz, inişte kayma tozu. 0.3 sn sonra hedefin üstünde çapraz tek kesik açılır.
static func zanko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.7)
	_blade(pj, c, 0.7)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		var start = c.global_position
		var dist = (start.distance_to(tt.global_position) + 3.0) if tt else 8.0
		var offs := []
		for k in 4:
			offs.append(d * dist * (k * 0.22))
		_ghost(pj, c, Color(0.32, 0.4, 0.62), 0.55, 0.55, offs, 0.04)
		c.global_position = pj.gp(start + d * dist)
		var g = _pal(start)
		var sd = _side(d)
		for k in 7:
			var h = randf_range(0.4, 1.8)
			var off = sd * randf_range(-0.55, 0.55) + UP * h
			_streak(pj, start + off + d * randf_range(-0.5, 0.5), d, dist * randf_range(0.55, 0.95), randf_range(0.04, 0.07), Color(0.95, 0.97, 1.0), Color(0.4, 0.45, 0.6), 0.3)
		_decal(pj, start + d * 0.9, 1.6, 4, 1.4, {"dir": d, "gnd": g["body"]})
		for k in 4:
			_puff(pj, pj.gp(start) + UP * 0.3 + sd * randf_range(-0.4, 0.4), randf_range(0.6, 0.9), 0.5, -d * randf_range(2.5, 4.0) + UP * 0.6, g["dust"], k * 0.03)
		_debris(pj, pj.gp(start), 6, 0.12, 3.0, g["body"], 0.6, 0.6)
		var end = c.global_position
		for k in 2:
			_puff(pj, end + UP * 0.25 + sd * (k - 0.5) * 0.6, 0.7, 0.45, d * 2.0 + UP * 0.3, g["dust"])
		Combat.hit_zone(c, start, d, dist, 10.0, 2.5, pj.inf(c, "zanko", 1.8, {"knock": 5.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.1}))
		pj.after(0.3, func():
			if tt and pj.live(tt):
				var at = tt.global_position + UP
				var cut = (sd * 0.8 + UP * 0.6).normalized()
				_streak(pj, at - cut * 1.2, cut, 2.4, 0.1, Color(1, 1, 1), Color(0.35, 0.05, 0.08), 0.35)
				_spikes(pj, at, 0.35, 1.5, 12, Color(0.1, 0.1, 0.13), Color(0.02, 0.02, 0.03), 0.22, {"wdeg": 2.5, "jag": 0.4, "seed": 1})
				_flecks(pj, at, cut, 8)
				pj.shake(0.35))
		Sfx.play("whoosh", start, 2.0, 0.6))


# ================================================================== 2) Ansatsu Jutsu: arkada belirip geniş beyaz hilal
## Kalkış yerinde yukarı fırlayan dikey kayboluş çizgileri ve küçük toz; hedefin arkasında belirişte yere çöken toz.
## Kesik: ref'teki gibi geniş, ince ışıltılı beyaz hilal (hafif eğik) + içinde ikinci ince yay; isabette siyah ince şok çizgileri.
static func ansatsu_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	var p0 = pj.gp(c.global_position)
	var g = _pal(p0)
	for k in 7:
		var off = _rnd_dir() * randf_range(0.2, 0.6) + UP * randf_range(0.0, 0.8)
		_streak(pj, p0 + off, UP, randf_range(1.0, 1.8), 0.05, Color(0.92, 0.94, 1.0), Color(0.3, 0.32, 0.4), 0.2)
	for k in 3:
		_puff(pj, p0 + UP * 0.25 + _rnd_dir() * 0.3, 0.6, 0.4, _rnd_dir() * 1.5, g["dust"])
	var away = tt.global_position - c.global_position
	away.y = 0
	c.global_position = pj.gp(tt.global_position + away.normalized() * 1.3)
	if c is Player:
		c.combat.face_to(tt)
	for k in 2:
		_puff(pj, pj.gp(c.global_position) + UP * 0.2 + _rnd_dir() * 0.4, 0.55, 0.35, _rnd_dir() * 1.2, g["dust"])
	pj.after(0.18, func():
		if not pj.live(c) or not pj.live(tt):
			return
		var d = (tt.global_position - c.global_position).normalized()
		var fd = _flat(d)
		_smear(pj, c.global_position + UP * 1.2, fd, 1.7, -110.0, 60.0, 0.36, Color(1, 1, 1), Color(0.55, 0.65, 0.85), 16.0, {"sweep": 0.08, "hold": 0.07, "fade": 0.2})
		_smear(pj, c.global_position + UP * 1.27, fd, 1.3, -100.0, 50.0, 0.12, Color(0.9, 0.94, 1.0), Color(0.5, 0.58, 0.8), 10.0, {"sweep": 0.1, "hold": 0.05, "fade": 0.16})
		var hs = pj.hit(c, tt.global_position + UP, 1.4, pj.inf(c, "ansatsu_jutsu", 2.0, {"knock": 4.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12}))
		if not hs.is_empty():
			var at = hs[0].global_position + UP
			_spikes(pj, at, 0.3, 1.2, 10, Color(0.12, 0.12, 0.15), Color(0.02, 0.02, 0.03), 0.2, {"wdeg": 2.0, "jag": 0.5, "seed": 2})
			_flecks(pj, at, _side(fd), 7)
			pj.shake(0.3)
		Sfx.play("clink", c.global_position, 0.8))


# ================================================================== 3) Ōkashō: zemini paramparça eden çakra yumruğu
## Hazırlık: yumruğa doğru çekilen pembe çakra kıvılcım çizgileri. Çarpma: siyah kenarlı beyaz + pembe çarpma karesi,
## tuğla halkalı göçük ve dışa uzanan çatlaklar, göçük çevresinde dikilip içe yatan çimli zemin levhaları (ref), havaya savrulan
## kaya parçaları ve dışa yayılan toz halkası; levhalar bir süre ayakta kalıp yere geri gömülür.
static func okasho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	var d = pj._jump_at(c, tt, 7.0, 8.0 if tt else 2.0)
	pj.busy(c, 1.0)
	pj.anim(c, "air", 1.0)
	var pink = Color(1, 0.6, 0.75)
	pj.every(0.45, 0.05, func(_i, _k):
		if pj.live(c):
			var hp = pj.hand_pos(c, true)
			for j in 2:
				var off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.5, 0.9)
				_streak(pj, hp + off, -off, off.length() * 0.8, 0.04, Color(1, 0.92, 0.96), pink.darkened(0.3), 0.12), Callable())
	pj.after(0.45, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.2)
		if c is CharacterBody3D:
			c.velocity = Vector3.DOWN * 20.0
		pj.after(0.12, func():
			var at = pj.gp(c.global_position + d * 0.6)
			var g = _pal(at)
			_spikes(pj, at + UP * 0.7, 0.45, 3.4, 22, Color(1, 1, 1), Color(0.08, 0.06, 0.06), 0.28, {"wdeg": 5.0, "jag": 0.5, "seed": 3})
			_spikes(pj, at + UP * 0.7, 0.3, 2.2, 12, Color(1, 0.66, 0.8), Color(0.55, 0.15, 0.32), 0.22, {"wdeg": 8.0, "jag": 0.3, "seed": 4})
			_decal(pj, at, 9.0, 2, 4.0, {"grow_t": 0.18, "n": 11.0, "gnd": g["body"]})
			for k in 12:
				var a = TAU * (k + randf_range(-0.3, 0.3)) / 12.0
				var dv = Vector3(cos(a), 0.0, sin(a))
				var rr = randf_range(2.2, 5.8)
				_slab(pj, at + dv * rr, dv, randf_range(1.2, 2.2), randf_range(1.4, 2.6), randf_range(28.0, 58.0), g, 3.0, randf() * 0.06)
			_debris(pj, at, 26, 0.55, 11.0, g["body"], 1.1, 1.3)
			_dust_ring(pj, at, 1.5, 9.0, 16, 2.2, 1.4, g["dust"], 0.6)
			pj.shake(1.2)
			pj.hit(c, at + UP, 6.5, pj.inf(c, "okasho", 2.2, {"knock": 18.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.1}))
			Sfx.play("boom", at, 0.8)))


## Göçükten dikilen zemin levhası: üstü çimli/zemin rengi, iç kenarı yukarıda, dış kenarı gömülü; hold sn sonra geri gömülür
static func _slab(pj: PathJutsu, q: Vector3, outward: Vector3, w: float, l: float, tilt: float, g: Dictionary, hold: float, delay := 0.0) -> void:
	var b = MB.new()
	b.add_grad("box", Vector3.ZERO, Vector3(w, 0.34, l), g["top"], g["body"])
	b.add("box", Vector3(w * 0.32, -0.04, l * 0.42), Vector3(w * 0.45, 0.3, l * 0.32), g["body"], Vector3(0, 27, 0))
	b.add("box", Vector3(-w * 0.3, -0.08, -l * 0.4), Vector3(w * 0.4, 0.26, l * 0.3), g["body"].darkened(0.1), Vector3(0, -19, 0))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(_cel_mat())
	var fl = pj.gp(q)
	_put(pj, mi, fl - UP * 1.2)
	mi.global_basis = _basis(outward) * Basis(Vector3.RIGHT, -deg_to_rad(tilt)) * Basis(UP, randf_range(-0.3, 0.3))
	var hi = fl + UP * (0.1 + 0.3 * tilt / 45.0)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mi, "global_position", hi, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(mi, "global_position", fl - UP * 1.6, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


# ================================================================== 4) Bunshin Taiatari: kopyaların üst üste bindiği gövde darbesi
## Her kopya beyaz dört-altı uçlu küçük bir patlama kıvılcımıyla belirir; hedefe uçarken arkasında hız çizgileri bırakır.
## Her çarpma bir öncekinin üstüne biner: ayak dibinde toz ve siyah şok çizgileri büyür; son kopyada yerde çatlak + güçlü sarsıntı.
static func bunshin_taiatari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var d = (tt.global_position - c.global_position)
	d.y = 0
	d = d.normalized()
	for k in 4:
		var q = pj.gp(c.global_position + d.cross(Vector3.UP) * (k - 1.5) * 0.9)
		_pop(pj, q + UP)
		var cl = pj.decoy(c, q, 1.2)
		if cl:
			var tw = cl.create_tween()
			tw.tween_interval(0.1 + k * 0.06)
			tw.tween_callback(func():
				pj.every(0.3, 0.03, func(_i, _k):
					if is_instance_valid(cl) and pj.live(tt):
						var fly = (tt.global_position - cl.global_position).normalized()
						var off = Vector3(randf_range(-0.35, 0.35), randf_range(0.4, 1.6), randf_range(-0.35, 0.35))
						_streak(pj, cl.global_position + off - fly * 1.6, fly, 1.4, 0.05, Color(1, 0.96, 0.85), Color(0.7, 0.45, 0.2), 0.15), Callable()))
			tw.tween_property(cl, "global_position", tt.global_position + Vector3.UP * (0.3 + k * 0.3), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				if pj.live(tt):
					_pile_hit(pj, tt, d, k)
					tt.take_hit(pj.inf(c, "bunshin_taiatari", 0.45, {"knock": 6.0 + k * 3.0, "kind": "heavy"}))
				_pop(pj, cl.global_position + Vector3.UP)
				cl.queue_free())
	Sfx.play("poof", c.global_position, 1.1)


## Kopya beliriş/dağılış kıvılcımı: küçük beyaz yıldız dikenler + iki minik toz
static func _pop(pj: PathJutsu, at: Vector3) -> void:
	_spikes(pj, at, 0.15, 0.8, 7, Color(1, 1, 1), Color(0.55, 0.58, 0.68), 0.18, {"wdeg": 9.0, "jag": 0.3, "seed": 5})
	for j in 2:
		_puff(pj, at + _rnd_dir() * 0.2 - UP * 0.2, 0.45, 0.3, _rnd_dir() * 1.2 + UP * 0.8, Color(0.94, 0.94, 0.96))


static func _pile_hit(pj: PathJutsu, tt: Node3D, d: Vector3, k: int) -> void:
	var at = tt.global_position + UP * (0.6 + k * 0.25)
	var g = _pal(tt.global_position)
	_spikes(pj, at, 0.3, 1.0 + k * 0.3, 8 + k * 2, Color(0.12, 0.1, 0.1), Color(0.02, 0.02, 0.02), 0.2, {"wdeg": 3.0, "jag": 0.4, "seed": 6 + k})
	for j in 2 + k:
		_puff(pj, pj.gp(tt.global_position) + UP * 0.3 + _side(d) * randf_range(-0.6, 0.6), 0.6 + k * 0.12, 0.5, d * randf_range(1.5, 3.0) + UP * 0.5, g["dust"])
	if k == 3:
		_decal(pj, tt.global_position, 2.6, 0, 2.5, {"n": 7.0, "gnd": g["body"]})
		pj.shake(0.5)
	else:
		pj.shake(0.15)


# ================================================================== 5) Dainamikku Entorī: uçan tekme girişi
## Kalkışta arkaya fışkıran toz + zemin sürtme izi; uçuşta bedenin çevresinden geriye akan mavi-beyaz hız çizgileri ve
## aralıklı ardıl görüntüler (ref: mavi hız arka planı). Çarpmada tabanın önünde dikey şok dikeni halkası (tekme yönüne dik)
## + kameraya dönük büyük beyaz çarpma karesi + hedefi itip giden ileri çizgiler.
static func dainamikku_entori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj._face(c, pj.tg(c, t, 14.0))
	pj.busy(c, 0.6)
	pj._kick_pose(c, 0.55)
	if c is CharacterBody3D:
		c.velocity = d * 22.0 + Vector3.UP * 4.0
	var p0 = pj.gp(c.global_position)
	var g = _pal(p0)
	for k in 5:
		_puff(pj, p0 + UP * 0.3 + _side(d) * randf_range(-0.5, 0.5), randf_range(0.7, 1.1), 0.55, -d * randf_range(4.0, 6.5) + UP * randf_range(0.6, 1.6), g["dust"], k * 0.02)
	_decal(pj, p0 - d * 0.6, 1.4, 4, 1.6, {"dir": d, "gnd": g["body"]})
	var sd = _side(d)
	var done := {"v": false}
	pj.every(0.5, 1.0 / 30.0, func(fi, _k):
		if done["v"] or not pj.live(c):
			return
		for j in 2:
			var off = sd * randf_range(-1.0, 1.0) * 0.9 + UP * randf_range(0.2, 1.8)
			_streak(pj, c.global_position + off - d * randf_range(2.5, 4.0), d, randf_range(2.2, 3.6), 0.05, Color(0.88, 0.95, 1.0), Color(0.35, 0.6, 0.95), 0.16)
		if fi % 5 == 2:
			_ghost(pj, c, Color(0.3, 0.55, 0.42), 0.4, 0.25, [Vector3.ZERO])
		var hs = pj.hit(c, c.global_position + Vector3.UP * 0.9 + d * 0.8, 1.2, pj.inf(c, "dainamikku_entori", 1.4, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "dir": d}))
		if not hs.is_empty():
			done["v"] = true
			pj.shake(0.4)
			var at = hs[0].global_position + Vector3.UP
			_spikes(pj, at - d * 0.3, 0.5, 2.0, 18, Color(0.85, 0.93, 1.0), Color(0.2, 0.4, 0.8), 0.26, {"horiz": true, "basis": _basis(d) * Basis(Vector3.RIGHT, PI * 0.5), "wdeg": 5.0, "jag": 0.4, "seed": 9})
			_spikes(pj, at, 0.3, 2.4, 16, Color(1, 1, 1), Color(0.06, 0.06, 0.08), 0.22, {"wdeg": 4.0, "jag": 0.55, "seed": 10})
			for j in 6:
				var off2 = sd * randf_range(-0.6, 0.6) + UP * randf_range(-0.5, 0.6)
				_streak(pj, at + off2, d, randf_range(2.0, 3.2), 0.06, Color(1, 1, 1), Color(0.3, 0.5, 0.85), 0.22, d * 1.5)
			if c is CharacterBody3D:
				c.velocity = -d * 5.0 + Vector3.UP * 5.0)


# ================================================================== 6) Hayanie: dürtüp kaldırma, yere çakma
## İki parmak dürtüşü: hedef göğsünde keskin dört uçlu beyaz parıltı + kısa siyah çizgiler. Hedef yükselirken altından yukarı
## koyu tarama çizgileri (ref'teki hız taraması); düşüşte yukarıdan aşağı inen çizgiler, yere çakılınca yıldız çatlak, yassı
## toz halkası, yere yatık şok dikenleri ve parçalar.
static func hayanie(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 4.0)
	pj.busy(c, 0.8)
	pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	if tt == null:
		return
	pj.st(tt, "stun", 1.2)
	var y0 = tt.global_position
	_spikes(pj, y0 + UP * 1.1, 0.02, 0.9, 4, Color(1, 1, 1), Color(0.5, 0.55, 0.7), 0.2, {"wdeg": 9.0, "jag": 0.0, "seed": 11})
	_spikes(pj, y0 + UP * 1.1, 0.25, 1.0, 10, Color(0.1, 0.1, 0.12), Color(0.02, 0.02, 0.02), 0.16, {"wdeg": 2.5, "jag": 0.4, "seed": 12})
	pj.every(0.25, 0.04, func(_i, _k):
		if pj.live(tt):
			var off = _rnd_dir() * randf_range(0.2, 0.55)
			_streak(pj, tt.global_position + off - UP * 0.4, UP, randf_range(1.2, 1.8), 0.04, Color(0.16, 0.16, 0.2), Color(0.05, 0.05, 0.07), 0.14), Callable())
	var tw = tt.create_tween()
	tw.tween_property(tt, "global_position", y0 + Vector3.UP * 2.2 + c.face_dir() * 0.5, 0.25)
	tw.tween_callback(func():
		if pj.live(tt):
			for j in 5:
				var off = _rnd_dir() * randf_range(0.2, 0.6)
				_streak(pj, tt.global_position + off + UP * 2.4, Vector3.DOWN, 2.2, 0.045, Color(0.16, 0.16, 0.2), Color(0.05, 0.05, 0.07), 0.16))
	tw.tween_property(tt, "global_position", pj.gp(y0 + c.face_dir() * 1.5), 0.12)
	tw.tween_callback(func():
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "hayanie", 1.6, {"knock": 2.0, "kind": "heavy"}))
			var at = tt.global_position
			var g = _pal(at)
			_decal(pj, at, 3.2, 0, 3.0, {"n": 8.0, "gnd": g["body"], "grow_t": 0.12})
			_spikes(pj, pj.gp(at) + UP * 0.15, 0.4, 2.2, 14, g["dust"].lightened(0.2), g["body"].darkened(0.5), 0.3, {"horiz": true, "basis": Basis(UP, randf() * TAU), "wdeg": 5.0, "jag": 0.45, "seed": 13})
			_dust_ring(pj, pj.gp(at), 0.3, 2.6, 8, 1.0, 0.7, g["dust"], 0.1)
			_debris(pj, at, 12, 0.3, 5.0, g["body"], 0.9, 0.9)
			pj.shake(0.5)
			Sfx.play("hit_heavy", tt.global_position, 1.0))


# ================================================================== 7) Hisenken: dönerek uçan kılıç
## Yassı dönen kılıç (ref: düz, bulanık uçan kılıç): uçların arkasında dönen yarı saydam bulanık yaylar, yol boyunca ıslık
## çizgileri. Her isabette hedefte çapraz iki kesik çizgisi + kıymık.
static func hisenken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.5)
	var from = c.global_position + Vector3.UP * 1.3
	var end = (tt.global_position + Vector3.UP if tt else from + c.face_dir() * 18.0)
	var fd0 = c.face_dir()
	var sw = Node3D.new()
	var b = MB.new()
	b.add("box", Vector3(0.5, 0, 0), Vector3(2.2, 0.04, 0.3), Color(0.75, 0.78, 0.82))
	b.add("box", Vector3(0.5, 0.012, 0.08), Vector3(2.15, 0.02, 0.06), Color(0.92, 0.94, 0.97))
	b.add("box", Vector3(-0.62, 0, 0), Vector3(0.06, 0.08, 0.42), Color(0.3, 0.26, 0.16))
	b.add("cyl", Vector3(-0.9, 0, 0), Vector3(0.07, 0.5, 0.07), Color(0.25, 0.2, 0.15), Vector3(0, 0, 90), 8)
	var blade = MeshInstance3D.new()
	blade.mesh = b.build(_cel_mat())
	sw.add_child(blade)
	for pr in [[1.6, -250.0, -90.0, 0.5], [1.15, 90.0 - 130.0, 90.0, 0.25]]:
		var blur = _gi(_arc_mesh(pr[0], pr[1], pr[2], pr[3], 1), _ink(false))
		sw.add_child(blur)
		_ipar(blur, {"k_col": Color(0.9, 0.92, 0.96), "k_edge": Color(0.45, 0.5, 0.6), "k_grow": 1.0, "k_tail": 1.0, "k_a": 0.55})
	pj.get_tree().current_scene.add_child(sw)
	sw.global_position = from
	var hit_set := {}
	var trail := {"n": 0, "prev": from}
	var tw = sw.create_tween()
	tw.tween_method(func(u):
		if not is_instance_valid(sw):
			return
		var back = pj.live(c)
		var home = c.global_position + Vector3.UP * 1.3 if back else from
		var fdir = c.face_dir() if is_instance_valid(c) else fd0
		var q: Vector3
		if u < 0.5:
			q = from.lerp(end, u * 2.0) + fdir.cross(Vector3.UP) * sin(u * PI * 2.0) * 2.5
		else:
			q = end.lerp(home, (u - 0.5) * 2.0) - fdir.cross(Vector3.UP) * sin(u * PI * 2.0) * 2.5
		sw.global_position = q
		sw.rotate_y(0.6)
		trail["n"] += 1
		var mv: Vector3 = q - trail["prev"]
		if trail["n"] % 3 == 0 and mv.length() > 0.05:
			_streak(pj, q - mv.normalized() * 1.4 + Vector3(0, randf_range(-0.15, 0.15), 0), mv.normalized(), 1.2, 0.035, Color(0.95, 0.97, 1.0), Color(0.5, 0.55, 0.65), 0.18)
		trail["prev"] = q
		for e in pj.enemies_near(c, q, 1.8):
			if not hit_set.has(e) or u > 0.5 and hit_set[e] < 0.5:
				hit_set[e] = u
				var at = e.global_position + Vector3.UP
				var sd = _side(mv if mv.length() > 0.01 else fdir)
				_streak(pj, at - (sd + UP * 0.5).normalized() * 0.8, (sd + UP * 0.5).normalized(), 1.6, 0.07, Color(1, 1, 1), Color(0.3, 0.32, 0.4), 0.22)
				_streak(pj, at - (sd - UP * 0.5).normalized() * 0.8, (sd - UP * 0.5).normalized(), 1.6, 0.07, Color(1, 1, 1), Color(0.3, 0.32, 0.4), 0.22)
				_flecks(pj, at, sd, 4)
				pj.shake(0.12)
				e.take_hit(pj.inf(c, "hisenken", 0.7, {"knock": 6.0, "kind": "heavy", "bleed": 3.0})), 0.0, 1.0, 1.4)
	tw.tween_callback(sw.queue_free)
	Sfx.play("whoosh", from, 0.9)


# ================================================================== 8) Hien: rüzgâr çakrası bıçak uzantısı
## Elin çevresinde kıvrılan küçük rüzgâr yayları toplanır; bıçaktan ileri uzanan saydam açık mavi çakra namlusu büyür
## (ref: Asuma'nın bıçak uzantısı), içinde akan rüzgâr çizgileri ve çevresinde dönen ince sarmal; süre bitince söner.
static func hien(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var root = Node3D.new()
		ba.add_child(root)
		var bl = _gi(_hien_blade_mesh(), _hien_mat())
		ba.add_child(bl)
		_ipar(bl, {"k_a": 1.0, "k_len": 0.0, "k_wisp": 0.0})
		var tw = bl.create_tween()
		tw.tween_method(_pf(bl, "k_len"), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(14.3)
		tw.tween_method(_pf(bl, "k_a"), 1.0, 0.0, 0.4)
		for s in [1.0, -1.0]:
			var wi = _gi(_hien_wisp_mesh(s), _hien_mat())
			root.add_child(wi)
			_ipar(wi, {"k_a": 1.0, "k_len": 0.0, "k_wisp": 1.0})
			var tw2 = wi.create_tween()
			tw2.tween_interval(0.1)
			tw2.tween_method(_pf(wi, "k_len"), 0.0, 1.0, 0.3)
			tw2.tween_interval(14.2)
			tw2.tween_method(_pf(wi, "k_a"), 1.0, 0.0, 0.3)
		var spin = root.create_tween().set_loops(60)
		spin.tween_property(root, "rotation:z", TAU, 0.25).from(0.0)
		pj.free_after(15.0, ba)
	var fd = c.face_dir()
	for k in 5:
		pj.after(k * 0.06, func():
			if pj.live(c):
				var h = pj.hand_pos(c, true)
				_smear(pj, h, fd.rotated(UP, randf() * TAU), randf_range(0.28, 0.42), -150.0, 60.0, 0.07, Color(0.88, 0.97, 1.0), Color(0.4, 0.68, 0.95), randf_range(-70.0, 70.0), {"sweep": 0.1, "hold": 0.02, "fade": 0.12, "tail": 1.1}))
	if c is Player:
		Buffs.add("hien", 15.0, {"melee": 1.2, "reach": 1.6, "_name": "Uçan Kırlangıç", "_desc": "bıçağa rüzgâr çakrası: menzil +%30, hasar +%20"})
	Sfx.play("wind", c.global_position, 1.6)


## Çakra namlusu: el kemiğinde +Z boyunca 0.1 → 1.15, kökte geniş, ucu sivri; çapraz iki düzlem
static func _hien_blade_mesh() -> ArrayMesh:
	if _cache.has("hien_blade"):
		return _cache["hien_blade"]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var seg = 10
	for pl in 2:
		var base = v.size()
		for i in seg + 1:
			var t = float(i) / seg
			var z = 0.1 + t * 1.05
			var hw = 0.09 * (1.0 - pow(t, 2.2)) + 0.004
			var th = hw * (1.0 if pl == 0 else 0.35)
			if pl == 0:
				v.append(Vector3(0, -th, z))
				v.append(Vector3(0, th, z))
			else:
				v.append(Vector3(-th, 0, z))
				v.append(Vector3(th, 0, z))
			uv.append(Vector2(t, 0.0))
			uv.append(Vector2(t, 1.0))
			col.append(Color.WHITE)
			col.append(Color.WHITE)
		for i in seg:
			var b = base + i * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, col, idx)
	_cache["hien_blade"] = m
	return m


## Namlunun çevresinde sarmal ince rüzgâr şeridi
static func _hien_wisp_mesh(sgn: float) -> ArrayMesh:
	var key = "hien_wisp_%d" % int(sgn)
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var seg = 24
	for i in seg + 1:
		var t = float(i) / seg
		var z = 0.05 + t * 1.25
		var a = sgn * t * TAU * 1.6
		var rr = 0.07 + 0.06 * t
		var c0 = Vector3(cos(a) * rr, sin(a) * rr, z)
		var wv = Vector3(-sin(a), cos(a), 0.0) * 0.018
		v.append(c0 - wv)
		v.append(c0 + wv)
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
		col.append(Color.WHITE)
		col.append(Color.WHITE)
	for i in seg:
		var b = i * 2
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


# ================================================================== 9) Daibyō Sogeki: büyük kedi pençesi
## Elde koyu mavi pençe çakrası kıvrılır; saldırıda çapraz düzlemde birbirine paralel dört kalın koyu lacivert pençe hilali
## (mavi kenarlı, ref'teki koyu kütle), dışında yay boyu dizilen beyaz tırtıklı şok çizgileri, yerde dört paralel pençe oyuğu.
static func daibyo_sogeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 3.0, 12.0 if tt else 4.0)
	pj.busy(c, 0.7)
	var navy = Color(0.06, 0.08, 0.2)
	var blue = Color(0.3, 0.55, 1.0)
	for k in 4:
		pj.after(k * 0.055, func():
			if pj.live(c):
				_smear(pj, pj.hand_pos(c, true), d.rotated(UP, randf() * TAU), randf_range(0.3, 0.45), -160.0, 40.0, 0.1, navy, blue, randf_range(-80.0, 80.0), {"sweep": 0.08, "hold": 0.02, "fade": 0.1, "tail": 1.0}))
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "hook", 1.5)
		var at = c.global_position + Vector3.UP * 1.3 + d * 1.2
		var roll = 52.0
		var bs = _basis(d) * Basis(Vector3(0, 0, 1), deg_to_rad(roll))
		for k in 4:
			var off = bs.y * ((k - 1.5) * 0.3)
			_smear(pj, at + off - d * 0.6, d, 1.5, -70.0, 70.0, 0.22, navy, blue, roll, {"sweep": 0.07 + k * 0.012, "hold": 0.08, "fade": 0.2, "tail": 0.7})
		_spikes(pj, at, 1.7, 2.6, 26, Color(1, 1, 1), Color(0.05, 0.06, 0.12), 0.32, {"wdeg": 2.0, "jag": 0.6, "seed": 14})
		var g = _pal(at)
		_decal(pj, at, 2.2, 3, 2.5, {"dir": d, "gnd": g["body"], "grow_t": 0.12})
		var hs = pj.hit(c, at, 2.4, pj.inf(c, "daibyo_sogeki", 1.4, {"knock": 12.0, "kind": "heavy", "bleed": 3.0}))
		if not hs.is_empty():
			_flecks(pj, hs[0].global_position + UP, d, 6)
			pj.shake(0.45)
		Sfx.play("whoosh", at, 1.1))


# ================================================================== 10) Tsūtenkyaku: zemini yaran topuk inişi
## Topuk yukarıdan önüne dikey bir hilal çizerek iner. Çarpmada: tuğla halkalı yuvarlak göçük (ref), ileri-geri uzanan uzun
## yarık ve yarık boyunca iki yana kalkan dar kaya dudakları, göçükten dikine fışkıran soluk sivri parçalar, toz halkası.
static func tsutenkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	var d = pj._jump_at(c, tt, 10.0, 6.0 if tt else 1.0)
	pj.busy(c, 1.0)
	pj._kick_pose(c, 0.9)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		if c is CharacterBody3D:
			c.velocity = Vector3.DOWN * 25.0
		_smear(pj, c.global_position + UP * 1.0, d, 1.4, -150.0, 30.0, 0.34, Color(1, 0.97, 0.9), Color(0.5, 0.4, 0.3), 90.0, {"sweep": 0.1, "hold": 0.04, "fade": 0.16})
		for j in 4:
			var off = _side(d) * randf_range(-0.5, 0.5) + d * 0.4
			_streak(pj, c.global_position + off + UP * 3.0, Vector3.DOWN, 2.4, 0.045, Color(1, 1, 1), Color(0.4, 0.35, 0.3), 0.14)
		pj.after(0.12, func():
			var at = pj.gp(c.global_position + d * 0.6)
			var g = _pal(at)
			_decal(pj, at, 4.6, 2, 5.0, {"gnd": g["body"], "n": 10.0, "grow_t": 0.1})
			_decal(pj, at, 10.0, 1, 5.0, {"dir": d, "gnd": g["body"], "grow_t": 0.35})
			var sd = _side(d)
			for i in 10:
				var s = (i - 4.5) * 1.15
				if absf(s) < 1.4:
					continue
				for side_k in [-1.0, 1.0]:
					_lip(pj, at + d * s + sd * side_k * 0.4, sd * side_k, g, absf(s) * 0.03)
			for k in 14:
				var sh = _shard(randf_range(0.5, 1.1), g["dust"].lightened(0.15))
				_put(pj, sh, at + UP * 0.3 + _rnd_dir() * randf() * 0.8)
				var v = _rnd_dir() * randf_range(1.0, 3.5) + UP * randf_range(9.0, 15.0)
				_toss(pj, sh, sh.global_position, v, randf_range(1.0, 1.4), 22.0, 4.0)
			_debris(pj, at, 20, 0.4, 8.0, g["body"], 1.0, 1.1)
			_dust_ring(pj, at, 0.6, 4.8, 10, 1.6, 1.1, g["dust"], 0.4)
			pj.shake(0.9)
			pj.hit(c, at + Vector3.UP, 5.0, pj.inf(c, "tsutenkyaku", 1.9, {"knock": 14.0, "launch": 8.0, "kind": "heavy"}))
			Sfx.play("boom", at, 0.9)))


## Yarık kenarından dışa yatarak kalkan dar kaya dudağı
static func _lip(pj: PathJutsu, q: Vector3, outward: Vector3, g: Dictionary, delay: float) -> void:
	var b = MB.new()
	b.add_grad("box", Vector3.ZERO, Vector3(0.9, 0.22, 0.6), g["top"], g["body"])
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(_cel_mat())
	var fl = pj.gp(q)
	_put(pj, mi, fl - UP * 0.6)
	mi.global_basis = _basis(outward) * Basis(Vector3.RIGHT, -deg_to_rad(randf_range(18.0, 34.0))) * Basis(UP, PI * 0.5 + randf_range(-0.2, 0.2))
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "global_position", fl + UP * 0.08, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(mi, "global_position", fl - UP * 0.8, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Soluk sivri kaya kıymığı (fışkıran)
static func _shard(s: float, col: Color) -> MeshInstance3D:
	var key = "shard_%s" % col.to_html(false)
	if not _cache.has(key):
		var b = MB.new()
		b.add("cone", Vector3.ZERO, Vector3(0.22, 1.0, 0.22), col, Vector3.ZERO, 4)
		b.add("cone", Vector3(0.06, -0.15, 0.0), Vector3(0.14, 0.6, 0.14), col.darkened(0.12), Vector3(0, 0, 18), 4)
		_cache[key] = b.build(_cel_mat())
	var mi = MeshInstance3D.new()
	mi.mesh = _cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * s
	mi.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
	return mi


# ================================================================== 11) Tsunoori: boynuzlu hücum
## Başta iki fildişi boynuz belirir; hücumda arkada bej toz seli (ref: bulanık bej toz), zemin sürtme izi ve sıcak tonlu hız
## çizgileri. İsabette yukarı kıvrılan iki boynuz yayı (kaldırıp savuran darbe) + ileri patlayan toz + siyah şok çizgileri.
static func tsunoori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.7)
	var hb = pj.bone_attach(c, "Head")
	if hb:
		var b = MB.new()
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.12, 0.2, 0.1), Vector3(0.08, 0.35, 0.08), Color(0.88, 0.83, 0.68), Vector3(-40, 0, -sx * 30), 6)
			b.add("cone", Vector3(sx * 0.17, 0.36, 0.0), Vector3(0.05, 0.2, 0.05), Color(0.94, 0.9, 0.78), Vector3(-65, 0, -sx * 18), 6)
			b.add("cyl", Vector3(sx * 0.1, 0.06, 0.12), Vector3(0.1, 0.05, 0.1), Color(0.6, 0.52, 0.4), Vector3(-40, 0, -sx * 30), 8)
		var hm = MeshInstance3D.new()
		hm.mesh = b.build(_cel_mat())
		hb.add_child(hm)
		pj.free_after(0.8, hb)
	var d = pj._jump_at(c, tt, 0.0, 22.0 if tt else 8.0)
	var p0 = pj.gp(c.global_position)
	var g = _pal(p0)
	var sd = _side(d)
	for k in 7:
		_puff(pj, p0 + UP * 0.45 + sd * randf_range(-0.6, 0.6), randf_range(1.1, 1.7), 0.7, -d * randf_range(3.0, 6.0) + UP * 0.6, g["dust"], k * 0.025)
	_decal(pj, p0, 2.2, 4, 1.8, {"dir": d, "gnd": g["body"]})
	pj.every(0.18, 0.03, func(_i, _k):
		if pj.live(c):
			var off = sd * randf_range(-0.7, 0.7) + UP * randf_range(0.3, 1.6)
			_streak(pj, c.global_position + off - d * 2.6, d, randf_range(1.8, 2.6), 0.05, Color(1, 0.94, 0.82), Color(0.6, 0.45, 0.28), 0.16), Callable())
	pj.after(0.18, func():
		if pj.live(c):
			var hs = pj.hit(c, c.global_position + Vector3.UP * 1.0 + d * 1.2, 2.0, pj.inf(c, "tsunoori", 1.6, {"knock": 20.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.08}))
			if not hs.is_empty():
				var at = hs[0].global_position + UP
				for sx in [-1.0, 1.0]:
					_smear(pj, at - d * 0.8 + sd * sx * 0.25, d, 1.0, -110.0, 0.0, 0.18, Color(1, 0.97, 0.88), Color(0.55, 0.45, 0.3), 90.0 + sx * 12.0, {"sweep": 0.08, "hold": 0.05, "fade": 0.18})
				_spikes(pj, at, 0.35, 1.6, 11, Color(0.12, 0.1, 0.08), Color(0.03, 0.02, 0.02), 0.22, {"wdeg": 3.0, "jag": 0.45, "seed": 15})
				for j in 4:
					_puff(pj, at - UP * 0.4 + sd * randf_range(-0.5, 0.5), 1.0, 0.55, d * randf_range(3.0, 5.0) + UP * 0.8, g["dust"])
				pj.shake(0.6))
	Sfx.play("whoosh", c.global_position, 0.8)


# ================================================================== 12) Iaigiri: mor yıldız patlamalı çekiş kesiği
## Kın ağzında küçük parıltı; kesişte geniş mor + beyaz yatay hilaller, 2 m önde mor tırtıklı çiçek biçimli patlama (ref) ve
## önde yerden kalkan bej toz bulutu sırası.
static func iaigiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.7)
	_blade(pj, c, 0.6)
	pj.after(0.12, func():
		if pj.live(c):
			_spikes(pj, c.global_position + UP * 1.0 + _side(d) * 0.25 + d * 0.2, 0.01, 0.45, 4, Color(1, 1, 1), Color(0.6, 0.5, 0.85), 0.16, {"wdeg": 8.0, "jag": 0.0, "seed": 16}))
	pj.after(0.3, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_a", 2.2)
		var at = c.global_position + Vector3.UP * 1.2
		_smear(pj, at, d, 4.0, -80.0, 80.0, 0.7, Color(0.9, 0.82, 1.0), Color(0.45, 0.3, 0.7), 5.0, {"sweep": 0.07, "hold": 0.06, "fade": 0.22})
		_smear(pj, at + Vector3.UP * 0.1, d, 3.6, -70.0, 70.0, 0.28, Color(1, 1, 1), Color(0.6, 0.5, 0.9), 2.0, {"sweep": 0.08, "hold": 0.05, "fade": 0.18})
		_spikes(pj, at + d * 2.0, 0.6, 2.6, 14, Color(0.6, 0.48, 0.76), Color(0.25, 0.14, 0.4), 0.45, {"wdeg": 13.0, "jag": 0.35, "seed": 17, "grow": 0.08})
		_spikes(pj, at + d * 2.0, 0.3, 1.6, 10, Color(0.82, 0.72, 0.96), Color(0.4, 0.28, 0.6), 0.36, {"wdeg": 11.0, "jag": 0.3, "seed": 18})
		var g = _pal(at)
		for k in 9:
			var dv = d.rotated(UP, deg_to_rad(randf_range(-60.0, 60.0)))
			_puff(pj, pj.gp(c.global_position + dv * randf_range(3.5, 6.0)) + UP * 0.5, randf_range(1.4, 2.2), 0.9, dv * 2.0 + UP * 0.5, g["dust"], randf() * 0.08)
		Combat.hit_zone(c, c.global_position, d, 8.0, 60.0, 2.5, pj.inf(c, "iaigiri", 2.0, {"knock": 10.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12}))
		pj.shake(0.3)
		Sfx.play("clink", at, 0.7))


# ================================================================== 13) Iaidō: göz açıp kapayana kadar tek çizgi
## Kalkış noktasında dört uçlu parıltı; geçilen yolda siyah kenarlı jilet gibi tek beyaz çizgi bir an durur, sonra ikiye ayrılıp
## açılarak söner; yol boyunca iki yana savrulan basınç tozu. 0.25 sn sonra kın sesiyle orta noktada kısa dikey dönüş kesiği.
static func iaido(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 0.6)
	var d = pj._face(c, tt)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var start = c.global_position
		if c is CharacterBody3D:
			c.global_position = pj.gp(start + d * minf(6.0, start.distance_to(tt.global_position) + 1.2 if tt else 4.0))
		var endp = c.global_position
		var a = start + Vector3.UP * 1.1
		var b = endp + Vector3.UP * 1.1
		var ln = a.distance_to(b) + 0.1
		var dirv = (b - a).normalized() if ln > 0.2 else d
		for s in [1.0, -1.0]:
			var mi = _streak(pj, a, dirv, ln, 0.05, Color(1, 1, 1), Color(0.04, 0.04, 0.06), 0.32)
			var tw = mi.create_tween()
			tw.tween_interval(0.08)
			tw.tween_property(mi, "global_position", a + Vector3.UP * s * 0.22, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_spikes(pj, a, 0.02, 1.4, 4, Color(1, 1, 1), Color(0.55, 0.55, 0.65), 0.24, {"wdeg": 7.0, "jag": 0.0, "seed": 19})
		var g = _pal(start)
		var sd = _side(dirv)
		for k in 6:
			var q = pj.gp(start.lerp(endp, (k + 0.5) / 6.0))
			for s in [1.0, -1.0]:
				_puff(pj, q + UP * 0.25 + sd * s * 0.4, 0.55, 0.45, sd * s * 3.0 + UP * 0.3, g["dust"], k * 0.02)
		Combat.hit_zone(c, start, d, start.distance_to(c.global_position) + 1.0, 12.0, 2.5, pj.inf(c, "iaido", 1.8, {"knock": 6.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.12}))
		pj.after(0.25, func():
			_smear(pj, (start + endp) * 0.5 + Vector3.UP * 1.1, d, 1.6, -30.0, 30.0, 0.16, Color(1, 0.95, 0.95), Color(0.35, 0.05, 0.08), 80.0, {"sweep": 0.05, "hold": 0.05, "fade": 0.14})
			pj.shake(0.25)
			Sfx.play("clink", c.global_position, 0.7))
		Sfx.play("whoosh", start, 1.8, 0.6))


# ================================================================== 14) Konoha Gōriki Senpū: dört yükselen güçlü dönen tekme
## Her tekmede bedenin çevresinde yatay mavi tırtıklı rüzgâr dişleri halkası (ref: mavi sivri kırıklar) — her seferinde büyür
## ve eğimi değişir; bel hizasında tekme yayı, savrulan yapraklar; isabette beyaz-mavi küçük çarpma karesi, artan sarsıntı.
static func konoha_goriki_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	var d = pj._face(c, tt)
	pj.busy(c, 1.0)
	for k in 4:
		pj.after(k * 0.2, func():
			if not pj.live(c):
				return
			pj._kick_pose(c, 0.16)
			if c is CharacterBody3D:
				c.velocity = d * 6.0 + Vector3.UP * (2.0 + k)
			var ctr = c.global_position + Vector3.UP * 1.0
			var bs = Basis(UP, randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(-12.0 + k * 8.0))
			_spikes(pj, ctr, 0.6 + 0.2 * k, 3.5 + 0.8 * k, 16 + 2 * k, Color(0.78, 0.92, 1.0), Color(0.2, 0.5, 0.9), 0.3, {"horiz": true, "basis": bs, "wdeg": 6.0, "jag": 0.45, "seed": 20 + k})
			_smear(pj, ctr, d, 1.3, -160.0 + k * 20.0, 100.0 + k * 20.0, 0.24, Color(1, 1, 1), Color(0.3, 0.55, 0.9), -15.0 + k * 10.0, {"sweep": 0.08, "hold": 0.03, "fade": 0.14})
			_leaves_burst(pj, c.global_position + Vector3.UP * 0.6, 12)
			var hs = pj.hit(c, c.global_position + Vector3.UP * 1.1 + d * 0.9, 2.4, pj.inf(c, "konoha_goriki_senpu", 0.55, {"knock": 5.0 + k * 5.0, "launch": 2.0 + k * 1.5, "kind": "heavy"}))
			if not hs.is_empty():
				_spikes(pj, hs[0].global_position + UP, 0.25, 1.1 + k * 0.2, 9, Color(1, 1, 1), Color(0.25, 0.5, 0.9), 0.18, {"wdeg": 4.0, "jag": 0.4, "seed": 24 + k})
				pj.shake(0.15 + 0.1 * k)
			Sfx.play("whoosh", c.global_position, 1.1 + k * 0.05))


# ================================================================== 15) Konoha Senpū: yaprak kasırgası tekmesi
## Bedenin çevresinde yükselerek dönen yaprak sarmalı, yerde dönen bej toz yayları, bel hizasında tek tam tur ince tekme yayı;
## isabette beyaz-yeşil küçük çarpma karesi.
static func konoha_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.55)
	var tt = pj.tg(c, t, 6.0)
	var d = pj._face(c, tt)
	pj._kick_pose(c, 0.45)
	if c is CharacterBody3D:
		c.velocity = d * (8.0 if tt else 3.0) + Vector3.UP * 4.0
	var ctr = c.global_position + Vector3.UP * 1.1
	var g = _pal(ctr)
	_leaf_vortex(pj, c, 30)
	for k in 3:
		_smear(pj, pj.gp(c.global_position) + UP * 0.15, d.rotated(UP, k * TAU / 3.0), 1.3 + k * 0.25, -170.0, 0.0, 0.22, g["dust"], g["body"].darkened(0.2), 0.0, {"sweep": 0.2, "hold": 0.05, "fade": 0.3, "tail": 0.9})
	pj.after(0.04, func():
		if pj.live(c):
			_smear(pj, c.global_position + UP * 1.0, d, 1.25, -200.0, 160.0, 0.2, Color(1, 1, 1), Color(0.3, 0.55, 0.3), 8.0, {"sweep": 0.14, "hold": 0.03, "fade": 0.14, "tail": 0.8}))
	Sfx.play("whoosh", ctr, 1.2, 0.6)
	pj.after(0.15, func():
		if pj.live(c):
			var hs = pj.hit(c, c.global_position + Vector3.UP * 1.1, 2.4, pj.inf(c, "konoha_senpu", 1.1, {"knock": 12.0, "launch": 3.0, "kind": "heavy"}))
			if not hs.is_empty():
				_spikes(pj, hs[0].global_position + UP, 0.25, 1.2, 10, Color(1, 1, 1), Color(0.3, 0.55, 0.3), 0.2, {"wdeg": 4.0, "jag": 0.4, "seed": 28})
				pj.shake(0.2))


## Bedeni izleyen yükselen yaprak sarmalı; sonda dışa savrulup söner
static func _leaf_vortex(pj: PathJutsu, c: Node3D, n: int) -> void:
	var last := {"p": c.global_position}
	for i in n:
		var lf = _gi(_leaf_mesh(), _leaf_mat())
		lf.scale = Vector3.ONE * randf_range(0.9, 1.5)
		_put(pj, lf, c.global_position)
		_ipar(lf, {"k_a": 1.0})
		var a0 = TAU * i / n
		var h0 = randf_range(0.0, 0.6)
		var rax = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		var spn = randf_range(1.4, 2.0)
		var life = randf_range(0.8, 1.1)
		var step = func(u: float) -> void:
			if not is_instance_valid(lf):
				return
			if is_instance_valid(c):
				last["p"] = c.global_position
			var ang = a0 + u * TAU * spn
			var rad = 0.6 + u * 1.7
			var h = h0 + u * 2.2 + sin(u * 9.0 + a0) * 0.15
			lf.global_position = last["p"] + Vector3(cos(ang), 0.0, sin(ang)) * rad + UP * h
			lf.global_basis = Basis(UP, -ang) * Basis(rax, u * 12.0)
			lf.set_instance_shader_parameter("k_a", clampf((1.0 - u) / 0.3, 0.0, 1.0))
		var tw = lf.create_tween()
		tw.tween_method(step, 0.0, 1.0, life)
		tw.tween_callback(lf.queue_free)
