class_name WeaponRig
extends SkeletonModifier3D
## Silah eli: silah tutan elin parmaklarını kabzanın etrafında yumruk yapar; kın çekme/sokma hareketinde kolu kına uzatır.
## PoseOverlay'den SONRA çalışır (açık avuç pozları silahlı elde yumruğa döner).

const FINGERS := ["Index", "Middle", "Ring", "Little"]
const FINGER_SEG := ["Proximal", "Intermediate", "Distal"]
const CURL := [1.25, 1.45, 0.9]   # parmak bölümü başına kıvrım (rad): tam kavrayış

var hold := {"Left": 0.0, "Right": 0.0}       # hedef: o elde silah var mı (0/1)
var _hold_w := {"Left": 0.0, "Right": 0.0}
var reach_side := "Right"
var reach_arms: Array = []    # [[kemik, model-uzayı yön], ...] kına uzanma pozu
var reach_w := 0.0            # 0..1 (CharacterModel kın animasyonunda sürer)
var two_hand_node: Node3D = null   # iki elle tutuş: sol el bu silahın sapına (kabzadan two_hand_off m ileride) uzanır
var two_hand_off := 0.32
var two_hand_w := 0.0
var left_holder := Basis.IDENTITY   # sol el tutuş çerçevesi (el kemiği uzayında)
var left_roll := 0.0
var mirror_axis := 0
static var left_single_sign := -1.0   # tek elli sol tutuş: +1 parmakları geriye büküyordu (yakın çekimle doğrulandı)
var left_curl_sign := -1.0   # ön izlemede onaylanan (alt sıra)   # sol elin kabza ekseni etrafında dönüşü (derece)   # sol el sağ elle aynı yönde kabzayı sarar (test: öndeki yumruk kabzanın etrafında)
var left_grip_pos := Vector3.ZERO   # sol el tutuş noktası (el kemiği uzayında)
var reach_open := false       # true: kol uzanırken el açık kalır (Rasengan / Chidori avucu), yumruk yapmaz
static var AX := Vector3(-1, 0, 0)   # VRoid parmak kıvrım ekseni (kemik yerel -X)


## Ön kol kilidi (tonfa): taraf -> [mesh'in el kemiğine göre basis'i, mesh uzayında dirseğe giden gövde ekseni].
## Her karede el kemiği döndürülür ki gövde ön kol boyunca dirseğe uzansın (bilek bükülse de tonfa koldan ayrılmaz).
var forearm_lock := {}


func _forearm_lock(sk: Skeleton3D) -> void:
	for side in forearm_lock:
		if float(hold.get(side, 0.0)) <= 0.0:
			continue
		var hb = _fb(sk, side + "Hand")
		var lb = _fb(sk, side + "LowerArm")
		if hb < 0 or lb < 0:
			continue
		var hp: Transform3D = sk.get_bone_global_pose(hb)
		var to_elbow: Vector3 = sk.get_bone_global_pose(lb).origin - hp.origin
		if to_elbow.length() < 0.01:
			continue
		var e: Array = forearm_lock[side]
		var axis: Vector3 = (hp.basis * (e[0] as Basis) * (e[1] as Vector3)).normalized()
		var want = to_elbow.normalized()
		if axis.dot(want) > 0.9999:
			continue
		var q = Quaternion(axis, want)
		var par = sk.get_bone_parent(hb)
		var parb: Basis = sk.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(hb, (parb.inverse() * (Basis(q) * hp.basis)).get_rotation_quaternion())


