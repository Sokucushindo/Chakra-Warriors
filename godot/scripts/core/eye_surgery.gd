class_name EyeSurgery
extends RefCounted
## GÖZ NAKLİ — kanon (Narutopedia: Kakashi'ye Rin sahada taktı; Orochimaru/Kabuto gizli ameliyatlar yaptı; Madara Nagato'ya gizlice
## taktı; Danzō Shisui'nin gözünü sargı altında taşıdı). Köy hastanesi başkasının dōjutsusunu takmaz: klan gözü klanın malıdır.
## Nakli yapabilenler:
##   * takımdaki tıbbi ninja (Rin örneği) — sahada, ücretsiz, iyi ihtimalle tutar
##   * kendi tıbbi ninjutsun — Shōsen + yüksek chakra kontrolü; riskli, beden ağır yıpranır
##   * yeraltının Kara Cerrahı (Orochimaru/Kabuto benzeri) — pahalı, soru sormaz, neredeyse hep tutar
## Ameliyat dünyada gerçek bir olaydır: düşman yakında olmamalı, oturursun, yeşil şifa chakrası gözünde çalışır (~5 sn),
## sonra göz tutar ya da beden reddeder (göz bozulur). Ardından iyileşme süresi (Buffs "nakil").
## Bedel (kanon): Uchiha kanı olmayan bedende Sharingan kapanmaz — açık olmasa da chakrayı yavaşça emer (Eyes._process).

const OP_TIME := 5.0


## Kendi tıbbi ninjutsunla nakil yapabilir mi? (Shōsen bilgisi + Iryō / tıbbi ustalık 50; eskiden chakra kontrolüne bakıyordu:
## tıbbı 0 olan biri %90 ile göz takabiliyordu)
static func can_self(pr: Dictionary) -> bool:
	return "shousen" in pr.get("learned", []) and LazyFx.g("Mastery").get_v(pr, "iryo") >= 50.0


## Kendi ameliyatının tutma olasılığı: Iryō 50 -> %40, 100 -> %90; ileri tıbbi teknikler (Tsunade yolu) +%5'er
static func self_chance(pr: Dictionary) -> float:
	var c = clampf(0.4 + (LazyFx.g("Mastery").get_v(pr, "iryo") - 50.0) * 0.01, 0.4, 0.9)
	for adv in ["in_yu_shometsu", "sozo_saisei", "chakura_no_mesu"]:
		if adv in pr.get("learned", []):
			c += 0.05
	return minf(0.97, c)


## Takımdaki tıbbi ninjanın gücüne göre (genin %35 civarı, usta tıbbi ninja %80): eskiden herkes için sabit %88'di
static func medic_chance(lv: float) -> float:
	return clampf(0.3 + lv * 0.006, 0.35, 0.8)


static var medic_lv := 20.0   # seçeneği açan takım arkadaşının gücü (squad _talk yazar)


static func surgeons(pr: Dictionary) -> Dictionary:
	return {
		"medic": {"title": "Sahada nakil", "chance": medic_chance(medic_lv), "price": 0, "hp": 0.15, "recover": 150.0,
			"ok": "Gözün sarıldı. \"Bir süre bandajı çıkarma; beden yeni gözü tanıyana kadar ağrıyacak.\""},
		"self": {"title": "Kendi tıbbi ninjutsunla nakil", "chance": self_chance(pr), "price": 0, "hp": 0.4, "recover": 300.0,
			"ok": "Titreyen ellerle son sinir bağını da kapattın. Göz tuttu."},
		"black": {"title": "Kara Cerrah", "chance": 0.35, "price": 1200, "hp": 0.1, "recover": 90.0,
			"ok": "Kara Cerrah dikişleri attı: \"Kimden aldığını sormadım, sen de unut.\""},
	}


