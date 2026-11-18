class_name NinjutsuFXB
extends RefCounted
## Genel ninjutsu grubu B: klon / kaçış / gizlenme / çağrı / ses-hava dalgası teknikleri.
## Her tekniğin görüntüsü bu dosyada sıfırdan üretilir (kendi cel / kontur / akım / bariyer / kırılma gölgelendiricileri,
## kendi parça yapı taşları). Oynanış ana ağaçtaki işleyicilerden satır satır taşındı; gerçek sistemler (gölge klon,
## Doki çağrısı, gizlenme, buff, zemin yarığı) olduğu gibi kullanılır — yalnız görünüş yeni.
## Okunurluk: tüm gölgelendiricilerde kameraya yakın kısım söner (near), hiçbir parça ekranı kaplamaz.

const INK := Color(0.07, 0.05, 0.09, 1.0)
const PAPER := Color(0.97, 0.96, 0.92, 1.0)
const PAPER_INK := Color(0.32, 0.3, 0.36, 1.0)
const SAND := Color(0.86, 0.73, 0.5, 1.0)
const SAND_INK := Color(0.36, 0.26, 0.14, 1.0)
const AIR := Color(0.9, 1.0, 0.94, 1.0)
const AIR_EDGE := Color(0.32, 0.46, 0.42, 1.0)
const DUST := Color(0.78, 0.68, 0.52, 1.0)
const ROCK := Color(0.62, 0.6, 0.57, 1.0)
const BLACK_INK := Color(0.04, 0.04, 0.06, 1.0)
const BARRIER := Color(0.65, 0.4, 1.0, 1.0)

static var _sh := {}
static var _mc := {}

# ================================================================== gölgelendiriciler
## Cel yüzey: köşe rengi × tint, sabit ışık yönüne göre iki ton, isteğe bağlı parlak vurgu; kameraya yakın söner.
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, CULLMODE, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float shade_k = 0.72;
uniform float hi = 0.0;
uniform float fade = 1.0;
uniform float near = 1.8;

varying vec3 wnrm;

void vertex() {
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wnrm);
	if (!FRONT_FACING) {
		n = -n;
	}
	float l = dot(n, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 c = tint.rgb * COLOR.rgb;
	if (l < 0.05) {
		c *= shade_k;
	}
	if (hi > 0.0 && l > 0.88) {
		c = mix(c, vec3(1.0), hi);
	}
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu kontur: ters kabuk (arka yüzler normal boyunca şişirilir); ana geçişten önce çizilir.
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform float width = 0.015;
uniform float fade = 1.0;
uniform float near = 1.8;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Akım çizgileri: şeritlerde akan kesik çizgiler (beyaz öz + koyu kenar). axis=1 ise akış UV.y boyunca.
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.55, 0.6, 0.75, 1.0);
uniform float lines = 16.0;
uniform float speed = 2.0;
uniform float axis = 0.0;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near = 2.5;

float h1(float x) {
	return fract(sin(x * 127.1 + seed * 13.7) * 43758.5453);
}

void fragment() {
	vec2 uv = axis > 0.5 ? UV.yx : UV;
	float lane = floor(uv.y * lines);
	float r = h1(lane);
	float fy = fract(uv.y * lines);
	float s = fract(uv.x * (0.8 + r) - TIME * speed * (0.6 + r) - r * 3.0);
	float len = 0.25 + 0.45 * h1(lane + 7.0);
	float on = step(s, len) * step(0.3, r);
	float body = step(0.2, fy) * step(fy, 0.8);
	float core = step(0.38, fy) * step(fy, 0.62);
	vec3 c = mix(edge.rgb, tint.rgb, core);
	float ends = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.85, uv.x);
	ALBEDO = c;
	ALPHA = on * body * ends * tint.a * fade * smoothstep(near * 0.4, near, length(VERTEX));
}
"""

## Basınçlı hava merceği: ortası neredeyse görünmez, kenara doğru dalgalı bant, en kenarda koyu cel kontur.
const AIR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.9, 1.0, 0.94, 1.0);
uniform vec4 edge : source_color = vec4(0.32, 0.46, 0.42, 1.0);
uniform float fade = 1.0;
uniform float near = 2.5;

void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float sw = sin(atan(NORMAL.y, NORMAL.x) * 9.0 + TIME * 14.0) * 0.5 + 0.5;
	float a = 0.07;
	vec3 c = tint.rgb;
	if (fr > 0.5) {
		a = 0.3 + 0.22 * step(0.6, sw);
	}
	if (fr > 0.86) {
		c = edge.rgb;
		a = 0.75;
	}
	ALBEDO = c;
	ALPHA = a * fade * smoothstep(near * 0.4, near, length(VERTEX));
}
"""

## Mühür bariyeri duvarı: yükselen mor tül desenleri, parlak alt/üst kenar, koyu dikey kontur.
const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.65, 0.4, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.95, 0.85, 1.0, 1.0);
uniform float fade = 1.0;
uniform float near = 2.0;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float w = vn(vec2(uv.x * 7.0, uv.y * 3.0 + TIME * 0.8)) * 0.65 + vn(vec2(uv.x * 19.0, uv.y * 6.0 + TIME * 1.7)) * 0.35;
	float band = step(0.56, w);
	vec3 c = mix(tint.rgb, rim.rgb, band * 0.55);
	float a = 0.22 + band * 0.24;
	if (uv.y < 0.035 || uv.y > 0.965) {
		c = rim.rgb;
		a = 0.85;
	}
	if (uv.x < 0.012 || uv.x > 0.988) {
		c = vec3(0.14, 0.05, 0.22);
		a = 0.9;
	}
	ALBEDO = c;
	ALPHA = a * fade * smoothstep(near * 0.4, near, length(VERTEX));
}
"""

## Kamuflaj kabuğu: arkasındaki görüntüyü kırar (beden çevreye karışır), ince parlak sınır çizgisi.
const REFRACT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform vec4 edge : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float fade = 1.0;
uniform float near = 1.5;

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 off = NORMAL.xy * 0.035 * fade + vec2(sin(TIME * 9.0 + SCREEN_UV.y * 70.0), 0.0) * 0.005 * fade;
	vec3 bg = textureLod(scr, SCREEN_UV + off, 0.0).rgb;
	float line = step(0.8, fr) * step(fr, 0.9);
	ALBEDO = mix(bg, edge.rgb, line * 0.55 * fade);
	ALPHA = fade * smoothstep(near * 0.4, near, length(VERTEX));
}
"""


# ================================================================== malzeme yapı taşları
static func _shader(key: String, code: String) -> Shader:
	if not _sh.has(key):
		var s := Shader.new()
		s.code = code
		_sh[key] = s
	return _sh[key]


## Cel malzeme + koyu kontur (outline > 0). two_side: şerit / yaprak gibi tek katlı yüzeyler.
static func cel(col := Color.WHITE, outline := 0.015, ink := INK, two_side := false, hi := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("cel2" if two_side else "cel", CEL_SHADER.replace("CULLMODE", "cull_disabled" if two_side else "cull_back"))
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("hi", hi)
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = _shader("ol", OUTLINE_SHADER)
		o.set_shader_parameter("ink", ink)
		o.set_shader_parameter("width", outline)
		o.render_priority = -1
		m.next_pass = o
	return m


static func streak_mat(tint: Color, edge: Color, lines := 16.0, speed := 2.0, axis := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("streak", STREAK_SHADER)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("lines", lines)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("axis", axis)
	m.set_shader_parameter("seed", randf() * 50.0)
	return m


static func _plain(key: String, code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	return m


## Malzemenin (ve kontur geçişinin) sönüm değeri
static func set_fade(m: Material, v: float) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter("fade", v)
		q = q.next_pass


## delay sonra dur sürede söner, sonra silinir
static func fade_free(n: Node, m: Material, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


# ================================================================== düğüm / geometri yapı taşları
static func put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	return n


static func mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _cam(pj: PathJutsu) -> Camera3D:
	var vp = pj.get_viewport()
	return vp.get_camera_3d() if vp else null


## Düğümün -Z'si p'ye bakar (dik bakışta yan eksen kullanılır)
static func _aim(n: Node3D, p: Vector3) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var d := p - n.global_position
	if d.length() < 0.01:
		return
	n.look_at(p, Vector3.UP if absf(d.normalized().y) < 0.97 else Vector3.RIGHT)


## Yassı profil (add_slab) → yere yatık: profil x → dünya X, profil y → -Z, kalınlık → Y
static func _flat_b() -> Basis:
	return Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))


## Yassı profil → dik: profil x → X, profil y → Y, kalınlık → Z (yüz kameraya / dışa döner)
static func _up_b() -> Basis:
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


## Yere yatık profil, profil x ekseni dir yönünde
static func _gb(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.z, dir.x)) * _flat_b()


static func slab_mesh(outline: PackedVector2Array, thick: float, col := Color.WHITE, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var b := MB.new()
	b.add_slab(outline, thick, col, xf)
	return b.build()


## a→b arası birim silindir dönüşümü (w: çap)
static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := maxf(d.length(), 0.001)
	var y := d / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * w, y * L, z * w), (a + b) * 0.5)


## Kırık çizgi tüp (eklem küreli), origin'e göre
static func _line(b: MB, pts: Array, w: float, col: Color, origin := Vector3.ZERO) -> void:
	for i in pts.size() - 1:
		b.add_xf("cyl", _seg_xf(pts[i] - origin, pts[i + 1] - origin, w), col, 6)
		if i > 0:
			b.add("sphere", pts[i] - origin, Vector3.ONE * w, col, Vector3.ZERO, 6)


## Şerit (iki yüzlü): uçları incelen; UV.x boy, UV.y en
static func _ribbon(pts: Array, w: float, nrm: Vector3, col := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var sd := tn.cross(nrm).normalized()
		if sd.length() < 0.1:
			sd = Vector3.RIGHT
		var u := float(i) / float(n - 1)
		var ww := w * (0.25 + 0.75 * sin(PI * u))
		for s in [-1.0, 1.0]:
			st.set_color(col)
			st.set_uv(Vector2(u, (s + 1.0) * 0.5))
			st.set_normal(nrm)
			st.add_vertex(p + sd * ww * s * 0.5)
	for i in n - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


## Yelpaze dilimi (XZ düzlemi, ön -Z): UV.x yarıçap boyunca, UV.y açı boyunca → çizgiler merkezden dışa akar
static func _sector(r0: float, r1: float, half: float, seg := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var u := float(i) / seg
		var a := lerpf(-half, half, u)
		var dv := Vector3(sin(a), 0, -cos(a))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, u))
		st.add_vertex(dv * r0)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, u))
		st.add_vertex(dv * r1)
	for i in seg:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	return st.commit()


# ------------------------------------------------------------------ 2B profiller
## Hilal: dış yay r, iç yay ortada w kadar içeri (uçlar sivri)
static func _crescent(r: float, w: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		o.append(Vector2(cos(a), sin(a)) * r)
	for i in range(n - 1, 0, -1):
		var u := float(i) / n
		var a := deg_to_rad(lerpf(a0, a1, u))
		o.append(Vector2(cos(a), sin(a)) * (r - w * sin(u * PI)))
	return o


static func _heart(s: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		o.append(Vector2(x, y) * s / 32.0)
	return o


## points uçlu yıldız
static func _star(points: int, r_out: float, r_in: float, rot := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * i / (points * 2.0)
		o.append(Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return o


## Düzensiz leke (mürekkep / kum birikintisi)
static func _blob(r: float, n := 18, rough := 0.25) -> PackedVector2Array:
	var o := PackedVector2Array()
	var ph := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rough * (sin(a * 3.0 + ph) * 0.5 + sin(a * 7.0 + ph * 2.0) * 0.3 + randf_range(-0.3, 0.3))
		o.append(Vector2(cos(a), sin(a)) * r * k)
	return o


static func _rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w, -h) * 0.5, Vector2(w, -h) * 0.5, Vector2(w, h) * 0.5, Vector2(-w, h) * 0.5])


## Dişli halka parçaları (ses halkası / yer nabzı): her dilim ayrı dışbükey profil, kontur kesintisiz görünür
static func _ring_mesh(r_in: float, r_mid: float, r_spike: float, seg: int, col: Color, thick: float, xf_b: Basis) -> ArrayMesh:
	var b := MB.new()
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var am := (a0 + a1) * 0.5
		var rs := r_spike * randf_range(0.92, 1.06)
		var o := PackedVector2Array([
			Vector2(cos(a0), sin(a0)) * r_in, Vector2(cos(a0), sin(a0)) * r_mid, Vector2(cos(am), sin(am)) * rs,
			Vector2(cos(a1), sin(a1)) * r_mid, Vector2(cos(a1), sin(a1)) * r_in])
		b.add_slab(o, thick, col, Transform3D(xf_b, Vector3.ZERO))
	return b.build()


# ------------------------------------------------------------------ parça yağmuru (kendi CPU parçacık ayarı)
## o: r (yayılma küresi), dir, spread, vmin, vmax, g (yerçekimi), damp, smin, smax, spin (derece/sn), expl, flat (XZ'ye kısıt),
## align (Y eksenini hıza hizala), hold (alfa tutma oranı)
static func burst(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = float(o.get("expl", 0.95))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.flatness = float(o.get("flat", 0.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -6, 0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.8))
	p.scale_amount_max = float(o.get("smax", 1.2))
	if o.get("align", false):
		p.particle_flag_align_y = true
	else:
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		var sp := float(o.get("spin", 120.0))
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(float(o.get("hold", 0.65)), Color(1, 1, 1, 1))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.6))))
	p.scale_amount_curve = cv
	put(pj, p, pos)
	p.emitting = true
	pj.free_after(life + 0.6, p)
	return p


