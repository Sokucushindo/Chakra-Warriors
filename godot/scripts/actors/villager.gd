class_name Villager
extends Fighter
## Köy halkı. Sokak rolleri: walker, kid, chat, patrol, roof, sitter, vendor, shopper, spar, worker, guard, drunk, ball.
## İç mekân rolleri: keeper (dükkâncı), customer, student, teacher, nurse, patient. [F] ile konuşulur.
## Konuşma balonları (Label3D), oyuncuyu rütbesine göre selamlama, çarpınca tepki.

const LINES := {
	"walker": ["Bugün hava çok güzel, değil mi?", "Ichiraku'nun yeni ramen tarifi efsaneymiş!", "Hokage Kulesi'nde yine görev kuyruğu var.",
		"Pazardan taze balık aldım, akşam ızgara yapacağım.", "Son zamanlarda sınırda tuhaf ninjalar görülüyormuş... dikkatli ol.",
		"Kayadaki yüzlere her bakışımda içim ısınıyor."],
	"kid": ["Hey! Sen de akademidensin değil mi? Yarışalım mı?", "Ben büyüyünce Hokage olacağım!", "Kawarimi'yi daha yapamıyorum, hep kütük düşüyor...",
		"Shuriken atmayı öğretir misin? Lütfeeen!", "Saklambaç oynuyoruz, sen ebesin!", "Annem akademiden sonra eve gel dedi ama..."],
	"chat": ["...ve sonra Chunin sınavında rakibini tek hamlede yenmiş!", "Duydun mu? Kumo'dan elçiler gelmiş.", "Fiyatlar yine artmış, bu Ryō nereye gidiyor?",
		"Oğlum Genin oldu, gururluyum!"],
	"vendor": ["Taze sebzeler! Bugün toplandı!", "Kunai, shuriken! Akademi öğrencilerine indirim!", "Dango, sıcacık dango!", "Ninja çantası lazım mı? En sağlamı bende!"],
	"sitter": ["Biraz dinleniyorum... Gençler hep koşturuyor.", "Benim gençliğimde savaş vardı, şimdi barış... kıymetini bilin.", "Bu bankta oturup köyü izlemeyi seviyorum."],
	"patrol": ["Devriyedeyiz. Bir sorun görürsen haber ver.", "Akademi öğrencisi misin? Çok çalış, Ateşin İradesi seninle.", "Kapıdan çıkarken dikkatli ol, ormanlar tehlikeli."],
	"roof": ["Çatılar en hızlı yol! Yakala beni!"],
	"shopper": ["Bu fiyata mı? Biraz indirim yap!", "Şu elmalar ne kadar taze...", "Akşam yemeğine ne alsam?"],
	"spar": ["Bir tur daha! Bu sefer Kawarimi yok!", "Taijutsu'nda açık veriyorsun!", "Antrenman bitmeden eve gitmek yok!"],
	"worker": ["Yeni ev yapıyoruz, ahşap jutsu olsa ne kolay olurdu...", "Kalas dikkat! Kafana düşmesin!", "Bu çatı yarın bitecek."],
	"guard": ["Kapı nöbeti sıkıcı ama önemli.", "Kimlik kontrolü! Şaka şaka, geç bakalım.", "Gece nöbeti uzun sürer."],
	"drunk": ["Hık! Bir şişe sake daha...", "Ben... hık... bir zamanlar Jonin olacaktım!", "Ay iki tane mi? Hık!"],
	"ball": ["Pas ver, pas!", "Gol! Gol!", "Top bende!"],
	"customer": ["Burası köyün en iyisi.", "Hmm, karar veremedim...", "Görevden sonra buraya gelmek gibisi yok."],
	"student": ["Mühürler çok karışık...", "Sensei bugün sınav yapacak mı?", "Teneffüs ne zaman?"],
	"patient": ["Bir görevde yaralandım...", "Tıbbi ninjalar mucize yaratıyor."],
}
const CALLS := {
	"vendor": ["Taze sebze!", "Buyrun, buyrun!", "Sıcak dango!", "Kunai indirimde!", "Taze balık!", "Bugüne özel!"],
	"drunk": ["Hık!", "Sake...", "Lalala~"],
	"ball": ["Pas!", "Benim!", "Gooool!"],
	"spar": ["Hah!", "Hıyaa!", "Tekrar!"],
	"worker": ["Kaldır!", "Dikkat!"],
}

const VillagerJobs = preload("res://scripts/actors/villager_jobs.gd")
var role := "walker"
var home := Vector3.ZERO
var goal := Vector3.ZERO
var wait := 0.0
var speed := 2.6
var buddy: Node3D = null
var points: Array = []      # sokak noktaları / çatılar / tezgâh önleri (yönetici verir)
var hop_t := -1.0
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
var display := "Köylü"
# yeni davranışlar
var interior := false
var display_override := ""
var lines_override: Array = []
var look_extra := {}         # rol görünümünün üstüne yazılır (Kage cüppesi, ANBU maskesi...)
var eat_mode := false
var floor_sit := false
var wander_r := 0.0
var stay := false             # yerinden hiç ayrılmaz (balkondaki izleyiciler: dolaşınca korkuluktan arenaya düşüyorlardı)
var stand_face := 0.0        # sabit rollerin baktığı yön (radyan)
var fixed_face := false
var going_home := false
var work_anims: Array = []
var work_points: Array = []
var job := ""                # rol "job": işin türü (VillagerJobs: çapa, pirinç dikme, sedye, devriye...)
var jd := {}                 # işin durumu (satır, nokta sırası, eş, aletler)
var night := false
var anim_t := 0.0
var greet_cd := 0.0
var bump_cd := 0.0
var call_cd := 0.0
var bubble: Label3D
var bubble_t := 0.0
var kick_t := -1.0
var nav := {}               # NpcNav durumu (engelden dolaşma, takılma)
var fading := false
var dest := Vector3.INF      # uzun yol hedefi (kapı, görev masası): sokak noktalarından geçerek gider, varınca kaybolur
var follow: Node3D = null    # takım: liderin arkasında yürür
var follow_off := Vector3.ZERO
var bow_t := 0.0
var folk_vid := ""           # kalıcı sivil: yeni yüzse bu köyün kaydına geçer (WorldFolk)
var folk_site := ""


var _planned := false


