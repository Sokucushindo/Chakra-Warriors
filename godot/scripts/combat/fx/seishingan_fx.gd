extends RefCounted
## Seishingan (醒心丸; hedef: res://scripts/combat/fx/seishingan_fx.gd). Kanon (Narutopedia "Mind Awakening Pill"): Orochimaru'nun ilacı; Lanetli Mührü zorla 2. aşamaya taşır,
## ama lanetin yayılmasını öyle hızlandırır ki kullanan birkaç dakikada ölür. Beden ancak Shikokumujin içinde mühürlenirse alışır: gerçek ölüm "sahte ölüm"e döner.
## Görünüş refs/seishingan: kırmızı iple bağlı, mantar kapaklı cam şişe, beyaz etiket, içinde koyu kahve haplar.
## Mekanik: yalnız Lanetli Mühür I AÇIKKEN yutulur; oyunun gerçek "Juin: Ni no Dankai"si başlar (öğrenilmemiş olsa da). Bulaşma durmadan hızlanır ve ÖLDÜRÜR.
## Kurtuluş: Fūja Hōin (lanet bastırılır) ya da Shikokumujin içine alınmak (sahte ölüm; oyuncu 2. aşamayı kalıcı öğrenir). Parayla satılmaz: Yılan yolunda Ten no Juin'i öğrenene 3 hap.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const Z = preload("res://scripts/combat/fx/zoketsugan_fx.gd")

const START_PILLS := 3
const RATE0 := 0.004      # sn başına azami canın payı
const RATE_UP := 0.0002   # her saniye artış (~80 sn'de tam can)
const STEP := 0.5
const MARK_EVERY := 15.0


static func _jar() -> Mesh:
	return Yk.mesh("seishin_sise", func():
		var b = MB.new()
		var glass = Color(0.1, 0.15, 0.17)
		var cord = Color(0.42, 0.08, 0.12)
		b.add("cyl", Vector3.ZERO, Vector3(0.05, 0.075, 0.05), glass, Vector3.ZERO, 10)
		b.add("cyl", Vector3(0, -0.012, 0), Vector3(0.052, 0.046, 0.052), Color(0.22, 0.12, 0.09), Vector3.ZERO, 10)   # dipteki haplar
		b.add("cyl", Vector3(0, 0.046, 0), Vector3(0.052, 0.016, 0.052), Color(0.46, 0.3, 0.16), Vector3.ZERO, 10)
		b.add("torus", Vector3(0, 0.034, 0), Vector3(0.058, 0.05, 0.058), cord, Vector3.ZERO, 12)
		b.add("box", Vector3(0, 0, 0.026), Vector3(0.012, 0.062, 0.002), Color(0.92, 0.92, 0.9))
		return b.build(Props.toon()))


static func left() -> int:
	return int(Game.profile.get("seishingan_left", START_PILLS))


## Hap listesinde görünür mü: lanet mührünü bilen, hapı kalan oyuncu
static func available() -> bool:
	return "ten_no_juin" in (Game.profile.get("learned", []) as Array) and left() > 0


static func _suppressed(who: Node3D) -> bool:
	return who.has_meta("fuja_until") and Time.get_ticks_msec() < int(who.get_meta("fuja_until"))


static func use(who: Node3D) -> bool:
	if who is Player:
		if _suppressed(who):
			Hud.msg("Lanet mührü Fūja Hōin ile bastırılmış: hap işlemez.", Color(0.85, 0.3, 0.3))
			return false
		if Buffs.has("juin2"):
			return false
		if not Buffs.has("juin1"):
			Hud.msg("Seishingan için önce Lanetli Mühür açık olmalı.", Color(0.85, 0.55, 1.0))
			return false
		Game.profile["seishingan_left"] = left() - 1
	Z.eat(who, _jar(), func():
		_awaken(who))
	return true


static func _awaken(who: Node3D) -> void:
	var pj = PathJutsu.get_pinst()
	pj.p_juin_ni_no_dankai(who, null)   # oyunun gerçek 2. aşaması: biçim, güç, kendi can bedeli
	if not who is Player and who.has_method("add_buff"):
		who.add_buff("juin2", 18.0, {})
	if who.has_meta("seishin_on"):
		return
	who.set_meta("seishin_on", true)
	if who is Player:
		Hud.msg("Seishingan: lanet bedenini yiyor. Fūja Hōin ya da Shikokumujin olmadan ölürsün!", Color(1.0, 0.4, 0.45), 5.0)
	var s = {"t": 0.0, "acc": 0.0, "mark": MARK_EVERY}
	_tick(who, s)


static func _tick(who: Node3D, s: Dictionary) -> void:
	if not is_instance_valid(who) or who.is_dead() or not who.has_meta("seishin_on"):
		return
	if _suppressed(who):
		who.remove_meta("seishin_on")
		Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Bulaşma durdu", Color(0.85, 0.6, 0.9))
		return
	s["t"] += STEP
	var t: float = s["t"]
	var d = float(who.max_hp) * (RATE0 + RATE_UP * t) * STEP
	if float(who.hp) - d <= 1.0:
		who.remove_meta("seishin_on")
		who.take_hit({"dmg": float(who.hp) + 1.0, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "sure": true, "true_dmg": true, "pierce_guard": true})
		return
	who.hp = float(who.hp) - d
	s["mark"] += STEP
	if float(s["mark"]) >= MARK_EVERY:
		s["mark"] = 0.0
		PathJutsu.get_pinst().skin_marks(who, 5, "juin_marks", MARK_EVERY + 1.0)
	Yk.after(who, STEP, func():
		_tick(who, s))


## Shikokumujin hedefi aldığında çağrılır: bulaşan beden sahte ölüme girer, mühre alışır
static func fog_seal(t: Node3D) -> void:
	if not t.has_meta("seishin_on"):
		return
	t.remove_meta("seishin_on")
	t.hp = maxf(1.0, float(t.max_hp) * 0.05)
	if t.has_method("apply_status"):
		t.apply_status("stun", 3.0)
	Combat.popup_text(t.global_position + Vector3.UP * 2.4, "Sahte ölüm", Color(0.8, 0.7, 0.95))
	if t is Player and not "juin_ni_no_dankai" in (Game.profile.get("learned", []) as Array):
		Progress.learn("juin_ni_no_dankai")


## Düşman: lanet mührü tekniği olan ninja sıkışınca bir kez (oyuncuyla aynı bedel)
static func ai(e: Node3D) -> void:
	if e.has_meta("seishin_used") or float(e.hp) >= float(e.max_hp) * 0.45 or _suppressed(e):
		return
	var jl: Array = e.arch.get("jutsu", [])
	if not ("ten_no_juin" in jl or "juin_ni_no_dankai" in jl):
		return
	e.set_meta("seishin_used", true)
	use(e)
