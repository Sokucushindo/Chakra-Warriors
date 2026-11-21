extends Node
## Akatsuki kapı sınavı (kullanıcının kaydının kopyası kayit_97): kilit çözülüyor mu, sınayan öldürüyor mu, kaybedince tekrar denenir mi
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.load_slot(97)
	await get_tree().create_timer(5.0).timeout
	Hud.close_dialog()
	var WA = load("res://scripts/core/world_akatsuki.gd")
	var me: Dictionary = WA.D()["me"]
	print("AKA basta test=", me.get("test"), " by=", me.get("by"))
	var pl = main.player
	var cp: Vector3 = WA.cave_pos()
	pl.global_position = cp + Vector3(0, 5, 60)
	await get_tree().create_timer(6.0).timeout
	var gp: Vector3 = AkatsukiCave.gate_pos()
	pl.global_position = gp + Vector3(0, 1, 8)
	await get_tree().create_timer(4.0).timeout
	print("AKA kapida test=", me.get("test"), " sinayan=", is_instance_valid(WA.recruiter), " takim=", WA.recruiter.team if is_instance_valid(WA.recruiter) else "-")
	var r = WA.recruiter
	print("AKA guc oyuncu=%.0f sinayan=%.0f  can oyuncu=%.0f sinayan=%.0f" % [Combat.power_of(pl), Combat.power_of(r), pl.max_hp, r.max_hp])
	# "Dövüş" seçeneğiyle aynı
	r.team = "enemy"
	r.set_meta("duel_rival", true)
	me["test"] = "duel"
	r.target = pl
	var minhp = pl.hp
	var big = 0.0
	var last = pl.hp
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000 and me["test"] == "duel":
		await get_tree().process_frame
		if pl.hp < last:
			big = maxf(big, (last - pl.hp) / pl.max_hp)
		last = pl.hp
		minhp = minf(minhp, pl.hp)
	print("AKA sonuc test=%s olu=%s en_dusuk_can=%.1f/%.0f en_buyuk_darbe=%%%.0f sinayan_takim=%s" % [me["test"], pl.is_dead(), minhp, pl.max_hp, big * 100.0, r.team if is_instance_valid(r) else "-"])
	Hud.close_dialog()
	pl.hp = pl.max_hp
	await get_tree().create_timer(1.0).timeout
	WA.gate({"pos": gp})
	await get_tree().create_timer(0.5).timeout
	print("AKA tekrar: kapı penceresi acik=", Hud.has_method("dialog_open") and Hud.dialog_open(), " test=", me["test"])
	get_tree().quit()