# ------------------------------------------------------------------ önbellekli küçük biçimler (beyaz geometri; renk malzemeden)
static func _cached(key: String, fn: Callable) -> Mesh:
	if not _mc.has(key):
		_mc[key] = fn.call()
	return _mc[key]


static func _m_blob() -> Mesh:
	return _cached("blob", func():
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.3, 0.22, 0.3), Color.WHITE, Vector3.ZERO, 8)
		return b.build())


static func _m_chunk() -> Mesh:
	return _cached("chunk", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.28, 0.2, 0.24), Color.WHITE, Vector3(18, 30, 9))
		b.add("box", Vector3(0.05, 0.06, 0.02), Vector3(0.16, 0.14, 0.15), Color(0.85, 0.85, 0.85), Vector3(-20, 10, 35))
		return b.build())


static func _m_shard() -> Mesh:
	return _cached("shard", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.035, 0.7, 0.035), Color.WHITE)
		return b.build())


static func _m_feather() -> Mesh:
	return _cached("feather", func():
		var o := PackedVector2Array([Vector2(-0.09, 0), Vector2(-0.05, 0.022), Vector2(0.03, 0.026), Vector2(0.09, 0.004), Vector2(0.05, -0.012), Vector2(0.06, -0.026), Vector2(0.0, -0.018), Vector2(-0.05, -0.02)])
		return slab_mesh(o, 0.008, Color(0.1, 0.1, 0.14), Transform3D(_flat_b(), Vector3.ZERO)))


static func _m_sheet() -> Mesh:
	return _cached("sheet", func():
		var b := MB.new()
		b.add("box", Vector3(0, 0, -0.05), Vector3(0.17, 0.005, 0.11), Color.WHITE, Vector3(9, 0, 0))
		b.add("box", Vector3(0, 0, 0.05), Vector3(0.17, 0.005, 0.11), Color(0.9, 0.9, 0.88), Vector3(-9, 0, 0))
		return b.build())


static func _m_heart() -> Mesh:
	return _cached("heart", func(): return slab_mesh(_heart(0.34), 0.04, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)))


static func _m_spark() -> Mesh:
	return _cached("spark", func(): return slab_mesh(_star(4, 0.16, 0.035), 0.02, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)))


static func _m_unit_cyl() -> Mesh:
	return _cached("ucyl", func():
		var b := MB.new()
		b.add("cyl", Vector3.ZERO, Vector3.ONE, Color.WHITE, Vector3.ZERO, 12)
		return b.build())


# ================================================================== KARASU BUNSHIN — karga klonu
## Karga: siyah gövde, kızıl (Sharingan) göz, tırtıklı tüylü kanat profili; kanatlar ayrı çırpar
static func _m_crow() -> Array:
	if _mc.has("crow"):
		return _mc["crow"]
	var k := Color(0.11, 0.11, 0.15)
	var b := MB.new()
	b.add("sphere", Vector3(0, 0, 0.02), Vector3(0.17, 0.15, 0.34), k, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.06, -0.19), Vector3(0.13, 0.13, 0.14), k, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.05, -0.3), Vector3(0.05, 0.12, 0.05), Color(0.24, 0.24, 0.27), Vector3(-90, 0, 0), 6)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.055, 0.085, -0.22), Vector3.ONE * 0.032, Color(0.95, 0.08, 0.06), Vector3.ZERO, 6)
	var tail := PackedVector2Array([Vector2(-0.04, 0), Vector2(0.04, 0), Vector2(0.09, -0.21), Vector2(0.03, -0.17), Vector2(0, -0.23), Vector2(-0.03, -0.17), Vector2(-0.09, -0.21)])
	b.add_slab(tail, 0.014, k, Transform3D(_flat_b(), Vector3(0, 0.01, 0.13)))
	var wr := PackedVector2Array([Vector2(0, 0.05), Vector2(0.2, 0.07), Vector2(0.44, 0.0), Vector2(0.39, -0.05), Vector2(0.34, -0.04),
		Vector2(0.3, -0.1), Vector2(0.24, -0.08), Vector2(0.2, -0.15), Vector2(0.14, -0.11), Vector2(0.09, -0.17), Vector2(0.03, -0.12), Vector2(0, -0.1)])
	var wl := PackedVector2Array()
	for p in wr:
		wl.append(Vector2(-p.x, p.y))
	var out := [b.build(), slab_mesh(wr, 0.014, k, Transform3D(_flat_b(), Vector3.ZERO)), slab_mesh(wl, 0.014, k, Transform3D(_flat_b(), Vector3.ZERO))]
	_mc["crow"] = out
	return out


static func _crow(pj: PathJutsu, m: Material, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	put(pj, n, pos)
	var parts := _m_crow()
	n.add_child(mi(parts[0], m))
	var ph := randf_range(0.055, 0.08)
	for s in 2:
		var w := mi(parts[1 + s], m)
		w.position = Vector3(0.05 if s == 0 else -0.05, 0.05, -0.02)
		n.add_child(w)
		var sg := 1.0 if s == 0 else -1.0
		w.rotation.z = 0.2 * sg
		var tw := Game.safe_loops(w.create_tween())
		tw.tween_property(w, "rotation:z", 0.95 * sg, ph)
		tw.tween_property(w, "rotation:z", -0.6 * sg, ph)
	return n


## Yere dökülmüş tüyler (ardıl iz)
static func _feather_litter(pj: PathJutsu, pos: Vector3, n: int, r: float) -> void:
	var b := MB.new()
	var o := PackedVector2Array([Vector2(-0.09, 0), Vector2(-0.05, 0.022), Vector2(0.03, 0.026), Vector2(0.09, 0.004), Vector2(0.05, -0.012), Vector2(0.06, -0.026), Vector2(0.0, -0.018), Vector2(-0.05, -0.02)])
	for i in n:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		var xf := Transform3D((Basis(Vector3.UP, randf() * TAU) * _flat_b()).scaled(Vector3.ONE * randf_range(0.9, 1.5)), Vector3(cos(a) * d, randf() * 0.02, sin(a) * d))
		b.add_slab(o, 0.008, Color(0.1, 0.1, 0.14), xf)
	var m := cel(Color.WHITE, 0.005)
	var x := mi(b.build(), m)
	put(pj, x, pj.gp(pos) + Vector3.UP * 0.04)
	fade_free(x, m, 3.0, 1.0)


## Karga Klonu: beden kara tüylere sökülür, gövdeden onlarca karga (kızıl gözlü) dışa fırlar, sürü hedefe uçup onu çevreleyerek
## döner, sonra tüy yağmuruna çözülür; iki yerde de yerde tüyler kalır. Asıl beden yerinde kopyayla değişir (gerçek gölge klon).
static func karasu_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 20.0)
	var base: Vector3 = c.global_position
	var crow_m := cel(Color.WHITE, 0.012, INK, false, 0.22)
	var fe_m := cel(Color.WHITE, 0.005)
	burst(pj, base + Vector3.UP * 1.1, _m_feather(), fe_m, 40, 1.8, {"r": 0.45, "vmin": 2.0, "vmax": 6.0, "g": Vector3(0, -1.0, 0), "damp": 2.5, "spin": 320.0, "smin": 0.9, "smax": 1.5})
	_feather_litter(pj, base, 14, 1.2)
	var fw = pj.fwd(c, t)
	var ctr: Vector3 = (tt.global_position if tt else base + fw * 8.0) + Vector3.UP * 1.3
	for k in 30:
		var start := base + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.8), randf_range(-0.3, 0.3))
		var cr := _crow(pj, crow_m, start)
		cr.scale = Vector3.ONE * 0.25
		var a0 := randf() * TAU
		var rad := randf_range(1.2, 2.2)
		var h := randf_range(-0.7, 1.0)
		var end := ctr + Vector3(cos(a0) * rad, h, sin(a0) * rad)
		var dv := start - base - Vector3.UP * 1.0
		dv.y = maxf(dv.y, 0.0)
		var out := start + (dv.normalized() if dv.length() > 0.05 else Vector3.UP) * randf_range(0.8, 1.5) + Vector3.UP * randf_range(0.0, 0.8)
		_aim(cr, out)
		var orbit := func(a: float):
			if not is_instance_valid(cr):
				return
			var p := ctr + Vector3(cos(a0 + a) * rad, h + sin(a * 3.0) * 0.25, sin(a0 + a) * rad)
			_aim(cr, p)
			cr.global_position = p
		var tw := cr.create_tween()
		tw.tween_property(cr, "global_position", out, 0.18).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(cr, "scale", Vector3.ONE * randf_range(0.85, 1.2), 0.18)
		tw.tween_callback(func(): _aim(cr, end))
		tw.tween_property(cr, "global_position", end, 0.42 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_method(orbit, 0.0, PI * 1.3, 0.7)
		tw.tween_property(cr, "scale", Vector3.ONE * 0.05, 0.15)
		tw.tween_callback(cr.queue_free)
	pj.decoy(c, c.global_position, 6.0)
	if tt:
		pj.after(0.8, func():
			if not is_instance_valid(tt):
				return
			for e in pj.enemies_near(c, tt.global_position, 3.0):
				if is_instance_valid(e) and not e.is_dead():
					pj.st(e, "stun", 1.5)
					e.take_hit(pj.inf(c, "karasu_bunshin_no_jutsu", 0.4, {"knock": 2.0, "kind": "light"}))
			pj.after(0.6, func():
				if is_instance_valid(tt):
					burst(pj, tt.global_position + Vector3.UP * 1.6, _m_feather(), cel(Color.WHITE, 0.005), 46, 2.0, {"r": 1.4, "vmin": 0.5, "vmax": 2.5, "g": Vector3(0, -1.4, 0), "damp": 1.5, "spin": 260.0, "smin": 0.9, "smax": 1.5})
					_feather_litter(pj, tt.global_position, 16, 1.8)))
	Sfx.play("whoosh", c.global_position, 1.3)


# ================================================================== MIKAZUKI NO MAI — üç yönlü hilal kesiği
## Hilal kılıç izi: düşey düzlemde (fwd-yukarı) süpürülen keskin hilal; tilt ile çapraz
static func _moon_cut(pj: PathJutsu, pos: Vector3, fwd: Vector3, tilt: float, col: Color, r: float) -> void:
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var root := Node3D.new()
	put(pj, root, pos)
	root.global_transform = Transform3D(Basis(side, fwd, Vector3.UP).rotated(fwd, tilt), pos)
	var m := cel(col, 0.022, Color(0.12, 0.22, 0.48))
	var sl := mi(slab_mesh(_crescent(r, r * 0.2, -80.0, 80.0, 22), 0.03), m)
	root.add_child(sl)
	sl.rotation.x = 0.9
	sl.scale = Vector3(1, 0.6, 0.6)
	var tw := sl.create_tween()
	tw.tween_property(sl, "rotation:x", -0.35, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sl, "scale", Vector3.ONE, 0.12)
	fade_free(root, m, 0.14, 0.25)


## Havadaki hilal yolu: sıçrayan bedenin bıraktığı ince ay-ışığı izi (üç iz = üç hilal)
static func _moon_trail(pj: PathJutsu, a: Vector3, b: Vector3, col: Color) -> void:
	var bb := MB.new()
	bb.add_xf("cyl", _seg_xf(Vector3.ZERO, b - a, 0.09), Color.WHITE, 6)
	bb.add("sphere", b - a, Vector3.ONE * 0.09, Color.WHITE, Vector3.ZERO, 6)
	var m := cel(col, 0.012, Color(0.18, 0.28, 0.55))
	var n := mi(bb.build(), m)
	put(pj, n, a)
	fade_free(n, m, 0.12, 0.35)


## Klon belirişi / kayboluşu: dikey ince hilal parıltısı + iki yanda çöken hız çizgileri (duman yok)
static func _moon_glint(pj: PathJutsu, pos: Vector3, fwd: Vector3, s: float) -> void:
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var root := Node3D.new()
	put(pj, root, pos)
	root.global_transform = Transform3D(Basis(fwd, Vector3.UP.cross(fwd), Vector3.UP), pos)
	var m := cel(Color(0.85, 0.93, 1.0), 0.016, Color(0.14, 0.24, 0.5))
	var b := MB.new()
	b.add_slab(_crescent(0.9, 0.22, -70.0, 70.0, 16), 0.02, Color.WHITE)
	for i in 4:
		var z := -0.7 + i * 0.45   # yerel z = yukarı: dikey hız çizgileri iki yanda
		b.add("box", Vector3(0, 0.55 + (i % 2) * 0.15, z), Vector3(0.015, 0.025, 0.36), Color.WHITE)
		b.add("box", Vector3(0, -0.55 - (i % 2) * 0.15, z + 0.2), Vector3(0.015, 0.025, 0.36), Color.WHITE)
	var x := mi(b.build(), m)
	root.add_child(x)
	x.scale = Vector3(1, 0.2, 0.2) * s
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3(1, 1.1, 0.7) * s, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(x, "scale", Vector3(1, 1.3, 0.05) * s, 0.18)
	fade_free(root, m, 0.1, 0.2)


## Kesişme noktası: altı uçlu keskin parıltı + yerde üç hilal yarığı (yavaş söner)
static func _moon_impact(pj: PathJutsu, at: Vector3, d0: Vector3) -> void:
	var g := pj.gp(at)
	var b := MB.new()
	for k in 3:
		var dir := d0.rotated(Vector3.UP, TAU * k / 3.0 + 0.4)
		b.add_slab(_crescent(1.5, 0.22, -55.0, 55.0, 14), 0.02, Color(0.14, 0.13, 0.17), Transform3D(_gb(dir), dir * -0.6))
	var gm := cel(Color.WHITE, 0.0)
	var scar := mi(b.build(), gm)
	put(pj, scar, g + Vector3.UP * 0.04)
	fade_free(scar, gm, 2.5, 1.0)
	var fm := cel(Color(0.95, 0.98, 1.0), 0.02, Color(0.15, 0.25, 0.5))
	var fl := mi(slab_mesh(_star(6, 1.1, 0.16, 0.2), 0.03, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)), fm)
	put(pj, fl, at + Vector3.UP * 1.1)
	var cam := _cam(pj)
	if cam:
		_aim(fl, cam.global_position)
	fl.scale = Vector3.ONE * 0.3
	var tw := fl.create_tween()
	tw.tween_property(fl, "scale", Vector3.ONE * 1.2, 0.08)
	fade_free(fl, fm, 0.08, 0.16)


