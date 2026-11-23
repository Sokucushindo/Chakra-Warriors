class_name Ceremony
extends ScenePoser
## Hayatın büyük anları sahneli tören olarak (yalnız yazı değil):
##  kage   : Kage yemin töreni — Kage Kulesi önünde, eski Kage şapkayı uzatır, köy halkı toplanır ve tezahürat yapar
##  genin  : Akademi mezuniyeti — hocan alın koruyucunu uzatır, alnına bağlarsın; takımla hatıra fotoğrafı
##  chunin : Chūnin terfisi — Kage adını okur, yeleğini verir; adaylar alkışlar
##  jonin  : Jōnin terfisi — Kage ve sana kefil olan iki jōnin; jōnin yeleği ve üç geninin haberi
##  rogue  : Kaçak olmak — bandını çözer, sembolün üstüne kunaiyle çizik atar, yeniden bağlar ve köye sırtını dönersin
##  pardon : Af — Kage kapıda karşılar; çizik bandı teslim eder, yenisini alnına bağlarsın
## Her biri: kendi kamerası (kesmeli açılar), sinema bantları, arayüz gizli; "grant" geri çağrısı terfiyi tam bandın / şapkanın
## takıldığı anda yapar, "done" törenden sonra eski akışı (pencere, ödül) sürdürür.

static var cur: Ceremony = null

var kind := ""
var args := {}
var vid := ""
var people: Array = []     # törene özel kişiler (sonunda dağılır)
var borrowed: Array = []   # [düğüm, fizik açıktı mı] — sahnede ödünç alınan mevcut kişiler (takım)
var prop: MeshInstance3D
var prop_at: Node3D
var _granted := false
var pin := Vector3.INF      # oyuncunun durduğu yer: eğimli zeminde / basamakta kaymasın (yürürken INF)
var dialogs_ok := false
var queued: Array = []     # tören sırasında açılmak istenen pencereler (sonra sırayla açılır)
var _done_called := false


static func start(k: String, a := {}) -> void:
	if is_instance_valid(cur) or Game.player == null or not is_instance_valid(Game.player) or Game.player.hp <= 0.0 or is_instance_valid(DeathScene.cur):
		_fallback(a)   # ölüyken / ölüm sahnesindeyken tören yok: olay yine işlenir
		return
	var c := Ceremony.new()
	c.kind = k
	c.args = a
	c.vid = String(a.get("vid", Progress.home()))
	cur = c
	Game.player.get_tree().current_scene.add_child(c)


## Sahne kurulamıyorsa olay yine işlenir (terfi kaybolmasın)
static func _fallback(a: Dictionary) -> void:
	var g: Callable = a.get("grant", Callable())
	if g.is_valid():
		g.call()
	var d: Callable = a.get("done", Callable())
	if d.is_valid():
		d.call()


## Kaçak olma gibi sahnelerin oynanabileceği sakin an: dövüş yok, iç mekân yok
static func calm() -> bool:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or (Interiors.inst and Interiors.inst.inside != ""):
		return false
	if pl.get("scene_hold") or not pl.grounded or (pl.combat and pl.combat.action != ""):
		return false
	for f in pl.get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and is_instance_valid(f) and not f.is_dead() and f.target == pl and f.global_position.distance_to(pl.global_position) < 45.0:
			return false
	return true


func _ready() -> void:
	Hud.close_dialog()
	_lock(300.0)
	# tören anında peşindekiler bırakır (köye dönüşte nöbetçi, yoldaki haydut): sahne kavgaya dönmesin
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and is_instance_valid(f) and not f.is_dead() and f.target == Game.player:
			f.lose_target(60.0)
			f.state = "idle"
	match kind:
		"kage": await _kage()
		"genin": await _genin()
		"chunin": await _chunin()
		"jonin": await _jonin()
		"rogue": await _rogue()
		"pardon": await _pardon()
	_finish()


func _finish() -> void:
	pin = Vector3.INF
	_grant()
	_cine_off()
	_release_player()
	for b in borrowed:
		if is_instance_valid(b[0]):
			_clear_pose(b[0])
			b[0].set_physics_process(b[1])
	borrowed.clear()
	var ps: Array = people.duplicate()
	people.clear()
	if cur == self:
		cur = null
	# törene gelenler dağılır (bir süre yerinde kalır, sonra gider)
	get_tree().create_timer(14.0, false).timeout.connect(func():
		for n in ps:
			if is_instance_valid(n):
				if n.has_method("vanish"):
					n.vanish()
				else:
					n.queue_free())
	dialogs_ok = true
	_after()
	_replay(queued.duplicate())
	queued.clear()
	queue_free()


## Ertelenen pencereler: açık pencere kapandıkça sıradaki açılır
static func _replay(q: Array) -> void:
	if q.is_empty() or Game.player == null or not is_instance_valid(Game.player):
		return
	var tree = Game.player.get_tree()
	if Hud.dialog_open() or is_instance_valid(cur):
		tree.create_timer(0.5, false).timeout.connect(func(): Ceremony._replay(q))
		return
	var d: Array = q.pop_front()
	Hud.dialog(String(d[0]), String(d[1]), d[2])
	tree.create_timer(0.5, false).timeout.connect(func(): Ceremony._replay(q))


func _grant() -> void:
	if _granted:
		return
	_granted = true
	var g: Callable = args.get("grant", Callable())
	if g.is_valid():
		g.call()


