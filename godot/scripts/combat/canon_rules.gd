class_name CanonRules
extends RefCounted
## Animedeki kullanım şartları (oyuncu + düşman aynı). "" = atılabilir, değilse sebep.
##  - Hiraishin ışınlanmaları: hedef senin işaretinle işaretli olmalı ya da yakında işaretli kunain olmalı (Minato: shiki işareti)
##  - Kirin: gökte fırtına bulutu — yağmur/fırtına ya da son 25 sn'de Katon ile ısıtılmış gök (Sasuke: Gōryūka ile bulut)
##  - Büyük Suiton: 30 m içinde su (göl/deniz/nehir) ya da yağmur; yoksa suyu chakradan üretir — yarı güç (Hoshigaki klanı muaf)

const HIRA_TP := ["hiraishin_no_jutsu", "hiraishingiri", "hiraishin_ni_no_dan", "hiraishin_ranbu", "hiraishin_rasengan", "hiraishin_dorai"]
const STORM := ["kirin"]
const WATER := ["suiton_dogo_tatsumaki", "suiton_daibakufu_no_jutsu", "suiton_daibakuryu", "suiton_haran_bansho", "suiton_suijinheki", "suiton_bakusui_shoha",
	"suiton_suiryudan_no_jutsu", "suiryudan", "suiton_daikodan_no_jutsu", "raisuiryudan"]


## Yağmur/gök gürültülü fırtına (kum ya da kar fırtınası değil)
static func rainy() -> bool:
	var w = String(Game.world.env.weather) if Game.world and Game.world.get("env") else ""
	if w.contains("kum") or w.contains("kar"):
		return false
	return w.contains("yağmur") or w.contains("fırtına") or w.contains("sağanak")


static func hira_mark_ok(c: Node3D) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	var my = c.get_instance_id()
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f != c and is_instance_valid(f) and not f.is_dead() and f.has_meta("hiraishin_by") and int(f.get_meta("hiraishin_by")) == my \
				and f.has_method("has_status") and f.has_status("marked") and f.global_position.distance_to(c.global_position) < 60.0:
			return true
	for m in c.get_meta("hira_marks", []):
		if m is Dictionary and Game.now() < float(m["until"]) and (m["pos"] as Vector3).distance_to(c.global_position) < 60.0:
			return true
	return false


static func storm_ok(c: Node3D) -> bool:
	if rainy():
		return true
	return c != null and is_instance_valid(c) and Game.now() - float(c.get_meta("katon_t", -999.0)) < 25.0


static func water_near(c: Node3D) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if rainy():
		return true
	var p = c.global_position
	for k in 13:
		var q = p if k == 0 else p + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * 30.0
		if Game.water_level(q.x, q.z) > Game.terrain_height(q.x, q.z) + 0.05:
			return true
	return false


static func hoshigaki(c: Node3D) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if c is Player:
		return String(Game.profile.get("clan", "")) == "hoshigaki"
	return c.get("arch") is Dictionary and String(c.arch.get("clan", "")) == "hoshigaki"


## Kanon silah şartı: yelpaze jutsuları elde yelpaze olmadan atılamaz (kullanıcı: "Kamaitachi yelpazesizken atılabiliyor")
const FAN := ["kamaitachi_no_jutsu", "daikamaitachi_no_jutsu", "kyodai_sensu"]   # herhangi bir savaş yelpazesi
const WEAPON_ONLY := {"kuchiyose_kirikiri_mai": ["temari_ogi"], "bashosen_kaze_no_maki": ["bashosen"], "bashosen_hi_no_maki": ["bashosen"],
	"bashosen_rai_no_maki": ["bashosen"], "bashosen_mizu_no_maki": ["bashosen"]}
const FAN_IDS := ["temari_ogi", "yelpaze", "bashosen", "gunbai"]

static func weapon_ids(c: Node3D) -> Array:
	var out = []
	if c is Player:
		for s in ["sag", "sol"]:
			var g = Gear.equipped(Game.profile, s)
			if not g.is_empty():
				out.append(String(g.get("id", "")))
	elif c != null and c.get("look") is Dictionary:
		for k in ["weapon_r", "weapon_l"]:
			if c.look.get(k) != null:
				out.append(String(c.look[k]))
	return out


