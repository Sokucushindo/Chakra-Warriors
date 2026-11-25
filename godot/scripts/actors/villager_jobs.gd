extends RefCounted
## (VillagerJobs: villager.gd ve village_life.gd içinde preload sabiti)
## İş yapan köy halkı (2026-11-25, kullanıcı: "köylüler cansız; tarla süren, iş yapan yok; hastanenin çevresinde tıbbi
## ninjalar, ANBU binasının çevresinde ANBU'lar gezinsin"). Villager rolü "job"; işin türü Villager.job, durumu Villager.jd.
## Yerler builder kayıtlarından (VillageLife.sites: farm, hospital, anbu, police, messenger, drill, dojo, sweep, fish) gelir;
## hareketler oyunun gerçek klipleri (Farm_PlantSeed / Farm_Harvest / Farm_Watering / Walk_Carry / throw / jab ...) ve
## MissionWork'ün iş pozları (çapa, süpürge) + aynı IK çözücüsüyle elle tutulan aletler (sepet, sandık, parşömen, olta, sedye).
## Uzaktaki (55 m+) işçi poz / alet güncellemez; Villager zaten 65 m ötesinde animasyonu durdurur.

const NEAR := 55.0

## iş -> kişi türü (görünüş, ad, sözler)
const KIND := {"hoe": "farmer", "harvest": "farmer", "water": "farmer", "plant": "farmer", "basket": "farmer",
	"heal": "medic", "supply": "medic", "stretcher": "medic", "chart": "medic",
	"anbu_guard": "anbu", "anbu_patrol": "anbu", "anbu_strike": "anbu", "anbu_throw": "anbu",
	"police_guard": "police", "police_patrol": "police", "messenger": "messenger",
	"drill_throw": "student", "drill_strike": "student", "drill_teacher": "teacher",
	"dojo_strike": "hyuga", "sweep": "shopkeep", "fish": "fisher"}
const ARCH := {"farmer": "farmer", "medic": "medic", "anbu": "anbu", "police": "chunin", "messenger": "chunin", "student": "student",
	"teacher": "chunin", "hyuga": "chunin", "shopkeep": "merchant", "fisher": "farmer"}
const DISPLAY := {"farmer": "Çiftçi", "medic": "Iryō-nin", "anbu": "ANBU", "police": "Keimu Butai", "messenger": "Haberci Chūnin",
	"student": "Akademi Öğrencisi", "teacher": "Akademi Hocası", "hyuga": "Hyūga", "shopkeep": "Dükkâncı", "fisher": "Balıkçı"}
const LINES := {
	"farmer": ["Yağmur geç kaldı bu yıl, toprak susuz.", "Pirinç fideleri sıra sıra dikilir, acele edersen eğri olur.", "Ninjalar köyü korur, biz de karnını doyururuz.",
		"Şu sırayı bitirince öğle yemeği!"],
	"medic": ["Hastanede yatak kalmadı, görevler zorlaştı.", "Yaraların varsa içeri gel, hemen bakalım.", "Tıbbi ninjutsu chakra kontrolü ister.",
		"Bugün üç ekip yaralı döndü..."],
	"anbu": ["...", "Burada durma. Yoluna devam et.", "Karargâha yetkisiz giriş yok."],
	"police": ["Konoha Askerî Polis Birliği. Köyde kavga çıkarma.", "Bir şey gördüysen bize bildir.", "Suçlular bu kapıdan geçemez."],
	"messenger": ["Acele mesaj! Hokage'ye götürüyorum.", "Sınır karakolundan rapor geldi.", "Yolumdan çekil, geç kalıyorum!"],
	"student": ["Bu sefer tam ortaya atacağım!", "Sensei bakıyor, dikkat!", "Bileğim ağrıdı ama devam!"],
	"teacher": ["Bileğini kullan, kolunu değil!", "Nefesini tut, sonra bırak!", "Güzel! Bir daha!"],
	"hyuga": ["Jūken: chakra noktalarına tam isabet.", "Duruşun bozuk. Ayaklarını yerleştir.", "Hyūga'nın gücü disiplinden gelir."],
	"shopkeep": ["Dükkânın önü temiz olmalı, müşteri öyle gelir.", "Buyurun, içeri bakın!", "Sabah süpürmeden kapı açılmaz."],
	"fisher": ["Bugün balıklar ısırmıyor...", "Sabır, sabır. Nehir her şeyi verir.", "Akşama ızgara balık!"],
}
const CALLS := {
	"farmer": ["Hah!", "Bir sıra daha...", "Ooof, belim..."],
	"medic": ["Sedye geliyor, açılın!", "Yaralı var!", "Malzemeler geldi!"],
	"anbu": [],
	"police": ["Devriye!", "Her şey yolunda."],
	"messenger": ["Acele mesaj!", "Yol verin!"],
	"student": ["Hıyaa!", "Tuttu!", "Iska..."],
	"teacher": ["Bileğini kullan!", "Odaklan!", "Güzel!"],
	"hyuga": ["Hah!", "Jūken!"],
	"shopkeep": [],
	"fisher": ["Vurdu! Vurdu!", "Kaçtı..."],
}
const PATIENT_LINES := ["Görevde kolumu incittim...", "Tıbbi ninjalar mucize yaratıyor.", "Yarın yine göreve çıkabilecek miyim?"]


