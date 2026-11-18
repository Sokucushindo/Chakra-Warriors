extends RefCounted
## Hazır setlere özel 3B ayrıntılar: look["set_id"] kayıtlıysa kıyafet kurulduktan sonra çalışır
const PARTS := [preload("res://scripts/actors/set_v2_a.gd"), preload("res://scripts/actors/set_v2_b.gd"), preload("res://scripts/actors/set_v2_c.gd"), preload("res://scripts/actors/set_v2_d.gd"), preload("res://scripts/actors/set_v2_e.gd")]


static func build(m, g: Dictionary) -> void:
	var sid = m.look.get("set_id")
	if sid == null or String(sid) == "":
		return
	for p in PARTS:
		if String(sid) in p.SETS:
			p.build(m, String(sid), g)
			return
