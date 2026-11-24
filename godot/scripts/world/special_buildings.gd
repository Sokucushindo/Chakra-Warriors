class_name SpecialBuildings
extends RefCounted
## Köyün özel binaları (Konoha): her biri kendi kimliğiyle — hastane (giriş kulesi, saçaklı kat bantları, kanopi, çatı korkuluğu,
## bahçe), ANBU karargâhı (karanlık sur, ağır kapı, meşaleler, maske arması), dükkân cepheleri (noren perde, kanji tabela,
## fenerler, sundurma ve dükkâna özel vitrin: ilaç kavanozları, silah rafı, manken, şemsiyeli çay bankı, mangal bacası, han kapısı).

static func _g(b: Builder, x: float, n: float) -> float:
	return Game.terrain_height(b.origin.x + x, b.origin.z - n) - b.origin.y


## Dükkân cephesi. nf: cephe düzlemi (yerel n), dn: caddeye doğru yön (+1 kuzey / -1 güney), w: cephe genişliği
## Çarşının adı olan dükkânlarının KENDİ binaları (2026-11-25, kullanıcı: "çeşitlilik çok az, özel binalarda elini korkak alıştırma"):
## her dükkân türü ayrı silüet, malzeme ve cephe: çayevi alçak ahşap kafes cepheli machiya, han kat kat balkonlu ryokan,
## silahçı taş kaideli koyu ahşap, parşömenci beyaz sıvalı kara kaideli kura ambarı, terzi sarkan kumaşlı, mangal evi koyu kızıl
## tuğla + baca, eczane yeşil sıvalı ot kurutmalı. x, nc: bina merkezi; dn: caddeye yön (-1 güney); w, d: taban.
static func shop_building(b: Builder, x: float, nc: float, w: float, d: float, dn: float, kind: String) -> float:
	var yo = b.yoff
	b.yoff = _g(b, x, nc)
	var yaw = 0.0 if dn < 0.0 else 180.0
	var front = nc + dn * d * 0.5
	var fz = func(o: float) -> float: return front + dn * o   # cepheden dışarı o metre
	var wood = Color(0.36, 0.23, 0.14)
	var wood_l = Color(0.55, 0.38, 0.24)
	var plaster = Color(0.93, 0.9, 0.82)
	var tile = Color(0.3, 0.31, 0.35)
	var stone = Color(0.55, 0.53, 0.5)
	var floors = 2
	var fh = 3.8
	var body = plaster
	var low = plaster
	var roof_c = tile
	match kind:
		"teahouse":
			floors = 2; body = Color(0.92, 0.88, 0.78); low = wood; roof_c = Color(0.28, 0.3, 0.33)
		"inn":
			floors = 3; body = Color(0.9, 0.85, 0.74); low = wood_l; roof_c = Color(0.25, 0.36, 0.5)
		"weapon_shop":
			floors = 2; body = Color(0.42, 0.3, 0.2); low = stone; roof_c = Color(0.22, 0.23, 0.26)
		"scrolls":
			floors = 2; body = Color(0.96, 0.95, 0.92); low = Color(0.14, 0.14, 0.16); roof_c = Color(0.2, 0.2, 0.22)
		"tailor":
			floors = 3; body = Color(0.92, 0.86, 0.9); low = plaster; roof_c = Color(0.42, 0.28, 0.5)
		"bbq":
			floors = 2; body = Color(0.6, 0.24, 0.18); low = Color(0.45, 0.18, 0.14); roof_c = Color(0.14, 0.13, 0.13)
		"pharmacy":
			floors = 2; body = Color(0.8, 0.9, 0.8); low = Color(0.88, 0.92, 0.86); roof_c = Color(0.28, 0.5, 0.35)
	var H = floors * fh
	# taban + gövde (zemin katı ayrı malzeme), kat kirişleri, köşe dikmeleri
	b.box(Vector3(x, 0.25, nc), Vector3(w + 0.5, 0.5, d + 0.5), stone, yaw)
	b.box(Vector3(x, 0.5 + fh * 0.5, nc), Vector3(w, fh, d), low, yaw)
	b.box(Vector3(x, 0.5 + fh + (H - fh) * 0.5, nc), Vector3(w - 0.3, H - fh, d - 0.3), body, yaw)
	for f in floors:
		b.box(Vector3(x, 0.5 + (f + 1) * fh - 0.12, nc), Vector3(w + 0.25, 0.26, d + 0.25), wood, yaw, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(x + sx * w * 0.5, 0.5 + H * 0.5, nc + sz * d * 0.5), Vector3(0.3, H, 0.3), wood, yaw, false)
	# kat saçakları (her katın üstünde kiremit etek) + ana çatı
	for f in range(1, floors):
		b.box(Vector3(x, 0.5 + f * fh + 0.2, fz.call(0.9)), Vector3(w + 1.2, 0.2, 2.0), roof_c, yaw, false, Vector3(-14 * dn, 0, 0))
	b.roof(Vector3(x, 0.5 + H + 1.4, nc), Vector3(w + 2.4, 2.8, d + 2.4), roof_c, yaw)
	b.box(Vector3(x, 0.5 + H + 2.85, nc), Vector3(w + 1.4, 0.35, 0.5), roof_c.darkened(0.2), yaw, false)   # mahya
	# cephe: türe göre
	var y1 = 0.5 + fh   # 1. kat tabanı
	match kind:
		"teahouse", "inn":
			# zemin katı ahşap kafes (koshi): sık dikey çıtalar
			var nsl = int(w / 0.32)
			for k in nsl:
				var sx2 = x - w * 0.5 + (k + 0.5) * w / nsl
				if absf(sx2 - x) < 1.4:
					continue   # kapı
				b.box(Vector3(sx2, 0.5 + fh * 0.45, fz.call(0.05)), Vector3(0.09, fh * 0.8, 0.12), wood, yaw, false)
			for f in range(1, floors):   # üst katlar: tam boy ahşap balkon + korkuluk + shoji
				var yb = 0.5 + f * fh
				b.box(Vector3(x, yb + 0.1, fz.call(0.9)), Vector3(w - 0.4, 0.18, 1.8), wood_l, yaw)
				b.box(Vector3(x, yb + 1.0, fz.call(1.75)), Vector3(w - 0.4, 0.12, 0.12), wood, yaw, false)
				var np = int(w / 1.6)
				for k in np + 1:
					b.box(Vector3(x - (w - 0.4) * 0.5 + k * (w - 0.4) / np, yb + 0.55, fz.call(1.75)), Vector3(0.1, 0.9, 0.1), wood, yaw, false)
				var nsh = int(w / 2.2)
				for k in nsh:
					var shx = x - w * 0.5 + (k + 0.5) * w / nsh
					b.box(Vector3(shx, yb + fh * 0.5, fz.call(0.04)), Vector3(w / nsh - 0.25, fh * 0.65, 0.08), Color(0.96, 0.94, 0.86), yaw, false)
					b.box(Vector3(shx, yb + fh * 0.5, fz.call(0.08)), Vector3(0.06, fh * 0.65, 0.06), wood, yaw, false)
			if kind == "inn":   # han: girişte büyük saçaklı kapı çatısı + uzun kağıt fenerler
				b.roof(Vector3(x, y1 - 0.6, fz.call(2.0)), Vector3(6.0, 1.4, 3.2), roof_c, yaw)
				for sx in [-1.0, 1.0]:
					b.box(Vector3(x + sx * 2.6, (y1 - 1.2) * 0.5, fz.call(3.3)), Vector3(0.3, y1 - 1.2, 0.3), wood, yaw)
		"weapon_shop":
			# taş zemin katı: iri blok derzleri; üst kat koyu ahşap kaplama + dar pencereler; çatıda çapraz dev kılıç levhası
			for k in 4:
				b.box(Vector3(x, 0.5 + 0.9 + k * 0.9, fz.call(0.03)), Vector3(w + 0.02, 0.06, 0.06), stone.darkened(0.25), yaw, false)
			var nw = int(w / 3.0)
			for k in nw:
				var wx = x - w * 0.5 + (k + 0.5) * w / nw
				b.box(Vector3(wx, y1 + fh * 0.55, fz.call(0.05)), Vector3(0.8, 2.0, 0.1), Color(0.12, 0.1, 0.1), yaw, false)
			var ry = 0.5 + H + 4.2
			for a in [-35.0, 35.0]:
				b.box(Vector3(x, ry, nc), Vector3(0.5, 6.0, 0.18), Color(0.72, 0.75, 0.8), yaw, false, Vector3(0, 0, a))
				b.box(Vector3(x, ry - 2.0, nc), Vector3(1.6, 0.25, 0.3), Color(0.2, 0.18, 0.16), yaw, false, Vector3(0, 0, a))
		"scrolls":
			# kura ambarı: kara kaidede açık gri ızgara derz (namako), üstte küçük kepenkli pencereler, kalın kenar bantları
			for k in int(w / 0.9) + 1:
				b.box(Vector3(x - w * 0.5 + k * 0.9, 0.5 + fh * 0.5, fz.call(0.03)), Vector3(0.07, fh, 0.05), Color(0.82, 0.82, 0.8), yaw, false)
			for k in 4:
				b.box(Vector3(x, 0.5 + 0.9 * (k + 0.5), fz.call(0.03)), Vector3(w, 0.07, 0.05), Color(0.82, 0.82, 0.8), yaw, false)
			for k in 3:
				var wx = x - w * 0.3 + k * w * 0.3
				b.box(Vector3(wx, y1 + fh * 0.55, fz.call(0.08)), Vector3(1.3, 1.3, 0.2), Color(0.15, 0.15, 0.17), yaw, false)
				b.box(Vector3(wx, y1 + fh * 0.55, fz.call(0.16)), Vector3(1.0, 1.0, 0.08), Color(0.55, 0.5, 0.42), yaw, false)
		"tailor":
			# üst kattan sarkan uzun renkli kumaş topları (boyacı / terzi vitrini)
			var cl = [Color(0.85, 0.3, 0.3), Color(0.25, 0.4, 0.75), Color(0.95, 0.8, 0.35), Color(0.4, 0.65, 0.4), Color(0.6, 0.35, 0.65)]
			var nb = int(w / 2.4)
			for k in nb:
				var bx = x - w * 0.5 + (k + 0.5) * w / nb
				var ln = 3.0 + (k % 3) * 0.8
				b.box(Vector3(bx, 0.5 + H - 0.3 - ln * 0.5, fz.call(0.25)), Vector3(1.4, ln, 0.05), cl[k % cl.size()], yaw, false)
				b.box(Vector3(bx, 0.5 + H - 0.25, fz.call(0.3)), Vector3(1.6, 0.12, 0.12), wood, yaw, false)
			for f in range(1, floors):
				for k in int(w / 3.0):
					b.box(Vector3(x - w * 0.5 + (k + 0.5) * w / int(w / 3.0), 0.5 + f * fh + fh * 0.55, fz.call(0.02)), Vector3(1.6, 1.8, 0.08), Color(0.5, 0.68, 0.82), yaw, false)
		"bbq":
			# tuğla derzleri, iki iri baca, saçak boyu kırmızı fener dizisi
			for k in int(H / 0.6):
				b.box(Vector3(x, 0.5 + 0.3 + k * 0.6, fz.call(0.02)), Vector3(w, 0.04, 0.04), Color(0.35, 0.12, 0.1), yaw, false)
			for sx in [-0.3, 0.3]:
				b.box(Vector3(x + sx * w, 0.5 + H + 3.0, nc - dn * d * 0.2), Vector3(1.2, 4.0, 1.2), Color(0.3, 0.28, 0.27), yaw)
				b.box(Vector3(x + sx * w, 0.5 + H + 5.1, nc - dn * d * 0.2), Vector3(1.6, 0.3, 1.6), Color(0.15, 0.14, 0.14), yaw, false)
			for k in int(w / 1.5):
				var lx = x - w * 0.5 + (k + 0.5) * w / int(w / 1.5)
				b.sphere(Vector3(lx, y1 - 0.5, fz.call(0.9)), Vector3(0.6, 0.75, 0.6), Color(0.92, 0.2, 0.15), 8)
		"pharmacy":
			# ot kurutma rafları (cephe boyunca çapraz direklerde demetler) + yeşil kanatlı pencereler
			for k in int(w / 1.2):
				var hx = x - w * 0.5 + (k + 0.5) * w / int(w / 1.2)
				b.box(Vector3(hx, y1 + 0.8, fz.call(0.4)), Vector3(0.35, 0.9, 0.35), [Color(0.45, 0.62, 0.3), Color(0.62, 0.55, 0.3), Color(0.35, 0.5, 0.3)][k % 3], yaw, false)
			b.box(Vector3(x, y1 + 1.3, fz.call(0.4)), Vector3(w - 0.6, 0.08, 0.08), wood, yaw, false)
			for k in int(w / 3.0):
				var wx = x - w * 0.5 + (k + 0.5) * w / int(w / 3.0)
				b.box(Vector3(wx, y1 + fh * 0.55, fz.call(0.03)), Vector3(1.6, 1.8, 0.08), Color(0.5, 0.68, 0.82), yaw, false)
				b.box(Vector3(wx, y1 + fh * 0.55, fz.call(0.06)), Vector3(1.9, 0.12, 0.1), Color(0.25, 0.5, 0.32), yaw, false)
	b.yoff = yo
	return H


