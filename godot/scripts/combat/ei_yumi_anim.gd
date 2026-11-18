extends RefCounted
## Ei Yumi (vatoz yayı; Seiren Funato): okçu duruşu oyundaki Yumi ile aynı (sol elde yay, sağ el kirişte); adımların anlamı EiYumiFX'te farklı.
## 1-2 Chakra oku, 3 Kyoku-ya (yandan dolanan ok), 4 geri sıçrayarak atış, 5 Hibiki (kiriş sesiyle tarama), 6 Goren (beş kıvrılan ok).

const A = preload("res://scripts/combat/yumi_anim.gd")


static func steps() -> Array:
	return A.steps()