func _after() -> void:
	if _done_called:
		return
	_done_called = true
	var d: Callable = args.get("done", Callable())
	if d.is_valid():
		d.call()


func _exit_tree() -> void:
	if cur == self:
		# yarıda kaldı (sahne değişti): terfi ve akış kaybolmasın, oyuncu serbest kalsın
		cur = null
		_grant()
		_cine_off()
		_release_player()
		for b in borrowed:
			if is_instance_valid(b[0]):
				b[0].set_physics_process(b[1])
		for n in people:
			if is_instance_valid(n):
				n.queue_free()
		dialogs_ok = true
		_after()
		_replay(queued.duplicate())


func _process(dt: float) -> void:
	_apply_poses(dt)
	_cine_tick(dt)
	var pl = Game.player
	if pin != Vector3.INF and pl and is_instance_valid(pl):
		pl.global_position = Vector3(pin.x, pl.global_position.y, pin.z)
		pl.velocity = Vector3.ZERO
	if is_instance_valid(prop) and is_instance_valid(prop_at):
		var reach = float(st[prop_at].get("reach", 0.4)) if st.has(prop_at) else 0.4
		var p = prop_at.global_position + Vector3.UP * (1.24 * prop_at.model.age_scale - 0.01) + _fd(prop_at) * (reach + 0.03)
		if st.has(prop_at) and String(st[prop_at].get("k", "")) in ["knot", "crown"]:
			p = _bone(prop_at, "Head") + _fd(prop_at) * 0.07 + Vector3.UP * (0.16 if String(st[prop_at]["k"]) == "crown" else 0.02)
		prop.global_position = prop.global_position.lerp(p, minf(1.0, dt * 12.0))
		prop.global_basis = Basis(Vector3.UP, prop_at.facing)


func _make(n: Node3D, s: Dictionary) -> Dictionary:
	var fd = _fd(n)
	var right = fd.cross(Vector3.UP).normalized()
	var sc: float = n.model.age_scale
	match String(s["k"]):
		"knot":    # iki el başın arkasında: bandın düğümü / şapkayı oturtur
			var c = _bone(n, "Head") - fd * 0.1 * sc + Vector3.UP * 0.03 + Vector3.UP * sin(float(s["t"]) * 9.0) * 0.012
			var a = _ik(n, "Left", c - right * 0.07)
			a.append_array(_ik(n, "Right", c + right * 0.07))
			return {"arms": a, "fL": GRIP, "fR": GRIP, "spine": 4.0, "neck": 14.0}
		"crown":   # iki el başın üstünde: şapkayı başına koyar
			var c2 = _bone(n, "Head") + Vector3.UP * 0.16 * sc + fd * 0.02
			var a3 = _ik(n, "Left", c2 - right * 0.14)
			a3.append_array(_ik(n, "Right", c2 + right * 0.14))
			return {"arms": a3, "fL": HALF, "fR": HALF, "spine": 0.0, "neck": 4.0}
		"offer":   # iki avuçta uzatır / alır
			var mid = n.global_position + Vector3.UP * 1.24 * sc + fd * float(s.get("reach", 0.4))
			var a2 = _ik(n, "Left", mid - right * 0.09)
			a2.append_array(_ik(n, "Right", mid + right * 0.09))
			return {"arms": a2, "fL": HALF, "fR": HALF, "spine": float(s.get("lean", 6.0)), "neck": 8.0}
		"scratch": # sol el bandı tutar, sağ el kunaiyi plaka üstünde çeker
			var mid2 = n.global_position + Vector3.UP * 1.24 * sc + fd * 0.3
			var u = sin(float(s["t"]) * 7.0)
			var a4 = _ik(n, "Left", mid2 - right * 0.08)
			a4.append_array(_ik(n, "Right", mid2 + right * (0.05 + u * 0.07) + Vector3.UP * (0.05 - u * 0.05) + fd * 0.03))
			return {"arms": a4, "fL": GRIP, "fR": GRIP, "spine": 10.0, "neck": 18.0}
	return super._make(n, s)


# ====================================================================== kişiler, eşyalar
func _person(nm: String, look: Dictionary, at: Vector3, face_to: Vector3, role := "guard") -> Villager:
	var v := Villager.new()
	v.role = role
	if nm != "":
		v.display_override = nm
	if not look.is_empty():
		v.look_extra = look
	get_tree().current_scene.add_child(v)
	var q = at
	q.y = Game.ground_height(q.x, q.z)
	v.global_position = q
	v.home = q
	v.goal = q
	v.wander_r = 0.0
	v.fixed_face = true
	var to = face_to - q
	v.facing = atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.3 else 0.0
	v.stand_face = v.facing
	v.set_physics_process(false)
	people.append(v)
	return v


func _kage_npc(at: Vector3, face_to: Vector3, with_hat := true) -> Villager:
	var lk: Dictionary = KageAttire.look(vid)
	lk["village"] = vid
	var k = _person(Kage.kage_name(vid), lk, at, face_to)
	if with_hat:
		KageAttire.hat(k.model, vid)
	return k


