extends Node
## Arena deneme sürümü (ShinobiYolu_ARENA.exe): menüsüz açılır, bire bir dövüş arenası. Yeni dövüş kuralları (Combat.storm) yalnız
## burada açık; arenada olgunlaşınca ana oyuna alınacak. Rakip dünyadaki gerçek kişilerden seçilir.
## F1: arena ayarları (rakip, güç, davranış)  •  F2: raundu yeniden başlat
var main: Node
var pl: Player
var foe: Enemy
var center := Vector3.ZERO
const R := 54.0   # stadyum sahasının içi (duvar 58 m'de; bu yalnız emniyet sınırı)
var kind_i := 1          # 0 hepsi, 1 klansız, 2 klanlı
var foe_i := 0
var foe_lv := 60
var my_lv := 60
var passive := false
var duel_cam := true     # düello kamerası: rakip hep görüşte, aralık açıldıkça uzaklaşır
var intro_t := -1.0      # raunt açılışı sayacı (>= 0: dövüşçüler bekler)
const INTRO := 2.3
var _cmb := {"me": [0, 0.0, 0.0, 1.0], "foe": [0, 0.0, 0.0, 1.0]}   # [vuruş, kalan süre, toplam hasar oranı, son can oranı]
var cands: Array = []
var over := false
var wins := 0
var losses := 0
var menu_open := false
var row := 0
var ready_ok := false
# arayüz
var layer: CanvasLayer
var duel: DuelHud
var panel: PanelContainer
var rows: Array = []
const KINDS := ["Hepsi", "Klansız", "Klanlı"]