## Görünüşün kararı (rol kalıbı + kıyafet + yaş). Sahneye girmeden de çağrılabilir: doğuran taraf yüzü / saçı arka planda
## hazırlatıp (CharacterModel.prepare) kişiyi hazır olunca sahneye alır; yoksa yeni yüz karede hesaplanıp oyunu takıyordu.
func plan_look() -> void:
	if _planned:
		return
	_planned = true
	var tops := [Color(0.5, 0.6, 0.45), Color(0.6, 0.35, 0.3), Color(0.8, 0.75, 0.55), Color(0.4, 0.45, 0.6), Color(0.7, 0.55, 0.65),
		Color(0.85, 0.85, 0.85), Color(0.55, 0.3, 0.45), Color(0.9, 0.6, 0.3)]
	var t: Color = tops.pick_random()
	var lk = {"gender": ["m", "f"].pick_random(), "top": t, "top2": t.darkened(0.12), "pants": [Color(0.35, 0.3, 0.28), Color(0.2, 0.22, 0.3), Color(0.4, 0.35, 0.25)].pick_random(),
		"band": null, "hair_style": CharacterModel.HAIR_STYLES.keys().filter(func(h): return h != "kel" or randf() < 0.3).pick_random(),
		"hair": [Color(0.1, 0.08, 0.06), Color(0.35, 0.22, 0.12), Color(0.6, 0.6, 0.62), Color(0.75, 0.45, 0.2), Color(0.85, 0.75, 0.4)].pick_random(),
		"sleeves": randf() < 0.6, "pants_style": "sivil", "sandal": Color(0.3, 0.22, 0.15), "skin": [Color(0.96, 0.8, 0.66), Color(0.88, 0.7, 0.55), Color(0.98, 0.86, 0.75)].pick_random()}
	lk["face_mark"] = ["yok", "yok", "yok", "yok", "çil", "burun yarası", "yanak çizgisi"].pick_random()
	var ninja = {"vest": Color(0.38, 0.48, 0.28), "pants_style": "ninja", "top_style": "uzun", "sandal": Color(0.15, 0.2, 0.32), "top": Color(0.18, 0.22, 0.3),
		"top2": Color(0.18, 0.22, 0.3), "pants": Color(0.18, 0.22, 0.3), "band": Color(0.15, 0.22, 0.55), "age": "adult"}
	match role:
		"kid", "ball", "student":
			lk["age"] = "child"
			speed = 6.5
			display = "Çocuk" if role != "student" else "Akademi Öğrencisi"
		"patrol", "roof", "guard":
			lk.merge(ninja, true)
			speed = 4.5 if role != "roof" else 14.0
			display = "Konoha Chunin" if role != "guard" else "Kapı Nöbetçisi"
		"spar":
			lk.merge(ninja, true)
			if randf() < 0.5:
				lk["vest"] = null
				lk["top_style"] = ["ceket", "yakali", "tisort"].pick_random()
				lk["top"] = [Color(0.15, 0.2, 0.33), Color(0.45, 0.15, 0.15), Color(0.2, 0.38, 0.22), Color(0.95, 0.5, 0.12)].pick_random()
				lk["age"] = "teen"
			display = "Antrenman Yapan Ninja"
		"teacher":
			lk.merge(ninja, true)
			display = "Akademi Hocası"
		"sitter":
			lk["hair"] = Color(0.8, 0.8, 0.82)
			lk["age"] = "adult"
			lk["face_mark"] = "kırışık"
			lk["beard"] = randf() < 0.6
			display = "Yaşlı Köylü"
		"vendor", "keeper":
			display = "Satıcı" if role == "vendor" else "Dükkâncı"
			lk["age"] = "adult"
			lk["top_style"] = ["uzun", "tisort"].pick_random()
			lk["beard"] = lk["gender"] == "m" and randf() < 0.3
		"nurse":
			lk.merge({"top": Color(0.96, 0.96, 0.97), "top2": Color(0.96, 0.96, 0.97), "pants": Color(0.9, 0.9, 0.92), "top_style": "uzun", "age": "young"}, true)
			display = "Tıbbi Ninja"
		"worker":
			lk.merge({"top_style": "tisort", "top": Color(0.55, 0.42, 0.3), "pants": Color(0.3, 0.27, 0.24), "age": "adult", "band": Color(0.85, 0.85, 0.85), "band_style": "head"}, true)
			display = "İnşaat İşçisi"
		"job":
			VillagerJobs.base_look(self, lk)
		"drunk":
			lk.merge({"age": "adult", "top": Color(0.6, 0.35, 0.3), "beard": true}, true)
			speed = 1.3
			display = "Sarhoş Adam"
		"shopper":
			lk["age"] = ["adult", "adult", "young"].pick_random()
			display = "Alışverişçi"
		"customer", "patient":
			lk["age"] = ["adult", "young", "teen"].pick_random()
			display = "Müşteri" if role == "customer" else "Hasta"
		_:
			lk["age"] = ["adult", "adult", "young", "teen"].pick_random()
			lk["beard"] = lk["age"] == "adult" and randf() < 0.3
	if display_override != "":
		display = display_override
	# rol kıyafet seti (özel görünüm verilmişse — Kage, ANBU... — dokunma)
	if look_extra.is_empty():
		lk.merge(Outfits.roll(_outfit_arch(), Outfits.village_near()), true)
		if role == "job":
			lk = VillagerJobs.finish_look(self, lk)
	if look_extra.get("whole", false):
		lk = {}   # gerçek kişi (dünya ninjası): rol kalıbından hiçbir şey sızmaz
	lk.merge(look_extra, true)
	lk.erase("whole")
	Aging.dress_civil(lk, {"builder": 0.9, "farmer": 0.7, "trainee": 0.6, "teacher": 0.5, "vendor": 0.1, "keeper": 0.1, "drunk": 0.0}.get(role, 0.25), role == "sitter")
	if look_extra.is_empty():
		lk["npc"] = true   # CharacterModel: hazır saç önbelleğini tercih et (kurulum donması olmasın)
	look = lk


func _ready() -> void:
	team = "neutral"
	plan_look()
	var lk = look
	var new_folk := {}
	if folk_vid != "" and look_extra.is_empty() and display_override == "":
		new_folk = WorldFolk.adopt(folk_vid, role, lk, folk_site)   # ilk kez görülen sivil: adı, yaşı, görünüşü kalıcı olur
		if not new_folk.is_empty():
			display = String(new_folk["name"])
	super._ready()
	if not new_folk.is_empty():
		WorldFolk.on_stage(new_folk, self)
	remove_from_group("fighters")
	add_to_group("talkers")
	if not _all.has(self):
		_all.append(self)
	collision_layer = 4
	collision_mask = 1 | 2   # köylüler birbirine çarpmaz (üst üste doğan ikisi birbirini itip saniyede 40 m kayarak binalara giriyordu); yönlendirme birbirinden kaçırır
	if model and look.get("age", "adult") != "adult":
		model.apply_age(look["age"])
		radius *= model.age_scale
		height *= model.age_scale
	goal = global_position
	home = global_position
	greet_cd = randf_range(2.0, 8.0)
	call_cd = randf_range(1.0, 8.0)
	anim_t = randf_range(0.0, 3.0)
	if role in ["guard", "patrol"] and night:
		_hold_lantern()
	Friends.tag(self)


## Tanıdık NPC'nin başında adı + rütbesi (bağ rengiyle)
var name_tag: Label3D


func set_name_tag(text: String, col: Color) -> void:
	if name_tag == null:
		name_tag = Label3D.new()
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.fixed_size = false
		name_tag.pixel_size = 0.005
		name_tag.font_size = 34
		name_tag.outline_size = 8
		name_tag.visibility_range_end = 35.0
		name_tag.visibility_range_end_margin = 6.0
		name_tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(name_tag)
	name_tag.text = text
	name_tag.modulate = col
	name_tag.position.y = height * (model.age_scale if model else 1.0) + 0.45


