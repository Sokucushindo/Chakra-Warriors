class_name CatNPC
extends CharacterBody3D
## Kayıp kedi Mikan: yaklaşınca kaçar, duvarlara tırmanır. [F] ile yakala.

var vis: Node3D
var t = 0.0
var flee = Vector3.ZERO
var ambient = false   # köydeki gezgin kedi/köpek (yakalanmaz)
var is_dog = false


func _ready() -> void:
	add_to_group("catchables")   # köydeki gezgin hayvan da [F] alır: yakalanmaz, sevilir
	if ambient:
		catch_label = "Sev"
	collision_layer = 0
	collision_mask = 1
	var cs = CollisionShape3D.new()
	var sh = SphereShape3D.new()
	sh.radius = 0.25
	cs.shape = sh
	cs.position.y = 0.25
	add_child(cs)
	# detaylı model (TownAnimals): kedi tekir / calico / smokin / siyah..., köpek shiba / akita / kurt köpeği; bacaklar ve kuyruk salınır
	var rng = RandomNumberGenerator.new()
	rng.seed = get_instance_id() * 7919 + Time.get_ticks_usec()   # her hayvan farklı tüy rengi
	var d: Dictionary = TownAnimals.dog(rng) if is_dog else TownAnimals.cat(rng, not ambient)
	vis = d["root"]
	add_child(vis)
	legs = d["legs"]
	tail = d["tail"]


var legs: Array = []
var tail: Node3D = null
var catch_label = "Yakala!"
var pet := 0          # 0 yok, 1 oyuncu yaklaşıyor (durup bekler), 2 seviliyor, 3 sevildi (köpek peşinden gelir / kedi sürtünür)
var pet_t := 0.0
var pet_who: Node3D = null


func pet_begin(who: Node3D) -> void:
	pet = 1
	pet_t = 0.0
	pet_who = who
	flee = Vector3.ZERO


## Sevilirken oyuncuya yan döner (sırtı elin altında)
func pet_face(who: Node3D) -> void:
	pet = 2
	pet_t = 0.0
	var to: Vector3 = who.global_position - global_position
	vis.rotation.y = atan2(-to.x, -to.z) + PI * 0.5


func pet_end(who: Node3D) -> void:
	pet = 3
	pet_t = 0.0
	pet_who = who
	vis.rotation.x = 0.0
	vis.position.y = 0.0


func _process(_dt: float) -> void:
	# yürüyüş: çapraz bacak salınımı hızla orantılı, kuyruk sallanır
	var spd = Vector2(velocity.x, velocity.z).length()
	var ph = t * (6.0 + spd * 1.6)
	for i in legs.size():
		var lg: Node3D = legs[i]
		lg.rotation.x = sin(ph + (PI if i in [1, 2] else 0.0)) * clampf(spd * 0.12, 0.0, 0.55)
	if tail:
		tail.rotation.z = sin(t * (3.0 if not is_dog else 9.0)) * (0.25 if not is_dog else 0.35)
	if pet == 2:
		pet_t += _dt
		var k = smoothstep(0.0, 0.5, pet_t)
		if is_dog:
			# oturur (arka alçalır), kuyruk çılgınca sallanır, sevinçten ön ayakları kalkıp iner, soluk soluğa
			vis.rotation.x = 0.3 * k + maxf(0.0, sin(pet_t * 5.0)) * 0.12 * k
			vis.position.y = absf(sin(pet_t * 5.0)) * 0.04 * k
			if tail:
				tail.rotation.z = sin(pet_t * 22.0) * 0.7
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = (-0.3 * k) if i >= 2 else (sin(pet_t * 5.0) * 0.25 * k)
		else:
			# oturur, sırtını ele doğru kabartır, kuyruk dik ve ucu ağır ağır kıvrılır, başını ele sürter
			vis.rotation.x = 0.22 * k
			vis.position.y = (0.035 + sin(pet_t * 4.2) * 0.02) * k
			vis.rotation.z = sin(pet_t * 2.1) * 0.08 * k
			if tail:
				tail.rotation.z = sin(pet_t * 2.4) * 0.3
				tail.rotation.x = -0.5 * k
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = (-0.25 * k) if i >= 2 else 0.0
	elif pet == 3 and tail:
		tail.rotation.x = 0.0
		if is_dog:
			tail.rotation.z = sin(t * 18.0) * 0.55


func _physics_process(dt: float) -> void:
	t += dt
	velocity.y -= 30.0 * dt
	var pl = Game.player
	if ambient:
		pl = null
	if pet in [1, 2]:
		# seviliyor: yerinde durur (60 sn'de bırakılmazsa kendiliğinden yoluna döner)
		pet_t += dt if pet == 1 else 0.0
		if pet == 1 and pet_t > 60.0:
			pet = 0
		velocity.x = 0.0; velocity.z = 0.0
		move_and_slide()
		var g0 = Game.ground_height(global_position.x, global_position.z)
		if global_position.y < g0:
			global_position.y = g0; velocity.y = 0
		return
	if pet == 3:
		pet_t += dt
		if not is_instance_valid(pet_who) or pet_t > (14.0 if is_dog else 3.5):
			pet = 0
		else:
			var to: Vector3 = pet_who.global_position - global_position
			to.y = 0
			if is_dog:
				# köpek sevenin peşinden koşar, yanında durur
				flee = to.normalized() * minf(7.0, to.length() * 1.6) if to.length() > 1.6 else Vector3.ZERO
			else:
				# kedi bacağa sürtünür: yanından dolanır
				flee = (to.normalized() * 0.5 + to.normalized().cross(Vector3.UP) * 0.9) * (1.0 if to.length() > 0.45 else 0.6)
			velocity.x = flee.x; velocity.z = flee.z
			move_and_slide()
			var g1 = Game.ground_height(global_position.x, global_position.z)
			if global_position.y < g1:
				global_position.y = g1; velocity.y = 0
			if flee.length() > 0.1:
				vis.rotation.y = atan2(-flee.x, -flee.z)
			return
	if pl and pl.global_position.distance_to(global_position) < 9.0:
		flee = (global_position - pl.global_position)
		flee.y = 0
		flee = flee.normalized() * 9.0
	elif fmod(t, 3.0) < dt:
		flee = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 2.0
	velocity.x = flee.x; velocity.z = flee.z
	move_and_slide()
	if is_on_wall():
		velocity.y = 6.0
	var g = Game.ground_height(global_position.x, global_position.z)
	if global_position.y < g:
		global_position.y = g; velocity.y = 0
	if flee.length() > 0.1:
		vis.rotation.y = atan2(-flee.x, -flee.z)   # yeni model önü -z: kafa gidilen yöne


func catch() -> void:
	if ambient:
		if pet == 0 or pet == 3:
			MissionWork.I().pet_animal(self)   # yanına git, diz çök, sev
		return
	if not Missions.active().is_empty() and Missions._cur().get("kind", "") == "cat":
		MissionWork.I().catch_cat(self)   # çömel, kavra, omza al
		return
	Hud.dialog("Mikan", "Miyaaav! (Kediyi yakaladın, çizik içindesin ama görev tamam.)", [])
	Missions.on_cat_caught()
	queue_free()
