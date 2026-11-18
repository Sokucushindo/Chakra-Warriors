extends RefCounted
## Alet yuvasından kullanılan, atılmayan eşyaların ORTAK ve görselsiz kapısı (hedef: res://scripts/combat/fx/tuketim.gd): sahiplik, bekleme, tek kullanım, kısa el pozu.

const S = preload("res://scripts/combat/samehada_anim.gd")


## true: kullanılabilir (bekleme / adet işlendi). single: envanterden bir adet düşer. busy_ok: başka eylem sürerken de olur.
static func gate(p: Node3D, id: String, cd: float, single := false, hold := 0.0, busy_ok := false) -> bool:
	var c = p.combat
	if not busy_ok and c.action != "" and c.action != "guard":
		return false
	var nm = str(Data.items.get(id, {"name": id})["name"])
	if not c.tool_owned(id):
		Hud.msg("%s sende yok." % nm, Color(1, 0.6, 0.5))
		return false
	if float(c.tool_cd.get(id, 0.0)) > 0.0:
		Hud.msg("%s hazır değil: %d sn" % [nm, ceili(float(c.tool_cd[id]))], Color(1, 0.75, 0.5))
		return false
	if cd > 0.0:
		c.tool_cd[id] = cd
	if single:
		var inv: Dictionary = Game.profile["inventory"]
		inv[id] = int(inv.get(id, 0)) - 1
	if hold > 0.0 and (c.action == "" or c.action == "guard"):
		c.action = "throw"
		c.t = 0.35 - hold
	return true


## Sol elde eşya, sol kol hedef poza gider, geri döner
static func pose(who: Node3D, item: String, l1: Dictionary, T := 0.6) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null:
		return
	var W = S.LEG_WIDE
	var r = {"RightUpperArm": Vector3(-0.25, -0.9, 0.3), "RightLowerArm": Vector3(0.1, -0.4, 0.9)}
	var l0 = {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(-0.1, -0.4, 0.9)}
	var fw = Vector3(0, 0, 1)
	m.overlay.play_keys({"len": T, "hit": T * 0.5, "keys": [S._k(0.0, 0.36, 0.0, 2.0, fw, S._a(r, l0), W), S._k(T * 0.35, 0.36, 4.0, 2.0, fw, S._a(r, l1), W),
		S._k(T * 0.72, 0.36, 4.0, 2.0, fw, S._a(r, l1), W), S._k(T, 0.36, 0.0, 2.0, fw, S._a(r, l0), W)]}, 1.0)
	if item != "" and m.has_method("hold_temp"):
		m.hold_temp(item, T * 0.8, "Left", 1.0, 0.0, false, true)
	who.get_tree().create_timer(T - 0.02).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())
