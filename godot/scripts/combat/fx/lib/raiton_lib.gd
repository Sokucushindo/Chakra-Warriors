class_name RaitonLib
extends RefCounted
## Raiton (şimşek) doğasının ortak malzeme / şekil kütüphanesi. Hazır efekt yardımcısı kullanmaz: kendi gölgelendiricileri
## (şimşek şeridi: beyaza yakın öz + camgöbeği / elektrik mavisi parıltı, dişli cel çakma yıldızı, elektrikli plazma yüzey,
## parlayan çatlaklı yanık, yer ağı çizgisi, elektrik perdesi, toz halkası) ve kendi geometrisi (orta nokta kırılımlı, dallanan,
## birkaç karede bir yeniden kırılan şimşek; keskin manga zikzakı; kıvılcım çizgileri; el / gövde çatırtısı; yerde sürünen ark).
## Yalnız yapı taşı verir; her tekniğin kompozisyonu kendi grup dosyasındadır.

const RAI := Color(0.65, 0.85, 1.0)
const CYAN := Color(0.3, 0.66, 1.0)
const EMAG := Color(0.55, 0.8, 1.0)
const GOLD := Color(1.0, 0.84, 0.32)
const PALE := Color(0.9, 0.95, 1.0)

static var _sh := {}
static var _mc := {}


# ═════════════════════════════════════════ gölgelendiriciler ═════════════════════════════════════════

const SH_NOISE := """
float rh2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.231); }
float rn2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rh2(i), rh2(i + vec2(1.0, 0.0)), f.x), mix(rh2(i + vec2(0.0, 1.0)), rh2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float rh3(vec3 p) { return fract(sin(dot(p, vec3(41.3, 289.1, 97.7))) * 45758.231); }
float rn3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(rh3(i), rh3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(rh3(i + vec3(0.0, 1.0, 0.0)), rh3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(rh3(i + vec3(0.0, 0.0, 1.0)), rh3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(rh3(i + vec3(0.0, 1.0, 1.0)), rh3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
"""

## Şimşek şeridi: ortada beyaza yakın keskin öz, dışa doğru renkli parıltı; parça parça kırpışır (toplamalı)
const SH_ARC := """
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float thin = 0.24;
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	float k = 1.0 - smoothstep(thin * 0.45, thin, e);
	float g = pow(clamp(1.0 - e, 0.0, 1.0), 2.6);
	float fl = 0.7 + 0.3 * step(0.45, rh2(vec2(floor(UV.x * 3.0), floor(TIME * 28.0))));
	ALBEDO = (glow.rgb * g * 1.7 + hot.rgb * k * 2.3) * fl;
	ALPHA = clamp(max(k, g * 0.85), 0.0, 1.0) * COLOR.a;
}
"""

## Çakma yıldızı: kameraya dönük, düzensiz uzunlukta sivri dişli cel yıldız; içi beyaz, dış bandı renkli (karışık)
const SH_STAR := """
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
uniform float power = 1.0;
uniform float spikes = 9.0;
uniform float sd = 0.0;
float sh1(float x) { return fract(sin(x * 12.9898 + sd * 3.71) * 43758.5453); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = (atan(p.y, p.x) + 3.14159265) / 6.2831853 * spikes;
	float i = floor(a);
	float f = fract(a);
	float tip = mix(0.5, 1.0, sh1(i));
	float tri = 1.0 - abs(f - 0.5) * 2.0;
	float edge = mix(0.26 + 0.08 * sh1(i + 7.0), tip, pow(tri, 2.2));
	if (r > edge) { discard; }
	float band = step(edge * 0.66, r);
	vec3 col = mix(vec3(1.0), clamp(glow.rgb, vec3(0.0), vec3(1.0)), band);
	ALBEDO = col;
	ALPHA = power * mix(1.0, 0.8, band);
}
"""

## Elektrik plazması (küre, tazı, yılan başı): iç beyaz, orta renk, kenar bandı; içinde birkaç karede bir yer değiştiren
## beyaz damarlar (cel bantlı, yarı saydam)
const SH_PLASMA := """
uniform vec4 inner : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
uniform vec4 edge_col : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float power = 1.0;
uniform float vein_amt = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 15.0);
	float n = rn3(lp * 4.5 + vec3(st * 0.31, st * 0.67, -st * 0.43));
	float vein = (1.0 - smoothstep(0.0, 0.05, abs(n - 0.5))) * vein_amt;
	vec3 col = inner.rgb;
	col = mix(col, glow.rgb * 1.2, step(0.42, fr));
	col = mix(col, edge_col.rgb * 1.3, step(0.8, fr));
	col = mix(col, vec3(1.0), vein);
	ALBEDO = col * 1.25;
	ALPHA = clamp(mix(0.92, 0.65, step(0.8, fr)) + vein * 0.3, 0.0, 1.0) * power;
}
"""

