import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new unique identifier for projects, scenes and objects.
String newId() => _uuid.v4();