## Atılabilir mi? "" = evet
static func block(c: Node3D, jid: String) -> String:
	if jid in FAN or WEAPON_ONLY.has(jid):
		var ws = weapon_ids(c)
		var need: Array = WEAPON_ONLY.get(jid, FAN_IDS)
		if not ws.any(func(w): return w in need):
			return "Elinde %s yok — bu teknik onunla savrulur." % ("Temari no Ōōgi" if need == ["temari_ogi"] else ("Bashōsen" if need == ["bashosen"] else "savaş yelpazesi"))
	if jid == "samidare_kekka" and not weapon_ids(c).any(func(w): return Gear.base_id(String(w)) == "amagasa"):
		return "Elinde Amagasa yok — iğneler şemsiyenin altından yağar."
	if jid == "shisho_tenketsu" and c != null and float(c.get("hp")) < float(c.get("max_hp")) * 0.25:
		return "Yaşam gücün yetmiyor — bu tenketsuları açarsan ölürsün."
	if jid == "rensha" and not weapon_ids(c).any(func(w): return Gear.base_id(String(w)) == "tsurukame"):
		return "Elinde Tsurukame yok — iğneler kabuğun ağızlarından çıkar."
	if jid in HIRA_TP and not hira_mark_ok(c):
		return "Işınlanacak işaret yok — önce Hiraishin kunaisi at ya da hedefe vurup işaretle."
	if jid == "chibitama_rasengan":
		var p7_msg: String = load("res://scripts/combat/fx/jutsu_p7_fx.gd").block(c, jid)
		if p7_msg != "":
			return p7_msg
	if jid in ["kagero_utakata", "saibo_kasseijutsu"]:
		var p2_msg: String = load("res://scripts/combat/fx/jutsu_p2_fx.gd").block(c, jid)
		if p2_msg != "":
			return p2_msg
	if jid == "iwa_nadare" and uphill(c) < 4.0:   # kanon: yalnız bir yamacın altında işe yarar (yamaçtan kaya çığı indirir)
		return "Yakında yukarı yamaç yok — Iwa Nadare bir dağın eteğinde yapılır."
	if jid in ["chikatsu_saisei", "saisei_kekkai", "biju_soshingeki", "tenpenchii"]:
		var p1_msg = load("res://scripts/combat/fx/jutsu_p1_fx.gd").gate(c, jid)
		if p1_msg != "":
			return p1_msg
	if jid in STORM and not storm_ok(c):
		return "Gökte fırtına bulutu yok — önce Katon ile göğü ısıt ya da fırtınayı bekle."
	return ""


## Hasar çarpanı (atılabilen ama şartı eksik): su kaynağı yoksa büyük Suiton yarı güç
static func dmg_mult(c: Node3D, jid: String) -> float:
	if jid in WATER and not hoshigaki(c) and not water_near(c):
		return 0.5
	return 1.0

## Yamaç yüksekliği: yapanın çevresinde (25 m içinde) kendisinden en çok ne kadar yükselen zemin var (Iwa Nadare şartı)
static func uphill(c: Node3D) -> float:
	if c == null or not is_instance_valid(c):
		return 0.0
	var p = c.global_position
	var h0 = Game.terrain_height(p.x, p.z)
	var best = 0.0
	for k in 16:
		var a = k * TAU / 16.0
		for r in [10.0, 18.0, 25.0]:
			var q = p + Vector3(cos(a), 0, sin(a)) * r
			best = maxf(best, Game.terrain_height(q.x, q.z) - h0)
	return best


## Yamacın en yüksek yönü (Iwa Nadare kayaları oradan iner)
static func uphill_dir(c: Node3D) -> Vector3:
	var p = c.global_position
	var h0 = Game.terrain_height(p.x, p.z)
	var best = -999.0
	var out = Vector3.FORWARD
	for k in 16:
		var a = k * TAU / 16.0
		var q = p + Vector3(cos(a), 0, sin(a)) * 18.0
		var dh = Game.terrain_height(q.x, q.z) - h0
		if dh > best:
			best = dh
			out = Vector3(cos(a), 0, sin(a))
	return out
