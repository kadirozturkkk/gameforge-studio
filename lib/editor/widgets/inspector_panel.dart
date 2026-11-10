import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../engine/components/camera2d.dart';
import '../../engine/components/component.dart';
import '../../engine/components/sprite_renderer.dart';
import '../../engine/components/transform2d.dart';
import '../../engine/scene/game_object.dart';
import '../editor_controller.dart';

const kPalette = <int>[
  0xFFFFFFFF, 0xFF9A9CA5, 0xFF56606E, 0xFF1B1C1F,
  0xFFE5484D, 0xFFFF8A3D, 0xFFFFC53D, 0xFF46A758,
  0xFF2F7D32, 0xFF4C8DFF, 0xFF2E4A62, 0xFFB57EDC,
  0xFF8B5E3C, 0xFFB59B6A, 0xFF22313F, 0xFF3B5D3A,
];

/// Shows and edits the selected object's properties and components.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        if (sel.isEmpty) {
          return _message(s.noSelection);
        }
        if (sel.length > 1) {
          return _message(s.multipleSelected(sel.length));
        }
        final o = controller.primarySelection;
        if (o == null) return _message(s.noSelection);
        return _ObjectInspector(key: ValueKey(o.id), controller: controller, object: o);
      },
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text,
              textAlign: TextAlign.center, style: const TextStyle(color: GfColors.textMuted)),
        ),
      );
}

class _ObjectInspector extends StatelessWidget {
  const _ObjectInspector({super.key, required this.controller, required this.object});

  final EditorController controller;
  final GameObject object;

  void _edit(void Function(GameObject o) f) => controller.editObject(object.id, f);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final o = object;
    final scene = controller.scene;
    final parentCandidates =
        scene.objects.where((x) => !scene.isInSubtree(x.id, o.id)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Section(
          title: o.kind.toUpperCase(),
          children: [
            Row(children: [
              Checkbox(
                key: const ValueKey('inspector_active'),
                value: o.active,
                onChanged: (v) => _edit((x) => x.active = v ?? true),
              ),
              Expanded(
                child: TextCommitField(
                  key: const ValueKey('inspector_name'),
                  value: o.name,
                  label: s.name,
                  onCommit: (v) {
                    final name = v.trim();
                    if (name.isNotEmpty) _edit((x) => x.name = name);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextCommitField(
                    value: o.tag,
                    label: s.tag,
                    onCommit: (v) => _edit((x) => x.tag = v.trim().isEmpty ? 'Untagged' : v.trim())),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextCommitField(
                    value: o.layer,
                    label: s.layer,
                    onCommit: (v) => _edit((x) => x.layer = v.trim().isEmpty ? 'Default' : v.trim())),
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey('inspector_parent_${o.parentId}'),
              value: o.parentId,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.setParent.replaceAll('…', '')),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s.noParent)),
                for (final p in parentCandidates)
                  DropdownMenuItem<String?>(
                      value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => controller.setParent(o.id, v),
            ),
          ],
        ),
        for (final comp in o.components) _componentSection(context, comp),
      ],
    );
  }

