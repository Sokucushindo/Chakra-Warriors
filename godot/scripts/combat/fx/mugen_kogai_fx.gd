extends RefCounted
## Mugen Kōgai (無限甲蓋; hedef: res://scripts/combat/fx/mugen_kogai_fx.gd). Kanon (Narutopedia "Infinite Armour", ANİME 218; Hōki, Seimei, Suiko): kaplan yüzlü göğüslük.
## Değen her şeyin chakrasını hızla çeker (Gaara'nın kumu düşer, Lee'nin tekmesindeki chakra emilir); emilen chakra yarayı ve chakrayı onarır. Zayıflık: delen mermiyi emecek hızda
## çekemez (Gaara'nın kum mızrağı). "Hasar indirimi yok" kuralı: yüzde düşürmez. Chakralı vuruşu ya TAMAMEN yutar ya hiç: tek vuruş EMIS_MAX üstündeyse ve depo doluysa geçer.
## Fiziksel silah ve aletler emilmez. Yakın dövüşle değen de chakra kaybeder ama vuruş geçer. Düşüş hasarı oyunda olmadığı için o özellik yok.
## Ref refs/mugen_kogai: beyaz kaplan başı, kulaklar, tüy katları, sarı çerçeveli açık ağız, azı dişleri.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const EMIS_MAX := 38.0    # bundan güçlü tek vuruş delip geçer
const DEPO := 110.0       # dolunca durur
const BOSALMA := 9.0      # saniyede boşalır
const STEAL := 7.0        # yakın dövüşle değenden çekilen chakra
const WHITE := Color(0.93, 0.93, 0.92)
const SHADE := Color(0.74, 0.74, 0.76)
const GOLD := Color(0.84, 0.68, 0.32)


## Yüz düzlemi XY, ön +Z (slab: kalınlık X'ten Z'ye çevrilir)
static func _xy(z: float) -> Transform3D:
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(0, 0, z))


## (x, y) noktaları -> slab (y, -x)
static func _o(pts: Array) -> PackedVector2Array:
	var o = PackedVector2Array()
	for p in pts:
		o.append(Vector2(float(p[1]), -float(p[0])))
	return o


static func build_chest(b: MB) -> void:
	b.add_slab(_o([[-0.12, 0.13], [0.12, 0.13], [0.16, 0.03], [0.13, -0.1], [0.05, -0.17], [-0.05, -0.17], [-0.13, -0.1], [-0.16, 0.03]]), 0.03, WHITE, _xy(0.0))
	for sx in [-1.0, 1.0]:
		b.add_slab(_o([[sx * 0.06, 0.12], [sx * 0.15, 0.13], [sx * 0.15, 0.22]]), 0.022, WHITE, _xy(0.008))
		b.add_slab(_o([[sx * 0.095, 0.135], [sx * 0.135, 0.14], [sx * 0.135, 0.185]]), 0.006, SHADE, _xy(0.022))
		for k in 3:   # yan tüy katları
			var y = 0.05 - k * 0.075
			b.add_slab(_o([[sx * 0.12, y + 0.05], [sx * (0.235 - k * 0.018), y - 0.012], [sx * 0.12, y - 0.04]]), 0.022, WHITE if k % 2 == 0 else SHADE, _xy(0.004))
		b.add("sphere", Vector3(sx * 0.07, 0.07, 0.022), Vector3(0.05, 0.026, 0.012), Color(0.04, 0.04, 0.05), Vector3(0, 0, sx * -14.0), 8)
		b.add("cone", Vector3(sx * 0.066, 0.0, 0.026), Vector3(0.026, 0.075, 0.012), Color(0.98, 0.98, 0.96), Vector3(180, 0, 0), 5)
		b.add("cone", Vector3(sx * 0.052, -0.13, 0.026), Vector3(0.02, 0.055, 0.01), Color(0.98, 0.98, 0.96), Vector3.ZERO, 5)
	b.add_slab(_o([[-0.075, 0.035], [0.075, 0.035], [0.075, -0.1], [0.035, -0.135], [-0.035, -0.135], [-0.075, -0.1]]), 0.006, GOLD, _xy(0.018))
	b.add_slab(_o([[-0.058, 0.02], [0.058, 0.02], [0.058, -0.092], [0.026, -0.118], [-0.026, -0.118], [-0.058, -0.092]]), 0.008, Color(0.16, 0.1, 0.16), _xy(0.021))
	b.add("sphere", Vector3(0, 0.135, 0.018), Vector3(0.04, 0.026, 0.02), Color(0.32, 0.74, 0.56), Vector3.ZERO, 8)