## Kalabalık: sahnenin önünde yay biçiminde sıralar (köy ninjaları + siviller), sahneye bakar
func _crowd(center: Vector3, toward: Vector3, n: int, r0 := 7.0) -> Array:
	var out = []
	var dir = toward - center
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var side = dir.cross(Vector3.UP).normalized()
	for i in n:
		var row = int(i / 7)
		var col = (i % 7) - 3
		var p = center - dir * (r0 + row * 1.6) + side * (col * 1.35 + (0.65 if row % 2 == 1 else 0.0)) + dir * absf(col) * 0.35
		var v: Villager
		if i % 3 == 2:
			v = _person("", {}, p, toward, "walker")   # sivil
		else:
			var lk = Outfits.roll(["genin", "chunin", "chunin", "jonin"][i % 4], vid)
			lk["gender"] = ["m", "f", "m"][i % 3]
			lk["age"] = "adult" if i % 5 != 4 else "teen"
			v = _person("", lk, p, toward)
		out.append(v)
	return out


func _cheer(group: Array, lines: Array) -> void:
	Sfx.play("crowd", Game.player.global_position, 1.0, 1.0)
	for i in group.size():
		var g = group[i]
		if is_instance_valid(g):
			_pose(g, "cheer" if i % 3 == 0 else "applaud", {"anim": "idle", "off": i * 0.6})
			if not lines.is_empty() and i % 4 == 1:
				_say(g, String(lines[int(i / 4) % lines.size()]), 3.5)


func _band_mesh(slashed := false) -> MeshInstance3D:
	var bc: Color = Progress.home_info().get("band", Color(0.16, 0.22, 0.5))
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.6, 0.014, 0.075), bc)
	b.add("box", Vector3(0, 0.014, 0), Vector3(0.17, 0.016, 0.07), Color(0.8, 0.82, 0.86))
	b.add("box", Vector3(0, 0.0235, 0), Vector3(0.05, 0.004, 0.035), Color(0.35, 0.37, 0.42))   # sembol kabartması
	if slashed:
		b.add("box", Vector3(0, 0.026, 0), Vector3(0.15, 0.004, 0.008), Color(0.1, 0.1, 0.12), Vector3(0, 18, 0))
	return _mesh(b)


func _hat_mesh() -> MeshInstance3D:
	var c: Color = KageAttire.COLOR.get(vid, KageAttire.COLOR["konoha"])
	var white = Color(0.97, 0.96, 0.93)
	var b = MB.new()
	b.add("cone", Vector3(0, 0.06, 0), Vector3(0.62, 0.19, 0.62), white, Vector3.ZERO, 24)
	b.add("cone", Vector3(0, 0.11, 0), Vector3(0.31, 0.095, 0.31), c, Vector3.ZERO, 24)
	b.add("cyl", Vector3(0, -0.03, 0), Vector3(0.63, 0.012, 0.63), white.darkened(0.12), Vector3.ZERO, 24)
	return _mesh(b)


func _vest_mesh(col: Color) -> MeshInstance3D:
	var b = MB.new()   # katlanmış yelek: iki kat kumaş + tomar cepleri
	b.add("box", Vector3.ZERO, Vector3(0.34, 0.05, 0.26), col)
	b.add("box", Vector3(0, 0.03, 0), Vector3(0.32, 0.012, 0.24), col.lightened(0.06))
	for sx in [-1.0, 1.0]:
		b.add("box", Vector3(sx * 0.09, 0.042, 0.06), Vector3(0.07, 0.016, 0.08), col.darkened(0.12))
	return _mesh(b)


func _kunai_mesh() -> MeshInstance3D:
	var b = MB.new()
	b.add("cone", Vector3(0, 0.1, 0), Vector3(0.055, 0.15, 0.014), Color(0.62, 0.64, 0.7), Vector3.ZERO, 4)
	b.add("cyl", Vector3(0, -0.03, 0), Vector3(0.022, 0.11, 0.022), Color(0.12, 0.12, 0.14), Vector3.ZERO, 8)
	b.add("cyl", Vector3(0, -0.1, 0), Vector3(0.045, 0.008, 0.045), Color(0.5, 0.5, 0.55), Vector3(90, 0, 0), 10)
	return _mesh(b)


func _give(from: Node3D, to: Node3D, m: MeshInstance3D) -> void:
	# uzatır; alan önce eğilir, iki eliyle alır
	prop = m
	prop.global_position = _bone(from, "Chest")
	prop_at = from
	_pose(from, "offer", {"anim": "idle", "reach": 0.42, "lean": 8.0})
	await _wait(1.2)
	_pose(to, "bow", {"anim": "idle", "len": 1.6})
	await _wait(1.6)
	_pose(to, "offer", {"anim": "idle", "reach": 0.4, "lean": 10.0})
	await _wait(0.6)
	prop_at = to
	_clear_pose(from)
	from.model.play("idle", 0.3)
	await _wait(0.7)


func _drop_prop() -> void:
	prop_at = null
	if is_instance_valid(prop):
		prop.queue_free()
	prop = null


func _tell(text: String, dur := 2.6) -> void:
	Combat.popup_text(_bone(Game.player, "Head") + Vector3.UP * 0.35, text, Color(1.0, 0.92, 0.72))
	await _wait(dur)


## Kıyafet / rütbe değişimi kısa bir kararmayla (model yeniden kurulur)
func _change(cb: Callable) -> void:
	await Interiors.inst._fade(1.0, 0.35)
	cb.call()
	await _wait(0.25)
	await Interiors.inst._fade(0.0, 0.45)


