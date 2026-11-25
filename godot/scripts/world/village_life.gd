extends Node3D
## Köy hayatı yöneticisi: oyuncu bir köydeyken çevresinde kalabalık tutar (yakında doğar, uzaklaşınca kaybolur).
## Günün saatine göre program: sabah işe/akademiye gidenler, öğlen pazar kalabalığı, akşam eve dönenler, gece nöbetçiler.
## Sabit mekânlar (tezgâhlar, antrenman, inşaat, banklar, top oynayan çocuklar, kapı nöbetçileri, meyhane önü)
## Builder kayıtlarından (sites) gelir; oyuncu yaklaşınca canlanır.

## köy id -> [{type, pos, face(rad), ...}]
static var sites := {}
const VillagerJobs = preload("res://scripts/actors/villager_jobs.gd")
static var doors := {}  # köy id -> [kapı önü noktaları] (akşam eve girenler)

const PHASE_ROLES := {
	"sabah": [["walker", 40], ["kid", 26], ["chat", 8], ["patrol", 8], ["roof", 6], ["animal", 8]],
	"oglen": [["walker", 36], ["kid", 14], ["chat", 16], ["shopper", 18], ["patrol", 6], ["roof", 6], ["animal", 8]],
	"aksam": [["walker", 50], ["kid", 8], ["chat", 16], ["patrol", 8], ["roof", 4], ["animal", 8]],
	"gece": [["walker", 14], ["patrol", 16], ["roof", 4], ["animal", 6]],
}

var npcs: Array = []
var current := ""
var t := 0.0
var street_cache := {}
var spawn_cd := 0.0   # köylü kurulumu ~80 ms: art arda her karede değil, aralıklı (köye girerken saniyelerce kasma)
var queue: Array = []  # bekleyen doğumlar: her karede en fazla bir karakter modeli yaratılır (takılma olmasın)
var active_sites := {}  # site index -> [nodes]
var phase := "oglen"
var interiors: Interiors
var crowd: AudioStreamPlayer3D
var glow_t := 0.0


func _ready() -> void:
	CharacterModel.prewarm()   # saç/yüz modelleri arka planda yüklensin
	interiors = Interiors.new()
	interiors.name = "Interiors"
	add_child(interiors)
	_add_village_trainers()
	WorldDay.vl = self


var hair_wait := 0     # yüzü / saçı hazırlanırken geri çevrilen kişi sayısı (üst sınır: sonsuza dek beklenmez)
var allow_defer := false   # yalnız sıradan gelen isteklerde: kişi hazır değilse istek sıraya geri döner
var deferred := false
var _planned := {}      # rol|yer -> sahneye girmeyi bekleyen (yüzü hazırlanan) yeni köylü


func _village_at(p: Vector3) -> Dictionary:
	if interiors and interiors.inside != "":
		return {}
	var m = Game.to_map(p)
	for v in Game.world_info["villages"]:
		if m.distance_to(Vector2(v["x"], v["y"])) < float(v["r"]) * 1.05:
			return v
	return {}


## Köyün sokak noktaları: yol ağındaki "street" parçalarından örneklenir (yanlara hafif sapma)
func _streets(v: Dictionary) -> Array:
	if street_cache.has(v["id"]):
		VillageSpots.top_up(street_cache[v["id"]], v)   # ara sokak / avlu / park noktaları (parklar sonradan kurulur)
		return street_cache[v["id"]]
	var pts: Array = []
	var c = Vector2(float(v["x"]), float(v["y"]))
	var r: float = v["r"]
	var segs: Array = Game.road_segments_near(c, r)
	for e in segs:
		var rd: Dictionary = Game.roads[e.x]
		if rd["kind"] != "street" and rd["kind"] != "road":
			continue
		var pa: Vector2 = rd["pts"][e.y]
		var pb: Vector2 = rd["pts"][e.y + 1]
		var L = pa.distance_to(pb)
		var n = int(L / 18.0)
		for i in n:
			var q = pa.lerp(pb, (float(i) + randf()) / maxf(1.0, n))
			if q.distance_to(c) > r * 0.97:
				continue
			var side = (pb - pa).normalized().orthogonal() * randf_range(-4.0, 4.0)
			var wq = Game.from_map(q + side)
			pts.append(wq)
			if rd["kind"] == "road":
				main_pts[_wkey(wq)] = true   # ana cadde: daha kalabalık
	if pts.is_empty():
		for i in 120:
			var a2 = randf() * TAU
			pts.append(Game.from_map(c + Vector2(cos(a2), sin(a2)) * sqrt(randf()) * r * 0.9))
	VillageSpots.top_up(pts, v)
	street_cache[v["id"]] = pts
	return pts


# ------------------------------------------------------------------ doğal dağılım
## Yoğunluk dünyadan: ana cadde ve pazar / ramen / meyhane / meydan çevresi kalabalık, ara sokak birkaç kişi, park biraz.
## Her ~15 m'lik çevrenin sığası var (yığılma olmaz); kalabalık sayısı oyuncunun çevresindeki gerçek sokak miktarıyla orantılı
## (köy kenarında / kapıda dururken 36 kişi birkaç sokağa sıkışıyordu).
var main_pts := {}     # ana cadde noktaları (anahtar: _wkey)
var _w_cache := {}
var _ref_cache := {}   # köy -> [nokta sayısı, tam pencerede beklenen nokta]
const BUSY_SITES := ["stall", "ramen", "crowd", "bar", "pigeons", "academy_yard"]
## İş yerleri (VillagerJobs): tarla, hastane önü, ANBU karargâhı, polis binası, Kage meydanı haberciler, akademi atış alanı,
## klan dōjō'su, dükkân önü, nehir kıyısı. Oyuncunun yakınındaki işçi sayısı JOB_CAP ile sınırlı (en yakın yerler önce);
## sokak kalabalığı işçi kadar azalır (toplam kişi sayısı artmaz, boştaki yürüyenler işe geçmiş olur).
const JOB_SITES := ["farm", "hospital", "anbu", "police", "messenger", "drill", "dojo", "sweep", "fish"]
const NIGHT_ROSTER := ["hospital", "anbu", "police"]   # gece vardiyası: kadro değişir (akşam yeniden kurulur)
const JOB_CAP := 18


static func _wkey(q: Vector3) -> Vector3i:
	return Vector3i(roundi(q.x), 0, roundi(q.z))


func _spot_w(vid: String, q: Vector3) -> float:
	var k = _wkey(q)
	if _w_cache.has(k):
		return _w_cache[k]
	var w = 1.0
	if main_pts.has(k):
		w += 1.0
	for st in sites.get(vid, []):
		if String(st.get("type", "")) in BUSY_SITES and (st["pos"] as Vector3).distance_to(q) < 35.0:
			w += 1.5
			break
	_w_cache[k] = w
	return w


## Adaylardan ağırlıklı, sığası dolmamış bir nokta (yoksa null). extra: aynı turda verilmiş yerler
func _pick_spot(vid: String, near: Array, tries := 10):
	var best = null
	var bs = -1.0
	for t2 in tries:
		var cand: Vector3 = near.pick_random()
		var w = _spot_w(vid, cand)
		var cnt = 0
		for nn in npcs:
			if is_instance_valid(nn) and (nn as Node3D).global_position.distance_squared_to(cand) < 225.0:
				cnt += 1
		for qq in queue:
			if qq.size() > 1 and qq[1] is Vector3 and (qq[1] as Vector3).distance_squared_to(cand) < 225.0:
				cnt += 2 if qq[0] == "chat2" else 1
		if cnt >= 1 + int(w * 1.5):
			continue   # bu çevre dolu (ara sokak 2, cadde 4, pazar 4-6 kişi)
		var sc = w * randf_range(0.4, 1.0) / (1.0 + cnt)
		if sc > bs:
			bs = sc
			best = cand
	return best