## Yanık: düzensiz kömür lekesi + gürültü eş-yükselti çizgilerinden örümceksi çatlaklar; heat ile çatlaklar parlak yanar
const SH_SCORCH := """
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
uniform float heat = 1.0;
uniform float fade = 1.0;
uniform float sd = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float border = 0.68 + 0.3 * rn2(vec2(cos(ang), sin(ang)) * 2.4 + vec2(sd, sd * 0.7));
	if (r > border) { discard; }
	float blot = 1.0 - smoothstep(border * 0.3, border, r);
	float c1 = abs(rn2(p * 3.6 + vec2(sd * 1.3, 2.0)) - 0.5);
	float c2 = abs(rn2(p * 8.5 - vec2(1.0, sd)) - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.03, c1)) + (1.0 - smoothstep(0.0, 0.022, c2)) * 0.7 * step(r, border * 0.65);
	crack = clamp(crack, 0.0, 1.0) * (1.0 - smoothstep(border * 0.55, border * 0.97, r));
	float hv = crack * heat;
	vec3 col = mix(vec3(0.05, 0.05, 0.07), glow.rgb * 1.8 + vec3(0.35), step(0.3, hv));
	ALBEDO = col;
	ALPHA = clamp(max(blot * 0.55 * (0.6 + 0.4 * rn2(p * 7.0)), step(0.3, hv)), 0.0, 1.0) * fade;
}
"""

## Yere çizilen ağ çizgisi (karışık, parlak zeminde de seçilir): ince camgöbeği-beyaz öz, geniş mavi hâle, parça parça
## kırpışma, çizgi boyunca dışa koşan beyaz akım nabızları
const SH_WEB := """
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	float k = 1.0 - smoothstep(0.16, 0.3, e);
	float halo = 1.0 - smoothstep(0.25, 1.0, e);
	float fl = step(0.3, rh2(vec2(floor(UV.x * 1.4), floor(TIME * 22.0))));
	float pul = pow(fract(UV.x * 0.22 - TIME * 1.7), 6.0);
	vec3 corec = mix(vec3(0.72, 0.94, 1.0), vec3(1.0), pul);
	vec3 haloc = clamp(glow.rgb * vec3(0.45, 0.75, 1.15), vec3(0.0), vec3(1.0));
	vec3 col = mix(haloc, corec, k);
	float a = max(k * (0.7 + 0.3 * fl), halo * (0.3 + 0.4 * pul) * (0.55 + 0.45 * fl));
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * COLOR.a;
}
"""

## Elektrik perdesi (bağlama kafesi): saydam mavi yüzey, içinde birkaç karede bir yer değiştiren beyaz damarlar,
## yukarı kayan tarama çizgileri, parlak kenarlar
const SH_SHEET := """
uniform vec4 glow : source_color = vec4(0.3, 0.66, 1.0, 1.0);
uniform float power = 1.0;
void fragment() {
	vec2 uv = UV;
	float side = smoothstep(0.92, 1.0, abs(uv.x - 0.5) * 2.0);
	float top = smoothstep(0.95, 1.0, 1.0 - uv.y) + smoothstep(0.95, 1.0, uv.y) * 0.6;
	float st = floor(TIME * 12.0);
	float n = rn2(vec2(uv.x * 5.0, uv.y * 3.0) + vec2(st * 0.37, st * 0.53));
	float line = 1.0 - smoothstep(0.0, 0.025, abs(n - 0.5));
	float scan = step(0.965, fract(uv.y * 4.0 + TIME * 1.3));
	vec3 col = glow.rgb * 0.5 + vec3(1.0) * line * 0.9 + glow.rgb * scan * 0.7 + vec3(0.85) * max(side, top);
	ALBEDO = col;
	ALPHA = clamp(0.22 + line * 0.55 + max(side, top) * 0.6 + scan * 0.18, 0.0, 1.0) * power;
}
"""

## Toz halkası: yere yatık, kenarı yumuşak cel toz şeridi (karışık, toplamalı değil)
const SH_DUST := """
uniform vec4 tint : source_color = vec4(0.62, 0.56, 0.47, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	float m = 1.0 - smoothstep(0.55, 1.0, e);
	float b = step(0.45, rn2(vec2(UV.x * 1.5, UV.y * 4.0)));
	ALBEDO = mix(tint.rgb * 0.82, tint.rgb * 1.08, b);
	ALPHA = m * COLOR.a * 0.8;
}
"""

## Kara şimşek (Kuroi Kaminari): opak siyah gövde, kenarında ince beyaz çizgi, içinde birkaç karede bir yer değiştiren
## beyaz damarlar (kaynak: Darui; siyah şerit + beyaz kontur, karışık — toplamalı değil)
const SH_DARK := """
uniform vec4 edge_col : source_color = vec4(0.9, 0.92, 1.0, 1.0);
uniform vec4 body_col : source_color = vec4(0.04, 0.035, 0.07, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	if (e > 0.97) { discard; }
	float st = floor(TIME * 16.0);
	float rim = smoothstep(0.66, 0.8, e);
	float n = rn2(vec2(UV.x * 1.8 + st * 0.37, UV.y * 2.6 + st * 0.71));
	float vein = (1.0 - smoothstep(0.0, 0.05, abs(n - 0.5))) * step(e, 0.62);
	float m = max(rim, vein);
	ALBEDO = mix(body_col.rgb, edge_col.rgb * 1.3, m);
	ALPHA = clamp(0.96 * COLOR.a, 0.0, 1.0);
}
"""

