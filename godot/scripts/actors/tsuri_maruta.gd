class_name TsuriMaruta
extends TrainingDummy
## Tsuri Maruta (asılı kütük): iki direkli çatıya iple asılmış, ortası bez sargılı kalın kütük. Vurunca vurduğun yöne savrulur,
## sarkaç gibi geri gelir; önündeysen sana çarpar. Çarpmayı yemek (ya da blokla karşılamak) dayanıklılığı, vurmak taijutsu'yu geliştirir.
## Kaçarsan bir şey kazanmazsın. Hasar azdır ve asla öldürmez (canın 1'in altına inmez).
## Kaynak: Lee / Gai'nin kütüğe vurarak beden sertleştirme antrenmanı (Narutopedia Third Training Ground kütükleri).

const PIVOT_H := 3.7    # çatı kirişi yüksekliği
const R := 2.05         # pivottan kütük ortasına (ip 1.25 + yarım kütük 0.8)
const W := 2.2          # √(g / R) ≈ sarkaç açısal hızı
var pivot: Node3D
var th := Vector2.ZERO   # savrulma açısı (dünya x, z yönünde; radyan)
var thv := Vector2.ZERO
var hit_cd := 0.0
static var _told := false


func _ready() -> void:
	add_to_group("fighters")
	global_position.y = Game.ground_height(global_position.x, global_position.z)
	radius = 0.5
	height = 2.2
	vis = Node3D.new()
	add_child(vis)
	var bark := Color(0.38, 0.27, 0.17)
	var rope := Color(0.7, 0.6, 0.42)
	var b := MB.new()
	var I := Transform3D.IDENTITY
	# çatı: iki eğik ayaklı direk + kiriş + ip bağları
	for sx in [-1.0, 1.0]:
		CampKit._rod(b, I, Vector3(sx * 1.35, 0.0, 0.0), Vector3(sx * 1.2, PIVOT_H + 0.15, 0.0), 0.11, bark, 7)
		for sz in [-1.0, 1.0]:   # payanda
			CampKit._rod(b, I, Vector3(sx * 1.3, 0.0, sz * 0.75), Vector3(sx * 1.24, 1.6, 0.0), 0.06, bark.darkened(0.1), 5)
		b.add("cyl", Vector3(sx * 1.35, 0.06, 0), Vector3(0.36, 0.12, 0.36), bark.darkened(0.3), Vector3.ZERO, 8)
	CampKit._rod(b, I, Vector3(-1.5, PIVOT_H + 0.08, 0), Vector3(1.5, PIVOT_H + 0.08, 0), 0.1, bark.lightened(0.05), 7)
	for sx in [-1.0, 1.0]:
		b.add("torus", Vector3(sx * 1.2, PIVOT_H + 0.08, 0), Vector3(0.24, 0.5, 0.24), rope, Vector3(0, 0, 90), 8)
	var fm := MeshInstance3D.new()
	fm.mesh = b.build(Props.toon())
	vis.add_child(fm)
	# sallanan kısım: pivot kirişte, kütük aşağıda
	pivot = Node3D.new()
	pivot.position = Vector3(0, PIVOT_H, 0)
	add_child(pivot)
	var lb := MB.new()
	for sx in [-1.0, 1.0]:
		CampKit._rod(lb, I, Vector3(sx * 0.32, 0.0, 0), Vector3(sx * 0.18, -1.27, 0), 0.018, rope, 4)
	lb.add("cyl", Vector3(0, -R, 0), Vector3(0.58, 1.6, 0.58), bark, Vector3.ZERO, 10)
	lb.add("cyl", Vector3(0, -R + 0.805, 0), Vector3(0.5, 0.012, 0.5), Color(0.7, 0.56, 0.38), Vector3.ZERO, 10)   # kesik uç halkası
	lb.add("cyl", Vector3(0, -R - 0.805, 0), Vector3(0.5, 0.012, 0.5), Color(0.7, 0.56, 0.38), Vector3.ZERO, 10)
	lb.add("cyl", Vector3(0, -R, 0), Vector3(0.62, 0.75, 0.62), Color(0.86, 0.82, 0.72), Vector3.ZERO, 12)   # vuruş yeri bez sargı
	for k in 5:
		lb.add("torus", Vector3(0, -R - 0.32 + k * 0.16, 0), Vector3(0.64, 0.3, 0.64), Color(0.74, 0.7, 0.6), Vector3(0, 0, 4.0 - k * 2.0), 12)
	lb.add("sphere", Vector3(0.03, -R + 0.08, 0.3), Vector3(0.2, 0.26, 0.03), Color(0.62, 0.5, 0.42), Vector3(0, 0, 18), 8)   # eski kan / ter lekesi
	lb.add("torus", Vector3(0, -R + 0.72, 0), Vector3(0.62, 0.4, 0.62), rope, Vector3.ZERO, 12)   # ip bağı
	var lm := MeshInstance3D.new()
	lm.mesh = lb.build(Props.toon())
	pivot.add_child(lm)
	# çarpışma: yalnız direkler (kütük oyuncuyu itmez; çarpmayı sarkaç kendi yapar)
	var sb := StaticBody3D.new()
	for sx in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.14
		sh.height = PIVOT_H
		cs.shape = sh
		cs.position = Vector3(sx * 1.28, PIVOT_H * 0.5, 0)
		sb.add_child(cs)
	add_child(sb)