## Sahne yeri: verilen noktaya en yakın açık zemin (ev / ağaç içine kurulmasın)
func _open(p: Vector3, r := 6.0) -> Vector3:
	var q: Vector3 = Missions.open_ground(p, r)
	q.y = Game.ground_height(q.x, q.z)
	return q


## Kapının önünde açık yön: 14 m boyunca engelsiz ve düz olan, istenen yöne (köy merkezine) en yakın yön
func _open_dir(door: Vector3, want: Vector3) -> Vector3:
	want.y = 0.0
	want = want.normalized() if want.length() > 1.0 else -Game.player.face_dir()
	var space = Game.player.get_world_3d().direct_space_state
	var h0 = Game.ground_height(door.x, door.z)
	var best := want
	var bs := -1e9
	for i in 16:
		var d = Vector3(sin(TAU * i / 16.0), 0, cos(TAU * i / 16.0))
		var q = PhysicsRayQueryParameters3D.create(door + Vector3.UP * 1.2 + d * 0.8, door + Vector3.UP * 1.2 + d * 14.0, 1)
		q.exclude = [Game.player.get_rid()]
		var free = space.intersect_ray(q).is_empty()
		var flat = absf(Game.ground_height(door.x + d.x * 10.0, door.z + d.z * 10.0) - h0) < 2.0
		var sc = d.dot(want) + (3.0 if free else 0.0) + (1.5 if flat else 0.0)
		if sc > bs:
			bs = sc
			best = d
	return best


## Bu noktada bir kişi boyu kapsül boş mu (sütun / duvar / eşya içinde değil)
func _free(p: Vector3) -> bool:
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.0)
	q.collision_mask = 1
	q.exclude = [Game.player.get_rid()]
	return Game.player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Kage Kulesi kapısı (yoksa köy merkezi)
func _tower() -> Vector3:
	var v = Game.village(vid)
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var best := Vector3.INF
	var bd := 1e9
	for it in Interact.items:
		var room = String(it.get("room", ""))
		if room in ["hokage", "kage"] and String(it.get("vid", vid)) == vid:
			var d = (it["pos"] as Vector3).distance_to(c)
			if d < bd and d < float(v.get("r", 400)) * 1.3:
				bd = d
				best = it["pos"]
	return best if best != Vector3.INF else c


# ====================================================================== törenler
func _kage() -> void:
	var pl = Game.player
	var kt = String(Progress.home_info()["kage"])
	var door = _tower()
	var v = Game.village(vid)
	var vc = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var out = _open_dir(door, vc - door)
	await Interiors.inst._fade(1.0, 0.8)
	var side = out.cross(Vector3.UP).normalized()
	# sahne: kapının önünde, iki kişinin duracağı yer de boş olan ilk mesafe (sütunlu girişte sütunun içinde doğup itiliyordu)
	var stage = door + out * 4.0
	for dd in [4.0, 5.0, 6.0, 7.0, 8.0, 9.0]:
		var c2 = door + out * dd
		c2.y = Game.ground_height(c2.x, c2.z)
		if _free(c2 + side * 0.9) and _free(c2 - side * 0.9) and _free(c2):
			stage = c2
			break
	stage.y = Game.ground_height(stage.x, stage.z)
	pl.global_position = stage + side * 0.9 + Vector3.UP * 0.05
	pl.velocity = Vector3.ZERO
	pin = pl.global_position
	_face(pl, atan2(-out.x, -out.z))
	var old = _kage_npc(stage - side * 0.9, stage - side * 0.9 + out, false)   # şapkası elinde
	var adv1 = _person("Danışman Tsugumi", {"top_style": "kimono", "top": Color(0.5, 0.48, 0.45), "top2": Color(0.3, 0.28, 0.26), "hair": Color(0.8, 0.8, 0.8), "hair_style": "topuz", "gender": "f", "age": "adult", "vest": null, "band": null}, stage - side * 2.6 - out * 0.8, stage + out * 4.0, "elder")
	var adv2 = _person("Danışman Gonza", {"top_style": "kimono", "top": Color(0.42, 0.44, 0.48), "top2": Color(0.25, 0.26, 0.3), "hair": Color(0.75, 0.75, 0.75), "hair_style": "kısa", "gender": "m", "age": "adult", "vest": null, "band": null}, stage + side * 2.6 - out * 0.8, stage + out * 4.0, "elder")
	var crowd = _crowd(stage + out * 1.0, stage, 18, 7.5)
	_cine_on()
	_cam_shot(stage + out * 13.0 + Vector3.UP * 3.2, stage + Vector3.UP * 1.4)
	await Interiors.inst._fade(0.0, 1.0)
	Hud.banner("YEMİN TÖRENİ", "%s'nin yeni %s'i" % [String(v.get("name", "Köy")), kt], Color(1, 0.8, 0.45))
	Sfx.play("crowd", stage, 0.8, 0.6)
	await _wait(3.0)
	_look_at(old, stage + out * 6.0)
	_cam_shot(stage + out * 4.6 - side * 0.8 + Vector3.UP * 1.5, stage - side * 0.3 + Vector3.UP * 1.75)   # ikisi birden kadrajda (konuşma balonu da)
	_say(old, "Bugün köyümüz yeni %s'ini seçti. Konsey, daimyō ve sizler... hepiniz tanıksınız." % kt, 4.0)
	await _wait(4.2)
	_say(old, "Bu şapka bir taç değil, bir yüktür. Her ninjanın, her çocuğun hayatı artık senin omuzlarında.", 4.4)
	await _wait(4.6)
	_look_at(old, pl.global_position)
	_look_at(pl, old.global_position)
	_cam_shot(stage - side * 2.8 + out * 1.4 + Vector3.UP * 1.65, stage + side * 0.7 + Vector3.UP * 1.4)   # eski Kage'nin omzu üstünden yüzüne
	await _give(old, pl, _hat_mesh())
	_say(old, "Taşıyabilecek misin, %s?" % String(pr_name()), 2.8)
	await _wait(1.4)
	await _tell("Canım pahasına.", 2.0)
	# şapkayı başına koyar: rütbe / cübbe / şapka tam bu anda
	_pose(pl, "crown", {"anim": "idle"})
	await _wait(0.9)
	_drop_prop()
	await _change(func(): _grant())
	_clear_pose(pl)
	_face(pl, atan2(-out.x, -out.z))
	_cam_shot(pl.global_position + out * 2.8 + side * 0.4 + Vector3.UP * 0.75, pl.global_position + Vector3.UP * 1.6)   # önden, alttan kahraman açısı
	await _tell("Bu köyü ve içindeki herkesi koruyacağım. Bugünden itibaren ben %s'im!" % kt, 3.6)
	_cam_shot(stage + out * 15.0 + side * 3.0 + Vector3.UP * 4.0, stage + Vector3.UP * 1.6)
	_cheer(crowd, ["%s-sama!" % kt, "Yaşasın!", "%s! %s!" % [kt, kt], "Ateşin İradesi!" if vid == "konoha" else "Köyümüz için!"])
	_pose(old, "applaud", {"anim": "idle"})
	_pose(adv1, "bow", {"anim": "idle", "len": 2.4})
	_pose(adv2, "bow", {"anim": "idle", "len": 2.4})
	Sfx.play("levelup", stage, 0.6, 0.7)
	await _wait(4.5)


