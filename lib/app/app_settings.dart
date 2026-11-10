import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../project/project_index.dart';

/// App-wide preferences, persisted in the SQLite settings table.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._index, this._language);

  final ProjectIndex? _index;
  AppLanguage _language;

  static const _languageKey = 'language';

  static Future<AppSettings> load(ProjectIndex index, {AppLanguage? systemDefault}) async {
    final stored = await index.getSetting(_languageKey);
    final lang = AppLanguage.values.firstWhere((l) => l.name == stored,
        orElse: () => systemDefault ?? AppLanguage.tr);
    return AppSettings._(index, lang);
  }

  /// In-memory settings for tests.
  factory AppSettings.memory([AppLanguage language = AppLanguage.tr]) =>
      AppSettings._(null, language);

  AppLanguage get language => _language;
  S get strings => S(_language);

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    await _index?.setSetting(_languageKey, language.name);
  }
}
