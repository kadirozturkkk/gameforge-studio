# Durum Raporu

## Aşama 1 — tamamlandı

**Yapılanlar**
- Modüler mimari: saf Dart motor çekirdeği (`engine/`), proje katmanı, arayüz katmanları. Bileşen kayıt sistemi ileride 3B türlerinin eklenmesine izin verir.
- Ana panel: yeni proje, 6 şablon (Platform, Üstten Görünüm, RPG, Sonsuz Koşu, Bulmaca, Boş), tüm projeler, son projeler, arama, sıralama, aç, yeniden adlandır, çoğalt, sil (onaylı), proje ayarları, `.gfproj` içe/dışa aktarma.
- Proje depolama: her proje kendi klasöründe; sürümlü ve doğrulanan JSON formatı; SQLite proje dizini ve ayarlar; diskten dizini yeniden kurma.
- Veri güvenliği: atomik yazma (geçici dosya + yeniden adlandırma), `.bak` yedekleri ve hasarlı dosyada otomatik kurtarma, kaydedilmemiş çalışma için kurtarma anlık görüntüleri (uygulama kapanınca/arka plana alınınca), "kaydedilmemiş değişiklik" uyarısı, daha yeni sürüm dosyalarının üzerine yazmama, zip-slip koruması.
- Temel sahne editörü: viewport (ızgara, kaydırma, iki parmakla yakınlaştırma, fare tekerleği), seçme ve taşıma araçları, dokunarak seçim, çoklu seçim, sürükleyerek taşıma, ızgaraya hizalama, geri al/yinele, kopyala/yapıştır/çoğalt/sil, seçime odaklanma, 8 nesne türü, birden çok sahne (oluştur/geçiş/sil/başlangıç sahnesi/ayarlar), kaydet/yükle, klavye kısayolları.
- Hiyerarşi (ağaç, görünürlük) ve Inspector (ad, etiket, katman, ebeveyn, Transform, Sprite Renderer, Camera 2D) — Aşama 2'nin bir kısmı erkenden geldi.
- Türkçe + İngilizce arayüz, koyu profesyonel tema, telefon ve tablet düzenleri.

**Testler:** 56 otomatik test (motor, serileştirme, proje yönetimi, SQLite, kurtarma, içe/dışa aktarma, editör komutları, widget testleri) — hepsi geçiyor.
**Derleme:** GitHub Actions'ta analiz + test + Android APK başarılı.

**Bilinen sınırlamalar**
- Görseller henüz şekil + renk; resim varlıkları Aşama 2'de.
- Döndürme/ölçekleme şimdilik Inspector'dan sayıyla; ekranda tutamaçlar Aşama 2'de.
- Bileşen ekleme/çıkarma Aşama 2'de.
- Oyunu oynatma (Play) Aşama 3'te; bu yüzden şu an Play düğmesi yok.
- Uygulama gerçek bir telefonda henüz elle denenmedi; testler sanal ortamda çalışıyor.

## Sıradaki: Aşama 2
Varlık yönetimi (PNG/JPG/ses içe aktarma, klasörler, önizleme, sahneye sürükleme), ekranda döndür/ölçekle tutamaçları, sürükle-bırak hiyerarşi, bileşen ekle/çıkar, Rigidbody/Collider bileşenlerinin veri modeli.
