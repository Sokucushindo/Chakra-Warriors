extends Node
## Doğuştan jinchūriki (%1): zorla açılan gerçek yeni oyun + afiş görüntüsü, durum tutarlılığı, zorlamasız oran, serbest canavar yoksa yok
## Kayıt yuvası 97 (kullanıcının yuvalarına dokunmaz), sonda silinir.
var main: Node
const SLOT := 97


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _check(tag: String, id: String) -> bool:
	var bs = TailedBeasts.beasts()
	var sp = []
	for b in bs:
		if String(bs[b].get("state", "")) == "sealed_player":
			sp.append(b)
	var ok = TailedBeasts.player_jinchuriki() == id and TailedBeasts.held() == [id] and sp == [id] and "jinchuriki" in Game.profile["skills"] \
		and String(Game.profile.get("jin_birth", "")) == id and not bs[id].has("host")
	print("JIN %s id=%s held=%s sealed_player=%s skills_jin=%s ok=%s" % [tag, id, TailedBeasts.held(), sp, "jinchuriki" in Game.profile["skills"], ok])
	return ok


func _ready() -> void:
	await get_tree().process_frame
	if FileAccess.file_exists(Game.save_path(SLOT)):
		print("JIN slot %d already exists; abort" % SLOT)
		get_tree().quit()
		return
	OS.set_environment("FORCE_JIN", "1")
	main.creator_state = {"slot": SLOT, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "village": "konoha",
		"hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	await main._start_new_game(true)
	OS.set_environment("FORCE_JIN", "")
	var id = TailedBeasts.player_jinchuriki()
	print("JIN game1 beast=%s states=%s" % [id, TailedBeasts.beasts().keys().map(func(k): return "%s:%s" % [k, TailedBeasts.beasts()[k]["state"]])])
	var all_ok = id != "" and _check("game1", id)
	await _w(1.0)
	await main.shot("jin_village_banner")
	await _w(3.6)
	await main.shot("jin_birth_banner")
	await _w(1.2)
	await main.shot("jin_birth_banner2")
	# --- profil düzeyinde: zorla (her canavar), zorlamasız oran, serbest yoksa yok
	var real = Game.profile
	var counts = {}
	for k in 30:
		Game.profile = Progress.new_profile({"slot": SLOT, "name": "T", "gender": "m", "clan": "none", "element": "katon", "look": real["look"], "village": ["konoha", "suna", "kumo", "kiri", "iwa"][k % 5]})
		var free_before = TailedBeasts.free_beasts()
		var b = TailedBeasts.roll_birth_jinchuriki("1")
		counts[b] = int(counts.get(b, 0)) + 1
		if b != "" and not b in free_before:
			print("JIN FAIL forced picked non-free %s (free=%s)" % [b, free_before])
			all_ok = false
		if b != "" and not _check("forced%d(%s)" % [k, Game.profile["village"]], b):
			all_ok = false
	print("JIN forced picks=%s" % counts)
	# belirli canavar zorla (Kurama başta hep inde)
	Game.profile = Progress.new_profile({"slot": SLOT, "name": "T", "gender": "m", "clan": "none", "element": "katon", "look": real["look"], "village": "kiri"})
	all_ok = _check("force_kurama", TailedBeasts.roll_birth_jinchuriki("kurama")) and all_ok
	# hiç serbest yoksa jinchūriki olmaz
	Game.profile = Progress.new_profile({"slot": SLOT, "name": "T", "gender": "m", "clan": "none", "element": "katon", "look": real["look"], "village": "konoha"})
	for b in TailedBeasts.beasts():
		TailedBeasts.beasts()[b]["state"] = "captured_org"
	var none = TailedBeasts.roll_birth_jinchuriki("1")
	print("JIN no_free result='%s' ok=%s" % [none, none == ""])
	all_ok = all_ok and none == ""
	# zorlamasız oran
	var hits = 0
	var N = 2000
	for k in N:
		Game.profile = Progress.new_profile({"slot": SLOT, "name": "T", "gender": "m", "clan": "none", "element": "katon", "look": real["look"], "village": "konoha"})
		if TailedBeasts.roll_birth_jinchuriki() != "":
			hits += 1
	print("JIN unforced hits=%d/%d (%.2f%%)" % [hits, N, 100.0 * hits / N])
	Game.profile = real
	print("JIN ALL_OK=%s" % all_ok)
	Game.delete_slot(SLOT)
	print("JIN slot deleted=%s" % (not FileAccess.file_exists(Game.save_path(SLOT))))
	get_tree().quit()
