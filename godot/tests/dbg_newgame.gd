extends Node
## Menüye dönüp yeni oyun: önceki oyunun insanları / düşmanlığı taşınmamalı, köy yeniden dolmalı
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _new(nm: String) -> void:
	main.creator_state = {"slot": 96, "name": nm, "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
func _count() -> Array:
	var vil := 0
	var foe := 0
	var wp := 0
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager:
			vil += 1
			if v.has_meta("world_person"):
				wp += 1
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and not f.dead and f.target == main.player:
			foe += 1
	return [vil, wp, foe]
func _ready() -> void:
	await get_tree().process_frame
	await _new("Bir")
	var pl = main.player
	pl.max_hp = 1e8; pl.hp = 1e8
	await _w(10.0)
	var civ = null
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and not v.interior and v.global_position.distance_to(pl.global_position) < 80.0:
			civ = v
			break
	if civ:
		civ.global_position = pl.global_position + Vector3(2, 0, 0)
		await _w(0.2)
		LazyFx.g("Crime").on_struck(civ)
	await _w(8.0)
	print("NG eski oyun: [köylü, dünya kişisi, bana saldıran]=", _count(), " alarm=", Orgs.blood_on(), " dünya kişi sayısı=", WorldPeople.all().size())
	Game.profile = {}
	Game.delete_slot(96)
	main.to_main_menu()
	await _w(1.0)
	print("NG menüde: ", _count(), " alarm=", Orgs.blood_on(), " baskın=", not Orgs._raid.is_empty())
	await _new("Iki")
	await _w(14.0)
	print("NG yeni oyun: ", _count(), " alarm=", Orgs.blood_on(), " baskın=", not Orgs._raid.is_empty(), " suç=", LazyFx.g("Crime").heat(), " kurban=", LazyFx.g("Crime").inst().victims.size(), " ad=", Game.profile.get("name"))
	Game.delete_slot(96)
	Game.profile = {}
	get_tree().quit()