func _process_modification() -> void:
	var sk = get_skeleton()
	if sk == null:
		return
	if sk != _tg_sk:
		_tg.clear()
		_tg_sk = sk
	var dt = get_process_delta_time()
	if not forearm_lock.is_empty():
		_forearm_lock(sk)
	if reach_w > 0.0:
		for a in reach_arms:
			_rot_model(sk, a[0], a[1], reach_w)
	if two_hand_w > 0.0 and two_hand_node and is_instance_valid(two_hand_node):
		_two_hand_ik(sk, two_hand_w)
	for side in hold:
		var tgt: float = hold[side]
		if side == "Left" and two_hand_w > 0.0:
			tgt = maxf(tgt, two_hand_w)
		if reach_w > 0.0 and side == reach_side and not reach_open:
			tgt = maxf(tgt, reach_w)
		_hold_w[side] = move_toward(_hold_w[side], tgt, dt * 8.0)
		var w: float = _hold_w[side]
		if w <= 0.0:
			if relax_free:
				_relax_hand(sk, side)
			continue
		var sgn = 1.0 if side == "Left" else -1.0
		if side == "Left" and two_hand_w > 0.0:
			sgn *= left_curl_sign   # iki elle tutuşta sol el aynalandığı için kıvrım yönü
		elif side == "Left":
			sgn *= left_single_sign   # tek elle sol tutuş (çift silahın sol eli)
		# başparmak kabzanın üstüne kapanır
		# başparmak kabzayı sarar, parmakların üstüne kapanır (eskiden kabza boyunca dik havada duruyordu)
		var th = Vector3(0.3 * sgn, 0.6 * sgn, 0.6 * sgn)
		var tds = sgn
		if side == "Left" and two_hand_w > 0.0:
			# iki elli tutuşta SOL BAŞPARMAK (kullanıcı istedi): aynalanmış elde dört parmağın işaret çevirmesi başparmağı
			# dışarı kaldırıyordu -> başparmak sol elin kendi sarma yönüyle kabzaya kapanır
			th = LEFT_TWO_THUMB[left_thumb_mode]
			tds = 1.0 if left_thumb_mode != 0 else sgn
		# hedefler (dinlenme dönüşü * sabit kıvrım) önbellekten: her karede 14 kemik adı / dönüş yeniden kurulmasın (sonuç aynı)
		var key := [side, sgn, th, tds]
		var lst = _tg.get(key)
		if lst == null:
			lst = []
			for f in FINGERS:
				for i in 3:
					_tg_add(sk, lst, side + f + FINGER_SEG[i], Quaternion(AX, CURL[i] * sgn), 1.0)
			_tg_add(sk, lst, side + "ThumbProximal", Quaternion.from_euler(th), 1.0)
			_tg_add(sk, lst, side + "ThumbDistal", Quaternion.from_euler(Vector3(0.5 * tds, 0, 0)), 1.0)
			_tg[key] = lst
		_tg_apply(sk, lst, w)


static var LEFT_TWO_THUMB := [Vector3(-0.3, -0.6, -0.6), Vector3(0.3, 0.6, 0.6), Vector3(-0.3, 0.6, 0.6), Vector3(0.3, -0.6, -0.6)]
static var left_thumb_mode := 1
var relax_meta := Vector3(0.6, -0.3, 0.0)   # boş el başparmağı içe kıvrık (dışa kanca gibi çıkmaz)
var relax_dist := 0.4
var relax_meta_r := Vector3(-0.6, -0.3, 0.0)   # sağ (silah) eli boşken başparmak içe kıvrık
var relax_thumb := Vector3.ZERO
var relax_free := true   # boştaki el: animasyonun zikzak başparmağı yerine rahat, hafif kıvrık el
var ov = null            # PoseOverlay: elde yumruk / mühür / sahne pozu varsa rahat kıvrım uygulanmaz
## Boş elin rahat kıvrımı (kemik dinlenme açısından mutlak, radyan): işaretten serçeye doğru artan, doğal yarı açık el.
## Animasyonun yapışık parmaklı şekilsiz eldiven duruşu yerine (kullanıcı 2026-11-23: "eller garip duruyor").
const RELAX_CURL := [[0.22, 0.32, 0.18], [0.32, 0.42, 0.22], [0.42, 0.5, 0.26], [0.52, 0.55, 0.3]]
const RELAX_SPREAD := [0.05, 0.0, -0.04, -0.09]