## Kanon nakil şartı (oyuncu ve dünya NPC'leri aynı kuralı kullanır): boş = takılabilir, dolu = neden takılamaz (menüde gösterilir).
## Sharingan / Mangekyō: herkese tutar (Kakashi, Danzō, Shin) ama Uchiha olmayan bedende kapanmaz. Byakugan: herkese (Ao).
## Ketsuryūgan: kan soyu gözü, kanonda nakil yasağı yok. Rinnegan: sıradan beden taşıyamaz — Senju hücresi (Obito, Madara'nın
## gözü) ya da Uzumaki yaşam gücü (Nagato). Tenseigan: Hamura'nın chakrasıyla yaşar (Toneri: Hyūga Byakugan'ı + Ōtsutsuki chakrası).
## Jōgan: Ōtsutsuki chakrasına bağlı (Boruto: Uzumaki + Hyūga kanı).
static func canon_block(eye_kind: int, clan: String, senju_dna: bool) -> String:
	match eye_kind:
		6:
			if not senju_dna and not clan in ["uzumaki", "otsutsuki"]:
				return "Rinnegan'ın chakrasını sıradan beden taşıyamaz: Senju hücresi (Obito) ya da Uzumaki yaşam gücü (Nagato) gerekir."
		7:
			if not clan in ["hyuga", "otsutsuki"]:
				return "Tenseigan Hamura'nın chakrasıyla yaşar: yalnız Hyūga ya da Ōtsutsuki soyunun bedeninde çalışır (Toneri)."
		8:
			if not clan in ["uzumaki", "hyuga", "otsutsuki"]:
				return "Jōgan Ōtsutsuki chakrasına bağlı: yalnız o kanı taşıyan soyda (Uzumaki, Hyūga, Ōtsutsuki) tutar."
	return ""


static func eye_kind_of(g: Dictionary) -> int:
	return int(LazyFx.g("Gear").item(String(g.get("id", ""))).get("eye", {}).get("kind", 0))


## Oyuncunun bedenine bu göz takılamazsa nedeni
static func block_reason(pr: Dictionary, g: Dictionary) -> String:
	return canon_block(eye_kind_of(g), String(pr.get("clan", "")), Eyes.has_senju_dna(pr))


## Nakilden önce oyuncuya söylenen kanon bedelleri / sonuçlar (engel değil)
static func notes(pr: Dictionary, g: Dictionary, slot: String) -> Array:
	var out = []
	var k = eye_kind_of(g)
	var clan = String(pr.get("clan", ""))
	if k in [1, 4, 5] and clan != "uchiha":
		out.append("Uchiha kanın yok: bu Sharingan hiç kapanmaz, açık olmasa da chakranı durmadan emer (Kakashi).")
	if k == 4:
		var cur = LazyFx.g("Gear").equipped(pr, slot)
		if not cur.is_empty() and cur["id"] == "goz_mangekyo":
			out.append("Mangekyō + Mangekyō: Ebedi Mangekyō olur, körlük biter.")
	if k == 6 and not Eyes.has_senju_dna(pr):
		out.append("Uzumaki yaşam gücü Rinnegan'ı taşır ama beden ağır yıpranır (Nagato).")
	out.append("Nakil göz doğuştan gözden çok daha fazla chakra harcar.")
	return out


## Görünen ad (tomoe, Mangekyō tarzı)
static func eye_label(g: Dictionary) -> String:
	var nm = String(LazyFx.g("Gear").item(String(g["id"]))["name"])
	if String(g["id"]) == "goz_sharingan":
		nm += "  (%d tomoe)" % int(g.get("lvl", 3))
	var st = String(g.get("ms_style", ""))
	if Eyes.MS_STYLES.has(st):
		nm += "  — %s" % String(Eyes.MS_STYLES[st]["name"])
	return nm


## Nakledilebilir kavanoz gözleri; aynı türden (id + tomoe + tarz + akrabalık) olanlar tek satırda: [[göz, adet], ...]
static func jar_groups(pr: Dictionary) -> Array:
	var seen := {}
	var out = []
	for g in pr.get("gear", []):
		if LazyFx.g("Gear").item(g["id"]).get("slot", "") != "goz" or LazyFx.g("Gear").is_equipped(pr, g):
			continue
		if String(g.get("origin", "dogustan")) == "dogustan" and bool(g.get("own", false)):
			continue   # kendi çıkardığın göz: menüden geri takılır, nakil gerekmez
		var key = "%s|%d|%s|%s" % [g["id"], int(g.get("lvl", 3)), String(g.get("ms_style", "")), str(bool(g.get("kin", false)))]
		if seen.has(key):
			out[int(seen[key])][1] += 1
			continue
		seen[key] = out.size()
		out.append([g, 1])
	return out