## Konoha-Ryū Mikazuki no Mai (kanon, Hayate Gekkō): kullanıcı ve iki gölge klonu kılıçla hilal düzeninde havaya sıçrayıp
## üç ayrı yönden AYNI ANDA keser. Görünüş: klonlar hilal parıltısıyla belirir, üç beden havada üç ince ay-ışığı yayı çizer,
## üç çapraz hilal kesiği tek noktada kesişir, yerde üç hilal yarığı kalır.
static func mikazuki_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.1)
	pj._ensure_blade(c, 1.4)
	var at = tt.global_position if tt else pj.gp(c.global_position + c.face_dir() * 7.0)
	var d0 = (at - c.global_position)
	d0.y = 0
	d0 = d0.normalized() if d0.length() > 0.1 else c.face_dir()
	var actors = [c]
	for k in 2:
		var cl = pj.decoy(c, c.global_position + d0.cross(Vector3.UP) * (2.0 if k == 0 else -2.0), 1.4)
		if cl.get("model") and cl.model:
			cl.model.look["weapon_r"] = pj._held_or(c, "katana")
		_moon_glint(pj, cl.global_position + Vector3.UP * 1.0, d0, 1.0)
		actors.append(cl)
	var starts = []
	var ends = []
	for k in 3:
		var ang = deg_to_rad([0.0, 70.0, -70.0][k])
		var dir = d0.rotated(Vector3.UP, ang)
		starts.append(actors[k].global_position)
		ends.append(pj.gp(at - dir * 1.3))
	Sfx.play("whoosh", c.global_position, 1.1)
	var prev = {}
	var step = func(i, k):
		for n in 3:
			var a2 = actors[n]
			if not is_instance_valid(a2):
				continue
			var p = (starts[n] as Vector3).lerp(ends[n], k) + Vector3.UP * sin(k * PI) * 3.2
			a2.global_position = p
			if a2.get("facing") != null:
				a2.facing = atan2(-(at - p).x, -(at - p).z)   # hedefe dön (Fighter.face_dir ile aynı açı)
			if i % 2 == 0:
				var q = p + Vector3.UP * 1.0
				if prev.has(n):
					_moon_trail(pj, prev[n], q, Color(0.8, 0.9, 1.0))
				prev[n] = q
	var finish = func():
		var hit_at = tt.global_position if tt and pj.live(tt) else at
		for n in 3:
			var a3 = actors[n]
			if not is_instance_valid(a3):
				continue
			var dd = (hit_at - a3.global_position)
			dd.y = 0
			dd = dd.normalized() if dd.length() > 0.05 else d0
			if a3.get("model") and a3.model:
				a3.model.play("slash_c", 0.05, 1.6, true)
			_moon_cut(pj, hit_at + Vector3.UP * 1.1 - dd * 0.6, dd, [0.0, 0.55, -0.55][n], Color(0.92, 0.95, 1.0), 1.7)
		_moon_impact(pj, hit_at, d0)
		pj.hit(c, hit_at + Vector3.UP, 1.9, pj.inf(c, "mikazuki_no_mai", 2.0, {"knock": 8.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.12}))
		Sfx.play("clink", hit_at, 0.9)
		for n in range(1, 3):
			var cl2 = actors[n]
			pj.after(0.35, func():
				if is_instance_valid(cl2):
					_moon_glint(pj, cl2.global_position + Vector3.UP * 1.0, d0, 0.8)
					cl2.queue_free())
	pj.every(0.42, 1.0 / 60.0, step, finish)


# ================================================================== SHIKIGAMI NO MAI — Konan'ın kâğıdı
## Konan'ın katlanmış dört uçlu kâğıt şurikeni: sivri yıldız + çapraz kat çizgileri
static func _m_origami_star() -> Mesh:
	return _cached("pstar", func():
		var b := MB.new()
		b.add_slab(_star(4, 0.24, 0.07, PI * 0.25), 0.012, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
		for k in 2:
			b.add("box", Vector3(0, 0.008, 0), Vector3(0.012, 0.004, 0.46), Color(0.72, 0.72, 0.74), Vector3(0, 45 + k * 90, 0))
		return b.build())


## Kâğıt kanadı: iki sıra uzun kâğıt yaprağı yelpaze gibi dizilir (sağ / sol)
static func _m_wing(right: bool) -> Mesh:
	return _cached("pwing%d" % int(right), func():
		var b := MB.new()
		for row in 2:
			for i in 8:
				var th := lerpf(4.0, 105.0, i / 7.0)
				var L := (0.8 - row * 0.28) + i * 0.035
				var dv := Vector3(cos(deg_to_rad(th)), sin(deg_to_rad(th)), 0)
				var cpos := dv * (0.14 + L * 0.5) + Vector3(0, 0, row * 0.035)
				var col := Color.WHITE if (i + row) % 2 == 0 else Color(0.9, 0.9, 0.9)
				if right:
					b.add("box", cpos, Vector3(L, 0.15, 0.01), col, Vector3(0, 0, th))
				else:
					b.add("box", Vector3(-cpos.x, cpos.y, cpos.z), Vector3(L, 0.15, 0.01), col, Vector3(0, 0, 180.0 - th))
		return b.build())


## Kâğıt kelebek: iki üçgen kanat çırpar (Konan'ın kâğıt kelebekleri)
static func _butterfly(parent: Node3D, m: Material) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var ph := randf_range(0.07, 0.1)
	for s in 2:
		var sg := 1.0 if s == 0 else -1.0
		var o := PackedVector2Array([Vector2(0, 0.02), Vector2(0.13 * sg, 0.1), Vector2(0.17 * sg, -0.02), Vector2(0.09 * sg, -0.11), Vector2(0, -0.04)])
		var w := mi(slab_mesh(o, 0.006, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)), m)
		n.add_child(w)
		var tw := Game.safe_loops(w.create_tween())
		tw.tween_property(w, "rotation:z", 1.0 * sg, ph)
		tw.tween_property(w, "rotation:z", -0.25 * sg, ph)
	return n


## Kollardan kâğıt seli: yapraklar elden sökülüp kıvrılarak yana akar, sonra uçlarda dağılır
static func _paper_stream(pj: PathJutsu, from: Vector3, to: Vector3, n: int, m: Material) -> void:
	var mesh := _m_sheet()
	for i in n:
		var x := mi(mesh, m)
		put(pj, x, from + Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15)))
		x.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var p0 := x.global_position
		var p2 := to + Vector3(randf_range(-0.7, 0.7), randf_range(-0.6, 0.9), randf_range(-0.7, 0.7))
		var p1 := (p0 + p2) * 0.5 + Vector3(randf_range(-1.2, 1.2), randf_range(0.4, 1.6), randf_range(-1.2, 1.2))
		var spin := Vector3(randf_range(-9, 9), randf_range(-12, 12), randf_range(-9, 9))
		var r0 := x.rotation
		var mv := func(u: float):
			if is_instance_valid(x):
				x.global_position = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
				x.rotation = r0 + spin * u
		var tw := x.create_tween()
		tw.tween_interval(i * 0.012)
		tw.tween_method(mv, 0.0, 1.0, randf_range(0.45, 0.7)).set_ease(Tween.EASE_OUT)
		tw.tween_property(x, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_callback(x.queue_free)


## Sırttan açılan kâğıt melek kanatları: kısa bir çırpış, sonra yaprak yaprak dağılır
static func _paper_wings(pj: PathJutsu, c: Node3D, dur: float, m: Material) -> void:
	var root := Node3D.new()
	put(pj, root, c.global_position + Vector3.UP * 1.35)
	for s in 2:
		var sg := 1.0 if s == 0 else -1.0
		var w := mi(_m_wing(s == 0), m)
		root.add_child(w)
		w.position = Vector3(0, 0, 0.24)
		w.scale = Vector3(0.05, 0.05, 1)
		var tw := w.create_tween()
		tw.tween_property(w, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(w, "rotation:y", -0.22 * sg, 0.22)
		tw.tween_property(w, "rotation:y", 0.12 * sg, 0.25)
		tw.tween_interval(maxf(0.05, dur - 1.0))
		tw.tween_property(w, "scale", Vector3(0.05, 0.05, 1), 0.2)
	var follow := func(_i, _k):
		if is_instance_valid(c) and is_instance_valid(root):
			var f: Vector3 = c.face_dir()
			f.y = 0.0
			if f.length() > 0.1:
				root.global_transform = Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), c.global_position + Vector3.UP * 1.35)
	var done := func():
		if is_instance_valid(root):
			burst(pj, root.global_position, _m_sheet(), m, 26, 1.8, {"r": 1.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -1.2, 0), "damp": 1.2, "spin": 240.0, "smin": 0.8, "smax": 1.3})
			root.queue_free()
	pj.every(dur, 1.0 / 30.0, follow, done)


## Uçan şurikenin ardından savrulan küçük kâğıt kırpıntıları
static func _paper_tail(pj: PathJutsu, pr: Projectile, m: Material) -> void:
	var acc := {"t": 0.0}
	pr.on_tick = func(p, dt):
		acc["t"] += dt
		if acc["t"] < 0.06:
			return
		acc["t"] = 0.0
		var x := mi(_m_sheet(), m)
		put(pj, x, p.global_position)
		x.scale = Vector3.ONE * 0.55
		x.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var tw := x.create_tween()
		tw.tween_property(x, "global_position", x.global_position + Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)), 0.5)
		tw.parallel().tween_property(x, "rotation:y", x.rotation.y + 6.0, 0.5)
		tw.parallel().tween_property(x, "scale", Vector3.ONE * 0.05, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)


## Yere düşüp yatan kâğıtlar (ardıl iz)
static func _paper_litter(pj: PathJutsu, pos: Vector3, n: int, r: float) -> void:
	var b := MB.new()
	for i in n:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		b.add("box", Vector3(cos(a) * d, randf() * 0.02, sin(a) * d), Vector3(0.17, 0.006, 0.22), Color.WHITE if i % 2 == 0 else Color(0.9, 0.9, 0.88), Vector3(randf_range(-6, 6), randf() * 360.0, randf_range(-6, 6)))
	var m := cel(PAPER, 0.006, PAPER_INK)
	var x := mi(b.build(), m)
	put(pj, x, pj.gp(pos) + Vector3.UP * 0.03)
	fade_free(x, m, 2.8, 1.0)