func _lines() -> Array:
	if not lines_override.is_empty():
		return lines_override
	return LINES.get(role, LINES["walker"])


func talk() -> void:
	if Orgs.rogue_confront(self):
		return   # kaçaksın: köy ninjası konuşmaz, saldırır
	if Game.player:
		var to = Game.player.global_position - global_position
		facing = atan2(-to.x, -to.z)
		model.rotation.y = facing
	if role not in ["sitter", "customer", "student", "patient"] and not floor_sit:
		model.play("talk", 0.2)
	wait = 4.0
	var fid = String(get_meta("friend_id", ""))
	var line = _lines().pick_random()
	if lines_override.is_empty() and role in ["walker", "shopper", "sitter", "kid", "customer"]:
		line = Talk.stranger(self, String(line))
	line = Talk.fit(self, Talk.localize(String(line)))
	var fk = WorldFolk.of_node(self)
	if fid != "" and Friends.all().has(fid):
		line = Friends.greeting(fid)
	elif not fk.is_empty():
		line = Talk.fit(self, WorldFolk.line(fk, self, String(line)))   # kalıcı sivil: kendini tanıtır, yakınından söz eder, seni hatırlar
		WorldFolk.talked(fk, self)
	elif has_meta("world_person"):
		var rg: Dictionary = WorldDay.regard_node(self)
		if String(rg.get("k", "")) in ["nefret", "minnet", "kage"]:
			line = String(rg["line"])   # aranızda yaşanan, sıradan sözün önüne geçer
	var extra = []
	if has_meta("jinchuriki_of"):   # köyün jinchūriki'si: saldırılabilir; yenilince canavar bedeninden fışkırır (mühürle / salıver)
		extra.append({"label": "Saldır! (içindeki canavarı al — köyde suç)", "cb": func(): TailedBeasts.attack_host(self)})
	Hud.dialog(display, line, Friends.options_for(self) + (Friends.small_talk(self) if fid == "" else []) + extra + ([] if has_meta("jinchuriki_of") or not HomeLife.kid_of(self).is_empty() else Crime.attack_option(self)))


## Kafanın üstünde kısa konuşma balonu. important=false: ortam sözü (satıcı çağrısı, selam, top / antrenman nidası) —
## 3 m içinde başka balon görünürken söylenmez. Önemli söz yakındaki ortam balonlarını kapatır, öbür önemli balonların
## üstüne dizilir (iki kişinin sözü üst üste binip okunmaz hâle geliyordu). Balonun alt kenarı ad etiketinin üstündedir.
static var _speakers: Array = []   # balonu görünen köylüler (yakın balon araması)
const BUB_PX := 0.005
const BUB_NEAR := 3.0
var _bub_amb := false
var _bub_h := 0.0


func say(text: String, dur := 2.6, important := true) -> void:
	var near: Array = []
	for o in _speakers.duplicate():
		if not is_instance_valid(o) or o.bubble == null or not o.bubble.visible:
			_speakers.erase(o)
			continue
		if o == self:
			continue
		var d = o.global_position - global_position
		if Vector2(d.x, d.z).length() < BUB_NEAR and absf(d.y) < 4.0:
			if o.bubble.text == text:
				return   # yanındaki aynı sözü zaten söylüyor (iki kişi aynı selamı üst üste veriyordu)
			near.append(o)
	if not important and (not near.is_empty() or (bubble != null and bubble.visible and not _bub_amb)):
		return   # yakında biri konuşuyor / kendi önemli sözü sürüyor: ortam sözü bekler
	if bubble == null:
		bubble = Label3D.new()
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.pixel_size = BUB_PX
		bubble.modulate = Color(1, 0.97, 0.88)
		bubble.outline_modulate = Color(0.08, 0.06, 0.06)
		bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # konum = alt kenar (çok satırlı söz yukarı uzar)
		bubble.visibility_range_end = 32.0
		bubble.visibility_range_end_margin = 5.0
		bubble.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(bubble)
	# uzun söz: satıra bölünür ve küçülür
	var long = text.length() > 24
	var fs = 30 if long else 38
	bubble.font_size = fs
	bubble.outline_size = 8 if long else 10
	bubble.width = 460.0
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	bubble.text = text
	var lines = 1 if not long else maxi(1, ceili(text.length() * 0.56 * fs / 460.0))
	_bub_h = lines * fs * 1.22 * BUB_PX
	_bub_amb = not important
	var y = _bubble_base()
	if important:
		for o in near:
			if o._bub_amb:
				o.bubble.visible = false   # önemli söz gelince yandakinin ortam nidası susar
		# yakındaki önemli balonların üstüne diz (alttan yukarı)
		near = near.filter(func(o): return o.bubble.visible)
		near.sort_custom(func(a, b): return a.bubble.global_position.y < b.bubble.global_position.y)
		for o in near:
			var ob: float = o.bubble.global_position.y
			var my = global_position.y + y
			if my < ob + o._bub_h + 0.05 and my + _bub_h + 0.05 > ob:
				y = ob + o._bub_h + 0.06 - global_position.y
	bubble.position = Vector3(0, y, 0)
	bubble.visible = true
	bubble_t = dur
	if not _speakers.has(self):
		_speakers.append(self)


## Balonun alt kenarı: ad etiketi varsa onun üst kenarının biraz üstü, yoksa başın üstü
func _bubble_base() -> float:
	if name_tag != null and name_tag.visible and name_tag.text != "":
		var tl = name_tag.text.count("\n") + 1
		return name_tag.position.y + tl * name_tag.font_size * name_tag.pixel_size * 1.22 * 0.5 + 0.06
	return height + 0.35


func _exit_tree() -> void:
	_speakers.erase(self)
	_all.erase(self)
	if not jd.is_empty():
		VillagerJobs.release(self)
	if _my_claim != null and int(_claims.get(_my_claim, 0)) == get_instance_id():
		_claims.erase(_my_claim)


# ------------------------------------------------------------------ birbirinin içine girmeme
## Köylüler fizikte birbirine çarpmaz (üst üste doğan ikisi birbirini itip binalara kayıyordu); yerine ucuz yerel ayrılma:
## karede bir kez 2 m'lik ızgara kurulur, her kişi yalnız komşu hücrelere bakar, ~0.8 m'den yakınsa yavaşça uzaklaşır.
static var _all: Array = []
static var _grid := {}
static var _grid_frame := -1
const SEP_CELL := 2.0


static func _grid_rebuild() -> void:
	_grid_frame = Engine.get_physics_frames()
	_grid.clear()
	for n in _all:
		if not is_instance_valid(n) or n.fading or n.role == "roof" or not n.is_inside_tree():
			continue
		var p: Vector3 = n.global_position
		var c = Vector2i(floori(p.x / SEP_CELL), floori(p.z / SEP_CELL))
		if _grid.has(c):
			_grid[c].append(n)
		else:
			_grid[c] = [n]