## Tek göz için yuva seçimi (ya da kanon engeli): Hud.dialog
static func choose_slot(uid: int, kind: String) -> void:
	var pr = Game.profile
	var g = LazyFx.g("Gear").find(pr, uid)
	if g.is_empty():
		return
	var why = block_reason(pr, g)
	if why != "":
		Hud.dialog("Göz Nakli", "%s takılamaz.\n%s" % [eye_label(g), why], [])
		return
	var s: Dictionary = surgeons(pr)[kind]
	var opts = []
	for sl in [["sag_goz", "Sağ göze tak"], ["sol_goz", "Sol göze tak"]]:
		var slot = sl[0]
		var cur = LazyFx.g("Gear").equipped(pr, slot)
		var lbl = String(sl[1]) + (("  (şimdiki: %s — kavanoza)" % String(LazyFx.g("Gear").item(cur["id"])["name"])) if not cur.is_empty() else "")
		opts.append({"label": lbl, "tip": "\n".join(notes(pr, g, slot)), "cb": func(): operate(uid, slot, kind)})
	var price = int(s["price"])
	var txt = "%s  •  %s\nTutma şansı %%%d%s\n%s" % [eye_label(g), String(s["title"]), int(round(float(s["chance"]) * 100.0)), (", %d Ryō" % price) if price > 0 else "",
		"\n".join(notes(pr, g, "sag_goz"))]
	Hud.dialog("Göz Nakli", txt, opts)


## Kavanozdaki her göz türü için bir seçenek (önce göz, sonra yuva); kanonca takılamayan gözler nedeniyle listede kalır
static func options(kind: String) -> Array:
	var pr = Game.profile
	var s: Dictionary = surgeons(pr)[kind]
	var opts = []
	for grp in jar_groups(pr):
		var g: Dictionary = grp[0]
		var uid = int(g["uid"])
		var why = block_reason(pr, g)
		var cnt = ("  x%d" % int(grp[1])) if int(grp[1]) > 1 else ""
		if why != "":
			opts.append({"label": "%s%s  — takılamaz" % [eye_label(g), cnt], "tip": why, "cb": func(): choose_slot(uid, kind)})
		else:
			opts.append({"label": "%s%s  (tutma %%%d)" % [eye_label(g), cnt, int(round(float(s["chance"]) * 100.0))], "cb": func(): choose_slot(uid, kind)})
	# Senju hücresi nakli (Yamato / Danzō / Madara): kavanozda doku varsa ve beden henüz taşımıyorsa
	if int(pr.get("flags", {}).get("senju_jar", 0)) > 0 and not Eyes.has_senju_dna(pr):
		var c2 = clampf(float(s["chance"]) - 0.25, 0.1, 0.9)   # kanon: hücre çoğu bedeni öldürür — gözden çok daha riskli
		var price2 = int(s["price"]) * 2
		opts.append({"label": "Senju hücresi nakli  (tutma %%%d%s)" % [int(round(c2 * 100.0)), (", %d Ryō" % price2) if price2 > 0 else ""], "cb": func(): operate(-1, "senju", kind)})
	return opts


## Yanındaki takım tıbbi ninjası (Rin örneği): GeninSquad üyesi, ayakta, 30 m içinde; yoksa null (gücünü medic_lv'ye yazar)
static func field_medic() -> Node3D:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return null
	var sq = p.get_tree().current_scene.get_node_or_null("Actors/GeninSquad") if p.get_tree().current_scene else null
	if sq == null:
		return null
	var mates: Array = LazyFx.g("GeninSquad").data().get("mates", [])
	for m in sq.members:
		var key = String(m.get("key", ""))
		var n = m.get("node")
		if key == "sensei" or not key.begins_with("m") or n == null or not is_instance_valid(n) or n.is_dead():
			continue
		var i = int(key.substr(1))
		if i >= mates.size() or not bool(mates[i].get("medic", false)) or n.global_position.distance_to(p.global_position) > 30.0:
			continue
		var mf: Dictionary = LazyFx.g("Friends").all().get(LazyFx.g("GeninSquad").fid(key), {})
		medic_lv = float(mf.get("pupil_lv", mf.get("level", maxf(5.0, float(Game.profile.get("level", 10)) - 1.0))))
		return n
	return null