## Tam bir pencerede (220 m) beklenen sokak noktası sayısı: köyün nokta yoğunluğu × pencere alanı
func _ref_points(v: Dictionary, streets: Array) -> float:
	var rc = _ref_cache.get(v["id"], [])
	if not rc.is_empty() and int(rc[0]) == streets.size():
		return float(rc[1])
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var rmax = 1.0
	for q in streets:
		rmax = maxf(rmax, Vector2(q.x - c.x, q.z - c.z).length())
	var ref = float(streets.size()) * minf(1.0, (220.0 * 220.0) / (rmax * rmax))
	_ref_cache[v["id"]] = [streets.size(), ref]
	return ref


## Büyük köylerin antrenman alanına eğitmen (etkileşim + NPC). Konoha kendi kurulumunda ekler.
func _add_village_trainers() -> void:
	for vid in ["suna", "kiri", "kumo", "iwa", "ame", "kusa", "taki", "oto", "yu", "shimo", "tani", "nami", "uzushio", "tetsu"]:
		var v = Game.village(vid)
		if v.is_empty():
			continue
		var has = false
		for it in Interact.items:
			if it["kind"] == "trainer" and it.get("village", "") == vid:
				has = true
		if has:
			continue
		var c = Vector2(float(v["x"]), float(v["y"]))
		var r = float(v["r"])
		var best = c + Vector2(r * 0.3, 0)
		var bd = 1e9
		for e in Game.road_segments_near(c, r * 0.6):
			var rd: Dictionary = Game.roads[e.x]
			var q: Vector2 = (rd["pts"][e.y] + rd["pts"][e.y + 1]) * 0.5
			var d = absf(q.distance_to(c) - r * 0.3)
			if d < bd:
				bd = d
				var dirv: Vector2 = (rd["pts"][e.y + 1] - rd["pts"][e.y]).normalized()
				best = q + dirv.orthogonal() * 10.0
		var wp = Game.from_map(best)
		var title = "%s Eğitmeni" % String(v.get("name", vid)).replace("gakure", "")
		Interact.add({"pos": wp + Vector3(0, 0.4, 0), "radius": 3.5, "kind": "trainer", "village": vid, "title": title,
			"label": "[F] %s: jutsu öğren" % title})
		if not sites.has(vid):
			sites[vid] = []
		sites[vid].append({"type": "trainer", "pos": wp + Vector3(0, 0, -1.2), "face": 0.0, "title": title})


static func _phase_of(tod: float) -> String:
	if tod < 0.24 or tod > 0.8:
		return "gece"
	if tod < 0.42:
		return "sabah"
	if tod < 0.62:
		return "oglen"
	return "aksam"


func _process(dt: float) -> void:
	# gece parıltısı (fenerler) — saniyede bir
	glow_t -= dt
	if glow_t <= 0.0 and Game.world:
		glow_t = 1.0
		var tod: float = Game.world.env.time_of_day
		var nk = 1.0 - smoothstep(0.22, 0.3, tod) + smoothstep(0.72, 0.8, tod)
		CityDecor.set_night(clampf(nk, 0.0, 1.0))
	if Game.player == null or Game.paused:
		return
	spawn_cd -= dt
	# ön kurulum sürerken sıra dönmez: biten kişi hemen girer (sıra dönünce her kişi bir tam tur bekliyor, köy dolmuyordu)
	var staging = is_instance_valid(_building) and not _building.built and Time.get_ticks_msec() - _building_t < 3000
	if not queue.is_empty() and spawn_cd <= 0.0 and not staging:
		# oyuncu koşarken / atılırken (Ctrl) yeni karakter kurma: hareket bitince sırayla gelirler
		var spd = Game.player.velocity.length() if "velocity" in Game.player else 0.0
		if spd < 9.0 or npcs.size() < 4:
			var rq = queue.pop_front()
			allow_defer = true
			deferred = false
			_stage_front = false
			_spawn(rq)
			allow_defer = false
			if deferred and _stage_front:
				queue.push_front(rq)   # modeli ön kurulumda: bitince ilk o girer
				spawn_cd = 0.0
			elif deferred:
				queue.push_back(rq)   # yüzü / saçı arka planda hazırlanıyor: biraz sonra yeniden
				spawn_cd = 0.12
			else:
				spawn_cd = 0.3
	t -= dt
	if t > 0.0:
		return
	t = 0.8
	_sweep_pend()
	var p = Game.player.global_position
	# Chūnin Sınavı sürerken (orman, ön eleme, final yolu/final) sınav alanında sıradan köylü olmaz: sokak ve mekân NPC'leri kalkar, yenisi gelmez
	if int(ChuninExam.stage) in [2, 3, 4, 5]:
		for n in npcs.duplicate():
			if is_instance_valid(n) and n.global_position.distance_to(p) < 220.0:
				n.queue_free()
				npcs.erase(n)
		for key in active_sites:
			for n in (active_sites[key]["nodes"] as Array).duplicate():
				if is_instance_valid(n) and n is Villager and n.global_position.distance_to(p) < 220.0:
					n.queue_free()
					active_sites[key]["nodes"].erase(n)
		for pv in _planned.values():
			if is_instance_valid(pv):
				pv.free()   # sahneye hiç girmedi
		_planned.clear()
		queue.clear()
		return
	var v = _village_at(p)
	var tod2: float = Game.world.env.time_of_day if Game.world else 0.5
	var new_phase = _phase_of(tod2)
	if new_phase != phase:
		phase = new_phase
		if phase == "aksam" or phase == "gece":
			_send_home(v)
		_world_shift(p)
	# uzaklaşanları temizle (karede birkaç tane). Köy içindeyken uzaklaşan sokak NPC'si silinmez,
	# oyuncunun yakınına taşınır (_recycle): koşarken her karede yeni karakter modeli kurmak (25-130 ms) takılma yapıyordu
	var freed = 0
	var far: Array = []
	for n in npcs.duplicate():
		if not is_instance_valid(n):
			npcs.erase(n)
		elif v.is_empty() or v["id"] != current:
			if freed < 6:
				freed += 1
				n.queue_free()
				npcs.erase(n)
		else:
			var dn = n.global_position.distance_to(p)
			if dn > 150.0:
				far.append(n)
			_shadow_lod(n, dn)
	_relocate(v)
	_update_sites(v, p)
	_update_crowd(v, p)
	if v.is_empty():
		current = ""
		queue = queue.filter(func(r): return r[0] == "__never")
		return
	# büyük gizli köyler Konoha kadar kalabalık; küçük kasabalar daha sakin (eskiden 22 kişi koca köye dağılıp boş görünüyordu)
	var big = v["id"] in ["konoha", "suna", "kiri", "kumo", "iwa"]
	var base = int((36 if big else 18) * maxf(0.35, Game.npc_scale))
	var target = base if phase != "gece" else int(base * 0.4)
	var streets = _streets(v)
	var roofs: Array = Builder.roof_points.get(v["id"], [])
	# sokak noktaları (Konoha'da binlerce): uzaklık süzgeci tikte BİR kez (her köylü / her grup için yeniden süzmek ~40 ms takılmaydı)
	var near_r: Array = []
	var near_spawn: Array = []
	var near_far: Array = []
	var inner = 22.0 if current == v["id"] else 4.0
	for q in streets:
		var dq = q.distance_to(p)
		if dq < 220.0:
			near_far.append(q)
			if dq < 170.0 and dq > inner:
				near_spawn.append(q)
			if dq < 140.0 and dq > 35.0:
				near_r.append(q)
	# kalabalık, çevredeki gerçek sokak miktarıyla orantılı
	var fill = clampf(float(near_far.size()) / maxf(1.0, _ref_points(v, streets)), 0.2, 1.0)
	target = maxi(2, int(round(target * fill)))
	target = maxi(2, target - int(_job_count() * 0.6))   # işe geçenler sokaktan eksilir (toplam kişi sayısı aynı kalır)
	for n in far:
		if is_instance_valid(n) and not _recycle(n, near_r, roofs, p, true):
			n.queue_free()
			npcs.erase(n)
	var planned = npcs.size() + queue.size()
	# kalabalık ayarı düşürüldü: fazlalardan, oyuncuya uzak olanı her tikte bir tane dağıt (göz önünde kaybolmasın)
	if npcs.size() > target + 2:
		for n in npcs:
			if is_instance_valid(n) and n.global_position.distance_to(p) > 45.0:
				n.queue_free()
				npcs.erase(n)
				break
	var groups = 0
	while planned < target and groups < 6:
		groups += 1
		var role = _pick_role()
		var near: Array = near_spawn.duplicate()
		if near.is_empty():
			# yakında sokak noktası yok (Kiri'nin geniş meydanları, köprüler): uzaktaki sokaklar, o da yoksa çevredeki açık zemin
			near = near_far.duplicate()
		if near.is_empty():
			for k in 6:
				var a = randf() * TAU
				var q = Missions.open_ground(p + Vector3(cos(a), 0, sin(a)) * randf_range(25.0, 70.0), 12.0)
				if Game.terrain_height(q.x, q.z) > 0.3:   # suya değil
					near.append(q)
		if near.is_empty():
			break
		# yer: bölgenin yoğunluğuna göre ağırlıklı, çevresi dolu olan atlanır (yığılma yok, ana cadde / pazar daha canlı)
		var atv = _pick_spot(String(v["id"]), near)
		if atv == null:
			break   # yakındaki tüm çevreler dolu
		var at: Vector3 = atv
		match role:
			"chat":
				queue.append(["chat2", at, streets])
				planned += 2
			"kid":
				for k in randi_range(2, 4):
					queue.append(["kid", at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), streets])
					planned += 1
			"roof":
				var near_roofs: Array = roofs.filter(func(q): return q.distance_to(p) < 110.0)
				if near_roofs.size() > 3:
					queue.append(["roof", near_roofs.pick_random(), near_roofs])
					planned += 1
			"shopper":
				var stalls = _stalls(v)
				if not stalls.is_empty():
					queue.append(["shopper", at, stalls])
					planned += 1
			_:
				queue.append([role, at, streets])
				planned += 1
	current = v["id"]


