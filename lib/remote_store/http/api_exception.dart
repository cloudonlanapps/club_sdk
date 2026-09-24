import '../../sdk/exceptions/error_codes.dart';
import '../../sdk/exceptions/exceptions.dart';

/// Maps HTTP error responses to [ServerException].
///
/// The server returns errors in either format:
/// ```json
/// {"error": {"code": "ERROR_CODE", "message": "Human readable message"}}
/// {"detail": {"code": "ERROR_CODE", "message": "Human readable message"}}
/// {"detail": [{"loc": [...], "msg": "...", "type": "..."}]}
/// ```
ServerException mapHttpError(int statusCode, Map<String, dynamic> body) {
  Map<String, dynamic>? error;
  if (body['error'] is Map<String, dynamic>) {
    error = body['error'] as Map<String, dynamic>;
  } else if (body['detail'] is Map<String, dynamic>) {
    error = body['detail'] as Map<String, dynamic>;
  } else if (body['detail'] is String) {
    final detail = body['detail'] as String;
    error = {'code': inferCodeFromStatus(statusCode), 'message': detail};
  } else if (body['detail'] is List) {
    final details = body['detail'] as List;
    final messages = details
        .map((e) {
          if (e is Map<String, dynamic>) {
            return e['msg']?.toString() ?? e.toString();
          }
          return e.toString();
        })
        .join('; ');
    error = {'code': 'VALIDATION_ERROR', 'message': messages};
  }

  var code = error?['code'] as String? ?? '';
  var message = error?['message'] as String? ?? 'Unknown error';

  // A blocking programme clash on create / split / reinstate answers 409
  // with the conflict report itself as `detail` (`hasConflict`,
  // `venueConflicts`, `userConflicts`) and no code (#16). Give it one so
  // callers can branch, and keep the report in `details`.
  if (statusCode == 409 && code.isEmpty && error?['hasConflict'] == true) {
    code = SdkErrorCode.timeConflict;
    message = 'The schedule clashes with another programme';
  }

  // Preserve any extra structured fields the server returned alongside
  // `code` / `message` (e.g. `membernames` for MEMBERS_INELIGIBLE).
  Map<String, dynamic>? details;
  if (error != null) {
    final extras = <String, dynamic>{
      for (final entry in error.entries)
        if (entry.key != 'code' && entry.key != 'message')
          entry.key: entry.value,
    };
    if (extras.isNotEmpty) details = extras;
  }

  if (code == SdkErrorCode.staleVersion) {
    return StaleVersionException.fromDetails(message, details);
  }
  if (statusCode == 503 && SdkErrorCode.moduleDisabledCodes.contains(code)) {
    return ModuleDisabledException(
      code: code,
      message: message,
      details: details,
    );
  }

  return ServerException(
    statusCode: statusCode,
    code: code,
    message: message,
    details: details,
  );
}

/// Infers an SDK error code from the HTTP status code
/// when the server response doesn't include a structured code.
String inferCodeFromStatus(int statusCode) {
  switch (statusCode) {
    case 401:
      return SdkErrorCode.notAuthenticated;
    case 403:
      return SdkErrorCode.insufficientPermission;
    default:
      return '';
  }
}