## Gözler sekmesinden: bu kavanoz gözünü bu yuvaya kim takabilir? (kanon engeli varsa nedeni; şu an kimse yoksa nereye gidileceği)
static func menu_offer(uid: int, slot: String) -> void:
	var pr = Game.profile
	var g = LazyFx.g("Gear").find(pr, uid)
	if g.is_empty():
		return
	var why = block_reason(pr, g)
	if why != "":
		Hud.dialog("Göz Nakli", "%s takılamaz.\n%s" % [eye_label(g), why], [])
		return
	var side = "sağ" if slot == "sag_goz" else "sol"
	var opts = []
	if can_self(pr):
		opts.append({"label": "Kendi tıbbi ninjutsunla nakil yap (tutma %%%d)" % int(round(self_chance(pr) * 100.0)), "cb": func(): operate(uid, slot, "self")})
	if field_medic() != null:
		opts.append({"label": "Takımının tıbbi ninjası taksın (tutma %%%d)" % int(round(medic_chance(medic_lv) * 100.0)), "cb": func(): operate(uid, slot, "medic")})
	if Game.has_meta("sandbox"):   # beceri deneme modu: Kara Cerrah her yerde
		opts.append({"label": "Kara Cerrah taksın (tutma %35, 1200 Ryō)", "cb": func(): operate(uid, slot, "black")})
	var txt = "%s → %s göz\n%s" % [eye_label(g), side, "\n".join(notes(pr, g, slot))]
	if opts.is_empty():
		txt += "\n\nŞu an nakli yapacak kimse yok. Takımındaki tıbbi ninja sahada takar (Rin–Kakashi), Shōsen ve 50 Iryō ustalığıyla kendin yaparsın ya da kaçakların mağarasındaki Kara Cerrah gizlice takar."
	Hud.dialog("Göz Nakli", txt, opts)


## Ameliyat olayı: düşman yokken oturur, şifa chakrası çalışır, sonra sonuç
static func operate(uid: int, slot: String, kind: String) -> void:
	var pr = Game.profile
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var s: Dictionary = surgeons(pr)[kind]
	var cells = slot == "senju"
	if not cells:
		var why = block_reason(pr, LazyFx.g("Gear").find(pr, uid))
		if why != "":
			Hud.msg(why, Color(1, 0.6, 0.4))
			return
	if int(pr.get("ryo", 0)) < int(s["price"]) * (2 if cells else 1):
		Hud.msg("Yeterli Ryō yok.", Color(1, 0.5, 0.4))
		return
	for f in p.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(p, f) and not f.is_dead() and f.global_position.distance_to(p.global_position) < 35.0:
			Hud.msg("Düşman yakındayken göz nakli yapılmaz — önce güvenli bir yere çekil.", Color(1, 0.6, 0.4))
			return
	if int(s["price"]) > 0:
		Progress.add_ryo(-int(s["price"]) * (2 if cells else 1))
	if not cells:
		var g = LazyFx.g("Gear").find(pr, uid)
		if g.is_empty():
			return
	# olay: otur, yeşil şifa chakrası gözünde (kendi ameliyatında senin ellerin, diğerlerinde cerrahın)
	p.velocity = Vector3.ZERO
	p.model.play("idle", 0.3)
	p.input_locked = OP_TIME + 0.5
	Hud.msg("Göz nakli başladı... kıpırdama." if kind != "self" else "Bir eline ayna, öbürüne şifa chakrası... kendi gözünü açıyorsun.", Color(0.6, 1.0, 0.65))
	var head = p.global_position + Vector3.UP * 1.0
	# sahada nakil: takımdaki tıbbi ninja yanına gelir, karşına diz çöküp şifa chakralı ellerini gözüne tutar
	if kind == "medic":
		var best: Node3D = null
		for f in p.get_tree().get_nodes_in_group("fighters"):
			if f.has_meta("teammate") and not f.is_dead() and (best == null or f.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
				best = f
		if best:
			var at = p.global_position + p.face_dir() * 0.9
			at.y = Game.ground_height(at.x, at.z)
			best.global_position = at
			best.velocity = Vector3.ZERO
			var dv = p.global_position - at
			best.facing = atan2(-dv.x, -dv.z)
			best.set_physics_process(false)   # ameliyat boyunca yerinden kıpırdamaz
			if best.get("model"):
				best.model.rotation.y = best.facing
				best.model.play("idle", 0.3)
			CastAnim.play(best, "shousen", OP_TIME)   # şifa elleri öne, gözüne
			var ma = FX.aura(best, Color(0.4, 1.0, 0.5), 0.5, Vector3(0, 1.0, 0), 0.0)
			best.get_tree().create_timer(OP_TIME).timeout.connect(func():
				if is_instance_valid(best):
					best.set_physics_process(true)
				if is_instance_valid(ma):
					ma.emitting = false
					ma.get_tree().create_timer(1.0).timeout.connect(ma.queue_free))
	var aura = FX.aura(p, Color(0.4, 1.0, 0.5), 0.6, Vector3(0, 1.0, 0), 0.0)
	Sfx.play("heal", head)
	if kind == "self":
		CastAnim.play(p, "shousen", OP_TIME)   # kendi elleri kendi gözünde
	var tw = p.create_tween()
	for i in int(OP_TIME / 0.5):
		tw.tween_callback(func():
			if is_instance_valid(p):
				FX.hit_spark(_eye_pos(p), Color(0.45, 1.0, 0.55), 0.12))
		tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(aura):
			aura.emitting = false
			aura.get_tree().create_timer(1.0).timeout.connect(aura.queue_free)
		_finish(uid, slot, kind))