func pr_name() -> String:
	return String(Game.profile.get("name", "")).split(" ")[-1]


func _genin() -> void:
	var pl = Game.player
	var sensei: Node3D = null
	var mates: Array = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and is_instance_valid(f) and f.has_meta("teammate") and not f.is_dead() and f.global_position.distance_to(pl.global_position) < 60.0:
			if String(f.get_meta("friend_id", "")) == GeninSquad.fid("sensei"):
				sensei = f
			elif mates.size() < 2:
				mates.append(f)
	var fd: Vector3 = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var here = _open(pl.global_position, 4.0)
	pl.global_position = here + Vector3.UP * 0.05
	pin = pl.global_position
	if sensei == null:
		var sl = {"top": Color(0.22, 0.3, 0.22), "vest": Color(0.3, 0.38, 0.22), "gender": "m", "age": "adult", "hair_style": "dağınık", "hair": Color(0.15, 0.12, 0.1)}
		GeninSquad.dress_sensei(sl)
		sensei = _person(GeninSquad.sensei_name(), sl, here + fd * 6.0, here)
	else:
		borrowed.append([sensei, sensei.is_physics_processing()])
		sensei.set_physics_process(false)
	for m in mates:
		borrowed.append([m, m.is_physics_processing()])
		m.set_physics_process(false)
	_cine_on()
	_cam_shot(here + side * 3.2 + fd * 1.0 + Vector3.UP * 1.6, here + fd * 0.6 + Vector3.UP * 1.65)
	# takım yan yana dizilir, hoca karşılarına gelir
	for i in mates.size():
		_go_w(mates[i], here + side * (1.2 if i == 0 else -1.2), 2.4)
	await _go_w(sensei, here + fd * 1.1, 2.0)
	for m in mates:
		_look_at(m, sensei.global_position)
	_look_at(sensei, here)
	_look_at(pl, sensei.global_position)
	_say(sensei, "Bunu hak ettin. Gözlerini kapat.", 3.0)
	await _wait(3.0)
	_cam_shot(here + side * 2.8 + fd * 0.4 + Vector3.UP * 1.6, here + fd * 0.55 + Vector3.UP * 1.8)
	await _give(sensei, pl, _band_mesh())
	_pose(pl, "knot", {"anim": "idle"})
	Sfx.play("pickup", here, 0.5, 0.8)
	await _wait(1.6)
	_drop_prop()
	_grant()   # alın koruyucusu tam bağlandığı an
	await _wait(0.6)
	_clear_pose(pl)
	_say(sensei, "Tebrikler. Bugünden itibaren bir genin'sin.", 3.2)
	await _wait(2.6)
	# hatıra fotoğrafı: hoca arkada, takım önde
	_go_w(sensei, here - fd * 0.9, 2.0)
	_look_at(pl, here + fd * 4.0)
	for m in mates:
		_look_at(m, here + fd * 4.0)
	await _wait(1.0)
	_look_at(sensei, here + fd * 4.0)
	_pose(pl, "cheer", {"anim": "idle"})
	if mates.size() > 0:
		mates[0].model.play("fold", 0.3)   # biri kollarını kavuşturur
	if mates.size() > 1:
		_pose(mates[1], "wave", {"anim": "idle"})
	_cam_shot(here + fd * 3.6 + Vector3.UP * 1.3, here + Vector3.UP * 1.15)
	await _wait(1.4)
	Sfx.play("click", here, 1.0, 1.0)
	_flash()
	_cine_k = 0.0
	_cine_mat.set_shader_parameter("desat", 0.75)   # eski fotoğraf tonu
	_hold_desat = 0.75
	await _wait(2.6)
	_hold_desat = -1.0
	_clear_pose(pl)
	for m in mates:
		_clear_pose(m)
		m.model.play("idle", 0.3)