static func kind_of(v) -> String:
	return String(KIND.get(v.job, "farmer"))


static func arch(v) -> String:
	return String(ARCH.get(kind_of(v), "civ"))


## Rol kalıbı (Villager.plan_look içinde): ad, yaş, hız
static func base_look(v, lk: Dictionary) -> void:
	var k = kind_of(v)
	v.display = String(DISPLAY.get(k, "Köylü"))
	lk["age"] = "adult"
	match k:
		"student":
			lk["age"] = "child"
		"medic", "messenger":
			lk["age"] = ["young", "adult", "adult"].pick_random()
		"farmer", "fisher", "shopkeep":
			lk["age"] = "adult"
			lk["beard"] = lk.get("gender", "m") == "m" and randf() < 0.3
	v.speed = 5.6 if v.job == "messenger" else 2.0


## Kıyafetten sonra son dokunuş (Outfits arketipinin üstüne): tür üniforması, hasır şapka, klan görünüşü
static func finish_look(v, lk: Dictionary) -> Dictionary:
	var k = kind_of(v)
	var vid = Outfits.village_near()
	match k:
		"farmer", "fisher":
			if randf() < 0.85:
				lk["head_style"] = "kasa"; lk["headgear"] = Color(0.78, 0.66, 0.42)
			if k == "farmer" and v.job == "plant":
				lk["pants_style"] = "kapri"   # pirinç tarlasında paçalar sıvalı
		"anbu", "police", "messenger", "teacher", "hyuga":
			lk["years"] = randf_range(19.0, 38.0)
			lk["fat"] = randf_range(-0.4, 0.0)
			lk["mus"] = randf_range(0.4, 0.8)
	if k == "police" and vid == "konoha":
		# Konoha Askerî Polisi: kanonda Uchiha klanının birliği; üniforma kanon tür seti (Outfits.TYPE_WEAR ile aynı)
		var fem = randf() < 0.3
		var cl: Dictionary = ClanWorld.clan_look("uchiha", "chunin", "konoha", fem, "adult")
		cl["years"] = lk["years"]; cl["fat"] = lk["fat"]; cl["mus"] = lk["mus"]
		lk = Outfits.wear_set(cl, "set_keimu") if Outfits._fits("set_keimu", fem) else cl
		v.display = "Keimu Butai"
	elif k == "hyuga":
		var fem2 = randf() < 0.4
		lk = ClanWorld.clan_look("hyuga", "chunin", vid, fem2, ["adult", "young", "teen"].pick_random())
		lk["years"] = randf_range(14.0, 36.0)
		v.display = ClanWorld.person_name("hyuga", fem2)
	return lk


# ====================================================================== kare
static func tick(v, dt: float, dist: float) -> void:
	var jd: Dictionary = v.jd
	if v.wait > 0.0:
		# konuşuyor / sana tepki veriyor: iş bırakılır, yüzü sana döner (talk() animasyonu oynatır)
		v.wait -= dt
		_unpose(v)
		v.step_move(v._sep() * 1.2, dt, false)
		if v.lantern == null:
			_hide_props(v)
		return
	if jd.get("lantern", false) and v.night and v.lantern == null:
		v._hold_lantern()
	var near = dist < NEAR
	_calls(v, dt, dist)
	match v.job:
		"hoe":
			_hoe(v, dt, near)
		"harvest", "water", "plant":
			_row_anim(v, dt, near)
		"basket", "supply":
			_carry_loop(v, dt, near, "basket" if v.job == "basket" else "crate")
		"heal":
			_stand(v, dt)
			v._cycle(dt, ["cast", "cast", "interact", "talk"], 3.0)
		"chart":
			_chart(v, dt, near)
		"stretcher":
			_stretcher(v, dt, near)
		"anbu_guard", "police_guard":
			_stand(v, dt)
			if v.night and v.lantern != null:
				v.model.play("b/Idle_Lantern", 0.3)
			else:
				v._cycle(dt, ["idle", "fold", "idle", "fold"], 6.0)
		"anbu_patrol", "police_patrol":
			_patrol(v, dt)
		"anbu_strike", "drill_strike", "dojo_strike":
			_strike(v, dt, dist)
		"anbu_throw", "drill_throw":
			_throw(v, dt, near)
		"drill_teacher":
			_pace(v, dt)
		"messenger":
			_carry_loop(v, dt, near, "scroll")
		"sweep":
			_sweep(v, dt, near)
		"fish":
			_fish(v, dt, near)
		_:
			_stand(v, dt)
			v.model.play("idle", 0.3)


static func _calls(v, dt: float, dist: float) -> void:
	v.call_cd -= dt
	if v.call_cd > 0.0:
		return
	v.call_cd = randf_range(9.0, 18.0)
	var c: Array = CALLS.get(kind_of(v), [])
	if dist < 25.0 and not c.is_empty() and randf() < 0.6:
		v.say(String(c.pick_random()), 2.0, false)


static func _stand(v, dt: float) -> void:
	v.step_move(Vector3.ZERO, dt, false)
	v._hold_face(dt)