## Konoha Askerî Polis Birliği binası (kaynak: refs/konoha/Konoha_Military_Police_Force.png): koyu sarı gövde, öne doğru
## çeyrek daire kavisle inen üst cephe, ortada amblemli dar kule (uzun ızgara pencere), kavisin iki yanında yuvarlak lomboz,
## tuğla rengi eğik saçak, verandada silindir sütunlar, alt bantta mor-mavi kaplama, mavi camlı kapılar, geniş basamaklar.
## dn: caddeye yön (+1 kuzey, -1 güney)
static func police_hq(b: Builder, x: float, nc: float, dn: float) -> void:
	var yo = b.yoff
	b.yoff = _g(b, x, nc)
	var yaw = 0.0 if dn < 0.0 else 180.0
	var W = 28.0; var D = 16.0
	var ochre = Color(0.86, 0.68, 0.45)
	var ochre_l = Color(0.93, 0.8, 0.58)
	var brick = Color(0.58, 0.32, 0.27)
	var violet = Color(0.48, 0.48, 0.78)
	var glass = Color(0.45, 0.62, 0.78)
	var front = nc + dn * D * 0.5
	var fz = func(o: float) -> float: return front + dn * o
	# kaide + ön basamaklar
	b.box(Vector3(x, 0.3, nc), Vector3(W + 1.0, 0.6, D + 1.0), Color(0.72, 0.72, 0.74), yaw)
	for k in 3:
		b.box(Vector3(x, 0.1 + k * 0.2, fz.call(3.6 - k * 0.6)), Vector3(W - 2.0, 0.2, 1.0 + k * 0.6), Color(0.78, 0.78, 0.8), yaw)
	# zemin kat gövdesi + mor-mavi alt bant
	b.box(Vector3(x, 0.6 + 2.6, nc), Vector3(W, 5.2, D), ochre, yaw)
	b.box(Vector3(x, 0.6 + 0.8, fz.call(0.04)), Vector3(W, 1.6, 0.1), violet, yaw, false)
	for k in int(W / 0.5):   # kaplama çıtaları
		b.box(Vector3(x - W * 0.5 + k * 0.5, 0.6 + 0.8, fz.call(0.1)), Vector3(0.05, 1.6, 0.05), violet.darkened(0.2), yaw, false)
	# kapılar ve vitrin
	for sx in [-0.3, 0.12]:
		b.box(Vector3(x + sx * W, 0.6 + 1.9, fz.call(0.06)), Vector3(4.2, 3.6, 0.12), glass, yaw, false)
		b.box(Vector3(x + sx * W, 0.6 + 1.9, fz.call(0.1)), Vector3(0.1, 3.6, 0.1), Color(0.3, 0.35, 0.45), yaw, false)
	b.box(Vector3(x + 0.33 * W, 0.6 + 2.6, fz.call(0.06)), Vector3(4.4, 1.6, 0.12), glass, yaw, false)
	b.box(Vector3(x + 0.33 * W, 0.6 + 3.6, fz.call(0.5)), Vector3(4.8, 0.12, 1.0), brick, yaw, false, Vector3(-16 * dn, 0, 0))
	# veranda: eğik tuğla saçak + silindir sütunlar
	b.box(Vector3(x, 0.6 + 5.0, fz.call(1.6)), Vector3(W + 1.0, 0.22, 3.6), brick, yaw, false, Vector3(-14 * dn, 0, 0))
	for k in 4:
		var cx = x - W * 0.38 + k * W * 0.253
		b.cyl(Vector3(cx, 0.6 + 2.4, fz.call(3.0)), 0.9, 4.8, ochre_l, true, 12)
	# üst kat: geride kalan kütle + öne kavisle inen çeyrek daire cephe (eğik dilimler)
	b.box(Vector3(x, 5.8 + 2.0, nc - dn * 2.5), Vector3(W - 2.0, 4.0, D - 5.0), ochre, yaw)
	var R = 5.5
	for k in 8:
		var a0 = (k + 0.5) / 8.0 * PI * 0.5
		var py = 5.8 + sin(a0) * R
		var pz = nc + dn * (D * 0.5 - 5.0 + cos(a0) * R * 0.95)
		b.box(Vector3(x, py - 0.45, pz - dn * 0.3), Vector3(W - 1.0, 1.5, R * PI * 0.5 / 8.0 + 0.7), ochre_l if k % 2 == 0 else ochre, yaw, k < 2, Vector3(-(90.0 - rad_to_deg(a0)), 0, 0))
	b.box(Vector3(x, 5.6, fz.call(0.2)), Vector3(W + 1.2, 0.5, 1.2), brick, yaw, false)   # kavis altı kiremit bandı
	# yuvarlak lomboz pencereler (kavisin iki yanında)
	for sx in [-1.0, 1.0]:
		var lp = Vector3(x + sx * W * 0.28, 8.4, nc + dn * (D * 0.5 - 5.0 + 4.95))   # kavis yüzeyinin önünde
		b.disc(lp, 3.0, 0.4, Color(0.4, 0.3, 0.22), yaw, 20)
		b.disc(lp + Vector3(0, 0, dn * 0.15), 2.5, 0.3, Color(0.5, 0.6, 0.66), yaw, 20)
	# orta kule: uzun ızgara pencere + tepede amblem
	b.box(Vector3(x, 8.0, nc + dn * (D * 0.5 - 3.5)), Vector3(5.0, 15.0, 4.0), ochre_l, yaw)
	b.box(Vector3(x, 15.7, nc + dn * (D * 0.5 - 3.5)), Vector3(5.4, 0.4, 4.4), brick, yaw, false)
	var tf = nc + dn * (D * 0.5 - 1.45)
	b.box(Vector3(x, 8.6, tf), Vector3(2.2, 7.5, 0.12), glass, yaw, false)
	for k in 6:
		b.box(Vector3(x, 5.4 + k * 1.3, tf + dn * 0.05), Vector3(2.3, 0.1, 0.08), Color(0.92, 0.88, 0.7), yaw, false)
	b.box(Vector3(x, 8.6, tf + dn * 0.05), Vector3(0.1, 7.5, 0.08), Color(0.92, 0.88, 0.7), yaw, false)
	var ep = Vector3(x, 13.8, tf + dn * 0.1)
	b.disc(ep, 2.6, 0.2, Color(0.95, 0.95, 0.92), yaw, 20)
	for k in 4:   # şuriken amblemi
		b.box(ep + Vector3(0, 0, dn * 0.12), Vector3(0.55, 2.0, 0.06), Color(0.15, 0.45, 0.5), yaw, false, Vector3(0, 0, 45.0 + k * 45.0))
	b.disc(ep + Vector3(0, 0, dn * 0.2), 0.8, 0.1, Color(0.82, 0.18, 0.15), yaw, 14)   # Uchiha yelpazesi
	b.kanji(Vector3(x, 12.2, tf + dn * 0.12), "警務部隊", 0.55, Color(0.2, 0.15, 0.12), yaw)
	b.yoff = yo


