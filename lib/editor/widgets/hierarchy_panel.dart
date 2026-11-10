import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../engine/scene/game_object.dart';
import '../editor_controller.dart';

IconData objectIcon(String kind) => switch (kind) {
      'sprite' => Icons.image_outlined,
      'character' => Icons.person_outline,
      'enemy' => Icons.pest_control_outlined,
      'platform' => Icons.horizontal_rule,
      'wall' => Icons.view_column_outlined,
      'background' => Icons.wallpaper,
      'camera' => Icons.videocam_outlined,
      _ => Icons.circle_outlined,
    };

/// Tree of scene objects. Tap selects, long-press adds to the selection,
/// the eye toggles visibility.
class HierarchyPanel extends StatefulWidget {
  const HierarchyPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  State<HierarchyPanel> createState() => _HierarchyPanelState();
}

class _HierarchyPanelState extends State<HierarchyPanel> {
  final Set<String> _collapsed = {};

  List<(GameObject, int)> _flatten() {
    final scene = widget.controller.scene;
    final out = <(GameObject, int)>[];
    void walk(String? parentId, int depth) {
      for (final o in scene.childrenOf(parentId)) {
        out.add((o, depth));
        if (!_collapsed.contains(o.id)) walk(o.id, depth + 1);
      }
    }

    walk(null, 0);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final rows = _flatten();
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.emptyScene,
                  textAlign: TextAlign.center, style: const TextStyle(color: GfColors.textMuted)),
            ),
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemExtent: 36,
          itemBuilder: (context, i) {
            final (o, depth) = rows[i];
            final selected = c.isSelected(o.id);
            final hasChildren = c.scene.objects.any((x) => x.parentId == o.id);
            final activeInHierarchy = c.scene.isActiveInHierarchy(o);
            return Material(
              color: selected ? GfColors.selection.withValues(alpha: 0.35) : Colors.transparent,
              child: InkWell(
                key: ValueKey('hierarchy_${o.id}'),
                onTap: () => c.select(o.id),
                onLongPress: () => c.select(o.id, additive: true),
                child: Row(children: [
                  SizedBox(width: 6.0 + depth * 14),
                  SizedBox(
                    width: 22,
                    child: hasChildren
                        ? InkWell(
                            onTap: () => setState(() {
                              if (!_collapsed.remove(o.id)) _collapsed.add(o.id);
                            }),
                            child: Icon(
                                _collapsed.contains(o.id)
                                    ? Icons.chevron_right
                                    : Icons.expand_more,
                                size: 18),
                          )
                        : null,
                  ),
                  Icon(objectIcon(o.kind), size: 16, color: GfColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: activeInHierarchy ? GfColors.text : GfColors.textMuted),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('hierarchy_visibility_${o.id}'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: Icon(o.active ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: o.active ? GfColors.textMuted : GfColors.border),
                    onPressed: () => c.editObject(o.id, (x) => x.active = !x.active),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
