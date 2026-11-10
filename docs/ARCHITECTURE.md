# GameForge Studio — Yazılım Mimarisi

Sürüm: 0.1 (Aşama 1) · Hedef platformlar: Android, iOS · Dil: Flutter/Dart

## 1. Temel ilkeler

1. **Motor, arayüzden bağımsızdır.** `lib/engine/` içindeki kod saf Dart'tır; Flutter widget'larına
   bağımlı değildir. Sahne modeli, bileşenler ve serileştirme hem editörde hem oyun çalıştırıcısında
   (runtime) hem de dışa aktarılan oyunlarda aynen kullanılır.
2. **Veri ile görüntü ayrıdır.** Editör bir `Scene` nesnesini düzenler; çizim (Flame veya Canvas)
   bu veriden üretilir. Böylece ileride 3B eklemek için yalnızca yeni bileşen türleri ve yeni bir
   renderer gerekir. Transform şimdilik 2B'dir, ama `Component` sistemi tür adına göre
   kayıt (registry) kullandığı için `Transform3D`, `MeshRenderer` gibi türler mevcut kodu bozmadan eklenebilir.
3. **Her değişiklik bir komuttur.** Editördeki tüm düzenlemeler `EditorCommand` nesneleridir
   (Command deseni). Geri al / yinele, otomatik kayıt ve "kaydedilmemiş değişiklik" takibi buradan gelir.
4. **Veri kaybı olmaz.** Her dosya önce geçici dosyaya yazılır, sonra atomik olarak yerine taşınır;
   eski sürüm `.bak` olarak saklanır. Açılışta bozuk dosya bulunursa yedekten kurtarılır.
5. **Sahte özellik yoktur.** Bir özellik henüz yoksa butonu da yoktur. Bir derleme gerçekten
   tamamlanmadıysa "başarılı" mesajı gösterilmez.

## 2. Katmanlar

```
lib/
  main.dart                  Uygulama girişi, servislerin kurulumu
  app/                       Tema (koyu, profesyonel), uygulama kabuğu
  l10n/                      Türkçe + İngilizce metinler, dil seçimi
  core/                      Ortak araçlar: güvenli dosya işlemleri, kimlik üretimi, hatalar
  engine/                    SAF DART motor çekirdeği
    math/                    Vec2 vb.
    scene/                   GameObject, Scene, hiyerarşi
    components/              Transform, SpriteRenderer, ... + ComponentRegistry
  project/                   Proje formatı ve proje yönetimi
    project_meta.dart        project.json modeli (sürümlü)
    project_storage.dart     Dosya düzeni, okuma/yazma, doğrulama, kurtarma
    project_index.dart       SQLite: proje listesi, son açılanlar, arama
    project_service.dart     Oluştur/aç/yeniden adlandır/çoğalt/sil/içe-dışa aktar
    templates.dart           6 şablonun başlangıç sahneleri
  dashboard/                 Unity Hub benzeri ana panel
  editor/                    Sahne editörü
    editor_controller.dart   Seçim, araçlar, geri al/yinele, pano, otomatik kayıt
    commands.dart            EditorCommand sınıfları
    widgets/                 Viewport, hiyerarşi, inspector, araç çubuğu
  (Aşama 3+) runtime/        Flame + Forge2D oyun çalıştırıcısı
  (Aşama 4+) scripting/      Görsel betik grafiği + yorumlayıcı
  (Aşama 5+) animation/, ui_designer/, audio/
  (Aşama 6+) build/          Dışa aktarma
```

Durum yönetimi: `ChangeNotifier` + `provider` paketi. Basit, kararlı, test edilmesi kolay.

## 3. Proje dosya formatı

Her proje, uygulamanın belge klasöründe kendi bağımsız klasörüne sahiptir:

```
GameForgeProjects/<proje-id>/
  project.json               Proje yapılandırması (formatVersion, ad, şablon, ayarlar)
  scenes/<sahne-id>.scene.json
  assets/                    İçe aktarılan görseller, sesler (kopyalanır, bağlantı değil)
  scripts/                   Görsel betik grafikleri (.graph.json)  — Aşama 4
  animations/                Animasyon klipleri (.anim.json)        — Aşama 5
  ui/                        Arayüz düzenleri                       — Aşama 5
  build/                     Derleme ayarları ve logları            — Aşama 6
  .recovery/                 Otomatik kayıt anlık görüntüleri
```

- `project.json` içinde `formatVersion` alanı vardır. Daha yeni bir sürümle kaydedilmiş proje açılmaz
  (uyarı verilir); eski sürümler `ProjectMigrator` ile yükseltilir.
