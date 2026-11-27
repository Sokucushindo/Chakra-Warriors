class_name VitalsUI
extends Control
## Sol üst oyuncu çerçevesi, arayüzün sumi-e dilinde (dokular: tools/make_ui_brush.py): kâğıda yayılmış mürekkep lekesi
## üstünde kırmızı ensō içinde portre, yırtık kenarlı washi plakada mürekkep isim + hanko, fırça oluklarında akan
## mürekkep can / chakra / stamina çubukları, mon sikkesi yığını, kütükler, EXP, klan kaynağı. Hud her karede set_state çağırır;
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

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h1(i), h1(i + 1.0), f); }

void fragment() {
	vec2 p = UV * sz;
	// fırça ucu: her kıl satırı farklı yerde biter
	float row = n1(p.y * 0.9 + 3.0) * 0.6 + n1(p.y * 2.3) * 0.4;
	float endf = sz.x * frac - row * min(10.0, sz.x * frac * 0.5);
	float endt = sz.x * trail - row * 8.0;
	vec4 o = vec4(0.0);
	if (trail > frac + 0.002 && p.x < endt) {
		o = vec4(mix(trail_col.rgb * 1.05, trail_col.rgb * 0.55, UV.y), 0.85);
	}
	if (frac > 0.003 && p.x < endf) {
		// derinlik: üst açık, alt koyu (ıslak mürekkep)
		vec3 base = mix(col.rgb * 1.3, col.rgb * 0.5, smoothstep(0.0, 1.0, UV.y));
		// kıl izleri: satır satır yoğunluk, yavaşça akar
		float streak = n1(p.y * 1.6 + 11.0 + floor(p.x * 0.01));
		float flow = n1(p.x * 0.03 - TIME * 0.9 * speed + p.y * 0.07);
		base *= 0.82 + 0.18 * streak;
		base += col.rgb * 0.22 * smoothstep(0.65, 1.0, flow);
		// ıslak parlama: üst kenarda kesik kesik açık şerit
		float sheen = (1.0 - smoothstep(0.08, 0.32, UV.y)) * smoothstep(0.08, 0.0, abs(UV.y - 0.16) - 0.06);
		base += vec3(0.32) * sheen * (0.55 + 0.45 * n1(p.x * 0.06 - TIME * 0.5 * speed));
		// uç: ıslak mürekkep birikintisi parlar
		float e = exp(-pow((p.x - endf + 3.0) / 6.0, 2.0));
		base += col.rgb * 0.45 * e + vec3(0.18) * e;
		o = vec4(base, 1.0);
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
var el_col: Color = LazyFx.g("UI").GOLD

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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # çerçeve 0.72 ölçekte: dokular küçülünce tırtıklanmasın
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
	_draw_portrait()
	_draw_name()
	var cf = cond_font()
	draw_style_box(LazyFx.g("UI").brush(Color(0.02, 0.018, 0.016, 0.88), "a", 0), Rect2(122, 59, 330, 26))
	_t(self, LazyFx.g("UI").font(true), Vector2(140, 78), String(st["rank_txt"]), 18, Color(1.0, 0.86, 0.5), 2, Color(0.05, 0.03, 0.02, 0.92))
	_bar_frame(HP_R)
	_bar_frame(CK_R)
	_bar_frame(ST_R)
	_bar_frame(XP_R)
	_ticks(XP_R)
	_leaf(Vector2(COL_X + 11, XP_R.get_center().y), 22.0)
	_t(self, cf, Vector2(COL_X + 28, XP_R.get_center().y + 6), LazyFx.g("Lang").t("GÜÇ"), 17, Color(0.98, 0.7, 0.38), 4)
	# Ryō + kütük satırı: kısa mürekkep oluk üstünde
	draw_style_box(LazyFx.g("UI").brush(Color(0.02, 0.018, 0.016, 0.72), "a", 0), Rect2(BX - 10, 182, 250, 32))
	draw_style_box(LazyFx.g("UI").brush(Color(0.02, 0.018, 0.016, 0.72), "s", 0), Rect2(408, 182, 130, 32))
	_coins(Vector2(BX + 6, 198))
	var cl: Dictionary = st["clan"]
	if not cl.is_empty():
		_bar_frame(KR_R)
		_ticks(KR_R)
		_gem(Vector2(COL_X + 11, KR_R.get_center().y), cl["c"])


## Hareketli katman: değerler, stamina, Ryō, kawarimi hakları (dolgular GPU gölgelendiricide)
func _draw_dyn() -> void:
	if st.is_empty():
		return
	var f = LazyFx.g("UI").font(true)
	var cf = cond_font()
	# çubukların üst kenarında ince parlak çizgi (dolgunun üstünde: ıslak yüzey)
	for r in [HP_R, CK_R, ST_R]:
		dyn.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.12), 1.0)
	_t(dyn, f, Vector2(COL_X, HP_R.position.y + 17), "%d / %d" % [st["hp"], st["hp_max"]], 18, st["hp_col"].lerp(Color.WHITE, 0.55), 4)
	_t(dyn, f, Vector2(COL_X, CK_R.position.y + 15), "%d / %d" % [st["ck"], st["ck_max"]], 16, Color(0.72, 0.86, 1.0), 4)
	_t(dyn, f, Vector2(COL_X, ST_R.position.y + 12), "%d / %d" % [st["sta"], st["sta_max"]], 14, ST_COL.lerp(Color.WHITE, 0.45), 4)
	_t(dyn, f, Vector2(BX + 66, 205), "%s Ryō" % _num(st["ryo"]), 18, Color(1.0, 0.86, 0.5), 4, Color(0.12, 0.06, 0.0, 0.9))
	for i in 4:
		_log(dyn, Vector2(432 + i * 24, 198), i < st["subs"])
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


