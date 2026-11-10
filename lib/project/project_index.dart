import 'package:sqflite/sqflite.dart';

import 'project_meta.dart';

/// One row of the project list shown on the dashboard.
class ProjectRecord {
  ProjectRecord({
    required this.id,
    required this.name,
    required this.template,
    required this.createdAt,
    required this.modifiedAt,
    this.lastOpenedAt,
  });

  final String id;
  final String name;
  final ProjectTemplate template;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime? lastOpenedAt;

  factory ProjectRecord.fromMeta(ProjectMeta m, {DateTime? lastOpenedAt}) => ProjectRecord(
        id: m.id,
        name: m.name,
        template: m.template,
        createdAt: m.createdAt,
        modifiedAt: m.modifiedAt,
        lastOpenedAt: lastOpenedAt,
      );
}

enum ProjectSort { lastModified, name, created }

/// SQLite database (`gameforge.db`) with the project list and app settings.
///
/// The project folders are the source of truth; this index can always be
/// rebuilt from them (see `ProjectService.syncIndexWithDisk`).
class ProjectIndex {
  ProjectIndex._(this._db);

  final Database _db;

  static const _schemaVersion = 1;

  static Future<ProjectIndex> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              template TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              modified_at INTEGER NOT NULL,
              last_opened_at INTEGER
            )''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )''');
        },
      ),
    );
    return ProjectIndex._(db);
  }

  Future<void> close() => _db.close();

  Future<void> upsert(ProjectMeta meta) async {
    final existing = await get(meta.id);
    await _db.insert(
      'projects',
      {
        'id': meta.id,
        'name': meta.name,
        'template': meta.template.name,
        'created_at': meta.createdAt.millisecondsSinceEpoch,
        'modified_at': meta.modifiedAt.millisecondsSinceEpoch,
        'last_opened_at': existing?.lastOpenedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String id) =>
      _db.delete('projects', where: 'id = ?', whereArgs: [id]);

  Future<void> markOpened(String id, DateTime when) => _db.update(
      'projects', {'last_opened_at': when.millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<ProjectRecord?> get(String id) async {
    final rows = await _db.query('projects', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<List<String>> allIds() async {
    final rows = await _db.query('projects', columns: ['id']);
    return [for (final r in rows) r['id'] as String];
  }

  /// Projects whose name contains [query] (case-insensitive).
  Future<List<ProjectRecord>> search(
      {String query = '', ProjectSort sort = ProjectSort.lastModified}) async {
    final orderBy = switch (sort) {
      ProjectSort.lastModified => 'modified_at DESC',
      ProjectSort.name => 'name COLLATE NOCASE ASC',
      ProjectSort.created => 'created_at DESC',
    };
    final q = query.trim();
    final rows = q.isEmpty
        ? await _db.query('projects', orderBy: orderBy)
        : await _db.query('projects',
            where: "name LIKE ? ESCAPE '\\'",
            whereArgs: ['%${_escapeLike(q)}%'],
            orderBy: orderBy);
    return rows.map(_fromRow).toList();
  }

  Future<List<ProjectRecord>> recent({int limit = 5}) async {
    final rows = await _db.query('projects',
        where: 'last_opened_at IS NOT NULL',
        orderBy: 'last_opened_at DESC',
        limit: limit);
    return rows.map(_fromRow).toList();
  }

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => _db.insert(
      'settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  static String _escapeLike(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  ProjectRecord _fromRow(Map<String, Object?> r) {
    final t = r['template'] as String;
    final opened = r['last_opened_at'] as int?;
    return ProjectRecord(
      id: r['id'] as String,
      name: r['name'] as String,
      template: ProjectTemplate.values
          .firstWhere((e) => e.name == t, orElse: () => ProjectTemplate.empty),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(r['modified_at'] as int),
      lastOpenedAt: opened == null ? null : DateTime.fromMillisecondsSinceEpoch(opened),
    );
  }
}
