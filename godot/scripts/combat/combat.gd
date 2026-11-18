extends Node
## Dövüş çekirdeği (autoload "Combat"): kapsül hitbox testleri, hasar, hit-stop, hasar sayıları, element tablosu.
## Her savaşçı "fighters" grubundadır ve şunları sağlar: team, radius, height, take_hit(info), is_dead()

const BEATS := {"katon": "fuuton", "fuuton": "raiton", "raiton": "doton", "doton": "suiton", "suiton": "katon"}



## Element üstünlüğü (kekkei genkai dahil, bkz. elements.gd) x hava etkisi (yağmur)
## ---------------------------------------------------------------- kontrol (stun/bağlama) azalan getirisi
## Aynı hedefe 8 sn içinde art arda: süre %100 -> %60 -> %35, dördüncüde 4 sn direnç.
## Kesintisiz kontrol en fazla 3 sn sürer; sonra hedef kurtulur ve 3 sn dirençli olur ("stun at kes" yok).
## Yeni dövüş kuralları (sendeletme, kombo dalları, kombodan jutsuya geçiş, zarsız Kawarimi / blok, yere düşme-kalkma...).
## Arenada olgunlaştı; kullanıcı 2026-11-15'te ana oyuna alınmasını istedi: artık her yerde açık.
var storm := true
const CC := ["stun", "bind", "frozen", "fear", "sleep", "paralyze"]
const CC_MAX := 3.0


## ---------------------------------------------------------------- tek atma (one-shot) güce göre
## Kullanıcı 2026-11-09: "Jigokudō gibi tek atan skilleri güce göre dengeleyelim; adam benden güçlüyse tek atmasın".
## Ortak kural (oyuncu = düşman, AI eşitliği): tek vuruşta canın %60'ından fazlasını götüren darbe ya da execute
## (Kamui, mühür, ruh sökme...) yalnız hedef saldırandan güçsüz/eşitse tam işler. Hedef güçlüyse darbe can oranına
## kırpılır: güç oranı r = saldıran/hedef -> en fazla max_hp * 0.6 * r² (en az %8). Güç: oyuncu Mastery.power, NPC level.
func power_of(n: Node) -> float:
	if n is Player:
		return float(Mastery.power(Game.profile)) if not Game.profile.is_empty() else 1.0
	var lv = n.get("level") if is_instance_valid(n) else null
	return float(lv) if lv != null else 1.0


func execute_ok(atk: Node, target: Node) -> bool:
	if not is_instance_valid(atk) or not is_instance_valid(target) or atk == target:
		return true
	return power_of(target) <= power_of(atk)


## take_hit başında: tek atan darbeyi güce göre kırpar (gerekirse kopya döndürür)
func cap_one_shot(target: Node, info: Dictionary) -> Dictionary:
	var atk = info.get("attacker")
	var mx = float(target.get("max_hp")) if target.get("max_hp") != null else 0.0
	if mx <= 0.0 or not is_instance_valid(atk) or atk == target:
		return info
	var dmg = float(info.get("dmg", 0.0))
	if dmg < mx * 0.6 and not bool(info.get("execute", false)):
		return info
	if execute_ok(atk, target):
		return info
	var r = power_of(atk) / maxf(power_of(target), 1.0)
	var out = info.duplicate()
	out["dmg"] = minf(maxf(dmg, mx * 0.6), mx * maxf(0.6 * r * r, 0.08))
	out.erase("execute")
	if float(target.get_meta("_os_pop", 0.0)) < Game.now():
		target.set_meta("_os_pop", Game.now() + 2.0)
		popup_text(target.global_position + Vector3.UP * 2.4, "Direndi!", Color(1.0, 0.8, 0.4))
	return out


