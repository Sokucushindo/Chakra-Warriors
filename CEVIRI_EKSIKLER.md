# Çeviri (İngilizce) — kalan eksikler

Durum: 2026-11-15, commit `a041f062` sonrası.

## Hazır olanlar
- Dil sistemi: `godot/scripts/core/lang.gd` (Godot çeviri sunucusuna bağlı; Label / Button kendiliğinden çevrilir,
  sayı / isim içeren yazılar `%s` / `%d` şablonuyla eşlenir, çok satırlı yazılar satır satır çevrilir).
- Ayarlar'da dil seçici, açılışta dil uygulanır, veri yazıları (jutsu / eşya / klan / yetenek açıklamaları) ve hikâye hedefleri dil değişince yenilenir.
- Katalog: `godot/data/i18n/en.json` — 8821 yazı, hepsi çevrili (boş yok). Exe paketine giriyor (`export_presets.cfg`).
- `godot/tests/test_lang.gd` geçiyor (0 hata): duraklatma, ayarlar, kontroller, ana menü, envanter, jutsu, görevler sekmeleri tamamen İngilizce.

## Kalanlar
`py tools/i18n_extract.py` → 4637 çevrilmemiş yazı (`_tmp/i18n_eksik.json`, 150'lik parçalar `_tmp/i18n_kod_NN.json`).
Bunların ~2744'ü Türkçe karakterli (kesin çevrilecek); geri kalanı çoğunlukla romaji ad (Katon, Tora, Nodachi…) ya da
kemik / düğüm adı (Hips, LeftHand…) — bunlar çevrilmez, gözden geçirip atla.

### 1. Kod içindeki yazılar (öncelik sırasıyla, Türkçe karakterli yazı sayısı)
| Dosya | Adet | Ne |
|---|---|---|
| core/legend_paths.gd | 402 | efsane yolları: ad, açıklama, görünüş tarifleri |
| core/gear.gd | 345 | silah / ekipman adları ve açıklamaları |
| combat/path_jutsu.gd | 309 | yol jutsuları açıklamaları |
| core/striker_sets.gd | 212 | dövüş setleri |
| actors/character_model.gd | 192 | saç / yüz / kıyafet seçenek adları (karakter yaratma, gardırop) |
| combat/fighting_styles.gd | 85 | dövüş stilleri |
| actors/anime_hair.gd | 81 | saç stili adları |
| core/world_akatsuki.gd, world_jubi.gd, world_people.gd, world_kin.gd | 59 / 47 / 43 / 40 | dünya olayları, aile / akraba yazıları |
| diğer 115 dosya | <40'ar | buffs, missions, legacy, swordsmen, summon, clan_jutsu, elements… |

### 2. Testte görülen çevrilmemiş ekran yazıları (birleştirilerek kurulan yazılar — şablon eklenmeli)
- Gardırop: `Savunma +5  •  Can +10  •  Hız +3%  •  Silah 4.2 hasar`, `Sıradan   •   takılı`
- Yetenekler: temel kombo açıklaması, `Ustalıkla açılanlar: · kai (Chakra Kontrolü 20) …`
- İlişkiler: `Ailesi: Babası …, Annesi …`, `Baban: Tatsuo — görevde (köy dışında) (tıkla: haritada göster)`, Annen / Ablan satırları
  → Bu yazılar `+` ile parça parça birleştiriliyor; parçaları ayrı ayrı `tr()` / `Lang.t()` ile sarmak ya da `%s` biçimli yazıya çevirmek gerek.

### 3. Veri dosyaları
`py tools/i18n_data.py` → 9 yazı kaldı, hepsi romaji (Kenjutsu, Ninjutsu, Kai!…): çevrilmesi gerekmiyor.

### 4. Denenmedi
- Konuşmalar (NPC diyalogları, görev konuşmaları) ve 3B dünya yazıları (isim etiketleri, hasar yazıları) testte yok.
  Konuşma sistemi dil dosyasına bağlandı ama oyun içinde İngilizce konuşma denenmedi.
- Karakter yaratma ekranı testte yok.

## Çalışma akışı
1. `py tools/i18n_extract.py` → `_tmp/i18n_kod_NN.json` parçalarını çevir (değer boş, karşısına İngilizcesi yazılır).
2. Çevrilenleri `godot/data/i18n/en.json` içine ekle (anahtar = Türkçe yazı aynen; `%s`, `%d`, `\n` korunur).
3. Jutsu / örgüt / eşya adları romaji kalır; yalnız açıklama ve konuşma çevrilir.
4. `py tools/gdcheck.py`, sonra `test_lang.gd` koşusu (CLAUDE.md'deki komutla).