## Yakındaki köylülerden uzaklaştıran yatay itme (0..~1.5; çarpanla hıza eklenir)
func _sep() -> Vector3:
	if Engine.get_physics_frames() != _grid_frame:
		_grid_rebuild()
	var p := global_position
	var c = Vector2i(floori(p.x / SEP_CELL), floori(p.z / SEP_CELL))
	var push := Vector3.ZERO
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var arr = _grid.get(c + Vector2i(dx, dz))
			if arr == null:
				continue
			for o in arr:
				if o == self:
					continue
				var d: Vector3 = p - o.global_position
				if absf(d.y) > 1.6:
					continue
				d.y = 0.0
				var want = clampf(float(radius) + float(o.radius) + 0.05, 0.55, 0.85)
				if o == buddy:
					want = 1.15   # sohbet / antrenman eşi: yüz yüze, ~1.2 m
				var l = d.length()
				if l >= want:
					continue
				if l < 0.02:
					# tam üst üste: kimlik numarasına göre sabit bir yön (ikisi aynı yöne kaçmasın)
					var a = float(get_instance_id() % 6283) * 0.001
					d = Vector3(cos(a), 0, sin(a))
					l = 0.02
				push += d / l * ((want - l) / want)
	if push.length() > 1.5:
		push = push.normalized() * 1.5
	return push


## Hedef noktası paylaşılmaz: aynı ~1.6 m hücreye ikinci kişi yönelmez (hepsi aynı sokak noktasında toplanıp duruyordu)
static var _claims := {}


static func _ckey(q: Vector3) -> Vector2i:
	return Vector2i(floori(q.x / 1.6), floori(q.z / 1.6))


func _taken(q: Vector3) -> bool:
	var id = int(_claims.get(_ckey(q), 0))
	if id == 0 or id == get_instance_id():
		return false
	var o = instance_from_id(id)
	return o != null and is_instance_valid(o) and o is Villager and not o.fading and _ckey(o.goal) == _ckey(q)


var _my_claim = null


func _claim(q: Vector3) -> void:
	if _my_claim != null and int(_claims.get(_my_claim, 0)) == get_instance_id():
		_claims.erase(_my_claim)
	_my_claim = _ckey(q)
	_claims[_my_claim] = get_instance_id()


func _hold_lantern() -> void:
	if model == null or model.skel == null or model.skel.find_bone("RightHand") < 0:
		return
	if lantern != null:
		return
	lantern = LanternRig.new()
	lantern.v = self
	add_child(lantern)


## Gece feneri (chōchin): sağ elde kısa ahşap taşıma sopası, ucundan asılı kâğıt fener. Sopa elin gerçek kemiğini izler
## (gövdenin baktığı yönde öne-aşağı uzanır); fener sopanın ucundan sarkar, her karede dik durur, yürürken hafifçe sallanır.
## Eskiden fener el kemiğinin dinlenme yönüne yapışık düz bir kutuydu: el dönünce kalçadan yana çıkan bej bir levha gibi duruyordu.
var lantern: LanternRig = null


class LanternRig extends Node:
	var v   # sahibi Villager
	var stick: MeshInstance3D
	var lamp: Node3D
	var hb := -1
	var sw := Vector3.ZERO      # fenerin sarkma sapması (yatay, m)
	var sw_v := Vector3.ZERO
	var prev_tip := Vector3.INF
	var tip_v := Vector3.ZERO
	var frame := 0
	static var _stick_mesh: ArrayMesh
	static var _frame_mesh: ArrayMesh
	static var _paper := {}       # renk adı -> [mesh, material]
	const STICK_L := 0.46
	const BODY_Y := -0.27         # fener gövdesinin merkezi (asılma noktasına göre)

	func _ready() -> void:
		hb = v.model.skel.find_bone("RightHand")
		if _stick_mesh == null:
			var bs = MB.new()
			var wood = Color(0.33, 0.22, 0.13)
			bs.add("cyl", Vector3(0, STICK_L * 0.5, 0), Vector3(0.022, STICK_L, 0.022), wood, Vector3.ZERO, 6)
			bs.add("cyl", Vector3(0, -0.02, 0), Vector3(0.03, 0.05, 0.03), wood.darkened(0.3), Vector3.ZERO, 6)   # sap ucu
			bs.add("torus", Vector3(0, STICK_L - 0.015, 0), Vector3(0.05, 0.25, 0.05), Color(0.12, 0.1, 0.08), Vector3(90, 0, 0), 8)   # asma halkası
			_stick_mesh = bs.build(Props.toon())
			# fener iskeleti: tepe / dip ahşap kapaklar, asma ipi, kâğıdın üstündeki bambu kaburgalar
			var bf = MB.new()
			var cap = Color(0.16, 0.11, 0.07)
			bf.add("cyl", Vector3(0, -0.035, 0), Vector3(0.006, 0.07, 0.006), Color(0.1, 0.08, 0.06), Vector3.ZERO, 4)   # ip
			bf.add("cyl", Vector3(0, -0.085, 0), Vector3(0.15, 0.035, 0.15), cap, Vector3.ZERO, 12)
			bf.add("cyl", Vector3(0, -0.068, 0), Vector3(0.09, 0.012, 0.09), cap.lightened(0.15), Vector3.ZERO, 10)
			bf.add("cyl", Vector3(0, BODY_Y - 0.185, 0), Vector3(0.16, 0.04, 0.16), cap, Vector3.ZERO, 12)
			var ry = 0.175
			for k in 9:
				var y = -ry + (k + 0.5) * (2.0 * ry / 9.0)
				var r = 0.135 * sqrt(maxf(0.0, 1.0 - (y / ry) * (y / ry)))
				bf.add("torus", Vector3(0, BODY_Y + y, 0), Vector3(r * 2.0 + 0.008, 0.12, r * 2.0 + 0.008), Color(0.25, 0.14, 0.08), Vector3.ZERO, 16)
			_frame_mesh = bf.build(Props.toon())
		var cname = "red" if randf() < 0.5 else "cream"
		if not _paper.has(cname):
			var col = Color(0.82, 0.16, 0.1) if cname == "red" else Color(1.0, 0.88, 0.66)
			var bp = MB.new()
			bp.add("sphere", Vector3(0, BODY_Y, 0), Vector3(0.27, 0.35, 0.27), col, Vector3.ZERO, 16)
			var m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.2) if cname == "red" else Color(1.0, 0.75, 0.4)
			m.emission_energy_multiplier = 1.6
			_paper[cname] = [bp.build(m), m]
		stick = MeshInstance3D.new()
		stick.mesh = _stick_mesh
		stick.top_level = true
		stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stick)
		lamp = Node3D.new()
		lamp.top_level = true
		add_child(lamp)
		var paper = MeshInstance3D.new()
		paper.mesh = _paper[cname][0]
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(paper)
		var fr = MeshInstance3D.new()
		fr.mesh = _frame_mesh
		fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(fr)
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.35) if cname == "red" else Color(1.0, 0.72, 0.4)
		l.light_energy = 0.8
		l.omni_range = 5.0
		l.position = Vector3(0, BODY_Y, 0)
		lamp.add_child(l)
		_update(1.0 / 60.0)

	func _process(dt: float) -> void:
		if not is_instance_valid(v) or v.model == null:
			return
		var on = not v.fading and v.visible
		stick.visible = on
		lamp.visible = on
		if not on:
			return
		# uzaktaki / ekran dışındaki fener seyrek güncellenir (kalabalıkta ucuz kalsın)
		frame += 1
		var cam = v.get_viewport().get_camera_3d()
		if cam != null:
			var far = cam.global_position.distance_squared_to(v.global_position) > 70.0 * 70.0
			var off = not cam.is_position_in_frustum(v.global_position + Vector3.UP)
			if (far or off) and frame % 15 != 0:
				return
			if far or off:
				dt *= 15.0
		_update(dt)

	func _update(dt: float) -> void:
		var sk: Skeleton3D = v.model.skel
		if sk == null or hb < 0:
			return
		var hx: Transform3D = sk.global_transform * sk.get_bone_global_pose(hb)
		var sc: float = v.model.age_scale if "age_scale" in v.model else 1.0
		var grip = hx.origin + hx.basis.y.normalized() * 0.075 * sc   # avuç: bilekten parmaklara doğru
		var f: float = v.facing
		var fwd = Vector3(-sin(f), 0, -cos(f))
		var right = Vector3(cos(f), 0, -sin(f))
		# sopa: avuçtan öne, hafif dışa ve yukarı (fener bacağa çarpmadan önde sallansın)
		var dir = (fwd * 0.8 + right * 0.25 + Vector3.UP * 0.35).normalized()
		var by = dir
		var bx = by.cross(right).normalized()
		if bx.length() < 0.1:
			bx = fwd
		var bz = bx.cross(by).normalized()
		stick.global_transform = Transform3D(Basis(bx, by, bz).scaled(Vector3(sc, sc, sc)), grip - dir * 0.04 * sc)
		var tip = grip + dir * (STICK_L - 0.06) * sc
		# sarkaç: ucun hızı fenerin altını geride bırakır, yay geri getirir
		dt = clampf(dt, 0.0, 0.25)
		if prev_tip == Vector3.INF or dt <= 0.0:
			prev_tip = tip
		var tv = (tip - prev_tip) / maxf(dt, 0.001)
		prev_tip = tip
		tv.y = 0.0
		tip_v = tip_v.lerp(tv, minf(1.0, dt * 12.0))
		var target = -tip_v * 0.05
		if target.length() > 0.18:
			target = target.normalized() * 0.18
		sw_v += (target - sw) * 40.0 * dt
		sw_v *= exp(-3.5 * dt)
		sw += sw_v * dt
		if sw.length() > 0.22:
			sw = sw.normalized() * 0.22
		var up = (Vector3.UP - sw / 0.3).normalized()   # asılma noktasından fenere bakan yönün tersi
		var lx = up.cross(fwd).normalized()
		if lx.length() < 0.1:
			lx = right
		var lz = lx.cross(up).normalized()
		lamp.global_transform = Transform3D(Basis(lx, up, lz).scaled(Vector3(sc, sc, sc)), tip)