## Boştaki el rahat duruş: parmaklar hafif kıvrık, başparmak işaret parmağının yanında düz-hafif kıvrık (zikzak yok)
func _relax_hand(sk: Skeleton3D, side: String) -> void:
	# boştaki el animasyonun orijinal hâlinde kalır; YALNIZ zikzak başparmak düzeltilir (işaret parmağının yanına yatık)
	var sgn = 1.0 if side == "Left" else -1.0
	var free := _hand_free(side)
	var rm = relax_meta if side == "Left" else relax_meta_r
	# hedefler önbellekten (aynı sonuç; her karede 15 kemik adı + dönüş kurulmuyordu)
	var key := [side, free, rm, relax_thumb, relax_dist]
	var lst = _tg.get(key)
	if lst == null:
		lst = []
		if free:
			var segs := ["Proximal", "Intermediate", "Distal"]
			var fins := ["Index", "Middle", "Ring", "Little"]
			for i in 4:
				for s in 3:
					var q := Quaternion(Vector3.RIGHT, float(RELAX_CURL[i][s]))
					if s == 0:
						q = Quaternion(Vector3.FORWARD, float(RELAX_SPREAD[i]) * sgn) * q
					_tg_add(sk, lst, side + String(fins[i]) + String(segs[s]), q, 0.9)
		if rm != Vector3.ZERO:
			_tg_add(sk, lst, side + "ThumbMetacarpal", Quaternion.from_euler(Vector3(rm.x * sgn, rm.y * sgn, rm.z * sgn)), 1.0)
		_tg_add(sk, lst, side + "ThumbProximal", Quaternion.from_euler(Vector3(relax_thumb.x * sgn, relax_thumb.y * sgn, relax_thumb.z * sgn)), 1.0)
		_tg_add(sk, lst, side + "ThumbDistal", Quaternion.from_euler(Vector3(relax_dist * sgn, 0, 0)), 1.0)
		_tg[key] = lst
	_tg_apply(sk, lst, 1.0)


## Parmak hedef önbelleği: anahtar -> [[kemik no, hedef dönüş (dinlenme * kıvrım), ağırlık çarpanı], ...]
var _tg := {}
var _tg_sk: Skeleton3D = null


func _tg_add(sk: Skeleton3D, lst: Array, bone: String, q: Quaternion, wk: float) -> void:
	var bi = _fb(sk, bone)
	if bi >= 0:
		lst.append([bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * q, wk])


func _tg_apply(sk: Skeleton3D, lst: Array, w: float) -> void:
	for e in lst:
		var bi: int = e[0]
		sk.set_bone_pose_rotation(bi, sk.get_bone_pose_rotation(bi).slerp(e[1], clampf(w * float(e[2]), 0.0, 1.0)))


## Elde başka bir poz yok mu (yumruk, mühür, sahne / kombo el pozu, iki elle tutuş): yalnız o zaman rahat kıvrım
func _hand_free(side: String) -> bool:
	if ov == null or not is_instance_valid(ov):
		return false
	if absf(float(ov.fist.get(side, 0.0))) > 0.01:
		return false
	for pn in ["cast", "seal", "guard", "kick"]:
		if float(ov.weights.get(pn, 0.0)) > 0.02:
			return false
	if ov.key_t >= 0.0 and not ov.key_anim.is_empty():
		return false
	if two_hand_w > 0.0 or (reach_w > 0.0 and side == reach_side):
		return false
	return true