func _chunin() -> void:
	var pl = Game.player
	var fd: Vector3 = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var here = _open(pl.global_position, 5.0)
	pl.global_position = here + Vector3.UP * 0.05
	pin = pl.global_position
	var kg = _kage_npc(here + fd * 7.0, here)
	var proctor = _person("Sınav Gözetmeni", Outfits.roll("jonin", vid), here + fd * 7.0 + side * 1.6, here)
	var cands = _crowd(here - fd * 0.5, here + fd * 3.0, 8, 3.2)
	_cine_on()
	_cam_shot(here - fd * 5.0 + side * 2.5 + Vector3.UP * 2.2, here + fd * 3.0 + Vector3.UP * 1.7)
	_go_w(proctor, here + fd * 1.6 + side * 1.4, 1.6)
	await _go_w(kg, here + fd * 1.15, 1.5)
	_look_at(kg, here)
	_look_at(pl, kg.global_position)
	_cam_shot(here + side * 3.3 + fd * 0.5 + Vector3.UP * 1.75, here + fd * 0.6 + Vector3.UP * 1.85)
	_say(kg, "%s. Sınavı kazanan değil, en iyi kararı veren chūnin olur. Jüri seni seçti." % pr_name(), 4.0)
	await _wait(4.2)
	await _give(kg, pl, _vest_mesh(Color(0.33, 0.42, 0.25)))
	_say(kg, "Bu yeleği giy. Artık bir takımı sen yöneteceksin.", 3.0)
	await _wait(1.6)
	_drop_prop()
	await _change(func(): _grant())   # yelek: Chūnin seti
	_face(pl, atan2(-(kg.global_position - pl.global_position).x, -(kg.global_position - pl.global_position).z))
	_pose(pl, "bow", {"anim": "idle", "len": 2.0})
	_cam_shot(here + fd * 3.6 - side * 2.4 + Vector3.UP * 1.9, here - fd * 1.8 + Vector3.UP * 1.2)   # önden (gözetmenin olmadığı yandan): eğilen sen + arkanda alkışlayan adaylar
	_cheer(cands, ["Tebrikler!", "Hak ettin!", "Bir dahakine ben!"])
	_pose(proctor, "applaud", {"anim": "idle"})
	await _wait(3.6)


func _jonin() -> void:
	var pl = Game.player
	var fd: Vector3 = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var here = _open(pl.global_position, 5.0)
	pl.global_position = here + Vector3.UP * 0.05
	pin = pl.global_position
	var kg = _kage_npc(here + fd * 6.0, here)
	var j1 = _person("Jōnin Kefili", Outfits.roll("jonin", vid), here + fd * 6.0 + side * 1.8, here)
	var j2 = _person("Jōnin Kefili", Outfits.roll("jonin", vid), here + fd * 6.0 - side * 1.8, here)
	_cine_on()
	_cam_shot(here - fd * 3.4 + side * 1.8 + Vector3.UP * 1.9, here + fd * 3.0 + Vector3.UP * 1.7)
	_go_w(j1, here + fd * 1.8 + side * 1.6, 1.5)
	_go_w(j2, here + fd * 1.8 - side * 1.6, 1.5)
	await _go_w(kg, here + fd * 1.15, 1.5)
	_look_at(kg, here)
	_look_at(j1, here)
	_look_at(j2, here)
	_look_at(pl, kg.global_position)
	_cam_shot(here - side * 3.3 + fd * 0.5 + Vector3.UP * 1.75, here + fd * 0.6 + Vector3.UP * 1.85)
	_say(j1, "Krizde soğukkanlıydı. Kefilim.", 2.8)
	await _wait(2.8)
	_say(j2, "Ben de. Takımının hayatını kendi hayatından önde tuttu.", 3.2)
	await _wait(3.2)
	_say(kg, "Bir jōninin kararı, başkalarının hayatıdır. Bu yükü taşımaya hazırsın.", 3.8)
	await _wait(3.8)
	await _give(kg, pl, _vest_mesh(Color(0.27, 0.33, 0.22)))
	_drop_prop()
	await _change(func(): _grant())   # jōnin yeleği
	_look_at(pl, kg.global_position)
	_say(kg, "Akademiden üç genin sana emanet. Onlara senin bildiğini öğret.", 3.6)
	await _wait(2.0)
	_pose(pl, "bow", {"anim": "idle", "len": 2.0})
	_pose(j1, "applaud", {"anim": "idle"})
	_pose(j2, "applaud", {"anim": "idle"})
	_cam_shot(here + fd * 4.2 + side * 1.2 + Vector3.UP * 1.4, here + Vector3.UP * 1.3)
	await _wait(3.0)


