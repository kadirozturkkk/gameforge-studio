/// Error types shared across GameForge Studio.
library;

/// Thrown when stored data cannot be read or fails validation.
class DataFormatException implements Exception {
  DataFormatException(this.message, {this.path});

  final String message;
  final String? path;

  @override
  String toString() =>
      path == null ? 'DataFormatException: $message' : 'DataFormatException ($path): $message';
}

/// Thrown when user input (for example a project name) is invalid.
class ValidationException implements Exception {
  ValidationException(this.code);

  /// Machine readable reason, translated by the UI.
  final ValidationError code;

  @override
  String toString() => 'ValidationException: ${code.name}';
}

enum ValidationError {
  nameEmpty,
  nameTooLong,
  nameInvalidCharacters,
  projectNotFound,
  sceneNotFound,
  unsupportedFormatVersion,
  invalidPackage,
  lastScene,
}
