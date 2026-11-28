class_name Fighter
extends CharacterBody3D
## NPC savaşçılarının tabanı (düşmanlar, klonlar, çağrılar): kapsül hitbox (boyuta göre), arazi takibi,
## hasar/sersemleme/savrulma, durum etkileri, animasyon.

var team = "enemy"
var radius = 0.38
var height = 1.8
var size = 1.0
var max_hp = 100.0
var hp = 100.0
var element = ""
var power = 1.0
var model: CharacterModel
var look = {}
var facing = 0.0
var grounded = true
var state = "idle"
var state_t = 0.0
var statuses = {}  # ad -> kalan süre
var buffs = {}     # ad -> {t, mods}: kendi attığı buff jutsuları (oyuncunun Buffs'ı ile aynı anahtarlar: armor, speed, melee, jutsu, element)
var dead = false
var poise = 0.0  # süper zırh (boss)
## Sersemletme kilidi kırıcı: kısa sürede üst üste sersemletilen savaşçı bir süre sersemlemez ve çevresini iterek kurtulur
## (klonlar ya da sonsuz hafif kombo ile kilitlenmesin)
var stun_meter := 0.0
var stun_last_ms := 0
var stun_armor_ms := 0
var hitstun_len := 0.45   # bu sendelemenin süresi (arena kuralları: saldıranın kombosundaki sıradaki vuruşa kadar sürer)


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = 4
	# dövüşçüler birbirine fizik çarpışması yapmaz (köylüler gibi): 30 kişilik savaşta her birinin her fizik karesinde 29 gövdeyle
	# kayma çözümü ortalamayı 10,6 -> 17 FPS düşürüyordu (2026-11-27 ölçümü). İç içe girmeyi _crowd_push yumuşak itmesi önler.
	collision_mask = 1 | 2
	_cpush_i = randi() % 4
	_cpush_i2 = randi() % 2
	_build_body()