## Uzaklaşan sokak NPC'sini oyuncunun 30-150 m çevresinde, görüş dışındaki bir sokak noktasına taşı (modeli yeniden kurmadan)
func _recycle(n: Node3D, streets: Array, roofs: Array, p: Vector3, prefiltered := false) -> bool:
	if n is Villager:
		if n.fading or n.going_home or n.role in ["shopper"]:
			return false
		if n.has_meta("world_person") and not WorldDay.still(n):
			return false   # günün dilimi değişti: artık başka yerde
		if n.role == "roof":
			var nr: Array = roofs.filter(func(q): return q.distance_to(p) < 110.0 and q.distance_to(p) > 40.0)
			if nr.size() < 4:
				return false
			n.points = nr
			n.hop_t = -1.0
			n.global_position = nr.pick_random()
			n.home = n.global_position
			return true
	var near: Array = streets if prefiltered else streets.filter(func(q): return q.distance_to(p) < 140.0 and q.distance_to(p) > 35.0)
	if near.is_empty():
		return false
	var cam = get_viewport().get_camera_3d()
	var vid = current
	var at: Vector3 = near.pick_random()
	for k in 6:   # kamera önüne doğmasın; dolu çevreye taşınmasın
		var pk = _pick_spot(vid, near, 6)
		if pk == null:
			return false
		at = pk
		if cam == null or not cam.is_position_in_frustum(at + Vector3(0, 1, 0)):
			break
	at.y = Game.ground_height(at.x, at.z)
	n.global_position = at
	if "velocity" in n:
		n.velocity = Vector3.ZERO
	if n is Villager:
		n.home = at
		n.goal = at
		n.wait = randf_range(0.0, 2.0)
		n.nav = {}
		if is_instance_valid(n.buddy):   # sohbet eşi de yanına
			if n.buddy.global_position.distance_to(p) > 150.0:
				n.buddy.global_position = at + Vector3(1.4, 0, 0.3)
				n.buddy.home = n.buddy.global_position
				n.buddy.goal = n.buddy.global_position
			else:
				n.buddy.buddy = null
				n.buddy = null
	n.reset_physics_interpolation()
	return true


## Kurulumda (fizik yokken) konan tezgâhlar: oyuncu köydeyken bir kez açık zemine taşınır
var _relocated := {}


func _relocate(v: Dictionary) -> void:
	if v.is_empty() or _relocated.get(v["id"], 0.0) < 0.0:
		return
	# köye girdikten ~3 sn sonra (binaların çarpışma gövdeleri yüklenmiş olsun)
	_relocated[v["id"]] = float(_relocated.get(v["id"], 0.0)) + 0.8
	if float(_relocated[v["id"]]) < 3.0:
		return
	_relocated[v["id"]] = -1.0
	for it in Interact.items:
		if not it.get("relocate", false) or String(it.get("village", "")) != String(v["id"]):
			continue
		var off: Vector3 = it.get("node_off", Vector3.ZERO)
		var base: Vector3 = it["pos"] + off
		var q = Missions.open_ground(base, 40.0)
		it["pos"] = q - off
		var n = it.get("node")
		if n and is_instance_valid(n):
			n.global_position = q


func _stalls(v: Dictionary) -> Array:
	var out = []
	for s in sites.get(v["id"], []):
		if s["type"] == "stall":
			out.append({"front": s["front"], "face": s["face"]})
	return out


## Akşam: sokaktaki yürüyenlerin bir kısmı en yakın kapıya yürüyüp "eve girer"
func _send_home(v: Dictionary) -> void:
	if v.is_empty():
		return
	var ds: Array = doors.get(v["id"], [])
	if ds.is_empty():
		return
	for n in npcs:
		if is_instance_valid(n) and n is Villager and n.role in ["walker", "kid", "chat"] and randf() < (0.5 if phase == "aksam" else 0.85):
			var best = ds[0]
			var bd = 1e9
			for k in 12:
				var q: Vector3 = ds.pick_random()
				var d = q.distance_to(n.global_position)
				if d < bd:
					bd = d; best = q
			n.role = "walker"
			n.going_home = true
			n.goal = best
			n.wait = 0.0


