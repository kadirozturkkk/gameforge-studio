import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'app/app_settings.dart';
import 'app/theme.dart';
import 'l10n/strings.dart';
import 'project/project_index.dart';
import 'project/project_service.dart';
import 'project/project_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  try {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'GameForgeProjects'));
    await root.create(recursive: true);
    final dbPath = p.join(await getDatabasesPath(), 'gameforge.db');
    final index = await ProjectIndex.open(databaseFactory, dbPath);
    final service = ProjectService(ProjectStorage(root), index);
    final broken = await service.syncIndexWithDisk();
    final systemLang = PlatformDispatcher.instance.locale.languageCode == 'tr'
        ? AppLanguage.tr
        : AppLanguage.en;
    final settings = await AppSettings.load(index, systemDefault: systemLang);
    runApp(GameForgeApp(service: service, settings: settings, startupWarnings: broken));
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(_StartupErrorApp(error: e));
  }
}

/// Shown if storage cannot be initialised (for example no disk space).
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildGfTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: GfColors.danger),
                const SizedBox(height: 16),
                const Text('GameForge Studio could not start / başlatılamadı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