func _build_body() -> void:
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = radius * size
	cap.height = maxf(height * size, cap.radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position.y = height * size * 0.5
	add_child(cs)
	radius *= size
	height *= size
	if model != null and model.get_parent() == null:
		add_child(model)   # adopt_model ile devralınan hazır model
		model.position = Vector3.ZERO
		model.scale = Vector3.ONE * size * float(model.age_scale)
	elif model == null and look != null:
		model = CharacterModel.new()
		add_child(model)
		model.setup(look)
		model.scale = Vector3.ONE * size * float(model.age_scale)   # çocuk klon çocuk boyunda (ölçek yaşı eziyordu)


## NPC düşmana/dövüşçüye dönüşürken onun hazır modelini devralır (add_child'dan ÖNCE çağrılır). Model yeniden kurulmaz:
## köy takımı saldırınca 3-4 model aynı karede sıfırdan kuruluyor, oyun yarım saniye donuyordu.
func adopt_model(src: Node) -> void:
	var m = src.get("model") if src != null and is_instance_valid(src) else null
	if m == null or not is_instance_valid(m) or not (m is CharacterModel) or m.is_queued_for_deletion():
		return
	var y = m.rotation.y
	m.get_parent().remove_child(m)
	m.rotation.y = y
	m.visible = true
	model = m
	src.set_process(false)   # kaynak bu karede silinecek: modelsiz kalan kaynağın kare işleri çalışmasın
	src.set_physics_process(false)
	if src.get("model") != null:
		src.set("model", null)


func is_dead() -> bool:
	return dead


func face_dir() -> Vector3:
	return Vector3(-sin(facing), 0, -cos(facing))


func apply_status(name: String, dur: float) -> void:
	if name in ["fear", "kokuangyo"] and Game.now() < float(get_meta("togarashi_until", 0.0)):
		return
	dur = Combat.cc_dur(self, name, dur)
	if dur <= 0.0:
		return
	statuses[name] = maxf(statuses.get(name, 0.0), dur)
	if name == "bind":
		Combat.tag_bind(self)
		_try_nawanuke()


## Düşmanın Nawanuke'si (oyuncuyla aynı kural: tekniği bilen, fiziksel bağdan 0.5 sn sonra sıyrılır, 5 chakra)
func _try_nawanuke() -> void:
	if not (get("arch") is Dictionary) or not "nawanuke_no_jutsu" in (get("arch").get("jutsu", []) as Array):
		return
	if not Combat.bind_physical(self) or float(get("chakra")) < 5.0:
		return
	get_tree().create_timer(0.5).timeout.connect(func():
		if not is_instance_valid(self) or not has_status("bind") or float(get("chakra")) < 5.0:
			return
		set("chakra", float(get("chakra")) - 5.0)
		statuses.erase("bind")
		Combat.popup_text(global_position + Vector3.UP * 2.2, "Nawanuke!", Color(0.9, 0.85, 0.6)))


func has_status(name: String) -> bool:
	return statuses.get(name, 0.0) > 0.0


## Kendi buff'ı (Buffs.add atan düşmansa buraya yönlendirir)
func add_buff(name: String, dur: float, mods: Dictionary) -> void:
	buffs[name] = {"t": dur, "mods": mods}   # önce kayıt: kalkan buff'ın ömrüne bağlı
	buffs[name]["mods"] = Combat.armor_to_shield(self, name, mods)   # yüzde indirim yok: engel -> kalkan (Buffs.add ile aynı)


func buff_mod(key: String) -> float:
	var v = 1.0
	for b in buffs.values():
		if b["mods"].has(key):
			v *= float(b["mods"][key])
	return v


func take_hit(info: Dictionary) -> void:
	if dead:
		return
	var em = Combat.element_mult(info.get("element", ""), element)
	var react = LazyFx.g("Elements").on_hit(self, info)
	var dmg: float = info.get("dmg", 5.0) * em * react * Combat.jutsu_factor(info) * (1.0 - LazyFx.g("Gear").elem_resist(self, String(info.get("element", ""))))   # set direnci (AI)
	if has_status("marked"):
		dmg *= 1.25   # Dinamik İşaretleme / algılama: işaretli hedef fazla hasar alır
	dmg *= maxf(1.0, buff_mod("armor"))   # yalnız bedel (zırh kırılması); savunma kalkanla (Combat.absorb)
	dmg = Combat.absorb(self, dmg)
	if Cheats.kills(info.get("attacker")):
		dmg = maxf(dmg, hp + 1.0)   # hile: tek vuruşta öldür (yalnız oyuncunun darbesi)
	if dmg <= 0.0:
		return
	if has_status("armor_broken"):
		dmg *= 1.2   # Kabutowari: zırhı kırılan 5 sn fazla hasar alır
	var atk = info.get("attacker")
	if atk is Player:
		var bs = LazyFx.g("Stats").skill(Game.profile, "backstab")
		if bs > 0.0:
			var from_atk = (atk.global_position - global_position)
			from_atk.y = 0
			var unaware = get("target") == null
			if unaware or face_dir().dot(from_atk.normalized()) < -0.3:
				dmg *= 1.0 + bs * 2.0
				Combat.popup_text(global_position + Vector3.UP * (height + 0.8), "ARKADAN!", Color(1, 0.4, 0.8))
	hp -= dmg
	Combat.note_jutsu_dmg(atk, info, minf(dmg, maxf(0.0, hp + dmg)))   # hasara göre bekleme (oyuncu ve AI)
	# Shintenshin: ele geçirilmiş bedene gelen acı, bedenin dışındaki Yamanaka ruhuna da yansır (anime)
	if has_meta("possessed_by"):
		var owner_p = get_meta("possessed_by")
		if is_instance_valid(owner_p) and owner_p is Player and owner_p.hp > 0.0:
			owner_p.hp = maxf(1.0, owner_p.hp - dmg * 0.35)
			Combat.damage_number(owner_p.global_position + Vector3.UP * 2.0, dmg * 0.35, Color(0.8, 0.6, 1.0))
	model.flash(0.9)
	_hit_feedback(info, dmg)
	var col = Color(1, 0.9, 0.3) if info.get("kind", "light") == "light" else Color(1, 0.55, 0.2)
	# element etkinliği: renk + yazı
	var eff = em * react
	if info.get("element", "") != "" and info.get("attacker") is Player and dmg >= 3.0 and absf(react - 1.0) < 0.01:
		if eff >= 1.25:
			col = Color(1, 0.35, 0.15)
			Combat.popup_text(global_position + Vector3.UP * (height + 0.9), "Etkili!", Color(1, 0.6, 0.2))
		elif eff <= 0.8:
			col = Color(0.65, 0.68, 0.75)
			Combat.popup_text(global_position + Vector3.UP * (height + 0.9), "Zayıf...", Color(0.7, 0.72, 0.8))
	Combat.damage_number(global_position + Vector3.UP * (height + 0.3), dmg, col, info.get("kind", "") == "heavy" or eff >= 1.25)
	if float(info.get("poison", 0.0)) > 0.0:
		load("res://scripts/combat/fx/doku_fx.gd").add(self, float(info["poison"]))
	if info.get("burn", 0.0) > 0.0:
		apply_status("burn", info["burn"])
	if info.get("stun", 0.0) > 0.0:
		apply_status("stun", info["stun"])
	if info.get("slow", 0.0) > 0.0:
		apply_status("slow", info["slow"])
	on_damaged(info)
	if hp <= 0.0:
		hp = 0.0
		die(info)
		return
	info = Combat.combo_shape(info)
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	var heavy: bool = info.get("kind", "light") == "heavy" or info.get("launch", 0.0) > 0.0
	# düz vuruş = jutsu olmayan her darbe (yakın dövüş, canavar/klon/bekçi vuruşu, boss taijutsusu): ağır olsa bile yere düşürmez,
	# sersemletmez; yalnız silahın havaya fırlatan bitişi (launch >= 8) düşürür
	var basic: bool = info.get("melee", false) or (not info.has("tier") and String(info.get("element", "")) == "" and float(info.get("stun", 0.0)) <= 0.0)
	if basic and float(info.get("launch", 0.0)) < 8.0 and not info.get("force_down", false):
		heavy = false
		info = info.duplicate()
		info["melee"] = true
	if poise > 0.0 and not heavy:
		return
	if has_meta("kage_of") or get_meta("elite_boss", "") == "S":
		# Kage jutsu yağmurunda kilitlenmez (kök sebep: her jutsu sersemletiyordu -> mod açamıyor, jutsu atamıyor, eriyordu);
		# yalnız her 3. ağır/jutsu darbesinde sersemler ya da düşer, diğerlerinde irkilip devam eder
		var hc = int(get_meta("kage_hits", 0)) + 1
		set_meta("kage_hits", hc)
		if hc % 3 != 0:
			model.flash(0.5)
			velocity += dir * 1.5
			return
	var hold: bool = info.get("combo_hold", false) and float(info.get("knock", 2.0)) <= 0.5
	if not heavy and float(info.get("knock", 2.0)) <= 0.5 and float(info.get("stun", 0.0)) <= 0.0 and not hold:
		return   # sürekli hasar tiki: sersemletmez (kombo ortasındaysa sendeletir: rakip kombodan yürüyüp çıkmasın)
	if info.get("melee", false) and not heavy and not Combat.storm:
		# düz vuruşla stun yok (kullanıcı kuralı): irkilir, itilir ama yaptığını kesmez
		model.flash(0.5)
		velocity += dir * float(info.get("knock", 2.0)) * 0.5 / size
		return
	if info.get("flinch", false):   # klon gibi zayıf vuruş: sadece irkilme, sersemletmez
		model.flash(0.5)
		velocity += dir * 1.5
		return
	# güç farkı (kanon): kendinden çok zayıfın darbesi güçlü ninjayı sersemletmez / yere sermez — hasarı alır ama akışı bozulmaz.
	# Güç oranı 0.6'nın altında hafif darbe hiç sersemletmez, ağır darbe yalnız sendeletir; 0.45'in altında ağır darbe de sersemletmez.
	var atkp = info.get("attacker")
	# düz vuruş bu kuralın dışında: oyuncu her düz vuruşta kesiliyor, rakip de aynı şekilde kesilir
	if atkp != null and is_instance_valid(atkp) and atkp != self and not info.get("execute", false) and not info.get("melee", false):
		var pgap = Combat.power_of(atkp) / maxf(Combat.power_of(self), 1.0)
		if pgap < 0.6:
			if not heavy or pgap < 0.45:
				velocity += dir * float(info.get("knock", 2.0)) * pgap / size
				return
			heavy = false
	var now = Time.get_ticks_msec()
	if now < stun_armor_ms:
		return   # kilit kırıldı: kısa süre sersemlemez (hasar yine alınır)
	# oyuncunun kendi kombosu (5 vuruş + bitiriş) tam oynansın; klon/çoklu saldırı yağmuru kilidi kırar
	# yarı ağırlık yalnız oyuncunun yakın dövüş kombosu için; jutsu yağmuru tam sayılır (eskiden saniyede bir jutsu yiyen düşman hiç kurtulamıyordu)
	var w = 0.55 if info.get("attacker") is Player and info.get("melee", false) else 1.0
	var ch: bool = info.get("combo_hold", false)
	if ch:   # kombo ortası (arena): bir adımın çoklu darbesi tek sayılır, ağır / hafif ayrımı yok — bir kombo kilidi kırmaz
		w = 0.0 if now - stun_last_ms < 300 else 0.55
	if info.get("juggle", false) or hold:
		w = 0.0   # havada sürdürülen kombo kilit sayacına yazılmaz (kaçış: Kawarimi)
	stun_meter = maxf(0.0, stun_meter - (now - stun_last_ms) / 1000.0 * 0.7) + (2.0 if heavy and not ch else 1.0) * w
	stun_last_ms = now
	if stun_meter >= 3.5 and size < 2.5:
		_break_stun()
		return
	state_t = 0.0
	if model and model.get("overlay"):
		# darbe: mühür / sıçrama / blok pozunda kalmasın (o pozda donuyordu)
		for pz in ["seal", "leap", "guard", "cast", "charge"]:
			model.overlay.set_pose(pz, 0.0)
	if heavy and size < 2.5 and Combat.knocks_down(info):
		state = "knockdown"
		velocity = dir * info.get("knock", 8.0) / size + Vector3.UP * (info.get("launch", 0.0) + 3.0)
		model.play("knock", 0.05, 1.2, true)
	else:
		state = "hitstun"
		hitstun_len = maxf(float(info.get("hitstun", 0.62)), Combat.combo_stun(info.get("attacker"))) if Combat.storm else 0.45
		velocity = dir * info.get("knock", 2.0) / size
		model.play("hit" if randf() < 0.5 else "hit_head", 0.04, 1.4, true)


## Kilit kırma: chakra patlamasıyla çevresini iter, 1.6 sn sersemlemez
func _break_stun() -> void:
	stun_meter = 0.0
	stun_armor_ms = Time.get_ticks_msec() + 1600
	state = "chase" if "target" in self else state
	state_t = 0.0
	Combat.popup_text(global_position + Vector3.UP * (height + 0.9), "Kurtuldu!", Color(0.7, 0.9, 1.0))
	FX.ring(global_position + Vector3.UP * 0.9, Color(0.7, 0.9, 1.0), 4.0, 0.35)
	for f in get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(self, f) and not f.is_dead() and f.global_position.distance_to(global_position) < 3.2:
			if f is ShadowClone:
				f.vanish()
			else:
				f.take_hit({"dmg": 4.0, "knock": 12.0, "kind": "light", "dir": (f.global_position - global_position).normalized(), "attacker": self})


## Her darbede: gövde savrulması (zırhlı/zayıf vuruşta da hafif) + kan (kesici silahta daha çok, ateş/şimşek jutsusunda yok)
func _hit_feedback(info: Dictionary, dmg: float) -> void:
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	var heavy: bool = info.get("kind", "light") == "heavy" or info.get("launch", 0.0) > 0.0
	var amp = clampf(dmg / maxf(1.0, max_hp) * 6.0, 0.55, 1.0) * (1.3 if heavy else 1.0) / maxf(1.0, size * 0.7)
	if model and model.has_method("react"):
		model.react(dir, amp, randf() < 0.35, clampf(float(info.get("launch", 0.0)) / 10.0, 0.0, 1.0), 1.0 if info.get("kind", "light") == "heavy" else 0.0)
	if dmg >= 1.0 and not info.get("no_blood", false) and String(info.get("element", "")) not in ["katon", "raiton"] and not is_in_group("no_blood"):
		var cut = String(info.get("weapon_style", "")) in ["blade", "sword", "heavy", "sickle", "claw", "dual", "chain"] or info.get("blade", false)
		FX.blood(global_position + Vector3.UP * height * 0.62, dir, clampf(dmg / maxf(1.0, max_hp) * 5.0, 0.3, 1.0) * (1.4 if cut else 0.8))


func on_damaged(_info: Dictionary) -> void:
	pass


func die(_info: Dictionary) -> void:
	dead = true
	state = "dead"
	collision_layer = 0
	if _info.get("kamui", false):
		# Kamui boyutuna yutuldu: beden burgaçta kayboldu (yere düşme, ceset, kan yok); düğüm sessizce kalkar
		model.visible = false
		remove_from_group("fighters")
		var tk = create_tween()
		tk.tween_interval(4.0)   # havadaki aletleri / kare işleri onu tutuyor olabilir: hemen silinmez (gizli, dövüş dışı)
		tk.tween_callback(queue_free)
		return
	model.play("death", 0.1)
	# cesedin altında kan gölü yayılır (ceset kalkınca söner); dev yaratıklar/klonlar hariç
	if size < 2.5 and not self is ShadowClone and not _info.get("no_blood", false):   # ruhu sökülen ölüde yara yok
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_instance_valid(self):
				FX.blood_pool(self, 1.1 + randf() * 0.4))
	remove_from_group("fighters")
	var tw = create_tween()
	# dōjutsu sahibi (göz alınabilsin) ve üstü aranabilir ceset (ganimet) bir süre yerde kalır
	tw.tween_interval(90.0 if has_meta("loot") else (45.0 if (has_meta("eyes") or has_meta("pain_ok") or is_in_group("senju_bearers")) else 3.0))   # Senju cesedi: hücre alınabilsin
	tw.tween_callback(func(): FX.smoke_puff(global_position + Vector3.UP * 0.5, 0.8, 10))
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(queue_free)


