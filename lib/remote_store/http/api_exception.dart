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
///
/// The last is a schema rejection: its code is `VALIDATION_ERROR`, its
/// message the reasons joined, and its `details` name each refused field
/// under [ServerException.refusedFieldsKey].
///
/// A body with no readable `code` (none, or not a string) falls back by
/// status through [inferCodeFromStatus]; one with no readable `message`
/// reads `HTTP <status> from <path>` ([path] is the request's, when known)
/// (#37).
ServerException mapHttpError(
  int statusCode,
  Map<String, dynamic> body, {
  String? path,
}) {
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
    // Keep which field each reason is about (#19). The value that was sent
    // (`input`) is left behind: it may be a password.
    final fields = [
      for (final e in details)
        if (e is Map<String, dynamic> && e['loc'] is List)
          {'loc': e['loc'], 'msg': e['msg'], 'type': e['type']},
    ];
    error = {
      'code': SdkErrorCode.validationError,
      'message': messages,
      if (fields.isNotEmpty) ServerException.refusedFieldsKey: fields,
    };
  }

  final rawCode = error?['code'];
  final rawMessage = error?['message'];
  var code = rawCode is String && rawCode.isNotEmpty ? rawCode : null;
  var message = rawMessage is String && rawMessage.isNotEmpty
      ? rawMessage
      : null;

  code ??= inferCodeFromStatus(statusCode);
  message ??= path == null ? 'HTTP $statusCode' : 'HTTP $statusCode from $path';

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
  if (code == SdkErrorCode.scheduleConflict) {
    return ScheduleConflictException.fromDetails(message, details);
  }
  if (code == SdkErrorCode.invalidProfileOption) {
    return InvalidProfileOptionException.fromDetails(message, details);
  }
  if (code == SdkErrorCode.applicationIncomplete) {
    return ApplicationIncompleteException.fromDetails(message, details);
  }
  if (code == SdkErrorCode.applicationCategoryRequired) {
    return ApplicationCategoryRequiredException.fromDetails(message, details);
  }
  if (code == SdkErrorCode.applicationCategoryNotFitting) {
    return ApplicationCategoryNotFittingException.fromDetails(
      message,
      details,
    );
  }
  if (code == SdkErrorCode.applicationDoesNotFit) {
    return ApplicationDoesNotFitException.fromDetails(message, details);
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
///
/// 502, 503 and 504 are a server down behind its reverse proxy; any other
/// status with no code is a response the SDK cannot read (#37).
String inferCodeFromStatus(int statusCode) {
  switch (statusCode) {
    case 401:
      return SdkErrorCode.notAuthenticated;
    case 403:
      return SdkErrorCode.insufficientPermission;
    case 502:
    case 503:
    case 504:
      return SdkErrorCode.serverUnavailable;
    default:
      return SdkErrorCode.invalidResponse;
  }
}