## Günün dilimi değişti: işi biten dünya ninjaları çekilir (sokaktakiler evine yürür; uzaktaki mekânlar yeni kişilerle açılır)
func _world_shift(p: Vector3) -> void:
	var ds: Array = doors.get(current, [])
	for n in npcs:
		if is_instance_valid(n) and n is Villager and n.has_meta("world_person") and not n.fading and not WorldDay.still(n):
			if ds.is_empty() or n.role == "roof":
				if n.global_position.distance_to(p) > 30.0:
					n.vanish()
				continue
			var best: Vector3 = ds[0]
			for k in 12:
				var q: Vector3 = ds.pick_random()
				if q.distance_to(n.global_position) < best.distance_to(n.global_position):
					best = q
			n.role = "walker"
			n.going_home = true
			n.goal = best
			n.wait = 0.0
	for key in active_sites.keys():
		var info: Dictionary = active_sites[key]
		if (info["site"]["pos"] as Vector3).distance_to(p) < 30.0:
			continue
		if (info["nodes"] as Array).any(func(n): return is_instance_valid(n) and n is Villager and n.has_meta("world_person") and not WorldDay.still(n)):
			for n in info["nodes"]:
				if is_instance_valid(n):
					n.queue_free()
			active_sites.erase(key)


func _pick_role() -> String:
	var roles: Array = PHASE_ROLES[phase]
	var total = 0
	for r in roles:
		total += r[1]
	var k = randi() % total
	for r in roles:
		k -= r[1]
		if k < 0:
			return r[0]
	return "walker"


func _spawn(req: Array) -> void:
	match req[0]:
		"animal":
			var c = CatNPC.new()
			c.ambient = true
			c.is_dog = randf() < 0.5
			add_child(c)
			c.global_position = req[1]
			npcs.append(c)
		"chat2":
			# sohbet çifti: ikinci kişi bir sonraki karede gelir
			var a = _villager("chat", req[1], req[2])
			if a == null:
				return
			queue.push_front(["chat_b", req[1] + Vector3(1.4, 0, 0.3), req[2], a])
		"chat_b":
			var b = _villager("chat", req[1], req[2])
			if b == null:
				return
			var a = req[3]
			if is_instance_valid(a):
				a.buddy = b
				b.buddy = a
				WorldDay.paired(a, b, "gezi")
		"site":
			_spawn_site_actor(req[1], req[2], req[3])
		_:
			var vg = _villager(req[0], req[1], req[2])
			if vg == null:
				return
			if req[0] == "shopper":
				vg._pick_stall()
			elif req[0] == "kid" and phase == "sabah":
				# sabah çocuklar akademiye koşar
				var ac = _site_pos(current, "academy_yard")
				if ac != Vector3.INF:
					vg.home = ac + Vector3(randf_range(-10, 10), 0, randf_range(-6, 6))
					vg.goal = vg.home


func _site_pos(vid: String, type: String) -> Vector3:
	for s in sites.get(vid, []):
		if s["type"] == type:
			return s["pos"]
	return Vector3.INF


func _villager(role: String, at: Vector3, pts: Array, extra := {}, skey := "", fid := "") -> Villager:
	# ön kurulum: kişinin modeli sahne dışında, aşamaları ayrı karelere yayılarak kurulur (giriş karesi takılmaz).
	# Kararlar (kim, hangi görünüş) bir kez verilir ve _pend'de saklanır; istek geri döndükçe yalnız "bitti mi" bakılır.
	# mekân kişisinde yer her denemede yeniden aranır (boş nokta): anahtar mekândan; sokak kişisinde istek yeri sabittir
	var rk = ("%s|%s|%s" % [role, skey, fid]) if skey != "" else ("%s|%.1f|%.1f" % [role, at.x, at.z])
	var stage_on = allow_defer and OS.get_environment("VL_NOSTAGE") == ""
	if stage_on:
		if _pend.has(rk):
			var pd: Dictionary = _pend[rk]
			pd["seen"] = Time.get_ticks_msec()
			pd["at"] = at
			if is_instance_valid(pd["m"]) and not pd["m"].built and Time.get_ticks_msec() - int(pd["t0"]) < 3000:
				deferred = true
				_stage_front = true
				return null
			_pend.erase(rk)
			if is_instance_valid(pd["m"]) and not pd["m"].built:
				pd["m"].queue_free()   # 3 sn'de bitmedi (kurulum bir yerde kaldı): eski yolla, tek karede kurulur
				pd["m"] = null
			return _enter(pd)
		elif is_instance_valid(_building) and not _building.built and Time.get_ticks_msec() - _building_t < 3000:
			deferred = true   # aynı anda tek ön kurulum
			return null
	# bu işi şu an yapan gerçek bir dünya ninjası varsa o gelir (adı, yüzü, hayatı kendi)
	var wp := {}
	var wact = String(WorldDay.ROLE_ACT.get(role, ""))
	if wact != "" and fid == "" and not extra.has("look_extra") and not extra.has("display_override"):
		wp = WorldDay.cast(WorldDay.village_of(at), wact, at)
		if not wp.is_empty():
			var wd: Dictionary = WorldDay.dress(wp, wact)
			# yüzü / saçı henüz hazır değilse (arka planda başlatıldı) kişi şimdi gelmez: istek sıraya döner, hazır olunca çıkar
			if allow_defer and hair_wait < 60 and not CharacterModel.prepare(wd.get("look_extra", {})):
				hair_wait += 1
				deferred = true
				return null
			hair_wait = 0
			extra = extra.duplicate()
			extra.merge(wd, true)
	# ninja değilse: köyün kalıcı sivillerinden biri (yoksa yeni yüz kayda geçer)
	var fk := {}
	if wp.is_empty() and fid == "" and role in WorldFolk.ROLES and not extra.has("look_extra") and not extra.has("display_override") and not extra.get("interior", false):
		var fvid = WorldDay.village_of(at)
		var fsite = (skey + ":" + role) if skey != "" and role in ["vendor", "keeper"] else ""
		if fvid != "":
			fk = WorldFolk.cast(fvid, role, fsite)
			extra = extra.duplicate()
			if fk.is_empty():
				extra["folk_vid"] = fvid
				extra["folk_site"] = fsite
			else:
				var fdr: Dictionary = WorldFolk.dress(fk)
				if allow_defer and hair_wait < 60 and not CharacterModel.prepare(fdr.get("look_extra", {})):
					hair_wait += 1
					deferred = true
					return null
				hair_wait = 0
				extra.merge(fdr, true)
	# yeni yüz (kayıtlı kişi değil): görünüşü sahneye girmeden kararlaştırılır, yüzü / saçı arka planda hazırlanır; hazır
	# değilse istek sıraya döner ve AYNI kişi (aynı görünüş) hazır olunca çıkar
	var plain = wp.is_empty() and fk.is_empty() and fid == "" and not extra.has("look_extra")
	var pkey = "%s|%s" % [role, skey]
	var vg: Villager = null
	if plain and _planned.has(pkey):
		vg = _planned[pkey]
		_planned.erase(pkey)
		if not is_instance_valid(vg):
			vg = null
	if vg == null:
		vg = Villager.new()
		vg.role = role
	for k in extra:
		vg.set(k, extra[k])
	vg.points = pts
	vg.night = phase == "gece"
	if plain and allow_defer and hair_wait < 60:
		vg.plan_look()
		if not CharacterModel.prepare(vg.look):
			_planned[pkey] = vg
			hair_wait += 1
			deferred = true
			return null
		hair_wait = 0
	var pd2 := {"vg": vg, "m": null, "at": at, "role": role, "wp": wp, "wact": wact, "fk": fk, "skey": skey, "fid": fid, "seen": Time.get_ticks_msec()}
	if stage_on:
		vg.plan_look()
		if _holder == null:
			_holder = Node3D.new()
			_holder.visible = false
			add_child(_holder)
			_holder.position = Vector3(0, -900, 0)
		var pm = CharacterModel.new()
		pm.staged = true
		_holder.add_child(pm)
		pm.setup(vg.look)
		_building = pm
		_building_t = Time.get_ticks_msec()
		pd2["m"] = pm
		pd2["t0"] = _building_t
		_pend[rk] = pd2
		deferred = true
		_stage_front = true
		return null
	return _enter(pd2)