## Shiki Dansı (Konan): kollar kâğıda çözülür — iki koldan kâğıt seli akar, sırtta kâğıt melek kanatları açılır,
## 36 katlanmış kâğıt şuriken ve kâğıt kelebekler bedenin çevresinde döner (kalkan), sonra şurikenler hedefe yağar;
## kâğıtlar süzülüp yere serilir.
static func shikigami_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	pj.anim(c, "cast", 1.0)
	var sheet_m := cel(PAPER, 0.006, PAPER_INK)
	for k in 2:
		_paper_stream(pj, pj.hand_pos(c, k == 0), c.global_position + Vector3.UP * 1.2 + c.face_dir().cross(Vector3.UP) * (k * 2 - 1) * 2.0, 22, sheet_m)
	_paper_wings(pj, c, 1.4, cel(PAPER, 0.008, PAPER_INK))
	var ring = Node3D.new()
	pj.get_tree().current_scene.add_child(ring)
	var star_mesh := _m_origami_star()
	var star_m := cel(PAPER, 0.008, PAPER_INK)
	var stars = []
	for k in 36:
		var s = Node3D.new()
		s.add_child(mi(star_mesh, star_m))
		ring.add_child(s)
		stars.append(s)
	var flies = []
	for k in 6:
		flies.append(_butterfly(ring, sheet_m))
	if c is Player:
		Buffs.add("shikigami", 1.2, {"armor": 0.3, "_name": "Kâğıt Kalkan"})
	var orbit = func(_i, k):
		if pj.live(c) and is_instance_valid(ring):
			ring.global_position = c.global_position + Vector3.UP * 1.1
			for n in stars.size():
				var a = TAU * n / stars.size() + k * 9.0
				stars[n].position = Vector3(cos(a) * (1.5 + sin(n) * 0.35), sin(n * 1.7) * 0.9, sin(a) * (1.5 + sin(n) * 0.35))
				stars[n].rotation.y = k * 30.0 + n
			for n in flies.size():
				var b = -k * 5.0 + TAU * n / flies.size()
				flies[n].position = Vector3(cos(b) * 2.3, 0.6 + sin(k * 12.0 + n) * 0.5, sin(b) * 2.3)
				flies[n].rotation.y = -b
	var release = func():
		if not is_instance_valid(ring):
			return
		if not is_instance_valid(c):
			ring.queue_free()
			return
		var tt = pj.tg(c, t, 30.0)
		for n in stars.size():
			var from = stars[n].global_position
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.1, 0.1)), 45.0, mi(star_mesh, star_m), pj.inf(c, "shikigami_no_mai", 0.08, {"knock": 1.0, "kind": "light", "bleed": 1.0}), null, false, 1.2)
			pr.spin = Vector3(0, 40, 0)
			if n % 3 == 0:
				_paper_tail(pj, pr, sheet_m)
		burst(pj, ring.global_position, _m_sheet(), cel(PAPER, 0.006, PAPER_INK), 34, 2.2, {"r": 1.6, "vmin": 0.3, "vmax": 1.6, "g": Vector3(0, -1.3, 0), "damp": 1.0, "spin": 240.0})
		_paper_litter(pj, c.global_position, 18, 2.2)
		ring.queue_free()
		Sfx.play("whoosh", c.global_position, 1.3)
	pj.every(1.1, 1.0 / 30.0, orbit, release)


# ================================================================== ZANKŪHA / ZANKŪKYOKUHA — Zaku'nun avuç hava basıncı
## Hava avuçlardaki deliklere çekilir: içe akan kısa çizgiler
static func _air_suck(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var m := cel(AIR, 0.008, AIR_EDGE)
	for i in 9:
		var dv := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var x := mi(_m_shard(), m)
		put(pj, x, pos + dv * randf_range(1.2, 1.8) * s)
		x.look_at(pos, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT)
		x.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		x.scale = Vector3(1, s * 1.3, 1)
		var tw := x.create_tween()
		tw.tween_interval(i * 0.015)
		tw.tween_property(x, "global_position", pos, 0.24).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(x, "scale", Vector3(1, 0.1, 1), 0.24)
		tw.tween_callback(x.queue_free)


## Avuç deliğinden ileri fışkıran ince hava iğneleri
static func _palm_pop(pj: PathJutsu, from: Vector3, dir: Vector3) -> void:
	burst(pj, from, _m_shard(), cel(AIR, 0.008, AIR_EDGE), 10, 0.25, {"r": 0.08, "dir": dir, "spread": 22.0, "vmin": 10.0, "vmax": 16.0, "g": Vector3.ZERO, "align": true, "smin": 0.6, "smax": 1.0, "hold": 0.3})


## Basınçlı hava merceği: basık kırılgan kabuk + arkasında incelen akım hunisi + ikinci dalga halkası
static func _air_lens() -> Node3D:
	var n := Node3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 12
	var am := _plain("air", AIR_SHADER)
	var lens := mi(sm, am)
	lens.scale = Vector3(1.15, 1.15, 0.38)
	n.add_child(lens)
	var lens2 := mi(sm, am)
	lens2.scale = Vector3(0.8, 0.8, 0.3)
	lens2.position = Vector3(0, 0, 0.4)
	n.add_child(lens2)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.08
	cm.height = 1.8
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	var tail := mi(cm, streak_mat(Color(0.95, 1.0, 0.97, 0.9), AIR_EDGE, 14.0, 3.5, 1.0))
	tail.rotation_degrees = Vector3(-90, 0, 0)
	tail.position = Vector3(0, 0, 0.9)
	n.add_child(tail)
	return n


## Merminin altında zemin kazınır: savrulan toz topakları + kısa sürtme izi
static func _scour(pj: PathJutsu, g: Vector3, dir: Vector3) -> void:
	burst(pj, g + Vector3.UP * 0.15, _m_blob(), cel(DUST, 0.01, SAND_INK), 4, 0.6, {"r": 0.3, "dir": Vector3.UP + dir * 0.5, "spread": 60.0, "vmin": 2.0, "vmax": 4.5, "g": Vector3(0, -7, 0), "smin": 0.7, "smax": 1.2})
	var m := cel(Color(0.3, 0.24, 0.17), 0.0)
	var x := mi(slab_mesh(_rect(1.3, 0.12), 0.01, Color.WHITE, Transform3D(_gb(dir), Vector3.ZERO)), m)
	put(pj, x, g + Vector3.UP * 0.04)
	fade_free(x, m, 0.9, 0.6)


## Kesici Hava Dalgası (Zaku): hava avuç deliklerine çekilir, avuçtan üç basınç merceği fırlar (kırılgan kabuk + akım hunisi),
## yolda zemini kazır; mercekler uçtukça büyür.
static func zankuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "push", 1.4)
	var tt = pj.tg(c, t, 22.0)
	_air_suck(pj, pj.hand_pos(c, true), 0.5)
	for k in 3:
		pj.after(0.15 + k * 0.12, func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, k % 2 == 0)
			var dir = pj.aim_at(c, tt, from)
			var rm := _air_lens()
			var pr = pj.shot(c, from, dir, 34.0, rm, pj.inf(c, "zankuha", 0.45, {"knock": 14.0, "kind": "heavy", "element": "fuuton"}), null, true, 0.75)
			pr.radius = 1.0
			rm.create_tween().tween_property(rm, "scale", Vector3.ONE * 2.8, 0.75)
			_palm_pop(pj, from, dir)
			pj.every(0.75, 0.1, func(_i, _k):
				if is_instance_valid(pr):
					_scour(pj, pj.gp(pr.global_position), dir), Callable())
			Sfx.play("wind", from, 1.3, 0.5))


## Büyük basınç yelpazesi: avuçlardan ışınsal açılan, birbirine eğik beş dilim akım çizgisi (çizgiler dışa akar)
static func _air_fan(pj: PathJutsu, from: Vector3, d: Vector3, L: float, half: float) -> void:
	var root := Node3D.new()
	put(pj, root, from)
	root.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), from)
	var m := streak_mat(Color(0.97, 0.95, 1.0, 0.95), Color(0.58, 0.54, 0.78), 46.0, 2.4, 0.0)
	var mesh := _sector(0.3, L, half, 28)
	for k in 5:
		var x := mi(mesh, m)
		root.add_child(x)
		x.rotation.z = k * PI / 5.0
	root.scale = Vector3(0.25, 0.25, 0.08)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)
	fade_free(root, m, 0.5, 0.45)


## Yelpazenin ön cephesi: zeminden kalkan toz duvarı + yelpaze gibi açılan kazıma izleri (yarık zemin: gerçek yavaşlatan alan)
static func _fan_front(pj: PathJutsu, q: Vector3, d: Vector3, w: float) -> void:
	var g := pj.gp(q)
	burst(pj, g + Vector3.UP * 0.3, _m_blob(), cel(DUST, 0.012, SAND_INK), 6, 0.8, {"r": w * 0.35, "dir": d + Vector3.UP * 0.35, "spread": 35.0, "vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -4, 0), "damp": 2.0, "smin": 1.2, "smax": 2.2})
	var b := MB.new()
	for i in 3:
		var dv := d.rotated(Vector3.UP, (i - 1) * 0.18)
		b.add_slab(_rect(2.2, 0.1), 0.01, Color.WHITE, Transform3D(_gb(dv), d.cross(Vector3.UP) * (i - 1) * w * 0.3))
	var m := cel(Color(0.3, 0.24, 0.18), 0.0)
	var x := mi(b.build(), m)
	put(pj, x, g + Vector3.UP * 0.04)
	fade_free(x, m, 3.5, 1.2)
	GroundFX.add(g, "cracked", 1.08, 5.0)   # yarık zemin: üstünden geçen yavaşlar (eski çatlak izinin oyun etkisi)


## Büyük Hava Basıncı Dalgası (Zaku): iki avuca hava çekilir, avuçlardan ışınsal dev basınç yelpazesi açılır (ref: beyaz-lila
## ışınsal patlama), önünde toz duvarı yuvarlanır, zeminde yelpaze kazıma izleri kalır.
static func zankukyokuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.anim(c, "push", 1.2)
	var d = pj.fwd(c, t)
	_air_suck(pj, c.global_position + Vector3.UP * 1.2 + d, 1.0)
	pj.after(0.15, func():
		_air_fan(pj, c.global_position + Vector3.UP * 1.1 + d * 0.6, d, 22.0, deg_to_rad(15.0))
		_palm_pop(pj, c.global_position + Vector3.UP * 1.1 + d * 0.6, d)
		for k in 8:
			pj.after(k * 0.05, func():
				var q = c.global_position + Vector3.UP * 1.0 + d * (3.0 + k * 2.4)
				_fan_front(pj, q, d, 3.0 + k * 0.6))
		Combat.hit_zone(c, c.global_position, d, 22.0, 30.0, 4.0, pj.inf(c, "zankukyokuha", 1.4, {"knock": 22.0, "launch": 5.0, "kind": "heavy", "element": "fuuton", "dir": d}))
		pj.shake(0.7))
	Sfx.play("wind", c.global_position, 0.5)


# ================================================================== DAIHŌKŌ — büyük kükreme
## Dişli ses halkası: d'ye dik düzlemde, krem-turuncu, koyu kontur; s ölçeğe büyür
static func _roar_ring(pj: PathJutsu, q: Vector3, d: Vector3, s0: float, s1: float, dur: float) -> void:
	var root := Node3D.new()
	put(pj, root, q)
	root.global_transform = Transform3D(Basis(d, Vector3.UP.cross(d).normalized(), Vector3.UP), q)
	var m := cel(Color(1.0, 0.93, 0.8), 0.03, Color(0.45, 0.2, 0.08))
	var x := mi(_ring_mesh(0.78, 0.88, 1.08, 22, Color.WHITE, 0.05, Basis.IDENTITY), m)
	root.add_child(x)
	x.scale = Vector3(1, s0, s0)
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3(1, s1, s1), dur).set_ease(Tween.EASE_OUT)
	fade_free(root, m, dur * 0.4, dur * 0.6)


## Sökülüp dikilen zemin kaldırım taşları (ref: yer blok blok kalkar) + savrulan parçalar
static func _rock_slabs(pj: PathJutsu, g: Vector3, d: Vector3, k: int) -> void:
	var side := d.cross(Vector3.UP).normalized()
	var m := cel(Color.WHITE, 0.025, Color(0.16, 0.15, 0.17))
	for s in [-1.0, 1.0]:
		var b := MB.new()
		var w := randf_range(0.9, 1.4)
		b.add("box", Vector3(0, 0.12, 0), Vector3(w, 0.28, randf_range(0.7, 1.0)), ROCK, Vector3(0, randf_range(-12, 12), 0))
		b.add("box", Vector3(w * 0.25, 0.3, 0.1), Vector3(w * 0.4, 0.14, 0.4), ROCK.lightened(0.1), Vector3(5, 20, -6))
		var x := mi(b.build(), m)
		var p := pj.gp(g + side * s * randf_range(0.8, 1.8 + k * 0.35))
		put(pj, x, p + Vector3.DOWN * 0.45)
		x.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP).rotated(side, deg_to_rad(randf_range(22.0, 48.0))), p + Vector3.DOWN * 0.45)
		var tw := x.create_tween()
		tw.tween_property(x, "global_position", p + Vector3.UP * 0.05, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.8)
		tw.tween_property(x, "global_position", p + Vector3.DOWN * 0.6, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)
	burst(pj, g + Vector3.UP * 0.3, _m_chunk(), cel(ROCK, 0.012, Color(0.16, 0.15, 0.17)), 5, 1.0, {"r": 0.8, "dir": d + Vector3.UP * 1.2, "spread": 40.0, "vmin": 5.0, "vmax": 9.0, "g": Vector3(0, -14, 0), "spin": 400.0, "smin": 0.8, "smax": 1.6, "end_scale": 1.0})