## Jinton: Mikiri (Hız salımı): pencere açıkken gelen darbe bulanık bir yan adımla boşa çıkar (en çok "mikiri_n" darbe).
## Oyuncu ve düşman aynı (take_hit başında çağrılır). "sure" darbeler (kaçınılamaz) işlemez. true = kaçtı.
func speed_dodge(target: Node, info: Dictionary) -> bool:
	if target.has_meta("olta_uke") and load("res://scripts/combat/fx/chakra_oltasi_fx.gd").parry(target, info):
		return true   # Chakra oltası: Sao-uke
	if load("res://scripts/combat/fx/mugen_kogai_fx.gd").absorb(target, info):
		return true   # Mugen Kōgai: chakralı vuruş yutuldu
	if target.has_meta("kuro_uke") and load("res://scripts/combat/fx/kurosawa_fx.gd").parry(target, info):
		return true   # Kurosawa: Uke-kamae
	if not is_instance_valid(target) or int(target.get_meta("mikiri_n", 0)) <= 0 or float(target.get_meta("mikiri_t", 0.0)) < Game.now() or info.get("sure", false):
		return false
	target.set_meta("mikiri_n", int(target.get_meta("mikiri_n")) - 1)
	var atk = info.get("attacker")
	var from: Vector3 = (atk as Node3D).global_position if atk is Node3D and is_instance_valid(atk) else target.global_position - Vector3.FORWARD
	var v: Vector3 = target.global_position - from
	v.y = 0.0
	var side = Vector3(-v.z, 0, v.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	FX.afterimage(target, 0.5, 0.35)
	var p0: Vector3 = target.global_position
	var p1: Vector3 = p0 + side * 1.8
	p1.y = Game.ground_height(p1.x, p1.z)
	target.global_position = p1
	for q in 3:
		var o = Vector3.UP * (0.4 + q * 0.5)
		WindFX.streak(func(u: float) -> Vector3: return p0.lerp(p1, u) + o, 0.15, 0.05, Color(0.95, 0.97, 1.0, 0.7), 0.0, 5)
	popup_text(p1 + Vector3.UP * 2.1, "Iska!", Color(0.75, 0.9, 1.0))
	Sfx.play("whoosh", p1, 1.7)
	return true


## Shinken Shirahadori (kanon: çıplak avuçlarla bıçağı yakalama): pencere açıkken gelen silahlı yakın darbe boşa çıkar,
## saldıran sersemler. Oyuncu ve düşman aynı (take_hit başında çağrılır). true = darbe yakalandı.
func shirahadori_catch(target: Node, info: Dictionary) -> bool:
	if not is_instance_valid(target) or float(target.get_meta("shirahadori_t", 0.0)) < Game.now() or not bool(info.get("melee", false)):
		return false
	var atk = info.get("attacker")
	var armed = bool(info.get("blade", false))
	if not armed and atk is Enemy:
		var lk = atk.get("look")
		armed = lk is Dictionary and String(lk.get("weapon_r", "")) != ""
	if not armed and atk is Player:
		armed = not Gear.weapon(Game.profile).is_empty() and bool(Game.profile.get("weapon_drawn", false))
	if not armed:
		return false
	target.remove_meta("shirahadori_t")
	popup_text(target.global_position + Vector3.UP * 2.4, "Shirahadori!", Color(1.0, 0.9, 0.6))
	FX.hit_spark(target.global_position + Vector3.UP * 1.3, Color(1.0, 0.95, 0.8), 1.2)
	Sfx.play("clash", target.global_position, 1.1)
	if is_instance_valid(atk) and atk.has_method("apply_status"):
		atk.apply_status("stun", 1.3)
	return true


## Silahsız vuruşta eller sıkılı yumruk (kullanıcı: yumruklar parmak ucuyla atılıyordu). Avuç/parmakla vurulan tarzlar açık kalır:
## Jūken (Hakke), tıbbi chakra neşteri, kâğıt, mürekkep, kil, kukla ipleri. Oyuncu ve düşman aynı (AI eşitliği).
const PALM_STYLES := ["style_juken", "style_tip", "style_kagit", "style_sumi", "style_kil", "style_akasuna"]
func punch_fist(model, style_id: String, armed: bool, dur: float) -> void:
	if model == null or not is_instance_valid(model) or model.get("overlay") == null:
		return
	var ov = model.overlay
	if armed and "weapons" in model and not (model.weapons as Array).is_empty() and (model.weapons as Array).all(func(w): return String(w["kind"]) == "worn"):
		armed = false   # kolluk (Raikage no Kote): kolda, eller boş -> sıkılı yumruk
	if armed or style_id in PALM_STYLES:
		return
	var tok = randi()
	ov.set_meta("fist_tok", tok)
	ov.fist["Right"] = 1.0
	ov.fist["Left"] = 1.0
	get_tree().create_timer(maxf(0.2, dur)).timeout.connect(func():
		if is_instance_valid(ov) and int(ov.get_meta("fist_tok", -1)) == tok:
			if float(ov.fist.get("Right", 0.0)) == 1.0:
				ov.fist.erase("Right")
			if float(ov.fist.get("Left", 0.0)) == 1.0:
				ov.fist.erase("Left"))


## Güç farkı (kanon: güçlü ninja zayıfın bağını / yavaşlatmasını kırar). Tekniği yapan hedeften zayıfsa süre güç oranı kadar
## kısalır (Güç 30 -> Güç 80: x0.375, en az x0.2); eşit ya da güçlüyse değişmez. Oyuncu ve düşman aynı kural.
## Kaynak: az önce jutsu yapan (Jutsu.execute) ya da hedefe son vuran (take_hit).
var cc_src: Node = null
var cc_src_t := -99.0
const SLOWS := ["slow", "mud", "chill", "chilled"]


func note_caster(c: Node) -> void:
	cc_src = c
	cc_src_t = Time.get_ticks_msec() / 1000.0


func note_hit(target: Node, info: Dictionary) -> void:
	var a = info.get("attacker")
	if a != null and is_instance_valid(a) and a != target:
		target.set_meta("hit_by", weakref(a))
		target.set_meta("hit_by_t", Time.get_ticks_msec() / 1000.0)


func cc_power_k(n: Node) -> float:
	var now = Time.get_ticks_msec() / 1000.0
	var src: Node = null
	if cc_src != null and is_instance_valid(cc_src) and now - cc_src_t < 2.5 and cc_src != n and hostile(cc_src, n):
		src = cc_src
	elif n.has_meta("hit_by") and now - float(n.get_meta("hit_by_t", -99.0)) < 4.0:
		src = (n.get_meta("hit_by") as WeakRef).get_ref()
	if src == null or not is_instance_valid(src):
		return 1.0
	return clampf(power_of(src) / maxf(power_of(n), 1.0), 0.2, 1.0)


func cc_dur(n: Node, kind: String, d: float) -> float:
	if d <= 0.0:
		return d
	if kind in ["fear", "kokuangyo"] and load("res://scripts/combat/fx/chakura_yoroi_fx.gd").stops_genjutsu(n):
		return 0.0   # Chakura no Yoroi: genjutsu tutmaz
	if kind in SLOWS:
		return d * cc_power_k(n)
	if not kind in CC:
		return d
	var pk = cc_power_k(n)
	if pk < 0.999:
		d *= pk
		if float(n.get_meta("_ccp_pop", 0.0)) < Time.get_ticks_msec() / 1000.0:
			n.set_meta("_ccp_pop", Time.get_ticks_msec() / 1000.0 + 3.0)
			_cc_pop(n, "Kırdı!")
	# kanon teknikler ortak sınırdan muaf (kullanıcı kuralı: anime neyse o) — ör. Kagemane chakra yettikçe tutar
	if kind == "bind" and (n.has_meta("kagemane_hold") or n.has_meta("chibaku_hold") or n.has_meta("gaki_hold")):
		return d
	var now = Time.get_ticks_msec() / 1000.0
	if now < float(n.get_meta("cc_imm", 0.0)):
		_cc_pop(n, "Direnç!")
		return 0.0
	var held = false
	for k in CC:
		if n.has_status(k):
			held = true
	if held:
		if now - float(n.get_meta("cc_start", now)) > CC_MAX:
			n.set_meta("cc_imm", now + 3.0)
			n.set_meta("cc_n", 0)
			_cc_free(n)
			_cc_pop(n, "Kurtuldu!")
			return 0.0
		return d
	var cnt = int(n.get_meta("cc_n", 0)) if now - float(n.get_meta("cc_last", -99.0)) < 8.0 else 0
	if cnt >= 3:
		n.set_meta("cc_imm", now + 4.0)
		n.set_meta("cc_n", 0)
		_cc_pop(n, "Direnç!")
		return 0.0
	n.set_meta("cc_n", cnt + 1)
	n.set_meta("cc_last", now)
	n.set_meta("cc_start", now)
	return d * [1.0, 0.6, 0.35][cnt]


func _cc_free(n: Node) -> void:
	var sts = n.get("statuses")
	if sts is Dictionary:
		for k in CC:
			sts.erase(k)
	if n.get("input_locked") != null:
		n.input_locked = 0.0
	if n is Node3D:
		FX.ring((n as Node3D).global_position + Vector3.UP, Color(0.7, 0.9, 1.0), 3.0, 0.3)


func _cc_pop(n: Node, txt: String) -> void:
	var now = Time.get_ticks_msec()
	if now - int(n.get_meta("cc_pop", 0)) > 1500 and n is Node3D:
		n.set_meta("cc_pop", now)
		popup_text((n as Node3D).global_position + Vector3.UP * 2.3, txt, Color(0.7, 0.9, 1.0))


## ---------------------------------------------------------------- jutsu hasar dengesi
## data/balance.json: her jutsunun ölçülen toplam hasarını rütbesinin hedefine çeken çarpan (tests/dbg_jdmg.gd + tools/balance.py)
var _bal := {}


func jutsu_factor(info: Dictionary) -> float:
	if info.get("melee", false):
		return 1.0
	var a = info.get("attacker")
	if a == null or not is_instance_valid(a) or not a.has_meta("jid"):
		return 1.0
	if Time.get_ticks_msec() / 1000.0 - float(a.get_meta("jid_t", 0.0)) > 12.0:
		return 1.0
	if _bal.is_empty():
		var f = FileAccess.open("res://data/balance.json", FileAccess.READ)
		_bal = JSON.parse_string(f.get_as_text()) if f else {"_": 1}
	return float(_bal.get(String(a.get_meta("jid")), 1.0))


## Hasara göre bekleme KALDIRILDI (kullanıcı 2026-11-08: "güce dayalı cooldown'u kaldır" — alan jutsusu/efsane kademe/modlarla
## beklemeler dakikalara uzuyordu). Bekleme yalnız rütbe süresi (jutsu_cd). Oyuncu ve AI aynı kural.
const DMG_CD := false
func note_jutsu_dmg(atk, info: Dictionary, dmg: float) -> void:
	if not DMG_CD:
		return
	if info.get("melee", false) or atk == null or not is_instance_valid(atk) or not atk.has_meta("jid") or dmg <= 0.0:
		return
	var jid = String(atk.get_meta("jid"))
	if atk is Player:
		if atk.combat:
			atk.combat.note_jutsu_dmg(jid, dmg)
	elif atk.has_method("note_jutsu_dmg"):
		atk.note_jutsu_dmg(jid, dmg)


## Hasar -> toplam bekleme (sn): güç çarpanına bölünmüş ~800 hasar -> ~60 sn
static func dmg_cd(dmg: float, power_mult: float) -> float:
	return 4.0 + dmg / maxf(1.0, power_mult) * 0.07


## ---------------------------------------------------------------- jutsu bekleme süresi (oyuncu ve düşman aynı kural)
## Rütbeye (kademe) göre taban; verideki süre yalnız kademe ortalamasına göre ±%20-40 karakter katar
const CD_TIER := [4.0, 6.0, 9.0, 12.0, 18.0, 28.0]
const CD_AVG := [5.5, 5.2, 8.0, 11.5, 16.3, 35.5]
const CD_UTIL := ["transform", "stealth", "sensor", "utility", "heal", "revive", "teleport", "clone", "counter", "summon"]


func jutsu_cd(j: Dictionary) -> float:
	if j.has("bijuu") or String(j.get("virtual", "")) != "":
		return float(j.get("cd", 6.0))   # göz / canavar teknikleri kendi süresini kullanır
	var t = clampi(int(j.get("tier", 2)), 0, 5)
	var raw = float(j.get("cd", CD_AVG[t]))
	if String(j.get("shape", "")) in CD_UTIL:
		return maxf(raw, CD_TIER[t])
	return snappedf(CD_TIER[t] * clampf(raw / CD_AVG[t], 0.8, 1.4), 0.5)


## Blok jutsuya karşı: küçük jutsu çoğunlukla bloklanır, büyük jutsu bloğu deler (geçen hasar oranı)
const BLOCK_PASS := [0.25, 0.3, 0.4, 0.55, 0.75, 0.9]


func block_pass(info: Dictionary, melee_pass: float) -> float:
	if info.has("tier"):
		return BLOCK_PASS[clampi(int(info["tier"]), 0, 5)]
	return melee_pass


func element_mult(atk: String, dfn: String) -> float:
	return Elements.mult(atk, dfn) * Elements.env_mult(atk)


## Bir noktanın savaşçının kapsülüne (boyutuna göre) değip değmediği
func capsule_hit(point: Vector3, f: Node3D, extra: float) -> bool:
	if f.has_method("hit_test"):  # dev canavarlar: parça kutularıyla isabet
		return f.hit_test(point, extra)
	var base = f.global_position
	var h: float = f.height
	var y = clampf(point.y, base.y + f.radius, base.y + h - f.radius)
	var c = Vector3(base.x, y, base.z)
	return point.distance_to(c) <= f.radius + extra


## Yere devirme kuralı (oyuncu + NPC ortak): yalnız tekniği gerçekten havaya kaldıran (launch >= 3) ya da çok sert iten
## (knock >= 14) vuruş devirir; diğer ağır vuruşlar sendeletir (eskiden her jutsu vuruşu yere atıyordu)
## Kawarimi kütüğü: kişinin durduğu yerde, göğüs hizasında belirir; darbenin yönüne devrilip yere düşer, bir kez seker, sonra kaybolur.
## Kabuklu gövde + iki ucunda açık renk kesit (oyuncu ve düşman aynısını kullanır).
func kawarimi_log(at: Vector3, push := Vector3.ZERO) -> void:
	var root = Node3D.new()
	var body = MeshInstance3D.new()
	var c = CylinderMesh.new()
	c.top_radius = 0.2; c.bottom_radius = 0.22; c.height = 1.1; c.radial_segments = 12
	c.material = Props.toon_color(Color(0.42, 0.28, 0.16))
	body.mesh = c
	root.add_child(body)
	for sy in [-1.0, 1.0]:
		var cap = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.185 if sy > 0.0 else 0.205; cm.bottom_radius = cm.top_radius; cm.height = 0.02; cm.radial_segments = 12
		cm.material = Props.toon_color(Color(0.84, 0.7, 0.46))
		cap.mesh = cm
		cap.position.y = sy * 0.555
		root.add_child(cap)
	get_tree().current_scene.add_child(root)
	var d = Vector3(push.x, 0, push.z)
	d = d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1).rotated(Vector3.UP, randf() * TAU)
	var gy = at.y
	root.global_position = at + Vector3.UP * 1.0
	root.rotation.y = atan2(d.x, d.z)   # devrilme ekseni: darbe yönüne doğru yatar
	var land = at + d * 0.9 + Vector3.UP * 0.22
	land.y = gy + 0.22
	var tw = root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "rotation:x", PI * 0.5, 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(root, "global_position:x", land.x, 0.38)
	tw.tween_property(root, "global_position:z", land.z, 0.38)
	tw.tween_property(root, "global_position:y", land.y, 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(false)
	tw.tween_callback(func(): Sfx.play("hit_heavy", land, 1.5, 0.35))
	tw.tween_property(root, "global_position:y", land.y + 0.16, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "global_position:y", land.y, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.3)
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(root.queue_free)


## Kombo sendelemesi (arena kuralları): saldıran kombonun ortasındaysa, yediren darbe hangi yoldan gelirse gelsin (silah, tarzın
## özel etkisi, ek darbe) rakip saldıranın SIRADAKİ vuruşuna kadar sendeler — ara vermeden sürdürülen kombo kopmaz.
## Kombonun son vuruşunda / kombo dışında 0 döner (olağan sendeleme süresi).
## Kombo ortasındaki darbe (arena kuralları): hangi yoldan gelirse gelsin (tarzın gölgesi, yılanı, zinciri, gecikmeli etkisi)
## rakibi sendeletir ve erişilemeyecek kadar uzağa / yükseğe atmaz; tam fırlatma bitiriş vuruşuna ve kombo dallarına kalır.
func combo_shape(info: Dictionary) -> Dictionary:
	if not storm or info.get("juggle", false) or info.get("force_down", false) or combo_stun(info.get("attacker")) <= 0.0:
		return info
	info = info.duplicate()
	info["combo_hold"] = true
	info["knock"] = minf(float(info.get("knock", 2.0)), 4.5)
	if float(info.get("launch", 0.0)) > 2.5:
		info["launch"] = 2.5   # kombo ortasında yere serilmez (yerdeki rakibe kombo sürmez, kalkarken dokunulmaz): ayakta sendeler
	return info


func combo_stun(atk) -> float:
	if atk == null or not is_instance_valid(atk):
		return 0.0
	if atk is Player:
		var pc = atk.combat
		if pc == null or pc.action != "attack" or pc.air_attack or pc.branch != "" or pc.step < 0 or pc.step >= pc.COMBO.size() - 1:
			return 0.0
		return clampf(float(pc._combo(pc.step)["dur"]) - float(pc.t) + float(pc._combo(pc.step + 1)["hit"]) + 0.6, 0.0, 2.3)
	if atk is Enemy and atk.state == "attack" and not atk.key_step.is_empty() and atk.combo_left > 1 and atk.key_step.get("mv", {}).is_empty():
		var sts: Array = atk.KEYED.steps(String(atk.key_step["id"]))
		var i = int(atk.key_step["i"])
		var spd0 = float(sts[i]["len"]) / maxf(0.05, float(atk.key_step["len"]))
		return clampf(float(atk.key_step["len"]) - float(atk.state_t) + float(sts[(i + 1) % sts.size()]["hit"]) / spd0 + 0.6, 0.0, 2.3)
	return 0.0


## Saldıranın vuruşa ne kadar önce başladığı (sn): savunan, hazırlığı görebildiyse bloklar. Fırlatılan / jutsu darbesi: hep görülür.
func windup_of(atk) -> float:
	if atk == null or not is_instance_valid(atk):
		return 99.0
	if atk is Player:
		return float(atk.combat.t) if atk.combat and atk.combat.action == "attack" else 99.0
	if "state" in atk and "state_t" in atk and atk.state == "attack":
		return float(atk.state_t)
	return 99.0


## Yere çarpma anı (düşen dövüşçü): toz, yer halkası, tok ses; sert çakılmada toprak parçaları + sarsıntı
func down_impact(who: Node3D, hard: bool) -> void:
	var at = who.global_position
	FX.dust(at, 1.3 if hard else 0.8)
	FX.ring(at + Vector3.UP * 0.05, Color(0.9, 0.86, 0.75), 4.5 if hard else 2.6, 0.3)
	Sfx.play("hit_heavy", at, 0.7 if hard else 0.9, 0.9 if hard else 0.6)
	if hard:
		VFX.debris(at + Vector3.UP * 0.1, Color(0.45, 0.38, 0.28), 10, 6.0, 0.22)
		if Game.world and Game.player and at.distance_to(Game.player.global_position) < 25.0:
			Game.world.env.add_shake(0.5)


func knocks_down(info: Dictionary) -> bool:
	return float(info.get("launch", 0.0)) >= 3.0 or float(info.get("knock", 0.0)) >= 14.0


## Oyuncunun yanındaki savaşan kişi sayısı (oyuncu dahil): 40 m içinde yaşayan takım arkadaşı / dost / görev müttefiki.
## Klon, çağrı, yapı sayılmaz. Ninja düşman grupları bu kadar kişi gelir (yalnızken 1, bir dostla 2 ...): 3-4 kişinin
## yalnız oyuncuyu sersemletip kilitlemesi (stunlock) adil değildi.
func party_size() -> int:
	var pl = Game.player
	if pl == null:
		return 1
	var n = 1
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == pl or not is_instance_valid(f) or f.get("team") != "player":
			continue
		if f is ShadowClone or f is Summon or f is ClanConstruct or f.is_dead():
			continue
		if (f as Node3D).global_position.distance_to(pl.global_position) < 40.0:
			n += 1
	return n


## Ninja grubunun boyu: takım sayısı kadar, en çok "cap" (olayın eski üst sınırı)
func foe_count(cap: int) -> int:
	return clampi(party_size(), 1, maxi(1, cap))


## YAKALANMA (kanon: büyük teknik tetikteki rakibe değmez; isabeti açık getirir — Lee'nin havaya kaldırıp Omote Renge'si,
## Naruto'nun Neji'ye alttan / klonla gelişi, Kakashi'nin Zabuza'yı köpeklerle tutup Chidori'si). Yakalanmış rakip
## büyük jutsudan kaçamaz: sersem / bağlı / donmuş / uykuda / korkuda, sendeliyor / yerde / havada savrulmuş,
## kendi saldırısının ya da mühürünün içinde, ya da saldıran arkasında. Oyuncu ve düşman aynı.
## KALKAN (kullanıcı 2026-11-16: "alınan hasar -%" indirimleri kaldırıldı). Kanon savunma teknikleri yüzde indirim değil:
##  · fiziksel engel (Susanoo, kum / kemik / kristal / taş zırh, kubbe, duvar, kalkan) darbeyi EMER, kırılınca söner
##  · içinden geçirme (Kamui, yerin altı, su beden, ikame beden, Yata aynası; eski armor <= 0.05) süre boyunca darbe boşa gider
##  · güç modları (Bilge, kuyruk örtüsü, Sekiz Kapı, Karma, yemek, tapınak...; melee/speed/jutsu artıranlar) indirim almaz
## Buffs.add / Fighter.add_buff her armor < 1 buff'ı buradan geçirir; kalkan buff'ın ömrüne bağlıdır. Oyuncu ve düşman aynı.
const MODE_KEYS := ["melee", "speed", "jutsu"]
const ARMOR_FORMS := ["kessho_yoroi", "bone_armor", "domu", "raiton_armor", "yoton_yoroi", "raigeki_no_yoroi", "iwa_no_yoroi", "koka",
	"suna_no_yoroi", "nenkin_yoroi", "hiruko", "jugo_kalkan", "kurogane_tsubasa"]
func armor_to_shield(n: Node, bname: String, mods: Dictionary) -> Dictionary:
	var a = float(mods.get("armor", 1.0))
	if a >= 1.0:
		return mods
	mods = mods.duplicate()
	mods.erase("armor")
	var mode := false
	for k in MODE_KEYS:
		if float(mods.get(k, 1.0)) > 1.0:
			mode = true
	if (mode and not bname in ARMOR_FORMS) or n == null or not is_instance_valid(n):
		return mods
	if a <= 0.05:
		set_shield(n, bname, -1.0)
	else:
		set_shield(n, bname, float(n.get("max_hp")) * (1.0 - a) * 0.6)
	if not mods.has("_desc"):
		mods["_desc"] = "kalkan: darbeyi emer, kırılınca söner" if a > 0.05 else "darbeler boşa gider"
	return mods


## hp < 0: içinden geçirme (her darbe boşa). regen: darbe almadan 3 sn sonra saniyede %12 dolar (Susanoo yeniden şekillenir).
func set_shield(n: Node, bname: String, hp: float, regen := false) -> void:
	var sh: Dictionary = n.get_meta("shields", {})
	sh[bname] = {"hp": hp, "max": hp, "regen": regen, "t": 0.0}
	n.set_meta("shields", sh)


func _shield_alive(n: Node, bname: String) -> bool:
	if n is Player:
		return Buffs.active.has(bname)
	return "buffs" in n and (n.buffs as Dictionary).has(bname)


## Gelen hasarı kalkanlarla karşılar; kalanı döner (<= 0: darbe tamamen tutuldu, tepki yok).
func absorb(n: Node, dmg: float) -> float:
	if dmg <= 0.0 or not n.has_meta("shields"):
		return dmg
	var sh: Dictionary = n.get_meta("shields")
	var now = Game.now()
	var pos: Vector3 = (n as Node3D).global_position + Vector3.UP * 1.5
	for bname in sh.keys():
		if not _shield_alive(n, bname):
			sh.erase(bname)
			continue
		var s: Dictionary = sh[bname]
		if float(s["max"]) < 0.0:
			popup_text(pos, "Iska!", Color(0.75, 0.9, 1.0))
			return 0.0
		if s["regen"] and float(s["hp"]) < float(s["max"]):
			s["hp"] = minf(float(s["max"]), float(s["hp"]) + float(s["max"]) * 0.12 * maxf(0.0, now - float(s["t"]) - 3.0))
		s["t"] = now
		if float(s["hp"]) <= 0.0:
			continue
		var took = minf(float(s["hp"]), dmg)
		s["hp"] = float(s["hp"]) - took
		dmg -= took
		if float(s["hp"]) <= 0.0:
			popup_text(pos, "Kalkan kırıldı!", Color(1.0, 0.6, 0.4))
			FX.hit_spark(pos, Color(0.7, 0.85, 1.0), 1.6)
			Sfx.play("hit_heavy", pos, 0.8)
		if dmg <= 0.0:
			FX.hit_spark(pos, Color(0.6, 0.8, 1.0), 0.8)
			return 0.0
	if sh.is_empty():
		n.remove_meta("shields")
	return dmg


## Chakra tükenmesi (kanon: dövüşü chakra bitirir — Kakashi Sharingan'dan sonra yığıldı, Sasuke chakrası bitince
## Orochimaru'yu tutamadı): chakrası %12'nin altındaki ninja yavaşlar (x0.8). Kawarimi chakra ister (KAWARIMI_COST).
## Oyuncu ve düşman aynı (Player.status_speed, Fighter.step_move).
const KAWARIMI_COST := 8.0
func exhaust_k(n: Node) -> float:
	if not ("chakra" in n) or not ("max_chakra" in n) or float(n.max_chakra) <= 20.0:
		return 1.0
	if float(n.chakra) < float(n.max_chakra) * 0.12:
		if not n.has_meta("tukendi"):
			n.set_meta("tukendi", true)
			popup_text((n as Node3D).global_position + Vector3.UP * 2.3, "Chakra tükendi", Color(0.6, 0.75, 1.0))
		return 0.8
	if n.has_meta("tukendi") and float(n.chakra) > float(n.max_chakra) * 0.2:
		n.remove_meta("tukendi")
	return 1.0


## GİZLİLİK (2026-11-16): "stealth" buff'ları (Kakuremino, Suiton Kakuremino, yer altı, Meisaigakure...) eskiden yalnız
## "Gizlisin" yazıyordu, hiçbir düşman / gözcü bakmıyordu. Ortak kural — gizli hedef görülmez, şunlar hariç:
##  · saldırırken / mühür dizerken (gizlilik bozulur) ya da 2.5 m'den yakında
##  · Byakugan / Rinnegan / Tenseigan / Jōgan her gizlenmeyi görür; Sharingan chakra gizlenmesini görür ama örtüyü (cloth) değil
##  · örtü (Kakuremino) kokuyu saklamaz: Inuzuka koklar
##  · örtünün kalitesi (stealth 0..1, ustalıktan) bakanın ustalığından düşükse usta ninja seçer (Konohamaru'nun yatay desenli örtüsü)
## Oyuncu ve düşman aynı (düşmanın gizlenmesi oyuncunun dostlarını / takımını da aynı kuralla şaşırtır).
func stealth_of(n: Node) -> float:
	var q := 0.0
	if n is Player:
		for b in Buffs.active.values():
			q = maxf(q, float(b["mods"].get("stealth", 0.0)))
	elif "buffs" in n:
		for b in (n.buffs as Dictionary).values():
			q = maxf(q, float(b["mods"].get("stealth", 0.0)))
	return q


## ALGILAMA (kanon algılayıcı ninja): algılama tekniği (Kanchi, Kagura Shingan, Kekkai Tengai Hōjin...) atanın menzili
## içinde gizlenmiş herkes görülür. Oyuncu ve düşman aynı; düşman algılayıcı oyuncunun gizlenmesini bozar.
func start_sensing(n: Node, r: float, dur: float) -> void:
	n.set_meta("sense_r", r)
	n.set_meta("sense_until", Game.now() + dur)


func sensing_r(n: Node) -> float:
	if n == null or not is_instance_valid(n) or Game.now() > float(n.get_meta("sense_until", 0.0)):
		return 0.0
	return float(n.get_meta("sense_r", 0.0))


func hidden_from(viewer: Node, n: Node) -> bool:
	if viewer == null or n == null or not is_instance_valid(viewer) or not is_instance_valid(n):
		return false
	if get_tree().has_group("kemuri_bulut") and load("res://scripts/combat/fx/kemuridama_fx.gd").veiled(viewer, n):
		return true
	var q = stealth_of(n)
	if q <= 0.0:
		return false
	var dv = (viewer as Node3D).global_position.distance_to((n as Node3D).global_position)
	if dv < 2.5:
		return false
	if dv <= sensing_r(viewer):
		return false   # algılayıcı chakrayı hisseder: göze dayalı gizlenme ondan kaçamaz (kanon: Karin, Kanchi)
	if n is Player:
		var pc = n.get("combat")
		if pc != null and String(pc.action) in ["attack", "cast", "throw"]:
			return false
	elif "state" in n and String(n.state) in ["attack", "cast", "throw"]:
		return false
	var cloth = String(n.get_meta("stealth_kind", "")) == "cloth"
	var ek = int(viewer.get_meta("eyes").get("kind", 0)) if viewer.has_meta("eyes") else 0
	if ek in [2, 6, 7, 8]:
		return false
	if ek in [1, 4, 5] and not cloth:
		return false
	if cloth and viewer.get("arch") is Dictionary and String(viewer.arch.get("clan", "")) == "inuzuka":
		return false
	var vs = float(viewer.get("skill")) if viewer.get("skill") != null else 0.5
	return q >= 1.0 or q > vs


## Bağın kaynağı: bağlayan jutsu (cc_src'nin son tekniği). Nawanuke yalnız fiziksel bağı çözer (kanon: ip / tel / düğüm).
func tag_bind(n: Node) -> void:
	var jid := ""
	var now = Time.get_ticks_msec() / 1000.0
	if cc_src != null and is_instance_valid(cc_src) and now - cc_src_t < 3.0 and cc_src.has_meta("jid"):
		jid = String(cc_src.get_meta("jid"))
	n.set_meta("bind_jid", jid)


## Fiziksel bağ mı: element yok (gölge / kum / ağaç / su / ateş bağları elementli), Nara / Sabaku / Senju klan tekniği değil,
## genjutsu değil. Kaynağı bilinmeyen bağ (alet: tel, ip, kusari) fiziksel sayılır.
func bind_physical(n: Node) -> bool:
	var jd: Dictionary = Data.jutsu.get(String(n.get_meta("bind_jid", "")), {})
	if jd.is_empty():
		return true
	if String(jd.get("element", "")) != "" or String(jd.get("category", "")) in ["genjutsu", "dojutsu", "senjutsu", "kekkei_genkai"]:
		return false
	return not String(jd.get("clan", "")) in ["nara", "sabaku", "senju", "uzumaki", "aburame"]


const CAUGHT_STATUS := ["stun", "bind", "frozen", "sleep", "fear", "kokuangyo", "mud"]
func caught(n: Node, attacker: Node = null) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("has_status"):
		for s in CAUGHT_STATUS:
			if n.has_status(s):
				return true
	if n is Player:
		var pc = n.get("combat")
		if pc != null and String(pc.action) in ["attack", "cast", "throw", "hitstun", "knockdown", "charge"]:
			return true
	elif "state" in n and String(n.state) in ["attack", "cast", "throw", "hitstun", "knockdown", "charge"]:
		return true
	if attacker is Node3D and is_instance_valid(attacker) and n is Node3D and n.has_method("face_dir"):
		var to_a: Vector3 = (attacker as Node3D).global_position - (n as Node3D).global_position
		to_a.y = 0.0
		if to_a.length() > 0.5 and n.face_dir().dot(to_a.normalized()) < -0.35:   # arkadan (~110°+)
			return true
	return false


func hostile(a: Node, b: Node) -> bool:
	if a == b or b == null or a == null:
		return false
	if a is Prey or b is Prey:   # av hayvanı: yalnız oyuncu (ve klonu / çağrısı) avlar; köy takımları, haydutlar karışmaz
		var o = b if a is Prey else a
		return o == Game.player or o is ShadowClone or (o is Summon and o.get("owner_f") == Game.player)
	var ta = a.get("team"); var tb = b.get("team")
	if ta == null or tb == null:
		return false
	if tb == "dummy" or ta == "dummy":
		return ta != tb
	if ta == "enemy" and tb == "enemy":
		return faction_hostile(String(a.get_meta("faction", "")), String(b.get_meta("faction", "")))
	return ta != tb and ta != "neutral" and tb != "neutral"


## Oyuncuya düşman olanlar kendi aralarında: köy ninjaları/av ekipleri kaçakları ve canavarları avlar; kuyruklu canavar herkese saldırır;
## haydut ve kaçak birbirine dokunmaz (yalnız oyuncuya düşman herkes aynı takımdaydı, köy ninjaları canavara hiç vurmuyordu)
const LAW := ["konoha", "suna", "kiri", "kumo", "iwa", "ame", "hunter", "samurai"]
func faction_hostile(fa: String, fb: String) -> bool:
	if fa == "" or fb == "" or fa == fb:
		return false
	if fa == "beast" or fb == "beast":
		return true
	if (fa in LAW and fb in ["rogue", "akatsuki"]) or (fb in LAW and fa in ["rogue", "akatsuki"]):
		return true
	return false


## Küre içinde kalan düşman savaşçılara vurur. Vurulanları döndürür.
func hit_sphere(attacker: Node3D, center: Vector3, radius: float, info: Dictionary, exclude: Array = []) -> Array:
	var hits: Array = []
	WorldDamage.impact(center, radius, info)   # ağaçlar/evler yanar, devrilir, yıkılır
	if String(info.get("element", "")) == "fuuton" and get_tree().has_group("kemuri_bulut"):
		load("res://scripts/combat/fx/kemuridama_fx.gd").wind(center, radius)   # rüzgâr dumanı dağıtır
	for f in get_tree().get_nodes_in_group("fighters"):
		if f in exclude or not hostile(attacker, f) or f.is_dead():
			continue
		if capsule_hit(center, f, radius):
			var inf = info.duplicate()
			inf["attacker"] = attacker
			inf["_r"] = radius   # alan genişliği: geniş alandan kaçış tam değil, sıyırır (Player.take_hit)
			if not inf.has("dir"):
				var d: Vector3 = f.global_position - attacker.global_position
				d.y = 0
				inf["dir"] = d.normalized() if d.length() > 0.01 else -attacker.global_transform.basis.z
			f.take_hit(inf)
			hits.append(f)
			if inf.get("melee", false):
				_lion_drain(attacker, f)
				if attacker.has_meta("doku_n"):
					load("res://scripts/combat/fx/doku_fx.gd").on_melee(attacker, f)
	if attacker is Player:
		for n in get_tree().get_nodes_in_group("ambient_team"):
			if is_instance_valid(n) and not n.dead and capsule_hit(center, n, radius):
				provoke(n)
	if not hits.is_empty() and info.get("hitstop", 0.0) > 0.0:
		hitstop(info["hitstop"])
	return hits


## Karamatsu no Mai (kanon): kemik dikenli bedene yakın dövüşle vuran kendini saplar — darbenin gücü kadar kendine zarar,
## kemiklere çarpan darbe büyük ölçüde boşa gider. Oyuncu (PlayerModes) ve düşman (Enemy.take_hit) aynı fonksiyonu çağırır.
func larch_counter(def: Node3D, info: Dictionary) -> bool:
	var on = Buffs.has("karamatsu") if def is Player else (def.get("buffs") != null and def.buffs.has("karamatsu"))
	if not on or not info.get("melee", false):
		return false
	var atk = info.get("attacker")
	var dmg = float(info.get("dmg", 0.0))
	info["dmg"] = dmg * 0.25
	if atk is Node3D and is_instance_valid(atk) and atk.has_method("take_hit") and not atk.is_dead():
		var heavy = String(info.get("kind", "light")) == "heavy"
		atk.take_hit({"dmg": dmg * (1.6 if heavy else 1.1) + 6.0, "knock": 4.0, "kind": "heavy" if heavy else "light", "bleed": 3.0,
			"attacker": def, "dir": (atk.global_position - def.global_position).normalized()})
		VFX.debris(atk.global_position + Vector3.UP, Color(0.75, 0.05, 0.05), 8, 5.0, 0.25)
		popup_text(atk.global_position + Vector3.UP * 2.3, "Kemiklere saplandı!", Color(1.0, 0.85, 0.7))
	return true


## Jūho Sōshiken (kanon): aslan başları dokunduğu kişinin chakra ağını emer — oyuncunun chakrası azalır,
## düşmanın (chakra değeri yok) ağı kısa süre kapanır; emen taraf chakra kazanır. Oyuncu ve düşman aynı kural.
func _lion_drain(attacker: Node3D, f: Node3D) -> void:
	var on = Buffs.active.has("juho_soshiken") if attacker is Player else (attacker.get("buffs") != null and attacker.buffs.has("juho_soshiken"))
	if not on or not is_instance_valid(f):
		return
	if f is Player:
		f.chakra = maxf(0.0, f.chakra - 6.0)
	else:
		f.apply_status("sealed", 1.2)
	if attacker is Player:
		attacker.chakra = minf(attacker.max_chakra, attacker.chakra + 4.0)
	FX.burst(f.global_position + Vector3.UP * 1.1, {"amount": 6, "life": 0.35, "tex": FX.tex_spark, "size": 0.35, "vmin": 1.5, "vmax": 3.5, "dir": (attacker.global_position - f.global_position).normalized(),
		"colors": [Color(0.75, 0.9, 1.0, 1), Color(0.35, 0.65, 1.0, 0)]})


## Oyuncu yolda yürüyen köy takımından birine vurdu (tarafsız NPC'ye darbe geçmez): takım saldırıya geçer.
## Kaçaksan zaten avcın — suç sayılmaz; köylüysen "köy takımına saldırı" suçu.
func provoke(n: Node) -> void:
	if not n.is_in_group("ambient_team"):
		return
	var at = get_tree().current_scene.find_child("AmbientTeams", true, false)
	if at != null and at.has_method("provoke"):
		at.provoke(n)


## Dev saldırı alanı: origin (yerde) önündeki yelpaze dilimine giren HER düşmana vurur — boy farkı önemsiz
## (Susanoo, kuyruklu canavar, dev çağrılar: küre isabeti yerdeki küçük hedefi ıskalıyordu).
## half_deg: yelpazenin yarım açısı; reach: yatay menzil; height: origin'den yukarı kapsanan yükseklik.
func hit_zone(attacker: Node3D, origin: Vector3, dir: Vector3, reach: float, half_deg: float, height: float, info: Dictionary, exclude: Array = []) -> Array:
	var hits: Array = []
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	WorldDamage.impact(origin + dir * reach * 0.55, reach * 0.45, info)
	var cmin = cos(deg_to_rad(half_deg))
	if attacker is Player:
		for n in get_tree().get_nodes_in_group("ambient_team"):
			if is_instance_valid(n) and not n.dead and (n.global_position - origin).length() < reach + 1.0:
				provoke(n)
	for f in get_tree().get_nodes_in_group("fighters"):
		if f in exclude or not hostile(attacker, f) or f.is_dead():
			continue
		var v: Vector3 = f.global_position - origin
		var fr: float = f.radius if "radius" in f else 0.5
		if f.has_method("hit_test"):
			fr = maxf(fr, float(f.height) * 0.3)
		if v.y < -3.0 - fr or v.y > height:
			continue
		var vh = Vector3(v.x, 0, v.z)
		var dh = vh.length()
		if dh > reach + fr:
			continue
		if dir != Vector3.ZERO and dh > fr + reach * 0.15 and vh.normalized().dot(dir) < cmin:
			continue
		var inf = info.duplicate()
		inf["attacker"] = attacker
		if not inf.has("dir"):
			inf["dir"] = vh.normalized() if dh > 0.01 else dir
		f.take_hit(inf)
		hits.append(f)
	if not hits.is_empty() and info.get("hitstop", 0.0) > 0.0:
		hitstop(info["hitstop"])
	return hits


func nearest_enemy(from: Node3D, max_d: float, dir := Vector3.ZERO, cone := -1.0) -> Node3D:
	var best: Node3D = null
	var bd = max_d
	for f in get_tree().get_nodes_in_group("fighters"):
		if not hostile(from, f) or f.is_dead():
			continue
		var v: Vector3 = f.global_position - from.global_position
		var d = v.length()
		if d > bd:
			continue
		if get_tree().has_group("kemuri_bulut") and load("res://scripts/combat/fx/kemuridama_fx.gd").veiled(from, f):
			continue
		if dir != Vector3.ZERO and cone > -1.0:
			var vf = Vector3(v.x, 0, v.z).normalized()
			if vf.dot(dir) < cone:
				continue
		bd = d
		best = f
	return best


## Vuruş anında oyunu kısa süre yavaşlat (Storm hissi). Gerçek zamanla ölçülür.
var hitstop_until = 0
var base_time_scale = 1.0  # Sharingan vb. yavaş çekim için
## Algı yavaşlaması (Sharingan / dojutsu modu): dünya yavaşlar, oyuncu NORMAL hızda kalır (telafi çarpanı).
## Vuruş duraksaması (hitstop) telafi edilmez: o an herkes donar.
var self_slow := false


func player_comp() -> float:
	if not self_slow or hitstop_until > 0 or base_time_scale >= 0.999:
		return 1.0
	return 1.0 / maxf(0.1, base_time_scale)


func hitstop(t: float) -> void:
	hitstop_until = maxi(hitstop_until, Time.get_ticks_msec() + int(t * 1000.0))
	Engine.time_scale = 0.05


func _process(_dt: float) -> void:
	if hitstop_until > 0 and Time.get_ticks_msec() >= hitstop_until:
		hitstop_until = 0
		Engine.time_scale = base_time_scale
	elif hitstop_until == 0 and absf(Engine.time_scale - base_time_scale) > 0.001:
		Engine.time_scale = base_time_scale


var quiet := false   # görsel denetim testleri: hasar sayısı/yazı yok


func damage_number(pos: Vector3, amount: float, col := Color(1, 0.9, 0.3), crit := false) -> void:
	if quiet:
		return
	var l = Label3D.new()
	l.text = str(int(round(amount)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0018 if not crit else 0.0026
	l.font_size = 48
	l.outline_size = 12
	l.modulate = col
	l.outline_modulate = Color(0.1, 0.05, 0.05)
	get_tree().current_scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw = l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


func popup_text(pos: Vector3, text: String, col := Color(1, 1, 1)) -> void:
	if quiet:
		return
	var l = Label3D.new()
	l.text = Keys.fix(text)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	l.font_size = 40
	l.outline_size = 10
	l.modulate = col
	get_tree().current_scene.add_child(l)
	pos += Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.4), randf_range(-0.5, 0.5))
	l.global_position = pos
	var tw = l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.0, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
