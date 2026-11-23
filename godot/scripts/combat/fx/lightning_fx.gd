class_name LightningFX
extends RefCounted
## Raiton (şimşek) görselleri ve 12 tekniğin tam akışı. Hazır / ortak efekt yardımcısı kullanmaz: kendi gölgelendiricileri
## (şimşek şeridi: beyaza yakın öz + camgöbeği / elektrik mavisi parıltı, çakma yıldızı, elektrikli yüzey, fırtına bulutu,
## yanık iz) ve kendi geometrisi (orta nokta kırılımlı, dallanan, birkaç karede bir yeniden kırılan şimşek; kıvılcım;
## ejder başı). Her teknikte hazırlık çatırtısı → salım → sonrası (yerde kalan ark, yanık + iyonlaşmış ışıltı; duman yok).
## Oynanış PathJutsu / Jutsu'daki eski gövdelerden satır satır taşındı.

const CYAN := Color(0.35, 0.7, 1.0)
const RAI := Color(0.65, 0.85, 1.0)
const WHITEBLUE := Color(0.8, 0.92, 1.0)
const RAIKAGE := Color(0.45, 0.7, 1.0)

static var _shaders := {}
static var _cache := {}


# ═════════════════════════════════════════ gölgelendiriciler ═════════════════════════════════════════

const SH_NOISE := """
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
"""

## Şimşek şeridi: ortada beyaza yakın ince öz, dışa doğru camgöbeği parıltı (toplamalı). Saydamlık köşe renginden.
const SH_BOLT := """
uniform vec4 glow : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	float c = 1.0 - smoothstep(0.1, 0.28, e);
	float g = pow(1.0 - e, 2.2);
	ALBEDO = glow.rgb * g * 1.7 + core.rgb * c * 2.2;
	ALPHA = clamp(max(c, g), 0.0, 1.0) * COLOR.a;
}
"""

## Çakma: kameraya dönük ışınsal yıldız + yuvarlak hâle + beyaz öz
const SH_FLASH := """
uniform vec4 glow : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform float power = 1.0;
uniform float rays = 6.0;
uniform float seed = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float a = atan(p.y, p.x);
	float ray = pow(max(0.0, cos(a * rays + seed)), 30.0) + pow(max(0.0, cos(a * rays * 0.5 + seed * 1.7 + 1.0)), 50.0) * 0.8;
	ray *= (1.0 - r);
	float corev = 1.0 - smoothstep(0.0, 0.22, r);
	float halo = pow(1.0 - r, 3.0);
	ALBEDO = vec3(1.0) * corev * 2.0 + glow.rgb * (halo * 1.4 + ray * 2.0);
	ALPHA = clamp(corev + halo + ray, 0.0, 1.0) * power;
}
"""

## Elektrikli yüzey (ejder başı, şimşek küresi): kenarı camgöbeği, içinden çakan beyaz damarlar (toplamalı)
const SH_ELEC := """
uniform vec4 glow : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform float power = 1.0;
uniform float solid = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float t = floor(TIME * 18.0);
	float n = n3(lp * 5.0 + vec3(t * 0.37, t * 0.71, -t * 0.53));
	float vein = 1.0 - smoothstep(0.0, 0.05, abs(n - 0.5));
	vec3 col = glow.rgb * (0.45 + fr * 1.6) + vec3(1.0) * vein * 1.6 + vec3(1.0) * step(0.7, 1.0 - fr) * 0.35;
	// solid=1 (karışık, toplamalı değil): koyu elektrik mavisi gövde, camgöbeği kenar bandı, beyaz damarlar, ince koyu kontur —
	// parlak gökte de seçilir (ejder)
	vec3 sol = mix(glow.rgb * vec3(0.25, 0.45, 0.85), glow.rgb * 1.3 + vec3(0.25), step(0.55, fr));
	sol = mix(sol, vec3(1.0), max(vein, step(0.8, 1.0 - fr) * 0.0));
	sol = mix(sol, vec3(0.02, 0.05, 0.15), step(0.9, fr));
	ALBEDO = mix(col, sol, solid);
	ALPHA = mix(clamp(0.5 + 0.5 * fr + vein * 0.5, 0.0, 1.0), 0.95, solid) * power;
}
"""

## Fırtına bulutu: kabaran cel bulut topağı; üstü açık, altı koyu, koyu kontur; flash>0 içinden çakan mavi ışık
const SH_CLOUD := """
uniform vec4 base : source_color = vec4(0.11, 0.11, 0.17, 1.0);
uniform vec4 lit : source_color = vec4(0.27, 0.28, 0.4, 1.0);
uniform vec4 flash_col : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float flash = 0.0;
uniform float grow = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * (n3(VERTEX * 2.2 + vec3(TIME * 0.25, 0.0, TIME * 0.18)) - 0.5) * 0.28;
	VERTEX *= grow;
}
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float up = dot(NORMAL, normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz));
	vec3 col = mix(base.rgb, lit.rgb, step(0.25, up));
	col = mix(col, base.rgb * 0.6, smoothstep(0.65, 1.0, fr));   // yumuşak kenar gölgesi (keskin eşik siyah leke yapıyordu)
	// iç çakma: yumuşak, bulutun içinden sızan soluk ışık (eskiden keskin desenle tüm bulutu açık maviye boyuyordu)
	float fl = flash * smoothstep(0.35, 0.75, n3(lp * 1.5 + vec3(TIME * 1.5))) * (1.0 - fr * 0.6);
	col += flash_col.rgb * fl * 0.45;
	ALBEDO = col;
}
"""

## Yanık iz: düzensiz kömür lekesi + ışınsal kırık çizgiler; heat ile çizgiler camgöbeği / beyaz kor gibi parlar, soğuyunca söner
const SH_SCORCH := """
uniform vec4 glow : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform float heat = 1.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dv = p / max(r, 0.0001);
	float a = atan(p.y, p.x);
	float edge = 0.72 + 0.28 * n2(dv * 3.0 + vec2(seed, seed * 1.7));
	if (r > edge) { discard; }
	float burnt = (1.0 - smoothstep(edge * 0.2, edge, r)) * (0.7 + 0.3 * n2(p * 6.0 + vec2(seed)));
	float t = (a + 3.14159265) / 6.2831853 * 11.0;
	float wig = n2(vec2(r * 5.0, floor(t) + seed)) * 0.5;
	float line = (1.0 - smoothstep(0.0, 0.05 + 0.05 * (1.0 - r), abs(fract(t + wig) - 0.5))) * step(0.1, r) * (1.0 - smoothstep(edge * 0.55, edge, r));
	vec3 charc = vec3(0.04, 0.035, 0.05);
	// kor çizgiler hep parlak renkte kalır, soğudukça yalnız saydamlaşır (koyu örümcek ağı kalmaz); kömür yumuşak benekli leke
	float hot = line * heat;
	vec3 col = mix(charc, glow.rgb * 2.2 + vec3(0.5), step(0.02, hot));
	col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.16, r)) * heat * 0.8);
	ALBEDO = col;
	ALPHA = clamp(mix(burnt * 0.5, 1.0, step(0.02, hot) * hot), 0.0, 1.0) * fade;
}
"""

const RENDER := {
	"bolt": "render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;",
	"flash": "render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;",
	"elec": "render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled;",
	"elec2": "render_mode unshaded, cull_disabled, blend_mix, shadows_disabled;",
	"cloud": "render_mode unshaded, cull_back, shadows_disabled;",
	"scorch": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
}


static func _shader(key: String) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var body := ""
	match key:
		"bolt":
			body = SH_BOLT
		"flash":
			body = SH_FLASH
		"elec", "elec2":
			body = SH_ELEC
		"cloud":
			body = SH_CLOUD
		"scorch":
			body = SH_SCORCH
	var s = Shader.new()
	s.code = "shader_type spatial;\n" + String(RENDER[key]) + "\n" + SH_NOISE + "\n" + body
	_shaders[key] = s
	return s


