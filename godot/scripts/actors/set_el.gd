extends RefCounted
## Elle modellenmiş kıyafetler: her parça (astar, kol, pantolon, üst giysi, kuşak) o kıyafete özel kurulur.
## Beden kıyafetin altında çizilmez (iç içe geçme olmaz); ağırlıklar doğrudan kemiklere yazılır (parça kopmaz).
## +Z ön, +X karakterin solu, ölçüler bedenin gerçek ölçüsünden.
const A = preload("res://scripts/actors/set_v2_a.gd")
const SETS := ["set_shugonin"]
## Parti dosyaları: her biri DONE listesi + recipe(k, sid). Listeye giren set eski yapımın yerine geçer.
const PART_FILES := ["res://scripts/actors/set_el_a.gd", "res://scripts/actors/set_el_b.gd", "res://scripts/actors/set_el_c.gd", "res://scripts/actors/set_el_d.gd", "res://scripts/actors/set_el_e.gd", "res://scripts/actors/set_el_f.gd", "res://scripts/actors/set_el_g.gd", "res://scripts/actors/set_el_h.gd", "res://scripts/actors/set_el_i.gd", "res://scripts/actors/set_el_j.gd", "res://scripts/actors/set_el_k.gd", "res://scripts/actors/set_el_l.gd", "res://scripts/actors/set_el_m.gd", "res://scripts/actors/set_el_n.gd", "res://scripts/actors/set_el_o.gd", "res://scripts/actors/set_el_p.gd", "res://scripts/actors/set_el_q.gd", "res://scripts/actors/set_el_r.gd", "res://scripts/actors/set_el_s.gd", "res://scripts/actors/set_el_t.gd", "res://scripts/actors/set_el_u.gd", "res://scripts/actors/set_el_v.gd", "res://scripts/actors/set_el_w.gd", "res://scripts/actors/set_el_x.gd", "res://scripts/actors/set_el_y.gd", "res://scripts/actors/set_el_z.gd", "res://scripts/actors/set_el_aa.gd", "res://scripts/actors/set_el_ab.gd", "res://scripts/actors/set_el_ac.gd", "res://scripts/actors/set_el_ad.gd", "res://scripts/actors/set_el_ae.gd", "res://scripts/actors/set_el_af.gd", "res://scripts/actors/set_el_ag.gd", "res://scripts/actors/set_el_ah.gd", "res://scripts/actors/set_el_ai.gd", "res://scripts/actors/set_el_aj.gd", "res://scripts/actors/set_el_ak.gd", "res://scripts/actors/set_el_al.gd", "res://scripts/actors/set_el_am.gd", "res://scripts/actors/set_el_an.gd", "res://scripts/actors/set_el_ao.gd", "res://scripts/actors/set_el_ap.gd", "res://scripts/actors/set_el_aq.gd", "res://scripts/actors/set_el_ar.gd", "res://scripts/actors/set_el_as.gd", "res://scripts/actors/set_el_at.gd", "res://scripts/actors/set_el_au.gd", "res://scripts/actors/set_el_av.gd", "res://scripts/actors/set_el_aw.gd"]
## Biten set -> parti dosyası (_tmp/kiyafet/el_sync.py yazar): oyunda parti betikleri yalnız gerekince yüklenir
const MAP := {"set_aburame": "set_el_a.gd", "set_akatsuki": "set_el_k.gd", "set_ame": "set_el_m.gd", "set_anbu": "set_el_i.gd", "set_anbu_byakue": "set_el_t.gd", "set_anbu_kaptan": "set_el_o.gd", "set_anbu_kasumi": "set_el_p.gd", "set_anbu_konoha": "set_el_o.gd", "set_anbu_wakate": "set_el_p.gd", "set_anbu_yami": "set_el_o.gd", "set_aogiri": "set_el_e.gd", "set_awa": "set_el_h.gd", "set_chinoike": "set_el_c.gd", "set_chunin": "set_el_i.gd", "set_funato": "set_el_c.gd", "set_genin": "set_el_i.gd", "set_genso": "set_el_h.gd", "set_goken": "set_el_n.gd", "set_hagoromo": "set_el_d.gd", "set_hokage": "set_el_n.gd", "set_iburi": "set_el_c.gd", "set_iryonin": "set_el_k.gd", "set_iwa_chunin": "set_el_k.gd", "set_iwa_eski": "set_el_d.gd", "set_iwa_jonin": "set_el_k.gd", "set_iwa_kunoichi": "set_el_e.gd", "set_jinmon": "set_el_b.gd", "set_joki": "set_el_l.gd", "set_jonin": "set_el_j.gd", "set_kage": "set_el_n.gd", "set_kage_no": "set_el_l.gd", "set_kaguya": "set_el_a.gd", "set_kazekage": "set_el_n.gd", "set_kazekiri": "set_el_g.gd", "set_keimu": "set_el_a.gd", "set_kenpo": "set_el_l.gd", "set_kenshi": "set_el_l.gd", "set_kiri_atki": "set_el_g.gd", "set_kiri_chunin": "set_el_j.gd", "set_kiri_jonin": "set_el_j.gd", "set_kiri_kenshi": "set_el_g.gd", "set_kiri_kunoichi": "set_el_g.gd", "set_konoha_eski": "set_el_d.gd", "set_kumo_chunin": "set_el_j.gd", "set_kumo_jonin": "set_el_k.gd", "set_kumo_kenshi": "set_el_e.gd", "set_kumo_kunoichi": "set_el_e.gd", "set_kumo_kyodai": "set_el_f.gd", "set_kumo_uta": "set_el_d.gd", "set_kurama": "set_el_c.gd", "set_kurenai_kenpo": "set_el_n.gd", "set_kuro_iryo": "set_el_e.gd", "set_kurosuki": "set_el_g.gd", "set_kusa": "set_el_b.gd", "set_matsuri": "set_el_m.gd", "set_mizukage": "set_el_o.gd", "set_nanao": "set_el_h.gd", "set_ne": "set_el_m.gd", "set_nekomata": "set_el_h.gd", "set_nidaime_koromo": "set_el_f.gd", "set_oinin": "set_el_d.gd", "set_oto": "set_el_a.gd", "set_oto_yonin": "set_el_a.gd", "set_raikage": "set_el_o.gd", "set_rengo": "set_el_a.gd", "set_ronin": "set_el_m.gd", "set_samurai": "set_el_l.gd", "set_sansho": "set_el_d.gd", "set_sengoku": "set_el_l.gd", "set_sennin_shugyo": "set_el_n.gd", "set_shakunetsu": "set_el_h.gd", "set_shimo": "set_el_b.gd", "set_shinobi": "set_el_i.gd", "set_soryo": "set_el_m.gd", "set_suna": "set_el_i.gd", "set_suna_chunin": "set_el_j.gd", "set_suna_jonin": "set_el_j.gd", "set_suna_rojo": "set_el_g.gd", "set_tabibito": "set_el_k.gd", "set_taka_kenshi": "set_el_f.gd", "set_taka_kunoichi": "set_el_f.gd", "set_taki": "set_el_b.gd", "set_tani": "set_el_c.gd", "set_tetsu_sho": "set_el_f.gd", "set_tsuchikage": "set_el_o.gd", "set_uchiha": "set_el_i.gd", "set_uzumaki_haha": "set_el_e.gd", "set_uzushio": "set_el_b.gd", "set_uzushio_hime": "set_el_f.gd", "set_yamanaka": "set_el_c.gd", "set_yogan": "set_el_h.gd", "set_yu": "set_el_b.gd", "set_yuki_tabi": "set_el_m.gd", "ss_acik_ceket": "set_el_y.gd", "ss_algi": "set_el_ad.gd", "ss_alti_yol": "set_el_q.gd", "ss_altinci": "set_el_ag.gd", "ss_anbu_kapuson": "set_el_q.gd", "ss_antrenman": "set_el_at.gd", "ss_antrenman_geishun": "set_el_au.gd", "ss_ates_pelerin": "set_el_z.gd", "ss_ay_cubbe": "set_el_at.gd", "ss_bes_kalp": "set_el_ac.gd", "ss_bilge_palto": "set_el_ak.gd", "ss_buhar_zirh": "set_el_w.gd", "ss_bulut_striker": "set_el_s.gd", "ss_bulut_striker_toprak": "set_el_t.gd", "ss_bulut_striker_yildiz": "set_el_t.gd", "ss_buz_kimono": "set_el_w.gd", "ss_buz_kimono2": "set_el_w.gd", "ss_delta": "set_el_u.gd", "ss_demir_dovme": "set_el_ad.gd", "ss_demir_kum": "set_el_aq.gd", "ss_denki": "set_el_u.gd", "ss_esofman": "set_el_r.gd", "ss_esofman2": "set_el_s.gd", "ss_esofman_turuncu2": "set_el_aj.gd", "ss_esofman_yirtik": "set_el_s.gd", "ss_flut": "set_el_as.gd", "ss_gelinlik": "set_el_ae.gd", "ss_genc_canavar": "set_el_af.gd", "ss_genclik": "set_el_av.gd", "ss_genclik_ayi": "set_el_av.gd", "ss_genclik_kedi": "set_el_av.gd", "ss_genclik_ruh": "set_el_av.gd", "ss_genis_yaka": "set_el_q.gd", "ss_genjutsu_sargi": "set_el_ae.gd", "ss_gezegen": "set_el_u.gd", "ss_gezgin_palto": "set_el_ap.gd", "ss_goksel_beyaz": "set_el_aa.gd", "ss_golge_genc": "set_el_ap.gd", "ss_golge_jonin": "set_el_aq.gd", "ss_gosterisli": "set_el_ar.gd", "ss_gosterisli_bahar": "set_el_ar.gd", "ss_gosterisli_hava": "set_el_ar.gd", "ss_gozluk_genc": "set_el_al.gd", "ss_gunebakan": "set_el_y.gd", "ss_gunesi": "set_el_p.gd", "ss_harika": "set_el_au.gd", "ss_harika_yildiz": "set_el_av.gd", "ss_hime_hakama": "set_el_w.gd", "ss_iblis": "set_el_aw.gd", "ss_ic_giysi": "set_el_ac.gd", "ss_inuzuka_ceket": "set_el_aw.gd", "ss_iryo_hemsire": "set_el_p.gd", "ss_iryo_hemsire_bahar": "set_el_p.gd", "ss_iwa_genin": "set_el_x.gd", "ss_kabuk_cocuk": "set_el_ad.gd", "ss_kabuk_cubbe": "set_el_aa.gd", "ss_kabuk_okul": "set_el_ad.gd", "ss_kabuk_yirtik": "set_el_ad.gd", "ss_kader_genc": "set_el_ak.gd", "ss_kagit_melek": "set_el_ae.gd", "ss_kaplumbaga": "set_el_av.gd", "ss_kara_palto": "set_el_ah.gd", "ss_karga_cubbe": "set_el_aa.gd", "ss_karga_tunik": "set_el_aa.gd", "ss_kaya_paltosu": "set_el_aa.gd", "ss_kaya_striker": "set_el_al.gd", "ss_kaya_striker_kurtarici": "set_el_am.gd", "ss_kaya_striker_postaci": "set_el_am.gd", "ss_kedi": "set_el_au.gd", "ss_kedi_alev": "set_el_aw.gd", "ss_kimono_etek": "set_el_s.gd", "ss_kiri_genin": "set_el_x.gd", "ss_kizil_elbise": "set_el_an.gd", "ss_kizil_fermuar": "set_el_an.gd", "ss_kizil_kayis": "set_el_ae.gd", "ss_kizil_palto": "set_el_v.gd", "ss_kizil_palto2": "set_el_v.gd", "ss_kizil_takim": "set_el_aj.gd", "ss_kizil_zirh": "set_el_ab.gd", "ss_kod": "set_el_t.gd", "ss_kok_reisi": "set_el_u.gd", "ss_konoha_genin": "set_el_x.gd", "ss_kopuk": "set_el_au.gd", "ss_kukla": "set_el_ad.gd", "ss_kukla_genc": "set_el_an.gd", "ss_kum_cocuk": "set_el_v.gd", "ss_kum_striker": "set_el_aw.gd", "ss_kum_striker_balon": "set_el_aw.gd", "ss_kum_striker_kabile": "set_el_aw.gd", "ss_kumarbaz": "set_el_au.gd", "ss_kumo_genin": "set_el_x.gd", "ss_kurbaga": "set_el_u.gd", "ss_kurbaga_bilge": "set_el_ab.gd", "ss_kurbaga_bilge2": "set_el_ab.gd", "ss_kurucu_genc": "set_el_ai.gd", "ss_kurucu_palto": "set_el_ai.gd", "ss_kutlama": "set_el_s.gd", "ss_kuyruklu_beyaz": "set_el_as.gd", "ss_lav_zirh": "set_el_am.gd", "ss_lavanta_ceket": "set_el_y.gd", "ss_maske_pelerin": "set_el_al.gd", "ss_maskeli_gaiden": "set_el_ac.gd", "ss_maskeli_genc": "set_el_ac.gd", "ss_maskeli_jonin": "set_el_ac.gd", "ss_metal_canavar": "set_el_ah.gd", "ss_mevsim": "set_el_ap.gd", "ss_mikoshi": "set_el_ao.gd", "ss_mor_etek": "set_el_z.gd", "ss_mor_genc": "set_el_z.gd", "ss_mor_genin": "set_el_aq.gd", "ss_mor_kemer": "set_el_y.gd", "ss_mor_uzun": "set_el_z.gd", "ss_murekkep": "set_el_z.gd", "ss_murekkep_ceket": "set_el_am.gd", "ss_naginata": "set_el_au.gd", "ss_ninja_yolu_tisort": "set_el_ak.gd", "ss_okul_mor": "set_el_aq.gd", "ss_on_kuyruk": "set_el_al.gd", "ss_onluk": "set_el_af.gd", "ss_orman_zirh": "set_el_w.gd", "ss_orman_zirh_genc": "set_el_w.gd", "ss_pembe_ceket": "set_el_y.gd", "ss_pembe_genc": "set_el_am.gd", "ss_pembe_kazak": "set_el_y.gd", "ss_pembe_kunoichi": "set_el_am.gd", "ss_pembe_kunoichi2": "set_el_an.gd", "ss_pijama": "set_el_ak.gd", "ss_ruzgar_elbise": "set_el_as.gd", "ss_ruzgar_elbise2": "set_el_as.gd", "ss_ruzgar_genc": "set_el_at.gd", "ss_ruzgar_kimono": "set_el_as.gd", "ss_ruzgar_zirh": "set_el_as.gd", "ss_sahil": "set_el_r.gd", "ss_sahil_denizci": "set_el_r.gd", "ss_sahil_flamingo": "set_el_r.gd", "ss_sahil_gok": "set_el_r.gd", "ss_sahil_hibiskus": "set_el_r.gd", "ss_sakaci": "set_el_ak.gd", "ss_samuray_kuro": "set_el_t.gd", "ss_sari_simsek": "set_el_ah.gd", "ss_sari_simsek_genc": "set_el_ah.gd", "ss_savas_reisi": "set_el_ag.gd", "ss_savas_reisi2": "set_el_ag.gd", "ss_savas_reisi3": "set_el_ag.gd", "ss_savas_reisi_genc": "set_el_ag.gd", "ss_seytan": "set_el_u.gd", "ss_sigara_jonin": "set_el_q.gd", "ss_silah_ustasi": "set_el_at.gd", "ss_simsek_kiyafet": "set_el_af.gd", "ss_sis_striker": "set_el_ah.gd", "ss_sis_striker_beyaz": "set_el_ah.gd", "ss_sis_striker_siyah": "set_el_ai.gd", "ss_siyah_ceket": "set_el_aj.gd", "ss_siyah_tulum": "set_el_t.gd", "ss_sokak": "set_el_ao.gd", "ss_son_savas": "set_el_an.gd", "ss_soylu_pelerin": "set_el_aa.gd", "ss_su_elbise": "set_el_ag.gd", "ss_su_zirh": "set_el_at.gd", "ss_suna_genin": "set_el_x.gd", "ss_tas_yasli": "set_el_al.gd", "ss_tatli": "set_el_ar.gd", "ss_tatli_baklava": "set_el_ar.gd", "ss_tatli_kultur": "set_el_ar.gd", "ss_tavsan_tanri": "set_el_ab.gd", "ss_tavsan_tanri2": "set_el_ab.gd", "ss_tehlike_ceket": "set_el_q.gd", "ss_turuncu_ceket": "set_el_aj.gd", "ss_turuncu_esofman": "set_el_ai.gd", "ss_turuncu_genc": "set_el_ak.gd", "ss_turuncu_maske": "set_el_at.gd", "ss_yaprak_striker": "set_el_af.gd", "ss_yaprak_striker_kovboy": "set_el_af.gd", "ss_yaprak_striker_matador": "set_el_af.gd", "ss_yaz": "set_el_aj.gd", "ss_yedi_kanat": "set_el_v.gd", "ss_yelpaze": "set_el_an.gd", "ss_yelpaze_b": "set_el_ao.gd", "ss_yelpaze_cocuk": "set_el_ap.gd", "ss_yelpaze_genc": "set_el_ap.gd", "ss_yelpaze_genc2": "set_el_ao.gd", "ss_yelpaze_kilic": "set_el_aq.gd", "ss_yelpaze_kolsuz": "set_el_ao.gd", "ss_yelpaze_takim": "set_el_ao.gd", "ss_yelpaze_yirtik": "set_el_ap.gd", "ss_yelpaze_zirh": "set_el_aq.gd", "ss_yemek": "set_el_s.gd", "ss_yeni_nesil": "set_el_ae.gd", "ss_yeni_nesil2": "set_el_ae.gd", "ss_yesil_canavar": "set_el_v.gd", "ss_yesil_canavar2": "set_el_v.gd", "ss_yilan_cubbe": "set_el_ab.gd", "ss_yilan_kimono": "set_el_ai.gd", "ss_yilan_sanin": "set_el_al.gd", "ss_yilan_zirh": "set_el_ai.gd", "ss_yirminci": "set_el_q.gd", "ss_yirtik_esofman": "set_el_aj.gd"}
static var _cache := {}
static var _parts := []