## İki kemikli IK: sol omuz-dirsek-el zinciri, silah sapındaki hedefe uzanır (dirsek aşağı-dışa)
func _two_hand_ik(sk: Skeleton3D, w: float) -> void:
	# sol el = sağ elin kabza düzlemine göre AYNA kopyası (aynı şekil, kabzanın karşı tarafından sarar), kabza boyunca biraz aşağıda.
	# Parmaklar sağ eldekiyle aynı kıvrımda (hold Left); kol IK ile bileği oraya taşır.
	var ua = _fb(sk, "LeftUpperArm")
	var la = _fb(sk, "LeftLowerArm")
	var hb = _fb(sk, "LeftHand")
	var rb = _fb(sk, "RightHand")
	if ua < 0 or la < 0 or hb < 0 or rb < 0:
		return
	var inv = sk.global_transform.affine_inverse()
	var wx: Transform3D = two_hand_node.global_transform
	var axis: Vector3 = (sk.global_transform.basis.orthonormalized().inverse() * wx.basis.z).normalized()
	var p0: Vector3 = inv * wx.origin
	var rp: Transform3D = sk.get_bone_global_pose(rb)
	var nx = Vector3.RIGHT - axis * axis.dot(Vector3.RIGHT)
	if nx.length() < 0.05:
		nx = Vector3.FORWARD
	nx = nx.normalized()
	var R = Basis(Vector3.RIGHT - 2.0 * nx * nx.x, Vector3.UP - 2.0 * nx * nx.y, Vector3.BACK - 2.0 * nx * nx.z)
	var D = [Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)), Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))][mirror_axis]
	var want_hand: Basis = (R * rp.basis.orthonormalized() * D).orthonormalized()
	var tgt: Vector3 = p0 + R * (rp.origin - p0) + axis * two_hand_off
	# yinelemeli IK: kemik eksen sapmaları yüzünden el hedefin ~6 cm yanına düşüyordu -> hatayı hedefe ekleyip 4 kez düzelt
	var aim = tgt
	for it in 4:
		_arm_ik(sk, ua, la, aim, w)
		var err = tgt - sk.get_bone_global_pose(hb).origin
		if err.length() < 0.004:
			break
		aim += err
	var par = sk.get_bone_parent(hb)
	var pbas: Basis = sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(hb, sk.get_bone_pose_rotation(hb).slerp((pbas.inverse() * want_hand).get_rotation_quaternion(), clampf(w, 0.0, 1.0)))


func _arm_ik(sk: Skeleton3D, ua: int, la: int, tgt: Vector3, w: float) -> void:
	var S = sk.get_bone_global_pose(ua).origin
	var E = sk.get_bone_global_pose(la).origin
	var hb = _fb(sk, "LeftHand")
	var H = sk.get_bone_global_pose(hb).origin
	var a = S.distance_to(E)
	var b = E.distance_to(H)
	var d = tgt - S
	var dist = clampf(d.length(), 0.05, a + b - 0.002)
	var dn = d.normalized()
	var pole = Vector3(0.4, -1.0, -0.3).normalized()
	var perp = (pole - dn * pole.dot(dn))
	if perp.length() < 0.01:
		perp = Vector3.DOWN
	perp = perp.normalized()
	var cos_a = clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var elbow = S + (dn * cos_a + perp * sqrt(1.0 - cos_a * cos_a)) * a
	_rot_model(sk, "LeftUpperArm", elbow - S, w)
	var E2 = sk.get_bone_global_pose(la).origin
	_rot_model(sk, "LeftLowerArm", (S + dn * dist) - E2, w)


## Parmağı dinlenme pozuna göre verilen kıvrıma (mutlak) yaklaştır: animasyondaki açık el ne olursa olsun kapanır
func _curl(sk: Skeleton3D, bone: String, q: Quaternion, w: float) -> void:
	var bi = _fb(sk, bone)
	if bi < 0:
		return
	var target = sk.get_bone_rest(bi).basis.get_rotation_quaternion() * q
	sk.set_bone_pose_rotation(bi, sk.get_bone_pose_rotation(bi).slerp(target, clampf(w, 0.0, 1.0)))


## Kemiği model uzayında verilen yöne çevir (PoseOverlay._rot_model ile aynı)
func _rot_model(sk: Skeleton3D, bone: String, dir_model: Vector3, w: float) -> void:
	var bi = _fb(sk, bone)
	if bi < 0:
		return
	var gp = sk.get_bone_global_pose(bi)
	var q = Quaternion(gp.basis.y.normalized(), dir_model.normalized())
	var parent = sk.get_bone_parent(bi)
	var parent_basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local = (parent_basis.inverse() * (Basis(q) * gp.basis)).get_rotation_quaternion()
	sk.set_bone_pose_rotation(bi, sk.get_bone_pose_rotation(bi).slerp(local, clampf(w, 0.0, 1.0)))

## Kemik numarası önbelleği: kemik adıyla arama (dize -> StringName -> karma) her karakterde her kare onlarca kez yapılıyordu
var _fb_c := {}
var _fb_sk: Skeleton3D = null

func _fb(sk: Skeleton3D, bone: String) -> int:
	if sk != _fb_sk:
		_fb_c.clear()
		_fb_sk = sk
	var v = _fb_c.get(bone)
	if v == null:
		v = sk.find_bone(bone)
		_fb_c[bone] = v
	return v