## Opak plazma gövde (tazı / yılan başı): cel bantlı (beyaz öz, açık mavi, koyu mavi kenar), içinde çakan beyaz damarlar;
## parlak sahnede de okunur
const SH_SOLID := """
uniform vec4 inner : source_color = vec4(0.9, 0.96, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform vec4 edge_col : source_color = vec4(0.22, 0.48, 0.95, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 15.0);
	float n = rn3(lp * 4.5 + vec3(st * 0.31, st * 0.67, -st * 0.43));
	float vein = 1.0 - smoothstep(0.0, 0.045, abs(n - 0.5));
	vec3 col = inner.rgb;
	col = mix(col, glow.rgb, step(0.45, fr));
	col = mix(col, edge_col.rgb, step(0.78, fr));
	col = mix(col, vec3(1.0), vein * step(fr, 0.78));
	ALBEDO = col;
}
"""

## Dış çizgi (ters kabuk, material_overlay): normaller boyunca şişirilmiş arka yüz, düz koyu renk -> net siluet
const SH_LINE := """
uniform vec4 line_col : source_color = vec4(0.04, 0.1, 0.28, 1.0);
uniform float thick = 0.035;
void vertex() { VERTEX += NORMAL * thick; }
void fragment() { ALBEDO = line_col.rgb; }
"""

## Opak cel şerit (yılan gövdesi): iç açık, orta renk, kenarda koyu çizgi; içinde çakan beyaz damarlar
const SH_BAND := """
uniform vec4 inner : source_color = vec4(1.0, 1.0, 0.92, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.84, 0.32, 1.0);
uniform vec4 line_col : source_color = vec4(0.45, 0.22, 0.04, 1.0);
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	if (e > 0.98) { discard; }
	vec3 col = mix(inner.rgb, glow.rgb, step(0.42, e));
	col = mix(col, line_col.rgb, step(0.8, e));
	float st = floor(TIME * 14.0);
	float vein = (1.0 - smoothstep(0.0, 0.05, abs(rn2(vec2(UV.x * 1.2 + st * 0.37, UV.y * 2.0 + st * 0.71)) - 0.5))) * step(e, 0.7);
	col = mix(col, vec3(1.0), vein);
	ALBEDO = col;
	ALPHA = COLOR.a;
}
"""

const RENDER := {
	"arc": "render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;",
	"star": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"plasma": "render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;",
	"scorch": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"web": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"solid": "render_mode unshaded, cull_back, shadows_disabled;",
	"line": "render_mode unshaded, cull_front, shadows_disabled;",
	"band": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"sheet": "render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;",
	"dust": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"dark": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
}


static func shader(key: String) -> Shader:
	if _sh.has(key):
		return _sh[key]
	var body := ""
	match key:
		"arc":
			body = SH_ARC
		"star":
			body = SH_STAR
		"plasma":
			body = SH_PLASMA
		"scorch":
			body = SH_SCORCH
		"web":
			body = SH_WEB
		"solid":
			body = SH_SOLID
		"line":
			body = SH_LINE
		"band":
			body = SH_BAND
		"sheet":
			body = SH_SHEET
		"dust":
			body = SH_DUST
		"dark":
			body = SH_DARK
	var s = Shader.new()
	s.code = "shader_type spatial;\n" + String(RENDER[key]) + "\n" + SH_NOISE + "\n" + body
	_sh[key] = s
	return s


static func mat(key: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = shader(key)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Renge göre paylaşılan şimşek şeridi malzemesi
static func arc_mat(col: Color) -> ShaderMaterial:
	var key = "arc_" + col.to_html()
	if not _mc.has(key):
		_mc[key] = mat("arc", {"glow": col})
	return _mc[key]


static func web_mat(col: Color) -> ShaderMaterial:
	var key = "web_" + col.to_html()
	if not _mc.has(key):
		_mc[key] = mat("web", {"glow": col})
	return _mc[key]


static func dust_mat(col: Color) -> ShaderMaterial:
	var key = "dust_" + col.to_html()
	if not _mc.has(key):
		_mc[key] = mat("dust", {"tint": col})
	return _mc[key]


## Kara şimşek malzemesi (paylaşılan)
static func dark_mat(edge := PALE) -> ShaderMaterial:
	var key = "dark_" + edge.to_html()
	if not _mc.has(key):
		_mc[key] = mat("dark", {"edge_col": edge})
	return _mc[key]


## Opak plazma gövde malzemesi
static func solid_mat(inner: Color, glow: Color, rim: Color) -> ShaderMaterial:
	var key = "solid_" + inner.to_html() + glow.to_html() + rim.to_html()
	if not _mc.has(key):
		_mc[key] = mat("solid", {"inner": inner, "glow": glow, "edge_col": rim})
	return _mc[key]


## Dış çizgi malzemesi (MeshInstance3D.material_overlay olarak)
static func line_mat(col: Color, thick := 0.035) -> ShaderMaterial:
	var key = "line_" + col.to_html() + str(thick)
	if not _mc.has(key):
		_mc[key] = mat("line", {"line_col": col, "thick": thick})
	return _mc[key]


## Opak cel şerit malzemesi
static func band_mat(inner: Color, glow: Color, line: Color) -> ShaderMaterial:
	var key = "band_" + inner.to_html() + glow.to_html() + line.to_html()
	if not _mc.has(key):
		_mc[key] = mat("band", {"inner": inner, "glow": glow, "line_col": line})
	return _mc[key]


## Plazma malzemesi (her çağrıda yeni: power tween'lenebilir)
static func plasma_mat(inner: Color, glow: Color, rim: Color, power := 1.0) -> ShaderMaterial:
	return mat("plasma", {"inner": inner, "glow": glow, "edge_col": rim, "power": power})


# ═════════════════════════════════════════ altyapı ═════════════════════════════════════════

## Her karede fn(node, dt, age) çağıran düğüm; fn false dönünce silinir
class Pulse extends Node3D:
	var fn := Callable()
	var age := 0.0

	func _process(dt: float) -> void:
		age += dt
		if not fn.is_valid() or not fn.call(self, dt, age):
			queue_free()


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func root() -> Node:
	return tree().current_scene


static func cam_pos() -> Vector3:
	var vp = root().get_viewport()
	var cam = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3(0, 60, 0)


static func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func rdir() -> Vector3:
	var v = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length_squared() > 0.0001 else Vector3.UP


static func hdir() -> Vector3:
	var a = randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))


