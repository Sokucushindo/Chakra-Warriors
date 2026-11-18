class_name VitalsUI
extends Control
## Sol üst oyuncu çerçevesi (tamamı kod çizimi): shuriken biçimli çelik-ahşap portre, parşömen üstünde isim,
## metal çerçeveli can / chakra / stamina çubukları, Ryō, EXP, klan kaynağı. Hud her karede set_state çağırır;
## yalnız görünür değer değişince yeniden çizilir.

const W := 720.0
const H := 239.0
const C := Vector2(72, 80)      # portre merkezi
const BX := 134.0               # çubukların sol kenarı
const HP_W := 380.0
const COL_X := BX + HP_W + 14.0  # değer / simge sütunu (tüm çubuklarda aynı hizada)
const HP_R := Rect2(BX, 83, HP_W, 22)
const CK_R := Rect2(BX, 115, HP_W, 18)
const ST_R := Rect2(BX, 141, HP_W, 12)
const XP_R := Rect2(BX, 165, HP_W, 6)
const KR_R := Rect2(BX, 220, HP_W, 8)
const ST_COL := Color(1.0, 0.62, 0.18)
const FILL_SHADER := """shader_type canvas_item;
uniform vec4 col : source_color = vec4(0.3, 0.9, 0.4, 1.0);
uniform vec4 trail_col : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float frac = 1.0;
uniform float trail = 0.0;
uniform vec2 sz = vec2(380.0, 22.0);
uniform float speed = 1.0;

float cap_d(vec2 p, vec2 s) {
	float r = min(s.x, s.y) * 0.5;
	vec2 q = abs(p - s * 0.5) - (s * 0.5 - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * sz;
	float fw = max(sz.x * frac, min(sz.y, 6.0));
	float tw = max(sz.x * trail, sz.y);
	vec4 o = vec4(0.0);
	if (trail > frac + 0.002) {
		float a = 1.0 - smoothstep(-0.7, 0.7, cap_d(p, vec2(tw, sz.y)));
		o = vec4(mix(trail_col.rgb * 1.1, trail_col.rgb * 0.6, UV.y), a);
	}
	if (frac > 0.003) {
		float a = 1.0 - smoothstep(-0.7, 0.7, cap_d(p, vec2(fw, sz.y)));
		float t = UV.y;
		vec3 base = mix(col.rgb * 1.45, col.rgb * 0.42, smoothstep(0.0, 1.0, t));
		float w1 = sin(p.x * 0.05 - TIME * 1.3 * speed + sin(p.y * 0.35 + p.x * 0.02) * 1.6);
		float w2 = sin(p.x * 0.12 + p.y * 0.28 + TIME * 0.8 * speed);
		float w3 = sin(p.x * 0.021 - TIME * 0.5 * speed + 1.7);
		base += vec3(1.0) * (smoothstep(0.7, 1.0, w1) * 0.20 + smoothstep(0.8, 1.0, w2) * 0.10);
		base *= 0.92 + 0.08 * w3;
		base += vec3(0.30) * (1.0 - smoothstep(0.0, 0.5, t));
		base *= 1.0 - 0.25 * smoothstep(0.75, 1.0, t);
		float e = exp(-pow((p.x - fw + 2.0) / 7.0, 2.0));
		base += col.rgb * 0.6 * e + vec3(0.25) * e;
		o.rgb = (o.a < 0.001) ? base : mix(o.rgb, base, a);
		o.a = max(o.a, a);
	}
	COLOR = o;
}
"""

var st: Dictionary = {}
var _hash := 0       # hareketli katman (çubuk dolgusu, sayılar)
var _hash_s := 0     # sabit katman (portre, parşömen, çubuk çerçeveleri): nadiren yeniden çizilir
var dyn: Control
var _fills := {}     # hp / ck / xp / kr -> ColorRect (GPU gölgelendirici dolgu: akan enerji dokusu)
static var _fill_shader: Shader
var portrait_tex: Texture2D = null
var el_col: Color = UI.GOLD

static var _ink: Font
static var _cond: Font