static func _mat(key: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(key)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Renge göre ortak şimşek şeridi malzemesi
static func _bmat(col: Color) -> ShaderMaterial:
	var key = "b_" + col.to_html()
	if not _cache.has(key):
		_cache[key] = _mat("bolt", {"glow": col})
	return _cache[key]


## Seçilir (karışık) elektrik gövde malzemesi: ejder başı ve gövde boğumları
static func _smat(col: Color) -> ShaderMaterial:
	var key = "s_" + col.to_html()
	if not _cache.has(key):
		_cache[key] = _mat("elec2", {"glow": col, "solid": 1.0})
	return _cache[key]


static func _emat(col: Color) -> ShaderMaterial:
	var key = "e_" + col.to_html()
	if not _cache.has(key):
		_cache[key] = _mat("elec", {"glow": col})
	return _cache[key]


# ═════════════════════════════════════════ altyapı ═════════════════════════════════════════

## Her karede fn(node, dt, age) çağıran düğüm; fn false dönünce silinir
class Ticker extends Node3D:
	var fn := Callable()
	var age := 0.0

	func _process(dt: float) -> void:
		age += dt
		if not fn.is_valid() or not fn.call(self, dt, age):
			queue_free()


static func _scene(n: Node) -> Node:
	return n.get_tree().current_scene


static func _tick(n: Node, pos: Vector3, fn: Callable, parent: Node = null) -> Ticker:
	var t = Ticker.new()
	t.fn = fn
	if parent != null and is_instance_valid(parent):
		parent.add_child(t)
		t.position = pos
	else:
		_scene(n).add_child(t)
		t.global_position = pos
	return t


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _sphere() -> SphereMesh:
	if not _cache.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 20
		s.rings = 10
		_cache["sphere"] = s
	return _cache["sphere"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _cam(n: Node3D) -> Vector3:
	var vp = n.get_viewport()
	var cam = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else n.global_position + Vector3(0, 50, 0)


static func _rand_dir() -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()


static func _floor(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


## Uç noktası sabit (Vector3) ya da hareketli (Callable) olabilir
static func _pt(x) -> Vector3:
	return x.call() if x is Callable else x


## Atanın eli (görünen poz); atan yok olursa son konum
static func _hand_fn(pj: PathJutsu, c: Node3D, right := true) -> Callable:
	var cw = weakref(c)
	var mem = {"p": pj.hand_pos(c, right)}
	return func() -> Vector3:
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and cc.is_inside_tree():
			mem["p"] = pj.live_hand(cc, right)
		return mem["p"]


static func _follow_fn(n: Node3D, off: Vector3) -> Callable:
	var w = weakref(n)
	var mem = {"p": n.global_position + off}
	return func() -> Vector3:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			mem["p"] = x.global_position + off
		return mem["p"]


# ───────────────────────── şerit çizimi ─────────────────────────

static func _vx(im: ImmediateMesh, p: Vector3, u: float, v: float, a: float) -> void:
	im.surface_set_color(Color(1, 1, 1, a))
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(p)


## Çoklu çizgiyi tek yüzeyde kameraya dönük üçgenlerle çizer. polys: [{"p": [Vector3], "w": yarı genişlik, "a": saydamlık,
## "t": 1 = uçlara doğru incel}]
static func _draw_polys(im: ImmediateMesh, mat: Material, polys: Array, cam: Vector3) -> void:
	var any = false
	for pl in polys:
		if (pl["p"] as Array).size() >= 2:
			any = true
			break
	if not any:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for pl in polys:
		var pts: Array = pl["p"]
		var m = pts.size()
		if m < 2:
			continue
		var al = float(pl["a"])
		var w0 = float(pl["w"])
		var tap = float(pl.get("t", 1.0))
		var L = []
		var R = []
		for i in m:
			var p: Vector3 = pts[i]
			var tn: Vector3 = Vector3(pts[mini(i + 1, m - 1)]) - Vector3(pts[maxi(i - 1, 0)])
			var sd: Vector3 = tn.cross(cam - p)
			if sd.length_squared() < 0.000000001:
				sd = Vector3.RIGHT
			var f = float(i) / float(m - 1)
			var w = w0 * lerpf(1.0, 0.3 + 0.7 * sin(PI * (0.06 + 0.88 * f)), tap)
			sd = sd.normalized() * w
			L.append(p + sd)
			R.append(p - sd)
		for i in m - 1:
			var u0 = float(i) / float(m - 1)
			var u1 = float(i + 1) / float(m - 1)
			_vx(im, L[i], u0, 0.0, al)
			_vx(im, R[i], u0, 1.0, al)
			_vx(im, L[i + 1], u1, 0.0, al)
			_vx(im, L[i + 1], u1, 0.0, al)
			_vx(im, R[i], u0, 1.0, al)
			_vx(im, R[i + 1], u1, 1.0, al)
	im.surface_end()


## Dünya koordinatında her kare yeniden çizilen taşıyıcı: fn(im, node, dt, age) -> bool
static func _host(n: Node, fn: Callable) -> Ticker:
	var im = ImmediateMesh.new()
	var mi = _mi(im, null)
	mi.extra_cull_margin = 40.0
	var t = _tick(n, Vector3.ZERO, func(node, dt, age) -> bool:
		im.clear_surfaces()
		return fn.call(im, node, dt, age))
	t.add_child(mi)
	return t


# ───────────────────────── şimşek geometrisi ─────────────────────────

static func _perp(v: Vector3) -> Vector3:
	var d = v.normalized()
	var r = _rand_dir()
	var p = r - d * r.dot(d)
	return p.normalized() if p.length_squared() > 0.000001 else Vector3.UP


## Orta nokta kırılımı: her turda parçalar ikiye bölünür, ortası dik yönde rastgele itilir, genlik yarıya iner
static func _jag(a: Vector3, b: Vector3, jag: float, depth: int) -> Array:
	var pts = [a, b]
	var amp = a.distance_to(b) * jag
	for k in depth:
		var np = [pts[0]]
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			np.append((p0 + p1) * 0.5 + _perp(p1 - p0) * randf_range(-amp, amp))
			np.append(p1)
		pts = np
		amp *= 0.5
	return pts


## Ana şimşek + çatallar (çatallar ana yoldan ayrılır, kısalır, incelir, bir kez daha çatallanabilir)
static func _fork(a: Vector3, b: Vector3, jag: float, depth: int, branches: int, out: Array, w: float, al: float) -> void:
	var main = _jag(a, b, jag, maxi(depth, 1))
	out.append({"p": main, "w": w, "a": al})
	if branches <= 0 or depth <= 1 or main.size() < 3:
		return
	var dir: Vector3 = (b - a).normalized()
	for q in branches:
		var i = randi_range(1, main.size() - 2)
		var s: Vector3 = main[i]
		var L = a.distance_to(b) * randf_range(0.15, 0.4)
		var e = s + (dir + _perp(dir) * randf_range(0.6, 1.5)).normalized() * L
		_fork(s, e, jag * 1.2, depth - 1, int(branches / 2.0), out, w * 0.45, al * 0.85)


## Şimşek: a → b (sabit ya da hareketli uçlar), her regen sn'de yeniden kırılır ve titrer; ömür boyunca söner
static func bolt(n: Node, a, b, width: float, life: float, branches := 2, col := CYAN, jag := 0.16, regen := 0.05, depth := 4) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "polys": []}
	_host(n, func(im, node, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + regen
			var polys = []
			var al = pow(1.0 - age / life, 0.6) * randf_range(0.55, 1.0)
			_fork(_pt(a), _pt(b), jag, depth, branches, polys, width, al)
			stt["polys"] = polys
		_draw_polys(im, mat, stt["polys"], _cam(node))
		return true)


## El çevresinde cıvıldayan çatırtı (Chidori sesi gibi): merkez etrafında her 35 ms yeniden doğan kısa kırık arklar
static func crackle(n: Node, pos_fn: Callable, radius: float, dur: float, count := 5, col := CYAN, width := 0.05, bind_to: Node = null) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "polys": []}
	var ow = weakref(bind_to) if bind_to != null else null
	_host(n, func(im, node, _dt, age) -> bool:
		if age > dur:
			return false
		if ow != null and (ow.get_ref() == null or not is_instance_valid(ow.get_ref())):
			return false   # bağlı olduğu düğüm (ejder başı) gitti
		if age >= float(stt["next"]):
			stt["next"] = age + 0.035
			var c0: Vector3 = pos_fn.call()
			var k = minf(1.0, age / 0.1) * clampf((dur - age) / 0.15, 0.0, 1.0)
			var polys = []
			for q in count:
				if randf() < 0.75:
					var s0 = c0 + _rand_dir() * radius * randf_range(0.05, 0.35)
					var e0 = c0 + _rand_dir() * radius * randf_range(0.6, 1.0)
					_fork(s0, e0, 0.3, 3, 1 if randf() < 0.4 else 0, polys, width, k * randf_range(0.6, 1.0))
			stt["polys"] = polys
		_draw_polys(im, mat, stt["polys"], _cam(node))
		return true)


## Çakma yıldızı (kameraya dönük); parent verilirse ona bağlı
static func flash(n: Node, at: Vector3, size: float, dur: float, col := CYAN, parent: Node3D = null) -> Ticker:
	var m = _mat("flash", {"glow": col, "seed": randf() * 10.0, "power": 1.0, "rays": float(randi_range(4, 7))})
	var t = _tick(n, at, func(node, _dt, age) -> bool:
		var u = age / dur
		if u >= 1.0:
			return false
		m.set_shader_parameter("power", pow(1.0 - u, 1.5))
		node.scale = Vector3.ONE * size * (0.7 + 0.3 * sqrt(u))
		return true, parent)
	var mi = _mi(_quad(), m)
	mi.extra_cull_margin = size * 2.0
	t.add_child(mi)
	t.scale = Vector3.ONE * size * 0.7
	return t


## Anlık ışık (OmniLight3D) — sahneyi mavimsi aydınlatır, söner
static func light(n: Node, at: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_scene(n).add_child(l)
	l.global_position = at
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Kıvılcımlar: hızla saçılan, yerçekimiyle düşen ince parlak çizgiler (tek yüzey)
static func sparks(n: Node, at: Vector3, count: int, speed: float, col := CYAN, life := 0.5, bias := Vector3.ZERO, grav := 9.0) -> void:
	var mat = _bmat(col)
	var sp = []
	for i in count:
		var v = (_rand_dir() + bias).normalized() * speed * randf_range(0.3, 1.0)
		sp.append({"p": at, "v": v, "l": life * randf_range(0.5, 1.0)})
	_host(n, func(im, node, dt, age) -> bool:
		if age > life:
			return false
		var polys = []
		for s in sp:
			if age > float(s["l"]):
				continue
			var v: Vector3 = s["v"]
			v.y -= grav * dt
			v *= maxf(0.0, 1.0 - dt * 2.0)
			s["v"] = v
			var p: Vector3 = Vector3(s["p"]) + v * dt
			s["p"] = p
			polys.append({"p": [p - v * 0.035, p], "w": 0.025, "a": 1.0 - age / float(s["l"]), "t": 0.0})
		_draw_polys(im, mat, polys, _cam(node))
		return true)


## Yanık iz (yere yatık): kor gibi parlayan ışınsal çatlaklar cool sn'de söner, iz dur sn sonra kaybolur
static func scorch(n: Node, at: Vector3, radius: float, dur: float, col := CYAN, cool := 0.9) -> void:
	var m = _mat("scorch", {"glow": col, "seed": randf() * 20.0, "heat": 1.0, "fade": 1.0})
	var mi = _mi(_quad(), m)
	mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)
	mi.scale = Vector3.ONE * radius * 2.0
	mi.extra_cull_margin = radius
	var t = Ticker.new()
	t.add_child(mi)
	t.fn = func(_node, _dt, age) -> bool:
		if age > dur:
			return false
		m.set_shader_parameter("heat", clampf(1.0 - age / cool, 0.0, 1.0) * (0.75 + 0.25 * randf()))
		m.set_shader_parameter("fade", clampf((dur - age) / (dur * 0.4), 0.0, 1.0))
		return true
	_scene(n).add_child(t)
	t.global_position = _floor(at) + Vector3.UP * 0.04


## Yerde kalan arklar: zemine sürünen kısa şimşekler, giderek seyrekleşir (iyonlaşmış zemin)
static func ground_arcs(n: Node, at: Vector3, radius: float, dur: float, count := 3, col := CYAN) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "polys": []}
	_host(n, func(im, node, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var k = 1.0 - age / dur
			var polys = []
			for q in count:
				if randf() < k:
					var a = randf() * TAU
					var s0 = _floor(at + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf())) + Vector3.UP * 0.08
					var b2 = randf() * TAU
					var e0 = _floor(s0 + Vector3(cos(b2), 0, sin(b2)) * randf_range(0.5, 1.6)) + Vector3.UP * randf_range(0.05, 0.4)
					_fork(s0, e0, 0.3, 3, 1, polys, 0.05, k * randf_range(0.5, 1.0))
			stt["polys"] = polys
		_draw_polys(im, mat, stt["polys"], _cam(node))
		return true)


## Çarpma: çakma + kıvılcım + ışık + (yere yakınsa) yanık iz ve kalan arklar
static func impact(n: Node, at: Vector3, s: float, col := CYAN) -> void:
	flash(n, at, 2.6 * s, 0.22, col)
	sparks(n, at, int(18 * s), 9.0 * s, col, 0.45)
	light(n, at, col, 5.0 * s, 8.0 * s, 0.25)
	var g = _floor(at)
	if at.y - g.y < 2.5:
		scorch(n, g, 0.9 * s, 2.4, col)
		ground_arcs(n, g, 0.9 * s, 0.9, 2, col)


## Elektrikli küre düğümü: parlak öz küre + titreyen çakma + yüzeyinde dolaşan arklar
static func orb_node(n: Node, size: float, col := CYAN) -> Node3D:
	var root = Node3D.new()
	var core = _mi(_sphere(), _emat(col))
	core.scale = Vector3.ONE * size
	root.add_child(core)
	var fm = _mat("flash", {"glow": col, "seed": randf() * 10.0, "power": 0.8, "rays": 5.0})
	var fq = _mi(_quad(), fm)
	fq.scale = Vector3.ONE * size * 3.2
	fq.extra_cull_margin = size * 3.0
	root.add_child(fq)
	var im = ImmediateMesh.new()
	var ami = _mi(im, null)
	ami.extra_cull_margin = size * 4.0
	var mat = _bmat(col)
	var stt = {"next": 0.0, "polys": []}
	var t = Ticker.new()
	t.fn = func(node, _dt, age) -> bool:
		fm.set_shader_parameter("power", randf_range(0.55, 1.0))
		fm.set_shader_parameter("seed", floor(age * 20.0) * 1.3)
		im.clear_surfaces()
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var polys = []
			for q in 4:
				var s0 = _rand_dir() * size * 0.45
				var e0 = _rand_dir() * size * randf_range(0.9, 1.6)
				_fork(s0, e0, 0.35, 3, 1, polys, size * 0.05 + 0.015, randf_range(0.6, 1.0))
			stt["polys"] = polys
		if node.is_inside_tree():
			_draw_polys(im, mat, stt["polys"], node.to_local(_cam(node)))
		return true
	t.add_child(ami)
	root.add_child(t)
	return root


## Bükülmüş ışın (yumuşak, kırıksız hüzme): pts boyunca baş hızla ilerler, sonra söner; çevresinde ince kırık kılıf
static func beam(n: Node, pts: Array, width: float, life: float, col := CYAN) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "sheath": []}
	_host(n, func(im, node, _dt, age) -> bool:
		if age > life:
			return false
		var head = clampf(age / (life * 0.3), 0.0, 1.0)
		var m = pts.size()
		var cnt = maxi(2, int(head * (m - 1)) + 1)
		var vis = pts.slice(0, cnt)
		var k = clampf((life - age) / (life * 0.6), 0.0, 1.0)
		var polys = [{"p": vis, "w": width, "a": k, "t": 0.6}]
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var sh = []
			for i in vis.size() - 1:
				if randf() < 0.5:
					_fork(vis[i], Vector3(vis[i + 1]) + _rand_dir() * width * 2.0, 0.35, 2, 0, sh, width * 0.3, k)
			stt["sheath"] = sh
		polys.append_array(stt["sheath"])
		_draw_polys(im, mat, polys, _cam(node))
		return true)


