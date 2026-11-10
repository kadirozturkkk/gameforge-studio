import '../core/errors.dart';
import '../core/json_read.dart';

enum ProjectTemplate { platformer, topDown, rpg, endlessRunner, puzzle, empty }

enum ScreenOrientation { landscape, portrait }

/// Per-project settings (shown in "Project Settings").
class ProjectSettings {
  ProjectSettings({
    this.referenceWidth = 1280,
    this.referenceHeight = 720,
    this.orientation = ScreenOrientation.landscape,
    this.pixelsPerUnit = 32,
  });

  int referenceWidth;
  int referenceHeight;
  ScreenOrientation orientation;

  /// World units per physics metre (used by Forge2D in Phase 3).
  double pixelsPerUnit;

  Map<String, dynamic> toJson() => {
        'referenceWidth': referenceWidth,
        'referenceHeight': referenceHeight,
        'orientation': orientation.name,
        'pixelsPerUnit': pixelsPerUnit,
      };

  factory ProjectSettings.fromJson(Map<String, dynamic> json) {
    int clampRes(int v, int fallback) => (v >= 64 && v <= 8192) ? v : fallback;
    final ppu = json.optDouble('pixelsPerUnit', 32);
    final o = json.optString('orientation', ScreenOrientation.landscape.name);
    return ProjectSettings(
      referenceWidth: clampRes(json.optInt('referenceWidth', 1280), 1280),
      referenceHeight: clampRes(json.optInt('referenceHeight', 720), 720),
      orientation: ScreenOrientation.values
          .firstWhere((e) => e.name == o, orElse: () => ScreenOrientation.landscape),
      pixelsPerUnit: ppu > 0 ? ppu : 32,
    );
  }
}

/// Contents of `project.json`.
class ProjectMeta {
  ProjectMeta({
    required this.id,
    required this.name,
    required this.template,
    required this.createdAt,
    required this.modifiedAt,
    required this.startSceneId,
    required this.sceneOrder,
    ProjectSettings? settings,
    this.formatVersion = currentFormatVersion,
  }) : settings = settings ?? ProjectSettings();

  /// Increase when the on-disk format changes; add a migration step in
  /// [ProjectMeta.fromJson] for older versions.
  static const currentFormatVersion = 1;

  final String id;
  String name;
  final ProjectTemplate template;
  final DateTime createdAt;
  DateTime modifiedAt;
  String startSceneId;

  /// Scene ids in the order shown in the editor.
  final List<String> sceneOrder;
  final ProjectSettings settings;
  final int formatVersion;

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'engine': 'GameForge Studio',
        'id': id,
        'name': name,
        'template': template.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'modifiedAt': modifiedAt.toUtc().toIso8601String(),
        'startSceneId': startSceneId,
        'sceneOrder': sceneOrder,
        'settings': settings.toJson(),
      };

  factory ProjectMeta.fromJson(Map<String, dynamic> json) {
    final version = json.optInt('formatVersion', 0);
    if (version < 1) throw DataFormatException('Missing formatVersion');
    if (version > currentFormatVersion) {
      throw ValidationException(ValidationError.unsupportedFormatVersion);
    }
    // Migrations from older versions go here (none yet).
    DateTime date(String key) =>
        DateTime.tryParse(json.optString(key, ''))?.toLocal() ?? DateTime.now();
    final t = json.optString('template', ProjectTemplate.empty.name);
    final order = [
      for (final s in json.optList('sceneOrder'))
        if (s is String && s.isNotEmpty) s
    ];
    return ProjectMeta(
      id: json.reqString('id'),
      name: json.reqString('name'),
      template: ProjectTemplate.values
          .firstWhere((e) => e.name == t, orElse: () => ProjectTemplate.empty),
      createdAt: date('createdAt'),
      modifiedAt: date('modifiedAt'),
      startSceneId: json.optString('startSceneId', order.isEmpty ? '' : order.first),
      sceneOrder: order,
      settings: ProjectSettings.fromJson(json.optMap('settings')),
      formatVersion: currentFormatVersion,
    );
  }
}

/// Validates and normalises a user supplied project or scene name.
String validateName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) throw ValidationException(ValidationError.nameEmpty);
  if (name.length > 64) throw ValidationException(ValidationError.nameTooLong);
  if (RegExp(r'[\x00-\x1F\x7F<>:"/\\|?*]').hasMatch(name)) {
    throw ValidationException(ValidationError.nameInvalidCharacters);
  }
  return name;
}
