import '../core/errors.dart';
import '../engine/scene/presets.dart';
import '../project/project_meta.dart';

enum AppLanguage { tr, en }

/// All user-facing text in Turkish and English. Every getter must provide
/// both languages, so a missing translation is a compile error.
class S {
  const S(this.lang);

  final AppLanguage lang;

  String _t(String tr, String en) => lang == AppLanguage.tr ? tr : en;

  // ---- general ----
  String get appName => 'GameForge Studio';
  String get ok => _t('Tamam', 'OK');
  String get cancel => _t('İptal', 'Cancel');
  String get create => _t('Oluştur', 'Create');
  String get save => _t('Kaydet', 'Save');
  String get delete => _t('Sil', 'Delete');
  String get rename => _t('Yeniden adlandır', 'Rename');
  String get duplicate => _t('Çoğalt', 'Duplicate');
  String get open => _t('Aç', 'Open');
  String get close => _t('Kapat', 'Close');
  String get name => _t('Ad', 'Name');
  String get settings => _t('Ayarlar', 'Settings');
  String get language => _t('Dil', 'Language');
  String get search => _t('Ara', 'Search');
  String get error => _t('Hata', 'Error');
  String get retry => _t('Tekrar dene', 'Retry');

  // ---- dashboard ----
  String get newProject => _t('Yeni Proje', 'New Project');
  String get openProject => _t('Projeyi Aç', 'Open Project');
  String get importProject => _t('Proje İçe Aktar', 'Import Project');
  String get exportProject => _t('Dışa Aktar (.gfproj)', 'Export (.gfproj)');
  String get projectSettings => _t('Proje Ayarları', 'Project Settings');
  String get recentProjects => _t('Son Projeler', 'Recent Projects');
  String get allProjects => _t('Tüm Projeler', 'All Projects');
  String get templates => _t('Şablonlar', 'Templates');
  String get searchProjects => _t('Projelerde ara…', 'Search projects…');
  String get noProjects =>
      _t('Henüz proje yok. Bir şablon seçerek başla.', 'No projects yet. Start from a template.');
  String get noSearchResults => _t('Sonuç bulunamadı.', 'No matching projects.');
  String get projectName => _t('Proje adı', 'Project name');
  String get chooseTemplate => _t('Şablon seç', 'Choose a template');
  String get sortBy => _t('Sırala', 'Sort');
  String get sortModified => _t('Son değişiklik', 'Last modified');
  String get sortName => _t('Ad', 'Name');
  String get sortCreated => _t('Oluşturulma', 'Created');
  String get modified => _t('Değiştirildi', 'Modified');
  String deleteProjectTitle(String n) => _t('"$n" silinsin mi?', 'Delete "$n"?');
  String get deleteProjectBody => _t(
      'Projenin tüm sahneleri ve dosyaları kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'All scenes and files of this project will be permanently deleted. This cannot be undone.');
  String copyName(String n) => _t('$n (kopya)', '$n (copy)');
  String get projectImported => _t('Proje içe aktarıldı', 'Project imported');
  String get projectExported => _t('Proje dışa aktarıldı', 'Project exported');
  String get projectRecovered => _t(
      'Proje dosyası hasarlıydı ve yedekten geri yüklendi.',
      'The project file was damaged and has been restored from its backup.');
  String brokenProjects(int n) => _t(
      '$n proje okunamadı ve listede gösterilmiyor.',
      '$n project(s) could not be read and are not listed.');
  String get referenceResolution => _t('Referans çözünürlük', 'Reference resolution');
  String get width => _t('Genişlik', 'Width');
  String get height => _t('Yükseklik', 'Height');
  String get orientation => _t('Ekran yönü', 'Orientation');
  String get landscape => _t('Yatay', 'Landscape');
  String get portrait => _t('Dikey', 'Portrait');
  String get pixelsPerUnit => _t('Birim başına piksel (fizik)', 'Pixels per unit (physics)');
  String get invalidNumber => _t('Geçersiz sayı', 'Invalid number');

  String templateName(ProjectTemplate t) => switch (t) {
        ProjectTemplate.platformer => _t('2D Platform', '2D Platformer'),
        ProjectTemplate.topDown => _t('2D Üstten Görünüm', '2D Top-Down'),
        ProjectTemplate.rpg => _t('2D RPG', '2D RPG'),
        ProjectTemplate.endlessRunner => _t('2D Sonsuz Koşu', '2D Endless Runner'),
        ProjectTemplate.puzzle => _t('2D Bulmaca', '2D Puzzle'),
        ProjectTemplate.empty => _t('Boş 2D Proje', 'Empty 2D Project'),
      };

  String templateDescription(ProjectTemplate t) => switch (t) {
        ProjectTemplate.platformer =>
          _t('Zemin, platformlar, oyuncu ve düşman', 'Ground, platforms, player and enemy'),
        ProjectTemplate.topDown =>
          _t('Duvarlarla çevrili arena, yerçekimi yok', 'Walled arena, no gravity'),
        ProjectTemplate.rpg => _t('Köy, ev, ağaçlar ve karakterler', 'Village, house, trees, NPCs'),
        ProjectTemplate.endlessRunner =>
          _t('Uzun zemin, koşucu ve engeller', 'Long ground, runner and obstacles'),
        ProjectTemplate.puzzle => _t('Dikey ekran, 4×4 karo tahtası', 'Portrait, 4×4 tile board'),
        ProjectTemplate.empty => _t('Sadece kamera', 'Camera only'),
      };

  // ---- editor ----
  String get hierarchy => _t('Hiyerarşi', 'Hierarchy');
  String get inspector => _t('Inspector', 'Inspector');
  String get scene => _t('Sahne', 'Scene');
  String get scenes => _t('Sahneler', 'Scenes');
  String get newScene => _t('Yeni sahne', 'New scene');
  String get sceneName => _t('Sahne adı', 'Scene name');
  String get renameScene => _t('Sahneyi yeniden adlandır', 'Rename scene');
  String get deleteScene => _t('Sahneyi sil', 'Delete scene');
  String deleteSceneTitle(String n) => _t('"$n" sahnesi silinsin mi?', 'Delete scene "$n"?');
  String get deleteSceneBody => _t(
      'Sahne ve içindeki tüm nesneler kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'The scene and all of its objects will be permanently deleted. This cannot be undone.');
  String get startScene => _t('Başlangıç sahnesi', 'Start scene');
  String get setAsStartScene => _t('Başlangıç sahnesi yap', 'Set as start scene');
  String get addObject => _t('Nesne ekle', 'Add object');
  String get undo => _t('Geri al', 'Undo');
  String get redo => _t('Yinele', 'Redo');
  String get copy => _t('Kopyala', 'Copy');
  String get paste => _t('Yapıştır', 'Paste');
  String get selectAll => _t('Tümünü seç', 'Select all');
  String get grid => _t('Izgara', 'Grid');
  String get snapToGrid => _t('Izgaraya hizala', 'Snap to grid');
  String get gridSize => _t('Izgara boyutu', 'Grid size');
  String get frameSelection => _t('Seçime odaklan', 'Frame selection');
  String get zoomIn => _t('Yakınlaştır', 'Zoom in');
  String get zoomOut => _t('Uzaklaştır', 'Zoom out');
  String get toolSelect => _t('Seç', 'Select');
  String get toolMove => _t('Taşı', 'Move');
  String get saved => _t('Kaydedildi', 'Saved');
  String get saveFailed => _t('Kaydedilemedi', 'Save failed');
  String get unsavedChanges => _t('Kaydedilmemiş değişiklikler', 'Unsaved changes');
  String get unsavedChangesBody => _t(
      'Sahnede kaydedilmemiş değişiklikler var. Kaydetmek ister misin?',
      'This scene has unsaved changes. Do you want to save them?');
  String get discard => _t('Kaydetme', "Don't save");
  String get recoveryTitle => _t('Kaydedilmemiş çalışma bulundu', 'Unsaved work found');
  String get recoveryBody => _t(
      'Bu sahnede uygulama kapanmadan önce kaydedilmemiş değişiklikler vardı. Geri yüklensin mi?',
      'This scene had unsaved changes when the app closed. Restore them?');
  String get restore => _t('Geri yükle', 'Restore');
  String get ignore => _t('Yok say', 'Ignore');
  String get noSelection => _t('Düzenlemek için bir nesne seç.', 'Select an object to edit it.');
  String multipleSelected(int n) => _t('$n nesne seçili', '$n objects selected');
  String get emptyScene => _t('Sahne boş. + ile nesne ekle.', 'Scene is empty. Add objects with +.');
  String get makeRoot => _t('En üst seviyeye taşı', 'Move to top level');
  String get setParent => _t('Ebeveyn seç…', 'Set parent…');
  String get chooseParent => _t('Ebeveyn nesne seç', 'Choose parent object');
  String get noParent => _t('(Ebeveyn yok)', '(No parent)');
  String get sceneSettings => _t('Sahne ayarları', 'Scene settings');
  String get backgroundColor => _t('Arka plan rengi', 'Background colour');
  String get sceneMissing => _t('Sahne açılamadı.', 'The scene could not be opened.');

  // inspector
  String get active => _t('Aktif (görünür)', 'Active (visible)');
  String get tag => _t('Etiket', 'Tag');
  String get layer => _t('Katman', 'Layer');
  String get transform => _t('Transform', 'Transform');
  String get position => _t('Konum', 'Position');
  String get rotation => _t('Döndürme', 'Rotation');
  String get scale => _t('Ölçek', 'Scale');
  String get spriteRenderer => _t('Sprite Renderer', 'Sprite Renderer');
  String get camera2d => _t('Kamera 2D', 'Camera 2D');
  String get size => _t('Boyut', 'Size');
  String get color => _t('Renk', 'Colour');
  String get shape => _t('Şekil', 'Shape');
  String get sortingOrder => _t('Çizim sırası', 'Sorting order');
  String get flipX => _t('Yatay çevir', 'Flip X');
  String get flipY => _t('Dikey çevir', 'Flip Y');
  String get zoom => _t('Yakınlık', 'Zoom');
  String get mainCamera => _t('Ana kamera', 'Main camera');
  String get unknownComponent =>
      _t('Bu sürümün tanımadığı bileşen (veri korunuyor)', 'Unknown component (data is preserved)');

  String shapeName(String s) => switch (s) {
        'rectangle' => _t('Dikdörtgen', 'Rectangle'),
        'circle' => _t('Daire', 'Circle'),
        'triangle' => _t('Üçgen', 'Triangle'),
        _ => s,
      };

  String presetName(ObjectPreset p) => switch (p) {
        ObjectPreset.empty => _t('Boş Nesne', 'Empty Object'),
        ObjectPreset.sprite => _t('Sprite', 'Sprite'),
        ObjectPreset.character => _t('Karakter', 'Character'),
        ObjectPreset.enemy => _t('Düşman', 'Enemy'),
        ObjectPreset.platform => _t('Platform', 'Platform'),
        ObjectPreset.wall => _t('Duvar', 'Wall'),
        ObjectPreset.background => _t('Arka Plan', 'Background'),
        ObjectPreset.camera => _t('Kamera', 'Camera'),
      };

  /// English default object names (engine convention, stable in projects).
  static String defaultObjectName(ObjectPreset p) => switch (p) {
        ObjectPreset.empty => 'GameObject',
        ObjectPreset.sprite => 'Sprite',
        ObjectPreset.character => 'Player',
        ObjectPreset.enemy => 'Enemy',
        ObjectPreset.platform => 'Platform',
        ObjectPreset.wall => 'Wall',
        ObjectPreset.background => 'Background',
        ObjectPreset.camera => 'Camera',
      };

  // ---- settings ----
  String get appSettings => _t('Uygulama Ayarları', 'App Settings');
  String get about => _t('Hakkında', 'About');
  String get version => _t('Sürüm', 'Version');
  String get storageLocation => _t('Proje klasörü', 'Projects folder');

  // ---- errors ----
  String validation(ValidationError e) => switch (e) {
        ValidationError.nameEmpty => _t('Ad boş olamaz.', 'Name cannot be empty.'),
        ValidationError.nameTooLong =>
          _t('Ad en fazla 64 karakter olabilir.', 'Name can be at most 64 characters.'),
        ValidationError.nameInvalidCharacters =>
          _t('Ad şu karakterleri içeremez: < > : " / \\ | ? *',
              'Name cannot contain: < > : " / \\ | ? *'),
        ValidationError.projectNotFound => _t('Proje bulunamadı.', 'Project not found.'),
        ValidationError.sceneNotFound => _t('Sahne bulunamadı.', 'Scene not found.'),
        ValidationError.unsupportedFormatVersion => _t(
            'Bu proje GameForge Studio\'nun daha yeni bir sürümüyle kaydedilmiş. Uygulamayı güncelle.',
            'This project was saved with a newer version of GameForge Studio. Please update.'),
        ValidationError.invalidPackage =>
          _t('Dosya geçerli bir GameForge projesi değil.', 'The file is not a valid GameForge project.'),
        ValidationError.lastScene =>
          _t('Projenin son sahnesi silinemez.', 'The last scene of a project cannot be deleted.'),
      };

  String describeError(Object e) {
    if (e is ValidationException) return validation(e.code);
    if (e is DataFormatException) {
      return _t('Dosya okunamadı veya hasarlı: ${e.message}',
          'File is unreadable or damaged: ${e.message}');
    }
    return _t('Beklenmeyen hata: $e', 'Unexpected error: $e');
  }
}