## Yılan şimşek: yol boyunca kıvrılarak ilerleyen, sürekli titreyen kırık gövde; başında parlayan çakma
static func snake_bolt(n: Node, path: Callable, dur: float, width: float, col: Color) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "polys": []}
	var hf = flash(n, path.call(0.0), width * 9.0, dur * 1.4, col)
	_host(n, func(im, node, _dt, age) -> bool:
		var s = age / dur
		if s > 1.5:
			return false
		var head = minf(s, 1.0)
		var tl = clampf(s - 0.55, 0.0, 1.0)
		if is_instance_valid(hf):
			hf.global_position = path.call(head)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var pts = []
			var N = 22
			for i in N + 1:
				var u = lerpf(tl, head, float(i) / N)
				pts.append(Vector3(path.call(u)) + _rand_dir() * width * 1.6 * float(i % 2))
			var polys = [{"p": pts, "w": width, "a": clampf(1.5 - s, 0.0, 1.0) * randf_range(0.7, 1.0), "t": 1.0}]
			for q in 2:
				var j = randi_range(1, N - 1)
				_fork(pts[j], Vector3(pts[j]) + _rand_dir() * width * 12.0, 0.3, 2, 0, polys, width * 0.4, 0.8)
			stt["polys"] = polys
		_draw_polys(im, mat, stt["polys"], _cam(node))
		return true)


## Şimşek kesiği: merkez çevresinde yay çizen, sivri uçlu parlak hilal + üstünde titreyen kırık arklar
static func arc_slash(n: Node, at: Vector3, d: Vector3, a0: float, a1: float, r: float, col := CYAN, life := 0.28) -> void:
	var mat = _bmat(col)
	var stt = {"next": 0.0, "arcs": []}
	_host(n, func(im, node, _dt, age) -> bool:
		if age > life:
			return false
		var head = clampf(age / (life * 0.35), 0.0, 1.0)
		var k = clampf((life - age) / (life * 0.6), 0.0, 1.0)
		var pts = []
		for i in 17:
			var q = float(i) / 16.0 * head
			pts.append(at + d.rotated(Vector3.UP, deg_to_rad(lerpf(a0, a1, q))) * r)
		var polys = [{"p": pts, "w": 0.16 * r, "a": k, "t": 1.0}]
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var ar = []
			for i in 4:
				var j = randi_range(0, pts.size() - 2)
				_fork(pts[j], Vector3(pts[j + 1]) + _rand_dir() * 0.4 * r, 0.3, 3, 1, ar, 0.04, k)
			stt["arcs"] = ar
		polys.append_array(stt["arcs"])
		_draw_polys(im, mat, polys, _cam(node))
		return true)