## Büyük Kükreme: önce hava ağza çekilir (daralan dişli halkalar), sonra ağızdan ileri art arda büyüyen dişli ses halkaları
## yayılır; yolunda zemin blok blok sökülüp dikilir, kaya parçaları savrulur.
static func daihoko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	for k in 2:
		pj.after(k * 0.1, func():
			if pj.live(c):
				_roar_ring(pj, pj._mouth_pos(c) + d * 1.2, d, 2.2, 0.3, 0.16))
	pj.after(0.25, func():
		for k in 8:
			pj.after(k * 0.05, func():
				var q = pj._mouth_pos(c) + d * (1.0 + k * 2.4)
				_roar_ring(pj, q, d, (2.5 + k * 1.0) * 0.3, 2.5 + k * 1.0, 0.35)
				_rock_slabs(pj, pj.gp(q), d, k))
		Combat.hit_zone(c, c.global_position, d, 22.0, 30.0, 4.0, pj.inf(c, "daihoko", 1.4, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "stun": 0.5}))
		pj.shake(1.0))
	Sfx.play("roar", c.global_position, 0.7)


# ================================================================== MATEKI: GENBU SŌKYOKU — Tayuya'nın flütü ve Doki'ler
## Ezgi: flütten kıvrılarak akan nota şeritleri + yükselip sönen nota işaretleri
static func _melody(pj: PathJutsu, from: Vector3, f: Vector3) -> void:
	var side := f.cross(Vector3.UP).normalized()
	var dv := (f + side * randf_range(-0.8, 0.8) + Vector3.UP * randf_range(0.0, 0.5)).normalized()
	var pts := []
	var ph := randf() * TAU
	for i in 18:
		var u := i / 17.0
		pts.append(dv * u * 3.2 + Vector3.UP * sin(u * 9.0 + ph) * 0.22 + side * cos(u * 7.0 + ph) * 0.12)
	var m := cel(Color(0.86, 0.78, 1.0, 0.9), 0.0, INK, true)
	var x := mi(_ribbon(pts, 0.07, side.cross(dv).normalized()), m)
	put(pj, x, from)
	var tw := x.create_tween()
	tw.tween_property(x, "global_position", from + dv * 1.2 + Vector3.UP * 0.3, 0.8)
	fade_free(x, m, 0.3, 0.5)
	for j in 2:
		var l := Label3D.new()
		l.text = ["♪", "♫", "♬"][randi() % 3]
		l.font_size = 72
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(0.88, 0.78, 1.0)
		l.outline_modulate = Color(0.22, 0.08, 0.3)
		l.outline_size = 14
		put(pj, l, from + dv * randf_range(0.8, 2.4) + Vector3.UP * randf_range(0.0, 0.4))
		var tl := l.create_tween()
		tl.tween_property(l, "global_position", l.global_position + Vector3.UP * 0.9, 0.9)
		tl.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
		tl.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
		tl.tween_callback(l.queue_free)


## Doki zeminden yükselir: yerde mor dişli mühür yarığı + bedenin çevresinde yükselen mor ruh sarmalları
static func _doki_rise(pj: PathJutsu, at: Vector3) -> void:
	var gm := cel(Color(0.32, 0.16, 0.4), 0.0)
	var ring := mi(_ring_mesh(1.2, 1.4, 1.9, 16, Color.WHITE, 0.02, _flat_b()), gm)
	put(pj, ring, pj.gp(at) + Vector3.UP * 0.05)
	ring.scale = Vector3.ONE * 0.2
	ring.create_tween().tween_property(ring, "scale", Vector3.ONE * 1.3, 0.3).set_ease(Tween.EASE_OUT)
	fade_free(ring, gm, 1.2, 0.8)
	_wisps(pj, at, 5, 1.3, 4.5)


## Mor ruh sarmalları (helezon şeritler): yükselir, söner
static func _wisps(pj: PathJutsu, at: Vector3, n: int, r: float, h: float) -> void:
	var m := cel(Color(0.62, 0.45, 0.85, 0.75), 0.0, INK, true)
	var holder := Node3D.new()
	put(pj, holder, pj.gp(at))
	for i in n:
		var pts := []
		var a0 := TAU * i / n
		for j in 16:
			var u := j / 15.0
			var a := a0 + u * 3.5
			pts.append(Vector3(cos(a) * r * (1.0 - u * 0.4), u * h, sin(a) * r * (1.0 - u * 0.4)))
		var x := mi(_ribbon(pts, 0.16, Vector3(cos(a0), 0, sin(a0))), m)
		holder.add_child(x)
		x.scale = Vector3(1, 0.1, 1)
		var tw := x.create_tween()
		tw.tween_property(x, "scale", Vector3.ONE, 0.45).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(x, "rotation:y", 1.2, 0.9)
	fade_free(holder, m, 0.45, 0.45)


## Gürz darbesi: yerde ışınsal kırık yarıklar + savrulan kaya + yere yayılan toz halkası
static func _club_crater(pj: PathJutsu, g: Vector3) -> void:
	var b := MB.new()
	for i in 9:
		var a := TAU * i / 9.0 + randf_range(-0.2, 0.2)
		var p := Vector3.ZERO
		var pts := [p]
		for j in 4:
			a += randf_range(-0.4, 0.4)
			p += Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 0.8)
			pts.append(p)
		for j in pts.size() - 1:
			var xf := _seg_xf(pts[j], pts[j + 1], 1.0)
			var bx := xf.basis.orthonormalized()
			var L: float = (pts[j + 1] - pts[j]).length()
			b.add_xf("box", Transform3D(Basis(bx.x * (0.11 - j * 0.02), bx.y * L, bx.z * 0.02), xf.origin), Color(0.14, 0.11, 0.09))
	var m := cel(Color.WHITE, 0.0)
	var x := mi(b.build(), m)
	put(pj, x, g + Vector3.UP * 0.03)
	fade_free(x, m, 4.0, 1.0)
	burst(pj, g + Vector3.UP * 0.3, _m_chunk(), cel(ROCK, 0.012, Color(0.16, 0.15, 0.17)), 10, 1.0, {"r": 0.6, "dir": Vector3.UP, "spread": 50.0, "vmin": 4.0, "vmax": 8.0, "g": Vector3(0, -14, 0), "spin": 400.0, "smin": 0.8, "smax": 1.5, "end_scale": 1.0})
	burst(pj, g + Vector3.UP * 0.25, _m_blob(), cel(DUST, 0.012, SAND_INK), 16, 0.7, {"r": 0.6, "dir": Vector3.RIGHT, "spread": 180.0, "flat": 1.0, "vmin": 5.0, "vmax": 8.0, "g": Vector3.ZERO, "damp": 6.0, "smin": 1.4, "smax": 2.2})


## Pençe tırmığı: üç paralel ince kemik-beyazı kesik yay
static func _claw_rake(pj: PathJutsu, pos: Vector3, dir: Vector3) -> void:
	for q in 3:
		_moon_cut_thin(pj, pos + Vector3.UP * (q - 1) * 0.3, dir)


static func _moon_cut_thin(pj: PathJutsu, pos: Vector3, fwd: Vector3) -> void:
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var root := Node3D.new()
	put(pj, root, pos)
	# yatay tırmık: hilal düzlemi yataya yakın (kemik bıçağın yana savruluşu)
	root.global_transform = Transform3D(Basis(Vector3.UP, fwd, -side).rotated(fwd, 0.25), pos)
	var m := cel(Color(0.96, 0.92, 0.78), 0.016, Color(0.35, 0.12, 0.1))
	var sl := mi(slab_mesh(_crescent(1.8, 0.12, -60.0, 60.0, 18), 0.02), m)
	root.add_child(sl)
	sl.rotation.x = -0.8
	var tw := sl.create_tween()
	tw.tween_property(sl, "rotation:x", 0.5, 0.12).set_ease(Tween.EASE_OUT)
	fade_free(root, m, 0.12, 0.22)


## Ruh solucanı çarpışı: mor topakçıklar dağılır
static func _soul_pop(pj: PathJutsu, p: Vector3) -> void:
	burst(pj, p, _m_blob(), cel(Color(0.55, 0.42, 0.75), 0.01, Color(0.18, 0.08, 0.26)), 10, 0.5, {"r": 0.3, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, 1.5, 0), "damp": 2.0, "smin": 0.6, "smax": 1.1})


