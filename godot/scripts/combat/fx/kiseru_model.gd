extends RefCounted
## Hōmatsu Kiseru modeli (Utakata'nın kabarcık borusu). Ref: refs/anime/full/utakata/Utakata_full_png.jpg (yakın kesit
## _tmp/wref/uta_pipe.png). Ref özellikleri (boy 1.78 m ölçeğiyle): ince açık bej bambu boru (çap ~1 cm), ağızlıkta kalınca halka;
## ağızdan ~19 cm düz iner, çift halkalı eklemde ~35° aşağı kırılır, ~10 cm ikinci parça, ucunda küçük pirinç çanak (çap ~3.5 cm).
## Eklemden ince kahve ip sarkar (iki beyaz boncuk) — ip CharacterModel'de Dangle şeridi olarak bağlanır.
## Toplam ~0.36 m (ref ~0.32; ağızlık-yumruk aralığı üfleme pozundan geldiği için ilk parça ~4 cm uzun). Tutuş z 0: ağızlık z -0.205
## (üfleme pozu bu noktaya göre tarandı, kiseru_anim), eklem z +0.03 (yumruğun hemen önü).
## Kırılma yönü +Y (elde +Y aşağı bakar).

const BL = preload("res://scripts/actors/blade_loft.gd")

const Z_MOUTH := -0.205
const Z_JOINT := 0.03
const BEND := 35.0
const SEG2 := 0.085
const R := 0.0055

## Çanın ağız merkezi (kabarcıklar buradan çıkar) — model uzayında
static func bell() -> Vector3:
	return _seg2_xf() * Vector3(0, 0, SEG2 + 0.036)


static func _seg2_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-BEND)), Vector3(0, 0, Z_JOINT))


static func build(b: MB) -> void:
	var tan = Color(0.86, 0.78, 0.56)
	var node_c = Color(0.7, 0.6, 0.38)
	var brass = Color(0.78, 0.64, 0.32)
	# 1. parça: ağızlık -> eklem
	_tube(b, Z_MOUTH + 0.008, Z_JOINT, R, tan, Transform3D.IDENTITY)
	for z in [Z_MOUTH + 0.075, Z_MOUTH + 0.14]:
		_ring(b, z, R * 1.28, 0.007, node_c, Transform3D.IDENTITY)     # bambu boğumları
	# ağızlık: kalınca kısa halka, ucu açık
	_tube(b, Z_MOUTH, Z_MOUTH + 0.016, R * 1.35, tan.lightened(0.08), Transform3D.IDENTITY)
	b.add("cyl", Vector3(0, 0, Z_MOUTH - 0.0005), Vector3(R * 1.3, 0.001, R * 1.3), Color(0.25, 0.18, 0.12), Vector3(90, 0, 0), 12)
	# eklem: çift halka + küre topuz (kırılma noktasını örter)
	_ring(b, Z_JOINT - 0.012, R * 1.4, 0.008, node_c, Transform3D.IDENTITY)
	b.add("sphere", Vector3(0, 0, Z_JOINT), Vector3(R * 2.7, R * 2.7, R * 2.7), node_c, Vector3.ZERO, 12)
	var x2 := _seg2_xf()
	_ring(b, 0.012, R * 1.4, 0.008, node_c, x2)
	# 2. parça: eklem -> çanak
	_tube(b, 0.0, SEG2, R * 0.95, tan, x2)
	_ring(b, SEG2 * 0.55, R * 1.25, 0.006, node_c, x2)
	# çanak: pirinç boyun + açılan kupa, içi koyu
	var secs := []
	var zs := []
	var prof := [[SEG2 - 0.004, 0.006], [SEG2 + 0.006, 0.0068], [SEG2 + 0.012, 0.0085], [SEG2 + 0.02, 0.012], [SEG2 + 0.028, 0.0155], [SEG2 + 0.034, 0.0175], [SEG2 + 0.037, 0.0178]]
	for p in prof:
		secs.append(BL.oval(p[1], p[1], 16))
		zs.append(p[0])
	BL.loft(b, secs, zs, [brass], false, true, false, x2)
	b.add_xf("cyl", x2 * Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.033, 0.002, 0.033)), Vector3(0, 0, SEG2 + 0.034)), Color(0.28, 0.2, 0.12), 16)   # kupa içi
	b.add_xf("torus", x2 * Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.037, 0.03, 0.037)), Vector3(0, 0, SEG2 + 0.037)), brass.lightened(0.1), 16)   # kupa dudağı
	# ip bağı (eklemin altında küçük düğüm; sarkan ip Dangle)
	b.add("sphere", Vector3(0, R * 2.2, Z_JOINT + 0.002), Vector3(0.006, 0.006, 0.006), Color(0.42, 0.24, 0.12), Vector3.ZERO, 8)


static func _tube(b: MB, z0: float, z1: float, r: float, col: Color, xf: Transform3D) -> void:
	BL.loft(b, [BL.oval(r, r, 12), BL.oval(r, r, 12)], [z0, z1], [col], false, true, true, xf)


static func _ring(b: MB, z: float, r: float, h: float, col: Color, xf: Transform3D) -> void:
	BL.loft(b, [BL.oval(r * 0.92, r * 0.92, 12), BL.oval(r, r, 12), BL.oval(r, r, 12), BL.oval(r * 0.92, r * 0.92, 12)], [z - h * 0.5, z - h * 0.3, z + h * 0.3, z + h * 0.5], [col], false, true, true, xf)