## Eve girer gibi kaybol
func vanish() -> void:
	if fading:
		return
	fading = true
	var tw = create_tween()
	tw.tween_property(model, "scale", Vector3(0.05, model.scale.y, 0.05), 0.35)
	tw.tween_callback(queue_free)


func _face(dir: Vector3, dt := 1.0) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, dt * 8.0))
	model.rotation.y = facing


func _hold_face(dt: float) -> void:
	facing = lerp_angle(facing, stand_face, minf(1.0, dt * 4.0))
	model.rotation.y = facing


func _cycle(dt: float, anims: Array, period := 3.5) -> void:
	anim_t -= dt
	if anim_t <= 0.0:
		anim_t = randf_range(period * 0.6, period * 1.4)
		model.play(anims.pick_random(), 0.3, 1.0, true)


## Oturan NPC'nin altı (kullanıcı: "sit and talk'ta havada oturuyorlar, altlarına sandalye ver"): kalçanın altında gerçek bir
## oturak (bank, tabure, kütük) yoksa ahşap tabure konur; her karede kalça oturağın üstüne hizalanır (sit ve Sitting_Talking
## kliplerinin kalça yüksekliği farklı: biri havada, öbürü gömük kalıyordu). Yerde oturanlar (floor_sit) dokunulmaz.
var _seat_y := NAN
var _seat_on := false
var _seat_frame := 0
var _stool: MeshInstance3D = null
static var _stool_mesh: ArrayMesh = null


func _hips_w() -> Vector3:
	var sk: Skeleton3D = model.skel
	var hb = sk.find_bone("Hips") if sk else -1
	if hb < 0:
		return global_position + Vector3.UP * 0.45 * model.age_scale
	return (sk.global_transform * sk.get_bone_global_pose(hb)).origin


func _seat_fix() -> void:
	if floor_sit or model == null or model.skel == null:
		return
	_seat_on = true
	_seat_frame = Engine.get_physics_frames()
	var a: float = model.age_scale
	var hp := _hips_w()
	if is_nan(_seat_y):
		# kalçanın altında oturak var mı (zeminden 25 cm yukarıda bir çarpışma yüzeyi)
		var q := PhysicsRayQueryParameters3D.create(Vector3(hp.x, global_position.y + 1.0 * a, hp.z), Vector3(hp.x, global_position.y - 0.2, hp.z))
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var gy := Game.ground_height(hp.x, hp.z)
		if not hit.is_empty() and float(hit["position"].y) > gy + 0.25 and float(hit["position"].y) < global_position.y + 0.8 * a:
			_seat_y = float(hit["position"].y)
		else:
			_seat_y = gy + 0.43 * a
			if _stool_mesh == null:
				var b := MB.new()
				var wood := Color(0.47, 0.34, 0.21)
				b.add("cyl", Vector3(0, -0.035, 0), Vector3(0.42, 0.07, 0.42), wood.lightened(0.08), Vector3.ZERO, 12)   # oturak tablası
				b.add("cyl", Vector3(0, -0.003, 0), Vector3(0.34, 0.012, 0.34), Color(0.62, 0.5, 0.36), Vector3.ZERO, 12)   # hasır minder
				for k in 3:
					var an := TAU * k / 3.0
					b.add("cyl", Vector3(cos(an) * 0.13, -0.22, sin(an) * 0.13), Vector3(0.05, 0.42, 0.05), wood.darkened(0.15), Vector3(cos(an) * 8.0, 0, -sin(an) * 8.0), 6)
				b.add("torus", Vector3(0, -0.28, 0), Vector3(0.3, 0.3, 0.3), wood.darkened(0.25), Vector3.ZERO, 10)   # ayak bağı
				_stool_mesh = b.build(Props.toon())
			_stool = MeshInstance3D.new()
			_stool.mesh = _stool_mesh
			_stool.top_level = true
			add_child(_stool)
			var top := _seat_y
			_stool.global_transform = Transform3D(Basis.from_scale(Vector3(a, (top - gy) / 0.43, a)), Vector3(hp.x, top, hp.z))
	if _stool:
		_stool.visible = true
	# kalça = oturak + kalça kalınlığı
	var hr := hp.y - model.global_position.y
	model.position.y = clampf(_seat_y + 0.07 * a - global_position.y - hr, -0.4, 0.6)