func _ready() -> void:
	Game.set_meta("arena", self)
	Combat.storm = true
	await get_tree().process_frame
	main.creator_state = {"slot": 9, "name": "Arena", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken",
		"hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "bottom": Color(0.15, 0.2, 0.4), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	await get_tree().create_timer(2.5).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	pl = Game.player
	_unlock(Game.profile)
	_set_my_power()
	# oyunun gerçek sınav stadyumu (Konoha): düz saha, çevresinde duvar ve tribün
	center = ChuninExam.stadium_pos("konoha")
	center.y = Game.ground_height(center.x, center.z)
	_place(pl, center + Vector3(0, 0, 6.0))
	_build_ui()
	_refresh_cands()
	await get_tree().create_timer(0.6).timeout
	_new_round()
	ready_ok = true


## Bütün jutsular, doğalar, ekipman ve eşyalar hazır (bedel ve bekleme süreleri gerçek — dövüş dengesi denenebilsin)
func _unlock(pr: Dictionary) -> void:
	pr["rank"] = 5
	pr["ryo"] = 9999999
	pr["elements"] = ["katon", "suiton", "fuuton", "doton", "raiton"]
	var nat = []
	for jid in Data.jutsu:
		var j = Data.jutsu[jid]
		if j is Dictionary:
			for el in j.get("elements", []):
				if not el in pr["elements"] and not el in nat:
					nat.append(el)
	pr["natures"] = nat
	for jid in Data.jutsu:
		var j = Data.jutsu[jid]
		if not j is Dictionary or String(jid).begins_with("_") or j.has("virtual"):
			continue
		if not jid in pr["learned"]:
			pr["learned"].append(jid)
	var have = {}
	for g in pr["gear"]:
		have[String(g["id"])] = true
	for gid in (Gear.ITEMS.keys().filter(func(k): return not Gear.ITEMS[k].get("removed", false))) + Gear.SETS.keys() + Gear.STRIKER.SETS.keys():
		if not have.has(gid):
			Gear.grant(pr, gid, "", null, null, {"lvl": 3, "origin": "dogustan"})
	for iid in Data.items:
		pr["inventory"][iid] = 1 if Stats.unlimited(iid) else maxi(int(pr["inventory"].get(iid, 0)), 20)
	Progress.clan_unlocks(false)
	SpecialSlots.refresh(pr)


func _set_my_power() -> void:
	var avg = 100.0 * pow(float(my_lv) / 100.0, 1.0 / 0.7)
	if not Game.profile.has("mastery"):
		Game.profile["mastery"] = {}
	for k in Mastery.KEYS:
		Game.profile["mastery"][k] = avg
	Mastery.refresh_level(Game.profile)
	pl.max_hp = Stats.max_hp(Game.profile)
	pl.max_chakra = Stats.max_chakra(Game.profile)
	pl.hp = pl.max_hp
	pl.chakra = pl.max_chakra


func _place(f: Node3D, at: Vector3) -> void:
	at.y = Game.ground_height(at.x, at.z) + 0.3
	f.global_position = at
	f.velocity = Vector3.ZERO
	f.reset_physics_interpolation()


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var uroot = Control.new()
	uroot.set_anchors_preset(Control.PRESET_FULL_RECT)
	uroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uroot.theme = UI.theme()
	layer.add_child(uroot)
	duel = DuelHud.new()
	duel.set_anchors_preset(Control.PRESET_FULL_RECT)
	duel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uroot.add_child(duel)
	# ayar paneli
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.offset_left = -380
	panel.offset_top = -200
	panel.visible = false
	var sbx = StyleBoxFlat.new()
	sbx.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	sbx.border_color = Color(1, 0.8, 0.3)
	sbx.set_border_width_all(2)
	sbx.set_corner_radius_all(10)
	sbx.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sbx)
	uroot.add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var ttl = Label.new()
	ttl.text = "ARENA AYARLARI"
	ttl.add_theme_font_size_override("font_size", 30)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ttl)
	for i in 6:
		var l = Label.new()
		l.add_theme_font_size_override("font_size", 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		rows.append(l)
	var hint = Label.new()
	hint.text = "↑ ↓ satır  •  ← → değiştir  •  Enter: raundu başlat  •  F1: kapat"
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(hint)


func _refresh_cands() -> void:
	cands = WorldPeople.all().values().filter(func(q):
		if not WorldPeople.alive(q) or int(q["rank"]) < 1:
			return false
		var cl = String(q.get("clan", ""))
		return kind_i == 0 or (kind_i == 1 and cl == "") or (kind_i == 2 and cl != ""))
	cands.sort_custom(func(x, y): return String(x["name"]) < String(y["name"]))
	foe_i = clampi(foe_i, 0, maxi(0, cands.size() - 1))


func _foe_label() -> String:
	if cands.is_empty():
		return "—"
	var q: Dictionary = cands[foe_i]
	var cl = String(q.get("clan", ""))
	return "%s (%s, %s)" % [String(q["name"]), cl.capitalize() if cl != "" else "klansız", String((q["els"] as Array)[0])]


func _menu_text() -> void:
	var vals = ["Rakip türü:  ◀  %s  ▶" % KINDS[kind_i], "Rakip:  ◀  %s  ▶   (%d / %d)" % [_foe_label(), foe_i + 1, cands.size()],
		"Rakibin gücü:  ◀  %d  ▶" % foe_lv, "Senin gücün:  ◀  %d  ▶" % my_lv, "Rakip:  ◀  %s  ▶" % ("Durur (kukla)" if passive else "Dövüşür"),
		"Kamera:  ◀  %s  ▶" % ("Düello (rakibi izler)" if duel_cam else "Serbest (fare)")]
	for i in rows.size():
		rows[i].text = vals[i]
		rows[i].modulate = Color(1, 0.85, 0.3) if i == row else Color(1, 1, 1)


func _input(e: InputEvent) -> void:
	if not ready_ok or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_F1:
		menu_open = not menu_open
		panel.visible = menu_open
		Game.ui_open = menu_open
		_menu_text()
		get_viewport().set_input_as_handled()
		return
	if e.keycode == KEY_F2 and not menu_open:
		_new_round()
		return
	if not menu_open:
		return
	get_viewport().set_input_as_handled()
	match e.keycode:
		KEY_UP:
			row = (row + rows.size() - 1) % rows.size()
		KEY_DOWN:
			row = (row + 1) % rows.size()
		KEY_LEFT, KEY_RIGHT:
			var s = 1 if e.keycode == KEY_RIGHT else -1
			match row:
				0:
					kind_i = (kind_i + s + KINDS.size()) % KINDS.size()
					foe_i = 0
					_refresh_cands()
				1:
					if not cands.is_empty():
						foe_i = (foe_i + s + cands.size()) % cands.size()
				2:
					foe_lv = clampi(foe_lv + s * 10, 10, 200)
				3:
					my_lv = clampi(my_lv + s * 10, 10, 200)
				4:
					passive = not passive
				5:
					duel_cam = not duel_cam
		KEY_ENTER, KEY_KP_ENTER:
			menu_open = false
			panel.visible = false
			Game.ui_open = false
			_set_my_power()
			_new_round()
			return
	_menu_text()


func _new_round() -> void:
	over = false
	if is_instance_valid(foe):
		foe.queue_free()
	foe = null
	pl.hp = pl.max_hp
	pl.chakra = pl.max_chakra
	pl.statuses.clear()
	pl.combat.cooldowns.clear()
	pl.combat.sub_bars = 4.0
	pl.combat.action = ""
	pl.combat.invuln = 0.0
	_place(pl, center + Vector3(0, 0, 4.5))
	pl.facing = 0.0
	_ko_ms = 0
	Combat.base_time_scale = 1.0
	if Game.world and Game.world.get("env"):   # dövüş denemesi hava etkisiz olsun (yağmur ateşi zayıflatıyor)
		Game.world.env.weather = "açık"
		Game.world.env.region_weather = "açık"
	if cands.is_empty():
		return
	var wp: Dictionary = (cands[foe_i] as Dictionary).duplicate(true)   # kopya: dünyadaki gerçek kişi değişmez / ölmez
	wp["level"] = foe_lv
	WorldPeople._learn(wp)
	var a = WorldPeople.arch_of(wp)
	a.erase("world_person")
	a["respawn"] = false
	foe = Enemy.new()
	foe.setup(a)
	get_tree().current_scene.add_child(foe)
	_place(foe, center + Vector3(0, 0, -4.5))
	foe.facing = PI
	foe.home = center
	var eye: Array = wp.get("eye", [0, 0])
	if String(wp["clan"]) != "" or int(eye[0]) > 0:
		ClanWorld.after_spawn_enemy(foe, String(wp["clan"]), foe_lv, int(eye[0]))
	foe.target = pl
	pl.combat.lock_target = foe
	duel.me["name"] = "Sen  •  Güç %d" % my_lv
	duel.foe["name"] = "%s  •  Güç %d" % [String(wp["name"]), foe_lv]
	duel.me["trail"] = 1.0
	duel.foe["trail"] = 1.0
	duel.score = "%d – %d" % [wins, losses]
	duel.clock = 0.0
	_cmb = {"me": [0, 0.0, 0.0, 1.0], "foe": [0, 0.0, 0.0, 1.0]}
	# açılış: iki dövüşçü karşılıklı bekler, kamera yandan başlayıp oyuncunun arkasına süzülür; "HAZIR" -> "BAŞLA!"
	intro_t = 0.0
	if duel_cam:
		pl.yaw = 180.0 + 75.0
		pl.pitch = -6.0
		pl.cam_dist = 7.0


func player_down() -> void:
	if over:
		return
	over = true
	losses += 1
	pl.hp = 1.0
	pl.combat.invuln = 5.0
	pl.combat.take_hit_down()
	_end("KAYBETTİN", Color(1, 0.4, 0.35))


func _end(txt: String, col: Color) -> void:
	duel.score = "%d – %d" % [wins, losses]
	# bitiriş: son darbe ağır çekimde, ortada "K.O."
	duel.flash("K.O.", 1.3, Color(1.0, 0.86, 0.3))
	_ko_ms = Time.get_ticks_msec() + 1100   # ağır çekim her karede yeniden kurulur (vuruş duraklaması ezmesin)
	await get_tree().create_timer(1.15, true, false, true).timeout
	if not over:
		return
	Hud.banner(txt, "Yeni raunt birazdan başlıyor  •  F1: ayarlar", col)
	await get_tree().create_timer(2.6).timeout
	if over:
		_new_round()


## Düello kamerası: oyuncunun omzunun arkasından rakibe bakar (rakip hep görüşte), aralık açıldıkça uzaklaşır, rakip yükselince
## yukarı bakar. Fare kısa süreliğine çevirir; kamera yumuşakça rakibe geri döner.
func _duel_camera(dt: float) -> void:
	if not duel_cam or menu_open or foe == null or not is_instance_valid(foe) or foe.dead:
		return
	var d: Vector3 = foe.global_position - pl.global_position
	var sep = Vector2(d.x, d.z).length()
	if sep < 0.4:
		return
	var want_yaw = rad_to_deg(atan2(-d.x, -d.z)) - 16.0 * clampf(sep / 4.0, 0.3, 1.0)   # oyuncu solda, rakip sağda kalır
	var k = clampf(dt * (2.2 if intro_t >= 0.0 else 4.5), 0.0, 1.0)
	pl.yaw = rad_to_deg(lerp_angle(deg_to_rad(pl.yaw), deg_to_rad(want_yaw), k))
	var want_pitch = clampf(-9.0 + rad_to_deg(atan2(d.y, maxf(sep, 2.0))) * 0.75, -40.0, 35.0)
	pl.pitch = lerpf(pl.pitch, want_pitch, clampf(dt * 3.0, 0.0, 1.0))
	pl.cam_dist = lerpf(pl.cam_dist, clampf(4.6 + sep * 0.42, 5.0, 13.0), clampf(dt * 3.0, 0.0, 1.0))


## Kombo sayacı: kısa aralıklarla art arda alınan darbeler tek kombo sayılır (vuruş sayısı + götürdüğü can yüzdesi)
func _combo_count(key: String, hp_f: float, dt: float) -> void:
	var c: Array = _cmb[key]
	if hp_f < float(c[3]) - 0.0005:
		var chain = float(c[1]) > 0.0
		c[0] = int(c[0]) + 1 if chain else 1
		c[2] = (float(c[2]) if chain else 0.0) + float(c[3]) - hp_f
		c[1] = 1.7
	c[3] = hp_f
	c[1] = float(c[1]) - dt
	var dd: Dictionary = duel.me if key == "foe" else duel.foe   # rakibe vurulan kombo oyuncunun tarafında görünür
	dd["hits"] = int(c[0]) if float(c[1]) > 0.0 else 0
	dd["cdmg"] = float(c[2])
	dd["cfade"] = clampf(float(c[1]) / 0.4, 0.0, 1.0)


func _physics_process(_dt: float) -> void:
	if not ready_ok:
		return
	_hud_t -= _dt
	if _hud_t <= 0.0:
		_hud_t = 0.25
		_hide_game_hud()
	# halkanın dışına çıkılmaz
	for f in [pl, foe]:
		if f == null or not is_instance_valid(f):
			continue
		var v: Vector3 = f.global_position - center
		v.y = 0.0
		if v.length() > R:
			var n = v.normalized()
			f.global_position = Vector3(center.x + n.x * R, f.global_position.y, center.z + n.z * R)
			var out = f.velocity.dot(n)
			if out > 0.0:
				f.velocity -= n * out
	_duel_camera(_dt)
	if _ko_ms > 0:
		if Time.get_ticks_msec() < _ko_ms:
			Combat.base_time_scale = 0.25
		else:
			_ko_ms = 0
			Combat.base_time_scale = 1.0
	if intro_t >= 0.0:
		intro_t += _dt
		pl.input_locked = 0.15
		pl.combat.action = "intro"   # saldırı / jutsu / blok yok
		pl.combat.invuln = maxf(pl.combat.invuln, 0.1)
		if is_instance_valid(foe):
			# rakip yerinde, oyuncuya dönük bekler (kendi gezinmesi / saldırısı açılış bitene kadar durur)
			foe.set_physics_process(false)
			foe.velocity = Vector3.ZERO
			foe.facing = PI
			foe.model.rotation.y = PI
			foe.model.play("idle", 0.2)
		duel.intro = "HAZIR" if intro_t < INTRO - 0.8 else "BAŞLA!"
		duel.intro_k = clampf(intro_t / 0.25, 0.0, 1.0) if intro_t < INTRO - 0.8 else clampf((intro_t - (INTRO - 0.8)) / 0.2, 0.0, 1.0)
		duel.intro_col = Color(1, 1, 1) if intro_t < INTRO - 0.8 else Color(1.0, 0.82, 0.3)
		if intro_t >= INTRO:
			intro_t = -1.0
			duel.intro = ""
			pl.combat.action = ""
			if is_instance_valid(foe):
				foe.set_physics_process(true)
				if not passive:
					foe.target = pl
			if not _hinted:
				_hinted = true
				Hud.msg("F1: rakip ve güç ayarları  •  F2: raundu yeniden başlat  •  K: jutsuları yuvalara diz  •  Tab: ekipman", Color(1, 0.85, 0.4), 7.0)
		return
	if is_instance_valid(foe):
		_combo_count("foe", clampf(foe.hp / maxf(1.0, foe.max_hp), 0.0, 1.0), _dt)
		_combo_count("me", clampf(pl.hp / maxf(1.0, pl.max_hp), 0.0, 1.0), _dt)
		if passive:
			foe.blind_t = 1.0   # kukla: saldırmaz, ama darbeye tepki verir
		elif not foe.dead and (foe.target == null or not is_instance_valid(foe.target)):
			foe.target = pl
		if pl.combat.lock_target == null and not foe.dead:
			pl.combat.lock_target = foe
		duel.foe["hp"] = clampf(foe.hp / maxf(1.0, foe.max_hp), 0.0, 1.0)
		duel.foe["ck"] = clampf(foe.chakra / maxf(1.0, foe.max_chakra), 0.0, 1.0)
		duel.foe["bars"] = foe.sub_bars
		if foe.dead and not over:
			over = true
			wins += 1
			_end("KAZANDIN", Color(0.5, 1.0, 0.5))
	duel.me["hp"] = clampf(pl.hp / maxf(1.0, pl.max_hp), 0.0, 1.0)
	duel.me["ck"] = clampf(pl.chakra / maxf(1.0, pl.max_chakra), 0.0, 1.0)
	duel.me["bars"] = pl.combat.sub_bars
	if not over:
		duel.clock += _dt


var _hud_t := 0.0
var _ko_ms := 0
var _hinted := false


## Oyunun üstteki göstergeleri (portre, harita, görev, pusula) arenada gizli: yerlerinde iki dövüşçünün barları var
func _hide_game_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for c0 in [Hud.compass, Hud.compass_lbl, Hud.minimap, Hud.objective_lbl, Hud.obj_progress_lbl]:
		if c0 != null and is_instance_valid(c0):
			c0.visible = false
	for c in Hud.game_hud.get_children():
		if c in [Hud.banner_box, Hud.msg_lbl, Hud.xhair, Hud.lock_ret, Hud.seal_box, Hud.prompt_box]:
			continue
		if c is Control and c.visible and c.size.y < vp.y * 0.5 and c.size.x < vp.x * 0.9 and c.get_global_rect().position.y < vp.y * 0.42:
			c.visible = false


## İki dövüşçünün göstergeleri: iki yanda aynalı eğik can barı (hasar izi geriden gelir), altında chakra, Kawarimi hakları; ortada skor ve süre
class DuelHud extends Control:
	var me := {"hp": 1.0, "trail": 1.0, "ck": 1.0, "bars": 4.0, "name": "", "hits": 0, "cdmg": 0.0, "cfade": 0.0}
	var foe := {"hp": 1.0, "trail": 1.0, "ck": 1.0, "bars": 4.0, "name": "", "hits": 0, "cdmg": 0.0, "cfade": 0.0}
	var score := "0 – 0"
	var clock := 0.0
	var intro := ""          # ortadaki büyük yazı (HAZIR / BAŞLA! / K.O.)
	var intro_k := 1.0       # 0..1 beliriş (büyükten oturur)
	var intro_col := Color(1, 1, 1)
	var _flash_t := 0.0

	func flash(txt: String, dur: float, col: Color) -> void:
		intro = txt
		intro_col = col
		intro_k = 0.0
		_flash_t = dur

	func _process(dt: float) -> void:
		if _flash_t > 0.0:
			var rdt = dt / maxf(Engine.time_scale, 0.05)   # ağır çekimde de gerçek hızda
			_flash_t -= rdt
			intro_k = minf(1.0, intro_k + rdt / 0.18)
			if _flash_t <= 0.0:
				intro = ""
		for d in [me, foe]:
			if float(d["trail"]) > float(d["hp"]):
				d["trail"] = maxf(float(d["hp"]), float(d["trail"]) - dt * 0.3)
			else:
				d["trail"] = d["hp"]
		queue_redraw()

	func _quad(x0: float, x1: float, y0: float, y1: float, sk: float, mir: bool) -> PackedVector2Array:
		var pts = [Vector2(x0 + sk, y0), Vector2(x1 + sk, y0), Vector2(x1, y1), Vector2(x0, y1)]
		if mir:
			for i in 4:
				pts[i].x = size.x - pts[i].x
		return PackedVector2Array(pts)

	func _fillq(x0: float, x1: float, y0: float, y1: float, sk: float, mir: bool, col: Color) -> void:
		if x1 - x0 > 1.0:
			draw_colored_polygon(_quad(x0, x1, y0, y1, sk, mir), col)

	func _side(d: Dictionary, mir: bool) -> void:
		var u = size.x / 1920.0
		var x0 = 64.0 * u
		var bw = 720.0 * u
		var y0 = 64.0 * u
		var bh = 30.0 * u
		var sk = 18.0 * u
		var hp := float(d["hp"])
		# gövde
		_fillq(x0 - 6.0 * u, x0 + bw + 6.0 * u, y0 - 6.0 * u, y0 + bh + 6.0 * u, sk * 1.4, mir, Color(0.03, 0.03, 0.05, 0.88))
		_fillq(x0, x0 + bw, y0, y0 + bh, sk, mir, Color(0.16, 0.05, 0.05, 0.9))
		_fillq(x0, x0 + bw * float(d["trail"]), y0, y0 + bh, sk, mir, Color(1.0, 0.93, 0.8))
		var col = Color(0.2, 0.85, 0.32) if hp > 0.5 else (Color(0.98, 0.78, 0.18) if hp > 0.25 else Color(0.95, 0.25, 0.2))
		_fillq(x0, x0 + bw * hp, y0, y0 + bh, sk, mir, col)
		_fillq(x0 + sk * 0.62, x0 + bw * hp + sk * 0.62 - sk * 0.62, y0, y0 + bh * 0.38, sk * 0.38, mir, Color(1, 1, 1, 0.22))
		var outl = _quad(x0, x0 + bw, y0, y0 + bh, sk, mir)
		outl.append(outl[0])
		draw_polyline(outl, Color(1.0, 0.82, 0.35), 2.5 * u, true)
		# chakra
		var cy = y0 + bh + 10.0 * u
		var cw = 520.0 * u
		var ch = 13.0 * u
		_fillq(x0 - 4.0 * u, x0 + cw + 4.0 * u, cy - 4.0 * u, cy + ch + 4.0 * u, sk * 0.6, mir, Color(0.03, 0.03, 0.05, 0.88))
		_fillq(x0, x0 + cw * float(d["ck"]), cy, cy + ch, sk * 0.43, mir, Color(0.25, 0.6, 1.0))
		_fillq(x0 + 4.0 * u, x0 + cw * float(d["ck"]), cy, cy + ch * 0.4, sk * 0.17, mir, Color(0.75, 0.9, 1.0, 0.45))
		# Kawarimi hakları: dört eşkenar dörtgen (dolmakta olan yarı saydam)
		var py = cy + ch + 22.0 * u
		for k in 4:
			var cx = x0 + (14.0 + k * 36.0) * u
			if mir:
				cx = size.x - cx
			var r = 11.0 * u
			var dm = PackedVector2Array([Vector2(cx, py - r), Vector2(cx + r, py), Vector2(cx, py + r), Vector2(cx - r, py)])
			draw_colored_polygon(dm, Color(0.03, 0.03, 0.05, 0.88))
			var f = clampf(float(d["bars"]) - float(k), 0.0, 1.0)
			if f > 0.02:
				var r2 = r * 0.72
				draw_colored_polygon(PackedVector2Array([Vector2(cx, py - r2), Vector2(cx + r2, py), Vector2(cx, py + r2), Vector2(cx - r2, py)]), Color(1.0, 0.85, 0.35, 1.0 if f >= 1.0 else 0.35))
		# isim
		var font = get_theme_default_font()
		var fs = int(30.0 * u)
		var tx = (size.x - x0 - bw - sk) if mir else (x0 + sk)
		var al = HORIZONTAL_ALIGNMENT_RIGHT if mir else HORIZONTAL_ALIGNMENT_LEFT
		draw_string_outline(font, Vector2(tx, y0 - 14.0 * u), String(d["name"]), al, bw, fs, int(6.0 * u), Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(tx, y0 - 14.0 * u), String(d["name"]), al, bw, fs, Color(1, 1, 1))
		# kombo sayacı: bu tarafın rakibe vurduğu art arda darbeler
		if int(d["hits"]) >= 2:
			var a := float(d["cfade"])
			var hy = py + 92.0 * u
			var hx = (size.x - x0 - 400.0 * u) if mir else x0
			var ht = "%d VURUŞ" % int(d["hits"])
			draw_string_outline(font, Vector2(hx, hy), ht, al, 400.0 * u, int(54.0 * u), int(10.0 * u), Color(0, 0, 0, 0.9 * a))
			draw_string(font, Vector2(hx, hy), ht, al, 400.0 * u, int(54.0 * u), Color(1.0, 0.82, 0.3, a))
			var dt2 = "%%%.1f hasar" % (float(d["cdmg"]) * 100.0)
			draw_string_outline(font, Vector2(hx, hy + 34.0 * u), dt2, al, 400.0 * u, int(24.0 * u), int(6.0 * u), Color(0, 0, 0, 0.9 * a))
			draw_string(font, Vector2(hx, hy + 34.0 * u), dt2, al, 400.0 * u, int(24.0 * u), Color(1, 1, 1, a))

	func _draw() -> void:
		var u = size.x / 1920.0
		_side(me, false)
		_side(foe, true)
		# orta: skor ve süre
		var c = Vector2(size.x * 0.5, 78.0 * u)
		var r = 64.0 * u
		var dm = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.25, 0), c + Vector2(0, r), c + Vector2(-r * 1.25, 0)])
		draw_colored_polygon(dm, Color(0.04, 0.04, 0.07, 0.92))
		dm.append(dm[0])
		draw_polyline(dm, Color(1.0, 0.82, 0.35), 3.0 * u, true)
		var font = get_theme_default_font()
		var fs = int(34.0 * u)
		draw_string(font, Vector2(c.x - 100.0 * u, c.y + 6.0 * u), score, HORIZONTAL_ALIGNMENT_CENTER, 200.0 * u, fs, Color(1, 1, 1))
		var tt = "%d:%02d" % [int(clock) / 60, int(clock) % 60]
		draw_string(font, Vector2(c.x - 100.0 * u, c.y + 34.0 * u), tt, HORIZONTAL_ALIGNMENT_CENTER, 200.0 * u, int(18.0 * u), Color(1.0, 0.85, 0.5))
		# ortadaki büyük yazı: büyükten küçülerek oturur, arkasında koyu şerit
		if intro != "":
			var kk = intro_k * intro_k * (3.0 - 2.0 * intro_k)
			var bs = int(lerpf(260.0, 150.0, kk) * u)
			var my = size.y * 0.42
			draw_rect(Rect2(0, my - 110.0 * u, size.x, 150.0 * u), Color(0, 0, 0, 0.35 * kk))
			draw_string_outline(font, Vector2(0, my), intro, HORIZONTAL_ALIGNMENT_CENTER, size.x, bs, int(22.0 * u), Color(0, 0, 0, 0.9 * kk))
			draw_string(font, Vector2(0, my), intro, HORIZONTAL_ALIGNMENT_CENTER, size.x, bs, Color(intro_col.r, intro_col.g, intro_col.b, kk))
