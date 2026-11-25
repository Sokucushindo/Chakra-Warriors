class_name LoadingScreen
extends Control
## Yükleme ekranı (sumi-e). Referans: interfaceingame.com yükleme ekranları (Sekiro, Witcher 3, God of War, Assassin's Creed,
## Death Stranding) ortak düzeni: atmosferik sahne arka planı, sol altta başlık + çizgi + açıklamalı ipucu (dönerek değişir),
## sağ altta dönen küçük simge + aşama yazısı + ince ilerleme, logo geri planda.
## Bizim dilde: gölgelendiriciyle çizilen mürekkep dağ katmanları + kırmızı güneş + kayan sis, ensō dönen simge,
## ilerleme kırmızı fırça darbesi olarak uzar. main.gd "L" (Label) ve "B" (ProgressBar) adlarıyla günceller.

const BG_SHADER := """shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.045, 0.04, 0.036, 1.0);
uniform vec4 sun_col : source_color = vec4(0.8, 0.16, 0.11, 1.0);
uniform vec2 res = vec2(1920.0, 1080.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
// sırt profili: keskin tepeli (ridged) gürültü
float ridge(float x, float seed) {
	float v = 0.0; float a = 0.5; float f = 1.0;
	for (int i = 0; i < 5; i++) { float n = noise(vec2(x * f + seed, seed * 1.7)); n = 1.0 - abs(n * 2.0 - 1.0); v += a * n * n; f *= 2.1; a *= 0.48; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float asp = res.x / res.y;
	vec2 p = vec2(uv.x * asp, uv.y);
	// gök: koyu washi tonu, ufka doğru açılır
	vec3 col = mix(vec3(0.085, 0.078, 0.072), vec3(0.2, 0.188, 0.175), smoothstep(0.0, 0.7, uv.y));
	col *= 0.85 + 0.25 * fbm(p * 1.6 + vec2(TIME * 0.01, 0.0));
	// kırmızı güneş (mürekkep kâğıdına basılmış gibi kenarı hafif tırtıklı) + yumuşak hale
	vec2 sc = vec2(0.71 * asp, 0.3);
	float sd = length(p - sc) + (noise(p * 90.0) - 0.5) * 0.002;
	float sun = 1.0 - smoothstep(0.104, 0.108, sd);
	col = mix(col, sun_col.rgb * (0.78 + 0.1 * fbm(p * 12.0)), sun * 0.92);
	col += sun_col.rgb * 0.07 * exp(-max(sd - 0.1, 0.0) * 7.0);
	// dağ katmanları: uzak (açık, sisli) -> yakın (koyu mürekkep); çok yavaş paralaks
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float base = 0.5 + fi * 0.115;
		float amp = 0.3 - fi * 0.045;
		float freq = 1.0 + fi * 0.6;
		float x = p.x * freq + fi * 13.7 + TIME * 0.006 * (fi + 1.0);
		float h = base - ridge(x, fi * 7.3) * amp;
		h += (noise(vec2(p.x * 70.0, fi * 3.0)) - 0.5) * 0.004;   // fırça kenarı
		float inside = smoothstep(h - 0.0015, h + 0.0015, uv.y);
		float dep = uv.y - h;
		// mürekkep yoğunluğu: sırtta koyu, eteğe doğru sise karışır (yakın katman daha dolu)
		float dens = mix(exp(-dep * (10.0 - fi * 2.0)), 1.0, fi * 0.2);
		vec3 lc = mix(ink.rgb, vec3(0.3, 0.285, 0.27), mix(0.6, 0.0, fi / 3.0));
		float tex = 0.84 + 0.16 * fbm(vec2(p.x * 9.0, uv.y * 45.0) + fi);   // kuru fırça lifleri
		col = mix(col, lc * tex, inside * clamp(dens, 0.0, 1.0) * (0.72 + fi * 0.09));
		// katmanlar arası kayan sis
		float mist = smoothstep(0.0, 0.1, dep) * (1.0 - smoothstep(0.1, 0.28, dep));
		float fog = fbm(vec2(p.x * 1.4 - TIME * 0.025 * (fi + 1.0), uv.y * 3.0 + fi));
		col = mix(col, vec3(0.24, 0.23, 0.215), inside * mist * fog * 0.4);
	}
	// kâğıt dokusu, vinyet, alt kısım yazılar için koyu
	col += (hash(floor(FRAGCOORD.xy * 0.7)) - 0.5) * 0.02;
	vec2 q = uv - 0.5;
	col *= 1.0 - smoothstep(0.35, 0.95, length(q * vec2(1.1, 1.3))) * 0.7;
	col *= 1.0 - smoothstep(0.55, 1.0, uv.y) * 0.6;
	COLOR = vec4(col, 1.0);
}
"""