static func _pl() -> Array:
	if _parts.is_empty():
		for f in PART_FILES:
			var s = load(f)
			if s != null and s.can_instantiate():   # yarım kalan parti dosyası diğerlerini bozmasın
				_parts.append(s)
	return _parts


class El:
	var m
	var c: Dictionary
	var sk: Dictionary
	var per: int
	var N: float
	var C: float
	var H: float
	var K: float
	var F: float
	var UA: float
	var UAy: float
	var LS: float

	func _init(mm, cc: Dictionary) -> void:
		m = mm
		c = cc
		sk = m._sk
		per = int(sk["per"])
		N = m._bp("Neck").y
		C = m._bp("UpperChest").y
		H = m._bp("Hips").y
		K = m._bp("LeftLowerLeg").y
		F = m._bp("LeftFoot").y
		UA = absf(m._bp("LeftUpperArm").x)
		UAy = m._bp("LeftUpperArm").y
		LS = signf(m._bp("LeftUpperArm").x)

	## Bedenin o yükseklikteki ölçüsü: yarı genişlik, ön z, arka z
	func M(y: float, xl: float) -> Vector3:
		var V: PackedVector3Array = c["V"]
		var rows: Dictionary = c["rows"]
		var ry := floori(y / A.ROW)
		var w := 0.0
		var f := -9.0
		var b := 9.0
		for k in [ry - 1, ry, ry + 1]:
			var l = rows.get(k)
			if l == null:
				continue
			for i in l:
				var q: Vector3 = V[i]
				if absf(q.y - y) < 0.018 and absf(q.x) < xl:
					w = maxf(w, absf(q.x))
					f = maxf(f, q.z)
					b = minf(b, q.z)
		return Vector3(w, f, b) if w > 0.0 else Vector3(xl * 0.8, 0.1, -0.1)

	func skin(list: Array) -> void:
		var bo := PackedInt32Array()
		var we := PackedFloat32Array()
		bo.resize(per)
		we.resize(per)
		var tot := 0.0
		for e in list:
			tot += float(e[1])
		var k := 0
		for e in list:
			if float(e[1]) <= 0.0 or k >= per:
				continue
			bo[k] = m._bind_index(String(e[0]))
			we[k] = float(e[1]) / tot
			k += 1
		sk["ob"].append_array(bo)
		sk["ow"].append_array(we)

	## Test: OUTFIT_DBGW=1 iken her nokta bağlı olduğu kemiğe göre boyanır (yeşil gövde, kırmızı kol, sarı karışık, mavi bacak)
	static var DBGW := OS.get_environment("OUTFIT_DBGW") != ""
	static func _dbg_col(sl: Array) -> Color:
		var a := 0.0
		var l := 0.0
		var t := 0.0
		for e in sl:
			var bn := String(e[0])
			if bn.contains("Arm") or bn.contains("Hand"):
				a += float(e[1])
			elif bn.contains("Leg") or bn.contains("Foot"):
				l += float(e[1])
			else:
				t += float(e[1])
		var s := maxf(a + l + t, 1e-4)
		return Color(a / s, t / s, l / s)

	## Omuz köşesi kolla iner: yalnız gövdeye bağlı nokta omuz hizasında ve omuz ekleminin dışındaysa üst kola da bağlanır
	## (T duruşunda modellenen kabuğun omuz köşesi kol aşağı inince yana sivri uç / havada omuz olarak kalıyordu)
	func arm_blend(list: Array, p: Vector3) -> Array:
		var arm_i := -1
		for i in list.size():
			var bn := String(list[i][0])
			if bn.contains("Hand") or bn.contains("Leg") or bn.contains("Foot") or bn.contains("Shoulder") or bn.contains("LowerArm"):
				return list
			if bn.contains("UpperArm"):
				arm_i = i
		if arm_i >= 0 and list.size() == 1:   # yalnız kola bağlı kol kumaşı omuz ekleminin içine uzanıyorsa göğse de bağlanır: kol inince üst kenarı omzun üstüne kanat gibi savrulmaz
			var g := 0.75 * (1.0 - smoothstep(UA - 0.005, UA + 0.05 + 0.9 * maxf(0.0, p.y - UAy), absf(p.x))) * smoothstep(UAy - 0.06, UAy + 0.0, p.y)   # eklemin üstü ne kadar yüksekse o kadar dışarıya kadar
			if g < 0.01:
				return list
			return [[list[0][0], 1.0 - g], ["UpperChest", g]]
		if arm_i >= 0:   # kol kökü (göğüs + üst kol karışık): omzun üstündeki noktalar kola daha çok bağlanır, kol inince kumaş boynuz gibi katlanmaz
			var f := 0.65 * smoothstep(UAy - 0.005, UAy + 0.045, p.y) * smoothstep(UA * 0.55, UA * 0.95, absf(p.x))
			if f < 0.01:
				return list
			var tot0 := 0.0
			for e in list:
				tot0 += float(e[1])
			var out0 := []
			for i in list.size():
				var wv := float(list[i][1]) / maxf(tot0, 1e-4)
				out0.append([list[i][0], wv + (1.0 - wv) * f if i == arm_i else wv * (1.0 - f)])
			return out0
		var w := 0.8 * smoothstep(UA - 0.01, UA + 0.04, absf(p.x)) * smoothstep(UAy - 0.11, UAy - 0.03, p.y) * (1.0 - smoothstep(UAy + 0.02, UAy + 0.07, p.y))   # yalnız omuz bandı: yakaya dokunmaz
		if w < 0.01:
			return list
		var tot := 0.0
		for e in list:
			tot += float(e[1])
		var out := []
		for e in list:
			out.append([e[0], float(e[1]) * (1.0 - w)])
		out.append([("Left" if signf(p.x) == LS else "Right") + "UpperArm", w * maxf(tot, 1e-4)])
		return out

	func torso_skin(y: float) -> Array:
		var ks := [["Hips", H], ["Spine", m._bp("Spine").y], ["Chest", m._bp("Chest").y], ["UpperChest", C], ["Neck", N]]
		if y <= H:
			return [["Hips", 1.0]]
		for i in ks.size() - 1:
			if y <= float(ks[i + 1][1]):
				var t := inverse_lerp(float(ks[i][1]), float(ks[i + 1][1]), y)
				return [[ks[i][0], 1.0 - t], [ks[i + 1][0], t]]
		return [["Neck", 1.0]]

	## Etek / uzun giysi ağırlığı: belden aşağı giderek iki bacağı izler (diz ve baldır kumaşı delmez, kumaş bacakla açılır)
	func cloth_skin(p: Vector3, hem: float, leg := 0.58) -> Array:
		if p.y >= H:
			return torso_skin(p.y)
		var t := clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
		var s := smoothstep(-0.075, 0.075, p.x)
		var w := t * leg
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]

	## Halka satırlarından yüzey. rows[j][i] = nokta; colf(i, j, nokta) -> renk; skinf(i, j, nokta) -> kemik listesi
	func grid(rows: Array, closed: bool, colf: Callable, skinf: Callable) -> void:
		var nj := rows.size()
		var ni: int = (rows[0] as Array).size()
		var base: int = (sk["ov"] as PackedVector3Array).size()
		var nr := []
		nr.resize(nj * ni)
		nr.fill(Vector3.ZERO)
		var at = func(i: int, j: int) -> Vector3: return rows[j][i % ni]
		var nq: int = ni if closed else ni - 1
		for j in nj - 1:
			for i in nq:
				var a: Vector3 = at.call(i, j)
				var fn: Vector3 = -(at.call(i + 1, j) - a).cross(at.call(i + 1, j + 1) - a)
				if fn.length_squared() < 1e-12:
					fn = -(at.call(i + 1, j + 1) - a).cross(at.call(i, j + 1) - a)
				for v in [[i, j], [(i + 1) % ni, j], [(i + 1) % ni, j + 1], [i, j + 1]]:
					nr[v[1] * ni + v[0]] += fn
		for j in nj:
			for i in ni:
				var p: Vector3 = rows[j][i]
				sk["ov"].append(p)
				var n0: Vector3 = nr[j * ni + i]
				sk["on"].append(n0.normalized() if n0.length_squared() > 0.0 else Vector3.UP)
				var sl: Array = arm_blend(skinf.call(i, j, p), p)
				sk["oc"].append(_dbg_col(sl) if DBGW else colf.call(i, j, p))
				skin(sl)
		for j in nj - 1:
			for i in nq:
				var i2 := (i + 1) % ni
				var q0 := base + j * ni + i
				var q1 := base + j * ni + i2
				var q2 := base + (j + 1) * ni + i2
				var q3 := base + (j + 1) * ni + i
				sk["oi"].append_array(PackedInt32Array([q0, q1, q2, q0, q2, q3]))

	## Kuvvetli elips kesit noktası
	static func sup(a: float, w: float, zf: float, zb: float, n := 2.5) -> Vector2:
		var s := sin(a)
		var co := cos(a)
		var e := 2.0 / n
		var x := signf(s) * pow(absf(s), e) * w
		var z := signf(co) * pow(absf(co), e) * (zf if co > 0.0 else -zb)
		return Vector2(x, z)

	## keys: [[y, w, zf, zb], ...] yukarıdan aşağı; y'de yumuşak ara değer
	static func key_at(keys: Array, y: float) -> Array:
		var pts := keys
		if y >= float(pts[0][0]):
			return pts[0]
		for i in pts.size() - 1:
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			if y >= float(b[0]):
				var t := smoothstep(0.0, 1.0, inverse_lerp(float(a[0]), float(b[0]), y))
				return [y, lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
		return pts[pts.size() - 1]

	## Kol / bacak tüpü. path: noktalar; bones: path parçası başına kemik; prof: [[t, r], ...]; n: halka
	func tube(path: Array, bones: Array, prof: Array, col: Callable, rings := 22, seg := 14, lip := true, rf := Callable()) -> void:
		var L := 0.0
		var cum := [0.0]
		for i in path.size() - 1:
			L += (path[i + 1] - path[i]).length()
			cum.append(L)
		var rr := func(t: float) -> float:
			for i in prof.size() - 1:
				if t <= float(prof[i + 1][0]):
					return lerpf(prof[i][1], prof[i + 1][1], smoothstep(0.0, 1.0, inverse_lerp(float(prof[i][0]), float(prof[i + 1][0]), t)))
			return float(prof[prof.size() - 1][1])
		var rows := []
		var info := []
		var nr := rings + 1
		for j in nr + (2 if lip else 0):
			var t := minf(1.0, float(j) / rings)
			var s := t * L
			var k := 0
			while k < path.size() - 2 and s > float(cum[k + 1]):
				k += 1
			var seg_l := maxf(0.0001, float(cum[k + 1]) - float(cum[k]))
			var u := clampf((s - float(cum[k])) / seg_l, 0.0, 1.0)
			var ctr: Vector3 = (path[k] as Vector3).lerp(path[k + 1], u)
			var d0: Vector3 = (path[k + 1] - path[k]).normalized()
			var d1: Vector3 = d0
			if u > 0.75 and k < path.size() - 2:
				d1 = d0.lerp((path[k + 2] - path[k + 1]).normalized(), (u - 0.75) * 2.0).normalized()
			var up := -d1
			var fw: Vector3 = (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
			var ri := up.cross(fw).normalized()
			var r: float = rr.call(t)
			if j == nr:
				r *= 0.93
			elif j == nr + 1:
				r *= 0.78
				ctr -= d1 * 0.012
			var ro := []
			for i in seg:
				var a := TAU * i / seg - PI
				var r2: float = r * (1.0 + (float(rf.call(t, a)) if rf.is_valid() else 0.0))
				ro.append(ctr + ri * sin(a) * r2 + fw * cos(a) * r2)
			rows.append(ro)
			var bl := [[bones[k], 1.0]]
			if u > 0.72 and k + 1 < bones.size():
				var b2 := smoothstep(0.72, 1.0, u) * 0.5
				bl = [[bones[k], 1.0 - b2], [bones[k + 1], b2]]
			elif u < 0.28 and k > 0:
				var b2 := (1.0 - smoothstep(0.0, 0.28, u)) * 0.5
				bl = [[bones[k], 1.0 - b2], [bones[k - 1], b2]]
			info.append(bl)
		grid(rows, true, func(i, j, _p): return col.call(float(mini(j, rings)) / rings, TAU * i / seg - PI, j > rings), func(_i, j, _p): return info[j])

	## Yüzeye kabartma şerit (kendi kemik ağırlığıyla: altındaki kumaştan ayrılmaz). skinf(nokta) -> kemik listesi
	func strip(pts: Array, outs: Array, hw: float, d: float, col: Color, closed := false, skinf := Callable()) -> void:
		var n := pts.size()
		var rows := []
		for i in n:
			var a: Vector3 = pts[(i - 1 + n) % n] if closed or i > 0 else pts[i]
			var b: Vector3 = pts[(i + 1) % n] if closed or i < n - 1 else pts[i]
			var o: Vector3 = outs[i]
			var w: Vector3 = (b - a).normalized().cross(o).normalized() * hw
			var p: Vector3 = pts[i]
			rows.append([p + w - o * 0.002, p + w * 0.86 + o * d, p - w * 0.86 + o * d, p - w - o * 0.002])
		if closed:
			rows.append(rows[0])
		var t0: Vector3 = rows[0][1]
		var fn: Vector3 = -(rows[0][2] - t0).cross(rows[1][2] - t0)
		if fn.dot(outs[0]) < 0.0:
			for ro in rows:
				ro.reverse()
		var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return torso_skin(p.y)
		grid(rows, false, func(_i, _j, _p): return col, func(_i, _j, p): return sf.call(p))

	## Uzvu saran sargı turu: eğik halka, ortası kabarık
	func wrap_turn(ctr: Vector3, d: Vector3, r: float, hw: float, tilt: float, col: Color, bones: Array) -> void:
		var up := -d.normalized()
		var fw: Vector3 = (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
		var ri := up.cross(fw).normalized()
		var rows := []
		for j in 4:
			var v := float(j) / 3.0
			var off := lerpf(hw, -hw, v)
			var rr := r + 0.0055 * sin(v * PI) - 0.007 * (1.0 - sin(v * PI))   # kenarlar uzva gömülür: boşlukta halka gibi durmaz
			var ro := []
			for i in 16:
				var a := TAU * i / 16.0 - PI
				ro.append(ctr + up * (off + sin(a + 0.6) * tilt) + (ri * sin(a) + fw * cos(a)) * rr)
			rows.append(ro)
		grid(rows, true, func(_i, j, _p): return col.darkened(0.1) if j in [0, 3] else col, func(_i, _j, _p): return bones)


## Disk önbelleği yalnız yayın sürümünde (geliştirmede kod değişir); dosya adı sürüme bağlı
static func _disk_path(sid: String, gender: String) -> String:
	if not (OS.has_feature("template") or OS.get_environment("EL_CACHE") != ""):
		return ""
	var ver := "dev"
	var f := FileAccess.open("res://data/build.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			ver = str(d.get("version", "dev"))
	return "user://el_kiyafet/%s/%s_%s.res" % [ver, sid, gender]


static func has(sid) -> bool:
	if sid == null or String(sid) == "":
		return false
	if sid in SETS or MAP.has(sid):
		return true
	if OS.has_feature("template") or OS.get_environment("EL_MAP") != "":
		return false
	for p in _pl():   # geliştirme: ajanların yeni bitirdiği setler
		if sid in p.DONE:
			return true
	return false


static func build(m, sid: String, g: Dictionary) -> void:
	var box := Vector3(m._bp("Neck").y + 0.015, m._bp("LeftFoot").y + 0.075, absf(m._bp("LeftHand").x) - 0.012)
	var ua: Vector3 = m._bp("LeftUpperArm")
	var keep := Vector2(ua.y, absf(ua.x) - 0.05)   # iki omuz eklemi arası boyun dibi / sırt üstü çizilir: yaka ve omuz kenarından yer görünmesin (kollar gizli kalır)
	for mt in m.materials:
		mt.set_shader_parameter("hand_box", box)
		mt.set_shader_parameter("hand_keep", keep)
	var key := "%s|%s" % [sid, str(m.look.get("gender", "m"))]
	var disk := _disk_path(sid, str(m.look.get("gender", "m")))
	if not _cache.has(key) and disk != "" and FileAccess.file_exists(disk):
		var dm = ResourceLoader.load(disk, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
		if dm is ArrayMesh:
			_cache[key] = [dm, dm.get_meta("dg", [])]
	if _cache.has(key):
		var e: Array = _cache[key]
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		m.skel.add_child(mi)
		mi.skin = m.body_mesh.skin
		mi.skeleton = mi.get_path_to(m.skel)
		mi.material_override = Props.toon()
		A._dangles(m, e[1])
		return
	var c = A._begin(m)
	if c.is_empty():
		return
	var k := El.new(m, c)
	if sid == "set_shugonin":
		_shugonin(k)
	else:
		if MAP.has(sid):
			load("res://scripts/actors/" + String(MAP[sid])).recipe(k, sid)
		else:
			for p in _pl():
				if sid in p.DONE:
					p.recipe(k, sid)
	var made = m._sk_end(g)
	_cache[key] = [made.mesh, c["dg"]]
	if disk != "":   # bir kez kurulan kıyafet diske: sonraki açılışlarda kurulum takılması olmaz
		(made.mesh as ArrayMesh).set_meta("dg", c["dg"])
		DirAccess.make_dir_recursive_absolute(disk.get_base_dir())
		ResourceSaver.save(made.mesh, disk)
	A._dangles(m, c["dg"])


# ------------------------------------------------------------------ ortak parçalar
static func arms(k: El, prof: Array, col: Callable, rf := Callable()) -> void:
	for sd in ["Left", "Right"]:
		var m = k.m
		var p0: Vector3 = m._bp(sd + "UpperArm")
		var p1: Vector3 = m._bp(sd + "LowerArm")
		var p2: Vector3 = m._bp(sd + "Hand")
		var ch: Vector3 = m._bp("UpperChest")
		k.tube([p0.lerp(Vector3(0.0, ch.y, ch.z), 0.2), p0, p1, p2.lerp(p1, 0.06)], ["UpperChest", sd + "UpperArm", sd + "LowerArm"], prof, col, 30, 16, true, rf)   # omuz kökü gövdeyle gider: kol savrulunca balon yapmaz


## Bacak kalçadan ayak bileğine TAM yapılır (top_y kısaltmak uyluğu boş bırakır, kullanma)
static func legs(k: El, prof: Array, col: Callable, top_y := 99.0, rf := Callable()) -> void:
	for sd in ["Left", "Right"]:
		var m = k.m
		var p0: Vector3 = m._bp(sd + "UpperLeg")
		var p1: Vector3 = m._bp(sd + "LowerLeg")
		var p2: Vector3 = m._bp(sd + "Foot")
		var st: Vector3 = p0 + Vector3(0, 0.05, 0)
		if top_y < st.y:
			st = st.lerp(p1, inverse_lerp(st.y, p1.y, top_y))
		k.tube([st, p1, p2 + Vector3(0, 0.07, 0)], [sd + "UpperLeg", sd + "LowerLeg"], prof, col, 34, 18, true, rf)


## Kapalı beden katmanı
static func body_layer(k: El, keys: Array, ny: int, na: int, colf: Callable, foldf := Callable()) -> void:
	var rows := []
	var y0: float = keys[0][0]
	var y1: float = keys[keys.size() - 1][0]
	for j in ny + 1:
		var y := lerpf(y0, y1, float(j) / ny)
		var s: Array = El.key_at(keys, y)
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var q: Vector2 = El.sup(a, s[1], s[2], s[3])
			var f := 1.0 + (float(foldf.call(a, y)) if foldf.is_valid() else 0.0)
			ro.append(Vector3(q.x * f, y, q.y * f))
		rows.append(ro)
	k.grid(rows, true, colf, func(_i, _j, p): return k.torso_skin(p.y))


# ------------------------------------------------------------------ Shugonin Jūnishi (ref refs/kiyafet/shugonin): koyu iç giysi, sargılı baldır, sarmal gri kolsuz üst, 火 kuşağı
static func _shugonin(k: El) -> void:
	var dk := Color(0.15, 0.15, 0.18)
	var gr := Color(0.47, 0.47, 0.5)
	var ed := Color(0.72, 0.71, 0.68)
	var wh := Color(0.86, 0.83, 0.74)
	var ink := Color(0.13, 0.11, 0.1)
	var N := k.N
	var H := k.H
	var C := k.C
	var ch := k.M(C - 0.03, k.UA * 1.0)
	var wa := k.M(H + 0.12, k.UA * 1.0)
	var hp := k.M(H - 0.04, 0.3)
	var nk := k.M(N + 0.02, 0.09)
	var pad := 0.012
	# iç giysi + dik yaka
	var inner := [[N + 0.075, nk.x + 0.01, nk.y + 0.012, nk.z - 0.012], [N + 0.02, nk.x + 0.018, nk.y + 0.016, nk.z - 0.016], [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9],
		[C - 0.03, ch.x + pad, ch.y + pad, ch.z - pad], [H + 0.12, wa.x + pad, wa.y + pad, wa.z - pad], [H - 0.09, hp.x + pad, hp.y + pad, hp.z - pad]]
	body_layer(k, inner, 26, 44, func(_i, j, _p): return dk.lightened(0.06) if j < 3 else dk, Callable())
	arms(k, [[0.0, 0.066], [0.42, 0.055], [0.55, 0.052], [0.88, 0.041], [1.0, 0.043]], func(t, a, inside):
		if inside:
			return dk.darkened(0.4)
		var cr := exp(-pow((t - 0.5) / 0.09, 2.0)) * (0.5 + 0.5 * sin(a * 3.0 + t * 34.0))
		return dk.lightened(0.05).darkened(cr * 0.38), func(t, a):   # dirsekte kırışık, omuz altında bolluk
		return 0.09 * exp(-pow((t - 0.5) / 0.08, 2.0)) * sin(a * 3.0 + t * 34.0) + 0.035 * exp(-pow((t - 0.16) / 0.12, 2.0)) * sin(a * 4.0 + 1.0))
	# pantolon: dizde hafif bol, baldır sargılı
	legs(k, [[0.0, 0.114], [0.26, 0.1], [0.46, 0.078], [0.6, 0.061], [1.0, 0.049]], func(t, a, inside):
		if inside:
			return dk.darkened(0.4)
		if t > 0.6:
			return dk.darkened(0.15)   # sargıların altı: turlar arasında koyu çizgi kalır
		var cr := exp(-pow((t - 0.46) / 0.09, 2.0)) * (0.5 + 0.5 * sin(a * 3.0 + t * 30.0))
		return dk.lightened(0.06).darkened(cr * 0.42), 99.0, func(t, a):   # diz kırışığı, sargının üstünde bolluk
		return 0.07 * exp(-pow((t - 0.45) / 0.075, 2.0)) * sin(a * 3.0 + t * 30.0) * (1.0 - smoothstep(0.5, 0.58, t)))
	# baldır ve bilek sargıları: tur tur
	for sd in ["Left", "Right"]:
		var kn: Vector3 = k.m._bp(sd + "LowerLeg")
		var ft: Vector3 = k.m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		var dl := ft - kn
		for i in 11:
			var t := float(i) / 10.0
			var tone := wh.darkened(0.05 * float(i % 3))
			k.wrap_turn(kn.lerp(ft, lerpf(0.2, 0.98, t)), dl, lerpf(0.069, 0.053, t), 0.0165, 0.012, tone, [[sd + "LowerLeg", 1.0]])
		var el: Vector3 = k.m._bp(sd + "LowerArm")
		var hd: Vector3 = k.m._bp(sd + "Hand")
		var da := hd - el
		for i in 5:
			var t := float(i) / 4.0
			k.wrap_turn(el.lerp(hd, lerpf(0.68, 0.93, t)), da, lerpf(0.046, 0.042, t), 0.012, 0.008, wh.darkened(0.05 * float(i % 2)), [[sd + "LowerArm", 1.0]])
	# üst giysi: omuzdan uyluğa sarmal kesim, sol kanat sağın üstüne biner
	var hem := H - 0.31
	var keys := [[N + 0.005, nk.x + 0.03, nk.y + 0.03, nk.z - 0.03], [N - 0.06, ch.x * 0.98, ch.y * 0.92, ch.z * 1.02], [C - 0.03, ch.x + 0.026, ch.y + 0.026, ch.z - 0.026],
		[H + 0.12, wa.x + 0.03, wa.y + 0.03, wa.z - 0.03], [H - 0.04, hp.x + 0.035, hp.y + 0.03, hp.z - 0.03], [hem, hp.x + 0.085, hp.y + 0.06, hp.z - 0.06]]
	var ny := 62
	var na := 104
	var rows := []
	var angs := []
	var edge_a := []
	var edge_b := []
	var y_top: float = keys[0][0]
	var open_at = func(y: float) -> float:   # yaka açıklığı: boyunda açık, göğüs altında kapanır
		return lerpf(0.5, -0.42, 1.0 - smoothstep(C - 0.12, N, y))
	var fold = func(a: float, y: float) -> float:
		if y < H:   # kuşak altı büzgü, etek ucuna doğru iri dalgalar
			var t := clampf((H - y) / (H - hem), 0.0, 1.0)
			var gather := pow(1.0 - t, 2.0) * 0.042 * sin(a * 17.0 + 0.4)
			return gather + t * t * (0.062 * sin(a * 7.0 + 0.6) + 0.03 * sin(a * 13.0 + 1.9))
		var s := clampf((y - H) / (N - H), 0.0, 1.0)   # kuşağa inen gerilme kırışıkları, omuzdan süzülen kat
		return (1.0 - s) * (0.024 * sin(a * 9.0 + y * 9.0) + 0.01 * sin(a * 19.0 - y * 21.0)) + s * 0.009 * sin(a * 4.0 - y * 24.0)
	for j in ny + 1:
		var y := lerpf(y_top, hem, float(j) / ny)
		var s: Array = El.key_at(keys, y)
		var e: float = open_at.call(y)
		var ro := []
		var ar := []
		for i in na + 1:
			var u := float(i) / na
			var a := lerpf(e, TAU - e * 0.55, u)   # 0 = ön orta; kanat yayı sarılır
			var q: Vector2 = El.sup(a if a < PI else a - TAU, s[1], s[2], s[3])
			var f: float = 1.0 + fold.call(a, y) + 0.05 * smoothstep(0.72, 1.0, u)
			ro.append(Vector3(q.x * f, y, q.y * f))
			ar.append(a)
		rows.append(ro)
		angs.append(ar)
		edge_a.append(ro[0])
		edge_b.append(ro[na])
	var vest_skin = func(p: Vector3) -> Array: return k.cloth_skin(p, hem)
	k.grid(rows, false, func(i, j, p):
		var v: float = fold.call(angs[j][i], p.y)
		var amp := 0.055 if p.y < H else 0.028
		var c0 := gr.darkened(clampf(-v / amp, 0.0, 1.0) * 0.34).lightened(clampf(v / amp, 0.0, 1.0) * 0.1)
		return c0.darkened(0.3) if j >= ny - 1 else c0, func(_i, _j, p): return vest_skin.call(p))
	# yaka şeridi + etek biyesi (kumaşın üstüne binen gerçek şerit)
	var outs_b := []
	var outs_a := []
	for p in edge_b:
		outs_b.append(Vector3(p.x * 0.6, 0.0, maxf(0.4, p.z * 4.0)).normalized())
	for p in edge_a:
		outs_a.append(Vector3(p.x * 0.6, 0.0, maxf(0.4, p.z * 4.0)).normalized())
	k.strip(edge_b.slice(0, ny - 8), outs_b.slice(0, ny - 8), 0.02, 0.006, ed, false, vest_skin)
	k.strip(edge_a.slice(0, ny - 8), outs_a.slice(0, ny - 8), 0.02, 0.006, ed, false, vest_skin)
	var hm := []
	var ho := []
	for p in rows[ny]:
		hm.append(p + Vector3(0, 0.012, 0))
		ho.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(hm, ho, 0.014, 0.005, ed, false, vest_skin)
	# 火 kuşağı: kalın, katlı bez
	var by := H + 0.045
	var skey: Array = El.key_at(keys, by)
	var belt := []
	for j in 7:
		var t := float(j) / 6.0
		var y := by + 0.05 - t * 0.1
		var bulge := 0.012 * sin(t * PI) + 0.004
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var q: Vector2 = El.sup(a, float(skey[1]) + bulge + 0.009, float(skey[2]) + bulge + 0.012, float(skey[3]) - bulge - 0.012)
			ro.append(Vector3(q.x, y, q.y))
		belt.append(ro)
	k.grid(belt, true, func(i, j, _p): return wh.darkened(0.16) if j in [2, 4] and (i + j) % 9 > 1 else wh, func(_i, _j, p): return k.torso_skin(p.y))
	var zf := float(skey[2]) + 0.03
	var kx := float(skey[1]) * 0.5
	k.tube([Vector3(kx - 0.036, by + 0.012, zf + 0.008), Vector3(kx + 0.036, by - 0.012, zf + 0.008)], ["Hips"], [[0.0, 0.016], [0.5, 0.027], [1.0, 0.016]], func(_t, a, _i): return wh.darkened(0.12 if sin(a * 3.0) < -0.2 else 0.0), 8, 12, false)   # kuşak düğümü
	for sg in [1.0, -1.0]:
		var o := Vector3(0, 0, sg)
		var z: float = (zf if sg > 0.0 else float(skey[3]) - 0.03)
		for st in [[Vector2(-0.55, 0.42), Vector2(-0.28, 0.08)], [Vector2(0.55, 0.42), Vector2(0.28, 0.08)], [Vector2(0.0, 0.85), Vector2(0.0, 0.18), Vector2(-0.62, -0.85)], [Vector2(0.0, 0.18), Vector2(0.65, -0.85)]]:
			var pts := []
			var ou := []
			for q in st:
				pts.append(Vector3(q.x * 0.036, by + q.y * 0.036, z))
				ou.append(o)
			k.strip(pts, ou, 0.0048, 0.0015, ink)
	# kuşak uçları: eteğin üstüne oturan iki kat (havada sallanmaz, kumaşla açılır)
	for e2 in [[kx + 0.012, 0.018, 0.3, 0.036, wh], [kx - 0.026, -0.012, 0.23, 0.03, wh.darkened(0.08)]]:
		var tp := []
		var to := []
		for i in 13:
			var v := float(i) / 12.0
			var y2: float = by - 0.05 - v * float(e2[2])
			var s2: Array = El.key_at(keys, y2)
			var x2: float = float(e2[0]) + float(e2[1]) * v
			var q2: Vector2 = El.sup(asin(clampf(x2 / maxf(0.05, float(s2[1])), -0.9, 0.9)), s2[1], s2[2], s2[3])
			tp.append(Vector3(x2, y2, q2.y * 1.11 + 0.008))
			to.append(Vector3(0.0, 0.0, 1.0))
		k.strip(tp, to, float(e2[3]), 0.005, e2[4], false, vest_skin)