## Çubuk oluğu: arkada kalın mürekkep fırça darbesi (kuru kuyruk değer sütununun altına uzanır), içte koyu oluk + iç gölge
func _bar_frame(r: Rect2) -> void:
	var th := r.size.y
	var pad := clampf(th * 0.55, 5.0, 12.0)
	var g := Rect2(r.position.x - 16.0, r.position.y - pad, r.size.x + 44.0, th + pad * 2.0)   # kuru kuyruk çubuğun ucunda biter, sayılara taşmaz
	draw_style_box(LazyFx.g("UI").brush(Color(0, 0, 0, 0.35), "a", 0), Rect2(g.position + Vector2(2, 3), g.size))
	draw_style_box(LazyFx.g("UI").brush(Color(0.025, 0.022, 0.02, 0.9), "a", 0), g)
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.85))
	draw_rect(r, Color(0.075, 0.066, 0.058))
	draw_rect(Rect2(r.position, Vector2(r.size.x, minf(3.0, th * 0.3))), Color(0, 0, 0, 0.45))   # iç gölge


## Ölçek çentikleri (ince çubuk boşken delik gibi görünmesin)
func _ticks(r: Rect2) -> void:
	for i in range(1, 10):
		var x := r.position.x + r.size.x * float(i) / 10.0
		draw_line(Vector2(x, r.position.y + 1.0), Vector2(x, r.end.y - 1.0), Color(1, 1, 1, 0.1), 1.0)