var _pend := {}        # istek anahtarı -> ön kurulumu süren kişi (kararları verilmiş, henüz sahnede değil)
var _holder: Node3D
var _building: CharacterModel
var _building_t := 0
var _stage_front := false
var staged_n := 0


## Kararı verilmiş (ve varsa modeli hazır) kişiyi sahneye sokar
func _enter(pd: Dictionary) -> Villager:
	var vg: Villager = pd["vg"]
	var at: Vector3 = pd["at"]
	if not is_instance_valid(vg):
		return null
	var pm = pd["m"]
	if pm != null and is_instance_valid(pm):
		_holder.remove_child(pm)
		pm.position = Vector3.ZERO
		vg.model = pm
		staged_n += 1
	if pd["skey"] != "":
		vg.set_meta("site_key", pd["skey"])
	if pd["fid"] != "":
		vg.set_meta("friend_id", pd["fid"])
	add_child(vg)
	at.y = Game.ground_height(at.x, at.z) if pd["role"] != "roof" else at.y
	vg.global_position = at
	vg.home = at
	vg.goal = at   # _ready konum verilmeden çalışır: hedef dünya sıfırında kalıyor, herkes ilk anda oraya yürüyordu
	npcs.append(vg)
	if not pd["wp"].is_empty():
		WorldDay.on_stage(pd["wp"], vg, pd["wact"])
	if not pd["fk"].is_empty():
		WorldFolk.on_stage(pd["fk"], vg)
	return vg


## İsteği düşmüş (köyden çıkıldı, sıra temizlendi) ön kurulumlar: modeli bitince silinir
func _sweep_pend() -> void:
	var now = Time.get_ticks_msec()
	for k in _pend.keys():
		var pd: Dictionary = _pend[k]
		if now - int(pd["seen"]) < 5000:
			continue
		if is_instance_valid(pd["m"]) and not pd["m"].built:
			continue
		if is_instance_valid(pd["m"]):
			pd["m"].queue_free()
		if is_instance_valid(pd["vg"]):
			pd["vg"].free()
		_pend.erase(k)


# ------------------------------------------------------------------ sabit mekânlar
func _site_ok(s: Dictionary) -> bool:
	if s.get("off", false):
		return false   # kapanan şantiye (VillageRuin: ev tamamlandı)
	match s["type"]:
		"stall", "work", "bench", "spar", "ball", "repair":
			return phase != "gece"
		"farm", "fish", "messenger", "dojo":
			return phase != "gece"
		"drill", "sweep":
			return phase == "sabah" or phase == "oglen"
		"bar":
			return phase == "gece" or phase == "aksam"
		"academy_yard", "crowd", "pigeons":
			return s["type"] == "pigeons" and phase != "gece"
	return true


func _update_sites(v: Dictionary, p: Vector3) -> void:
	# uzaklaşan / saati geçen mekânları kapat
	for key in active_sites.keys():
		var info: Dictionary = active_sites[key]
		var s: Dictionary = info["site"]
		var far = v.is_empty() or s["pos"].distance_to(p) > 150.0
		var shift = String(s["type"]) in NIGHT_ROSTER and bool(info.get("night", false)) != (phase == "gece")
		if far or not _site_ok(s) or shift:
			var job = String(s["type"]) in JOB_SITES and not far
			for n in info["nodes"]:
				if not is_instance_valid(n):
					continue
				if job and n is Villager and not n.fading and n.global_position.distance_to(p) < 120.0:
					_job_leave(n)   # iş bitti / vardiya değişti: gözünün önünde kaybolmaz, kapıya yürür
				else:
					n.queue_free()
			active_sites.erase(key)
	if v.is_empty():
		return
	var list: Array = sites.get(v["id"], [])
	var jobs: Array = []
	for i in list.size():
		var s: Dictionary = list[i]
		var key = "%s_%d" % [v["id"], i]
		if active_sites.has(key) or not _site_ok(s):
			continue
		if s["pos"].distance_to(p) < 110.0:
			if String(s["type"]) in JOB_SITES:
				jobs.append([s["pos"].distance_to(p), key, s])
			else:
				active_sites[key] = {"site": s, "nodes": []}
				_open_site(key, s)
	if jobs.is_empty() or Missions.quiet():
		return   # görev / sınav / antrenman sürerken yeni kimse sahneye girmez
	# iş yerleri: en yakından, sınır dolana kadar
	jobs.sort_custom(func(a, b): return a[0] < b[0])
	var have = _job_count()
	for j in jobs:
		if have >= JOB_CAP:
			break
		var s2: Dictionary = j[2]
		if String(s2["type"]) == "farm" and not _staffed(s2):
			continue
		active_sites[j[1]] = {"site": s2, "nodes": [], "night": phase == "gece"}
		have += _open_job(j[1], s2)


## Yakındaki iş yerlerinde çalışan (ya da sırada bekleyen) kişi sayısı
func _job_count() -> int:
	var c = 0
	for key in active_sites:
		var info: Dictionary = active_sites[key]
		if String(info["site"]["type"]) in JOB_SITES:
			c += int(info.get("planned", 0))
	return c


## Tarlaların hepsinde biri olmaz: yerine göre sabit (aynı tarla her gün aynı; dünya verisinden, rastgele değil)
func _staffed(s: Dictionary) -> bool:
	var q: Vector3 = s["pos"]
	return absi(hash(Vector2i(roundi(q.x), roundi(q.z)))) % 100 < 42


func _job_leave(n: Villager) -> void:
	var ds: Array = doors.get(current, [])
	var best: Vector3 = n.global_position + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
	if not ds.is_empty():
		var bd = 1e9
		for k in 14:
			var q: Vector3 = ds.pick_random()
			var d = q.distance_to(n.global_position)
			if d < bd:
				bd = d; best = q
	VillagerJobs.leave(n, best)
	npcs.append(n)   # artık sokak kişisi: köyden çıkınca / eve varınca silinir


