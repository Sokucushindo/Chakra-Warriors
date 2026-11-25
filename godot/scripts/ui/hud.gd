extends CanvasLayer
## Oyun içi arayüz (autoload "Hud"): barlar, slotlar, mini harita, mesajlar, banner'lar, diyaloglar, dükkân.

var root: Control
var vit: VitalsUI   # sol üst oyuncu çerçevesi
var buff_lbl: RichTextLabel   # aktif güçlendirmeler: ad (süre): ne verdiği
var hp_trail_v := 0.0   # can düşüş izi (sarı)
var slots_box: HBoxContainer
var _ss_t := 0   # sanal (göz/canavar) slot girdilerini yenileme zamanı
var slot_nodes: Array = []
var side_nodes: Array = []   # yan yuvalar: [R alet, T değiştir, H merhem, Y hap] -> [kare, ad, bekleme]
var side_state: Array = []
const SIDE_KEYS := ["throw", "tool_next", "salve", "pill"]
var msg_lbl: Label
var msg_t = 0.0
var prompt_lbl: Label
var region_lbl: Label
var doom_lbl: Label      # dünya tehdidi sayacı (Mugen Tsukuyomi)
var region_name = ""
var objective_lbl: Label
var obj_progress_lbl: Label
var banner_box: Control
var seal_box: HBoxContainer
var boss: Node = null
var boss_box: VBoxContainer
var boss_bar_pb: ProgressBar
var boss_lbl: Label
var lock_ret: Control
var minimap: Control
var vignette: ColorRect
var darkness: ColorRect
var fps_lbl: Label
var cheat_lbl: Label   # açık hile varken "Hile açık" (Ayarlar > Hileler)
var dialog_layer: Control
var game_hud: Control
var map_tex: Texture2D
var compass: Control
var compass_lbl: Label
var compass_dir = Vector2.UP
var beam: MeshInstance3D
const SLOT_COUNT := 9
var slot_state: Array = []
var prompt_box: PanelContainer
var prompt_key: PanelContainer
var mm_region: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	game_hud = Control.new()
	game_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_hud.visible = false
	root.add_child(game_hud)
	map_tex = Game.world_map_tex()
	Game.map_ready.connect(func(): map_tex = Game.world_map_tex())
	Icons.ensure(self)
	Thumbs.ensure(self)
	_build_vitals()
	_build_slots()
	_build_texts()
	_build_minimap()
	_build_boss()
	_build_compass()
	_build_crosshair()
	dialog_layer = Control.new()
	dialog_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialog_layer)


## Nişangâh: ekran ortası = jutsuların gittiği nokta; nişangâh düşmanın üstündeyse kırmızı (jutsu ona kilitlenir)
var xhair: Control
var xhair_lock := false


func _build_crosshair() -> void:
	xhair = Control.new()
	xhair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xhair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	xhair.anchor_left = Player.AIM_SCREEN.x; xhair.anchor_right = Player.AIM_SCREEN.x
	xhair.anchor_top = Player.AIM_SCREEN.y; xhair.anchor_bottom = Player.AIM_SCREEN.y
	xhair.custom_minimum_size = Vector2(48, 48)
	xhair.offset_left = -24; xhair.offset_top = -24; xhair.offset_right = 24; xhair.offset_bottom = 24
	game_hud.add_child(xhair)
	xhair.draw.connect(func():
		xhair.draw_set_transform(Vector2(24, 24))
		var col = Color(1.0, 0.25, 0.2, 0.95) if xhair_lock else Color(1, 1, 1, 0.85)
		var sh = Color(0, 0, 0, 0.55)
		var g = 5.0 if xhair_lock else 7.0
		xhair.draw_circle(Vector2.ZERO, 3.2, sh)
		xhair.draw_circle(Vector2.ZERO, 2.0, col)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			xhair.draw_line(d * g, d * (g + 7.0), sh, 4.0)
			xhair.draw_line(d * g, d * (g + 7.0), col, 2.0)
		if xhair_lock:
			xhair.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, col, 1.5))


func show_game_hud(on: bool) -> void:
	game_hud.visible = on
	if beam and is_instance_valid(beam) and not on:
		beam.visible = false


