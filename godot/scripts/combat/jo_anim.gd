extends RefCounted
## Jō (kısa sopa; Iwabee Yuino): Bō kombosunu kullanır, daha kısa ve daha hızlıdır (EKSIK.md kararı). Kendi hareketi yok.

const B = preload("res://scripts/combat/bo_anim.gd")


static func steps() -> Array:
	return B.steps()