## İş yerinin kadrosunu sıraya koyar; kaç kişi geleceğini döndürür
func _open_job(key: String, s: Dictionary) -> int:
	var pos: Vector3 = s["pos"]
	var night = phase == "gece"
	var reqs: Array = []   # [rol, veri]
	var J = func(job: String, at: Vector3, face: float, jd: Dictionary, more := {}) -> void:
		var d = {"pos": at, "face": face, "fixed_face": true, "job": job, "jd": jd}
		d.merge(more, true)
		reqs.append(["job", d])
	match String(s["type"]):
		"farm":
			var u: Vector3 = s["u"]
			var vv: Vector3 = s["v"]
			var w: float = s["w"]
			var dp: float = s["d"]
			var crop = int(s.get("crop", 1))
			var hsh = absi(hash(Vector2i(roundi(pos.x), roundi(pos.z))))
			var kinds: Array = [["plant", "plant"], ["hoe", "water", "harvest"], ["harvest", "hoe"]][clampi(crop, 0, 2)]
			var n = 1 + (1 if hsh % 3 != 0 else 0)
			for k in n:
				var job: String = kinds[(hsh / 7 + k) % kinds.size()]
				var row = randf_range(-w * 0.5 + 1.2, w * 0.5 - 1.2)
				var sv = randf_range(-dp * 0.5 + 1.5, dp * 0.5 - 1.5)
				var edge = pos + u * (w * 0.5 + 1.4) + vv * randf_range(-dp * 0.3, dp * 0.3)
				var jd = {"c": pos, "u": u, "v": vv, "w": w, "d": dp, "row": row, "s": sv, "dir": 1.0 if randf() < 0.5 else -1.0, "edge": edge}
				var at = pos + u * row + vv * sv
				J.call(job, at, atan2(-vv.x, -vv.z), jd)
			if crop != 0 and hsh % 4 == 0:
				# hasat sepetini tarla kenarından yol tarafına taşıyan
				var e0 = pos + u * (w * 0.5 + 1.5)
				var e1 = pos + u * (w * 0.5 + 1.5) + vv * (dp * 0.5 + 4.0)
				J.call("basket", e0, 0.0, {"pts": [e1, e0]})
		"hospital":
			var door: Vector3 = s["door"]
			var gate: Vector3 = s["gate"]
			var fo: float = s.get("face_out", PI)
			var side: Vector3 = s.get("side", Vector3.RIGHT)
			J.call("chart", door + side * 4.5, fo, {"face0": fo})
			J.call("supply", door - side * 2.5, fo, {"pts": [gate - side * 2.5, door - side * 2.5]})
			if not night:
				var bs: Array = s.get("benches", [])
				if not bs.is_empty():
					var be: Array = bs[randi() % bs.size()]
					var bp: Vector3 = be[0]
					var bf: float = be[1]
					var bfd = Vector3(-sin(bf), 0, -cos(bf))
					reqs.append(["patient", {"pos": bp, "face": bf, "fixed_face": true, "lines_override": VillagerJobs.PATIENT_LINES, "display_override": "Hasta"}])
					J.call("heal", bp + bfd * 1.05, bf + PI, {})
				var sp = side * 6.5
				J.call("stretcher", door + sp, fo, {"pts": [gate + sp, door + sp], "lead": true, "pair": "st"})
				J.call("stretcher", door + sp - Vector3(-sin(fo), 0, -cos(fo)) * 2.3, fo, {"lead": false, "pair": "st"})
		"anbu", "police":
			var anbu = String(s["type"]) == "anbu"
			var pre = "anbu_" if anbu else "police_"
			var gs: Array = s.get("guards", [])
			for k in gs.size():
				if night and not anbu and k > 0:
					break
				J.call(pre + "guard", gs[k][0], gs[k][1], {"lantern": not anbu and night})
			var ring: Array = s.get("ring", [])
			if ring.size() >= 2:
				var r0: Vector3 = ring[0]
				J.call(pre + "patrol", r0, 0.0, {"pts": ring.slice(1) + [r0], "lead": true, "pair": "pt", "lantern": night})
				J.call(pre + "patrol", r0 + Vector3(1.2, 0, 0), 0.0, {"lead": false, "pair": "pt"})
			var inner: Array = s.get("inner", [])
			if inner.size() >= 2:
				J.call(pre + "patrol", inner[0], 0.0, {"pts": inner, "lead": true, "lantern": night and not anbu})
			if not night and anbu:
				var posts: Array = s.get("posts", [])
				if not posts.is_empty():
					var pe: Array = posts[randi() % posts.size()]
					J.call("anbu_strike", pe[0], pe[1], {})
				var th: Array = s.get("throw", [])
				if th.size() >= 3:
					J.call("anbu_throw", th[0], th[1], {"target": th[2]})
		"messenger":
			var pts: Array = s["pts"]
			J.call("messenger", pts[0], 0.0, {"pts": [pts[1], pts[0]]})
			if absi(hash(Vector2i(roundi(pos.x), roundi(pos.z)))) % 2 == 0:
				J.call("messenger", pts[1], 0.0, {"pts": [pts[0], pts[1]], "t": 6.0})
		"drill":
			var tg: Array = s.get("targets", [])
			var f: float = s.get("face", 0.0)
			var rv: Vector3 = s.get("u", Vector3.RIGHT)
			var fd = Vector3(-sin(f), 0, -cos(f))
			for k in mini(3, tg.size()):
				var t3: Vector3 = tg[(k * 2) % tg.size()]
				var at = Vector3(t3.x, pos.y, t3.z) - fd * 6.5 + rv * randf_range(-0.6, 0.6)
				J.call("drill_throw", at, f, {"target": t3})
			var ps: Array = s.get("posts", [])
			if not ps.is_empty():
				J.call("drill_strike", ps[0][0], ps[0][1], {})
			J.call("drill_teacher", pos - fd * 3.0 - rv * 8.0, f, {"pts": [pos - fd * 3.0 + rv * 8.0, pos - fd * 3.0 - rv * 8.0]})
		"dojo":
			var cl = String(s.get("clan", "hyuga"))
			var vid = String(current)
			for pr in s.get("pairs", []).slice(0, 1):
				var pp: Vector3 = pr
				for sd in [-1.0, 1.0]:
					var fem = randf() < 0.4
					var lk = ClanWorld.clan_look(cl, "chunin", vid, fem, ["adult", "young", "teen"].pick_random())
					reqs.append(["spar", {"pos": pp + Vector3(1.1 * sd, 0, 0), "pair": "a" if sd < 0 else "b", "look_extra": lk,
						"display_override": ClanWorld.person_name(cl, fem), "lines_override": VillagerJobs.LINES["hyuga"]}])
			var dp2: Array = s.get("posts", [])
			for k in mini(2, dp2.size()):
				J.call("dojo_strike", dp2[k * 2 % dp2.size()][0], dp2[k * 2 % dp2.size()][1], {})
		"sweep":
			J.call("sweep", pos, s.get("face", 0.0), {})
		"fish":
			J.call("fish", pos, s.get("face", 0.0), {"water_y": float(s.get("water_y", pos.y - 0.4))})
	# iş yeri kadrosu sıranın önüne (sokak kalabalığı onlardan sonra dolar): yaklaşırken yer boş görünmesin
	for ri in range(reqs.size() - 1, -1, -1):
		var r: Array = reqs[ri]
		var d: Dictionary = r[1]
		if r[0] == "job":
			d["lines_override"] = VillagerJobs.LINES.get(VillagerJobs.KIND.get(d["job"], "farmer"), [])
		queue.push_front(["site", key, r[0], d])
	active_sites[key]["planned"] = reqs.size()
	return reqs.size()


