# Çeviri (İngilizce) — durum

Durum: 2026-11-15 akşam. Katalog `godot/data/i18n/en.json` (12 bin yazı, hepsi çevrili).

## Bitenler
- Dil sistemi (`core/lang.gd`), Ayarlar'da dil seçici, veri yazıları, hikâye hedefleri.
- Koddaki bütün ekran yazıları çevrildi: `py tools/i18n_extract.py` Türkçe karakterli yalnız 5 teknik kalıp bırakıyor
  (ünlü dizileri, `yol|düğüm`, `hücre|mesh`: çevrilmez). Kalan ~1400 yazı romaji ad, kemik / düğüm adı, hata ayıklama satırı.
- Birleştirilerek kurulan ekran yazıları parça parça `Lang.t()` ile çevrildi: Gardırop istatistik satırı, Yetenekler
  (temel kombo açıklaması, ustalıkla açılanlar), İlişkiler (aile, durum, konum, çocuk satırı), büyük harfli başlıklar
  (`Lang.upper(Lang.t(...))`), karakter yaratma özet kartı.
- Testler: `tests/test_lang.gd` (menüler, 6 ninja sekmesi, 0 çevrilmemiş) ve `tests/test_lang_creator.gd` (karakter yaratma + seçicilerde gezinti, 0 çevrilmemiş).

## Dikkat (yeni yazı eklerken)
- Biçimli yazıda yer tutucu SIRASI kaynakla aynı olmalı (`%s %d` → çeviride de aynı sıra); şablon eşlemesi sıraya göre doldurur.
- Birleştirilen yazıyı (`"a" + x + "b"`) tek parça çevirmek olmaz: parçaları ayrı ayrı `Lang.t()` ile sar.
- Yeni yazı ekledikten sonra `py tools/i18n_extract.py`, çevir, `en.json`'a ekle (LF, anahtarlar sıralı, sondaki satır sonu yok).

## Denenmedi
- NPC konuşmaları ve 3B dünya yazıları (isim etiketleri, hasar yazıları) oyun içinde İngilizce gözle denenmedi;
  kodda sabit yazılar katalogda, ama çalışma anında birleştirilen cümleler kalmış olabilir (oyunda görülünce yukarıdaki yöntemle düzelt).