## Konoha Kütüphanesi (kaynak: anime "Konoha Library" — pembe sıva, alt kısmı dikey ahşap kaplama, mavi çerçeveli pencereler,
## kapı yanında dikey 図書 levhalı silindir direk) + üst katta "木ノ葉図書館" tabelası
static func library(b: Builder, x: float, nc: float, dn: float) -> void:
	var yo = b.yoff
	b.yoff = _g(b, x, nc)
	var yaw = 0.0 if dn < 0.0 else 180.0
	var W = 24.0; var D = 15.0; var H = 9.0
	var pink = Color(0.92, 0.78, 0.8)
	var plank = Color(0.55, 0.36, 0.3)
	var frame = Color(0.3, 0.45, 0.6)
	var front = nc + dn * D * 0.5
	var fz = func(o: float) -> float: return front + dn * o
	b.box(Vector3(x, 0.25, nc), Vector3(W + 0.6, 0.5, D + 0.6), Color(0.7, 0.68, 0.66), yaw)
	b.box(Vector3(x, 0.5 + H * 0.5, nc), Vector3(W, H, D), pink, yaw)
	b.box(Vector3(x, 0.5 + H + 0.3, nc), Vector3(W + 0.8, 0.6, D + 0.8), Color(0.62, 0.45, 0.42), yaw)
	for k in int(W / 0.45):   # dikey ahşap kaplama (alt 2 m)
		b.box(Vector3(x - W * 0.5 + (k + 0.5) * 0.45, 1.5, fz.call(0.05)), Vector3(0.4, 2.0, 0.08), plank.darkened(0.06 * (k % 2)), yaw, false)
	for f in 2:   # pencereler
		for k in 5:
			var wx = x - W * 0.4 + k * W * 0.2
			if f == 0 and absf(wx - x) < 3.0:
				continue
			b.box(Vector3(wx, 3.4 + f * 3.6, fz.call(0.06)), Vector3(2.4, 2.0, 0.1), frame, yaw, false)
			b.box(Vector3(wx, 3.4 + f * 3.6, fz.call(0.1)), Vector3(2.1, 1.7, 0.08), Color(0.62, 0.74, 0.82), yaw, false)
	b.box(Vector3(x, 2.0, fz.call(0.06)), Vector3(2.6, 3.0, 0.12), frame, yaw, false)   # kapı
	b.box(Vector3(x, 2.0, fz.call(0.1)), Vector3(2.2, 2.7, 0.08), Color(0.55, 0.68, 0.78), yaw, false)
	# dikey silindir levha direği
	var sp = Vector3(x + 2.6, 2.2, fz.call(0.6))
	b.cyl(sp, 1.0, 3.6, plank, true, 14)
	b.cyl(sp + Vector3(0, 2.0, 0), 1.1, 0.4, Color(0.25, 0.25, 0.27), false, 14)
	b.box(sp + Vector3(0, 0, dn * 0.5), Vector3(0.8, 3.2, 0.06), Color(0.95, 0.93, 0.86), yaw, false)
	b.kanji(sp + Vector3(0, 0.6, dn * 0.55), "図", 0.6, Color(0.15, 0.12, 0.1), yaw)
	b.kanji(sp + Vector3(0, -0.4, dn * 0.55), "書", 0.6, Color(0.15, 0.12, 0.1), yaw)
	b.box(Vector3(x, 0.5 + H - 0.9, fz.call(0.12)), Vector3(9.0, 1.4, 0.15), Color(0.7, 0.5, 0.3), yaw, false)
	b.kanji(Vector3(x, 0.5 + H - 0.9, fz.call(0.22)), "木ノ葉図書館", 0.9, Color(0.15, 0.1, 0.08), yaw)
	b.yoff = yo