func _rogue() -> void:
	var pl = Game.player
	var fd: Vector3 = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var here = pl.global_position
	pin = here
	var v = Game.village(String(Orgs.flags().get("rogue_from", vid)) if Orgs.flags().has("rogue_from") else vid)
	var vc = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	# yanındaki takım geride kalır (bu karar senin tek başına)
	var k := 0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and is_instance_valid(f) and f.has_meta("teammate") and f.global_position.distance_to(here) < 40.0:
			borrowed.append([f, f.is_physics_processing()])
			f.set_physics_process(false)
			f.global_position = _open(here - fd * 7.0 + side * (k * 2.5 - 1.25), 3.0)
			_look_at(f, here)
			k += 1
	_cine_on()
	_cine_k = 0.35
	_cam_shot(here + fd * 2.6 + side * 1.2 + Vector3.UP * 1.5, here + Vector3.UP * 1.45)
	await _wait(1.2)
	# bandını çözer
	_pose(pl, "knot", {"anim": "idle"})
	Sfx.play("pickup", here, 0.5, 0.8)
	await _wait(1.8)
	prop = _band_mesh(false)
	prop.global_position = _bone(pl, "Head")
	prop_at = pl
	_pose(pl, "offer", {"anim": "idle", "reach": 0.3, "lean": 4.0})
	_cam_shot(here + fd * 1.25 + side * 0.35 + Vector3.UP * 1.35, here + fd * 0.33 + Vector3.UP * 1.24)   # banda yakın
	await _tell("...", 1.2)
	# kunaiyle sembolün üstüne çizik
	var kn = _kunai_mesh()
	_pose(pl, "scratch", {"anim": "idle"})
	var plate: Vector3 = here + Vector3.UP * 1.25 + fd * 0.33
	kn.global_position = plate + side * 0.09 + Vector3.UP * 0.05
	kn.global_basis = Basis.looking_at(-side, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-70))
	var tw = create_tween()
	tw.tween_property(kn, "global_position", plate - side * 0.08 - Vector3.UP * 0.01, 0.55).set_trans(Tween.TRANS_SINE)
	Sfx.play("blade", plate, 0.7, 0.7)
	await _wait(0.3)
	Sfx.play("clink", plate, 0.6, 0.5)
	await _wait(0.4)
	# plakada artık çizik var
	prop.queue_free()
	prop = _band_mesh(true)
	prop.global_position = plate
	prop_at = pl
	await _wait(0.8)
	kn.queue_free()
	_pose(pl, "offer", {"anim": "idle", "reach": 0.3, "lean": 4.0})
	await _wait(1.0)
	# yeniden bağlar: çizik bant
	_pose(pl, "knot", {"anim": "idle"})
	await _wait(1.4)
	_drop_prop()
	_grant()
	_clear_pose(pl)
	await _wait(0.4)
	# köye son bir bakış, sonra sırtını döner ve yürür
	var to_v = vc - here
	to_v.y = 0
	to_v = to_v.normalized() if to_v.length() > 1.0 else -fd
	_look_at(pl, here + to_v * 5.0)
	_cam_shot(here - to_v * 2.4 + side * 0.8 + Vector3.UP * 1.7, here + to_v * 30.0 + Vector3.UP * 3.0)   # omzunun üstünden köye
	_cine_k = 0.6
	await _wait(2.0)
	await _tell("Elveda.", 1.6)
	_cam_shot(here + to_v * 3.5 + Vector3.UP * 1.4, here - to_v * 2.0 + Vector3.UP * 1.2)
	pin = Vector3.INF   # yürüyüp gider
	await _go_w(pl, here - to_v * 5.0, 1.4, true)
	pl.model.play("idle", 0.3)


func _pardon() -> void:
	var pl = Game.player
	var fd: Vector3 = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var here = _open(pl.global_position, 5.0)
	pl.global_position = here + Vector3.UP * 0.05
	pin = pl.global_position
	var kg = _kage_npc(here + fd * 6.5, here)
	var g1 = _person("Kapı Nöbetçisi", Outfits.roll("chunin", vid), here + fd * 6.5 + side * 1.6, here)
	var g2 = _person("Kapı Nöbetçisi", Outfits.roll("chunin", vid), here + fd * 6.5 - side * 1.6, here)
	_cine_on()
	_cine_k = 0.3
	_cam_shot(here - fd * 3.2 + side * 1.8 + Vector3.UP * 1.9, here + fd * 3.0 + Vector3.UP * 1.7)
	_go_w(g1, here + fd * 2.0 + side * 1.5, 1.4)
	_go_w(g2, here + fd * 2.0 - side * 1.5, 1.4)
	await _go_w(kg, here + fd * 1.15, 1.4)
	_look_at(kg, here)
	_look_at(g1, here)
	_look_at(g2, here)
	_look_at(pl, kg.global_position)
	_cam_shot(here + side * 3.3 + fd * 0.5 + Vector3.UP * 1.75, here + fd * 0.6 + Vector3.UP * 1.85)
	_say(kg, "Kanıtını getirdin. Köyüne sırt çevirdin... ama onu korumak için geri döndün.", 4.0)
	await _wait(4.2)
	# çizik bandı çözüp teslim eder
	_pose(pl, "knot", {"anim": "idle"})
	await _wait(1.6)
	var old_band = _band_mesh(true)
	old_band.global_position = _bone(pl, "Head")
	await _give(pl, kg, old_band)
	await _wait(0.6)
	_drop_prop()
	_say(kg, "Bu artık geçmişte kaldı.", 2.4)
	await _wait(2.0)
	# yenisini uzatır; alnına bağlarsın
	await _give(kg, pl, _band_mesh(false))
	_pose(pl, "knot", {"anim": "idle"})
	Sfx.play("pickup", here, 0.5, 0.8)
	await _wait(1.5)
	_drop_prop()
	_grant()   # af: bant temiz
	_cine_k = 0.0
	await _wait(0.5)
	_clear_pose(pl)
	_say(kg, "Köyüne yeniden hoş geldin, %s." % pr_name(), 3.2)
	_pose(g1, "bow", {"anim": "idle", "len": 2.0})
	_pose(g2, "bow", {"anim": "idle", "len": 2.0})
	_pose(pl, "bow", {"anim": "idle", "len": 2.2})
	_cam_shot(here - fd * 4.0 + side * 2.0 + Vector3.UP * 2.0, here + fd * 1.0 + Vector3.UP * 1.3)
	await _wait(3.4)


