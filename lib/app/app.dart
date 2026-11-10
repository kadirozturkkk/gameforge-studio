import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../dashboard/dashboard_screen.dart';
import '../l10n/strings.dart';
import '../project/project_service.dart';
import 'app_settings.dart';
import 'theme.dart';

extension StringsContext on BuildContext {
  /// Strings for use inside `build` (rebuilds when the language changes).
  S get s => watch<AppSettings>().strings;

  /// Strings for use in callbacks.
  S get sRead => read<AppSettings>().strings;
}

class GameForgeApp extends StatelessWidget {
  const GameForgeApp({
    super.key,
    required this.service,
    required this.settings,
    this.startupWarnings = const [],
  });

  final ProjectService service;
  final AppSettings settings;

  /// Ids of projects that could not be read during start-up.
  final List<String> startupWarnings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProjectService>.value(value: service),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) => MaterialApp(
          title: 'GameForge Studio',
          debugShowCheckedModeBanner: false,
          theme: buildGfTheme(),
          locale: Locale(settings.language.name),
          supportedLocales: [for (final l in AppLanguage.values) Locale(l.name)],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DashboardScreen(brokenProjectCount: startupWarnings.length),
        ),
      ),
    );
  }
}
