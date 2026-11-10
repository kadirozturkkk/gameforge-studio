import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../dashboard/dialogs.dart';
import '../engine/scene/presets.dart';
import '../l10n/strings.dart';
import '../project/project_service.dart';
import 'editor_controller.dart';
import 'editor_launcher.dart';
import 'widgets/hierarchy_panel.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/scene_viewport.dart';

enum _UnsavedChoice { save, discard, cancel }

/// The scene editor workspace: toolbar, viewport, hierarchy and inspector.
/// On wide screens panels sit beside the viewport; on phones they share a
/// collapsible bottom panel so the viewport keeps most of the screen.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.initialController});

  final EditorController initialController;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late EditorController _c = widget.initialController;
  final _viewportKey = GlobalKey<SceneViewportState>();
  final _focusNode = FocusNode(debugLabel: 'editor');
  bool _bottomPanelOpen = true;
  int _bottomTab = 0;
  Map<String, String> _sceneNames = {};
  bool _busy = false;

  ProjectService get _service => context.read<ProjectService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSceneNames();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.writeRecoveryNow();
    _c.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _c.writeRecoveryNow();
    }
  }

  Future<void> _loadSceneNames() async {
    final names = await _service.sceneNames(_c.project);
    if (mounted) setState(() => _sceneNames = names);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  // ---------------------------------------------------------------- saving

  Future<bool> _save() async {
    final s = context.sRead;
    final ok = await _c.save();
    if (!mounted) return ok;
    _snack(ok ? s.saved : '${s.saveFailed}: ${s.describeError(_c.lastSaveError!)}');
    if (ok) _loadSceneNames();
    return ok;
  }

  /// Returns true if it is OK to leave the current scene.
  Future<bool> _confirmLeave() async {
    if (!_c.isDirty) return true;
    final s = context.sRead;
    final choice = await showDialog<_UnsavedChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.unsavedChanges),
        content: Text(s.unsavedChangesBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(_UnsavedChoice.cancel), child: Text(s.cancel)),
          TextButton(
              key: const ValueKey('unsaved_discard'),
              onPressed: () => Navigator.of(ctx).pop(_UnsavedChoice.discard),
              child: Text(s.discard)),
          FilledButton(
              key: const ValueKey('unsaved_save'),
              onPressed: () => Navigator.of(ctx).pop(_UnsavedChoice.save),
              child: Text(s.save)),
        ],
      ),
    );
    switch (choice) {
      case _UnsavedChoice.save:
        return _save();
      case _UnsavedChoice.discard:
        await _c.discardChanges();
        return true;
      case _UnsavedChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _exit() async {
    if (await _confirmLeave() && mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- scenes

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(context.sRead.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchScene(String sceneId) async {
    if (sceneId == _c.scene.id) return;
    if (!await _confirmLeave() || !mounted) return;
    await _runBusy(() async {
      final next = await loadSceneController(context, _c.project, sceneId);
      if (next == null || !mounted) return;
      final old = _c;
      setState(() => _c = next);
      old.dispose();
    });
  }

  Future<void> _newScene() async {
    final s = context.sRead;
    final name = await showNameDialog(context,
        title: s.newScene, label: s.sceneName, initial: 'Scene ${_c.project.sceneOrder.length + 1}', confirm: s.create);
    if (name == null || !mounted) return;
    if (!await _confirmLeave() || !mounted) return;
    await _runBusy(() async {
      final scene = await _service.createScene(_c.project, name);
      await _loadSceneNames();
      if (!mounted) return;
      final next = await loadSceneController(context, _c.project, scene.id);
      if (next == null || !mounted) return;
      final old = _c;
      setState(() => _c = next);
      old.dispose();
    });
  }

  Future<void> _sceneSettings() async {
    final s = context.sRead;
    final nameCtrl = TextEditingController(text: _c.scene.name);
    var color = _c.scene.backgroundColor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.sceneSettings),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.sceneName)),
                const SizedBox(height: 12),
                Text(s.backgroundColor, style: const TextStyle(color: GfColors.textMuted)),
                const SizedBox(height: 8),
                ColorSwatches(selected: color, onSelect: (c) => setLocal(() => color = c)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.ok)),
          ],
        ),
      ),
    );
    final newName = nameCtrl.text;
    nameCtrl.dispose();
    if (ok != true) return;
    try {
      _c.updateSceneSettings(name: validateSceneName(newName), backgroundColor: color);
    } catch (e) {
      if (mounted) _snack(s.describeError(e));
    }
  }

  String validateSceneName(String raw) {
    final name = raw.trim();
    return name.isEmpty ? _c.scene.name : (name.length > 64 ? name.substring(0, 64) : name);
  }

  Future<void> _deleteScene() async {
    final s = context.sRead;
    final ok = await showConfirmDialog(context,
        title: s.deleteSceneTitle(_c.scene.name),
        body: s.deleteSceneBody,
        confirm: s.delete,
        destructive: true);
    if (!ok || !mounted) return;
    await _runBusy(() async {
      final deletedId = _c.scene.id;
      await _service.deleteScene(_c.project, deletedId);
      await _c.discardChanges();
      if (!mounted) return;
      final next = await loadSceneController(context, _c.project, _c.project.startSceneId);
      if (next == null || !mounted) return;
      final old = _c;
      setState(() => _c = next);
      old.dispose();
      await _loadSceneNames();
    });
  }

  Future<void> _setStartScene() async {
    await _runBusy(() async {
      _c.project.startSceneId = _c.scene.id;
      await _service.saveMeta(_c.project);
      if (mounted) _snack(context.sRead.saved);
    });
  }

  // ---------------------------------------------------------------- objects

  void _addObject(ObjectPreset p) {
    _c.addObject(p, S.defaultObjectName(p));
  }

  void _frame() {
    final size = _viewportKey.currentState?.size;
    if (size != null && size.width > 0) _c.frame(size.width, size.height);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => PopScope(
        canPop: !_c.isDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
        },
        child: CallbackShortcuts(
          bindings: _shortcuts(),
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: Scaffold(
              appBar: _appBar(s),
              body: Stack(children: [
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 840;
                  return wide ? _wideLayout(s) : _narrowLayout(s, constraints.maxHeight);
                }),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() => {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _c.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _c.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _c.redo,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _c.copySelection,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _c.paste,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _c.duplicateSelection,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): _c.selectAll,
        const SingleActivator(LogicalKeyboardKey.delete): _c.deleteSelection,
        const SingleActivator(LogicalKeyboardKey.keyF): _frame,
      };

  PreferredSizeWidget _appBar(S s) {
    final sceneTitle = _c.scene.name + (_c.isDirty ? ' •' : '');
    return AppBar(
      leading: IconButton(
        key: const ValueKey('editor_back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: _exit,
      ),
      titleSpacing: 0,
      title: PopupMenuButton<String>(
        key: const ValueKey('scene_menu'),
        tooltip: s.scenes,
        onSelected: (v) {
          if (v.startsWith('scene:')) {
            _switchScene(v.substring(6));
          } else if (v == 'new') {
            _newScene();
          } else if (v == 'settings') {
            _sceneSettings();
          } else if (v == 'start') {
            _setStartScene();
          } else if (v == 'delete') {
            _deleteScene();
          }
        },
        itemBuilder: (_) => [
          for (final id in _c.project.sceneOrder)
            PopupMenuItem(
              value: 'scene:$id',
              child: Row(children: [
                Icon(id == _c.scene.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(id == _c.scene.id ? _c.scene.name : (_sceneNames[id] ?? '…'),
                        overflow: TextOverflow.ellipsis)),
                if (id == _c.project.startSceneId)
                  const Icon(Icons.flag_outlined, size: 16, color: GfColors.success),
              ]),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'new', child: Text(s.newScene)),
          PopupMenuItem(value: 'settings', child: Text(s.sceneSettings)),
          PopupMenuItem(value: 'start', child: Text(s.setAsStartScene)),
          PopupMenuItem(
              value: 'delete',
              enabled: _c.project.sceneOrder.length > 1,
              child: Text(s.deleteScene)),
        ],
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sceneTitle, overflow: TextOverflow.ellipsis),
                Text(_c.project.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: GfColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
      actions: [
        IconButton(
            key: const ValueKey('editor_undo'),
            tooltip: s.undo,
            icon: const Icon(Icons.undo),
            onPressed: _c.canUndo ? _c.undo : null),
        IconButton(
            key: const ValueKey('editor_redo'),
            tooltip: s.redo,
            icon: const Icon(Icons.redo),
            onPressed: _c.canRedo ? _c.redo : null),
        IconButton(
            key: const ValueKey('editor_save'),
            tooltip: s.save,
            icon: Icon(Icons.save_outlined, color: _c.isDirty ? GfColors.accentOrange : null),
            onPressed: _save),
        PopupMenuButton<ObjectPreset>(
          key: const ValueKey('editor_add'),
          tooltip: s.addObject,
          icon: const Icon(Icons.add_box_outlined),
          onSelected: _addObject,
          itemBuilder: (_) => [
            for (final p in ObjectPreset.values)
              PopupMenuItem(
                key: ValueKey('add_${p.name}'),
                value: p,
                child: Row(children: [
                  Icon(objectIcon(p.name), size: 18),
                  const SizedBox(width: 10),
                  Text(s.presetName(p)),
                ]),
              ),
          ],
        ),
        PopupMenuButton<String>(
          key: const ValueKey('editor_more'),
          onSelected: (v) {
            switch (v) {
              case 'copy':
                _c.copySelection();
              case 'paste':
                _c.paste();
              case 'duplicate':
                _c.duplicateSelection();
              case 'delete':
                _c.deleteSelection();
              case 'selectAll':
                _c.selectAll();
              case 'grid':
                _c.toggleGrid();
              case 'snap':
                _c.toggleSnap();
              case 'frame':
                _frame();
            }
          },
          itemBuilder: (_) {
            final hasSel = _c.selection.isNotEmpty;
            return [
              PopupMenuItem(value: 'copy', enabled: hasSel, child: Text(s.copy)),
              PopupMenuItem(value: 'paste', enabled: _c.canPaste, child: Text(s.paste)),
              PopupMenuItem(
                  key: const ValueKey('menu_duplicate'),
                  value: 'duplicate',
                  enabled: hasSel,
                  child: Text(s.duplicate)),
              PopupMenuItem(
                  key: const ValueKey('menu_delete'),
                  value: 'delete',
                  enabled: hasSel,
                  child: Text(s.delete)),
              PopupMenuItem(value: 'selectAll', child: Text(s.selectAll)),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: 'grid', checked: _c.showGrid, child: Text(s.grid)),
              CheckedPopupMenuItem(value: 'snap', checked: _c.snapToGrid, child: Text(s.snapToGrid)),
              PopupMenuItem(value: 'frame', child: Text(s.frameSelection)),
            ];
          },
        ),
      ],
    );
  }

  Widget _viewportArea(S s) {
    return Stack(children: [
      Positioned.fill(child: SceneViewport(key: _viewportKey, controller: _c)),
      Positioned(
        left: 8,
        top: 8,
        child: _ToolStrip(children: [
          _toolButton(Icons.near_me_outlined, s.toolSelect, _c.tool == EditorTool.select,
              () => _c.setTool(EditorTool.select), const ValueKey('tool_select')),
          _toolButton(Icons.open_with, s.toolMove, _c.tool == EditorTool.move,
              () => _c.setTool(EditorTool.move), const ValueKey('tool_move')),
          const SizedBox(height: 6),
          _toolButton(Icons.grid_on, s.grid, _c.showGrid, _c.toggleGrid, const ValueKey('tool_grid')),
          _toolButton(Icons.grid_goldenratio, s.snapToGrid, _c.snapToGrid, _c.toggleSnap,
              const ValueKey('tool_snap')),
        ]),
      ),
      Positioned(
        right: 8,
        bottom: 8,
        child: _ToolStrip(children: [
          _toolButton(Icons.add, s.zoomIn, false, () => _c.zoomBy(1.25), const ValueKey('zoom_in')),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${(_c.zoom * 100).round()}%',
                style: const TextStyle(fontSize: 10, color: GfColors.textMuted)),
          ),
          _toolButton(Icons.remove, s.zoomOut, false, () => _c.zoomBy(0.8), const ValueKey('zoom_out')),
          _toolButton(Icons.center_focus_strong_outlined, s.frameSelection, false, _frame,
              const ValueKey('zoom_frame')),
        ]),
      ),
    ]);
  }

  Widget _toolButton(IconData icon, String tooltip, bool active, VoidCallback onTap, Key key) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active ? GfColors.selection : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 20, color: active ? Colors.white : GfColors.text),
        ),
      ),
    );
  }

  Widget _panelHeader(String title) => Container(
        height: 34,
        color: GfColors.panelHeader,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _wideLayout(S s) {
    return Row(children: [
      SizedBox(
        width: 250,
        child: Material(
          color: GfColors.panel,
          child: Column(children: [
            _panelHeader(s.hierarchy),
            Expanded(child: HierarchyPanel(controller: _c)),
          ]),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(child: _viewportArea(s)),
      const VerticalDivider(width: 1),
      SizedBox(
        width: 310,
        child: Material(
          color: GfColors.panel,
          child: Column(children: [
            _panelHeader(s.inspector),
            Expanded(child: InspectorPanel(controller: _c)),
          ]),
        ),
      ),
    ]);
  }

  Widget _narrowLayout(S s, double height) {
    final panelHeight = (height * 0.42).clamp(160.0, 420.0).toDouble();
    return Column(children: [
      Expanded(child: _viewportArea(s)),
      Container(
        color: GfColors.panelHeader,
        height: 40,
        child: Row(children: [
          _tabButton(s.hierarchy, 0, const ValueKey('tab_hierarchy')),
          _tabButton(s.inspector, 1, const ValueKey('tab_inspector')),
          const Spacer(),
          IconButton(
            key: const ValueKey('toggle_panel'),
            icon: Icon(_bottomPanelOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
            onPressed: () => setState(() => _bottomPanelOpen = !_bottomPanelOpen),
          ),
        ]),
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: _bottomPanelOpen ? panelHeight : 0,
        child: Material(
          color: GfColors.panel,
          child: _bottomPanelOpen
              ? IndexedStack(index: _bottomTab, children: [
                  HierarchyPanel(controller: _c),
                  InspectorPanel(controller: _c),
                ])
              : const SizedBox.shrink(),
        ),
      ),
    ]);
  }

  Widget _tabButton(String label, int index, Key key) {
    final selected = _bottomTab == index;
    return InkWell(
      key: key,
      onTap: () => setState(() {
        _bottomTab = index;
        _bottomPanelOpen = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: selected ? GfColors.accent : Colors.transparent, width: 2),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? GfColors.text : GfColors.textMuted)),
      ),
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GfColors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GfColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