static func perp(v: Vector3) -> Vector3:
	var d = v.normalized()
	var r = rdir()
	var p = r - d * r.dot(d)
	return p.normalized() if p.length_squared() > 0.000001 else Vector3.UP


## Sabit nokta ya da Callable
static func pt(x) -> Vector3:
	return x.call() if x is Callable else x


## Düğümü izleyen nokta (düğüm silinirse son konum)
static func follow_fn(n: Node3D, off := Vector3.ZERO) -> Callable:
	var w = weakref(n)
	var mem = {"p": n.global_position + off}
	return func() -> Vector3:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			mem["p"] = x.global_position + off
		return mem["p"]


## Atanın görünen eli
static func hand_fn(pj: PathJutsu, c: Node3D, right := true) -> Callable:
	var w = weakref(c)
	var mem = {"p": pj.hand_pos(c, right)}
	return func() -> Vector3:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			mem["p"] = pj.live_hand(x, right)
		return mem["p"]


static func alive(n) -> bool:
	return n != null and is_instance_valid(n) and n.is_inside_tree()


static func pulse(pos: Vector3, fn: Callable, parent: Node = null) -> Pulse:
	var p = Pulse.new()
	p.fn = fn
	if parent != null and is_instance_valid(parent):
		parent.add_child(p)
		p.position = pos
	else:
		root().add_child(p)
		p.global_position = pos
	return p


## Dünya koordinatında her kare yeniden çizilen taşıyıcı: fn(im, node, dt, age) -> bool
static func host(fn: Callable) -> Pulse:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 80.0
	var p = pulse(Vector3.ZERO, func(node, dt, age) -> bool:
		im.clear_surfaces()
		return fn.call(im, node, dt, age))
	p.add_child(mi)
	return p


static func mi_of(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if m:
		mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func sphere_mesh() -> SphereMesh:
	if not _mc.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 20
		s.rings = 10
		_mc["sphere"] = s
	return _mc["sphere"]


static func quad_mesh() -> QuadMesh:
	if not _mc.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_mc["quad"] = q
	return _mc["quad"]


static func plane_mesh() -> PlaneMesh:
	if not _mc.has("plane"):
		var q = PlaneMesh.new()
		q.size = Vector2(1.0, 1.0)
		_mc["plane"] = q
	return _mc["plane"]


# ═════════════════════════════════════════ şerit çizimi ═════════════════════════════════════════

static func _vx(im: ImmediateMesh, p: Vector3, u: float, v: float, a: float) -> void:
	im.surface_set_color(Color(1, 1, 1, a))
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(p)


## Çoklu çizgiyi tek yüzeyde çizer. polys: [{"p": [Vector3], "w": yarı genişlik, "a": saydamlık, "k": 0 iki uç incelir /
## 1 baştan uca kalınlaşır (kuyruk) / 2 sabit}]. flat: yere yatık (yan yön yatay), değilse kameraya dönük. U = dünya uzunluğu.
static func draw(im: ImmediateMesh, m: Material, polys: Array, amul: float, cam: Vector3, flat := false) -> void:
	var any = false
	for pl in polys:
		if (pl["p"] as Array).size() >= 2 and float(pl["a"]) * amul > 0.002:
			any = true
			break
	if not any:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, m)
	for pl in polys:
		var pts: Array = pl["p"]
		var n = pts.size()
		if n < 2:
			continue
		var al = float(pl["a"]) * amul
		if al <= 0.002:
			continue
		var w0 = float(pl["w"])
		var kind = int(pl.get("k", 0))
		var ls = []
		var rs = []
		var us = []
		var acc = 0.0
		for i in n:
			var p: Vector3 = pts[i]
			if i > 0:
				acc += p.distance_to(pts[i - 1])
			us.append(acc)
			var tn: Vector3 = Vector3(pts[mini(i + 1, n - 1)]) - Vector3(pts[maxi(i - 1, 0)])
			var sd: Vector3 = tn.cross(Vector3.UP) if flat else tn.cross(cam - p)
			if sd.length_squared() < 0.000000001:
				sd = Vector3.RIGHT
			var f = float(i) / float(n - 1)
			var w = w0
			if kind == 0:
				w = w0 * (0.3 + 0.7 * sin(PI * (0.05 + 0.9 * f)))
			elif kind == 1:
				w = w0 * (0.15 + 0.85 * f)
			elif kind == 3:
				w = w0 * (0.08 + 0.92 * sin(PI * f))
			sd = sd.normalized() * w
			ls.append(p + sd)
			rs.append(p - sd)
		for i in n - 1:
			var u0 = float(us[i])
			var u1 = float(us[i + 1])
			_vx(im, ls[i], u0, 0.0, al)
			_vx(im, rs[i], u0, 1.0, al)
			_vx(im, ls[i + 1], u1, 0.0, al)
			_vx(im, ls[i + 1], u1, 0.0, al)
			_vx(im, rs[i], u0, 1.0, al)
			_vx(im, rs[i + 1], u1, 1.0, al)
	im.surface_end()