static func shop_front(b: Builder, decor: Node3D, x: float, nf: float, dn: float, kind: String, col: Color, w: float) -> void:
	var yo = b.yoff
	b.yoff = _g(b, x, nf + dn * 2.0)
	var yaw = 0.0 if dn < 0.0 else 180.0
	var wood = Color(0.38, 0.25, 0.15)
	var cream = Color(0.97, 0.94, 0.86)
	var kj = {"pharmacy": "薬", "weapon_shop": "武器", "tailor": "呉服", "teahouse": "茶屋", "bbq": "焼肉", "inn": "宿", "scrolls": "巻物"}.get(kind, "店")
	var f = func(d: float) -> float: return nf + dn * d   # cepheden caddeye d metre
	# sundurma: eğik saçak + iki direk
	b.box(Vector3(x, 3.6, f.call(1.3)), Vector3(w * 0.8, 0.14, 2.8), col.darkened(0.25), yaw, false, Vector3(12, 0, 0))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(x + sx * w * 0.38, 1.7, f.call(2.5)), Vector3(0.2, 3.4, 0.2), wood, yaw)
	# kanji tabela (ahşap levha üstünde)
	b.box(Vector3(x, 4.7, f.call(0.15)), Vector3(minf(w * 0.6, 1.6 + kj.length() * 1.3), 1.4, 0.2), wood, yaw, false)
	b.box(Vector3(x, 4.7, f.call(0.27)), Vector3(minf(w * 0.6, 1.6 + kj.length() * 1.3) - 0.25, 1.15, 0.05), cream, yaw, false)
	b.kanji(Vector3(x, 4.7, f.call(0.33)), kj, 0.95, Color(0.12, 0.1, 0.1), yaw)
	# noren: kapı üstünde 4 kumaş şerit + ortada kanji
	for k in 4:
		b.box(Vector3(x - 1.35 + k * 0.9, 2.55, f.call(0.4)), Vector3(0.84, 1.0, 0.04), col, yaw, false)
	b.box(Vector3(x, 3.08, f.call(0.38)), Vector3(3.8, 0.08, 0.08), wood, yaw, false)
	b.kanji(Vector3(x, 2.6, f.call(0.44)), kj.substr(0, 1), 0.6, cream, yaw)
	# kapı yanlarında fenerler (gece yanar)
	for sx in [-1.0, 1.0]:
		var lp = Vector3(x + sx * 2.6, 2.9, f.call(0.5))
		b.cyl(lp + Vector3(0, 0.42, 0), 0.08, 0.2, wood, false, 6)
		b.sphere(lp, Vector3(0.55, 0.7, 0.55), Color(0.9, 0.22, 0.16) if kind in ["bbq", "teahouse"] else Color(1.0, 0.93, 0.8), 10)
		Lights.add(b.w(lp))
	# dükkâna özel vitrin
	match kind:
		"pharmacy":
			b.box(Vector3(x + w * 0.3, 0.5, f.call(1.0)), Vector3(2.4, 1.0, 0.8), wood, yaw)
			for k in 6:
				b.cyl(Vector3(x + w * 0.3 - 1.0 + k * 0.4, 1.2, f.call(1.0)), 0.3, 0.4, [Color(0.45, 0.7, 0.45), Color(0.85, 0.75, 0.4), Color(0.6, 0.4, 0.3)][k % 3], false, 8)
			for k in 3:
				b.cyl(Vector3(x - w * 0.3 + k * 0.7, 0.3, f.call(1.2)), 0.6, 0.6, Color(0.6, 0.48, 0.3), false, 8)
				b.sphere(Vector3(x - w * 0.3 + k * 0.7, 0.65, f.call(1.2)), Vector3(0.55, 0.3, 0.55), Color(0.35, 0.6, 0.3), 8)
		"weapon_shop":
			# silah rafı: iki direk + kirişler + çapraz kılıçlar; dev shuriken tabela
			var rx = x + w * 0.3
			for sx in [-0.9, 0.9]:
				b.box(Vector3(rx + sx, 1.0, f.call(1.0)), Vector3(0.15, 2.0, 0.15), wood, yaw)
			for yy in [0.8, 1.6]:
				b.box(Vector3(rx, yy, f.call(1.0)), Vector3(2.0, 0.08, 0.12), wood, yaw, false)
			for k in 4:
				b.box(Vector3(rx - 0.6 + k * 0.4, 1.25, f.call(1.08)), Vector3(0.06, 1.5, 0.03), Color(0.75, 0.78, 0.82), yaw, false, Vector3(0, 0, 14 if k % 2 else -14))
			var sp = Vector3(x - w * 0.3, 5.2, f.call(0.3))
			for k in 4:
				b.box(sp, Vector3(0.5, 2.0, 0.08), Color(0.25, 0.27, 0.3), yaw, false, Vector3(0, 0, 45.0 + k * 90.0 / 2.0))
			b.cyl(sp, 0.5, 0.12, Color(0.6, 0.62, 0.66), false, 10)
			for sx in [-1.0, 1.0]:  # kunai kütükleri
				b.cyl(Vector3(x + sx * (w * 0.42), 0.5, f.call(1.8)), 0.6, 1.0, Color(0.5, 0.35, 0.2), true, 8)
		"tailor":
			for k in 2:
				var mx = x + w * 0.25 + k * 1.4
				b.cyl(Vector3(mx, 0.75, f.call(1.2)), 0.12, 1.5, wood, false, 6)
				b.box(Vector3(mx, 1.45, f.call(1.2)), Vector3(0.7, 0.8, 0.35), [Color(0.2, 0.3, 0.6), Color(0.75, 0.25, 0.3)][k], yaw, false)
				b.sphere(Vector3(mx, 2.05, f.call(1.2)), Vector3(0.28, 0.32, 0.28), Color(0.9, 0.85, 0.75), 8)
			for k in 4:  # kumaş topları
				b.cyl(Vector3(x - w * 0.3 + k * 0.45, 0.4, f.call(1.0)), 0.36, 0.8, [Color(0.85, 0.3, 0.3), Color(0.3, 0.5, 0.75), Color(0.9, 0.8, 0.4), Color(0.4, 0.65, 0.4)][k], false, 8)
		"teahouse":
			for sx in [-1.0, 1.0]:  # kırmızı bank + büyük şemsiye
				var bx0 = x + sx * w * 0.3
				b.box(Vector3(bx0, 0.45, f.call(1.8)), Vector3(2.4, 0.12, 0.8), Color(0.82, 0.16, 0.14), yaw)
				b.box(Vector3(bx0, 0.22, f.call(1.8)), Vector3(2.2, 0.44, 0.6), wood, yaw, false)
				b.cyl(Vector3(bx0 + 0.9 * sx, 1.6, f.call(2.4)), 0.08, 3.2, wood, false, 6)
				b.cone(Vector3(bx0 + 0.9 * sx, 3.2, f.call(2.4)), 3.0, 0.8, Color(0.85, 0.18, 0.16), 14)
			# dango tabelası: şiş üstünde üç renkli top
			for k in 3:
				b.sphere(Vector3(x + 2.2, 5.4 - k * 0.42, f.call(0.4)), Vector3(0.4, 0.4, 0.4), [Color(1.0, 0.7, 0.75), Color(0.97, 0.95, 0.9), Color(0.55, 0.8, 0.45)][k], 8)
			b.box(Vector3(x + 2.2, 5.0, f.call(0.4)), Vector3(0.05, 1.8, 0.05), wood, yaw, false)
		"bbq":
			b.box(Vector3(x + w * 0.35, 6.0, f.call(-1.0)), Vector3(0.9, 4.0, 0.9), Color(0.4, 0.36, 0.34), yaw)  # baca
			b.box(Vector3(x + w * 0.35, 8.1, f.call(-1.0)), Vector3(1.2, 0.3, 1.2), Color(0.25, 0.22, 0.2), yaw, false)
			CityDecor.lantern_string(decor, b.w(Vector3(x - w * 0.4, 3.9, f.call(2.6))), b.w(Vector3(x + w * 0.4, 3.9, f.call(2.6))), 6, [Color(0.95, 0.25, 0.2), Color(1.0, 0.85, 0.5)])
			b.box(Vector3(x - w * 0.3, 0.5, f.call(1.2)), Vector3(1.4, 1.0, 0.9), Color(0.3, 0.3, 0.32), yaw)  # mangal
			b.box(Vector3(x - w * 0.3, 1.02, f.call(1.2)), Vector3(1.2, 0.04, 0.7), Color(0.85, 0.35, 0.15), yaw, false)
		"inn":
			# han kapısı: iki direk + kiremit çatı, saksı bambular, uzun fenerler
			var gn = f.call(4.0)
			for sx in [-1.0, 1.0]:
				b.box(Vector3(x + sx * 2.4, 1.8, gn), Vector3(0.35, 3.6, 0.35), wood, yaw)
				b.cyl(Vector3(x + sx * 3.4, 0.35, gn - dn * 0.3), 0.7, 0.7, Color(0.4, 0.3, 0.22), false, 8)
				for k in 4:
					b.cyl(Vector3(x + sx * 3.4 + (k % 2) * 0.15 - 0.07, 1.9, gn - dn * 0.3 + (k / 2) * 0.15 - 0.07), 0.08, 3.0, Color(0.45, 0.65, 0.3), false, 5)
			b.roof(Vector3(x, 3.6, gn), Vector3(6.2, 1.0, 1.4), Color(0.22, 0.3, 0.42), yaw + 90.0)
			b.box(Vector3(x, 3.3, gn), Vector3(5.2, 0.3, 0.3), wood, yaw, false)
	b.yoff = yo