## İki nokta arasında yürü (yerinde değilse). true: vardı
static func _walk_to(v, q: Vector3, dt: float, spd: float, anim := "walk", aspd := 1.0) -> bool:
	var to = q - v.global_position
	to.y = 0.0
	if to.length() < 0.6:
		return true
	var dir = NpcNav.steer(v, to.normalized(), dt)
	v.step_move(dir * spd + v._sep() * 1.2, dt)
	v.model.play(anim, 0.2, aspd)
	if NpcNav.stuck(v, q, dt):
		# takıldı (arada bir şey var): hedefe doğrudan konar — kimse duvara yürüyüp kalmasın
		if v.global_position.distance_to(Game.player.global_position) > 25.0:
			v.global_position = Vector3(q.x, Game.ground_height(q.x, q.z), q.z)
		NpcNav.reset(v)
		return true
	return false


# ====================================================================== tarla
## Satır boyunca: v ekseni (satır yönü), u ekseni (satırlar arası). jd: c, u, v, w, d, row, dir, s (satırdaki yer)
static func _row_pt(jd: Dictionary) -> Vector3:
	var c: Vector3 = jd["c"]
	var p = c + (jd["u"] as Vector3) * float(jd["row"]) + (jd["v"] as Vector3) * float(jd["s"])
	p.y = Game.ground_height(p.x, p.z)
	return p


static func _row_next(jd: Dictionary, step: float) -> void:
	var hv = float(jd["d"]) * 0.5 - 1.0
	var s = float(jd["s"]) + step * float(jd["dir"])
	if absf(s) > hv:
		# satır bitti: yandaki satıra geç, geri dön
		jd["dir"] = -float(jd["dir"])
		s = clampf(s, -hv, hv)
		var hu = float(jd["w"]) * 0.5 - 1.0
		var r = float(jd["row"]) + float(jd.get("rstep", 1.1))
		if absf(r) > hu:
			jd["rstep"] = -float(jd.get("rstep", 1.1))
			r = clampf(r, -hu, hu)
		jd["row"] = r
	jd["s"] = s


static func _row_face(v) -> float:
	var d: Vector3 = (v.jd["v"] as Vector3) * float(v.jd["dir"])
	return atan2(-d.x, -d.z)