func _unseat() -> void:
	_seat_on = false
	model.position.y = 0.0
	if _stool:
		_stool.visible = false
	_seat_y = NAN
	if _stool:
		_stool.queue_free()
		_stool = null


func _physics_process(dt: float) -> void:
	if Game.paused or Game.player == null or fading:
		return
	var pl = Game.player
	var dist = global_position.distance_to(pl.global_position)
	if dist > (100.0 if role == "team" else 65.0):
		# uzaktakiler: animasyon ve hareket durur (performans)
		if model.anim.is_playing():
			# durdurmadan önce mevcut kareyi iskelete uygula (yoksa yeni doğan NPC T-pozda kalır)
			model.anim.seek(model.anim.current_animation_position, true)
			model.anim.pause()
		return
	elif not model.anim.is_playing():
		model.anim.play()
	_social(dt, dist)
	if _seat_on and Engine.get_physics_frames() - _seat_frame > 2:
		_unseat()   # artık oturmuyor: model yerine, tabure gizli
	match role:
		"roof":
			_roof(dt)
			return
		"vendor", "keeper":
			step_move(Vector3.ZERO, dt, false)
			if dist < 5.0:
				_face(pl.global_position - global_position, dt)
			elif fixed_face:
				_hold_face(dt)
			if wait > 0.0:
				wait -= dt
			else:
				_cycle(dt, ["idle", "talk", "fold", "interact", "idle", "yes"])
			if role == "vendor":
				_call(dt, dist)
			return
		"sitter", "customer", "student", "patient":
			step_move(Vector3.ZERO, dt, false)
			if fixed_face:
				_hold_face(dt)
			if floor_sit:
				model.play("crouch", 0.3)
			elif role == "customer" and not eat_mode:
				_cycle(dt, ["idle", "interact", "talk", "yes", "no", "fold"])
			elif eat_mode or role == "student":
				_cycle(dt, ["sit", "sit", "a/Sitting_Talking"], 4.0)
				_seat_fix()
			else:
				model.play("sit", 0.3)
				_seat_fix()
			return
		"chat":
			step_move(_sep() * 1.2, dt, false)
			if buddy and is_instance_valid(buddy):
				_face(buddy.global_position - global_position, dt)
			model.play("talk" if fmod(Time.get_ticks_msec() * 0.001 + home.z, 6.0) < 3.0 else "idle", 0.3)
			return
		"spar":
			_spar(dt, dist)
			return
		"guard":
			step_move(Vector3.ZERO, dt, false)
			_hold_face(dt)
			if night:
				model.play("b/Idle_Lantern", 0.3)
			else:
				_cycle(dt, ["idle", "fold", "idle"], 6.0)
			return
		"worker":
			_work(dt)
			return
		"job":
			VillagerJobs.tick(self, dt, dist)
			return
		"shopper":
			_shop(dt)
			return
		"ball":
			_ball(dt)
			return
		"teacher", "nurse":
			_wander_small(dt)
			return
	if follow != null:
		_follow(dt)
		return
	if wait > 0.0:
		wait -= dt
		step_move(_sep() * 1.5, dt, false)
		model.play("idle", 0.3)
		return
	var v = goal - global_position
	v.y = 0
	if v.length() < 1.5:
		if going_home:
			vanish()
			return
		_new_goal()
		return
	var mv = NpcNav.steer(self, v.normalized(), dt)
	if role == "drunk":
		var wob = sin(Time.get_ticks_msec() * 0.003 + home.x) * 0.9
		mv = mv.rotated(Vector3.UP, wob)
		_call(dt, dist)
	step_move(mv * speed + _sep() * 1.8, dt)
	model.play("run" if speed > 5.0 else "walk", 0.2, 0.75 if role == "drunk" else 1.0)
	if NpcNav.stuck(self, goal, dt):
		_unstick(dist)


## Takım üyesi: liderin arkasındaki yerini tutar; lider gidince o da gider
func _follow(dt: float) -> void:
	if not is_instance_valid(follow) or follow.fading:
		vanish()
		return
	var f: float = follow.facing
	var want = follow.global_position + Vector3(sin(f), 0, cos(f)) * follow_off.z + Vector3(cos(f), 0, -sin(f)) * follow_off.x
	var tv = want - global_position
	tv.y = 0
	if tv.length() < 0.4:
		step_move(_sep() * 1.5, dt, false)
		model.play("idle", 0.3)
		return
	step_move(NpcNav.steer(self, tv.normalized(), dt) * minf(speed * 1.3, tv.length() * 2.5 + 0.6) + _sep() * 1.8, dt)
	model.play("walk", 0.2)


## Uzun yol: hedefe yaklaştıran, düz hattı açık sokak noktası; hedef yakınsa doğrudan
func _dest_goal() -> void:
	wait = 0.0
	var dd = dest - global_position
	dd.y = 0
	var left = dd.length()
	if left < 3.0:
		vanish()
		return
	var cands: Array = []
	if left < 45.0:
		cands.append(dest)
	var near: Array = []
	for q in points:
		var qp: Vector3 = q["front"] if q is Dictionary else q
		var dq = qp.distance_to(global_position)
		if dq > 10.0 and dq < 55.0 and qp.distance_to(dest) < left - 6.0 and not _taken(qp):
			near.append(qp)
	near.sort_custom(func(a, b): return a.distance_to(dest) < b.distance_to(dest))
	cands.append_array(near.slice(0, 6))
	var pq = NpcNav.pick_clear(self, cands)
	if pq != null:
		goal = pq
	else:
		# sokak noktası yok: hedef yönünde yelpaze, düz hattı açık ilk yön (binaya doğru yürüyüp duvar boyunca sürüklenmesin)
		var base = dd.normalized()
		goal = global_position + base * minf(left, 28.0)
		for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
			var q = global_position + base.rotated(Vector3.UP, ang) * minf(left, 26.0)
			if NpcNav.ray_clear(self, global_position, q):
				goal = q
				break
	NpcNav.reset(self)


func _wander_small(dt: float) -> void:
	if stay:
		step_move(Vector3.ZERO, dt)
		if fixed_face:
			_hold_face(dt)
		model.play("idle", 0.3)
		return
	if wait > 0.0:
		wait -= dt
		step_move(_sep() * 1.2, dt, false)
		if role == "teacher":
			_hold_face(dt)
			_cycle(dt, ["talk", "talk", "yes", "interact"], 2.5)
		else:
			model.play("idle", 0.3)
		return
	var tv = goal - global_position
	tv.y = 0
	if tv.length() < 0.5:
		goal = home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * maxf(1.0, wander_r)
		wait = randf_range(2.5, 6.0)
		return
	step_move(NpcNav.steer(self, tv.normalized(), dt) * 1.2 + _sep() * 1.2, dt)
	model.play("walk", 0.2)
	if NpcNav.stuck(self, goal, dt):
		goal = home
		wait = randf_range(1.0, 3.0)


