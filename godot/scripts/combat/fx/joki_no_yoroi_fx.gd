extends RefCounted
## Jōki no Yoroi (蒸気の鎧; hedef: res://scripts/combat/fx/joki_no_yoroi_fx.gd). Kanon (Narutopedia "Steam Armour", Naruto 564-565): Han'ın zırhı; sırttaki ocak buhar biriktirir,
## salınan buharın basıncı fiziksel vuruşu güçlendirir; güç, salınan buharın miktarıyla orantılı. Görünüş refs/joki_no_yoroi: kızıl dilimli zırh, omuzlardan yükselen buhar.
## Sırt ocağı (yuva: sırt) basınç toplar. Her yakın dövüş vuruşu biraz boşaltır; bitiriş adımı TAMAMINI boşaltır, güç birikene orantılı.
## Futton doğası ya da Kokuō iki kat hızlı doldurur. Hasar indirimi yok. Oyuncu ve düşman aynı kod (KeyedCombos.on_strike).

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const BACK_ID := "joki_ocak"
const FILL_T := 14.0
const SPEND := 0.2
const MIN_P := 0.2
const COST := 0.012   # salım başına azami chakra payı

const JET_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = 0.5 + 0.5 * sin(UV.x * 18.0 - TIME * 16.0 + sin(UV.y * 9.0));
	float m = smoothstep(0.12 + 0.34 * UV.x * w, 0.62, v);
	ALBEDO = mix(vec3(0.72, 0.73, 0.74), vec3(0.97, 0.97, 0.96), smoothstep(0.5, 0.95, v));
	ALPHA = m * fade_k * (1.0 - UV.x * UV.x);
	if (ALPHA < 0.02) discard;
}
"""


## Sırt ocağı (BackItemsExt): yerel +Y yukarı, -Z sırttan dışarı. Han'ın ocağının sırt görünümü kaynakta yok: biçim kanon tarifinden.
static func back_model(mb: MB) -> void:
	var iron = Color(0.2, 0.19, 0.2)
	var red = Color(0.45, 0.12, 0.14)
	var brass = Color(0.55, 0.42, 0.22)
	mb.add("cyl", Vector3.ZERO, Vector3(0.26, 0.42, 0.2), iron, Vector3.ZERO, 12)
	for y in [-0.15, 0.0, 0.15]:
		mb.add("cyl", Vector3(0, y, 0), Vector3(0.275, 0.035, 0.215), red, Vector3.ZERO, 12)
	mb.add("sphere", Vector3(0, 0.21, 0), Vector3(0.26, 0.1, 0.2), iron, Vector3.ZERO, 10)
	mb.add("box", Vector3(0, -0.07, -0.105), Vector3(0.1, 0.07, 0.012), Color(0.08, 0.07, 0.07))   # ocak ağzı
	for s in [-1.0, 1.0]:   # omuzlara çıkan buhar boruları (kaynakta buhar iki omuzdan yükselir)
		mb.add("cyl", Vector3(s * 0.15, 0.28, 0.03), Vector3(0.04, 0.2, 0.04), brass, Vector3(0, 0, -s * 22.0), 8)
		mb.add("cyl", Vector3(s * 0.195, 0.385, 0.03), Vector3(0.055, 0.03, 0.055), iron, Vector3(0, 0, -s * 22.0), 8)


static func worn(who: Node3D) -> bool:
	var a = who.get("arch")
	if a is Dictionary and str(a.get("beast", "")) == "kokuo":
		return true   # kanon: zırh Kokuō'nun jinchūriki'sinin
	var m = who.get("model")
	return m != null and m.get("look") is Dictionary and str(m.look.get("back_item", "")) == BACK_ID


static func _fast(who: Node3D) -> bool:
	return Yk.nature(who, "futton") or (who is Player and str(Game.profile.get("jinchuriki", "")) == "kokuo")


static func pressure(who: Node3D) -> float:
	var now = Game.now()
	var p = float(who.get_meta("joki_p", 0.5))
	var t0 = float(who.get_meta("joki_t", now))
	p = minf(1.0, p + (now - t0) / (FILL_T * (0.5 if _fast(who) else 1.0)))
	who.set_meta("joki_p", p)
	who.set_meta("joki_t", now)
	return p


static func _jet(who: Node3D, amt: float) -> void:
	var f = Yk.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var h = Yk.height_of(who)
	var m = Yk.mat("joki_jet", JET_SH)
	for sd in [-1.0, 1.0]:
		var a: Vector3 = who.global_position + Vector3.UP * h * 0.86 - f * 0.2 + s * sd * 0.2
		var pts = []
		var L = 0.7 + 1.5 * amt
		for k in 7:
			var u = k / 6.0
			pts.append(a - f * L * u + Vector3.UP * L * 0.55 * u * u + s * sd * 0.22 * u + s * sin(u * 8.0 + sd) * 0.05)
		Yk.fade(Yk.strip(pts, 0.07 + 0.09 * amt, m, -0.8), 0.05 + 0.1 * amt, 0.2 + 0.2 * amt)


## Her yakın dövüş vuruşunda (KeyedCombos.on_strike başı). i == 5: bitiriş, tüm basınç.
static func on_melee(who: Node3D, i: int, dmg: float) -> void:
	if not worn(who):
		return
	var p = pressure(who)
	var fin = i == 5
	var use_p = p if fin else minf(p, SPEND)
	if use_p < MIN_P * (1.0 if fin else 0.5) or not Yk.pay(who, COST):
		return
	who.set_meta("joki_p", p - use_p)
	_jet(who, use_p)
	Sfx.play("wind", who.global_position, 1.5 - use_p * 0.6, 0.35 + use_p * 0.4)
	var info = {"dmg": dmg * (0.15 + 1.0 * use_p), "knock": 2.0 + 16.0 * use_p, "kind": "heavy" if use_p > 0.5 else "light", "hitstop": 0.03 + 0.05 * use_p, "melee": true}
	if use_p > 0.5:
		info["launch"] = 3.0
		Yk.shake(who, 0.15 + 0.3 * use_p)
	Combat.hit_zone(who, who.global_position, Yk.face(who), 2.7, 50.0, 2.3, info)