static var _shader: Shader

var _tip_i := 0
var _tip_box: VBoxContainer
var _bar: ProgressBar
var _stroke: Control
var _spin: TextureRect


## Oyunun gerçek mekanikleri (tuş adları oyuncunun atamasından)
static func tips() -> Array:
	var k = func(a: String) -> String: return Keys.name(a) if Keys.binds.has(a) else a
	return [
		["Kawarimi", "%s ile darbe gelmeden yerine kütük bırakıp kaçarsın. Sol üstteki kütükler kalan hakkını gösterir. Genjutsu'ya düştüğünde aynı tuş Kai olur." % k.call("substitute")],
		["Chakra şarjı", "%s tuşunu basılı tutarak chakra toplarsın. Jutsu attıkça ve meditasyon yaptıkça chakra kontrolün de gelişir." % k.call("charge")],
		["Mühür modu", "%s ile mühür moduna geç; 1-9, 0, - ve = tuşlarıyla mühürleri örerek jutsu yaparsın." % k.call("seal_mode")],
		["Duvar atılımı", "Duvardayken %s ile chakra harcayıp atılırsın. Duvar ve ağaç tırmanmak chakra kontrolünü geliştirir." % k.call("leap")],
		["Ustalık", "Yaptıkça gelişirsin: yumrukla vurdukça taijutsu, silahla vurdukça kenjutsu ilerler. Antrenman kuklasına vurmak iki kat sayılır."],
		["Klan teknikleri", "Klanının gizli teknikleri Güç'ün arttıkça kendiliğinden öğrenilir. Doğana uymayan teknikler, o doğayı ikinci doğa olarak alınca açılır."],
		["Görev masası", "Köyündeki görev masasından görev alırsın. Takip ettiğin hedefi %s ile değiştirebilirsin; ok ve ışık sütunu yolu gösterir." % k.call("track_next")],
		["Bingo Kitabı", "Kaçak ninjaların başında ödül var. Bingo Kitabı'ndan birini takibe alıp avlayabilirsin."],
		["Hızlı seyahat", "Haritadan keşfettiğin köylere, bölgelere ve yerlere ışınlanabilirsin."],
		["Ninja koşusu", "%s ile ninja koşusuna geçersin; havadayken aynı tuş seni ileri atar." % k.call("dash")],
	]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BG_SHADER
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm = ShaderMaterial.new()
	sm.shader = _shader
	bg.material = sm
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	resized.connect(func(): sm.set_shader_parameter("res", size))
	# logo: sol üst
	var logo = UI.vbox(0)
	logo.position = Vector2(96, 80)
	add_child(logo)
	logo.add_child(UI.label("忍 の 道", 20, UI.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var t = UI.label("CHAKRA WARRIORS", 58, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.add_theme_font_override("font", UI.title_font())
	logo.add_child(t)
	logo.add_child(UI.brush_line(220))
	# ipucu: sol alt
	_tip_box = UI.vbox(6)
	_tip_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tip_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip_box.offset_left = 96; _tip_box.offset_bottom = -92; _tip_box.offset_top = -92
	add_child(_tip_box)
	_tip_i = randi() % tips().size()
	_show_tip(false)
	# sağ alt: ensō döner, aşama yazısı, fırça ilerleme
	var br = Control.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-560, -170)
	br.size = Vector2(470, 110)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br)
	_spin = TextureRect.new()
	_spin.texture = UI._t("enso")
	_spin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spin.stretch_mode = TextureRect.STRETCH_SCALE
	_spin.size = Vector2(64, 64)
	_spin.position = Vector2(406, 0)
	_spin.pivot_offset = Vector2(32, 32)
	_spin.modulate = UI.ACCENT
	_spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.add_child(_spin)
	var l = UI.label("Dünya yükleniyor...", 20, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, true)
	l.name = "L"
	l.position = Vector2(0, 14)
	l.size = Vector2(394, 32)
	l.clip_text = true
	br.add_child(l)
	_bar = ProgressBar.new()
	_bar.name = "B"
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false   # değer taşıyıcı: çizimi fırça darbesi yapar
	add_child(_bar)
	_stroke = Control.new()
	_stroke.position = Vector2(0, 62)
	_stroke.size = Vector2(470, 40)
	_stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stroke.draw.connect(_draw_stroke)
	br.add_child(_stroke)
	_bar.value_changed.connect(func(_v): _stroke.queue_redraw())
	# ipucu döngüsü
	var tm = Timer.new()
	tm.wait_time = 7.0
	tm.autostart = true
	tm.process_mode = Node.PROCESS_MODE_ALWAYS
	tm.timeout.connect(func():
		_tip_i = (_tip_i + 1) % tips().size()
		_show_tip(true))
	add_child(tm)


func _process(dt: float) -> void:
	if _spin:
		_spin.rotation += dt * 1.6


## İlerleme: koyu fırça oluğu üstünde, değer kadar uzayan kırmızı fırça darbesi (kuyruk ucu her zaman görünür)
func _draw_stroke() -> void:
	var w := _stroke.size.x
	var h := _stroke.size.y
	_stroke.draw_style_box(UI.brush(Color(1, 0.95, 0.88, 0.07), "a", 0), Rect2(0, 0, w, h))   # oluk: tam boy soluk darbe
	var v := clampf(_bar.value, 0.0, 1.0)
	if v > 0.001:
		var fw := 140.0 + (w - 140.0) * v   # 9 dilimli doku en az baş + kuyruk kadar
		var a := clampf(v / 0.05, 0.0, 1.0)
		_stroke.draw_style_box(UI.brush(Color(UI.ACCENT, a), "a", 0), Rect2(0, 4, fw, h - 8))
	var pf = UI.font(true)
	var pt := "%d%%" % roundi(v * 100.0)
	_stroke.draw_string(pf, Vector2(w - pf.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x - 60, h + 8), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UI.TEXT, 0.6))


func _show_tip(fade: bool) -> void:
	var tl: Array = tips()[_tip_i]
	var fill = func() -> void:
		for c in _tip_box.get_children():
			c.queue_free()
		var head = UI.hbox(10)
		head.add_child(UI.seal("知", 26.0))
		head.add_child(UI.label("İPUCU", 14, UI.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
		_tip_box.add_child(head)
		var ti = UI.label(String(tl[0]), 32, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, true)
		ti.add_theme_font_override("font", UI.title_font())
		_tip_box.add_child(ti)
		_tip_box.add_child(UI.brush_line(130))
		var body = UI.label(String(tl[1]), 19, Color(UI.TEXT, 0.9))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(760, 0)
		_tip_box.add_child(body)
	if not fade:
		fill.call()
		return
	var tw = create_tween()
	tw.tween_property(_tip_box, "modulate:a", 0.0, 0.35)
	tw.tween_callback(fill)
	tw.tween_property(_tip_box, "modulate:a", 1.0, 0.45)