## Selamlama + çarpma tepkisi + balon süresi
func _social(dt: float, dist: float) -> void:
	greet_cd -= dt
	bump_cd -= dt
	if bubble and bubble.visible:
		bubble_t -= dt
		if bubble_t <= 0.0:
			bubble.visible = false
	if bow_t > 0.0:
		bow_t -= dt
		if bow_t <= 0.0:
			model.overlay.set_pose("bow", 0.0)
	var pl = Game.player
	var pv = Vector2(pl.velocity.x, pl.velocity.z).length()
	if dist < radius + 0.8 and pv > 6.5 and bump_cd <= 0.0 and role != "roof":
		bump_cd = 4.0
		model.play("hit", 0.05, 1.2, true)
		say(["Hey! Dikkat et!", "Ay! Önüne baksana!", "Koşma şurada!", "Ninjalar hep acelede..."].pick_random())
		var away = global_position - pl.global_position
		away.y = 0
		velocity += away.normalized() * 3.0
		wait = maxf(wait, 0.8)
		anim_t = maxf(anim_t, 0.8)
		return
	if dist < 5.5 and greet_cd <= 0.0 and has_meta("world_person") and not has_meta("friend_id") and role != "roof" and follow == null:
		# dünya ninjası seni tanır: yaşananlara göre eğilir, sırtını döner ya da adınla seslenir
		greet_cd = randf_range(45.0, 80.0)
		var rg: Dictionary = WorldDay.regard_node(self)
		if not rg.is_empty():
			react(rg)
			return
	if dist < 4.5 and greet_cd <= 0.0 and role not in ["roof", "spar", "student"]:
		greet_cd = randf_range(20.0, 40.0)
		if randf() < 0.35:
			say(_greeting(), 2.6, false)


## Sana tepki: söz + beden (eğilme / sırt çevirme)
func react(rg: Dictionary) -> void:
	say(String(rg["line"]), 3.6)
	var to = Game.player.global_position - global_position
	to.y = 0
	if role in ["sitter", "customer"] or to.length() < 0.1:
		return
	match String(rg.get("act", "")):
		"bow":
			facing = atan2(-to.x, -to.z)
			if not fixed_face:
				stand_face = facing
			model.rotation.y = facing
			model.overlay.set_pose("bow", 1.0)
			bow_t = 1.7
			wait = maxf(wait, 2.4)
			anim_t = maxf(anim_t, 2.4)
		"turn":
			facing = atan2(to.x, to.z)
			if not fixed_face:
				stand_face = facing
			model.rotation.y = facing
			wait = maxf(wait, 3.0)
			anim_t = maxf(anim_t, 3.0)
		_:
			if role != "spar":
				facing = atan2(-to.x, -to.z)
				model.rotation.y = facing
				wait = maxf(wait, 1.8)


func _greeting() -> String:
	var rank = int(Game.profile.get("rank", 0))
	var t = Game.world.env.time_of_day if Game.world else 0.5
	var hello = "Günaydın" if t < 0.42 else ("İyi akşamlar" if t > 0.72 else "Merhaba")
	if Orgs.is_rogue():   # kaçak: köy rütbesiyle selam yok — Bingo Kitabı sınıfına göre tedirginlik/korku
		var rr = Orgs.rogue_rank()
		if role in ["kid", "ball"]:
			return ["Anne! Alın bandı çizik bir ninja!", "O... kaçak ninja mı?", "Babam senden uzak durmamı söyledi!"][randi() % 3]
		if rr >= 3:
			return ["B-Bingo Kitabı'ndaki S-rank kaçak... (geri çekilir)", "Kimse bakmasın ona... S-rank bir katil...", "Lütfen... burada kimse sana dokunmadı."][randi() % 3]
		if rr == 2:
			return ["Aranan bir kaçak... başına büyük ödül konmuş.", "Muhafızları mı çağırsam... (fısıltı)"][randi() % 2]
		return ["Çizik alın bandı... kaçak bir ninja.", "Sorun çıkarma da git, kaçak.", "Hm. Bir nukenin."][randi() % 3]
	if role in ["kid", "ball"]:
		if rank > 0:
			return ["Vay, gerçek bir ninja!", "Bana bir jutsu göster!", "Alın koruyucun çok havalı!"][randi() % 3]
		return "Sen de akademidesin, değil mi?"
	match rank:
		0:
			return "%s küçük öğrenci, derslerine çalış!" % hello
		1:
			return "%s Genin-san!" % hello
		2:
			return "%s Chunin-san, kolay gelsin." % hello
		3:
			return "Jonin-sama! %s." % hello
	return "...ANBU mu bu? (fısıltı)"


func _call(dt: float, dist: float) -> void:
	call_cd -= dt
	if call_cd <= 0.0:
		call_cd = randf_range(6.0, 13.0)
		if dist < 30.0 and CALLS.has(role):
			say(CALLS[role].pick_random(), 2.0, false)


func _spar(dt: float, dist: float) -> void:
	step_move(Vector3.ZERO, dt, false)
	if buddy == null or not is_instance_valid(buddy):
		_cycle(dt, ["jab", "cross", "hook", "idle"], 1.2)
		return
	_face(buddy.global_position - global_position, dt)
	if kick_t > 0.0:
		kick_t -= dt
		if kick_t <= 0.0:
			model.overlay.set_pose("kick", 0.0)
	anim_t -= dt
	if anim_t > 0.0:
		return
	anim_t = randf_range(0.7, 1.3)
	var k = randi() % 6
	if k < 4:
		model.play(["jab", "cross", "hook", "slash_a"][k], 0.05, 1.3, true)
		if buddy.has_method("_take_spar"):
			buddy._take_spar()
		if dist < 25.0 and randf() < 0.5:
			Sfx.play("punch", global_position, randf_range(0.9, 1.15), 0.4)
	elif k == 4:
		model.overlay.set_pose("kick", 1.0)
		kick_t = 0.35
	else:
		model.play("block", 0.1, 1.0, true)
	if randf() < 0.15:
		say(CALLS["spar"].pick_random(), 1.2, false)


func _take_spar() -> void:
	if randf() < 0.5:
		model.play("block", 0.05, 1.2, true)
	else:
		model.play("hit", 0.05, 1.3, true)
	anim_t = maxf(anim_t, 0.4)


func _work(dt: float) -> void:
	if work_points.size() >= 2:
		# taşıyıcı: iki nokta arasında kalas taşır
		if goal.distance_to(work_points[0]) > 0.5 and goal.distance_to(work_points[1]) > 0.5:
			goal = work_points[0]
		var v = goal - global_position
		v.y = 0
		if v.length() < 1.0 and wait <= 0.0:
			goal = work_points[1] if goal.distance_to(work_points[0]) < 0.5 else work_points[0]
			wait = 1.5
		if wait > 0.0:
			wait -= dt
			step_move(Vector3.ZERO, dt)
			model.play("pickup", 0.2)
			VillagerJobs.carry_plank(self, false)
			return
		step_move(v.normalized() * 1.6, dt)
		model.play("b/Walk_Carry", 0.2)
		VillagerJobs.carry_plank(self, true)
		return
	step_move(Vector3.ZERO, dt, false)
	_hold_face(dt)
	_cycle(dt, work_anims if not work_anims.is_empty() else ["b/TreeChopping", "a/Fixing_Kneeling"], 2.5)
	_call(dt, global_position.distance_to(Game.player.global_position))