func stagger(t: float) -> void:
	state = "hitstun"
	hitstun_len = 0.45
	state_t = -t
	model.play("hit", 0.05, 0.8, true)


## Hareket + arazi; wish: istenen yatay hız
var _gh_x := INF
var _gh_z := INF
var _gh_v := 0.0
## Bulunduğu noktanın zemin yüksekliği; yer değişmediyse yeniden hesaplanmaz (duran dövüşçü her fizik karesinde soruyordu)
func _ground_here() -> float:
	var p := global_position
	if p.x != _gh_x or p.z != _gh_z:
		_gh_x = p.x
		_gh_z = p.z
		_gh_v = Game.ground_height(p.x, p.z)
	return _gh_v


var _cpush_v := Vector3.ZERO
var _cpush_i := 0
var _cpush_i2 := 0
## Yakındaki dövüşçülerden yumuşak ayrışma hızı (m/sn): 4 fizik karesinde bir hesaplanır (sıra kişiden kişiye kaydırılmış)
func _crowd_push() -> Vector3:
	var push := Vector3.ZERO
	var me := global_position
	for o in get_tree().get_nodes_in_group("fighters"):
		if o == self or not (o is Fighter) or o.dead:
			continue
		var dx: float = me.x - o.global_position.x
		var dz: float = me.z - o.global_position.z
		if absf(dx) > 0.8 or absf(dz) > 0.8 or absf(me.y - o.global_position.y) > 1.6:
			continue
		var d2 := dx * dx + dz * dz
		if d2 > 0.64:
			continue
		var d := sqrt(d2)
		if d < 0.02:   # tam üst üste: sabit bir yöne ayrıl (ikisi zıt yön seçsin diye kimlik sırası)
			var ang := float(get_instance_id() % 628) * 0.01
			dx = cos(ang); dz = sin(ang); d = 1.0
		push += Vector3(dx / d, 0, dz / d) * ((0.8 - minf(d, 0.8)) / 0.8 * 3.2)
	return push.limit_length(3.2)