## Çapalama: MissionWork'ün çapa pozu (iki elle kaldır, toprağa vur, çek) birkaç vuruş; sonra satırda bir adım ilerle
static func _hoe(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	var st = String(jd.get("st", "go"))
	if st == "go":
		_unpose(v)
		if _walk_to(v, _row_pt(jd), dt, 1.3):
			jd["st"] = "work"
			jd["t"] = randf_range(6.0, 11.0)
			v.stand_face = _row_face(v)
		return
	_stand(v, dt)
	if near:
		_busy(v, "hoe")
	else:
		_unpose(v)
		v.model.play("idle", 0.3)
	jd["t"] = float(jd["t"]) - dt
	if float(jd["t"]) <= 0.0:
		_row_next(jd, 2.2)
		jd["st"] = "go"


## Klipli tarla işleri: pirinç fidesi dikme (geri geri), hasat, sulama (kova / emzikli kova elde)
static func _row_anim(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	var st = String(jd.get("st", "go"))
	var clip = {"plant": "b/Farm_PlantSeed", "harvest": "b/Farm_Harvest", "water": "b/Farm_Watering"}[v.job]
	if v.job == "water" and near:
		_hand_prop(v, "can", "RightHand")
	if st == "go":
		var q = _row_pt(jd)
		if v.job == "plant" and v.global_position.distance_to(q) < 2.0:
			# pirinç dikilirken geriye adım atılır (dikilen fideye basılmaz): yüz satırın tersine, geri geri
			var to = q - v.global_position
			to.y = 0.0
			if to.length() > 0.2:
				v.step_move(to.normalized() * 0.9, dt, false)
				v._hold_face(dt)
				v.model.play("walk", 0.2, -0.55)
				return
		elif not _walk_to(v, q, dt, 1.3):
			return
		jd["st"] = "work"
		jd["n"] = int(jd.get("n", 0)) + 1
		v.stand_face = _row_face(v) + (PI if v.job == "plant" else 0.0)
		var A: Animation = v.model.anim.get_animation(clip) if v.model.anim.has_animation(clip) else null
		jd["t"] = (A.length if A != null else 2.4) + randf_range(0.0, 0.6)
		v.model.play(clip, 0.25, 1.0, true)
		if v.job == "harvest" and int(jd["n"]) % 6 == 0 and jd.has("edge"):
			jd["st"] = "drop"   # kucağı doldu: tarla kenarındaki sepete boşalt
		return
	if st == "drop":
		if _walk_to(v, jd["edge"], dt, 1.4):
			jd["st"] = "put"
			jd["t"] = 1.6
			v.model.play("pickup", 0.2, 1.0, true)
		return
	_stand(v, dt)
	jd["t"] = float(jd["t"]) - dt
	if float(jd["t"]) <= 0.0:
		_row_next(jd, 0.8 if v.job == "plant" else 1.3)
		jd["st"] = "go"


## Taşıma döngüsü: iki nokta arasında (sepet / sağlık sandığı iki elde, parşömen tek elde); uçlarda bırakır / alır
static func _carry_loop(v, dt: float, near: bool, item: String) -> void:
	var jd: Dictionary = v.jd
	var pts: Array = jd["pts"]
	var i = int(jd.get("i", 0))
	if float(jd.get("t", 0.0)) > 0.0:
		jd["t"] = float(jd["t"]) - dt
		_stand(v, dt)
		if item == "scroll":
			v._cycle(dt, ["interact", "yes", "talk"], 1.4)
		_hide_props(v)
		return
	var run = item == "scroll"
	var arrived = _walk_to(v, pts[i], dt, v.speed if run else 1.5, "run" if run else "b/Walk_Carry", 1.0)
	if near:
		if item == "scroll":
			_hand_prop(v, "scroll", "RightHand")
		else:
			_two_hand_prop(v, item)
	if arrived:
		jd["i"] = (i + 1) % pts.size()
		jd["t"] = randf_range(2.0, 4.0)
		v.stand_face = v.facing
		if item != "scroll":
			v.model.play("pickup", 0.2, 1.0, true)


# ====================================================================== hastane
## Hasta kâğıdı: sol elde pano, sağ el yazar; arada kapının önünde birkaç adım
static func _chart(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	if jd.has("to"):
		_unpose(v)
		if near:
			_hand_prop(v, "clipboard", "LeftHand")
		if _walk_to(v, jd["to"], dt, 1.2):
			jd.erase("to")
			jd["t"] = randf_range(10.0, 18.0)
			v.stand_face = float(jd.get("face0", v.facing)) + randf_range(-0.6, 0.6)
		return
	_stand(v, dt)
	v.model.play("idle", 0.3)
	if near:
		var mw = MissionWork.I()
		var fd = mw._fd(v)
		var right = fd.cross(Vector3.UP).normalized()
		var sc: float = v.model.age_scale
		var t = Time.get_ticks_msec() * 0.001
		var board = v.global_position + Vector3.UP * 1.08 * sc + fd * 0.3 - right * 0.04
		var pen = board + right * (0.05 + sin(t * 5.0) * 0.04) + fd * 0.03 + Vector3.UP * (0.02 + sin(t * 2.3) * 0.03)
		var arms = mw._ik(v, "Left", board - right * 0.08)
		arms.append_array(mw._ik(v, "Right", pen))
		_cast(v, {"arms": arms, "fL": ScenePoser.GRIP, "fR": ScenePoser.HALF, "spine": 4.0, "neck": 24.0})
		var cb = _prop(v, "clipboard")
		cb.visible = true
		cb.global_transform = Transform3D(Basis(Vector3.UP, v.facing) * Basis(Vector3.RIGHT, deg_to_rad(-55.0)), board + right * 0.03)
	jd["t"] = float(jd.get("t", 8.0)) - dt
	if float(jd["t"]) <= 0.0:
		var home: Vector3 = v.home
		jd["to"] = home + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-2.0, 2.0))


## Sedye: önde ve arkada iki tıbbi ninja; giderken boş (katlı battaniye), dönerken üstünde örtülü yaralı.
## Lider kapı <-> bahçe kapısı arasında yürür, eş 2.3 m arkasından gelir; sedye iki kişinin elleri arasında durur.
static func _stretcher(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	var mate = jd.get("mate")
	var lead: bool = jd.get("lead", false)
	if not lead:
		if not is_instance_valid(mate) or mate.fading or mate.job != "stretcher":
			_unpose(v)
			_stand(v, dt)
			v.model.play("idle", 0.3)
			return
		var mfd = Vector3(-sin(mate.facing), 0, -cos(mate.facing))
		var want = mate.global_position - mfd * 2.3
		var to = want - v.global_position
		to.y = 0.0
		if to.length() > 0.15:
			v.step_move(to.normalized() * minf(1.9, to.length() * 3.0), dt, false)
		else:
			v.step_move(Vector3.ZERO, dt, false)
		var look = mate.global_position - v.global_position
		look.y = 0.0
		if look.length() > 0.3:
			v.facing = lerp_angle(v.facing, atan2(-look.x, -look.z), minf(1.0, dt * 6.0))
			v.model.rotation.y = v.facing
		v.model.play("walk" if to.length() > 0.2 or mate.velocity.length() > 0.3 else "idle", 0.25)
		if near:
			_stretch_arms(v, false)
		return
	var pts: Array = jd["pts"]
	var i = int(jd.get("i", 0))
	if float(jd.get("t", 0.0)) > 0.0:
		jd["t"] = float(jd["t"]) - dt
		_stand(v, dt)
		v.model.play("idle", 0.3)
	elif _walk_to(v, pts[i], dt, 1.25):
		jd["i"] = (i + 1) % pts.size()
		jd["t"] = randf_range(3.0, 5.0)
		jd["loaded"] = i == 1   # bahçe kapısından (1) yaralıyla döner
		v.stand_face = v.facing
	if near:
		_stretch_arms(v, true)
		if is_instance_valid(mate) and mate.job == "stretcher":
			var sp = _prop(v, "stretcher_load" if jd.get("loaded", false) else "stretcher")
			_prop(v, "stretcher" if jd.get("loaded", false) else "stretcher_load").visible = false
			var mw = MissionWork.I()
			var a = (mw._hand(v, "Left") + mw._hand(v, "Right")) * 0.5
			var b = (mw._hand(mate, "Left") + mw._hand(mate, "Right")) * 0.5
			var mid = (a + b) * 0.5
			var dirv = (a - b)
			if dirv.length() > 0.5:
				sp.visible = true
				var z = dirv.normalized()
				var x = Vector3.UP.cross(z).normalized()
				sp.global_transform = Transform3D(Basis(x, z.cross(x), z), mid + Vector3.DOWN * 0.04)
	else:
		_hide_props(v)


static func _stretch_arms(v, front: bool) -> void:
	var mw = MissionWork.I()
	var fd = mw._fd(v)
	var right = fd.cross(Vector3.UP).normalized()
	var sc: float = v.model.age_scale
	var base = v.global_position + Vector3.UP * 0.8 * sc
	var off = -fd * 0.12 if front else fd * 0.4
	var arms = mw._ik(v, "Left", base - right * 0.3 + off)
	arms.append_array(mw._ik(v, "Right", base + right * 0.3 + off))
	_cast(v, {"arms": arms, "fL": ScenePoser.GRIP, "fR": ScenePoser.GRIP, "spine": 4.0 if front else 8.0, "neck": 0.0})


# ====================================================================== nöbet / devriye / antrenman
## Devriye: noktalar arasında yürür, köşelerde durup çevreyi kollar; eşli devriyede eş yanından yürür
static func _patrol(v, dt: float) -> void:
	var jd: Dictionary = v.jd
	var mate = jd.get("mate")
	if not jd.get("lead", true) and is_instance_valid(mate) and not mate.fading and mate.job == v.job:
		var mfd = Vector3(-sin(mate.facing), 0, -cos(mate.facing))
		var mr = mfd.cross(Vector3.UP).normalized()
		var want = mate.global_position + mr * 1.2 - mfd * 0.3
		var to = want - v.global_position
		to.y = 0.0
		if to.length() > 0.3:
			v.step_move(NpcNav.steer(v, to.normalized(), dt) * minf(2.6, to.length() * 2.0), dt)
			v.model.play("walk", 0.2)
		else:
			v.step_move(Vector3.ZERO, dt, false)
			v.facing = lerp_angle(v.facing, mate.facing + sin(Time.get_ticks_msec() * 0.0009 + 1.0) * 0.6, minf(1.0, dt * 3.0))
			v.model.rotation.y = v.facing
			v.model.play("idle", 0.3)
		return
	if not jd.has("pts"):
		_stand(v, dt)   # eşi gitti: yerinde nöbet tutar
		v._cycle(dt, ["idle", "fold"], 5.0)
		return
	var pts: Array = jd["pts"]
	var i = int(jd.get("i", 0))
	if float(jd.get("t", 0.0)) > 0.0:
		jd["t"] = float(jd["t"]) - dt
		v.step_move(Vector3.ZERO, dt, false)
		# köşede çevreyi kollar: sağa sola bakar
		v.facing = lerp_angle(v.facing, v.stand_face + sin(float(jd["t"]) * 1.3) * 0.9, minf(1.0, dt * 3.0))
		v.model.rotation.y = v.facing
		v.model.play("idle", 0.3)
		return
	if _walk_to(v, pts[i], dt, 1.9):
		jd["i"] = (i + 1) % pts.size()
		jd["t"] = randf_range(2.0, 4.5)
		v.stand_face = v.facing


## Kütüğe / direğe vuruş antrenmanı (ANBU avlusu, Akademi kütükleri, Hyūga dōjō'su)
static func _strike(v, dt: float, dist: float) -> void:
	var jd: Dictionary = v.jd
	_stand(v, dt)
	if v.kick_t > 0.0:
		v.kick_t -= dt
		if v.kick_t <= 0.0:
			v.model.overlay.set_pose("kick", 0.0)
	v.anim_t -= dt
	if v.anim_t > 0.0:
		return
	jd["n"] = int(jd.get("n", 0)) + 1
	if int(jd["n"]) % 9 == 0:
		v.anim_t = randf_range(2.0, 3.5)   # soluklanma
		v.model.play("idle", 0.3)
		return
	v.anim_t = randf_range(0.6, 1.1)
	var hy = v.job == "dojo_strike"
	var k = randi() % 5
	if k < 4:
		var anims = ["jab", "cross", "push", "jab"] if hy else ["jab", "cross", "hook", "cross"]
		v.model.play(anims[k], 0.05, 1.25, true)
	elif not hy:
		v.model.overlay.set_pose("kick", 1.0)
		v.kick_t = 0.35
	else:
		v.model.play("cross", 0.05, 1.4, true)
	if dist < 22.0:
		Sfx.play("punch", v.global_position, randf_range(0.8, 1.0), 0.25)


## Hedef tahtasına kunai / shuriken atışı: atış klibi, el kalkınca kunai tahtaya uçar ve saplanır (birkaç saniye kalır)
static func _throw(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	_stand(v, dt)
	v.anim_t -= dt
	if jd.has("fly"):
		var f: Dictionary = jd["fly"]
		f["t"] = float(f["t"]) + dt
		var m: Node3D = f["m"]
		if is_instance_valid(m):
			if float(f["t"]) < 0.0:
				m.visible = false
			else:
				var k = clampf(float(f["t"]) / 0.28, 0.0, 1.0)
				var a: Vector3 = f["a"]
				var b: Vector3 = f["b"]
				m.visible = true
				var p = a.lerp(b, k) + Vector3.UP * sin(k * PI) * 0.15
				if k < 1.0:
					m.look_at(b, Vector3.UP)
					m.rotate_object_local(Vector3.UP, PI)
					m.global_position = p
				elif not f.get("hit", false):
					f["hit"] = true
					m.global_position = b
					if v.global_position.distance_to(Game.player.global_position) < 25.0:
						Sfx.play("kunai", b, randf_range(1.1, 1.3), 0.3)
				if float(f["t"]) > 3.0:
					m.visible = false
					jd.erase("fly")
		else:
			jd.erase("fly")
	if v.anim_t > 0.0:
		return
	v.anim_t = randf_range(2.0, 3.2)
	v.model.play("throw", 0.1, 1.0, true)
	if near and not jd.has("fly"):
		var tg: Vector3 = jd["target"]
		var m2 = _prop(v, "kunai")
		var h = MissionWork.I()._hand(v, "Right") if v.model.skel else v.global_position + Vector3.UP * 1.4
		jd["fly"] = {"m": m2, "t": -0.32, "a": h + Vector3.UP * 0.25, "b": tg + Vector3(randf_range(-0.35, 0.35), randf_range(-0.3, 0.3), 0.0)}


## Hoca: öğrencilerin arkasında bir uçtan öbür uca yürür, durur, izler, düzeltir
static func _pace(v, dt: float) -> void:
	var jd: Dictionary = v.jd
	var pts: Array = jd["pts"]
	var i = int(jd.get("i", 0))
	if float(jd.get("t", 0.0)) > 0.0:
		jd["t"] = float(jd["t"]) - dt
		_stand(v, dt)
		v._cycle(dt, ["fold", "talk", "yes", "fold", "idle"], 3.0)
		return
	if _walk_to(v, pts[i], dt, 1.1):
		jd["i"] = (i + 1) % pts.size()
		jd["t"] = randf_range(5.0, 9.0)


## Dükkân önünü süpürme (MissionWork süpürge pozu); arada yanına bir adım
static func _sweep(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	if jd.has("to"):
		_unpose(v)
		if _walk_to(v, jd["to"], dt, 1.0):
			jd.erase("to")
			jd["t"] = randf_range(8.0, 14.0)
			v.stand_face = v.facing
		return
	_stand(v, dt)
	if near:
		_busy(v, "sweep")
	else:
		v.model.play("idle", 0.3)
	jd["t"] = float(jd.get("t", 10.0)) - dt
	if float(jd["t"]) <= 0.0:
		var home: Vector3 = v.home
		jd["to"] = home + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-1.2, 1.2))


## Nehir kıyısında olta: iki el oltada, misina suya iner; arada balık vurur (olta kalkar)
static func _fish(v, dt: float, near: bool) -> void:
	var jd: Dictionary = v.jd
	_stand(v, dt)
	v.model.play("idle", 0.3)
	if not near:
		_unpose(v)
		_hide_props(v)
		return
	jd["t"] = float(jd.get("t", randf_range(15.0, 30.0))) - dt
	var bite = 0.0
	if float(jd["t"]) < 1.6:
		bite = sin(clampf(float(jd["t"]) / 1.6, 0.0, 1.0) * PI)
		if float(jd["t"]) <= 0.0:
			jd["t"] = randf_range(18.0, 40.0)
			if randf() < 0.4 and v.global_position.distance_to(Game.player.global_position) < 20.0:
				v.say(String(CALLS["fisher"].pick_random()), 2.0, false)
	var mw = MissionWork.I()
	var fd = mw._fd(v)
	var right = fd.cross(Vector3.UP).normalized()
	var sc: float = v.model.age_scale
	var tt = Time.get_ticks_msec() * 0.001
	var butt = v.global_position + Vector3.UP * 0.92 * sc + fd * 0.18 + right * 0.1
	var rdir = (fd * (0.8 - 0.35 * bite) + Vector3.UP * (0.5 + 0.6 * bite) + right * 0.05).normalized()
	rdir = (rdir + Vector3.UP * sin(tt * 1.7) * 0.02).normalized()
	var arms = mw._ik(v, "Right", butt + rdir * 0.05)
	arms.append_array(mw._ik(v, "Left", butt + rdir * 0.42))
	_cast(v, {"arms": arms, "fL": ScenePoser.GRIP, "fR": ScenePoser.GRIP, "spine": 6.0, "neck": 14.0})
	var rod = _prop(v, "rod")
	rod.visible = true
	mw._aim(rod, butt, butt + rdir)
	var tip = butt + rdir * 2.6
	var wy: float = float(jd.get("water_y", v.global_position.y - 0.4))
	var bob = tip + fd * 0.6
	bob.y = wy + sin(tt * 2.1) * 0.03 - 0.15 * bite
	var ln = _prop(v, "line")
	ln.visible = true
	var L = tip.distance_to(bob)
	mw._aim(ln, tip, bob)
	ln.scale = Vector3(1, 1, maxf(0.05, L))


# ====================================================================== poz + alet yardımcıları
static func _busy(v, kind: String) -> void:
	if String(v.jd.get("busy", "")) == kind:
		return
	_unpose(v)
	MissionWork.I().busy(v, kind)
	v.jd["busy"] = kind


static func _cast(v, cp: Dictionary) -> void:
	if String(v.jd.get("busy", "")) != "":
		MissionWork.I().stop_busy(v)
		v.jd["busy"] = ""
	v.model.overlay.cast_pose = cp
	v.model.overlay.set_pose("cast", 1.0)
	v.jd["cp"] = true


static func _unpose(v) -> void:
	if String(v.jd.get("busy", "")) != "":
		if is_instance_valid(MissionWork.inst):
			MissionWork.inst.stop_busy(v)
		v.jd["busy"] = ""
	if v.jd.get("cp", false):
		v.jd["cp"] = false
		v.model.overlay.set_pose("cast", 0.0)
		v.model.overlay.cast_pose = {}


static func _hide_props(v, keep := "") -> void:
	for k in v.jd.get("props", {}):
		var m = v.jd["props"][k]
		if k != keep and is_instance_valid(m):
			m.visible = false


## Kişi sahneden çıkarken (Villager._exit_tree): poz ve aletler bırakılır
static func release(v) -> void:
	if v.jd.is_empty():
		return
	_unpose(v)
	for m in v.jd.get("props", {}).values():
		if is_instance_valid(m):
			m.queue_free()
	v.jd["props"] = {}


## İş bitti (akşam / gece vardiyası): aletini bırakır, en yakın kapıya yürüyüp "eve girer"
static func leave(v, door: Vector3) -> void:
	release(v)
	v.jd = {}
	v.job = ""
	v.role = "walker"
	v.going_home = true
	v.goal = door
	v.wait = 0.0
	NpcNav.reset(v)


## Tek elde taşınan (parşömen, kova, pano): el kemiğine oturur, gövdenin yönünde durur
static func _hand_prop(v, name: String, bone: String) -> void:
	_hide_props(v, name)
	var m = _prop(v, name)
	var sk: Skeleton3D = v.model.skel
	var bi = sk.find_bone(bone) if sk else -1
	if bi < 0:
		m.visible = false
		return
	var hx: Transform3D = sk.global_transform * sk.get_bone_global_pose(bi)
	var sc: float = v.model.age_scale
	var grip = hx.origin + hx.basis.y.normalized() * 0.07 * sc
	m.visible = true
	m.global_transform = Transform3D(Basis(Vector3.UP, v.facing).scaled(Vector3.ONE * sc), grip)


## İki elle önde taşınan (sepet, sandık): iki elin ortasında
static func _two_hand_prop(v, name: String) -> void:
	_hide_props(v, name)
	var m = _prop(v, name)
	var mw = MissionWork.I()
	var mid = (mw._hand(v, "Left") + mw._hand(v, "Right")) * 0.5
	var sc: float = v.model.age_scale
	m.visible = true
	m.global_transform = Transform3D(Basis(Vector3.UP, v.facing).scaled(Vector3.ONE * sc), mid + Vector3.DOWN * 0.06 * sc)


static var _meshes := {}


static func _prop(v, name: String) -> MeshInstance3D:
	if not v.jd.has("props"):
		v.jd["props"] = {}
	var have = v.jd["props"].get(name)
	if is_instance_valid(have):
		return have
	var m = MeshInstance3D.new()
	m.mesh = _mesh(name)
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if name in ["line", "kunai", "scroll", "clipboard"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	m.visible = false
	v.add_child(m)
	v.jd["props"][name] = m
	return m


## Aletler (parçalar +z boyunca uzanır; taşınanlar gövdenin önünde, -z ileri)
static func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var b = MB.new()
	var wood = Color(0.55, 0.4, 0.24)
	match name:
		"basket":   # hasır sepet, içinde sebze
			b.add("cyl", Vector3(0, 0.0, -0.08), Vector3(0.48, 0.28, 0.48), Color(0.72, 0.58, 0.32), Vector3.ZERO, 12)
			b.add("torus", Vector3(0, 0.14, -0.08), Vector3(0.5, 0.3, 0.5), Color(0.55, 0.42, 0.22), Vector3.ZERO, 12)
			for k in 7:
				var a = k * TAU / 7.0
				var gr = [Color(0.4, 0.62, 0.25), Color(0.85, 0.45, 0.15), Color(0.55, 0.7, 0.3)][k % 3]
				b.add("sphere", Vector3(cos(a) * 0.12, 0.16, -0.08 + sin(a) * 0.12), Vector3(0.14, 0.12, 0.14), gr, Vector3.ZERO, 8)
		"crate":    # sağlık malzemesi sandığı: açık ahşap, beyaz bez, kırmızı artı
			b.add("box", Vector3(0, 0.0, -0.1), Vector3(0.5, 0.3, 0.36), Color(0.82, 0.72, 0.55))
			b.add("box", Vector3(0, 0.16, -0.1), Vector3(0.46, 0.03, 0.32), Color(0.95, 0.95, 0.93))
			for sz in [-1.0, 1.0]:
				b.add("box", Vector3(0, 0.0, -0.1 + sz * 0.182), Vector3(0.16, 0.05, 0.01), Color(0.82, 0.15, 0.12))
				b.add("box", Vector3(0, 0.0, -0.1 + sz * 0.182), Vector3(0.05, 0.16, 0.01), Color(0.82, 0.15, 0.12))
		"scroll":
			b.add("cyl", Vector3(0, 0, -0.04), Vector3(0.075, 0.34, 0.075), Color(0.92, 0.86, 0.68), Vector3(0, 0, 90), 8)
			for sx in [-1.0, 1.0]:
				b.add("cyl", Vector3(sx * 0.18, 0, -0.04), Vector3(0.09, 0.03, 0.09), Color(0.45, 0.14, 0.1), Vector3(0, 0, 90), 8)
		"can":      # ahşap kova (emzikli): elden sarkar
			b.add("cyl", Vector3(0, -0.2, -0.02), Vector3(0.26, 0.26, 0.26), wood, Vector3.ZERO, 10)
			b.add("torus", Vector3(0, -0.12, -0.02), Vector3(0.27, 0.3, 0.27), Color(0.3, 0.3, 0.32), Vector3.ZERO, 10)
			b.add("torus", Vector3(0, -0.03, -0.02), Vector3(0.22, 0.22, 0.22), Color(0.3, 0.3, 0.32), Vector3(0, 90, 90), 10)
			b.add("cyl", Vector3(0, -0.22, -0.24), Vector3(0.04, 0.3, 0.04), wood.darkened(0.15), Vector3(-55, 0, 0), 6)
		"clipboard":
			b.add("box", Vector3.ZERO, Vector3(0.24, 0.012, 0.32), Color(0.5, 0.36, 0.22))
			b.add("box", Vector3(0, 0.008, 0.01), Vector3(0.2, 0.006, 0.26), Color(0.97, 0.96, 0.92))
			b.add("box", Vector3(0, 0.012, -0.13), Vector3(0.08, 0.016, 0.03), Color(0.6, 0.6, 0.62))
		"stretcher", "stretcher_load":   # sedye: iki sırık + bez; yüklüde örtülü yaralı
			for sx in [-1.0, 1.0]:
				b.add("cyl", Vector3(sx * 0.3, 0, 0), Vector3(0.04, 2.5, 0.04), wood, Vector3(90, 0, 0), 6)
			b.add("box", Vector3(0, -0.01, 0), Vector3(0.58, 0.02, 1.8), Color(0.86, 0.84, 0.76))
			if name == "stretcher":
				b.add("box", Vector3(0, 0.04, 0.55), Vector3(0.5, 0.07, 0.4), Color(0.55, 0.62, 0.75))
			else:
				b.add("sphere", Vector3(0, 0.11, -0.1), Vector3(0.4, 0.22, 1.5), Color(0.55, 0.62, 0.75), Vector3.ZERO, 12)
				b.add("sphere", Vector3(0, 0.12, 0.74), Vector3(0.2, 0.18, 0.22), Color(0.93, 0.78, 0.64), Vector3.ZERO, 10)
		"rod":
			b.add("cyl", Vector3(0, 0, 1.3), Vector3(0.025, 2.6, 0.025), Color(0.62, 0.55, 0.3), Vector3(90, 0, 0), 5)
			b.add("cyl", Vector3(0, 0, 0.12), Vector3(0.04, 0.24, 0.04), Color(0.3, 0.2, 0.12), Vector3(90, 0, 0), 6)
		"line":
			b.add("box", Vector3(0, 0, 0.5), Vector3(0.006, 0.006, 1.0), Color(0.9, 0.9, 0.88))
		"kunai":
			b.add("cyl", Vector3(0, 0, -0.06), Vector3(0.02, 0.1, 0.02), Color(0.2, 0.2, 0.22), Vector3(90, 0, 0), 6)
			b.add("torus", Vector3(0, 0, -0.13), Vector3(0.05, 0.05, 0.05), Color(0.3, 0.3, 0.32), Vector3(90, 0, 0), 6)
			b.add("cone", Vector3(0, 0, 0.06), Vector3(0.05, 0.16, 0.014), Color(0.55, 0.57, 0.6), Vector3(90, 0, 0), 4)
		"plank":    # kereste: kucakta enine üç tahta
			for k in 3:
				b.add("box", Vector3(0, 0.02 + k * 0.055, -0.05), Vector3(1.5, 0.05, 0.16), Color(0.7, 0.55, 0.34).darkened(k * 0.06))
	var mesh = b.build(Props.toon())
	_meshes[name] = mesh
	return mesh


## İnşaat taşıyıcısı (Villager._work): yürürken kucağında kereste
static func carry_plank(v, on: bool) -> void:
	if on and v.global_position.distance_to(Game.player.global_position) < NEAR:
		_two_hand_prop(v, "plank")
	else:
		_hide_props(v)