func _shop(dt: float) -> void:
	if wait > 0.0:
		wait -= dt
		step_move(_sep() * 1.2, dt, false)
		_hold_face(dt)
		_cycle(dt, ["talk", "yes", "no", "interact", "idle", "talk"], 2.0)
		if wait <= 0.0:
			_pick_stall()
		elif randf() < dt * 0.04:
			say(LINES["shopper"].pick_random(), 2.2, false)
		return
	var v = goal - global_position
	v.y = 0
	if v.length() < 0.9:
		wait = randf_range(6.0, 14.0)
		return
	step_move(NpcNav.steer(self, v.normalized(), dt) * 2.4 + _sep() * 1.8, dt)
	model.play("walk", 0.2)
	if NpcNav.stuck(self, goal, dt):
		if int(nav.get("n", 0)) >= 3 and global_position.distance_to(Game.player.global_position) > 30.0:
			global_position = goal  # görünmezken sıkıştıysa yerine al
			nav["n"] = 0
		else:
			_pick_stall()


func _pick_stall() -> void:
	if points.is_empty():
		return
	for k in 4:   # tezgâh önünde başka alışverişçinin durduğu yere değil
		var s = points.pick_random()
		if s is Dictionary:
			goal = s["front"] + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.4, 0.4))
			stand_face = s["face"]
		else:
			goal = s
		if not _taken(goal):
			break
	_claim(goal)


func _ball(dt: float) -> void:
	var v = goal - global_position
	v.y = 0
	if kick_t > 0.0:
		kick_t -= dt
		step_move(Vector3.ZERO, dt)
		if kick_t <= 0.0:
			model.overlay.set_pose("kick", 0.0)
		return
	if v.length() < 0.6:
		step_move(_sep() * 1.5, dt, false)
		model.play("idle", 0.2)
		return
	_face(v, dt)
	step_move(v.normalized() * minf(5.5, v.length() * 2.5) + _sep() * 2.0, dt, false)
	model.play("jog" if v.length() > 1.5 else "walk", 0.15)


func kick_ball() -> void:
	model.overlay.set_pose("kick", 1.0)
	kick_t = 0.3
	if randf() < 0.3:
		say(CALLS["ball"].pick_random(), 1.2, false)


func _new_goal() -> void:
	if dest != Vector3.INF:
		_dest_goal()
		return
	match role:
		"kid":
			# kovalamaca: ev noktası etrafında hızlı koşuşturma (düz hattı açık nokta)
			var ks: Array = []
			for k in 4:
				ks.append(home + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14)))
			var kq = NpcNav.pick_clear(self, ks)
			goal = kq if kq != null else home
			wait = randf_range(0.0, 0.6)
			if randf() < 0.15:
				Sfx.play("jump", global_position, 1.5, 0.4)
		"drunk":
			goal = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			wait = randf_range(1.0, 4.0)
			if randf() < 0.3:
				model.play("dance", 0.3)
		_:
			# sokak noktalarından yakın (8-70 m) ve düz hattı açık olanı seç: köyün öbür ucuna,
			# evlerin içinden geçen bir hatta yürüyüp duvara yapışmasın
			var cands: Array = []
			if not points.is_empty():
				for k in 10:
					var q = points.pick_random()
					var qp: Vector3 = q["front"] if q is Dictionary else q
					var dq = qp.distance_to(global_position)
					if dq > 8.0 and dq < 70.0 and not _taken(qp):
						cands.append(qp)
					if cands.size() >= 5:
						break
			var pq = NpcNav.pick_clear(self, cands)
			if pq != null:
				goal = pq
			elif not cands.is_empty():
				goal = cands[0]
			else:
				goal = home
			wait = randf_range(0.5, 6.0) if role == "walker" else randf_range(0.0, 1.0)
	_claim(goal)
	NpcNav.reset(self)


## Takıldı: önce yeni hedef; art arda takılırsa başladığı sokak noktasına dön; görünmezken hâlâ
## sıkışıksa oraya yerleş (duvara yapışık kalmasın)
func _unstick(dist: float) -> void:
	var k = int(nav.get("n", 0))
	if dest != Vector3.INF:
		if k >= 4:
			vanish()
		else:
			_new_goal()
			nav["n"] = k
		return
	if going_home:
		if k >= 2:
			vanish()  # kapıya ulaşamadı: yine de "eve girdi"
		return
	if k >= 4 and dist > 30.0:
		global_position = home
		velocity = Vector3.ZERO
		nav["n"] = 0
		_new_goal()
	elif k >= 2:
		goal = home
		NpcNav.reset(self)
	else:
		_new_goal()


## Çatıdan çatıya sekerek koşan ninja
func _roof(dt: float) -> void:
	if points.size() < 2:
		return
	if hop_t < 0.0:
		var best: Vector3 = points[0]
		var bd = 1e9
		for i in 6:
			var q: Vector3 = points.pick_random()
			var d = q.distance_to(global_position)
			if d > 8.0 and d < 40.0 and d < bd:
				bd = d; best = q
		if bd > 1e8:
			best = points.pick_random()
			global_position = best
			return
		hop_from = global_position
		hop_to = best
		hop_t = 0.0
		var to = hop_to - hop_from
		facing = atan2(-to.x, -to.z)
		model.rotation.y = facing
		model.play("jump", 0.05, 1.4, true)
	var dur = maxf(0.6, hop_from.distance_to(hop_to) / speed)
	hop_t += dt / dur
	var k = clampf(hop_t, 0.0, 1.0)
	var p = hop_from.lerp(hop_to, k)
	p.y += sin(k * PI) * (4.0 + hop_from.distance_to(hop_to) * 0.15)
	global_position = p
	if k > 0.25 and k < 0.9:
		model.play("air", 0.2)
	if hop_t >= 1.0:
		hop_t = -1.0
		model.play("land", 0.05, 1.5, true)
		if randf() < 0.3:
			hop_t = -0.4  # kısa bekleme (negatif sayaç)


## Rolün kıyafet arketipi (Outfits): sokak halkı çeşitli, ninjalar köy üniformalı
func _outfit_arch() -> String:
	match role:
		"kid", "ball":
			return "kid"
		"student":
			return "student"
		"patrol", "roof":
			return "chunin" if randf() < 0.8 else "jonin"
		"guard":
			return "guard"
		"spar":
			return ["genin", "genin", "chunin"].pick_random()
		"teacher":
			return ["chunin", "jonin"].pick_random()
		"sitter":
			return "elder"
		"vendor", "keeper":
			return "merchant"
		"nurse":
			return "medic"
		"worker":
			return "worker"
		"job":
			return VillagerJobs.arch(self)
		"drunk":
			return ["civ", "traveler"].pick_random()
	var r = randf()
	if r < 0.08:
		return "traveler"
	if r < 0.13:
		return "farmer"
	if r < 0.16:
		return "monk"
	if r < 0.2:
		return "merchant"
	if r < 0.23:
		return "noble"
	if r < 0.3 and role in ["walker", "chat"]:
		return ["genin", "chunin"].pick_random()
	return "civ"