func _open_site(key: String, s: Dictionary) -> void:
	var pos: Vector3 = s["pos"]
	var f: float = s.get("face", 0.0)
	match s["type"]:
		"stall":
			queue.append(["site", key, "vendor", {"pos": s["back"], "face": f + PI, "fixed_face": true}])
		"spar":
			queue.append(["site", key, "spar", {"pos": pos + Vector3(1.1, 0, 0), "pair": "a"}])
			queue.append(["site", key, "spar", {"pos": pos - Vector3(1.1, 0, 0), "pair": "b"}])
		"work":
			for k in 2:
				var o = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
				queue.append(["site", key, "worker", {"pos": pos + o, "face": randf() * TAU, "work_anims": [["b/TreeChopping", "a/Fixing_Kneeling"], ["a/Push", "a/Fixing_Kneeling", "b/TreeChopping"]][k]}])
			queue.append(["site", key, "worker", {"pos": pos + Vector3(4, 0, 0), "work_points": [pos + Vector3(6, 0, 3), pos + Vector3(-5, 0, -2)]}])
		"repair":
			# yıkıntı onarımı (VillageRuin): iki usta evin önünde çalışır, biri kereste yığınından tahta taşır
			var hp: Vector3 = s.get("house", pos)
			var to = hp - pos
			to.y = 0
			to = to.normalized() if to.length() > 0.1 else Vector3.FORWARD
			var side = Vector3(-to.z, 0, to.x)
			var hw: float = float(s.get("w", 8.0)) * 0.3
			var ff = atan2(-to.x, -to.z)
			queue.append(["site", key, "worker", {"pos": pos + side * hw, "face": ff, "fixed_face": true, "work_anims": ["b/TreeChopping", "a/Fixing_Kneeling"]}])
			queue.append(["site", key, "worker", {"pos": pos - side * hw, "face": ff, "fixed_face": true, "work_anims": ["a/Fixing_Kneeling", "b/TreeChopping"]}])
			queue.append(["site", key, "worker", {"pos": pos - to * 2.0, "work_points": [pos - to * 1.0, pos + side * (float(s.get("w", 8.0)) * 0.5 + 2.2) + to * 1.0]}])
		"bench":
			queue.append(["site", key, "sitter", {"pos": pos, "face": f, "fixed_face": true}])
			if randf() < 0.5:
				queue.append(["site", key, "sitter", {"pos": pos + Vector3(cos(f), 0, -sin(f)) * 0.7, "face": f, "fixed_face": true}])
		"ball":
			var bg = BallGame.new()
			add_child(bg)
			bg.global_position = pos
			active_sites[key]["nodes"].append(bg)
			for k in 3:
				queue.append(["site", key, "ball", {"pos": pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), "game": bg}])
		"guard":
			queue.append(["site", key, "guard", {"pos": pos, "face": f, "fixed_face": true}])
		"bar":
			queue.append(["site", key, "drunk", {"pos": pos}])
		"trainer":
			queue.append(["site", key, "teacher", {"pos": pos, "face": f, "fixed_face": true, "display_override": s.get("title", "Jonin Eğitmen"),
				"lines_override": ["Antrenmana hazır mısın?", "Önce temel, sonra ileri teknikler.", "Chakra kontrolün gelişiyor!"], "wander_r": 1.2}])
		"pigeons":
			var fl = PigeonFlock.new()
			fl.position = pos
			add_child(fl)
			fl.global_position = pos
			active_sites[key]["nodes"].append(fl)
		"ramen":
			queue.append(["site", key, "keeper", {"pos": s["back"], "face": f + PI, "fixed_face": true, "display_override": "Ramen Ustası", "lines_override": ["Miso chashu mu, shio mu?", "Ekstra naruto dilimi koydum!", "Bir kase daha?"]}])
			for k in 2:
				var sp: Vector3 = s["seats"][k * 2 + 1]
				queue.append(["site", key, "customer", {"pos": sp, "face": f, "fixed_face": true, "eat_mode": true}])


func _spawn_site_actor(key: String, role: String, d: Dictionary) -> void:
	if not active_sites.has(key):
		return
	var extra = {}
	for k in ["fixed_face", "work_anims", "work_points", "display_override", "lines_override", "eat_mode", "wander_r", "job", "jd", "look_extra"]:
		if d.has(k):
			extra[k] = d[k]
	# bu yerde tanıştığın biri varsa o gelir (adı, görünüşü); yoksa sıradan biri
	var skey = Friends.site_key(d["pos"])
	var fid = Friends.at_site(skey)
	if fid != "":
		var f: Dictionary = Friends.all()[fid]
		extra["look_extra"] = Friends.look_of(f)
		extra["display_override"] = String(f["name"])
	var at: Vector3 = d["pos"]
	if not role in ["sitter", "vendor", "eat", "bench", "patient"] and not String(d.get("job", "")) in ["hoe", "harvest", "water", "plant", "fish"]:
		at = _free_spot(at)   # fener / sandık / duvarın içine ya da arkasına düşen nöbetçi vb. yakındaki boş noktaya
	var vg = _villager(role, at, [], extra, skey, fid)
	if vg == null:
		return
	npcs.erase(vg)  # mekân aktörleri sokak sayısına dahil değil
	if d.has("face"):
		vg.facing = d["face"]
		vg.stand_face = d["face"]
		vg.model.rotation.y = vg.facing
	active_sites[key]["nodes"].append(vg)
	if role == "spar":
		for n in active_sites[key]["nodes"]:
			if n != vg and n is Villager and n.role == "spar":
				n.buddy = vg
				vg.buddy = n
				WorldDay.paired(n, vg)
	if role == "ball" and d.has("game") and is_instance_valid(d["game"]):
		d["game"].kids.append(vg)
	if role == "job":
		vg.jd = (vg.jd as Dictionary).duplicate(true)   # kayıttaki veri paylaşılmasın (her kişinin kendi durumu)
		var pr = String(vg.jd.get("pair", ""))
		if pr != "":
			# eşli iş (sedye, çift devriye): aynı yerin eşiyle bağlanır
			for n in active_sites[key]["nodes"]:
				if n != vg and n is Villager and n.role == "job" and n.job == vg.job and String(n.jd.get("pair", "")) == pr and not n.jd.has("mate"):
					n.jd["mate"] = vg
					vg.jd["mate"] = n
					break


## Ayakta duracak NPC için boş nokta: konumda katı bir şey varsa çevresinde halka halka boşluk ara
func _free_spot(p: Vector3) -> Vector3:
	var space = get_world_3d().direct_space_state
	var q = PhysicsShapeQueryParameters3D.new()
	var sh = CapsuleShape3D.new()
	sh.radius = 0.45
	sh.height = 1.3
	q.shape = sh
	q.collision_mask = 1
	for r in [0.0, 1.0, 1.6, 2.3, 3.0]:
		for k in (1 if r == 0.0 else 8):
			var a = TAU * k / 8.0
			var c = p + Vector3(cos(a) * r, 0, sin(a) * r)
			c.y = Game.ground_height(c.x, c.z) if r > 0.0 else p.y
			q.transform = Transform3D(Basis.IDENTITY, c + Vector3(0, 1.75, 0))   # alt ucu 1.1 m: basamak / teras zemini sayılmaz
			if space.intersect_shape(q, 1).is_empty():
				return c
	return p