# ------------------------------------------------------------------ yapım
func _build_vitals() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type canvas_item; uniform float amount = 0.0; void fragment(){ vec2 q = UV - 0.5; float v = smoothstep(0.25, 0.75, length(q)); COLOR = vec4(0.6, 0.0, 0.0, v * amount); }"
	sm.shader = sh
	vignette.material = sm
	game_hud.add_child(vignette)
	# Kokuangyo: görüş tamamen kararır (yalnız arayüz görünür)
	darkness = ColorRect.new()
	darkness.set_anchors_preset(Control.PRESET_FULL_RECT)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.color = Color(0.0, 0.0, 0.01, 0.0)
	# Kokuangyo (anime): her yer zifiri; ayak altında uzaklaşan gri girdap/odun damarı çizgileri — derin kuyunun dibi
	var dsm = ShaderMaterial.new()
	var dsh = Shader.new()
	dsh.code = "shader_type canvas_item;\nvoid fragment(){\n vec2 s = SCREEN_UV; float h = s.y - 0.42; vec3 c = vec3(0.0, 0.0, 0.01);\n if (h > 0.0) {\n  vec2 g = vec2((s.x - 0.5) * 1.78 / h, 1.0 / h) * 0.3;\n  float w = sin(g.x * 4.0 + sin(g.y * 2.6 + g.x * 1.4) * 2.6 + g.y * 1.1 + TIME * 0.15);\n  float ln = smoothstep(0.72, 0.95, w) * smoothstep(0.0, 0.2, h);\n  c += vec3(0.3) * ln;\n }\n COLOR = vec4(c, COLOR.a);\n}\n"
	dsm.shader = dsh
	darkness.material = dsm
	game_hud.add_child(darkness)
	# --- oyuncu çerçevesi (sol üst): shuriken portre + parşömen isim + metal çubuklar (VitalsUI, tamamı kod çizimi)
	vit = VitalsUI.new()
	vit.position = Vector2(22, 18)
	vit.scale = Vector2(0.72, 0.72)   # 720x239 → ~518x172
	game_hud.add_child(vit)
	buff_lbl = RichTextLabel.new()
	buff_lbl.bbcode_enabled = true
	buff_lbl.fit_content = true
	buff_lbl.scroll_active = false
	buff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_lbl.position = Vector2(26, 190)
	buff_lbl.size = Vector2(520, 10)
	buff_lbl.add_theme_font_size_override("normal_font_size", 14)
	buff_lbl.add_theme_constant_override("outline_size", 4)
	buff_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	game_hud.add_child(buff_lbl)
	fps_lbl = UI.label("", 13, Color(0.7, 0.9, 0.7))
	fps_lbl.position = Vector2(26, 190)
	game_hud.add_child(fps_lbl)
	cheat_lbl = UI.label("", 13, Color(1.0, 0.5, 0.35), HORIZONTAL_ALIGNMENT_LEFT, true)
	cheat_lbl.position = Vector2(26, 208)
	game_hud.add_child(cheat_lbl)
	# takım paneli (sol): takım arkadaşlarının adı + canı
	party_box = UI.vbox(6)
	party_box.position = Vector2(30, 330)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_hud.add_child(party_box)
	party_box.add_child(UI.label("TAKIM", 12, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	for i in 6:
		var prow = UI.vbox(1)
		prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl = UI.label("", 13, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		prow.add_child(nl)
		var hb = UI.hbox(6)
		var pbar = UI.bar(Color(0.4, 0.9, 0.45), 170, 7)
		hb.add_child(pbar)
		var tl = UI.label("", 11, UI.MUTED)
		hb.add_child(tl)
		prow.add_child(hb)
		party_box.add_child(prow)
		party_rows.append([prow, nl, pbar, tl])
	party_box.visible = false


var party_box: VBoxContainer
var party_rows: Array = []
var _party_t := 0.0


## Takım paneli: yanındaki takım arkadaşları (Genin takımı, dostlar, köy muhafızları) — ad + can
func _update_party(dt: float) -> void:
	_party_t -= dt
	if _party_t > 0.0 or party_box == null:
		return
	_party_t = 0.2
	var mates = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.has_meta("teammate") and f.get_meta("teammate") == true and is_instance_valid(f) and not f.is_dead():
			mates.append(f)
	party_box.visible = not mates.is_empty()
	for i in party_rows.size():
		var r: Array = party_rows[i]
		if i >= mates.size():
			r[0].visible = false
			continue
		var m = mates[i]
		r[0].visible = true
		var nm = String(m.get("display_name") if m.get("display_name") != null else "Takım")
		r[1].text = nm
		var bar: ProgressBar = r[2]
		bar.max_value = maxf(1.0, float(m.max_hp))
		bar.value = float(m.hp)
		var k = clampf(float(m.hp) / maxf(1.0, float(m.max_hp)), 0.0, 1.0)
		(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.35, 0.9, 0.35) if k > 0.5 else (Color(1, 0.8, 0.2) if k > 0.25 else Color(1, 0.3, 0.25))
		r[3].text = "%d" % int(m.hp)


var portrait_tex: Texture2D = null
var _portrait_key := ""
var _portrait_busy := false


## Oyuncunun yüz portresi: kendi modelinden (saç, alın bandı, kıyafet) baş çekimi, daire maskeli doku.
## Görünüş değişince (kıyafet, saç, göz) yeniden çekilir.
func _refresh_portrait() -> void:
	var pl = Game.player
	if pl == null or _portrait_busy or not pl.has_method("_look_with_age"):
		return
	var look: Dictionary = pl._look_with_age()
	var kl: Dictionary = look.duplicate()   # yaş sürekli küsuratla artar: portre yalnız görünür değişimde yenilensin
	for kk in ["years", "fat", "mus"]:
		if kl.has(kk):
			kl[kk] = snappedf(float(kl[kk]), 0.5 if kk == "years" else 0.1)
	var key = str(kl).md5_text()
	if key == _portrait_key:
		return
	_portrait_busy = true
	var pv: Control = Menus._model_preview(look, Vector3(0, 1.58, -0.95), Vector3(0, 1.52, 0), 26.0, false, Vector2(192, 192))
	pv.position = Vector2(-3000, -3000)   # ekran dışında çizilir
	add_child(pv)
	var mdl = pv.get_meta("model")
	for k in 2:
		await RenderingServer.frame_post_draw
	# yaşa göre boy değişir: kamerayı baş kemiğine göre yerleştir
	if mdl and mdl.get("skel"):
		var sk: Skeleton3D = mdl.skel
		var bi = sk.find_bone("Head")
		if bi >= 0:
			var hp = (sk.global_transform * sk.get_bone_global_pose(bi)).origin + Vector3(0, 0.03, 0)
			for ch in pv.get_child(0).get_children():
				if ch is Camera3D:
					var cp = hp + Vector3(0, 0.04, -0.85)
					ch.global_transform = Transform3D(Basis.looking_at(hp - cp), cp)
	for k in 3:
		await RenderingServer.frame_post_draw
	var sv: SubViewport = pv.get_child(0)
	var img: Image = sv.get_texture().get_image()
	pv.queue_free()
	if img:
		img.convert(Image.FORMAT_RGBA8)
		var n = img.get_width()
		var r = n * 0.5
		for y in n:
			for x in n:
				var d = Vector2(x + 0.5 - r, y + 0.5 - r).length()
				if d > r - 1.0:
					var c = img.get_pixel(x, y)
					c.a *= clampf(r - d, 0.0, 1.0)
					img.set_pixel(x, y, c)
		portrait_tex = ImageTexture.create_from_image(img)
		_portrait_key = key
		vit.portrait_tex = portrait_tex
		vit.queue_redraw()
	_portrait_busy = false


## Alt çubuk ölçüleri: yuva SLOT_PX kare; çizim 80 birimlik tasarımdan SS oranıyla küçülür
const SLOT_PX := 66.0
const SS := SLOT_PX / 80.0
const SLOT_GAP := 10.0
const GROUP_GAP := 26.0   # yan gruplarla jutsu dizisi arası (ayırıcı çizgi ortada)
const PAD := 12.0
const DOCK_BOTTOM := 10.0


func _build_slots() -> void:
	var sw = SLOT_COUNT * SLOT_PX + (SLOT_COUNT - 1) * SLOT_GAP
	var side_w = 2.0 * SLOT_PX + SLOT_GAP
	var half = sw * 0.5 + GROUP_GAP + side_w + PAD
	var dock_h = SLOT_PX + PAD * 2.0
	var top_y = -(dock_h + DOCK_BOTTOM) + PAD
	# çubuğun ortak cam zemini (yan yuvalar + 9 jutsu tek parça görünsün); iç boşluk dört yanda eşit
	var dock = Panel.new()
	var dsb = UI.ink_panel(0.8, 0, Color(0.02, 0.018, 0.016))   # yırtık kenarlı mürekkep zemin (oyuncu çerçevesiyle aynı dil)
	dock.add_theme_stylebox_override("panel", dsb)
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# mürekkep dokusunun yırtık kenarı ~18 px saydam: zemin yuvaların dışına taşsın diye dört yandan büyütülür
	dock.size = Vector2(half * 2.0 + 44.0, dock_h + 30.0)
	dock.position = Vector2(-half - 22.0, -(dock_h + DOCK_BOTTOM) - 15.0)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_hud.add_child(dock)
	for sgn in [-1.0, 1.0]:
		var dv = ColorRect.new()
		dv.color = Color(UI.ACCENT, 0.55)
		dv.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		dv.size = Vector2(1, SLOT_PX)
		dv.position = Vector2(sgn * (sw * 0.5 + GROUP_GAP * 0.5), top_y)
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_hud.add_child(dv)
	slots_box = UI.hbox(int(SLOT_GAP))
	slots_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	slots_box.position = Vector2(-sw * 0.5, top_y)
	game_hud.add_child(slots_box)
	for i in SLOT_COUNT:
		slot_nodes.append(_make_slot(slots_box, _draw_slot.bind(i)))
		slot_state.append({"el": "", "cd": 0.0, "max": 1.0, "ok": true, "empty": true})
	# sol: atılabilir alet (R) + değiştir (T), sağ: merhem (H) + hap (Y); jutsu yuvalarıyla aynı cam kare dili
	var left_box = UI.hbox(int(SLOT_GAP))
	left_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	left_box.position = Vector2(-sw * 0.5 - GROUP_GAP - side_w, top_y)
	game_hud.add_child(left_box)
	var right_box = UI.hbox(int(SLOT_GAP))
	right_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	right_box.position = Vector2(sw * 0.5 + GROUP_GAP, top_y)
	game_hud.add_child(right_box)
	for i in SIDE_KEYS.size():
		side_nodes.append(_make_slot(left_box if i < 2 else right_box, _draw_side.bind(i)))
		side_state.append({"empty": true, "icon": "", "col": UI.ELEMENT_COLORS[""], "cd": 0.0, "max": 1.0, "ok": true, "badge": "", "badge_col": Color.WHITE, "alt": ""})
	seal_box = UI.hbox(6)
	seal_box.set_anchors_preset(Control.PRESET_CENTER)
	seal_box.position = Vector2(-150, 120)
	game_hud.add_child(seal_box)


## Ortak yuva iskeleti: SLOT_PX kare çizim alanı + altta ad + ortada bekleme sayısı -> [kare, ad, bekleme]
func _make_slot(parent: Control, draw_cb: Callable) -> Array:
	var p = Control.new()
	p.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(draw_cb)
	var nm = UI.label("", 11, Color(0.93, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	nm.position = Vector2(2, SLOT_PX - 18.0)
	nm.size = Vector2(SLOT_PX - 4.0, 16)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_constant_override("outline_size", 3)
	nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	p.add_child(nm)
	var cd = UI.label("", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	cd.position = Vector2(0, SLOT_PX * 0.5 - 12.0)
	cd.size = Vector2(SLOT_PX, 24)
	cd.add_theme_constant_override("outline_size", 6)
	cd.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	p.add_child(cd)
	parent.add_child(p)
	return [p, nm, cd]


## Yuvarlak köşeli dikdörtgenin köşe noktaları (dolgu / çizgi için)
static func _rr_pts(r: Rect2, rad: float, seg := 6) -> PackedVector2Array:
	var pts = PackedVector2Array()
	# yarıçap kutunun yarısını aşarsa köşe yayları üst üste biner -> çokgen kendini keser, çizim hatası (yuva ad şeridi 24 / 13)
	rad = maxf(0.0, minf(rad, minf(r.size.x, r.size.y) * 0.5 - 0.5))
	var cs = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for c in 4:
		for s in seg + 1:
			var a = -PI * 0.5 + (c + float(s) / seg) * PI * 0.5
			pts.append(cs[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Dikey renk geçişli yuvarlak dikdörtgen
static func _rr_fill(p: Control, r: Rect2, rad: float, top: Color, bot: Color) -> void:
	var pts = _rr_pts(r, rad)
	var cols = PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bot, clampf((q.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	p.draw_polygon(pts, cols)


static func _rr_line(p: Control, r: Rect2, rad: float, col: Color, w: float) -> void:
	var pts = _rr_pts(r, rad)
	pts.append(pts[0])
	p.draw_polyline(pts, col, w, true)


## Ortak yuva çizimi (jutsu 1-9 ve yan R/T/H/Y): renk geçişli cam kare, simge ışıltısı + gölgesi, parlama,
## saat yönünde bekleme süresi, tuş rozeti, bekleme bitince kısa parlama.
## st: empty, icon, col, ok, cd, max, badge (sağ alt köşe metni), badge_col, alt (sağ üst ikinci tuş), tint, flash
func _paint_slot(p: Control, st: Dictionary, key_text: String) -> void:
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2(SS, SS))   # tasarım 80 birim; şekiller ölçeklenir, metin _txt_c ile keskin
	var sz = Vector2(80, 80)
	var box = Rect2(Vector2.ZERO, sz)
	var ec: Color = st["col"]
	var empty: bool = st["empty"]
	var is_ready: bool = (not empty) and st["ok"] and st["cd"] <= 0.0
	if not empty:
		var top = Color(ec.r * 0.22 + 0.05, ec.g * 0.22 + 0.045, ec.b * 0.22 + 0.04, 0.92) if st["ok"] else Color(0.1, 0.09, 0.085, 0.92)
		_rr_fill(p, box, 2.0, top, Color(0.03, 0.027, 0.025, 0.95))
		if st["ok"]:
			p.draw_circle(Vector2(40, 31), 24.0, Color(ec, 0.08))
		# ad şeridi: alt kenarda saydamdan koyuya geçiş (ad yazısı burada okunur)
		_rr_fill(p, Rect2(Vector2(1, 54), Vector2(78, 25)), 1.0, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.66))
		var col = Color(1, 1, 1, 0.97) if st["ok"] else Color(0.55, 0.55, 0.6, 0.85)
		var icr = Rect2(Vector2(17, 8), Vector2(46, 46))
		if st["icon"] == "swap":
			var dk = Color(0, 0, 0, 0.45)
			for k in 2:
				var o = Vector2(1.5, 2.5) if k == 0 else Vector2.ZERO
				var cc = dk if k == 0 else ec.lerp(Color.WHITE, 0.45)
				p.draw_colored_polygon(PackedVector2Array([Vector2(34, 17) + o, Vector2(34, 45) + o, Vector2(13, 31) + o]), cc)
				p.draw_colored_polygon(PackedVector2Array([Vector2(46, 17) + o, Vector2(46, 45) + o, Vector2(67, 31) + o]), cc)
		else:
			p.draw_texture_rect(Icons.tex(st["icon"]), Rect2(icr.position + Vector2(1.5, 2.5), icr.size), false, Color(0, 0, 0, 0.5))
			p.draw_texture_rect(Icons.tex(st["icon"]), icr, false, ec.lerp(Color.WHITE, 0.35) if st["ok"] else col)
	else:
		_rr_fill(p, box, 2.0, Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.4))
	# kenarlık: ince açık mürekkep çizgi; hazırsa element renginde; altta element rengi fırça şeridi
	if is_ready:
		_rr_line(p, box.grow(1.0), 2.0, Color(ec, 0.35), 3.0)
	_rr_line(p, box.grow(-0.75), 2.0, Color(UI.TEXT, 0.4) if not empty else Color(UI.TEXT, 0.16), 1.5)
	if not empty:
		p.draw_rect(Rect2(Vector2(3, 74), Vector2(74, 3)), Color(ec, 0.95))
	if st["cd"] > 0.0:
		var k = clampf(st["cd"] / maxf(0.01, st["max"]), 0.0, 1.0)
		var c = sz * 0.5
		var pts = PackedVector2Array([c])
		var n = 32
		for j in n + 1:
			var a = -PI * 0.5 + TAU * k * float(j) / n
			pts.append(c + Vector2(cos(a), sin(a)) * 56.0)
		# kareye kırp: köşeleri aşan noktaları sınırla
		for j in pts.size():
			pts[j] = pts[j].clamp(Vector2(2, 2), sz - Vector2(2, 2))
		p.draw_colored_polygon(pts, Color(0, 0, 0, 0.64))
		p.draw_line(c, pts[pts.size() - 1], Color(1, 1, 1, 0.4), 1.5, true)
	elif not st["ok"] and not empty:
		_rr_fill(p, box.grow(-2.0), 1.0, st.get("tint", Color(0.1, 0.2, 0.5, 0.35)), st.get("tint", Color(0.1, 0.2, 0.5, 0.35)))
	# bekleme bitti: kısa beyaz parlama
	var fl = 1.0 - float(Time.get_ticks_msec() - int(st.get("flash", -100000))) / 400.0
	if fl > 0.0 and not empty:
		_rr_fill(p, box, 2.0, Color(1, 1, 1, fl * 0.42), Color(ec, fl * 0.2))
		_rr_line(p, box.grow(1.0), 2.0, Color(1, 1, 1, fl * 0.9), 3.0)
	var f = UI.font(true)
	# tuş rozeti: koyu hap, ince çerçeve (uzun tuş adı küçülür)
	var fs = 12
	if _txt_w(f, key_text, fs) > 30.0:
		fs = 9
	var bw = maxf(21.0, _txt_w(f, key_text, fs) + 11.0)
	p.draw_style_box(UI._box(Color(0.03, 0.035, 0.05, 0.94), Color(1, 1, 1, 0.38 if not empty else 0.12), 1, 7, 0), Rect2(Vector2(3, 3), Vector2(bw, 20)))
	_txt_c(p, f, Vector2(3 + bw * 0.5, 13), key_text, fs, Color(UI.TEXT, 1.0 if not empty else 0.45))
	# ikinci tuş (ör. hap değiştirme): sağ üstte küçük altın rozet
	var alt: String = st.get("alt", "")
	if alt != "" and not empty:
		var ax = 3.0 + bw + 12.0
		p.draw_circle(Vector2(ax, 13), 9.5, Color(0, 0, 0, 0.55))
		p.draw_circle(Vector2(ax, 13), 8.5, Color(UI.ACCENT, 0.97))
		_txt_c(p, f, Vector2(ax, 13), alt, 10, UI.CREAM)
	# köşe rozeti (sağ üst): enerji bedeli / stok
	var bt: String = st.get("badge", "")
	if bt != "" and not empty:
		var tw = _txt_w(f, bt, 12) + 11.0
		p.draw_style_box(UI._box(Color(0.02, 0.025, 0.035, 0.85), Color(st.get("badge_col", Color.WHITE), 0.55), 1, 8, 0), Rect2(Vector2(77 - tw, 4), Vector2(tw, 18)))
		_txt_c(p, f, Vector2(77 - tw * 0.5, 13), bt, 12, st.get("badge_col", Color.WHITE))
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Yuva metni: font px = tasarım boyu x SS (en az 10); ölçek dönüşümü dışında çizilir (keskin)
func _fpx(fs: int) -> int:
	return maxi(10, roundi(fs * SS + 1.0))


func _txt_w(f: Font, t: String, fs: int) -> float:   # tasarım birimiyle genişlik
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _fpx(fs)).x / SS


func _txt_c(p: Control, f: Font, c: Vector2, t: String, fs: int, col: Color) -> void:   # c: tasarım koordinatında merkez
	var px = _fpx(fs)
	var w = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	p.draw_string(f, Vector2(c.x * SS - w * 0.5, c.y * SS + px * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2(SS, SS))


## Jutsu yuvası (1-9): element simgesi + enerji bedeli rozeti (chakra mavi / stamina yeşil / yetmezse kırmızı)
func _draw_slot(i: int) -> void:
	var st: Dictionary = slot_state[i]
	var d = st.duplicate()
	d["col"] = UI.ELEMENT_COLORS.get(st["el"], UI.ELEMENT_COLORS[""])
	d["icon"] = UI.ELEMENT_ICONS.get(st["el"], "chakra")
	var cost := int(roundf(float(st.get("cost", 0.0))))
	d["badge"] = str(cost) if cost > 0 else ""
	d["badge_col"] = (Color(1.0, 0.72, 0.35) if st.get("tai", false) else Color(0.55, 0.78, 1.0)) if st["ok"] else Color(1.0, 0.45, 0.4)
	_paint_slot(slot_nodes[i][0], d, Keys.name("slot%d" % (i + 1)))


## Yan yuva (R alet / T değiştir / H merhem / Y hap)
func _draw_side(i: int) -> void:
	_paint_slot(side_nodes[i][0], side_state[i], Keys.name(SIDE_KEYS[i]))



const TOOL_ICONS := {"agiz_kozu": "flame", "aobiko": "bomb", "inochi_kare": "potion", "genjutsu_kosui": "leaf", "genjutsu_yaku": "pill", "bijugan": "pill", "mushu_dokugiri": "bomb", "kosho_mimikazari": "flame", "hiko_tsubasa": "star", "yuki_ita": "arrow", "okarina": "leaf", "eiyu_mizu": "potion", "toge_dama": "bomb", "kemuri_fuda": "seal", "chusha_bari": "arrow", "kemuri_senkodan": "eye", "kunai": "kunai", "shuriken": "shuriken", "tag": "seal", "smoke": "bomb", "senbon": "arrow", "makibishi": "star", "hikaridama": "eye", "togarashi_dama": "flame", "kibaku_dama": "bomb", "hyodama": "bomb", "raizutsu": "bomb", "suzu": "star", "boenkyo": "eye", "bakusaidama": "bomb", "kibaku_fuda": "seal", "doku": "flame", "gedokuyaku": "pill", "kosen": "arrow", "sode_kunai": "kunai", "nuno_maki": "seal", "fuin_fuda": "seal", "kekkai_fuda": "seal"}
const PILL_COLS := {"zoketsugan": Color(0.85, 0.2, 0.22), "seishingan": Color(0.7, 0.4, 0.95), "pill": Color(1.0, 0.75, 0.4), "hap_horenzai": Color(0.5, 0.9, 0.5), "hap_kare": Color(1.0, 0.9, 0.4), "hap_togarashi": Color(1.0, 0.45, 0.4)}


## Yan yuvalar: [R] seçili alet, [T] alet değiştir, [H] merhem, [Y] hap; bekleme ve stok yuvanın üstünde
func _update_side(pl: Node, pr: Dictionary) -> void:
	var inv: Dictionary = pr.get("inventory", {})
	var scene = get_tree().current_scene
	var tool: String = pr.get("throw_sel", "kunai")
	var tcd = float(pl.combat.tool_cd.get(tool, 0.0)) if pl.combat else 0.0
	var tn = int(inv.get(tool, 0))
	_set_side(0, Lang.t(String(Data.items.get(tool, {"name": tool})["name"])), TOOL_ICONS.get(tool, "kunai"), Color(0.85, 0.88, 0.95), tcd, tn > 0, ("∞" if Stats.unlimited(tool) else str(tn)) if tn > 0 else "0")
	_set_side(1, Lang.t("Alet değiştir"), "swap", Color(0.62, 0.65, 0.72), 0.0, true, "")
	var scd = float(scene.salve_cooldown()) if scene.has_method("salve_cooldown") else 0.0
	var sn_ = int(inv.get("salve", 0))
	_set_side(2, Lang.t("Merhem"), "potion", Color(0.5, 0.9, 0.55), scd, sn_ > 0, str(sn_))
	var psel = ClanMech.pill_sel()
	var pcd = float(scene.pill_cooldown()) if scene.has_method("pill_cooldown") else 0.0
	if psel != "pill":
		pcd = ClanMech.aki_pill_left(psel)
	var many = ClanMech.pill_list().size() > 1
	_set_side(3, Lang.t(String(ClanMech.AKI_PILL_NAMES.get(psel, "Asker Hapı"))).split("(")[0].strip_edges(), "pill", PILL_COLS.get(psel, PILL_COLS["pill"]), pcd, true, "∞" if psel == "pill" else "", Keys.name("pill_next") if many else "")


## Yan yuvayı güncelle; görünüm değiştiyse yeniden çizdirir
func _set_side(i: int, nm: String, icon: String, col: Color, cd: float, ok: bool, badge: String, alt := "") -> void:
	var sn: Array = side_nodes[i]
	var st: Dictionary = side_state[i]
	sn[1].text = nm
	sn[2].text = ("%d" % ceili(cd)) if cd > 0.0 else ""
	var mx = maxf(float(st["max"]) if float(st["cd"]) > 0.0 else 0.0, cd)
	if float(st["cd"]) > 0.0 and cd <= 0.0 and not st["empty"]:
		st["flash"] = Time.get_ticks_msec()
	if st["empty"] or st["icon"] != icon or st["col"] != col or absf(st["cd"] - cd) > 0.001 or st["ok"] != ok or st["badge"] != badge or st["alt"] != alt or Time.get_ticks_msec() - int(st.get("flash", -100000)) < 420:
		st["empty"] = false; st["icon"] = icon; st["col"] = col; st["cd"] = cd; st["max"] = mx; st["ok"] = ok
		st["badge"] = badge; st["alt"] = alt
		st["badge_col"] = Color(0.9, 0.9, 0.95) if ok else Color(1.0, 0.45, 0.4)
		st["tint"] = Color(0.5, 0.08, 0.08, 0.4)
		sn[0].queue_redraw()


func _build_texts() -> void:
	msg_lbl = UI.label("", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	msg_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	msg_lbl.position = Vector2(-500, -210)
	msg_lbl.size = Vector2(1000, 30)
	game_hud.add_child(msg_lbl)
	# etkileşim ipucu: tuş rozeti + metin, mürekkep hap
	prompt_box = PanelContainer.new()
	var psb = UI.brush(Color(0, 0, 0, 0.72), "s", 7)
	psb.content_margin_left = 12; psb.content_margin_right = 34
	prompt_box.add_theme_stylebox_override("panel", psb)
	prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph = UI.hbox(10)
	prompt_box.add_child(ph)
	prompt_key = UI.key_badge("F", 19)
	ph.add_child(prompt_key)
	prompt_lbl = UI.label("", 21, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	ph.add_child(prompt_lbl)
	prompt_box.visible = false
	game_hud.add_child(prompt_box)
	region_lbl = UI.label("", 40, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	region_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	region_lbl.position = Vector2(-400, 122)
	region_lbl.size = Vector2(800, 60)
	region_lbl.modulate.a = 0.0
	game_hud.add_child(region_lbl)
	doom_lbl = UI.label("", 24, Color(1.0, 0.32, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	doom_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	doom_lbl.position = Vector2(-300, 84)
	doom_lbl.size = Vector2(600, 32)
	doom_lbl.visible = false
	game_hud.add_child(doom_lbl)
	# görev paneli (sağda, minimap altında)
	var obj = PanelContainer.new()
	var osb = UI._box(Color(0.03, 0.027, 0.025, 0.5), Color(0, 0, 0, 0), 0, 2, 14)
	osb.border_width_left = 3
	osb.border_color = Color(UI.ACCENT, 0.9)
	obj.add_theme_stylebox_override("panel", osb)
	obj.anchor_left = 1.0; obj.anchor_right = 1.0
	obj.offset_left = -392; obj.offset_right = -18; obj.offset_top = 312
	obj.custom_minimum_size = Vector2(374, 0)
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov = UI.vbox(4)
	obj.add_child(ov)
	ov.add_child(UI.icon_label("mission", "GÖREV", 13, UI.ACCENT))
	objective_lbl = UI.label("", 14, Color(UI.TEXT, 0.92))
	objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_lbl.custom_minimum_size = Vector2(346, 0)
	ov.add_child(objective_lbl)
	obj_progress_lbl = UI.label("", 14, UI.GOOD)
	obj_progress_lbl.visible = false
	ov.add_child(obj_progress_lbl)
	game_hud.add_child(obj)
	banner_box = Control.new()
	banner_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_hud.add_child(banner_box)
	lock_ret = Control.new()
	lock_ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_ret.draw.connect(func():
		var c = Color(1, 0.35, 0.25)
		lock_ret.draw_arc(Vector2.ZERO, 22, 0, TAU, 32, c, 3.0)
		for k in 4:
			var a = k * PI * 0.5 + Time.get_ticks_msec() * 0.003
			lock_ret.draw_line(Vector2(cos(a), sin(a)) * 16, Vector2(cos(a), sin(a)) * 30, c, 3.0))
	game_hud.add_child(lock_ret)


func _build_minimap() -> void:
	minimap = Control.new()
	minimap.anchor_left = 1.0; minimap.anchor_right = 1.0
	minimap.offset_left = -270; minimap.offset_right = -30; minimap.offset_top = 20; minimap.offset_bottom = 260
	minimap.custom_minimum_size = Vector2(240, 240)
	minimap.size = Vector2(240, 240)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# çerçeve gölgesi + mürekkep halkası
	var ring = Control.new()
	ring.size = Vector2(240, 240)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		ring.draw_circle(Vector2(120, 124), 126, Color(0, 0, 0, 0.3))
		ring.draw_circle(Vector2(120, 120), 124, Color(0.04, 0.035, 0.03, 0.85))
		ring.draw_arc(Vector2(120, 120), 121, 0.0, TAU, 96, Color(UI.ACCENT, 0.85), 2.0, true))
	minimap.add_child(ring)
	var tr = TextureRect.new()
	tr.texture = map_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(240, 240)
	tr.size = Vector2(240, 240)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 center; uniform float zoom; uniform float rot;
void fragment(){
	vec2 q = UV - 0.5;
	if (length(q) > 0.5) discard;
	float c = cos(rot), s = sin(rot);
	vec2 r = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
	vec2 uv = center + r * zoom;
	vec4 col = texture(TEXTURE, uv);
	col.rgb = mix(col.rgb, col.rgb * vec3(1.05, 1.0, 0.9), 0.5);
	float vig = smoothstep(0.3, 0.5, length(q));
	col.rgb *= 1.0 - vig * 0.35;
	float edge = smoothstep(0.465, 0.48, length(q)) - smoothstep(0.49, 0.5, length(q));
	COLOR = mix(col, vec4(0.05, 0.045, 0.04, 1.0), edge);   // mürekkep halka
}"""
	sm.shader = sh
	tr.material = sm
	minimap.add_child(tr)
	minimap.set_meta("mat", sm)
	minimap.set_meta("tex", tr)
	var over = Control.new()
	over.size = Vector2(240, 240)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(_draw_minimap_markers.bind(over))
	minimap.add_child(over)
	minimap.set_meta("over", over)
	# bölge adı şeridi (haritanın altında)
	var rp = PanelContainer.new()
	var rsb = UI._box(Color(0.04, 0.05, 0.07, 0.7), Color(1, 1, 1, 0.08), 1, 14, 5, 0.0)
	rsb.content_margin_left = 14; rsb.content_margin_right = 14
	rp.add_theme_stylebox_override("panel", rsb)
	rp.position = Vector2(10, 236)
	rp.custom_minimum_size = Vector2(220, 0)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_region = UI.label("", 14, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	mm_region.clip_text = true
	rp.add_child(mm_region)
	minimap.add_child(rp)
	game_hud.add_child(minimap)


# ------------------------------------------------------------------ hedef oku (pusula) + dünyadaki ışık sütunu
func _build_compass() -> void:
	compass = Control.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-170, 14)
	compass.size = Vector2(340, 96)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.draw.connect(_draw_compass)
	game_hud.add_child(compass)
	compass_lbl = UI.label("", 18, Color(1, 0.92, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	compass_lbl.position = Vector2(0, 62)
	compass_lbl.size = Vector2(340, 28)
	compass.add_child(compass_lbl)


func _draw_compass() -> void:
	var c = Vector2(170, 32)
	compass.draw_circle(c, 29, Color(0.05, 0.04, 0.06, 0.6))
	compass.draw_arc(c, 29, 0, TAU, 40, Color(0.96, 0.55, 0.16, 0.9), 2.5)
	var d = compass_dir.normalized()
	var side = Vector2(-d.y, d.x)
	var tip = c + d * 24
	var back = c - d * 14
	var pts = PackedVector2Array([tip, back + side * 13, c - d * 6, back - side * 13])
	compass.draw_colored_polygon(pts, Color(1, 0.8, 0.2))
	compass.draw_polyline(PackedVector2Array([tip, back + side * 13, c - d * 6, back - side * 13, tip]), Color(0.25, 0.1, 0.0), 2.0)


## Hedefin kameraya göre ekrandaki yönü (yukarı = kameranın baktığı yön); minimap ile aynı dönüşüm
func _target_screen_dir(pl: Node3D, wp: Vector3) -> Vector2:
	var d = Vector2(wp.x - pl.global_position.x, wp.z - pl.global_position.z)
	return d.rotated(deg_to_rad(pl.yaw))


func _update_objective_pointer(pl: Node3D) -> void:
	var on = Missions.has_marker and not Game.paused
	compass.visible = on
	if on:
		var wp: Vector3 = Missions.target_marker
		compass_dir = _target_screen_dir(pl, wp)
		var dist = Vector2(wp.x - pl.global_position.x, wp.z - pl.global_position.z).length()
		var nm: String = Missions.target_name if Missions.target_name != "" else "Hedef"
		compass_lbl.text = "%s — %d m" % [Lang.t(nm), int(dist)] if dist > 6.0 else Lang.t("%s — buradasın") % Lang.t(nm)
		compass.position.y = 84.0 if boss_box.visible else 14.0
		compass.queue_redraw()
	# dünyadaki ışık sütunu
	if beam == null or not is_instance_valid(beam):
		if not Missions.has_marker or pl.get_parent() == null:
			return
		beam = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 1.6
		cm.bottom_radius = 1.6
		cm.height = 260.0
		cm.radial_segments = 16
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		beam.mesh = cm
		var sm = ShaderMaterial.new()
		sm.shader = load("res://shaders/beam.gdshader")
		beam.material_override = sm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pl.get_parent().add_child(beam)
	beam.visible = Missions.has_marker
	if beam.visible:
		var tp: Vector3 = Missions.target_marker
		beam.global_position = Vector3(tp.x, Game.terrain_height(tp.x, tp.z) + 130.0, tp.z)
		var dist = Vector2(tp.x - pl.global_position.x, tp.z - pl.global_position.z).length()
		(beam.material_override as ShaderMaterial).set_shader_parameter("fade", clampf((dist - 8.0) / 14.0, 0.0, 1.0))


func _build_boss() -> void:
	boss_box = UI.vbox(3)
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-310, 22)
	boss_lbl = UI.label("", 22, Color(1, 0.62, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	boss_lbl.custom_minimum_size = Vector2(620, 0)
	boss_bar_pb = UI.bar(Color(0.9, 0.16, 0.2), 620, 20)
	boss_box.add_child(boss_lbl)
	boss_box.add_child(boss_bar_pb)
	boss_box.visible = false
	game_hud.add_child(boss_box)


# ------------------------------------------------------------------ API
## Dünya tehdidi sayacı (boş metin gizler)
func doom(text: String) -> void:
	if doom_lbl == null:
		return
	doom_lbl.visible = text != ""
	doom_lbl.text = text


func msg(text: String, col := Color(1, 1, 1), dur := 3.5) -> void:
	msg_lbl.text = Keys.fix(text)
	msg_lbl.modulate = col
	msg_t = dur


func float_text(text: String, col: Color) -> void:
	var l = UI.label(text, 24, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(120 + randf_range(-30, 30), -40 + randf_range(-20, 20))
	l.pivot_offset = Vector2(40, 15)
	l.scale = Vector2.ONE * 1.6
	game_hud.add_child(l)
	var tw = l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 70, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


## Sinematik afiş: ince altın çizgiler arasında büyük başlık, yumuşak kararma
func banner(title: String, sub: String, col: Color) -> void:
	for c in banner_box.get_children():
		c.queue_free()
	var root = Control.new()
	# ekranın üstünde, hedef okunun / etiketinin hemen altında ortalı (oyuncunun üstünü kapatmaz)
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.13
	root.anchor_bottom = 0.13
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(root)
	var shade = TextureRect.new()
	var gt = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.add_point(0.5, Color(0.01, 0.015, 0.03, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(-560, -12)
	shade.size = Vector2(1120, 96)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	for y in [0.0, 72.0]:
		var ln = ColorRect.new()
		ln.color = Color(col, 0.85)
		ln.position = Vector2(-170, y)
		ln.size = Vector2(340, 2)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ln)
	var t = UI.label(title, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	t.position = Vector2(-560, 5)
	t.size = Vector2(1120, 38)
	root.add_child(t)
	var s2 = UI.label(sub, 14, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, true)
	s2.position = Vector2(-560, 46)
	s2.size = Vector2(1120, 22)
	root.add_child(s2)
	root.modulate.a = 0.0
	root.scale = Vector2(1.06, 1.06)
	var tw = root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.25)
	tw.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(root, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(root.queue_free)


func show_seals(seals: Array) -> void:
	for c in seal_box.get_children():
		c.queue_free()
	for i in seals.size():
		var l = UI.label(seals[i], 18, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		l.modulate.a = 0.0
		seal_box.add_child(l)
		var tw = l.create_tween()
		tw.tween_interval(i * 0.075)
		tw.tween_property(l, "modulate:a", 1.0, 0.05)
		tw.tween_interval(0.8)
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)


func objective_changed() -> void:
	if Game.profile.is_empty():
		return
	var s = Progress.story()
	var t: String = Progress.objective_text()
	var m: Dictionary = Game.profile.get("active_mission", {})
	if not m.is_empty():
		t += "\n\n[%s] %s: %s (%d/%d)" % [m["rank"], Lang.t(String(m["title"])), Lang.t(String(m["desc"])), m.get("progress", 0), m["count"]]
	objective_lbl.text = t
	obj_progress_lbl.text = ""
	obj_progress_lbl.visible = false


func objective_progress(t: String) -> void:
	obj_progress_lbl.text = t
	obj_progress_lbl.visible = t != ""


func boss_bar(b: Node) -> void:
	boss = b
	boss_box.visible = b != null and is_instance_valid(b)
	if boss_box.visible:
		boss_lbl.text = b.display_name
		boss_bar_pb.max_value = b.max_hp
		boss_bar_pb.value = b.hp


# ------------------------------------------------------------------ diyalog / dükkân
## Görsel roman tarzı diyalog: altta cam kutu, solda konuşanın portresi, isim plakası, daktilo metin, hap seçenekler
var forced_speaker: Node3D = null   # hizmet noktasının bağlı olduğu kişi (konuşma kamerası onu hedefler)


var last_dialog := ""   # son diyalog metni (testler ve hata ayıklama)
var last_options: Array = []
func dialog(title: String, text: String, options: Array) -> void:
	if is_instance_valid(Ceremony.cur) and not Ceremony.cur.dialogs_ok:
		Ceremony.cur.queued.append([title, text, options])   # tören sürerken açılan pencere (takım haberi vb.) törenden sonra
		return
	last_dialog = text
	last_options = options
	# görev masası ve bingo kitabı kendi ekranlarında
	if title.begins_with("Görev Masası — ") and Missions.board_village != "":
		show_mission_board(Missions.board_village)
		return
	if title.begins_with("BINGO KİTABI"):
		Menus.bingo_book(get_tree().current_scene)
		return
	close_dialog()
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_layer.add_child(root)
	root.set_meta("dialog", true)
	# alttan koyulaşan degrade
	var grad = TextureRect.new()
	var gt = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.85))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -420
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var many = options.size() > 4
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.ink_panel(0.88, 22))
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.custom_minimum_size = Vector2(1180, 230)
	box.position = Vector2(-590, -280 - (180 if many else 0))
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN   # içerik uzarsa kutu yukarı büyür (seçenekler ekran dışına kaçmaz)
	root.add_child(box)
	var h = UI.hbox(24)
	box.add_child(h)
	h.add_child(_dialog_portrait(title))
	var v = UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var plate = UI.label(title, 24, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(plate)
	var pl = UI.brush_line(110)
	pl.custom_minimum_size.y = 10
	v.add_child(pl)
	var body = UI.label(text, 19, UI.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560 if not many else 900, 0)
	if text.length() > 420 or text.count("
") > 7:
		# uzun metin: kaydırılabilir alan (kutu ekrandan taşmasın)
		var bsc = ScrollContainer.new()
		bsc.custom_minimum_size = Vector2(560 if not many else 900, 220)
		bsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(bsc)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bsc.add_child(body)
	else:
		v.add_child(body)
	# daktilo efekti (tıklayınca tamamlanır)
	body.visible_ratio = 0.0
	var tw = body.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var talk_dur = clampf(text.length() / 70.0, 0.25, 2.2)
	tw.tween_property(body, "visible_ratio", 1.0, talk_dur)
	# RPG konuşma kamerası: konuşanın yüzüne; yazı bitince (cevap seçerken) oyuncunun yüzüne döner
	if Game.player and not Game.paused:
		var sp = forced_speaker if (forced_speaker != null and is_instance_valid(forced_speaker)) else _near_talker(Game.player)
		forced_speaker = null
		if sp:
			var tc = TalkCam.ensure()
			tc.begin(sp, talk_dur)
			if not options.is_empty():
				tw.tween_callback(func(): if is_instance_valid(tc): tc.to_player()).set_delay(0.9)
	box.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			tw.kill()
			body.visible_ratio = 1.0)
	var opt_parent: Container
	if many:
		var sc = ScrollContainer.new()
		sc.custom_minimum_size = Vector2(900, 200)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(sc)
		var ov = UI.vbox(8)
		ov.custom_minimum_size = Vector2(880, 0)
		sc.add_child(ov)
		opt_parent = ov
	else:
		var ov = UI.vbox(8)
		ov.custom_minimum_size = Vector2(380, 0)
		ov.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(ov)
		opt_parent = ov
	for o in options:
		var b = _pill(String(o["label"]), func():
			close_dialog()
			o["cb"].call(), 860 if many else 380)
		if o.has("tip"):
			b.tooltip_text = o["tip"]
		opt_parent.add_child(b)
	var cl = _pill("Kapat [Esc]", close_dialog, 860 if many else 380, true)
	opt_parent.add_child(cl)
	box.modulate.a = 0.0
	var t2 = box.create_tween().set_parallel(true)
	t2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t2.tween_property(box, "modulate:a", 1.0, 0.16)
	# yerleşimden sonra: kutunun altı ekranın içinde kalsın
	box.resized.connect(func():
		var vh = box.get_viewport_rect().size.y
		if box.global_position.y + box.size.y > vh - 30.0:
			box.global_position.y = maxf(20.0, vh - 30.0 - box.size.y))


## Diyalog seçeneği: sade satır, üzerine gelince kırmızı fırça darbesi
func _pill(text: String, cb: Callable, w: float, muted := false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_override("font", UI.font(not muted))
	b.add_theme_font_size_override("font_size", 16)
	var n = UI.brush(Color(0, 0, 0, 0.3 if muted else 0.6), "a", 8)
	n.content_margin_left = 22
	var hv = UI.brush(UI.ACCENT, "a", 8)
	hv.content_margin_left = 22
	for k in [["normal", n], ["hover", hv], ["pressed", hv], ["focus", hv]]:
		b.add_theme_stylebox_override(k[0], k[1])
	b.add_theme_color_override("font_color", UI.MUTED if muted else UI.TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.93))
	b.add_theme_color_override("font_focus_color", Color(1, 0.97, 0.93))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.97, 0.93))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.15))
	return b


## Konuşanın portresi: yakındaki NPC ise yüzü canlı çizilir, değilse amblem
func _dialog_portrait(title: String) -> Control:
	var frame = Panel.new()
	frame.custom_minimum_size = Vector2(170, 170)
	frame.add_theme_stylebox_override("panel", UI._box(Color(0.03, 0.027, 0.025, 0.9), Color(UI.ACCENT, 0.85), 2, 85, 0))
	frame.clip_contents = true
	var who: Node = null
	if Game.player:
		for c in get_tree().get_nodes_in_group("talkers"):
			if c.get("display") == title and c.global_position.distance_to(Game.player.global_position) < 8.0:
				who = c
				break
	if who != null and who.get("look") is Dictionary:
		var lk: Dictionary = who.look.duplicate()
		var pv = Menus._model_preview(lk, Vector3(0, 1.56, -1.15), Vector3(0, 1.5, 0), 28.0, false, Vector2(162, 162))
		pv.position = Vector2(4, 4)
		frame.add_child(pv)
		var mdl = pv.get_meta("model")
		if mdl:
			mdl.play("talk")
	else:
		var ic = Icons.view("person" if title.length() < 26 else "scroll", 86, Color(UI.GOLD, 0.8))
		ic.position = Vector2(42, 36)
		frame.add_child(ic)
	return frame


func close_dialog() -> void:
	for c in dialog_layer.get_children():
		c.queue_free()
	Game.ui_open = false
	if not Game.paused and Game.player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func dialog_open() -> bool:
	return dialog_layer.get_child_count() > 0


## Görev masası: ahşap pano + asılı parşömenler (missions.gd çağırır)
func show_mission_board(village_id: String) -> void:
	Menus.mission_board(village_id)


func shop(title: String, items: Array) -> void:
	var entries = []
	for id in items:
		var it: Dictionary = Data.items.get(id, {})
		if it.is_empty():
			continue
		var locked = false
		var lock_text = ""
		if it.get("kind", "") == "scroll":
			var j: Dictionary = Data.jutsu.get(it.get("jutsu", ""), {})
			if String(j.get("element", "")) != "" and not j["element"] in Game.profile["elements"]:
				locked = true
				lock_text = "Bu parşömen %s doğası olanlar için." % Menus._el_name(String(j["element"]))
			elif int(Game.profile["level"]) < int(j.get("level", 1)):
				locked = true
				lock_text = "Güç %d gerekli." % int(j.get("level", 1))
			elif it.get("jutsu", "") in Game.profile["learned"]:
				locked = true
				lock_text = "Bunu zaten biliyorsun."
		var iid = id
		entries.append({"id": id, "name": it["name"], "price": Stats.price(int(it["price"])), "desc": it.get("desc", ""), "stats": "",
			"locked": locked, "lock_text": lock_text, "owned": int(Game.profile["inventory"].get(id, 0)), "unlimited": Stats.unlimited(id), "rarity": 1 if it.get("kind", "") == "scroll" else 0,
			"view": func(): return Thumbs.item_view(iid, 96)})
	Menus.shop_screen(title, entries, func(id): _buy(id, title, items), _sell_cb(title, func(): shop(title, items)))


const SHOP_SELL := preload("res://scripts/core/shop_sell.gd")


## Dükkânın "Eşya sat" düğmesi: bu tezgâh mal alıyorsa satış ekranını açar (back: alış ekranına dön); almıyorsa boş
func _sell_cb(title: String, back: Callable) -> Callable:
	var buyer = SHOP_SELL.buyer_of(title)
	if buyer == "":
		return Callable()
	return func(): Menus.sell_screen(title, buyer, back)


## Ekipman dükkânı: silah ve kıyafetler (alınca Tab > Ekipman'dan giyilir)
func gear_shop(title: String, ids: Array) -> void:
	var pr = Game.profile
	Gear.ensure(pr)
	var entries = []
	for id in ids:
		var it = Gear.item(id)
		if it.is_empty():
			continue
		var have = 0
		for g in pr["gear"]:
			if g["id"] == id:
				have += 1
		var why: String = Gear.req_text(id, pr)   # rütbe, köy, klan: giyemeyeceğin şey satın alınamaz
		var locked = why != ""
		var gid = id
		entries.append({"id": id, "name": it["name"], "price": Stats.price(int(it.get("price", 0))), "desc": it.get("desc", ""), "stats": Gear.stats_text(id),
			"locked": locked, "lock_text": why, "try_on": func(): return Gear.try_on_look(gid), "owned": have, "rarity": UI.rarity_of_gear(id),
			"view": func(): return Thumbs.gear_view(gid, 96)})
	Menus.shop_screen(title, entries, func(id):
		var it = Gear.item(id)
		if int(pr["ryo"]) < Stats.price(int(it["price"])):
			msg("Yeterli Ryō yok!", Color(1, 0.5, 0.4))
		else:
			Progress.add_ryo(-Stats.price(int(it["price"])))
			Gear.grant(pr, id)
			if it.has("unique"):   # benzersiz: bir kez satılır
				if not pr.has("unique_bought"):
					pr["unique_bought"] = []
				pr["unique_bought"].append(id)
				ids = ids.filter(func(x): return x != id)
			Sfx.play("coin")
			msg("%s alındı! Giymek için: Tab > Ekipman" % it["name"], Color(0.6, 1, 0.6))
		gear_shop(title, ids), _sell_cb(title, func(): gear_shop(title, ids)))


func _buy(id: String, title: String, items: Array) -> void:
	var it: Dictionary = Data.items[id]
	if int(Game.profile["ryo"]) < Stats.price(int(it["price"])):
		msg("Yeterli Ryō yok!", Color(1, 0.5, 0.4))
	else:
		if it["kind"] == "scroll":
			var jid: String = it["jutsu"]
			var j: Dictionary = Data.jutsu[jid]
			if j["element"] != "" and not j["element"] in Game.profile["elements"]:
				msg("Bu parşömen %s elementine sahip olanlar için." % j["element"], Color(1, 0.6, 0.4))
				shop(title, items)
				return
			if int(Game.profile["level"]) < int(j["level"]):
				msg("Bu parşömen için Güç %d gerekli." % j["level"], Color(1, 0.6, 0.4))
				shop(title, items)
				return
			if jid in Game.profile["learned"]:
				msg("Bunu zaten biliyorsun.", Color(1, 0.8, 0.5))
				shop(title, items)
				return
			Progress.add_ryo(-Stats.price(int(it["price"])))
			Progress.learn(jid)
		elif Stats.unlimited(id):
			# aletler bir kez alınır, sonra sınırsız (her birinin 30 sn bekleme süresi var); Asker Hapı zaten bitmez
			if id == "pill":
				msg("Asker Hapı bitmez: bekleme süresiyle kullanılır.", Color(1, 0.85, 0.5))
				shop(title, items)
				return
			if int(Game.profile["inventory"].get(id, 0)) > 0:
				msg("%s zaten sende (sınırsız, 30 sn bekleme)." % it["name"], Color(1, 0.85, 0.5))
				shop(title, items)
				return
			Progress.add_ryo(-Stats.price(int(it["price"])))
			Game.profile["inventory"][id] = 1
			Game.profile["throw_sel"] = id
			Sfx.play("coin")
			msg("%s alındı — artık sınırsız! [R] fırlat, [T] değiştir." % it["name"], Color(0.6, 1, 0.6))
		else:
			Progress.add_ryo(-Stats.price(int(it["price"])))
			var n = 5 if id in ["kunai", "shuriken"] else 1
			var cap = Stats.carry_cap(Game.profile, id)
			if int(Game.profile["inventory"].get(id, 0)) >= cap:
				Progress.add_ryo(Stats.price(int(it["price"])))  # iade
				msg("Çantan dolu (en fazla %d). Fūin Depolama yeteneği kapasiteyi artırır." % cap, Color(1, 0.7, 0.4))
				shop(title, items)
				return
			Game.profile["inventory"][id] = mini(cap, int(Game.profile["inventory"].get(id, 0)) + n)
			Sfx.play("coin")
	shop(title, items)


# ------------------------------------------------------------------ güncelleme
var _ui_stuck := 0.0


## Arayüz bekçisi: hiçbir pencere / menü açık değilken "arayüz açık", görünür fare ya da duraklama kalmışsa (bir akış penceresini
## kapatmadan değiştirip bıraktıysa: Rinnegan uyanışı vb.) oyun donmuş gibi kalıyordu, ESC düzeltiyordu — yarım saniye sonra kendisi toparlar
func _ui_watchdog(dt: float) -> void:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or not pl.is_inside_tree():
		_ui_stuck = 0.0
		return
	var open := false
	for c in dialog_layer.get_children():
		if not c.is_queued_for_deletion():
			open = true
			break
	# duraklama menüsü / sınav kartı da bu katmanda: katman boşken oyun duraklamış kalmışsa (kartı başka bir pencere silip
	# devam ettirmeden bıraktıysa) ekranda hiçbir şey yokken oyun donuk kalıyordu
	var bad = not open and (Game.paused or Game.ui_open or get_tree().paused or (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.window_is_focused()))
	if not bad:
		_ui_stuck = 0.0
		return
	_ui_stuck += dt
	if _ui_stuck < 0.5:
		return
	_ui_stuck = 0.0
	if Game.paused:
		var m = get_tree().current_scene
		if m and m.has_method("resume"):
			m.resume()   # ESC'nin yaptığının aynısı
			return
		Game.paused = false
	Game.ui_open = false
	if get_tree().paused:
		get_tree().paused = false
	if DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(dt: float) -> void:
	_ui_watchdog(dt)
	if not game_hud.visible:
		return
	var pl = Game.player
	if pl == null:
		return
	var pr = Game.profile
	fps_lbl.text = "FPS %d" % Engine.get_frames_per_second() if Game.settings["show_fps"] else ""
	var cheat_on = Cheats.any_on()
	cheat_lbl.text = "Hile açık" if cheat_on else ""
	cheat_lbl.position.y = 208.0 if Game.settings["show_fps"] else 190.0
	if buff_lbl:
		buff_lbl.position.y = cheat_lbl.position.y + 18.0 if cheat_on else 190.0   # güçlendirme listesi yazının altına
	if xhair:
		var lk = Jutsu.soft_target(pl) != null
		if lk != xhair_lock:
			xhair_lock = lk
		xhair.queue_redraw()
	var rname: String = Data.RANKS[int(pr.get("rank", 0))]
	if Orgs.is_rogue():
		rname = "%s (%s-rank)" % [Lang.t(Orgs.rogue_rank_name()), String(Orgs.ROGUE_RANKS[Orgs.rogue_rank()][2])]   # kaçakta köy rütbesi yok
	if buff_lbl:
		var bl = []
		for ln in Buffs.lines():
			bl.append("[color=#ffd27a]%s[/color]%s: %s" % [Lang.t(String(ln[0])), (" (%ds)" % int(ln[2])) if ln[2] >= 0.0 else "", Lang.t(String(ln[1]))])
		buff_lbl.text = "\n".join(bl)
	_update_party(dt)
	var hk = clampf(pl.hp / maxf(1.0, pl.max_hp), 0.0, 1.0)
	var hcol = Color(0.45, 0.74, 0.4) if hk > 0.5 else (Color(0.9, 0.7, 0.3) if hk > 0.25 else Color(0.9, 0.26, 0.2))   # mürekkep tonları
	hp_trail_v = move_toward(hp_trail_v, pl.hp, dt * pl.max_hp * 0.35) if hp_trail_v > pl.hp else pl.hp
	if Engine.get_process_frames() % 60 == 0:
		_refresh_portrait()
	var elm: String = pr.get("elements", [""])[0] if not pr.get("elements", []).is_empty() else ""
	vit.el_col = UI.ELEMENT_COLORS.get(elm, UI.GOLD)
	var cm = ClanMech.meter()
	var clan := {}
	if not cm.is_empty():
		clan = {"label": Lang.t(String(cm["label"])), "v": cm["v"], "max": cm["max"], "col": cm["col"]}
	var combat = pl.combat
	vit.set_state({"name": String(pr.get("name", "")), "rank_txt": Lang.t("%s  •  Güç %d") % [Lang.upper(Lang.t(rname)), int(pr.get("level", 1))],
		"hp": pl.hp, "hp_max": pl.max_hp, "hp_col": hcol, "trail": hp_trail_v, "ck": pl.chakra, "ck_max": pl.max_chakra,
		"sta": pl.stamina, "sta_max": pl.max_stamina, "xp": Mastery.power_progress(pr), "ryo": int(pr.get("ryo", 0)),
		"subs": combat.sub_bars if combat else 0, "rk": int(pr.get("rank", 0)), "clan": clan})
	var comb = pl.combat
	(vignette.material as ShaderMaterial).set_shader_parameter("amount", clampf(1.0 - pl.hp / pl.max_hp * 2.5, 0.0, 0.8))
	var dk = 0.97 if pl.has_status("kokuangyo") else 0.0
	darkness.color.a = lerpf(darkness.color.a, dk, 0.25)
	var slots: Array = pr.get("slots", [])
	for i in SLOT_COUNT:
		var jid = slots[i] if i < slots.size() else ""
		var sn: Array = slot_nodes[i]
		var st: Dictionary = slot_state[i]
		if jid == null or jid == "":
			sn[1].text = ""; sn[2].text = ""
			if not st["empty"]:
				st["empty"] = true; st["cd"] = 0.0
				sn[0].queue_redraw()
			continue
		if (jid in SpecialSlots.EYE_IDS or ((jid in SpecialSlots.BIJUU_IDS or jid in SpecialSlots.SUS_IDS) and not Data.jutsu.has(jid))) and Time.get_ticks_msec() > _ss_t:   # göz yuvası: tarz değişince ad da değişsin
			_ss_t = Time.get_ticks_msec() + 2000
			SpecialSlots.refresh(pr)
		var j: Dictionary = Data.jutsu.get(jid, {})
		sn[1].text = Lang.t(String(j.get("name", jid))).split(":")[-1].split("(")[0].strip_edges()
		var cd: float = SpecialSlots.cooldown(pl, jid) if j.has("virtual") else (comb.cooldowns.get(jid, 0.0) if comb else 0.0)
		var cost = PlayerCombat.cast_cost(j)
		var tai = Stats.is_taijutsu(j)
		var ok = (pl.stamina if tai else pl.chakra) >= cost
		sn[2].text = ("%.1f" % cd) if cd > 0.0 else ""
		sn[2].add_theme_color_override("font_color", Color(1, 1, 1))
		var el = String(j.get("element", ""))
		var mx = maxf(maxf(Combat.jutsu_cd(j), float(comb.cd_max.get(jid, 0.0)) if comb and not j.has("virtual") else 0.0), cd)
		if st["cd"] > 0.0 and cd <= 0.0 and not st["empty"]:
			st["flash"] = Time.get_ticks_msec()
		if st["empty"] or st["el"] != el or absf(st["cd"] - cd) > 0.001 or st["ok"] != ok or st["max"] != mx or int(st.get("cost", -1.0)) != int(cost) or st.get("tai", false) != tai or Time.get_ticks_msec() - int(st.get("flash", -100000)) < 420:
			st["empty"] = false; st["el"] = el; st["cd"] = cd; st["ok"] = ok; st["max"] = mx; st["cost"] = cost; st["tai"] = tai
			sn[0].queue_redraw()
	_update_side(pl, pr)
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.0:
			msg_lbl.text = ""
	var it = Interact.nearest(pl.global_position)
	var catch = _near_catchable(pl)
	var tk = _near_talker(pl) if it.is_empty() and not catch else null
	var ptxt = it.get("label", "") if not it.is_empty() else ((String(catch.get("catch_label")) if catch.get("catch_label") != null else "Yakala!") if catch else (Lang.t("Konuş: %s") % tk.display if tk else ""))
	# önce tam metin çevrilir (sözlükte "[F] ..." ile kayıtlı), sonra [F] atılır — eskiden önce atılıyor, çeviri bulunmuyordu
	var ptr = Lang.t(String(ptxt))
	if ptr == String(ptxt):
		ptr = Lang.t(String(ptxt).replace("[F] ", "").replace("[F]", "").strip_edges())
	ptxt = ptr.replace("[F] ", "").replace("[F]", "").strip_edges()
	prompt_box.visible = ptxt != ""
	if prompt_box.visible:
		prompt_key.get_child(0).text = Keys.name("interact")
	if prompt_box.visible and prompt_lbl.text != ptxt:
		prompt_lbl.text = ptxt
		prompt_box.reset_size()
		# alt orta çapası: konum çapaya göre (offset) verilir — position ekranın sol üstüne göre olduğundan kutu ekran dışına düşüyordu
		prompt_box.offset_left = -prompt_box.size.x * 0.5
		prompt_box.offset_right = prompt_box.size.x * 0.5
		prompt_box.offset_top = -148.0 - prompt_box.size.y
		prompt_box.offset_bottom = -148.0
	var rn = Game.region_name(pl.global_position) if Engine.get_process_frames() % 20 == 0 else region_name
	if rn != region_name:
		region_name = rn
		region_lbl.text = rn
		mm_region.text = rn
		var tw = region_lbl.create_tween()
		tw.tween_property(region_lbl, "modulate:a", 1.0, 0.4)
		tw.tween_interval(2.5)
		tw.tween_property(region_lbl, "modulate:a", 0.0, 1.0)
	# kilit nişanı
	var lt = comb.lock_target if comb else null
	if lt and is_instance_valid(lt) and not lt.is_dead():
		var cam = pl.cam
		var wp: Vector3 = lt.global_position + Vector3.UP * lt.height * 0.6
		lock_ret.visible = not cam.is_position_behind(wp)
		lock_ret.position = cam.unproject_position(wp)
		lock_ret.queue_redraw()
	else:
		lock_ret.visible = false
	_update_objective_pointer(pl)
	if boss and is_instance_valid(boss):
		boss_bar_pb.value = boss.hp
	elif boss_box.visible:
		boss_box.visible = false
	# mini harita
	var sm: ShaderMaterial = minimap.get_meta("mat")
	var rm = Game.world.get("road_map") if Game.world else null
	if rm != null and rm.local_map != null and rm.local_rect.z > 0.0:
		# yüksek çözünürlüklü yerel harita (yollar, nehirler, köyler; 1.6 km, kuzey yukarı)
		var tr: TextureRect = minimap.get_meta("tex")
		if minimap.get_meta("map_ver", -1) != rm.version:
			tr.texture = rm.local_map
			minimap.set_meta("map_ver", rm.version)
		var r: Vector4 = rm.local_rect
		var gp = pl.global_position
		sm.set_shader_parameter("center", Vector2((gp.x - r.x) / r.z, (gp.z - r.y) / r.z))
		sm.set_shader_parameter("zoom", 900.0 / r.z)
	else:
		var m = Game.to_map(pl.global_position)
		var W = Game.hw * Game.res
		var H = Game.hh * Game.res
		sm.set_shader_parameter("center", Vector2((m.x - Game.x0) / W, (Game.y1 - m.y) / H))
		sm.set_shader_parameter("zoom", 900.0 / W)
	sm.set_shader_parameter("rot", deg_to_rad(pl.yaw) * -1.0)
	(minimap.get_meta("over") as Control).queue_redraw()


func _near_talker(pl: Node3D) -> Node:
	# baktığın kişi: menzildekiler arasında kameranın baktığı yöndeki öne geçer (eskiden yalnız en yakın: önündekine
	# bakarken arkandakiyle konuşuyordun)
	var best: Node = null
	var bs = 1e9
	var cam = get_viewport().get_camera_3d()
	var fw = Vector3.ZERO
	if cam != null:
		fw = -cam.global_transform.basis.z
		fw.y = 0.0
		fw = fw.normalized() if fw.length() > 0.01 else Vector3.ZERO
	for c in get_tree().get_nodes_in_group("talkers"):
		var to: Vector3 = c.global_position - pl.global_position
		var d = to.length()
		if d >= 3.4:
			continue
		to.y = 0.0
		var facing = to.normalized().dot(fw) if to.length() > 0.3 and fw != Vector3.ZERO else 1.0
		var sc = d - 2.4 * facing
		if sc < bs:
			bs = sc; best = c
	return best


func _near_catchable(pl: Node3D) -> Node:
	for c in get_tree().get_nodes_in_group("catchables"):
		if c.global_position.distance_to(pl.global_position) < 2.5:
			return c
	return null


func _draw_minimap_markers(c: Control) -> void:
	var pl = Game.player
	if pl == null:
		return
	var R = 120.0
	var scale = R / 450.0  # 900 m çap
	var rot = deg_to_rad(pl.yaw)
	var to_mm = func(wp: Vector3) -> Vector2:
		var d = Vector2(wp.x - pl.global_position.x, wp.z - pl.global_position.z)
		d = d.rotated(rot)
		return Vector2(R, R) + d * scale
	var sense_r = Stats.sense_radius(Game.profile)
	for f in get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(pl, f) and f.get("team") != "dummy" and not f.is_dead():
			if f.global_position.distance_to(pl.global_position) > sense_r:
				continue
			var q: Vector2 = to_mm.call(f.global_position)
			if q.distance_to(Vector2(R, R)) < R - 4:
				c.draw_circle(q, 3.5, Color(1, 0.25, 0.2))
	# önemli yerler (dükkân, hastane, görev masası, han...): harf rozeti, yakındakilerin adı da yazılır
	var t_ms = Time.get_ticks_msec()
	if t_ms - int(c.get_meta("lm_t", 0)) > 1000:
		c.set_meta("lm_t", t_ms)
		c.set_meta("lm", Interact.landmarks(pl.global_position, 460.0))
	var fnt = ThemeDB.fallback_font
	for lm in c.get_meta("lm", []):
		var q: Vector2 = to_mm.call(lm["pos"])
		if q.distance_to(Vector2(R, R)) > R - 8:
			continue
		c.draw_circle(q, 7.5, Color(0.08, 0.06, 0.08, 0.9))
		c.draw_arc(q, 7.5, 0, TAU, 16, lm["col"], 1.6)
		c.draw_string(fnt, q + Vector2(-4, 4.5), lm["glyph"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lm["col"])
		if lm["pos"].distance_to(pl.global_position) < 90.0:
			c.draw_string_outline(fnt, q + Vector2(9, 4), Lang.t(String(lm["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.9))
			c.draw_string(fnt, q + Vector2(9, 4), Lang.t(String(lm["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))
	if Missions.has_marker:
		var q: Vector2 = to_mm.call(Missions.target_marker)
		var dv = q - Vector2(R, R)
		if dv.length() > R - 12:
			# menzil dışı: kenarda hedefe bakan ok
			var dn = dv.normalized()
			var sd = Vector2(-dn.y, dn.x)
			var tp = Vector2(R, R) + dn * (R - 4)
			var bk = Vector2(R, R) + dn * (R - 22)
			c.draw_colored_polygon(PackedVector2Array([tp, bk + sd * 9, bk - sd * 9]), Color(1, 0.85, 0.2))
			c.draw_polyline(PackedVector2Array([tp, bk + sd * 9, bk - sd * 9, tp]), Color(0.25, 0.1, 0.0), 2.0)
		else:
			c.draw_circle(q, 8, Color(1, 0.85, 0.2))
			c.draw_circle(q, 4, Color(0.2, 0.1, 0.0))
	# oyuncu oku (yukarı = kamera yönü)
	var fr = pl.facing - deg_to_rad(pl.yaw)
	var tip = Vector2(R, R) + Vector2(0, -12).rotated(-fr)
	var l = Vector2(R, R) + Vector2(-7, 8).rotated(-fr)
	var r = Vector2(R, R) + Vector2(7, 8).rotated(-fr)
	c.draw_colored_polygon(PackedVector2Array([tip, l, r]), Color(1, 0.95, 0.9))
	c.draw_polyline(PackedVector2Array([tip, l, r, tip]), Color(0.1, 0.05, 0.0), 2.0)
	var npos = Vector2(R, R) + Vector2(0, -1).rotated(rot) * (R - 14)
	c.draw_circle(npos, 10, Color(0.1, 0.06, 0.04, 0.85))
	c.draw_string(ThemeDB.fallback_font, npos + Vector2(-5, 6), "N" if Lang.is_en() else "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.3))