  Widget _componentSection(BuildContext context, Component comp) {
    final s = context.s;
    if (comp is Transform2D) {
      return _Section(title: s.transform, children: [
        _vecRow(s.position, comp.position.x, comp.position.y,
            (v) => _edit((x) => x.transform.position = x.transform.position.withX(v)),
            (v) => _edit((x) => x.transform.position = x.transform.position.withY(v)),
            keyPrefix: 'pos'),
        _vecRow(s.rotation, comp.rotation, null,
            (v) => _edit((x) => x.transform.rotation = v), null,
            keyPrefix: 'rot'),
        _vecRow(s.scale, comp.scale.x, comp.scale.y,
            (v) => _edit((x) => x.transform.scale = x.transform.scale.withX(v)),
            (v) => _edit((x) => x.transform.scale = x.transform.scale.withY(v)),
            keyPrefix: 'scale'),
      ]);
    }
    if (comp is SpriteRenderer) {
      void editR(void Function(SpriteRenderer r) f) =>
          _edit((x) => f(x.getComponent<SpriteRenderer>()!));
      return _Section(title: s.spriteRenderer, children: [
        _vecRow(s.size, comp.size.x, comp.size.y,
            (v) => editR((r) => r.size = r.size.withX(v.abs())),
            (v) => editR((r) => r.size = r.size.withY(v.abs())),
            keyPrefix: 'size'),
        const SizedBox(height: 6),
        Text(s.color, style: const TextStyle(fontSize: 12, color: GfColors.textMuted)),
        const SizedBox(height: 6),
        ColorSwatches(selected: comp.color, onSelect: (c) => editR((r) => r.color = c)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<SpriteShape>(
              value: comp.shape,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.shape),
              items: [
                for (final sh in SpriteShape.values)
                  DropdownMenuItem(value: sh, child: Text(s.shapeName(sh.name))),
              ],
              onChanged: (v) {
                if (v != null) editR((r) => r.shape = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: NumberCommitField(
                value: comp.sortingOrder.toDouble(),
                label: s.sortingOrder,
                integer: true,
                onCommit: (v) => editR((r) => r.sortingOrder = v.round())),
          ),
        ]),
        Row(children: [
          Expanded(
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.flipX),
              value: comp.flipX,
              onChanged: (v) => editR((r) => r.flipX = v ?? false),
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.flipY),
              value: comp.flipY,
              onChanged: (v) => editR((r) => r.flipY = v ?? false),
            ),
          ),
        ]),
      ]);
    }
    if (comp is Camera2D) {
      void editC(void Function(Camera2D c) f) => _edit((x) => f(x.getComponent<Camera2D>()!));
      return _Section(title: s.camera2d, children: [
        NumberCommitField(
            value: comp.zoom,
            label: s.zoom,
            onCommit: (v) {
              if (v > 0) editC((c) => c.zoom = v);
            }),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(s.mainCamera),
          value: comp.isMain,
          onChanged: (v) => editC((c) => c.isMain = v ?? true),
        ),
      ]);
    }
    return _Section(title: comp.type, children: [
      Text(s.unknownComponent, style: const TextStyle(color: GfColors.textMuted)),
    ]);
  }

  Widget _vecRow(String label, double x, double? y, ValueChanged<double> onX,
      ValueChanged<double>? onY,
      {required String keyPrefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12, color: GfColors.textMuted))),
        Expanded(
          child: NumberCommitField(
              key: ValueKey('inspector_${keyPrefix}_x'), value: x, label: y == null ? '' : 'X', onCommit: onX),
        ),
        if (y != null && onY != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: NumberCommitField(
                key: ValueKey('inspector_${keyPrefix}_y'), value: y, label: 'Y', onCommit: onY),
          ),
        ],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GfColors.border))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: GfColors.text, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({super.key, required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in kPalette)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Color(c),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: (c & 0xFFFFFFFF) == (selected & 0xFFFFFFFF)
                      ? GfColors.accentOrange
                      : GfColors.border,
                  width: (c & 0xFFFFFFFF) == (selected & 0xFFFFFFFF) ? 2.5 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Text field that commits on submit or when it loses focus, and follows
/// external value changes (undo/redo) while not being edited.
class TextCommitField extends StatefulWidget {
  const TextCommitField(
      {super.key, required this.value, required this.label, required this.onCommit, this.keyboardType, this.inputFormatters});

  final String value;
  final String label;
  final ValueChanged<String> onCommit;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<TextCommitField> createState() => _TextCommitFieldState();
}

class _TextCommitFieldState extends State<TextCommitField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(TextCommitField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _c.text != widget.value) _c.text = widget.value;
  }

  void _commit() {
    if (_c.text != widget.value) widget.onCommit(_c.text);
    // If the value was rejected (or normalised), show the real value again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus && _c.text != widget.value) _c.text = widget.value;
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: widget.label.isEmpty ? null : widget.label),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// Numeric variant of [TextCommitField]. Invalid input is reverted.
class NumberCommitField extends StatelessWidget {
  const NumberCommitField(
      {super.key, required this.value, required this.label, required this.onCommit, this.integer = false});

  final double value;
  final String label;
  final ValueChanged<double> onCommit;
  final bool integer;

  static String format(double v, bool integer) {
    if (integer) return v.round().toString();
    final r = (v * 1000).round() / 1000;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TextCommitField(
      value: format(value, integer),
      label: label,
      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
      onCommit: (text) {
        final v = double.tryParse(text.trim().replaceAll(',', '.'));
        if (v != null && v.isFinite) onCommit(integer ? v.roundToDouble() : v);
      },
    );
  }
}