## Doki çekilir: yere gömülerek söner + mor sarmallar
static func _doki_sink(pj: PathJutsu, dk: Node3D) -> void:
	_wisps(pj, dk.global_position, 4, 1.2, 4.0)
	var tw := dk.create_tween()
	tw.tween_property(dk, "scale", Vector3(1.1, 0.02, 1.1), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(dk.queue_free)


## Mateki: Genbu Sōkyoku (kanon, Tayuya): flütle çağrılan üç Doki (Gürzlü, Pençeli, Sargılı) — yalnız Tayuya'nın ezgisiyle
## hareket eder. Görünüş: flütten nota şeritleri akar, Doki'ler yerde mor mühür yarığından ruh sarmallarıyla yükselir; gürz
## yeri ışınsal yarar, pençe üç kemik kesiği bırakır, sargılının ruh solucanları mor topakçıklara dağılır; sonunda Doki'ler
## yere gömülür. Gerçek modeller: Doki (scripts/actors/doki.gd).
static func mateki_genbu_sokyoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	var dur = 8.0
	pj.busy(c, 1.0)
	var m = c.get("model")
	if m and m.has_method("hold_temp"):
		m.hold_temp("mateki", dur, "Right", 1.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	for k in 3:
		pj.after(k * 0.15, func():
			if pj.live(c):
				_melody(pj, pj._mouth_pos(c), d))
	var dokis = []
	for k in 3:
		var at = pj.gp(c.global_position - d * 1.5 + side * (k - 1) * 4.2)
		_doki_rise(pj, at)
		var dk = Doki.spawn(pj.get_tree().current_scene, at, atan2(-d.x, -d.z), k)
		dk.scale = Vector3(1, 0.05, 1)
		dk.create_tween().tween_property(dk, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dokis.append(dk)
	Sfx.play("poof", c.global_position, 0.6)
	# ezgi sürerken her Doki sırayla saldırır (ritim: 1.1 sn); hedefe doğru ağır adımlarla yürür
	var beat = {"n": 0}
	pj.every(dur, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		var cur = tt if pj.live(tt) else pj.tg(c, null, 26.0)
		for j in dokis.size():
			var dk: Doki = dokis[j]
			if not is_instance_valid(dk) or cur == null:
				continue
			var want = cur.global_position + side * (j - 1) * 3.0 - (cur.global_position - c.global_position).normalized() * 2.8
			var v = want - dk.global_position
			v.y = 0
			if v.length() > 0.6:
				dk.global_position += v.normalized() * minf(v.length(), 0.45)
				dk.global_position.y = pj.gp(dk.global_position).y
			var fl = cur.global_position - dk.global_position
			fl.y = 0
			if fl.length() > 0.1:
				dk.rotation.y = lerp_angle(dk.rotation.y, atan2(-fl.x, -fl.z), 0.3), Callable())
	pj.every(dur - 0.6, 1.1, func(_i, _k):
		if not pj.live(c):
			return
		var cur = tt if pj.live(tt) else pj.tg(c, null, 26.0)
		if cur == null:
			return
		var j = beat["n"] % 3
		beat["n"] += 1
		var dk: Doki = dokis[j]
		if not is_instance_valid(dk):
			return
		if pj.live(c) and j == 0:
			_melody(pj, pj._mouth_pos(c), d)
		match j:
			0:   # Gürzlü: kaldır, indir
				dk.set_pose("raise", 0.25)
				pj.after(0.3, func():
					if is_instance_valid(dk):
						dk.set_pose("smash", 0.16))
				pj.after(0.46, func():
					if not is_instance_valid(dk) or not pj.live(c):
						return
					var g = pj.gp(dk.weapon.to_global(Vector3(0, 4.5, 0)) if dk.weapon else cur.global_position)
					_club_crater(pj, g)
					GroundFX.add(g, "cracked", 1.8, 5.0)   # yarık zemin: üstünden geçen yavaşlar (eski çatlak izinin oyun etkisi)
					pj.shake(0.4)
					pj.hit(c, g + Vector3.UP * 0.8, 2.4, pj.inf(c, "mateki_genbu_sokyoku", 0.7, {"knock": 8.0, "launch": 5.0, "kind": "heavy"})))
			1:   # Pençeli: kemik bıçaklarla tırmık
				dk.set_pose("swipe", 0.2)
				pj.after(0.22, func():
					if not is_instance_valid(dk) or not pj.live(c):
						return
					var hpos = dk.hand_pos(true)
					_claw_rake(pj, hpos, (cur.global_position - dk.global_position).normalized() if pj.live(cur) else d)
					pj.hit(c, hpos, 2.6, pj.inf(c, "mateki_genbu_sokyoku", 0.6, {"knock": 10.0, "kind": "heavy", "bleed": 3.0})))
			2:   # Sargılı: ağzını açıp ruh solucanları salar (ref "Doki Attack")
				dk.set_pose("roar", 0.25)
				for q in 3:
					pj.after(0.2 + q * 0.12, func():
						if not is_instance_valid(dk) or not pj.live(cur) or not pj.live(c):
							return
						Doki.spirit_worm(pj.get_tree().current_scene, dk.mouth_pos(), cur.global_position + Vector3.UP * 1.0, 0.6, func(p: Vector3):
							_soul_pop(pj, p)
							if pj.live(c):
								pj.hit(c, p, 1.6, pj.inf(c, "mateki_genbu_sokyoku", 0.35, {"knock": 3.0, "kind": "light", "chakra_drain": 6.0}))))
		pj.after(0.8, func():
			if is_instance_valid(dk):
				dk.set_pose("stand", 0.3)), Callable())
	pj.after(dur, func():
		for dk in dokis:
			if is_instance_valid(dk):
				_doki_sink(pj, dk))
	Sfx.play("genjutsu", c.global_position, 1.4)


# ================================================================== buff / gizlenme mekaniklerinin taşınması (eski genel motorun
# yalnız oyun kısmı; görünüşü her teknik kendi üretir)
static func _buff_port(c: Node3D, id: String, kind: String, col: Color) -> void:
	var d: Dictionary = Data.jutsu.get(id, {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	var mods = {"melee": 1.0 + 0.07 * (tier + 1)}
	var cat: String = d.get("category", "")
	var el: String = d.get("element", "")
	if kind == "mode" or cat == "senjutsu":
		mods = {"melee": 1.2 + 0.06 * tier, "armor": 0.85, "jutsu": 1.15 + 0.05 * tier}
	elif el == "raiton":
		mods = {"speed": 1.15 + 0.04 * tier, "melee": 1.1 + 0.05 * tier}
	elif el in ["doton", "shoton", "jiton"] or kind == "transform":
		mods = {"armor": maxf(0.5, 0.9 - 0.06 * tier), "melee": 1.05 + 0.04 * tier}
	elif el in ["fuuton"]:
		mods = {"speed": 1.2 + 0.04 * tier}
	elif kind == "utility":
		mods = {"speed": 1.1}
		dur = 8.0 + tier * 2.0
	Buffs.add(String(d.get("id", "buff")), dur, mods)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], col.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== TANUKI NEIRI — Gaara'nın uyur gibi yapması
## Kum tümseği: bedeni beline kadar saran tümsek, üstünde Shukaku'nun koyu mavi lanet çizgileri
static func _m_mound() -> Mesh:
	return _cached("mound", func():
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(2.2, 2.2, 2.2), Color.WHITE, Vector3.ZERO, 16)
		var line := Color(0.26, 0.3, 0.55)
		for i in 5:
			var a0 := TAU * i / 5.0
			for j in 9:
				var e := deg_to_rad(8.0 + j * 9.0)
				var a := a0 + sin(j * 0.9) * 0.18
				b.add("sphere", Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 1.1, Vector3.ONE * 0.09, line, Vector3.ZERO, 5)
		return b.build())


## Kum Shukaku başı: yuvarlak baş, iki sivri kulak, lanet çizgileri; gözler ayrı (kapanır)
static func _m_tanuki_head() -> Mesh:
	return _cached("tanuki", func():
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(1.3, 1.1, 1.1), Color.WHITE, Vector3.ZERO, 14)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.42, 0.6, 0.05), Vector3(0.36, 0.62, 0.26), Color.WHITE, Vector3(0, 0, -sx * 22.0), 6)
			b.add("cone", Vector3(sx * 0.42, 0.58, -0.06), Vector3(0.2, 0.42, 0.1), Color(0.26, 0.3, 0.55), Vector3(0, 0, -sx * 22.0), 5)
			for j in 4:
				b.add("sphere", Vector3(sx * (0.25 + j * 0.1), 0.25 - j * 0.12, -0.5 + j * 0.03), Vector3.ONE * 0.07, Color(0.26, 0.3, 0.55), Vector3.ZERO, 5)
		b.add("box", Vector3(0, -0.25, -0.53), Vector3(0.5, 0.05, 0.04), Color(0.26, 0.3, 0.55))
		return b.build())


## Uyur Gibi Yapma (Gaara / Shukaku): yerden kum yükselip bedeni beline kadar sarar, önünde kumdan Shukaku başı belirir ve
## gözlerini kapatır (uyku); sonra baş kum tanelerine dağılır, tümsek çöker, yerde kum birikintisi kalır.
static func tanuki_neiri_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var g := pj.gp(c.global_position)
	var f: Vector3 = c.face_dir()
	f.y = 0.0
	f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
	var sm := cel(SAND, 0.02, SAND_INK)
	var mound := mi(_m_mound(), sm)
	put(pj, mound, g)
	mound.scale = Vector3(0.1, 0.05, 0.1)
	var tw := mound.create_tween()
	tw.tween_property(mound, "scale", Vector3(1.0, 0.85, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(mound, "scale", Vector3(1.4, 0.04, 1.4), 0.6).set_ease(Tween.EASE_IN)
	fade_free(mound, sm, 2.6, 0.3)
	var hp := g + f * 1.0 + Vector3.UP * 2.5
	var head_m := cel(SAND, 0.025, SAND_INK)
	var head := Node3D.new()
	put(pj, head, hp)
	head.global_transform = Transform3D(Basis.looking_at(f, Vector3.UP), hp)
	head.add_child(mi(_m_tanuki_head(), head_m))
	var eye_m := cel(Color(0.92, 0.8, 0.32), 0.012, INK)
	for sx in [-1.0, 1.0]:
		var eb := MB.new()
		eb.add("sphere", Vector3.ZERO, Vector3(0.3, 0.3, 0.06), Color.WHITE, Vector3.ZERO, 10)
		eb.add_slab(_star(4, 0.1, 0.03), 0.02, Color(0.1, 0.08, 0.06), Transform3D(_up_b(), Vector3(0, 0, -0.035)))
		var eye := mi(eb.build(), eye_m)
		head.add_child(eye)
		eye.position = Vector3(sx * 0.28, 0.05, -0.53)
		var te := eye.create_tween()
		te.tween_interval(0.9)
		te.tween_property(eye, "scale", Vector3(1.0, 0.06, 1.0), 0.3).set_ease(Tween.EASE_IN)
	head.scale = Vector3.ONE * 0.05
	var th := head.create_tween()
	th.tween_property(head, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	th.tween_interval(1.65)
	th.tween_callback(func():
		if is_instance_valid(head):
			burst(pj, head.global_position, _m_blob(), cel(SAND, 0.008, SAND_INK), 40, 1.2, {"r": 0.8, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -9, 0), "smin": 0.25, "smax": 0.5}))
	th.tween_property(head, "scale", Vector3(1.1, 0.05, 1.1), 0.3).set_ease(Tween.EASE_IN)
	fade_free(head, head_m, 2.3, 0.1)
	# baştan aşağı kum akıntısı (uyurken dökülen kum)
	burst(pj, hp + Vector3.DOWN * 0.4, _m_blob(), cel(SAND, 0.006, SAND_INK), 30, 0.8, {"r": 0.4, "vmin": 0.0, "vmax": 0.3, "g": Vector3(0, -6, 0), "expl": 0.0, "smin": 0.2, "smax": 0.35})
	var pm := cel(SAND.darkened(0.08), 0.0)
	var patch := mi(slab_mesh(_blob(1.8, 20, 0.2), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)), pm)
	put(pj, patch, g + Vector3.UP * 0.035)
	fade_free(patch, pm, 4.0, 1.2)
	_buff_port(c, "tanuki_neiri_no_jutsu", "utility", SAND)


# ================================================================== BUNRETSU — bölünme
## Sargı-şeritli beden kabuğu (ref: beyaz bantlı gövde)
static func _m_band_body() -> Mesh:
	return _cached("bandbody", func():
		var b := MB.new()
		for i in 9:
			var r := 0.5 - absf(i - 4.0) * 0.025
			b.add("cyl", Vector3(0, 0.16 + i * 0.18, 0), Vector3(r, 0.18, r * 0.82), Color(0.94, 0.93, 0.9) if i % 2 == 0 else Color(0.82, 0.81, 0.8), Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, 1.86, 0), Vector3(0.38, 0.42, 0.38), Color(0.94, 0.93, 0.9), Vector3.ZERO, 12)
		b.add("cyl", Vector3(0, 1.92, 0), Vector3(0.41, 0.1, 0.41), Color(0.25, 0.25, 0.3), Vector3.ZERO, 12)
		return b.build())


