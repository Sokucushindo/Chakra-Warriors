extends RefCounted
## Naitosōdo: model, uzayan ağız ve chakra kesiği (hedef: res://scripts/combat/fx/naitosodo_fx.gd). Kanon: Temujin'in Avrupa tipi kısa kılıcı; ağzı boğumlarından uzayıp tam boy geniş kılıç olur, enerji akıtılınca menzili büyür.
## Kanonda enerji Gelel taşından gelir; taş oyunda yok, kullanıcının chakrası harcanır (uyarlama). Ref: altın kanatlı siper, kırmızı taş, burgulu sap, topuz. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const BL = preload("res://scripts/actors/blade_loft.gd")

const ID := "naitosodo"
const COST := 0.12

const WAVE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float s = 0.5 + 0.5 * sin(UV.x * 26.0 + UV.y * 5.0 - TIME * 12.0);
	ALBEDO = mix(vec3(0.2, 0.72, 0.58), vec3(0.88, 1.0, 0.94), smoothstep(0.35, 0.95, e * (0.7 + 0.3 * s)));
	ALPHA = smoothstep(0.0, 0.5, e) * smoothstep(0.0, 0.1, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x)) * fade_k * 0.85;
}
"""


## Kabza 0, ağız +Z, keskin yüzler ±Y (kılıç gibi ince eksen X). Ref refs/naitosodo/Knight_Sword_2.png + Knight_Sword_Extending.png:
## geniş düz iki ağızlı ağız (yassı orta yüz + açık renk ağız şevleri), uçta bir kenarı eğik kesilmiş sivri uç, siperin dibinde dar
## kök (ricasso) ve basamak; uzun hâlde eğik uzama boğumları. Altın siper: ortada oval kabartma göbek + iki yüzde kırmızı oval taş
## (altın yuva içinde), iki yana açılıp ağıza doğru kıvrılan hilal kanatlar (ortada kabartma sırt, uçları çatallı). Sap: kahve
## burgulu sargı, siper altında altın bilezik, dipte uzun altın topuz.
static func model(b: MB, id: String) -> void:
	var steel = Color(0.76, 0.78, 0.83)
	var steel_d = Color(0.62, 0.64, 0.7)
	var bevel = Color(0.95, 0.96, 0.98)
	var gold = Color(0.8, 0.7, 0.42)
	var gold_d = Color(0.6, 0.5, 0.28)
	var L = 1.28 if id == "naitosodo_uzun" else 0.56
	_blade(b, L, steel, steel_d, bevel, id == "naitosodo_uzun")
	_guard(b, gold, gold_d)
	_grip(b, gold, gold_d)


## Ağız: altı köşeli kesit (iki keskin kenar, şev çizgileri, yassı yüzler). z 0.03 (siperin içinde) -> 0.09 + L uç.
static func _blade(b: MB, L: float, steel: Color, steel_d: Color, bevel: Color, long_b: bool) -> void:
	var z0 := 0.09
	var zt := z0 + L          # uç
	var tip := 0.13
	var zl := [0.03, z0, z0 + 0.045, z0 + 0.05, z0 + 0.06]
	var n := int(ceil((L - tip - 0.06) / 0.1))
	for k in range(1, n + 1):
		zl.append(lerpf(z0 + 0.06, zt - tip, float(k) / n))
	for u in [0.25, 0.5, 0.75, 0.92, 1.0]:
		zl.append(zt - tip + u * tip)
	var secs := []
	for z in zl:
		var w := 0.045
		if z < z0 + 0.048:
			w = 0.032                                   # dar kök (ricasso)
		elif z < z0 + 0.06:
			w = 0.047                                   # kök basamağı
		w *= 1.0 - 0.06 * clampf((z - z0) / L, 0.0, 1.0)
		var u := clampf((z - (zt - tip)) / tip, 0.0, 1.0)
		var y_lo := -w                                  # alt kenar uca kadar düz
		var y_hi := lerpf(w, -w * 0.8, pow(u, 0.9))     # üst kenar eğik kesilir (ref: tek yanlı sivri uç)
		var th := 0.0075 * lerpf(1.0, 0.25, u)          # yassı yüz yarı kalınlığı
		var bv := (y_hi - y_lo) * 0.17                  # ağız şevi eni
		var mid := (y_hi + y_lo) * 0.5
		secs.append(PackedVector2Array([
			Vector2(0.0, y_hi), Vector2(th, y_hi - bv), Vector2(th * 1.12, mid), Vector2(th, y_lo + bv),
			Vector2(0.0, y_lo), Vector2(-th, y_lo + bv), Vector2(-th * 1.12, mid), Vector2(-th, y_hi - bv)]))
	# yüzler: 0 şev, 1-2 yassı yüz (ortada çok hafif sırt), 3 şev, 4 şev, 5-6 yassı, 7 şev
	BL.loft(b, secs, zl, [bevel, steel, steel_d, bevel, bevel, steel_d, steel, bevel], true, true, true)
	if long_b:
		for k in 3:   # uzama boğumları: ağzın iki yüzünde eğik koyu çizgi (ref Knight_Sword_Extending)
			var z := z0 + 0.36 + k * 0.3
			for sx in [-1.0, 1.0]:
				b.add("box", Vector3(sx * 0.0086, 0, z), Vector3(0.0015, 0.098, 0.004), steel_d.darkened(0.45), Vector3(-28, 0, 0))


## Siper: oval göbek + taş yuvası + hilal kanatlar (y-z düzleminde yassı levha, X kalınlık)
static func _guard(b: MB, gold: Color, gold_d: Color) -> void:
	var zc := 0.062   # göbeğin altı yumruğun üstünde kalsın (el siperin hemen altında)
	# göbek: iki katlı oval (geniş ince taban + kalın iç kabartma), kenarı koyu
	b.add_slab(_ellipse(0.06, 0.042, zc, 24), 0.03, gold, Transform3D.IDENTITY, Callable(), gold_d)
	b.add_slab(_ellipse(0.047, 0.034, zc, 24), 0.042, gold.lightened(0.06), Transform3D.IDENTITY, Callable(), gold_d)
	# kanatlar: kökten dışa (+-Y) uzanıp ağıza (+Z) doğru kıvrılan hilal, uçta çatal
	for sy in [-1.0, 1.0]:
		var o := PackedVector2Array()
		var inner := []
		var outer := []
		for k in 13:
			var t := k / 12.0
			var ph := deg_to_rad(lerpf(0.0, 80.0, t))           # kıvrılma: kökte dışa (Y), uçta ağıza (+Z)
			var p := Vector2(0.04 + sin(ph) * 0.13, zc - 0.012 + (1.0 - cos(ph)) * 0.11)
			var half := lerpf(0.03, 0.017, t)                     # kanat eni uca doğru incelir
			var nrm := Vector2(-sin(ph) * 0.11, cos(ph) * 0.13).normalized()
			outer.append(p - nrm * half)
			inner.append(p + nrm * half)
		var tipc: Vector2 = (outer[12] + inner[12]) * 0.5
		var tdir: Vector2 = (tipc - (outer[11] + inner[11]) * 0.5).normalized()
		for q in outer:
			o.append(q)
		o.append(outer[12] + tdir * 0.022)                   # çatalın dış dişi
		o.append(tipc + tdir * 0.006)                         # çatal oyuğu
		o.append(inner[12] + tdir * 0.016)                    # iç diş
		for k in range(12, -1, -1):
			o.append(inner[k])
		for i in o.size():
			o[i] = Vector2(o[i].x * sy, o[i].y)
		b.add_slab(o, 0.026, gold, Transform3D.IDENTITY, func(q: Vector2) -> float: return lerpf(0.026, 0.012, clampf((absf(q.x) - 0.04) / 0.14, 0.0, 1.0)), gold_d)
		# kanadın ortasında kabartma sırt (daha dar levha, biraz kalın)
		var rib := PackedVector2Array()
		for k in range(1, 12):
			rib.append(Vector2(((outer[k] + inner[k]) * 0.5).x * sy, ((outer[k] + inner[k]) * 0.5).y) + ((outer[k] - inner[k]) * 0.18) * Vector2(sy, 1))
		for k in range(11, 0, -1):
			rib.append(Vector2(((outer[k] + inner[k]) * 0.5).x * sy, ((outer[k] + inner[k]) * 0.5).y) - ((outer[k] - inner[k]) * 0.18) * Vector2(sy, 1))
		b.add_slab(rib, 0.034, gold.lightened(0.1), Transform3D.IDENTITY, func(q: Vector2) -> float: return lerpf(0.034, 0.016, clampf((absf(q.x) - 0.04) / 0.14, 0.0, 1.0)), gold_d)
	# taş: iki yüzde altın yuva halkası + kırmızı oval kabaşon + parlama
	for sx in [-1.0, 1.0]:
		b.add("torus", Vector3(sx * 0.021, 0, zc), Vector3(0.062, 0.03, 0.046), gold_d, Vector3(0, 0, 90), 20)
		b.add("sphere", Vector3(sx * 0.02, 0, zc), Vector3(0.022, 0.052, 0.037), Color(0.68, 0.06, 0.07), Vector3.ZERO, 16)
		b.add("sphere", Vector3(sx * 0.027, 0.004, zc + 0.003), Vector3(0.012, 0.03, 0.022), Color(0.9, 0.22, 0.2), Vector3.ZERO, 12)
		b.add("sphere", Vector3(sx * 0.0305, 0.012, zc + 0.01), Vector3(0.004, 0.008, 0.007), Color(1.0, 0.9, 0.88), Vector3.ZERO, 8)


static func _ellipse(ry: float, rz: float, zc: float, n: int) -> PackedVector2Array:
	var o := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		o.append(Vector2(cos(a) * ry, zc + sin(a) * rz))
	return o


## Sap: iki başlı burgulu kahve sargı (yuvarlak kesit, sarmal sırtlar), siper altında altın bilezik, dipte uzun altın topuz
static func _grip(b: MB, gold: Color, gold_d: Color) -> void:
	var brown = Color(0.36, 0.25, 0.16)
	var z0 := -0.17
	var z1 := 0.012
	var secs := []
	var zs := []
	var ns := 28
	for s in ns + 1:
		var z := lerpf(z0, z1, float(s) / ns)
		var sec := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			var r := 0.0175 + 0.0026 * pow(maxf(0.0, cos(2.0 * a - (z - z0) * 95.0)), 2.0)
			sec.append(Vector2(cos(a) * r, sin(a) * r * 1.08))
		secs.append(sec)
		zs.append(z)
	BL.loft(b, secs, zs, [brown], false, true, true)
	# altın bilezik (siper altı) ve dip bileziği
	for p in [[0.018, 0.024, 0.0215], [-0.168, 0.012, 0.021]]:
		BL.loft(b, [BL.oval(p[2] * 0.92, p[2] * 0.98, 18), BL.oval(p[2], p[2] * 1.06, 18), BL.oval(p[2], p[2] * 1.06, 18), BL.oval(p[2] * 0.92, p[2] * 0.98, 18)],
			[p[0] - p[1] * 0.5, p[0] - p[1] * 0.3, p[0] + p[1] * 0.3, p[0] + p[1] * 0.5], [gold], false, true, true)
	# topuz: uzun yumurta biçimi altın topuz (ref: sapın ucunda uzunca altın baş), ortasında ince bant
	var tsecs := []
	var tzs := []
	for k in 11:
		var t := k / 10.0
		var r := 0.023 * sin(lerpf(0.35, PI, t)) + 0.004
		tsecs.append(BL.oval(r, r, 16))
		tzs.append(lerpf(-0.175, -0.245, t))
	BL.loft(b, tsecs, tzs, [gold], false, true, true)
	b.add("cyl", Vector3(0, 0, -0.205), Vector3(0.05, 0.004, 0.05), gold_d, Vector3(90, 0, 0), 16)


static func _form(who: Node3D, long_b: bool) -> void:
	var n = Yk.node_of(who, ID)
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("naitosodo_uzun" if long_b else ID)
		Sfx.play("clink", who.global_position + Vector3.UP * 1.2, 1.5 if long_b else 1.2, 0.45)


static func _set_len(who: Node3D, delay: float, long_b: bool) -> void:
	Yk.after(who, delay, _form.bind(who, long_b))


## Geniş chakra kesiği: art arda üç ince yay, sıra sıra vurur
static func _wave(who: Node3D, dmg: float) -> void:
	var f = Yk.face(who)
	var side = f.cross(Vector3.UP).normalized()
	var c = who.global_position + Vector3.UP * 1.15
	var done: Array = []
	var m = Yk.mat("naito_wave", WAVE_SH)
	for s in 3:
		var r = 4.0 + s * 1.5
		var pts = []
		for k in 21:
			var a = lerpf(-1.05, 1.05, k / 20.0)
			pts.append(c + (f * cos(a) + side * sin(a)) * r + Vector3.UP * (a * -0.55 + s * 0.14))
		Yk.fade(Yk.strip(pts, 0.34 - s * 0.05, m, 0.0), 0.08 + s * 0.04, 0.26)
	for k in 7:
		var a = lerpf(-1.0, 1.0, k / 6.0)
		for r in [3.2, 5.6]:
			var hits = Combat.hit_sphere(who, c + (f * cos(a) + side * sin(a)) * r, 1.5, {"dmg": dmg * 1.5, "knock": 9.0, "kind": "heavy", "hitstop": 0.08, "melee": true}, done)
			done.append_array(hits)
	Sfx.play("chakra", c, 0.8, 0.8)
	Sfx.play("swing_sword", c, 0.7, 1.0)
	Yk.shake(who, 0.4)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	if i == 0:
		_form(who, false)
	elif i == 2:
		_set_len(who, 0.2, true)
	elif i == 4:
		_set_len(who, 0.05, false)
	elif i == 5:
		_set_len(who, 0.25, true)
		_set_len(who, 1.2, false)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i == 4:
		Sfx.play("hit_heavy", who.global_position + Vector3.UP * 1.4, 1.3, 0.6)
	elif i == 5:
		if Yk.pay(who, COST):
			_wave(who, dmg)
		else:
			var f = Yk.face(who)
			Combat.hit_sphere(who, who.global_position + Vector3.UP * 1.1 + f * 1.9, 1.7, {"dmg": dmg * 1.1, "knock": 7.0, "kind": "heavy", "hitstop": 0.07, "melee": true})
