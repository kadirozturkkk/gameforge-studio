import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/app_settings.dart';
import '../app/theme.dart';
import '../l10n/strings.dart';
import '../project/project_service.dart';

const appVersion = '0.1.0 (Phase 1)';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = context.watch<AppSettings>();
    final root = context.read<ProjectService>().storage.root.path;
    return Scaffold(
      appBar: AppBar(title: Text(s.appSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.language),
            trailing: SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.tr, label: Text('Türkçe')),
                ButtonSegment(value: AppLanguage.en, label: Text('English')),
              ],
              selected: {settings.language},
              onSelectionChanged: (v) => settings.setLanguage(v.first),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(s.storageLocation),
            subtitle: SelectableText(root,
                style: const TextStyle(fontSize: 12, color: GfColors.textMuted)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.version),
            subtitle: const Text(appVersion),
          ),
        ],
      ),
    );
  }
}
