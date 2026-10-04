import '../../sdk/interfaces/audit_log.dart';
import '../../sdk/models/audit_log.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [AuditLogSource] using the HTTP API.
class RemoteAuditLogSource implements AuditLogSource {
  RemoteAuditLogSource(this._store);

  final RemoteStore _store;

  @override
  Future<AuditLogPage> list({
    int offset = 0,
    int limit = 50,
    String? actor,
    String? action,
    int? fromTsUtc,
    int? toTsUtc,
    String? username,
    String? resourceType,
    String? resourceId,
    int verbose = 1,
  }) async {
    assert(
      (resourceType == null) == (resourceId == null),
      'resourceType and resourceId must be provided together',
    );
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      'verbose': verbose.toString(),
      'actor': ?actor,
      'action': ?action,
      'from_ts': ?fromTsUtc?.toString(),
      'to_ts': ?toTsUtc?.toString(),
      'username': ?username,
      'resource_type': ?resourceType,
      'resource_id': ?resourceId,
    };
    final response = await _store.get(
      endpoints.auditLog.list,
      queryParams: queryParams,
    );
    return AuditLogPage.fromMap(response);
  }
}