# ═════════════════════════════════════════ şimşek geometrisi ═════════════════════════════════════════

## Orta nokta kırılımı: her turda parçalar ikiye bölünür, orta nokta dik yönde rastgele itilir, genlik azalır
static func jag(a: Vector3, b: Vector3, rough: float, depth: int, horizontal := false) -> Array:
	var pts = [a, b]
	var amp = a.distance_to(b) * rough
	for k in depth:
		var np = [pts[0]]
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			var side: Vector3
			if horizontal:
				side = (p1 - p0).cross(Vector3.UP)
				side = side.normalized() if side.length_squared() > 0.000001 else Vector3.RIGHT
			else:
				side = perp(p1 - p0)
			np.append((p0 + p1) * 0.5 + side * randf_range(-amp, amp))
			np.append(p1)
		pts = np
		amp *= 0.55
	return pts


## Ana şimşek + çatallar (çatal ana yoldan ayrılır, kısalır, incelir, bir kez daha çatallanabilir)
static func fork(a: Vector3, b: Vector3, rough: float, depth: int, branches: int, out: Array, w: float, al: float) -> void:
	var main = jag(a, b, rough, maxi(depth, 1))
	out.append({"p": main, "w": w, "a": al})
	if branches <= 0 or main.size() < 3:
		return
	var d = b - a
	var L = d.length()
	if L < 0.05:
		return
	d /= L
	for q in branches:
		var i = randi_range(1, main.size() - 2)
		var s: Vector3 = main[i]
		var e = s + (d + perp(d) * randf_range(0.5, 1.4)).normalized() * L * randf_range(0.15, 0.4)
		fork(s, e, rough * 1.15, maxi(depth - 1, 1), int(branches * 0.5), out, w * 0.5, al * 0.8)


## Keskin manga zikzakı: düz parçalı, sert köşeli (fraktal değil)
static func zigzag(a: Vector3, b: Vector3, n: int, amp: float) -> Array:
	var d = b - a
	var side = perp(d)
	var pts = [a]
	for i in range(1, n):
		var f = float(i) / float(n)
		var s = amp * (1.0 if i % 2 == 0 else -1.0) * randf_range(0.6, 1.2)
		pts.append(a + d * f + side * s)
	pts.append(b)
	return pts


## Yerde sürünen yol: yatay kırılım, her nokta zemine oturur
static func ground_path(a: Vector3, b: Vector3, rough: float, depth: int, lift := 0.06) -> Array:
	var pts = jag(a, b, rough, depth, true)
	for i in pts.size():
		var p: Vector3 = pts[i]
		pts[i] = Vector3(p.x, Game.jutsu_floor(p.x, p.z) + lift, p.z)
	return pts


# ═════════════════════════════════════════ yapı taşları ═════════════════════════════════════════

## Şimşek: a → b (sabit ya da Callable uçlar), her regen sn'de yeniden kırılır; ömür boyunca söner
static func bolt(a, b, col := RAI, w := 0.1, life := 0.25, branches := 2, rough := 0.18, regen := 0.05, depth := 4) -> Pulse:
	var m = arc_mat(col)
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + regen
			var out = []
			fork(pt(a), pt(b), rough, depth, branches, out, w, 1.0)
			stt["polys"] = out
		var al = pow(1.0 - age / life, 0.7) * randf_range(0.6, 1.0)
		draw(im, m, stt["polys"], al, cam_pos())
		return true)


## bolt ile aynı, ama verilen malzemeyle (ör. dark_mat: kara şimşek)
static func bolt_m(a, b, m: Material, w := 0.1, life := 0.25, branches := 2, rough := 0.18, regen := 0.05, depth := 4) -> Pulse:
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + regen
			var out = []
			fork(pt(a), pt(b), rough, depth, branches, out, w, 1.0)
			stt["polys"] = out
		draw(im, m, stt["polys"], clampf((life - age) / (life * 0.4), 0.0, 1.0), cam_pos())
		return true)


## Keskin zikzak şimşek: düz parçalı, sert köşeli ana tel + ince ikiz tel; regen'de yeniden kırılır, uçları sivri
static func zig_bolt(a, b, col := RAI, w := 0.07, life := 0.3, n := 6, amp := 0.4, regen := 0.06) -> Pulse:
	var m = arc_mat(col)
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		if age > life:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + regen
			var pa = pt(a)
			var pb = pt(b)
			var main = zigzag(pa, pb, n, amp)
			var twin = []
			for q in main:
				twin.append(Vector3(q) + rdir() * amp * 0.25)
			stt["polys"] = [{"p": main, "w": w, "a": 1.0, "k": 3}, {"p": twin, "w": w * 0.4, "a": 0.7, "k": 3}]
		draw(im, m, stt["polys"], pow(1.0 - age / life, 0.6), cam_pos())
		return true)