static func ink_font() -> Font:
	if _ink == null:
		var f = SystemFont.new()
		f.font_names = PackedStringArray(["Ink Free", "Segoe Script", "Bahnschrift SemiBold", "Segoe UI Semibold", "Arial"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_ink = f
	return _ink


static func cond_font() -> Font:
	if _cond == null:
		var f = SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift SemiBold Condensed", "Bahnschrift SemiCondensed", "Bahnschrift SemiBold", "Arial Narrow", "Arial"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_cond = f
	return _cond


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fill_shader == null:
		_fill_shader = Shader.new()
		_fill_shader.code = FILL_SHADER
	for kv in [["hp", HP_R], ["ck", CK_R], ["st", ST_R], ["xp", XP_R], ["kr", KR_R]]:
		var cr := ColorRect.new()
		var rr: Rect2 = kv[1]
		cr.position = rr.position
		cr.size = rr.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = _fill_shader
		sm.set_shader_parameter("sz", rr.size)
		cr.material = sm
		add_child(cr)
		_fills[kv[0]] = cr
	dyn = Control.new()
	dyn.size = Vector2(W, H)
	dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.draw.connect(_draw_dyn)
	add_child(dyn)


## d: name, rank_txt, hp, hp_max, hp_col, trail, ck, ck_max, sta, sta_max, xp (0..1), ryo, subs, rk, clan (Dictionary: label, v, max, col; boş = yok)
func set_state(d: Dictionary) -> void:
	var q := {
		"name": d["name"], "rank_txt": d["rank_txt"],
		"hp": int(d["hp"]), "hp_max": int(d["hp_max"]), "hpf": int(clampf(d["hp"] / maxf(1.0, d["hp_max"]), 0.0, 1.0) * 400.0),
		"hp_col": d["hp_col"], "trail": int(clampf(d["trail"] / maxf(1.0, d["hp_max"]), 0.0, 1.0) * 400.0),
		"ck": int(d["ck"]), "ck_max": int(d["ck_max"]), "ckf": int(clampf(d["ck"] / maxf(1.0, d["ck_max"]), 0.0, 1.0) * 400.0),
		"sta": int(d["sta"]), "sta_max": int(d["sta_max"]), "staf": int(clampf(d["sta"] / maxf(1.0, d["sta_max"]), 0.0, 1.0) * 400.0),
		"xp": int(clampf(d["xp"], 0.0, 1.0) * 300.0), "ryo": int(d["ryo"]), "subs": int(d["subs"]), "rk": int(d["rk"]),
		"clan": {} if d["clan"].is_empty() else {"l": d["clan"]["label"], "v": int(d["clan"]["v"]), "m": int(d["clan"]["max"]),
			"f": int(clampf(d["clan"]["v"] / maxf(0.001, d["clan"]["max"]), 0.0, 1.0) * 300.0), "c": d["clan"]["col"]},
	}
	var cl: Dictionary = q["clan"]
	var hs := [q["name"], q["rank_txt"], q["rk"], cl.is_empty(), cl.get("c", Color.BLACK), el_col].hash()
	var h := q.hash()
	if h == _hash and hs == _hash_s:
		return
	st = q
	if hs != _hash_s:
		_hash_s = hs
		queue_redraw()
	if h != _hash:
		_hash = h
		dyn.queue_redraw()
		_fill("hp", q["hpf"] / 400.0, q["hp_col"], q["trail"] / 400.0)
		_fill("ck", q["ckf"] / 400.0, Color(0.28, 0.6, 1.0))
		_fill("st", q["staf"] / 400.0, ST_COL)
		_fill("xp", q["xp"] / 300.0, Color(1.0, 0.7, 0.25))
		var cl2: Dictionary = q["clan"]
		_fills["kr"].visible = not cl2.is_empty()
		if not cl2.is_empty():
			_fill("kr", cl2["f"] / 300.0, cl2["c"])


func _fill(key: String, frac: float, col: Color, trail := 0.0) -> void:
	var m := (_fills[key] as ColorRect).material as ShaderMaterial
	m.set_shader_parameter("frac", frac)
	m.set_shader_parameter("trail", trail)
	m.set_shader_parameter("col", col)


# ------------------------------------------------------------------ çizim yardımcıları
static func _circ(c: Vector2, r: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _ell(c: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _star(c: Vector2, ro: float, ri: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	return pts


## Sol üst ışıktan sağ alt gölgeye vertex renk geçişli çokgen (metal / ahşap)
func _metal(pts: PackedVector2Array, c: Vector2, r: float, light: Color, dark: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf(0.5 - (p - c).dot(Vector2(0.7, 0.7)) / (r * 2.0), 0.0, 1.0)
		cols.append(dark.lerp(light, t))
	draw_polygon(pts, cols)


func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	draw_polyline(p, col, w, true)


func _t(c: Control, f: Font, p: Vector2, s: String, fs: int, col: Color, ow := 4, ol := Color(0, 0, 0, 0.85)) -> void:
	if ow > 0:
		c.draw_string(f, p + Vector2(0, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
		c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, ol)
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return ("-" if n < 0 else "") + out


# ------------------------------------------------------------------ ana çizim
## Sabit katman: parşömen, portre, rütbe, çubuk çerçeveleri, simgeler (yalnız ad / rütbe / klan / portre değişince)
func _draw() -> void:
	if st.is_empty():
		return
	_draw_scroll()
	_draw_portrait()
	var cf = cond_font()
	_t(self, cf, Vector2(142, 73), String(st["rank_txt"]), 19, Color(1.0, 0.86, 0.5), 5, Color(0.1, 0.05, 0.0, 0.9))
	_bar_frame(HP_R, 4.0)
	_bar_frame(CK_R, 4.0)
	_bar_frame(ST_R, 3.0)
	_coins(Vector2(BX + 4, 202))
	_rf(self, Rect2(410, 178, 106, 26), 12.0, Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.3))
	_rl(self, Rect2(410, 178, 106, 26), 12.0, Color(0.8, 0.85, 0.95, 0.35), 1.0)
	_bar_frame(XP_R, 2.0)
	_ticks(XP_R)
	_leaf(Vector2(COL_X + 11, XP_R.get_center().y), 22.0)
	_t(self, cf, Vector2(COL_X + 28, XP_R.get_center().y + 6), "EXP", 17, Color(1.0, 0.6, 0.25), 4)
	var cl: Dictionary = st["clan"]
	if not cl.is_empty():
		_bar_frame(KR_R, 2.0)
		_ticks(KR_R)
		_gem(Vector2(COL_X + 11, KR_R.get_center().y), cl["c"])


## Hareketli katman: değerler, stamina, Ryō, kawarimi hakları (dolgular GPU gölgelendiricide)
func _draw_dyn() -> void:
	if st.is_empty():
		return
	var f = UI.font(true)
	var cf = cond_font()
	_t(dyn, f, Vector2(COL_X, HP_R.position.y + 17), "%d / %d" % [st["hp"], st["hp_max"]], 18, st["hp_col"].lerp(Color.WHITE, 0.6), 4)
	_t(dyn, f, Vector2(COL_X, CK_R.position.y + 15), "%d / %d" % [st["ck"], st["ck_max"]], 16, Color(0.72, 0.88, 1.0), 4)
	_t(dyn, f, Vector2(COL_X, ST_R.position.y + 12), "%d / %d" % [st["sta"], st["sta_max"]], 14, ST_COL.lerp(Color.WHITE, 0.45), 4)
	_t(dyn, f, Vector2(BX + 98, 198), "%s Ryō" % _num(st["ryo"]), 18, Color(1.0, 0.86, 0.45), 5, Color(0.2, 0.1, 0.0, 0.9))
	for i in 4:
		_log(dyn, Vector2(428 + i * 24, 191), i < st["subs"])
	var cl: Dictionary = st["clan"]
	if not cl.is_empty():
		var lt := String(cl["l"])
		if cl["m"] > 1:
			lt += ": %d / %d" % [cl["v"], cl["m"]]
		_t(dyn, cf, Vector2(COL_X + 28, KR_R.get_center().y + 6), lt, 16, cl["c"].lerp(Color.WHITE, 0.45), 4)


## Yarıçapı yüksekliğe sığdırılmış gradyanlı yuvarlak dikdörtgen (dejenere çokgen üretmez)
static func _rf(p: Control, r: Rect2, rad: float, top: Color, bot: Color) -> void:
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	Hud._rr_fill(p, r, minf(rad, minf(r.size.x, r.size.y) * 0.49), top, bot)


static func _rl(p: Control, r: Rect2, rad: float, col: Color, w: float) -> void:
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	Hud._rr_line(p, r, minf(rad, minf(r.size.x, r.size.y) * 0.49), col, w)


## Metal çubuk çerçevesi + koyu iç (sabit)
func _bar_frame(r: Rect2, fw: float) -> void:
	var rad := r.size.y * 0.5
	var fr := r.grow(fw)
	_rf(self, Rect2(fr.position + Vector2(0, 2), fr.size), rad + fw, Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.4))
	_rf(self, fr, rad + fw, Color(0.95, 0.96, 1.0), Color(0.38, 0.42, 0.52))
	_rl(self, fr.grow(-1.2), rad + fw - 1.0, Color(1, 1, 1, 0.45), 1.0)
	_rl(self, fr.grow(-0.5), rad + fw, Color(0.04, 0.05, 0.07, 0.95), 1.2)
	_rl(self, fr.grow(-fw + 0.5), rad + 0.5, Color(0, 0, 0, 0.6), 1.0)
	if fw < 3.0:
		_rf(self, r, rad, Color(0.16, 0.13, 0.11, 0.97), Color(0.08, 0.06, 0.05, 0.97))
	else:
		_rf(self, r, rad, Color(0.01, 0.025, 0.03, 0.97), Color(0.06, 0.09, 0.09, 0.97))


## Ölçek çentikleri (ince çubuk boşken delik gibi görünmesin)
func _ticks(r: Rect2) -> void:
	for i in range(1, 10):
		var x := r.position.x + r.size.x * float(i) / 10.0
		draw_line(Vector2(x, r.position.y + 1.5), Vector2(x, r.end.y - 1.5), Color(1, 1, 1, 0.13), 1.0)


func _draw_scroll() -> void:
	var x0 := 116.0
	var x1 := 470.0
	var y0 := 6.0
	var y1 := 46.0
	var n := 14
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(Vector2(x0 + (x1 - x0) * float(i) / n, y0 + sin(float(i) * 1.7) * 1.3))
	for i in range(n, -1, -1):
		pts.append(Vector2(x0 + (x1 - x0) * float(i) / n, y1 + sin(float(i) * 2.3 + 1.0) * 1.3))
	# gölge
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 4))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.32))
	var cols := PackedColorArray()
	var mid := (x0 + x1) * 0.5
	for p in pts:
		var ex := pow(absf(p.x - mid) / (mid - x0), 4.0)
		var v := clampf((p.y - y0) / (y1 - y0), 0.0, 1.0)
		cols.append(Color(0.95, 0.89, 0.72).lerp(Color(0.80, 0.68, 0.46), v * 0.55 + ex * 0.5))
	draw_polygon(pts, cols)
	# kâğıt lifleri + kenar
	for i in 5:
		var yy := y0 + 8.0 + i * 8.0
		draw_line(Vector2(x0 + 24 + i * 11, yy), Vector2(x1 - 40 - i * 17, yy + 1.0), Color(0.55, 0.4, 0.2, 0.07), 1.0)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.45, 0.32, 0.16, 0.55), 1.2, true)
	# iki ucu sarılı rulo
	for e in [x0, x1]:
		var sgn := 1.0 if e == x1 else -1.0
		var cx: float = e + sgn * 1.0
		var rect := PackedVector2Array([Vector2(cx - 6, y0 - 3), Vector2(cx + 6, y0 - 3), Vector2(cx + 6, y1 + 3), Vector2(cx - 6, y1 + 3)])
		var rc := PackedColorArray([Color(0.62, 0.48, 0.28), Color(0.93, 0.85, 0.66), Color(0.5, 0.37, 0.2), Color(0.5, 0.37, 0.2)])
		draw_polygon(rect, rc)
		draw_polygon(PackedVector2Array([Vector2(cx - 6, y0 - 3), Vector2(cx - 1, y0 - 3), Vector2(cx - 1, y1 + 3), Vector2(cx - 6, y1 + 3)]), PackedColorArray([Color(0.5, 0.37, 0.2), Color(0.95, 0.88, 0.7), Color(0.95, 0.88, 0.7), Color(0.5, 0.37, 0.2)]))
		draw_colored_polygon(_ell(Vector2(cx, y0 - 3), 6.0, 2.2), Color(0.98, 0.93, 0.78))
		draw_colored_polygon(_ell(Vector2(cx, y1 + 3), 6.0, 2.2), Color(0.45, 0.32, 0.17))
	# isim: kaligrafik mürekkep, kalın fırça görünümü (kontur aynı renkte), kısa isim parşömende ortalanır
	var nm := String(st["name"])
	var f = ink_font()
	var fs := 42
	while fs > 18 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 300.0:
		fs -= 2
	var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var nx := maxf(146.0, 300.0 - nw * 0.5)
	var ny := 26.0 + fs * 0.36
	var ink := Color(0.1, 0.055, 0.03)
	draw_string(f, Vector2(nx + 1.5, ny + 1.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.28))
	draw_string_outline(f, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, ink)
	draw_string(f, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _draw_portrait() -> void:
	var rot := -PI * 0.5
	draw_circle(C + Vector2(0, 5), 72.0, Color(0, 0, 0, 0.32))
	# ahşap plakalar (sivri uçların arasında)
	for i in 6:
		var am := rot + PI / 6.0 + PI / 3.0 * i
		var pts := PackedVector2Array([C])
		for k in 9:
			var a := am + (float(k) - 4.0) * 0.085
			pts.append(C + Vector2(cos(a), sin(a)) * 67.0)
		_metal(pts, C, 67.0, Color(0.60, 0.38, 0.19), Color(0.22, 0.12, 0.06))
		_outline(pts, Color(0.1, 0.05, 0.02, 0.85), 1.5)
		for g in 3:
			var ga := am + (float(g) - 1.0) * 0.07
			draw_line(C + Vector2(cos(ga), sin(ga)) * 54.0, C + Vector2(cos(ga), sin(ga)) * 64.0, Color(0.15, 0.07, 0.03, 0.4), 1.0)
	# çelik shuriken uçları
	var star := _star(C, 77.0, 44.0, 6, rot)
	_metal(star, C, 77.0, Color(0.86, 0.89, 0.94), Color(0.26, 0.29, 0.35))
	_outline(star, Color(0.06, 0.07, 0.09, 0.95), 1.6)
	for i in 6:
		var a := rot + PI / 3.0 * i
		draw_line(C + Vector2(cos(a), sin(a)) * 56.0, C + Vector2(cos(a), sin(a)) * 72.0, Color(1, 1, 1, 0.35), 1.2, true)
	# çelik halka
	draw_colored_polygon(_circ(C, 54.0, 56), Color(0.05, 0.06, 0.08))
	_metal(_circ(C, 52.5, 56), C, 52.5, Color(0.88, 0.9, 0.95), Color(0.3, 0.33, 0.4))
	_metal(_circ(C, 43.0, 56), C, 43.0, Color(0.3, 0.33, 0.4), Color(0.85, 0.88, 0.93))
	draw_arc(C, 48.0, PI * 0.9, PI * 1.65, 20, Color(1, 1, 1, 0.5), 1.5, true)
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.3
		var rp := C + Vector2(cos(a), sin(a)) * 48.0
		draw_circle(rp + Vector2(0.6, 0.9), 2.4, Color(0, 0, 0, 0.5))
		draw_circle(rp, 2.2, Color(0.55, 0.58, 0.64))
		draw_circle(rp + Vector2(-0.6, -0.7), 0.9, Color(1, 1, 1, 0.8))
	# yüz
	draw_circle(C, 41.0, el_col.darkened(0.65))
	if portrait_tex:
		draw_texture_rect(portrait_tex, Rect2(C - Vector2(40, 40), Vector2(80, 80)), false)
	else:
		var nm := String(st["name"]).substr(0, 1).to_upper()
		var fb = UI.font(true)
		var w := fb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(fb, C + Vector2(-w * 0.5, 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.TEXT)
	draw_arc(C, 41.0, 0.0, TAU, 48, Color(0, 0, 0, 0.55), 2.5, true)
	# rütbe plakası: koyu çelik yay (yıldızlar ahşap uçların üstünde karışmasın)
	var pa0 := PI * 0.5 - 1.0
	var pa1 := PI * 0.5 + 1.0
	draw_arc(C, 59.0, pa0, pa1, 28, Color(0.03, 0.035, 0.05), 19.0, true)
	draw_arc(C, 59.0, pa0, pa1, 28, Color(0.2, 0.22, 0.28), 16.0, true)
	draw_arc(C, 59.0, pa0, pa1, 28, Color(0.09, 0.1, 0.13), 12.0, true)
	draw_arc(C, 66.0, pa0 + 0.04, pa1 - 0.04, 28, Color(1, 1, 1, 0.22), 1.2, true)
	# rütbe yıldızları (halkanın alt kavsinde): kazanılan = gümüş shuriken
	for i in 6:
		var a := PI * 0.5 + (float(i) - 2.5) * 0.3
		var sp := C + Vector2(cos(a), sin(a)) * 59.0
		var lit: bool = i < int(st["rk"])
		var sr := _star(sp, 8.5, 3.0, 4, 0.4)
		if lit:
			draw_colored_polygon(_star(sp + Vector2(0, 1.5), 8.5, 3.0, 4, 0.4), Color(0, 0, 0, 0.5))
			_metal(sr, sp, 8.5, Color(0.95, 0.96, 1.0), Color(0.45, 0.48, 0.56))
			_outline(sr, Color(0.05, 0.06, 0.08, 0.95), 1.0)
			draw_circle(sp, 1.4, Color(0.1, 0.1, 0.12))
		else:
			draw_colored_polygon(sr, Color(0.06, 0.07, 0.09, 0.9))
			_outline(sr, Color(0.75, 0.8, 0.9, 0.6), 1.0)


## Altın para yığınları
func _coins(base: Vector2) -> void:
	var sc := 1.0
	draw_set_transform(base * (1.0 - sc), 0.0, Vector2(sc, sc))
	var stacks := [[10.0, 3], [26.0, 5], [42.0, 4], [55.0, 2], [67.0, 3]]
	for s in stacks:
		var x: float = base.x + s[0]
		for k in int(s[1]):
			var cy := base.y - 4.0 - float(k) * 3.4
			draw_colored_polygon(_ell(Vector2(x, cy + 3.0), 10.0, 4.0), Color(0.55, 0.36, 0.06))
			draw_rect(Rect2(x - 10.0, cy, 20.0, 3.0), Color(0.62, 0.42, 0.08))
			draw_colored_polygon(_ell(Vector2(x, cy), 10.0, 4.0), Color(1.0, 0.82, 0.3))
			draw_colored_polygon(_ell(Vector2(x, cy), 6.8, 2.6), Color(0.85, 0.6, 0.15))
			draw_colored_polygon(_ell(Vector2(x - 1.0, cy - 0.4), 5.0, 1.8), Color(1.0, 0.9, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Kawarimi kütüğü: ahşap silindir; hak yoksa sönük
func _log(c: Control, p: Vector2, lit: bool) -> void:
	var a := 1.0 if lit else 0.22
	var r := Rect2(p - Vector2(10, 6), Vector2(20, 12))
	_rf(c, r, 4.0, Color(0.7, 0.45, 0.22, a), Color(0.32, 0.18, 0.08, a))
	_rl(c, r, 4.0, Color(0.1, 0.05, 0.02, 0.8 * a), 1.0)
	c.draw_colored_polygon(_ell(p + Vector2(-8, 0), 3.2, 5.2), Color(0.88, 0.66, 0.38, a))
	c.draw_arc(p + Vector2(-8, 0), 1.6, 0.0, TAU, 10, Color(0.4, 0.22, 0.1, a), 1.0)


## Yaprak simgesi (EXP)
func _leaf(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	var rot := -0.65
	var n := 10
	for i in n + 1:
		var t := float(i) / n
		var hw := 0.42 * s * pow(sin(PI * t), 0.9) * (1.0 - 0.25 * t)
		pts.append(c + Vector2(lerpf(-s * 0.5, s * 0.5, t), -hw).rotated(rot))
	for i in range(n, -1, -1):
		var t := float(i) / n
		var hw := 0.42 * s * pow(sin(PI * t), 0.9) * (1.0 - 0.25 * t)
		pts.append(c + Vector2(lerpf(-s * 0.5, s * 0.5, t), hw).rotated(rot))
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.05:
			clean.append(p)
	draw_colored_polygon(clean, Color(0, 0, 0, 0.4))
	_metal(clean, c, s * 0.6, Color(1.0, 0.8, 0.4), Color(0.78, 0.38, 0.1))
	_outline(clean, Color(0.3, 0.12, 0.02, 0.9), 1.0)
	draw_line(c + Vector2(-s * 0.6, 0).rotated(rot), c + Vector2(s * 0.35, 0).rotated(rot), Color(0.4, 0.18, 0.04, 0.8), 1.2, true)


## Elmas simge (klan kaynağı): gümüş çerçeve + renkli taş
func _gem(c: Vector2, col: Color) -> void:
	var outer := PackedVector2Array([c + Vector2(0, -11), c + Vector2(9, 0), c + Vector2(0, 11), c + Vector2(-9, 0)])
	var inner := PackedVector2Array([c + Vector2(0, -7), c + Vector2(5.5, 0), c + Vector2(0, 7), c + Vector2(-5.5, 0)])
	draw_colored_polygon(PackedVector2Array([outer[0] + Vector2(0, 2), outer[1] + Vector2(0, 2), outer[2] + Vector2(0, 2), outer[3] + Vector2(0, 2)]), Color(0, 0, 0, 0.45))
	_metal(outer, c, 11.0, Color(0.9, 0.92, 0.97), Color(0.35, 0.38, 0.46))
	_outline(outer, Color(0.06, 0.07, 0.09, 0.9), 1.0)
	_metal(inner, c, 7.0, col.lightened(0.45), col.darkened(0.35))
	draw_line(c + Vector2(-2, -3), c + Vector2(1, -5), Color(1, 1, 1, 0.7), 1.2, true)