## Yerden kopan taş parçaları (toon taş, MB geometri)
static func rocks(n: Node, at: Vector3, count: int, speed: float) -> void:
	if not _cache.has("rock"):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color(0.36, 0.31, 0.26))
		b.add("box", Vector3(0.2, 0.25, 0.1), Vector3(0.6, 0.5, 0.55), Color(0.28, 0.24, 0.2), Vector3(20, 30, 10))
		_cache["rock"] = b.build(Props.toon())
	var host = Ticker.new()
	var rs = []
	for i in count:
		var mi = _mi(_cache["rock"], null)
		var s = randf_range(0.15, 0.4)
		mi.scale = Vector3.ONE * s
		host.add_child(mi)
		var v = (Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1))).normalized() * speed * randf_range(0.4, 1.0)
		rs.append({"mi": mi, "v": v, "w": _rand_dir() * randf_range(4.0, 10.0)})
	host.fn = func(node, dt, age) -> bool:
		if age > 1.6:
			return false
		for r in rs:
			var v: Vector3 = r["v"]
			v.y -= 22.0 * dt
			r["v"] = v
			var mi: MeshInstance3D = r["mi"]
			mi.position += v * dt
			var gy = Game.jutsu_floor_at(Vector3(node.global_position.x + mi.position.x, node.global_position.y, node.global_position.z + mi.position.z)).y - node.global_position.y
			if mi.position.y < gy:
				mi.position.y = gy
				r["v"] = Vector3(v.x * 0.4, 0.0, v.z * 0.4)
			mi.rotation += Vector3(r["w"]) * dt
			if age > 1.2:
				mi.scale = Vector3.ONE * maxf(0.01, mi.scale.x * 0.85)
		return true
	_scene(n).add_child(host)
	host.global_position = at


# ───────────────────────── ejder / bulut ─────────────────────────

## Çizgi boyunca kaymasız (paralel taşınan) çerçeveler: [teğet, üst, yan]
static func _frames(pts: Array) -> Array:
	var n = pts.size()
	var out = []
	var prev_n = Vector3.UP
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var tv = b - a
		tv = tv.normalized() if tv.length() > 0.00001 else Vector3.FORWARD
		var nv: Vector3 = prev_n - tv * tv.dot(prev_n)
		if nv.length() < 0.01:
			nv = Vector3.RIGHT - tv * tv.dot(Vector3.RIGHT)
		nv = nv.normalized()
		prev_n = nv
		out.append([tv, nv, tv.cross(nv)])
	return out


## Elips kesitli loft (rad[i] = Vector2(yan, üst)); ön yüz saat yönünde (dışa bakar)
static func _loft(st: SurfaceTool, pts: Array, rad: Array, sides := 10, xf := Transform3D.IDENTITY) -> void:
	var fr = _frames(pts)
	var n = pts.size()
	var rings = []
	var norms = []
	for i in n:
		var f: Array = fr[i]
		var rv: Vector2 = rad[i]
		rv = Vector2(maxf(rv.x, 0.002), maxf(rv.y, 0.002))
		var ring = []
		var nr = []
		for s in sides + 1:
			var a = TAU * s / sides
			ring.append(xf * (Vector3(pts[i]) + f[2] * cos(a) * rv.x + f[1] * sin(a) * rv.y))
			nr.append((xf.basis * (f[2] * cos(a) * rv.y + f[1] * sin(a) * rv.x)).normalized())
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		for s in sides:
			for q in [[i, s, u0], [i + 1, s + 1, u1], [i + 1, s, u1], [i, s, u0], [i, s + 1, u0], [i + 1, s + 1, u1]]:
				st.set_color(Color.WHITE)
				st.set_normal(norms[q[0]][q[1]])
				st.set_uv(Vector2(q[2], float(q[1]) / sides))
				st.add_vertex(rings[q[0]][q[1]])


## Şimşek ejderi başı (yerel -Z ileri, boy ~2): loft kafatası + uzun burun, aşağı açılmış alt çene, dişler, gözler,
## geriye kıvrık uzun boynuzlar, yele dikenleri, sarkan bıyıklar (kutu yığını değil, pürüzsüz kesitler)
static func _dragon_head_mesh() -> ArrayMesh:
	if _cache.has("dhead2"):
		return _cache["dhead2"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, [Vector3(0, 0.05, 0.55), Vector3(0, 0.1, 0.3), Vector3(0, 0.1, 0.0), Vector3(0, 0.05, -0.35), Vector3(0, 0.0, -0.7),
		Vector3(0, -0.02, -1.05), Vector3(0, -0.04, -1.3), Vector3(0, -0.05, -1.38)],
		[Vector2(0.2, 0.18), Vector2(0.46, 0.36), Vector2(0.5, 0.38), Vector2(0.38, 0.27), Vector2(0.3, 0.2), Vector2(0.25, 0.16),
		Vector2(0.16, 0.1), Vector2(0.01, 0.01)], 12)
	var pv = Vector3(0, -0.1, 0.25)
	var jaw = Transform3D(Basis.IDENTITY, pv) * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pv)
	_loft(st, [Vector3(0, -0.15, 0.35), Vector3(0, -0.2, 0.0), Vector3(0, -0.22, -0.45), Vector3(0, -0.22, -0.85), Vector3(0, -0.22, -1.1), Vector3(0, -0.22, -1.18)],
		[Vector2(0.3, 0.14), Vector2(0.36, 0.16), Vector2(0.28, 0.12), Vector2(0.2, 0.09), Vector2(0.12, 0.06), Vector2(0.01, 0.01)], 10, jaw)
	for sx in [-1.0, 1.0]:
		for i in 4:
			var z = -0.4 - i * 0.2
			_loft(st, [Vector3(sx * 0.19, -0.1, z), Vector3(sx * 0.19, -0.3, z)], [Vector2(0.045, 0.045), Vector2(0.004, 0.004)], 5)
			_loft(st, [Vector3(sx * 0.17, -0.13, z + 0.06), Vector3(sx * 0.17, 0.04, z + 0.06)], [Vector2(0.04, 0.04), Vector2(0.004, 0.004)], 5, jaw)
		_loft(st, [Vector3(sx * 0.38, 0.22, -0.06), Vector3(sx * 0.4, 0.23, -0.2), Vector3(sx * 0.37, 0.21, -0.36)],
			[Vector2(0.01, 0.01), Vector2(0.06, 0.08), Vector2(0.01, 0.01)], 8)
		_loft(st, [Vector3(sx * 0.25, 0.3, 0.3), Vector3(sx * 0.34, 0.6, 0.8), Vector3(sx * 0.32, 0.8, 1.35), Vector3(sx * 0.26, 0.86, 1.8)],
			[Vector2(0.12, 0.12), Vector2(0.09, 0.09), Vector2(0.05, 0.05), Vector2(0.005, 0.005)], 7)
		_loft(st, [Vector3(sx * 0.22, -0.02, -1.0), Vector3(sx * 0.65, -0.05, -0.6), Vector3(sx * 0.95, -0.3, 0.05), Vector3(sx * 1.1, -0.6, 0.75)],
			[Vector2(0.04, 0.04), Vector2(0.03, 0.03), Vector2(0.018, 0.018), Vector2(0.003, 0.003)], 5)
		for k in 4:
			var b = Vector3(sx * 0.36, 0.1 - k * 0.04, 0.3 + k * 0.2)
			_loft(st, [b, b + Vector3(sx * 0.4, 0.15, 0.45)], [Vector2(0.09, 0.05), Vector2(0.004, 0.004)], 5)
	for k in 6:
		var b2 = Vector3(0, 0.36 - k * 0.03, 0.15 + k * 0.2)
		_loft(st, [b2, b2 + Vector3(0, 0.5 - k * 0.05, 0.38)], [Vector2(0.06, 0.11), Vector2(0.004, 0.004)], 5)
	var mesh = st.commit()
	_cache["dhead2"] = mesh
	return mesh


## Gövde tüpü (dünya koordinatı, her kare yeniden örülür): pts baştan kuyruğa, rads yarıçap, k ölçek (parıltı kabuğu için)
static func _tube(im: ImmediateMesh, pts: Array, rads: Array, sides: int, k: float) -> void:
	var fr = _frames(pts)
	var n = pts.size()
	var rings = []
	var norms = []
	for i in n:
		var f: Array = fr[i]
		var ring = []
		var nr = []
		for s in sides + 1:
			var a = TAU * s / sides
			var dv: Vector3 = f[2] * cos(a) + f[1] * sin(a)
			ring.append(Vector3(pts[i]) + dv * float(rads[i]) * k)
			nr.append(dv)
		rings.append(ring)
		norms.append(nr)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		for s in sides:
			for q in [[i, s, u0], [i + 1, s + 1, u1], [i + 1, s, u1], [i, s, u0], [i, s + 1, u0], [i + 1, s + 1, u1]]:
				im.surface_set_normal(norms[q[0]][q[1]])
				im.surface_set_uv(Vector2(q[2], float(q[1]) / sides))
				im.surface_add_vertex(rings[q[0]][q[1]])
	im.surface_end()


