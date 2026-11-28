class_name Menus
extends RefCounted
## Tam ekran menüler (modern): bulanık oyun arka planı, sol simge rayı, cam paneller, simgeli kartlar.
## Hepsi Hud.dialog_layer'a eklenir.

## Yetenek ağacı verisi: data/skills.json (tools/build_skills.py), ekran: SkillTree
const SKILL_ICONS := {"Taijutsu": "hand", "Ninjutsu": "chakra", "Destek": "heart"}

static var _fresh := false


static func clear() -> void:
	# Ninja menüsü kapanırken/yenilenirken açık sekmenin kaydırma konumunu hatırla (yeniden açınca kaldığın yerden)
	if _menu_open and _last_tab != "":
		_scroll_mem[_last_tab] = _scroll_positions()
	_menu_open = false
	if (settings_open() or _set_sub) and not _set_keep:   # ayarlar kaydedilmeden kapanıyor (Esc, Tab...): yarım kalan değişiklikleri geri al
		_set_sub = false
		_settings_revert()
	for c in Hud.dialog_layer.get_children():
		c.queue_free()


## Tam ekran arka plan: bulanıklaştırılmış oyun görüntüsü + koyulaştırma + vinyet
static func _full(dim := 0.55) -> Control:
	_fresh = Hud.dialog_layer.get_child_count() == 0
	clear()
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm = ShaderMaterial.new()
	sm.shader = load("res://shaders/ui_backdrop.gdshader")
	sm.set_shader_parameter("dim", maxf(dim, 0.6))
	bg.material = sm
	Hud.dialog_layer.add_child(bg)
	if _fresh:
		bg.modulate.a = 0.0
		var tw = bg.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(bg, "modulate:a", 1.0, 0.18)
	return bg


static func _center_panel(parent: Control, w := 560.0) -> VBoxContainer:
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var p = LazyFx.g("UI").panel()
	p.custom_minimum_size = Vector2(w, 0)
	p.add_theme_stylebox_override("panel", LazyFx.g("UI").ink_panel(0.92, 26))
	cc.add_child(p)
	var v = LazyFx.g("UI").vbox(12)
	p.add_child(v)
	if _fresh:
		LazyFx.g("UI").pop_in(p)
	return v


## Ekran üst köşesinde kapatma düğmesi
static func _close_button(parent: Control, cb: Callable) -> Button:
	var b = LazyFx.g("UI").button("", cb, 56, "close")
	b.custom_minimum_size = Vector2(56, 56)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# kâğıda yayılmış yuvarlak mürekkep lekesi (arayüzün fırça diliyle), üzerine gelince kırmızı leke
	var n = StyleBoxTexture.new()
	n.texture = LazyFx.g("UI")._t("ink_disc")
	n.modulate_color = Color(0.02, 0.018, 0.016, 0.9)
	n.set_content_margin_all(8)
	var h = n.duplicate()
	h.modulate_color = LazyFx.g("UI").ACCENT
	for k in [["normal", n], ["hover", h], ["pressed", h], ["focus", h]]:
		b.add_theme_stylebox_override(k[0], k[1])
	b.add_theme_color_override("icon_normal_color", LazyFx.g("UI").CREAM)
	b.add_theme_color_override("icon_hover_color", Color(1, 0.97, 0.93))
	b.tooltip_text = "Kapat [Esc]"
	b.anchor_left = 1.0; b.anchor_right = 1.0
	b.offset_left = -84; b.offset_right = -28; b.offset_top = 24; b.offset_bottom = 80
	parent.add_child(b)
	return b


static func _scroll(parent: Control, w: float, h := 600.0) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(w, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v = LazyFx.g("UI").vbox(8)
	v.custom_minimum_size = Vector2(w - 16, 0)
	sc.add_child(v)
	return v


## Kare karo düğme: içerik (simge/3B görsel), alt yazı, nadirlik kenarı, seçili parlama
static func _tile(content: Control, text: String, accent: Color, selected: bool, cb: Callable, size := 96, badge := "") -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(size, size + (18 if text != "" else 0))
	b.add_theme_font_override("font", LazyFx.g("UI").font(true))
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", LazyFx.g("UI").MUTED)
	b.add_theme_color_override("font_hover_color", LazyFx.g("UI").TEXT)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	var n = LazyFx.g("UI")._box(Color(1, 1, 1, 0.045), Color(accent, 0.45), 1, 12, 6)
	n.content_margin_top = size - 4
	var h = n.duplicate()
	h.bg_color = Color(1, 1, 1, 0.1)
	h.border_color = Color(accent, 0.9)
	var s = n.duplicate()
	s.bg_color = Color(LazyFx.g("UI").ACCENT, 0.22)
	s.border_color = LazyFx.g("UI").ACCENT
	s.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", s if selected else n)
	b.add_theme_stylebox_override("hover", s if selected else h)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s if selected else h)
	# nadirlik şeridi (alt)
	var strip = ColorRect.new()
	strip.color = Color(accent, 0.85)
	strip.anchor_left = 0.0; strip.anchor_right = 1.0
	strip.offset_left = 12; strip.offset_right = -12; strip.offset_top = size - 6; strip.offset_bottom = size - 4
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(strip)
	var cc = CenterContainer.new()
	cc.position = Vector2(0, 4)
	cc.size = Vector2(size, size - 10)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cc)
	content.custom_minimum_size = Vector2(size - 24, size - 24)
	cc.add_child(content)
	if badge != "":
		var bl = LazyFx.g("UI").label(badge, 13, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true)
		bl.position = Vector2(4, 4)
		bl.size = Vector2(size - 10, 18)
		b.add_child(bl)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.15))
	return b