func step_move(wish: Vector3, dt: float, turn := true) -> void:
	_cpush_i += 1
	if state == "dead":
		_cpush_v = Vector3.ZERO
	elif _cpush_i % (4 if (wish != Vector3.ZERO or _cpush_v != Vector3.ZERO) else 16) == 0:
		_cpush_v = _crowd_push()
	if _cpush_v != Vector3.ZERO:
		velocity.x += _cpush_v.x * minf(1.0, dt * 10.0)
		velocity.z += _cpush_v.z * minf(1.0, dt * 10.0)
	# duran kişi (tezgâhtar, oturan, nöbetçi, bekleyen dövüşçü): hız sıfır, yerde ve tam zemin hizasındaysa çarpışma hareketi
	# atlanır (profil: duranların her fizik karesindeki boş move_and_slide). İtilen / vurulan / yürüyen normal yoldan geçer.
	if wish == Vector3.ZERO and grounded and velocity.y <= 0.0 and absf(velocity.x) + absf(velocity.z) < 0.02 and state not in ["hitstun", "knockdown", "dead"]:
		if absf(global_position.y - _ground_here()) < 0.002:
			velocity = Vector3.ZERO
			if model.rotation.y != facing:
				model.rotation.y = facing
			return
	var slow = 0.45 if has_status("slow") else Combat.exhaust_k(self)
	var hv = Vector3(velocity.x, 0, velocity.z)
	if state in ["hitstun", "knockdown", "dead"]:
		hv = hv.move_toward(Vector3.ZERO, dt * (8.0 if state == "knockdown" else 25.0))
	else:
		hv = hv.lerp(wish * slow * buff_mod("speed"), minf(1.0, dt * 10.0))
	velocity.x = hv.x; velocity.z = hv.z
	velocity.y -= 32.0 * dt
	var pre: Vector3 = global_position
	# kalabalık yükü (2026-11-27, 30 kişilik savaş ölçümü: hareket adımı saniyede 160 ms): zemin zaten arazi yüksekliğinden
	# alınıyor, çarpışma çözümü yalnız duvar / yapı için. Yavaş giderken (< 12 m/sn) her iki fizik karesinden birinde düz
	# ilerleme; sıradaki çarpışmalı kare en çok 20 cm'lik girişi geri iter (kapsül yarıçapından küçük).
	# Konum yerel değişkende hesaplanır, düğüme en sonda TEK kez yazılır (her yazış modelin bütün alt düğümlerini kirletiyordu).
	var q: Vector3 = pre
	var slid := false
	_cpush_i2 += 1
	var hsp := absf(velocity.x) + absf(velocity.z)
	# 8 m/sn altı: üç karede bir çarpışma çözümü (en çok 27 cm giriş), 12 m/sn altı: iki karede bir
	if grounded and absf(velocity.y) < 6.0 and ((hsp < 8.0 and _cpush_i2 % 3 != 0) or (hsp < 12.0 and (_cpush_i2 & 1) == 1)):
		q += Vector3(velocity.x, 0.0, velocity.z) * dt
	elif grounded and absf(pre.y - _ground_here()) < 0.02 and velocity.y <= 0.6:
		# arazi hizasında yürüyen: yerçekimi zemine bastırmasın (her çağrıda zeminle fazladan çarpışma + kayma turu + zemine
		# yapışma sorgusu çıkıyordu); yükseklik aşağıda arazi yüksekliğinden alınır
		var vy := velocity.y
		var fs := floor_snap_length
		velocity.y = 0.0
		floor_snap_length = 0.0
		move_and_slide()
		floor_snap_length = fs
		velocity.y = vy
		q = global_position
		slid = true
	else:
		move_and_slide()
		q = global_position
		slid = true
	var q0: Vector3 = q
	# iç içe geçme itmesi kaçağı: hızı sıfırken bile fizik ayırma itmesi karakteri her karede metrelerce kaydırabiliyordu
	var lim = maxf(Vector2(velocity.x, velocity.z).length(), hv.length()) * dt * 1.6 + 0.06
	var mvd = Vector2(q.x - pre.x, q.z - pre.z)
	if mvd.length() > lim:
		mvd = mvd.normalized() * lim
		q = Vector3(pre.x + mvd.x, q.y, pre.z + mvd.y)
	var g: float
	if q.x == _gh_x and q.z == _gh_z:
		g = _gh_v
	else:
		g = Game.ground_height(q.x, q.z)
		_gh_x = q.x
		_gh_z = q.z
		_gh_v = g
	# uçuruma ışınlanma yok: adımda aşılamayacak dik arazi yatay hareketi durdurur
	var horiz = Vector2(q.x - pre.x, q.z - pre.z).length()
	if horiz > 0.0005 and g - minf(pre.y, q.y) > maxf(0.45, horiz * 1.4):
		q = Vector3(pre.x, q.y, pre.z)
		velocity.x = 0.0; velocity.z = 0.0
		g = Game.ground_height(q.x, q.z)
		_gh_x = q.x
		_gh_z = q.z
		_gh_v = g
	var snap = maxf(0.3, hv.length() * dt * 1.6)
	if grounded and velocity.y <= 0 and q.y > g and q.y - g < snap:
		q.y = g
	if q.y <= g and velocity.y <= 0:
		q.y = g
		velocity.y = 0
		grounded = true
	else:
		grounded = is_on_floor() if slid else grounded
	if q != q0 or not slid:
		global_position = q
	if turn and hv.length() > 0.5 and state not in ["hitstun", "knockdown", "dead"]:
		facing = lerp_angle(facing, atan2(-hv.x, -hv.z), minf(1.0, dt * 10.0))
	if model.rotation.y != facing:
		model.rotation.y = facing