## Şimşek ejderi: baş (elektrikli yüzey + çevresinde arklar) ve onu izleyen gövde (omurga boyunca titreyen 3 kırık iplik +
## geniş parıltı şeridi + yer yer kopan çatallar). Döner: {"head": Node3D}. Baş silinince gövde sönerek kaybolur.
static func dragon(n: Node, s: float, length: float, radius: float, col := CYAN) -> Node3D:
	var head = Node3D.new()
	var hm = _mi(_dragon_head_mesh(), _smat(col))   # seçilir koyu-mavi gövde + camgöbeği kenar + beyaz damarlar
	hm.scale = Vector3.ONE * s
	head.add_child(hm)
	var hg = _mi(_dragon_head_mesh(), _emat(col))   # üstünde toplamalı parıltı kabuğu
	hg.scale = Vector3.ONE * s * 1.08
	head.add_child(hg)
	var fl = _mat("flash", {"glow": col, "seed": 1.0, "power": 0.8, "rays": 6.0})
	var fq = _mi(_quad(), fl)
	fq.scale = Vector3.ONE * s * 3.0
	fq.extra_cull_margin = s * 3.0
	head.add_child(fq)
	_scene(n).add_child(head)
	crackle(n, _follow_fn(head, Vector3.ZERO), s * 1.6, 30.0, 6, col, 0.04 + s * 0.02, head)
	var mat = _bmat(col)
	var hist = []
	var stt = {"next": 0.0, "polys": [], "fade": 1.0}
	var hw = weakref(head)
	var bim = ImmediateMesh.new()   # pürüzsüz gövde (seçilir koyu elektrik mavisi, beyaz damar, camgöbeği kenar)
	var gim = ImmediateMesh.new()   # üstünde toplamalı parıltı kabuğu
	var host = _host(n, func(im, node, dt, age) -> bool:
		var h = hw.get_ref()
		var alive = h != null and is_instance_valid(h) and h.is_inside_tree()
		if alive:
			fl.set_shader_parameter("power", randf_range(0.5, 0.95))
			var p: Vector3 = h.global_position
			if hist.is_empty() or Vector3(hist[hist.size() - 1]).distance_to(p) > radius * 0.25:
				hist.append(p)
			var tot = 0.0
			var cut = 0
			for i in range(hist.size() - 1, 0, -1):
				tot += Vector3(hist[i]).distance_to(hist[i - 1])
				if tot > length:
					cut = i - 1
					break
			for r in cut:   # yerinde kırp (yakalanan dizi yeniden atanmaz)
				hist.pop_front()
		else:
			stt["fade"] = float(stt["fade"]) - dt * 3.0
			if float(stt["fade"]) <= 0.0:
				return false
		if hist.size() < 2:
			return true
		# gövde: baştan kuyruğa yay uzunluğuyla eşit örnekler → incelen yarıçapla loft tüp, boyunca akan hafif dalga
		var fd0 = float(stt["fade"])
		var ns = 24
		var stp = length / ns
		var idx = hist.size() - 1
		var acc = 0.0
		var bpts = [Vector3(hist[idx])]
		for k in range(1, ns + 1):
			var want = stp * k
			while idx > 0 and acc + Vector3(hist[idx]).distance_to(hist[idx - 1]) < want:
				acc += Vector3(hist[idx]).distance_to(hist[idx - 1])
				idx -= 1
			if idx == 0:
				break
			var sl = Vector3(hist[idx]).distance_to(hist[idx - 1])
			bpts.append(Vector3(hist[idx]).lerp(hist[idx - 1], clampf((want - acc) / maxf(sl, 0.001), 0.0, 1.0)))
		bim.clear_surfaces()
		gim.clear_surfaces()
		if bpts.size() >= 3 and fd0 > 0.0:
			var bfr = _frames(bpts)
			var rads = []
			for k in bpts.size():
				var u = float(k) / ns
				var rr = lerpf(0.75, 1.0, clampf(u / 0.12, 0.0, 1.0)) if u < 0.12 else lerpf(1.0, 0.08, (u - 0.12) / 0.88)
				rads.append(radius * 0.85 * rr * fd0)
				var f: Array = bfr[k]
				bpts[k] = Vector3(bpts[k]) + (f[1] * sin(k * 0.7 - age * 8.0) + f[2] * cos(k * 0.5 - age * 6.0)) * radius * 0.12 * u
			_tube(bim, bpts, rads, 14, 1.0)
			_tube(gim, bpts, rads, 14, 1.12)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.045
			var fd = float(stt["fade"])
			var m = hist.size()
			var polys = [{"p": hist.duplicate(), "w": radius * 0.9, "a": 0.28 * fd, "t": 1.0}]
			for strand in 3:
				var pts = []
				for i in m:
					var f = float(i) / float(m - 1)
					pts.append(Vector3(hist[i]) + _rand_dir() * radius * 0.55 * f)
				polys.append({"p": pts, "w": radius * 0.16 * (1.0 - strand * 0.25), "a": fd * randf_range(0.7, 1.0), "t": 1.0})
			for q in 3:
				var j = randi_range(0, m - 1)
				_fork(hist[j], Vector3(hist[j]) + _rand_dir() * radius * 2.0, 0.35, 3, 1, polys, radius * 0.05, fd)
			stt["polys"] = polys
		_draw_polys(im, mat, stt["polys"], _cam(node))
		return true)
	var bmi = _mi(bim, _smat(col))
	bmi.extra_cull_margin = 80.0
	host.add_child(bmi)
	var gmi = _mi(gim, _emat(col))
	gmi.extra_cull_margin = 80.0
	host.add_child(gmi)
	return head


## Fırtına bulutu: gökte kabaran koyu cel topaklar halkası; dönen taşıyıcı. Döner: {"host", "mat"}
static func storm_cloud(n: Node, at: Vector3, radius: float, count: int, dur: float) -> Dictionary:
	var m = _mat("cloud", {"grow": 0.0, "flash": 0.0})
	var host = Ticker.new()
	for i in count:
		var a = randf() * TAU
		var r = radius * sqrt(randf())
		var mi = _mi(_sphere(), m)
		var sz = randf_range(12.0, 22.0) * (1.2 - r / radius * 0.4)
		mi.scale = Vector3(sz, sz * randf_range(0.4, 0.6), sz)
		mi.position = Vector3(cos(a) * r, randf_range(-2.5, 2.5) + (1.0 - r / radius) * 3.0, sin(a) * r)
		mi.extra_cull_margin = sz
		host.add_child(mi)
	host.fn = func(node, dt, age) -> bool:
		if age > dur:
			return false
		var g = minf(1.0, age / 0.6) * clampf((dur - age) / 1.4, 0.0, 1.0)
		m.set_shader_parameter("grow", g)
		var f = _sp0(m.get_shader_parameter("flash"))
		m.set_shader_parameter("flash", maxf(0.0, f - dt * 5.0))
		node.rotate_y(dt * 0.12)
		return true
	_scene(n).add_child(host)
	host.global_position = at
	return {"host": host, "mat": m}


# ═════════════════════════════════════════ teknikler ═════════════════════════════════════════