## Çatırtı: merkez çevresinde kısa, kesik kesik çakıp sönen arklar (el, küre, gövde). bind verilirse o düğüm yok olunca biter
static func crackle(center, radius: float, dur: float, col := RAI, count := 4, w := 0.035, regen := 0.06, bind: Node = null) -> Pulse:
	var m = arc_mat(col)
	var has_bind = bind != null
	var bw = weakref(bind) if has_bind else null
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if has_bind:
			var b = bw.get_ref()
			if b == null or not is_instance_valid(b):
				return false
		var c0 = pt(center)
		if age >= float(stt["next"]):
			stt["next"] = age + regen * randf_range(0.7, 1.4)
			var out = []
			for k in count:
				if randf() < 0.3:
					continue   # cıvıltı: her karede hepsi yanmaz
				var s = c0 + rdir() * radius * randf_range(0.35, 1.0)
				var e = s + (perp(s - c0) + rdir() * 0.4).normalized() * radius * randf_range(0.5, 1.1)
				fork(s, e, 0.3, 3, 1 if randf() < 0.4 else 0, out, w, randf_range(0.6, 1.0))
			stt["polys"] = out
		var fade = clampf((dur - age) / 0.12, 0.0, 1.0)
		draw(im, m, stt["polys"], fade, cam_pos())
		return true)


## Gövde arkları: hedefin kapsülü üzerinde sürünen kısa şimşekler (felç / yanık hissi)
static func body_arcs(t: Node3D, dur: float, col := RAI, count := 4, w := 0.04) -> Pulse:
	if not alive(t):
		return null
	var m = arc_mat(col)
	var tw = weakref(t)
	var hgt = float(t.get("height")) if t.get("height") != null else 1.8
	var rad = float(t.get("radius")) if t.get("radius") != null else 0.45
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		var tt = tw.get_ref()
		if age > dur or tt == null or not is_instance_valid(tt) or not tt.is_inside_tree():
			return false
		var base: Vector3 = tt.global_position
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var out = []
			for k in count:
				var a0 = randf() * TAU
				var y0 = randf_range(0.1, hgt)
				var a1 = a0 + randf_range(0.8, 2.0) * (1.0 if randf() < 0.5 else -1.0)
				var y1 = clampf(y0 + randf_range(-0.7, 0.7), 0.05, hgt + 0.1)
				var r0 = rad * randf_range(1.0, 1.3)
				var s = base + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
				var e = base + Vector3(cos(a1) * r0, y1, sin(a1) * r0)
				fork(s, e, 0.25, 3, 1 if randf() < 0.3 else 0, out, w, randf_range(0.6, 1.0))
			stt["polys"] = out
		draw(im, m, stt["polys"], clampf((dur - age) / 0.1, 0.0, 1.0), cam_pos())
		return true)


## Çakma yıldızı (dişli cel yıldız): hızla büyür, söner
static func flash(pos: Vector3, size: float, col := RAI, life := 0.15, spikes := 9.0, parent: Node3D = null) -> MeshInstance3D:
	var m = mat("star", {"glow": col, "power": 1.0, "spikes": spikes, "sd": randf() * 100.0})
	var mi = mi_of(quad_mesh(), m)
	if parent != null and is_instance_valid(parent):
		parent.add_child(mi)
		mi.position = pos
	else:
		root().add_child(mi)
		mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.35
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/power", 0.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Anlık ışık
static func light(pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	root().add_child(l)
	l.global_position = pos
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Kıvılcım çizgileri: hızla saçılır, yerçekimiyle eğilir, söner. dir sıfırsa her yöne
static func sparks(pos: Vector3, n: int, col := RAI, speed := 10.0, life := 0.4, dir := Vector3.ZERO, spread := 1.0, w := 0.022) -> Pulse:
	var m = arc_mat(col)
	var ps = []
	for i in n:
		var v: Vector3
		if dir.length_squared() < 0.0001:
			v = rdir()
		else:
			v = (dir.normalized() + rdir() * spread).normalized()
		ps.append({"p": pos, "v": v * speed * randf_range(0.4, 1.0), "l": life * randf_range(0.5, 1.0)})
	return host(func(im, _n, dt, age) -> bool:
		if age > life:
			return false
		var polys = []
		for s in ps:
			if age > float(s["l"]):
				continue
			var v: Vector3 = s["v"]
			v = v * maxf(0.0, 1.0 - 3.0 * dt) + Vector3.DOWN * 9.0 * dt
			s["v"] = v
			s["p"] = Vector3(s["p"]) + v * dt
			var p: Vector3 = s["p"]
			polys.append({"p": [p - v * 0.035, p], "w": w, "a": 1.0 - age / float(s["l"]), "k": 2})
		draw(im, m, polys, 1.0, cam_pos())
		return true)


## Toplanma: kıvılcım çizgileri çevreden merkeze (el) çekilir
static func converge(center, radius: float, dur: float, col := RAI, n := 10, w := 0.025) -> Pulse:
	var m = arc_mat(col)
	var ps = []
	for i in n:
		ps.append({"d": rdir(), "r": radius * randf_range(0.6, 1.0), "o": randf_range(0.0, dur * 0.4)})
	return host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var c0 = pt(center)
		var polys = []
		for s in ps:
			var f = clampf((age - float(s["o"])) / maxf(dur - float(s["o"]), 0.01), 0.0, 1.0)
			if f <= 0.0 or f >= 1.0:
				continue
			var r = float(s["r"]) * (1.0 - f * f)
			var d: Vector3 = s["d"]
			var p = c0 + d * r
			polys.append({"p": [p + d * (0.15 + r * 0.25), p], "w": w, "a": 0.4 + f * 0.6, "k": 1})
		draw(im, m, polys, 1.0, cam_pos())
		return true)