func _update_crowd(v: Dictionary, p: Vector3) -> void:
	# sentez kalabalık uğultusu caddelerde sinek vızıltısı / uçak sesi gibi duyuluyordu: kapalı
	if crowd:
		crowd.stop()
	return
	var cpos = _site_pos(v.get("id", ""), "crowd") if not v.is_empty() else Vector3.INF
	if cpos == Vector3.INF:
		if crowd:
			crowd.stop()
		return
	if crowd == null:
		crowd = AudioStreamPlayer3D.new()
		var s = load("res://assets/sfx/crowd.wav")
		if s == null:
			return
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
		crowd.stream = s
		crowd.unit_size = 14.0   # meydana yakınken duyulur, sokaklara yayılıp uğuldamasın
		crowd.max_distance = 70.0
		add_child(crowd)
	crowd.global_position = cpos
	var vol = {"sabah": 0.45, "oglen": 1.0, "aksam": 0.6, "gece": 0.0}[phase] * float(Game.settings["sfx"]) * 0.4
	if vol <= 0.01:
		crowd.stop()
		return
	crowd.volume_db = linear_to_db(vol)
	if not crowd.playing:
		crowd.play()


# ------------------------------------------------------------------ top oynayan çocuklar
class BallGame extends Node3D:
	var kids: Array = []
	var ball: MeshInstance3D
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var k := 1.0
	var holder: Node3D = null
	var hold_t := 0.0

	func _ready() -> void:
		ball = MeshInstance3D.new()
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.32, 0.32, 0.32), Color(0.9, 0.25, 0.2), Vector3.ZERO, 10)
		b.add("box", Vector3.ZERO, Vector3(0.33, 0.05, 0.05), Color(1, 1, 1))
		ball.mesh = b.build(Props.toon())
		add_child(ball)
		from = global_position
		to = global_position

	func _process(dt: float) -> void:
		kids = kids.filter(func(x): return is_instance_valid(x))
		if kids.size() < 2 or Game.paused:
			return
		if k < 1.0:
			k = minf(1.0, k + dt / maxf(0.5, from.distance_to(to) / 7.0))
			var p = from.lerp(to, k)
			p.y = Game.terrain_height(p.x, p.z) + 0.16 + sin(k * PI) * minf(2.5, from.distance_to(to) * 0.25)
			ball.global_position = p
			ball.rotation.x += dt * 10.0
			if holder:
				holder.goal = to
			return
		# top yere düştü: en yakın çocuk gelir ve vurur
		if holder == null or not is_instance_valid(holder):
			var best = kids[0]
			for c in kids:
				if c.global_position.distance_to(ball.global_position) < best.global_position.distance_to(ball.global_position):
					best = c
			holder = best
			hold_t = 0.0
		holder.goal = ball.global_position
		for c in kids:
			if c != holder and c.goal.distance_to(global_position) > 9.0:
				c.goal = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		hold_t += dt
		if holder.global_position.distance_to(ball.global_position) < 0.9 or hold_t > 4.0:
			holder.kick_ball()
			var others = kids.filter(func(x): return x != holder)
			var target = others.pick_random()
			from = ball.global_position
			to = target.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			to = global_position + (to - global_position).limit_length(9.0)
			k = 0.0
			holder = target
			if randf() < 0.4:
				Sfx.play("punch", from, 1.6, 0.25)


# ------------------------------------------------------------------ güvercinler: yerde gagalar, yaklaşınca havalanır
class PigeonFlock extends Node3D:
	var birds: Array = []
	var flying := -1.0
	var reset_t := 0.0
	static var _mesh: ArrayMesh

	func _ready() -> void:
		if _mesh == null:
			var b = MB.new()
			b.add("sphere", Vector3(0, 0.12, 0), Vector3(0.16, 0.14, 0.26), Color(0.55, 0.57, 0.62), Vector3.ZERO, 6)
			b.add("sphere", Vector3(0, 0.22, -0.12), Vector3(0.1, 0.1, 0.1), Color(0.45, 0.5, 0.58), Vector3.ZERO, 6)
			b.add("cone", Vector3(0, 0.21, -0.19), Vector3(0.03, 0.06, 0.03), Color(0.85, 0.6, 0.3), Vector3(-90, 0, 0), 4)
			b.add("box", Vector3(0, 0.13, 0.15), Vector3(0.1, 0.02, 0.12), Color(0.4, 0.42, 0.48))
			_mesh = b.build(Props.toon())
		for i in 12:
			var m = MeshInstance3D.new()
			m.mesh = _mesh
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			birds.append({"n": m, "o": Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), "ph": randf() * TAU, "v": Vector3.ZERO})
		# sürünün konumu add_child'dan SONRA veriliyor: hemen konarsa kuşlar dünya merkezine göre konup sürüyle taşınıp havada kalıyordu
		_land.call_deferred()

	func _land() -> void:
		flying = -1.0
		var space = get_world_3d().direct_space_state
		for b in birds:
			# gerçek yüzeye kon: yukarıdan ışın; binaya / çatıya / duvar içine düşen kuş yakındaki açık zemine
			var placed = false
			for k in 8:
				var o: Vector3 = b["o"] if k == 0 else Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
				var p = global_position + o
				var g = Game.ground_height(p.x, p.z)
				var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, g + 40.0, p.z), Vector3(p.x, g - 2.0, p.z), 1))
				var y = g if hit.is_empty() else float(hit["position"].y)
				if y > g + 0.6:
					continue   # bina / çatı / tezgâh
				p.y = y
				b["o"] = o
				b["n"].global_position = p
				placed = true
				break
			b["n"].rotation.y = randf() * TAU
			b["n"].visible = placed

	func _process(dt: float) -> void:
		if Game.player == null or Game.paused:
			return
		var pd = Game.player.global_position.distance_to(global_position)
		if flying < 0.0:
			if pd < 5.0:
				flying = 0.0
				Sfx.play("whoosh", global_position, 1.8, 0.4)
				for b in birds:
					b["v"] = Vector3(randf_range(-3, 3), randf_range(5, 8), randf_range(-3, 3))
				return
			var tt = Time.get_ticks_msec() * 0.001
			for b in birds:
				var peck = maxf(0.0, sin(tt * 3.0 + b["ph"]))
				b["n"].rotation.x = -peck * 0.6
				if randf() < dt * 0.3:
					b["n"].rotation.y += randf_range(-1.0, 1.0)
			return
		flying += dt
		for b in birds:
			b["n"].global_position += b["v"] * dt
			b["v"] += Vector3(0, -1.0, 0) * dt
			b["n"].rotation.x = sin(flying * 30.0 + b["ph"]) * 0.4
		if flying > 3.0:
			for b in birds:
				b["n"].visible = false
			reset_t += dt
			if reset_t > 20.0 and pd > 25.0:
				reset_t = 0.0
				_land()


## Uzak köylü gölge atmaz (kişi başı ~40 bin üçgen x gölge katmanları: kalabalık meydanda/antrenman alanında FPS düşüyordu)
static func _shadow_lod(n: Node, d: float) -> void:
	var want = d < 40.0
	if n.has_meta("shadow_on") and bool(n.get_meta("shadow_on")) == want:
		return
	n.set_meta("shadow_on", want)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if g.has_meta("no_shadow_base"):
			continue
		if not g.has_meta("shadow0"):
			g.set_meta("shadow0", g.cast_shadow)
		g.cast_shadow = g.get_meta("shadow0") if want else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