## Kirin: gökte koyu fırtına bulutu kabarır, içinde şimşekler çakar ve bulut içten aydınlanır; bulutun içinden dev bir
## şimşek ejderi kavis çizerek kilitli hedefe iner; çarpışta gökle yer arasında kalın ana şimşek, çakma, her yöne kıvılcım,
## yerde kor gibi parlayan büyük yanık ve uzun süre sürünen arklar. (Fırtına şartı CanonRules'ta, değişmedi.)
static func kirin(js, c: Node3D, t: Node3D) -> void:   # js: Jutsu otomatik yüklemesi (türsüz: _tg / _inf ona özgü)
	var tg = js._tg(c, t, 45.0)
	var pos: Vector3 = tg.global_position if tg else js._ground(js._aim_ground(c, t, 20.0, 40.0))
	var sky = pos + Vector3.UP * 70.0 - js._aim_flat(c, t) * 10.0   # animede fırtına bulutları gökyüzünde; ejder oradan iner
	var col = Color(0.55, 0.75, 1.0)
	Sfx.play("thunder", sky, 0.6)
	# fırtına karanlığı yalnız yakındaki oyuncuda ve kendiliğinden geçer (atan ölünce temizleme kodu çalışmıyor, ekran kararık kalıyordu)
	if Game.world and Game.player and is_instance_valid(Game.player) and Game.player.global_position.distance_to(pos) < 90.0:
		Game.world.env.flash_tint(Color(0.05, 0.05, 0.15, 0.35), 4.0)
	# 1) bulut toplanması: kabaran koyu topaklar + içinde çakan şimşekler (bulut içten aydınlanır)
	# Görsel bulut alçakta (yerden ~30 m, kameradan görünür, ekranın üstünü kaplar); ses / oynanış konumları değişmedi
	var cloud_at: Vector3 = pos + Vector3.UP * 30.0 - js._aim_flat(c, t) * 6.0
	var cl = storm_cloud(js, cloud_at + Vector3.UP * 5.0, 38.0, 36, 6.5)
	var cm: ShaderMaterial = cl["mat"]
	crackle(js, func() -> Vector3: return cloud_at + Vector3.UP * 2.0, 26.0, 3.0, 4, col, 0.3)
	for k in 6:
		js.get_tree().create_timer(0.2 + k * 0.18).timeout.connect(func():
			var a = cloud_at + Vector3(randf_range(-25, 25), randf_range(0, 4), randf_range(-25, 25))
			bolt(js, a, a + Vector3(randf_range(-18, 18), randf_range(-6, 0), randf_range(-18, 18)), 0.5, 0.25, 4, col, 0.2, 0.05, 5)
			cm.set_shader_parameter("flash", 1.0)
			if Game.world: Game.world.env.screen_flash(0.04))
	# 1b) ejder bulutun altında belirir ve kıvrılarak döner (okunsun diye dalıştan önce 0.6 sn görünür; vuruş zamanı aynı)
	var hold = {}
	js.get_tree().create_timer(0.8).timeout.connect(func():
		var hd = dragon(js, 5.5, 46.0, 3.4, col)
		hd.global_position = cloud_at
		hold["h"] = hd
		cm.set_shader_parameter("flash", 1.0)
		var ctw = hd.create_tween()
		ctw.tween_method(func(k: float):
			var a = k * TAU * 0.8
			var p = cloud_at + Vector3(cos(a) * 9.0, -k * 4.0, sin(a) * 9.0)
			var a2 = a + 0.1
			var nx = cloud_at + Vector3(cos(a2) * 9.0, -k * 4.0 - 0.3, sin(a2) * 9.0)
			hd.global_position = p
			hd.look_at(nx, Vector3.UP), 0.0, 1.0, 0.6)
		hold["tw"] = ctw)
	# 2) şimşek ejderhası iner
	js.get_tree().create_timer(1.4).timeout.connect(func():
		if tg and is_instance_valid(tg):
			pos = tg.global_position
		var head: Node3D = hold.get("h") if hold.has("h") and is_instance_valid(hold["h"]) else null
		if head == null:
			head = dragon(js, 5.5, 46.0, 3.4, col)
			head.global_position = cloud_at
		if hold.has("tw") and hold["tw"] is Tween and (hold["tw"] as Tween).is_valid():
			(hold["tw"] as Tween).kill()   # kıvrılma bitti, dalış başlar
		var start: Vector3 = head.global_position
		cm.set_shader_parameter("flash", 1.0)
		var tw = head.create_tween()
		var mid = start.lerp(pos, 0.5) + Vector3(randf_range(-8, 8), 4.0, randf_range(-8, 8))
		tw.tween_method(func(k: float):
			var a = start.lerp(mid, k); var b2 = mid.lerp(pos, k)
			var p = a.lerp(b2, k)
			var nxt = start.lerp(mid, minf(1.0, k + 0.02)).lerp(mid.lerp(pos, minf(1.0, k + 0.02)), minf(1.0, k + 0.02))
			head.global_position = p
			if nxt.distance_to(p) > 0.01:
				head.look_at(nxt, Vector3.UP if absf((nxt - p).normalized().y) < 0.98 else Vector3.RIGHT), 0.0, 1.0, 0.8)
		tw.tween_callback(func():
			bolt(js, cloud_at + Vector3.UP * 4.0, pos, 1.6, 0.5, 8, Color(0.85, 0.95, 1.0), 0.12, 0.05, 6)
			bolt(js, cloud_at + Vector3(randf_range(-10, 10), 4.0, randf_range(-10, 10)), pos, 0.7, 0.35, 4, col, 0.16, 0.05, 6)
			cm.set_shader_parameter("flash", 1.0)
			flash(js, pos + Vector3.UP * 2.0, 26.0, 0.45, Color(0.75, 0.9, 1.0))
			flash(js, pos + Vector3.UP * 0.5, 12.0, 0.9, col)
			sparks(js, pos + Vector3.UP * 2.0, 160, 40.0, col.lightened(0.4), 0.7)
			for q in 14:   # yere yayılan kalın kökler
				var a = q * TAU / 14.0 + randf() * 0.3
				var e = _floor(pos + Vector3(cos(a), 0, sin(a)) * randf_range(9.0, 16.0)) + Vector3.UP * 0.2
				bolt(js, pos + Vector3.UP * 0.3, e, 0.35, 0.6, 2, col, 0.18, 0.06, 5)
			scorch(js, pos, 9.0, 6.0, col, 2.0)
			ground_arcs(js, pos, 10.0, 3.5, 6, col)
			rocks(js, pos + Vector3.UP * 0.3, 26, 20.0)
			light(js, pos + Vector3.UP * 3.0, col, 14.0, 40.0, 0.8)
			Combat.hit_sphere(c, pos + Vector3.UP, 7.0, js._inf(c, "kirin", 3.0, {"stun": 2.0, "knock": 18.0, "launch": 8.0}))
			Sfx.play("thunder", pos, 1.0)
			Sfx.play("boom", pos, 0.6)
			if Game.world:
				Game.world.env.add_shake(2.0)
				Game.world.env.screen_flash(0.6)
				Game.world.env.set_tint(Color(0, 0, 0, 0))
			head.queue_free()))


## Kangekiha: elde cıvıldayan çatırtı toplanır; kol savrulunca ileri doğru genişleyerek ilerleyen yatay şimşek perdeleri,
## öne fırlayan beyaz çatallar; geçtiği yerde yanık izleri ve sürünen arklar kalır
static func kangekiha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var hand = _hand_fn(pj, c, true)
	crackle(pj, hand, 0.7, 0.35, 7, CYAN, 0.04)
	flash(pj, hand.call(), 0.9, 0.3, CYAN)
	pj.after(0.2, func():
		# Kangekiha: ileri savrulan mavi şimşek dalgası
		var o = c.global_position + Vector3.UP * 1.0 + d * 1.2
		light(pj, o + d * 6.0, CYAN, 8.0, 22.0, 0.5)
		flash(pj, o, 3.5, 0.25, WHITEBLUE)
		for k in 8:
			pj.after(k * 0.04, func():
				var q = c.global_position + Vector3.UP * 1.0 + d * (2.0 + k * 2.0)
				var w = 1.5 + k * 0.6
				bolt(pj, q - side * w, q + side * w, 0.38, 0.45, 3, CYAN, 0.14, 0.045, 5)
				bolt(pj, q - side * w * 0.8 + Vector3.UP * 0.6, q + side * w * 0.8 + Vector3.UP * 0.6, 0.22, 0.35, 2, WHITEBLUE, 0.18, 0.045, 5)
				bolt(pj, q, q + d * 2.5 + side * randf_range(-w, w) + Vector3.UP * randf_range(-0.5, 1.5), 0.18, 0.3, 1, WHITEBLUE)
				var g = _floor(q)
				scorch(pj, g, 0.9 + k * 0.2, 4.0, CYAN, 1.0)
				ground_arcs(pj, g, w * 0.6, 2.4, 2, CYAN))
		Combat.hit_zone(c, c.global_position, d, 18.0, 30.0, 3.0, pj.inf(c, "raiton_kangekiha", 1.2, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.6}))
		pj.shake(0.4))
	Sfx.play("thunder", c.global_position, 1.1)