## Yanık izi: kömür leke + parlak çatlaklar; heat_t'de soğur, life sonunda silinir
static func scorch(g: Vector3, r: float, col := RAI, life := 5.0, heat_t := 1.0) -> MeshInstance3D:
	var m = mat("scorch", {"glow": col, "heat": 1.0, "fade": 1.0, "sd": randf() * 50.0})
	var mi = mi_of(plane_mesh(), m)
	root().add_child(mi)
	mi.global_position = g + Vector3.UP * 0.04
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	var tw = mi.create_tween()
	tw.tween_property(m, "shader_parameter/heat", 0.0, heat_t)
	tw.tween_interval(maxf(life - heat_t - 1.0, 0.1))
	tw.tween_property(m, "shader_parameter/fade", 0.0, 1.0)
	tw.tween_callback(mi.queue_free)
	return mi


## Yerde sürünen arklar: merkez çevresinde zemine yapışık kısa şimşekler
static func ground_arcs(center: Vector3, r: float, dur: float, col := RAI, count := 5, w := 0.045, regen := 0.07) -> Pulse:
	var m = arc_mat(col)
	var stt = {"next": 0.0, "polys": []}
	return host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + regen * randf_range(0.7, 1.4)
			var out = []
			for k in count:
				if randf() < 0.35:
					continue
				var s = center + hdir() * r * sqrt(randf())
				var e = s + hdir() * randf_range(0.6, 1.6)
				out.append({"p": ground_path(s, e, 0.3, 3), "w": w, "a": randf_range(0.5, 1.0)})
			stt["polys"] = out
		draw(im, m, stt["polys"], clampf((dur - age) / 0.3, 0.0, 1.0), cam_pos(), true)
		return true)


## İz: düğümün geçtiği yolda kısa süre kalan, titreyen şimşek kuyruğu. bind düğümü yok olunca kuyruk söner
static func trail(n: Node3D, col := RAI, w := 0.15, keep := 0.22, jit := 0.08) -> Pulse:
	var m = arc_mat(col)
	var nw = weakref(n)
	var pts = []
	var stt = {"gone": -1.0, "jt": 0.0, "off": []}
	return host(func(im, _n, _dt, age) -> bool:
		var x = nw.get_ref()
		var live = x != null and is_instance_valid(x) and x.is_inside_tree()
		if live:
			pts.append({"p": x.global_position, "t": age})
		elif float(stt["gone"]) < 0.0:
			stt["gone"] = age
		while pts.size() > 0 and age - float(pts[0]["t"]) > keep:
			pts.pop_front()
		if not live and (pts.size() < 2 or age - float(stt["gone"]) > keep):
			return false
		if pts.size() < 2:
			return true
		if age >= float(stt["jt"]):
			stt["jt"] = age + 0.04
			var off = []
			for i in 24:
				off.append(rdir() * jit)
			stt["off"] = off
		var line = []
		var offs: Array = stt["off"]
		for i in pts.size():
			var p: Vector3 = pts[i]["p"]
			line.append(p + Vector3(offs[i % offs.size()]) * (float(i) / pts.size()))
		draw(im, m, [{"p": line, "w": w, "a": 1.0, "k": 1}], 1.0, cam_pos())
		return true)


## Plazma küre (kendi titremesiyle)
static func orb(r: float, inner: Color, glow: Color, rim: Color) -> Node3D:
	var root_n = Node3D.new()
	var mi = mi_of(sphere_mesh(), plasma_mat(inner, glow, rim))
	mi.scale = Vector3.ONE * r * 2.0
	root_n.add_child(mi)
	var stt = {"next": 0.0}
	var p = Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(mi):
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.045
			mi.scale = Vector3(randf_range(0.92, 1.08), randf_range(0.92, 1.08), randf_range(0.92, 1.08)) * r * 2.0
		return true
	root_n.add_child(p)
	return root_n


## Elde şimşek yükü: sağ el kemiğine küçük plazma çekirdek + çevresinde çatırtı; dur sonunda söner
static func hand_charge(pj: PathJutsu, c: Node3D, dur: float, col := RAI, s := 1.0) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		crackle(hand_fn(pj, c), 0.35 * s, dur, col, 4, 0.03)
		return
	var o = orb(0.09 * s, Color(1, 1, 1), col, col.lightened(0.3))
	ba.add_child(o)
	crackle(follow_fn(ba), 0.32 * s, dur, col, 4, 0.03 * s, 0.05, ba)
	pj.free_after(dur, ba)


