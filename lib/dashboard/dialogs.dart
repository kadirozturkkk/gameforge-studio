import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../core/errors.dart';
import '../project/project_meta.dart';
import 'dashboard_screen.dart' show templateColor, templateIcon;

class NewProjectResult {
  NewProjectResult(this.name, this.template);
  final String name;
  final ProjectTemplate template;
}

Future<NewProjectResult?> showNewProjectDialog(BuildContext context,
    {ProjectTemplate? initialTemplate}) {
  return showDialog<NewProjectResult>(
    context: context,
    builder: (_) => _NewProjectDialog(initialTemplate: initialTemplate ?? ProjectTemplate.platformer),
  );
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.initialTemplate});
  final ProjectTemplate initialTemplate;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  late ProjectTemplate _template = widget.initialTemplate;
  late final TextEditingController _name;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'My Game');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final name = validateName(_name.text);
      Navigator.of(context).pop(NewProjectResult(name, _template));
    } on ValidationException catch (e) {
      setState(() => _error = context.sRead.validation(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.newProject),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('new_project_name'),
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: s.projectName, errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(s.chooseTemplate, style: const TextStyle(color: GfColors.textMuted)),
              const SizedBox(height: 8),
              for (final t in ProjectTemplate.values)
                RadioListTile<ProjectTemplate>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: t,
                  groupValue: _template,
                  onChanged: (v) => setState(() => _template = v ?? _template),
                  secondary: Icon(templateIcon(t), color: templateColor(t)),
                  title: Text(s.templateName(t)),
                  subtitle: Text(s.templateDescription(t),
                      style: const TextStyle(fontSize: 11, color: GfColors.textMuted)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(
            key: const ValueKey('new_project_create'),
            onPressed: _submit,
            child: Text(s.create)),
      ],
    );
  }
}

/// Asks for a name; validates with [validateName].
Future<String?> showNameDialog(BuildContext context,
    {required String title,
    required String label,
    required String initial,
    required String confirm}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _NameDialog(title: title, label: label, initial: initial, confirm: confirm),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog(
      {required this.title, required this.label, required this.initial, required this.confirm});
  final String title, label, initial, confirm;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.of(context).pop(validateName(_c.text));
    } on ValidationException catch (e) {
      setState(() => _error = context.sRead.validation(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('name_dialog_field'),
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(
            key: const ValueKey('name_dialog_confirm'),
            onPressed: _submit,
            child: Text(widget.confirm)),
      ],
    );
  }
}

Future<bool> showConfirmDialog(BuildContext context,
    {required String title,
    required String body,
    required String confirm,
    bool destructive = false}) async {
  final s = context.sRead;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
        FilledButton(
          key: const ValueKey('confirm_dialog_ok'),
          style: destructive ? FilledButton.styleFrom(backgroundColor: GfColors.danger) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Edits [meta.settings] in place. Returns true if the user saved.
Future<bool> showProjectSettingsDialog(BuildContext context, ProjectMeta meta) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ProjectSettingsDialog(meta: meta),
  );
  return result ?? false;
}

class _ProjectSettingsDialog extends StatefulWidget {
  const _ProjectSettingsDialog({required this.meta});
  final ProjectMeta meta;

  @override
  State<_ProjectSettingsDialog> createState() => _ProjectSettingsDialogState();
}

class _ProjectSettingsDialogState extends State<_ProjectSettingsDialog> {
  late final _w = TextEditingController(text: '${widget.meta.settings.referenceWidth}');
  late final _h = TextEditingController(text: '${widget.meta.settings.referenceHeight}');
  late final _ppu = TextEditingController(text: '${widget.meta.settings.pixelsPerUnit}');
  late ScreenOrientation _orientation = widget.meta.settings.orientation;
  String? _error;

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _ppu.dispose();
    super.dispose();
  }

  void _save() {
    final w = int.tryParse(_w.text.trim());
    final h = int.tryParse(_h.text.trim());
    final ppu = double.tryParse(_ppu.text.trim().replaceAll(',', '.'));
    final valid = w != null &&
        h != null &&
        ppu != null &&
        w >= 64 &&
        w <= 8192 &&
        h >= 64 &&
        h <= 8192 &&
        ppu > 0 &&
        ppu <= 1000;
    if (!valid) {
      setState(() => _error = context.sRead.invalidNumber);
      return;
    }
    final st = widget.meta.settings;
    st.referenceWidth = w;
    st.referenceHeight = h;
    st.pixelsPerUnit = ppu;
    st.orientation = _orientation;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text('${s.projectSettings} · ${widget.meta.name}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.referenceResolution, style: const TextStyle(color: GfColors.textMuted)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _w,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.width)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _h,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.height)),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<ScreenOrientation>(
              value: _orientation,
              decoration: InputDecoration(labelText: s.orientation),
              items: [
                DropdownMenuItem(value: ScreenOrientation.landscape, child: Text(s.landscape)),
                DropdownMenuItem(value: ScreenOrientation.portrait, child: Text(s.portrait)),
              ],
              onChanged: (v) => setState(() => _orientation = v ?? _orientation),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _ppu,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.pixelsPerUnit)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: GfColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
        FilledButton(onPressed: _save, child: Text(s.save)),
      ],
    );
  }
}
