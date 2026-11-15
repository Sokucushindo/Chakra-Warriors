extends Node
## Ayarların oyun içi etkisi: kayıt süresi (otomatik kayıt takılması), görüş mesafesinin canlı uygulanması,
## kalabalık ayarı düşünce köy halkının azalması, dövüşte otomatik kaydın beklemesi.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var orig = Game.settings.duplicate(true)
	main.creator_state = {"slot": 97, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(6.0).timeout
	# 1) kayıt süresi
	var worst := 0.0
	for i in 5:
		var t0 := Time.get_ticks_usec()
		Game.save_game()
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
	print("  kayıt süresi en kötü %.1f ms" % worst)
	ok(worst < 30.0, "kayıt kısa (%.1f ms < 30)" % worst)
	# 2) görüş mesafesi canlı
	var g: GeometryInstance3D = null
	for c in Game.world.find_children("*", "GeometryInstance3D", true, false):
		if c.visibility_range_end > 50.0:
			g = c
			break
	var e0 = g.visibility_range_end
	var tf := Time.get_ticks_usec()
	var all = Game.world.find_children("*", "GeometryInstance3D", true, false)
	print("  find_children: %d düğüm, %.1f ms" % [all.size(), (Time.get_ticks_usec() - tf) / 1000.0])
	var t1 := Time.get_ticks_usec()
	Game.rescale_view(1.0, 0.5)
	var ms = (Time.get_ticks_usec() - t1) / 1000.0
	var worst_f := 0.0
	var frames_n := 0
	for i in 200:
		var tf0 := Time.get_ticks_usec()
		await get_tree().process_frame
		worst_f = maxf(worst_f, (Time.get_ticks_usec() - tf0) / 1000.0)
		frames_n += 1
		if is_equal_approx(g.visibility_range_end, e0 * 0.5):
			break
	ok(is_equal_approx(g.visibility_range_end, e0 * 0.5), "görüş mesafesi canlı: %.0f -> %.0f m (%d karede)" % [e0, g.visibility_range_end, frames_n])
	ok(ms < 5.0, "kaydetme anı takılmıyor (ilk dilim %.1f ms)" % ms)
	print("  tarama sırasında en uzun kare %.1f ms" % worst_f)
	await get_tree().create_timer(3.0).timeout
	Game.rescale_view(0.5, 1.0)
	await get_tree().create_timer(3.0).timeout
	# 3) kalabalık: Kalabalık -> Az
	var vl = get_tree().current_scene.find_child("VillageLife", true, false)
	Game.settings["crowd"] = 2
	Game.apply_graphics()
	for i in 40:   # köy dolsun
		await get_tree().create_timer(1.0).timeout
		if vl.npcs.size() >= 36:
			break
	var n0 = vl.npcs.size()
	Game.settings["crowd"] = 0
	Game.apply_graphics()
	await get_tree().create_timer(25.0).timeout
	var n1 = vl.npcs.size()
	print("  köylü: Kalabalık %d, Az'a inince 15 sn sonra %d" % [n0, n1])
	ok(n0 >= 33 and n1 <= 20, "kalabalık Az'a inince köylü azaldı (%d -> %d)" % [n0, n1])
	# 4) dövüşte otomatik kayıt bekler
	var pc: PlayerCombat = null
	for c in Game.player.get_children():
		if c is PlayerCombat:
			pc = c
	pc.last_hit_t = 0.0
	ok(Game._in_fight(), "hasar aldıktan hemen sonra dövüşte sayılıyor")
	pc.last_hit_t = 20.0
	ok(not Game._in_fight(), "20 sn sonra dövüş bitmiş sayılıyor")
	for k in orig:
		Game.settings[k] = orig[k]
	DirAccess.remove_absolute(Game.save_path(97))
	print("SONUC: %d hata" % fails)
	get_tree().quit()
