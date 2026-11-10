import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../editor/editor_launcher.dart';
import '../project/project_index.dart';
import '../project/project_meta.dart';
import '../project/project_service.dart';
import '../settings/settings_screen.dart';
import 'dashboard_controller.dart';
import 'dialogs.dart';

/// Unity Hub style start screen: projects, templates, import.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.brokenProjectCount = 0});

  final int brokenProjectCount;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = DashboardController(context.read<ProjectService>())..refresh();
    if (widget.brokenProjectCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _snack(context.sRead.brokenProjects(widget.brokenProjectCount));
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  ProjectService get _service => _c.service;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(context.sRead.describeError(e));
    }
    await _c.refresh();
  }

  // ---------------------------------------------------------------- actions

  Future<void> _newProject({ProjectTemplate? template}) async {
    final result = await showNewProjectDialog(context, initialTemplate: template);
    if (result == null) return;
    await _guard(() async {
      final meta = await _service.createProject(result.name, result.template);
      if (mounted) await openProjectInEditor(context, meta.id);
    });
  }

  Future<void> _open(ProjectRecord p) =>
      _guard(() => openProjectInEditor(context, p.id));

  Future<void> _rename(ProjectRecord p) async {
    final s = context.sRead;
    final name = await showNameDialog(context,
        title: s.rename, label: s.projectName, initial: p.name, confirm: s.rename);
    if (name == null) return;
    await _guard(() => _service.rename(p.id, name));
  }

  Future<void> _duplicate(ProjectRecord p) async {
    final s = context.sRead;
    final name = await showNameDialog(context,
        title: s.duplicate, label: s.projectName, initial: s.copyName(p.name), confirm: s.duplicate);
    if (name == null) return;
    await _guard(() => _service.duplicate(p.id, name));
  }

  Future<void> _delete(ProjectRecord p) async {
    final s = context.sRead;
    final ok = await showConfirmDialog(context,
        title: s.deleteProjectTitle(p.name),
        body: s.deleteProjectBody,
        confirm: s.delete,
        destructive: true);
    if (!ok) return;
    await _guard(() => _service.delete(p.id));
  }

  Future<void> _settings(ProjectRecord p) async {
    await _guard(() async {
      final meta = (await _service.openProject(p.id)).value;
      if (!mounted) return;
      final changed = await showProjectSettingsDialog(context, meta);
      if (changed) await _service.saveMeta(meta);
    });
  }

  Future<void> _export(ProjectRecord p) async {
    final s = context.sRead;
    await _guard(() async {
      final bytes = await _service.exportPackage(p.id);
      final fileName = '${p.name.replaceAll(RegExp(r'[^\w\- ]'), '_')}.${ProjectService.packageExtension}';
      // file_picker 11 writes [bytes] itself on Android/iOS.
      final Object? target = await FilePicker.saveFile(
        dialogTitle: s.exportProject,
        fileName: fileName,
        bytes: bytes,
      );
      if (target == null) return; // cancelled
      if (!Platform.isAndroid && !Platform.isIOS) {
        final path = target is Uri ? target.toFilePath() : target.toString();
        await File(path).writeAsBytes(bytes, flush: true);
      }
      if (mounted) _snack(s.projectExported);
    });
  }

  Future<void> _import() async {
    final s = context.sRead;
    await _guard(() async {
      final result = await FilePicker.pickFiles(type: FileType.any, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
      if (bytes == null) return;
      await _service.importPackage(bytes);
      if (mounted) _snack(s.projectImported);
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.hexagon_outlined, color: GfColors.accentOrange),
          const SizedBox(width: 8),
          Text(s.appName),
        ]),
        actions: [
          IconButton(
            tooltip: s.importProject,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _import,
          ),
          IconButton(
            tooltip: s.appSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newProject(),
        icon: const Icon(Icons.add),
        label: Text(s.newProject),
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _c.refresh,
          child: CustomScrollView(
            slivers: [
              _sectionTitle(s.templates),
              SliverToBoxAdapter(child: _templatesRow()),
              if (_c.recent.isNotEmpty) ...[
                _sectionTitle(s.recentProjects),
                SliverToBoxAdapter(child: _recentRow()),
              ],
              _sectionTitle(s.allProjects, trailing: _sortMenu()),
              SliverToBoxAdapter(child: _searchField()),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              ..._projectList(),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? trailing}) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
          child: Row(children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: GfColors.textMuted)),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _templatesRow() {
    final s = context.s;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: ProjectTemplate.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = ProjectTemplate.values[i];
          return SizedBox(
            width: 170,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('template_${t.name}'),
                onTap: () => _newProject(template: t),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(templateIcon(t), color: templateColor(t), size: 28),
                      const Spacer(),
                      Text(s.templateName(t),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s.templateDescription(t),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: GfColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _c.setQuery,
          decoration: InputDecoration(
            hintText: context.s.searchProjects,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _c.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _c.setQuery('');
                    },
                  ),
          ),
        ),
      );

  Widget _sortMenu() {
    final s = context.s;
    String label(ProjectSort v) => switch (v) {
          ProjectSort.lastModified => s.sortModified,
          ProjectSort.name => s.sortName,
          ProjectSort.created => s.sortCreated,
        };
    return PopupMenuButton<ProjectSort>(
      tooltip: s.sortBy,
      initialValue: _c.sort,
      onSelected: _c.setSort,
      itemBuilder: (_) => [
        for (final v in ProjectSort.values) PopupMenuItem(value: v, child: Text(label(v))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sort, size: 18, color: GfColors.textMuted),
          const SizedBox(width: 4),
          Text(label(_c.sort), style: const TextStyle(fontSize: 12, color: GfColors.textMuted)),
        ]),
      ),
    );
  }

  Widget _recentRow() => SizedBox(
        height: 64,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _c.recent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = _c.recent[i];
            return ActionChip(
              avatar: Icon(templateIcon(p.template), size: 18, color: templateColor(p.template)),
              label: Text(p.name),
              onPressed: () => _open(p),
            );
          },
        ),
      );

  List<Widget> _projectList() {
    final s = context.s;
    if (_c.loading && _c.projects.isEmpty) {
      return [
        const SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
      ];
    }
    if (_c.error != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(s.describeError(_c.error!), textAlign: TextAlign.center),
              TextButton(onPressed: _c.refresh, child: Text(s.retry)),
            ]),
          ),
        )
      ];
    }
    if (_c.projects.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(_c.query.isEmpty ? s.noProjects : s.noSearchResults,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GfColors.textMuted)),
            ),
          ),
        )
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 76,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _projectCard(_c.projects[i]),
            childCount: _c.projects.length,
          ),
        ),
      ),
    ];
  }

  Widget _projectCard(ProjectRecord p) {
    final s = context.s;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('project_${p.id}'),
        onTap: () => _open(p),
        child: Row(children: [
          Container(
            width: 56,
            color: templateColor(p.template).withValues(alpha: 0.18),
            alignment: Alignment.center,
            child: Icon(templateIcon(p.template), color: templateColor(p.template)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${s.templateName(p.template)} · ${formatDate(p.modifiedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: GfColors.textMuted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('project_menu_${p.id}'),
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _open(p);
                case 'rename':
                  _rename(p);
                case 'duplicate':
                  _duplicate(p);
                case 'settings':
                  _settings(p);
                case 'export':
                  _export(p);
                case 'delete':
                  _delete(p);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'open', child: Text(s.openProject)),
              PopupMenuItem(value: 'rename', child: Text(s.rename)),
              PopupMenuItem(value: 'duplicate', child: Text(s.duplicate)),
              PopupMenuItem(value: 'settings', child: Text(s.projectSettings)),
              PopupMenuItem(value: 'export', child: Text(s.exportProject)),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(s.delete, style: const TextStyle(color: GfColors.danger))),
            ],
          ),
        ]),
      ),
    );
  }
}

IconData templateIcon(ProjectTemplate t) => switch (t) {
      ProjectTemplate.platformer => Icons.directions_run,
      ProjectTemplate.topDown => Icons.grid_view,
      ProjectTemplate.rpg => Icons.castle_outlined,
      ProjectTemplate.endlessRunner => Icons.fast_forward,
      ProjectTemplate.puzzle => Icons.extension_outlined,
      ProjectTemplate.empty => Icons.crop_square,
    };

Color templateColor(ProjectTemplate t) => switch (t) {
      ProjectTemplate.platformer => const Color(0xFF4C8DFF),
      ProjectTemplate.topDown => const Color(0xFF46A758),
      ProjectTemplate.rpg => const Color(0xFFE0A458),
      ProjectTemplate.endlessRunner => const Color(0xFFFF8A3D),
      ProjectTemplate.puzzle => const Color(0xFFB57EDC),
      ProjectTemplate.empty => const Color(0xFF9A9CA5),
    };

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