## Konoha Hastanesi: geniş beyaz blok, öne çıkan giriş kulesi (kırmızı haç + 病院), kat bantları, pencere sıraları, giriş kanopisi,
## çatı korkuluğu + su depoları, yan kanat ve bağlantı koridoru, ön bahçe (saksılar, banklar, fenerler)
static func hospital(b: Builder, decor: Node3D, hx: float, hn: float, rng: RandomNumberGenerator) -> void:
	var yo = b.yoff
	b.yoff = _g(b, hx, hn)
	# anime (refs/konoha/Konoha_Hospital.png): açık leylak üç katlı gövde, mavi eğimli çatı, turuncu balkon bantları,
	# nane yeşili pencereler, girişte yeşil tabela + kırmızı 医 diski ve mavi saçak; çatıda soluk mavi kubbe,
	# turuncu külahlı kule (tepesinde top) ve turuncu şapkalı iki silindir kule; sağda alçak mor kanat.
	var white = Color(0.93, 0.9, 0.94)
	var grey = Color(0.78, 0.78, 0.8)
	var red = Color(0.82, 0.3, 0.2)
	var glass = Color(0.62, 0.86, 0.8)
	var blue = Color(0.28, 0.6, 0.74)
	var orange = Color(0.95, 0.66, 0.22)
	var lilac = Color(0.8, 0.76, 0.88)
	var fn = hn - 21.0
	b.box(Vector3(hx, 12, hn), Vector3(76, 24, 42), white)
	b.roof(Vector3(hx, 24.0, hn), Vector3(81, 6.0, 47), blue)
	b.box(Vector3(hx, 24.1, fn - 2.5), Vector3(81.4, 0.5, 0.6), blue.darkened(0.25), 0, false)   # saçak kenarı
	for k in 20:   # çatı sacı dikişleri (ön yüz)
		b.box(Vector3(hx - 38.0 + k * 4.0, 26.9, hn - 11.8), Vector3(0.2, 0.2, 24.2), blue.darkened(0.18), 0, false, Vector3(14.3, 0, 0))
	for i in 13:   # cephe payandaları (bölmeler)
		var bx = hx - 36.0 + i * 6.0
		if absf(bx - hx) < 8.0:
			continue
		b.box(Vector3(bx, 12.0, fn - 0.2), Vector3(0.7, 24.0, 0.5), white.lightened(0.04), 0, false)
	for fl in 3:
		var y = 4.2 + fl * 7.4
		for i in 12:
			var wx = hx - 33.0 + i * 6.0
			if absf(wx - hx) < 9.0:
				continue
			b.box(Vector3(wx, y, fn - 0.12), Vector3(2.9, 3.4, 0.3), Color(0.42, 0.66, 0.62), 0, false)
			b.box(Vector3(wx, y, fn - 0.25), Vector3(2.4, 2.9, 0.2), glass, 0, false)
			b.box(Vector3(wx, y, fn - 0.32), Vector3(0.14, 2.9, 0.2), Color(0.42, 0.66, 0.62), 0, false)
			if fl == 1:   # orta kat: kemerli pencere
				b.disc(Vector3(wx, y + 1.5, fn - 0.2), 2.9, 0.3, Color(0.42, 0.66, 0.62), 0.0, 12)
				b.disc(Vector3(wx, y + 1.5, fn - 0.3), 2.4, 0.3, orange, 0.0, 12)
			if fl > 0:    # üst katlarda turuncu balkon bandı
				b.box(Vector3(wx, y - 2.6, fn - 0.6), Vector3(5.0, 1.3, 1.1), orange, 0, false)
				b.box(Vector3(wx, y - 1.9, fn - 0.6), Vector3(5.1, 0.14, 1.2), orange.darkened(0.15), 0, false)
	for fl in 3:   # arka ve yan cepheler boş duvar kalmasın
		for i in 12:
			b.box(Vector3(hx - 33.0 + i * 6.0, 4.2 + fl * 7.4, hn + 21.12), Vector3(2.9, 3.4, 0.3), Color(0.42, 0.66, 0.62), 0, false)
			b.box(Vector3(hx - 33.0 + i * 6.0, 4.2 + fl * 7.4, hn + 21.2), Vector3(2.4, 2.9, 0.3), glass, 0, false)
		for i in 5:
			b.box(Vector3(hx - 38.12, 4.2 + fl * 7.4, hn - 14.0 + i * 7.0), Vector3(0.3, 3.4, 2.9), Color(0.42, 0.66, 0.62), 0, false)
			b.box(Vector3(hx - 38.2, 4.2 + fl * 7.4, hn - 14.0 + i * 7.0), Vector3(0.3, 2.9, 2.4), glass, 0, false)
		b.box(Vector3(hx, 1.6 + fl * 7.4 + 7.0, hn + 21.2), Vector3(76.4, 0.5, 0.5), orange, 0, false)
	# giriş bölümü: hafif öne çıkan blok, mavi saçak, yeşil tabela + 医 diski, altında hastane yazısı
	b.box(Vector3(hx, 10.0, fn - 3.0), Vector3(16, 20, 6), white.darkened(0.03))
	b.box(Vector3(hx, 17.0, fn - 6.1), Vector3(11, 5.0, 0.3), Color(0.78, 0.9, 0.86), 0, false)   # üst kat cam bandı
	b.box(Vector3(hx, 12.0, fn - 6.5), Vector3(19.0, 3.6, 0.6), Color(0.36, 0.7, 0.36), 0, false)
	b.box(Vector3(hx, 12.0, fn - 6.4), Vector3(19.8, 4.4, 0.4), Color(0.9, 0.8, 0.3), 0, false)
	b.disc(Vector3(hx, 12.8, fn - 6.7), 6.6, 0.5, Color(0.9, 0.8, 0.3), 0.0, 24)
	b.disc(Vector3(hx, 12.8, fn - 6.9), 5.8, 0.5, red, 0.0, 24)
	b.kanji(Vector3(hx, 12.8, fn - 7.2), "医", 3.4, red.darkened(0.45), 0.0)
	b.box(Vector3(hx, 8.6, fn - 10.5), Vector3(20.0, 0.5, 9.6), blue, 0, false, Vector3(-6.0, 0, 0))   # mavi saçak
	b.box(Vector3(hx, 8.1, fn - 15.2), Vector3(20.2, 0.5, 0.4), blue.darkened(0.25), 0, false)
	b.box(Vector3(hx, 6.6, fn - 6.3), Vector3(11.0, 1.7, 0.3), Color(0.3, 0.56, 0.36), 0, false)
	b.kanji(Vector3(hx, 6.6, fn - 6.5), "木ノ葉病院", 1.3, Color(0.92, 0.9, 0.7), 0.0)
	b.box(Vector3(hx, 2.4, fn - 6.2), Vector3(8.0, 4.8, 0.3), Color(0.5, 0.74, 0.88), 0, false)
	for dxk in [-2.0, 0.0, 2.0]:
		b.box(Vector3(hx + dxk, 2.4, fn - 6.3), Vector3(0.18, 4.8, 0.3), Color(0.3, 0.5, 0.62), 0, false)
	for sx in [-1.0, 1.0]:
		for sn in [-8.0, -14.5]:
			b.cyl(Vector3(hx + sx * 9.0, 4.0, fn + sn), 0.7, 8.0, white.darkened(0.08), true, 8)
	b.box(Vector3(hx, 0.25, fn - 9.0), Vector3(12.0, 0.5, 6.0), Color(0.72, 0.74, 0.8), 0, false)   # giriş basamağı
	b.box(Vector3(hx, 0.08, fn - 13.0), Vector3(14.0, 0.16, 3.0), Color(0.72, 0.74, 0.8), 0, false)
	# çatı üstü: soluk mavi kubbe (kasnaklı), sol uçta turuncu külah kule + top, sağda turuncu şapkalı iki silindir kule
	var rt = 27.0
	b.cyl(Vector3(hx - 10.0, rt + 2.0, hn + 4.0), 26.0, 5.0, Color(0.72, 0.86, 0.9), true, 24)
	for k in 24:
		var da = TAU * k / 24.0
		b.box(Vector3(hx - 10.0 + sin(da) * 13.05, rt + 2.4, hn + 4.0 - cos(da) * 13.05), Vector3(0.5, 3.2, 0.3), Color(0.56, 0.74, 0.82), -rad_to_deg(da), false)
	b.dome(Vector3(hx - 10.0, rt + 4.5, hn + 4.0), 25.0, 8.0, Color(0.74, 0.9, 0.94), 24)
	b.cyl(Vector3(hx - 31.0, rt + 1.0, hn + 4.0), 13.0, 6.0, white, true, 16)
	b.cone(Vector3(hx - 31.0, rt + 8.5, hn + 4.0), 17.0, 11.0, orange, 16)
	for k in 3:
		b.cyl(Vector3(hx - 31.0, rt + 6.6 + k * 2.6, hn + 4.0), 12.6 - k * 3.6, 0.5, orange.darkened(0.18), false, 16)
	b.sphere(Vector3(hx - 31.0, rt + 15.6, hn + 4.0), Vector3(5.2, 5.2, 5.2), orange.lightened(0.05))
	for t in 2:
		var tx = hx + 14.0 + t * 15.0
		var th = 9.0 + t * 5.0
		b.cyl(Vector3(tx, rt + th * 0.5 - 1.0, hn + 5.0), 10.0, th, lilac.lightened(0.08), true, 14)
		for k in 8:
			var wa = TAU * k / 8.0
			b.box(Vector3(tx + sin(wa) * 5.02, rt + th - 3.4, hn + 5.0 - cos(wa) * 5.02), Vector3(1.6, 2.2, 0.3), Color(0.5, 0.72, 0.8), -rad_to_deg(wa), false)
		b.cone(Vector3(tx, rt + th + 1.0, hn + 5.0), 13.5, 4.0, orange.darkened(0.08), 14)
		b.cyl(Vector3(tx, rt + th + 2.6, hn + 5.0), 4.0, 1.8, Color(0.86, 0.9, 0.94), false, 12)
	b.cyl(Vector3(hx + 21.5, rt + 1.6, hn + 12.0), 6.0, 4.2, Color(0.88, 0.92, 0.96), true, 14)   # su deposu
	# sağ kanat: alçak mor blok, düz çatı, turuncu bant, çatıda depolar + bağlantı koridoru
	b.box(Vector3(hx + 50, 10, hn + 4), Vector3(22, 20, 30), lilac)
	b.box(Vector3(hx + 50, 20.4, hn + 4), Vector3(23.5, 0.8, 31.5), lilac.darkened(0.22))
	b.box(Vector3(hx + 40.0, 12.0, hn - 4.0), Vector3(6.0, 4.0, 5.0), Color(0.78, 0.9, 0.86))
	b.box(Vector3(hx + 50, 10.6, hn - 11.3), Vector3(20.0, 1.2, 0.7), orange, 0, false)
	for fl in 2:
		for i in 2:
			b.box(Vector3(hx + 45.5 + i * 9.0, 6.4 + fl * 8.0, hn - 11.15), Vector3(2.8, 3.2, 0.3), Color(0.3, 0.56, 0.52), 0, false)
			b.box(Vector3(hx + 45.5 + i * 9.0, 6.4 + fl * 8.0, hn - 11.25), Vector3(2.2, 2.6, 0.3), glass, 0, false)
	for t in 2:
		b.cyl(Vector3(hx + 45.0 + t * 10.0, 22.4, hn + 8.0), 5.6, 3.6, Color(0.88, 0.92, 0.96), true, 12)
	# bahçe kapısı direkleri (tepesinde taş top)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(hx + sx * 7.5, 2.6, fn - 43.0), Vector3(2.0, 5.2, 2.0), Color(0.62, 0.74, 0.76))
		b.sphere(Vector3(hx + sx * 7.5, 6.0, fn - 43.0), Vector3(2.0, 2.0, 2.0), Color(0.66, 0.78, 0.8))
	b.kanji(Vector3(hx - 7.5, 3.0, fn - 44.05), "病院", 1.0, Color(0.2, 0.3, 0.34), 0.0)
	# ön avlu: taş döşeme, derzler, giriş yolu, ortada yuvarlak çiçeklik + ağaç
	var pav = Color(0.82, 0.8, 0.76)
	b.box(Vector3(hx, -0.5, fn - 21.0), Vector3(66.0, 1.12, 42.0), pav, 0, false)
	for k in 12:
		b.box(Vector3(hx - 30.0 + k * 5.5, 0.065, fn - 21.0), Vector3(0.1, 0.03, 41.0), pav.darkened(0.12), 0, false)
	b.box(Vector3(hx, 0.08, fn - 30.0), Vector3(7.0, 0.05, 24.0), pav.lightened(0.1), 0, false)
	b.cyl(Vector3(hx, 0.4, fn - 32.0), 9.0, 0.8, Color(0.7, 0.68, 0.66), true, 24)
	b.cyl(Vector3(hx, 0.83, fn - 32.0), 8.2, 0.1, Color(0.36, 0.26, 0.18), false, 24)   # taş halkanın üstünde (aynı yükseklikte titriyordu)
	for k in 10:
		var a = k * 36.0
		var q = Builder.rot(0, 3.4, a)
		b.sphere(Vector3(hx + q.x, 1.1, fn - 32.0 + q.y), Vector3(1.3, 0.9, 1.3), Color(0.26, 0.52, 0.26), 8)
	KageHall.tree(b, hx, fn - 32.0, 0.7, "green", rng, 1.1)
	if b.has_method("add_solid"):
		b.add_solid(b.w(Vector3(hx, 0, fn - 21.0)), 33.0, 21.0, 0.0)
	# ön bahçe: iki saksı (budanmış çalı + ağaç), banklar, fener
	for sx in [-1.0, 1.0]:
		KageHall.planter(b, hx + sx * 24.0, fn - 14.0, 18.0, 7.0, Color(0.7, 0.68, 0.66), "green", rng, 2)
		b.prop("bench", Vector3(hx + sx * 12.5, 0.0, fn - 19.0), 0.0, 0.0, 0.0)
		b.lantern(hx + sx * 11.0, fn - 22.0, 3.2)
	CityDecor.banner(decor, KageHall._gp(b, hx - 10.5, fn - 16.0), 0.0, Color(0.95, 0.95, 0.95), red)
	b.yoff = yo