## Bölünme: beden ortadan ikiye ayrılır — iki gerçek beden (biri klon) dağılır. Görünüş: bantlı iki beden kabuğu üst üste
## şişip yana ayrılır, aralarında gerilen zar incelip kopar (soluk damlacıklar), kabuklar söner.
static func bunretsu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var side = c.face_dir().cross(Vector3.UP)
	var at = pj.gp(c.global_position + side * 2.4)
	var m := cel(Color.WHITE, 0.014, Color(0.3, 0.3, 0.34))
	var a := mi(_m_band_body(), m)
	put(pj, a, c.global_position)
	var bb := mi(_m_band_body(), m)
	c.add_child(bb)
	for x in [a, bb]:
		x.scale = Vector3(1.15, 1.0, 1.15)
	a.create_tween().tween_property(a, "global_position", at, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var nm := cel(Color(0.9, 0.89, 0.86), 0.012, Color(0.3, 0.3, 0.34))
	var neck := mi(_m_unit_cyl(), nm)
	put(pj, neck, c.global_position)
	var stretch := func(_i, k):
		if not (is_instance_valid(a) and is_instance_valid(neck) and is_instance_valid(c)):
			return
		var p0: Vector3 = c.global_position + Vector3.UP * 1.0
		var p1: Vector3 = a.global_position + Vector3.UP * 1.0
		if p0.distance_to(p1) > 0.05:
			neck.global_transform = _seg_xf(p0, p1, lerpf(0.6, 0.05, k))
	var snap := func():
		if is_instance_valid(neck):
			burst(pj, neck.global_position, _m_blob(), cel(Color(0.92, 0.91, 0.88), 0.01, Color(0.3, 0.3, 0.34)), 12, 0.6, {"r": 0.2, "vmin": 1.5, "vmax": 4.0, "g": Vector3(0, -9, 0), "smin": 0.3, "smax": 0.6})
			neck.queue_free()
	pj.every(0.32, 1.0 / 60.0, stretch, snap)
	fade_free(a, m, 0.35, 0.3)
	pj.free_after(0.7, bb)
	var d = pj.decoy(c, at, 14.0)
	if d:
		d.set("max_hp", 5.0)
	if c is CharacterBody3D:
		c.velocity = -side * 8.0
	Sfx.play("poof", c.global_position, 0.9)


# ================================================================== GOFŪ KEKKAI — beş mühür bariyeri
## Mühür etiketi: krem kâğıt, kırmızı çerçeve, ortada «禁»; arkasında küçük kazık
static func _seal_tag(pj: PathJutsu, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var b := MB.new()
	b.add_slab(_rect(0.36, 0.56), 0.012, Color(0.95, 0.93, 0.84), Transform3D(_up_b(), Vector3.ZERO))
	var red := Color(0.75, 0.14, 0.16)
	for s in [-1.0, 1.0]:
		b.add("box", Vector3(s * 0.14, 0, 0.009), Vector3(0.018, 0.46, 0.006), red)
		b.add("box", Vector3(0, s * 0.23, 0.009), Vector3(0.3, 0.018, 0.006), red)
	b.add("cyl", Vector3(0, -0.3, -0.04), Vector3(0.07, 1.1, 0.07), Color(0.42, 0.3, 0.2), Vector3.ZERO, 6)
	n.add_child(mi(b.build(), cel(Color.WHITE, 0.01, INK)))
	var l := Label3D.new()
	l.text = "禁"
	l.font_size = 96
	l.pixel_size = 0.0028
	l.modulate = red
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.016)
	n.add_child(l)
	return n


## Beş Mühür Bariyeri: «禁» yazılı beş etiket elden fırlayıp beş noktaya çakılır, aralarında mor tül duvarlı beşgen bariyer
## örülür, yerde mor beşgen çizgisi ve yayılan mühür nabzı; süre bitince etiketler kopup savrulur. İçerideki kapanır.
static func gofu_kekkai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 6.0)
	var col = BARRIER
	var pts = []
	for k in 5:
		var a = TAU * k / 5.0
		pts.append(at + Vector3(cos(a), 0, sin(a)) * 3.0)
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_position = at
	var wm := _plain("wall", WALL_SHADER)
	wm.set_shader_parameter("tint", col)
	var lm := cel(Color(0.85, 0.65, 1.0), 0.0)
	for k in 5:
		var p0: Vector3 = pts[k] - at
		var p1: Vector3 = pts[(k + 1) % 5] - at
		var wall = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(p0.distance_to(p1), 3.2)
		wall.mesh = qm
		wall.material_override = wm
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.position = (p0 + p1) * 0.5 + Vector3.UP * 1.6
		wall.rotation.y = -atan2(p1.z - p0.z, p1.x - p0.x)
		root.add_child(wall)
		var line = mi(_m_unit_cyl(), lm)
		line.transform = _seg_xf(p0 + Vector3.UP * 0.05, p1 + Vector3.UP * 0.05, 0.08)
		root.add_child(line)
	root.scale = Vector3(1, 0.01, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(6.0)
	tw.tween_property(root, "scale", Vector3(1, 0.01, 1), 0.3)
	tw.tween_callback(root.queue_free)
	# etiketler elden beş noktaya uçup çakılır (kendi kökünde: bariyer ezilip açılırken etiketler ezilmesin)
	var troot := Node3D.new()
	put(pj, troot, at)
	var hand = pj.hand_pos(c, true)
	for k in 5:
		var tag := _seal_tag(pj, troot)
		var dest: Vector3 = pts[k] + Vector3.UP * 0.75
		tag.global_position = hand
		var p1 = (hand + dest) * 0.5 + Vector3.UP * 1.5
		var fly := func(u: float):
			if is_instance_valid(tag):
				tag.global_position = hand.lerp(p1, u).lerp(p1.lerp(dest, u), u)
		var ttw := tag.create_tween()
		ttw.tween_method(fly, 0.0, 1.0, 0.22 + k * 0.03)
		ttw.tween_callback(func():
			if is_instance_valid(tag):
				_aim(tag, Vector3(at.x, tag.global_position.y, at.z))   # -Z merkeze → yazılı yüz (+Z) dışa bakar
				var fm := cel(Color(1, 1, 1, 0.9), 0.0)
				var fl := mi(slab_mesh(_rect(0.6, 0.85), 0.01, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)), fm)
				tag.add_child(fl)
				fl.position = Vector3(0, 0, 0.03)
				fl.create_tween().tween_property(fl, "scale", Vector3.ONE * 1.8, 0.15)
				fade_free(fl, fm, 0.0, 0.18))
		ttw.tween_property(tag, "scale", Vector3(1.25, 1.25, 1.25), 0.06)
		ttw.tween_property(tag, "scale", Vector3.ONE, 0.08)
	var trw := troot.create_tween()
	trw.tween_interval(6.4)
	trw.tween_callback(func():
		for k in 5:
			burst(pj, pts[k] + Vector3.UP * 0.75, _m_sheet(), cel(Color(0.95, 0.93, 0.84), 0.006, Color(0.6, 0.12, 0.14)), 6, 1.2, {"r": 0.2, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -2, 0), "damp": 1.0, "spin": 300.0}))
	trw.tween_property(troot, "scale", Vector3(1, 0.01, 1), 0.2)
	trw.tween_callback(troot.queue_free)
	# yerde yayılan mühür nabzı
	var pm := cel(Color(0.78, 0.55, 1.0, 0.9), 0.0)
	var pulse := mi(_ring_mesh(0.9, 0.97, 1.0, 40, Color.WHITE, 0.02, _flat_b()), pm)
	put(pj, pulse, at + Vector3.UP * 0.08)
	pulse.scale = Vector3.ONE * 0.5
	pulse.create_tween().tween_property(pulse, "scale", Vector3.ONE * 3.5, 0.5).set_ease(Tween.EASE_OUT)
	fade_free(pulse, pm, 0.2, 0.3)
	for e in pj.enemies_near(c, at, 3.0):
		pj.st(e, "bind", 6.0)
		Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Mühür bariyeri!", col)
	Sfx.play("seal", at, 0.8)


# ================================================================== KEBARI SENBON — Jiraiya'nın saç iğneleri
## Saç iğnesi: saç renginde ince gövde + açık parlak sırt çizgisi + sivri uç (−Z ileri)
static func _m_needle(hair: Color) -> Mesh:
	var b := MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.022, 0.42, 0.022), hair.darkened(0.1), Vector3(90, 0, 0), 5)
	b.add("cyl", Vector3(0, 0.008, -0.02), Vector3(0.008, 0.3, 0.008), hair.lightened(0.6), Vector3(90, 0, 0), 4)
	b.add("cone", Vector3(0, 0, -0.25), Vector3(0.022, 0.08, 0.022), hair.darkened(0.1), Vector3(-90, 0, 0), 5)
	return b.build()


## Yere saplanıp kalan iğne (ardıl iz)
static func _stuck_needle(pj: PathJutsu, pos: Vector3, dir: Vector3, mesh: Mesh, m: Material) -> void:
	var x := mi(mesh, m)
	put(pj, x, pos - dir.normalized() * 0.12)
	_aim(x, pos + dir)
	var tw := x.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(x, "scale", Vector3(0.05, 0.05, 1), 0.4)
	tw.tween_callback(x.queue_free)


## Saç İğneleri (Jiraiya): saç başın çevresinde uzun sivri tutamlarla dikilir, saç kılları dışa sıçrar, sonra yüzlerce iğne
## (parlak sırtlı) yağar; yere düşenler saplanıp kalır.
static func kebari_senbon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var hair: Color = c.model.look.get("hair", Color(0.9, 0.9, 0.88)) if c.get("model") else Color(0.9, 0.9, 0.88)
	var ba = pj.bone_attach(c, "Head")
	if ba:
		var b = MB.new()
		for k in 26:
			var a = deg_to_rad(-110.0 + k * 8.8)
			var e = deg_to_rad(randf_range(-15, 45))
			var dv = Vector3(sin(a) * cos(e), sin(e) + 0.2, -cos(a) * cos(e)).normalized()
			var L = randf_range(0.8, 1.25)
			b.add("cone", dv * (0.1 + L * 0.5), Vector3(0.09, L, 0.09), hair if k % 2 == 0 else hair.darkened(0.15), Vector3(rad_to_deg(acos(clampf(dv.y, -1, 1))), rad_to_deg(atan2(dv.x, dv.z)), 0), 5)
		var spikes = mi(b.build(), cel(Color.WHITE, 0.012, hair.darkened(0.7)))
		ba.add_child(spikes)
		spikes.scale = Vector3.ONE * 0.1
		var tw = spikes.create_tween()
		tw.tween_property(spikes, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.8)
		tw.tween_property(spikes, "scale", Vector3.ONE * 0.05, 0.2)
		tw.tween_callback(ba.queue_free)
	var d = pj.fwd(c, t)
	var head = c.global_position + Vector3.UP * 1.7
	burst(pj, head, _m_shard(), cel(hair, 0.006, hair.darkened(0.7)), 18, 0.3, {"r": 0.2, "dir": d, "spread": 75.0, "vmin": 4.0, "vmax": 8.0, "g": Vector3.ZERO, "align": true, "smin": 0.4, "smax": 0.8, "hold": 0.3})
	Sfx.play("whoosh", head, 1.7)
	var nm := _m_needle(hair)
	var n_mat := cel(Color.WHITE, 0.006, hair.darkened(0.7))
	var tb := MB.new()
	tb.add("box", Vector3.ZERO, Vector3(0.012, 0.012, 0.9), Color.WHITE)
	var tail_mesh := tb.build()
	var tail_m := cel(Color(hair.lightened(0.5).r, hair.lightened(0.5).g, hair.lightened(0.5).b, 0.4), 0.0)
	for k in 50:
		pj.after(0.2 + k * 0.012, func():
			var needle := mi(nm, n_mat)
			if k % 5 == 0:
				var tl := mi(tail_mesh, tail_m)
				tl.position = Vector3(0, 0, 0.65)
				needle.add_child(tl)
			var dir = (d + Vector3(randf_range(-0.3, 0.3), randf_range(-0.12, 0.12), randf_range(-0.3, 0.3))).normalized()
			var stick_it = k % 2 == 0
			var on_hit := func(pos: Vector3, target: Node3D):
				if stick_it and target == null and absf(pos.y - pj.gp(pos).y) < 0.5:
					_stuck_needle(pj, pos, dir, nm, n_mat)
			pj.shot(c, head + Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.3), randf_range(-0.3, 0.3)), dir, 55.0, needle, pj.inf(c, "kebari_senbon", 0.06, {"knock": 0.5, "kind": "light", "bleed": 1.0}), null, false, 0.6, on_hit))


# ================================================================== HĀREMU — harem tekniği
## Harem: çevrede altı noktada pembe-beyaz kurdeleler kıvrılarak yükselir, tepelerinde kalpler ve parıltılar patlar;
## yerde kalpli halka kalır. Mekanik: dönüşüm güçlendirmesi (genel motorun oyun kısmı aynen).
static func haremu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var base: Vector3 = c.global_position
	var rm := cel(Color(1.0, 0.82, 0.9, 0.9), 0.0, INK, true)
	var hm := cel(Color(1.0, 0.45, 0.65), 0.02, Color(0.5, 0.08, 0.22))
	var sm := cel(Color(1.0, 0.95, 0.75), 0.012, Color(0.6, 0.4, 0.1))
	var holder := Node3D.new()
	put(pj, holder, base)
	for k in 6:
		var a = k * TAU / 6.0
		var p: Vector3 = pj.gp(base + Vector3(cos(a), 0, sin(a)) * 2.0)
		var pts := []
		for j in 18:
			var u := j / 17.0
			var aa: float = a + u * 6.0
			pts.append(Vector3(cos(aa) * 0.45 * (1.0 - u * 0.5), u * 2.2, sin(aa) * 0.45 * (1.0 - u * 0.5)))
		var x := mi(_ribbon(pts, 0.22, Vector3(cos(a), 0, sin(a))), rm)
		put(pj, x, p, holder)
		x.scale = Vector3(1, 0.05, 1)
		var tw := x.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(x, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(x, "rotation:y", 2.5, 0.7)
		tw.tween_callback(func():
			burst(pj, p + Vector3.UP * 2.2, _m_heart(), hm, 4, 1.4, {"r": 0.3, "vmin": 0.6, "vmax": 1.6, "g": Vector3(0, 1.2, 0), "damp": 1.0, "spin": 90.0, "smin": 0.7, "smax": 1.2})
			burst(pj, p + Vector3.UP * 2.2, _m_spark(), sm, 5, 0.6, {"r": 0.5, "vmin": 1.0, "vmax": 2.5, "g": Vector3.ZERO, "damp": 2.0, "spin": 200.0, "smin": 0.6, "smax": 1.2}))
	fade_free(holder, rm, 0.75, 0.35)
	var gb := MB.new()
	for k in 12:
		var a = TAU * k / 12.0
		gb.add_slab(_heart(0.32), 0.015, Color.WHITE, Transform3D(Basis(Vector3.UP, -a) * _flat_b(), Vector3(cos(a), 0, sin(a)) * 2.0))
	var gm := cel(Color(1.0, 0.55, 0.72, 0.85), 0.0)
	var ring := mi(gb.build(), gm)
	put(pj, ring, pj.gp(base) + Vector3.UP * 0.04)
	fade_free(ring, gm, 1.6, 0.8)
	for e in pj.enemies_near(c, base, 10.0):
		Combat.popup_text(e.global_position + Vector3.UP * 2.4, "‼", Color(1.0, 0.5, 0.7))
	_buff_port(c, "haremu_no_jutsu", "transform", Color(1.0, 0.6, 0.75))


# ================================================================== TENSŌ — göksel aktarım
## Mühürlü kil kavanoz: turuncu gövde, beyaz örgülü ip boyun bağı ve sarkan uçlar, önde baklava mühür
static func _m_jar() -> Mesh:
	return _cached("jar", func():
		var b := MB.new()
		var clay := Color(0.88, 0.5, 0.18)
		b.add("sphere", Vector3(0, 0.8, 0), Vector3(1.35, 1.45, 1.35), clay, Vector3.ZERO, 16)
		b.add("cyl", Vector3(0, 1.55, 0), Vector3(0.78, 0.3, 0.78), clay, Vector3.ZERO, 16)
		b.add("cyl", Vector3(0, 1.73, 0), Vector3(0.82, 0.1, 0.82), Color(0.5, 0.38, 0.26), Vector3.ZERO, 16)
		for i in 18:
			var a := TAU * i / 18.0
			b.add("sphere", Vector3(cos(a) * 0.42, 1.45 + (i % 2) * 0.03, sin(a) * 0.42), Vector3(0.14, 0.12, 0.14), Color(0.97, 0.96, 0.94), Vector3.ZERO, 6)
		for j in 5:
			b.add("sphere", Vector3(0.5 + j * 0.02, 1.32 - j * 0.15, 0.05), Vector3(0.13, 0.16, 0.13), Color(0.97, 0.96, 0.94), Vector3.ZERO, 6)
		var ds := PackedVector2Array([Vector2(0, 0.32), Vector2(0.24, 0), Vector2(0, -0.32), Vector2(-0.24, 0)])
		for sz in [1.0, -1.0]:
			var xf := Transform3D(_up_b().rotated(Vector3.UP, 0.0 if sz > 0 else PI), Vector3(0, 0.85, 0.7 * sz))
			b.add_slab(ds, 0.02, Color(0.62, 0.36, 0.14), xf)
			# yerel x = yüz normali: çizgiler yüzün önünde (gömülmesin)
			b.add("box", xf * Vector3(0.016, 0, -0.04), Vector3(0.24, 0.025, 0.01), Color(0.5, 0.28, 0.1), Vector3(0, 0.0 if sz > 0 else 180.0, 0))
			b.add("box", xf * Vector3(0.016, 0, 0.03), Vector3(0.025, 0.36, 0.01), Color(0.5, 0.28, 0.1), Vector3(0, 0.0 if sz > 0 else 180.0, 0))
		return b.build())


## Kırık beyaz şimşek (kendi tüp çizgisi): mavi kontur, titreyip söner
static func _tbolt(pj: PathJutsu, a: Vector3, b: Vector3, m: Material) -> void:
	var pts := [a]
	for i in range(1, 6):
		pts.append(a.lerp(b, i / 6.0) + Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)))
	pts.append(b)
	var mb := MB.new()
	_line(mb, pts, 0.05, Color.WHITE, a)
	var x := mi(mb.build(), m)
	put(pj, x, a)
	var tw := x.create_tween()
	for k in 3:
		tw.tween_callback(func(): x.visible = not x.visible)
		tw.tween_interval(0.05)
	tw.tween_interval(0.1)
	tw.tween_callback(x.queue_free)


