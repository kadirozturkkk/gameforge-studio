import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'errors.dart';

/// Result of reading a file that may have been restored from its backup.
class RecoverableRead<T> {
  RecoverableRead(this.value, {required this.recoveredFromBackup});

  final T value;
  final bool recoveredFromBackup;
}

/// Crash-safe file operations.
///
/// Writes go to a temporary file first and are then renamed over the target,
/// so a crash mid-write never leaves a half-written file behind. The previous
/// version of the file is kept as `<name>.bak` and used for recovery.
class SafeFile {
  SafeFile._();

  static const _encoder = JsonEncoder.withIndent('  ');

  static File backupOf(File file) => File('${file.path}.bak');

  static Future<void> writeString(File file, String content,
      {bool keepBackup = true}) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (keepBackup && await file.exists()) {
      await file.copy(backupOf(file).path);
    }
    await tmp.rename(file.path);
  }

  static Future<void> writeJson(File file, Map<String, dynamic> json,
      {bool keepBackup = true}) {
    return writeString(file, _encoder.convert(json), keepBackup: keepBackup);
  }

  /// Reads and parses a JSON file. If the file is missing or corrupt, the
  /// backup is tried; a successful backup read also repairs the main file.
  static Future<RecoverableRead<T>> readJson<T>(
      File file, T Function(Map<String, dynamic> json) parse) async {
    Object? firstError;
    try {
      return RecoverableRead(await _parseFile(file, parse),
          recoveredFromBackup: false);
    } on ValidationException {
      // Readable but unsupported (e.g. saved by a newer version): never
      // replace it with an older backup.
      rethrow;
    } catch (e) {
      firstError = e;
    }
    final backup = backupOf(file);
    if (await backup.exists()) {
      try {
        final value = await _parseFile(backup, parse);
        await backup.copy(file.path);
        return RecoverableRead(value, recoveredFromBackup: true);
      } catch (_) {
        // Fall through to the original error.
      }
    }
    if (firstError is DataFormatException) throw firstError;
    throw DataFormatException(firstError.toString(), path: file.path);
  }

  static Future<T> _parseFile<T>(
      File file, T Function(Map<String, dynamic> json) parse) async {
    if (!await file.exists()) {
      throw DataFormatException('File not found', path: file.path);
    }
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw DataFormatException('Root is not a JSON object', path: file.path);
    }
    return parse(decoded);
  }

  /// Deletes a file together with its backup and temp file.
  static Future<void> delete(File file) async {
    for (final f in [file, backupOf(file), File('${file.path}.tmp')]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Recursively copies [source] into [target] (which must not exist).
  static Future<void> copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        await copyDirectory(entity, Directory(p.join(target.path, name)));
      } else if (entity is File) {
        await entity.copy(p.join(target.path, name));
      }
    }
  }
}