# ====================================================================== sahne kamerası + solma (ölüm sahnesiyle aynı ekran efekti)
var _cine_cam: Camera3D
var _cine_mat: ShaderMaterial
var _cine_layer: CanvasLayer
var _flash_rect: ColorRect
var _cine_k := 0.15
var _cine_now := 0.0
var _hold_desat := -1.0
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO
var _cine_bh: Node


func _cine_on() -> void:
	if is_instance_valid(_cine_cam):
		return
	_cine_layer = CanvasLayer.new()
	_cine_layer.layer = 9
	add_child(_cine_layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DeathScene.SHADER
	_cine_mat = ShaderMaterial.new()
	_cine_mat.shader = sh
	r.material = _cine_mat
	_cine_layer.add_child(r)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_cine_layer.add_child(_flash_rect)
	_cine_cam = Camera3D.new()
	_cine_cam.fov = 50.0
	_cine_cam.far = 4000.0
	add_child(_cine_cam)
	_cine_cam.global_transform = Game.player.cam.global_transform
	_cam_from = _cine_cam.global_position
	_cam_at = Game.player.global_position + Vector3.UP * 1.2
	if Game.world and Game.world.get("env"):
		Game.world.env.attach_post(_cine_cam)
	_cine_cam.current = true
	Hud.show_game_hud(false)
	if Hud.banner_box.get_parent() != Hud:
		_cine_bh = Hud.banner_box.get_parent()
		Hud.banner_box.reparent(Hud, false)


func _cine_off() -> void:
	var pl = Game.player
	if pl and is_instance_valid(pl) and pl.cam:
		pl.cam.current = true
		if Game.world and Game.world.get("env"):
			Game.world.env.attach_post(pl.cam)
	if _cine_bh and is_instance_valid(_cine_bh) and Hud.banner_box.get_parent() != _cine_bh:
		Hud.banner_box.reparent(_cine_bh, false)
	_cine_bh = null
	Hud.show_game_hud(true)
	if is_instance_valid(_cine_layer):
		_cine_layer.queue_free()
	if is_instance_valid(_cine_cam):
		_cine_cam.queue_free()
	_cine_cam = null


func _flash() -> void:
	if not is_instance_valid(_flash_rect):
		return
	_flash_rect.color = Color(1, 1, 1, 0.9)
	var tw = create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.5)


func _cam_shot(from: Vector3, at: Vector3) -> void:
	if not is_instance_valid(_cine_cam):
		return
	# kamera yapıya girmesin: açı duvara çarparsa aynası, sonra yükseği denenir; hiçbiri açık değilse en uzak açık nokta
	var off: Vector3 = from - at
	var fdv: Vector3 = Game.player.face_dir()
	var lat: Vector3 = off - fdv * off.dot(fdv)
	lat.y = 0.0
	var cands = [from, from - lat * 2.0, from + Vector3.UP * 1.6, from - lat * 2.0 + Vector3.UP * 1.6]
	var best: Vector3 = from
	var best_d := -1.0
	for cnd in cands:
		var q = PhysicsRayQueryParameters3D.create(at, cnd, 1)
		q.exclude = [Game.player.get_rid()]
		var hit = Game.player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			best = cnd
			break
		var hp: Vector3 = at + (hit["position"] - at) * 0.85
		if hp.distance_to(at) > best_d:
			best_d = hp.distance_to(at)
			best = hp
	from = best
	from.y = maxf(from.y, Game.ground_height(from.x, from.z) + 0.4)
	# açı değişimi KESME ile; çekim boyunca hedefe doğru yavaşça yaklaşır
	_cine_cam.global_position = from
	if from.distance_to(at) > 0.05:
		_cine_cam.look_at(at, Vector3.UP)
	_cam_from = from.lerp(at, 0.12)
	_cam_at = at


func _cine_tick(dt: float) -> void:
	if not is_instance_valid(_cine_cam) or not _cine_cam.current:
		return
	_cine_now = move_toward(_cine_now, _cine_k, dt * 0.35)
	_cine_mat.set_shader_parameter("bars", 1.0)
	_cine_mat.set_shader_parameter("desat", _hold_desat if _hold_desat >= 0.0 else _cine_now)
	_cine_mat.set_shader_parameter("vig", 0.35 + _cine_now * 0.6)
	_cine_cam.global_position = _cine_cam.global_position.lerp(_cam_from, minf(1.0, dt * 0.25))
	var want = _cine_cam.global_transform.looking_at(_cam_at, Vector3.UP).basis
	_cine_cam.global_basis = _cine_cam.global_basis.slerp(want, minf(1.0, dt * 2.5)).orthonormalized()