## ANBU karargâhı: kalın koyu sur, demir çivili ağır kapı (暗部), meşaleler, iki katlı siyah çatılı ana bina, gözetleme kulesi,
## maske arması (beyaz disk + kırmızı çizgiler)
static func anbu(b: Builder, decor: Node3D, ax: float, an: float) -> void:
	var yo = b.yoff
	b.yoff = _g(b, ax, an)
	var wall = Color(0.24, 0.24, 0.27)
	var dark = Color(0.12, 0.12, 0.14)
	var tile = Color(0.08, 0.08, 0.1)
	# sur (güneyde kapı)
	b.wall_rect(ax, an + 2.0, 72.0, 52.0, 7.0, wall, 12.0)
	for sz in [-1.0, 1.0]:  # sur üstü kiremit
		b.box(Vector3(ax, 7.3, an + 2.0 + sz * 26.0), Vector3(73.0, 0.5, 2.0), tile, 0, false)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(ax + sx * 36.0, 7.3, an + 2.0), Vector3(2.0, 0.5, 53.0), tile, 0, false)
	# kapı: iki kule direk + üst kiriş + çatı + ağır kapı kanatları (açık)
	var gn = an + 2.0 - 26.0
	for sx in [-1.0, 1.0]:
		b.box(Vector3(ax + sx * 7.5, 5.0, gn), Vector3(3.0, 10.0, 3.0), wall.darkened(0.1))
		b.roof(Vector3(ax + sx * 7.5, 10.0, gn), Vector3(4.2, 1.6, 4.2), tile)
		b.box(Vector3(ax + sx * 4.6, 3.5, gn - 2.2), Vector3(0.4, 7.0, 4.6), Color(0.22, 0.14, 0.1), sx * 10.0)
		for k in 3:
			for j in 3:
				b.sphere(Vector3(ax + sx * 4.85, 1.6 + k * 2.0, gn - 0.8 - j * 1.2), Vector3(0.18, 0.18, 0.18), Color(0.5, 0.5, 0.52), 6)
		# meşale
		var tp = Vector3(ax + sx * 9.5, 3.4, gn - 1.8)
		b.cyl(tp, 0.15, 2.0, Color(0.3, 0.2, 0.12), false, 6)
		b.cone(tp + Vector3(0, 1.3, 0), 0.6, 0.8, Color(1.0, 0.55, 0.15), 8)
		Lights.add(b.w(tp + Vector3(0, 1.3, 0)))
	b.box(Vector3(ax, 9.4, gn), Vector3(18.0, 1.2, 2.4), dark, 0, false)
	b.roof(Vector3(ax, 10.0, gn), Vector3(20.0, 2.2, 3.4), tile)
	b.box(Vector3(ax, 8.0, gn - 1.3), Vector3(4.6, 1.6, 0.2), Color(0.9, 0.88, 0.84), 0, false)
	b.kanji(Vector3(ax, 8.0, gn - 1.45), "暗部", 1.3, Color(0.1, 0.1, 0.12), 0.0)
	# ana bina: iki kat, siyah kiremit çatılar, maske arması
	b.box(Vector3(ax, 5.0, an + 8.0), Vector3(40, 10, 24), wall)
	b.box(Vector3(ax, 10.4, an + 8.0), Vector3(44, 0.8, 28), dark, 0, false)
	b.box(Vector3(ax, 14.0, an + 10.0), Vector3(30, 7, 16), wall.lightened(0.04))
	b.roof(Vector3(ax, 17.5, an + 10.0), Vector3(34, 5, 20), tile)
	for i in 8:
		b.box(Vector3(ax - 17.5 + i * 5.0, 5.0, an - 4.15), Vector3(1.0, 2.6, 0.3), Color(0.05, 0.05, 0.06), 0, false)
	b.disc(Vector3(ax, 14.0, an + 1.9), 4.4, 0.3, Color(0.95, 0.95, 0.93), 0.0, 20)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(ax + sx * 0.8, 13.6, an + 1.7), Vector3(0.2, 1.4, 0.06), Color(0.75, 0.1, 0.12), 0, false, Vector3(0, 0, 25 * sx))
		b.box(Vector3(ax + sx * 0.9, 14.6, an + 1.7), Vector3(0.9, 0.3, 0.06), Color(0.1, 0.1, 0.12), 0, false, Vector3(0, 0, -12 * sx))
	b.box(Vector3(ax, 3.0, an - 4.15), Vector3(4.0, 6.0, 0.3), Color(0.08, 0.08, 0.09), 0, false)
	# gözetleme kulesi (köşe)
	var tx = ax + 30.0; var tn = an + 22.0
	b.box(Vector3(tx, 9.0, tn), Vector3(6, 18, 6), wall.darkened(0.06))
	b.box(Vector3(tx, 18.5, tn), Vector3(8, 1.0, 8), dark, 0, false)
	b.roof(Vector3(tx, 21.0, tn), Vector3(9, 3, 9), tile)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(tx + sx * 3.6, 19.8, tn), Vector3(0.25, 1.6, 7.6), dark, 0, false)
	# avlu: çakıl zemin, antrenman kütükleri, hedef tahtaları
	b.box(Vector3(ax, 0.05, an - 13.0), Vector3(60, 0.1, 16), Color(0.5, 0.5, 0.52), 0, false)
	for k in 4:
		b.cyl(Vector3(ax - 20.0 + k * 3.0, 0.9, an - 16.0), 0.6, 1.8, Color(0.4, 0.28, 0.18), true, 8)
	for k in 3:
		b.disc(Vector3(ax + 14.0 + k * 4.0, 1.6, an - 8.0), 1.6, 0.2, Color(0.9, 0.88, 0.84), 0.0, 14)
		b.disc(Vector3(ax + 14.0 + k * 4.0, 1.6, an - 8.12), 0.7, 0.2, Color(0.75, 0.15, 0.12), 0.0, 12)
	b.yoff = yo