static func _finish(uid: int, slot: String, kind: String) -> void:
	var pr = Game.profile
	var p = Game.player
	var s: Dictionary = surgeons(pr)[kind]
	if slot == "senju":
		_finish_cells(kind)
		return
	var g = LazyFx.g("Gear").find(pr, uid)
	if g.is_empty() or p == null:
		return
	p.hp = maxf(1.0, p.hp - p.max_hp * float(s["hp"]))
	if randf() > float(s["chance"]):
		# beden reddetti: göz bozuldu (kavanozdan da gider)
		pr["gear"].erase(g)
		Buffs.add("nakil", float(s["recover"]) * 0.5, {"speed": 0.85, "melee": 0.85})
		Hud.banner("NAKİL TUTMADI", "Beden gözü reddetti — göz kullanılamaz hale geldi", Color(0.8, 0.3, 0.3))
		return
	var gid = String(g["id"])
	Eyes.transplant(pr, uid, slot)
	Buffs.add("nakil", float(s["recover"]), {"speed": 0.85, "melee": 0.85})
	var txt = String(s["ok"])
	if gid in ["goz_sharingan", "goz_mangekyo", "goz_ems"] and String(pr.get("clan", "")) != "uchiha":
		txt += "\nUchiha kanın olmadığı için bu Sharingan kapanmaz: açık olmasa da chakranı durmadan emer."
	if gid == "goz_rinnegan" and not Eyes.has_senju_dna(pr):
		# kanon (Nagato): Uzumaki yaşam gücü Rinnegan'ı taşır ama beden erir — uzun iyileşme
		Buffs.add("nakil", float(s["recover"]) * 2.0, {"speed": 0.75, "melee": 0.75})
		txt += "\nRinnegan bedenini zorluyor: iyileşmen uzun sürecek."
	Hud.dialog("Göz Nakli", txt, [])
	if kind == "self":
		LazyFx.g("Mastery").gain(pr, "chakra", 0.5)


## Senju hücresi naklinin sonucu: tutarsa Mokuton + Ashura chakrası (EMS ile Rinnegan yolu); tutmazsa doku ölür, beden ağır yıpranır
static func _finish_cells(kind: String) -> void:
	var pr = Game.profile
	var p = Game.player
	if p == null:
		return
	var s: Dictionary = surgeons(pr)[kind]
	var fl: Dictionary = pr["flags"]
	fl["senju_jar"] = maxi(0, int(fl.get("senju_jar", 0)) - 1)
	var chance = clampf(float(s["chance"]) - 0.25, 0.1, 0.9)
	if randf() > chance:
		p.hp = maxf(1.0, p.hp - p.max_hp * 0.5)
		Buffs.add("nakil", float(s["recover"]), {"speed": 0.8, "melee": 0.8})
		Hud.banner("HÜCRE REDDEDİLDİ", "Beden Senju dokusunu reddetti — doku öldü, sen zor kurtuldun", Color(0.8, 0.3, 0.3))
		return
	p.hp = maxf(1.0, p.hp - p.max_hp * float(s["hp"]))
	Buffs.add("nakil", float(s["recover"]), {"speed": 0.85, "melee": 0.85})
	fl["senju_cells"] = true
	if not Progress.has_nature("mokuton"):
		Progress.awaken_nature("mokuton")
	var txt = "Senju hücreleri bedeninde kök saldı. Mokuton artık senin — bedelini chakranla ödeyeceksin."
	var ey = p.combat.modes.eyes if p.combat and p.combat.modes else null
	if ey and ey._both_slots_kind(5):
		txt += "\nEbedi Mangekyō'n Ashura'nın chakrasını hissediyor: açık tuttukça Rinnegan uyanacak."
	Hud.dialog("Hücre Nakli", txt, [])


## Oyuncunun göz hizası (baş kemiğinden; yoksa çömelme yüksekliği)
static func _eye_pos(p: Node3D) -> Vector3:
	var m = p.get("model")
	if m and is_instance_valid(m) and m.get("skel") and m.skel.find_bone("Head") >= 0:
		var t: Transform3D = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Head"))
		return t.origin + Vector3.UP * 0.08 + p.face_dir() * 0.12
	return p.global_position + Vector3.UP * 0.95 + p.face_dir() * 0.15