static func worn(t: Node) -> bool:
	var m = t.get("model")
	if m == null or m.get("look") == null:
		return false
	return str(m.look.get("back_item", "")) == "mugen_kogai"


static func _fill(t: Node3D) -> float:
	var now = Game.now()
	var v = maxf(0.0, float(t.get_meta("mk_dolu", 0.0)) - (now - float(t.get_meta("mk_t", now))) * BOSALMA)
	t.set_meta("mk_t", now)
	return v


static func _chest(t: Node3D) -> Vector3:
	return Kit.chest(t) + t.face_dir() * 0.2 if t.has_method("face_dir") else Kit.chest(t)


## Mavi chakra taneleri kaynaktan göğüsteki ağza akar
static func _stream(from: Vector3, t: Node3D, n: int) -> void:
	var m = Kit.cached_mesh("mk_tane", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.05, Color(0.62, 0.82, 1.0), Vector3.ZERO, 6)
		return b.build(Props.toon_color(Color(0.62, 0.82, 1.0), 0.5)))
	for k in n:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		mi.global_position = from
		var ph = randf() * TAU
		var fly = func(v: float) -> void:
			if is_instance_valid(mi) and is_instance_valid(t):
				var q = from.lerp(_chest(t), v * v)
				mi.global_position = q + Vector3(cos(ph + v * 9.0), sin(ph + v * 7.0), sin(ph + v * 9.0)) * 0.22 * (1.0 - v)
				mi.scale = Vector3.ONE * (1.0 - v * 0.7)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.025)
		tw.tween_method(fly, 0.0, 1.0, 0.26)
		tw.tween_callback(mi.queue_free)


static func _gain(t: Node3D, amount: float) -> void:
	if t.get("chakra") != null and t.get("max_chakra") != null:
		t.chakra = minf(float(t.max_chakra), float(t.chakra) + amount * 0.6)
	if t.get("hp") != null and t.get("max_hp") != null:
		t.hp = minf(float(t.max_hp), float(t.hp) + amount * 0.15)


## Combat.speed_dodge başından (oyuncu + düşman). true: vuruş tamamen yutuldu.
static func absorb(t: Node3D, info: Dictionary) -> bool:
	if not worn(t) or info.get("sure", false):
		return false
	var atk = info.get("attacker")
	var src: Vector3 = U.chest(atk) if atk != null and is_instance_valid(atk) and atk is Node3D else Kit.chest(t) + Vector3.UP
	if info.get("melee", false):   # değen chakra verir, darbe yine işler
		if atk != null and is_instance_valid(atk) and atk is Node3D and Game.now() >= float(t.get_meta("mk_el", 0.0)):
			t.set_meta("mk_el", Game.now() + 0.4)
			if atk.get("chakra") != null:
				atk.chakra = maxf(0.0, float(atk.chakra) - STEAL)
			elif atk.has_method("apply_status"):
				atk.apply_status("sealed", 0.8)
			_gain(t, STEAL)
			_stream(src, t, 4)
		return false
	var chakra_hit = info.has("tier") or (not info.get("element", "") in [null, ""])
	if not chakra_hit or info.has("tool"):
		return false
	var d = float(info.get("dmg", 0.0))
	var fill = _fill(t)
	if d > EMIS_MAX or fill + d > DEPO:
		t.set_meta("mk_dolu", fill)
		return false   # kanon: emebileceğinden hızlı gelen delip geçer
	t.set_meta("mk_dolu", fill + d)
	_gain(t, d)
	_stream(src, t, 7)
	Sfx.play("absorb", t.global_position + Vector3.UP, 1.2, 0.5)
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Emildi", Color(0.65, 0.85, 1.0))
	return true
