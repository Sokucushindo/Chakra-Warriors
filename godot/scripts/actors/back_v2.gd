extends RefCounted
## Yeniden yapılan sırt / bel eşyaları. Burada kaydı olan tür eski modelin ve hazır modelin yerine geçer.
const PARTS := [preload("res://scripts/actors/back_v2_a.gd"), preload("res://scripts/actors/back_v2_b.gd"), preload("res://scripts/actors/back_v2_c.gd")]


static func has(kind) -> bool:
	if kind == null:
		return false
	for p in PARTS:
		if String(kind) in p.KINDS:
			return true
	return false


static func build(m, kind, bc: Color, ch: Vector3, hip: Vector3, toon: Material) -> bool:
	if kind == null:
		return false
	for p in PARTS:
		if String(kind) in p.KINDS:
			return p.build(m, String(kind), bc, ch, hip, toon)
	return false