func take_hit(info: Dictionary) -> void:
	var d: Vector3 = info.get("dir", -global_transform.basis.z)
	var atk = info.get("attacker")
	if atk is Node3D and is_instance_valid(atk):
		d = global_position - (atk as Node3D).global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var dmg: float = info.get("dmg", 5.0)
	var heavy: bool = info.get("kind", "") == "heavy"
	thv += Vector2(d.x, d.z) * clampf(0.9 + dmg * 0.02, 0.9, 1.8) * (1.4 if heavy else 1.0)
	Combat.damage_number(global_position + Vector3.UP * 2.3, dmg, Color(1, 0.9, 0.3) if not heavy else Color(1, 0.55, 0.2))
	Progress.on_dummy_hit(self, dmg)   # vuran: taijutsu / kenjutsu (kuklayla aynı)
	Sfx.play("punch", global_position + Vector3.UP * 1.6, randf_range(0.6, 0.75), 0.7)
	if not _told and atk == Game.player:
		_told = true
		Hud.msg("Tsuri Maruta: kütük geri gelecek — karşıla (ya da blokla) dayanıklılığın artsın, kaçarsan bir şey kazanmazsın.", Color(1.0, 0.9, 0.6))


func _physics_process(dt: float) -> void:
	if pivot == null:
		return
	# sarkaç: θ'' = -ω² sin θ - sönüm
	thv += (-Vector2(sin(th.x), sin(th.y)) * W * W - thv * 0.35) * dt
	th += thv * dt
	if th.length() > 1.15:
		th = th.normalized() * 1.15
		thv *= -0.3
	pivot.rotation = Vector3(-th.y, 0.0, th.x)
	hit_cd -= dt
	if hit_cd > 0.0 or thv.length() * R < 1.6:
		return
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.hp <= 1.0:
		return
	var lc: Vector3 = pivot.global_transform * Vector3(0, -R, 0)
	var to: Vector3 = pl.global_position + Vector3.UP * 1.1 - lc
	var v := Vector3(cos(th.x) * thv.x, 0.0, cos(th.y) * thv.y) * R
	if Vector2(to.x, to.z).length() > 0.85 or absf(to.y) > 1.2 or v.dot(Vector3(to.x, 0, to.z)) <= 0.0:
		return
	hit_cd = 0.9
	var sp := clampf(v.length() / 4.0, 0.4, 1.3)
	var dmg := minf(pl.max_hp * 0.035 * sp, pl.hp - 1.0)   # asla öldürmez
	var hp0: float = pl.hp
	var guarding: bool = pl.combat != null and pl.combat.action == "guard"
	pl.take_hit({"dmg": dmg, "attacker": self, "kind": "heavy" if sp > 0.9 else "light", "dir": v.normalized(), "melee": true, "knock": 2.0 * sp})
	if pl.hp < hp0 or guarding:
		Mastery.gain(Game.profile, "dayaniklilik", 0.07 * (0.6 if guarding else 1.0))   # ~13 çarpmada 1 puan (kuklada vuruşla taijutsu ~25 vuruş)   # bilerek darbe karşılama: dayakla gelen kazancın üstüne
		Sfx.play("hit_heavy", lc, randf_range(0.55, 0.7), 0.8)
	thv *= -0.25   # gövdeye çarpıp geri teper


func is_dead() -> bool:
	return false