## İsim plakası: yırtık kenarlı washi şerit, mürekkep isim, sağ uçta kırmızı hanko
func _draw_name() -> void:
	var plate := Rect2(118, 2, 364, 54)
	var sb := StyleBoxTexture.new()
	sb.texture = LazyFx.g("UI")._t("washi")
	sb.set_texture_margin_all(16)
	sb.modulate_color = Color(0, 0, 0, 0.4)
	draw_style_box(sb, Rect2(plate.position + Vector2(3, 4), plate.size))
	sb.modulate_color = Color.WHITE
	draw_style_box(sb, plate)
	var nm := String(st["name"])
	var f = LazyFx.g("UI").title_font()
	var fs := 38
	while fs > 18 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 270.0:
		fs -= 2
	var nw = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var nx = plate.position.x + 18.0 + (290.0 - nw) * 0.5
	var ny := plate.get_center().y + fs * 0.34
	var ink := Color(0.09, 0.06, 0.045)
	draw_string(f, Vector2(nx, ny + 1.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.25))
	draw_string_outline(f, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, ink)
	draw_string(f, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# hanko: rütbe mührü
	var hr := Rect2(plate.end.x - 50, plate.position.y + 9, 36, 36)
	draw_texture_rect(LazyFx.g("UI")._t("seal"), hr, false, Color(LazyFx.g("UI").ACCENT, 0.92))
	var kf = LazyFx.g("UI").seal_font()
	var ch := "忍"
	var cw = kf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(kf, Vector2(hr.get_center().x - cw * 0.5, hr.get_center().y + 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.95, 0.88, 0.95))


func _draw_portrait() -> void:
	# kâğıda yayılmış mürekkep lekesi zemin
	draw_texture_rect(LazyFx.g("UI")._t("ink_disc"), Rect2(C - Vector2(90, 90), Vector2(180, 180)), false, Color(0.025, 0.022, 0.02, 0.92))
	draw_circle(C, 43.0, el_col.darkened(0.72))
	if portrait_tex:
		draw_texture_rect(portrait_tex, Rect2(C - Vector2(41, 41), Vector2(82, 82)), false)
	else:
		var nm := String(st["name"]).substr(0, 1).to_upper()
		var fb = LazyFx.g("UI").title_font()
		var w = fb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(fb, C + Vector2(-w * 0.5, 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, LazyFx.g("UI").CREAM)
	draw_arc(C, 43.0, 0.0, TAU, 64, Color(0, 0, 0, 0.75), 2.5, true)
	draw_arc(C, 45.0, 0.0, TAU, 64, Color(LazyFx.g("UI").CREAM, 0.18), 1.0, true)
	# ensō: önce gölgesi, sonra kırmızı fırça halkası
	var er := Rect2(C - Vector2(78, 78), Vector2(156, 156))
	draw_texture_rect(LazyFx.g("UI")._t("enso"), Rect2(er.position + Vector2(2, 3), er.size), false, Color(0, 0, 0, 0.55))
	draw_texture_rect(LazyFx.g("UI")._t("enso"), er, false, LazyFx.g("UI").ACCENT)
	# rütbe: halkanın altında altı elmas; kazanılan = krem, içinde kırmızı nokta; kalan = koyu, ince krem kenar
	for i in 6:
		var a := PI * 0.5 + (float(i) - 2.5) * 0.25
		var sp := C + Vector2(cos(a), sin(a)) * 72.0
		var d := PackedVector2Array([sp + Vector2(0, -6.5), sp + Vector2(4.6, 0), sp + Vector2(0, 6.5), sp + Vector2(-4.6, 0)])
		var dsh := PackedVector2Array()
		for q in d:
			dsh.append(q + Vector2(1, 1.5))
		draw_colored_polygon(dsh, Color(0, 0, 0, 0.6))
		if i < int(st["rk"]):
			draw_colored_polygon(d, LazyFx.g("UI").CREAM)
			_outline(d, Color(0.08, 0.05, 0.03, 0.9), 1.2)
			draw_circle(sp, 1.6, LazyFx.g("UI").ACCENT)
		else:
			draw_colored_polygon(d, Color(0.06, 0.055, 0.05, 0.92))
			_outline(d, Color(LazyFx.g("UI").CREAM, 0.45), 1.0)


## Ryō: ipe dizili mon sikkeleri (yan yana üç yığın), soluk altın, kare delik, mürekkep kenar
func _coins(base: Vector2) -> void:
	var stacks := [[0.0, 3], [17.0, 4], [34.0, 2]]
	for s in stacks:
		var x: float = base.x + s[0]
		for k in int(s[1]):
			var cy := base.y + 4.0 - float(k) * 3.6
			var rim := _ell(Vector2(x, cy + 2.2), 8.5, 3.6, 20)
			draw_colored_polygon(rim, Color(0.42, 0.28, 0.08))
			draw_rect(Rect2(x - 8.5, cy, 17.0, 2.2), Color(0.5, 0.34, 0.1))
			var top := _ell(Vector2(x, cy), 8.5, 3.6, 20)
			var cols := PackedColorArray()
			for q in top:
				cols.append(Color(1.0, 0.86, 0.48).lerp(Color(0.78, 0.56, 0.2), clampf((q.x - x + 8.5) / 17.0, 0.0, 1.0)))
			draw_polygon(top, cols)
			_outline(top, Color(0.12, 0.07, 0.02, 0.85), 1.0)
			draw_rect(Rect2(x - 2.0, cy - 1.0, 4.0, 2.0), Color(0.1, 0.06, 0.02))
	# ip: sikkelerin ortasından geçen kırmızı bağ
	draw_line(base + Vector2(-6, -6), base + Vector2(40, -4), Color(LazyFx.g("UI").ACCENT, 0.9), 1.5, true)


## Kawarimi kütüğü: yuvarlak ahşap kesit + gövde, mürekkep kontur ve halkalar; hak yoksa sönük
func _log(c: Control, p: Vector2, lit: bool) -> void:
	var a := 1.0 if lit else 0.3
	var ink := Color(0.06, 0.035, 0.02, 0.95 * a)
	var body := PackedVector2Array([p + Vector2(-7, -6.5), p + Vector2(10, -6.5), p + Vector2(10, 6.5), p + Vector2(-7, 6.5)])
	c.draw_polygon(body, PackedColorArray([Color(0.72, 0.48, 0.25, a), Color(0.62, 0.4, 0.2, a), Color(0.36, 0.21, 0.09, a), Color(0.42, 0.25, 0.11, a)]))
	c.draw_line(p + Vector2(-4, -2), p + Vector2(9, -2.5), Color(0.3, 0.16, 0.06, 0.6 * a), 1.0, true)   # kabuk çizgisi
	c.draw_line(p + Vector2(-3, 2.5), p + Vector2(9, 3), Color(0.3, 0.16, 0.06, 0.6 * a), 1.0, true)
	c.draw_polyline(PackedVector2Array([p + Vector2(-7, -6.5), p + Vector2(10, -6.5), p + Vector2(10, 6.5), p + Vector2(-7, 6.5)]), ink, 1.4, true)
	var cap := _ell(p + Vector2(-7, 0), 4.2, 6.5, 18)
	c.draw_colored_polygon(cap, Color(0.93, 0.76, 0.5, a))
	_poly_line(c, cap, ink, 1.4)
	c.draw_arc(p + Vector2(-7, 0), 2.2, 0.0, TAU, 12, Color(0.5, 0.3, 0.12, 0.8 * a), 1.0, true)


static func _poly_line(c: Control, pts: PackedVector2Array, col: Color, w: float) -> void:
	var q := pts.duplicate()
	q.append(pts[0])
	c.draw_polyline(q, col, w, true)


## Yaprak simgesi (Güç çubuğu: sıradaki Güç puanına ilerleme)
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
	var sh := PackedVector2Array()
	for q in clean:
		sh.append(q + Vector2(1, 1.5))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
	var lc := PackedColorArray()
	for q in clean:
		lc.append(Color(1.0, 0.76, 0.4).lerp(Color(0.85, 0.42, 0.14), clampf((q.y - c.y + s * 0.5) / s, 0.0, 1.0)))
	draw_polygon(clean, lc)
	_outline(clean, Color(0.12, 0.05, 0.02, 0.95), 1.3)
	draw_line(c + Vector2(-s * 0.6, 0).rotated(rot), c + Vector2(s * 0.35, 0).rotated(rot), Color(0.25, 0.12, 0.04, 0.8), 1.2, true)


## Elmas simge (klan kaynağı): gümüş çerçeve + renkli taş
func _gem(c: Vector2, col: Color) -> void:
	var outer := PackedVector2Array([c + Vector2(0, -11), c + Vector2(9, 0), c + Vector2(0, 11), c + Vector2(-9, 0)])
	var inner := PackedVector2Array([c + Vector2(0, -7), c + Vector2(5.5, 0), c + Vector2(0, 7), c + Vector2(-5.5, 0)])
	draw_colored_polygon(PackedVector2Array([outer[0] + Vector2(0, 2), outer[1] + Vector2(0, 2), outer[2] + Vector2(0, 2), outer[3] + Vector2(0, 2)]), Color(0, 0, 0, 0.45))
	draw_colored_polygon(outer, Color(0.05, 0.045, 0.04))
	_outline(outer, Color(LazyFx.g("UI").TEXT, 0.45), 1.0)
	draw_colored_polygon(inner, col)
	draw_line(c + Vector2(-2, -3), c + Vector2(1, -5), Color(1, 1, 1, 0.7), 1.2, true)