- Tüm JSON dosyaları açılırken doğrulanır (zorunlu alanlar, türler, benzersiz kimlikler, geçerli ebeveyn bağları).
- **Neden JSON + SQLite?** Proje içeriği taşınabilir, okunabilir JSON dosyalarındadır: zip'lenip
  paylaşılabilir, bozulursa elle kurtarılabilir. SQLite (`gameforge.db`) ise proje listesi, son açılanlar,
  arama ve ileride varlık (asset) önbelleği gibi hızlı sorgular için kullanılır. SQLite dizini kaybolsa bile
  klasörler taranarak yeniden oluşturulabilir.
- İçe/dışa aktarma: proje klasörü `.gfproj` (zip) dosyası olarak paketlenir.

## 4. Oyun nesnesi ve bileşen modeli

```
Scene ── List<GameObject> (düz liste, parentId ile hiyerarşi)
GameObject: id, name, active(visible), layer, tag, parentId, order, components[]
Component (soyut): type, enabled, toJson()/fromJson()
  Transform        (her nesnede zorunlu: position, rotation, scale)
  SpriteRenderer   (Aşama 1'de renk + şekil; Aşama 2'de görsel varlık)
  Camera2D, Rigidbody2D, BoxCollider2D, ...  (sonraki aşamalar)
```

Bilinmeyen bir bileşen türüyle karşılaşılırsa veri `UnknownComponent` içinde **olduğu gibi korunur**;
daha yeni bir sürümde kaydedilmiş bileşenler silinmez.

## 5. Oyun çalıştırıcısı (Aşama 3)

Flame `FlameGame` içinde her `GameObject` bir Flame bileşenine dönüştürülür. Forge2D dünyası
Rigidbody/Collider bileşenlerinden kurulur. Görsel betik yorumlayıcısı her karede (frame) olayları işler.
Editördeki "Oynat" düğmesi sahnenin **kopyasını** çalıştırır; durdurunca editör sahnesi değişmeden kalır.

## 6. Dışa aktarma stratejisi (Aşama 6) — önemli kısıtlar

Bir telefon Android/Flutter derleme araç zincirini (Gradle, Android SDK, Dart derleyicisi) çalıştıramaz.
Bu nedenle GameForge, Godot'nun "export template" yaklaşımını kullanır:

1. Ayrı bir **GameForge Player** uygulaması önceden derlenir (aynı `engine/` + `runtime/` kodu).
2. "APK Dışa Aktar": Player APK şablonu kopyalanır, içine oyun paketi (sahneler + varlıklar) eklenir,
   uygulama adı / paket kimliği / ikon güncellenir ve APK cihazda kullanıcının anahtarıyla imzalanır.
3. **AAB (Google Play):** AAB üretimi `bundletool` gerektirir; cihazda desteklenmez. Studio, bilgisayarda
   tek komutla derlenebilen hazır bir proje klasörü üretir.
4. **iOS:** Apple kuralları gereği macOS + Xcode + Apple Developer hesabı (yıllık 99$) zorunludur.
   Studio bir Xcode proje paketi üretir ve gereksinimleri açıkça listeler.

Hiçbir durumda gerçek bir derleme tamamlanmadan "başarılı" mesajı gösterilmez.

## 7. Test ve sürekli entegrasyon

- `test/` altında birim testleri (motor, serileştirme, proje depolama, SQLite dizini, editör komutları) ve
  widget testleri bulunur.
- GitHub Actions her gönderimde: `flutter analyze` → `flutter test` → `flutter build apk`.
  APK, derleme çıktısı (artifact) olarak indirilebilir.

## 8. Yol haritası

| Aşama | Kapsam | Durum |
|---|---|---|
| 1 | Mimari, ana panel, proje oluşturma/yönetimi/depolama, temel sahne editörü | Devam ediyor |
| 2 | Hiyerarşi, nesne manipülasyonu (döndür/ölçekle, çoklu seçim), Inspector, bileşenler, varlık yönetimi | Bekliyor |
| 3 | Flame entegrasyonu, oyun çalıştırıcısı, oynat/duraklat, Forge2D fizik | Bekliyor |
| 4 | Görsel betik editörü, düğüm bağlantıları, yorumlayıcı | Bekliyor |
| 5 | Animasyon editörü, UI tasarımcısı, ses sistemi | Bekliyor |
| 6 | Android/iOS dışa aktarma | Bekliyor |
| 7 | Test kapsamı, performans, son kalite kontrol | Bekliyor |
