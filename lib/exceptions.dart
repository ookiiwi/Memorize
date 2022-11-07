class UnauthorizedAccessException implements Exception {}

class PrivilegedSessionReachedException implements Exception {}

class InvalidCredentialsException implements Exception {
  final Map<String, String> errors;

  const InvalidCredentialsException(this.errors);
}

class UnknownException implements Exception {
  final String message;

  const UnknownException(this.message);
}

class InitiateWithValidSessionException implements Exception {
  final String message;

  const InitiateWithValidSessionException(this.message);
}

class OriginalFlowExpiredException implements Exception {
  final String message;

  const OriginalFlowExpiredException(this.message);
}

class MissingAuthorityException implements Exception {
  final String message;

  const MissingAuthorityException(this.message);
}