## Vishnu Senpō Raiton: sennin chakrası bedenin üstünde altın çatırtıyla toplanır (her yönden içe akan şimşekler); gökten
## dört kalın altın şimşek sütunu iner, yere on altın kök yayılır; büyük kor yanık ve uzun süren altın arklar
static func vishnu_senpo_raiton(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 34.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var gold = Color(1.0, 0.85, 0.35)
	var top = _follow_fn(c, Vector3.UP * 2.0)
	crackle(pj, _follow_fn(c, Vector3.UP * 1.1), 1.5, 0.65, 7, gold, 0.05)
	for k in 8:   # içe akan altın şimşekler
		pj.after(k * 0.06, func():
			var tp: Vector3 = top.call()
			bolt(pj, tp + _rand_dir() * randf_range(2.5, 4.0), top, 0.1, 0.18, 1, gold, 0.25))
	flash(pj, top.call(), 2.0, 0.6, gold)
	pj.after(0.6, func():
		for k in 4:
			pj.after(k * 0.07, func(): bolt(pj, at + Vector3(randf_range(-2, 2), 60.0, randf_range(-2, 2)), at, (1.6 - k * 0.3) * 0.7, 0.45, 6, gold, 0.12, 0.05, 6))
		for i in 10:
			var a = TAU * i / 10.0
			bolt(pj, at + Vector3.UP * 0.3, _floor(at + Vector3(cos(a), 0.0, sin(a)) * randf_range(8.0, 14.0)) + Vector3.UP * 0.15, 0.25, 0.5, 2, gold.lightened(0.2), 0.16, 0.06, 5)
		light(pj, at + Vector3.UP * 4.0, gold, 16.0, 30.0, 0.5)
		flash(pj, at + Vector3.UP * 3.0, 18.0, 0.5, gold)
		sparks(pj, at + Vector3.UP, 120, 30.0, gold, 0.7)
		scorch(pj, at, 8.0, 6.0, gold, 1.6)
		ground_arcs(pj, at, 9.0, 3.0, 5, gold)
		rocks(pj, at + Vector3.UP * 0.3, 18, 16.0)
		pj.hit(c, at + Vector3.UP, 12.0, pj.inf(c, "vishnu_senpo_raiton", 3.0, {"knock": 16.0, "launch": 8.0, "kind": "heavy", "element": "raiton", "stun": 1.5}))
		if Game.world:
			Game.world.env.screen_flash(0.3)
		pj.shake(1.8))
	Sfx.play("thunder", at, 0.6)


## Raiso Gekishin: yere vuran elden altı şimşek faresi fırlar — zeminde zıplayarak koşan parlak küreler, arkalarında yanık
## çizgisi ve sekmeli kısa şimşekler; hedefin altında yerden göğe şimşek fışkırır
static func raiso_gekishin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	crackle(pj, _hand_fn(pj, c, true), 0.6, 0.3, 6, RAI, 0.04)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var o = pj.gp(c.global_position)
		flash(pj, o + Vector3.UP * 0.3, 3.0, 0.25, RAI)
		scorch(pj, o, 1.2, 2.5, RAI)
		var targets = pj.enemies_near(c, o, 20.0)
		for k in 6:
			var dest = pj.gp(targets[k % targets.size()].global_position) if not targets.is_empty() else o + Vector3(cos(k * TAU / 6.0), 0, sin(k * TAU / 6.0)) * 10.0
			var path_pts = []
			for s in 8:
				path_pts.append(o.lerp(dest, s / 7.0) + Vector3(randf_range(-0.8, 0.8), 0.15, randf_range(-0.8, 0.8)))
			var rat = orb_node(pj, 0.32, RAI)   # şimşek faresi
			pj.scene_add(rat, path_pts[0])
			var rtw = rat.create_tween()
			rtw.tween_interval(k * 0.03)
			for s in 7:
				rtw.tween_property(rat, "global_position", Vector3(path_pts[s + 1]) + Vector3.UP * 0.25, 0.06)
			rtw.tween_interval(0.5)
			rtw.tween_callback(rat.queue_free)
			for s in 7:
				pj.after(s * 0.06 + k * 0.03, func():
					bolt(pj, path_pts[s], path_pts[s + 1], 0.1, 0.14, 1, Color(0.7, 0.9, 1.0), 0.25)
					scorch(pj, path_pts[s], 0.35, 1.8, RAI, 0.5)
					sparks(pj, path_pts[s], 4, 4.0, RAI, 0.25, Vector3.UP))
			pj.after(0.5 + k * 0.03, func():
				bolt(pj, dest, dest + Vector3.UP * 4.0, 0.4, 0.25, 3, RAI, 0.14, 0.045, 5)
				flash(pj, dest + Vector3.UP * 1.0, 3.2, 0.25, RAI)
				sparks(pj, dest + Vector3.UP * 0.3, 16, 8.0, RAI, 0.5, Vector3.UP)
				scorch(pj, dest, 1.3, 2.6, RAI)
				ground_arcs(pj, dest, 1.4, 1.2, 2, RAI)
				pj.hit(c, dest + Vector3.UP, 2.4, pj.inf(c, "raiso_gekishin", 0.45, {"knock": 3.0, "launch": 5.0, "kind": "heavy", "element": "raiton", "stun": 0.6})))
		pj.shake(0.5))
	Sfx.play("thunder", c.global_position, 1.3)


