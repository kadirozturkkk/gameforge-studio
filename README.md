# GameForge Studio

Telefonda kod yazmadan 2D oyun yapmak için mobil oyun geliştirme ortamı (Flutter, Android + iOS).

- Mimari: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Durum raporu: [docs/STATUS.md](docs/STATUS.md)

## Uygulamayı telefona kurmak (Android)

1. Telefonunda GitHub'a giriş yap ve bu deponun **Releases** sayfasını aç.
2. En üstteki "GameForge Studio build N" sürümünden `GameForgeStudio.apk` dosyasını indir.
3. Dosyayı aç. Android "bilinmeyen kaynaklardan yükleme" izni isterse tarayıcına bu izni ver.
4. **Yükle**'ye bas.

Her `main` gönderiminde GitHub Actions şunları otomatik yapar: statik analiz → otomatik testler → APK derleme → yeni Release.
Testlerden biri başarısız olursa APK yayınlanmaz.

## Geliştiriciler için: yerelde derleme (Windows 11)

Gerekenler: Flutter SDK (stable), Android Studio (Android SDK + bir emülatör ya da USB hata ayıklaması açık bir telefon), Java 17.

```powershell
git clone https://github.com/kadirozturkkk/gameforge-studio
cd gameforge-studio
flutter create --platforms=android,ios --org com.gameforge --project-name gameforge_studio .
flutter pub get
flutter test          # otomatik testler
flutter run           # bağlı cihazda çalıştır
flutter build apk     # build/app/outputs/flutter-apk/app-release.apk
```

Masaüstünde `flutter test` çalıştırmak için SQLite gerekir (Windows'ta `sqlite3.dll`, Linux'ta `libsqlite3-dev`).

iOS derlemesi Apple kuralları gereği macOS + Xcode + Apple Developer hesabı gerektirir (`flutter build ios`).

## Proje yapısı

```
lib/core       güvenli dosya işlemleri, hatalar, kimlikler
lib/engine     saf Dart motor çekirdeği: GameObject, bileşenler, sahne, matematik
lib/project    proje formatı, SQLite dizini, şablonlar, içe/dışa aktarma
lib/dashboard  ana panel
lib/editor     sahne editörü (viewport, hiyerarşi, inspector, komutlar)
lib/l10n       Türkçe + İngilizce metinler
test/          birim ve widget testleri
```