## Hız çizgileri: atanın çevresinde geriye uzanan ince düz çizgiler (atanı izler)
static func speed_lines(c: Node3D, dir: Vector3, dur: float, col := PALE, n := 9) -> Pulse:
	var m = arc_mat(col)
	var cw = weakref(c)
	var d = Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	var side = d.cross(Vector3.UP).normalized()
	return host(func(im, _n, _dt, age) -> bool:
		var x = cw.get_ref()
		if age > dur or x == null or not is_instance_valid(x):
			return false
		var base: Vector3 = x.global_position
		var polys = []
		for i in n:
			var p = base + side * randf_range(-0.9, 0.9) + Vector3.UP * randf_range(0.2, 2.0) + d * randf_range(-0.4, 0.6)
			polys.append({"p": [p - d * randf_range(1.2, 2.6), p], "w": 0.018, "a": randf_range(0.4, 1.0), "k": 1})
		draw(im, m, polys, 1.0 - age / dur, cam_pos())
		return true)


## Toz halkası: zeminde dışa açılan, kenarı düzensiz toz şeridi (duman bulutu değil)
static func dust_ring(g: Vector3, r0: float, r1: float, dur: float, col := Color(0.62, 0.56, 0.47)) -> Pulse:
	var m = dust_mat(col)
	var nseg = 40
	var wob = []
	for i in nseg + 1:
		wob.append(randf_range(0.85, 1.15))
	wob[nseg] = wob[0]
	return host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = age / dur
		var r = lerpf(r0, r1, 1.0 - pow(1.0 - f, 3.0))
		var line = []
		for i in nseg + 1:
			var a = TAU * i / nseg
			var q = g + Vector3(cos(a), 0, sin(a)) * r * float(wob[i])
			line.append(Vector3(q.x, Game.jutsu_floor(q.x, q.z) + 0.15 + f * 0.3, q.z))
		draw(im, m, [{"p": line, "w": 0.25 + f * 0.6, "a": 1.0 - f, "k": 2}], 1.0, cam_pos(), true)
		return true)


## Kaya kırıntıları: zeminden fırlar, yere düşer, söner
static func debris(g: Vector3, n: int, speed := 6.0, col := Color(0.42, 0.38, 0.33), dir := Vector3.ZERO) -> void:
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.14, 0.1, 0.12), col)
	var mesh = b.build(Props.toon())
	for i in n:
		var mi = mi_of(mesh, null)
		root().add_child(mi)
		mi.global_position = g + Vector3.UP * 0.15
		mi.scale = Vector3.ONE * randf_range(0.6, 1.6)
		var v = (Vector3.UP * randf_range(0.8, 1.6) + hdir() * randf_range(0.3, 1.0) + dir).normalized() * speed * randf_range(0.5, 1.0)
		var spin = rdir() * randf_range(4.0, 12.0)
		var stt = {"v": v}
		var p = Pulse.new()
		p.fn = func(_node, dt, age) -> bool:
			if not is_instance_valid(mi):
				return false
			if age > 1.6:
				mi.queue_free()
				return false
			var vv: Vector3 = stt["v"]
			vv.y -= 16.0 * dt
			var np = mi.global_position + vv * dt
			var fl = Game.jutsu_floor(np.x, np.z)
			if np.y < fl + 0.05:
				np.y = fl + 0.05
				vv = vv * 0.3
				vv.y = absf(vv.y) * 0.3
			stt["v"] = vv
			mi.global_position = np
			mi.rotation += spin * dt * (1.0 if vv.length() > 0.5 else 0.0)
			if age > 1.2:
				mi.scale *= 0.85
			return true
		mi.add_child(p)


## Oyuncu ekranı: kısa beyaz-sarı patlama + keskin manga zikzakları (Raigen Raikōchū gibi göz alan teknikler)
static func screen_flash(col: Color, dur: float, zig := 5) -> void:
	var cl = CanvasLayer.new()
	cl.layer = 60
	var rect = ColorRect.new()
	rect.color = Color(col.r, col.g, col.b, 0.85)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	root().add_child(cl)
	var sz = root().get_viewport().get_visible_rect().size
	for k in zig:
		var ln = Line2D.new()
		ln.width = sz.y * randf_range(0.012, 0.025)
		ln.default_color = Color(col.r * 0.95, col.g * 0.85, col.b * 0.35, 1.0)
		ln.joint_mode = Line2D.LINE_JOINT_SHARP
		var a = Vector2(randf_range(0.05, 0.95) * sz.x, randf_range(-0.05, 0.3) * sz.y)
		var b = a + Vector2(randf_range(-0.25, 0.25) * sz.x, randf_range(0.35, 0.7) * sz.y)
		var nseg = 5
		for i in nseg + 1:
			var f = float(i) / nseg
			var q = a.lerp(b, f)
			if i > 0 and i < nseg:
				q += Vector2((1.0 if i % 2 == 0 else -1.0) * sz.x * randf_range(0.02, 0.05), 0.0)
			ln.add_point(q)
		cl.add_child(ln)
	var tw = cl.create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(rect, "color:a", 0.0, dur)
	tw.tween_callback(cl.queue_free)
	for ch in cl.get_children():
		if ch is Line2D:
			var t2 = ch.create_tween()
			t2.tween_interval(dur * 0.4)
			t2.tween_property(ch, "modulate:a", 0.0, dur * 0.5)


## Islak zemine düşen şimşek alanı çarpar (eski çarpma etkisindeki oynanış koşulu aynen: yere 2.5 m'den yakın)
static func wet_shock(at: Vector3, s: float) -> void:
	var g = floor_at(at)
	if at.y - g.y < 2.5:
		GroundFX.shock(g, null, 12.0 * s)