## Kavanoz belirip kapanır (kaynak: şimşekler içinde saydam kavanoz), yerde baklava mühür izi
static func _tenso_jar(pj: PathJutsu, pos: Vector3, appear: bool) -> void:
	var jm := cel(Color(1, 1, 1, 0.78), 0.03, Color(0.3, 0.14, 0.05))
	var jar := mi(_m_jar(), jm)
	put(pj, jar, pos)
	jar.scale = Vector3(1, 0.05, 1) if appear else Vector3.ONE
	var tw := jar.create_tween()
	if appear:
		tw.tween_property(jar, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12)
		tw.tween_property(jar, "scale", Vector3(0.05, 1.2, 0.05), 0.12).set_ease(Tween.EASE_IN)
	else:
		tw.tween_interval(0.25)
		tw.tween_property(jar, "scale", Vector3(1.2, 0.05, 1.2), 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(jar.queue_free)
	var bm := cel(Color(0.96, 0.98, 1.0), 0.02, Color(0.3, 0.55, 1.0))
	for k in 6:
		_tbolt(pj, pos + Vector3.UP * randf_range(0.5, 2.0), pos + Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), bm)
	var gm := cel(Color(0.5, 0.75, 1.0, 0.85), 0.0)
	var gb := MB.new()
	var ds := PackedVector2Array([Vector2(0, 1.2), Vector2(0.85, 0), Vector2(0, -1.2), Vector2(-0.85, 0)])
	var dsi := PackedVector2Array([Vector2(0, 1.0), Vector2(0.68, 0), Vector2(0, -1.0), Vector2(-0.68, 0)])
	for i in 4:
		var p0: Vector2 = ds[i]
		var p1: Vector2 = ds[(i + 1) % 4]
		var q0: Vector2 = dsi[i]
		var q1: Vector2 = dsi[(i + 1) % 4]
		gb.add_slab(PackedVector2Array([p0, p1, q1, q0]), 0.015, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	gb.add_slab(_rect(0.08, 1.6), 0.015, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	gb.add_slab(_rect(1.0, 0.08), 0.015, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	var mark := mi(gb.build(), gm)
	put(pj, mark, pj.gp(pos) + Vector3.UP * 0.04)
	fade_free(mark, gm, 1.2, 0.8)


## Göksel Aktarım: kullanıcı beyaz şimşekler içinde saydam mühürlü kavanoza kapanır, kavanoz incelip kaybolur; hedefin
## yanında yeniden belirip yayvanlaşarak açılır. İki yerde de yerde baklava mühür izi. Bedeli: can.
static func tenso_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 40.0)
	var start = c.global_position
	var end = pj.gp(tt.global_position - (tt.global_position - start).normalized() * 2.0) if tt else pj.gp(start + pj.fwd(c, t) * 20.0)
	_tenso_jar(pj, start, true)
	c.global_position = end
	_tenso_jar(pj, end, false)
	if c is Player:
		c.hp = maxf(1.0, c.hp - c.max_hp * 0.05)
	Sfx.play("thunder", end, 1.6)


# ================================================================== MEISAIGAKURE — tam kamuflaj
## Kırılma kabuğu: bedenin çevresinde arka planı büken kabuk, sönerek beden çevreye karışır
static func _shimmer(pj: PathJutsu, c: Node3D, dur: float, rise: bool) -> void:
	if not is_instance_valid(c):
		return
	var cm := CapsuleMesh.new()
	cm.radius = 0.45
	cm.height = 1.95
	var m := _plain("refract", REFRACT_SHADER)
	var x := mi(cm, m)
	c.add_child(x)
	x.position = Vector3.UP * 0.97
	set_fade(m, 0.0 if rise else 1.0)
	var tw := x.create_tween()
	if rise:
		tw.tween_method(func(v: float): set_fade(m, v), 0.0, 1.0, dur * 0.4)
		tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, dur * 0.6)
	else:
		tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, dur)
	tw.tween_callback(x.queue_free)
	# ışığı büken ince dikey dalgalar (yükselir)
	var sm := streak_mat(Color(0.92, 0.97, 1.0, 0.7), Color(0.5, 0.6, 0.7), 6.0, 2.0, 1.0)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var pts := []
		for j in 8:
			pts.append(Vector3(cos(a) * 0.55, j * 0.3, sin(a) * 0.55) + Vector3(sin(j * 1.3 + k) * 0.06, 0, 0))
		var r := mi(_ribbon(pts, 0.18, Vector3(cos(a), 0, sin(a))), sm)
		c.add_child(r)
		var tr := r.create_tween()
		tr.tween_property(r, "position", Vector3.UP * 0.6, dur)
		tr.tween_callback(r.queue_free)
	var hold := Node3D.new()
	c.add_child(hold)
	fade_free(hold, sm, dur * 0.5, dur * 0.5)


## Tam Gizlenme: beden ışığı kırıp arka plana karışır (kırılma kabuğu + dikey ışık dalgaları); süre dolunca aynı dalgayla geri
## belirir. Mekanik: gizlenme güçlendirmesi + yakındaki düşmanlar hedefi kaybeder (genel motorun oyun kısmı aynen).
static func meisaigakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("meisaigakure_no_jutsu", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	_shimmer(pj, c, 0.8, false)
	if c.get("model"):
		c.model.visible = false
		pj.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true
				_shimmer(pj, c, 0.7, true))
	Sfx.play("poof", c.global_position)


# ================================================================== SUMI BUNSHIN — Sai'nin mürekkep klonu
## Mürekkep sütunu: yerde yayılan kara gölcük, içinden parlak kara mürekkep yükselip klonu sarar, sonra eriyip akar
static func _ink_rise(pj: PathJutsu, at: Vector3) -> void:
	var g := pj.gp(at)
	var pm := cel(BLACK_INK, 0.0, INK, false, 0.3)
	var pool := mi(slab_mesh(_blob(1.1, 18, 0.3), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)), pm)
	put(pj, pool, g + Vector3.UP * 0.035)
	pool.scale = Vector3.ONE * 0.1
	pool.create_tween().tween_property(pool, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	fade_free(pool, pm, 1.6, 0.6)
	var b := MB.new()
	for i in 10:
		var y := 0.15 + i * 0.2
		var r := 0.55 - absf(i - 4.5) * 0.03
		b.add("sphere", Vector3(randf_range(-0.06, 0.06), y, randf_range(-0.06, 0.06)), Vector3(r, 0.3, r), Color.WHITE, Vector3.ZERO, 10)
	var cm := cel(BLACK_INK, 0.012, Color(0.3, 0.3, 0.36), false, 0.45)
	var col := mi(b.build(), cm)
	put(pj, col, g)
	col.scale = Vector3(0.6, 0.02, 0.6)
	var tw := col.create_tween()
	tw.tween_property(col, "scale", Vector3(1.0, 1.0, 1.0), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(col, "scale", Vector3(1.5, 0.02, 1.5), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(col.queue_free)
	burst(pj, g + Vector3.UP * 1.6, _m_blob(), cel(BLACK_INK, 0.0, INK, false, 0.4), 14, 0.7, {"r": 0.4, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -10, 0), "smin": 0.3, "smax": 0.6})


## Fırça savuruşu: elden klonun yerine kavis çizen mürekkep damlaları
static func _ink_flick(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var m := cel(BLACK_INK, 0.0, INK, false, 0.4)
	for i in 9:
		var x := mi(_m_blob(), m)
		put(pj, x, from)
		x.scale = Vector3.ONE * randf_range(0.35, 0.7)
		var p1 := (from + to) * 0.5 + Vector3.UP * randf_range(0.6, 1.3)
		var dest := to + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.4), randf_range(-0.4, 0.4))
		var mv := func(u: float):
			if is_instance_valid(x):
				x.global_position = from.lerp(p1, u).lerp(p1.lerp(dest, u), u)
		var tw := x.create_tween()
		tw.tween_interval(i * 0.02)
		tw.tween_method(mv, 0.0, 1.0, 0.22)
		tw.tween_callback(x.queue_free)


## Mürekkep patlaması: ışınsal kara sıçrama + taç gibi kalkan mürekkep dikenleri + yerde dişli mürekkep lekesi (yavaşlatma süresi kadar)
static func _ink_splash(pj: PathJutsu, p: Vector3) -> void:
	var g := pj.gp(p)
	burst(pj, g + Vector3.UP * 1.0, _m_blob(), cel(BLACK_INK, 0.0, INK, false, 0.45), 30, 0.9, {"r": 0.5, "vmin": 3.0, "vmax": 8.0, "g": Vector3(0, -12, 0), "smin": 0.6, "smax": 1.4})
	var sb := MB.new()
	sb.add_slab(_blob(2.0, 22, 0.35), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(2.3, 3.6)
		sb.add_slab(_blob(randf_range(0.12, 0.3), 9, 0.2), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3(cos(a) * r, 0, sin(a) * r)))
	var sm := cel(BLACK_INK, 0.0, INK, false, 0.25)
	var splat := mi(sb.build(), sm)
	put(pj, splat, g + Vector3.UP * 0.035)
	splat.scale = Vector3.ONE * 0.2
	splat.create_tween().tween_property(splat, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	fade_free(splat, sm, 2.6, 0.6)
	var cb := MB.new()
	for i in 12:
		var a := TAU * i / 12.0
		cb.add("cone", Vector3(cos(a) * 1.0, 0.45, sin(a) * 1.0), Vector3(0.22, 0.9 + randf() * 0.5, 0.22), Color.WHITE, Vector3(sin(a) * 25.0, 0, -cos(a) * 25.0), 6)
	var crm := cel(BLACK_INK, 0.01, Color(0.3, 0.3, 0.36), false, 0.45)
	var crown := mi(cb.build(), crm)
	put(pj, crown, g)
	crown.scale = Vector3(0.5, 0.05, 0.5)
	var tw := crown.create_tween()
	tw.tween_property(crown, "scale", Vector3(1.0, 1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(crown, "scale", Vector3(1.4, 0.02, 1.4), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(crown.queue_free)


## Mürekkep Klonu (Sai): elden savrulan mürekkep yere gölcük olur, içinden kara mürekkep sütunu yükselip kopyaya dönüşür;
## kopya vurulunca mürekkep patlar — çevredekiler kör olur ve yavaşlar (yerde mürekkep lekesi).
static func sumi_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var at: Vector3 = c.global_position + c.global_transform.basis.x * 2.5
	_ink_flick(pj, pj.hand_pos(c, true), at)
	_ink_rise(pj, at)
	pj.decoy(c, at, 12.0, func(p: Vector3):
		var pj2 := PathJutsu.get_pinst()   # klon geç vurulunca yakalanan pj boş olabilir
		if pj2 == null or not is_instance_valid(c):
			return
		_ink_splash(pj2, p)
		for e in pj2.enemies_near(c, p, 5.0):
			pj2.st(e, "slow", 3.0)
			if e.has_method("lose_target"):
				e.lose_target(2.5))