var _env_t = 0.0


func tick_status(dt: float) -> void:
	_env_t -= dt
	if _env_t <= 0.0:
		_env_t = 0.5
		LazyFx.g("Elements").env_tick(self, 0.5)
	if randf() < dt * 3.0:
		var hp_ = global_position + Vector3.UP * randf_range(0.4, height)
		if has_status("wet"):
			FX.burst(hp_, {"amount": 2, "life": 0.5, "size": 0.25, "vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0, -9, 0),
				"colors": [Color(0.7, 0.85, 1, 0.9), Color(0.5, 0.7, 1, 0)]})
		if has_status("frozen") or has_status("chill"):
			FX.burst(hp_, {"amount": 3, "life": 0.7, "tex": FX.tex_spark, "size": 0.4, "vmin": 0.3, "vmax": 1.0,
				"colors": [Color(0.9, 0.98, 1, 1), Color(0.7, 0.9, 1, 0)]})
		if has_status("shock"):
			FX.hit_spark(hp_, Color(0.7, 0.85, 1.0), 0.4)
		if has_status("mud"):
			FX.burst(global_position + Vector3.UP * 0.3, {"amount": 2, "life": 0.6, "add": false, "size": 0.3, "vmin": 0.2, "vmax": 0.5,
				"gravity": Vector3(0, -6, 0), "colors": [Color(0.4, 0.3, 0.2, 1), Color(0.35, 0.25, 0.18, 0)]})
	# güvenlik: canı başka yoldan (zincir şimşek, canavar DoT, jutsu bedeli...) sıfıra inip die() çağrılmadan kalanlar
	# yerde çömelip nefes alarak "ölümsüz" kalıyordu
	if hp <= 0.0 and not dead:
		hp = 0.0
		die({})
		return
	for k in statuses.keys():
		statuses[k] -= dt
		if statuses[k] <= 0.0:
			statuses.erase(k)
	for k in buffs.keys():
		buffs[k]["t"] -= dt
		if buffs[k]["t"] <= 0.0:
			buffs.erase(k)
	if has_status("poison"):
		load("res://scripts/combat/fx/doku_fx.gd").tick(self, dt)
		if hp <= 0.0 and not dead:
			die({})
	if has_status("burn"):
		hp -= 4.0 * dt
		if randf() < dt * 8.0:
			FX.burst(global_position + Vector3.UP * randf_range(0.3, height), {"amount": 3, "life": 0.5, "size": 0.6, "vmin": 1, "vmax": 2, "gravity": Vector3(0, 3, 0),
				"colors": [Color(1, 0.8, 0.3, 1), Color(1, 0.3, 0.05, 0)]})
		if hp <= 0.0 and not dead:
			die({})
