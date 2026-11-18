extends RefCounted
## Shodai Hokage no Kubikazari (初代火影の首飾り; hedef: res://scripts/combat/fx/shodai_kubikazari_fx.gd). Kanon: İlk Hokage'nin kristal kolyesi; kuyruklu canavarları yakalama ve denetleme gücünü artırır. Yamato mühür ekleyip Naruto'yu dizginlemek için kullanır, altı kuyrukta kırılır.
## Mekanik (Senju / Mokuton şartı oyun uyarlaması): Senju soyu ya da Mokuton sahibi takarsa kuyruklu canavar daha erken diz çöker ve daha uzun çökük kalır. Başkasında yalnız süs. Parayla satılmaz: Senju'ya aile yadigârı. Görünüş: siyah ip, iki inci, uzun altıgen yeşil kristal (ref).

const BACK_ID := "shodai_kubikazari"
const SUBDUE := 0.2      # canavarın normal 0.08 eşiği yerine
const HOLD_X := 1.6


static func model(mb: MB) -> void:
	var cord = Color(0.06, 0.06, 0.07)
	var gem = Color(0.3, 0.72, 0.72)
	var dk = Color(0.08, 0.36, 0.43)
	var pearl = Color(0.84, 0.86, 0.9)
	for k in 18:
		var a = lerpf(-1.75, 1.75, k / 17.0)
		mb.add("box", Vector3(sin(a) * 0.135, 0.035 + 0.085 * (1.0 - cos(a)), cos(a) * 0.11), Vector3(0.05, 0.005, 0.005), cord, Vector3(0, rad_to_deg(a), 0))
	mb.add("cyl", Vector3(0, -0.015, 0.128), Vector3(0.03, 0.095, 0.018), gem, Vector3.ZERO, 6)
	mb.add("box", Vector3(0.004, -0.015, 0.133), Vector3(0.006, 0.08, 0.004), pearl)
	mb.add("cyl", Vector3(-0.007, -0.02, 0.121), Vector3(0.026, 0.09, 0.014), dk, Vector3.ZERO, 6)
	mb.add("cone", Vector3(0, -0.075, 0.128), Vector3(0.03, 0.026, 0.018), gem, Vector3(180, 0, 0), 6)
	for s in [-1.0, 1.0]:
		mb.add("sphere", Vector3(0.05 * s, 0.042, 0.104), Vector3.ONE * 0.014, pearl, Vector3.ZERO, 6)


## Oyuncu takıyor ve kolye ona karşılık veriyor mu?
static func active() -> bool:
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.get("model") == null:
		return false
	if str(p.model.look.get("back_item", "")) != BACK_ID:
		return false
	return str(Game.profile.get("clan", "")) == "senju" or Progress.has_nature("mokuton")


## TailedBeast: diz çökme eşiği
static func subdue_at(base: float) -> float:
	return maxf(base, SUBDUE) if active() else base


static func hold_mult() -> float:
	return HOLD_X if active() else 1.0