## Gözler sekmesi: sağ göz / sol göz durumu, uyanış, kavanozdaki gözler, Susanoo; tuşlar
## Taşınan kuyruklu canavarlar (biri aktif) + mühür kabındakiler (içine aktarılabilir)
static func _tab_beasts(main: Node, body: Control) -> void:
	var sc = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v = LazyFx.g("UI").vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var held: Array = TailedBeasts.held()
	var jar: Array = TailedBeasts.jarred()
	if held.is_empty() and jar.is_empty():
		v.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("Hiç kuyruklu canavarın yok. Bir canavarı yenip [%s] ile mühürle: içine (Jinchūriki) ya da mühür kabına.") % Keys.name("interact"), 17, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		return
	var act = TailedBeasts.player_jinchuriki()
	v.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("İÇİNDEKİLER  (aktif olan: %s pelerin / dönüşüm / zihin dünyası)") % Keys.name("beast"), 18, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	for id in held:
		v.add_child(_beast_row(main, id, "held", id == act))
	if not jar.is_empty():
		v.add_child(HSeparator.new())
		v.add_child(LazyFx.g("UI").label("MÜHÜR KABINDAKİLER", 18, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
		for id in jar:
			v.add_child(_beast_row(main, id, "jar", false))


static func _beast_row(main: Node, id: String, where: String, active: bool) -> Control:
	var inf: Dictionary = LazyFx.g("BeastModels").INFO.get(id, {})
	var col: Color = inf.get("chakra", LazyFx.g("UI").GOLD)
	var card = LazyFx.g("UI").card(col if active else Color(0, 0, 0, 0))
	var h = LazyFx.g("UI").hbox(16)
	card.add_child(h)
	var tv = LazyFx.g("UI").vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(LazyFx.g("UI").label(String(inf.get("name", id)) + ("   — AKTİF" if active else ""), 20, col, HORIZONTAL_ALIGNMENT_LEFT, true))
	var tr = TailedBeasts.trust(id)
	tv.add_child(LazyFx.g("UI").label(("Güven %d / 100" % int(tr)) if where == "held" else "Mühür kabında uyuyor. İçine aktarırsan chakrasını kullanabilirsin (güven sıfırdan başlar).", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	if where == "held" and not active:
		h.add_child(LazyFx.g("UI").button("Aktif yap", func():
			TailedBeasts.set_active(id)
			ninja_menu(main, "beasts"), 200, "check"))
	elif where == "jar":
		h.add_child(LazyFx.g("UI").button("İçime aktar", func():
			TailedBeasts.transfer_from_jar(id)
			ninja_menu(main, "beasts"), 200, "seal"))
	return card


## İmzalı sözleşmeler: aktif sözleşme ve çağrılacak kademe seçimi
static func _tab_summons(main: Node, body: Control) -> void:
	LazyFx.g("Contracts").ensure()
	var pr = Game.profile
	var sc = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v = LazyFx.g("UI").vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	# Mangekyō sahibinin Sharingan'la boyun eğdirdiği (mühürlenmemiş) kuyruklu canavarlar: Bijū Kuchiyose
	if Progress.has_eye("mangekyo"):
		var red = Color(0.95, 0.2, 0.2)
		var mcard = LazyFx.g("UI").card(red)
		v.add_child(mcard)
		var mv = LazyFx.g("UI").vbox(8)
		mcard.add_child(mv)
		mv.add_child(LazyFx.g("UI").label("Bijū Kuchiyose (Mangekyō)", 20, red, HORIZONTAL_ALIGNMENT_LEFT, true))
		var bound: Array = TailedBeasts.ms_pool()   # boyun eğdirdiklerin + mühür kabındakiler
		var names: Array = bound.map(func(bid): return String(LazyFx.g("BeastModels").INFO.get(bid, {}).get("name", bid)).split(" — ")[0] + ("  (mühür kabında)" if bid in TailedBeasts.jarred() else ""))
		if bound.is_empty():
			var mtxt = LazyFx.g("UI").label("Henüz Sharingan'ınla çağırabileceğin kuyruklu canavar yok.", 16, LazyFx.g("UI").TEXT)
			mtxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mv.add_child(mtxt)
		else:
			# çağrılacak canavar: ◀ ▶ seçici
			var cur_pick = String(pr.get("beast_ms_pick", ""))
			var pi = maxi(0, bound.find(cur_pick))
			if not cur_pick in bound:
				pr["beast_ms_pick"] = String(bound[0])
			mv.add_child(_arrow_row("Çağrılacak", names, pi, func(i: int): pr["beast_ms_pick"] = String(bound[i])))
		var mtip = LazyFx.g("UI").label(LazyFx.g("Lang").t("Mühür kabındaki canavarları da Mangekyō'nla dışarı çağırıp yönetebilirsin; boyun eğdirmek için canavarı dövüşte diz çöktürüp mühürleme penceresinde «Sharingan ile boyun eğdir» seç. Jutsular (%s) ekranından «Bijū Kuchiyose»yi bir yuvaya koy; Mangekyō açıkken çağırırsın (40 sn, 120 chakra). Kontrol ettiğin canavarın gözleri Sharingan olur.") % Keys.name("skills"), 14, LazyFx.g("UI").MUTED)
		mtip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(mtip)
	var cs: Dictionary = pr.get("contracts", {})
	if cs.is_empty():
		v.add_child(LazyFx.g("UI").label("Hiçbir hayvanla sözleşmen yok. Gizli bilgelerin diyarlarını bul ya da köy sözleşme ustalarına danış.", 17, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		return
	var act = LazyFx.g("Contracts").active()
	for id in cs:
		if not LazyFx.g("Contracts").DEFS.has(id):
			continue
		var d: Dictionary = LazyFx.g("Contracts").DEFS[id]
		var card = LazyFx.g("UI").card(d["color"] if id == act else Color(0, 0, 0, 0))
		v.add_child(card)
		var cv = LazyFx.g("UI").vbox(8)
		card.add_child(cv)
		var top = LazyFx.g("UI").hbox(16)
		cv.add_child(top)
		var t = LazyFx.g("UI").label("%s%s" % [d["name"], "   — AKTİF" if id == act else ""], 20, d["color"], HORIZONTAL_ALIGNMENT_LEFT, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		top.add_child(LazyFx.g("UI").label("Ustalık %d" % int(LazyFx.g("Contracts").mastery(id)), 15, LazyFx.g("UI").MUTED))
		if id != act:
			top.add_child(LazyFx.g("UI").button("Aktif yap", func():
				pr["summon"] = id
				Game.save_game()
				ninja_menu(main, "summons"), 180, "check"))
		var pref = int(cs[id].get("tier_pref", -1))
		var row = LazyFx.g("UI").hbox(10)
		cv.add_child(row)
		row.add_child(LazyFx.g("UI").button(("● " if pref < 0 else "") + "Otomatik (en büyüğü)", func():
			cs[id]["tier_pref"] = -1
			ninja_menu(main, "summons"), 220))
		var tiers: Dictionary = d["tiers"]
		for tk in [0, 1, 2]:
			if not tiers.has(tk):
				continue
			var td: Dictionary = tiers[tk]
			var ok = int(pr["level"]) >= LazyFx.g("Contracts").TIER_LEVEL[tk] and LazyFx.g("Contracts").mastery(id) >= LazyFx.g("Contracts").TIER_MASTERY[tk]
			var lbl = ("● " if pref == tk else "") + String(td["name"]) + ("" if ok else "  (Güç %d, ustalık %d)" % [LazyFx.g("Contracts").TIER_LEVEL[tk], int(LazyFx.g("Contracts").TIER_MASTERY[tk])])
			var b = LazyFx.g("UI").button(lbl, func():
				cs[id]["tier_pref"] = tk
				ninja_menu(main, "summons"), 260)
			b.disabled = not ok
			row.add_child(b)


static var _eyes_paths := false


## Pein Rikudō: altı yola arşivdeki bedenlerden atama (◀ ▶). Beden kendi gücüyle gelir, teknikleri yolunkilerdir.
static func _paths_panel(main: Node, outer: Control) -> void:
	var SP = LazyFx.g("SixPaths")
	var bodies: Array = SP.data()["bodies"]
	var card = LazyFx.g("UI").card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(700, 480)
	card.add_child(sc)
	var v = LazyFx.g("UI").vbox(10)
	v.custom_minimum_size = Vector2(680, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.add_child(v)
	v.add_child(LazyFx.g("UI").label("PEIN RIKUDŌ", 20, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("Arşivdeki bedenler: %d / %d") % [bodies.size(), SP.ARCHIVE_MAX], 14, LazyFx.g("UI").TEXT))
	var help = LazyFx.g("UI").label("Öldürdüğün birinin cesedine yaklaşıp [F] ile kara alıcı sapla: beden arşive girer. Aşağıdan yollara ata, Pein Rikudō tekniğiyle çağır. Beden kendi gücüyle gelir; teknikleri atandığı yolunkilerdir. Bedenler sahadayken chakran akar.", 13, LazyFx.g("UI").MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(680, 0)
	v.add_child(help)
	var labels: Array = [LazyFx.g("Lang").t("Boş")]
	var ids: Array = [0]
	for b in bodies:
		labels.append(LazyFx.g("Lang").t("%s (Güç %d)") % [String(b["name"]), int(b["level"])])
		ids.append(int(b["id"]))
	# bedene giydirilecek set: kendi kıyafeti ya da sahip olduğun setlerden biri (Pain'in Akatsuki cübbeli bedenleri gibi)
	var wlabels: Array = [LazyFx.g("Lang").t("Kendi kıyafeti")]
	var wids: Array = [""]
	for sid in SP.wear_choices():
		wlabels.append(LazyFx.g("Lang").t(String(LazyFx.g("Gear").item(sid).get("name", sid))))
		wids.append(sid)
	for path in SP.PATHS:
		var pth: String = path
		var idx = maxi(0, ids.find(SP.slot_id(pth)))
		var row = _arrow_row(String(SP.NAMES[pth]), labels, idx, func(i: int):
			var id: int = ids[i]
			var clash = false
			for q in SP.PATHS:
				if q != pth and id != 0 and SP.slot_id(q) == id:
					clash = true
			SP.assign(pth, id)
			if clash:   # beden başka yoldan alındı: o satır da güncellensin
				ninja_menu(main, "eyes"))
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.custom_minimum_size = Vector2(680, 0)
		v.add_child(row)
		var wrow = _arrow_row("Kıyafet", wlabels, maxi(0, wids.find(SP.wear_id(pth))), func(i: int): SP.set_wear(pth, String(wids[i])))
		wrow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wrow.custom_minimum_size = Vector2(680, 0)
		v.add_child(wrow)
		v.add_child(LazyFx.g("UI").label(String(SP.INFO[pth]), 12, LazyFx.g("UI").MUTED))
	if SP.count_out() > 0:
		v.add_child(LazyFx.g("UI").button("Bedenleri geri gönder", func():
			SP.recall_all()
			ninja_menu(main, "eyes"), 260))


static func _tab_eyes(main: Node, body: Control) -> void:
	var pr = Game.profile
	# 1600 px tasarım genişliğinde iki kart + yan sütun ekrandan taşıyordu: tuşlar artık kartların üstünde yatay şerit
	var outer = LazyFx.g("UI").vbox(12)
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(outer)
	var strip = HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 22)
	strip.add_theme_constant_override("v_separation", 6)
	outer.add_child(strip)
	for k in [[Keys.name("dojutsu"), "Gözleri aç → Mangekyō (varsa) → kapat"], [Keys.name("skills"), "Göz teknikleri jutsu yuvalarına"], [LazyFx.g("Lang").t("%s (basılı)") % Keys.name("dojutsu"), "Susanoo (iki göz Mangekyō)"], [Keys.name("interact"), "Düşmüş dōjutsu sahibinin gözlerini al"]]:
		var r = LazyFx.g("UI").hbox(8)
		r.add_child(LazyFx.g("UI").key_badge(k[0], 13))
		r.add_child(LazyFx.g("UI").label(k[1], 14, LazyFx.g("UI").TEXT))
		strip.add_child(r)
	if Susanoo.max_tier(pr) > 0:
		var sr = LazyFx.g("UI").hbox(10)
		sr.add_child(LazyFx.g("UI").label("Susanoo: Kademe %d" % Susanoo.cur_tier(pr), 15, Color(0.75, 0.6, 1.0)))
		sr.add_child(LazyFx.g("UI").button("Susanoo'yu Özelleştir", func():
			_eq_slot = "susanoo"
			ninja_menu(main, "wardrobe"), 240))
		strip.add_child(sr)
	if LazyFx.g("SixPaths").has_rinnegan():
		var pr2 = LazyFx.g("UI").hbox(10)
		pr2.add_child(LazyFx.g("UI").button("Gözler" if _eyes_paths else "Pein Rikudō", func():
			_eyes_paths = not _eyes_paths
			ninja_menu(main, "eyes"), 200))
		strip.add_child(pr2)
		if _eyes_paths:
			_paths_panel(main, outer)
			return
	var h = LazyFx.g("UI").hbox(22)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(h)
	for sl in ["sag_goz", "sol_goz"]:
		var card = LazyFx.g("UI").card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(card)
		var sc = ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size = Vector2(420, 480)
		card.add_child(sc)
		var v = LazyFx.g("UI").vbox(10)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
		v.add_child(LazyFx.g("UI").label("SAĞ GÖZ" if sl == "sag_goz" else "SOL GÖZ", 20, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
		_eq_slot = sl
		_eye_panel(main, v, pr)
	_eq_slot = "set"


## Gözler eşya değil, bedenin parçası: durum, uyanış ilerlemesi, saklanan gözler (nakil hastanede)
static func _eye_panel(main: Node, dv: VBoxContainer, pr: Dictionary) -> void:
	var cur = LazyFx.g("Gear").equipped(pr, _eq_slot)
	var side = "Sağ" if _eq_slot == "sag_goz" else "Sol"
	if cur.is_empty():
		dv.add_child(LazyFx.g("UI").label("%s gözün normal bir göz." % side, 16, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		var cl = Data.clans.get(String(pr.get("clan", "")), {})
		if cl.has("dojutsu"):
			dv.add_child(LazyFx.g("UI").label("Soyunda bir göz tekniği var ama henüz uyanmadı. Ölümcül bir dövüşte, hayatın tehlikedeyken uyanabilir.", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		var it = LazyFx.g("Gear").item(cur["id"])
		var e: Dictionary = it.get("eye", {})
		var lvl = int(cur.get("lvl", 3))
		var title = String(e.get("name", it["name"]))
		if int(e.get("kind", 0)) == 1:
			title += "  (%d tomoe)" % lvl
		dv.add_child(LazyFx.g("UI").label(title, 22, Color(1, 0.45, 0.45), HORIZONTAL_ALIGNMENT_LEFT, true))
		dv.add_child(LazyFx.g("UI").label("%s göz  •  %s" % [side, "doğuştan" if cur.get("origin", "dogustan") == "dogustan" else "nakil (daha çok chakra harcar)"], 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		var d = LazyFx.g("UI").label(String(it.get("desc", "")), 14, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dv.add_child(d)
		var k = int(e.get("kind", 0))
		if k == 1 and lvl < 3:
			var xp = float(cur.get("xp", 0.0))
			var need = 600.0 * lvl   # Eyes.gd ile aynı: gözler açık + 25 m içinde düşman varken geçen saniye
			dv.add_child(LazyFx.g("UI").label("Sonraki tomoe: Sharingan açıkken düşmanla dövüşerek  %d:%02d / %d dk" % [int(xp) / 60, int(xp) % 60, int(need) / 60], 14, Color(1, 0.7, 0.6), HORIZONTAL_ALIGNMENT_LEFT, true))
		elif k == 1 and lvl >= 3:
			dv.add_child(LazyFx.g("UI").label("Mangekyō, en yakınını kendi ellerinle öldürmenin ya da yanında savaşan bir dostun gözlerinin önünde ölmesinin acısıyla uyanır...", 14, Color(1, 0.7, 0.6), HORIZONTAL_ALIGNMENT_LEFT, true))
		var sk = Eyes.SKILLS.get(k, [])
		if not sk.is_empty():
			var si = sk[0 if _eq_slot == "sag_goz" else 1]
			dv.add_child(LazyFx.g("UI").label("Göz tekniği: %s  (Jutsular sekmesinden yuvaya koy)" % Eyes.eye_skill_label(pr, "sag" if _eq_slot == "sag_goz" else "sol", k), 15, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
		if k in [4, 5]:
			_ms_editor(main, dv, Eyes.design_for(pr, _eq_slot))
		# gözü çıkar: kavanoza konur, yerine normal göz kalır (geri takmak için aşağıdaki listeden)
		var slot_now = _eq_slot
		dv.add_child(LazyFx.g("UI").button("Gözü çıkar (kavanoza koy)", func():
			Hud.dialog("Gözü Çıkar", "%s %s gözünden çıkarılıp kavanoza konacak. Göz teknikleri bu gözle kullanılamaz. Emin misin?" % [title, side.to_lower()], [
				{"label": "Evet, çıkar", "cb": func():
					_eye_remove(pr, slot_now)
					ninja_menu(main, "eyes")},
				{"label": "Vazgeç", "cb": func(): ninja_menu(main, "eyes")}]), 380, "close"))
		dv.add_child(LazyFx.g("UI").button("Gözü yok et", func():
			Hud.dialog("Gözü Yok Et", "%s %s gözünden çıkarılıp tamamen yok edilecek. Geri dönüşü yok. Emin misin?" % [title, side.to_lower()], [
				{"label": "Evet, yok et", "cb": func():
					_eye_destroy(pr, int(LazyFx.g("Gear").equipped(pr, slot_now).get("uid", -1)))
					ninja_menu(main, "eyes")},
				{"label": "Vazgeç", "cb": func(): ninja_menu(main, "eyes")}]), 380, "close"))
	# saklanan gözler (kavanozda)
	var jars = []
	for g in pr.get("gear", []):
		if LazyFx.g("Gear").item(g["id"]).get("slot", "") == "goz" and not LazyFx.g("Gear").is_equipped(pr, g):
			jars.append(g)
	dv.add_child(HSeparator.new())
	dv.add_child(LazyFx.g("UI").label("SAKLANAN GÖZLER (%d)" % jars.size(), 16, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	if jars.is_empty():
		dv.add_child(LazyFx.g("UI").label("Kavanozunda göz yok. Yendiğin dōjutsu sahiplerinin gözlerini alabilirsin.", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var slot_here = _eq_slot
	for g in jars:
		var gname = EyeSurgery.eye_label(g)
		var own = String(g.get("origin", "dogustan")) == "dogustan" and bool(g.get("own", false))
		var row = LazyFx.g("UI").hbox(8)
		row.add_child(LazyFx.g("UI").label("• " + gname, 14, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		dv.add_child(row)
		var uid = int(g["uid"])
		if own:
			# kendi çıkardığın gözü geri takmak nakil gerektirmez
			dv.add_child(LazyFx.g("UI").button("Bu göze geri tak", func():
				_eye_insert(pr, uid, slot_here)
				ninja_menu(main, "eyes"), 300, "eye"))
		else:
			# başkasının gözü: tıbbi nakil (kanon şartı tutmuyorsa nedeni yazılır, düğme yok)
			var why = EyeSurgery.block_reason(pr, g)
			if why == "":
				dv.add_child(LazyFx.g("UI").button("Bu göze nakil yap", func(): EyeSurgery.menu_offer(uid, slot_here), 300, "eye"))
			else:
				dv.add_child(LazyFx.g("UI").label("Takılamaz: " + why, 13, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, true))
		var juid = int(g["uid"])
		dv.add_child(LazyFx.g("UI").button("Yok et", func():
			Hud.dialog("Gözü Yok Et", "%s kavanozdan atılıp yok edilecek. Emin misin?" % gname, [
				{"label": "Evet, yok et", "cb": func():
					_eye_destroy(pr, juid)
					ninja_menu(main, "eyes")},
				{"label": "Vazgeç", "cb": func(): ninja_menu(main, "eyes")}]), 200, "close"))
	if not jars.is_empty() and not EyeSurgery.can_self(pr):
		dv.add_child(LazyFx.g("UI").label("Kendi naklini yapmak için Shōsen (tıbbi ninjutsu) ve en az 50 Iryō (tıbbi) ustalığı gerekir. Tutma şansı tıbbi ustalığınla artar.", 13, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	dv.add_child(LazyFx.g("UI").label("Başkasından alınan gözü köy hastanesi takmaz (kanon: klan gözü klanın malıdır). Nakli takımındaki tıbbi ninja sahada yapar (Rin–Kakashi), kendi tıbbi ninjutsunla yaparsın ya da yeraltındaki Kara Cerrah gizlice takar.", 13, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	# uzun açıklamalar tek satır kalınca paneli genişletip sol göz kutusunu ekranın dışına itiyordu (her çözünürlükte): satırları kaydır
	for l in dv.get_children():
		if l is Label:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 0.0


## Takılı gözü kavanoza koyar (yuvası boşalır = normal göz); açık gözler kapanır
static func _eye_remove(pr: Dictionary, slot: String) -> void:
	var g = LazyFx.g("Gear").equipped(pr, slot)
	if g.is_empty():
		return
	g["own"] = String(g.get("origin", "dogustan")) == "dogustan"
	pr["equip"].erase(slot)
	_eye_refresh(pr)
	Hud.msg("Göz çıkarıldı ve kavanoza kondu.", Color(1, 0.8, 0.6))


## Gözü tamamen yok eder (takılıysa önce yuvası boşalır = normal göz)
static func _eye_destroy(pr: Dictionary, uid: int) -> void:
	var g = LazyFx.g("Gear").find(pr, uid)
	if g.is_empty():
		return
	for s in pr["equip"].keys():
		if int(pr["equip"][s]) == uid:
			pr["equip"].erase(s)
	pr["gear"].erase(g)
	_eye_refresh(pr)
	Hud.msg("Göz yok edildi.", Color(1, 0.7, 0.6))


static func _eye_insert(pr: Dictionary, uid: int, slot: String) -> void:
	var cur = LazyFx.g("Gear").equipped(pr, slot)
	if not cur.is_empty():
		cur["own"] = String(cur.get("origin", "dogustan")) == "dogustan"
	pr["equip"][slot] = uid
	_eye_refresh(pr)
	Hud.msg("Göz yerine takıldı.", Color(0.7, 1, 0.7))


static func _eye_refresh(pr: Dictionary) -> void:
	var eyes = null
	if Game.player and Game.player.get("combat") and Game.player.combat.get("modes") and Game.player.combat.modes.get("eyes"):
		eyes = Game.player.combat.modes.eyes
	if eyes and eyes.active:
		eyes._close()
	LazyFx.g("Gear").apply_look(pr)
	if Game.player:
		Game.player.rebuild_model()
		Game.player.apply_profile_stats()
	if eyes:
		eyes.refresh_visual()


static func _swatch(c: Color, on: bool, cb: Callable) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(34, 34)
	var sb = LazyFx.g("UI")._box(c, Color(1, 1, 1, 0.95) if on else Color(1, 1, 1, 0.15), 3 if on else 1, 17, 0)
	var sh = sb.duplicate()
	sh.border_color = LazyFx.g("UI").GOLD
	sh.set_border_width_all(2)
	for st in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sh)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


# ================================================================== ana menü
static func main_menu(main: Node) -> void:
	clear()
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	Hud.dialog_layer.add_child(root)
	# soldan sağa koyulaşan degrade
	var grad = TextureRect.new()
	var gt = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0, Color(0.03, 0.026, 0.024, 0.92))
	g.set_color(1, Color(0.03, 0.026, 0.024, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 900
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var col = LazyFx.g("UI").vbox(0)
	col.position = Vector2(110, 120)
	root.add_child(col)
	var kanji = LazyFx.g("UI").label("忍 の 戦 士", 22, LazyFx.g("UI").ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true)
	col.add_child(kanji)
	var logo = LazyFx.g("UI").label("CHAKRA", 112, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	logo.add_theme_constant_override("line_spacing", -20)
	col.add_child(logo)
	var logo2 = LazyFx.g("UI").label("W A R R I O R S", 40, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_LEFT, true)
	col.add_child(logo2)
	col.add_child(LazyFx.g("UI").brush_line(250))
	col.add_child(LazyFx.g("UI").spacer(0, 14, false))
	col.add_child(LazyFx.g("UI").label("Beş Büyük Ülke'nin dünyasında kendi efsaneni yaz.", 19, LazyFx.g("UI").MUTED))
	col.add_child(LazyFx.g("UI").spacer(0, 54, false))
	var items = [["Yeni Oyun", "play", func(): slot_select(main, true)], ["Devam Et", "save", func(): slot_select(main, false)],
		["Ayarlar", "settings", func(): settings(func(): main_menu(main))], ["Çıkış", "exit", func(): main.get_tree().quit()]]
	for i in items.size():
		var b = _menu_entry(items[i][0], items[i][1], items[i][2])
		col.add_child(b)
		LazyFx.g("UI").slide_in(b, -30.0, 0.05 * i)
	var ver = LazyFx.g("UI").label("v%s %s   •   Kanon karakter içermez; Naruto evreninde geçen özgün bir hikâye." % [Game.version, "(TEST)" if Game.build_tag == "test" else ""], 13, Color(LazyFx.g("UI").MUTED, 0.8))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(110, -44)
	root.add_child(ver)


## Ana menü satırı: sade yazı; üzerine gelince / seçiliyken arkasında kırmızı fırça darbesi (Tsushima ana menüsü)
static func _menu_entry(text: String, icon: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.icon = LazyFx.g("Icons").tex(icon)
	b.add_theme_constant_override("icon_max_width", 26)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 62)
	b.add_theme_font_override("font", LazyFx.g("UI").title_font())
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(LazyFx.g("UI").TEXT, 0.82))
	for k in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color(1, 0.97, 0.93))
	b.add_theme_color_override("icon_normal_color", Color(LazyFx.g("UI").TEXT, 0.6))
	b.add_theme_color_override("icon_hover_color", Color(1, 0.97, 0.93))
	b.add_theme_color_override("icon_focus_color", Color(1, 0.97, 0.93))
	b.add_theme_constant_override("h_separation", 18)
	var n = StyleBoxEmpty.new()
	n.content_margin_left = 22
	var h = LazyFx.g("UI").brush(LazyFx.g("UI").ACCENT, "a", 0)
	h.content_margin_left = 22
	for k in [["normal", n], ["hover", h], ["pressed", h], ["focus", h]]:
		b.add_theme_stylebox_override(k[0], k[1])
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.2))
	return b


static func slot_select(main: Node, new_game: bool) -> void:
	var bg = _full(0.65)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var root = LazyFx.g("UI").vbox(28)
	cc.add_child(root)
	root.add_child(LazyFx.g("UI").header("YENİ OYUN — BİR KAYIT YUVASI SEÇ" if new_game else "KAYITLI OYUNU YÜKLE", 28))
	var row = LazyFx.g("UI").hbox(22)
	root.add_child(row)
	for s in [1, 2, 3]:
		var info = Game.slot_summary(s)
		var card = Button.new()
		card.text = "Yuva %d" % s
		card.custom_minimum_size = Vector2(320, 360)
		# düğme yazısı test/erişilebilirlik için durur ama görünmez; içerik elle yerleştirilir
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			card.add_theme_color_override(k, Color(0, 0, 0, 0))
		var n = LazyFx.g("UI").glass(16, 26, 0.75)
		var h = n.duplicate()
		h.border_color = LazyFx.g("UI").GOLD
		h.bg_color = Color(0.1, 0.11, 0.14, 0.9)
		for k in [["normal", n], ["hover", h], ["focus", h], ["pressed", h], ["disabled", n]]:
			card.add_theme_stylebox_override(k[0], k[1])
		var ic = LazyFx.g("Icons").view("person" if info != "" else "plus", 96, LazyFx.g("UI").GOLD if info != "" else Color(LazyFx.g("UI").TEXT, 0.3))
		ic.position = Vector2(112, 56)
		card.add_child(ic)
		var tl = LazyFx.g("UI").label("YUVA %d" % s, 26, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		tl.position = Vector2(0, 182)
		tl.size = Vector2(320, 34)
		card.add_child(tl)
		var parts = info.split("(") if info != "" else []
		var dl = LazyFx.g("UI").label(parts[0].strip_edges() if info != "" else "Boş yuva", 16, LazyFx.g("UI").GOLD if info != "" else LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.position = Vector2(20, 226)
		dl.size = Vector2(280, 50)
		card.add_child(dl)
		var dd = LazyFx.g("UI").label(("(" + parts[1]) if parts.size() > 1 else ("Yeni bir hikâye başlat" if new_game else ""), 13, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		dd.position = Vector2(20, 290)
		dd.size = Vector2(280, 20)
		card.add_child(dd)
		card.pressed.connect(func():
			Sfx.play("click")
			if new_game:
				main.start_creator(s)
			elif info != "":
				main.load_slot(s))
		if not new_game and info == "":
			card.disabled = true
		if info != "":
			# sağ üst köşede sil düğmesi: önce onay sorulur
			var del = Button.new()
			del.icon = LazyFx.g("Icons").tex("close", 40, LazyFx.g("UI").CREAM)
			del.expand_icon = true   # simge düğmeye sığar (doğal 40 px boyu düğmeyi genişletiyordu)
			del.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			del.custom_minimum_size = Vector2(34, 34)
			del.add_theme_constant_override("h_separation", 0)
			del.tooltip_text = "Kaydı sil"
			del.focus_mode = Control.FOCUS_NONE
			var dn = LazyFx.g("UI")._box(Color(0.03, 0.027, 0.025, 0.7), Color(LazyFx.g("UI").TEXT, 0.25), 1, 2, 9)
			var dh = LazyFx.g("UI")._box(LazyFx.g("UI").ACCENT, Color(LazyFx.g("UI").TEXT, 0.4), 1, 2, 9)
			for k in [["normal", dn], ["hover", dh], ["pressed", dh], ["focus", dn]]:
				del.add_theme_stylebox_override(k[0], k[1])
			del.position = Vector2(320 - 46, 12)
			del.size = Vector2(34, 34)
			var nm_s = String(parts[0]).strip_edges()
			del.pressed.connect(func():
				Sfx.play("click")
				_slot_delete_ask(main, new_game, s, nm_s))
			card.add_child(del)
			del.size = Vector2(34, 34)
		LazyFx.g("UI").hover_anim(card, 1.025)
		row.add_child(card)
	var back = LazyFx.g("UI").button("Geri", func(): main_menu(main), 200, "arrow")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(back)


## Kayıt silme onayı (geri alınamaz)
static func _slot_delete_ask(main: Node, new_game: bool, slot: int, who: String) -> void:
	var host = Hud.dialog_layer.get_child(Hud.dialog_layer.get_child_count() - 1)
	var ov = ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(ov)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", LazyFx.g("UI").ink_panel(0.97, 28))
	cc.add_child(p)
	var v = LazyFx.g("UI").vbox(14)
	p.add_child(v)
	var hd = LazyFx.g("UI").hbox(12)
	hd.add_child(LazyFx.g("UI").seal("消", 34.0))
	var t = LazyFx.g("UI").label("Yuva %d silinsin mi?" % slot, 26, LazyFx.g("UI").CREAM)
	t.add_theme_font_override("font", LazyFx.g("UI").title_font())
	hd.add_child(t)
	v.add_child(hd)
	var d = LazyFx.g("UI").label("%s — bu kayıt kalıcı olarak silinir, geri alınamaz." % who, 16, LazyFx.g("UI").MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(520, 0)
	v.add_child(d)
	v.add_child(LazyFx.g("UI").spacer(0, 6, false))
	var h = LazyFx.g("UI").hbox(12)
	v.add_child(h)
	var cancel = LazyFx.g("UI").button("Vazgeç", func(): ov.queue_free(), 200, "arrow")
	h.add_child(cancel)
	h.add_child(LazyFx.g("UI").spacer())
	h.add_child(LazyFx.g("UI").primary("Kaydı Sil", func():
		Game.delete_slot(slot)
		Hud.msg("Yuva %d silindi." % slot, Color(1, 0.6, 0.5))
		slot_select(main, new_game), 220, "close"))
	cancel.call_deferred("grab_focus")
	LazyFx.g("UI").pop_in(p, 0.96)


# ================================================================== karakter yaratma
static var _ctab := "kimlik"
static var _cfocus := ""   # yaratıcıda en son değiştirilen ayar (kamera o bölgeye yaklaşır: göz, kaş, ağız, saç, gövde...)


static func creator(main: Node, state: Dictionary, on_change: Callable, on_start: Callable) -> void:
	var keep_scroll = _scroll_positions() if Hud.dialog_layer.get_child_count() > 0 and Hud.dialog_layer.get_child(0).has_meta("creator") else []
	clear()
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("creator", true)
	Hud.dialog_layer.add_child(root)
	var redraw = func(): creator(main, state, on_change, on_start)
	# sol panel: başlık, sekmeler, seçenek kartları
	# panel içeriğe göre boylanır (altta boş alan kalmaz); içerik ekrana sığmazsa kaydırılır
	var pnl = PanelContainer.new()
	pnl.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(18, 22, 0.86))
	pnl.position = Vector2(28, 28)
	pnl.custom_minimum_size = Vector2(580, 0)
	root.add_child(pnl)
	var outer = LazyFx.g("UI").vbox(14)
	pnl.add_child(outer)
	var head = LazyFx.g("UI").vbox(2)
	head.add_child(LazyFx.g("UI").header("KARAKTERİNİ YARAT", 28))
	head.add_child(LazyFx.g("UI").label("Shinobi yolun burada başlıyor. Oklarla seçenekler arasında gezin.", 13, LazyFx.g("UI").MUTED))
	outer.add_child(head)
	var tabs = LazyFx.g("UI").hbox(8)
	for t in [["kimlik", "person", "Kimlik"], ["gorunum", "hair", "Görünüm"], ["kiyafet", "shirt", "Kıyafet"]]:
		var tb = LazyFx.g("UI").chip(t[2], _ctab == t[0], func():
			_ctab = t[0]
			_cfocus = ""   # sekme değişince sekmenin genel çerçevesi
			if main.has_method("_frame_creator_cam"):
				main._frame_creator_cam()
			redraw.call(), 170)
		tb.icon = LazyFx.g("Icons").tex(t[1], 40, LazyFx.g("UI").INK if _ctab == t[0] else LazyFx.g("UI").TEXT)
		tb.expand_icon = false
		tb.add_theme_constant_override("icon_max_width", 20)
		tb.custom_minimum_size = Vector2(170, 44)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
	outer.add_child(tabs)
	var sep = ColorRect.new()
	sep.color = LazyFx.g("UI").LINE
	sep.custom_minimum_size = Vector2(0, 1)
	outer.add_child(sep)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var v = LazyFx.g("UI").vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	# kaydırma alanı içerik boyunda; yalnız ekrana sığmayınca sınırlanır
	var fit = func() -> void:
		if not is_instance_valid(sc) or not is_instance_valid(pnl):
			return
		var pad = pnl.get_theme_stylebox("panel").get_minimum_size().y
		var other = outer.get_combined_minimum_size().y - sc.custom_minimum_size.y
		var avail = root.get_viewport_rect().size.y - 56.0 - pad - other
		sc.custom_minimum_size.y = clampf(v.get_combined_minimum_size().y, 0.0, maxf(120.0, avail))
		pnl.size = Vector2(pnl.size.x, 0)   # küçülen içerikte panel de küçülsün
	v.minimum_size_changed.connect(fit)
	fit.call_deferred()
	var card = func() -> VBoxContainer:
		var pc = PanelContainer.new()
		var csb = LazyFx.g("UI")._box(Color(0.03, 0.027, 0.025, 0.55), Color(0, 0, 0, 0), 0, 2, 12)
		csb.content_margin_top = 8; csb.content_margin_bottom = 8
		pc.add_theme_stylebox_override("panel", csb)
		v.add_child(pc)
		var cv = LazyFx.g("UI").vbox(6)
		pc.add_child(cv)
		return cv
	# seçim yan etkileri (köy -> önerilen doğa, klan -> klan doğası)
	var pick = func(key: String, val) -> void:
		state[key] = val
		_cfocus = key
		if key == "village" and Progress.HOME_VILLAGES.has(val):
			state["element"] = Progress.HOME_VILLAGES[val]["element"]
		if key == "clan":
			state["face_paint"] = CharacterModel.CLAN_FACE_PAINT.get(val, "yok")   # klanın kanon yüz boyası (değiştirilebilir)
		if key == "clan" and String(ClanWorld.MAIN_EL.get(val, "")) in ["katon", "suiton", "fuuton", "doton", "raiton"]:
			state["element"] = ClanWorld.MAIN_EL[val]   # klan teknikleri bu doğayı ister
		on_change.call()
		redraw.call()
	# ◀ Ad ▶ oklu seçici (Mangekyō desen seçicisi gibi)
	var carousel = func(title: String, key: String, options: Array, labels: Array, col = LazyFx.g("UI").CREAM) -> VBoxContainer:
		var cv: VBoxContainer = card.call()
		var n = options.size()
		var idx = maxi(0, options.find(state.get(key)))
		# tek hizalı satır: [ad sütunu 130] [◀] [değer, ortalı] [▶] — bütün satırlarda aynı sütunlar, aynı yükseklik
		var row = LazyFx.g("UI").hbox(10)
		row.custom_minimum_size = Vector2(0, 44)
		var tl = LazyFx.g("UI").label(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(title)), 13, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		tl.custom_minimum_size = Vector2(130, 0)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tl)
		row.add_child(_arrow_btn("◀", func(): pick.call(key, options[posmod(idx - 1, n)])))
		var mid = LazyFx.g("UI").vbox(3)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.add_child(LazyFx.g("UI").label(String(labels[idx]), 19, col, HORIZONTAL_ALIGNMENT_CENTER, true))
		# konum noktaları (az seçenekte) ya da sayaç
		if n <= 12:
			var dots = LazyFx.g("UI").hbox(4)
			dots.alignment = BoxContainer.ALIGNMENT_CENTER
			for i in n:
				var d = ColorRect.new()
				d.custom_minimum_size = Vector2(14 if i == idx else 6, 3)
				d.color = LazyFx.g("UI").ACCENT if i == idx else Color(1, 1, 1, 0.2)
				d.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dots.add_child(d)
			mid.add_child(dots)
		else:
			mid.add_child(LazyFx.g("UI").label("%d / %d" % [idx + 1, n], 12, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(mid)
		row.add_child(_arrow_btn("▶", func(): pick.call(key, options[posmod(idx + 1, n)])))
		cv.add_child(row)
		return cv
	var swatches = func(title: String, key: String, cols: Array) -> void:
		var cv: VBoxContainer = card.call()
		var srow = LazyFx.g("UI").hbox(10)
		cv.add_child(srow)
		var stl = LazyFx.g("UI").label(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(title)), 13, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		stl.custom_minimum_size = Vector2(130, 0)
		stl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		srow.add_child(stl)
		var fl = HFlowContainer.new()
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		for c in cols:
			fl.add_child(_swatch(c, Color(state.get(key, Color.BLACK)).is_equal_approx(c), func():
				state[key] = c
				if key in ["top", "pants"]:
					state["dyed_" + key] = true   # elle yapılmış set: seçilen renk kıyafete boya olarak geçer
				_cfocus = key
				on_change.call()
				redraw.call()))
		srow.add_child(fl)
	var note = func(cv: VBoxContainer, text: String, col = LazyFx.g("UI").MUTED) -> void:
		var l = LazyFx.g("UI").label(text, 13, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(l)
	var el_names = {"katon": "Ateş", "suiton": "Su", "fuuton": "Rüzgâr", "doton": "Toprak", "raiton": "Yıldırım"}
	match _ctab:
		"kimlik":
			var nc: VBoxContainer = card.call()
			var nrow = LazyFx.g("UI").hbox(10)
			nc.add_child(nrow)
			var nl = LazyFx.g("UI").label("İSİM", 13, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
			nl.custom_minimum_size = Vector2(130, 0)
			nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nrow.add_child(nl)
			var name_edit = LineEdit.new()
			name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_edit.text = state["name"]
			name_edit.placeholder_text = "Ninja adın (boş kalırsa rastgele)"
			name_edit.max_length = 18
			name_edit.custom_minimum_size = Vector2(0, 44)
			name_edit.add_theme_font_size_override("font_size", 18)
			name_edit.text_changed.connect(func(t): state["name"] = t)
			nrow.add_child(name_edit)
			carousel.call("Cinsiyet", "gender", ["m", "f"], ["Erkek", "Kadın"])
			var vids = Progress.HOME_VILLAGES.keys()
			var vc: VBoxContainer = carousel.call("Köy", "village", vids, vids.map(func(x): return Game.village(x).get("name", x)))
			var vinfo = Progress.HOME_VILLAGES.get(state.get("village", "konoha"), {})
			note.call(vc, "%s  •  Önerilen doğa: %s" % [vinfo.get("kage", ""), el_names.get(String(vinfo.get("element", "katon")), "")])
			# yalnızca seçilen köyün klanları (Suna'da Konoha klanı olmaz); oynanamaz klanlar (Ōtsutsuki) listelenmez
			var hvil = String(state.get("village", "konoha"))
			var clan_ids: Array = Data.clans.keys().filter(func(c): return hvil in Data.clans[c].get("villages", ["konoha"]) and not Progress.UNPLAYABLE_CLANS.has(c))
			if not state["clan"] in clan_ids:
				state["clan"] = "none"
			var cc: VBoxContainer = carousel.call("Klan", "clan", clan_ids, clan_ids.map(func(c): return Data.clans[c]["name"]))
			var cl_d: Dictionary = Data.clans.get(state["clan"], {})
			if cl_d.has("kg"):
				note.call(cc, "Kekkei Genkai: " + String(cl_d["kg"]), LazyFx.g("UI").ACCENT)
			note.call(cc, String(cl_d.get("desc", "")))
			# Kazekage ailesi: üç ayrı soy (anime: Gaara kum, Rasa altın kum, Üçüncü demir kum — kimse hepsini kullanmaz)
			if state["clan"] == "sabaku":
				if not String(state.get("sand_line", "")) in ClanWorld.SAND_LINE_ORDER:
					state["sand_line"] = "suna"
				var sl_ids: Array = ClanWorld.SAND_LINE_ORDER
				var slc: VBoxContainer = carousel.call("Kum Soyu", "sand_line", sl_ids, sl_ids.map(func(k): return ClanWorld.SAND_LINE_NAMES[k]))
				note.call(slc, {"suna": "Shukaku'nun kumu: kum kalkanı, kum zırhı, Sabaku Kyū / Sōsō. Mıknatıs Salınımı yok.",
					"sakin": "Mıknatıs Salınımı ile ağır altın tozu: ezici dalgalar, gömme, kalın duvarlar.",
					"satetsu": "Mıknatıs Salınımı ile demir kum: dikenler, işaretleme, dallanan demir yapılar."}[String(state["sand_line"])])
			# klanın hiden teknikleri: seviye geldikçe kendiliğinden öğrenilir
			var cj = []
			for k in ClanWorld.clan_jutsu_ids(String(state["clan"]), String(state.get("sand_line", ""))):
				cj.append(Data.jutsu[k])
			cj.sort_custom(func(a, b): return int(a.get("level", 1)) < int(b.get("level", 1)))
			if not cj.is_empty():
				var names = cj.map(func(x): return "%s (Güç %d)" % [String(x["name"]).split(" (")[0], int(x.get("level", 1))])
				note.call(cc, "Klan teknikleri: " + ", ".join(names), LazyFx.g("UI").GOLD)
			# klansız: klan adı olmayan nadir kan soyu (Darui'nin Ranton'u, Pakura'nın Shakuton'u gibi) — yalnız o köyde doğar
			var soy_ids: Array = [""]
			if state["clan"] == "none":
				soy_ids.append_array(LazyFx.g("KgPaths").SOY.keys().filter(func(k): return hvil in LazyFx.g("KgPaths").SOY[k]["villages"]))
			if not String(state.get("soy", "")) in soy_ids:
				state["soy"] = ""
			if soy_ids.size() > 1:
				var soy_c: VBoxContainer = carousel.call("Kan Soyu", "soy", soy_ids, soy_ids.map(func(k): return "Yok" if k == "" else String(LazyFx.g("KgPaths").SOY[k]["name"])))
				var sd: Dictionary = LazyFx.g("KgPaths").SOY.get(String(state.get("soy", "")), {})
				if sd.is_empty():
					note.call(soy_c, "Sıradan kan: kekkei genkai yok.")
				else:
					note.call(soy_c, "Kekkei Genkai: %s (Güç %d'de uyanır)" % [LazyFx.g("Elements").NAMES.get(String(sd["nature"]), String(sd["nature"])), int(sd["level"])], LazyFx.g("UI").ACCENT)
					note.call(soy_c, String(sd["desc"]))
			var els = ["katon", "suiton", "fuuton", "doton", "raiton"]
			var ec: VBoxContainer = carousel.call("Chakra Doğası", "element", els, els.map(func(e): return el_names[e]), LazyFx.g("UI").ELEMENT_COLORS.get(state["element"], LazyFx.g("UI").CREAM))
			# klan teknikleri hangi doğaları istiyor: seçilen doğada olmayanlar ikinci doğa alınana kadar kilitli
			var need := {}
			for k in Data.jutsu.keys():
				var jj = Data.jutsu[k]
				if jj is Dictionary and String(jj.get("clan", "")) == state["clan"] and String(jj.get("element", "")) in els:
					need[jj["element"]] = int(need.get(jj["element"], 0)) + 1
			need.erase(state["element"])
			if not need.is_empty():
				var parts = []
				for e in need:
					parts.append((LazyFx.g("Lang").t("%s (1 teknik)") % LazyFx.g("Lang").t(el_names[e])) if int(need[e]) == 1 else (LazyFx.g("Lang").t("%s (%d teknik)") % [LazyFx.g("Lang").t(el_names[e]), need[e]]))
				note.call(ec, LazyFx.g("Lang").t("⚠ Bu doğayla bazı klan teknikleri kilitli kalır: ") + ", ".join(parts) + LazyFx.g("Lang").t(". O doğayı ikinci doğa olarak alınca açılır."), Color(1, 0.7, 0.4))
		"gorunum":
			var hks = CharacterModel.hair_styles_for(String(state["gender"]))
			if not hks.has(state["hair_style"]):
				state["hair_style"] = hks[0]
			carousel.call("Saç Stili", "hair_style", hks, hks.map(func(h): return CharacterModel.HAIR_STYLES[h]))
			# yüz: hazır yüz + yüz hatları (çene, yanak, göz biçimi, kaş)
			var fbn = (CharacterModel.FACE_DONORS_F if String(state["gender"]) == "f" else CharacterModel.FACE_DONORS_M).size()
			state["face_base"] = clampi(int(state.get("face_base", 0)), 0, fbn - 1)
			carousel.call("Yüz", "face_base", range(fbn), range(fbn).map(func(i): return "Yüz %d" % (i + 1)))
			var eans: Array = CharacterModel.eye_art_names()
			if not eans.has(state.get("eye_art")):
				state["eye_art"] = "Kirpikli" if String(state["gender"]) == "f" else "Yuvarlak"
			carousel.call("Göz", "eye_art", eans, eans)
			for fr in [["Yüz Şekli", "face_head", CharacterModel.FACE_HEADS, "Sade"], ["Göz Ayarı", "face_eye", CharacterModel.FACE_EYES, "Sade"], ["İris", "face_iris", CharacterModel.FACE_IRIS, "Normal"],
					["Kaş", "face_brow", CharacterModel.FACE_BROWS, "Sade"], ["Ağız", "face_mouth", CharacterModel.FACE_MOUTHS, "Normal"]]:
				var fks: Array = (fr[2] as Dictionary).keys()
				if not fks.has(state.get(fr[1])):
					state[fr[1]] = fr[3]
				carousel.call(fr[0], fr[1], fks, fks)
			swatches.call("Saç Rengi", "hair", [Color(0.3, 0.2, 0.12), Color(0.08, 0.08, 0.1), Color(0.18, 0.12, 0.1), Color(0.95, 0.8, 0.25), Color(0.98, 0.92, 0.6), Color(0.75, 0.25, 0.15),
				Color(0.95, 0.4, 0.15), Color(0.9, 0.9, 0.92), Color(0.6, 0.6, 0.65), Color(0.2, 0.3, 0.6), Color(0.15, 0.18, 0.35), Color(0.9, 0.55, 0.7), Color(0.55, 0.3, 0.6), Color(0.25, 0.45, 0.25)])
			if state["clan"] == "hoshigaki":
				# Hoshigaki: mavi / soluk gri ten (normal ten seçenekleri yok)
				if not ClanWorld.HOSHIGAKI_SKINS.has(state["skin"]):
					state["skin"] = ClanWorld.HOSHIGAKI_SKINS[0]
				swatches.call("Ten", "skin", ClanWorld.HOSHIGAKI_SKINS)
			else:
				var skins := [Color(0.98, 0.88, 0.8), Color(0.96, 0.8, 0.66), Color(0.86, 0.68, 0.52), Color(0.68, 0.5, 0.36), Color(0.5, 0.36, 0.26)]
				if ClanWorld.HOSHIGAKI_SKINS.has(state["skin"]):
					state["skin"] = skins[1]   # Hoshigaki'den başka klana geçince mavi ten kalıyordu
				swatches.call("Ten", "skin", skins)
			# yüz boyası (Striker Face Paint): klanın kanon boyası varsayılan
			if not state.has("face_paint"):
				state["face_paint"] = CharacterModel.CLAN_FACE_PAINT.get(state["clan"], "yok")
			var fpk: Array = CharacterModel.FACE_PAINTS.keys()
			carousel.call("Yüz Boyası", "face_paint", fpk, fpk.map(func(k): return CharacterModel.FACE_PAINTS[k]))
			if String(state.get("face_paint", "yok")) != "yok":
				var pck: Array = CharacterModel.FACE_PAINT_COLORS.keys()
				carousel.call("Boya Rengi", "face_paint_col_name", pck, pck)
			if not state["clan"] in ["uchiha", "hyuga", "aburame"]:
				swatches.call("Göz Rengi", "eye", [Color(0.25, 0.45, 0.8), Color(0.3, 0.2, 0.12), Color(0.25, 0.55, 0.3), Color(0.1, 0.1, 0.1), Color(0.6, 0.4, 0.15), Color(0.55, 0.55, 0.6), Color(0.6, 0.25, 0.55)])
		"kiyafet":
			# kıyafet artık set olarak giyilir (parçalar iç içe geçmesin)
			var ss = LazyFx.g("Gear").start_sets(String(state.get("gender", "m")), String(state.get("clan", "")))
			if state.has("start_set") and not String(state["start_set"]) in ss:
				state["start_set"] = ss[0]   # cinsiyet değişince karşı cinsin seti seçili kalmasın
			var sl = ss.map(func(x): return String(LazyFx.g("Gear").item(x).get("name", x)))
			carousel.call("Kıyafet Seti", "start_set", ss, sl)
			var outfit_cols = [Color(0.15, 0.2, 0.33), Color(0.15, 0.15, 0.17), Color(0.45, 0.15, 0.15), Color(0.95, 0.5, 0.12), Color(0.2, 0.38, 0.22), Color(0.35, 0.25, 0.45), Color(0.85, 0.82, 0.75), Color(0.15, 0.4, 0.45)]
			swatches.call("Üst Rengi", "top", outfit_cols)
			swatches.call("Alt Rengi", "pants", outfit_cols)
	if not keep_scroll.is_empty():
		_restore_scroll.call_deferred(keep_scroll)
		Engine.get_main_loop().process_frame.connect(_restore_scroll.bind(keep_scroll), CONNECT_ONE_SHOT)   # yerleşim bittikten sonra bir kez daha
	# sağ üst: özet kartı
	var sum = PanelContainer.new()
	sum.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(14, 16, 0.7))
	sum.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sum.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sum.offset_left = -440; sum.offset_right = -28; sum.offset_top = 28
	root.add_child(sum)
	var sv = LazyFx.g("UI").vbox(4)
	sum.add_child(sv)
	var nm = String(state.get("name", "")).strip_edges()
	sv.add_child(LazyFx.g("UI").label(nm if nm != "" else "İsimsiz Ninja", 24, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var cname = String(Data.clans.get(state["clan"], {}).get("name", "Klansız"))
	sv.add_child(LazyFx.g("UI").label("%s  •  %s  •  %s" % [LazyFx.g("Lang").t(String(Game.village(String(state.get("village", "konoha"))).get("name", ""))), cname, LazyFx.g("Lang").t(String(el_names.get(String(state["element"]), "")))], 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	# sağ alt: eylemler
	var bar = LazyFx.g("UI").hbox(12)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = -28; bar.offset_top = -28; bar.offset_right = -28; bar.offset_bottom = -28
	root.add_child(bar)
	bar.add_child(LazyFx.g("UI").button("Rastgele", func():
		_creator_random(state)
		on_change.call()
		redraw.call(), 170, "star"))
	bar.add_child(LazyFx.g("UI").button("Geri", func(): main.back_to_menu(), 140, "arrow"))
	bar.add_child(LazyFx.g("UI").primary("Maceraya Başla!", on_start, 300, "play"))
	var hint = LazyFx.g("UI").icon_label("person", "Sürükleyerek karakteri döndür", 14, LazyFx.g("UI").MUTED)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = -36; hint.offset_top = -92; hint.offset_right = -36; hint.offset_bottom = -92
	root.add_child(hint)


## İlişkiler sekmesi: solda seçili kişinin kartı + tanıdığın herkes (bağa göre renkli), sağda köylerle itibar ve diplomasi
static func _tab_relations(main: Node, body: Control) -> void:
	var h = LazyFx.g("UI").hbox(26)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left = _scroll(h, 780, 900)
	left.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.get_parent().custom_minimum_size.y = 0.0   # sabit 900 px ekrandan taşıyordu: listenin altına inilemiyordu
	_friends_card(main, left)
	var fs: Dictionary = LazyFx.g("Friends").listed()   # defnedilenler listeden düşer (mezarlıkta adları yazar)
	if not fs.is_empty():
		var lc = LazyFx.g("UI").card()
		left.add_child(lc)
		var lv = LazyFx.g("UI").vbox(4)
		lc.add_child(lv)
		lv.add_child(LazyFx.g("UI").icon_label("person", "TANIDIĞIN HERKES", 15, LazyFx.g("UI").GOLD))
		var ids = fs.keys()
		var order = ids.duplicate()
		order.sort_custom(func(a, b): return int(fs[a]["bond"]) > int(fs[b]["bond"]))
		for id in order:
			var f: Dictionary = fs[id]
			var b = int(f["bond"])
			var stt = String(f.get("status", ""))
			var txt = "%s  —  %s, %s, %d yaş  •  %s (%d)%s" % [f["name"], String(f.get("title", "")), LazyFx.g("Friends").rank_label(f), int(Aging.person_years(f)), LazyFx.g("Friends").bond_label(f), b,
				"  •  ÖLDÜ" if stt == "öldü" else ("  •  KAÇAK" if stt == "kaçak" else ("  ★ takımda" if f.get("party", false) else ""))]
			var row = LazyFx.g("UI").chip(txt, ids.find(id) == _friend_i, func():
				_friend_i = ids.find(id)
				ninja_menu(main, "relations"))
			if ids.find(id) != _friend_i:
				row.add_theme_color_override("font_color", LazyFx.g("Friends").level_color(b) if stt == "" else LazyFx.g("UI").MUTED)
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lv.add_child(row)
	# köyler
	var right = LazyFx.g("UI").vbox(14)
	right.custom_minimum_size = Vector2(560, 0)
	h.add_child(right)
	# senin ailen: eş + çocuklar
	var pr = Game.profile
	var kids: Array = pr.get("children", [])
	if LazyFx.g("Friends").spouse_id() != "" or not kids.is_empty() or not LazyFx.g("Kin").rows().is_empty():
		var ac = LazyFx.g("UI").card(Color(1, 0.6, 0.75))
		right.add_child(ac)
		var av = LazyFx.g("UI").vbox(6)
		ac.add_child(av)
		av.add_child(LazyFx.g("UI").icon_label("heart", "AİLEN", 15, Color(1, 0.65, 0.78)))
		# her aile üyesi tıklanır: dost kaydı olanlar (eş, mezun çocuk) arkadaş kartında açılır + haritada işaretlenir;
		# küçük çocuklar evinde yaşar, evin işaretlenir
		var fids = fs.keys()
		for kr in LazyFx.g("Kin").rows():
			var kid_id = String(kr[1])
			av.add_child(_family_row("%s  —  %s" % [kr[0], LazyFx.g("Friends").where_text(kid_id)], func():
				_friend_i = fids.find(kid_id)
				LazyFx.g("Friends").show_on_map(kid_id)
				ninja_menu(main, "relations")))
		var sid = LazyFx.g("Friends").spouse_id()
		if sid != "" and fs.has(sid):
			av.add_child(_family_row("Eşin: %s  —  %s" % [fs[sid]["name"], LazyFx.g("Friends").where_text(sid)], func():
				_friend_i = fids.find(sid)
				LazyFx.g("Friends").show_on_map(sid)
				ninja_menu(main, "relations")))
		for k in kids:
			var cl: Array = k.get("clans", [])
			var mix = ("  [%s melezi]" % " × ".join(cl.map(func(c): return ClanWorld.clan_name(c)))) if cl.size() >= 2 and cl[0] != cl[1] else ""
			var rel = "Kızın" if k["gender"] == "f" else "Oğlun"
			var kname = String(k["name"])
			var kfid = ""
			if k.get("grad", false):
				for id in fids:
					if String(fs[id]["name"]) == kname:
						kfid = String(id)
			if kfid != "":
				av.add_child(_family_row("%s: %s%s  —  %s" % [rel, kname, mix, LazyFx.g("Friends").where_text(kfid)], func():
					_friend_i = fids.find(kfid)
					LazyFx.g("Friends").show_on_map(kfid)
					ninja_menu(main, "relations")))
			else:
				av.add_child(_family_row("%s: %s%s  —  %s" % [rel, kname, mix, LazyFx.g("KidLife").stage_text(k)], func():
					if LazyFx.g("KidLife").at_school(k) and LazyFx.g("SchoolVisit").yard() != Vector3.INF:
						var yp = LazyFx.g("SchoolVisit").yard()
						Game.profile["waypoint"] = [yp.x, yp.y, yp.z, "Akademi (%s)" % kname.split(" ")[-1]]
						Game.profile["track"] = "waypoint"
						Hud.msg("Akademi işaretlendi: avluda talim yapıyor.", Color(1, 0.8, 0.88))
					else:
						_mark_home()
					main.resume()))
		if float(pr.get("baby_due", 0.0)) > 0.0:
			av.add_child(LazyFx.g("UI").label("Bir bebek yolda ♥", 13, Color(1, 0.75, 0.8)))
	var vc = LazyFx.g("UI").card(LazyFx.g("UI").GOLD)
	right.add_child(vc)
	var vv = LazyFx.g("UI").vbox(8)
	vc.add_child(vv)
	vv.add_child(LazyFx.g("UI").icon_label("village", "KÖYLER — İTİBAR VE DİPLOMASİ", 15, LazyFx.g("UI").GOLD))
	var rep: Dictionary = Game.profile.get("rep", {})
	for vid in Kage.GREAT:
		var r = int(rep.get(vid, 0))
		var rel = Kage.relation(vid) if vid != Progress.home() else 100
		var rt = "Kahraman" if r >= 150 else ("Saygın" if r >= 50 else ("Tanınmıyor" if r >= 0 else ("Kötü şöhretli" if r > -50 else "Aranıyor")))
		var dt = "Kendi köyün" if vid == Progress.home() else LazyFx.g("WorldRelations").state(Progress.home(), vid)
		vv.add_child(LazyFx.g("UI").label("%s  •  %s" % [Game.village(vid).get("name", vid), Kage.kage_name(vid)], 15, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		vv.add_child(LazyFx.g("UI").label("İtibarın: %d (%s)   •   Köyünle ilişkisi: %s" % [r, rt, dt], 13, Color(1, 0.45, 0.4) if rel <= -40 or r < 0 else LazyFx.g("UI").MUTED))
		var bar = LazyFx.g("UI").bar(Color(1, 0.4, 0.35) if rel < 0 else Color(0.55, 1.0, 0.7), 500, 6)
		bar.min_value = -100
		bar.max_value = 100
		bar.value = rel
		vv.add_child(bar)
	var wars = []
	for wk in LazyFx.g("WorldRelations").D()["war"]:
		var ab = String(wk).split("|")
		wars.append("%s – %s" % [LazyFx.g("WorldRelations").vn(ab[0]), LazyFx.g("WorldRelations").vn(ab[1])])
	var minors = []
	for m in LazyFx.g("WorldRelations").MINOR:
		if Game.village(m).is_empty():
			continue
		var sw = LazyFx.g("WorldRelations").sway_of(m)
		minors.append("%s: %s%s" % [LazyFx.g("WorldRelations").vn(m), LazyFx.g("Lang").t(LazyFx.g("WorldRelations").state(Progress.home(), m)), (" (" + LazyFx.g("Lang").t("%s hakimiyetinde") % LazyFx.g("WorldRelations").vn(sw) + ")") if sw != "" else ""])
	if not minors.is_empty():
		var ml = LazyFx.g("UI").label(LazyFx.g("Lang").t("Küçük köyler — ") + ", ".join(minors), 13, LazyFx.g("UI").MUTED)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.custom_minimum_size = Vector2(520, 0)
		vv.add_child(ml)
	if not wars.is_empty():
		vv.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("Süren savaşlar: ") + ", ".join(wars), 13, Color(1, 0.5, 0.45), HORIZONTAL_ALIGNMENT_LEFT, true))
	var note = LazyFx.g("UI").label("İtibarın tanıştığın ninjaların sana ilk bakışını belirler; köylerin arası açılırsa sınırlarda ve köyünde baskınlar başlar. Köyler kendi aralarında da anlaşır ve savaşır; köyün işin içindeyse görev panosuna ilan düşer.", 12, LazyFx.g("UI").MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(520, 0)
	vv.add_child(note)


## AİLEN kartı satırı: sola yaslı, tıklanır
static func _family_row(text: String, cb: Callable) -> Button:
	var b = LazyFx.g("UI").chip(text, false, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", Color(1, 0.82, 0.88))
	return b


## Oyuncunun evinin kapısını haritada işaretle (küçük çocuklar orada yaşar)
static func _mark_home() -> void:
	for it in Interact.items:
		if String(it.get("room", "")) == "home_player":
			var p: Vector3 = it["pos"]
			Game.profile["waypoint"] = [p.x, p.y, p.z, "Evin"]
			Game.profile["track"] = "waypoint"
			Hud.msg("Evin haritada işaretlendi: çocukların orada.", Color(1, 0.8, 0.88))
			return
	Hud.msg("Evin kendi köyünde; çocukların orada seni bekliyor.", Color(1, 0.8, 0.88))


static var _friend_i := 0
## Arkadaşlar: ◀ ▶ ile gez; bağ çubuğu, takıma al / köyde beklet
static func _friends_card(main: Node, left: Control) -> void:
	var fs: Dictionary = LazyFx.g("Friends").listed()
	var fc = LazyFx.g("UI").card(Color(0.6, 1.0, 0.75))
	left.add_child(fc)
	var fv = LazyFx.g("UI").vbox(8)
	fc.add_child(fv)
	var party = LazyFx.g("Friends").party_ids()
	fv.add_child(LazyFx.g("UI").icon_label("person", "ARKADAŞLAR (%d)  •  Takımda: %d / %d" % [fs.size(), party.size(), LazyFx.g("Friends").party_max()], 15, Color(0.6, 1.0, 0.75)))
	if fs.is_empty():
		var hl = LazyFx.g("UI").label("Köydeki ninjalarla (klan üyeleri, devriye ve antrenman ninjaları) konuş ([F]) ve kendini tanıt. Sohbet, hediye ve dostça düello bağı güçlendirir; bağ %d olunca takımına katılırlar." % LazyFx.g("Friends").JOIN_BOND, 13, LazyFx.g("UI").MUTED)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(700, 0)
		fv.add_child(hl)
		return
	var ids = fs.keys()
	_friend_i = posmod(_friend_i, ids.size())
	var labels = ids.map(func(k): return "%s%s" % [fs[k]["name"], "  ★" if fs[k].get("party", false) else ""])
	fv.add_child(_arrow_row("Arkadaş", labels, _friend_i, func(i):
		_friend_i = i
		ninja_menu(main, "relations")))
	var id = String(ids[_friend_i])
	var f: Dictionary = fs[id]
	var b = int(f.get("bond", 0))
	var stt = String(f.get("status", ""))
	var st_txt = ""
	if stt == "öldü":
		st_txt = "  •  ÖLDÜ"
	elif stt == "kaçak":
		st_txt = "  •  Kaçak — sana borçlu" if LazyFx.g("Friends").bingo_status(id) == "spared" else ("  •  KAÇAK (Bingo Kitabı)" if LazyFx.g("Friends").bingo_status(id) != "dead" else "  •  Kaçak — yakalandı/öldü")
	elif String(f.get("kage", "")) != "":
		st_txt = "  •  %s!" % LazyFx.g("Lang").t(String(Progress.kage_title(String(f["kage"]))))
	elif stt == "hapiste":
		st_txt = LazyFx.g("Lang").t("  •  HAPİSTE")
	elif stt == "" and Orgs.is_rogue() and not f.get("rogue", false):
		st_txt = LazyFx.g("Lang").t("  •  Köyde — seni artık kaçak biliyor (dost değil)")
	elif not LazyFx.g("Friends").available(f):
		var mins = ceili((float(f.get("away", 0.0)) - Time.get_unix_time_from_system()) / 60.0)
		st_txt = (LazyFx.g("Lang").t("  •  Hastanede: %s (~%d dk)") % [LazyFx.g("Lang").t(String(f["injury"])), mins]) if f.has("injury") and float(f.get("inj_away", -1.0)) == float(f.get("away", 0.0)) else LazyFx.g("Lang").t("  •  Köyde değil (görev)")
	elif not f.get("party", false):
		st_txt = "  •  " + LazyFx.g("Lang").t(String(LazyFx.g("Friends").JOB_NAMES.get(LazyFx.g("Friends").job_of(f), "Evde")))
	var rm = LazyFx.g("Friends").romance_of(id)
	if rm != "":
		st_txt += "  •  %s ♥" % LazyFx.g("Lang").t(String({"eş": "Eşin", "sevgili": "Sevgilin", "flört": "Flört"}.get(rm, rm)))
	fv.add_child(LazyFx.g("UI").label("%s  •  %s  •  %d yaşında  •  %s: %d (%s)%s" % [String(f.get("title", "")), LazyFx.g("Friends").rank_label(f), int(Aging.person_years(f)), LazyFx.g("Lang").t("Güven") if f.get("rogue", false) else LazyFx.g("Lang").t("Bağ"), b, LazyFx.g("Lang").t(LazyFx.g("Friends").bond_label(f)), st_txt], 13, LazyFx.g("Friends").level_color(b)))
	if f.get("rogue", false) and int(f.get("motive_known", 0)) > 0:
		fv.add_child(LazyFx.g("UI").label("Neden kaçtı: " + String(LazyFx.g("RogueBonds").motive_of(f)[int(f["motive_known"])]), 12, Color(0.85, 0.8, 0.7), HORIZONTAL_ALIGNMENT_LEFT, true))
	var bar = LazyFx.g("UI").bar(LazyFx.g("Friends").level_color(b), 700, 8)
	bar.min_value = -100
	bar.max_value = 100
	bar.value = b
	fv.add_child(bar)
	if LazyFx.g("Friends").TRAITS.has(String(f.get("trait", ""))) and LazyFx.g("Friends").trait_known(f):
		fv.add_child(LazyFx.g("UI").label("Kişilik: " + String(LazyFx.g("Friends").TRAITS[f["trait"]]["desc"]), 12, Color(0.85, 0.85, 1.0)))
	elif f.has("trait"):
		fv.add_child(LazyFx.g("UI").label("Kişilik: ? (onunla birkaç kez sohbet et)", 12, LazyFx.g("UI").MUTED))
	if rm != "" and rm != "eş":
		fv.add_child(LazyFx.g("UI").label("Gönül: %d/100  (iltifat, gece yürüyüşü, randevu, sevdiği hediye; evlilik için sevgili olarak zaman + gönül/bağ 85)" % int(f.get("love", 0)), 12, Color(1, 0.65, 0.8)))
	if int(f.get("gift_known", -1)) >= 0:
		fv.add_child(LazyFx.g("UI").label("Sevdiği hediye: " + String(LazyFx.g("Friends").GIFTS[int(f["gift_known"])][0]), 12, Color(1, 0.75, 0.8)))
	var fam: Array = f.get("family", [])
	if not fam.is_empty():
		var fl = LazyFx.g("UI").label(LazyFx.g("Lang").t("Ailesi: ") + ", ".join(fam.map(func(m): return "%s %s%s%s" % [LazyFx.g("Lang").t(String(m["rel"])), String(m["name"]), (" [%s]" % m["mix"]) if m.has("mix") else "", "" if m.get("alive", true) else LazyFx.g("Lang").t(" (öldü)")])), 12, LazyFx.g("UI").MUTED)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(700, 0)
		fv.add_child(fl)
	var lg: Array = f.get("log", [])
	if not lg.is_empty():
		var ll = LazyFx.g("UI").label("Son olaylar: " + "  •  ".join(lg.slice(maxi(0, lg.size() - 3))), 12, Color(0.85, 0.85, 0.7))
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(700, 0)
		fv.add_child(ll)
	if stt != "öldü":
		fv.add_child(LazyFx.g("UI").button("Haritada göster", func():
			LazyFx.g("Friends").show_on_map(id)
			main.resume(), 260, "map"))
	if stt == "" and not (Orgs.is_rogue() and not f.get("rogue", false)):
		if f.get("party", false):
			fv.add_child(LazyFx.g("UI").button("Köyde beklet", func():
				LazyFx.g("Friends").set_party(id, false)
				ninja_menu(main, "relations"), 260, "person"))
		elif b >= LazyFx.g("Friends").JOIN_BOND:
			fv.add_child(LazyFx.g("UI").button("Takıma al", func():
				LazyFx.g("Friends").set_party(id, true)
				ninja_menu(main, "relations"), 260, "person"))
		else:
			fv.add_child(LazyFx.g("UI").label("Takıma katılması için bağ %d olmalı: köyde rastlayınca sohbet et, hediye ver, dostça düello yap." % LazyFx.g("Friends").JOIN_BOND, 13, LazyFx.g("UI").MUTED))
	# Unut: ilişkiler listesinden kaldır (onay ister; eş, öğrenci ve takım hocası unutulmaz)
	fv.add_child(LazyFx.g("UI").button("Unut", func():
		var why = LazyFx.g("Friends").forget_block(id)
		if why != "":
			Hud.msg(why, Color(1, 0.7, 0.45))
			return
		Hud.dialog("Unut", "%s ilişkiler listenden silinsin mi? Geri alınamaz." % String(f["name"]), [
			{"label": "Evet, unut", "cb": func():
				LazyFx.g("Friends").forget(id)
				ninja_menu(main, "relations")},
			{"label": "Vazgeç", "cb": func(): pass}]), 260, "person"))


## Başlık + ◀ Ad (n/N) ▶ satırı; on_pick(yeni_indeks). Seçenekler hep böyle oklarla gezilir, tek tek dizilmez
static func _arrow_row(title: String, labels: Array, idx: int, on_pick: Callable) -> Control:
	var n = labels.size()
	idx = clampi(idx, 0, maxi(n - 1, 0))
	var row = LazyFx.g("UI").hbox(10)
	var tl = LazyFx.g("UI").label(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(title)), 13, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	tl.custom_minimum_size = Vector2(110, 0)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tl)
	# satır kendi yazısını günceller (sekme yeniden çizilmese de seçim görünür)
	var cur = [idx]
	var name_l = LazyFx.g("UI").label(String(labels[idx]) if n > 0 else "-", 17, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	var cnt_l = LazyFx.g("UI").label("%d / %d" % [idx + 1, n], 12, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var go = func(d: int) -> void:
		if n <= 0:
			return
		cur[0] = posmod(cur[0] + d, n)
		if is_instance_valid(name_l):
			name_l.text = String(labels[cur[0]])
		if is_instance_valid(cnt_l):
			cnt_l.text = "%d / %d" % [cur[0] + 1, n]
		on_pick.call(cur[0])
	row.add_child(_arrow_btn("◀", func(): go.call(-1)))
	var mid = LazyFx.g("UI").vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size = Vector2(200, 0)
	mid.add_child(name_l)
	mid.add_child(cnt_l)
	row.add_child(mid)
	row.add_child(_arrow_btn("▶", func(): go.call(1)))
	return row


## Ok düğmesi (◀ ▶): köşeli mürekkep kare, üzerine gelince kırmızı
static func _arrow_btn(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", LazyFx.g("UI").font(true))
	b.add_theme_font_size_override("font_size", 16)
	var n = LazyFx.g("UI")._box(Color(0.03, 0.027, 0.025, 0.8), Color(LazyFx.g("UI").TEXT, 0.22), 1, 2, 6)
	var h = LazyFx.g("UI")._box(LazyFx.g("UI").ACCENT, Color(LazyFx.g("UI").TEXT, 0.4), 1, 2, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", n)
	b.add_theme_color_override("font_color", LazyFx.g("UI").CREAM)
	for k in ["font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color(1, 0.97, 0.93))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.15))
	return b


## Rastgele görünüm (köy/klan/doğa korunur)
static func _creator_random(state: Dictionary) -> void:
	state["gender"] = ["m", "f"].pick_random()
	state["hair_style"] = CharacterModel.hair_styles_for(state["gender"]).filter(func(h): return h != "kel").pick_random()
	state["face_base"] = randi() % 4
	state["eye_art"] = CharacterModel.eye_art_names().pick_random()
	state["face_head"] = CharacterModel.FACE_HEADS.keys().pick_random()
	state["face_eye"] = CharacterModel.FACE_EYES.keys().pick_random()
	state["face_iris"] = CharacterModel.FACE_IRIS.keys().pick_random()
	state["face_brow"] = CharacterModel.FACE_BROWS.keys().pick_random()
	state["face_mouth"] = CharacterModel.FACE_MOUTHS.keys().pick_random()
	state["hair"] = [Color(0.3, 0.2, 0.12), Color(0.08, 0.08, 0.1), Color(0.95, 0.8, 0.25), Color(0.75, 0.25, 0.15), Color(0.9, 0.9, 0.92), Color(0.2, 0.3, 0.6), Color(0.9, 0.55, 0.7), Color(0.95, 0.4, 0.15)].pick_random()
	state["skin"] = [Color(0.98, 0.88, 0.8), Color(0.96, 0.8, 0.66), Color(0.86, 0.68, 0.52), Color(0.68, 0.5, 0.36)].pick_random()
	state["eye"] = [Color(0.25, 0.45, 0.8), Color(0.3, 0.2, 0.12), Color(0.25, 0.55, 0.3), Color(0.1, 0.1, 0.1)].pick_random()
	state["top_style"] = CharacterModel.TOP_STYLES.keys().pick_random()
	state["pants_style"] = CharacterModel.PANTS_STYLES.keys().pick_random()
	var oc = [Color(0.15, 0.2, 0.33), Color(0.15, 0.15, 0.17), Color(0.45, 0.15, 0.15), Color(0.95, 0.5, 0.12), Color(0.2, 0.38, 0.22), Color(0.35, 0.25, 0.45), Color(0.85, 0.82, 0.75), Color(0.15, 0.4, 0.45)]
	state["top"] = oc.pick_random()
	state["top2"] = oc.pick_random()
	state["pants"] = oc.pick_random()


# ================================================================== duraklatma
static func pause(main: Node) -> void:
	var bg = _full(0.6)
	var root = LazyFx.g("UI").vbox(6)
	root.position = Vector2(110, 110)
	bg.add_child(root)
	root.add_child(LazyFx.g("UI").label("DURAKLATILDI", 15, LazyFx.g("UI").ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
	root.add_child(LazyFx.g("UI").label(String(Game.profile.get("name", "")), 54, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	root.add_child(LazyFx.g("UI").label("%s  •  %d yaşında  •  %s" % [Orgs.rogue_rank_name() if Orgs.is_rogue() else Data.RANKS[int(Game.profile.get("rank", 0))], int(Aging.player_years()), Game.region_name(Game.player.global_position) if Game.player else ""], 17, LazyFx.g("UI").MUTED))
	root.add_child(LazyFx.g("UI").spacer(0, 26, false))
	var items = [["Devam", "play", func(): main.resume()], ["Ninja Menüsü", "bag", func(): ninja_menu(main, last_tab())],
		["Ekipman ve Kıyafetler", "armor", func(): ninja_menu(main, "wardrobe")], ["Jutsular", "scroll", func(): ninja_menu(main, "jutsu")],
		["Harita", "map", func(): region_map(main)], ["Ayarlar", "settings", func(): settings(func(): pause(main))],
		["Kaydet", "save", func():
			Game.save_game()
			Hud.msg("Oyun kaydedildi.", Color(0.6, 1, 0.6))],
		["Ana Menüye Dön (kaydeder)", "home", func(): main.to_main_menu()], ["Oyundan Çık (kaydeder)", "exit", func():
			Game.save_game()
			main.get_tree().quit()]]
	for i in items.size():
		var b = _menu_entry(items[i][0], items[i][1], items[i][2])
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(440, 50)
		root.add_child(b)
		if _fresh:
			LazyFx.g("UI").slide_in(b, -24.0, 0.025 * i)


static var _ctl_info := ""   # son atamanın kısa bilgisi (yer değiştirme vb.)
static var _ctl_scroll := 0


const CTL_ICONS := ["sandal", "hand", "chakra", "bag", "book", "scroll"]
static var _ctl_bg: Control = null
static var _ctl_focus := -1   # klavyeyle seçili tuş (yeniden çizimde korunur)


## Kontroller: hiçbir tuş seçili değilken aşağı / yukarı ok ilk tuşu seçer
static func controls_focus_first() -> bool:
	if not is_instance_valid(_ctl_bg) or _ctl_bg.is_queued_for_deletion() or Keys.capturing:
		return false
	if _ctl_bg.get_viewport().gui_get_focus_owner() != null:
		return false
	var ks = _ctl_bg.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("key_i"))
	if ks.is_empty():
		return false
	ks[0].grab_focus()
	return true


## Kontroller ekranında Esc: geri (tuş beklerken değil). Ele alındıysa true
static func controls_escape() -> bool:
	if Keys.capturing or not is_instance_valid(_ctl_bg) or _ctl_bg.is_queued_for_deletion():
		return false
	var back: Callable = _ctl_bg.get_meta("back")
	_ctl_bg = null
	back.call()
	return true


static func controls(back: Callable, keep := false) -> void:
	if not keep:
		_ctl_info = ""
		_ctl_scroll = 0
		_ctl_focus = -1
	var from_set := _set_sub   # ayarlardan gelindi: sol rayda ayar sekmeleri (Kontrol seçili)
	var k := _set_keep
	_set_keep = k or _set_sub   # ayarlardan gelindiyse yeniden çizim ayarları geri almasın
	var bg = _full()
	_set_keep = k
	_ctl_bg = bg
	bg.set_meta("back", back)
	var on_tab := Callable()
	if from_set:
		on_tab = func(id):
			_set_tab = id
			_set_scroll = 0
			_set_focus = -1
			back.call()
	var rw := _set_frame(bg, "Kontroller", "controls", on_tab, "geri")
	_close_button(bg, func(): back.call())
	var cw = bg.get_viewport_rect().size.x - rw - 72
	var ncol := 3 if cw >= 1450.0 else (2 if cw >= 860.0 else 1)
	var area = Control.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_left = rw + 36; area.offset_top = 90; area.offset_right = -36; area.offset_bottom = -96
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(area)
	var top = LazyFx.g("UI").vbox(10)
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(top)
	var tp = PanelContainer.new()
	var tsb = LazyFx.g("UI")._box(Color(0.02, 0.022, 0.03, 0.82), Color(0, 0, 0, 0), 0, 6, 10)
	tsb.border_width_left = 3
	tsb.border_color = Color(LazyFx.g("UI").GOLD, 0.6)
	tsb.content_margin_left = 16
	tp.add_theme_stylebox_override("panel", tsb)
	var tip = LazyFx.g("UI").label("Değiştirmek istediğin tuşa tıkla, sonra yeni tuşa ya da fare düğmesine bas. Başka eylemdeki bir tuşu seçersen ikisi yer değiştirir.", 15, LazyFx.g("UI").TEXT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(120, 0)
	tp.add_child(tip)
	top.add_child(tp)
	var info = LazyFx.g("UI").label(_ctl_info, 15, LazyFx.g("UI").GOLD)
	info.visible = _ctl_info != ""
	top.add_child(info)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = true
	top.add_child(sc)
	var keys_list := []
	var cols = LazyFx.g("UI").hbox(24)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var colv := []
	for i in ncol:
		var c = LazyFx.g("UI").vbox(22)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c)
		colv.append(c)
	var place: Array = [[0, 0, 0, 0, 0, 0], [0, 0, 1, 1, 1, 0], [0, 1, 1, 2, 2, 0]][ncol - 1]   # grupların sütunu
	for gi in Keys.GROUPS.size():
		var g = Keys.GROUPS[gi]
		var sec = _set_section(colv[place[gi]], CTL_ICONS[gi % CTL_ICONS.size()], String(g[0]))
		for r in g[1]:
			var a: String = r[0]
			var h = _set_row(sec, r[1], 120, 16, 46)
			h.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in Keys.binds[a].size():
				var code: int = Keys.binds[a][i]
				var kb = _key_btn(Keys.code_name(code), code != Keys.defaults(a)[i], func(): _ctl_capture(back, sc, a, i))
				var ki := keys_list.size()
				kb.set_meta("key_i", ki)
				kb.focus_entered.connect(func(): _ctl_focus = ki)
				keys_list.append(kb)
				h.add_child(kb)
	# değişmeyen tuşlar ve tuş birleşimleri (atanan tuşla yazılır)
	var fixed = [["Fare", "Kamera"], ["Fare tekerleği", "Kamera uzaklığı"], ["Esc", "Menü / geri"], ["%s + 1-9, 0, -, =" % Keys.name("seal_mode"), "Mühür ör"],
		["Duvarda %s" % Keys.name("leap"), "Duvar atılımı (chakra)"],
		["Havada %s" % Keys.name("attack"), "Hava kombosu (rakip yakınsa) / dalış tekmesi"]]
	var fs = _set_section(colv[ncol - 1], "lock", "Sabit")
	for f in fixed:
		var h = _set_row(fs, f[1], 120, 16, 46)
		h.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.get_child(0).add_theme_color_override("font_color", LazyFx.g("UI").MUTED)
		var kb = PanelContainer.new()
		kb.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 1, 8, 6))
		kb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kb.add_child(LazyFx.g("UI").label(f[0], 14, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
		h.add_child(kb)
	var keep_scroll := _ctl_scroll
	if keep_scroll > 0:
		sc.get_v_scroll_bar().changed.connect(func(): sc.scroll_vertical = keep_scroll, CONNECT_ONE_SHOT)
	if _fresh:
		LazyFx.g("UI").pop_in(area, 0.985)
	# klavyeyle atanan tuş yeniden çizimde seçili kalsın (sonraki tuşa ok ile geçilebilsin)
	if _ctl_focus >= 0 and _ctl_focus < keys_list.size():
		keys_list[_ctl_focus].call_deferred("grab_focus")
	_set_bottom(bg, rw, "Varsayılana Dön", "hourglass", func():
		Keys.reset_all()
		_ctl_info = "Tüm tuşlar varsayılana döndü."
		_ctl_scroll = sc.scroll_vertical
		controls(back, true), "Geri", "arrow", func(): back.call())


## Tuş kapağı: koyu, altı kalın altın çizgili; değiştirilmiş tuş altın dolgulu
static func _key_btn(text: String, changed: bool, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(118, 38)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", LazyFx.g("UI").font(true))
	b.add_theme_font_size_override("font_size", 14)
	var n = LazyFx.g("UI")._box(Color(LazyFx.g("UI").GOLD, 0.92) if changed else Color(0.07, 0.075, 0.095, 0.95), Color(LazyFx.g("UI").GOLD, 0.45), 1, 7, 4)
	n.border_width_bottom = 3
	var hv = LazyFx.g("UI")._box(Color(1.0, 0.86, 0.55) if changed else Color(0.16, 0.15, 0.13, 0.98), LazyFx.g("UI").GOLD, 1, 7, 4)
	hv.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, LazyFx.g("UI").INK if changed else LazyFx.g("UI").CREAM)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.18))
	return b


## Yeni tuşu bekle: ekranı kaplayan katman bütün tuş / fare basışlarını yutar (oyuna ve menülere gitmez)
static func _ctl_capture(back: Callable, sc: ScrollContainer, action: String, idx: int) -> void:
	_ctl_scroll = sc.scroll_vertical
	var ov = ColorRect.new()
	ov.color = Color(0, 0, 0, 0.7)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.focus_mode = Control.FOCUS_ALL
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var vb = LazyFx.g("UI").vbox(10)
	vb.add_child(LazyFx.g("UI").label(Keys.label(action), 28, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))
	vb.add_child(LazyFx.g("UI").label("Yeni tuşa ya da fare düğmesine bas", 18, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(LazyFx.g("UI").label("Esc: vazgeç", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	cc.add_child(vb)
	Hud.dialog_layer.get_child(Hud.dialog_layer.get_child_count() - 1).add_child(ov)
	Keys.capturing = true
	ov.tree_exiting.connect(func(): Keys.capturing = false)
	ov.gui_input.connect(func(e: InputEvent):
		if not ((e is InputEventKey or e is InputEventMouseButton) and e.pressed):
			return
		ov.accept_event()
		if e is InputEventKey and e.is_echo():
			return
		if e is InputEventKey and (e.physical_keycode == KEY_ESCAPE or e.keycode == KEY_ESCAPE):
			_ctl_info = ""
		else:
			_ctl_info = Keys.rebind(action, idx, Keys.event_code(e))
		Keys.capturing = false
		Menus.controls.call_deferred(back, true))
	ov.grab_focus()


# ================================================================== ayarlar
static var _set_bg: Control = null   # açık ayarlar ekranı (yeniden çizimde yenisiyle değişir)
static var _set_snap := {}           # ekran açılırkenki ayarlar: kaydetmeden çıkılırsa buna dönülür
static var _set_keep := false        # yeniden çizim / kaydetme sürüyor: geri alma
static var _set_scroll := 0
static var _set_sub := false        # ayarlardan Kontroller'e geçildi (ayarlar kaydedilmeden açık sayılır)


static func settings_open() -> bool:
	return is_instance_valid(_set_bg) and not _set_bg.is_queued_for_deletion()


static var _set_keys := {}   # ekran açılırkenki tuş atamaları (kaydetmeden çıkınca geri konur)
static var _view_live := -1.0   # dünyaya şu an uygulanmış görüş mesafesi (kaydırırken önizleme)


## Görüş mesafesi önizlemesi: dünyadaki görünürlük sınırlarını ayardaki değere getir
static func _view_preview() -> void:
	var v := float(Game.settings["view"])
	if Game.world and _view_live > 0.0 and not is_equal_approx(_view_live, v):
		Game.rescale_view(_view_live, v)
		Game.apply_graphics()   # sis
	_view_live = v


static func _settings_revert() -> void:
	_set_bg = null
	Game.settings["view"] = _set_snap.get("view", Game.settings["view"])
	_view_preview()   # önizlenen görüş mesafesini geri al
	if Keys.binds != _set_keys and not _set_keys.is_empty():
		Keys.restore(_set_keys)
	var s = Game.settings
	var win = s.get("display") != _set_snap.get("display") or s.get("fullscreen") != _set_snap.get("fullscreen") or s.get("ui_scale") != _set_snap.get("ui_scale") or s.get("win_mode") != _set_snap.get("win_mode") or s.get("resolution") != _set_snap.get("resolution")
	for k in _set_snap:
		s[k] = _set_snap[k]
	if win:
		Game.apply_settings()
	Game.apply_graphics()


## Kaydetmeden çık (Esc): değişiklikleri geri al, gelinen menüye dön
static func settings_cancel() -> void:
	if not settings_open():
		return
	# kaydedilmemiş değişiklik varsa önce sor (ikinci Esc: kaydetmeden çık)
	if settings_dirty() and not _set_bg.has_meta("asking"):
		_settings_ask()
		return
	var back: Callable = _set_bg.get_meta("back")   # ekranla birlikte silinir (kalıcı değişkende tutulunca oyun kapanırken çöküyordu)
	_settings_revert()
	back.call()


## Ekran açıldığından beri değişen ayar var mı
static func settings_dirty() -> bool:
	if Keys.binds != _set_keys:
		return true
	for k in _set_snap:
		if Game.settings.get(k) != _set_snap[k]:
			return true
	return false


## Kaydedilmemiş değişiklik uyarısı: Kaydet ve çık / Kaydetmeden çık / Vazgeç
static func _settings_ask() -> void:
	var bg := _set_bg
	bg.set_meta("asking", true)
	var ov = ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.add_child(ov)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", LazyFx.g("UI").ink_panel(0.97, 28))
	cc.add_child(p)
	var v = LazyFx.g("UI").vbox(14)
	p.add_child(v)
	var t = LazyFx.g("UI").label("Kaydedilmemiş değişiklikler var", 26, LazyFx.g("UI").CREAM)
	t.add_theme_font_override("font", _brush_font())
	v.add_child(t)
	v.add_child(LazyFx.g("UI").label("Değişiklikleri kaydetmeden çıkarsan eski ayarlara dönülür.", 15, LazyFx.g("UI").MUTED))
	v.add_child(LazyFx.g("UI").spacer(0, 6, false))
	var h = LazyFx.g("UI").hbox(12)
	v.add_child(h)
	var close = func() -> void:
		if is_instance_valid(bg):
			bg.remove_meta("asking")
		ov.queue_free()
	h.add_child(LazyFx.g("UI").button("Vazgeç", close, 170, "arrow"))
	h.add_child(LazyFx.g("UI").button("Kaydetmeden Çık", func(): settings_cancel(), 230, "close"))
	var sv = LazyFx.g("UI").primary("Kaydet ve Çık", func(): _settings_save(bg.get_meta("back")), 210, "check")
	h.add_child(sv)
	h.add_child(LazyFx.g("UI").spacer(0, 0, false))
	sv.call_deferred("grab_focus")
	LazyFx.g("UI").pop_in(p, 0.96)


## Kaydet ve geri dön
static func _settings_save(back: Callable) -> void:
	var s = Game.settings
	_view_preview()
	_set_bg = null   # kaydedildi: çıkarken geri alma
	Game.save_settings()
	if Game.player:
		Game.player.cam.fov = s["fov"]
	if Game.world:
		Game.apply_graphics()
	Sfx.music_a.volume_db = linear_to_db(maxf(0.001, float(s["music"]) * 0.6))
	back.call()


## Ayar açıklamaları (satırın üstüne gelince / seçilince altta görünür)
const SET_DESC := {
	"Dil / Language": "Arayüz dili. Hemen uygulanır.",
	"Otomatik kayıt": "Oyun akarken belirli aralıkla kaydeder. Dövüş sırasında kaydetmez, dövüş bitince kaydeder.",
	"Kamera sarsıntısı": "Darbelerde ve patlamalarda kameranın sarsılması. Baş dönmesi yapıyorsa azalt.",
	"Kan efekti": "Vuruşlarda kan sıçraması.",
	"Ekran modu": "Çerçevesiz tam ekran: masaüstüne hızlı geçiş. Tam ekran: oyun ekranı tek başına kullanır. Pencere: seçilen boyutta pencere.",
	"Çözünürlük": "Pencerede pencere boyutu. Tam ekranda oyunun çizildiği çözünürlük: düşük seçmek kare hızını artırır, arayüz keskin kalır.",
	"Arayüz ölçeği": "Menülerin ve yazıların büyüklüğü. Küçük ekranlarda küçült.",
	"Grafik kalitesi": "Aşağıdaki ayrıntıları birlikte kurar (gölge, kenar yumuşatma, görüş mesafesi…). Sonra tek tek değiştirebilirsin.",
	"Gölgeler": "Güneş ve fener gölgeleri. Kapatmak FPS'i belirgin artırır.",
	"Kenar yumuşatma": "Kenarlardaki tırtıkları giderir. MSAA daha temiz ama daha ağır; FXAA hafif ama biraz bulanık.",
	"Ortam gölgesi (SSAO)": "Köşelerde ve temas noktalarında yumuşak gölge. Orta ağırlıkta.",
	"Çözünürlük ölçeği": "Sahneyi daha düşük çözünürlükte çizip büyütür. Düşürmek FPS'i en çok artıran ayardır.",
	"Anime çizgileri": "Karakterlerin ve nesnelerin kenarlarındaki koyu çizgi.",
	"Yumuşak filtre": "Hafif ışıltı ve yumuşak renk filtresi.",
	"Görüş mesafesi": "Uzaktaki yapıların ve ağaçların ne kadar uzaktan görüneceği. Kaydırırken hemen görürsün.",
	"Çimen yoğunluğu": "Etrafındaki çimenin miktarı ve uzanma mesafesi.",
	"Kalabalık yoğunluğu": "Köylerdeki insan sayısı. Hemen uygulanır; fazlalar sen bakmazken dağılır.",
	"Görüş alanı (FOV)": "Kameranın açısı. Büyük değer daha geniş görür.",
	"Dikey eşitleme (VSync)": "Ekran yırtılmasını önler; FPS'i ekranın yenileme hızıyla sınırlar.",
	"FPS sınırı": "Saniyedeki en çok kare. Isınmayı ve fan sesini azaltır.",
	"FPS göster": "Köşede saniyedeki kare sayısını gösterir.",
	"Ana ses": "Bütün seslerin düzeyi.",
	"Efektler": "Dövüş, jutsu ve dünya sesleri.",
	"Arayüz sesleri": "Menülerdeki tık sesleri.",
	"Oyun arka plandayken sesi kapat": "Başka pencereye geçince oyunun sesini kapatır.",
	"Fare hassasiyeti": "Kameranın fareyle dönme hızı.",
	"Fareyi ters çevir (Y)": "Fareyi yukarı itince kamera aşağı bakar.",
	"Tuş atamaları": "Bütün tuşları değiştirebileceğin ekran.",
}
const SET_TABS := [["general", "leaf", "Genel"], ["graphics", "monitor", "Görüntü"], ["sound", "sound", "Ses"], ["controls", "controls", "Kontrol"], ["cheats", "skull", "Hileler"]]
## Ayar ekranı mühürleri (hanko): sekme / bölüm / tuş grubu adı -> kanji
const SET_SEALS := {"Ayarlar": "設", "Kontroller": "操", "Genel": "基", "Görüntü": "画", "Ses": "音", "Kontrol": "操",
	"Oyun": "遊", "Ekran": "映", "Grafik": "彩", "Dünya": "界", "Kamera": "眼", "Kare Hızı": "速", "Ses Düzeyi": "音",
	"Fare ve Tuşlar": "操", "Hareket": "走", "Dövüş": "闘", "Modlar ve çağrı": "術", "Eşya ve etkileşim": "具",
	"Menüler": "巻", "Jutsu yuvaları": "印", "Sabit": "固", "Hileler": "秘", "Hile Kuralları": "秘", "Anında": "急", "Göz Ver": "眼",
	"Jutsu Aç": "術", "Güç ve Rütbe": "力", "Kuyruklu Canavar": "獣", "Eşya Ver": "具", "Işınlanma ve Dünya": "界"}
static var _set_tab := "general"
static var _set_focus := -1          # klavye / kol ile seçili satır (yeniden çizimde korunur)
static var _brush: Font = null
static var _diamond: Texture2D = null
static var _chev := {}


## Fırça başlık yazısı (kalın, eğik)
static func _brush_font() -> Font:
	return LazyFx.g("UI").title_font()


## Kaydırıcı tutamacı: altın elmas
static func _diamond_tex() -> Texture2D:
	if _diamond == null:
		var n := 26
		var img = Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) * 0.5
		for y in n:
			for x in n:
				var d = absf(x - c) + absf(y - c)
				if d <= c - 0.5:
					var col = LazyFx.g("UI").CREAM.lerp(LazyFx.g("UI").ACCENT, clampf((y - 2.0) / n, 0.0, 1.0))
					img.set_pixel(x, y, Color(0.12, 0.03, 0.02) if d > c - 3.0 else col)
				elif d <= c + 0.5:
					img.set_pixel(x, y, Color(0.12, 0.03, 0.02, c + 0.5 - d))
		_diamond = ImageTexture.create_from_image(img)
	return _diamond


## Seçici oku: ince köşeli ok (sağa bakan; sola bakan için yatay çevrilir)
static func _chevron_tex(left: bool) -> Texture2D:
	if not _chev.has(left):
		var w := 16
		var h := 26
		var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		var a := Vector2(4, 3)
		var m := Vector2(12, 13)
		var b := Vector2(4, 23)
		for y in h:
			for x in w:
				var p := Vector2(x + 0.5, y + 0.5)
				var d = minf(Geometry2D.get_closest_point_to_segment(p, a, m).distance_to(p), Geometry2D.get_closest_point_to_segment(p, m, b).distance_to(p))
				var al = clampf(2.2 - d, 0.0, 1.0)
				if al > 0.0:
					img.set_pixel(w - 1 - x if left else x, y, Color(1, 1, 1, al))
		_chev[left] = ImageTexture.create_from_image(img)
	return _chev[left]


## Ayarlar / Kontroller ortak çerçevesi: arka planı az koyulaştır (köy görünsün), sol ray (başlık, sekmeler, alt ipucu).
## on_tab boşsa sekme yok. Ray genişliğini döndürür.
static func _set_frame(bg: Control, title: String, active: String, on_tab: Callable, hint: String) -> int:
	var mat: ShaderMaterial = bg.material
	mat.set_shader_parameter("dim", 0.42)
	mat.set_shader_parameter("blur", 2.2)
	mat.set_shader_parameter("tint", Color(0.05, 0.035, 0.03))
	var vw = bg.get_viewport_rect().size.x
	var rw := 300 if vw >= 1150.0 else 210
	var rail = Panel.new()
	var rsb = LazyFx.g("UI")._box(Color(0.035, 0.031, 0.028, 0.92), Color(0, 0, 0, 0), 0, 0, 0)
	rsb.border_width_right = 1
	rsb.border_color = LazyFx.g("UI").LINE
	rail.add_theme_stylebox_override("panel", rsb)
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_right = rw
	bg.add_child(rail)
	var head = LazyFx.g("UI").hbox(12)
	head.position = Vector2(24, 26)
	rail.add_child(head)
	head.add_child(LazyFx.g("UI").seal(SET_SEALS.get(title, "設"), 50.0 if rw > 250 else 38.0))
	var big := 46 if rw > 250 else 30
	var tl = LazyFx.g("UI").label(title, big if title.length() <= 8 else big - 10, LazyFx.g("UI").CREAM)
	tl.add_theme_font_override("font", _brush_font())
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tl)
	if on_tab.is_valid():
		var tabs = LazyFx.g("UI").vbox(6)
		tabs.position = Vector2(14, 130)
		tabs.custom_minimum_size = Vector2(rw - 28, 0)
		rail.add_child(tabs)
		for t in SET_TABS:
			var on: bool = t[0] == active
			var b = Button.new()
			b.text = t[2]
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(rw - 28, 60)
			b.add_theme_font_override("font", LazyFx.g("UI").font(true))
			b.add_theme_font_size_override("font_size", 20)
			# Sekiro seçenek rayı: her sekme koyu fırça darbesi, seçili olan kırmızı fırça
			var n = LazyFx.g("UI").brush(Color(0.0, 0.0, 0.0, 0.55), "a", 10)
			n.content_margin_left = 70
			var h = LazyFx.g("UI").brush(Color(0.0, 0.0, 0.0, 0.85), "a", 10)
			h.content_margin_left = 70
			var sel = LazyFx.g("UI").brush(LazyFx.g("UI").ACCENT, "a", 10)
			sel.content_margin_left = 70
			# sekme mührü: seçili sekmede kırmızı fırça üstünde krem mühür
			var sl = LazyFx.g("UI").seal(SET_SEALS.get(t[2], "設"), 34.0, on)
			sl.position = Vector2(24, 13)
			b.add_child(sl)
			b.add_theme_stylebox_override("normal", sel if on else n)
			b.add_theme_stylebox_override("hover", sel if on else h)
			b.add_theme_stylebox_override("pressed", sel)
			b.add_theme_stylebox_override("focus", sel if on else h)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(k, Color(1, 0.97, 0.93) if on else LazyFx.g("UI").TEXT)
			var tab_id: String = t[0]
			b.pressed.connect(func():
				Sfx.play("click")
				if tab_id != active:
					on_tab.call(tab_id))
			b.mouse_entered.connect(func(): Sfx.play("click", null, 1.8, 0.18))
			tabs.add_child(b)
	# sol alttaki tuş ipuçları (Q / E, Esc) kaldırıldı: tuşlar çalışmaya devam eder, kapat düğmesinin ipucunda Esc yazar
	return rw


## Bölüm: fırça şeritli başlık + satır kartı (satırlar dönen kutuya eklenir)
static func _set_section(body: Container, icon: String, title: String) -> VBoxContainer:
	var wrap = LazyFx.g("UI").vbox(0)
	body.add_child(wrap)
	var ban = PanelContainer.new()
	var bsb = LazyFx.g("UI").brush(Color(0.0, 0.0, 0.0, 0.88), "a", 12)
	bsb.content_margin_left = 24; bsb.content_margin_right = 110
	ban.add_theme_stylebox_override("panel", bsb)
	ban.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bh = LazyFx.g("UI").hbox(12)
	if SET_SEALS.has(title):
		bh.add_child(LazyFx.g("UI").seal(SET_SEALS[title], 30.0))
	else:
		bh.add_child(LazyFx.g("Icons").view(icon, 26, LazyFx.g("UI").ACCENT))
	var bt = LazyFx.g("UI").label(title, 25, LazyFx.g("UI").CREAM)
	bt.add_theme_font_override("font", _brush_font())
	bh.add_child(bt)
	ban.add_child(bh)
	wrap.add_child(ban)
	var card = PanelContainer.new()
	var csb = LazyFx.g("UI")._box(Color(0.035, 0.031, 0.028, 0.86), Color(0, 0, 0, 0), 0, 2, 0)
	csb.content_margin_left = 26; csb.content_margin_right = 26; csb.content_margin_top = 8; csb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", csb)
	wrap.add_child(card)
	var rows = LazyFx.g("UI").vbox(0)
	card.add_child(rows)
	return rows


## Satır: solda ad, sağına denetim eklenir (satırlar arası ince çizgi)
static func _set_row(sec: VBoxContainer, title: String, lw: float, size := 18, h := 54.0) -> HBoxContainer:
	if sec.get_child_count() > 0:
		var ln = ColorRect.new()
		ln.color = LazyFx.g("UI").LINE
		ln.custom_minimum_size = Vector2(0, 1)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec.add_child(ln)
	var r = LazyFx.g("UI").hbox(14)
	r.custom_minimum_size = Vector2(0, h)
	var l = LazyFx.g("UI").label(title, size)
	l.custom_minimum_size = Vector2(lw, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	if SET_DESC.has(title):
		r.set_meta("desc", SET_DESC[title])
	sec.add_child(r)
	return r


## Alt çubuk: solda koyu hap düğme, sağda turuncu ana düğme
static func _set_bottom(bg: Control, rw: int, left_text: String, left_icon: String, left_cb: Callable, right_text: String, right_icon: String, right_cb: Callable) -> void:
	var bot = LazyFx.g("UI").hbox(12)
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = rw + 36; bot.offset_right = -36; bot.offset_top = -80; bot.offset_bottom = -24
	bg.add_child(bot)
	var rb = LazyFx.g("UI").button(left_text, left_cb, 250, left_icon)
	rb.custom_minimum_size.y = 52
	bot.add_child(rb)
	bot.add_child(LazyFx.g("UI").spacer())
	var save = LazyFx.g("UI").primary(right_text, right_cb, 300, right_icon)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		save.add_theme_color_override(k, Color(1, 1, 1))
	save.add_theme_font_size_override("font_size", 20)
	save.custom_minimum_size.y = 56
	bot.add_child(save)


## Q / E (kolda omuz tuşları): ayarlar sekmesi değiştir
static func settings_tab(d: int) -> void:
	if not settings_open():
		return
	var ids = SET_TABS.map(func(t): return t[0])
	_set_tab = ids[posmod(ids.find(_set_tab) + d, ids.size())]
	_set_scroll = 0
	_set_focus = -1
	Sfx.play("click")
	settings(_set_bg.get_meta("back"))


## Yukarı / aşağı ile ilk kez gezinme: hiçbir satır seçili değilse ilkini seç
static func settings_focus_first() -> bool:
	if not settings_open() or _set_bg.get_viewport().gui_get_focus_owner() != null:
		return false
	var f = _set_bg.find_children("*", "", true, false).filter(func(c): return c is Control and c.has_meta("set_row"))
	if f.is_empty():
		return false
	f[0].grab_focus()
	return true


static func settings(back: Callable) -> void:
	if not settings_open() and not _set_sub:
		_set_snap = Game.settings.duplicate(true)
		_set_keys = Keys.binds.duplicate(true)
		_view_live = float(Game.settings["view"])
		_set_scroll = 0
		_set_tab = "general"
		_set_focus = -1
	_set_sub = false
	_view_preview()
	_set_keep = true
	var bg = _full()
	_set_keep = false
	_set_bg = bg
	bg.set_meta("back", back)
	var s = Game.settings
	var rw := _set_frame(bg, "Ayarlar", _set_tab, func(id):
		_set_tab = id
		_set_scroll = 0
		_set_focus = -1
		settings(back), "kaydetmeden çık")
	var lw := 300 if bg.get_viewport_rect().size.x - rw >= 900.0 else 210
	var xb = _close_button(bg, func(): settings_cancel())
	xb.tooltip_text = "Kaydetmeden çık [Esc]"
	# ---- içerik: bölüm kartları, kaydırılabilir
	var area = Control.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_left = rw + 36; area.offset_top = 90; area.offset_right = -36; area.offset_bottom = -150
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(area)
	# açıklama şeridi: üstüne gelinen / seçilen ayarın ne işe yaradığı
	var dp = PanelContainer.new()
	var dsb = LazyFx.g("UI")._box(Color(0.02, 0.018, 0.016, 0.85), Color(0, 0, 0, 0), 0, 6, 10)
	dsb.border_width_left = 3
	dsb.border_color = LazyFx.g("UI").ACCENT
	dsb.content_margin_left = 16
	dp.add_theme_stylebox_override("panel", dsb)
	dp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dp.offset_left = rw + 36; dp.offset_right = -36; dp.offset_top = -142; dp.offset_bottom = -96
	dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(dp)
	var desc = LazyFx.g("UI").label("Bir ayarın üstüne gel ya da seç: ne işe yaradığı burada yazar.", 15, LazyFx.g("UI").MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 0)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dp.add_child(desc)
	var show_desc = func(r: Control) -> void:
		if is_instance_valid(desc) and r.has_meta("desc"):
			desc.text = r.get_meta("desc")
			desc.add_theme_color_override("font_color", LazyFx.g("UI").TEXT)
	var sc = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true   # klavyeyle aşağı inince seçili satır görünür kalsın
	area.add_child(sc)
	var body = LazyFx.g("UI").vbox(22)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	# yeniden çizimde (ok tuşu, kalite) kaldığın yerde kal
	var bar = sc.get_v_scroll_bar()
	var keep_scroll := _set_scroll
	var state = [keep_scroll <= 0]
	bar.changed.connect(func():
		if not state[0] and bar.max_value - bar.page >= keep_scroll - 1.0:
			state[0] = true
			sc.set_deferred("scroll_vertical", keep_scroll))
	bar.value_changed.connect(func(x):
		if state[0]:
			_set_scroll = int(x))
	var focusables := []
	# klavye / kol: satır seçilince sırası saklanır; seçili satırın çerçevesi parlar
	var mark = func(c: Control, sb: StyleBoxFlat) -> void:
		var i := focusables.size()
		focusables.append(c)
		c.set_meta("set_row", i)
		c.focus_mode = Control.FOCUS_ALL
		var lit = [false, false]   # [fare üstünde, odakta]
		var paint = func() -> void: sb.border_color = Color(LazyFx.g("UI").ACCENT, 0.95) if lit[0] or lit[1] else Color(LazyFx.g("UI").TEXT, 0.16)
		c.mouse_entered.connect(func():
			lit[0] = true
			paint.call())
		c.mouse_exited.connect(func():
			lit[0] = false
			paint.call())
		c.focus_entered.connect(func():
			_set_focus = i
			lit[1] = true
			paint.call()
			var r = c.get_parent()
			while r != null and not r.has_meta("desc") and r != body:
				r = r.get_parent()
			if r != null and r != body:
				show_desc.call(r))
		c.focus_exited.connect(func():
			lit[1] = false
			paint.call())
	# kaydedilmemiş değişiklik: satır adının önünde turuncu nokta, ad altın renkli
	var dirty = func(h: HBoxContainer, keys: Array) -> void:
		var ch := false
		for kk in keys:
			if s.get(kk) != _set_snap.get(kk):
				ch = true
		if not ch:
			return
		var l: Label = h.get_child(0)
		l.add_theme_color_override("font_color", LazyFx.g("UI").GOLD)
		var dot = Panel.new()
		dot.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(LazyFx.g("UI").ACCENT, Color(0, 0, 0, 0), 0, 4, 0))
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.tooltip_text = "Kaydedilmedi"
		h.add_child(dot)
		h.move_child(dot, 0)
		l.custom_minimum_size.x -= 22.0
	var note = func(sec: VBoxContainer, text: String) -> void:
		var l = LazyFx.g("UI").label(text, 13, LazyFx.g("UI").MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(120, 0)
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_top", 2)
		m.add_theme_constant_override("margin_bottom", 4)
		m.add_child(l)
		sec.add_child(m)
	# kaydırıcı: seçicilerle aynı genişlikte (300), değer kutusu içinde
	var slider = func(sec: VBoxContainer, title: String, key: String, mn: float, mx: float, step: float, pct: bool) -> void:
		var h = _set_row(sec, title, lw)
		var fmt = func(x: float) -> String: return ("%d%%" % roundi(x * 100.0)) if pct else ("%.0f°" % x if step >= 1.0 else "%.2f" % x)
		var box = PanelContainer.new()
		var bsb = LazyFx.g("UI")._box(Color(0.01, 0.012, 0.018, 0.9), Color(LazyFx.g("UI").GOLD, 0.28), 1, 23, 0)
		bsb.content_margin_left = 18; bsb.content_margin_right = 8
		box.add_theme_stylebox_override("panel", bsb)
		box.custom_minimum_size = Vector2(300, 46)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bh = LazyFx.g("UI").hbox(10)
		box.add_child(bh)
		var sl = HSlider.new()
		sl.min_value = mn; sl.max_value = mx; sl.step = step; sl.value = float(s.get(key, mx))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.scrollable = false   # fare tekeri sayfayı kaydırsın, üstünden geçtiği sürgüyü değiştirmesin
		var track = LazyFx.g("UI")._box(Color(0, 0, 0, 0.6), Color(1, 1, 1, 0.1), 1, 5, 0)
		track.content_margin_top = 3; track.content_margin_bottom = 3
		var fill = LazyFx.g("UI")._box(LazyFx.g("UI").ACCENT, Color(0, 0, 0, 0), 0, 5, 0)
		fill.content_margin_top = 3; fill.content_margin_bottom = 3
		sl.add_theme_stylebox_override("slider", track)
		sl.add_theme_stylebox_override("grabber_area", fill)
		sl.add_theme_stylebox_override("grabber_area_highlight", fill)
		sl.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		sl.add_theme_icon_override("grabber", _diamond_tex())
		sl.add_theme_icon_override("grabber_highlight", _diamond_tex())
		bh.add_child(sl)
		var vl = LazyFx.g("UI").label(fmt.call(sl.value), 16, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
		vl.custom_minimum_size = Vector2(64, 0)
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bh.add_child(vl)
		h.add_child(box)
		mark.call(sl, bsb)
		dirty.call(h, [key])
		var hl: Label = h.get_child(h.get_child_count() - 2) if h.get_child(0) is Panel else h.get_child(0)
		sl.value_changed.connect(func(x):
			s[key] = x
			vl.text = fmt.call(x)
			if s.get(key) != _set_snap.get(key):
				hl.add_theme_color_override("font_color", LazyFx.g("UI").GOLD)
			if key in ["master", "music"]:
				Game.apply_audio()
				Sfx.music_a.volume_db = linear_to_db(maxf(0.001, float(s["music"]) * 0.6))
			if key == "view":   # kaydırma durunca dünyaya uygula (her adımda tüm dünyayı taramasın)
				sl.get_tree().create_timer(0.3).timeout.connect(func():
					if is_equal_approx(float(s["view"]), x):
						_view_preview()))
	# ‹ değer › seçici: tek hap, içinde ince oklar, altında konum noktaları. Değişiklik hemen uygulanır, ekran yeniden çizilir
	var pick = func(sec: VBoxContainer, title: String, cur_text: String, step: Callable, no_tr: bool, at: Vector2i) -> HBoxContainer:
		var h = _set_row(sec, title, lw)
		var go = func(d: int) -> void:
			step.call(d)
			Game.apply_graphics()
			settings(back)
		var pill = PanelContainer.new()
		var psb = LazyFx.g("UI")._box(Color(0.01, 0.012, 0.018, 0.9), Color(LazyFx.g("UI").GOLD, 0.28), 1, 23, 0)
		pill.add_theme_stylebox_override("panel", psb)
		pill.custom_minimum_size = Vector2(300, 46)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.call(pill, psb)
		pill.gui_input.connect(func(ev: InputEvent):
			if ev.is_action_pressed("ui_left", true):
				pill.accept_event()
				go.call(-1)
			elif ev.is_action_pressed("ui_right", true) or ev.is_action_pressed("ui_accept"):
				pill.accept_event()
				go.call(1)
			elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				# fare tekeri seçicinin üstündeyken değeri değiştirir (sayfayı kaydırmaz)
				pill.accept_event()
				go.call(1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
		var ph = LazyFx.g("UI").hbox(0)
		pill.add_child(ph)
		var arrow = func(left: bool) -> Button:
			var b = Button.new()
			b.icon = _chevron_tex(left)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.custom_minimum_size = Vector2(52, 44)
			b.focus_mode = Control.FOCUS_NONE
			var n = StyleBoxEmpty.new()
			var hv = LazyFx.g("UI")._box(Color(LazyFx.g("UI").ACCENT, 0.3), Color(0, 0, 0, 0), 0, 0, 0)
			if left:
				hv.corner_radius_top_left = 2; hv.corner_radius_bottom_left = 2
			else:
				hv.corner_radius_top_right = 2; hv.corner_radius_bottom_right = 2
			for k in [["normal", n], ["focus", n], ["hover", hv], ["pressed", hv]]:
				b.add_theme_stylebox_override(k[0], k[1])
			b.add_theme_color_override("icon_normal_color", Color(LazyFx.g("UI").GOLD, 0.75))
			b.add_theme_color_override("icon_hover_color", LazyFx.g("UI").CREAM)
			b.add_theme_color_override("icon_pressed_color", Color(1, 1, 1))
			b.pressed.connect(func():
				Sfx.play("click")
				go.call(-1 if left else 1))
			b.mouse_entered.connect(func():
				Sfx.play("click", null, 1.8, 0.18)
				pill.mouse_entered.emit())   # okun üstündeyken de hap parlasın
			return b
		ph.add_child(arrow.call(true))
		var mid = LazyFx.g("UI").vbox(3)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vl = LazyFx.g("UI").label(cur_text, 17, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
		if no_tr:
			vl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		mid.add_child(vl)
		var dots = LazyFx.g("UI").hbox(4)
		dots.alignment = BoxContainer.ALIGNMENT_CENTER
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in at.y:
			var dt = Panel.new()
			var on := i == at.x
			dt.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(LazyFx.g("UI").ACCENT if on else Color(1, 1, 1, 0.18), Color(0, 0, 0, 0), 0, 2, 0))
			dt.custom_minimum_size = Vector2(14 if on else 4, 4)
			dt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.add_child(dt)
		mid.add_child(dots)
		ph.add_child(mid)
		ph.add_child(arrow.call(false))
		h.add_child(pill)
		return h
	var toggle = func(sec: VBoxContainer, title: String, key: String, def: bool) -> void:
		var on := bool(s.get(key, def))
		dirty.call(pick.call(sec, title, "Açık" if on else "Kapalı", func(_d): s[key] = not bool(s.get(key, def)), false, Vector2i(int(on), 2)), [key])
	# sabit listeden seçim (değer listesi, görünen adlar)
	var choose = func(sec: VBoxContainer, title: String, key: String, vals: Array, names: Array, def) -> void:
		var cur = s.get(key, def)
		var i := 0
		for j in vals.size():
			if vals[j] == cur:
				i = j
		dirty.call(pick.call(sec, title, names[i], func(d): s[key] = vals[clampi(i + d, 0, vals.size() - 1)], false, Vector2i(i, vals.size())), [key])
	match _set_tab:
		"general":
			var g = _set_section(body, "leaf", "Oyun")
			# dil: hemen uygulanır (ekrandaki yazılar kendiliğinden çevrilir)
			var lr = pick.call(g, "Dil / Language", LazyFx.g("Lang").NAMES[Game.lang()], func(d):
				s["lang"] = LazyFx.g("Lang").CODES[posmod(LazyFx.g("Lang").CODES.find(Game.lang()) + d, LazyFx.g("Lang").CODES.size())]
				LazyFx.g("Lang").apply(s["lang"]), true, Vector2i(LazyFx.g("Lang").CODES.find(Game.lang()), LazyFx.g("Lang").CODES.size()))
			dirty.call(lr, ["lang"])
			choose.call(g, "Otomatik kayıt", "autosave", [0, 5, 10, 15], ["Kapalı", "5 dakikada bir", "10 dakikada bir", "15 dakikada bir"], 10)
			toggle.call(g, "Kan efekti", "blood", true)
		"graphics":
			var e = _set_section(body, "monitor", "Ekran")
			# ekran modu: ◀ Çerçevesiz tam ekran / Tam ekran / Pencere ▶ ; çözünürlük: ◀ ekran / 1920 × 1080 ... ▶ (ekrana sığanlar)
			var wm = Game.WIN_MODES
			var wi = maxi(0, wm.find(Game.win_mode()))
			var mr = pick.call(e, "Ekran modu", Game.win_mode_label(wm[wi]), func(d):
				s["win_mode"] = wm[posmod(wi + d, wm.size())]
				s["resolution"] = Game.resolution_key()
				s["display"] = ""
				s["fullscreen"] = s["win_mode"] != "window"
				Game.apply_settings(), false, Vector2i(wi, wm.size()))
			dirty.call(mr, ["win_mode", "display", "fullscreen"])
			var ro = Game.resolution_options()
			var rk = maxi(0, ro.find(Game.resolution_key()))
			var rr = pick.call(e, "Çözünürlük", Game.resolution_label(ro[rk]), func(d):
				s["win_mode"] = Game.win_mode()
				s["resolution"] = ro[clampi(rk + d, 0, ro.size() - 1)]
				s["display"] = ""
				Game.apply_settings(), true, Vector2i(rk, ro.size()))
			dirty.call(rr, ["resolution", "display"])
			var scales = [0.75, 0.85, 1.0, 1.15, 1.3, 1.5]
			var si = 2
			for i in scales.size():
				if absf(scales[i] - float(s.get("ui_scale", 1.0))) < 0.01:
					si = i
			var ur = pick.call(e, "Arayüz ölçeği", "%d%%" % roundi(scales[si] * 100.0), func(d):
				s["ui_scale"] = scales[posmod(si + d, scales.size())]
				Game.apply_settings(), false, Vector2i(si, scales.size()))
			dirty.call(ur, ["ui_scale"])
			var g = _set_section(body, "monitor", "Grafik")
			var q = int(s.get("quality", 2))
			var q4: int = Game.quality4()
			dirty.call(pick.call(g, "Grafik kalitesi", Game.QUALITY4_NAMES[q4], func(d): Game.set_quality4(posmod(q4 + d, 4)), false, Vector2i(q4, 4)), ["quality", "potato"])
			toggle.call(g, "Gölgeler", "shadows", true)
			choose.call(g, "Kenar yumuşatma", "aa", [0, 1, 2, 3], ["Kapalı", "FXAA", "MSAA 2x", "MSAA 4x"], 2)
			toggle.call(g, "Ortam gölgesi (SSAO)", "ssao", true)
			var rs := [0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0]
			var ri = rs.find(snappedf(float(s.get("res_scale", 1.0)), 0.05))
			ri = rs.size() - 1 if ri < 0 else ri
			dirty.call(pick.call(g, "Çözünürlük ölçeği", "%d%%" % roundi(rs[ri] * 100.0), func(d): s["res_scale"] = rs[clampi(ri + d, 0, rs.size() - 1)], false, Vector2i(ri, rs.size())), ["res_scale"])
			toggle.call(g, "Anime çizgileri", "outline", true)
			toggle.call(g, "Yumuşak filtre", "dreamy", false)
			var w = _set_section(body, "tree", "Dünya")
			slider.call(w, "Görüş mesafesi", "view", 0.4, 1.6, 0.05, false)
			choose.call(w, "Çimen yoğunluğu", "grass", [0, 1, 2, 3], ["Kapalı", "Az", "Orta", "Çok"], 3)
			choose.call(w, "Kalabalık yoğunluğu", "crowd", [0, 1, 2], ["Az", "Orta", "Kalabalık"], 2)
			var c = _set_section(body, "eye", "Kamera")
			slider.call(c, "Görüş alanı (FOV)", "fov", 55.0, 100.0, 1.0, false)
			choose.call(c, "Kamera sarsıntısı", "shake", [0, 1, 2], ["Kapalı", "Az", "Normal"], 2)
			var f = _set_section(body, "hourglass", "Kare Hızı")
			toggle.call(f, "Dikey eşitleme (VSync)", "vsync", true)
			var fl: Array = Game.FPS_LIMITS
			choose.call(f, "FPS sınırı", "max_fps", fl, fl.map(func(x): return "Sınırsız" if x == 0 else str(x)), 0)
			toggle.call(f, "FPS göster", "show_fps", false)
			if not OS.has_feature("mobile"):
				toggle.call(f, "Çok çekirdekli çizim (deneysel)", "render_thread", false)
				note.call(f, "Çizimi ayrı işlemci çekirdeğinde yapar; kalabalık savaşlarda FPS artar. Oyunu yeniden başlatınca geçerli olur. Çökme ya da görüntü bozulması olursa kapat.")
			if bool(s.get("vsync", true)):
				note.call(f, "Dikey eşitleme açıkken FPS ekranın yenileme hızını geçmez.")
		"sound":
			var a = _set_section(body, "sound", "Ses Düzeyi")
			slider.call(a, "Ana ses", "master", 0.0, 1.0, 0.05, true)
			slider.call(a, "Müzik", "music", 0.0, 1.0, 0.05, true)   # 2026-11-27: müzikler geri geldi (assets/music)
			slider.call(a, "Efektler", "sfx", 0.0, 1.0, 0.05, true)
			slider.call(a, "Arayüz sesleri", "ui_vol", 0.0, 1.0, 0.05, true)
			toggle.call(a, "Oyun arka plandayken sesi kapat", "bg_mute", false)
		"controls":
			var k = _set_section(body, "controls", "Fare ve Tuşlar")
			slider.call(k, "Fare hassasiyeti", "sens", 0.2, 3.0, 0.05, false)
			toggle.call(k, "Fareyi ters çevir (Y)", "invert_y", false)
			var h = _set_row(k, "Tuş atamaları", lw)
			if Keys.binds != _set_keys:   # tuş değişikliği de kaydedilmemiş sayılır
				h.get_child(0).add_theme_color_override("font_color", LazyFx.g("UI").GOLD)
			var kb = LazyFx.g("UI").button("Tuş Atamalarını Düzenle", func():
				_set_sub = true   # ayarlar açık kalır sayılır: dönünce yarım değişiklikler korunur, Esc ile çıkılırsa geri alınır
				_set_keep = true
				controls(func(): settings(back))
				_set_keep = false, 300, "controls")
			kb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(kb)
		"cheats":
			Cheats.build_tab(body, lw, pick, func(): settings(back))   # Hileler: scripts/core/cheats.gd
	if _fresh:
		LazyFx.g("UI").pop_in(area, 0.985)
	# klavyeyle değiştirilen satır yeniden çizimde seçili kalsın
	if _set_focus >= 0 and _set_focus < focusables.size():
		focusables[_set_focus].call_deferred("grab_focus")
	_set_bottom(bg, rw, "Varsayılana Dön", "hourglass", func():
		# kaydedilmez: "Kaydet ve Geri" ile kalıcı olur, Esc / ✕ ile geri alınır
		var win = s.get("display") != Game.settings_defaults.get("display") or s.get("fullscreen") != Game.settings_defaults.get("fullscreen") or s.get("ui_scale") != Game.settings_defaults.get("ui_scale") or s.get("win_mode") != Game.settings_defaults.get("win_mode") or s.get("resolution") != Game.settings_defaults.get("resolution")
		for key in Game.settings_defaults:
			s[key] = Game.settings_defaults[key]
		if win:
			Game.apply_settings()
		Game.apply_graphics()
		Sfx.music_a.volume_db = linear_to_db(maxf(0.001, float(s["music"]) * 0.6))
		Hud.msg("Ayarlar varsayılana döndü (kaydetmek için: Kaydet ve Geri).", Color(0.9, 0.85, 0.6))
		settings(back), "Kaydet ve Geri", "check", func(): _settings_save(back))
	# satırların açıklaması: fare üstüne gelince
	for r in body.find_children("*", "HBoxContainer", true, false):
		if r.has_meta("desc"):
			r.mouse_entered.connect(show_desc.bind(r))


# ================================================================== ninja menüsü [Tab]
const TABS := [["inv", "bag", "Envanter"], ["wardrobe", "armor", "Ekipman"], ["eyes", "eye", "Gözler"], ["jutsu", "scroll", "Jutsular"], ["skills", "star", "Ustalık"],
	["beasts", "flame", "Canavarlar"], ["summons", "seal", "Kuchiyose"], ["relations", "heart", "İlişkiler"], ["missions", "mission", "Görevler"], ["paths", "book", "Yollar"], ["map", "map", "Harita"]]
const TAB_TITLES := {"beasts": "KUYRUKLU CANAVARLAR", "summons": "KUCHİYOSE SÖZLEŞMELERİ", "inv": "ENVANTER", "wardrobe": "EKİPMAN", "jutsu": "JUTSULAR", "skills": "USTALIK (YAPTIKÇA GELİŞME)", "missions": "GÖREVLER", "relations": "İLİŞKİLER", "eyes": "GÖZLER (DŌJUTSU)", "paths": "EFSANE YOLLARI"}
const SWATCHES := [Color(0.15, 0.2, 0.33), Color(0.12, 0.12, 0.14), Color(0.45, 0.15, 0.15), Color(0.95, 0.5, 0.12), Color(0.2, 0.38, 0.22),
	Color(0.35, 0.25, 0.45), Color(0.85, 0.82, 0.75), Color(0.15, 0.4, 0.45), Color(0.55, 0.42, 0.3), Color(0.75, 0.2, 0.25)]


static var _last_tab := ""
static var _last_shop := ""
static var _scroll_mem := {}     # sekme -> kaydırma konumları
static var _menu_open := false


## Menü kısayolu: en son açık bırakılan sekme (ilk açılışta envanter)
static func last_tab(fallback := "inv") -> String:
	return _last_tab if _last_tab != "" else fallback


static func _scroll_positions() -> Array:
	return _live_scrolls().map(func(sc): return sc.scroll_vertical)


## Silinmeyi bekleyen eski ekranın kaydırma kutuları sayılmaz (yeniden kurulan ekranda konum eskisine yazılıp kayboluyordu)
static func _live_scrolls() -> Array:
	var out = []
	for sc in Hud.dialog_layer.find_children("*", "ScrollContainer", true, false):
		var dead = false
		var n: Node = sc
		while n != null and n != Hud.dialog_layer:
			if n.is_queued_for_deletion():
				dead = true
				break
			n = n.get_parent()
		if not dead:
			out.append(sc)
	return out


static func _restore_scroll(vals: Array) -> void:
	var scs = _live_scrolls()
	for i in mini(scs.size(), vals.size()):
		if is_instance_valid(scs[i]):
			scs[i].scroll_vertical = int(vals[i])


static func ninja_menu(main: Node, tab := "inv", picked := "") -> void:
	if tab == "map":
		region_map(main)
		return
	# aynı sekme yeniden kurulurken (eşya seçince) kaydırma yerinde kalsın; eskiden en üste dönüyordu
	var bg = _full(0.5)   # (önceki sekmenin kaydırması clear() içinde kaydedilir)
	var keep = _scroll_mem.get(tab, [])
	_last_tab = tab
	_menu_open = true
	var pr = Game.profile
	# sol ray
	var rail_bg = Panel.new()
	var rsb = LazyFx.g("UI")._box(Color(0.035, 0.031, 0.028, 0.78), Color(0, 0, 0, 0), 0, 0, 0)
	rsb.border_width_right = 1
	rsb.border_color = LazyFx.g("UI").LINE
	rail_bg.add_theme_stylebox_override("panel", rsb)
	rail_bg.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail_bg.offset_right = 112
	bg.add_child(rail_bg)
	var rail = LazyFx.g("UI").vbox(2)
	rail.position = Vector2(20, 92)
	rail_bg.add_child(rail)
	var emb = LazyFx.g("Icons").view("leaf", 44, LazyFx.g("UI").ACCENT)
	emb.position = Vector2(34, 30)
	rail_bg.add_child(emb)
	for t in TABS:
		rail.add_child(LazyFx.g("UI").icon_button(t[1], t[2], func(): ninja_menu(main, t[0]), 66, t[0] == tab))   # 11 sekme 16:9 ve daha basık ekranlara sığsın
	# üst çubuk: başlık + oyuncu bilgisi
	var title = LazyFx.g("UI").label(TAB_TITLES.get(tab, ""), 34, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.position = Vector2(150, 24)
	bg.add_child(title)
	var tline = LazyFx.g("UI").brush_line(150)
	tline.position = Vector2(146, 70)
	bg.add_child(tline)
	var info = LazyFx.g("UI").hbox(18)
	info.anchor_left = 1.0; info.anchor_right = 1.0
	info.offset_left = -720; info.offset_right = -110; info.offset_top = 36
	info.alignment = BoxContainer.ALIGNMENT_END
	bg.add_child(info)
	info.add_child(LazyFx.g("UI").icon_label("person", "%s  •  %s  •  %d yaşında  •  Güç %d" % [pr["name"], Data.RANKS[int(pr["rank"])], int(Aging.player_years()), int(pr["level"])], 16, LazyFx.g("UI").TEXT))
	info.add_child(LazyFx.g("UI").icon_label("coin", "%d Ryō" % int(pr["ryo"]), 16, LazyFx.g("UI").GOLD))
	_close_button(bg, func(): main.resume())
	# içerik
	var body = Control.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 150; body.offset_top = 100; body.offset_right = -40; body.offset_bottom = -54
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(body)
	match tab:
		"inv":
			_tab_inventory(main, body)
		"wardrobe":
			_tab_wardrobe(main, body)
		"jutsu":
			_tab_jutsu(main, body, picked)
		"skills":
			_tab_skills(main, body)
		"missions":
			_tab_missions(main, body)
		"relations":
			_tab_relations(main, body)
		"eyes":
			_tab_eyes(main, body)
		"paths":
			LazyFx.g("PathsTab").build(main, body)
		"beasts":
			_tab_beasts(main, body)
		"summons":
			_tab_summons(main, body)
	if not keep.is_empty():
		_restore_scroll.call_deferred(keep)
		Engine.get_main_loop().process_frame.connect(_restore_scroll.bind(keep), CONNECT_ONE_SHOT)
	elif _fresh:
		LazyFx.g("UI").pop_in(body, 0.985)
	# alt ipucu satırı
	var foot = LazyFx.g("UI").hbox(8)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(150, -42)
	bg.add_child(foot)
	for k in [[Keys.name("menu"), "menüyü kapat"], [Keys.name("inventory"), "envanter"], [Keys.name("skills"), "jutsular"], [Keys.name("map"), "harita"]]:
		foot.add_child(LazyFx.g("UI").key_badge(k[0], 12))
		foot.add_child(LazyFx.g("UI").label(k[1] + "    ", 13, LazyFx.g("UI").MUTED))


# ------------------------------------------------------------------ envanter
static var _inv_filter := "all"
static var _inv_sel := ""


static func _tab_inventory(main: Node, body: Control) -> void:
	var pr = Game.profile
	var h = LazyFx.g("UI").hbox(28)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left = LazyFx.g("UI").vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var chips = LazyFx.g("UI").hbox(8)
	left.add_child(chips)
	for f in [["all", "Tümü"], ["throw", "Aletler"], ["use", "Tüketilebilir"], ["scroll", "Parşömenler"], ["gear", "Ekipman"]]:
		chips.add_child(LazyFx.g("UI").chip(f[1], _inv_filter == f[0], func():
			_inv_filter = f[0]
			ninja_menu(main, "inv")))
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var entries = []
	var inv: Dictionary = pr["inventory"]
	for id in inv.keys():
		if int(inv[id]) <= 0:
			continue
		var it: Dictionary = Data.items.get(id, {"name": id, "desc": "", "kind": "misc"})
		var kind = String(it.get("kind", "misc"))
		if _inv_filter in ["all", kind]:
			entries.append({"type": "item", "id": id, "name": it["name"], "count": int(inv[id]), "kind": kind, "desc": it.get("desc", ""), "unlimited": LazyFx.g("Stats").unlimited(id)})
	if _inv_filter in ["all", "gear"]:
		LazyFx.g("Gear").ensure(pr)
		var counts = {}
		for g in pr.get("gear", []):
			if LazyFx.g("Gear").is_eye(g["id"]):
				continue   # gözler eşya değil: Gözler (dōjutsu) sekmesinde
			counts[g["id"]] = int(counts.get(g["id"], 0)) + 1
		for gid in counts:
			var gi = LazyFx.g("Gear").item(gid)
			if gi.is_empty():
				continue
			entries.append({"type": "gear", "id": gid, "name": gi["name"], "count": counts[gid], "kind": "gear", "desc": gi.get("desc", "")})
	if _inv_sel == "" and not entries.is_empty():
		_inv_sel = entries[0]["id"]
	var sel = {}
	for e in entries:
		var view = LazyFx.g("Thumbs").gear_view(e["id"], 72) if e["type"] == "gear" else LazyFx.g("Thumbs").item_view(e["id"], 72)
		var acc = LazyFx.g("UI").RARITY[LazyFx.g("UI").rarity_of_gear(e["id"])] if e["type"] == "gear" else LazyFx.g("UI").RARITY[0]
		grid.add_child(_tile(view, e["name"], acc, e["id"] == _inv_sel, func():
			_inv_sel = e["id"]
			ninja_menu(main, "inv"), 104, "∞" if e.get("unlimited", false) else ("x%d" % e["count"] if e["count"] > 1 else "")))
		if e["id"] == _inv_sel:
			sel = e
	if entries.is_empty():
		left.add_child(LazyFx.g("UI").label("Bu kategoride eşya yok.", 16, LazyFx.g("UI").MUTED))
	# sağ: ayrıntı + durum
	var right = LazyFx.g("UI").vbox(16)
	right.custom_minimum_size = Vector2(420, 0)
	h.add_child(right)
	var dc = LazyFx.g("UI").card()
	dc.custom_minimum_size = Vector2(420, 300)
	right.add_child(dc)
	var dv = LazyFx.g("UI").vbox(10)
	dc.add_child(dv)
	if sel.is_empty():
		dv.add_child(LazyFx.g("UI").label("Bir eşya seç.", 16, LazyFx.g("UI").MUTED))
	else:
		var top = LazyFx.g("UI").hbox(16)
		var big = LazyFx.g("Thumbs").gear_view(sel["id"], 96) if sel["type"] == "gear" else LazyFx.g("Thumbs").item_view(sel["id"], 96)
		top.add_child(big)
		var tv = LazyFx.g("UI").vbox(4)
		tv.add_child(LazyFx.g("UI").label(sel["name"], 24, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		if sel["type"] == "gear":
			var r = LazyFx.g("UI").rarity_of_gear(sel["id"])
			tv.add_child(LazyFx.g("UI").label(LazyFx.g("UI").RARITY_NAMES[r], 14, LazyFx.g("UI").RARITY[r], HORIZONTAL_ALIGNMENT_LEFT, true))
			tv.add_child(LazyFx.g("UI").label(LazyFx.g("Gear").stats_text(sel["id"]), 14, LazyFx.g("UI").GOOD))
			var rs = LazyFx.g("Gear").req_summary(sel["id"])
			if rs != "":
				var why = LazyFx.g("Gear").req_text(sel["id"], pr)
				tv.add_child(LazyFx.g("UI").icon_label("lock" if why != "" else "check", rs + ("  —  henüz takamazsın" if why != "" else ""), 14, LazyFx.g("UI").BAD if why != "" else LazyFx.g("UI").GOOD))
		tv.add_child(LazyFx.g("UI").label("Adet: sınırsız" if sel.get("unlimited", false) else "Adet: %d" % sel["count"], 14, LazyFx.g("UI").MUTED))
		top.add_child(tv)
		dv.add_child(top)
		var d = LazyFx.g("UI").label(sel["desc"], 15, LazyFx.g("UI").MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(380, 0)
		dv.add_child(d)
		if sel["kind"] == "throw":
			var on: bool = pr["throw_sel"] == sel["id"]
			var b = LazyFx.g("UI").primary("Kuşanıldı" if on else LazyFx.g("Lang").t("Kuşan [%s]") % Keys.name("throw"), func():
				pr["throw_sel"] = sel["id"]
				ninja_menu(main, "inv"), 380, "check" if on else "kunai")
			b.disabled = on
			dv.add_child(b)
		elif sel["kind"] == "use":
			dv.add_child(LazyFx.g("UI").primary("Kullan", func():
				main.use_item(sel["id"])
				ninja_menu(main, "inv"), 380, "potion"))
		elif sel["type"] == "gear":
			dv.add_child(LazyFx.g("UI").button("Ekipmanda göster", func():
				var gs = String(LazyFx.g("Gear").item(sel["id"]).get("slot", "govde"))
				_eq_slot = {"el": "sag", "yuz": "kafa"}.get(gs, gs)   # yüz eşyaları Kafa yuvasında, silahlar tek Silah yuvasında
				ninja_menu(main, "wardrobe"), 380, "armor"))
	# durum kartı
	var st = LazyFx.g("UI").card()
	right.add_child(st)
	var sv = LazyFx.g("UI").vbox(8)
	st.add_child(sv)
	var pl = Game.player
	var stat_row = func(icon: String, name: String, val: String, col = LazyFx.g("UI").TEXT) -> void:
		var r = LazyFx.g("UI").hbox(10)
		r.add_child(LazyFx.g("Icons").view(icon, 20, LazyFx.g("UI").GOLD))
		var l = LazyFx.g("UI").label(name, 15, LazyFx.g("UI").MUTED)
		l.custom_minimum_size = Vector2(150, 0)
		r.add_child(l)
		r.add_child(LazyFx.g("UI").label(val, 15, col, HORIZONTAL_ALIGNMENT_LEFT, true))
		sv.add_child(r)
	if pl:
		stat_row.call("heart", "Can", "%d / %d" % [int(pl.hp), int(pl.max_hp)], LazyFx.g("UI").GOOD)
		stat_row.call("chakra", "Chakra", "%d / %d" % [int(pl.chakra), int(pl.max_chakra)], Color(0.5, 0.75, 1.0))
	stat_row.call("star", "Toplam Ustalık", "%d" % int(LazyFx.g("Mastery").total(pr)))
	stat_row.call("leaf", "Klan", Data.clans.get(pr["clan"], {}).get("name", "Klansız"))
	if LazyFx.g("KgPaths").SOY.has(String(pr.get("soy", ""))):
		stat_row.call("leaf", "Kan Soyu", LazyFx.g("KgPaths").SOY[String(pr["soy"])]["name"])
	stat_row.call(LazyFx.g("UI").ELEMENT_ICONS.get(String(pr["elements"][0]) if not pr["elements"].is_empty() else "", "chakra"), "Chakra doğası", ", ".join((pr["elements"] as Array).map(func(e): return _el_name(String(e)))) if not pr["elements"].is_empty() else "—")
	var md: Dictionary = pr["missions_done"]
	stat_row.call("mission", "Görevler", "D%d  C%d  B%d  A%d  S%d" % [md.get("D", 0), md.get("C", 0), md.get("B", 0), md.get("A", 0), md.get("S", 0)])


# ------------------------------------------------------------------ ekipman (karakter etrafında yuvalar)
static var _eq_slot := "set"
# gözler ekipman değil (Gözler sekmesinde)
const DOLL_LEFT := ["kafa", "set"]
const DOLL_RIGHT := ["sirt", "sag"]
## Silah dövüş tarzının oyuncuya görünen adı (iç kimlik yazılmaz)
const WEAPON_STYLE_NAMES := {"fist": "Yumruk", "blade": "Kısa bıçak", "dual": "Çift el", "claw": "Pençe", "sickle": "Orak", "sword": "Kılıç",
	"heavy": "Ağır silah", "staff": "Uzun saplı", "chain": "Zincirli", "fan": "Yelpaze"}


static func _slot_name(sl: String) -> String:
	for s in LazyFx.g("Gear").SLOTS:
		if s[0] == sl:
			return s[1]
	return {"sac": "Saç", "susanoo": "Susanoo"}.get(sl, sl)


static func _tab_wardrobe(main: Node, body: Control) -> void:
	var pr = Game.profile
	LazyFx.g("Gear").ensure(pr)
	if _eq_slot in ["sag_goz", "sol_goz"] or _eq_slot in LazyFx.g("Gear").OLD_CLOTH_SLOTS:
		_eq_slot = "set"
	var refresh = func() -> void:
		LazyFx.g("Gear").apply_look(pr)
		if Game.player:
			Game.player.rebuild_model()
			Game.player.apply_profile_stats()
		ninja_menu(main, "wardrobe")
	var h = LazyFx.g("UI").hbox(26)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	# --- sol: karakter + çevresindeki yuvalar
	var doll = Control.new()
	doll.custom_minimum_size = Vector2(860, 740)
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(doll)
	var preview: Control
	if _eq_slot == "susanoo":
		preview = _susanoo_preview(pr)
	else:
		var plk: Dictionary = (Game.player._look_with_age() if Game.player else pr["look"]).duplicate()
		plk["own_hair"] = true
		preview = _model_preview(plk)
	preview.position = Vector2(250, 0)
	preview.size = Vector2(360, 700)
	preview.custom_minimum_size = Vector2(360, 700)
	doll.add_child(preview)
	# zemin halkası
	var ring = Control.new()
	ring.position = Vector2(250, 600)
	ring.size = Vector2(360, 100)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		ring.draw_arc(Vector2(180, 60), 150, 0, TAU, 64, Color(LazyFx.g("UI").GOLD, 0.25), 2.0, true)
		ring.draw_arc(Vector2(180, 60), 110, 0, TAU, 64, Color(LazyFx.g("UI").GOLD, 0.12), 1.0, true))
	doll.add_child(ring)
	ring.scale = Vector2(1, 0.35)
	ring.position.y = 660
	var make_slot = func(sl: String, pos: Vector2, name_left: bool) -> void:
		var g = LazyFx.g("Gear").equipped(pr, sl) if not sl in ["sac", "susanoo"] else {}
		var view: Control
		var acc = Color(1, 1, 1, 0.2)
		var item_name = ""
		if sl == "sac":
			view = LazyFx.g("Icons").view("hair", 44, Color(pr["look"].get("hair", LazyFx.g("UI").TEXT)).lightened(0.2))
			item_name = String(CharacterModel.HAIR_STYLES.get(String(pr["look"].get("hair_style", "")), ""))
		elif sl == "susanoo":
			view = LazyFx.g("Icons").view("susanoo", 44, Color(0.7, 0.55, 1.0))
			item_name = "Kademe %d" % Susanoo.cur_tier(pr)
		elif g.is_empty():
			view = LazyFx.g("Icons").view(LazyFx.g("Thumbs").SLOT_ICONS.get(sl, "info"), 40, Color(1, 1, 1, 0.18))
		else:
			view = LazyFx.g("Thumbs").gear_view(g["id"], 56, Color.html(g["c1"]))
			acc = LazyFx.g("UI").RARITY[LazyFx.g("UI").rarity_of_gear(g["id"])]
			item_name = LazyFx.g("Gear").item(g["id"])["name"]
		var t = _tile(view, _slot_name(sl), acc, sl == _eq_slot, func():
			_eq_slot = sl
			ninja_menu(main, "wardrobe"), 76)
		t.position = pos
		t.tooltip_text = item_name if item_name != "" else "Boş"
		doll.add_child(t)
		if item_name != "":
			var nl = LazyFx.g("UI").label(item_name, 13, Color(acc, 1.0) if acc.a > 0.5 else LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_RIGHT if name_left else HORIZONTAL_ALIGNMENT_LEFT)
			nl.size = Vector2(150, 20)
			nl.position = pos + (Vector2(-158, 30) if name_left else Vector2(84, 30))
			nl.clip_text = true
			doll.add_child(nl)
	for i in DOLL_LEFT.size():
		make_slot.call(DOLL_LEFT[i], Vector2(160, 4 + i * 100), true)
	for i in DOLL_RIGHT.size():
		make_slot.call(DOLL_RIGHT[i], Vector2(624, 4 + i * 100), false)
	make_slot.call("sac", Vector2(624, 4 + 6 * 100), false)
	if Susanoo.max_tier(pr) > 0:
		make_slot.call("susanoo", Vector2(392, 620), false)
	# toplam istatistikler (karakterin üstünde)
	var tot = []
	for k in [["hp", "Can", false], ["chakra", "Chakra", false], ["speed", "Hız", true], ["melee", "Yakın dövüş", true]]:
		var v = LazyFx.g("Gear").stat(pr, k[0])
		if v != 0.0:
			tot.append(("%s %+d%%" % [LazyFx.g("Lang").t(k[1]), int(round(v * 100))]) if k[2] else ("%s %+d" % [LazyFx.g("Lang").t(k[1]), int(v)]))
	if LazyFx.g("Gear").weapon(pr).has("hit"):   # silahsızken yumruk verisi "silah" diye yazılmasın
		tot.append(LazyFx.g("Lang").t("Silah %.1f hasar") % float(LazyFx.g("Gear").weapon(pr)["hit"]))
	var tl = LazyFx.g("UI").label("  •  ".join(tot), 13, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tl.position = Vector2(220, -26)
	tl.size = Vector2(420, 20)
	doll.add_child(tl)
	# --- sağ: seçili yuvanın çekmecesi
	var drawer = PanelContainer.new()
	drawer.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(16, 20, 0.7))
	drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(drawer)
	var dv = _scroll(drawer, 520, 680)
	dv.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(LazyFx.g("UI").header(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(_slot_name(_eq_slot))), 22))
	if _eq_slot == "sac":
		_hair_panel(dv, pr["look"], refresh)
		return
	if _eq_slot == "susanoo":
		_susanoo_panel(main, dv, null)
		return
	var cur = LazyFx.g("Gear").equipped(pr, _eq_slot)
	if _eq_slot in ["sag_goz", "sol_goz"]:
		_eye_panel(main, dv, pr)
		return
	if _eq_slot in LazyFx.g("Gear").HIDE_SLOTS:
		# görünüşü gizle: eşya takılı kalır, statları sayılır, yalnız karakterde görünmez
		var hid = LazyFx.g("Gear").look_hidden(pr, _eq_slot)
		dv.add_child(_arrow_row("Görünüş", ["Göster", "Gizle (statlar sayılır)"], 1 if hid else 0, func(i):
			if not pr.has("hide_look"):
				pr["hide_look"] = {}
			pr["hide_look"][_eq_slot] = i == 1
			refresh.call()))
	if _eq_slot == "kafa" and String(LazyFx.g("Gear").item(String(cur.get("id", ""))).get("look", {}).get("band_style", "none")) in ["head", "slashed"]:
		# tek alın koruyucu, takılış tarzı oyuncunun seçimi (anime: Kakashi göze eğik, Zabuza yana, Sakura saç bandı, Hinata boyun...)
		var wears: Array = CharacterModel.BAND_WEARS
		var wl = []
		for w in wears:
			wl.append(CharacterModel.BAND_WEAR_NAMES[w])
		dv.add_child(_arrow_row("Takılış", wl, maxi(0, wears.find(String(pr.get("band_wear", "alin")))), func(i):
			pr["band_wear"] = wears[i]
			LazyFx.g("Gear").apply_look(pr)
			refresh.call()))
	var list = LazyFx.g("Gear").owned_for(pr, _eq_slot)
	if list.is_empty():
		dv.add_child(LazyFx.g("UI").label("Bu yuvaya uygun eşyan yok. Dükkânlardan alabilir, görevlerden kazanabilirsin.", 15, LazyFx.g("UI").MUTED))
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	dv.add_child(grid)
	var detail = LazyFx.g("UI").card()
	var detail_v = LazyFx.g("UI").vbox(8)
	detail.add_child(detail_v)
	var show_detail = func(g: Dictionary) -> void:
		for c in detail_v.get_children():
			c.queue_free()
		if g.is_empty():
			detail_v.add_child(LazyFx.g("UI").label("Boş yuva", 15, LazyFx.g("UI").MUTED))
			return
		var it = LazyFx.g("Gear").item(g["id"])
		var r = LazyFx.g("UI").rarity_of_gear(g["id"])
		var row = LazyFx.g("UI").hbox(14)
		row.add_child(LazyFx.g("Thumbs").gear_view(g["id"], 72, Color.html(g["c1"])))
		var tv = LazyFx.g("UI").vbox(2)
		tv.add_child(LazyFx.g("UI").label(it["name"], 21, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		tv.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t(LazyFx.g("UI").RARITY_NAMES[r]) + (("   •   " + LazyFx.g("Lang").t("takılı")) if not cur.is_empty() and int(cur["uid"]) == int(g["uid"]) else ""), 13, LazyFx.g("UI").RARITY[r], HORIZONTAL_ALIGNMENT_LEFT, true))
		row.add_child(tv)
		detail_v.add_child(row)
		# istatistik karşılaştırması
		var mine = it.get("stats", {})
		var theirs = LazyFx.g("Gear").item(cur["id"]).get("stats", {}) if not cur.is_empty() else {}
		var names = {"hp": "Can", "chakra": "Chakra", "speed": "Hız", "melee": "Yakın dövüş"}
		for k in names:
			var a = float(mine.get(k, 0.0)); var b = float(theirs.get(k, 0.0))
			if a == 0.0 and b == 0.0:
				continue
			var pct = k in ["speed", "melee"]
			var txt = ("%+d%%" % int(round(a * 100))) if pct else ("%+d" % int(a))
			var diff = a - b
			var dtxt = ""
			if not cur.is_empty() and int(cur["uid"]) != int(g["uid"]) and absf(diff) > 0.0001:
				dtxt = ("  (%+d%%)" % int(round(diff * 100))) if pct else ("  (%+d)" % int(diff))
			var sr = LazyFx.g("UI").hbox(6)
			var nl = LazyFx.g("UI").label(names[k], 14, LazyFx.g("UI").MUTED)
			nl.custom_minimum_size = Vector2(130, 0)
			sr.add_child(nl)
			sr.add_child(LazyFx.g("UI").label(txt, 14, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
			if dtxt != "":
				sr.add_child(LazyFx.g("UI").label(dtxt, 14, LazyFx.g("UI").GOOD if diff > 0 else LazyFx.g("UI").BAD, HORIZONTAL_ALIGNMENT_LEFT, true))
			detail_v.add_child(sr)
		if it.has("weapon"):
			var wst = String(it["weapon"].get("style", ""))
			detail_v.add_child(LazyFx.g("UI").label("Vuruş hasarı %.1f   •   Menzil +%.1f m   •   %s%s" % [float(it["weapon"].get("hit", 4.2)), it["weapon"]["reach"], LazyFx.g("Lang").t(String(WEAPON_STYLE_NAMES.get(wst, "Silah"))), ("   •   " + LazyFx.g("Lang").t("Uzun menzil")) if it["weapon"].get("ranged", false) else ""], 14, LazyFx.g("UI").GOLD))
		var d = LazyFx.g("UI").label(it.get("desc", ""), 14, LazyFx.g("UI").MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(460, 0)
		detail_v.add_child(d)
		var rs = LazyFx.g("Gear").req_summary(g["id"])
		var why = LazyFx.g("Gear").req_text(g["id"], pr)
		if rs != "":
			detail_v.add_child(LazyFx.g("UI").icon_label("lock" if why != "" else "check", rs, 14, LazyFx.g("UI").BAD if why != "" else LazyFx.g("UI").GOOD))
		var on = not cur.is_empty() and int(cur["uid"]) == int(g["uid"])
		if why != "" and not on:
			detail_v.add_child(LazyFx.g("UI").label("Takamazsın: %s." % why, 15, LazyFx.g("UI").BAD, HORIZONTAL_ALIGNMENT_LEFT, true))
		elif on:
			if not _eq_slot in LazyFx.g("Gear").REQUIRED:
				detail_v.add_child(LazyFx.g("UI").button("Çıkar", func():
					pr["equip"].erase(_eq_slot)
					refresh.call(), 460, "close"))
		else:
			detail_v.add_child(LazyFx.g("UI").primary("Giy / Kuşan", func():
				pr["equip"][_eq_slot] = int(g["uid"])
				refresh.call(), 460, "check"))
	for g in list:
		var it = LazyFx.g("Gear").item(g["id"])
		var used_other = false
		for sl in LazyFx.g("Gear").SLOTS:
			if sl[0] != _eq_slot and int(pr["equip"].get(sl[0], -1)) == int(g["uid"]):
				used_other = true
		var on = not cur.is_empty() and int(cur["uid"]) == int(g["uid"])
		var why = LazyFx.g("Gear").req_text(g["id"], pr)
		var t = _tile(LazyFx.g("Thumbs").gear_view(g["id"], 60, Color.html(g["c1"])), it["name"], LazyFx.g("UI").RARITY[LazyFx.g("UI").rarity_of_gear(g["id"])] if why == "" else Color(1, 1, 1, 0.12), on, func():
			if why != "" and not on:
				Hud.msg("Takamazsın: %s" % why, Color(1, 0.5, 0.4))
				show_detail.call(g)
				return
			if used_other:
				Hud.msg("Bu eşya başka bir yuvada takılı.", Color(1, 0.8, 0.5))
				return
			pr["equip"][_eq_slot] = int(g["uid"])
			refresh.call(), 92, "✓" if on else ("◐" if used_other else ("Kilitli" if why != "" else "")))
		if why != "" and not on:
			t.modulate = Color(1, 1, 1, 0.5)
		t.tooltip_text = "%s\n%s%s" % [it["name"], LazyFx.g("Gear").stats_text(g["id"]), ("\n" + why) if why != "" else ""]
		t.mouse_entered.connect(func(): show_detail.call(g))
		grid.add_child(t)
	dv.add_child(detail)
	show_detail.call(cur if not cur.is_empty() else (list[0] if not list.is_empty() else {}))
	# Mangekyō deseni
	if _eq_slot in ["sag_goz", "sol_goz"] and not Eyes.design_for(pr, _eq_slot).is_empty():
		_ms_editor(main, dv, Eyes.design_for(pr, _eq_slot))
	# boya
	if not cur.is_empty() and not LazyFx.g("Gear").item(cur["id"]).has("weapon") and not LazyFx.g("Gear").item(cur["id"]).has("eye"):
		var names = {"set": ["Üst Rengi", "Alt Rengi (pantolon)"]}.get(_eq_slot, ["Renk"])
		for ci in names.size():
			var key = "c%d" % (ci + 1)
			dv.add_child(LazyFx.g("UI").label(names[ci], 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
			var fl = HFlowContainer.new()
			fl.add_theme_constant_override("h_separation", 8)
			for c in SWATCHES:
				fl.add_child(_swatch(c, Color.html(cur[key]).is_equal_approx(c), func():
					cur[key] = c.to_html(false)
					cur["dyed_" + key] = true   # elle yapılmış set: yalnız gerçekten boyanan renk kıyafete uygulanır
					refresh.call()))
			dv.add_child(fl)


## Özel Mangekyō deseni: canlı önizleme + stil (oklu seçici)/kanat/kıvrım/kalınlık/halka/renk
## Değişiklikler yerinde uygulanır: menü baştan kurulmaz (eskiden stil seçince başka sekmeye atlıyordu)
const MS_STYLES := ["Çark", "Yıldız", "Taç Yaprak", "Shuriken", "Sarmal", "Haç", "Tomoe Halkası", "Orak", "Pervane", "Çiçek",
	"Elmas", "Halkalar", "Kanca", "Dört Bıçak", "Altı Köşeli Yıldız", "Kelebek", "Kar Tanesi", "Kalkan",
	"Madara", "Sasuke", "Shisui", "Kakashi", "Izuna", "Indra", "Ebedi Sasuke", "Ebedi Madara", "Nokta Halkası", "Haç Yaprak",
	"Gül", "Kum Saati", "Güneş", "Dişli", "Triskel", "Hilaller", "Göz İçinde Göz", "Nilüfer", "Dalga", "Diken Halkası",
	"Pusula", "Dişler", "Girdap", "Kare", "Altıgen", "Alev", "Tüy", "Taç", "Çift Nokta", "Gül Düğümü", "Rinne Sharingan Halkası", "Sharingan Kılıcı"]
const MS_COLORS := [[0.9, 0.05, 0.06], [0.6, 0.0, 0.05], [0.55, 0.2, 0.85], [0.15, 0.4, 0.95], [0.95, 0.7, 0.1], [0.1, 0.7, 0.4], [0.95, 0.95, 0.98], [0.05, 0.05, 0.08], [1.0, 0.4, 0.7], [0.2, 0.85, 0.95]]
static func _ms_editor(main: Node, v: VBoxContainer, d: Dictionary) -> void:
	v.add_child(LazyFx.g("UI").spacer(0, 6, false))
	v.add_child(LazyFx.g("UI").header("MANGEKYŌ DESENİ", 18))
	var box = LazyFx.g("UI").vbox(6)
	v.add_child(box)
	_ms_editor_fill(box, d)


static func _ms_editor_fill(box: VBoxContainer, d: Dictionary) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var row = LazyFx.g("UI").hbox(18)
	box.add_child(row)
	var pv = ColorRect.new()
	pv.custom_minimum_size = Vector2(160, 160)
	var sm = ShaderMaterial.new()
	sm.shader = load("res://shaders/ms_preview.gdshader")
	pv.material = sm
	row.add_child(pv)
	var apply_pv = func() -> void:
		var vv = Eyes.design_vecs(d)
		sm.set_shader_parameter("ms_a", vv[0])
		sm.set_shader_parameter("ms_b", vv[1])
		sm.set_shader_parameter("col", vv[2])
		if Game.player and Game.player.combat and Game.player.combat.modes and Game.player.combat.modes.eyes:
			Game.player.combat.modes.eyes.refresh_visual()
	apply_pv.call()
	var ctl = LazyFx.g("UI").vbox(6)
	row.add_child(ctl)
	# stil: < Ad (n/N) > oklu seçici
	var sr = LazyFx.g("UI").hbox(8)
	var sl0 = LazyFx.g("UI").label("Desen", 13, LazyFx.g("UI").MUTED)
	sl0.custom_minimum_size = Vector2(92, 0)
	sr.add_child(sl0)
	var name_l = LazyFx.g("UI").label("", 15, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	name_l.custom_minimum_size = Vector2(150, 0)
	var upd_name = func() -> void:
		var st = int(d.get("style", 0)) % MS_STYLES.size()
		name_l.text = "%s  (%d/%d)" % [MS_STYLES[st], st + 1, MS_STYLES.size()]
	var step = func(dir: int) -> void:
		d["style"] = posmod(int(d.get("style", 0)) + dir, MS_STYLES.size())
		upd_name.call()
		apply_pv.call()
	sr.add_child(LazyFx.g("UI").button("◀", func(): step.call(-1), 44))
	sr.add_child(name_l)
	sr.add_child(LazyFx.g("UI").button("▶", func(): step.call(1), 44))
	upd_name.call()
	ctl.add_child(sr)
	var slider = func(title: String, key: String, mn: float, mx: float, stp: float) -> void:
		var hh = LazyFx.g("UI").hbox(8)
		var l = LazyFx.g("UI").label(title, 13, LazyFx.g("UI").MUTED)
		l.custom_minimum_size = Vector2(92, 0)
		hh.add_child(l)
		var sl = HSlider.new()
		sl.min_value = mn
		sl.max_value = mx
		sl.step = stp
		sl.value = float(d.get(key, mn))
		sl.custom_minimum_size = Vector2(180, 22)
		sl.focus_mode = Control.FOCUS_NONE   # ok tuşları kaydırıcıyı değil menüyü gezsin
		sl.value_changed.connect(func(x):
			d[key] = x
			apply_pv.call())
		hh.add_child(sl)
		ctl.add_child(hh)
	slider.call("Kanat sayısı", "blades", 2, 8, 1)
	slider.call("Kıvrım", "curve", -3.0, 3.0, 0.05)
	slider.call("Kalınlık", "thick", 0.2, 0.9, 0.01)
	slider.call("Göz bebeği", "inner", 0.08, 0.4, 0.01)
	slider.call("Dönüş hızı", "spin", 0.0, 2.0, 0.05)
	var tg = LazyFx.g("UI").hbox(6)
	for opt in [["ring", "Dış halka"], ["invert", "Ters renk"]]:
		var cb = CheckBox.new()
		cb.text = opt[1]
		cb.button_pressed = bool(d.get(opt[0], false))
		cb.toggled.connect(func(x):
			d[opt[0]] = x
			apply_pv.call())
		tg.add_child(cb)
	ctl.add_child(tg)
	var cr = HFlowContainer.new()
	cr.add_theme_constant_override("h_separation", 6)
	cr.add_theme_constant_override("v_separation", 6)
	for c in MS_COLORS:
		cr.add_child(_swatch(Color(c[0], c[1], c[2]), false, func():
			d["col"] = c
			apply_pv.call()))
	cr.add_child(LazyFx.g("UI").button("Rastgele", func():
		var nd = Eyes.random_design()
		for k in nd:
			d[k] = nd[k]
		_ms_editor_fill.call_deferred(box, d), 140, "star"))
	cr.add_child(LazyFx.g("UI").button("Diğer göze aktar", func():
		# hangi gözün deseni düzenleniyorsa o (panel iki gözü de çizip seçili yuvayı sıfırlıyor: tuş hep "Mangekyō yok" diyordu)
		var from := _eq_slot
		for s0 in ["sag_goz", "sol_goz"]:
			if is_same(Eyes.design_for(Game.profile, s0), d):
				from = s0
		if Eyes.copy_design(Game.profile, from):
			Hud.msg("Desen diğer göze aktarıldı.", Color(1, 0.6, 0.6))
			apply_pv.call()
		else:
			Hud.msg("Diğer gözde Mangekyō yok.", Color(0.85, 0.8, 0.7)), 190, "eye"))
	box.add_child(cr)


static var _sus_prev: Susanoo   # gardıroptaki önizleme (kaydırıcılar anında günceller)
## Susanoo önizlemesi (karakter yerine)
static func _susanoo_preview(pr: Dictionary) -> Control:
	var svc = SubViewportContainer.new()
	svc.stretch = true
	svc.process_mode = Node.PROCESS_MODE_ALWAYS
	var sv = SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	var sn = Susanoo.new()
	sv.add_child(sn)
	sn.build(pr, maxi(1, Susanoo.cur_tier(pr)))
	_sus_prev = sn
	sn.scale = Vector3.ONE * (2.1 / 1.8)
	# yere gömülü kademeler (iskelet/İnsansı) önizlemede de belden görünsün (eskiden kadraj dışına kayıyordu)
	sn.position.y = -0.95 * sn.scale.y * 0.55 if sn.tier in [2, 3] else 0.0
	var cam = Camera3D.new()
	cam.fov = 36
	sv.add_child(cam)
	var cp = Vector3(0, 1.25, -5.2)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 1.1, 0) - cp), cp)
	var tw = Game.safe_loops(sn.create_tween())
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sn, "rotation:y", TAU, 10.0).from(0.0)
	return svc


## Susanoo özelleştirme: kademe, renk, zırh, yüz, silah, kanat
static func _susanoo_panel(main: Node, v: VBoxContainer, _h) -> void:
	var pr = Game.profile
	var cfg = Susanoo.config(pr)
	var mt = Susanoo.max_tier(pr)
	var redraw = func() -> void:
		ninja_menu(main, "wardrobe")
	var m = float(cfg.get("mastery", 0.0))
	var nxt = mt + 1
	var info = "Ustalık: %d sn" % int(m)
	if nxt <= 5:
		info += "   •   Kademe %d için %d sn%s" % [nxt, int(Susanoo.MASTERY_STEPS[nxt]), " (Ebedi Mangekyō)" if nxt >= 4 else ""]
	v.add_child(LazyFx.g("UI").label(info, 14, Color(0.78, 0.7, 1.0)))
	if nxt <= 5:
		var pb = LazyFx.g("UI").bar(Color(0.65, 0.5, 1.0), 460, 8)
		pb.max_value = Susanoo.MASTERY_STEPS[nxt]
		pb.value = m
		v.add_child(pb)
	var opt_row = func(title: String, labels: Array, cur, key: String, values: Array, limit := 99) -> void:
		var n = mini(labels.size(), limit)   # kilitli kademeler oklarla seçilemez
		v.add_child(_arrow_row(title, labels.slice(0, n), maxi(0, values.find(cur)), func(i):
			cfg[key] = values[i]
			redraw.call()))
	var tp = int(cfg.get("tier_pref", 5))
	opt_row.call("Kademe", ["1 Kaburga", "2 İskelet", "3 İnsansı", "4 Zırhlı", "5 Mükemmel"], tp, "tier_pref", [1, 2, 3, 4, 5], mt)
	opt_row.call("Zırh", Susanoo.ARMORS, int(cfg.get("armor", 0)), "armor", range(Susanoo.ARMORS.size()))
	opt_row.call("Yüz", Susanoo.FACES, int(cfg.get("face", 0)), "face", range(Susanoo.FACES.size()))
	opt_row.call("Silah", Susanoo.WEAPONS.values(), cfg.get("weapon", "kilic"), "weapon", Susanoo.WEAPONS.keys())
	v.add_child(LazyFx.g("UI").label("Renk", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var cr = HFlowContainer.new()
	cr.add_theme_constant_override("h_separation", 8)
	for c in Susanoo.COLORS:
		var cc: Array = cfg.get("color", Susanoo.COLORS[0])
		cr.add_child(_swatch(Color(c[0], c[1], c[2]), Color(cc[0], cc[1], cc[2]).is_equal_approx(Color(c[0], c[1], c[2])), func():
			cfg["color"] = c
			redraw.call()))
	v.add_child(cr)
	v.add_child(LazyFx.g("UI").label("Kenar rengi", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var rr = HFlowContainer.new()
	rr.add_theme_constant_override("h_separation", 8)
	for c in Susanoo.COLORS:
		var rc: Array = cfg.get("rim_color", cfg.get("color", Susanoo.COLORS[0]))
		rr.add_child(_swatch(Color(c[0], c[1], c[2]), Color(rc[0], rc[1], rc[2]).is_equal_approx(Color(c[0], c[1], c[2])), func():
			cfg["rim_color"] = c
			redraw.call()))
	v.add_child(rr)
	# kaydırıcılar: menüyü baştan kurmadan önizlemeye ve açıksa oyundaki Susanoo'ya uygulanır
	var live = func() -> void:
		if is_instance_valid(_sus_prev):
			_sus_prev.apply_look()
		var ey = Game.player.combat.modes.eyes if Game.player and Game.player.combat and Game.player.combat.modes else null
		if ey and ey.susanoo and is_instance_valid(ey.susanoo_node):
			ey.susanoo_node.apply_look()
	for sd in [["Yoğunluk", "density", 0.3, 2.0], ["Kenar parlaklığı", "glow", 0.3, 2.0], ["Alev akışı", "flow", 0.0, 3.0]]:
		var hh = LazyFx.g("UI").hbox(8)
		var l = LazyFx.g("UI").label(sd[0], 13, LazyFx.g("UI").MUTED)
		l.custom_minimum_size = Vector2(130, 0)
		hh.add_child(l)
		var sl = HSlider.new()
		sl.min_value = sd[2]
		sl.max_value = sd[3]
		sl.step = 0.05
		sl.value = float(cfg.get(sd[1], 1.0))
		sl.custom_minimum_size = Vector2(240, 22)
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(x):
			cfg[sd[1]] = x
			live.call())
		hh.add_child(sl)
		v.add_child(hh)
	var wb = CheckBox.new()
	wb.text = "Kanatlar (Mükemmel Susanoo)"
	wb.button_pressed = bool(cfg.get("wings", true))
	wb.toggled.connect(func(x):
		cfg["wings"] = x
		redraw.call())
	v.add_child(wb)
	v.add_child(LazyFx.g("UI").icon_label("info", "Gözler açıkken V basılı tut. Sol tık dev savuruş, sağ tık silah saldırısı.", 13, LazyFx.g("UI").MUTED))


static func _hair_panel(v: VBoxContainer, look: Dictionary, refresh: Callable) -> void:
	v.add_child(LazyFx.g("UI").label("Berber ücretsiz", 14, LazyFx.g("UI").MUTED))
	var keys = CharacterModel.hair_styles_for(String(look.get("gender", "m")))
	v.add_child(_arrow_row("Saç Stili", keys.map(func(h): return CharacterModel.HAIR_STYLES[h]), maxi(0, keys.find(look.get("hair_style", ""))), func(i):
		look["hair_style"] = keys[i]
		refresh.call()))
	# yüz boyası (Striker Face Paint): berberde de değiştirilebilir
	var fpk: Array = CharacterModel.FACE_PAINTS.keys()
	v.add_child(_arrow_row("Yüz Boyası", fpk.map(func(k): return CharacterModel.FACE_PAINTS[k]), maxi(0, fpk.find(String(look.get("face_paint", "yok")))), func(i):
		look["face_paint"] = fpk[i]
		refresh.call()))
	var pck: Array = CharacterModel.FACE_PAINT_COLORS.keys()
	var cur_pc = look.get("face_paint_col")
	var pci = 0
	for k in pck.size():
		if cur_pc is Color and (CharacterModel.FACE_PAINT_COLORS[pck[k]] as Color).is_equal_approx(cur_pc):
			pci = k
	v.add_child(_arrow_row("Boya Rengi", pck, pci, func(i):
		look["face_paint_col"] = CharacterModel.FACE_PAINT_COLORS[pck[i]]
		refresh.call()))
	v.add_child(LazyFx.g("UI").label("Renk", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var cg = HFlowContainer.new()
	cg.add_theme_constant_override("h_separation", 8)
	for c in [Color(0.3, 0.2, 0.12), Color(0.08, 0.08, 0.1), Color(0.95, 0.8, 0.25), Color(0.75, 0.25, 0.15), Color(0.9, 0.9, 0.92), Color(0.2, 0.3, 0.6), Color(0.9, 0.55, 0.7), Color(0.25, 0.45, 0.25)]:
		cg.add_child(_swatch(c, Color(look.get("hair", Color.BLACK)).is_equal_approx(c), func():
			look["hair"] = c
			refresh.call()))
	v.add_child(cg)


## Önizleme / portrede dōjutsu görünsün (Bingo Book, envanter): look'taki göz eşyaları (eye_r / eye_l) ya da "dojutsu" sayısı
static func _preview_eyes(m: CharacterModel, look: Dictionary) -> void:
	var kr := 0; var lr := 3; var kl := 0; var ll := 3
	for pair in [["eye_r", true], ["eye_l", false]]:
		var ed = look.get(pair[0])
		if ed is Dictionary and int(ed.get("kind", 0)) > 0:
			if pair[1]:
				kr = int(ed["kind"]); lr = int(ed.get("lvl", 3))
			else:
				kl = int(ed["kind"]); ll = int(ed.get("lvl", 3))
	var dk := int(look.get("dojutsu", 0))
	if dk > 0:
		if kr == 0:
			kr = dk
		if kl == 0:
			kl = dk
	if kr == 0 and kl == 0:
		return
	m.set_dojutsu_eyes(kr, lr, kl, ll, false)
	if bool(look.get("own_hair", false)) and Game.profile is Dictionary and not Game.profile.is_empty():
		m.set_ms_designs(Eyes.design_for(Game.profile, "sag_goz"), Eyes.design_for(Game.profile, "sol_goz"))


## Ayrı dünyada dönen karakter önizlemesi (oyun duraklatılmışken de çalışır)
static func _model_preview(look: Dictionary, cam_pos := Vector3(0, 1.0, -4.4), target := Vector3(0, 0.92, 0), fov := 32.0, spin := true, size := Vector2(400, 600)) -> Control:
	var svc = SubViewportContainer.new()
	svc.custom_minimum_size = size
	svc.size = size
	svc.stretch = true
	svc.process_mode = Node.PROCESS_MODE_ALWAYS
	var sv = SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.environment.ambient_light_energy = 0.55
	sv.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	sv.add_child(sun)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.8, 0.55)
	sv.add_child(rim)
	var m = CharacterModel.new()
	sv.add_child(m)
	var lk2 = look.duplicate()
	lk2["own_hair"] = bool(look.get("own_hair", false))   # oyuncu (own_hair) seçtiği saçla; NPC (Bingo, konuşma portresi) dünyadaki gibi anime saçına eşlenir
	m.setup(lk2)
	m.play("idle")
	m.scale = Vector3.ONE
	_preview_eyes(m, look)
	var cam = Camera3D.new()
	cam.fov = fov
	sv.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(target - cam_pos), cam_pos)
	if spin:
		var tw = Game.safe_loops(m.create_tween())
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(m, "rotation:y", TAU, 12.0).from(0.0)
	svc.set_meta("model", m)
	return svc


# ------------------------------------------------------------------ jutsular
static var _jf_mode := "learned"
static var _jf_cat := ""
static var _jf_el := ""
static var _jf_text := ""
static var _jf_page := 0
const JF_PER := 120
const JUTSU_CATS := [["", "Tümü"], ["ninjutsu", "Ninjutsu"], ["taijutsu", "Taijutsu"], ["genjutsu", "Genjutsu"], ["fuinjutsu", "Fūinjutsu"], ["kekkei_genkai", "Kekkei Genkai"],
	["dojutsu", "Dōjutsu"], ["bijuu", "Kuyruklu Canavar"], ["hiden", "Hiden"], ["senjutsu", "Senjutsu"], ["kinjutsu", "Kinjutsu"], ["medical", "Tıbbi"], ["space_time", "Uzay-Zaman"], ["summoning", "Çağırma"]]
const JUTSU_ELEMS := [["", "Tüm elementler"], ["katon", "Katon"], ["suiton", "Suiton"], ["fuuton", "Fūton"], ["raiton", "Raiton"], ["doton", "Doton"],
	["mokuton", "Mokuton"], ["hyoton", "Hyōton"], ["yoton", "Yōton"], ["futton", "Futton"], ["ranton", "Ranton"], ["bakuton", "Bakuton"], ["jinton", "Jinton"],
	["shakuton", "Shakuton"], ["jiton", "Jiton"], ["shoton", "Shōton"], ["koton", "Kōton"], ["taiton", "Taiton"], ["meiton", "Meiton"], ["jinton_swift", "Jinton (Hız)"], ["deiton", "Deiton"]]


## Doğanın romaji adı (Katon, Fūton, Hyōton...): iç kimlik oyuncuya yazılmaz
static func _el_name(e: String) -> String:
	for r in JUTSU_ELEMS:
		if r[0] == e and e != "":
			return r[1]
	return String(LazyFx.g("Elements").NAMES.get(e, e.capitalize()))


static func _tab_jutsu(main: Node, body: Control, picked: String) -> void:
	var pr = Game.profile
	var h = LazyFx.g("UI").hbox(26)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left = LazyFx.g("UI").vbox(16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	# göz ve kuyruklu canavar teknikleri de slota konabilir (sanal jutsu)
	var learned: Array = (pr["learned"] as Array) + LazyFx.g("SpecialSlots").refresh(pr)
	if picked == "" and not learned.is_empty():
		picked = learned[0]
	# filtreler: öğrendiklerim / jutsu kitabı (tümü), kategori, element, arama
	var fbar = LazyFx.g("UI").hbox(8)
	left.add_child(fbar)
	var my_clan = String(pr.get("clan", "none"))
	var clan_ids: Array = ClanWorld.clan_jutsu_ids(my_clan, String(pr.get("sand_line", "")))
	var modes = [["learned", "Öğrendiklerim (%d)" % learned.size()], ["all", "Jutsu Kitabı (%d)" % Data.jutsu.size()]]
	if not clan_ids.is_empty():
		modes.append(["clan", "%s Teknikleri (%d)" % [Data.clans.get(my_clan, {}).get("name", my_clan), clan_ids.size()]])
	for m in modes:
		fbar.add_child(LazyFx.g("UI").chip(m[1], _jf_mode == m[0], func():
			_jf_mode = m[0]
			_jf_page = 0
			ninja_menu(main, "jutsu", picked)))
	var search = LineEdit.new()
	search.placeholder_text = "Ara..."
	search.text = _jf_text
	search.custom_minimum_size = Vector2(200, 36)
	search.text_submitted.connect(func(t):
		_jf_text = t
		_jf_page = 0
		ninja_menu(main, "jutsu", picked))
	fbar.add_child(search)
	var cbar = HFlowContainer.new()
	cbar.add_theme_constant_override("h_separation", 6)
	left.add_child(cbar)
	for c in JUTSU_CATS:
		cbar.add_child(LazyFx.g("UI").chip(c[1], _jf_cat == c[0], func():
			_jf_cat = c[0]
			_jf_page = 0
			ninja_menu(main, "jutsu", picked)))
	var ebar = HFlowContainer.new()
	ebar.add_theme_constant_override("h_separation", 6)
	left.add_child(ebar)
	for e in JUTSU_ELEMS:
		ebar.add_child(LazyFx.g("UI").chip(e[1], _jf_el == e[0], func():
			_jf_el = e[0]
			_jf_page = 0
			ninja_menu(main, "jutsu", picked)))
	var shown: Array = []
	for jid in (learned if _jf_mode == "learned" else (clan_ids if _jf_mode == "clan" else Data.jutsu.keys())):
		if String(jid).begins_with("_"):
			continue
		var jj: Dictionary = Data.jutsu.get(jid, {})
		if _jf_cat != "" and String(jj.get("category", "")) != _jf_cat:
			continue
		if _jf_el != "" and String(jj.get("element", "")) != _jf_el and not _jf_el in jj.get("elements", []):
			continue
		if _jf_text != "" and not String(jj.get("name", jid)).to_lower().contains(_jf_text.to_lower()):
			continue
		shown.append(jid)
	# sayfalama: liste ne kadar uzun olursa olsun hepsi görülebilir (◀ ▶)
	var pages := maxi(1, int(ceil(shown.size() / float(JF_PER))))
	_jf_page = clampi(_jf_page, 0, pages - 1)
	var total_shown := shown.size()
	shown = shown.slice(_jf_page * JF_PER, (_jf_page + 1) * JF_PER)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	if learned.is_empty() and _jf_mode == "learned":
		left.add_child(LazyFx.g("UI").label("Henüz bir jutsu bilmiyorsun. Akademi hocanla konuş!", 16, LazyFx.g("UI").MUTED))
	for jid in shown:
		var card = _jutsu_card(jid, jid == picked, func(): ninja_menu(main, "jutsu", jid))
		if not jid in learned:
			card.modulate = Color(1, 1, 1, 0.45)
		else:
			# sürükle: öğrenilmiş jutsu kartı slot çubuğuna bırakılabilir
			var cref = card
			var drag_card = func(_at):
				cref.set_drag_preview(_jutsu_drag_preview(jid))
				return {"jutsu": jid, "from_slot": -1}
			card.set_drag_forwarding(drag_card, Callable(), Callable())
		grid.add_child(card)
	if pages > 1:
		var pg = LazyFx.g("UI").hbox(10)
		pg.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(pg)
		pg.add_child(LazyFx.g("UI").chip("◀", false, func():
			_jf_page = (_jf_page - 1 + pages) % pages
			ninja_menu(main, "jutsu", picked)))
		pg.add_child(LazyFx.g("UI").label("Sayfa %d / %d  (%d teknik)" % [_jf_page + 1, pages, total_shown], 14, LazyFx.g("UI").MUTED))
		pg.add_child(LazyFx.g("UI").chip("▶", false, func():
			_jf_page = (_jf_page + 1) % pages
			ninja_menu(main, "jutsu", picked)))
	# slot çubuğu
	var bar = LazyFx.g("UI").card()
	left.add_child(bar)
	var bv = LazyFx.g("UI").vbox(8)
	bar.add_child(bv)
	var tipl = LazyFx.g("UI").label("Jutsu kartını bir slota sürükle-bırak (ya da seç ve slota tıkla). Slotlar arasında sürükleyerek yer değiştir, slottan çıkarmak için çöpe sürükle ya da sağ tıkla.", 14, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	tipl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(tipl)
	# slot karoları ekran genişliğine sığar (9 slot + çöp; sağdaki ayrıntı paneli ekran dışına itilmesin)
	var tw := int(clampf(floor((body.get_viewport_rect().size.x - 150.0 - 40.0 - 26.0 - 420.0 - 40.0 - 90.0) / 10.0), 64.0, 112.0))
	var sh = LazyFx.g("UI").hbox(10)
	bv.add_child(sh)
	var refresh_j = func() -> void:
		(func(): ninja_menu(main, "jutsu", picked)).call_deferred()
	# i: hedef slot, jid: bırakılan jutsu, from: kaynak slot (-1 = kitaptan)
	var assign = func(i: int, jid: String, from: int) -> void:
		while pr["slots"].size() < 9:
			pr["slots"].append("")
		if from >= 0 and from != i:
			var other = pr["slots"][i]
			pr["slots"][i] = jid
			pr["slots"][from] = other if other != null else ""
		elif from < 0:
			for k in 6:
				if pr["slots"][k] == jid:
					pr["slots"][k] = ""
			pr["slots"][i] = jid
		Sfx.play("click")
		refresh_j.call()
	var accepts = func(_at, data) -> bool:
		return data is Dictionary and data.has("jutsu") and String(data["jutsu"]) in learned
	for i in 9:
		var cur = pr["slots"][i] if i < pr["slots"].size() else ""
		var j: Dictionary = Data.jutsu.get(cur, {}) if cur != null and cur != "" else {}
		var el = String(j.get("element", ""))
		var view = LazyFx.g("Icons").view(LazyFx.g("UI").ELEMENT_ICONS.get(el, "chakra") if not j.is_empty() else "plus", 40, LazyFx.g("UI").ELEMENT_COLORS.get(el, LazyFx.g("UI").TEXT) if not j.is_empty() else Color(1, 1, 1, 0.15))
		var nm = String(j.get("name", "Boş")).split(":")[-1].split("(")[0].strip_edges()
		var t = _tile(view, "[%d] %s" % [i + 1, nm], LazyFx.g("UI").ELEMENT_COLORS.get(el, Color(1, 1, 1, 0.2)) if not j.is_empty() else Color(1, 1, 1, 0.15), false, func():
			if picked != "" and picked in learned:
				assign.call(i, picked, -1)
			elif picked != "":
				Hud.msg("Önce bu jutsuyu öğrenmelisin.", Color(1, 0.6, 0.4)), tw)
		t.tooltip_text = nm
		if not j.is_empty():
			var sfx_t = _jutsu_effects(String(cur), j)
			t.tooltip_text = String(j.get("name", nm)) + ("
" + sfx_t.replace("  •  ", "
") if sfx_t != "" else "")
		var tref = t
		var cur_id = String(cur) if cur != null else ""
		var drag_slot = func(_at):
			if cur_id == "":
				return null
			tref.set_drag_preview(_jutsu_drag_preview(cur_id))
			return {"jutsu": cur_id, "from_slot": i}
		var drop_slot = func(_at, data) -> void:
			assign.call(i, String(data["jutsu"]), int(data.get("from_slot", -1)))
		t.set_drag_forwarding(drag_slot, accepts, drop_slot)
		t.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and cur_id != "":
				pr["slots"][i] = ""
				Sfx.play("click")
				refresh_j.call())
		sh.add_child(t)
	# çöp: slottan sürüklenen jutsu buraya bırakılınca slot boşalır
	var trash = _tile(LazyFx.g("Icons").view("close", 36, Color(1, 0.5, 0.45)), "Çıkar", Color(1, 0.4, 0.35, 0.5), false, func(): pass, tw)
	trash.tooltip_text = "Slottan çıkarmak için buraya sürükle"
	var trash_ok = func(_at, data) -> bool:
		return data is Dictionary and int(data.get("from_slot", -1)) >= 0
	var trash_drop = func(_at, data) -> void:
		pr["slots"][int(data["from_slot"])] = ""
		Sfx.play("click")
		refresh_j.call()
	trash.set_drag_forwarding(Callable(), trash_ok, trash_drop)
	sh.add_child(trash)
	# sağ: ayrıntı
	var right = LazyFx.g("UI").card()
	right.custom_minimum_size = Vector2(420, 0)
	h.add_child(right)
	var rv = LazyFx.g("UI").vbox(10)
	right.add_child(rv)
	# uzun satır paneli ekran dışına itmesin: doğrudan eklenen her yazı satır kaydırır
	rv.child_entered_tree.connect(func(n):
		if n is Label and n.autowrap_mode == TextServer.AUTOWRAP_OFF:
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART)
	if picked == "":
		rv.add_child(LazyFx.g("UI").label("Bir jutsu seç.", 16, LazyFx.g("UI").MUTED))
		return
	var j: Dictionary = Data.jutsu.get(picked, {})
	var el = String(j.get("element", ""))
	var ec: Color = LazyFx.g("UI").ELEMENT_COLORS.get(el, LazyFx.g("UI").GOLD)
	if not picked in learned:
		var why = Progress.can_learn(picked) if Progress.has_method("can_learn") else ""
		var how = {"academy": "Akademide öğrenilir", "scroll": "Köydeki Parşömenci'den parşömeni alınır (doğana uygunsa)", "clan": "Klan tekniği",
			"kinjutsu": "Yasak teknik: Yeraltı Simsarı'ndan parşömenin izini al, saklandığı yerden çıkar", "element": "Element başlangıç tekniği",
			"shrine:uzumaki": "Uzushio harabesindeki Uzumaki maske tapınağında (Uzumaki klanı ya da Kage)"}
		var lp = String(j.get("learn", ""))
		var txt = how.get(lp, "")
		if lp.begins_with("trainer"):
			var tk = lp.trim_prefix("trainer").trim_prefix(":")
			if tk in Progress.SCROLL_TRAINERS:
				txt = LazyFx.g("Lang").t("%s köy eğitmeni öğretir; parşömeni Parşömenci'de de çıkar") % WorldPeople.vname(tk)
			elif tk == "hospital":
				txt = LazyFx.g("Lang").t("Köy hastanesindeki tıbbi ninja eğitmeni öğretir")
			elif tk in ["jonin", "fuin", "konoha_jonin"]:
				txt = LazyFx.g("Lang").t("Köy eğitmeni öğretir (Chūnin ve üstü)")
			else:
				txt = LazyFx.g("Lang").t("Köy eğitmeni ya da Akademi yardımcı hocası öğretir")
		elif lp.begins_with("quest:"):
			txt = LazyFx.g("Lang").t("Özel görevle öğrenilir")
		elif lp.begins_with("path:"):
			txt = LazyFx.g("Lang").t("Efsane Yolu: %s ustası öğretir") % LazyFx.g("Lang").t(String(LegendPaths.PATHS.get(lp.substr(5), {}).get("name", "bir yolun")))
		elif lp.begins_with("locked:"):
			txt = LazyFx.g("Lang").t("Şu an öğrenilemez")
		elif lp.begins_with("clan:"):
			txt = LazyFx.g("Lang").t("%s klan tekniği — klan üyeleri Güç %d'de kendiliğinden öğrenir") % [Data.clans.get(lp.substr(5), {}).get("name", lp.substr(5)), int(j.get("level", 1))]
		elif lp == "element":
			txt = LazyFx.g("Lang").t("İlk element tekniği: mezuniyetten sonra Antrenman Alanı'nda hocanın chakra kâğıdı testiyle öğrenilir (o doğa sende olmalı)")
		elif lp.begins_with("kg"):
			txt = LazyFx.g("Lang").t("Kekkei genkai gerekir (%s)") % _el_name(lp.trim_prefix("kg:"))
		elif lp.begins_with("eye"):
			txt = LazyFx.g("Lang").t("%s gözü gerekir") % Progress.eye_name(lp.trim_prefix("eye:"))
		elif lp.begins_with("sage"):
			txt = LazyFx.g("Lang").t("Sennin modu gerekir (bir sözleşme diyarında doğa enerjisi eğitimi)")
		elif lp.begins_with("weapon:"):
			txt = LazyFx.g("Lang").t("%s ele geçirilince öğrenilir") % String(LazyFx.g("Gear").item(lp.substr(7)).get("name", lp.substr(7)))
		elif lp.begins_with("beast:"):
			txt = LazyFx.g("Lang").t("%s jinchūriki'si olunca canavar öğretir (Güç %d)") % [String(LazyFx.g("BeastModels").INFO.get(lp.substr(6), {}).get("name", lp.substr(6))).split(" —")[0], int(j.get("level", 1))]
		elif lp.begins_with("contract:"):
			txt = LazyFx.g("Lang").t("%s imzalanınca bilge öğretir (Güç %d)") % [String(LazyFx.g("Contracts").DEFS.get(lp.substr(9), {}).get("name", "Çağırma sözleşmesi")), int(j.get("level", 1))]
		elif lp.begins_with("special") or lp == "signature":
			txt = LazyFx.g("Lang").t("Özel görev ile açılır")
		if picked in Data.clans.get(String(Game.profile.get("clan", "")), {}).get("family_arts", []):
			txt = LazyFx.g("Lang").t("Aile öğretisi: Güç %d olunca ailen öğretir (rütbe gerekmez)") % int(j.get("level", 1))
		rv.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("🔒 Öğrenilmedi — ") + LazyFx.g("Lang").t(txt if txt != "" else lp) + ((".  " + LazyFx.g("Lang").t(why)) if why != "" and not LazyFx.g("Lang").t(txt).contains(LazyFx.g("Lang").t(why)) else ""), 14, Color(1, 0.75, 0.45), HORIZONTAL_ALIGNMENT_LEFT, true))
	var top = LazyFx.g("UI").hbox(14)
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(76, 76)
	badge.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(ec, 0.18), Color(ec, 0.8), 2, 38, 0))
	var bi = LazyFx.g("Icons").view(LazyFx.g("UI").ELEMENT_ICONS.get(el, "chakra"), 44, ec)
	bi.position = Vector2(16, 16)
	badge.add_child(bi)
	top.add_child(badge)
	var tv = LazyFx.g("UI").vbox(2)
	var nm = LazyFx.g("UI").label(String(j.get("name", picked)), 22, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(300, 0)
	tv.add_child(nm)
	tv.add_child(LazyFx.g("UI").label("%s-rank   •   %s" % [j.get("canon_rank", "?"), _el_name(el) if el != "" else "Doğasız"], 14, ec, HORIZONTAL_ALIGNMENT_LEFT, true))
	top.add_child(tv)
	rv.add_child(top)
	var stats = LazyFx.g("UI").hbox(22)
	stats.add_child(LazyFx.g("UI").icon_label("chakra", _cost_text(j), 15, Color(1.0, 0.75, 0.4) if LazyFx.g("Stats").is_taijutsu(j) else Color(0.55, 0.78, 1.0)))
	stats.add_child(LazyFx.g("UI").icon_label("hourglass", "%.1f sn" % Combat.jutsu_cd(j), 15, LazyFx.g("UI").MUTED))
	rv.add_child(stats)
	var seals: Array = j.get("seals", [])
	if not seals.is_empty():
		rv.add_child(LazyFx.g("UI").label("Mühürler", 13, LazyFx.g("UI").MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		var fl = HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for s in seals:
			var p = PanelContainer.new()
			var psb = LazyFx.g("UI")._box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), 1, 14, 4)
			psb.content_margin_left = 12; psb.content_margin_right = 12
			p.add_theme_stylebox_override("panel", psb)
			p.add_child(LazyFx.g("UI").label(String(s), 13, LazyFx.g("UI").CREAM))
			fl.add_child(p)
		rv.add_child(fl)
	var mean = String(j.get("meaning", ""))
	var d = LazyFx.g("UI").label(("“%s” — " % mean if mean != "" else "") + String(j.get("desc", "")), 15, LazyFx.g("UI").MUTED)   # ad Japonca; Türkçe anlamı açıklamada
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(380, 0)
	rv.add_child(d)
	var fx = _jutsu_effects(picked, j)
	if fx != "":
		var fl2 = LazyFx.g("UI").label(fx, 15, Color(1, 0.82, 0.55))
		fl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl2.custom_minimum_size = Vector2(380, 0)
		rv.add_child(fl2)


## Jutsunun sayısal etkisi: tahmini hasar (oyuncunun gücüyle), element etkileri
static func _jutsu_effects(jid: String, j: Dictionary) -> String:
	var parts = []
	var shp = String(j.get("shape", ""))
	var t = int(j.get("tier", 2))
	var dmg = _jutsu_dmg(j)
	if dmg > 0:
		parts.append(LazyFx.g("Lang").t("Hasar ≈ %d") % dmg)
	var el = String(j.get("element", ""))
	if el in ["katon", "yoton"]:
		parts.append(LazyFx.g("Lang").t("Yakar (%.1f sn)") % (1.5 + t * 0.4))
	if el == "shakuton":
		parts.append(LazyFx.g("Lang").t("Beden suyunu buharlaştırır: yavaşlatır (%.1f sn)") % (1.0 + t * 0.3))
	if el in ["raiton", "ranton"] and t >= 2:
		parts.append(LazyFx.g("Lang").t("Sersemletir (%.1f sn)") % (0.3 + t * 0.12))
	# doğa döngüsü (Elements.BEATS: Katon > Fūton > Raiton > Doton > Suiton > Katon)
	if LazyFx.g("Elements").BEATS.has(el):
		parts.append(LazyFx.g("Lang").t("%s karşısında üstün, %s karşısında zayıf") % [_el_name(String(LazyFx.g("Elements").BEATS[el])), _el_name(String(LazyFx.g("Elements").BEATS.find_key(el)))])
	elif el == "hyoton":
		parts.append(LazyFx.g("Lang").t("Suyu dondurur, Katon karşısında zayıf"))
	if t >= 3:
		parts.append(LazyFx.g("Lang").t("Ağır vuruş: geri savurur"))
	match shp:
		"buff", "transform":
			parts.append(LazyFx.g("Lang").t("Güçlendirme — etkisi kullanınca sol üstte yazar"))
		"heal":
			parts.append(LazyFx.g("Lang").t("İyileştirir"))
		"bind", "genjutsu_stun":
			parts.append(LazyFx.g("Lang").t("Hareketsiz bırakır"))
	return "  •  ".join(parts)


## Sürüklenirken imlecin yanında görünen küçük jutsu rozeti
static func _jutsu_drag_preview(jid: String) -> Control:
	var j: Dictionary = Data.jutsu.get(jid, {})
	var el = String(j.get("element", ""))
	var ec: Color = LazyFx.g("UI").ELEMENT_COLORS.get(el, LazyFx.g("UI").GOLD)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(0.05, 0.06, 0.09, 0.92), ec, 2, 14, 8))
	var hb = LazyFx.g("UI").hbox(8)
	p.add_child(hb)
	hb.add_child(LazyFx.g("Icons").view(LazyFx.g("UI").ELEMENT_ICONS.get(el, "chakra"), 32, ec))
	hb.add_child(LazyFx.g("UI").label(String(j.get("name", jid)).split("(")[0].strip_edges(), 15, LazyFx.g("UI").TEXT))
	p.position = Vector2(-20, -20)
	return p


static func _jutsu_card(jid: String, selected: bool, cb: Callable) -> Button:
	var j: Dictionary = Data.jutsu.get(jid, {})
	var el = String(j.get("element", ""))
	var ec: Color = LazyFx.g("UI").ELEMENT_COLORS.get(el, LazyFx.g("UI").GOLD)
	var b = Button.new()
	b.custom_minimum_size = Vector2(300, 92)
	var n = LazyFx.g("UI")._box(Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.08), 1, 12, 10)
	n.border_width_left = 4
	n.border_color = Color(ec, 0.8)
	var hh = n.duplicate()
	hh.bg_color = Color(1, 1, 1, 0.1)
	var s = n.duplicate()
	s.bg_color = Color(ec, 0.16)
	s.set_border_width_all(2)
	s.border_width_left = 4
	s.border_color = ec
	b.add_theme_stylebox_override("normal", s if selected else n)
	b.add_theme_stylebox_override("hover", s if selected else hh)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s if selected else hh)
	var ic = LazyFx.g("Icons").view(LazyFx.g("UI").ELEMENT_ICONS.get(el, "chakra"), 38, ec)
	ic.position = Vector2(16, 26)
	b.add_child(ic)
	var nm = LazyFx.g("UI").label(String(j.get("name", jid)).split("(")[0].strip_edges(), 16, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.position = Vector2(66, 16)
	nm.size = Vector2(222, 22)
	nm.clip_text = true
	b.add_child(nm)
	var sub = LazyFx.g("UI").label("%s-rank  •  %s  •  %d mühür" % [j.get("canon_rank", "?"), _cost_text(j), (j.get("seals", []) as Array).size()], 12, LazyFx.g("UI").MUTED)
	sub.position = Vector2(66, 46)
	sub.size = Vector2(222, 18)
	b.add_child(sub)
	# hasar kartın sağ üstünde, ayrıntılar üstüne gelince (ipucu)
	var dmg = _jutsu_dmg(j)
	if dmg > 0:
		var dl = LazyFx.g("UI").label("%d hasar" % dmg, 12, Color(1, 0.6, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, true)
		dl.position = Vector2(196, 66)
		dl.size = Vector2(96, 18)
		b.add_child(dl)
	var fx = _jutsu_effects(jid, j)
	b.tooltip_text = ("“%s”
" % j["meaning"] if String(j.get("meaning", "")) != "" else "") + String(j.get("desc", "")) + ("

" + fx.replace("  •  ", "
") if fx != "" else "") + "
%s   •   Bekleme: %.1f sn" % [_cost_text(j), Combat.jutsu_cd(j)]
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	LazyFx.g("UI").hover_anim(b, 1.02)
	return b


## Jutsunun bedeli: taijutsu chakra değil stamina harcar (PlayerCombat ile aynı hesap)
static func _cost_text(j: Dictionary) -> String:
	if LazyFx.g("Stats").is_taijutsu(j):
		return LazyFx.g("Lang").t("%d stamina") % int(LazyFx.g("Stats").tai_stamina_cost(j))
	return LazyFx.g("Lang").t("%d chakra") % int(PlayerCombat.jutsu_cost(j))


## Jutsunun yaklaşık hasarı (hasarsız teknikler: 0)
static func _jutsu_dmg(j: Dictionary) -> int:
	if Game.player == null or String(j.get("category", "")) == "dojutsu":
		return 0
	if String(j.get("shape", "")) in ["buff", "transform", "heal", "teleport", "clone", "summon", "genjutsu_stun", "bind", "mode", "utility", "sensor", "stealth"]:
		return 0
	return int(LazyFx.g("JutsuEngine").base_dmg(Game.player, j))


# ------------------------------------------------------------------ yetenek ağacı (düğüm grafiği)
static var _skill_sel := ""


## Yetenek ağacı kaldırıldı: bu sekme ustalıkları gösterir (nasıl geliştiği + açtığı şeyler)
static func _tab_skills(_main: Node, body: Control) -> void:
	var pr = Game.profile
	var v = LazyFx.g("UI").vbox(12)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(v)
	v.add_child(LazyFx.g("UI").label("Güç %d  —  seviye yok: yaptıkça gelişirsin" % int(pr.get("level", 1)), 24, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_LEFT, true))
	# dövüş tarzı: silahsız düz vuruş kombosu (klan/yol/bijū ile açılır); silah kuşanınca silahın kombosu geçerli
	var styles: Array = LazyFx.g("FightingStyles").available(pr)
	var cur = String(pr.get("fight_style", ""))
	var ci = maxi(0, styles.find(cur))
	var sdesc = func(id: String) -> String:
		return (LazyFx.g("Lang").t("Silahsız temel yumruk-tekme kombosu. Klanın, yolun ya da bijūn yeni tarzlar açar.") if id == "" or not LazyFx.g("FightingStyles").STYLES.has(id) else LazyFx.g("Lang").t("Menzil: %s.") % LazyFx.g("Lang").t(String(LazyFx.g("FightingStyles").STYLES[id].get("range", "yakın"))) + "  " + LazyFx.g("Lang").t(String(LazyFx.g("FightingStyles").STYLES[id]["desc"]))) + "  " + LazyFx.g("Lang").t("(Silah kuşanınca silahın kendi kombosu geçerli.)")
	var sdl = LazyFx.g("UI").label(sdesc.call(cur), 14, LazyFx.g("UI").MUTED)
	sdl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sdl.custom_minimum_size = Vector2(1200, 0)
	v.add_child(_arrow_row("Dövüş Tarzı", styles.map(func(x): return LazyFx.g("FightingStyles").name_of(String(x))), ci, func(i):
		pr["fight_style"] = String(styles[i])
		sdl.text = sdesc.call(String(styles[i]))
		Hud.msg("Dövüş tarzı: %s" % LazyFx.g("FightingStyles").name_of(String(styles[i])), Color(0.95, 0.85, 0.55))))
	v.add_child(sdl)
	var how = {"ninjutsu": "Jutsu attıkça (mühür bozulsa da biraz). Yüksek rütbe teknikler için gerekli; mühür hızı.",
		"taijutsu": "Yumrukla vurdukça; antrenman kuklası 2 kat.", "kenjutsu": "Silahla vurdukça; antrenman kuklası 2 kat.",
		"chakra": LazyFx.g("Lang").t("Jutsu attıkça, %s ile meditasyon, duvar/ağaç tırmanma, su üstünde yürüme. Chakra havuzu ve toplama hızı.") % Keys.name("charge"),
		"dayaniklilik": "Hasar aldıkça, taijutsu tekniği yaptıkça, asılı kütükle (Tsuri Maruta) ve kaya tırmanarak. Can ve stamina.",
		"hiz": LazyFx.g("Lang").t("Ninja koşusunda (%s) koştukça. Hareket hızı.") % Keys.name("dash"),
		"genjutsu": "Genjutsu yaptıkça. Genjutsu gücü + sana atılan genjutsunun etkisi azalır.", "fuinjutsu": "Mühürleme teknikleri yaptıkça. Fūinjutsu gücü.", "iryo": "Tıbbi teknikler yaptıkça (Shōsen...). İyileştirme gücü.",
		"senjutsu": "Senjutsu teknikleri yaptıkça. Senjutsu gücü + Sage Modu güçlenir.", "kuchiyose": "Çağırma teknikleri yaptıkça. Çağrının canı ve hasarı artar.", "shurikenjutsu": "Kunai, shuriken, senbon attıkça. Atış hasarı + alet bekleme süresi kısalır."}
	# 12 dal: iki sütun + kaydırma (tek sütunda alttakiler ekranın dışına taşıyordu)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var inner = LazyFx.g("UI").vbox(14)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 14)
	inner.add_child(grid)
	for k in LazyFx.g("Mastery").KEYS:
		var val = LazyFx.g("Mastery").get_v(pr, k)
		var cell = LazyFx.g("UI").vbox(4)
		cell.custom_minimum_size = Vector2(620, 0)
		grid.add_child(cell)
		var row = LazyFx.g("UI").hbox(12)
		cell.add_child(row)
		var nl = LazyFx.g("UI").label(LazyFx.g("Mastery").NAMES[k], 19, LazyFx.g("UI").GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		nl.custom_minimum_size = Vector2(220, 0)
		row.add_child(nl)
		var bar = ProgressBar.new()
		bar.max_value = maxf(100.0, ceilf((val + 0.01) / 100.0) * 100.0)   # sınır yok: çubuk sonraki yüzlüğe kadar
		bar.value = val
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 20)
		row.add_child(bar)
		row.add_child(LazyFx.g("UI").label("%.2f" % val, 19, LazyFx.g("UI").CREAM))   # ondalıklı: yavaş artış da görünsün
		var hl = LazyFx.g("UI").label(how[k], 14, LazyFx.g("UI").MUTED)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(600, 0)
		cell.add_child(hl)
	var opened = []
	# yalnız oyunda gerçekten işleyen açılımlar, oyuncunun anlayacağı adla (eskiden iç kimlikler ve etkisiz bayraklar yazıyordu)
	var unlock_names = {"kai": LazyFx.g("Lang").t("Kai: sersemlik / genjutsu çözme (%s)") % Keys.name("substitute"), "sensor": LazyFx.g("Lang").t("Algılama: uzaktaki düşmanlar mini haritada"), "multi_throw": LazyFx.g("Lang").t("Çoklu atış (kunai, shuriken)")}
	for f in unlock_names:
		var u = LazyFx.g("Stats").UNLOCK_AT[f]
		opened.append("%s %s (%s %d)" % ["✓" if LazyFx.g("Stats").has_unlock(pr, f) else "·", unlock_names[f], LazyFx.g("Lang").t(String(LazyFx.g("Mastery").NAMES[u[0]])), int(u[1])])
	var ol = LazyFx.g("UI").label(LazyFx.g("Lang").t("Ustalıkla açılanlar:") + "  " + "   ".join(opened), 13, LazyFx.g("UI").MUTED)
	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ol.custom_minimum_size = Vector2(1240, 0)
	inner.add_child(ol)
	# doğalar: her doğanın ustalığı, sıradaki doğa eşiği, birleştirilebilecek ara doğalar
	var el_parts = []
	for e in pr.get("elements", []):
		if e in LazyFx.g("KgPaths").BASE:
			el_parts.append("%s %d" % [LazyFx.g("Lang").t(String(LazyFx.g("Elements").NAMES.get(e, e))), int(LazyFx.g("Mastery").el_v(pr, e))])
	var el_txt = LazyFx.g("Lang").t("Doğa ustalığı:") + "  " + "   ".join(el_parts)
	var nin = LazyFx.g("Mastery").get_v(pr, "ninjutsu")
	for t in LazyFx.g("Mastery").EL_AT:
		if nin < t and el_parts.size() < 5:
			el_txt += "      " + LazyFx.g("Lang").t("Sıradaki doğa: Ninjutsu %d") % int(t)
			break
	var el_l = LazyFx.g("UI").label(el_txt, 13, LazyFx.g("UI").MUTED)
	el_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	inner.add_child(el_l)
	var fz = []
	for r in LazyFx.g("KgPaths").fuse_rows(pr):
		fz.append(("✓ %s" % LazyFx.g("Lang").t(r[0])) if r[5] else "%s: %s %d/%d + %s %d/%d" % [LazyFx.g("Lang").t(r[0]), LazyFx.g("Lang").t(r[1]), r[2], int(LazyFx.g("KgPaths").FUSE_AT), LazyFx.g("Lang").t(r[3]), r[4], int(LazyFx.g("KgPaths").FUSE_AT)])
	if not fz.is_empty():
		var fl = LazyFx.g("UI").label(LazyFx.g("Lang").t("Doğa birleştirme:") + "  " + "     ".join(fz), 13, LazyFx.g("UI").MUTED)
		fl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(1240, 0)
		inner.add_child(fl)


# ------------------------------------------------------------------ görevler sekmesi
static func _tab_missions(main: Node, body: Control) -> void:
	var pr = Game.profile
	var h = LazyFx.g("UI").hbox(26)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left = LazyFx.g("UI").vbox(16)
	left.custom_minimum_size = Vector2(760, 0)
	h.add_child(left)
	# Genin takımı: köyde bekletildiyse geri çağır
	var sqd: Dictionary = pr.get("squad", {})
	if int(pr.get("rank", 0)) == 1 and String(sqd.get("state", "")) == "active":
		var tc = LazyFx.g("UI").card(Color(0.55, 1.0, 0.6))
		left.add_child(tc)
		var tv = LazyFx.g("UI").vbox(6)
		tc.add_child(tv)
		tv.add_child(LazyFx.g("UI").label("Takımın: %s, %s  •  Hoca: %s" % [sqd["mates"][0]["name"], sqd["mates"][1]["name"], sqd["sensei"]["name"]], 16, LazyFx.g("UI").TEXT))
		if sqd.get("on_mission", false):
			tv.add_child(LazyFx.g("UI").label("Takım görevde, yanında. Görev bitince dağılırsınız.", 13, LazyFx.g("UI").MUTED))
		elif sqd.has("meet"):
			tv.add_child(LazyFx.g("UI").label("Buluşma: antrenman alanı — oraya gidince görev başlar.", 13, LazyFx.g("UI").GOLD))
		else:
			tv.add_child(LazyFx.g("UI").button("Hocana haber gönder (görev iste)", func():
				main.resume()
				LazyFx.g("GeninSquad").recall(), 300, "person"))
			tv.add_child(LazyFx.g("UI").label("Arkadaşların ve hocan köyde kendi hayatlarını yaşıyor; Tab > İlişkiler'de görünürler. Görevleri hocan alır: önce 2 D-rank, sonra C-rank. %d görev yapıldı." % int(sqd.get("missions", 0)), 13, LazyFx.g("UI").MUTED))
	# hikâye
	var sc = LazyFx.g("UI").card(LazyFx.g("UI").GOLD)
	left.add_child(sc)
	var sv = LazyFx.g("UI").vbox(8)
	sc.add_child(sv)
	sv.add_child(LazyFx.g("UI").icon_label("book", "YOLUN" if LazyFx.g("Journal").is_free() else "AKADEMİ", 15, LazyFx.g("UI").GOLD))
	var st = LazyFx.g("UI").label(String(Progress.objective_text()), 18)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(700, 0)
	sv.add_child(st)
	LazyFx.g("JournalUI").build_story(main, sv)   # kişisel hedefler, yaşam yolu, rakip (sabit hikâye yok)
	# aktif görev
	var m: Dictionary = pr.get("active_mission", {})
	var mc = LazyFx.g("UI").card()
	left.add_child(mc)
	var mv = LazyFx.g("UI").vbox(8)
	mc.add_child(mv)
	mv.add_child(LazyFx.g("UI").icon_label("mission", "AKTİF GÖREV", 15, LazyFx.g("UI").GOLD))
	if m.is_empty():
		mv.add_child(LazyFx.g("UI").label("Aktif görev yok. Köydeki görev masasından görev alabilirsin.", 16, LazyFx.g("UI").MUTED))
	else:
		var row = LazyFx.g("UI").hbox(16)
		row.add_child(_rank_stamp(String(m.get("rank", "D")), 64))
		var tv = LazyFx.g("UI").vbox(4)
		tv.add_child(LazyFx.g("UI").label(String(m.get("title", "")), 22, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		var dl = LazyFx.g("UI").label(String(m.get("desc", "")), 15, LazyFx.g("UI").MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(600, 0)
		tv.add_child(dl)
		row.add_child(tv)
		mv.add_child(row)
		var steps: Array = m.get("steps", [])
		var cur_step = int(m.get("step", m.get("progress", 0)))
		for i in steps.size():
			var done = i < cur_step
			mv.add_child(LazyFx.g("UI").icon_label("check" if done else ("play" if i == cur_step else "target"), String(steps[i].get("text", "")), 15, LazyFx.g("UI").GOOD if done else (LazyFx.g("UI").TEXT if i == cur_step else LazyFx.g("UI").MUTED)))
	# takip: ok neyi göstersin (her an aynı yeri göstermesin)
	var tc = LazyFx.g("UI").card()
	left.add_child(tc)
	var tv2 = LazyFx.g("UI").vbox(8)
	tc.add_child(tv2)
	tv2.add_child(LazyFx.g("UI").icon_label("target", "TAKİP — ok ve ışık sütunu neyi göstersin?", 15, LazyFx.g("UI").GOLD))
	var topts = Missions.track_options()
	var tlabels = topts.map(func(o): return o[1])
	tv2.add_child(_arrow_row("Göster", tlabels, Missions.track_index(topts), func(i):
		Missions.set_track(String(topts[i][0]))
		Sfx.play("click")
		ninja_menu(main, "missions")))
	var wp = pr.get("waypoint")
	if wp is Array and wp.size() >= 4:
		tv2.add_child(LazyFx.g("UI").button("Seçilen yeri sil", func():
			pr.erase("waypoint")
			if String(pr.get("track", "")) == "waypoint":
				pr["track"] = ""
			ninja_menu(main, "missions"), 240, "close"))
		tv2.get_child(tv2.get_child_count() - 1).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv2.add_child(LazyFx.g("UI").label(LazyFx.g("Lang").t("Oyun içinde %s tuşu: aktif hedefler arasında geç. Yeni yer seçmek için: Harita > Yakındaki Yerler.") % Keys.name("track_next"), 13, LazyFx.g("UI").MUTED))
	var acts = LazyFx.g("UI").hbox(12)
	left.add_child(acts)
	acts.add_child(LazyFx.g("UI").button("Haritada göster", func(): world_map(main), 240, "map"))
	if Missions.has_method("bingo_entries"):
		acts.add_child(LazyFx.g("UI").button("Bingo Kitabı", func(): bingo_book(main), 240, "book"))
	# sağ: tamamlananlar
	var right = LazyFx.g("UI").card()
	right.custom_minimum_size = Vector2(380, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(right)
	var rv = LazyFx.g("UI").vbox(12)
	right.add_child(rv)
	rv.add_child(LazyFx.g("UI").icon_label("check", "TAMAMLANANLAR", 15, LazyFx.g("UI").GOLD))
	var md: Dictionary = pr["missions_done"]
	var grid = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	for r in ["D", "C", "B", "A", "S"]:
		var cv = LazyFx.g("UI").vbox(4)
		cv.add_child(_rank_stamp(r, 52))
		cv.add_child(LazyFx.g("UI").label(str(int(md.get(r, 0))), 18, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
		grid.add_child(cv)
	rv.add_child(grid)
	LazyFx.g("JournalUI").build_chronicle(rv)   # yaşadıklarının günlüğü


## Kırmızı mürekkep rütbe damgası
static func _rank_stamp(r: String, size := 64) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col = {"D": Color(0.55, 0.62, 0.5), "C": Color(0.3, 0.55, 0.85), "B": Color(0.62, 0.38, 0.85), "A": Color(0.9, 0.45, 0.15), "S": Color(0.85, 0.12, 0.12)}.get(r, Color(0.8, 0.15, 0.15))
	c.draw.connect(func():
		var cen = Vector2(size, size) * 0.5
		c.draw_circle(cen, size * 0.47, Color(col, 0.16))
		c.draw_arc(cen, size * 0.44, 0, TAU, 40, col, maxf(2.0, size * 0.06), true)
		c.draw_arc(cen, size * 0.34, 0.3, TAU - 0.4, 40, Color(col, 0.55), 1.5, true)
		var f = LazyFx.g("UI").font(true)
		var fs = int(size * 0.5)
		var w = f.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(f, cen + Vector2(-w * 0.5, fs * 0.36), r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col))
	return c


static func inventory(main: Node) -> void:
	ninja_menu(main, "inv")


static func jutsu_skills(main: Node, picked := "") -> void:
	ninja_menu(main, "jutsu", picked)


static func _pick_element(_main) -> void:
	var pr = Game.profile
	var opts = []
	for e in ["katon", "suiton", "fuuton", "doton", "raiton"]:
		if e in pr["elements"]:
			continue
		opts.append({"label": e.capitalize(), "cb": func():
			pr["elements"].append(e)

			var starter = {"katon": "katon_goukakyuu", "suiton": "suiton_suikoudan", "fuuton": "fuuton_shinkuu", "doton": "doton_doryuusou", "raiton": "raiton_nagashi"}[e]
			Progress.learn(starter)
			Progress.clan_unlocks(true)})
	Hud.dialog("Yeni Chakra Doğası", "Ninjutsu ustalığın bir doğa daha açtı. Hangisini geliştireceksin?", opts)


# ================================================================== görev masası (ahşap pano + parşömenler)
static var _board_open := {}


static func mission_board(village_id: String) -> void:
	var main = Hud.get_tree().current_scene
	var list: Array = []
	if Missions.has_method("board_missions"):
		list = Missions.board_missions(village_id)
	else:
		list = Missions.board
	Missions.board = list
	Missions.board_village = village_id
	Game.ui_open = true
	Game.mouse(false)
	var bg = _full(0.45)
	# ahşap pano
	var board = ColorRect.new()
	var wm = ShaderMaterial.new()
	wm.shader = load("res://shaders/ui_wood.gdshader")
	board.material = wm
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.offset_left = 90; board.offset_right = -90; board.offset_top = 70; board.offset_bottom = -70
	bg.add_child(board)
	if _fresh:
		LazyFx.g("UI").pop_in(board, 0.97)
	# başlık plakası
	var ug = village_id == LazyFx.g("RogueJobs").BOARD   # yeraltı panosu
	var vname = "Yeraltı" if ug else String(Game.village(village_id).get("name", village_id))
	var plate = PanelContainer.new()
	var psb = LazyFx.g("UI")._box(Color(0.12, 0.07, 0.04, 0.95), Color(LazyFx.g("UI").GOLD, 0.7), 2, 8, 12)
	psb.content_margin_left = 40; psb.content_margin_right = 40
	plate.add_theme_stylebox_override("panel", psb)
	plate.add_child(LazyFx.g("UI").label("闇   YERALTI PANOSU" if ug else "任務   GÖREV MASASI — %s" % vname.to_upper(), 24, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))
	plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plate.position = Vector2(-330, -18)
	plate.custom_minimum_size = Vector2(660, 0)
	board.add_child(plate)
	var rep_txt = ""
	if Missions.has_method("rep"):
		rep_txt = "%s itibarın: %d" % [vname, int(Missions.rep(village_id))]
	if Missions.has_method("board_limits") and not ug:
		var lim = Missions.board_limits(village_id)
		if String(lim.get("note", "")) != "":
			rep_txt += "   •   " + String(lim["note"])
	var sub = LazyFx.g("UI").label(("Kaçak rütben: %s   •   şöhret %d   •   başındaki ödül %d Ryō   •   iz %d/100" % [Orgs.rogue_rank_name(), Orgs.infamy(), int(Orgs.state().get("bounty", 0)), int(LazyFx.g("RogueJobs").trail())]) if ug else ("Rütben: %s   •   %s" % [Data.RANKS[int(Game.profile["rank"])], rep_txt]), 15, Color(1, 0.92, 0.8))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-500, 52)
	sub.size = Vector2(1000, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(sub)
	# asılı parşömenler
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 26)
	flow.add_theme_constant_override("v_separation", 30)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	flow.offset_left = 50; flow.offset_right = -50; flow.offset_top = 110; flow.offset_bottom = -30
	board.add_child(flow)
	if list.is_empty():
		var l = LazyFx.g("UI").label("Şu an rütbene uygun görev yok. Daha sonra tekrar bak.", 20, LazyFx.g("UI").CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		flow.add_child(l)
	for i in list.size():
		var m: Dictionary = list[i]
		var sc = _hanging_scroll(m, func(): _unroll(m, village_id))
		flow.add_child(sc)
		if _fresh:
			sc.modulate.a = 0.0
			var tw = sc.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_interval(0.05 * i)
			tw.tween_property(sc, "modulate:a", 1.0, 0.2)
	# son haberler: almadığın ilanlara kim gitti, ne oldu
	var nw: Array = LazyFx.g("WorldNews").recent()
	if not nw.is_empty():
		var news = LazyFx.g("UI").label("Son haber:  " + String(nw[nw.size() - 1]), 13, Color(1, 0.86, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		news.set_anchors_preset(Control.PRESET_CENTER_TOP)
		news.position = Vector2(-560, 78)
		news.size = Vector2(1120, 20)
		news.clip_text = true
		board.add_child(news)
	_close_button(bg, func(): Hud.close_dialog())


## Panoya iğnelenmiş görev parşömeni
static func _hanging_scroll(m: Dictionary, cb: Callable) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(200, 300)
	var empty = StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, empty)
	var paper = ColorRect.new()
	var pm = ShaderMaterial.new()
	pm.shader = load("res://shaders/ui_parchment.gdshader")
	pm.set_shader_parameter("seed", float(hash(String(m.get("title", "")))) * 0.0001)
	paper.material = pm
	paper.position = Vector2(8, 14)
	paper.size = Vector2(184, 280)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(paper)
	# iğne
	var pin = Control.new()
	pin.position = Vector2(100, 14)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.draw.connect(func():
		pin.draw_circle(Vector2(2, 3), 8, Color(0, 0, 0, 0.35))
		pin.draw_circle(Vector2.ZERO, 8, Color(0.75, 0.12, 0.1))
		pin.draw_circle(Vector2(-2, -2), 3, Color(1, 0.6, 0.55)))
	b.add_child(pin)
	var stamp = _rank_stamp(String(m.get("rank", "D")), 58)
	stamp.position = Vector2(71, 34)
	b.add_child(stamp)
	var ink = Color(0.16, 0.1, 0.06)
	var t = LazyFx.g("UI").label(String(m.get("title", "")), 18, ink, HORIZONTAL_ALIGNMENT_CENTER, true)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.position = Vector2(20, 104)
	t.size = Vector2(160, 80)
	b.add_child(t)
	if m.get("dyn", false):
		# dünyada olmuş bir olay: süresi dolarsa başka takım gider
		var dl = LazyFx.g("UI").label("◆ olay  •  ~%d dk" % maxi(1, LazyFx.g("WorldNews").left_min(String(m.get("news", "")))), 12, Color(0.7, 0.12, 0.08), HORIZONTAL_ALIGNMENT_CENTER, true)
		dl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		dl.position = Vector2(20, 186)
		dl.size = Vector2(160, 16)
		b.add_child(dl)
	if m.get("local", false):
		var loc = LazyFx.g("UI").label("★ köye özgü", 12, Color(0.6, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER, true)
		loc.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		loc.position = Vector2(20, 186)
		loc.size = Vector2(160, 16)
		b.add_child(loc)
	var rw = _rewards(m)
	var r1 = LazyFx.g("UI").label("%d Ryō" % rw[0], 15, ink, HORIZONTAL_ALIGNMENT_CENTER, true)
	r1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	r1.position = Vector2(20, 222)
	r1.size = Vector2(160, 20)
	b.add_child(r1)
	var r2 = LazyFx.g("UI").label("✦ ekipman şansı" if rw[2] >= 0.5 else "", 13, Color(0.35, 0.25, 0.15), HORIZONTAL_ALIGNMENT_CENTER)   # XP kalktı (ustalık sistemi)
	r2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	r2.position = Vector2(20, 246)
	r2.size = Vector2(160, 18)
	b.add_child(r2)
	b.resized.connect(func(): b.pivot_offset = Vector2(100, 14))
	b.mouse_entered.connect(func():
		Sfx.play("click", null, 1.6, 0.2)
		var tw = b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "rotation", deg_to_rad(-2.5), 0.12))
	b.mouse_exited.connect(func():
		var tw = b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "rotation", 0.0, 0.15))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func _rewards(m: Dictionary) -> Array:
	if m.has("rewards") and m["rewards"] is Dictionary:
		var rw: Dictionary = m["rewards"]
		return [int(rw.get("ryo", 0)), int(rw.get("xp", 0)), float(rw.get("gear_chance", 0.0))]
	var r = String(m.get("rank", "D"))
	var base: Array = Missions.REWARD.get(r, [0, 0])
	return [int(base[0]), int(base[1]), float(Missions.GEAR_CHANCE.get(r, 0.0))]


## Parşömen açılır: brifing, hedefler, ödüller, hanko damgalı kabul
static func _unroll(m: Dictionary, village_id: String) -> void:
	var layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	Hud.dialog_layer.add_child(layer)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var holder = Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.size = Vector2(900, 620)
	holder.position = Vector2(-450, -310)
	layer.add_child(holder)
	# rulolar
	for y in [0.0, 600.0]:
		var rod = Panel.new()
		rod.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(0.32, 0.18, 0.1), Color(0.15, 0.08, 0.04), 2, 10, 0))
		rod.position = Vector2(-20, y)
		rod.size = Vector2(940, 22)
		holder.add_child(rod)
	var paper = ColorRect.new()
	var pm = ShaderMaterial.new()
	pm.shader = load("res://shaders/ui_parchment.gdshader")
	pm.set_shader_parameter("edge", 0.05)
	paper.material = pm
	paper.position = Vector2(0, 16)
	paper.size = Vector2(900, 588)
	holder.add_child(paper)
	paper.clip_contents = true
	var ink = Color(0.16, 0.1, 0.06)
	var mk = func(text: String, size: int, col: Color, bold := false) -> Label:
		var l = LazyFx.g("UI").label(text, size, col, HORIZONTAL_ALIGNMENT_LEFT, bold)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		return l
	var v = LazyFx.g("UI").vbox(10)
	v.position = Vector2(56, 34)
	v.custom_minimum_size = Vector2(620, 0)
	paper.add_child(v)
	v.add_child(mk.call("%s-RANK GÖREV%s" % [m.get("rank", "D"), "   •   KÖYE ÖZGÜ" if m.get("local", false) else ""], 14, Color(0.6, 0.15, 0.1), true))
	var tl = mk.call(String(m.get("title", "")), 30, ink, true)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(620, 0)
	v.add_child(tl)
	v.add_child(mk.call("Görevi veren: %s" % m.get("giver", "Görev masası"), 15, Color(0.35, 0.25, 0.15)))
	var br = mk.call(String(m.get("brief", m.get("desc", ""))), 17, ink)
	br.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	br.custom_minimum_size = Vector2(620, 0)
	v.add_child(br)
	v.add_child(mk.call("HEDEFLER", 14, Color(0.6, 0.15, 0.1), true))
	var steps: Array = m.get("steps", [])
	for i in steps.size():
		var row = LazyFx.g("UI").hbox(10)
		var num = PanelContainer.new()
		num.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(0.6, 0.15, 0.1, 0.9), Color(0, 0, 0, 0), 0, 12, 2))
		num.custom_minimum_size = Vector2(24, 24)
		num.add_child(LazyFx.g("UI").label(str(i + 1), 13, Color(1, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER, true))
		row.add_child(num)
		var sl = mk.call(String(steps[i].get("text", "")), 15, ink)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(560, 0)
		row.add_child(sl)
		v.add_child(row)
	# ödüller + damga (sağ sütun)
	var rw = _rewards(m)
	var rv = LazyFx.g("UI").vbox(12)
	rv.position = Vector2(700, 60)
	paper.add_child(rv)
	rv.add_child(_rank_stamp(String(m.get("rank", "D")), 110))
	rv.add_child(mk.call("ÖDÜL", 14, Color(0.6, 0.15, 0.1), true))
	var r1 = LazyFx.g("UI").hbox(8)
	r1.add_child(LazyFx.g("Icons").view("coin", 22, Color(0.6, 0.42, 0.1)))
	r1.add_child(mk.call("%d Ryō" % rw[0], 18, ink, true))
	rv.add_child(r1)
	# XP satırı kaldırıldı: seviye sistemi yok, gelişim yaptıkça (ustalık)
	if rw[2] > 0.0:
		var r3 = LazyFx.g("UI").hbox(8)
		r3.add_child(LazyFx.g("Icons").view("chest", 22, Color(0.6, 0.42, 0.1)))
		r3.add_child(mk.call("Ekipman %%%d" % int(rw[2] * 100), 15, ink))
		rv.add_child(r3)
	# hanko: kabul et
	var hanko = Button.new()
	hanko.text = "受\nKABUL ET"
	hanko.custom_minimum_size = Vector2(130, 130)
	hanko.add_theme_font_override("font", LazyFx.g("UI").font(true))
	hanko.add_theme_font_size_override("font_size", 17)
	var hn = LazyFx.g("UI")._box(Color(0.72, 0.1, 0.08, 0.92), Color(0.45, 0.04, 0.03), 4, 65, 6)
	var hh = hn.duplicate()
	hh.bg_color = Color(0.85, 0.15, 0.1, 0.97)
	hh.shadow_color = Color(0.9, 0.2, 0.1, 0.5)
	hh.shadow_size = 14
	for k in [["normal", hn], ["hover", hh], ["pressed", hh], ["focus", hh]]:
		hanko.add_theme_stylebox_override(k[0], k[1])
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		hanko.add_theme_color_override(k, Color(1, 0.95, 0.9))
	hanko.position = Vector2(724, 420)
	hanko.rotation = deg_to_rad(-8)
	hanko.pressed.connect(func():
		Sfx.play("seal", null, 0.9)
		Hud.close_dialog()
		Missions.accept(m))
	LazyFx.g("UI").hover_anim(hanko, 1.06)
	paper.add_child(hanko)
	var back = LazyFx.g("UI").ink_button("‹  Diğer görevler", func(): mission_board(village_id), 220)
	back.position = Vector2(56, 524)
	paper.add_child(back)
	# açılma animasyonu: kâğıt yukarıdan aşağıya iner
	paper.scale = Vector2(1, 0.04)
	var tw = paper.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(paper, "scale:y", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var rods = [holder.get_child(1)]
	for rd in rods:
		rd.position.y = 0
		var t2 = rd.create_tween()
		t2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t2.tween_property(rd, "position:y", 600.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", null, 1.4, 0.4)


# ================================================================== Bingo Kitabı (açık kitap)
static var _bb_index := 0


static func bingo_book(main: Node = null) -> void:
	if not Missions.has_method("bingo_entries"):
		return
	var entries: Array = Missions.bingo_entries()
	Game.ui_open = true
	Game.mouse(false)
	var bg = _full(0.6)
	_close_button(bg, func():
		if Game.paused and main and main.has_method("resume"):
			main.resume()
		else:
			Hud.close_dialog())
	var book = Control.new()
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.size = Vector2(1240, 720)
	book.position = Vector2(-620, -360)
	bg.add_child(book)
	if _fresh:
		LazyFx.g("UI").pop_in(book, 0.95)
	# kapak (koyu kırmızı deri)
	var cover = Panel.new()
	var csb = LazyFx.g("UI")._box(Color(0.32, 0.06, 0.06), Color(0.15, 0.02, 0.02), 3, 18, 0)
	csb.shadow_color = Color(0, 0, 0, 0.6)
	csb.shadow_size = 30
	cover.add_theme_stylebox_override("panel", csb)
	cover.size = book.size
	book.add_child(cover)
	var pages = []
	for i in 2:
		var pg = ColorRect.new()
		var pm = ShaderMaterial.new()
		pm.shader = load("res://shaders/ui_parchment.gdshader")
		pm.set_shader_parameter("edge", 0.06)
		pm.set_shader_parameter("seed", 3.0 + i)
		pm.set_shader_parameter("paper", Color(0.95, 0.9, 0.78))
		pg.material = pm
		pg.position = Vector2(24 + i * 600, 22)
		pg.size = Vector2(592, 676)
		book.add_child(pg)
		pages.append(pg)
	var spine = ColorRect.new()
	spine.color = Color(0, 0, 0, 0.25)
	spine.position = Vector2(612, 22)
	spine.size = Vector2(16, 676)
	book.add_child(spine)
	var ink = Color(0.16, 0.1, 0.06)
	var red = Color(0.62, 0.1, 0.08)
	var mk = func(text: String, size: int, col: Color, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
		var l = LazyFx.g("UI").label(text, size, col, align, bold)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		return l
	var lp: Control = pages[0]
	var rp: Control = pages[1]
	if entries.is_empty():
		var l = mk.call("Bingo Kitabı boş.", 24, ink, true, HORIZONTAL_ALIGNMENT_CENTER)
		l.position = Vector2(0, 300)
		l.size = Vector2(592, 40)
		lp.add_child(l)
		return
	_bb_index = clampi(_bb_index, 0, entries.size() - 1)
	var e: Dictionary = entries[_bb_index]
	var dead = e.get("status", "alive") != "alive"
	# sol sayfa: portre + isim + ödül
	var head = mk.call("ビンゴブック   •   BINGO KİTABI", 14, red, true, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 22)
	head.size = Vector2(592, 20)
	lp.add_child(head)
	var frame = Panel.new()
	frame.add_theme_stylebox_override("panel", LazyFx.g("UI")._box(Color(0.2, 0.17, 0.14), Color(0.3, 0.2, 0.12), 6, 6, 0))
	frame.position = Vector2(146, 60)
	frame.size = Vector2(300, 340)
	lp.add_child(frame)
	if e.has("look") and e["look"] is Dictionary:
		var blk: Dictionary = (e["look"] as Dictionary).duplicate()
		var bey := int(e.get("eye", 0))
		if bey <= 0 and String(e.get("clan", "")) != "":
			bey = int(ClanWorld.EYE_KIND.get(String(e.get("clan", "")), 0))
		if bey > 0:
			blk["dojutsu"] = bey   # portrede göz açık (Sharingan / Byakugan…)
		var pv = _model_preview(blk, Vector3(0, 1.48, -1.75), Vector3(0, 1.4, 0), 30.0, false, Vector2(288, 328))
		pv.position = Vector2(6, 6)
		frame.clip_contents = true
		frame.add_child(pv)
		var mdl = pv.get_meta("model")
		if mdl:
			mdl.rotation.y = 0.0
	if dead:
		var x = Control.new()
		x.size = Vector2(300, 340)
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x.draw.connect(func():
			x.draw_line(Vector2(20, 20), Vector2(280, 320), Color(red, 0.85), 10.0, true)
			x.draw_line(Vector2(280, 20), Vector2(20, 320), Color(red, 0.85), 10.0, true))
		frame.add_child(x)
	var nm = mk.call(String(e.get("name", "?")), 30, ink, true, HORIZONTAL_ALIGNMENT_CENTER)
	nm.position = Vector2(0, 414)
	nm.size = Vector2(592, 40)
	lp.add_child(nm)
	var al = mk.call("«%s»" % e.get("alias", ""), 18, Color(0.4, 0.28, 0.18), false, HORIZONTAL_ALIGNMENT_CENTER)
	al.position = Vector2(0, 456)
	al.size = Vector2(592, 24)
	lp.add_child(al)
	var stampw = mk.call(("BAĞIŞLANDI" if e.get("status", "") == "spared" else "YAKALANDI") if dead else "ARANIYOR", 40, Color(red, 0.85), true, HORIZONTAL_ALIGNMENT_CENTER)
	stampw.position = Vector2(150, 500)
	stampw.size = Vector2(292, 50)
	stampw.rotation = deg_to_rad(-6)
	lp.add_child(stampw)
	var bounty = mk.call("ÖDÜL: %d Ryō" % int(e.get("bounty", 0)), 26, ink, true, HORIZONTAL_ALIGNMENT_CENTER)
	bounty.position = Vector2(0, 570)
	bounty.size = Vector2(592, 34)
	lp.add_child(bounty)
	# sağ sayfa: ayrıntılar
	var v = LazyFx.g("UI").vbox(12)
	v.position = Vector2(50, 50)
	v.custom_minimum_size = Vector2(492, 0)
	rp.add_child(v)
	v.add_child(_rank_stamp(String(e.get("rank", "C")), 84))
	var info = [["Köy", "%s (kaçak)" % e.get("village_name", "?")], ["Tehlike", "%s-rank  •  %s" % [e.get("rank", "?"), _threat_word(int(e.get("level", 1)))]],
		["Element", String(e.get("element", "?")).capitalize()], ["Son görüldüğü yer", "%s (~%d m alan)" % [e.get("region", "?"), int(e.get("known", 0))]]]
	# neye karşı olduğunu bil: klan, göz (dōjutsu), kan soyu, taşıdığı canavar, özel silah — yalnız olanlar
	var bclan := String(e.get("clan", ""))
	if bclan != "":
		info.append(["Klan", ClanWorld.clan_name(bclan)])
	var beye := int(e.get("eye", 0))
	if beye <= 0 and bclan != "":
		beye = int(ClanWorld.EYE_KIND.get(bclan, 0))
	if beye > 0:
		info.append(["Göz", String({1: "Sharingan", 2: "Byakugan", 3: "Ketsuryūgan", 4: "Mangekyō Sharingan", 5: "Ebedî Mangekyō Sharingan", 6: "Rinnegan", 7: "Tenseigan", 8: "Jōgan"}.get(beye, "?"))])
	var bnat: Array = e.get("nat", [])
	if not bnat.is_empty():
		info.append(["Kan soyu", ", ".join(bnat.map(func(n): return String(LazyFx.g("Elements").NAMES.get(String(n), String(n).capitalize()))))])
	if e.has("beast"):
		info.append(["Jinchūriki", String(LazyFx.g("BeastModels").INFO.get(String(e["beast"]), {}).get("name", String(e["beast"]))).split(" — ")[0]])
	if e.has("mist_sword"):
		info.append(["Kılıç", LazyFx.g("Swordsmen").sword_name(String(e["mist_sword"]))])
	elif e.has("legend_weapon"):
		info.append(["Silah", String(LazyFx.g("Gear").item(String(e["legend_weapon"])).get("name", String(e["legend_weapon"]))).split(" (")[0]])
	for row in info:
		var r = LazyFx.g("UI").hbox(10)
		var k = mk.call(row[0], 15, Color(0.45, 0.32, 0.2), true)
		k.custom_minimum_size = Vector2(170, 0)
		r.add_child(k)
		var vl = mk.call(row[1], 16, ink)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.custom_minimum_size = Vector2(310, 0)
		r.add_child(vl)
		v.add_child(r)
	v.add_child(mk.call("SUÇLARI", 14, red, true))
	var cr = mk.call("• " + "\n• ".join(e.get("crimes", [])), 16, ink)
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cr.custom_minimum_size = Vector2(490, 0)
	v.add_child(cr)
	if String(e.get("rank", "")) in ["B", "A", "S"]:
		v.add_child(mk.call("Dikkat: yenilmek üzereyken kaçmaya çalışır.", 14, red))
	var id = int(e.get("id", 0))
	if not dead:
		var acts = LazyFx.g("UI").hbox(10)
		acts.position = Vector2(50, 560)
		rp.add_child(acts)
		var tracked = bool(e.get("tracked", false))
		acts.add_child(LazyFx.g("UI").primary("Takipte" if tracked else "Takip Et", func():
			Missions.track_bounty(id)
			bingo_book(main), 220, "target"))
		var cost = maxi(50, int(int(e.get("bounty", 0)) * 0.05))
		acts.add_child(LazyFx.g("UI").ink_button("Muhbire sor (%d Ryō)" % cost, func():
			Missions.ask_informant(id), 250))
	# sayfa çevirme
	var nav = LazyFx.g("UI").hbox(14)
	nav.position = Vector2(960, 640)
	book.add_child(nav)
	nav.add_child(LazyFx.g("UI").ink_button("◀", func():
		_bb_index = (_bb_index - 1 + entries.size()) % entries.size()
		bingo_book(main), 56))
	var pl = LazyFx.g("UI").label("%d / %d" % [_bb_index + 1, entries.size()], 18, Color(0.16, 0.1, 0.06), HORIZONTAL_ALIGNMENT_CENTER, true)
	pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pl.custom_minimum_size = Vector2(80, 42)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(pl)
	nav.add_child(LazyFx.g("UI").ink_button("▶", func():
		_bb_index = (_bb_index + 1) % entries.size()
		bingo_book(main), 56))


# ================================================================== dükkân (ızgara + ayrıntı)
static var _shop_sel := ""


## entries: [{id, name, price, desc, stats, locked, lock_text, owned, view: Callable->Control, rarity}], buy: Callable(id)
static func shop_screen(title: String, entries: Array, buy: Callable, sell := Callable()) -> void:
	Game.ui_open = true
	# aynı dükkân yeniden kurulurken (eşya seçince/alınca) liste en üste dönmesin
	var keep = _scroll_positions() if title == _last_shop else []
	_last_shop = title
	Game.mouse(false)
	var bg = _full(0.55)
	var head = LazyFx.g("UI").label(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(title)), 34, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	head.position = Vector2(110, 40)
	bg.add_child(head)
	var ryo = LazyFx.g("UI").icon_label("coin", "%d Ryō" % int(Game.profile.get("ryo", 0)), 20, LazyFx.g("UI").GOLD)
	ryo.anchor_left = 1.0; ryo.anchor_right = 1.0
	ryo.offset_left = -300; ryo.offset_top = 52
	bg.add_child(ryo)
	if sell.is_valid():   # tezgâha eşya sat (bu dükkânın aldığı mallar)
		var sb = LazyFx.g("UI").button("Eşya sat", sell, 200, "coin")
		sb.anchor_left = 1.0; sb.anchor_right = 1.0
		sb.offset_left = -540; sb.offset_right = -340; sb.offset_top = 40
		bg.add_child(sb)
	_close_button(bg, func(): Hud.close_dialog())
	var h = LazyFx.g("UI").hbox(28)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 110; h.offset_top = 110; h.offset_right = -60; h.offset_bottom = -60
	bg.add_child(h)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var ids = entries.map(func(x): return x["id"])
	if not keep.is_empty():
		Engine.get_main_loop().process_frame.connect(_restore_scroll.bind(keep), CONNECT_ONE_SHOT)
	if not _shop_sel in ids and not entries.is_empty():
		_shop_sel = entries[0]["id"]
	var sel = {}
	for e in entries:
		var acc: Color = LazyFx.g("UI").RARITY[int(e.get("rarity", 0))]
		var t = _tile(e["view"].call(), "%s — %d" % [e["name"], int(e["price"])], acc if not e.get("locked", false) else Color(1, 1, 1, 0.12), e["id"] == _shop_sel, func():
			_shop_sel = e["id"]
			shop_screen(title, entries, buy), 132, ("∞" if e.get("unlimited", false) else "x%d" % int(e["owned"])) if int(e.get("owned", 0)) > 0 else "")
		if e.get("locked", false):
			t.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(t)
		if e["id"] == _shop_sel:
			sel = e
	var right = LazyFx.g("UI").card()
	right.custom_minimum_size = Vector2(440, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(right)
	var rv = LazyFx.g("UI").vbox(12)
	right.add_child(rv)
	if sel.is_empty():
		rv.add_child(LazyFx.g("UI").label("Satılık bir şey yok.", 16, LazyFx.g("UI").MUTED))
		return
	if sel.has("try_on"):   # üstünde nasıl durduğunu dönerek gösterir
		var ph = clampf(bg.get_viewport_rect().size.y - 520.0, 210.0, 430.0)
		var pv = _model_preview(sel["try_on"].call(), Vector3(0, 1.02, -3.9), Vector3(0, 0.92, 0), 28.0, true, Vector2(400, ph))
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rv.add_child(pv)
	var top = LazyFx.g("UI").hbox(16)
	var big = sel["view"].call()
	big.custom_minimum_size = Vector2(110, 110) if not sel.has("try_on") else Vector2(64, 64)
	top.add_child(big)
	var tv = LazyFx.g("UI").vbox(4)
	var nm = LazyFx.g("UI").label(sel["name"], 22, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(280, 0)
	tv.add_child(nm)
	var r = int(sel.get("rarity", 0))
	tv.add_child(LazyFx.g("UI").label(LazyFx.g("UI").RARITY_NAMES[r], 13, LazyFx.g("UI").RARITY[r], HORIZONTAL_ALIGNMENT_LEFT, true))
	if String(sel.get("stats", "")) != "":
		var st = LazyFx.g("UI").label(sel["stats"], 14, LazyFx.g("UI").GOOD)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size = Vector2(280, 0)
		tv.add_child(st)
	top.add_child(tv)
	rv.add_child(top)
	var d = LazyFx.g("UI").label(String(sel.get("desc", "")), 15, LazyFx.g("UI").MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(400, 0)
	rv.add_child(d)
	if int(sel.get("owned", 0)) > 0:
		rv.add_child(LazyFx.g("UI").label("Sende: sınırsız" if sel.get("unlimited", false) else "Sende: %d" % int(sel["owned"]), 14, LazyFx.g("UI").MUTED))
	if sel.get("locked", false):
		rv.add_child(LazyFx.g("UI").icon_label("lock", String(sel.get("lock_text", "Kilitli")), 16, LazyFx.g("UI").BAD))
	else:
		var afford = int(Game.profile.get("ryo", 0)) >= int(sel["price"])
		var b = LazyFx.g("UI").primary("Satın al — %d Ryō" % int(sel["price"]), func():
			buy.call(sel["id"]), 400, "coin")
		b.disabled = not afford
		rv.add_child(b)
		if not afford:
			rv.add_child(LazyFx.g("UI").label("Yeterli Ryō yok.", 14, LazyFx.g("UI").BAD))


## Dükkâna satış: bu tezgâhın aldığı mallar (SHOP_SELL.entries); adet ◀ ▶ ile seçilir. back: alış ekranına dön
const SHOP_SELL := preload("res://scripts/core/shop_sell.gd")
static var _sell_sel := ""
static var _sell_qty := 1


static func sell_screen(title: String, buyer: String, back: Callable) -> void:
	Game.ui_open = true
	var keep = _scroll_positions() if title == _last_shop else []
	_last_shop = title
	Game.mouse(false)
	var pr = Game.profile
	var entries = SHOP_SELL.entries(pr, buyer)
	var bg = _full(0.55)
	var head = LazyFx.g("UI").label(LazyFx.g("Lang").upper(LazyFx.g("Lang").t(title)) + "  —  " + LazyFx.g("Lang").upper(LazyFx.g("Lang").t("Satış")), 34, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	head.position = Vector2(110, 40)
	bg.add_child(head)
	var ryo = LazyFx.g("UI").icon_label("coin", "%d Ryō" % int(pr.get("ryo", 0)), 20, LazyFx.g("UI").GOLD)
	ryo.anchor_left = 1.0; ryo.anchor_right = 1.0
	ryo.offset_left = -300; ryo.offset_top = 52
	bg.add_child(ryo)
	var bb = LazyFx.g("UI").button("Satın al", back, 200, "coin")
	bb.anchor_left = 1.0; bb.anchor_right = 1.0
	bb.offset_left = -540; bb.offset_right = -340; bb.offset_top = 40
	bg.add_child(bb)
	_close_button(bg, func(): Hud.close_dialog())
	var h = LazyFx.g("UI").hbox(28)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 110; h.offset_top = 110; h.offset_right = -60; h.offset_bottom = -60
	bg.add_child(h)
	var lv = LazyFx.g("UI").vbox(10)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lv)
	lv.add_child(LazyFx.g("UI").label(SHOP_SELL.buyer_text(buyer), 15, LazyFx.g("UI").MUTED))
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	if not keep.is_empty():
		Engine.get_main_loop().process_frame.connect(_restore_scroll.bind(keep), CONNECT_ONE_SHOT)
	var key = func(e): return "%s:%s" % [e["type"], e["id"]]
	if not _sell_sel in entries.map(key) and not entries.is_empty():
		_sell_sel = key.call(entries[0])
		_sell_qty = 1
	var sel = {}
	for e in entries:
		var k = key.call(e)
		var view = LazyFx.g("Thumbs").gear_view(e["id"], 96) if e["type"] == "gear" else LazyFx.g("Thumbs").item_view(e["id"], 96)
		var acc: Color = LazyFx.g("UI").RARITY[int(e.get("rarity", 0))]
		var badge = "∞" if e.get("unlimited", false) else ("x%d" % int(e["owned"]) if int(e["owned"]) > 1 else "")
		var t = _tile(view, "%s — %d" % [e["name"], int(e["price"])], acc if e["reason"] == "" else Color(1, 1, 1, 0.12), k == _sell_sel, func():
			if _sell_sel != k:
				_sell_qty = 1
			_sell_sel = k
			sell_screen(title, buyer, back), 132, badge)
		if e["reason"] != "":
			t.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(t)
		if k == _sell_sel:
			sel = e
	var right = LazyFx.g("UI").card()
	right.custom_minimum_size = Vector2(440, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(right)
	var rv = LazyFx.g("UI").vbox(12)
	right.add_child(rv)
	if sel.is_empty():
		rv.add_child(LazyFx.g("UI").label("Bu tezgâha satabileceğin bir şeyin yok.", 16, LazyFx.g("UI").MUTED))
		return
	var top = LazyFx.g("UI").hbox(16)
	var big = LazyFx.g("Thumbs").gear_view(sel["id"], 110) if sel["type"] == "gear" else LazyFx.g("Thumbs").item_view(sel["id"], 110)
	big.custom_minimum_size = Vector2(110, 110)
	top.add_child(big)
	var tv = LazyFx.g("UI").vbox(4)
	var nm = LazyFx.g("UI").label(sel["name"], 22, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(280, 0)
	tv.add_child(nm)
	var r = int(sel.get("rarity", 0))
	tv.add_child(LazyFx.g("UI").label(LazyFx.g("UI").RARITY_NAMES[r], 13, LazyFx.g("UI").RARITY[r], HORIZONTAL_ALIGNMENT_LEFT, true))
	tv.add_child(LazyFx.g("UI").label("Sende: sınırsız" if sel.get("unlimited", false) else "Sende: %d" % int(sel["owned"]), 14, LazyFx.g("UI").MUTED))
	if int(sel.get("equipped", 0)) > 0:
		tv.add_child(LazyFx.g("UI").label("Üstünde: %d" % int(sel["equipped"]), 14, LazyFx.g("UI").MUTED))
	top.add_child(tv)
	rv.add_child(top)
	var d = LazyFx.g("UI").label(String(sel.get("desc", "")), 15, LazyFx.g("UI").MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(400, 0)
	rv.add_child(d)
	if sel["reason"] != "":
		var why = LazyFx.g("UI").icon_label("lock", String(sel["reason"]), 16, LazyFx.g("UI").BAD)
		rv.add_child(why)
		return
	var n = int(sel["count"])
	_sell_qty = clampi(_sell_qty, 1, n)
	rv.add_child(LazyFx.g("UI").label("Tanesi: %d Ryō" % int(sel["price"]), 15, LazyFx.g("UI").GOLD))
	var b = LazyFx.g("UI").primary("Sat — %d Ryō" % (int(sel["price"]) * _sell_qty), func(): pass, 400, "coin")
	if n > 1:   # adet: ◀ ▶ seçici
		var labels = []
		for i in n:
			labels.append(str(i + 1))
		rv.add_child(_arrow_row("Adet", labels, _sell_qty - 1, func(i: int):
			_sell_qty = i + 1
			if is_instance_valid(b):
				b.text = LazyFx.g("Lang").t("Sat — %d Ryō") % (int(sel["price"]) * _sell_qty)))
	b.pressed.connect(func():
		var cnt = _sell_qty
		var gain = SHOP_SELL.sell(Game.profile, sel, cnt)
		if gain > 0:
			Sfx.play("coin")
			Hud.float_text("+%d Ryō" % gain, Color(1, 0.85, 0.4))
			Hud.msg(LazyFx.g("Lang").t("%s x%d satıldı: +%d Ryō") % [LazyFx.g("Lang").t(String(sel["name"])), cnt, gain], Color(0.6, 1, 0.6))
		_sell_qty = 1
		sell_screen(title, buyer, back))
	rv.add_child(b)


# ================================================================== dünya haritası + hızlı seyahat
## Bölgesel harita: oyuncunun çevresi (1.6 km) yakın plan; yollar, nehirler, binalar ve dükkân / önemli yer ikonları.
## Sağ panelden yere tıklayınca ok oraya yönlendirir. [Dünya Haritası] düğmesiyle dünya haritasına geçilir.
## Haritaya oyuncunun kendi işaretçisi: sol tık (telefonda dokunuş) koyar, sağ tık kaldırır; ok oraya yol gösterir.
## to_world: harita pikseli -> dünya konumu, to_px: dünya konumu -> harita pikseli
static func _map_marker(tr: Control, to_world: Callable, to_px: Callable) -> void:
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	var mk = Control.new()
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(mk)
	mk.draw.connect(func():
		mk.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-9, -18), Vector2(9, -18)]), Color(0.95, 0.3, 0.25))
		mk.draw_circle(Vector2(0, -22), 10.0, Color(0.95, 0.3, 0.25))
		mk.draw_circle(Vector2(0, -22), 4.0, Color.WHITE)
		mk.draw_arc(Vector2(0, -22), 10.0, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0, true))
	var place = func():
		var wp = Game.profile.get("waypoint")
		mk.visible = wp is Array and wp.size() >= 4 and String(wp[3]) == "İşaret"
		if mk.visible:
			mk.position = to_px.call(Vector3(float(wp[0]), float(wp[1]), float(wp[2])))
		mk.queue_redraw()
	place.call()
	tr.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventMouseButton and e.pressed):
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			var w: Vector3 = to_world.call(e.position)
			w.y = Game.ground_height(w.x, w.z)
			Game.profile["waypoint"] = [w.x, w.y, w.z, "İşaret"]
			Game.profile["track"] = "waypoint"
			Hud.msg(LazyFx.g("Lang").t("İşaret kondu (%d m) — sağ tık: kaldır") % int(w.distance_to(Game.player.global_position)) if Game.player else "", Color(1, 0.85, 0.4))
			Sfx.play("click")
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			var wp = Game.profile.get("waypoint")
			if wp is Array and wp.size() >= 4 and String(wp[3]) == "İşaret":
				Game.profile.erase("waypoint")
				if String(Game.profile.get("track", "")) == "waypoint":
					Game.profile["track"] = ""
				Hud.msg("İşaret kaldırıldı", Color(0.85, 0.85, 0.9))
		place.call())
	var hint = LazyFx.g("UI").label("Sol tık: işaret koy  •  Sağ tık: kaldır", 13, LazyFx.g("UI").CREAM)
	hint.position = Vector2(14, 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(hint)


static func region_map(main: Node) -> void:
	if Game.has_meta("kamui_space"):
		kamui_map(main)
		return
	var rm = Game.world.get("road_map") if Game.world else null
	if rm == null or rm.local_map == null or rm.local_rect.z <= 0.0 or Game.player == null:
		world_map(main)
		return
	var bg = _full(0.7)
	var vp = bg.get_viewport_rect().size
	var side_w = 330.0
	var r: Vector4 = rm.local_rect
	vp = vp / maxf(0.01, float(Game.settings.get("ui_scale", 1.0))) if bg.get_viewport_rect().size.x > 3000.0 else vp
	var sz = Vector2.ONE * minf(vp.x - side_w - 180, vp.y - 140)
	var ox = maxf(40.0, (vp.x - (sz.x + 40.0 + side_w)) * 0.5)   # harita + yer listesi ortada yan yana (liste sağ köşeye yapışıyordu)
	var frame = Panel.new()
	frame.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(16, 0, 0.6))
	frame.position = Vector2(ox, (vp.y - sz.y) * 0.5 + 10) - Vector2(10, 10)
	frame.size = sz + Vector2(20, 20)
	bg.add_child(frame)
	var tr = TextureRect.new()
	tr.texture = rm.local_map
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	tr.position = Vector2(ox, (vp.y - sz.y) * 0.5 + 10)
	tr.clip_contents = true
	bg.add_child(tr)
	var pm = Game.to_map(Game.player.global_position)
	var region = ""
	for v in Game.world_info["villages"]:
		if pm.distance_to(Vector2(v["x"], v["y"])) < float(v["r"]) * 1.3:
			region = String(v["name"])
	var title = LazyFx.g("UI").label("BÖLGE HARİTASI" + ("  —  " + region.to_upper() if region != "" else ""), 30, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.position = Vector2(tr.position.x, tr.position.y - 50)
	bg.add_child(title)
	var to_px = func(wp: Vector3) -> Vector2:
		return Vector2((wp.x - r.x) / r.z, (wp.z - r.y) / r.z) * sz
	var lms = Interact.landmarks(Game.player.global_position, r.z * 0.7)
	for lm in lms:
		var q: Vector2 = to_px.call(lm["pos"])
		if q.x < 0 or q.y < 0 or q.x > sz.x or q.y > sz.y:
			continue
		var dot = Control.new()
		dot.position = q
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = lm["col"]
		var gl: String = lm["glyph"]
		dot.draw.connect(func():
			dot.draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.6))
			dot.draw_circle(Vector2.ZERO, 9, col.darkened(0.45))
			dot.draw_string(ThemeDB.fallback_font, Vector2(-5, 5), gl, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE))
		tr.add_child(dot)
	var me = Control.new()
	me.position = to_px.call(Game.player.global_position)
	me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var yaw = deg_to_rad(Game.player.yaw)
	me.draw.connect(func():
		var f = Vector2(sin(yaw), -cos(yaw)) * -1.0
		var s = Vector2(-f.y, f.x)
		me.draw_colored_polygon(PackedVector2Array([f * 14.0, -f * 7.0 + s * 8.0, -f * 4.0, -f * 7.0 - s * 8.0]), Color(0.25, 0.6, 1.0))
		me.draw_polyline(PackedVector2Array([f * 14.0, -f * 7.0 + s * 8.0, -f * 4.0, -f * 7.0 - s * 8.0, f * 14.0]), Color.WHITE, 2.0, true))
	tr.add_child(me)
	if Missions.has_marker:
		var mq: Vector2 = to_px.call(Missions.target_marker)
		if mq.x >= 0 and mq.y >= 0 and mq.x <= sz.x and mq.y <= sz.y:
			var mk = LazyFx.g("Icons").view("target", 30, LazyFx.g("UI").GOLD)
			mk.position = mq - Vector2(15, 15)
			tr.add_child(mk)
	_map_marker(tr, func(px: Vector2) -> Vector3: return Vector3(r.x + px.x / sz.x * r.z, 0.0, r.y + px.y / sz.y * r.z), to_px)
	var scl = LazyFx.g("UI").label("%d m" % int(r.z * 0.25), 13, LazyFx.g("UI").CREAM)
	scl.position = Vector2(14, sz.y - 30)
	tr.add_child(scl)
	var bar = ColorRect.new()
	bar.color = LazyFx.g("UI").CREAM
	bar.position = Vector2(14, sz.y - 10)
	bar.size = Vector2(sz.x * 0.25, 3)
	tr.add_child(bar)
	# yan panel: yerler listesi (tıkla -> yol göster) + dünya haritası
	var side = PanelContainer.new()
	side.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(16, 20, 0.8))
	side.position = Vector2(ox + sz.x + 40.0, (vp.y - sz.y) * 0.5 + 10)
	side.size = Vector2(side_w, sz.y)
	side.custom_minimum_size = Vector2(side_w, 0)
	bg.add_child(side)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var sv = LazyFx.g("UI").vbox(8)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sv)
	sv.add_child(LazyFx.g("UI").button("Dünya Haritası  ▶", func():
		bg.queue_free()
		world_map(main), side_w - 40, "map"))
	sv.add_child(LazyFx.g("UI").header("BU BÖLGEDE", 18))
	lms.sort_custom(func(a, b): return a["pos"].distance_to(Game.player.global_position) < b["pos"].distance_to(Game.player.global_position))
	for lm in lms.slice(0, 18):
		var lp: Vector3 = lm["pos"]
		var nm: String = lm["name"]
		var b = LazyFx.g("UI").button("%s  %s  (%d m)" % [lm["glyph"], nm, int(lp.distance_to(Game.player.global_position))], func():
			Game.profile["waypoint"] = [lp.x, lp.y, lp.z, nm]
			Game.profile["track"] = "waypoint"
			Hud.msg("Yol gösteriliyor: %s" % nm, Color(1, 0.85, 0.4))
			main.resume(), side_w - 40)
		b.add_theme_color_override("font_color", lm["col"])
		sv.add_child(b)
	_close_button(bg, func(): main.resume())


## Kamui Kūkan'dayken harita: dünya yerine boyutun kendi kütle haritası (Hud.draw_kamui_map), tutsaklar ve çıkış girdabı
static func kamui_map(main: Node) -> void:
	var bg = _full(0.7)
	var vp = bg.get_viewport_rect().size
	var D = minf(vp.x - 120.0, vp.y - 160.0)
	var cv = Control.new()
	cv.position = Vector2((vp.x - D) * 0.5, (vp.y - D) * 0.5 + 20.0)
	cv.size = Vector2(D, D)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.draw.connect(func():
		if Game.player:
			Hud.draw_kamui_map(cv, Game.player, Vector2(D, D) * 0.5, D * 0.5, 360.0))
	bg.add_child(cv)
	var title = LazyFx.g("UI").label("KAMUI KŪKAN", 30, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.position = Vector2(0, cv.position.y - 52)
	title.size = Vector2(vp.x, 40)
	bg.add_child(title)
	var hint = LazyFx.g("UI").label("Kırmızı: tutsaklar   ·   Mor girdap: çıkış", 16, Color(LazyFx.g("UI").TEXT, 0.75), HORIZONTAL_ALIGNMENT_CENTER, true)
	hint.position = Vector2(0, cv.position.y + D + 8)
	hint.size = Vector2(vp.x, 28)
	bg.add_child(hint)
	_close_button(bg, func(): main.resume())


static func world_map(main: Node) -> void:
	if Game.has_meta("kamui_space"):
		kamui_map(main)
		return
	var bg = _full(0.7)
	var tex: Texture2D = Game.world_map_tex()
	var vp = bg.get_viewport_rect().size
	var side_w = 330.0
	var scale = minf((vp.x - side_w - 180) / tex.get_width(), (vp.y - 140) / tex.get_height())
	var sz = Vector2(tex.get_width(), tex.get_height()) * scale
	var ox = maxf(40.0, (vp.x - (sz.x + 40.0 + side_w)) * 0.5)   # harita + yer listesi ortada yan yana (liste sağ köşeye yapışıyordu)
	var frame = Panel.new()
	frame.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(16, 0, 0.6))
	frame.position = Vector2(ox, (vp.y - sz.y) * 0.5 + 10) - Vector2(10, 10)
	frame.size = sz + Vector2(20, 20)
	bg.add_child(frame)
	var tr = TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	tr.position = Vector2(ox, (vp.y - sz.y) * 0.5 + 10)
	bg.add_child(tr)
	var title = LazyFx.g("UI").label("SHINOBİ DÜNYASI", 30, LazyFx.g("UI").TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.position = Vector2(tr.position.x, tr.position.y - 50)
	bg.add_child(title)
	var W = Game.hw * Game.res
	var H = Game.hh * Game.res
	var to_px = func(mx: float, my: float) -> Vector2:
		return Vector2((mx - Game.x0) / W * sz.x, (Game.y1 - my) / H * sz.y)
	for c in Game.world_info["countries"]:
		var l = LazyFx.g("UI").label(String(c["name"]).to_upper(), 13, Color(0.22, 0.16, 0.1, 0.8), HORIZONTAL_ALIGNMENT_LEFT, true)
		l.add_theme_color_override("font_shadow_color", Color(1, 0.97, 0.9, 0.5))
		l.position = to_px.call(c["x"], c["y"]) + Vector2(-50, 24)
		tr.add_child(l)
	for v in Game.world_info["villages"]:
		var visited: bool = v["id"] in Game.profile.get("visited", [])
		var dot = Control.new()
		dot.position = to_px.call(v["x"], v["y"])
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.draw.connect(func():
			dot.draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.5))
			dot.draw_circle(Vector2.ZERO, 5, Color(0.85, 0.15, 0.1) if visited else Color(0.4, 0.35, 0.3)))
		tr.add_child(dot)
		var l = LazyFx.g("UI").label(v["name"], 13, Color(0.15, 0.08, 0.05) if visited else Color(0.35, 0.3, 0.25), HORIZONTAL_ALIGNMENT_LEFT, true)
		l.add_theme_color_override("font_shadow_color", Color(1, 0.97, 0.9, 0.6))
		l.position = to_px.call(v["x"], v["y"]) + Vector2(9, -10)
		tr.add_child(l)
	for l in Game.world_info["landmarks"]:
		var lb = LazyFx.g("UI").label("· " + l["name"], 11, Color(0.3, 0.25, 0.4))
		lb.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.3))
		lb.position = to_px.call(l["x"], l["y"]) - Vector2(4, 8)
		tr.add_child(lb)
	if Game.player:
		var pm = Game.to_map(Game.player.global_position)
		var me = Control.new()
		me.position = to_px.call(pm.x, pm.y)
		me.mouse_filter = Control.MOUSE_FILTER_IGNORE
		me.draw.connect(func():
			me.draw_circle(Vector2.ZERO, 11, Color(0.2, 0.55, 1.0, 0.35))
			me.draw_circle(Vector2.ZERO, 6, Color(0.25, 0.6, 1.0))
			me.draw_arc(Vector2.ZERO, 6, 0, TAU, 20, Color.WHITE, 2.0, true))
		tr.add_child(me)
	var rb = LazyFx.g("UI").button("◀  Bölge Haritası", func():
		bg.queue_free()
		region_map(main), 240, "map")
	rb.position = Vector2(tr.position.x + sz.x - 240, tr.position.y - 56)
	bg.add_child(rb)
	if Missions.has_marker:
		var mm = Game.to_map(Missions.target_marker)
		var mk = LazyFx.g("Icons").view("target", 30, LazyFx.g("UI").GOLD)
		mk.position = to_px.call(mm.x, mm.y) - Vector2(15, 15)
		tr.add_child(mk)
	_map_marker(tr, func(px: Vector2) -> Vector3: return Game.from_map(Vector2(Game.x0 + px.x / sz.x * W, Game.y1 - px.y / sz.y * H)),
		func(wp: Vector3) -> Vector2:
			var m2 = Game.to_map(wp)
			return to_px.call(m2.x, m2.y))
	# yan panel: hızlı seyahat
	var side = PanelContainer.new()
	side.add_theme_stylebox_override("panel", LazyFx.g("UI").glass(16, 20, 0.8))
	side.position = Vector2(ox + sz.x + 40.0, (vp.y - sz.y) * 0.5 + 10)
	side.size = Vector2(side_w, sz.y)
	side.custom_minimum_size = Vector2(side_w, 0)
	bg.add_child(side)
	# liste uzun olunca tekerlekle aşağı kaydırılabilsin
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var sv = LazyFx.g("UI").vbox(8)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sv)
	sv.add_child(LazyFx.g("UI").header("HIZLI SEYAHAT", 18))
	sv.add_child(LazyFx.g("UI").label("Keşfettiğin köylere, haritadaki bölgelere ve yerlere ışınlan.", 13, LazyFx.g("UI").MUTED))
	for v in Game.world_info["villages"]:
		var visited: bool = v["id"] in Game.profile.get("visited", [])
		if not visited:
			continue
		var vid: String = v["id"]
		if Orgs.is_rogue() and vid in Orgs.ROGUE_BANNED:
			continue   # kaçak gizli köylere ışınlanamaz
		sv.add_child(LazyFx.g("UI").button(v["name"], func(): main.fast_travel(vid), side_w - 40, "village"))
	# köylerinde yaşayan jinchūriki'ler: kim nerede (gidip bulmak için)
	if not TailedBeasts.host_list().is_empty():
		sv.add_child(LazyFx.g("UI").header("JİNCHŪRİKİ", 16))
		for row in TailedBeasts.host_list():
			var hv = String(row[3]); var hn = String(row[0])
			sv.add_child(LazyFx.g("UI").button("%s — %s (%s)" % [hn, row[1], row[2]], func():
				var at = Exams.find_point(["training"], hv)
				Game.profile["waypoint"] = [at.x, at.y, at.z, "%s (%s)" % [hn, row[2]]]
				Game.profile["track"] = "waypoint"
				Hud.msg("Yol gösteriliyor: %s, %s antrenman alanında." % [hn, row[2]], Color(1, 0.8, 0.5))
				main.resume(), side_w - 40, "person"))
	# haritadaki her bölge ve önemli yer (aşırı hızlı koşmaya gerek kalmasın)
	sv.add_child(LazyFx.g("UI").header("BÖLGELER", 16))
	for c in Game.world_info.get("countries", []):
		var cx = float(c["x"]); var cy = float(c["y"]); var cn = String(c["name"])
		sv.add_child(LazyFx.g("UI").button(cn, func(): main.travel_to_map(cx, cy, cn), side_w - 40, "map"))
	sv.add_child(LazyFx.g("UI").header("YERLER", 16))
	for l in Game.world_info.get("landmarks", []):
		var lx = float(l["x"]); var ly = float(l["y"]); var ln = String(l["name"])
		sv.add_child(LazyFx.g("UI").button(ln, func(): main.travel_to_map(lx, ly, ln), side_w - 40, "map"))
	if Orgs.is_rogue():
		sv.add_child(LazyFx.g("UI").button("Kaçak Sığınağı", func():
			main.resume()
			Game.player.respawn(Missions.open_ground(Orgs.hideout_spawn(), 6.0)), side_w - 40, "village"))
	# yakındaki önemli yerler: tıkla -> ok ve ışık sütunu oraya yönlendirir
	if Game.player:
		var near = Interact.landmarks(Game.player.global_position, 2500.0)
		near.sort_custom(func(a, b): return a["pos"].distance_to(Game.player.global_position) < b["pos"].distance_to(Game.player.global_position))
		if not near.is_empty():
			sv.add_child(LazyFx.g("UI").spacer(0, 8, false))
			sv.add_child(LazyFx.g("UI").header("YAKINDAKİ YERLER", 18))
			sv.add_child(LazyFx.g("UI").label("Tıkla: ok seni oraya götürsün.", 13, LazyFx.g("UI").MUTED))
			var seen = {}
			for lm in near:
				if seen.has(lm["name"]) or seen.size() >= 12:
					continue
				seen[lm["name"]] = true
				var d = int(lm["pos"].distance_to(Game.player.global_position))
				var lp: Vector3 = lm["pos"]
				var nm: String = lm["name"]
				var b = LazyFx.g("UI").button("%s  %s  (%d m)" % [lm["glyph"], nm, d], func():
					Game.profile["waypoint"] = [lp.x, lp.y, lp.z, nm]
					Game.profile["track"] = "waypoint"
					Hud.msg("Yol gösteriliyor: %s" % nm, Color(1, 0.85, 0.4))
					main.resume(), side_w - 40)
				b.add_theme_color_override("font_color", lm["col"])
				sv.add_child(b)
	sv.add_child(LazyFx.g("UI").spacer(0, 10, false))
	sv.add_child(LazyFx.g("UI").icon_label("person", "Sen", 14, Color(0.4, 0.7, 1.0)))
	sv.add_child(LazyFx.g("UI").icon_label("target", "Görev hedefi", 14, LazyFx.g("UI").GOLD))
	_close_button(bg, func(): main.resume())


## Seviye sayısı göstermeden düşmanın oyuncuya göre tehlikesi (güç değeri iç hesap)
static func _threat_word(lv: int) -> String:
	var me = maxf(1.0, float(Game.profile.get("level", 1)))
	var r = float(lv) / me
	if r < 0.7:
		return "Senden zayıf"
	if r < 1.2:
		return "Dengin"
	if r < 2.0:
		return "Senden güçlü"
	if r < 3.5:
		return "Çok tehlikeli"
	return "Ölümcül — kaç"