## Bakurai: elden yere inen şimşek yükü toprağa gömülür — zeminde kor gibi ısınan yanık çatlakları ve yükselen kıvılcımlar;
## sonra patlar: yukarı-dışa sekiz şimşek, kopan taşlar, büyük çakma, yerde süren arklar
static func raiton_bakurai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	bolt(pj, pj.hand_pos(c, true), at, 0.15, 0.2, 1, RAI)
	scorch(pj, at, 1.6, 4.0, RAI, 1.4)   # gömülen yük: zemin kızarır
	ground_arcs(pj, at, 1.2, 0.6, 3, RAI)
	pj.every(0.6, 0.08, func(_i, _k):
		sparks(pj, at, 5, 5.0, RAI, 0.25, Vector3.UP * 1.5), func():
		for i in 8:
			var a = TAU * i / 8.0
			bolt(pj, at, at + Vector3(cos(a) * 4.0, randf_range(2.0, 6.0), sin(a) * 4.0), 0.3, 0.3, 2, RAI, 0.16, 0.05, 5)
		rocks(pj, at + Vector3.UP * 0.2, 12, 12.0)
		scorch(pj, at, 3.8, 4.5, RAI, 1.2)
		ground_arcs(pj, at, 3.5, 2.0, 4, RAI)
		flash(pj, at + Vector3.UP * 1.0, 7.0, 0.35, WHITEBLUE)
		sparks(pj, at + Vector3.UP * 0.5, 50, 14.0, RAI, 0.6, Vector3.UP * 0.6)
		light(pj, at + Vector3.UP, RAI, 10.0, 16.0, 0.3)
		pj.hit(c, at + Vector3.UP, 4.5, pj.inf(c, "raiton_bakurai", 1.4, {"knock": 6.0, "launch": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
		pj.shake(0.8))
	Sfx.play("thunder", at, 1.0)


## Rairyū no Tatsumaki: şimşek ejderi dönerek ileri yükselir, altında zeminde dönen ark halkası ve sarmal yanık izi; yakındaki
## rakiplere başından şimşek atar
static func rairyu_no_tatsumaki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var start = pj.gp(c.global_position + d * 3.0)
	crackle(pj, _hand_fn(pj, c, true), 0.8, 0.4, 7, RAI, 0.05)
	flash(pj, start + Vector3.UP * 1.5, 4.0, 0.3, RAI)
	var head = dragon(pj, 1.8, 16.0, 1.4, RAI)
	head.global_position = start
	pj.every(3.0, 1.0 / 30.0, func(i, k):
		if not is_instance_valid(head):
			return
		var base = pj.gp(start + d * k * 22.0)
		var a = k * TAU * 8.0
		var p = base + Vector3(cos(a) * 3.0, 2.0 + sin(k * PI * 6.0) * 4.0 + 4.0, sin(a) * 3.0)
		head.look_at(p, Vector3.UP)
		head.global_position = p
		if i % 6 == 0:
			for e in pj.enemies_near(c, base, 4.0):
				if pj.live(e):
					bolt(pj, p, e.global_position + Vector3.UP, 0.2, 0.15, 2, RAI)
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "rairyu_no_tatsumaki", 0.3, {"knock": 3.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
		if i % 10 == 0:   # tabanda dönen ark halkası + sarmal yanık
			for q in 6:
				var b0 = a + q * TAU / 6.0
				bolt(pj, base + Vector3(cos(b0), 0.1, sin(b0)) * 2.6, base + Vector3(cos(b0 + 0.9), 0.4, sin(b0 + 0.9)) * 2.6, 0.12, 0.3, 1, RAI, 0.25)
			scorch(pj, base, 1.6, 2.5, RAI, 0.8), func():
		if is_instance_valid(head):
			head.queue_free())
	Sfx.play("thunder", start, 1.0)


## Rengō Raibakudan: çevrende beş şimşek küresi belirir, hedefte birleşip dev bir küre olur ve patlar: on dört şimşek,
## dev çakma, kıvılcım yağmuru, yere yakınsa yanık ve arklar
static func raiton_rengo_raibakudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	var at = (tt.global_position + Vector3.UP * 1.2) if tt else c.global_position + pj.fwd(c, t) * 12.0 + Vector3.UP * 1.2
	for k in 5:
		var orb = orb_node(pj, 0.5, RAI)
		var a = TAU * k / 5.0
		var p0 = c.global_position + Vector3(cos(a) * 2.0, 2.2, sin(a) * 2.0)
		pj.scene_add(orb, p0)
		orb.scale = Vector3.ONE * 0.05
		var tw = orb.create_tween()
		tw.tween_property(orb, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.15)
		tw.tween_property(orb, "global_position", at, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(orb.queue_free)
		bolt(pj, c.global_position + Vector3.UP * 1.2, p0, 0.08, 0.2, 1, RAI, 0.25)
	pj.after(0.85, func():
		var big = orb_node(pj, 2.2, Color(0.7, 0.88, 1.0))
		pj.scene_add(big, at)
		var btw = big.create_tween()
		btw.tween_interval(0.35)
		btw.tween_property(big, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
		btw.tween_callback(big.queue_free)
		for i in 14:
			var d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
			bolt(pj, at, at + d * randf_range(5.0, 10.0), 0.3, 0.35, 3, RAI, 0.16, 0.05, 5)
		light(pj, at, RAI, 14.0, 24.0, 0.4)
		flash(pj, at, 12.0, 0.4, WHITEBLUE)
		sparks(pj, at, 90, 22.0, RAI, 0.6)
		var g = _floor(at)
		if at.y - g.y < 4.0:
			scorch(pj, g, 4.0, 4.0, RAI, 1.2)
			ground_arcs(pj, g, 4.0, 2.0, 4, RAI)
		pj.hit(c, at, 7.0, pj.inf(c, "raiton_rengo_raibakudan", 2.4, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "stun": 1.2}))
		if Game.world:
			Game.world.env.screen_flash(0.2)
		pj.shake(1.2))
	Sfx.play("thunder", c.global_position, 1.0)


## Kumo şimşek zırhı hissi: bedenin çevresinde sürekli çatırdayan arklar
static func _rai_cloak(pj: PathJutsu, c: Node3D, dur: float) -> void:
	crackle(pj, _follow_fn(c, Vector3.UP * 1.0), 1.15, dur, 8, RAIKAGE, 0.05)
	crackle(pj, _follow_fn(c, Vector3.UP * 0.4), 0.8, dur, 4, WHITEBLUE, 0.035)


## Bijū Rairai Netsuto: beden şimşek zırhına bürünür; şimşek hızında ileri atılış — yol boyunca zincir şimşek ve paralel hız
## şimşekleri, ardında yanık çizgisi; varışta çakma
static func biju_rairai_netsuto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	_rai_cloak(pj, c, 1.0)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var a = c.global_position
		var b = pj.gp(a + d * 16.0)
		for k in 6:
			bolt(pj, a.lerp(b, k / 6.0) + Vector3.UP, a.lerp(b, (k + 1) / 6.0) + Vector3.UP * randf_range(0.6, 1.6), 0.3, 0.3, 2, RAI, 0.16, 0.05, 4)
			scorch(pj, a.lerp(b, (k + 0.5) / 6.0), 0.9, 2.4, RAI, 0.6)
		var sd = d.cross(Vector3.UP).normalized()
		for q in 4:   # paralel hız şimşekleri
			var off = sd * randf_range(-0.8, 0.8) + Vector3.UP * randf_range(0.4, 1.8)
			bolt(pj, a + off, b + off, 0.08, 0.35, 0, WHITEBLUE, 0.03, 0.06, 4)
		ground_arcs(pj, a.lerp(b, 0.5), 6.0, 1.2, 4, RAI)
		c.global_position = b
		var ip = b + Vector3.UP + d
		flash(pj, ip, 4.4, 0.25, WHITEBLUE)
		sparks(pj, ip, 28, 16.0, RAI, 0.4)
		scorch(pj, pj.gp(ip), 1.8, 2.6, RAI)
		pj.shake(0.25 * 2.0)
		Combat.hit_zone(c, a, d, 16.0, 30.0, 3.5, pj.inf(c, "biju_rairai_netsuto", 2.4, {"knock": 22.0, "launch": 6.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "dir": d})))
	Sfx.play("thunder", c.global_position, 1.0)


## Shunrai Konbineshon: iki yandan çapraz geçen iki şimşek çizgisi (arkalarında kısa süre kalan ardıl ışık), hedefte
## şimşekli kılıç hilali ve üstünde titreyen arklar
static func shunrai_konbineshon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 14.0)
	pj._ensure_blade(c, 0.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var a = c.global_position
	var b = pj.gp((tt.global_position + d * 2.0) if tt else a + d * 12.0)
	flash(pj, a + Vector3.UP, 2.4, 0.2, RAI)
	for s in [-1.0, 1.0]:
		var p0 = a + side * s * 1.5 + Vector3.UP
		var p1 = b - side * s * 1.5 + Vector3.UP
		bolt(pj, p0, p1, 0.2, 0.25, 2, RAI)
		beam(pj, [p0, p0.lerp(p1, 0.5), p1], 0.1, 0.35, WHITEBLUE)
		scorch(pj, p0.lerp(p1, 0.5), 0.8, 2.0, RAI, 0.5)
	c.global_position = b
	if tt and pj.live(tt):
		arc_slash(pj, tt.global_position + Vector3.UP, side, -60.0, 60.0, 1.8, Color(0.8, 0.9, 1.0))
		impact(pj, tt.global_position + Vector3.UP, 0.8, RAI)
		pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.5, pj.inf(c, "shunrai_konbineshon", 1.8, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
	Sfx.play("chidori", b, 1.4)


## Yakın dövüş vuruşu (eski ortak vuruşun oynanış kısmı) + kendi şimşek çarpması
static func _mhit(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary, col: Color) -> Array:
	var hs = pj.hit(c, pos, r, info)
	if not hs.is_empty():
		impact(pj, hs[0].global_position + Vector3.UP * 1.0, 0.8, col)
	return hs


## Senpō Ranton Kōga: iki elden sırayla çıkan mor-beyaz ışık hüzmeleri kavis çizip hedefe saplanır (yumuşak hüzme, çevresinde
## ince kırık kılıf); saplandığı yerde mor çakma
static func senpo_ranton_koga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.0)
	var purple = Color(0.75, 0.45, 1.0)
	crackle(pj, _hand_fn(pj, c, true), 0.5, 0.65, 4, purple, 0.035)
	crackle(pj, _hand_fn(pj, c, false), 0.5, 0.65, 4, purple, 0.035)
	for k in 4:
		pj.after(0.25 + k * 0.1, func():
			if not pj.live(c):
				return
			var a = pj.hand_pos(c, k % 2 == 0)
			var b = (tt.global_position + Vector3.UP if is_instance_valid(tt) else c.global_position + pj.fwd(c, t) * 26.0 + Vector3.UP)
			var side = (b - a).cross(Vector3.UP).normalized() * randf_range(-3.0, 3.0) + Vector3.UP * randf_range(0.0, 2.0)
			var pts = []
			for i in 13:
				var q = i / 12.0
				pts.append(a + (b - a) * q + side * sin(q * PI))
			beam(pj, pts, 0.16, 0.4, Color(0.9, 0.75, 1.0))
			beam(pj, pts, 0.42, 0.3, purple)
			bolt(pj, pts[6], b, 0.12, 0.25, 2, purple)
			flash(pj, a, 1.2, 0.18, purple)
			pj.after(0.12, func(): flash(pj, b, 2.2, 0.25, purple))
			_mhit(pj, c, b, 1.6, pj.inf(c, "senpo_ranton_koga", 0.45, {"knock": 4.0, "kind": "heavy", "element": "raiton"}), purple))
	Sfx.play("lightning", c.global_position, 1.3)


## Senrai no Senshu: elde beyaz sennin şimşeği toplanır (çevreden içe çakan şimşekler, avuçta parlayan küre); delici tek el
## darbesi — arkada ışık izi, ileri fırlayan mızrak şimşek, çarpışta çakma
static func senrai_no_senshu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 0.9)
	var white = Color(0.85, 0.95, 1.0)
	var hand = _hand_fn(pj, c, true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var core = orb_node(pj, 0.35, white)
		ba.add_child(core)
		pj.free_after(0.8, ba)
	crackle(pj, hand, 0.55, 0.8, 5, white, 0.035)
	for k in 4:
		pj.after(k * 0.08, func():
			if pj.live(c):
				var h = pj.hand_pos(c)
				bolt(pj, h + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.5), randf_range(-1.5, 1.5)), hand, 0.08, 0.15, 1, white, 0.25))
	pj.after(0.35, func():
		if not pj.live(c):
			return
		pj._jump_at(c, tt, 0.0, 9.0)
		var d = pj._face(c, tt)
		var at = c.global_position + Vector3.UP * 1.1 + d * 1.3
		beam(pj, [at - d * 3.0, at - d * 1.5, at], 0.22, 0.3, white)
		bolt(pj, at, at + d * 4.0, 0.3, 0.25, 3, white, 0.1, 0.04, 5)
		flash(pj, at + d * 0.5, 2.8, 0.22, white)
		_mhit(pj, c, at, 1.6, pj.inf(c, "senrai_no_senshu", 2.2, {"knock": 16.0, "kind": "heavy", "element": "raiton", "hitstop": 0.12, "stun": 0.8}), white)
		Sfx.play("chidori", at, 1.1))


## Senpō Daijarai: beden yeşil sennin çatırtısına bürünür; iki elden üç yılan biçimli yeşil şimşek kıvrılarak süzülür
## (titreyen kırık gövde, parlayan baş); hedefe varınca tepeden iner, yeşil yanık ve arklar kalır
static func senpo_daijarai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.2)
	var green = Color(0.45, 1.0, 0.75)
	crackle(pj, _follow_fn(c, Vector3.UP * 1.0), 1.25, 1.2, 8, green, 0.045)
	for k in 3:
		pj.after(0.35 + k * 0.15, func():
			if not pj.live(c):
				return
			var a = pj.hand_pos(c, k != 1)
			var b = (tt.global_position + Vector3.UP if is_instance_valid(tt) else c.global_position + pj.fwd(c, t) * 18.0 + Vector3.UP)
			var side = (b - a).cross(Vector3.UP).normalized()
			var ph = randf() * TAU
			var path = func(q: float) -> Vector3: return a.lerp(b, q) + side * sin(q * TAU * 1.5 + ph) * 1.4 * (1.0 - q * 0.6) + Vector3.UP * sin(q * PI) * 1.2
			snake_bolt(pj, path, 0.3, 0.12, green)
			pj.after(0.3, func():
				bolt(pj, b + Vector3.UP * 0.5, b, 0.18, 0.2, 3, green)
				bolt(pj, b + Vector3.UP * 4.0, b, 0.12, 0.2, 2, Color(0.9, 1.0, 0.95), 0.2)
				scorch(pj, pj.gp(b), 1.2, 2.4, green)
				ground_arcs(pj, pj.gp(b), 1.2, 1.0, 2, green)
				_mhit(pj, c, b, 1.8, pj.inf(c, "senpo_daijarai", 0.8, {"knock": 6.0, "kind": "heavy", "element": "raiton", "stun": 0.6}), green)))
	Sfx.play("lightning", c.global_position, 0.9)


## atanmamış shader parametresi null gelir (float(null) çöker)
static func _sp0(v) -> float:
	return 1.0 if v == null else float(v)
